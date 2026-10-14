extends RefCounted
## Ejecuta un GuionSeccion sobre los tanques: dispara los eventos y aplica sus
## efectos en cada paso de simulación (simulation-logic.md §12.2, paso 6).
##
## Lo que hace cada tipo (todo le OCURRE al jugador; nadie opera BOP ni bombas):
##   perdida_circulacion  resta tasa·Δt del activo mientras dura (o hasta terminar()).
##   influjo              suma la ganancia al activo y exige el peso de matada
##                        (Formulas.peso_de_matada, redondeado arriba a 0,1 ppg).
##                        La perforación queda parada hasta tener ese peso.
##   contaminacion        aplica el contaminante al lodo de todos los tanques
##                        activos, de una vez o repartido en la duración.
##   gas_*                solo avisa; con subir_densidad_ppg exige un peso mínimo.
##   viaje                para la perforación mientras dura.
##   falla_equipo         saca un equipo de servicio mientras dura.
##   sag                  solo avisa (la oscilación en la llegada va en el aviso).
##
## Los efectos sobre el volumen NO se le cuentan al PVT (sim/monitor_tanques.gd):
## por eso el monitor ve una pérdida o ganancia real y da alarma verdadera.

const Props := preload("res://sim/propiedades_lodo.gd")
const EventoScript := preload("res://sim/evento.gd")

const CARPETA_EVENTOS := "res://data/eventos"

var guion: Resource
var rng := RandomNumberGenerator.new()
## Horas de juego desde que empezó la sección.
var horas := 0.0
## id → horas en que disparó.
var disparados: Dictionary = {}
## Eventos con efecto en curso: {evento, restante_h, perdido_bbl}.
var activos: Array = []
## Avisos dados en la sección, en orden (para el debrief).
var historial: Array = []
## Lo que el pozo le exige al jugador: id del evento → {peso_minimo_ppg, detiene, texto}.
## "detiene": la perforación espera a que se cumpla (influjo: peso de matada).
var exigencias: Dictionary = {}


func _init(guion_: Resource = null, semilla := 1) -> void:
	guion = guion_
	rng.seed = semilla


## Todos los eventos de data/eventos/ (descarta otros recursos de la carpeta).
static func cargar_catalogo(carpeta := CARPETA_EVENTOS) -> Array:
	var eventos: Array = []
	for archivo in DirAccess.get_files_at(carpeta):
		archivo = archivo.trim_suffix(".remap")
		if archivo.ends_with(".tres"):
			var r = load("%s/%s" % [carpeta, archivo])
			if r != null and r.get_script() == EventoScript:
				eventos.append(r)
	return eventos


## Un paso de simulación. Devuelve los avisos nuevos (diccionarios, ver _aviso).
## "contexto" llega a las condiciones de los eventos (perforando, acciones…).
func paso(tanques: Array, profundidad_ft: float, dt_min: float, contexto := {}) -> Array:
	var dt_h := dt_min / 60.0
	horas += dt_h
	var nuevos: Array = []
	if guion != null:
		var estado := _estado(tanques, profundidad_ft, contexto)
		for e in guion.eventos:
			if disparados.has(e.id):
				continue
			if e.debe_disparar(estado, dt_h, rng):
				nuevos.append(disparar(e, tanques, profundidad_ft))
	_avanzar_activos(tanques, dt_h)
	return nuevos


## Dispara un evento ya (también para pruebas y para eventos sueltos fuera de
## guion). Aplica el efecto instantáneo y devuelve el aviso.
func disparar(e: Resource, tanques: Array, profundidad_ft := 0.0) -> Dictionary:
	disparados[e.id] = horas
	var datos := {
		"profundidad": profundidad_ft, "tasa": e.tasa_perdida_bbl_h,
		"clasificacion": e.clasificacion(), "gas": e.gas_unidades,
		"sidpp": e.sidpp_psi, "tvd": e.tvd_ft, "ganancia": e.ganancia_bbl,
		"variacion": e.variacion_densidad_ppg, "equipo": e.equipo,
		"subir": e.subir_densidad_ppg,
	}
	var densidad := densidad_activo(tanques)
	datos["densidad"] = densidad
	match e.tipo:
		"influjo":
			sumar_al_activo(tanques, e.ganancia_bbl)
			var kmw: float = e.peso_de_matada(densidad)
			datos["peso_matada_exacto"] = kmw
			datos["peso_matada"] = EventoScript.redondear_arriba(kmw)
			exigencias[e.id] = {"peso_minimo_ppg": datos["peso_matada"], "detiene": true,
				"texto": "Peso de matada %.1f ppg" % datos["peso_matada"]}
		"gas_fondo", "gas_conexion", "gas_viaje":
			if e.subir_densidad_ppg > 0.0:
				var objetivo := snappedf(densidad + e.subir_densidad_ppg, 0.1)
				datos["peso_pedido"] = objetivo
				exigencias[e.id] = {"peso_minimo_ppg": objetivo, "detiene": false,
					"texto": "Subir la densidad a %.1f ppg" % objetivo}
		"contaminacion":
			if e.duracion_h <= 0.0:
				aplicar_contaminante(tanques, e.contaminante, e.cantidad)
	if e.duracion_h > 0.0:
		activos.append({"evento": e, "restante_h": e.duracion_h, "perdido_bbl": 0.0})
	var aviso := _aviso(e, datos)
	historial.append(aviso)
	return aviso


## Termina antes de tiempo un evento en curso (p. ej. la píldora de material de
## pérdida selló la zona). Devuelve false si no estaba activo.
func terminar(id_evento: String) -> bool:
	for i in activos.size():
		if activos[i]["evento"].id == id_evento:
			activos.remove_at(i)
			return true
	return false


func esta_activo(id_evento: String) -> bool:
	return activos.any(func(a): return a["evento"].id == id_evento)


## bbl perdidos hasta ahora por un evento (activo o no, mientras siga en la lista).
func perdido_bbl(id_evento: String) -> float:
	for a in activos:
		if a["evento"].id == id_evento:
			return a["perdido_bbl"]
	return _perdido_terminado.get(id_evento, 0.0)


## Equipos que hoy no se pueden encender (fallas en curso).
func equipos_fuera() -> Array:
	var r: Array = []
	for a in activos:
		if a["evento"].tipo == "falla_equipo":
			r.append(a["evento"].equipo)
	return r


## ¿Está parada la perforación? Viajes en curso, o un influjo cuyo peso de
## matada todavía no se alcanzó en el activo.
func perforacion_detenida(tanques: Array) -> bool:
	for a in activos:
		if a["evento"].detiene_perforacion:
			return true
	for id_evento in exigencias:
		if exigencias[id_evento]["detiene"] and not exigencia_cumplida(id_evento, tanques):
			return true
	return false


## ¿El activo ya tiene el peso que exige el evento? (tolerancia de la balanza)
func exigencia_cumplida(id_evento: String, tanques: Array) -> bool:
	if not exigencias.has(id_evento):
		return true
	return densidad_activo(tanques) >= float(exigencias[id_evento]["peso_minimo_ppg"]) - 0.05


## Lo que hace falta para el debrief: un renglón por evento disparado.
func debrief() -> Array:
	var r: Array = []
	for a in historial:
		r.append({"id": a["id"], "titulo": a["titulo"], "explicacion": a["explicacion"],
			"referencia": a["referencia"]})
	return r


# ======================= Efectos sobre los tanques =======================

## Resta "bbl" del activo, repartido en proporción al volumen de cada tanque.
## Devuelve lo que realmente se sacó.
static func restar_del_activo(tanques: Array, bbl: float) -> float:
	var total := _volumen_activo(tanques)
	if total <= 0.0 or bbl <= 0.0:
		return 0.0
	var sacar := minf(bbl, total)
	for t in tanques:
		if t.en_sistema_activo and t.volumen_bbl > 0.0:
			t.volumen_bbl -= sacar * t.volumen_bbl / total
	return sacar


## Suma "bbl" al activo con el mismo lodo (ganancia por influjo). 🧩 El fluido
## de formación no cambia la composición: el modelo no lleva gas ni salmuera
## de formación todavía. Respeta la capacidad.
static func sumar_al_activo(tanques: Array, bbl: float) -> float:
	var total := _volumen_activo(tanques)
	if total <= 0.0 or bbl <= 0.0:
		return 0.0
	var sumado := 0.0
	for t in tanques:
		if t.en_sistema_activo and t.volumen_bbl > 0.0:
			var parte := minf(bbl * t.volumen_bbl / total, t.espacio_libre_bbl())
			t.volumen_bbl += parte
			sumado += parte
	return sumado


## Aplica el contaminante a cada tanque activo ("cantidad" por bbl de lodo).
## 🧩 Entra parejo en todo el activo: lo que pasa en el fondo llega en un
## retorno, y la homogenización (sim/cinetica.gd) lo reparte en un ciclo.
static func aplicar_contaminante(tanques: Array, contaminante: Resource, cantidad: float) -> void:
	for t in tanques:
		if t.en_sistema_activo and t.volumen_bbl > 0.0:
			contaminante.aplicar(t.lodo, cantidad)


## Densidad media del activo, ponderada por volumen (0 si está vacío).
static func densidad_activo(tanques: Array) -> float:
	var total := _volumen_activo(tanques)
	if total <= 0.0:
		return 0.0
	var suma := 0.0
	for t in tanques:
		if t.en_sistema_activo:
			suma += t.lodo.densidad() * t.volumen_bbl
	return suma / total


## Lodo medio del activo (copia mezclada) o null si no hay lodo.
static func lodo_medio(tanques: Array) -> RefCounted:
	var medio: RefCounted = null
	var vol := 0.0
	for t in tanques:
		if not t.en_sistema_activo or t.volumen_bbl <= 0.0:
			continue
		if medio == null:
			medio = t.lodo.copiar()
		else:
			medio.mezclar(t.lodo, vol, t.volumen_bbl)
		vol += t.volumen_bbl
	return medio


# ======================= Interno =======================

var _perdido_terminado: Dictionary = {}


func _avanzar_activos(tanques: Array, dt_h: float) -> void:
	var siguen: Array = []
	for a in activos:
		var e = a["evento"]
		var dt := minf(dt_h, a["restante_h"])
		match e.tipo:
			"perdida_circulacion":
				a["perdido_bbl"] += restar_del_activo(tanques, e.perdida_en(dt))
			"contaminacion":
				aplicar_contaminante(tanques, e.contaminante, e.cantidad * dt / e.duracion_h)
		a["restante_h"] -= dt
		if a["restante_h"] > 1e-9:
			siguen.append(a)
		else:
			_perdido_terminado[e.id] = a["perdido_bbl"]
	activos = siguen


func _estado(tanques: Array, profundidad_ft: float, contexto: Dictionary) -> Dictionary:
	var ctx := contexto.duplicate()
	ctx["disparados"] = disparados.keys()
	ctx["activos"] = activos.map(func(a): return a["evento"].id)
	var props := {}
	for e in guion.eventos:
		if not disparados.has(e.id) and e.condicion != "":
			props = Props.de(lodo_medio(tanques))
			break
	return {"profundidad": profundidad_ft, "horas": horas, "props": props, "contexto": ctx}


func _aviso(e: Resource, datos: Dictionary) -> Dictionary:
	return {
		"id": e.id, "titulo": e.titulo, "tipo": e.tipo, "quien_avisa": e.quien_avisa,
		"texto": _formatear(e.aviso, datos), "explicacion": _formatear(e.explicacion, datos),
		"referencia": e.referencia, "horas": horas, "datos": datos,
	}


## Claves que se escriben siempre con un decimal (ppg).
const CLAVES_PPG := ["densidad", "peso_matada", "peso_matada_exacto", "peso_pedido",
	"variacion", "subir"]


## Reemplaza {clave} por el valor con formato de campo: coma decimal y punto de
## miles ("10.000 ft", "11,0 ppg").
static func _formatear(texto: String, datos: Dictionary) -> String:
	var r := texto
	for clave: String in datos:
		var v = datos[clave]
		var s: String
		if v is float or v is int:
			if clave in CLAVES_PPG:
				s = ("%.1f" % v).replace(".", ",")
			elif absf(v - roundf(v)) > 1e-6:
				s = ("%.1f" % v).replace(".", ",")
			else:
				s = _miles(int(roundf(v)))
		else:
			s = str(v)
		r = r.replace("{%s}" % clave, s)
	return r


static func _miles(n: int) -> String:
	var s := str(absi(n))
	var r := ""
	while s.length() > 3:
		r = "." + s.substr(s.length() - 3) + r
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + r


static func _volumen_activo(tanques: Array) -> float:
	var total := 0.0
	for t in tanques:
		if t.en_sistema_activo:
			total += t.volumen_bbl
	return total
