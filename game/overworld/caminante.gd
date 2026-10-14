extends Node2D
## Personaje que camina por casillas en 4 direcciones (jugador y NPCs).
##
## La casilla lógica (`celda`) cambia al empezar el paso, así nadie más puede
## pisarla mientras tanto; la posición en pantalla se interpola durante
## DURACION_PASO. La animación usa la hoja del contrato (hoja_personaje.gd):
## en cada paso alterna paso A y paso B, y vuelve a "quieto" al llegar.

signal paso_terminado(celda: Vector2i)

const Hoja := preload("res://game/overworld/hoja_personaje.gd")
const Recursos := preload("res://game/overworld/recursos.gd")

const LADO := 16
const DURACION_PASO := 0.25

var id_personaje := ""
var celda := Vector2i.ZERO
var direccion := Vector2i.DOWN
var en_movimiento := false
var es_marcador := false
var imagen_hoja: Image
## Callable(celda: Vector2i) -> bool. Si no es válido, todo es transitable.
var puede_pisar: Callable

var sprite: Sprite2D
var _origen := Vector2.ZERO
var _destino := Vector2.ZERO
var _t := 0.0
var _pie := 0


func configurar(id: String) -> void:
	id_personaje = id
	name = id
	var hoja := Hoja.cargar(id)
	imagen_hoja = hoja["imagen"]
	es_marcador = hoja["marcador"]
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		sprite.centered = false
		sprite.position = Vector2(0, LADO - Hoja.ALTO_CUADRO)
		add_child(sprite)
	sprite.texture = ImageTexture.create_from_image(imagen_hoja)
	sprite.hframes = Hoja.COLUMNAS
	sprite.vframes = Hoja.FILAS
	if es_marcador:
		var etiqueta := Label.new()
		etiqueta.name = "Inicial"
		etiqueta.text = Hoja.inicial(id)
		etiqueta.add_theme_font_override("font", Recursos.fuente())
		etiqueta.add_theme_font_size_override("font_size", Recursos.TAMANO_FUENTE)
		etiqueta.add_theme_color_override("font_color", Color8(40, 36, 48))
		etiqueta.position = Vector2(5, -1)
		add_child(etiqueta)
	_actualizar_cuadro(0)


func colocar(c: Vector2i) -> void:
	celda = c
	en_movimiento = false
	position = Vector2(c * LADO)


func mirar(dir: Vector2i) -> void:
	direccion = dir
	_actualizar_cuadro(0)


## Mira hacia una casilla (por ejemplo, la del jugador que le habla).
func mirar_hacia(otra: Vector2i) -> void:
	var d := otra - celda
	if d == Vector2i.ZERO:
		return
	if absi(d.x) >= absi(d.y):
		mirar(Vector2i(signi(d.x), 0))
	else:
		mirar(Vector2i(0, signi(d.y)))


func celda_de_enfrente() -> Vector2i:
	return celda + direccion


## Gira hacia `dir` y empieza un paso si la casilla está libre.
func intentar_paso(dir: Vector2i) -> bool:
	if en_movimiento:
		return false
	mirar(dir)
	var destino := celda + dir
	if puede_pisar.is_valid() and not puede_pisar.call(destino):
		return false
	celda = destino
	en_movimiento = true
	_t = 0.0
	_origen = position
	_destino = Vector2(destino * LADO)
	return true


## Avanza la animación del paso. Devuelve true si el paso terminó ahora.
func avanzar(delta: float) -> bool:
	if not en_movimiento:
		return false
	_t += delta
	var k := minf(_t / DURACION_PASO, 1.0)
	position = _origen.lerp(_destino, k).round()
	if k < 1.0:
		_actualizar_cuadro(1 + _pie if k < 0.5 else 0)
		return false
	en_movimiento = false
	_pie = 1 - _pie
	_actualizar_cuadro(0)
	paso_terminado.emit(celda)
	return true


func _actualizar_cuadro(columna: int) -> void:
	if sprite != null:
		sprite.frame = Hoja.fila_de(direccion) * Hoja.COLUMNAS + columna
