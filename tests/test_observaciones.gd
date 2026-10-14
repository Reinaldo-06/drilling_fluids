extends "res://tests/test_case.gd"
## Observación visual como datos (data/observaciones/). Referencia:
## game-design-mechanics.md, "Observación visual" y "Trampas que salen de la
## observación".
##
## Regla de diseño que se verifica acá: una observación dice que algo cambió,
## nunca qué contaminante químico es. Eso lo hacen las pruebas (invariante 1).

const EstadoLodoScript := preload("res://sim/estado_lodo.gd")
const ObservacionScript := preload("res://sim/observacion.gd")
const Lab := preload("res://sim/laboratorio.gd")
const Base := preload("res://sim/lodos_base.gd")

const CARPETA := "res://data/observaciones"
const ESTACIONES := ["tanques", "caja_de_llegada", "zarandas"]

## Palabras que el jugador no puede leer en una observación. Se buscan como
## fragmento (así "carbonat" atrapa carbonato, carbonatos, bicarbonato…).
## "sal" va aparte, como palabra entera, para no atrapar "salida" o "señal".
##
## Decisión sobre el olor a huevo podrido: el diseño lo define como emergencia
## de seguridad. Se permite describir el olor (es lo que se percibe) y dar la
## orden de seguridad ("gas tóxico", máscara, viento arriba), pero el texto no
## nombra la especie química: la regla se aplica igual a todas las
## observaciones, y la confirmación y la concentración salen del Garrett Gas
## Train. El protocolo se dispara con el campo alerta_seguridad, no con el texto.
const PROHIBIDAS := [
	"cemento", "yeso", "anhidrit", "carbonat", "h2s", "h₂s", "sulfh", "sulfur",
	"calcio", "magnesio", "clorur", "potasio",
]
const PROHIBIDAS_PALABRA := ["sal", "sales", "salado", "salada", "salino", "salmuera", "cal"]


## Estado falso para fijar la VA sin depender de la calibración del lodo.
class EstadoFalso extends RefCounted:
	var aire := 0.0
	var sulfuro := 0.0
	var _va := 20.0

	func va() -> float:
		return _va


func _obs(id: String) -> Resource:
	return load("%s/%s.tres" % [CARPETA, id])


func _todas() -> Array:
	var lista := []
	for archivo in DirAccess.get_files_at(CARPETA):
		if archivo.ends_with(".tres"):
			lista.append(load("%s/%s" % [CARPETA, archivo]))
	return lista


func _palabras(texto: String) -> PackedStringArray:
	var limpio := ""
	for c in texto.to_lower():
		limpio += c if c.to_upper() != c.to_lower() else " "
	return limpio.split(" ", false)


func test_estructura_de_los_datos() -> void:
	var todas := _todas()
	verificar(todas.size() >= 4, "hay al menos espuma, viscosidad, rebose y lodo ennegrecido")
	for o in todas:
		verificar(o.get_script() == ObservacionScript, "%s: no es una Observacion" % o.id)
		verificar(o.textos.size() == o.umbrales.size() + 1, "%s: un texto por nivel" % o.id)
		verificar(o.niveles.size() == o.textos.size(), "%s: un nombre por nivel" % o.id)
		for i in range(1, o.umbrales.size()):
			verificar(o.umbrales[i] > o.umbrales[i - 1], "%s: umbrales ascendentes" % o.id)
		verificar(not o.estaciones.is_empty(), "%s: se ve en alguna estación" % o.id)
		for e in o.estaciones:
			verificar(e in ESTACIONES, "%s: estación desconocida %s" % [o.id, e])
		verificar(o.nivel_normal >= 0 and o.nivel_normal < o.textos.size(), "%s: nivel normal válido" % o.id)


func test_ningun_texto_nombra_un_contaminante_quimico() -> void:
	for o in _todas():
		var visibles: Array = [o.nombre] + Array(o.textos)
		for texto: String in visibles:
			var bajo := texto.to_lower() + " "
			for fragmento in PROHIBIDAS:
				verificar(not fragmento in bajo, "%s nombra «%s»: %s" % [o.id, fragmento, texto])
			for palabra in _palabras(texto):
				verificar(not palabra in PROHIBIDAS_PALABRA, "%s nombra «%s»: %s" % [o.id, palabra, texto])


func test_viscosidad_a_ojo_en_cuatro_niveles() -> void:
	var o := _obs("viscosidad_a_ojo")
	var e := EstadoFalso.new()
	var casos := [[5.0, "fluido"], [18.0, "normal"], [35.0, "espeso"], [70.0, "muy_espeso"]]
	for caso in casos:
		e._va = caso[0]
		verificar(o.nombre_nivel(e) == caso[1], "VA %s → %s, obtenido %s" % [caso[0], caso[1], o.nombre_nivel(e)])
		verificar(o.evaluar(e) == o.textos[o.nivel(e)], "el texto corresponde al nivel")
		verificar(o.es_alarma(e) == (caso[1] != "normal"), "VA %s: alarma solo fuera de lo normal" % caso[0])
	verificar(o.visible_en("tanques") and o.visible_en("zarandas"), "se ve en tanques y zarandas")


func test_espuma_desde_el_aire_atrapado() -> void:
	var o := _obs("espuma")
	var lodo = Base.disperso_lignosulfonato()
	var casos := [[0.0, "sin_espuma"], [0.01, "burbujas"], [0.05, "espuma_abundante"]]
	for caso in casos:
		lodo.aire = caso[0]
		verificar(o.nombre_nivel(lodo) == caso[1], "aire %s → %s" % caso)
	verificar(o.visible_en("caja_de_llegada"), "se ve en la caja de llegada")


func test_rebose_de_zarandas_con_viscosidad_muy_alta() -> void:
	var o := _obs("rebose_zarandas")
	var e := EstadoFalso.new()
	e._va = 20.0
	verificar(not o.es_alarma(e), "lodo normal no rebosa")
	e._va = 80.0
	verificar(o.nombre_nivel(e) == "rebosando", "lodo muy viscoso rebosa")
	verificar(o.visible_en("zarandas") and not o.visible_en("tanques"), "solo se ve en las zarandas")


func test_lodo_ennegrecido_es_alerta_de_seguridad() -> void:
	var o := _obs("lodo_ennegrecido")
	var lodo = Base.disperso_lignosulfonato()
	verificar(o.nombre_nivel(lodo) == "normal", "lodo base sin olor")
	load("res://data/contaminantes/h2s.tres").aplicar(lodo, 400.0)
	verificar(o.nombre_nivel(lodo) == "ennegrecido", "con sulfuros se ennegrece")
	verificar(o.es_alarma(lodo) and o.alerta_seguridad, "dispara la alerta de seguridad")
	verificar("huevo podrido" in o.evaluar(lodo), "describe el olor")


## La idea central del juego: dos contaminantes químicos distintos se ven
## igual en los tanques, y solo las pruebas químicas los separan.
func test_misma_viscosidad_a_ojo_distinta_quimica() -> void:
	var o := _obs("viscosidad_a_ojo")
	var base = Base.disperso_lignosulfonato()
	var nivel_base: int = o.nivel(base)
	var yeso = _contaminar_hasta_cambiar(o, "yeso", 0.05)
	var carb = _contaminar_hasta_cambiar(o, "carbonatos", 50.0)
	if yeso == null or carb == null:
		verificar(false, "la contaminación fuerte no cambia la viscosidad a ojo: revisar umbrales o calibración")
		return
	verificar(o.nivel(yeso) == nivel_base + 1 and o.nivel(carb) == nivel_base + 1,
		"los dos suben un nivel de viscosidad a ojo")
	verificar(o.evaluar(yeso) == o.evaluar(carb), "el jugador ve exactamente lo mismo")

	var h := {"hechas": ["filtrado_api"]}
	var dureza := Lab.cargar("dureza")
	var alcal := Lab.cargar("pf_mf")
	var d_base: float = dureza.ejecutar(base, h)["dureza_total"]
	var d_yeso: float = dureza.ejecutar(yeso, h)["dureza_total"]
	var d_carb: float = dureza.ejecutar(carb, h)["dureza_total"]
	verificar(d_yeso > d_base + 200.0, "yeso: la dureza sube (%.0f → %.0f)" % [d_base, d_yeso])
	verificar(d_carb < d_base, "carbonatos: la dureza baja (%.0f → %.0f)" % [d_base, d_carb])
	var a_base: Dictionary = alcal.ejecutar(base, h)
	var a_yeso: Dictionary = alcal.ejecutar(yeso, h)
	var a_carb: Dictionary = alcal.ejecutar(carb, h)
	verificar(a_carb["mf"] > a_base["mf"] + 1.0, "carbonatos: el Mf se dispara")
	verificar(a_yeso["mf"] <= a_base["mf"], "yeso: el Mf no sube")


## Aplica el contaminante en pasos crecientes hasta que la observación cambia
## de nivel. Devuelve el lodo, o null si nunca cambia.
func _contaminar_hasta_cambiar(o: Resource, contaminante: String, inicio: float):
	var c: Resource = load("res://data/contaminantes/%s.tres" % contaminante)
	var nivel_base: int = o.nivel(Base.disperso_lignosulfonato())
	var cantidad := inicio
	for _i in 80:
		var lodo = Base.disperso_lignosulfonato()
		c.aplicar(lodo, cantidad)
		if o.nivel(lodo) != nivel_base:
			return lodo
		cantidad *= 1.2
	return null
