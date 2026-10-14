extends CanvasLayer
## Caja de diálogo estilo consola portátil: caja clara con borde, dos líneas
## por página, el texto aparece letra a letra y la tecla de interactuar
## completa la página o pasa a la siguiente. Al terminar emite `cerrado`.

signal cerrado

const Recursos := preload("res://game/overworld/recursos.gd")

const LETRAS_POR_SEGUNDO := 50.0
const LINEAS_POR_PAGINA := 2
const CAJA := Rect2(2, 114, 236, 44)
const MARGEN := Vector2(8, 7)
const COLOR_TEXTO := Color8(56, 56, 64)
const COLOR_SOMBRA := Color8(200, 200, 208)
const COLOR_FONDO := Color8(248, 248, 240)
const COLOR_BORDE := Color8(72, 104, 136)
const COLOR_BORDE_INT := Color8(136, 176, 200)

var abierto := false
var paginas: Array[String] = []
var pagina_actual := 0

var _caja: Panel
var _texto: Label
var _nombre_caja: Panel
var _nombre: Label
var _flecha: Label
var _visibles := 0.0
var _cuadro_apertura := -1
var _parpadeo := 0.0


func _ready() -> void:
	layer = 10
	_construir()
	_ocultar()


func _construir() -> void:
	if _caja != null:
		return
	var fuente := Recursos.fuente()
	_caja = Panel.new()
	_caja.name = "Caja"
	_caja.position = CAJA.position
	_caja.size = CAJA.size
	_caja.add_theme_stylebox_override("panel", _estilo())
	add_child(_caja)

	_texto = _etiqueta(fuente)
	_texto.name = "Texto"
	_texto.position = MARGEN
	_texto.size = Vector2(CAJA.size.x - 2 * MARGEN.x, CAJA.size.y - MARGEN.y)
	_texto.add_theme_constant_override("line_spacing", 2)
	_caja.add_child(_texto)

	_flecha = _etiqueta(fuente)
	_flecha.name = "Flecha"
	_flecha.text = "▼"
	_flecha.add_theme_color_override("font_color", Color8(208, 72, 56))
	_flecha.position = Vector2(CAJA.size.x - 13, CAJA.size.y - 13)
	_caja.add_child(_flecha)

	_nombre_caja = Panel.new()
	_nombre_caja.name = "NombreCaja"
	_nombre_caja.add_theme_stylebox_override("panel", _estilo())
	add_child(_nombre_caja)
	_nombre = _etiqueta(fuente)
	_nombre.name = "Nombre"
	_nombre.position = Vector2(5, 2)
	_nombre_caja.add_child(_nombre)


func _etiqueta(fuente: Font) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", fuente)
	l.add_theme_font_size_override("font_size", Recursos.TAMANO_FUENTE)
	l.add_theme_color_override("font_color", COLOR_TEXTO)
	l.add_theme_color_override("font_shadow_color", COLOR_SOMBRA)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


func _estilo() -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = COLOR_FONDO
	e.border_color = COLOR_BORDE
	e.set_border_width_all(2)
	e.set_corner_radius_all(3)
	e.anti_aliasing = false
	e.shadow_color = COLOR_BORDE_INT
	return e


## Muestra uno o varios textos. Cada texto se parte en páginas de dos líneas.
func mostrar(textos: Array, quien := "") -> void:
	_construir()
	paginas = paginar(textos)
	pagina_actual = 0
	abierto = true
	_cuadro_apertura = Engine.get_process_frames()
	_caja.visible = true
	_nombre_caja.visible = quien != ""
	if quien != "":
		_nombre.text = quien
		var ancho := Recursos.fuente().get_string_size(quien, HORIZONTAL_ALIGNMENT_LEFT, -1, Recursos.TAMANO_FUENTE).x
		_nombre_caja.position = Vector2(CAJA.position.x + 4, CAJA.position.y - 13)
		_nombre_caja.size = Vector2(ancho + 12, 15)
	_mostrar_pagina()


func _mostrar_pagina() -> void:
	_texto.text = paginas[pagina_actual]
	_visibles = 0.0
	_texto.visible_characters = 0
	_flecha.visible = false


func pagina_completa() -> bool:
	return _texto.visible_characters < 0 or _texto.visible_characters >= _texto.text.length()


## Lo que hace la tecla de interactuar: completar la página, pasar o cerrar.
func avanzar() -> void:
	if not abierto:
		return
	if not pagina_completa():
		_texto.visible_characters = -1
		return
	pagina_actual += 1
	if pagina_actual >= paginas.size():
		_ocultar()
		cerrado.emit()
	else:
		_mostrar_pagina()


func _ocultar() -> void:
	abierto = false
	if _caja != null:
		_caja.visible = false
		_nombre_caja.visible = false


func _process(delta: float) -> void:
	if not abierto:
		return
	if not pagina_completa():
		_visibles += delta * LETRAS_POR_SEGUNDO
		_texto.visible_characters = int(_visibles)
		_flecha.visible = false
	else:
		_parpadeo += delta
		_flecha.visible = fmod(_parpadeo, 0.8) < 0.5


func _unhandled_input(evento: InputEvent) -> void:
	if not abierto:
		return
	if Engine.get_process_frames() == _cuadro_apertura:
		return  # la misma pulsación que abrió la caja no la avanza
	if evento.is_action_pressed("interactuar") or evento.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		avanzar()


## Parte los textos en páginas de LINEAS_POR_PAGINA líneas que caben en la caja.
func paginar(textos: Array) -> Array[String]:
	var ancho := CAJA.size.x - 2 * MARGEN.x - 10  # deja sitio a la flecha
	var resultado: Array[String] = []
	for t in textos:
		var lineas := envolver(str(t), ancho)
		for i in range(0, lineas.size(), LINEAS_POR_PAGINA):
			resultado.append("\n".join(lineas.slice(i, i + LINEAS_POR_PAGINA)))
	if resultado.is_empty():
		resultado.append("")
	return resultado


static func envolver(texto: String, ancho: float) -> PackedStringArray:
	var fuente := Recursos.fuente()
	var lineas := PackedStringArray()
	var actual := ""
	for palabra in texto.split(" ", false):
		var prueba := palabra if actual == "" else actual + " " + palabra
		var w := fuente.get_string_size(prueba, HORIZONTAL_ALIGNMENT_LEFT, -1, Recursos.TAMANO_FUENTE).x
		if w <= ancho or actual == "":
			actual = prueba
		else:
			lineas.append(actual)
			actual = palabra
	if actual != "":
		lineas.append(actual)
	return lineas
