extends Node
## Une el overworld con la sesión del turno (docs/plan-desarrollo.md, Paso 2).
## Solo traduce: las señales del mapa se vuelven llamadas a la sesión y sus
## resultados se muestran en el reloj, el menú y la caja de diálogo. Ninguna
## regla de juego vive aquí (la simulación no sabe nada de la interfaz).

const Sesion := preload("res://sim/sesion_turno.gd")
const Hud := preload("res://game/ui/hud_turno.gd")
const Menu := preload("res://game/ui/menu_acciones.gd")
const Datos := preload("res://game/overworld/mapa_locacion.gd")

var overworld: Node2D
var sesion: RefCounted
var hud: CanvasLayer
var menu: CanvasLayer
var _opciones_en_curso: Array = []
var _fin_avisado := false
## Asistente de parámetros: la acción elegida, sus pasos, lo ya elegido y las
## opciones del paso en curso (el menú devuelve su posición).
var _accion := ""
var _pasos: Array = []
var _elegidos: Dictionary = {}
var _opciones_del_paso: Array = []


func conectar(overworld_: Node2D, sesion_: RefCounted, mostrar_objetivo := false) -> void:
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
	menu.cancelado.connect(_al_cancelar)
	_refrescar()
	if mostrar_objetivo:
		var resumen: Dictionary = sesion.turno.resumen_caso()
		if not resumen.is_empty():
			_decir([resumen["objetivo"]], "Objetivo del turno")


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
	_accion = ""
	_opciones_en_curso = m["menu"].map(func(o): return {"accion": o["accion"], "nombre": o["nombre"], "habilitada": true})
	overworld.jugador.bloqueado = true
	menu.mostrar(_nombre_de_estacion(id_estacion), _opciones_en_curso)


## Elegir en el menú: o una acción de la estación, o la opción de un parámetro.
func _al_elegir(clave: String) -> void:
	if _accion == "":
		_iniciar_asistente(clave)
	else:
		_elegir_parametro(int(clave))


## Una acción con parámetros pregunta de a uno (producto, dosis, tanque…); una
## sin parámetros se ejecuta ya.
func _iniciar_asistente(accion: String) -> void:
	_accion = accion
	_pasos = sesion.pasos_de(accion)
	_elegidos = {}
	_siguiente_paso()


func _siguiente_paso() -> void:
	if _elegidos.size() >= _pasos.size():
		var accion := _accion
		_accion = ""
		var r: Dictionary = sesion.ejecutar(accion, _elegidos)
		_refrescar()
		_decir(_textos_de_resultado(r), _nombre_de_estacion(sesion.estacion_mapa))
		return
	var paso: Dictionary = _pasos[_elegidos.size()]
	_opciones_del_paso = sesion.opciones_de(_accion, paso["nombre"], _elegidos)
	var opciones: Array = []
	for i in _opciones_del_paso.size():
		opciones.append({"accion": str(i), "nombre": _opciones_del_paso[i]["nombre"], "habilitada": true})
	overworld.jugador.bloqueado = true
	menu.mostrar(paso["pregunta"], opciones)


func _elegir_parametro(indice: int) -> void:
	var paso: Dictionary = _pasos[_elegidos.size()]
	_elegidos[paso["nombre"]] = _opciones_del_paso[indice]["valor"]
	_siguiente_paso()


func _al_hablar(id_personaje: String) -> void:
	sesion.hablar_con(id_personaje)
	_refrescar()


func _al_cancelar() -> void:
	_accion = ""
	_liberar_jugador()


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
