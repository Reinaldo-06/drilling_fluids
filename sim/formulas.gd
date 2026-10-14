class_name Formulas
extends RefCounted
## Fórmulas de campo del ingeniero de fluidos.
##
## Todas en unidades de campo (ppg, bbl, psi, ft, pulg, lb/bbl, mg/l).
## Cada función cita la sección de docs/ de donde sale; los ejemplos de esas
## secciones son los casos de prueba en tests/test_formulas.gd.
## Funciones puras: no tocan escena ni estado.

const DENSIDAD_BARITA_PPG := 35.0      ## SG 4,2
const DENSIDAD_AGUA_PPG := 8.345
const DENSIDAD_LGS_PPG := 21.7         ## sólidos de baja gravedad, SG 2,6
const LB_BARITA_POR_BBL := 1470.0
const LB_POR_SACO := 100.0
const SACOS_BARITA_POR_BBL := 14.7
const GRADIENTE_POR_PPG := 0.052       ## psi/ft por ppg
const CONSTANTE_CAPACIDAD := 1029.4    ## pulg² → bbl/ft
const GAL_POR_BBL := 42.0

## Factores de la Tabla 2 del manual (mud-engineer-reference.md §1.2).
## Dosis (lb/bbl) = mg/l × Fw × factor.
const FACTOR_DOSIS := {
	"carbonato_yeso": 0.00100,
	"carbonato_cal": 0.000432,
	"bicarbonato_cal": 0.00424,
	"calcio_carbonato_de_sodio": 0.000928,
	"calcio_sapp": 0.000971,
	"calcio_bicarbonato_de_sodio": 0.00735,
	"dureza_soda_caustica": 0.00116,
	"sulfuro_oxido_de_cinc": 0.00091,
}

## Factores por lb/bbl de exceso de cal (cemento o cal), mismo §1.2.
const FACTOR_EXCESO_CAL := {
	"bicarbonato_de_sodio": 1.135,
	"sapp": 1.150,
	"acido_citrico": 1.893,
}


# --- Densificar, diluir, mezclar (mud-engineer-reference.md §2) ---

## Barita por barril de lodo inicial para pasar de w1 a w2 (§2.1).
static func barita_lb_por_bbl(w1: float, w2: float) -> float:
	return LB_BARITA_POR_BBL * (w2 - w1) / (DENSIDAD_BARITA_PPG - w2)


## Volumen de barita que entra (bbl) = aumento de volumen del sistema (§2.1).
static func volumen_barita_bbl(volumen_inicial: float, w1: float, w2: float) -> float:
	return volumen_inicial * (w2 - w1) / (DENSIDAD_BARITA_PPG - w2)


## Sacos de 100 lb para densificar un volumen (§2.1). Sin redondear.
static func sacos_barita(volumen_inicial: float, w1: float, w2: float) -> float:
	return volumen_barita_bbl(volumen_inicial, w1, w2) * LB_BARITA_POR_BBL / LB_POR_SACO


## Aumento de volumen por sacos agregados (§2.1).
static func aumento_volumen_por_sacos(sacos: float) -> float:
	return sacos / SACOS_BARITA_POR_BBL


## Agua para bajar la densidad de w1 a w2 (§2.2).
static func agua_dilucion_bbl(volumen_inicial: float, w1: float, w2: float, densidad_agua := DENSIDAD_AGUA_PPG) -> float:
	return volumen_inicial * (w1 - w2) / (w2 - densidad_agua)


## Densidad de la mezcla de dos lodos (§2.3).
static func densidad_mezcla(v1: float, d1: float, v2: float, d2: float) -> float:
	return (v1 * d1 + v2 * d2) / (v1 + v2)


## Volumen del lodo liviano (d1) para preparar volumen_total de densidad
## objetivo mezclando con el pesado (d2) (§2.3). El resto es del pesado.
static func volumen_liviano_para_mezcla(volumen_total: float, objetivo: float, d1: float, d2: float) -> float:
	return volumen_total * (d2 - objetivo) / (d2 - d1)


## Lechada de barita y agua para bajar sólidos de s1 % a s2 % sin cambiar el peso (§2.4).
## Devuelve {lechada, barita, agua, sacos} en bbl (sacos en unidades).
static func reducir_solidos(volumen_inicial: float, s1: float, s2: float, peso: float) -> Dictionary:
	var lechada := (s1 - s2) / s2 * volumen_inicial
	var fraccion_barita := (peso - DENSIDAD_AGUA_PPG) / (DENSIDAD_BARITA_PPG - DENSIDAD_AGUA_PPG)
	var barita := lechada * fraccion_barita
	return {
		"lechada": lechada,
		"barita": barita,
		"agua": lechada - barita,
		"sacos": barita * SACOS_BARITA_POR_BBL,
	}


## % en volumen de sólidos de baja gravedad en lodo no densificado con agua dulce (§2.5).
static func lgs_porcentaje(densidad: float) -> float:
	return 100.0 * (densidad - DENSIDAD_AGUA_PPG) / (DENSIDAD_LGS_PPG - DENSIDAD_AGUA_PPG)


# --- Volúmenes y tiempos de circulación (simulation-logic.md §2) ---

## Capacidad interna de un hueco o tubería (bbl/ft).
static func capacidad_bbl_por_ft(diametro_pulg: float) -> float:
	return diametro_pulg * diametro_pulg / CONSTANTE_CAPACIDAD


## Capacidad anular entre hueco y tubería (bbl/ft).
static func capacidad_anular_bbl_por_ft(hueco_pulg: float, tuberia_pulg: float) -> float:
	return (hueco_pulg * hueco_pulg - tuberia_pulg * tuberia_pulg) / CONSTANTE_CAPACIDAD


## Velocidad anular (ft/min) (mud-engineer-reference.md §2.5).
static func velocidad_anular_ft_min(gpm: float, hueco_pulg: float, tuberia_pulg: float) -> float:
	return 24.5 * gpm / (hueco_pulg * hueco_pulg - tuberia_pulg * tuberia_pulg)


## Salida real de la bomba por embolada.
static func salida_bomba_bbl_por_emb(desplazamiento_teorico: float, eficiencia := 0.95) -> float:
	return desplazamiento_teorico * eficiencia


## Minutos para desplazar un volumen a un caudal en gpm.
static func minutos_para_volumen(volumen_bbl: float, gpm: float) -> float:
	return volumen_bbl / (gpm / GAL_POR_BBL)


## Emboladas para desplazar un volumen.
static func emboladas(volumen_bbl: float, bbl_por_emb: float) -> float:
	return volumen_bbl / bbl_por_emb


# --- Presión (domain-research.md §4.1) ---

static func presion_hidrostatica_psi(densidad: float, tvd_ft: float) -> float:
	return GRADIENTE_POR_PPG * densidad * tvd_ft


static func gradiente_psi_por_ft(densidad: float) -> float:
	return GRADIENTE_POR_PPG * densidad


## Peso de lodo de matada a partir de la presión de cierre en la sarta.
static func peso_de_matada(densidad: float, sidpp_psi: float, tvd_ft: float) -> float:
	return densidad + sidpp_psi / (GRADIENTE_POR_PPG * tvd_ft)


## Densidad equivalente de circulación.
static func ecd(densidad: float, perdida_anular_psi: float, tvd_ft: float) -> float:
	return densidad + perdida_anular_psi / (GRADIENTE_POR_PPG * tvd_ft)


# --- Reología (mud-engineer-reference.md §5) ---

static func vp(t600: float, t300: float) -> float:
	return t600 - t300


static func pc(t600: float, t300: float) -> float:
	return t300 - vp(t600, t300)


## Viscosidad aparente (cP).
static func va(t600: float) -> float:
	return t600 / 2.0


## Límite práctico del manual: VP ≤ 2 × peso del lodo.
static func vp_excede_limite(vp_cp: float, densidad: float) -> bool:
	return vp_cp > 2.0 * densidad


# --- Química y dosis (mud-engineer-reference.md §1.2) ---

## Exceso de cal (lb/bbl).
static func exceso_de_cal(pm: float, pf: float, fw: float) -> float:
	return 0.26 * (pm - pf * fw)


## Dosis de tratamiento (lb/bbl) por concentración del ion. Ver FACTOR_DOSIS.
static func dosis_por_ion(tratamiento: String, mg_l: float, fw: float) -> float:
	assert(FACTOR_DOSIS.has(tratamiento), "Tratamiento desconocido: %s" % tratamiento)
	return mg_l * fw * FACTOR_DOSIS[tratamiento]


## Dosis (lb/bbl) para tratar exceso de cal. Ver FACTOR_EXCESO_CAL.
static func dosis_por_exceso_de_cal(tratamiento: String, exceso_cal_lb_bbl: float) -> float:
	assert(FACTOR_EXCESO_CAL.has(tratamiento), "Tratamiento desconocido: %s" % tratamiento)
	return exceso_cal_lb_bbl * FACTOR_EXCESO_CAL[tratamiento]


# --- Píldoras (mud-engineer-reference.md §3.1) ---

## Longitud de columna de una píldora a partir de la diferencia de presión.
static func longitud_columna_pildora_ft(presion_psi: float, densidad_lodo: float, densidad_pildora: float) -> float:
	return presion_psi / (gradiente_psi_por_ft(densidad_lodo) - gradiente_psi_por_ft(densidad_pildora))


# --- Sólidos (simulation-logic.md §6.1) ---

## Sólidos que genera la broca (bbl/h).
static func solidos_generados_bbl_h(hueco_pulg: float, rop_ft_h: float, porosidad: float) -> float:
	return capacidad_bbl_por_ft(hueco_pulg) * rop_ft_h * (1.0 - porosidad)
