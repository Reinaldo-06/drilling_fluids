extends "res://tests/test_case.gd"
## Cada contaminación tratada como dice el manual, con la dosis de sus fórmulas.
## Comprueba que el tratamiento correcto funciona y que las trampas se comportan
## como trampas (mud-engineer-reference.md §1, game-design-mechanics.md).

const Base := preload("res://sim/lodos_base.gd")
const F := preload("res://sim/formulas.gd")


func _contaminado(nombre: String, cantidad: float):
	var lodo = Base.disperso_lignosulfonato()
	load("res://data/contaminantes/%s.tres" % nombre).aplicar(lodo, cantidad)
	return lodo


func _producto(nombre: String) -> Resource:
	return load("res://data/productos/%s.tres" % nombre)


# §1.4 — yeso: precipitar el calcio con carbonato de sodio
func test_carbonato_de_sodio_trata_yeso() -> void:
	var lodo = Base.disperso_lignosulfonato()
	lodo.cal_exceso = 0.0
	load("res://data/contaminantes/yeso.tres").aplicar(lodo, 1.0)
	var objetivo := 120.0
	var dosis := F.dosis_por_ion("calcio_carbonato_de_sodio", lodo.ca - objetivo, lodo.fw())
	_producto("carbonato_de_sodio").aplicar(lodo, dosis)
	verificar_cerca(lodo.ca, objetivo, 15.0, "calcio vuelve al objetivo")
	verificar_cerca(lodo.floculacion(), 0.0, 0.01, "deja de estar floculado")


# Con cal en exceso, el carbonato de sodio se gasta primero en ella: la dosis
# calculada con el calcio no alcanza y además sube el pH. Hay que mirar el Pm.
func test_cal_en_exceso_se_come_el_carbonato_de_sodio() -> void:
	var lodo = _contaminado("yeso", 1.0)
	verificar(lodo.cal_exceso > 0.0, "queda cal en exceso del lodo base")
	var ca_antes: float = lodo.ca
	var dosis := F.dosis_por_ion("calcio_carbonato_de_sodio", lodo.ca - 120.0, lodo.fw())
	_producto("carbonato_de_sodio").aplicar(lodo, dosis)
	verificar(lodo.ca > 120.0 + 50.0, "el calcio no llega al objetivo (%.0f mg/l)" % lodo.ca)
	verificar(lodo.ca < ca_antes, "pero sí baja")


# §1.3 — cemento: la dosis del manual elimina justo la cal en exceso.
# Con 1 lb/bbl: parte de la cal se la come el tampón del lignosulfonato y el
# resto queda sin disolver, que es lo que mide el Pm.
func test_bicarbonato_trata_cemento() -> void:
	var lodo = _contaminado("cemento", 1.0)
	var pm_antes: float = lodo.pm()
	var ca_antes: float = lodo.ca
	var exceso := F.exceso_de_cal(lodo.pm(), lodo.pf(), lodo.fw())
	_producto("bicarbonato_de_sodio").aplicar(lodo, F.dosis_por_exceso_de_cal("bicarbonato_de_sodio", exceso))
	verificar_cerca(lodo.cal_exceso, 0.0, 0.01, "no queda cal en exceso")
	# Ca(OH)₂ + NaHCO₃ → CaCO₃ + NaOH: se va la cal sólida pero queda soda en solución,
	# así que el Pm baja menos que el aporte de la cal.
	verificar(lodo.pm() < pm_antes - 0.5, "el Pm baja (%.2f → %.2f)" % [pm_antes, lodo.pm()])
	verificar(lodo.ca <= ca_antes, "el calcio no sube")


# §1.3 — SAPP sobre cemento baja pH y Pm
func test_sapp_trata_cemento() -> void:
	var lodo = _contaminado("cemento", 0.5)
	var ph_antes: float = lodo.ph()
	var pm_antes: float = lodo.pm()
	var ca_antes: float = lodo.ca
	var exceso := F.exceso_de_cal(lodo.pm(), lodo.pf(), lodo.fw())
	_producto("sapp").aplicar(lodo, F.dosis_por_exceso_de_cal("sapp", exceso))
	verificar(lodo.ph() < ph_antes, "baja el pH")
	verificar(lodo.pm() < pm_antes, "baja el Pm")
	verificar(lodo.ca < ca_antes, "baja el calcio")


# §1.3 — trampa: carbonato de sodio sobre cemento sube la alcalinidad
func test_carbonato_de_sodio_sobre_cemento_es_trampa() -> void:
	var con_soda_ash = _contaminado("cemento", 0.5)
	var con_bicarbonato = _contaminado("cemento", 0.5)
	var mmol := 10.0  # misma cantidad de moles de cada producto
	_producto("carbonato_de_sodio").aplicar(con_soda_ash, mmol * 105.99 / 2853.0 * con_soda_ash.fw())
	_producto("bicarbonato_de_sodio").aplicar(con_bicarbonato, mmol * 84.01 / 2853.0 * con_bicarbonato.fw())
	verificar(con_soda_ash.pf() > con_bicarbonato.pf(), "el carbonato de sodio deja más alcalinidad")
	verificar(con_soda_ash.ph() >= con_bicarbonato.ph(), "y no baja el pH")


# §1.7 — bicarbonatos con pH < 10,3: cal
func test_cal_trata_bicarbonatos() -> void:
	var lodo = Base.disperso_lignosulfonato()
	lodo.cal_exceso = 0.0
	lodo.ca = 0.0
	lodo.agregar_ion("hco3", 7000.0)
	verificar(lodo.ph() < 10.3, "con pH bajo la regla del manual pide cal")
	verificar(lodo.floculacion() > 0.0, "el bicarbonato flocula")
	_producto("cal").aplicar(lodo, F.dosis_por_ion("bicarbonato_cal", lodo.hco3, lodo.fw()))
	verificar(lodo.hco3 < 30.0, "se fue el bicarbonato (%.0f mg/l)" % lodo.hco3)
	verificar(lodo.mf() / lodo.pf() < 1.2, "Mf ≈ Pf: ya no hay carbonatos (Pf %.2f, Mf %.2f)" % [lodo.pf(), lodo.mf()])
	verificar(lodo.ph() > 11.3, "pero la cal deja soda libre: el pH queda alto (%.1f)" % lodo.ph())
	verificar_cerca(lodo.floculacion(), 0.0, 0.01, "deja de flocular")


# §1.8 — H₂S: óxido de cinc
func test_oxido_de_cinc_trata_h2s() -> void:
	var lodo = _contaminado("h2s", 400.0)
	var dosis := F.dosis_por_ion("sulfuro_oxido_de_cinc", lodo.sulfuro, lodo.fw())
	verificar_cerca(dosis, 0.36, 0.05, "regla del manual: ~1 lb/bbl por cada 1.000 mg/l")
	_producto("oxido_de_cinc").aplicar(lodo, dosis)
	verificar(lodo.sulfuro < 10.0, "precipitan los sulfuros (%.0f mg/l)" % lodo.sulfuro)


# §5.2 — el desfloculante baja PC y geles, si va con su soda (1 saco por cada 4, SLB)
func test_lignosulfonato_desflocula() -> void:
	var lodo = _contaminado("sal", 8.0)
	var pc_antes: float = lodo.pc()
	verificar(lodo.floculacion() > 0.0, "la sal flocula")
	_producto("lignosulfonato").aplicar(lodo, 4.0)
	_producto("soda_caustica").aplicar(lodo, 1.0)
	verificar(lodo.ph() > 9.5, "con su soda el pH queda donde rinde (%.2f)" % lodo.ph())
	verificar(lodo.pc() < pc_antes, "baja el PC")


# §1.5 — trampa: lignosulfonato sin soda baja el pH y rinde poco
func test_lignosulfonato_sin_soda_rinde_poco() -> void:
	var con_soda = _contaminado("sal", 8.0)
	var sin_soda = _contaminado("sal", 8.0)
	var ph_antes: float = sin_soda.ph()
	_producto("lignosulfonato").aplicar(sin_soda, 4.0)
	_producto("lignosulfonato").aplicar(con_soda, 4.0)
	_producto("soda_caustica").aplicar(con_soda, 1.0)
	verificar(sin_soda.ph() < ph_antes - 0.3, "el lignosulfonato es ácido (%.2f → %.2f)" % [ph_antes, sin_soda.ph()])
	verificar(sin_soda.eficacia_lignosulfonato() < 0.7, "y bajo pH 9,5 pierde eficacia")
	verificar(con_soda.pc() < sin_soda.pc() - 1.0, "con soda desflocula más (PC %.1f vs %.1f)" % [con_soda.pc(), sin_soda.pc()])


# §1.5 — la dilución es la única forma económica de bajar cloruros
func test_agua_diluye_cloruros() -> void:
	var lodo = _contaminado("sal", 12.0)
	var cl_antes: float = lodo.cl
	var fw_antes: float = lodo.fw()
	_producto("agua").aplicar(lodo, 1.0)
	verificar_cerca(lodo.cl, cl_antes * fw_antes / (fw_antes + 1.0), 1.0, "cloruros diluidos")


# §2.1 — densificar con la dosis del manual llega al peso
func test_barita_llega_al_peso_objetivo() -> void:
	var lodo = Base.disperso_lignosulfonato()
	var w1: float = lodo.densidad()
	var w2 := w1 + 1.5
	_producto("barita").aplicar(lodo, F.barita_lb_por_bbl(w1, w2))
	verificar_cerca(lodo.densidad(), w2, 0.01, "densidad después de densificar")


# §2.2 — diluir con la dosis del manual llega al peso
func test_agua_llega_al_peso_objetivo() -> void:
	var lodo = Base.disperso_lignosulfonato()
	_producto("barita").aplicar(lodo, 150.0)
	var w1: float = lodo.densidad()
	var w2 := w1 - 0.5
	_producto("agua").aplicar(lodo, F.agua_dilucion_bbl(1.0, w1, w2))
	verificar_cerca(lodo.densidad(), w2, 0.02, "densidad después de diluir")


# Sacos para la mezcla del encuellador (ejemplo de §2.1: 1.548 sacos)
func test_sacos_de_barita() -> void:
	var barita := _producto("barita")
	verificar(ceili(barita.sacos(1000.0, F.barita_lb_por_bbl(14.0, 16.0))) == 1548, "sacos para 1.000 bbl de 14 a 16 ppg")
