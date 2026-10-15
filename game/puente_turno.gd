extends Node
## Une el overworld con la sesión del turno (docs/plan-desarrollo.md, Paso 2).
## Solo traduce: las señales del mapa se vuelven llamadas a la sesión y sus
## resultados se muestran en el reloj, el menú y la caja de diálogo. Ninguna
## regla de juego vive aquí (la simulación no sabe nada de la interfaz).

const Sesion := preload("res://sim/sesion_turno.gd")
const Hud := preload("res://game/ui/hud_turno.gd")
const Menu := preload("res://game/ui/menu_acciones.gd")
const Datos := preload("res://game/overworld/mapa_locacion.gd")

## Parámetros por omisión de las acciones que el menú puede lanzar sin pantalla
## propia. Las demás (tratar, transferir, correr_prueba…) esperan a las
## pantallas del Hito 2 y 3 y salen apagadas.
const PARAMETROS_POR_OMISION := {"esperar": {"minutos": 10.0}}

var overworld: Node2D
var sesion: RefCounted
var hud: CanvasLayer
var menu: CanvasLayer
var _opciones_en_curso: Array = []
var _fin_avisado := false


func conectar(overworld_: Node2D, sesion_: RefCounted) -> void:
	overworld = overworld_
	sesion = sesion_
	overworld.mostrar_texto_estaciones = false
	overworld.caminado.connect(_al_caminar)
	overworld.interactuado.connect(_al_interactuar)
	overworld.hablado_con.connect(_al_hablar)
	overworld.valvula_cambiada.connect(func(id, abierta): sesion.valvula(id, abierta))

	hud = Hud.new()
	hud.name = "Reloj"
	overworld.add_child(hud)
	menu = Menu.new()
	menu.name = "MenuAcciones"
	overworld.add_child(menu)
	menu.elegido.connect(_al_elegir)
	menu.cancelado.connect(_liberar_jugador)
	_refrescar()


func _refrescar() -> void:
	hud.actualizar(sesion.estado())


func _al_caminar(casillas: int) -> void:
	var r: Dictionary = sesion.al_caminar(casillas)
	_refrescar()
	if not r["ok"]:
		if not _fin_avisado:
			_fin_avisado = true
			_decir([r["mensaje"]], "Turno")
		return
	if not r["avisos"].is_empty():
		_decir(_textos_de_avisos(r["avisos"]), "Aviso")


func _al_interactuar(id_estacion: String) -> void:
	var m: Dictionary = sesion.interactuar(id_estacion)
	if m["menu"].is_empty():
		_decir([_texto_de_estacion(id_estacion), m["mensaje"]], _nombre_de_estacion(id_estacion))
		return
	_opciones_en_curso = []
	for o in m["menu"]:
		var sin_pantalla := false
		for p: String in o["parametros"]:
			if not p.ends_with("?") and not PARAMETROS_POR_OMISION.get(o["accion"], {}).has(p):
				sin_pantalla = true
		_opciones_en_curso.append({"accion": o["accion"], "nombre": o["nombre"], "habilitada": not sin_pantalla})
	overworld.jugador.bloqueado = true
	menu.mostrar(_nombre_de_estacion(id_estacion), _opciones_en_curso)


func _al_elegir(accion: String) -> void:
	var r: Dictionary = sesion.ejecutar(accion, PARAMETROS_POR_OMISION.get(accion, {}))
	_refrescar()
	_decir(_textos_de_resultado(r), _nombre_de_estacion(sesion.estacion_mapa))


func _al_hablar(id_personaje: String) -> void:
	sesion.hablar_con(id_personaje)
	_refrescar()


func _liberar_jugador() -> void:
	overworld.jugador.set_deferred("bloqueado", false)


func _decir(textos: Array, quien: String) -> void:
	overworld.mostrar_dialogo(textos, quien)


## Mensaje del resultado, luego cada regla que se disparó con su porqué (feedback
## explícito) y los avisos que dejó el turno.
func _textos_de_resultado(r: Dictionary) -> Array:
	var t: Array = [r["mensaje"]]
	for h: Dictionary in r["hallazgos"]:
		t.append("%s: %s" % [h["titulo"], h["explicacion"]])
	t.append_array(_textos_de_avisos(r["avisos"]))
	return t.filter(func(x): return str(x) != "")


static func _textos_de_avisos(avisos: Array) -> Array:
	return avisos.map(func(a): return str(a["texto"]))


func _texto_de_estacion(id: String) -> String:
	for e in Datos.ESTACIONES:
		if e["id"] == id:
			return e["texto"]
	return ""


func _nombre_de_estacion(id: String) -> String:
	for e in Datos.ESTACIONES:
		if e["id"] == id:
			return e["nombre"]
	return ""
