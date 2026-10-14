extends "res://tests/test_case.gd"
## Programa de lodos por sección (invariante 6) y datos de pozos y sistemas.
## Fuente: docs/mud-programs.md, "Pozo CAIMÁN-3" y "Formato del programa de lodos".

const Base := preload("res://sim/lodos_base.gd")
const Props := preload("res://sim/propiedades_lodo.gd")

const SECCIONES := ["superficial", "intermedia", "produccion"]


func _programa(nombre: String) -> Resource:
	return load("res://data/programas/caiman_3_%s.tres" % nombre)


## Lodo dentro de todos los rangos de la superficial de CAIMÁN-3.
func _spud_en_rango() -> Dictionary:
	return {"densidad": 8.8, "embudo": 40.0, "vp": 9.0, "pc": 20.0, "gel_10s": 8.0,
		"gel_10min": 15.0, "ph": 9.0, "ca": 80.0, "mbt": 20.0}


func test_caiman_3_superficial_completo() -> void:
	var p := _programa("superficial")
	verificar(p.pozo == "CAIMÁN-3" and p.seccion == "Superficial", "encabezado")
	verificar(p.diametro == "17½\"", "diámetro 17½\"")
	verificar(p.profundidad_desde == 0.0 and p.profundidad_hasta == 2500.0, "0–2.500 ft")
	verificar(p.sistema == "bentonitico", "sistema bentonítico")
	verificar(p.rangos["densidad"] == [8.6, 9.0], "densidad 8,6–9,0 ppg")
	# Propiedades del sistema 1 (mud-programs.md).
	verificar(p.rangos["embudo"] == [35.0, 45.0], "embudo 35–45 s")
	verificar(p.rangos["vp"] == [5.0, 12.0], "VP 5–12 cP")
	verificar(p.rangos["pc"] == [15.0, 30.0], "PC 15–30")
	verificar(p.rangos["ph"] == [8.5, 9.5], "pH 8,5–9,5")
	verificar(not p.rangos.has("filtrado"), "filtrado sin control")
	for producto in ["bentonita", "carbonato_de_sodio", "soda_caustica"]:
		verificar(p.puede_usar(producto), "aprueba %s" % producto)
		verificar(p.concentraciones.has(producto), "concentración de %s" % producto)
	verificar(p.advertencias.size() > 0, "advertencias")
	verificar(p.criterios_cambio_fluido != "", "criterios de cambio de fluido")
	verificar(p.objetivo != "", "objetivo")


func test_programas_consistentes() -> void:
	for nombre in SECCIONES:
		var p := _programa(nombre)
		verificar(ResourceLoader.exists("res://data/sistemas/%s.tres" % p.sistema),
			"%s: el sistema %s existe" % [nombre, p.sistema])
		for propiedad: String in p.rangos:
			verificar(Props.VALORES_POR_OMISION.has(propiedad), "%s: propiedad %s conocida" % [nombre, propiedad])
			var r: Array = p.rangos[propiedad]
			verificar(r.size() == 2 and r[0] <= r[1], "%s: rango de %s válido" % [nombre, propiedad])
		for producto in p.productos_aprobados:
			verificar(ResourceLoader.exists("res://data/productos/%s.tres" % producto),
				"%s: el producto aprobado %s existe" % [nombre, producto])
		# Cuando alguien cree uno de estos productos, esta prueba avisa para aprobarlo.
		for producto in p.productos_por_crear:
			verificar(not ResourceLoader.exists("res://data/productos/%s.tres" % producto),
				"%s: %s ya existe, pásalo a productos_aprobados" % [nombre, producto])
		for clave: String in p.explicaciones:
			verificar(clave.ends_with("_alto") or clave.ends_with("_bajo"), "%s: clave %s" % [nombre, clave])


func test_sistemas_del_catalogo() -> void:
	var ids := ["bentonitico", "disperso_lignosulfonato", "kcl_phpa", "salado_saturado",
		"calcico", "rdf", "amina_phpa"]
	for id in ids:
		var s = load("res://data/sistemas/%s.tres" % id)
		verificar(s.id == id, "%s: id" % id)
		verificar(s.nombre != "" and not s.aditivos.is_empty() and not s.rangos_tipicos.is_empty(),
			"%s: datos completos" % id)
		verificar(s.vulnerabilidades.size() == 6, "%s: fila de vulnerabilidades" % id)


func test_pozo_caiman_3() -> void:
	var pozo = load("res://data/pozos/caiman_3.tres")
	verificar(pozo.secciones.size() == 3, "tres secciones")
	for i in range(1, pozo.secciones.size()):
		verificar(pozo.secciones[i].profundidad_desde == pozo.secciones[i - 1].profundidad_hasta,
			"secciones contiguas")
	verificar(pozo.seccion_a(1200.0).sistema == "bentonitico", "a 1.200 ft: bentonítico")
	verificar(pozo.seccion_a(3200.0).sistema == "kcl_phpa", "a 3.200 ft: KCl/PHPA")
	verificar(pozo.seccion_a(9600.0).sistema == "rdf", "en el fondo: RDF")
	verificar(pozo.seccion_a(12000.0) == null, "bajo el fondo: nada")


func test_acepta_lodo_en_rango() -> void:
	var p := _programa("superficial")
	verificar(p.fuera_de_especificacion(_spud_en_rango()).is_empty(), "nada fuera de rango")
	verificar(p.dentro_de_especificacion(_spud_en_rango()), "dentro de especificación")


func test_detecta_lodo_fuera_de_rango() -> void:
	var p := _programa("superficial")
	var lodo := _spud_en_rango()
	lodo["densidad"] = 9.3
	lodo["pc"] = 10.0
	var fuera: Array = p.fuera_de_especificacion(lodo)
	verificar(fuera.size() == 2, "dos propiedades fuera (%d)" % fuera.size())
	var por_prop := {}
	for f in fuera:
		por_prop[f["propiedad"]] = f
	verificar(por_prop.has("densidad") and por_prop["densidad"]["sentido"] == "alto", "densidad alta")
	verificar(por_prop.has("pc") and por_prop["pc"]["sentido"] == "bajo", "PC bajo")
	var texto: String = por_prop["densidad"]["texto"]
	verificar("9,30 ppg" in texto and "8,60–9,00 ppg" in texto, "texto con valor y rango: %s" % texto)
	verificar(texto.length() > 80, "el texto explica el porqué")
	# La explicación propia de la sección reemplaza a la genérica.
	verificar("17½" in por_prop["pc"]["texto"], "explicación propia de la superficial")


## Con un estado real: densificar de más saca la densidad del programa por arriba.
func test_detecta_densidad_alta_en_estado_real() -> void:
	var p := _programa("superficial")
	var lodo = Base.disperso_lignosulfonato()
	load("res://data/productos/barita.tres").aplicar(lodo, 40.0)
	var props := []
	for f in p.fuera_de_especificacion(lodo):
		props.append(f["propiedad"])
		if f["propiedad"] == "densidad":
			verificar(f["sentido"] == "alto", "densidad por arriba")
	verificar("densidad" in props, "detecta la densidad")


func test_palanca_de_dificultad() -> void:
	var p := _programa("superficial")
	verificar(p.puede_usar("barita"), "la superficial permite densificar")
	var dificil: Resource = p.sin_producto("barita")
	verificar(not dificil.puede_usar("barita"), "sin barita en el programa no se puede usar")
	verificar(dificil.puede_usar("bentonita"), "el resto sigue aprobado")
	verificar(p.puede_usar("barita"), "el programa original no cambia")
	verificar(not _programa("produccion").puede_usar("barita"), "barita prohibida en el RDF")
	verificar(not _programa("intermedia").puede_usar("producto_inexistente"), "un producto que no existe no se puede usar")


func test_formato_de_numeros() -> void:
	var P := preload("res://sim/programa_seccion.gd")
	verificar(P._num(8.6, 1) == "8,6", "decimal con coma")
	verificar(P._num(15000.0, 0) == "15.000", "miles con punto")
	verificar(P._num(0.5, 2) == "0,50", "rellena decimales")


func test_densidad_programada_dentro_del_rango() -> void:
	# Decisión del autor: la densidad se sube por programa al profundizar.
	for nombre in SECCIONES:
		var p := _programa(nombre)
		verificar(not p.densidad_programada.is_empty(), "%s tiene programa de densidad" % nombre)
		var previa := 0.0
		for tramo in p.densidad_programada:
			var ppg := float(tramo[1])
			verificar(ppg >= p.rangos["densidad"][0] and ppg <= p.rangos["densidad"][1],
				"%s: %.1f ppg dentro del rango" % [nombre, ppg])
			verificar(ppg >= previa, "%s: la densidad no baja al profundizar" % nombre)
			previa = ppg
	var inter := _programa("intermedia")
	verificar_cerca(inter.densidad_en(6500.0), 10.0, 1e-9, "tramo de 6.000 ft")
	verificar_cerca(inter.densidad_en(7200.0), 10.5, 1e-9, "tramo de 7.000 ft")
