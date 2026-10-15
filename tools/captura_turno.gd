extends SceneTree
## Captura real (necesita pantalla, p. ej. xvfb-run) del juego con el turno
## conectado: reloj y menú de la caseta, y el resultado del chequeo rápido.
##
## Uso: xvfb-run -a godot --path . --script res://tools/captura_turno.gd
## Salidas: docs/img/turno_menu.png y docs/img/turno_resultado.png (×3).

const ESCALA := 3


func _init() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ow: Node2D = main.overworld
	# unos pasos y a la caseta
	for i in 5:
		ow.caminado.emit(1)
	var celda: Vector2i = ow.mapa.estaciones["caseta_lodos"].celdas[0]
	ow.interactuar_con(celda)
	await _esperar(6)
	_guardar("res://docs/img/turno_menu.png")
	main.puente.menu.confirmar()
	await _esperar(90)   # que el texto termine de aparecer
	ow.dialogo._texto.visible_characters = -1
	await _esperar(3)
	_guardar("res://docs/img/turno_resultado.png")
	quit()


func _esperar(cuadros: int) -> void:
	for i in cuadros:
		await process_frame


func _guardar(ruta: String) -> void:
	var img := root.get_texture().get_image()
	img.resize(img.get_width() * ESCALA, img.get_height() * ESCALA, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(ruta))
	print("captura ", ruta, " ", img.get_size())
