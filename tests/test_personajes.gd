extends "res://tests/test_case.gd"
## Personajes y diálogos como datos (data/personajes/, assets/personajes/).
## Diseño en docs/personajes.md; roles en simulation-logic.md §5.
##
## Regla que se verifica acá (invariante 1): ningún NPC identifica un
## contaminante químico. Pueden contar lo que ven o lo que saben de la
## operación; "cemento" solo se permite cuando el driller avisa que van a
## rotar cemento (situación cemento_por_perforar), que es información de
## operación y no un diagnóstico.

const PersonajeScript := preload("res://sim/personaje.gd")

const CARPETA := "res://data/personajes"
const CARPETA_SPRITES := "res://assets/personajes"
const IDS := ["jugador", "driller", "encuellador", "company_man", "mud_logger", "toolpusher", "cuadrillero"]

## Se buscan como fragmento ("carbonat" atrapa carbonato y bicarbonato).
const PROHIBIDAS := [
	"cemento", "yeso", "anhidrit", "carbonat", "h2s", "h₂s", "sulfh",
	"magnesio", "carnalit", "calcio",
]
## Se buscan como palabra entera, para no atrapar "salida" o "calma".
const PROHIBIDAS_PALABRA := ["sal", "sales", "salado", "salada", "salmuera", "cal"]
## Única situación donde "cemento" es información de operación.
const PERMITE_CEMENTO := "cemento_por_perforar"

## Valores representativos para medir el largo de una página con variables.
const CONTEXTO_EJEMPLO := {
	"profundidad": "12.345", "formacion": "lutita de Carbonera",
	"sidpp": "1.250", "peso_matada": "12,4",
}


func _personaje(id: String) -> Resource:
	return load("%s/%s.tres" % [CARPETA, id])


func _palabras(texto: String) -> PackedStringArray:
	var limpio := ""
	for c in texto.to_lower():
		limpio += c if c.to_upper() != c.to_lower() else " "
	return limpio.split(" ", false)


func test_cada_id_tiene_datos_y_hoja() -> void:
	for id in IDS:
		var ruta := "%s/%s.tres" % [CARPETA, id]
		verificar(ResourceLoader.exists(ruta), "%s: falta %s" % [id, ruta])
		var p := _personaje(id)
		if p == null:
			continue
		verificar(p.get_script() == PersonajeScript, "%s: no es un Personaje" % id)
		verificar(p.id == id, "%s: el id no coincide con el archivo" % id)
		verificar(not p.nombre.is_empty() and not p.rol.is_empty(), "%s: falta nombre o rol" % id)
		verificar(p.estacion in PersonajeScript.ESTACIONES, "%s: estación desconocida %s" % [id, p.estacion])
		verificar(p.hoja == "%s/%s.png" % [CARPETA_SPRITES, id], "%s: ruta de hoja" % id)


func test_hojas_miden_48_por_128_con_fondo_transparente() -> void:
	for id in IDS:
		var ruta := ProjectSettings.globalize_path("%s/%s.png" % [CARPETA_SPRITES, id])
		var img := Image.load_from_file(ruta)
		verificar(img != null, "%s: no se pudo cargar el PNG" % id)
		if img == null:
			continue
		verificar(img.get_width() == 48 and img.get_height() == 128,
			"%s: la hoja mide %dx%d, se esperaba 48x128" % [id, img.get_width(), img.get_height()])
		verificar(img.get_pixel(0, 0).a == 0.0, "%s: el fondo no es transparente" % id)
		# Los 12 cuadros tienen algo dibujado.
		for fila in 4:
			for col in 3:
				var region := img.get_region(Rect2i(col * 16, fila * 32, 16, 32))
				verificar(not region.is_invisible(), "%s: cuadro vacío fila %d col %d" % [id, fila, col])


func test_todos_tienen_saludo() -> void:
	for id in IDS:
		var p := _personaje(id)
		verificar(p.tiene("saludo") and not p.dialogos["saludo"].is_empty(), "%s: falta saludo" % id)


func test_situaciones_del_juego_estan_cubiertas() -> void:
	var esperadas := {
		"driller": ["inicio_turno", "aviso_transferencia", "falsa_alarma_pvt", "kick", "perdida", "cemento_por_perforar"],
		"encuellador": ["orden_mezcla", "mezcla_terminada", "perdida", "recortes_raros"],
		"mud_logger": ["gas_conexion", "gas_fondo_sube"],
		"company_man": ["fuera_de_especificacion", "costo_alto", "reporte_recibido"],
		"toolpusher": ["consejo"],
		"cuadrillero": ["recortes_raros"],
	}
	for id in esperadas:
		var p := _personaje(id)
		for s in esperadas[id]:
			verificar(p.tiene(s), "%s: falta la situación %s" % [id, s])


func test_lineas_sustituye_variables() -> void:
	var driller := _personaje("driller")
	var paginas: Array = driller.lineas("kick", {"sidpp": 450, "peso_matada": "11,2"})
	var todo := " ".join(paginas)
	verificar(todo.contains("450 psi"), "sustituye {sidpp}")
	verificar(todo.contains("11,2 ppg"), "sustituye {peso_matada}")
	verificar(not todo.contains("{"), "no quedan variables sin sustituir")
	var inicio := " ".join(driller.lineas("inicio_turno", {"profundidad": "3.200", "formacion": "arcillolita"}))
	verificar(inicio.contains("3.200 pies") and inicio.contains("arcillolita"), "sustituye profundidad y formación")
	# El diccionario guardado no cambia.
	verificar(String(driller.dialogos["kick"][1]).contains("{sidpp}"), "lineas() no modifica el dato")


func test_lineas_cae_en_saludo() -> void:
	for id in IDS:
		var p := _personaje(id)
		verificar(p.lineas("situacion_que_no_existe") == p.lineas("saludo"), "%s: no cae en saludo" % id)


func test_ninguna_pagina_excede_la_caja() -> void:
	for id in IDS:
		var p := _personaje(id)
		for situacion in p.dialogos:
			for pagina in p.lineas(situacion, CONTEXTO_EJEMPLO):
				var partes := PersonajeScript.partir_en_lineas(pagina)
				verificar(partes.size() <= PersonajeScript.LINEAS_POR_PAGINA,
					"%s/%s: página de %d líneas: %s" % [id, situacion, partes.size(), pagina])
				for linea in partes:
					verificar(linea.length() <= PersonajeScript.CARACTERES_POR_LINEA,
						"%s/%s: palabra más larga que la línea: %s" % [id, situacion, linea])


func test_ningun_dialogo_nombra_un_contaminante_quimico() -> void:
	for id in IDS:
		var p := _personaje(id)
		for situacion in p.dialogos:
			for pagina in p.dialogos[situacion]:
				var texto := String(pagina).to_lower()
				for palabra in PROHIBIDAS:
					if palabra == "cemento" and situacion == PERMITE_CEMENTO:
						continue
					verificar(not texto.contains(palabra),
						"%s/%s nombra '%s': %s" % [id, situacion, palabra, pagina])
				var palabras := _palabras(texto)
				for palabra in PROHIBIDAS_PALABRA:
					verificar(not palabra in palabras,
						"%s/%s nombra '%s': %s" % [id, situacion, palabra, pagina])


func test_la_prueba_de_contaminantes_detecta_una_falla() -> void:
	# Control: la misma búsqueda atrapa un diagnóstico prohibido.
	var p := PersonajeScript.new()
	p.dialogos = {"saludo": ["Inge, eso es cemento, échele bicarbonato."]}
	var texto := String(p.lineas("saludo")[0]).to_lower()
	verificar(texto.contains("cemento") and texto.contains("carbonat"), "la búsqueda por fragmento funciona")
	verificar("sal" in _palabras("Entró sal al lodo."), "la búsqueda por palabra funciona")
	verificar(not "sal" in _palabras("Salió lodo por la salida."), "no atrapa 'salida'")
