extends "res://tests/test_case.gd"
## Amortiguación del pH: el tampón del lignosulfonato y la bentonita.
## Metas de calibración (simulation-logic.md §12.6; mud-programs.md, sistema 2):
## - lodo base en pH 10 con Pf y Mf plausibles para un lodo con lignosulfonato;
## - yeso, sal y H₂S bajan el pH a 8–9,5, no a 7;
## - 0,25–0,5 lb/bbl de soda llevan un lodo de pH 8,5 a 9,5–10,5;
## - el lignosulfonato pide 1 saco de soda por cada 4 (SLB).

const Base := preload("res://sim/lodos_base.gd")
const EstadoLodoScript := preload("res://sim/estado_lodo.gd")


func _producto(nombre: String) -> Resource:
	return load("res://data/productos/%s.tres" % nombre)


func _contaminado(nombre: String, cantidad: float):
	var lodo = Base.disperso_lignosulfonato()
	load("res://data/contaminantes/%s.tres" % nombre).aplicar(lodo, cantidad)
	return lodo


func test_lodo_base_tiene_alcalinidad_de_lodo_con_lignosulfonato() -> void:
	var lodo = Base.disperso_lignosulfonato()
	verificar_cerca(lodo.ph(), 10.0, 0.05, "pH")
	verificar(lodo.pf() > 0.5 and lodo.pf() < 2.0, "Pf plausible: %.2f" % lodo.pf())
	verificar(lodo.mf() > lodo.pf(), "Mf > Pf por el tampón orgánico")
	verificar(lodo.mf() < 5.0, "Mf < 5: sin problema de carbonatos (manual §1.7): %.2f" % lodo.mf())
	verificar(lodo.tampon_base > 0.0, "el tampón está cargado")


func test_contaminantes_acidos_bajan_el_ph_a_rango_de_campo() -> void:
	for caso in [["yeso", 1.0], ["sal", 12.0], ["h2s", 400.0]]:
		var lodo = _contaminado(caso[0], caso[1])
		verificar(lodo.ph() >= 8.0 and lodo.ph() <= 9.5,
			"%s: pH entre 8 y 9,5, no 7 (%.2f)" % [caso[0], lodo.ph()])


func test_soda_desde_ph_8_5_llega_a_rango_de_trabajo() -> void:
	for caso in [[0.25, 9.3, 9.8], [0.5, 10.2, 10.8]]:
		var lodo = Base.disperso_lignosulfonato()
		lodo.fijar_ph(8.5)
		_producto("soda_caustica").aplicar(lodo, caso[0])
		verificar(lodo.ph() >= caso[1] and lodo.ph() <= caso[2],
			"%.2f lb/bbl de soda desde pH 8,5: esperado %.1f–%.1f, obtenido %.2f" % [caso[0], caso[1], caso[2], lodo.ph()])


func test_poca_soda_no_dispara_el_ph() -> void:
	var lodo = Base.disperso_lignosulfonato()
	lodo.fijar_ph(8.5)
	_producto("soda_caustica").aplicar(lodo, 0.1)
	verificar(lodo.ph() < 9.2, "0,1 lb/bbl mueve el pH menos de 0,7 (%.2f)" % lodo.ph())


func test_sin_tampon_la_soda_si_dispara_el_ph() -> void:
	# Agua sola: sin tampón 0,1 lb/bbl de soda pasa de pH 11,5. Es lo que hacía el
	# modelo antes y por qué el tampón importa.
	var agua = EstadoLodoScript.new()
	_producto("soda_caustica").aplicar(agua, 0.1)
	verificar(agua.ph() > 11.5, "agua sola: %.2f" % agua.ph())


func test_lodo_nuevo_pide_un_saco_de_soda_por_cuatro_de_lignosulfonato() -> void:
	var lodo = EstadoLodoScript.new()
	lodo.agregar_bentonita(12.0)
	verificar(lodo.ph() > 8.5 and lodo.ph() < 9.5, "bentonita en agua: pH natural ~9 (%.2f)" % lodo.ph())
	lodo.agregar_aditivo("lignosulfonato", 2.0)
	verificar(lodo.ph() < 8.0, "el lignosulfonato es ácido (%.2f)" % lodo.ph())
	_producto("soda_caustica").aplicar(lodo, 0.5)
	verificar(lodo.ph() > 9.5 and lodo.ph() < 10.5, "con 1:4 queda en pH de trabajo (%.2f)" % lodo.ph())


func test_diluir_con_agua_casi_no_mueve_el_ph() -> void:
	var lodo = Base.disperso_lignosulfonato()
	lodo.agregar_agua(0.5)
	verificar_cerca(lodo.ph(), 10.0, 0.1, "el tampón amortigua la dilución")


func test_oxido_de_cinc_devuelve_la_alcalinidad_del_h2s() -> void:
	# ZnO + HS⁻ → ZnS + OH⁻ (manual §1.8)
	var lodo = _contaminado("h2s", 400.0)
	var ph_antes: float = lodo.ph()
	_producto("oxido_de_cinc").aplicar(lodo, 0.4)
	verificar(lodo.ph() > ph_antes + 0.3, "sube el pH al precipitar el sulfuro (%.2f → %.2f)" % [ph_antes, lodo.ph()])


func test_bicarbonato_baja_el_ph_con_pf_que_sube() -> void:
	# Manual §1.7: "↑Pf con pH constante" — el tampón sostiene el pH.
	var lodo = Base.disperso_lignosulfonato()
	var pf_antes: float = lodo.pf()
	lodo.agregar_ion("hco3", 3000.0)
	verificar(lodo.ph() > 9.3, "el pH apenas baja (%.2f)" % lodo.ph())
	verificar(lodo.mf() - lodo.pf() > 2.0, "se abre la brecha Pf–Mf")
	verificar(lodo.pf() > pf_antes - 0.3, "el Pf no cae (%.2f → %.2f)" % [pf_antes, lodo.pf()])


func test_alcalinidad_se_conserva_al_reequilibrar() -> void:
	var lodo = _contaminado("carbonatos", 4000.0)
	var copia = lodo.copiar()
	copia.equilibrar()
	verificar_cerca(copia.ph(), lodo.ph(), 0.001, "equilibrar dos veces no cambia nada")
	verificar_cerca(copia.mf(), lodo.mf(), 0.001, "ni el Mf")


func test_mezclar_dos_lodos() -> void:
	var limpio = Base.disperso_lignosulfonato()
	var salado = _contaminado("sal", 12.0)
	var cl_esperado: float = (limpio.cl * limpio.fw() + salado.cl * salado.fw()) / (limpio.fw() + salado.fw())
	var ph_salado: float = salado.ph()
	limpio.mezclar(salado, 1.0, 1.0)
	verificar_cerca(limpio.cl, cl_esperado, 1.0, "cloruros promediados por agua")
	verificar(limpio.ph() > ph_salado and limpio.ph() < 10.0, "pH entre los dos (%.2f)" % limpio.ph())
