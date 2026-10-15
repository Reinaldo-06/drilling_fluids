extends CanvasLayer
## Reloj del turno siempre visible: hora, minutos que quedan y dónde está el
## jugador. Solo muestra lo que le dice la sesión (sim/sesion_turno.gd).

const Recursos := preload("res://game/overworld/recursos.gd")

const COLOR_FONDO := Color8(248, 248, 240)
const COLOR_BORDE := Color8(72, 104, 136)
const COLOR_TEXTO := Color8(56, 56, 64)
const COLOR_ALERTA := Color8(184, 56, 40)
## Debajo de este tiempo el reloj se pone rojo.
const MINUTOS_ALERTA := 60.0

var _panel: Panel
var _texto: Label


func _ready() -> void:
	layer = 5
	_construir()


func _construir() -> void:
	if _panel != null:
		return
	_panel = Panel.new()
	_panel.name = "Reloj"
	_panel.position = Vector2(2, 2)
	_panel.size = Vector2(112, 15)
	var e := StyleBoxFlat.new()
	e.bg_color = COLOR_FONDO
	e.border_color = COLOR_BORDE
	e.set_border_width_all(1)
	e.anti_aliasing = false
	_panel.add_theme_stylebox_override("panel", e)
	add_child(_panel)
	_texto = Label.new()
	_texto.add_theme_font_override("font", Recursos.fuente())
	_texto.add_theme_font_size_override("font_size", Recursos.TAMANO_FUENTE)
	_texto.add_theme_color_override("font_color", COLOR_TEXTO)
	_texto.position = Vector2(4, 1)
	_panel.add_child(_texto)


## Texto del reloj para un estado de la sesión. Estático: se prueba sin escena.
static func texto_de(estado: Dictionary) -> String:
	if estado["terminado"]:
		return "Día %d  %s  FIN DEL TURNO" % [estado["dia"], estado["hora"]]
	return "Día %d  %s  (%d min)" % [estado["dia"], estado["hora"], ceili(estado["minutos_restantes"])]


func actualizar(estado: Dictionary) -> void:
	_construir()
	_texto.text = texto_de(estado)
	var alerta: bool = estado["terminado"] or estado["minutos_restantes"] <= MINUTOS_ALERTA
	_texto.add_theme_color_override("font_color", COLOR_ALERTA if alerta else COLOR_TEXTO)
	_panel.size.x = Recursos.fuente().get_string_size(_texto.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		Recursos.TAMANO_FUENTE).x + 10
