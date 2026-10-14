extends RefCounted
## Lodos de partida. Valores plausibles para pozos ficticios (mud-programs.md).

const EstadoLodoScript := preload("res://sim/estado_lodo.gd")


## Disperso con lignosulfonato, ~9 ppg, pH 10 (mud-programs.md, sistema 2).
## Lleva un poco de cal sin disolver de tratamientos anteriores, como es común.
static func disperso_lignosulfonato() -> EstadoLodoScript:
	var lodo := EstadoLodoScript.new()
	lodo.bentonita = 12.0
	lodo.frac_lgs = 0.043          # bentonita + sólidos perforados viejos
	lodo.lignosulfonato = 2.0
	lodo.pac = 0.5
	lodo.cal_exceso = 0.2
	lodo.ca = 120.0
	lodo.na = 650.0
	lodo.cl = 1000.0
	# pH 10 con la soda justa: deja OH⁻ ≈ 1,7 mg/l y el tampón del lignosulfonato
	# y la bentonita cargado (es lo que da Pf y Mf; ver EstadoLodo).
	lodo.fijar_ph(10.0)
	return lodo
