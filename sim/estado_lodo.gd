class_name EstadoLodo
extends RefCounted
## Estado del lodo de un tanque: guarda la COMPOSICIÓN y deriva las propiedades.
##
## Diseño en docs/simulation-logic.md §12. Puntos clave:
## - Nada de PV, YP o filtrado guardado: se calculan al pedirlos.
## - La floculación se deriva de la química del agua y de los desfloculantes,
##   así todo contaminante químico produce síntomas físicos parecidos y solo
##   la química los distingue (invariante 1).
## - Alcalinidades con las relaciones API entre Pf/Mf y OH⁻, CO₃²⁻, HCO₃⁻.
## - Las reacciones son las del manual (mud-engineer-reference.md §1).
## Las constantes de las propiedades físicas son de calibración (🧩) y se
## ajustan jugando; lo que no se puede romper son los sentidos de la Tabla 4.

const F := preload("res://sim/formulas.gd")

const MG_POR_MEQ_OH := 17.0
const MG_POR_MMOL_CO3 := 60.0
const MG_POR_MMOL_HCO3 := 61.0
const MG_POR_MMOL_CA := 40.08
const MG_POR_MMOL_MG := 24.31
## mmol de Ca(OH)₂ por litro de lodo en 1 lb/bbl (453,6 g / 159 l / 74,09 g/mol).
const MMOL_CAL_POR_LB_BBL := 38.51
## OH⁻ con cal saturada (pH ≈ 12,4). Por encima la cal queda sin disolver.
const OH_MAX_CAL_MG_L := 425.0
## Aumento de densidad del agua por mg/l de cloruro (agua saturada ≈ 10 ppg).
const PPG_POR_MG_L_CL := 8.83e-6
const PKA2_CARBONATO := 10.33

# --- Fases (fracción del volumen de lodo) ---
var frac_barita := 0.0
var frac_lgs := 0.0          ## sólidos de baja gravedad: bentonita + perforados
var frac_aceite := 0.0
var aire := 0.0              ## aire atrapado; solo afecta la balanza atmosférica

# --- Productos activos (lb/bbl) ---
var bentonita := 0.0
var lignosulfonato := 0.0
var pac := 0.0
var xc := 0.0
var arcilla_activa := 0.0    ## arcilla perforada reactiva (suma al MBT)
## Sólidos alcalinos sin disolver (cal, finos de cemento), en lb/bbl de Ca(OH)₂.
## Solo reaccionan con ácidos y bicarbonatos; es lo que separa Pm de Pf·Fw.
var cal_exceso := 0.0

# --- Química del filtrado (mg/l) ---
var oh := 0.0
var co3 := 0.0
var hco3 := 0.0
var ca := 0.0
var mg := 0.0
var na := 0.0
var k := 0.0
var cl := 0.0
var so4 := 0.0
var sulfuro := 0.0
var mg_oh2 := 0.0            ## Mg(OH)₂ precipitado: gel que espesa (carnalita)
## Alcalinidad de sales orgánicas (lignosulfonato, lignito) en ml de ácido.
var alc_org_pf := 0.0
var alc_org_mf := 0.0


# ======================= Fases y densidad =======================

## Fracción de agua (lo que da la retorta como Fw).
func fw() -> float:
	return 1.0 - frac_barita - frac_lgs - frac_aceite


func densidad_agua() -> float:
	return F.DENSIDAD_AGUA_PPG + PPG_POR_MG_L_CL * cl


func densidad() -> float:
	return fw() * densidad_agua() + frac_barita * F.DENSIDAD_BARITA_PPG \
		+ frac_lgs * F.DENSIDAD_LGS_PPG + frac_aceite * 7.0


## Lo que lee la balanza no presurizada: el aire baja la lectura.
func densidad_balanza_atmosferica() -> float:
	return densidad() * (1.0 - aire)


func solidos_pct() -> float:
	return 100.0 * (frac_barita + frac_lgs)


func lgs_pct() -> float:
	return 100.0 * frac_lgs


func mbt() -> float:
	return bentonita + arcilla_activa


# ======================= Química =======================

func pf() -> float:
	return oh / 340.0 + co3 / 1200.0 + alc_org_pf


func mf() -> float:
	return oh / 340.0 + co3 / 600.0 + hco3 / 1220.0 + alc_org_mf


## Pm = Pf·Fw + cal sin disolver; es la inversa de Formulas.exceso_de_cal.
func pm() -> float:
	return pf() * fw() + cal_exceso / 0.26


func ph() -> float:
	if hco3 > 0.5:
		if co3 <= 0.0:
			return 8.3
		var razon := (co3 / MG_POR_MMOL_CO3) / (hco3 / MG_POR_MMOL_HCO3)
		return clampf(PKA2_CARBONATO + _log10(razon), 6.5, PKA2_CARBONATO)
	var p := 7.0
	if oh > 0.0:
		p = 14.0 + _log10(oh / 17000.0)
	if co3 > 0.0:
		# Hidrólisis del carbonato: OH⁻ ≈ √(Kb·C), Kb = 10^-3,67.
		p = maxf(p, 14.0 + 0.5 * _log10(pow(10.0, -3.67) * co3 / 60000.0))
	if pf() > 0.0:
		p = maxf(p, 8.3)  # Pf > 0 significa pH sobre el punto de la fenolftaleína
	return p


# ======================= Propiedades físicas derivadas =======================

## 0 = disperso, 1 = totalmente floculado.
func floculacion() -> float:
	var insultos := maxf(0.0, ca - 120.0) / 400.0 \
		+ mg / 200.0 \
		+ maxf(0.0, cl - 3000.0) / 15000.0 \
		+ maxf(0.0, mf() - 3.0) / 4.0 \
		+ sulfuro / 200.0
	# MBT bajo → poco efecto de la contaminación química (manual 4C.1).
	var reactividad := clampf(mbt() / 25.0, 0.2, 1.5)
	return clampf(insultos * reactividad - 0.08 * lignosulfonato, 0.0, 1.0)


func vp() -> float:
	return 2.0 + 2.5 * lgs_pct() + 0.6 * 100.0 * frac_barita + 3.0 * xc + 1.5 * pac


func pc() -> float:
	return 0.8 * bentonita + 4.0 * xc + 25.0 * floculacion() + mg_oh2 / 10.0


func lectura_600() -> float:
	return 2.0 * vp() + pc()


func lectura_300() -> float:
	return vp() + pc()


func va() -> float:
	return F.va(lectura_600())


func gel_10s() -> float:
	return 0.25 * bentonita + 0.3 * lgs_pct() + 12.0 * floculacion() + 1.5 * xc + mg_oh2 / 15.0


func gel_10min() -> float:
	return gel_10s() * 1.8 + 10.0 * floculacion()


func filtrado_api() -> float:
	var control := 1.0 + 0.12 * bentonita + 0.6 * pac + 0.15 * lignosulfonato
	return 25.0 / control * (1.0 + 2.0 * floculacion())


## Viscosidad de embudo Marsh (s/qt); agua ≈ 26.
func viscosidad_embudo() -> float:
	return 26.0 + 0.9 * va() + 0.4 * gel_10s()


# ======================= Cambios de composición =======================

## Agrega Ca(OH)₂ (cal o cemento). Se disuelve hasta saturar; el resto queda
## como cal en exceso.
func agregar_cal(lb_bbl: float) -> void:
	cal_exceso += lb_bbl
	var mmol_disponible := cal_exceso * MMOL_CAL_POR_LB_BBL / fw()
	var mmol_espacio := maxf(0.0, OH_MAX_CAL_MG_L - oh) / (2.0 * MG_POR_MEQ_OH)
	var disuelto := minf(mmol_disponible, mmol_espacio)
	oh += disuelto * 2.0 * MG_POR_MEQ_OH
	ca += disuelto * MG_POR_MMOL_CA
	cal_exceso -= disuelto * fw() / MMOL_CAL_POR_LB_BBL
	_equilibrar()


## Agrega acidez (meq por litro de filtrado). Orden de consumo: OH⁻, CO₃²⁻ → HCO₃⁻,
## alcalinidad orgánica, cal sin disolver (libera Ca²⁺) y por último HCO₃⁻ → CO₂.
func agregar_acido(meq: float) -> void:
	var resto := meq
	var tomado := minf(resto, oh / MG_POR_MEQ_OH)
	oh -= tomado * MG_POR_MEQ_OH
	resto -= tomado

	tomado = minf(resto, co3 / MG_POR_MMOL_CO3)
	co3 -= tomado * MG_POR_MMOL_CO3
	hco3 += tomado * MG_POR_MMOL_HCO3
	resto -= tomado

	tomado = minf(resto, alc_org_pf * 20.0)
	alc_org_pf -= tomado / 20.0
	alc_org_mf = maxf(0.0, alc_org_mf - tomado / 20.0)
	resto -= tomado

	var meq_cal := cal_exceso * MMOL_CAL_POR_LB_BBL / fw() * 2.0
	tomado = minf(resto, meq_cal)
	cal_exceso -= tomado / 2.0 * fw() / MMOL_CAL_POR_LB_BBL
	ca += tomado / 2.0 * MG_POR_MMOL_CA
	resto -= tomado

	tomado = minf(resto, hco3 / MG_POR_MMOL_HCO3)
	hco3 -= tomado * MG_POR_MMOL_HCO3
	_equilibrar()


## Agrega un ion disuelto (mg/l de filtrado) y re-equilibra.
func agregar_ion(nombre: String, mg_l: float) -> void:
	assert(nombre in ["oh", "co3", "hco3", "ca", "mg", "na", "k", "cl", "so4", "sulfuro"],
		"Ion desconocido: %s" % nombre)
	set(nombre, get(nombre) + mg_l)
	_equilibrar()


## Sólidos perforados inertes (fracción de volumen) que reemplazan agua.
func agregar_solidos(fraccion: float) -> void:
	frac_lgs += fraccion


## Aplica los aportes declarados por un contaminante (ver sim/contaminante.gd).
## Claves: "cal_lb_bbl", "acido_meq", "intercambio_ca", "lgs_frac", "ion_<nombre>".
func aplicar_aportes(aportes: Dictionary, cantidad: float) -> void:
	for clave: String in aportes:
		var valor: float = aportes[clave] * cantidad
		if clave == "cal_lb_bbl":
			agregar_cal(valor)
		elif clave == "acido_meq":
			agregar_acido(valor)
		elif clave == "intercambio_ca":
			# Calcio que la arcilla suelta por intercambio con el sodio de la sal.
			agregar_ion("ca", valor * clampf(mbt() / 25.0, 0.2, 1.5))
		elif clave == "lgs_frac":
			agregar_solidos(valor)
		elif clave.begins_with("ion_"):
			agregar_ion(clave.trim_prefix("ion_"), valor)
		else:
			assert(false, "Aporte desconocido: %s" % clave)


## Reacciones que el manual da como completas (mud-engineer-reference.md §1.7).
func _equilibrar() -> void:
	# HCO₃⁻ + OH⁻ → CO₃²⁻ + H₂O
	var m := minf(hco3 / MG_POR_MMOL_HCO3, oh / MG_POR_MEQ_OH)
	hco3 -= m * MG_POR_MMOL_HCO3
	oh -= m * MG_POR_MEQ_OH
	co3 += m * MG_POR_MMOL_CO3

	# Ca(OH)₂ + 2 HCO₃⁻ → CaCO₃↓ + CO₃²⁻ + 2 H₂O  (la cal sin disolver trata bicarbonatos)
	var mmol_cal := cal_exceso * MMOL_CAL_POR_LB_BBL / fw()
	m = minf(hco3 / MG_POR_MMOL_HCO3 / 2.0, mmol_cal)
	hco3 -= 2.0 * m * MG_POR_MMOL_HCO3
	cal_exceso -= m * fw() / MMOL_CAL_POR_LB_BBL
	co3 += m * MG_POR_MMOL_CO3

	# Ca²⁺ + CO₃²⁻ → CaCO₃↓  (solo el carbonato precipita calcio, no el bicarbonato)
	m = minf(ca / MG_POR_MMOL_CA, co3 / MG_POR_MMOL_CO3)
	ca -= m * MG_POR_MMOL_CA
	co3 -= m * MG_POR_MMOL_CO3

	# Mg²⁺ + 2 OH⁻ → Mg(OH)₂↓  (gel que espesa; por eso la cáustica empeora la carnalita)
	m = minf(mg / MG_POR_MMOL_MG, oh / (2.0 * MG_POR_MEQ_OH))
	mg -= m * MG_POR_MMOL_MG
	oh -= m * 2.0 * MG_POR_MEQ_OH
	mg_oh2 += m * 58.32


## Copia independiente, para comparar antes y después o para pruebas piloto.
func copiar() -> RefCounted:
	var otro: RefCounted = get_script().new()
	for propiedad in get_property_list():
		if propiedad["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			otro.set(propiedad["name"], get(propiedad["name"]))
	return otro


static func _log10(x: float) -> float:
	return log(x) / log(10.0)
