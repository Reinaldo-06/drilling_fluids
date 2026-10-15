extends RefCounted
## Contrato entre el overworld y el turno (docs/plan-desarrollo.md, Paso 2).
##
##   overworld            sesión (este script)                 turno / simulación
##   caminado(n)    →     al_caminar(n)          →   Turno.caminar_casillas(n)
##   interactuado   →     interactuar(id)        →   (sin costo) fija la estación, ofrece un menú
##   (menú)         →     ejecutar(accion, {…})  →   Turno.<acción>(…)  → resultado estándar
##   hablado_con    →     hablar_con(id)         →   Turno.hablar(id)
##   valvula_cambiada →   valvula(id, abierta)   →   (se anota; Hito 3 la conecta a las rutas)
##
## Reglas del contrato (cada una tiene su prueba en tests/test_sesion_turno.gd):
## 1. El tiempo se cobra UNA vez. Caminar cuesta por casilla; interactuar no
##    cuesta; la acción cobra lo suyo SIN caminata (Turno.caminata_en_mapa).
## 2. No se actúa a distancia. Caminar invalida la estación: para actuar hay que
##    volver a interactuar con una estación que ofrezca esa acción.
## 3. Toda acción devuelve el resultado estándar (sim/resultado_accion.gd), con
##    el porqué en "mensaje" cuando falla.
## 4. Con el turno terminado solo queda entregar el reporte.
##
## No depende de nada de game/ (invariante 5): las estaciones del mapa llegan
## como ids de texto y su traducción vive en data/turno/estaciones_mapa.tres.

const Turno := preload("res://sim/turno.gd")
const Accion := preload("res://sim/accion.gd")
const Resultado := preload("res://sim/resultado_accion.gd")
const Lab := preload("res://sim/laboratorio.gd")
const TABLA := preload("res://data/turno/estaciones_mapa.tres")

## Acciones que siguen disponibles con el turno terminado.
const ACCIONES_DE_CIERRE := ["entregar_reporte"]

var turno: RefCounted
## Estación del mapa con la que se interactuó y donde sigue parado el jugador;
## "" si se alejó o todavía no interactuó.
var estacion_mapa := ""
## id de válvula del mapa → abierta (bool). Solo se anota; las rutas son del Hito 3.
var valvulas: Dictionary = {}


static func crear(turno_: RefCounted) -> RefCounted:
	var s = load("res://sim/sesion_turno.gd").new()
	s.turno = turno_
	turno_.caminata_en_mapa = true
	return s


## Estado para el reloj y el letrero de la interfaz.
func estado() -> Dictionary:
	return {
		"dia": turno.dia,
		"hora": turno.reloj.hora_texto(),
		"minuto": turno.reloj.minuto,
		"minutos_restantes": turno.reloj.restante(),
		"terminado": turno.reloj.terminado(),
		"estacion_mapa": estacion_mapa,
		"estacion": turno.ubicacion,
		"avisos_pendientes": turno.avisos.size(),
	}


# ======================= Señales del mapa =======================

## El jugador dio "casillas" pasos. Cada uno cuesta tiempo y lo aleja de la estación.
func al_caminar(casillas: int = 1) -> Dictionary:
	estacion_mapa = ""
	if turno.reloj.terminado():
		return Resultado.fallo("caminar", "El turno terminó: ya no se puede caminar. Entrega el reporte.", turno)
	var r: Dictionary = turno.caminar_casillas(casillas)
	return Resultado.de("caminar", r, turno)


## El jugador interactuó con una estación del mapa. No cuesta tiempo: solo dice
## qué se puede hacer ahí. Devuelve {ok, mensaje, estacion, menu: [{accion, nombre,
## parametros}]}.
func interactuar(id_estacion: String) -> Dictionary:
	var datos = _datos_estacion(id_estacion)
	if datos == null:
		return {"ok": false, "mensaje": "Esa estación no hace nada todavía.", "menu": []}
	estacion_mapa = id_estacion
	turno.ubicacion = datos["estacion"]
	var menu: Array = []
	for id in datos["acciones"]:
		if turno.reloj.terminado() and not id in ACCIONES_DE_CIERRE:
			continue
		var a: Dictionary = TABLA.valor("acciones")[id]
		menu.append({"accion": id, "nombre": a["nombre"], "parametros": a["parametros"]})
	var mensaje := ""
	if menu.is_empty():
		mensaje = "Aquí no hay nada que hacer con el lodo por ahora." if not turno.reloj.terminado() \
			else "El turno terminó: solo queda entregar el reporte en la oficina."
	return {"ok": true, "mensaje": mensaje, "estacion": datos["estacion"], "menu": menu}


## Hace una acción del menú de la estación actual. "params" son los parámetros
## de la acción (ver data/turno/estaciones_mapa.tres). Devuelve el resultado estándar.
func ejecutar(accion: String, params: Dictionary = {}) -> Dictionary:
	if estacion_mapa == "":
		return Resultado.fallo(accion, "Estás lejos de cualquier estación: camina hasta una e interactúa con ella.", turno)
	var datos = _datos_estacion(estacion_mapa)
	if datos == null or not accion in datos["acciones"]:
		return Resultado.fallo(accion, "Esa acción no se hace aquí.", turno)
	if turno.reloj.terminado() and not accion in ACCIONES_DE_CIERRE:
		return Resultado.fallo(accion, "El turno terminó: solo queda entregar el reporte.", turno)
	var faltan := _parametros_faltantes(accion, params)
	if not faltan.is_empty():
		return Resultado.fallo(accion, "Falta indicar: %s." % ", ".join(faltan), turno)
	var r: Dictionary = _llamar(accion, params)
	return Resultado.de(accion, r, turno)


## El jugador habló con un personaje: cuesta lo que dice la tabla de acciones.
func hablar_con(id_personaje: String) -> Dictionary:
	estacion_mapa = ""
	if turno.reloj.terminado():
		return Resultado.fallo("hablar", "El turno terminó.", turno)
	return Resultado.de("hablar", turno.hablar(id_personaje), turno)


## El jugador movió una válvula del mapa. Se anota (Hito 3 la conecta a las rutas
## hidráulicas); por ahora no cuesta tiempo: la caminata hasta ella ya se cobró.
func valvula(id_valvula: String, abierta: bool) -> Dictionary:
	valvulas[id_valvula] = abierta
	return {"ok": true, "mensaje": "La válvula quedó %s." % ("abierta" if abierta else "cerrada")}


# ======================= Parámetros: lo que elige el jugador =======================

## Los parámetros que hay que elegir para una acción, en orden:
## [{nombre, pregunta}]. Los opcionales (con "?") toman su valor por omisión.
func pasos_de(accion: String) -> Array:
	var pasos: Array = []
	var preguntas: Dictionary = TABLA.valor("parametros")
	if not TABLA.valor("acciones").has(accion):
		return pasos
	for p: String in TABLA.valor("acciones")[accion]["parametros"]:
		if not p.ends_with("?"):
			pasos.append({"nombre": p, "pregunta": preguntas.get(p, p)})
	return pasos


## Las opciones de un parámetro: [{valor, nombre}]. "elegidos" son los
## parámetros ya elegidos (la dosis del agua no es la de un polvo).
func opciones_de(accion: String, parametro: String, elegidos: Dictionary = {}) -> Array:
	var fijas: Dictionary = TABLA.valor("opciones_fijas")
	match parametro:
		"producto":
			return _opciones_de_producto(accion)
		"tanque", "origen", "destino":
			return turno.tanques.map(func(t): return {"valor": t.nombre,
				"nombre": "%s (%d bbl)" % [t.nombre, roundi(t.volumen_bbl)]})
		"prueba":
			return _opciones_de_prueba()
		"diagnostico":
			return _opciones_de_diagnostico()
		"lb_bbl":
			var clave := "lb_bbl_agua" if elegidos.get("producto", "") == "agua" else "lb_bbl"
			return _de_pares(fijas[clave])
	if fijas.has(parametro):
		return _de_pares(fijas[parametro])
	return []


static func _de_pares(pares: Array) -> Array:
	return pares.map(func(p): return {"valor": p[0], "nombre": p[1]})


func _opciones_de_producto(accion: String) -> Array:
	var ids: Array = []
	if turno.programa != null:
		ids = Array(turno.programa.productos_aprobados)
	else:
		ids = turno.inventario.sacos.keys()
	var o: Array = []
	for id: String in ids:
		if id == "agua" and accion == "ordenar_mezcla":
			continue
		var p: Resource = turno.inventario.producto(id)
		if p == null:
			continue
		var stock := "" if id == "agua" else " (%d sacos)" % floori(turno.inventario.disponible(id))
		o.append({"valor": id, "nombre": "%s%s" % [p.nombre, stock]})
	return o


func _opciones_de_prueba() -> Array:
	var o: Array = []
	var todas: Dictionary = Lab.cargar_todas()
	var ids := todas.keys()
	ids.sort()
	for id in ids:
		o.append({"valor": id, "nombre": todas[id].nombre})
	return o


func _opciones_de_diagnostico() -> Array:
	var o: Array = []
	if turno.seguimiento != null:
		for c: Dictionary in turno.seguimiento.caso.causas:
			o.append({"valor": c["id"], "nombre": c["nombre"]})
	o.append({"valor": "no_se", "nombre": "Todavía no sé"})
	return o


# ======================= Internos =======================

func _datos_estacion(id: String):
	var todas: Dictionary = TABLA.valor("estaciones")
	return todas.get(id)


## Parámetros obligatorios (los que no terminan en "?") que no vinieron.
func _parametros_faltantes(accion: String, params: Dictionary) -> Array:
	var faltan: Array = []
	for p: String in TABLA.valor("acciones")[accion]["parametros"]:
		if not p.ends_with("?") and not params.has(p):
			faltan.append(p)
	return faltan


func _llamar(accion: String, p: Dictionary) -> Dictionary:
	match accion:
		"chequeo_rapido":
			return turno.chequeo_rapido(str(p.get("tanque", "")))
		"chequeo_completo":
			return turno.chequeo_completo(str(p.get("tanque", "")), bool(p.get("con_retorta", false)))
		"correr_prueba":
			return turno.correr_prueba(str(p["prueba"]), str(p.get("tanque", "")))
		"diagnosticar":
			return turno.diagnosticar(str(p["diagnostico"]))
		"esperar":
			return turno.esperar(float(p["minutos"]))
		"tratar":
			return turno.tratar(str(p["producto"]), float(p["lb_bbl"]), str(p.get("tanque", "")),
				bool(p.get("prehidratada", false)))
		"ordenar_mezcla":
			return turno.ordenar_mezcla(str(p["producto"]), float(p["sacos"]), str(p.get("tanque", "")),
				bool(p.get("cuadrilla", false)), str(p.get("quien", "encuellador")))
		"transferir":
			return turno.transferir(str(p["origen"]), str(p["destino"]), float(p["bbl"]))
		"avisar_driller":
			return turno.avisar_driller()
		"entregar_reporte":
			var antes: float = turno.reloj.minuto
			var reporte = turno.entregar_reporte(p.get("recomendaciones", []))
			return {"minutos": turno.reloj.minuto - antes, "reporte": reporte, "tarde": reporte.tarde}
		"inventario":
			return {"minutos": 0.0, "inventario": turno.inventario.sacos.duplicate()}
		"observar":
			return turno.observar()
		"revisar_balance":
			return turno.revisar_balance()
		"ver_resumen":
			var resumen: Dictionary = turno.resumen_caso()
			if resumen.is_empty():
				return {"error": "Hoy no hay un caso asignado: el turno es de rutina."}
			return {"minutos": 0.0, "resumen": resumen}
	return {"error": "Acción desconocida: %s." % accion}
