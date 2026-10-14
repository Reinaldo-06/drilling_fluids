extends "res://tests/test_case.gd"
## Overworld: mapa, estaciones, movimiento por casillas, personajes y diálogo.
## Corre sin ventana: instancia la escena en el árbol del ejecutor de pruebas.

const ESCENA := preload("res://game/overworld/overworld.tscn")
const Datos := preload("res://game/overworld/mapa_locacion.gd")
const Hoja := preload("res://game/overworld/hoja_personaje.gd")
const Npc := preload("res://game/overworld/npc.gd")
const Dialogo := preload("res://game/ui/dialogo.gd")
const Recursos := preload("res://game/overworld/recursos.gd")

## Estaciones de la tabla "El taladro como overworld" de
## docs/game-design-mechanics.md, más los tanques de rig-tank-system.md §2.
const ESTACIONES_DEL_DISENO := [
	"caseta_lodos", "tanque_succion", "tanque_proceso", "trampa_arena",
	"embudo_abajo", "embudo_arriba", "bodega_quimicos", "zarandas",
	"caja_de_llegada", "piso_perforacion", "cabina_mud_logger",
	"oficina_company_man", "reserva_1", "reserva_2", "fractanque_1",
	"fractanque_2", "tanque_pildora", "tanque_viaje",
	"valvula_reserva_1", "valvula_reserva_2", "valvula_fractanques",
	"valvula_pildora", "valvula_igualadora",
]


func _crear() -> Node2D:
	var arbol := Engine.get_main_loop() as SceneTree
	var ow: Node2D = ESCENA.instantiate()
	arbol.root.add_child(ow)
	ow.construir()
	return ow


func test_la_escena_se_instancia() -> void:
	var ow := _crear()
	verificar(ow.mapa != null, "el overworld no creó el mapa")
	verificar(ow.jugador != null, "el overworld no creó el jugador")
	verificar(ow.mapa.tamano() == Vector2i(Datos.ANCHO, Datos.ALTO), "tamaño del mapa")
	verificar(ow.mapa.get_used_cells().size() == Datos.ANCHO * Datos.ALTO, "faltan casillas pintadas")
	verificar(ow.mapa.tile_set != null and ow.mapa.tile_set.get_source_count() == 1, "TileSet sin atlas")
	ow.free()


func test_filas_del_mapa_bien_formadas() -> void:
	verificar(Datos.FILAS.size() == Datos.ALTO, "cantidad de filas")
	for y in Datos.FILAS.size():
		var fila: String = Datos.FILAS[y]
		verificar(fila.length() == Datos.ANCHO, "fila %d mide %d" % [y, fila.length()])
		for ch in fila:
			verificar(Datos.LEYENDA.has(ch), "letra '%s' sin leyenda en la fila %d" % [ch, y])


func test_existen_todas_las_estaciones_y_se_alcanzan() -> void:
	var ow := _crear()
	var alcanzables := _alcanzables(ow.mapa, Datos.INICIO_JUGADOR)
	for id in ESTACIONES_DEL_DISENO:
		var est = ow.mapa.estaciones.get(id)
		verificar(est != null, "falta la estación %s" % id)
		if est == null:
			continue
		verificar(not est.celdas.is_empty(), "la estación %s no ocupa casillas sólidas" % id)
		verificar(est.texto != "" and est.nombre != "", "la estación %s no tiene nombre o texto" % id)
		var se_llega := false
		for c in est.celdas:
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if alcanzables.has(c + d):
					se_llega = true
		verificar(se_llega, "no se puede llegar caminando a %s" % id)
	ow.free()


func test_estaciones_de_las_observaciones_existen() -> void:
	# data/observaciones/*.tres nombran estaciones o grupos ("tanques").
	var ow := _crear()
	var nombres := {}
	for id in ow.mapa.estaciones:
		nombres[id] = true
		nombres[ow.mapa.estaciones[id].grupo] = true
	for archivo in DirAccess.get_files_at("res://data/observaciones"):
		if not archivo.ends_with(".tres"):
			continue
		var obs = load("res://data/observaciones/" + archivo)
		for e in obs.estaciones:
			verificar(nombres.has(e), "%s nombra la estación '%s', que no está en el mapa" % [archivo, e])
	ow.free()


func test_el_jugador_no_atraviesa_paredes() -> void:
	var ow := _crear()
	var j = ow.jugador
	j.colocar(Datos.INICIO_JUGADOR)
	# arriba del inicio está la puerta de la caseta de lodos
	verificar(not j.intentar_paso(Vector2i.UP), "atravesó la puerta de la caseta")
	verificar(j.celda == Datos.INICIO_JUGADOR, "se movió contra una pared")
	verificar(j.direccion == Vector2i.UP, "al chocar debe quedar mirando la pared")
	# contra un tanque, desde la plancha
	j.colocar(Vector2i(18, 12))
	verificar(not j.intentar_paso(Vector2i.UP), "entró al tanque de succión")
	# fuera del mapa o contra la cerca
	j.colocar(Vector2i(2, 2))
	verificar(not j.intentar_paso(Vector2i.UP), "atravesó la cerca")
	verificar(not j.intentar_paso(Vector2i.LEFT), "atravesó la cerca")
	ow.free()


func test_el_jugador_no_atraviesa_personajes() -> void:
	var ow := _crear()
	var npc = ow.npcs["driller"]
	var j = ow.jugador
	var al_lado: Vector2i = npc.celda + Vector2i.DOWN
	verificar(ow.mapa.es_transitable(al_lado), "el puesto del driller no tiene casilla libre debajo")
	j.colocar(al_lado)
	verificar(not j.intentar_paso(Vector2i.UP), "atravesó al driller")
	ow.free()


func test_caminar_emite_casillas() -> void:
	var ow := _crear()
	var j = ow.jugador
	var pasos := [0]
	ow.caminado.connect(func(n: int): pasos[0] += n)
	j.colocar(Datos.INICIO_JUGADOR)
	verificar(j.intentar_paso(Vector2i.LEFT), "no pudo caminar sobre grava")
	verificar(j.celda == Datos.INICIO_JUGADOR + Vector2i.LEFT, "la casilla lógica cambia al empezar el paso")
	verificar(not j.intentar_paso(Vector2i.LEFT), "no se empieza otro paso a mitad de camino")
	j.avanzar(j.DURACION_PASO * 0.3)
	verificar(pasos[0] == 0, "emitió antes de llegar")
	verificar(j.sprite.frame % Hoja.COLUMNAS != 0, "a mitad de paso debe mostrar un cuadro de paso")
	j.avanzar(j.DURACION_PASO)
	verificar(pasos[0] == 1, "debe emitir caminado(1) al terminar el paso, emitió %d" % pasos[0])
	verificar(j.position == Vector2((Datos.INICIO_JUGADOR + Vector2i.LEFT) * 16), "posición final en la grilla")
	verificar(j.sprite.frame == Hoja.FILA_IZQUIERDA * Hoja.COLUMNAS, "al llegar vuelve al cuadro quieto")
	ow.free()


func test_interactuar_con_estacion_y_valvula() -> void:
	var ow := _crear()
	var ids: Array[String] = []
	var valvulas := []
	ow.interactuado.connect(func(id: String): ids.append(id))
	ow.valvula_cambiada.connect(func(id: String, abierta: bool): valvulas.append([id, abierta]))
	ow.interactuar_con(Vector2i(24, 16))  # puerta de la caseta
	verificar(ids == ["caseta_lodos"], "interactuar con la puerta: %s" % [ids])
	verificar(ow.dialogo.abierto, "debe mostrar el texto de la estación")
	verificar(ow.jugador.bloqueado, "con el diálogo abierto el jugador no camina")
	var antes: Vector2i = ow.mapa.get_cell_atlas_coords(Vector2i(17, 22))
	ow.interactuar_con(Vector2i(17, 22))
	verificar(valvulas == [["valvula_reserva_1", true]], "la válvula cerrada se abre: %s" % [valvulas])
	verificar(ow.mapa.get_cell_atlas_coords(Vector2i(17, 22)) != antes, "el tile de la válvula cambia")
	ow.interactuar_con(Vector2i(10, 2))  # grava: nada
	verificar(ids.size() == 2, "la grava no es estación")
	ow.free()


func test_contrato_de_sprites_con_marcador() -> void:
	var h := Hoja.cargar("personaje_que_no_existe")
	verificar(h["marcador"], "sin PNG debe usar marcador")
	var img: Image = h["imagen"]
	verificar(img.get_width() == 48 and img.get_height() == 128, "el marcador respeta la hoja 48x128")
	verificar(Hoja.fila_de(Vector2i.DOWN) == 0 and Hoja.fila_de(Vector2i.LEFT) == 1, "filas abajo/izquierda")
	verificar(Hoja.fila_de(Vector2i.RIGHT) == 2 and Hoja.fila_de(Vector2i.UP) == 3, "filas derecha/arriba")
	var npc := Npc.new()
	npc.cargar_datos("personaje_que_no_existe")
	verificar(npc.sprite.hframes == 3 and npc.sprite.vframes == 4, "Sprite2D con 3x4 cuadros")
	verificar(npc.has_node("Inicial"), "el marcador lleva la inicial")
	verificar(npc.lineas().size() > 0 and npc.lineas()[0] != "", "diálogo genérico de saludo")
	verificar(npc.lineas("situacion_rara") == npc.lineas(), "situación desconocida cae en saludo")
	npc.free()


func test_personajes_del_contrato_colocados() -> void:
	var ow := _crear()
	var ocupadas := {}
	for id in ["driller", "encuellador", "company_man", "mud_logger", "toolpusher", "cuadrillero"]:
		verificar(ow.npcs.has(id), "falta el personaje %s" % id)
		if not ow.npcs.has(id):
			continue
		var npc = ow.npcs[id]
		verificar(ow.mapa.es_transitable(npc.celda), "%s está sobre una casilla sólida" % id)
		verificar(not ocupadas.has(npc.celda), "%s comparte casilla" % id)
		ocupadas[npc.celda] = true
		# si el agente I ya dejó el PNG, la hoja debe ser la suya
		var hay_png := FileAccess.file_exists(ProjectSettings.globalize_path(Hoja.ruta(id)))
		verificar(npc.es_marcador != hay_png, "%s: marcador=%s con PNG=%s" % [id, npc.es_marcador, hay_png])
	# hablarle: mira al jugador y emite hablado_con
	var hablados: Array[String] = []
	ow.hablado_con.connect(func(id: String): hablados.append(id))
	var driller = ow.npcs["driller"]
	ow.jugador.colocar(driller.celda + Vector2i.DOWN)
	ow.interactuar_con(driller.celda)
	verificar(hablados == ["driller"], "hablado_con(driller)")
	verificar(driller.direccion == Vector2i.DOWN, "el driller se gira hacia el jugador")
	ow.free()


func test_dialogo_pagina_y_avanza() -> void:
	var fuente: Font = Recursos.fuente()
	verificar(fuente != ThemeDB.fallback_font, "no cargó la fuente pixel de assets/fuentes")
	var medida := fuente.get_string_size("Píldora ñ ¿?", HORIZONTAL_ALIGNMENT_LEFT, -1, Recursos.TAMANO_FUENTE)
	verificar(medida.x > 30 and medida.x < 80, "ancho del texto con la fuente pixel: %s" % medida.x)
	var d := Dialogo.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(d)
	var largo := "El lodo viene espeso de las zarandas y la caja de llegada huele raro. Conviene correr el Fann y las titulaciones antes de tratar con cualquier químico."
	var paginas := d.paginar([largo, "¿Listo?"])
	verificar(paginas.size() >= 3, "un texto largo ocupa varias páginas")
	for p in paginas:
		verificar(p.split("\n").size() <= 2, "máximo dos líneas por página: '%s'" % p)
	var cerrados := [0]
	d.cerrado.connect(func(): cerrados[0] += 1)
	d.mostrar(["Hola, ingeniero."], "Driller")
	verificar(d.abierto, "se abre")
	verificar(not d.pagina_completa(), "el texto aparece letra a letra")
	d.avanzar()
	verificar(d.pagina_completa(), "la tecla completa la página")
	d.avanzar()
	verificar(not d.abierto and cerrados[0] == 1, "la tecla cierra al final")
	d.free()


## Casillas alcanzables caminando desde `inicio` (búsqueda en anchura).
func _alcanzables(mapa, inicio: Vector2i) -> Dictionary:
	var vistos := {inicio: true}
	var cola: Array[Vector2i] = [inicio]
	while not cola.is_empty():
		var c: Vector2i = cola.pop_front()
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var v: Vector2i = c + d
			if not vistos.has(v) and mapa.es_transitable(v):
				vistos[v] = true
				cola.append(v)
	return vistos
