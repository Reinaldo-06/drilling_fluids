extends CanvasLayer
## Menú de acciones de una estación: lista vertical, arriba/abajo mueven,
## interactuar elige, menú cancela. Las opciones sin pantalla todavía salen en
## gris y no se pueden elegir (el Hito 2 y el 3 traen sus pantallas).

signal elegido(accion: String)
signal cancelado

const Recursos := preload("res://game/overworld/recursos.gd")

const COLOR_FONDO := Color8(248, 248, 240)
const COLOR_BORDE := Color8(72, 104, 136)
const COLOR_TEXTO := Color8(56, 56, 64)
const COLOR_APAGADO := Color8(168, 168, 176)
const COLOR_FLECHA := Color8(208, 72, 56)
const ALTO_LINEA := 12
const ANCHO_MINIMO := 90

var abierto := false
## [{accion, nombre, habilitada}]
var opciones: Array = []
var seleccion := 0

var _panel: Panel
var _lineas: Array[Label] = []
var _cuadro_apertura := -1


func _ready() -> void:
	layer = 11
	_ocultar()


## Abre el menú con las opciones dadas: [{accion, nombre, habilitada}].
func mostrar(titulo: String, opciones_: Array) -> void:
	opciones = opciones_
	seleccion = _primera_habilitada()
	abierto = true
	_cuadro_apertura = Engine.get_process_frames()
	_dibujar(titulo)


func _primera_habilitada() -> int:
	for i in opciones.size():
		if opciones[i]["habilitada"]:
			return i
	return 0


func _dibujar(titulo: String) -> void:
	if _panel != null:
		_panel.queue_free()
	_lineas.clear()
	_panel = Panel.new()
	_panel.name = "Panel"
	var alto := (opciones.size() + 1) * ALTO_LINEA + 8
	var ancho := _ancho_para(titulo)
	_panel.size = Vector2(ancho, alto)
	_panel.position = Vector2(240 - ancho - 2, 158 - alto - 2)
	var e := StyleBoxFlat.new()
	e.bg_color = COLOR_FONDO
	e.border_color = COLOR_BORDE
	e.set_border_width_all(2)
	e.set_corner_radius_all(3)
	e.anti_aliasing = false
	_panel.add_theme_stylebox_override("panel", e)
	add_child(_panel)
	_linea(titulo, 0, COLOR_BORDE)
	for i in opciones.size():
		_lineas.append(_linea("", i + 1, COLOR_TEXTO))
	_refrescar()


## Ancho que necesita la fila más larga (con la flecha y el "(pronto)").
func _ancho_para(titulo: String) -> int:
	var fuente := Recursos.fuente()
	var mas_ancho := fuente.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, Recursos.TAMANO_FUENTE).x
	for o in opciones:
		mas_ancho = maxf(mas_ancho, fuente.get_string_size(texto_de_opcion(o, true),
			HORIZONTAL_ALIGNMENT_LEFT, -1, Recursos.TAMANO_FUENTE).x)
	return clampi(ceili(mas_ancho) + 20, ANCHO_MINIMO, 236)


func _linea(texto: String, fila: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", Recursos.fuente())
	l.add_theme_font_size_override("font_size", Recursos.TAMANO_FUENTE)
	l.add_theme_color_override("font_color", color)
	l.position = Vector2(8, 4 + fila * ALTO_LINEA)
	l.text = texto
	_panel.add_child(l)
	return l


## Texto de cada fila: flecha en la elegida, "(pronto)" en las apagadas.
static func texto_de_opcion(opcion: Dictionary, elegida: bool) -> String:
	var t: String = opcion["nombre"] if opcion["habilitada"] else "%s (pronto)" % opcion["nombre"]
	return ("> " if elegida else "  ") + t


func _refrescar() -> void:
	for i in opciones.size():
		_lineas[i].text = texto_de_opcion(opciones[i], i == seleccion)
		_lineas[i].add_theme_color_override("font_color",
			COLOR_FLECHA if i == seleccion and opciones[i]["habilitada"] \
			else (COLOR_TEXTO if opciones[i]["habilitada"] else COLOR_APAGADO))


func mover(delta: int) -> void:
	if opciones.is_empty():
		return
	seleccion = posmod(seleccion + delta, opciones.size())
	_refrescar()


## Elige la opción marcada. Las apagadas no hacen nada.
func confirmar() -> void:
	if not abierto or opciones.is_empty() or not opciones[seleccion]["habilitada"]:
		return
	var accion: String = opciones[seleccion]["accion"]
	_ocultar()
	elegido.emit(accion)


func cancelar() -> void:
	if not abierto:
		return
	_ocultar()
	cancelado.emit()


func _ocultar() -> void:
	abierto = false
	if _panel != null:
		_panel.visible = false


func _unhandled_input(evento: InputEvent) -> void:
	if not abierto or Engine.get_process_frames() == _cuadro_apertura:
		return
	if evento.is_action_pressed("mover_arriba"):
		get_viewport().set_input_as_handled()
		mover(-1)
	elif evento.is_action_pressed("mover_abajo"):
		get_viewport().set_input_as_handled()
		mover(1)
	elif evento.is_action_pressed("interactuar"):
		get_viewport().set_input_as_handled()
		confirmar()
	elif evento.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		cancelar()
