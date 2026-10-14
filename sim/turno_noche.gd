extends RefCounted
## Turno de noche simulado (game-design-mechanics.md, "Turnos por día de pozo").
##
## El jugador no juega la noche: el pozo sigue (enganches de perforación,
## sólidos y eventos), el encuellador mezcla y la cuadrilla de noche cumple las
## RECOMENDACIONES que el jugador dejó en el reporte. Al día siguiente el
## jugador encuentra las consecuencias.
##
## Recomendaciones: lista de diccionarios con "tipo" y sus campos. "tanque" es
## opcional en todas (por omisión, la succión o el primer tanque activo).
##   mantener_producto  {producto, lb_bbl}: X lb de producto por cada bbl de
##                      lodo construido en la noche (= 100·X lb cada 100 bbl), para
##                      que el volumen nuevo salga con la concentración del programa.
##   agua               {bbl_h}: agua de dilución o de volumen, a ritmo fijo.
##   reponer_volumen    {bbl}: cada hora, completar el sistema activo con agua
##                      hasta esos bbl (el hueco se come volumen al perforar).
##   mantener_ph        {min, max, producto?}: cada hora la cuadrilla mide pH y,
##                      si está bajo el mínimo, ordena el producto (soda cáustica
##                      por omisión) para llevarlo a la mitad del rango.
##   densidad_objetivo  {ppg}: cada hora, si la densidad está más de
##                      TOLERANCIA_DENSIDAD_PPG bajo el objetivo, ordena barita.
## Todo lo que lleva sacos pasa por el encuellador: respeta su ritmo y la bodega.

const F := preload("res://sim/formulas.gd")
const Tanque := preload("res://sim/tanque.gd")
const Reloj := preload("res://sim/reloj.gd")

const TIPOS := ["mantener_producto", "agua", "reponer_volumen", "mantener_ph", "densidad_objetivo"]

## 🧩 La cuadrilla de noche revisa las recomendaciones cada hora.
const INTERVALO_MIN := 60.0
## 🧩 Dosis de prueba de la cuadrilla para el pH y tope por hora.
const PASO_DOSIS_PH_LB_BBL := 0.05
const DOSIS_MAX_PH_LB_BBL := 0.5
## 🧩 Margen antes de densificar.
const TOLERANCIA_DENSIDAD_PPG := 0.05


## "" si la recomendación es válida; si no, por qué.
static func validar(rec, turno: RefCounted) -> String:
	if not rec is Dictionary or not rec.has("tipo"):
		return "Una recomendación necesita un tipo."
	var tipo: String = rec["tipo"]
	if not tipo in TIPOS:
		return "Tipo de recomendación desconocido: %s." % tipo
	if rec.has("tanque") and turno.tanque(rec["tanque"]) == null:
		return "No hay un tanque llamado %s." % rec["tanque"]
	match tipo:
		"mantener_producto":
			if turno.inventario.producto(str(rec.get("producto", ""))) == null:
				return "Producto desconocido: %s." % rec.get("producto", "")
			if float(rec.get("lb_bbl", 0.0)) <= 0.0:
				return "Falta la concentración (lb/bbl)."
		"agua":
			if float(rec.get("bbl_h", 0.0)) <= 0.0:
				return "Falta el caudal de agua (bbl/h)."
		"reponer_volumen":
			if float(rec.get("bbl", 0.0)) <= 0.0:
				return "Falta el volumen a mantener (bbl)."
		"mantener_ph":
			if float(rec.get("min", 0.0)) <= 0.0 or float(rec.get("max", 0.0)) < float(rec.get("min", 0.0)):
				return "El rango de pH no es válido."
			if turno.inventario.producto(str(rec.get("producto", "soda_caustica"))) == null:
				return "Producto desconocido: %s." % rec.get("producto")
		"densidad_objetivo":
			if float(rec.get("ppg", 0.0)) <= 8.33:
				return "La densidad objetivo no es válida."
	return ""


static func describir(rec: Dictionary) -> String:
	match rec.get("tipo", ""):
		"mantener_producto":
			return "Mantener %s lb/bbl de %s en el lodo construido (%s lb cada 100 bbl)." % [
				rec["lb_bbl"], rec["producto"], float(rec["lb_bbl"]) * 100.0]
		"agua":
			return "Agregar %s bbl/h de agua." % rec["bbl_h"]
		"reponer_volumen":
			return "Mantener %s bbl en el sistema activo." % rec["bbl"]
		"mantener_ph":
			return "Mantener el pH entre %s y %s." % [rec["min"], rec["max"]]
		"densidad_objetivo":
			return "Densidad objetivo %s ppg." % rec["ppg"]
	return str(rec)


## Corre lo que queda del turno de día y las 12 h de la noche.
## Devuelve el resumen: {minutos, acciones: [{minuto, texto}], productos, costo,
## volumen (balance), avisos, invalidas}.
static func simular(turno: RefCounted, recomendaciones: Array) -> Dictionary:
	var validas: Array = []
	var invalidas: Array = []
	for rec in recomendaciones:
		var e := validar(rec, turno)
		if e == "":
			validas.append(rec)
		else:
			invalidas.append({"recomendacion": rec, "error": e})

	turno.en_noche = true
	turno.inventario.cerrar_turno()
	turno.abrir_contabilidad_volumen()
	var acciones: Array = []
	var deuda_lb := {}       # producto → lb pendientes de mantener_producto
	var construido_visto := 0.0
	var minuto := 0.0

	# Lo que quedaba del turno de día corre igual (el jugador ya entregó).
	var resto: float = turno.reloj.restante()
	if resto > 0.0:
		turno.avanzar_tiempo(resto)
		minuto += resto

	turno.reloj = Reloj.new()
	turno.reloj.hora_inicio = Reloj.HORA_INICIO_DIA + 12
	while not turno.reloj.terminado():
		for rec in validas:
			var texto := _aplicar(turno, rec, deuda_lb, construido_visto)
			if texto != "":
				acciones.append({"minuto": minuto + turno.reloj.minuto, "texto": texto})
		# mantener_producto mira el volumen construido hasta ahora, incluida el agua de esta hora.
		for rec in validas:
			if rec["tipo"] == "mantener_producto":
				var texto := _mantener_producto(turno, rec, deuda_lb,
					float(turno.volumen["construido"]) - construido_visto)
				if texto != "":
					acciones.append({"minuto": minuto + turno.reloj.minuto, "texto": texto})
		construido_visto = turno.volumen["construido"]
		turno.avanzar_tiempo(INTERVALO_MIN)

	var resumen := {
		"minutos": minuto + turno.reloj.minuto,
		"acciones": acciones,
		"productos": turno.inventario.productos_del_turno(),
		"costo": turno.inventario.costo_turno,
		"volumen": load("res://sim/reporte_diario.gd").balance_volumen(turno.volumen, turno.volumen_superficie()),
		"avisos": turno.tomar_avisos(),
		"invalidas": invalidas,
	}
	turno.en_noche = false
	turno.resumen_noche_anterior = resumen
	return resumen


static func _tanque(turno: RefCounted, rec: Dictionary) -> Resource:
	return turno.tanque(rec.get("tanque", ""))


static func _aplicar(turno: RefCounted, rec: Dictionary, _deuda: Dictionary, _visto: float) -> String:
	var t := _tanque(turno, rec)
	if t == null:
		return ""
	match rec["tipo"]:
		"agua":
			var bbl := float(rec["bbl_h"]) * INTERVALO_MIN / 60.0
			return turno.agregar_agua_noche(t, bbl)
		"reponer_volumen":
			var falta: float = float(rec["bbl"]) - turno.volumen_activo()
			if falta > 0.5:
				return turno.agregar_agua_noche(t, falta)
		"mantener_ph":
			return _mantener_ph(turno, t, rec)
		"densidad_objetivo":
			return _densidad(turno, t, rec)
	return ""


static func _mantener_producto(turno: RefCounted, rec: Dictionary, deuda: Dictionary, construido: float) -> String:
	if construido <= 0.0:
		return ""
	var id: String = rec["producto"]
	var p: Resource = turno.inventario.producto(id)
	deuda[id] = float(deuda.get(id, 0.0)) + float(rec["lb_bbl"]) * construido
	var sacos := floorf(deuda[id] / p.lb_por_saco + 1e-6)
	if sacos < 1.0:
		return ""
	deuda[id] -= sacos * p.lb_por_saco
	turno.ordenar_mezcla_noche(id, sacos, _tanque(turno, rec))
	return "Cuadrilla de noche: %d sacos de %s por %.0f bbl construidos." % [sacos, p.nombre, construido]


static func _ya_ordenado(turno: RefCounted, id: String) -> bool:
	for m in turno.encuellador.cola:
		if m["producto_id"] == id:
			return true
	return false


static func _mantener_ph(turno: RefCounted, t: Resource, rec: Dictionary) -> String:
	var id: String = rec.get("producto", "soda_caustica")
	var ph: float = t.lodo.ph()
	if ph >= float(rec["min"]) or _ya_ordenado(turno, id) or t.volumen_bbl <= 0.0:
		return ""
	var p: Resource = turno.inventario.producto(id)
	var meta := (float(rec["min"]) + float(rec["max"])) / 2.0
	# La cuadrilla prueba la dosis en una muestra (prueba piloto) antes de echarla.
	var lb := 0.0
	while lb < DOSIS_MAX_PH_LB_BBL - 1e-9:
		lb += PASO_DOSIS_PH_LB_BBL
		var copia = t.lodo.copiar()
		p.aplicar(copia, lb)
		if copia.ph() >= meta:
			break
	var sacos := ceilf(p.sacos(t.volumen_bbl, lb) - 1e-6)
	turno.ordenar_mezcla_noche(id, sacos, t)
	return "Cuadrilla de noche: pH %.1f bajo %.1f, %d sacos de %s." % [ph, float(rec["min"]), sacos, p.nombre]


static func _densidad(turno: RefCounted, t: Resource, rec: Dictionary) -> String:
	var objetivo := float(rec["ppg"])
	var d: float = t.lodo.densidad()
	if d >= objetivo - TOLERANCIA_DENSIDAD_PPG or _ya_ordenado(turno, "barita"):
		return ""
	var sacos := ceilf(F.sacos_barita(t.volumen_bbl, d, objetivo) - 1e-6)
	if sacos < 1.0:
		return ""
	turno.ordenar_mezcla_noche("barita", sacos, t)
	return "Cuadrilla de noche: densidad %.2f bajo %.2f ppg, %d sacos de barita." % [d, objetivo, sacos]
