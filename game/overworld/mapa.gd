extends TileMapLayer
## Mapa de la locación. Construye el TileSet y las casillas a partir de
## `mapa_locacion.gd` y responde preguntas de la grilla: si una casilla es
## transitable y a qué estación pertenece.

const Datos := preload("res://game/overworld/mapa_locacion.gd")
const Atlas := preload("res://game/overworld/atlas_tiles.gd")
const Recursos := preload("res://game/overworld/recursos.gd")
const Estacion := preload("res://game/overworld/estacion.gd")

const N := 1
const E := 2
const S := 4
const O := 8

var _letras := {}  # Vector2i -> String
var _estacion_por_celda := {}  # Vector2i -> Estacion
var estaciones := {}  # id -> Estacion
var valvulas_abiertas := {}  # id -> bool


func _ready() -> void:
	if tile_set == null:
		construir()


func construir() -> void:
	tile_set = _crear_tile_set()
	clear()
	_letras.clear()
	for y in Datos.ALTO:
		var fila: String = Datos.FILAS[y]
		for x in Datos.ANCHO:
			_letras[Vector2i(x, y)] = fila[x]
	for celda in _letras:
		_pintar(celda)
	_crear_estaciones()


func tamano() -> Vector2i:
	return Vector2i(Datos.ANCHO, Datos.ALTO)


func letra(celda: Vector2i) -> String:
	return _letras.get(celda, "")


func es_solida(celda: Vector2i) -> bool:
	var l := letra(celda)
	if l == "":
		return true  # fuera del mapa
	return Datos.LEYENDA[l][1]


func es_transitable(celda: Vector2i) -> bool:
	return not es_solida(celda)


func estacion_en(celda: Vector2i) -> Estacion:
	return _estacion_por_celda.get(celda, null)


func ids_estaciones() -> PackedStringArray:
	return PackedStringArray(estaciones.keys())


## Primer puesto libre de la estación (o una casilla transitable vecina).
func puestos_de(id_estacion: String) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	var est: Estacion = estaciones.get(id_estacion)
	if est == null:
		return resultado
	for p in est.puestos:
		if es_transitable(p):
			resultado.append(p)
	for c in est.celdas:
		for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			var v: Vector2i = c + d
			if es_transitable(v) and not resultado.has(v):
				resultado.append(v)
	return resultado


func alternar_valvula(id_valvula: String) -> bool:
	var abierta: bool = not valvulas_abiertas.get(id_valvula, false)
	fijar_valvula(id_valvula, abierta)
	return abierta


func fijar_valvula(id_valvula: String, abierta: bool) -> void:
	valvulas_abiertas[id_valvula] = abierta
	var est: Estacion = estaciones.get(id_valvula)
	if est == null:
		return
	for c in est.celdas:
		if letra(c) == "o":
			_pintar(c)


# --- construcción ---------------------------------------------------------

func _crear_tile_set() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(Atlas.LADO, Atlas.LADO)
	var fuente := TileSetAtlasSource.new()
	fuente.texture = Recursos.cargar_textura(Atlas.RUTA)
	fuente.texture_region_size = Vector2i(Atlas.LADO, Atlas.LADO)
	if fuente.texture != null:
		var cuadros := fuente.texture.get_size() / Atlas.LADO
		for y in int(cuadros.y):
			for x in int(cuadros.x):
				fuente.create_tile(Vector2i(x, y))
	ts.add_source(fuente, 0)
	return ts


func _grupo(l: String) -> String:
	return Datos.GRUPOS_MASCARA.get(l, l)


func _mascara(celda: Vector2i) -> int:
	var g := _grupo(letra(celda))
	var m := 0
	if _grupo(letra(celda + Vector2i.UP)) == g:
		m |= N
	if _grupo(letra(celda + Vector2i.RIGHT)) == g:
		m |= E
	if _grupo(letra(celda + Vector2i.DOWN)) == g:
		m |= S
	if _grupo(letra(celda + Vector2i.LEFT)) == g:
		m |= O
	return m


func coordenada_atlas(celda: Vector2i) -> Vector2i:
	var l := letra(celda)
	var tipo: String = Datos.LEYENDA[l][0]
	if tipo.begins_with("m:"):
		return Vector2i(_mascara(celda), Atlas.FILAS_MASCARA[tipo.substr(2)])
	if tipo.begins_with("v:"):
		var opciones: Array = Datos.VARIANTES[tipo.substr(2)]
		var h := absi(celda.x * 73856093 ^ celda.y * 19349663) % opciones.size()
		return Atlas.SUELTOS[opciones[h]]
	if tipo == "valvula":
		var vertical := _grupo(letra(celda + Vector2i.UP)) == "tubo" or _grupo(letra(celda + Vector2i.DOWN)) == "tubo"
		var est: Estacion = _estacion_por_celda.get(celda)
		var abierta: bool = valvulas_abiertas.get(est.id, false) if est else false
		var nombre := "valvula_%s_%s" % ["v" if vertical else "h", "abierta" if abierta else "cerrada"]
		return Atlas.SUELTOS[nombre]
	return Atlas.SUELTOS[tipo]


func _pintar(celda: Vector2i) -> void:
	set_cell(celda, 0, coordenada_atlas(celda))


func _crear_estaciones() -> void:
	for hijo in get_children():
		hijo.queue_free()
	estaciones.clear()
	_estacion_por_celda.clear()
	for d in Datos.ESTACIONES:
		var est := Estacion.new()
		est.id = d["id"]
		est.nombre = d["nombre"]
		est.grupo = d["grupo"]
		est.texto = d["texto"]
		est.name = est.id
		for p in d["puestos"]:
			est.puestos.append(p)
		for r: Rect2i in d["rects"]:
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					var c := Vector2i(x, y)
					if es_solida(c):
						est.celdas.append(c)
						_estacion_por_celda[c] = est
		est.position = Vector2(est.celdas[0] * Atlas.LADO) if not est.celdas.is_empty() else Vector2.ZERO
		estaciones[est.id] = est
		add_child(est)
		if d.has("abierta"):
			valvulas_abiertas[est.id] = d["abierta"]
	for id in valvulas_abiertas:
		fijar_valvula(id, valvulas_abiertas[id])
