extends "res://game/overworld/caminante.gd"
## El jugador. Movimiento estilo consola portátil: un toque corto solo gira;
## mantener la dirección camina una casilla tras otra.

signal interaccion_pedida(celda_enfrente: Vector2i)
signal menu_pedido

## Tiempo que hay que mantener una dirección nueva para caminar (si no, solo gira).
const PAUSA_GIRO := 0.09

## Mientras está bloqueado (diálogo abierto) no camina ni interactúa.
var bloqueado := false
var _espera := 0.0
var _venia_caminando := false


func _process(delta: float) -> void:
	if en_movimiento:
		if not avanzar(delta):
			return
		_venia_caminando = true
	if bloqueado:
		_venia_caminando = false
		return
	var dir := leer_direccion()
	if dir == Vector2i.ZERO:
		_venia_caminando = false
		_espera = 0.0
		return
	if dir != direccion and not _venia_caminando:
		mirar(dir)
		_espera = PAUSA_GIRO
		return
	if _espera > 0.0:
		_espera -= delta
		if _espera > 0.0:
			return
	if not intentar_paso(dir):
		_venia_caminando = false


func leer_direccion() -> Vector2i:
	# La última dirección del eje vertical gana sobre la horizontal, como en
	# los juegos de grilla: nunca se camina en diagonal.
	if Input.is_action_pressed("mover_arriba"):
		return Vector2i.UP
	if Input.is_action_pressed("mover_abajo"):
		return Vector2i.DOWN
	if Input.is_action_pressed("mover_izquierda"):
		return Vector2i.LEFT
	if Input.is_action_pressed("mover_derecha"):
		return Vector2i.RIGHT
	return Vector2i.ZERO


func _unhandled_input(evento: InputEvent) -> void:
	if bloqueado or en_movimiento:
		return
	if evento.is_action_pressed("interactuar"):
		get_viewport().set_input_as_handled()
		interaccion_pedida.emit(celda_de_enfrente())
	elif evento.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		menu_pedido.emit()
