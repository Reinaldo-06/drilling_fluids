extends Node2D
## Overworld: la locación del taladro vista desde arriba.
##
## Arma el mapa, el jugador, los personajes y la caja de diálogo, y avisa
## hacia afuera con señales. No sabe nada del reloj del turno ni de la
## simulación: quien integre conecta las señales.
##
## Señales:
## - caminado(casillas): el jugador terminó de caminar `casillas` casillas
##   (hoy se emite 1 por paso). El gestor de turno lo convierte en minutos.
## - interactuado(id_estacion): el jugador interactuó con una estación
##   (ids en mapa_locacion.gd → ESTACIONES).
## - hablado_con(id_personaje): el jugador le habló a un personaje.
## - valvula_cambiada(id_valvula, abierta): el jugador movió una válvula.
## - menu_pedido: el jugador apretó la tecla de menú.

signal caminado(casillas: int)
signal interactuado(id_estacion: String)
signal hablado_con(id_personaje: String)
signal valvula_cambiada(id_valvula: String, abierta: bool)
signal menu_pedido

const Datos := preload("res://game/overworld/mapa_locacion.gd")
const Mapa := preload("res://game/overworld/mapa.gd")
const Jugador := preload("res://game/overworld/jugador.gd")
const Npc := preload("res://game/overworld/npc.gd")
const Dialogo := preload("res://game/ui/dialogo.gd")
const Estacion := preload("res://game/overworld/estacion.gd")

const LADO := 16

## Si es true, al interactuar con una estación se muestra su texto. La
## integración puede apagarlo y abrir su propia pantalla.
@export var mostrar_texto_estaciones := true

var mapa: TileMapLayer
var jugador: Node2D
var dialogo: CanvasLayer
var personajes: Node2D
var npcs := {}  # id -> Npc
var camara: Camera2D


func _ready() -> void:
	construir()


## Arma todo. Idempotente: las pruebas lo llaman directamente porque en el
## ejecutor `--script` los nodos agregados al árbol no reciben `_ready`.
func construir() -> void:
	if mapa != null:
		return
	mapa = Mapa.new()
	mapa.name = "Mapa"
	add_child(mapa)
	mapa.construir()

	personajes = Node2D.new()
	personajes.name = "Personajes"
	personajes.y_sort_enabled = true
	add_child(personajes)

	jugador = Jugador.new()
	jugador.configurar("jugador")
	jugador.puede_pisar = puede_pisar
	jugador.colocar(Datos.INICIO_JUGADOR)
	jugador.mirar(Vector2i.UP)
	personajes.add_child(jugador)
	jugador.paso_terminado.connect(_al_terminar_paso)
	jugador.interaccion_pedida.connect(interactuar_con)
	jugador.menu_pedido.connect(func(): menu_pedido.emit())

	camara = Camera2D.new()
	camara.name = "Camara"
	camara.offset = Vector2(LADO / 2.0, LADO / 2.0)
	camara.limit_left = 0
	camara.limit_top = 0
	camara.limit_right = Datos.ANCHO * LADO
	camara.limit_bottom = Datos.ALTO * LADO
	jugador.add_child(camara)  # habilitada: es la cámara activa del viewport

	_colocar_personajes()

	dialogo = Dialogo.new()
	dialogo.name = "Dialogo"
	add_child(dialogo)
	dialogo.cerrado.connect(_al_cerrar_dialogo)


func puede_pisar(celda: Vector2i) -> bool:
	return mapa.es_transitable(celda) and npc_en(celda) == null


func npc_en(celda: Vector2i) -> Node2D:
	for id in npcs:
		if npcs[id].celda == celda:
			return npcs[id]
	return null


## Lo que pasa al apretar interactuar mirando `celda`.
func interactuar_con(celda: Vector2i) -> void:
	var npc := npc_en(celda)
	if npc != null:
		npc.mirar_hacia(jugador.celda)
		hablado_con.emit(npc.id_personaje)
		_abrir_dialogo(npc.lineas(), npc.titulo())
		return
	var est: Estacion = mapa.estacion_en(celda)
	if est == null:
		return
	var texto := est.texto
	if est.es_valvula():
		var abierta: bool = mapa.alternar_valvula(est.id)
		valvula_cambiada.emit(est.id, abierta)
		texto = "%s %s" % [est.texto, "Ahora está ABIERTA." if abierta else "Ahora está CERRADA."]
	interactuado.emit(est.id)
	if mostrar_texto_estaciones or est.es_valvula():
		_abrir_dialogo([texto], est.nombre)


func _abrir_dialogo(textos: Array, quien: String) -> void:
	jugador.bloqueado = true
	dialogo.mostrar(textos, quien)


func _al_cerrar_dialogo() -> void:
	# diferido: la misma pulsación que cerró la caja no debe volver a abrirla
	jugador.set_deferred("bloqueado", false)
	for id in npcs:
		npcs[id].mirar(npcs[id].direccion_reposo)


func _al_terminar_paso(_celda: Vector2i) -> void:
	caminado.emit(1)


func _colocar_personajes() -> void:
	for id in Datos.PERSONAJES:
		var npc := Npc.new()
		npc.cargar_datos(id)
		var id_estacion: String = Datos.PERSONAJES[id]
		var de_datos: String = Datos.ALIAS_ESTACION.get(npc.estacion, npc.estacion)
		if de_datos != "" and mapa.estaciones.has(de_datos):
			id_estacion = de_datos
		var puesto := _puesto_libre(id_estacion)
		npc.colocar(puesto)
		# mira de costado hacia su estación si la tiene al lado (el driller a
		# su consola); si no, hacia abajo, de cara a quien llega
		var est: Estacion = mapa.estaciones.get(id_estacion)
		npc.direccion_reposo = Vector2i.DOWN
		if est != null:
			for d in [Vector2i.LEFT, Vector2i.RIGHT]:
				if est.celdas.has(puesto + d):
					npc.direccion_reposo = d
					break
		npc.mirar(npc.direccion_reposo)
		npc.estacion = id_estacion
		npcs[id] = npc
		personajes.add_child(npc)


func _puesto_libre(id_estacion: String) -> Vector2i:
	for p in mapa.puestos_de(id_estacion):
		if npc_en(p) == null and p != Datos.INICIO_JUGADOR:
			return p
	# último recurso: cualquier casilla libre cerca del inicio
	for r in range(1, 10):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var c := Datos.INICIO_JUGADOR + Vector2i(x, y)
				if puede_pisar(c) and c != Datos.INICIO_JUGADOR:
					return c
	return Datos.INICIO_JUGADOR
