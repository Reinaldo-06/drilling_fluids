extends RefCounted
## Foto de las propiedades de un lodo como diccionario plano.
##
## Es lo que ven las reglas (sim/evaluador_reglas.gd) y el programa de la sección
## (sim/programa_seccion.gd). Acepta un EstadoLodo o un diccionario parcial: lo
## que falte se completa con los valores por omisión, así una condición nunca
## falla por una clave ausente y las pruebas pueden armar escenarios a mano.
##
## Los nombres siguen el formato del programa de lodos (mud-programs.md):
## densidad (ppg), embudo (s/qt), vp (cP), pc (lb/100 ft²), geles, filtrado
## (ml/30 min), pH, alcalinidades (ml), iones (mg/l), sólidos (% vol).

const VALORES_POR_OMISION := {
	"densidad": 0.0, "embudo": 0.0, "vp": 0.0, "pc": 0.0, "va": 0.0,
	"gel_10s": 0.0, "gel_10min": 0.0, "filtrado": 0.0,
	"ph": 7.0, "pf": 0.0, "mf": 0.0, "pm": 0.0, "mf_carbonatos": 0.0,
	"oh": 0.0, "co3": 0.0, "hco3": 0.0,
	"ca": 0.0, "mg": 0.0, "cl": 0.0, "k": 0.0, "na": 0.0, "so4": 0.0, "sulfuro": 0.0,
	"cal_exceso": 0.0, "mbt": 0.0, "frac_barita": 0.0, "lgs_pct": 0.0, "solidos_pct": 0.0,
	"fw": 1.0, "floculacion": 0.0, "mg_oh2": 0.0,
}


## Diccionario completo de propiedades. `estado` puede ser un EstadoLodo,
## un diccionario (parcial o completo) o null (todo por omisión).
static func de(estado) -> Dictionary:
	var props: Dictionary = VALORES_POR_OMISION.duplicate()
	if estado == null:
		return props
	if estado is Dictionary:
		props.merge(estado, true)
		return props
	props["densidad"] = estado.densidad()
	props["embudo"] = estado.viscosidad_embudo()
	props["vp"] = estado.vp()
	props["pc"] = estado.pc()
	props["va"] = estado.va()
	props["gel_10s"] = estado.gel_10s()
	props["gel_10min"] = estado.gel_10min()
	props["filtrado"] = estado.filtrado_api()
	props["ph"] = estado.ph()
	props["pf"] = estado.pf()
	props["mf"] = estado.mf()
	props["pm"] = estado.pm()
	props["mf_carbonatos"] = estado.mf_carbonatos()
	for ion in ["oh", "co3", "hco3", "ca", "mg", "cl", "k", "na", "so4", "sulfuro",
			"cal_exceso", "frac_barita", "mg_oh2"]:
		props[ion] = estado.get(ion)
	props["mbt"] = estado.mbt()
	props["lgs_pct"] = estado.lgs_pct()
	props["solidos_pct"] = estado.solidos_pct()
	props["fw"] = estado.fw()
	props["floculacion"] = estado.floculacion()
	return props
