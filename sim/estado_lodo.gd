class_name EstadoLodo
extends RefCounted
## Estado del lodo de un tanque: guarda la COMPOSICIÓN y deriva las propiedades.
##
## Diseño en docs/simulation-logic.md §12. Puntos clave:
## - Nada de PV, YP o filtrado guardado: se calculan al pedirlos.
## - La floculación se deriva de la química del agua y de los desfloculantes,
##   así todo contaminante químico produce síntomas físicos parecidos y solo
##   la química los distingue (invariante 1).
## - Alcalinidades con las relaciones API entre Pf/Mf y OH⁻, CO₃²⁻, HCO₃⁻, más
##   el tampón orgánico y arcilloso titulado hasta pH 8,3 (Pf) y 4,3 (Mf).
## - Las reacciones son las del manual (mud-engineer-reference.md §1).
##
## Química del agua (ver "Equilibrio ácido-base" más abajo): el estado guarda las
## especies; cada cambio conserva la ALCALINIDAD TOTAL (meq/l) y el carbono
## inorgánico total, y el pH sale de repartirlos entre OH⁻, el par
## CO₃²⁻/HCO₃⁻/CO₂ y el tampón (lignosulfonato y bentonita). Así el pH no cae a 7
## sin soda ni salta a 12 con un puñado de cáustica.
## Las constantes de las propiedades físicas son de calibración (🧩) y se
## ajustan jugando; lo que no se puede romper son los sentidos de la Tabla 4.

const F := preload("res://sim/formulas.gd")

const MG_POR_MEQ_OH := 17.0
const MG_POR_MMOL_CO3 := 60.0
const MG_POR_MMOL_HCO3 := 61.0
const MG_POR_MMOL_CO2 := 44.01
const MG_POR_MMOL_CA := 40.08
const MG_POR_MMOL_MG := 24.31
const MG_POR_MMOL_MG_OH2 := 58.32
## mmol de Ca(OH)₂ por litro de lodo en 1 lb/bbl (453,6 g / 159 l / 74,09 g/mol).
const MMOL_CAL_POR_LB_BBL := 38.51
## OH⁻ con cal saturada (pH ≈ 12,4). Por encima la cal queda sin disolver.
const OH_MAX_CAL_MG_L := 425.0
## Aumento de densidad del agua por mg/l de cloruro (agua saturada ≈ 10 ppg).
const PPG_POR_MG_L_CL := 8.83e-6
## pKa del ácido carbónico a 25 °C (valores de libro de texto; el segundo ya
## estaba en el modelo y coincide con el pH 10,3 de conversión del manual §1.7).
const PKA1_CARBONATO := 6.35
const PKA2_CARBONATO := 10.33
## mg de producto por litro de lodo en 1 lb/bbl (453,592 g / 158,987 l).
const MG_L_LODO_POR_LB_BBL := 2853.0
const DENSIDAD_CACO3_PPG := 22.6       ## SG 2,71
## Efecto de los aditivos nuevos sobre las propiedades (por lb/bbl). 🧩 calibración
## de juego, en el orden de magnitud de los demás aditivos del modelo.
const VP_POR_LB_PHPA := 2.0
const PC_POR_LB_PHPA := 3.0
const GEL_POR_LB_PHPA := 0.5
const VP_POR_LB_ALMIDON := 0.8
const CONTROL_FILTRADO_ALMIDON := 0.5  ## el PAC es 0,6
const CONTROL_FILTRADO_PHPA := 0.2
const CONTROL_FILTRADO_LIGNITO := 0.15
const CONTROL_FILTRADO_CACO3_POR_PCT := 0.3  ## puenteo: por % de volumen
const DESFLOCULANTE_POR_LB_LIGNITO := 0.06   ## el lignosulfonato es 0,08
const MG_POR_MMOL_ION := {
	"oh": 17.01, "co3": 60.01, "hco3": 61.02, "ca": 40.08, "mg": 24.31,
	"na": 22.99, "k": 39.10, "cl": 35.45, "so4": 96.06, "sulfuro": 32.06,
}

# --- Tampón del pH (🧩 calibración anclada a datos de campo) ---
## Grupos ácidos débiles del lodo (fenólicos del lignosulfonato, bordes de la
## arcilla). Se reparten por igual en tres pKa para que el tampón cubra el
## rango de trabajo 8,5–10,5 sin escalones. 🧩
const PKA_TAMPON := [8.5, 9.5, 10.5]
## Capacidad tampón del lignosulfonato: meq por litro de lodo y por lb/bbl.
## Anclada a la regla de campo "1 saco de soda cáustica por cada 4 de
## lignosulfonato o lignito" (producto con pH ≈ 3–4), que da 17,8 meq/l por
## lb/bbl a pH 10; dividido por la fracción ionizada a pH 10 (0,656) da 27.
## Fuentes: SLB, Caustic soda y SPERSENE (1:4, rango eficaz pH 9–11):
## https://www.slb.com/products-and-services/innovating-in-oil-and-gas/well-construction/drilling-fluids/drilling-fluid-additives/alkalinity-control/caustic-soda
## https://www.slb.com/products-and-services/innovating-in-oil-and-gas/well-construction/drilling-fluids/drilling-fluid-additives/thinners-and-dispersants/spersene-chrome-lignosulfonate
## ⚠️ La titulación de lignosulfonato puro da menos grupos (1,32 mmol/g
## fenólicos + 0,86 carboxílicos ≈ 6 meq/l por lb/bbl; hgxb.cip.com.cn
## 2012, 63(1):258): el resto de la demanda de soda se le carga al tampón. 🧩
const MEQ_TAMPON_POR_LB_LIGNOSULFONATO := 27.0
## Capacidad tampón de la bentonita (sitios de borde dependientes del pH,
## ~15 % de una CIC de 80 meq/100 g): meq por litro de lodo por lb/bbl. 🧩
const MEQ_TAMPON_POR_LB_BENTONITA := 0.35
## pH natural de una suspensión de bentonita sódica sin soda (5 %: pH 8–10).
## https://digitalfire.com/material/big+horn+ce+200+bentonite ⚠️ (ficha de
## producto; coincide con el pH de hidratación habitual en el campo)
const PH_NATURAL_BENTONITA := 9.0

# --- Solubilidades (concentraciones molares, sin coeficientes de actividad) ---
## Mg(OH)₂: Ksp ≈ 5,6e-12 a 1,8e-11 según la fuente; se usa el alto porque en
## un filtrado salino la actividad sube la solubilidad aparente. Con 1.000 mg/l
## de Mg precipita desde pH ≈ 9,4 y a pH 11 queda < 1 mg/l (manual §1.6).
const KSP_MG_OH2 := 1.8e-11
## CaCO₃: el Ksp termodinámico de la calcita es 3,3e-9; se usa 1e-8 porque los
## lignosulfonatos inhiben la nucleación y el filtrado no es agua pura. 🧩
const KSP_CACO3 := 1.0e-8
## Eficacia del lignosulfonato según el pH: pierde solubilidad bajo 9,5 (manual
## §1.5) y el fabricante lo da eficaz entre pH 9 y 11 (SPERSENE, SLB). 🧩
const PH_LIGNO_PLENO := 9.5
const PH_LIGNO_NULO := 8.0
const EFICACIA_LIGNO_MINIMA := 0.25
## Mg(OH)₂ precipitado (mg/l) por cada punto de PC y de gel. Antes 10 y 15; se
## subieron porque el Mg ahora precipita también contra el tampón (pH ≈ 9,4) y
## no solo contra el OH⁻ libre, así que hay más gel por la misma carnalita. 🧩
const MG_OH2_POR_PUNTO_PC := 30.0
const MG_OH2_POR_PUNTO_GEL := 45.0

# --- Fases (fracción del volumen de lodo) ---
var frac_barita := 0.0
var frac_lgs := 0.0          ## sólidos de baja gravedad: bentonita + perforados
var frac_aceite := 0.0
var frac_caco3 := 0.0        ## carbonato de calcio dimensionado (puenteo soluble en ácido, SG 2,71)
var aire := 0.0              ## aire atrapado; solo afecta la balanza atmosférica

# --- Productos activos (lb/bbl) ---
var bentonita := 0.0
var lignosulfonato := 0.0
var pac := 0.0
var xc := 0.0
var phpa := 0.0              ## encapsulador e inhibidor secundario (simulation-logic §13.3)
var almidon := 0.0           ## controlador de filtrado; tolera sal (mud-programs, sistemas 3, 4 y 6)
var lignito := 0.0           ## desfloculante y control de filtrado; entra ácido como el lignosulfonato
var amina := 0.0             ## inhibidor principal del sistema amina/PHPA (simulation-logic §13.2)
var arcilla_activa := 0.0    ## arcilla perforada reactiva (suma al MBT)
## Cal en exceso: reserva alcalina sin disolver, en lb/bbl de Ca(OH)₂. No se
## disuelve sola; solo reacciona con ácidos, bicarbonatos y carbonatos. Es lo que
## separa Pm de Pf·Fw. (Los finos de cemento, que sí se disuelven solos, van aparte.)
var cal_exceso := 0.0
## Finos de cemento sin disolver (lb/bbl de Ca(OH)₂). A diferencia de la cal en
## exceso, se disuelven solos en pocas vueltas del lodo (manual §1.3, punto 6:
## sacarlos con el equipo de sólidos antes de que se disuelvan). Ver sim/cinetica.gd.
var finos_cemento := 0.0

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
var mg_oh2 := 0.0            ## Mg(OH)₂ precipitado (mg/l): gel que espesa (carnalita)
## CO₂ disuelto (mg/l): la parte del carbono inorgánico bajo pH ~7. No suma a Pf ni Mf.
var co2 := 0.0
## Base retenida por el tampón (meq/l de filtrado): grupos ácidos del
## lignosulfonato y la arcilla que ya cedieron su protón. Suma a Pf y Mf.
var tampon_base := 0.0
## Alcalinidad de sales orgánicas en ml de ácido. Heredado: el tampón la
## reemplaza y los lodos base la dejan en 0, pero sigue sumando si se usa.
var alc_org_pf := 0.0
var alc_org_mf := 0.0


# ======================= Fases y densidad =======================

## Fracción de agua (lo que da la retorta como Fw).
func fw() -> float:
	return 1.0 - frac_barita - frac_lgs - frac_aceite - frac_caco3


func densidad_agua() -> float:
	return F.DENSIDAD_AGUA_PPG + PPG_POR_MG_L_CL * cl


func densidad() -> float:
	return fw() * densidad_agua() + frac_barita * F.DENSIDAD_BARITA_PPG \
		+ frac_lgs * F.DENSIDAD_LGS_PPG + frac_aceite * 7.0 + frac_caco3 * DENSIDAD_CACO3_PPG


## Lo que lee la balanza no presurizada: el aire baja la lectura.
func densidad_balanza_atmosferica() -> float:
	return densidad() * (1.0 - aire)


func solidos_pct() -> float:
	return 100.0 * (frac_barita + frac_lgs + frac_caco3)


func lgs_pct() -> float:
	return 100.0 * frac_lgs


func mbt() -> float:
	return bentonita + arcilla_activa


# ======================= Química =======================

## Pf: ml de H₂SO₄ 0,02 N por ml de filtrado hasta pH 8,3 (20 meq/l = 1 ml).
func pf() -> float:
	var tampon := maxf(0.0, tampon_base - capacidad_tampon() * _fraccion_tampon(8.3)) / 20.0
	return oh / 340.0 + co3 / 1200.0 + alc_org_pf + tampon


## Mf: hasta pH 4,3. El tampón cuenta entero (a 4,3 ya no le queda base).
func mf() -> float:
	var tampon := maxf(0.0, tampon_base - capacidad_tampon() * _fraccion_tampon(4.3)) / 20.0
	return oh / 340.0 + co3 / 600.0 + hco3 / 1220.0 + alc_org_mf + tampon


## La parte del Mf que viene de carbonatos y bicarbonatos (sin OH⁻ ni orgánicos).
func mf_carbonatos() -> float:
	return co3 / 600.0 + hco3 / 1220.0


## Pm = Pf·Fw + cal sin disolver; es la inversa de Formulas.exceso_de_cal.
func pm() -> float:
	# Los finos de cemento sin disolver también titulan en el lodo entero.
	return pf() * fw() + (cal_exceso + finos_cemento) / 0.26


## Dureza de calcio (valoración con calcon/EDTA a pH 12–13): solo Ca²⁺, mg/l.
func dureza_calcio_mg_l() -> float:
	return ca


## Dureza total (valoración con EDTA a pH 10): Ca²⁺ + Mg²⁺, expresada como mg/l
## de Ca²⁺. El magnesio sale de la diferencia (manual §1.6: hay que valorarlos
## por separado para confirmar magnesio).
func dureza_total_mg_l() -> float:
	return ca + mg * MG_POR_MMOL_CA / MG_POR_MMOL_MG


## Magnesio por diferencia entre dureza total y de calcio (mg/l de Mg²⁺).
func magnesio_por_diferencia_mg_l() -> float:
	return (dureza_total_mg_l() - dureza_calcio_mg_l()) * MG_POR_MMOL_MG / MG_POR_MMOL_CA


func ph() -> float:
	# Tras cualquier cambio el equilibrio deja OH⁻ > 0: el pH sale directo de él.
	if oh > 0.0:
		return 14.0 + _log10(oh / (MG_POR_MEQ_OH * 1000.0))
	# Estados armados a mano sin equilibrar (pruebas de las relaciones API).
	if hco3 > 0.5:
		if co3 <= 0.0:
			return 8.3
		var razon := (co3 / MG_POR_MMOL_CO3) / (hco3 / MG_POR_MMOL_HCO3)
		return clampf(PKA2_CARBONATO + _log10(razon), 6.5, PKA2_CARBONATO)
	var p := 7.0
	if co3 > 0.0:
		# Hidrólisis del carbonato: OH⁻ ≈ √(Kb·C), Kb = 10^-3,67.
		p = maxf(p, 14.0 + 0.5 * _log10(pow(10.0, -3.67) * co3 / 60000.0))
	if pf() > 0.0:
		p = maxf(p, 8.3)  # Pf > 0 significa pH sobre el punto de la fenolftaleína
	return p


## Capacidad tampón total (meq por litro de filtrado).
func capacidad_tampon() -> float:
	var fw_ := maxf(fw(), 0.05)
	return (MEQ_TAMPON_POR_LB_LIGNOSULFONATO * (lignosulfonato + lignito)
		+ MEQ_TAMPON_POR_LB_BENTONITA * bentonita) / fw_


## 1 con pH ≥ 9,5; baja hasta 0,25 en pH 8: el lignosulfonato sin álcali no rinde.
func eficacia_lignosulfonato() -> float:
	var t := (ph() - PH_LIGNO_NULO) / (PH_LIGNO_PLENO - PH_LIGNO_NULO)
	return clampf(t, EFICACIA_LIGNO_MINIMA, 1.0)


# ======================= Propiedades físicas derivadas =======================

## 0 = disperso, 1 = totalmente floculado.
func floculacion() -> float:
	var insultos := maxf(0.0, ca - 120.0) / 400.0 \
		+ mg / 200.0 \
		+ maxf(0.0, cl - 3000.0) / 15000.0 \
		+ maxf(0.0, mf_carbonatos() - 3.0) / 4.0 \
		+ sulfuro / 200.0
	# MBT bajo → poco efecto de la contaminación química (manual 4C.1).
	var reactividad := clampf(mbt() / 25.0, 0.2, 1.5)
	var desfloculante := (0.08 * lignosulfonato + DESFLOCULANTE_POR_LB_LIGNITO * lignito) \
		* eficacia_lignosulfonato()
	return clampf(insultos * reactividad - desfloculante, 0.0, 1.0)


func vp() -> float:
	return 2.0 + 2.5 * lgs_pct() + 0.6 * 100.0 * frac_barita + 3.0 * xc + 1.5 * pac \
		+ 2.5 * 100.0 * frac_caco3 + VP_POR_LB_PHPA * phpa + VP_POR_LB_ALMIDON * almidon


func pc() -> float:
	return 0.8 * bentonita + 4.0 * xc + 25.0 * floculacion() + mg_oh2 / MG_OH2_POR_PUNTO_PC \
		+ PC_POR_LB_PHPA * phpa


func lectura_600() -> float:
	return 2.0 * vp() + pc()


func lectura_300() -> float:
	return vp() + pc()


func va() -> float:
	return F.va(lectura_600())


func gel_10s() -> float:
	return 0.25 * bentonita + 0.3 * lgs_pct() + 12.0 * floculacion() + 1.5 * xc + mg_oh2 / MG_OH2_POR_PUNTO_GEL \
		+ GEL_POR_LB_PHPA * phpa


func gel_10min() -> float:
	return gel_10s() * 1.8 + 10.0 * floculacion()


func filtrado_api() -> float:
	var control := 1.0 + 0.12 * bentonita + 0.6 * pac + 0.15 * lignosulfonato \
		+ CONTROL_FILTRADO_ALMIDON * almidon + CONTROL_FILTRADO_PHPA * phpa \
		+ CONTROL_FILTRADO_LIGNITO * lignito + CONTROL_FILTRADO_CACO3_POR_PCT * 100.0 * frac_caco3
	return 25.0 / control * (1.0 + 2.0 * floculacion())


## Viscosidad de embudo Marsh (s/qt); agua ≈ 26.
func viscosidad_embudo() -> float:
	return 26.0 + 0.9 * va() + 0.4 * gel_10s()


# ======================= Cambios de composición =======================

## Agrega Ca(OH)₂ (cal o cemento). Primero se come los carbonatos; después se
## disuelve hasta saturar (pH ≈ 12,4, contando lo que absorbe el tampón) y el
## resto queda como cal en exceso.
func agregar_cal(lb_bbl: float) -> void:
	cal_exceso += lb_bbl
	_equilibrar()
	var ph_saturacion := 14.0 + _log10(OH_MAX_CAL_MG_L / (MG_POR_MEQ_OH * 1000.0))
	for _vuelta in 20:
		var alcalinidad := _alcalinidad_actual()
		var falta := _alcalinidad_en_ph(ph_saturacion, _carbono_total(), capacidad_tampon()) - alcalinidad
		var mmol := minf(_mmol_cal(), falta / 2.0)
		if mmol <= 1e-9:
			break
		_restar_cal(mmol)
		ca += mmol * MG_POR_MMOL_CA
		_resolver(alcalinidad + 2.0 * mmol)


## Agrega acidez (meq por litro de filtrado). Orden de consumo: la alcalinidad
## disuelta hasta pH 8,3 (OH⁻, CO₃²⁻ → HCO₃⁻ y el tampón, todo a la vez),
## alcalinidad orgánica heredada, cal sin disolver (libera Ca²⁺) y por último lo
## que queda bajo 8,3 (HCO₃⁻ → CO₂ y el tampón restante).
## Los ácidos atacan primero lo disuelto; en cambio, bicarbonatos y carbonatos
## consumen primero la cal sólida (ver _resolver), que es lo que suponen las
## fórmulas de tratamiento del manual.
func agregar_acido(meq: float) -> void:
	var alcalinidad := _alcalinidad_actual()
	var carbono := _carbono_total()
	var resto := meq

	var hasta_8_3 := alcalinidad - _alcalinidad_en_ph(8.3, carbono, capacidad_tampon())
	var tomado := clampf(hasta_8_3, 0.0, resto)
	alcalinidad -= tomado
	resto -= tomado

	tomado = minf(resto, alc_org_pf * 20.0)
	alc_org_pf -= tomado / 20.0
	alc_org_mf = maxf(0.0, alc_org_mf - tomado / 20.0)
	resto -= tomado

	tomado = minf(resto, _mmol_cal() * 2.0)
	_restar_cal(tomado / 2.0)
	ca += tomado / 2.0 * MG_POR_MMOL_CA
	resto -= tomado

	_resolver(alcalinidad - resto)


## Agrega un ion disuelto (mg/l de filtrado) y re-equilibra.
## OH⁻, CO₃²⁻ y HCO₃⁻ suben la alcalinidad total (1, 2 y 1 meq por mmol).
func agregar_ion(nombre: String, mg_l: float) -> void:
	assert(nombre in ["oh", "co3", "hco3", "ca", "mg", "na", "k", "cl", "so4", "sulfuro"],
		"Ion desconocido: %s" % nombre)
	set(nombre, get(nombre) + mg_l)
	_equilibrar()


## Sólidos perforados inertes (fracción de volumen) que reemplazan agua.
func agregar_solidos(fraccion: float) -> void:
	frac_lgs += fraccion


## Agrega un químico que se disuelve y reacciona (soda, carbonato de sodio, SAPP…).
## "reaccion" va por mol de producto: "ion_<nombre>" (mol de ion), "acido" (eq),
## "precipita_ca" (mol de Ca²⁺), "precipita_sulfuro" (mol de S²⁻).
## La conversión lb/bbl → mmol/l de filtrado usa Fw, igual que las fórmulas
## de dosis del manual, así la dosis calculada trata exactamente lo medido.
func agregar_quimico(reaccion: Dictionary, peso_molecular: float, lb_bbl: float) -> void:
	var mmol := lb_bbl * MG_L_LODO_POR_LB_BBL / peso_molecular / fw()
	for clave: String in reaccion:
		var cantidad: float = reaccion[clave] * mmol
		if clave == "acido":
			agregar_acido(cantidad)
		elif clave == "precipita_ca":
			ca = maxf(0.0, ca - cantidad * MG_POR_MMOL_CA)
		elif clave == "precipita_sulfuro":
			# ZnO + HS⁻ → ZnS↓ + OH⁻: devuelve la alcalinidad que el H₂S se llevó.
			# El ZnO que sobra no se disuelve y no aporta nada.
			var precipitado := minf(cantidad, sulfuro / MG_POR_MMOL_ION["sulfuro"])
			sulfuro -= precipitado * MG_POR_MMOL_ION["sulfuro"]
			oh += precipitado * MG_POR_MEQ_OH
		elif clave.begins_with("ion_"):
			var ion := clave.trim_prefix("ion_")
			set(ion, get(ion) + cantidad * MG_POR_MMOL_ION[ion])
		else:
			assert(false, "Reacción desconocida: %s" % clave)
	_equilibrar()


## Aditivo que no cambia los iones (lb/bbl): lignosulfonato, lignito, PAC, XC,
## PHPA, almidón, amina. El lignosulfonato y el lignito entran ácidos (pH 3–4):
## suman capacidad tampón sin base, así que bajan el pH hasta que se les echa
## soda (1 saco por cada 4, SLB).
func agregar_aditivo(nombre: String, lb_bbl: float) -> void:
	assert(nombre in ADITIVOS, "Aditivo desconocido: %s" % nombre)
	set(nombre, get(nombre) + lb_bbl)
	if nombre in ["lignosulfonato", "lignito"]:
		_equilibrar()


const ADITIVOS := ["lignosulfonato", "lignito", "pac", "xc", "phpa", "almidon", "amina"]


## Carbonato de calcio dimensionado (lb por bbl de lodo inicial). Sólido inerte
## para puenteo; suma volumen y peso (SG 2,71). No reacciona: es soluble en
## ácido, no en el lodo.
func agregar_carbonato_de_calcio(lb_bbl: float) -> void:
	var v := lb_bbl / (DENSIDAD_CACO3_PPG * F.GAL_POR_BBL)
	_diluir_por_volumen_agregado(v, false)
	frac_caco3 += v / (1.0 + v)


## Barita (lb por bbl de lodo inicial). Sube el volumen: el resultado se
## expresa de nuevo por bbl de lodo final. Coincide con Formulas.barita_lb_por_bbl.
func agregar_barita(lb_bbl: float) -> void:
	var v := lb_bbl / F.LB_BARITA_POR_BBL
	_diluir_por_volumen_agregado(v, false)
	frac_barita += v / (1.0 + v)


## Bentonita seca (lb por bbl de lodo inicial). Suma volumen de sólidos livianos
## y su tampón, que trae la base de su pH natural (~9).
func agregar_bentonita(lb_bbl: float) -> void:
	var v := lb_bbl / (F.DENSIDAD_LGS_PPG * F.GAL_POR_BBL)
	_diluir_por_volumen_agregado(v, false)
	frac_lgs += v / (1.0 + v)
	var nueva := lb_bbl / (1.0 + v)
	bentonita += nueva
	tampon_base += MEQ_TAMPON_POR_LB_BENTONITA * nueva / fw() * _fraccion_tampon(PH_NATURAL_BENTONITA)
	_equilibrar()


## Agua dulce (bbl por bbl de lodo inicial). Diluye sólidos, productos e iones.
## El tampón amortigua el cambio de pH, como en el campo.
func agregar_agua(bbl_por_bbl: float) -> void:
	_diluir_por_volumen_agregado(bbl_por_bbl, true)
	_equilibrar()


## Mezcla en este estado otro lodo (por ejemplo, transferencia entre tanques).
## Fases y productos se promedian por volumen de lodo; los iones del filtrado,
## por volumen de agua. Después se re-equilibra (puede precipitar CaCO₃ o Mg(OH)₂).
func mezclar(otro: RefCounted, volumen_propio: float, volumen_otro: float) -> void:
	var total := volumen_propio + volumen_otro
	if total <= 0.0:
		return
	var agua_propia := fw() * volumen_propio
	var agua_otra: float = otro.fw() * volumen_otro
	var agua_total := agua_propia + agua_otra
	for campo in _CAMPOS_FILTRADO:
		if agua_total > 0.0:
			set(campo, (get(campo) * agua_propia + otro.get(campo) * agua_otra) / agua_total)
	for campo in _CAMPOS_POR_BBL + ["aire"]:
		set(campo, (get(campo) * volumen_propio + otro.get(campo) * volumen_otro) / total)
	_equilibrar()


## Recalcula el equilibrio químico (para quien cambie campos a mano).
func equilibrar() -> void:
	_equilibrar()


## Lleva el filtrado a un pH dado ajustando la alcalinidad, sin tocar el carbono
## ni las sales. Para armar lodos de partida (equivale a haberle echado la soda
## justa). No precipita nada.
func fijar_ph(valor: float) -> void:
	var carbono := _carbono_total()
	var capacidad := capacidad_tampon()
	_especiar(_alcalinidad_en_ph(valor, carbono, capacidad), carbono, capacidad)


const _CAMPOS_FILTRADO := ["oh", "co3", "hco3", "ca", "mg", "na", "k", "cl", "so4", "sulfuro",
	"mg_oh2", "co2", "tampon_base", "alc_org_pf", "alc_org_mf"]
const _CAMPOS_POR_BBL := ["frac_barita", "frac_lgs", "frac_aceite", "frac_caco3", "bentonita",
	"lignosulfonato", "lignito", "pac", "xc", "phpa", "almidon", "amina", "arcilla_activa",
	"cal_exceso", "finos_cemento"]


## Todo lo que está "por bbl de lodo" se reparte en (1 + v) bbl. Si lo que entra
## es agua, además se diluyen los iones del filtrado (y el tampón y el Mg(OH)₂,
## que el modelo cuenta por litro de filtrado).
func _diluir_por_volumen_agregado(v: float, es_agua: bool) -> void:
	var factor := 1.0 / (1.0 + v)
	if es_agua:
		var fw_antes := fw()
		var factor_iones := fw_antes / (fw_antes + v)
		for ion in _CAMPOS_FILTRADO:
			set(ion, get(ion) * factor_iones)
	for campo in _CAMPOS_POR_BBL:
		set(campo, get(campo) * factor)


## Aplica los aportes declarados por un contaminante (ver sim/contaminante.gd).
## Claves: "cal_lb_bbl", "finos_cemento", "acido_meq", "intercambio_ca", "lgs_frac", "ion_<nombre>".
func aplicar_aportes(aportes: Dictionary, cantidad: float) -> void:
	for clave: String in aportes:
		var valor: float = aportes[clave] * cantidad
		if clave == "finos_cemento":
			finos_cemento += valor
		elif clave == "cal_lb_bbl":
			agregar_cal(valor)
		elif clave == "acido_meq":
			agregar_acido(valor)
		elif clave == "intercambio_ca":
			# Calcio que la arcilla suelta por intercambio con el catión de la sal.
			agregar_ion("ca", valor * clampf(mbt() / 25.0, 0.2, 1.5))
		elif clave == "lgs_frac":
			agregar_solidos(valor)
		elif clave.begins_with("ion_"):
			agregar_ion(clave.trim_prefix("ion_"), valor)
		else:
			assert(false, "Aporte desconocido: %s" % clave)


# ======================= Equilibrio ácido-base =======================
#
# Alcalinidad total A (meq/l de filtrado) = OH⁻ − H⁺ + HCO₃⁻ + 2·CO₃²⁻ + tampón.
# Se conserva al re-especiar; solo la cambian los ácidos, las bases y las
# precipitaciones (CaCO₃ y Mg(OH)₂ se llevan 2 meq por mmol). El pH es el único
# valor que reparte A entre las especies: se busca por bisección.

func _equilibrar() -> void:
	_resolver(_alcalinidad_actual())


## Reacciones del manual (mud-engineer-reference.md §1.3–1.7) más el reparto ácido-base.
func _resolver(alcalinidad: float) -> void:
	var carbono := _carbono_total()
	var capacidad := capacidad_tampon()
	for _vuelta in 30:
		var movido := 0.0

		# Cal sólida + carbonatos → CaCO₃↓ (el factor 1,135 del manual). La cal
		# aporta 2 OH⁻ y el CaCO₃ se lleva 2 meq: la alcalinidad no cambia, solo
		# se va el carbono. Va primero: mientras haya cal sólida, ella amortigua
		# antes que el OH⁻ y el calcio disueltos. Por eso el carbonato de sodio
		# sobre cemento sube el pH.
		var m := minf(carbono, _mmol_cal())
		if m > 0.0:
			carbono -= m
			_restar_cal(m)
			movido += m

		# Ca²⁺ + CO₃²⁻ → CaCO₃↓ hasta el producto de solubilidad. A pH bajo casi
		# todo el carbono es HCO₃⁻ y el calcio convive con él (Ca(HCO₃)₂ soluble).
		var ca_mmol := ca / MG_POR_MMOL_CA
		if ca_mmol > 1e-6 and carbono > 1e-6:
			var y := _precipitar_caco3(alcalinidad, carbono, capacidad, ca_mmol)
			if y > 0.0:
				alcalinidad -= 2.0 * y
				carbono -= y
				ca = maxf(0.0, ca - y * MG_POR_MMOL_CA)
				movido += y

		# Mg²⁺ + 2 OH⁻ ⇄ Mg(OH)₂↓ (gel que espesa). Reversible: si el pH baja se
		# redisuelve (manual §1.6: hay que MANTENER el pH alto).
		var mg_mmol := mg / MG_POR_MMOL_MG
		var solido := mg_oh2 / MG_POR_MMOL_MG_OH2
		if mg_mmol > 1e-6 or solido > 1e-6:
			var x := _precipitar_mg(alcalinidad, carbono, capacidad, mg_mmol, solido)
			if absf(x) > 0.0:
				alcalinidad -= 2.0 * x
				mg = maxf(0.0, mg - x * MG_POR_MMOL_MG)
				mg_oh2 = maxf(0.0, mg_oh2 + x * MG_POR_MMOL_MG_OH2)
				movido += absf(x)

		if movido < 1e-7:
			break
	_especiar(alcalinidad, carbono, capacidad)


## Fija OH⁻, CO₃²⁻, HCO₃⁻, CO₂ y la base del tampón para una alcalinidad dada.
func _especiar(alcalinidad: float, carbono: float, capacidad: float) -> void:
	var p := _ph_para_alcalinidad(alcalinidad, carbono, capacidad)
	var fr := _fracciones_carbonato(p)
	oh = MG_POR_MEQ_OH * 1000.0 * pow(10.0, p - 14.0)
	co2 = carbono * fr[0] * MG_POR_MMOL_CO2
	hco3 = carbono * fr[1] * MG_POR_MMOL_HCO3
	co3 = carbono * fr[2] * MG_POR_MMOL_CO3
	tampon_base = capacidad * _fraccion_tampon(p)


## Alcalinidad (meq/l) que tendría el filtrado a un pH dado.
func _alcalinidad_en_ph(p: float, carbono: float, capacidad: float) -> float:
	var fr := _fracciones_carbonato(p)
	return 1000.0 * (pow(10.0, p - 14.0) - pow(10.0, -p)) \
		+ carbono * (fr[1] + 2.0 * fr[2]) + capacidad * _fraccion_tampon(p)


func _ph_para_alcalinidad(alcalinidad: float, carbono: float, capacidad: float) -> float:
	var bajo := 0.0
	var alto := 14.5
	for _i in 36:
		var medio := 0.5 * (bajo + alto)
		if _alcalinidad_en_ph(medio, carbono, capacidad) < alcalinidad:
			bajo = medio
		else:
			alto = medio
	return 0.5 * (bajo + alto)


## Alcalinidad guardada en las especies actuales.
func _alcalinidad_actual() -> float:
	var a := oh / MG_POR_MEQ_OH + hco3 / MG_POR_MMOL_HCO3 + 2.0 * co3 / MG_POR_MMOL_CO3 + tampon_base
	if oh > 0.0:
		a -= 1000.0 * pow(10.0, -ph())
	return a


## Carbono inorgánico total (mmol/l).
func _carbono_total() -> float:
	return co3 / MG_POR_MMOL_CO3 + hco3 / MG_POR_MMOL_HCO3 + co2 / MG_POR_MMOL_CO2


## [CO₂, HCO₃⁻, CO₃²⁻] como fracción del carbono total a un pH.
func _fracciones_carbonato(p: float) -> Array[float]:
	var h := pow(10.0, -p)
	var k1 := pow(10.0, -PKA1_CARBONATO)
	var k2 := pow(10.0, -PKA2_CARBONATO)
	var d := h * h + k1 * h + k1 * k2
	return [h * h / d, k1 * h / d, k1 * k2 / d]


## Fracción del tampón que ya cedió su protón a un pH.
func _fraccion_tampon(p: float) -> float:
	var suma := 0.0
	for pka: float in PKA_TAMPON:
		suma += 1.0 / (1.0 + pow(10.0, pka - p))
	return suma / PKA_TAMPON.size()


## mmol/l de CaCO₃ que precipitan hasta llegar al Ksp.
func _precipitar_caco3(alcalinidad: float, carbono: float, capacidad: float, ca_mmol: float) -> float:
	# Ya en equilibrio (tolerancia 0,1 % del Ksp): no repetir la bisección.
	if _exceso_caco3(0.0, alcalinidad, carbono, capacidad, ca_mmol) <= 1e-3 * KSP_CACO3:
		return 0.0
	var bajo := 0.0
	var alto := minf(ca_mmol, carbono)
	for _i in 36:
		var medio := 0.5 * (bajo + alto)
		if _exceso_caco3(medio, alcalinidad, carbono, capacidad, ca_mmol) > 0.0:
			bajo = medio
		else:
			alto = medio
	return alto


func _exceso_caco3(y: float, alcalinidad: float, carbono: float, capacidad: float, ca_mmol: float) -> float:
	var c := carbono - y
	var p := _ph_para_alcalinidad(alcalinidad - 2.0 * y, c, capacidad)
	var co3_molar := c * _fracciones_carbonato(p)[2] / 1000.0
	return (ca_mmol - y) / 1000.0 * co3_molar - KSP_CACO3


## mmol/l de Mg(OH)₂ que precipitan (positivo) o se redisuelven (negativo).
func _precipitar_mg(alcalinidad: float, carbono: float, capacidad: float, mg_mmol: float, solido: float) -> float:
	if absf(_exceso_mg(0.0, alcalinidad, carbono, capacidad, mg_mmol)) <= 1e-3 * KSP_MG_OH2:
		return 0.0
	var bajo := -solido
	var alto := mg_mmol
	if _exceso_mg(bajo, alcalinidad, carbono, capacidad, mg_mmol) <= 0.0:
		return bajo
	for _i in 36:
		var medio := 0.5 * (bajo + alto)
		if _exceso_mg(medio, alcalinidad, carbono, capacidad, mg_mmol) > 0.0:
			bajo = medio
		else:
			alto = medio
	return 0.5 * (bajo + alto)


func _exceso_mg(x: float, alcalinidad: float, carbono: float, capacidad: float, mg_mmol: float) -> float:
	var p := _ph_para_alcalinidad(alcalinidad - 2.0 * x, carbono, capacidad)
	var oh_molar := pow(10.0, p - 14.0)
	return (mg_mmol - x) / 1000.0 * oh_molar * oh_molar - KSP_MG_OH2


## mmol de cal sin disolver por litro de filtrado.
func _mmol_cal() -> float:
	return cal_exceso * MMOL_CAL_POR_LB_BBL / fw()


func _restar_cal(mmol: float) -> void:
	cal_exceso = maxf(0.0, cal_exceso - mmol * fw() / MMOL_CAL_POR_LB_BBL)


## Copia independiente, para comparar antes y después o para pruebas piloto.
func copiar() -> RefCounted:
	var otro: RefCounted = get_script().new()
	for propiedad in get_property_list():
		if propiedad["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			otro.set(propiedad["name"], get(propiedad["name"]))
	return otro


static func _log10(x: float) -> float:
	return log(x) / log(10.0)
