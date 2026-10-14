extends "res://tests/test_case.gd"
## La Tabla 4 del manual (mud-engineer-reference.md §1.1) como batería de pruebas.
##
## Para cada contaminante: se parte del lodo base, se aplica el contaminante y
## cada propiedad tiene que moverse en el sentido de la flecha de la tabla.
## "=" es "—" en la tabla: sin cambio apreciable.
## Si esta prueba falla, el modelo está mal, no la tabla.

const Base := preload("res://sim/lodos_base.gd")

const COLUMNAS := ["fv", "vp", "pc", "geles", "filtrado", "ph", "pm", "pf", "mf", "cl", "ca", "solidos"]

## Cambio mínimo para contar como "sube" o "baja" (unidades de cada columna).
## Pm va con 0,05 ml: es una titulación de lodo entero (se lee al 0,05–0,1 ml) y
## los sólidos inertes la bajan apenas al quitar agua (Pf·Fw), sin que nadie lo vea.
const UMBRAL := {
	"fv": 1.0, "vp": 0.5, "pc": 0.5, "geles": 0.5, "filtrado": 0.3, "ph": 0.05,
	"pm": 0.05, "pf": 0.02, "mf": 0.02, "cl": 50.0, "ca": 10.0, "solidos": 0.1,
}

## archivo, cantidad aplicada, flechas en el orden de COLUMNAS.
const TABLA := [
	["cemento", 0.5,     ["+", "=", "+", "+", "+", "+", "+", "+", "+", "=", "+", "="]],
	["yeso", 1.0,        ["+", "=", "+", "+", "+", "-", "-", "-", "-", "=", "+", "="]],
	["sal", 12.0,        ["+", "=", "+", "+", "+", "-", "-", "-", "-", "+", "+", "="]],
	["carbonatos", 9000.0, ["+", "=", "+", "+", "+", "-", "-", "+", "+", "=", "-", "="]],
	["h2s", 400.0,       ["+", "=", "+", "+", "+", "-", "-", "-", "-", "=", "+", "="]],
	["solidos_perforados", 2.0, ["+", "+", "=", "+", "=", "=", "=", "=", "=", "=", "=", "+"]],
]


func _medir(lodo) -> Dictionary:
	return {
		"fv": lodo.viscosidad_embudo(), "vp": lodo.vp(), "pc": lodo.pc(),
		"geles": lodo.gel_10s(), "filtrado": lodo.filtrado_api(), "ph": lodo.ph(),
		"pm": lodo.pm(), "pf": lodo.pf(), "mf": lodo.mf(), "cl": lodo.cl,
		"ca": lodo.ca, "solidos": lodo.solidos_pct(),
	}


func test_firmas_coinciden_con_tabla_4() -> void:
	for fila in TABLA:
		var contaminante: Resource = load("res://data/contaminantes/%s.tres" % fila[0])
		var lodo = Base.disperso_lignosulfonato()
		var antes := _medir(lodo)
		contaminante.aplicar(lodo, fila[1])
		var despues := _medir(lodo)
		for i in COLUMNAS.size():
			var col: String = COLUMNAS[i]
			var delta: float = despues[col] - antes[col]
			var signo := "="
			if delta > UMBRAL[col]:
				signo = "+"
			elif delta < -UMBRAL[col]:
				signo = "-"
			verificar(signo == fila[2][i],
				"%s / %s: tabla %s, simulación %s (%.3f → %.3f)" % [fila[0], col, fila[2][i], signo, antes[col], despues[col]])


func test_sintomas_fisicos_no_distinguen_contaminantes_quimicos() -> void:
	# Invariante 1: todos los químicos suben FV, PC, geles y filtrado y no tocan la VP.
	for fila in TABLA:
		if fila[0] == "solidos_perforados":
			continue
		verificar(fila[2].slice(0, 5) == ["+", "=", "+", "+", "+"],
			"%s: la firma física de la tabla debería ser la misma para todos" % fila[0])
