extends "res://tests/test_case.gd"
## Coherencia interna del estado del lodo.

const Base := preload("res://sim/lodos_base.gd")
const EstadoLodoScript := preload("res://sim/estado_lodo.gd")
const F := preload("res://sim/formulas.gd")


func test_lodo_base_plausible() -> void:
	var lodo = Base.disperso_lignosulfonato()
	verificar_cerca(lodo.ph(), 10.0, 0.05, "pH")
	verificar_cerca(lodo.densidad(), 8.92, 0.05, "densidad")
	verificar(lodo.vp() > 8.0 and lodo.vp() < 20.0, "VP en rango de lignosulfonato: %.1f" % lodo.vp())
	verificar(lodo.filtrado_api() > 4.0 and lodo.filtrado_api() < 12.0, "filtrado: %.1f" % lodo.filtrado_api())
	verificar_cerca(lodo.floculacion(), 0.0, 0.0001, "el lodo base no está floculado")
	verificar(not F.vp_excede_limite(lodo.vp(), lodo.densidad()), "VP dentro del límite del manual")


func test_pm_es_coherente_con_formula_de_exceso_de_cal() -> void:
	var lodo = Base.disperso_lignosulfonato()
	lodo.agregar_cal(0.8)
	verificar_cerca(F.exceso_de_cal(lodo.pm(), lodo.pf(), lodo.fw()), lodo.cal_exceso, 0.0001,
		"la fórmula del manual devuelve la cal sin disolver del estado")


func test_relaciones_api_de_alcalinidad() -> void:
	var solo_oh = EstadoLodoScript.new()
	solo_oh.oh = 340.0
	verificar_cerca(solo_oh.pf(), solo_oh.mf(), 0.0001, "solo OH⁻: Pf = Mf")
	var solo_co3 = EstadoLodoScript.new()
	solo_co3.co3 = 1200.0
	verificar_cerca(solo_co3.mf(), 2.0 * solo_co3.pf(), 0.0001, "solo CO₃²⁻: Mf = 2·Pf")
	var solo_hco3 = EstadoLodoScript.new()
	solo_hco3.hco3 = 1220.0
	verificar_cerca(solo_hco3.pf(), 0.0, 0.0001, "solo HCO₃⁻: Pf = 0")
	verificar_cerca(solo_hco3.ph(), 8.3, 0.01, "solo HCO₃⁻: pH 8,3")


func test_cal_se_satura_cerca_de_ph_12_4() -> void:
	var lodo = Base.disperso_lignosulfonato()
	lodo.agregar_cal(5.0)
	verificar_cerca(lodo.ph(), 12.4, 0.05, "pH con cal saturada")
	verificar(lodo.cal_exceso > 4.0, "casi toda la cal queda sin disolver")


func test_soda_caustica_con_magnesio_espesa() -> void:
	# Trampa de la carnalita (mud-engineer-reference.md §1.5): la cáustica precipita Mg(OH)₂.
	var lodo = Base.disperso_lignosulfonato()
	lodo.agregar_ion("mg", 400.0)
	var pc_antes: float = lodo.pc()
	lodo.agregar_ion("oh", 200.0)
	verificar(lodo.mg_oh2 > 0.0, "precipita Mg(OH)₂")
	verificar(lodo.pc() > pc_antes, "el lodo se espesa en vez de mejorar")


func test_soda_caustica_en_bicarbonatos_solo_los_convierte() -> void:
	# Bucle de carbonatos (§1.7): la cáustica convierte HCO₃⁻ en CO₃²⁻ y el calcio
	# del sistema lo precipita; el carbonato no se va del lodo.
	var lodo = Base.disperso_lignosulfonato()
	lodo.cal_exceso = 0.0
	lodo.ca = 0.0
	lodo.agregar_ion("hco3", 3000.0)
	var carbono_antes: float = lodo.co3 / 60.0 + lodo.hco3 / 61.0
	lodo.agregar_ion("oh", 300.0)
	var carbono_despues: float = lodo.co3 / 60.0 + lodo.hco3 / 61.0
	verificar_cerca(carbono_despues, carbono_antes, 0.001, "el carbono total no cambia")
	verificar(lodo.ph() > 10.0, "el pH sube y el lodo parece arreglado")


func test_aire_baja_la_balanza_atmosferica() -> void:
	var lodo = Base.disperso_lignosulfonato()
	lodo.aire = 0.05
	verificar(lodo.densidad_balanza_atmosferica() < lodo.densidad(), "lee bajo con aire")


func test_copiar_es_independiente() -> void:
	var lodo = Base.disperso_lignosulfonato()
	var copia = lodo.copiar()
	copia.agregar_cal(1.0)
	verificar_cerca(lodo.cal_exceso, 0.2, 0.0001, "el original no cambia")
