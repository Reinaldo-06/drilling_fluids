class_name Formacion
extends Resource
## Una formación como dato (invariante 3): lo que la broca encuentra y le hace
## al lodo. Se arma en data/formaciones/*.tres; agregar una = agregar un archivo.
##
## Fuentes del diseño:
## - Entrada de sólidos: simulation-logic.md §6.1 (porosidad).
## - Lutitas reactivas: simulation-logic.md §13.5 (reactividad = capacidad de
##   intercambio, tipo de arcilla decide qué inhibidor sirve).
## - Lutita frágil mecánicamente (no química): reference-wells.md §2 y
##   PIEDEMONTE-2. El MBT y el K⁺ están bien; lo que la estabiliza es la densidad.
## Lo usa sim/perforacion.gd.

const TIPOS_ARCILLA := ["montmorillonita", "illita", "caolinita", "ninguna"]

@export var nombre := ""
@export_multiline var descripcion := ""
@export var litologia := ""
## Profundidades medidas (ft) donde se la encuentra en el pozo del nivel.
@export var tope_ft := 0.0
@export var base_ft := 0.0
## Fracción de poros: la parte del hueco que no es roca (§6.1).
@export var porosidad := 0.2
## Capacidad de intercambio catiónico de la roca (meq/100 g). La bentonita
## comercial anda en 70–90; una lutita reactiva, 15–30; una arena, casi 0. Es
## la "reactividad": cuánto MBT aporta y cuánto K⁺ se come por bbl de recorte.
@export var cic_meq_100g := 0.0
@export_enum("montmorillonita", "illita", "caolinita", "ninguna") var tipo_arcilla := "ninguna"
## Reparto de tamaños de los recortes al llegar a superficie (fracción en
## volumen). Gruesos > ~74 μm (zarandas), medios 20–74 μm (hidrociclones),
## finos < 20 μm (centrífuga); finos = 1 − gruesos − medios. 🧩
@export var fraccion_gruesos := 0.66
@export var fraccion_medios := 0.22
## Contaminante que aporta (id de data/contaminantes/, sin extensión; vacío = ninguno).
@export var contaminante := ""
## Cantidad del contaminante, en su unidad × bbl de lodo, por bbl de ROCA
## perforada (sólidos generados). Por bbl de roca y no por pie para que no
## dependa del diámetro: al aplicarlo se divide por el volumen del tanque.
## Ejemplo: cemento con 40 → 40 lb de cal libre por bbl de cemento perforado. 🧩
@export var contaminante_por_bbl_roca := 0.0
## Lutita frágil: se derrumba si la densidad del lodo queda bajo
## densidad_minima_estable_ppg, aunque la inhibición química sea buena.
@export var fragil_mecanicamente := false
@export var densidad_minima_estable_ppg := 0.0


func fraccion_finos() -> float:
	return maxf(0.0, 1.0 - fraccion_gruesos - fraccion_medios)


func contiene(profundidad_ft: float) -> bool:
	return profundidad_ft >= tope_ft and profundidad_ft < base_ft
