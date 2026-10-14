class_name EquipoSolidos
extends Resource
## Un equipo de control de sólidos como dato (data/equipos/*.tres).
##
## Puntos de corte de simulation-logic.md §7: zarandas > ~100 μm (según la
## malla), desarenador ~40 μm, deslimador ~20 μm, centrífuga a los finos. La
## barita mide 2–80 μm: los hidrociclones la botan; la centrífuga la recupera.
## No hay porcentajes de eficiencia confiables por equipo (⚠️ §7): todas las
## eficiencias son calibración de juego 🧩.
##
## Dos maneras de actuar (ver sim/control_solidos.gd):
## - En la ENTRADA: sobre los recortes que vuelven del pozo, por clase de tamaño
##   (gruesos, medios, finos). Zarandas e hidrociclones; la centrífuga no, porque
##   trabaja sobre una derivación del activo (§7).
## - Por PASADA sobre el lodo del tanque: sólidos perforados ya dispersos,
##   barita y finos de cemento, en el caudal que procesa el equipo.

const TIPOS := ["zaranda", "desarenador", "deslimador", "centrifuga"]
const ESTADOS := ["bueno", "malla_rota", "conos_tapados"]
## Qué le queda al equipo según su estado. 🧩
const FACTOR_MALLA_ROTA := 0.3
const FACTOR_CONOS_TAPADOS := 0.2

@export var nombre := ""
@export_enum("zaranda", "desarenador", "deslimador", "centrifuga") var tipo := "zaranda"
@export_multiline var descripcion := ""
@export var punto_corte_um := 0.0
## Número de malla API (solo zarandas; 0 si no aplica).
@export var malla_api := 0
@export var actua_en_entrada := true

# --- Entrada: fracción removida de cada clase de recorte que le llega ---
@export var eficiencia_gruesos := 0.0
@export var eficiencia_medios := 0.0
@export var eficiencia_finos := 0.0

# --- Por pasada sobre el lodo del tanque ---
## Caudal que procesa (gpm). Los hidrociclones tienen su bomba; la centrífuga
## toma una derivación pequeña del activo (§7).
@export var caudal_gpm := 0.0
@export var eficiencia_perforados_lodo := 0.0
## Fracción de la barita procesada que va al descarte. Cerca de la mitad en el
## deslimador (§7); casi nada en la centrífuga, que la devuelve al activo.
@export var eficiencia_barita := 0.0
@export var eficiencia_finos_cemento := 0.0
## Fracción en volumen de sólidos en el descarte; el resto es lodo que se va
## pegado (en la zaranda, el lodo de los recortes húmedos; simulation-logic §10.1).
@export var solidos_en_descarte := 0.5
## Tope del descarte por pasada (bbl/h de underflow); 0 = sin tope. 🧩
@export var descarte_max_bbl_h := 0.0

# --- Estado en el taladro ---
@export var encendido := true
@export_enum("bueno", "malla_rota", "conos_tapados") var estado := "bueno"


## Multiplicador de todas las eficiencias según encendido y estado.
func factor() -> float:
	if not encendido:
		return 0.0
	match estado:
		"malla_rota":
			return FACTOR_MALLA_ROTA
		"conos_tapados":
			return FACTOR_CONOS_TAPADOS
	return 1.0


## Fracción removida de una clase de recorte en la entrada ("gruesos", "medios", "finos").
func eficiencia_entrada(clase: String) -> float:
	if not actua_en_entrada:
		return 0.0
	return clampf(get("eficiencia_" + clase) * factor(), 0.0, 1.0)


## bbl de lodo que se van con cada bbl de sólido descartado.
func lodo_por_bbl_solido() -> float:
	return (1.0 - solidos_en_descarte) / solidos_en_descarte
