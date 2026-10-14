extends "res://tests/test_case.gd"
## Carnalita y magnesio (mud-engineer-reference.md §1.5–1.6).

const Base := preload("res://sim/lodos_base.gd")
const F := preload("res://sim/formulas.gd")


func _carnalita(cantidad: float):
	var lodo = Base.disperso_lignosulfonato()
	load("res://data/contaminantes/carnalita.tres").aplicar(lodo, cantidad)
	return lodo


func _producto(nombre: String) -> Resource:
	return load("res://data/productos/%s.tres" % nombre)


func test_firma_de_la_carnalita() -> void:
	var base = Base.disperso_lignosulfonato()
	var lodo = _carnalita(2.0)
	verificar(lodo.cl > base.cl + 2000.0, "disparan los cloruros (%.0f)" % lodo.cl)
	verificar(lodo.k > 500.0, "aporta potasio (%.0f)" % lodo.k)
	verificar(lodo.dureza_total_mg_l() > base.dureza_total_mg_l() + 300.0, "sube la dureza total (%.0f)" % lodo.dureza_total_mg_l())
	verificar(lodo.ca > base.ca, "y algo el calcio, por intercambio")
	verificar(lodo.ph() < base.ph() - 0.3, "baja el pH: el Mg se come el OH⁻ (%.2f)" % lodo.ph())
	verificar(lodo.pf() < base.pf(), "baja el Pf")
	verificar(lodo.mg_oh2 > 0.0, "ya precipita algo de Mg(OH)₂")
	verificar(lodo.pc() > base.pc() + 3.0, "espesa (PC %.1f → %.1f)" % [base.pc(), lodo.pc()])


func test_dureza_total_separa_magnesio_de_calcio() -> void:
	var lodo = _carnalita(2.0)
	verificar(lodo.dureza_total_mg_l() > 2.0 * lodo.dureza_calcio_mg_l(),
		"la dureza total es mucho más que la de calcio")
	verificar_cerca(lodo.magnesio_por_diferencia_mg_l(), lodo.mg, 0.01, "el magnesio sale por diferencia")


func test_soda_caustica_espesa_la_carnalita() -> void:
	# §1.5: la regla "si baja el pH, echa cáustica" acá empeora la viscosidad.
	var lodo = _carnalita(2.0)
	var pc_antes: float = lodo.pc()
	var mg_antes: float = lodo.mg
	_producto("soda_caustica").aplicar(lodo, 0.25)
	verificar(lodo.mg < mg_antes, "precipita magnesio")
	verificar(lodo.pc() > pc_antes + 2.0, "el lodo se espesa (PC %.1f → %.1f)" % [pc_antes, lodo.pc()])
	verificar(lodo.ph() < 10.0, "y el pH casi no sube: el Mg se come la soda (%.2f)" % lodo.ph())


func test_dureza_sigue_alta_despues_del_carbonato_de_sodio() -> void:
	# §1.6: el carbonato de sodio saca el calcio pero no el magnesio.
	var lodo = _carnalita(2.0)
	lodo.cal_exceso = 0.0
	_producto("carbonato_de_sodio").aplicar(lodo, F.dosis_por_ion("calcio_carbonato_de_sodio", lodo.ca - 40.0, lodo.fw()))
	verificar(lodo.ca < 60.0, "el calcio baja (%.0f)" % lodo.ca)
	verificar(lodo.dureza_total_mg_l() > 400.0, "pero la dureza total sigue alta (%.0f)" % lodo.dureza_total_mg_l())


func test_ph_11_saca_el_magnesio_de_una_contaminacion_leve() -> void:
	# §1.6: contaminación leve (agua salada dura): pH 11 precipita el Mg(OH)₂.
	var lodo = _carnalita(0.5)
	_producto("soda_caustica").aplicar(lodo, 0.75)
	verificar(lodo.ph() > 11.0, "pH sobre 11 (%.2f)" % lodo.ph())
	verificar(lodo.mg < 2.0, "queda casi sin magnesio disuelto (%.1f mg/l)" % lodo.mg)


func test_si_el_ph_baja_el_magnesio_vuelve() -> void:
	# §1.6: hay que MANTENER el pH, o el Mg(OH)₂ se redisuelve.
	var lodo = _carnalita(0.5)
	_producto("soda_caustica").aplicar(lodo, 0.75)
	var mg_alto: float = lodo.mg
	lodo.agregar_acido(60.0)
	verificar(lodo.mg > mg_alto + 20.0, "el magnesio vuelve al filtrado (%.1f → %.1f)" % [mg_alto, lodo.mg])
