extends RefCounted
## Conecta el pozo al turno (sim/turno.gd) por sus enganches:
##   antes   (§12.2 pasos 1–2): perforación (sim/perforacion.gd) y control de
##           sólidos (sim/control_solidos.gd) sobre la succión.
##   despues (§12.2 pasos 6–7): eventos del guion (sim/guion_ejecucion.gd) y
##           lectura del PVT (sim/monitor_tanques.gd).
##
## Volumen: el hueco nuevo, el lodo pegado a los recortes y el descarte de los
## equipos se registran en el balance del turno porque el jugador los conoce.
## Las pérdidas y ganancias de los eventos NO se registran: son justamente lo
## que el jugador tiene que notar (en el PVT, en los tanques o en el reporte).
##
## PVT: todo lo que cambió el activo entre dos lecturas, fuera de los eventos,
## cuenta como cambio conocido por el driller. Las transferencias sin avisar ya
## dan su falsa alarma en el propio turno (Turno.transferir), así que el monitor
## solo ve lo que hizo el pozo.

const Perforacion := preload("res://sim/perforacion.gd")
const ControlSolidos := preload("res://sim/control_solidos.gd")
const GuionEjecucion := preload("res://sim/guion_ejecucion.gd")
const MonitorTanques := preload("res://sim/monitor_tanques.gd")

const RUTA_MONITOR := "res://data/eventos/monitor_pvt.tres"

var formaciones: Array = []
var control: RefCounted = null
var guion: RefCounted = null
var monitor: Resource = null
var rop_ft_h := 0.0
var diametro_pulg := 0.0
## El driller está perforando (false: circulando sin avanzar, p. ej. en una
## conexión larga o esperando órdenes).
var perforando := true
## El driller paró las bombas por falta de nivel en la succión.
var bombas_paradas := false
var _caudal_guardado := 0.0
## Equipos que apagó una falla; se vuelven a encender cuando termina.
var _apagados_por_falla: Array = []
var _volumen_referencia := -1.0
## bbl que salieron del activo desde la última lectura del PVT sin que nadie lo
## supiera (filtración durante la perforación).
var _sin_avisar_bbl := 0.0


## "guion" es un GuionSeccion (data/guiones/) o null; "formaciones", Formacion
## (data/formaciones/).
static func crear(formaciones_: Array, guion_seccion: Resource, rop: float, diametro: float,
		semilla := 1) -> RefCounted:
	var o = load("res://sim/operacion_pozo.gd").new()
	o.formaciones = formaciones_
	o.control = ControlSolidos.crear_estandar()
	o.guion = GuionEjecucion.new(guion_seccion, semilla)
	o.monitor = (load(RUTA_MONITOR) as Resource).duplicate()
	o.rop_ft_h = rop
	o.diametro_pulg = diametro
	return o


func conectar(turno: RefCounted) -> void:
	if guion.programa == null:
		guion.programa = turno.programa
	monitor.referenciar(turno.tanques)
	_volumen_referencia = MonitorTanques.volumen_activo(turno.tanques)
	turno.enganches_antes.append(_perforar)
	turno.enganches_despues.append(_eventos)


## El driller reconoce la alarma del PVT: el volumen actual pasa a ser la
## referencia y la próxima diferencia vuelve a avisar.
func reconocer_alarma(turno: RefCounted) -> void:
	monitor.reconocer(turno.tanques)
	_volumen_referencia = MonitorTanques.volumen_activo(turno.tanques)


func perforacion_detenida(turno: RefCounted) -> bool:
	return not perforando or bombas_paradas or guion.perforacion_detenida(turno.tanques)


# ======================= Enganches =======================

func _perforar(turno: RefCounted, dt: float) -> void:
	_aplicar_fallas()
	var succion: Resource = turno.tanque_principal()
	if succion == null:
		return
	_revisar_succion(turno, succion)
	var formacion: Resource = Perforacion.formacion_en(formaciones, turno.profundidad_ft)
	if formacion != null and not perforacion_detenida(turno):
		var activos: Array = turno.tanques.filter(func(t): return t.en_sistema_activo)
		var r: Dictionary = Perforacion.paso(succion, formacion, rop_ft_h, diametro_pulg, dt, control, activos)
		if r["volumen_faltante_bbl"] > 0.0:
			_parar_bombas(turno, "No hay lodo en el activo para llenar el hueco: faltan %.0f bbl." % r["volumen_faltante_bbl"])
		elif r["pies"] > 0.0:
			turno.profundidad_ft += r["pies"]
			turno.volumen_pozo_bbl += r["hueco_bbl"]
			# Neto en superficie: sale el hueco, entra lo que el lodo retiene de los recortes.
			turno.registrar_volumen("hueco", r["hueco_bbl"] - r["retenidos_bbl"])
			turno.registrar_volumen("descarte", r["lodo_en_recortes_bbl"])
			# Filtración hacia una formación permeable: nadie la avisa ni se registra.
			var filtrado: float = Perforacion.tasa_filtracion(succion.lodo, formacion) * dt / 60.0
			if filtrado > 0.0:
				_sin_avisar_bbl += GuionEjecucion.restar_del_activo(turno.tanques, filtrado)
	var p: Dictionary = control.procesar(succion, dt)
	turno.registrar_volumen("descarte", p["descarte_bbl"])
	for e in control.equipos:
		if e.encendido:
			turno.horas_equipos[e.tipo] = turno.horas_equipos.get(e.tipo, 0.0) + dt / 60.0


## Succión bajo su mínimo → la bomba aspira aire: el driller para las bombas.
## Vuelven cuando el nivel se recupera (auditoría C2).
func _revisar_succion(turno: RefCounted, succion: Resource) -> void:
	var minimo: float = succion.minimo_bbl()
	if not bombas_paradas and succion.volumen_bbl < minimo:
		_parar_bombas(turno, "La succión bajó a %.0f bbl, bajo el mínimo de %.0f: la bomba empieza a aspirar aire." % [
			succion.volumen_bbl, minimo])
	elif bombas_paradas and succion.volumen_bbl >= minimo:
		bombas_paradas = false
		turno.caudal_gpm = _caudal_guardado
		turno.avisos.append({"minuto": turno.reloj.minuto, "tipo": "bombas_reanudadas",
			"quien_avisa": "driller", "texto": "Ya hay nivel en la succión. Arrancamos bombas y seguimos perforando."})


func _parar_bombas(turno: RefCounted, causa: String) -> void:
	if bombas_paradas:
		return
	bombas_paradas = true
	_caudal_guardado = turno.caudal_gpm
	turno.caudal_gpm = 0.0
	turno.avisos.append({"minuto": turno.reloj.minuto, "tipo": "bombas_paradas", "quien_avisa": "driller",
		"texto": "Inge, paré las bombas. %s Mándeme volumen al activo para seguir." % causa,
		"explicacion": "La bomba toma de la succión. Con el nivel bajo se forma un vórtice, entra aire y la bomba pierde la succión; además, sin lodo en superficie no se puede mantener lleno el pozo. Mantener volumen en el activo (construir en la reserva y transferir con aviso al driller) es trabajo del ingeniero de lodos.",
		"referencia": "docs/auditoria-logica.md C2; rig-tank-system.md §3"})


func _eventos(turno: RefCounted, dt: float) -> void:
	var tanques: Array = turno.tanques
	var antes := MonitorTanques.volumen_activo(tanques)
	if _volumen_referencia < 0.0:
		monitor.referenciar(tanques)
	else:
		monitor.cambio_avisado(antes - _volumen_referencia + _sin_avisar_bbl)
	_sin_avisar_bbl = 0.0
	var minuto: float = turno.reloj.minuto + dt
	var contexto := {"perforando": not perforacion_detenida(turno)}
	for a in guion.paso(tanques, turno.profundidad_ft, dt, contexto):
		var aviso: Dictionary = a.duplicate()
		aviso["minuto"] = minuto
		aviso["tipo"] = "evento_" + str(a["tipo"])
		turno.avisos.append(aviso)
	var lectura: Dictionary = monitor.leer(tanques)
	if lectura["nueva"] and not lectura["falsa"]:
		turno.avisos.append({"minuto": minuto, "tipo": "alarma_pvt", "texto": lectura["aviso"],
			"quien_avisa": lectura["quien_avisa"], "explicacion": lectura["explicacion"],
			"referencia": lectura["referencia"]})
	_volumen_referencia = MonitorTanques.volumen_activo(tanques)


func _aplicar_fallas() -> void:
	var fuera: Array = guion.equipos_fuera()
	for tipo in _apagados_por_falla.duplicate():
		if not tipo in fuera:
			control.encender(tipo, true)
			_apagados_por_falla.erase(tipo)
	for tipo in fuera:
		var e: Resource = control.equipo(tipo)
		if e != null and e.encendido:
			control.encender(tipo, false)
			_apagados_por_falla.append(tipo)
