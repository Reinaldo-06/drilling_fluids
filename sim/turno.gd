extends RefCounted
## El turno de día: convierte la simulación en un día de juego, sin interfaz.
##
## Cada acción del jugador cuesta minutos del reloj (sim/reloj.gd, 720 min). Al
## avanzar el reloj corre, en pasos de 10 min y en el orden de
## simulation-logic.md §12.2:
##   1–2. enganches_antes   (perforación, control de sólidos: otros sistemas)
##   3.   encuellador y obrero de patio (mezclas en curso)
##   4–5. Cinetica.paso     (química, hidratación, asentamiento, homogenización)
##   6–7. enganches_despues (eventos, detección)
##   y se entregan los resultados de laboratorio cuya espera terminó.
## Cada enganche es un Callable f(turno, dt_min). Puede leer y cambiar los
## tanques, caudal_gpm, volumen_pozo_bbl, profundidad_ft, equipos,
## horas_equipos y temperatura, y debe contabilizar el volumen con
## registrar_volumen("hueco" | "descarte" | "perdidas" | "construido", bbl).
## Una pérdida que NO se registre es justamente la que el balance detecta.
##
## Las acciones que se pueden evaluar llaman al evaluador de reglas en su
## momento ("al_tratar", "al_transferir", "al_diagnosticar", "al_cerrar_dia") y
## guardan los hallazgos en "hallazgos" (debrief) y en la respuesta (aviso).
## Si el jugador no está en la estación de la acción, camina hasta ella y ese
## tiempo se suma.
##
## Toda acción devuelve un diccionario con "minutos" (lo que costó) o "error"
## (no se hizo y no gastó tiempo).

const Reloj := preload("res://sim/reloj.gd")
const Accion := preload("res://sim/accion.gd")
const Encuellador := preload("res://sim/encuellador.gd")
const Inventario := preload("res://sim/turno_inventario.gd")
const Reporte := preload("res://sim/reporte_diario.gd")
const Noche := preload("res://sim/turno_noche.gd")
const Seguimiento := preload("res://sim/seguimiento_caso.gd")
const Observacion := preload("res://sim/observacion.gd")
const Cinetica := preload("res://sim/cinetica.gd")
const Lab := preload("res://sim/laboratorio.gd")
const Evaluador := preload("res://sim/evaluador_reglas.gd")
const Props := preload("res://sim/propiedades_lodo.gd")
const Tanque := preload("res://sim/tanque.gd")

const CONCEPTOS_VOLUMEN := ["construido", "hueco", "descarte", "perdidas", "derrame"]

var dia := 1
var reloj: Reloj = Reloj.new()
var tanques: Array = []
var programa: Resource = null
var inventario: Inventario = Inventario.new()
var encuellador: Encuellador = Encuellador.new()
## Segundo mezclador: el jugador le puede dar la orden al encuellador o al
## obrero de patio (decisión del autor). Cada uno con su cola y su ritmo.
var obrero_patio: Encuellador = _mezclador("Obrero de patio")
const MEZCLADORES := ["encuellador", "obrero_patio"]
var evaluador: Evaluador = Evaluador.new()
var reglas: Array = []

## Estación donde está el jugador.
var ubicacion := "caseta"
## El driller prestó la cuadrilla de piso (lo decide un evento o el diálogo).
var cuadrilla_disponible := false
## false = el Fann se corre en frío (lee alto).
var copa_termica := true
var en_noche := false
## true: el jugador camina de verdad por el mapa (sim/sesion_turno.gd). La
## caminata se cobra por casilla (caminar_casillas) y las acciones ya no suman la
## de la tabla de distancias: sería descontarla dos veces.
var caminata_en_mapa := false

# --- Estado del pozo que mantienen los enganches ---
var caudal_gpm := 0.0
var volumen_pozo_bbl := 0.0
var profundidad_ft := 0.0
## equipo de control de sólidos → encendido (lo leen las reglas).
var equipos: Dictionary = {}
## equipo → horas de uso en el turno (para el reporte).
var horas_equipos: Dictionary = {}
## {"entrada": °F, "salida": °F}
var temperatura: Dictionary = {"entrada": null, "salida": null}

# --- Enganches ---
var enganches_antes: Array[Callable] = []
var enganches_despues: Array[Callable] = []
## f(turno, origen, destino, bbl): transferencia sin aviso (falsa alarma del PVT).
var enganches_alarma_pvt: Array[Callable] = []
## Lo que el pozo sabe y el jugador puede preguntar (sim/operacion_pozo.gd):
##   observadores: f(turno, estacion) → Array de textos de lo que se ve ahí
##   balance_volumen: f(turno, ventana_min) → {perdida_bbl_h, ventana_min}
var observadores: Array[Callable] = []
## Quien conectó los enganches (sim/operacion_pozo.gd). Un Callable no mantiene
## vivo a su objeto: sin esta referencia, la operación se libera y el pozo deja
## de perforar sin avisar.
var operacion: RefCounted = null
var balance_volumen: Callable = Callable()
## Caso en curso (sim/caso.gd) y el avance del jugador (sim/seguimiento_caso.gd).
var seguimiento: RefCounted = null
## f(turno, personaje) -> Variant: diálogo (lo pone la capa del juego).
var al_hablar: Callable = Callable()

# --- Registro del turno ---
## [{prueba, tanque, minuto_muestra, minuto, lecturas}]
var mediciones: Array = []
## Pruebas terminadas en el turno (para requisitos y para las reglas).
var pruebas_corridas: Array = []
## Pruebas con espera que todavía corren: [{prueba, muestra, tanque, minuto_muestra, fin}]
var pruebas_en_curso: Array = []
## equipo → minuto en que se libera.
var equipo_libre: Dictionary = {}
## [{minuto, momento, accion, id, titulo, tipo, explicacion, referencia}]
var hallazgos: Array = []
var acciones: Array = []
var tratamientos_previos: Array = []
var alarmas_pvt := 0
## Avisos para la interfaz: [{minuto, tipo, texto}]
var avisos: Array = []
var volumen: Dictionary = {}
var reporte: RefCounted = null
var resumen_noche_anterior: Dictionary = {}

var _aviso_driller := false
## Horas que cubre el próximo reporte: 24 si la noche anterior se simuló.
var horas_periodo := 12.0
var _noche_simulada := false
var _muestra_filtrado: RefCounted = null
## Lo que el jugador sabe de cada tanque: tanque → {clave: última lectura}.
## No se borra entre días (la retorta de ayer sigue dando el Fw).
var lecturas_por_tanque: Dictionary = {}
## Lecturas anteriores a la última, por tanque (para tendencias: "previo").
var lecturas_previas: Dictionary = {}


static func crear(tanques_: Array, programa_: Resource = null, inventario_inicial: Dictionary = {}) -> RefCounted:
	var t = load("res://sim/turno.gd").new()
	t.tanques = tanques_
	t.programa = programa_
	t.reglas = Evaluador.cargar_catalogo()
	for id in inventario_inicial:
		t.inventario.agregar(id, inventario_inicial[id])
	t.abrir_contabilidad_volumen()
	return t


## Empieza un nuevo turno de día (después de la noche).
func iniciar_dia() -> void:
	if reporte != null:
		dia += 1
	reloj = Reloj.new()
	mediciones.clear()
	pruebas_corridas.clear()
	pruebas_en_curso.clear()
	equipo_libre.clear()
	hallazgos.clear()
	acciones.clear()
	tratamientos_previos.clear()
	horas_equipos.clear()
	alarmas_pvt = 0
	reporte = null
	_aviso_driller = false
	_muestra_filtrado = null
	# El reporte diario cubre 24 h (decisión del autor): la noche simulada
	# después del reporte anterior y este turno de día. Si hubo noche, su
	# contabilidad sigue abierta; si no (primer día), se abre ahora.
	if _noche_simulada:
		horas_periodo = 24.0
	else:
		horas_periodo = 12.0
		inventario.cerrar_turno()
		abrir_contabilidad_volumen()
	_noche_simulada = false


# ======================= Consultas =======================

func tanque(nombre: String) -> Resource:
	if nombre == "":
		return tanque_principal()
	for t in tanques:
		if t.nombre == nombre:
			return t
	return null


## Succión del activo, o el primer tanque activo.
func tanque_principal() -> Resource:
	for t in tanques:
		if t.rol == "succion" and t.en_sistema_activo:
			return t
	for t in tanques:
		if t.en_sistema_activo:
			return t
	return null if tanques.is_empty() else tanques[0]


func volumen_superficie() -> float:
	var total := 0.0
	for t in tanques:
		total += t.volumen_bbl
	return total


func volumen_activo() -> float:
	return Cinetica.volumen_activo_bbl(tanques)


## Hallazgos nuevos y mensajes pendientes para la interfaz; los vacía.
func tomar_avisos() -> Array:
	var r := avisos.duplicate()
	avisos.clear()
	return r


# ======================= API para los enganches =======================

func abrir_contabilidad_volumen() -> void:
	volumen = {"inicial": volumen_superficie()}
	for c in CONCEPTOS_VOLUMEN:
		volumen[c] = 0.0


func registrar_volumen(concepto: String, bbl: float) -> void:
	assert(concepto in CONCEPTOS_VOLUMEN, "Concepto de volumen desconocido: %s" % concepto)
	volumen[concepto] += bbl


func avisar(tipo: String, texto: String) -> void:
	avisos.append({"minuto": reloj.minuto, "tipo": tipo, "texto": texto})


## Hace correr el tiempo (pasos de simulación) sin acción del jugador.
func avanzar_tiempo(minutos: float) -> float:
	return reloj.avanzar(minutos, _paso)


# ======================= Acciones del jugador =======================

## Activa un caso: de ahora en adelante el turno lleva el avance del jugador.
func activar_caso(caso: Resource) -> void:
	seguimiento = Seguimiento.new(caso)


## Resumen del caso para la oficina; {} si no hay caso.
func resumen_caso() -> Dictionary:
	return seguimiento.resumen() if seguimiento != null else {}


## Recorrer una zona del taladro y mirar: las zarandas (recortes y mallas) o los
## tanques (niveles y derrames), más las observaciones visuales del lodo
## (data/observaciones/). Solo se ve lo que se ve: nunca la química (invariante 1).
func observar(estacion := "") -> Dictionary:
	var donde := estacion if estacion != "" else ubicacion
	if not donde in ["zarandas", "tanques"]:
		return {"error": "Desde aquí no se ve nada útil del lodo: ve a las zarandas o a los tanques."}
	var minutos := Accion.minutos("observar")
	var costo := _caminata(donde) + minutos
	if not reloj.cabe(costo):
		return _sin_tiempo(costo)
	var inicio := reloj.minuto
	_ir_a(donde)
	avanzar_tiempo(minutos)
	var textos: Array = []
	if donde == "tanques":
		for t in tanques:
			textos.append("%s: %d bbl de %d%s." % [t.nombre, roundi(t.volumen_bbl), roundi(t.capacidad_bbl),
				" (mínimo %d)" % roundi(t.minimo_bbl()) if t.minimo_bbl() > 0.0 else ""])
	var principal := tanque_principal()
	for o: Resource in catalogo_observaciones():
		if o.visible_en(donde) and principal != null:
			textos.append(o.evaluar(principal.lodo))
	for f in observadores:
		textos.append_array(f.call(self, donde))
	var evidencia := "recortes" if donde == "zarandas" else "niveles"
	if seguimiento != null:
		seguimiento.registrar_evidencia(evidencia, reloj.minuto)
	if not evidencia in pruebas_corridas:
		pruebas_corridas.append(evidencia)
	acciones.append(Accion.registro("observar", inicio, reloj.minuto - inicio, {"estacion": donde}))
	return {"minutos": reloj.minuto - inicio, "textos": textos}


## El mud logger compara el volumen que sale del pozo con el que debería: lo que
## falta es lo que el pozo se está llevando (bbl/h). No dice la causa.
func revisar_balance(ventana_min := 60.0) -> Dictionary:
	if not balance_volumen.is_valid():
		return {"error": "El mud logger no tiene datos de volumen todavía."}
	var minutos := Accion.minutos("revisar_balance")
	var costo := _caminata("mud_logger") + minutos
	if not reloj.cabe(costo):
		return _sin_tiempo(costo)
	var inicio := reloj.minuto
	_ir_a("mud_logger")
	avanzar_tiempo(minutos)
	var b: Dictionary = balance_volumen.call(self, ventana_min)
	var h: Array = []
	if seguimiento != null:
		seguimiento.registrar_evidencia("balance_volumen", reloj.minuto)
		h = seguimiento.registrar_balance(float(b["perdida_bbl_h"]))
		_registrar_del_caso(h, "al_revisar_balance", {"tipo": "revisar_balance"})
	if not "balance_volumen" in pruebas_corridas:
		pruebas_corridas.append("balance_volumen")
	acciones.append(Accion.registro("revisar_balance", inicio, reloj.minuto - inicio, b))
	return {"minutos": reloj.minuto - inicio, "perdida_bbl_h": b["perdida_bbl_h"],
		"ventana_min": b["ventana_min"], "hallazgos": h}


## Minutos de caminata hasta una estación (0 si el mapa ya cobró cada casilla).
func _caminata(hacia: String) -> float:
	return 0.0 if caminata_en_mapa else Accion.minutos_caminar(ubicacion, hacia)


## Caminar "n" casillas del mapa: cada una cuesta Accion.minutos("caminar_casilla").
## Si no entran, no se camina y no se gasta tiempo.
func caminar_casillas(n: int) -> Dictionary:
	var m := float(n) * Accion.minutos("caminar_casilla")
	if n <= 0:
		return {"minutos": 0.0}
	if not reloj.cabe(m):
		return _sin_tiempo(m)
	avanzar_tiempo(m)
	return {"minutos": m}


func esperar(minutos: float) -> Dictionary:
	var m := avanzar_tiempo(minutos)
	acciones.append(Accion.registro("esperar", reloj.minuto - m, m))
	return {"minutos": m}


func caminar(destino: String) -> Dictionary:
	if not Accion.es_estacion(destino):
		return {"error": "No existe la estación %s." % destino}
	var m := _caminata(destino)
	if not reloj.cabe(m):
		return _sin_tiempo(m)
	_ir_a(destino)
	return {"minutos": m}


## Chequeo rápido: densidad, embudo y pH (≤ 10 min, lo hace el jugador).
func chequeo_rapido(tanque_nombre := "") -> Dictionary:
	return _chequeo(Lab.chequeo("rapido"), "chequeo_rapido", tanque_nombre)


## Chequeo completo, planificado con el laboratorio. con_retorta suma la
## retorta del día (corre en paralelo con el filtro prensa).
func chequeo_completo(tanque_nombre := "", con_retorta := false) -> Dictionary:
	var pruebas := Lab.chequeo("completo")
	if con_retorta:
		pruebas.append_array(Lab.chequeo("diaria"))
	return _chequeo(pruebas, "chequeo_completo", tanque_nombre)


## Una prueba suelta. El jugador queda ocupado los minutos activos; si tiene
## espera, el resultado llega solo cuando termina (ver tomar_avisos()).
func correr_prueba(id: String, tanque_nombre := "") -> Dictionary:
	var prueba: Resource = Lab.cargar(id) if ResourceLoader.exists("%s/%s.tres" % [Lab.CARPETA, id]) else null
	if prueba == null:
		return {"error": "No existe la prueba %s." % id}
	var t := tanque(tanque_nombre)
	if t == null:
		return {"error": "No hay un tanque llamado %s." % tanque_nombre}
	if not prueba.faltantes(pruebas_corridas).is_empty():
		return {"error": prueba.ejecutar(t.lodo, {"hechas": pruebas_corridas})["error"]}
	var caminata := _caminata("caseta")
	var espera_equipo := maxf(0.0, float(equipo_libre.get(prueba.equipo, 0.0)) - reloj.minuto - caminata)
	var costo: float = caminata + espera_equipo + prueba.minutos_activos
	if not reloj.cabe(costo):
		return _sin_tiempo(costo)
	var inicio := reloj.minuto
	_ir_a("caseta")
	avanzar_tiempo(espera_equipo)
	var muestra: RefCounted = _muestra_filtrado if prueba.muestra == "filtrado" else t.lodo.copiar()
	var minuto_muestra := reloj.minuto
	avanzar_tiempo(prueba.minutos_activos)
	var en_curso := {"prueba": prueba, "muestra": muestra, "tanque": t.nombre,
		"minuto_muestra": minuto_muestra, "fin": reloj.minuto + prueba.minutos_espera}
	if prueba.equipo != "":
		equipo_libre[prueba.equipo] = en_curso["fin"]
	acciones.append(Accion.registro("prueba", inicio, reloj.minuto - inicio, {"prueba": id, "tanque": t.nombre}))
	if prueba.minutos_espera <= 0:
		return {"minutos": reloj.minuto - inicio, "lecturas": _completar_prueba(en_curso)}
	pruebas_en_curso.append(en_curso)
	return {"minutos": reloj.minuto - inicio, "listo_en": en_curso["fin"]}


## Avisar al driller (y al mud logger) antes de transferir.
func avisar_driller() -> Dictionary:
	var costo := _caminata("piso") + Accion.minutos("avisar_driller")
	if not reloj.cabe(costo):
		return _sin_tiempo(costo)
	var inicio := reloj.minuto
	_ir_a("piso")
	avanzar_tiempo(Accion.minutos("avisar_driller"))
	_aviso_driller = true
	acciones.append(Accion.registro("avisar_driller", inicio, reloj.minuto - inicio))
	return {"minutos": reloj.minuto - inicio}


## Mover válvulas y pasar lodo con la bomba de transferencia. El aviso al
## driller vale para la próxima transferencia.
func transferir(origen_nombre: String, destino_nombre: String, bbl: float) -> Dictionary:
	var o := tanque(origen_nombre)
	var d := tanque(destino_nombre)
	if o == null or d == null or o == d:
		return {"error": "Origen o destino no válidos."}
	var movible := minf(maxf(bbl, 0.0), minf(o.volumen_bbl, d.espacio_libre_bbl()))
	if movible <= 0.0:
		return {"error": "No hay lodo para mover o el destino está lleno."}
	var minutos := Accion.minutos("abrir_valvulas") + movible / Accion.minutos("transferencia_bbl_por_min")
	var costo := _caminata("tanques") + minutos
	if not reloj.cabe(costo):
		return _sin_tiempo(costo)
	var inicio := reloj.minuto
	_ir_a("tanques")
	var antes: RefCounted = d.lodo.copiar()
	var movido: float = o.transferir(d, movible)
	# Entre dos tanques del activo el total no cambia: el PVT no ve nada.
	var afecta: bool = o.en_sistema_activo != d.en_sistema_activo
	var aviso := _aviso_driller
	_aviso_driller = false
	var accion := {"tipo": "transferir", "origen": o.nombre, "destino": d.nombre,
		"volumen_bbl": movido, "afecta_activo": afecta, "aviso_driller": aviso}
	var h := _evaluar("al_transferir", accion, antes, d.lodo, d.nombre)
	if afecta and not aviso:
		alarmas_pvt += 1
		avisar("alarma_pvt", "Alarma del PVT: el driller ve %+.0f bbl en el activo que nadie le avisó y para la perforación." % (
			movido if d.en_sistema_activo and not o.en_sistema_activo else -movido))
		for f in enganches_alarma_pvt:
			f.call(self, o, d, movido)
	avanzar_tiempo(minutos)
	acciones.append(Accion.registro("transferir", inicio, reloj.minuto - inicio, accion))
	return {"minutos": reloj.minuto - inicio, "movido_bbl": movido, "hallazgos": h}


## El jugador agrega el producto él mismo por el embudo. Los sacos se redondean
## hacia arriba (no se echan medios sacos); el agua va en bbl por bbl.
func tratar(producto_id: String, lb_bbl: float, tanque_nombre := "", prehidratada := false) -> Dictionary:
	var p := inventario.producto(producto_id)
	var t := tanque(tanque_nombre)
	if p == null or t == null or t.volumen_bbl <= 0.0 or lb_bbl <= 0.0:
		return {"error": "Producto, tanque o dosis no válidos."}
	var cantidad: float
	var lb_real := lb_bbl
	var minutos := Accion.minutos("tratar_base")
	if p.efecto == "agua":
		cantidad = lb_bbl * t.volumen_bbl
		minutos += cantidad / Accion.minutos("agua_bbl_por_min")
	else:
		cantidad = ceilf(p.sacos(t.volumen_bbl, lb_bbl) - 1e-6)
		lb_real = cantidad * p.lb_por_saco / t.volumen_bbl
		minutos += cantidad / Accion.minutos("tratar_sacos_por_h") * 60.0
	if inventario.disponible(producto_id) < cantidad - 1e-6:
		return {"error": "En la bodega quedan %d sacos de %s y hacen falta %d." % [
			floori(inventario.disponible(producto_id)), p.nombre, roundi(cantidad)]}
	var costo := _caminata("embudo") + minutos
	if not reloj.cabe(costo):
		return _sin_tiempo(costo)
	var inicio := reloj.minuto
	_ir_a("embudo")
	var antes: RefCounted = t.lodo.copiar()
	var costo_antes: float = inventario.costo_turno
	inventario.consumir(producto_id, cantidad)
	var r: Dictionary = t.tratar(p, lb_real)
	_contabilizar(r)
	var accion := {"tipo": "tratar", "producto": producto_id, "lb_bbl": lb_real,
		"volumen_bbl": t.volumen_bbl, "prehidratada": prehidratada}
	var h := _evaluar("al_tratar", accion, antes, t.lodo, t.nombre)
	tratamientos_previos.append(producto_id)
	if seguimiento != null:
		seguimiento.registrar_tratamiento(producto_id, cantidad)
	avanzar_tiempo(minutos)
	acciones.append(Accion.registro("tratar", inicio, reloj.minuto - inicio, accion))
	return {"minutos": reloj.minuto - inicio, "cantidad": cantidad, "lb_bbl": lb_real,
		"costo": inventario.costo_turno - costo_antes, "hallazgos": h}


## Orden al encuellador: mezcla en segundo plano a 50 sacos/h (250 con la
## cuadrilla prestada). Las reglas se evalúan al ordenar, con el lodo que
## resultaría de la mezcla completa.
func ordenar_mezcla(producto_id: String, sacos: float, tanque_nombre := "", cuadrilla := false,
		quien := "encuellador") -> Dictionary:
	if not quien in MEZCLADORES:
		return {"error": "Nadie llamado %s puede mezclar." % quien}
	var mezclador: Encuellador = get(quien)
	var p := inventario.producto(producto_id)
	var t := tanque(tanque_nombre)
	if p == null or t == null or t.volumen_bbl <= 0.0 or sacos <= 0.0 or p.efecto == "agua":
		return {"error": "Producto, tanque o cantidad no válidos."}
	if cuadrilla and not cuadrilla_disponible:
		return {"error": "El driller no prestó la cuadrilla de piso."}
	var costo := _caminata("tanques") + Accion.minutos("orden_encuellador")
	if not reloj.cabe(costo):
		return _sin_tiempo(costo)
	var inicio := reloj.minuto
	_ir_a("tanques")
	var lb_bbl: float = sacos * p.lb_por_saco / t.volumen_bbl
	var previsto = Tanque.crear(t.nombre, t.capacidad_bbl, t.rol, t.volumen_bbl, t.lodo.copiar(), t.en_sistema_activo)
	previsto.bentonita_sin_hidratar = t.bentonita_sin_hidratar
	previsto.tratar(p, lb_bbl)
	var accion := {"tipo": "tratar", "producto": producto_id, "lb_bbl": lb_bbl,
		"volumen_bbl": t.volumen_bbl, "mezcla": true, "sacos": sacos, "cuadrilla": cuadrilla}
	var h := _evaluar("al_tratar", accion, t.lodo, previsto.lodo, t.nombre)
	tratamientos_previos.append(producto_id)
	if seguimiento != null:
		seguimiento.registrar_tratamiento(producto_id, sacos)
	var mezcla: Dictionary = mezclador.ordenar(producto_id, p, sacos, t, cuadrilla, reloj.minuto)
	var aviso := ""
	if inventario.disponible(producto_id) < sacos:
		aviso = "En la bodega solo hay %d sacos de %s: la mezcla va a parar antes." % [
			floori(inventario.disponible(producto_id)), p.nombre]
	avanzar_tiempo(Accion.minutos("orden_encuellador"))
	acciones.append(Accion.registro("orden_encuellador", inicio, reloj.minuto - inicio, accion))
	return {"minutos": reloj.minuto - inicio, "mezcla": mezcla, "hallazgos": h, "aviso": aviso,
		"minutos_estimados": Encuellador.minutos_mezcla(sacos, cuadrilla)}


func hablar(personaje: String) -> Dictionary:
	if not Accion.ESTACION_DE_PERSONAJE.has(personaje):
		return {"error": "No hay nadie llamado %s." % personaje}
	var estacion: String = Accion.ESTACION_DE_PERSONAJE[personaje]
	var costo := _caminata(estacion) + Accion.minutos("hablar")
	if not reloj.cabe(costo):
		return _sin_tiempo(costo)
	var inicio := reloj.minuto
	_ir_a(estacion)
	var dialogo = al_hablar.call(self, personaje) if al_hablar.is_valid() else null
	avanzar_tiempo(Accion.minutos("hablar"))
	acciones.append(Accion.registro("hablar", inicio, reloj.minuto - inicio, {"personaje": personaje}))
	return {"minutos": reloj.minuto - inicio, "dialogo": dialogo}


## El jugador declara qué cree que pasa (para las reglas "al_diagnosticar").
func diagnosticar(diagnostico: String) -> Dictionary:
	var t := tanque_principal()
	var accion := {"tipo": "diagnosticar", "diagnostico": diagnostico}
	var h := _evaluar("al_diagnosticar", accion, t.lodo if t else null, t.lodo if t else null,
		t.nombre if t else "")
	if seguimiento != null:
		var del_caso: Array = seguimiento.registrar_diagnostico(diagnostico)
		_registrar_del_caso(del_caso, "al_diagnosticar", accion)
		h.append_array(del_caso)
	avanzar_tiempo(Accion.minutos("diagnosticar"))
	acciones.append(Accion.registro("diagnosticar", reloj.minuto, 0.0, accion))
	return {"minutos": 0.0, "hallazgos": h}


## Entrega el reporte en la oficina. Si el turno ya no da, se entrega tarde.
## Lo que queda del turno de día corre después en simular_noche().
func entregar_reporte(recomendaciones: Array = []) -> RefCounted:
	var inicio := reloj.minuto
	var costo := _caminata("oficina") + Accion.minutos("entregar_reporte")
	var tarde := not reloj.cabe(costo)
	_ir_a("oficina")
	avanzar_tiempo(Accion.minutos("entregar_reporte"))
	# El company man juzga lo que está en el reporte: solo lo medido.
	var t := tanque_principal()
	var h := _evaluar("al_cerrar_dia", {"tipo": "cerrar_dia"}, t.lodo if t else null,
		t.lodo if t else null, t.nombre if t else "")
	reporte = Reporte.desde_turno(self, recomendaciones)
	reporte.tarde = tarde
	reporte.hallazgos_cierre = h
	reporte.hallazgos_turno = hallazgos.duplicate()
	acciones.append(Accion.registro("entregar_reporte", inicio, reloj.minuto - inicio))
	return reporte


## Corre el resto del día y la noche con las recomendaciones del último reporte.
func simular_noche(recomendaciones = null) -> Dictionary:
	var recs: Array = recomendaciones if recomendaciones != null else \
		(reporte.recomendaciones if reporte != null else [])
	var resumen := Noche.simular(self, recs)
	_noche_simulada = true
	return resumen


# ======================= Lo que usa la noche =======================

func agregar_agua_noche(t: Resource, bbl: float) -> String:
	var agua := inventario.producto("agua")
	var bbl_real := minf(bbl, t.espacio_libre_bbl())
	if bbl_real <= 0.0 or t.volumen_bbl <= 0.0:
		return ""
	inventario.consumir("agua", bbl_real)
	_contabilizar(t.tratar(agua, bbl_real / t.volumen_bbl))
	return "Cuadrilla de noche: %.0f bbl de agua en %s." % [bbl_real, t.nombre]


func ordenar_mezcla_noche(producto_id: String, sacos: float, t: Resource) -> void:
	encuellador.ordenar(producto_id, inventario.producto(producto_id), sacos, t, false, reloj.minuto)


# ======================= Internos =======================

func _paso(minuto_inicio: float, dt: float) -> void:
	for f in enganches_antes:
		f.call(self, dt)
	for quien in MEZCLADORES:
		var r: Dictionary = (get(quien) as Encuellador).avanzar(dt, inventario)
		for ap in r["aplicado"]:
			_contabilizar(ap)
		for a in r["avisos"]:
			avisos.append({"minuto": minuto_inicio + dt, "tipo": quien + "_" + a["tipo"], "texto": a["texto"]})
	Cinetica.paso(tanques, dt, caudal_gpm, volumen_pozo_bbl)
	for f in enganches_despues:
		f.call(self, dt)
	var fin := minuto_inicio + dt
	for en_curso in pruebas_en_curso.duplicate():
		if en_curso["fin"] <= fin + 1e-6:
			pruebas_en_curso.erase(en_curso)
			_completar_prueba(en_curso)
			avisos.append({"minuto": en_curso["fin"], "tipo": "resultado",
				"texto": "Listo: %s." % en_curso["prueba"].nombre})


func _completar_prueba(en_curso: Dictionary) -> Dictionary:
	var prueba: Resource = en_curso["prueba"]
	var lecturas: Dictionary = prueba.ejecutar(en_curso["muestra"],
		{"hechas": pruebas_corridas, "copa_termica": copa_termica})
	_registrar_medicion(prueba.id, en_curso["tanque"], en_curso["minuto_muestra"], en_curso["fin"], lecturas)
	if prueba.produce == "filtrado" or prueba.id == "filtrado_api":
		_muestra_filtrado = en_curso["muestra"]
	return lecturas


func _chequeo(pruebas: Array, tipo: String, tanque_nombre: String) -> Dictionary:
	var t := tanque(tanque_nombre)
	if t == null:
		return {"error": "No hay un tanque llamado %s." % tanque_nombre}
	var plan := Lab.planificar(pruebas)
	if plan.has("error"):
		return {"error": plan["error"]}
	var costo: float = _caminata("caseta") + plan["total_min"]
	if not reloj.cabe(costo):
		return _sin_tiempo(costo)
	var inicio := reloj.minuto
	_ir_a("caseta")
	var muestra: RefCounted = t.lodo.copiar()
	var minuto_muestra := reloj.minuto
	avanzar_tiempo(plan["total_min"])
	var ids: Array = []
	for p in pruebas:
		ids.append(p.id)
	var todas := {}
	for p in pruebas:
		var lecturas: Dictionary = p.ejecutar(muestra, {"hechas": ids, "copa_termica": copa_termica})
		_registrar_medicion(p.id, t.nombre, minuto_muestra, reloj.minuto, lecturas)
		todas.merge(lecturas, true)
	if "filtrado_api" in ids:
		_muestra_filtrado = muestra
	acciones.append(Accion.registro(tipo, inicio, reloj.minuto - inicio, {"tanque": t.nombre}))
	return {"minutos": reloj.minuto - inicio, "plan": plan, "lecturas": todas}


func _registrar_medicion(id: String, tanque_nombre: String, minuto_muestra: float, minuto: float, lecturas: Dictionary) -> void:
	if lecturas.has("error"):
		return
	var m := {"prueba": id, "tanque": tanque_nombre, "minuto_muestra": minuto_muestra,
		"minuto": minuto, "lecturas": lecturas}
	mediciones.append(m)
	var actuales: Dictionary = lecturas_por_tanque.get(tanque_nombre, {})
	var previas: Dictionary = lecturas_previas.get(tanque_nombre, {})
	var nuevas := Reporte.medidos([m])
	for clave in nuevas:
		if actuales.has(clave):
			previas[clave] = actuales[clave]
		actuales[clave] = nuevas[clave]
	lecturas_por_tanque[tanque_nombre] = actuales
	lecturas_previas[tanque_nombre] = previas
	if not id in pruebas_corridas:
		pruebas_corridas.append(id)


## Evalúa las reglas del momento sobre lo que el jugador midió en el tanque
## (Props.de_medido) y lo que puede prever de su acción. Devuelve los hallazgos
## inmediatos. Las reglas con debrief_real que solo se disparan con el estado
## real quedan en "hallazgos" con "fuente": "real", sin aviso (invariante 1).
func _evaluar(momento: String, accion: Dictionary, antes, despues, tanque_nombre := "") -> Array:
	var real_antes := Props.de(antes)
	var real_despues := Props.de(despues)
	var medido_antes := Props.de_medido(lecturas_por_tanque.get(tanque_nombre, {}))
	var medido_despues := Props.proyectar(medido_antes, real_antes, real_despues)
	var medido_previo := Props.de_medido(lecturas_previas.get(tanque_nombre, {}))
	var ctx := {
		"antes": medido_antes, "despues": medido_despues, "previo": medido_previo,
		"accion": accion,
		"pruebas_corridas": pruebas_corridas,
		"tratamientos_previos": tratamientos_previos,
		"equipos": equipos,
	}
	if programa != null:
		ctx["programa"] = programa
	var h: Array = evaluador.evaluar(reglas, momento, ctx)
	var ids: Array = h.map(func(x): return x["id"])
	var solo_debrief: Array = []
	var con_real := reglas.filter(func(r): return r.debrief_real and not r.id in ids)
	if not con_real.is_empty():
		var ctx_real := ctx.duplicate()
		ctx_real["antes"] = real_antes
		ctx_real["despues"] = real_despues
		ctx_real["previo"] = real_antes
		solo_debrief = evaluador.evaluar(con_real, momento, ctx_real)
	for x: Dictionary in h:
		_guardar_hallazgo(x, momento, accion, "medido")
		avisos.append({"minuto": reloj.minuto, "tipo": "hallazgo_" + x["tipo"], "texto": x["titulo"]})
	for x: Dictionary in solo_debrief:
		_guardar_hallazgo(x, momento, accion, "real")
	return h


## Los hallazgos del caso van al debrief y al aviso igual que los de las reglas.
func _registrar_del_caso(hallazgos_: Array, momento: String, accion: Dictionary) -> void:
	for x: Dictionary in hallazgos_:
		_guardar_hallazgo(x, momento, accion, "caso")
		avisos.append({"minuto": reloj.minuto, "tipo": "hallazgo_" + x["tipo"], "texto": x["titulo"]})


func _guardar_hallazgo(x: Dictionary, momento: String, accion: Dictionary, fuente: String) -> void:
	var registro := x.duplicate()
	registro["minuto"] = reloj.minuto
	registro["momento"] = momento
	registro["accion"] = accion
	registro["fuente"] = fuente
	hallazgos.append(registro)


static var _observaciones: Array = []


## Catálogo de observaciones visuales (data/observaciones/), cargado una vez.
static func catalogo_observaciones() -> Array:
	if _observaciones.is_empty():
		for archivo in DirAccess.get_files_at("res://data/observaciones"):
			archivo = archivo.trim_suffix(".remap")
			if archivo.ends_with(".tres"):
				_observaciones.append(load("res://data/observaciones/%s" % archivo))
	return _observaciones


func _contabilizar(r: Dictionary) -> void:
	volumen["construido"] += float(r.get("volumen_agregado_bbl", 0.0))
	volumen["derrame"] += float(r.get("rebalse_bbl", 0.0))
	if float(r.get("rebalse_bbl", 0.0)) > 0.0:
		avisar("derrame", "El tanque rebalsó: se perdieron %.1f bbl." % r["rebalse_bbl"])


func _ir_a(estacion: String) -> void:
	var m := _caminata(estacion)
	if m > 0.0:
		var inicio := reloj.minuto
		avanzar_tiempo(m)
		acciones.append(Accion.registro("caminar", inicio, reloj.minuto - inicio, {"desde": ubicacion, "hasta": estacion}))
	ubicacion = estacion


static func _mezclador(nombre: String) -> Encuellador:
	var m := Encuellador.new()
	m.nombre = nombre
	return m


func _sin_tiempo(costo: float) -> Dictionary:
	return {"error": "No alcanza el turno: hacen falta %.0f min y quedan %.0f." % [costo, reloj.restante()]}
