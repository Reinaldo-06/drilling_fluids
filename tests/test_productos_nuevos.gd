extends "res://tests/test_case.gd"
## Productos que pedían los programas de CAIMÁN-3 y los sistemas del catálogo.
## Se prueban los sentidos de su efecto; las magnitudes son calibración (🧩).

const Base := preload("res://sim/lodos_base.gd")


func _producto(nombre: String) -> Resource:
	return load("res://data/productos/%s.tres" % nombre)


func test_almidon_baja_el_filtrado() -> void:
	var lodo = Base.disperso_lignosulfonato()
	var antes: float = lodo.filtrado_api()
	_producto("almidon").aplicar(lodo, 4.0)
	verificar(lodo.filtrado_api() < antes, "el filtrado baja (%.1f → %.1f)" % [antes, lodo.filtrado_api()])


func test_phpa_viscosifica_y_controla_filtrado() -> void:
	var lodo = Base.disperso_lignosulfonato()
	var vp: float = lodo.vp()
	var pc: float = lodo.pc()
	var filtrado: float = lodo.filtrado_api()
	_producto("phpa").aplicar(lodo, 1.0)
	verificar(lodo.vp() > vp, "sube la VP")
	verificar(lodo.pc() > pc, "sube el PC")
	verificar(lodo.filtrado_api() < filtrado, "baja un poco el filtrado")


func test_lignito_entra_acido_y_desflocula() -> void:
	var lodo = Base.disperso_lignosulfonato()
	var ph: float = lodo.ph()
	_producto("lignito").aplicar(lodo, 4.0)
	verificar(lodo.ph() < ph, "sin soda baja el pH (%.2f → %.2f)" % [ph, lodo.ph()])
	var floculado = Base.disperso_lignosulfonato()
	load("res://data/contaminantes/sal.tres").aplicar(floculado, 8.0)
	var pc: float = floculado.pc()
	_producto("lignito").aplicar(floculado, 4.0)
	_producto("soda_caustica").aplicar(floculado, 1.0)  # 1 saco de soda por cada 4
	verificar(floculado.pc() < pc, "con su soda, desflocula (PC %.1f → %.1f)" % [pc, floculado.pc()])


func test_carbonato_de_calcio_es_solido_inerte() -> void:
	var lodo = Base.disperso_lignosulfonato()
	var densidad: float = lodo.densidad()
	var solidos: float = lodo.solidos_pct()
	var filtrado: float = lodo.filtrado_api()
	var ph: float = lodo.ph()
	var ca: float = lodo.ca
	_producto("carbonato_de_calcio").aplicar(lodo, 30.0)
	verificar(lodo.densidad() > densidad, "suma peso")
	verificar(lodo.solidos_pct() > solidos, "suma sólidos")
	verificar(lodo.filtrado_api() < filtrado, "puentea: baja el filtrado")
	verificar_cerca(lodo.ph(), ph, 0.05, "no cambia el pH")
	verificar_cerca(lodo.ca, ca, 1.0, "no aporta calcio disuelto")


func test_nacl_satura_y_pesa_el_agua() -> void:
	var lodo = Base.disperso_lignosulfonato()
	var densidad_agua: float = lodo.densidad_agua()
	_producto("nacl").aplicar(lodo, 120.0)
	verificar(lodo.cl > 150000.0, "cerca de saturación (%.0f mg/l)" % lodo.cl)
	verificar(lodo.densidad_agua() > densidad_agua + 1.0, "el agua pesa más")


func test_amina_queda_en_el_lodo() -> void:
	var lodo = Base.disperso_lignosulfonato()
	_producto("amina").aplicar(lodo, 3.0)
	verificar_cerca(lodo.amina, 3.0, 0.0001, "3 lb/bbl de amina")


func test_todos_los_productos_de_los_sistemas_existen() -> void:
	for archivo in DirAccess.get_files_at("res://data/sistemas"):
		if not archivo.ends_with(".tres"):
			continue
		var sistema: Resource = load("res://data/sistemas/" + archivo)
		for propiedad in sistema.get_property_list():
			if propiedad["type"] != TYPE_DICTIONARY or not (propiedad["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			if propiedad["name"] != "aditivos":
				continue
			for id in sistema.get(propiedad["name"]):
				verificar(ResourceLoader.exists("res://data/productos/%s.tres" % id),
					"%s pide '%s', que no existe en data/productos/" % [archivo, id])
