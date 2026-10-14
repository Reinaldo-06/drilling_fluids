extends SceneTree
## Compone una captura del overworld sin ventana: copia del atlas cada casilla
## del TileMapLayer y dibuja encima a los personajes en su cuadro "quieto".
##
## Uso: godot --headless --path . --script res://tools/captura_overworld.gd
## Salidas: docs/img/overworld.png (mapa entero x2) y
##          docs/img/overworld_vista.png (lo que ve la cámara al empezar, x3).

const ESCENA := preload("res://game/overworld/overworld.tscn")
const Atlas := preload("res://game/overworld/atlas_tiles.gd")
const Recursos := preload("res://game/overworld/recursos.gd")
const Hoja := preload("res://game/overworld/hoja_personaje.gd")
const LADO := 16


func _initialize() -> void:
	var ow: Node2D = ESCENA.instantiate()
	root.add_child(ow)
	ow.construir()
	var mapa: TileMapLayer = ow.mapa
	var atlas := Recursos.cargar_imagen(Atlas.RUTA)
	atlas.convert(Image.FORMAT_RGBA8)
	var tam: Vector2i = mapa.tamano()
	var img := Image.create(tam.x * LADO, tam.y * LADO, false, Image.FORMAT_RGBA8)
	for celda in mapa.get_used_cells():
		var c: Vector2i = mapa.get_cell_atlas_coords(celda)
		img.blit_rect(atlas, Rect2i(c * LADO, Vector2i(LADO, LADO)), celda * LADO)
	# personajes ordenados por fila, como el y-sort del juego
	var lista: Array = ow.npcs.values()
	lista.append(ow.jugador)
	lista.sort_custom(func(a, b): return a.celda.y < b.celda.y)
	for p in lista:
		var hoja: Image = p.imagen_hoja
		hoja.convert(Image.FORMAT_RGBA8)
		var cuadro := Rect2i(0, Hoja.fila_de(p.direccion) * Hoja.ALTO_CUADRO, Hoja.ANCHO_CUADRO, Hoja.ALTO_CUADRO)
		img.blend_rect(hoja, cuadro, p.celda * LADO + Vector2i(0, LADO - Hoja.ALTO_CUADRO))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/img"))
	var vista_origen: Vector2i = (ow.jugador.celda * LADO + Vector2i(8, 8)) - Vector2i(120, 80)
	vista_origen = vista_origen.clamp(Vector2i.ZERO, img.get_size() - Vector2i(240, 160))
	var vista := img.get_region(Rect2i(vista_origen, Vector2i(240, 160)))
	vista.resize(240 * 3, 160 * 3, Image.INTERPOLATE_NEAREST)
	vista.save_png(ProjectSettings.globalize_path("res://docs/img/overworld_vista.png"))
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path("res://docs/img/overworld.png"))
	print("captura guardada en docs/img/overworld.png")
	ow.free()
	quit(0)
