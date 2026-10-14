extends RefCounted
## Reporte diario de lodo: el cierre del día (simulation-logic.md §9;
## game-design-mechanics.md, paso 8 del ciclo).
##
## Se llena SOLO con lo que el jugador midió: una prueba que no corrió deja la
## casilla vacía (null), visible para el company man. Incluye la comparación con
## el programa de la sección, el balance de volumen, productos y costo, horas de
## equipos y temperatura (los llenan los enganches de otros sistemas) y las
## recomendaciones que el jugador deja para el turno de noche.

const Props := preload("res://sim/propiedades_lodo.gd")
const Noche := preload("res://sim/turno_noche.gd")

## Filas de propiedades del reporte, en el orden del formato de campo.
## [clave del reporte, nombre, unidad, prueba que la mide]. La clave es la de
## la lectura del instrumento (data/pruebas/), salvo las de LECTURA_A_CLAVE.
const FILAS := [
	["densidad", "Densidad", "ppg", "balanza"],
	["embudo", "Viscosidad de embudo", "s/qt", "embudo_marsh"],
	["fann_600", "Lectura 600", "dial", "fann"],
	["fann_300", "Lectura 300", "dial", "fann"],
	["fann_6", "Lectura 6", "dial", "fann"],
	["fann_3", "Lectura 3", "dial", "fann"],
	["vp", "VP", "cP", "fann"],
	["pc", "PC (YP)", "lb/100 ft²", "fann"],
	["va", "VA", "cP", "fann"],
	["gel_10s", "Gel 10 s", "lb/100 ft²", "geles"],
	["gel_10min", "Gel 10 min", "lb/100 ft²", "geles"],
	["filtrado", "Filtrado API", "ml/30 min", "filtrado_api"],
	["ph", "pH", "", "ph"],
	["pm", "Pm", "ml", "pm"],
	["pf", "Pf", "ml", "pf_mf"],
	["mf", "Mf", "ml", "pf_mf"],
	["cl", "Cloruros", "mg/l", "cloruros"],
	["ca", "Calcio", "mg/l", "dureza"],
	["dureza_total", "Dureza total (como Ca)", "mg/l", "calcio_magnesio"],
	["mg", "Magnesio", "mg/l", "calcio_magnesio"],
	["k", "Potasio (K⁺)", "mg/l", "potasio"],
	["mbt", "MBT", "lb/bbl", "mbt"],
	["agua_pct", "Agua (retorta)", "%", "retorta"],
	["aceite_pct", "Aceite (retorta)", "%", "retorta"],
	["solidos_pct", "Sólidos (retorta)", "%", "retorta"],
	["fw", "Fw", "", "retorta"],
	["carbonatos_totales", "Carbonatos (GGT)", "mg/l", "ggt_carbonatos"],
	["sulfuros", "Sulfuros (GGT)", "mg/l", "ggt_sulfuros"],
]

## Lecturas del instrumento cuyo nombre no coincide con la clave del reporte
## (que es la de sim/propiedades_lodo.gd, para comparar con el programa).
const LECTURA_A_CLAVE := {"viscosidad_embudo": "embudo", "filtrado_api": "filtrado"}

## 🧩 Diferencia de volumen que se acepta como error de lectura de niveles.
const TOLERANCIA_BALANCE_BBL := 2.0

var dia := 1
var pozo := ""
var seccion := ""
var profundidad_ft := 0.0
## Horas que cubre: 24 (noche anterior + turno de día) o 12 el primer día.
## Volumen, productos y costo son de todo ese período (decisión del autor).
var horas := 12.0
## Minuto del turno en que se entregó.
var minuto_entrega := 0.0
## true si se entregó con el turno ya terminado.
var tarde := false

## clave → valor medido (última medición del turno) o null si no se midió.
var propiedades: Dictionary = {}
## clave → {minuto, tanque, prueba} de la medición usada.
var origen: Dictionary = {}
## Claves sin medir (casillas vacías).
var casillas_vacias: Array = []
## Propiedades que el programa especifica y no se midieron: el company man las pregunta.
var sin_medir_del_programa: Array = []
## Entradas de ProgramaSeccion.fuera_de_especificacion, solo de lo medido.
var fuera_de_especificacion: Array = []

## Ver balance_volumen().
var volumen: Dictionary = {}

## [{producto, sacos, unidad, costo, quedan}]
var productos: Array = []
var costo_dia := 0.0
var costo_acumulado := 0.0
var presupuesto := 0.0

var horas_equipos: Dictionary = {}
## {"entrada": °F o null, "salida": °F o null}
var temperatura: Dictionary = {}

## Lista estructurada (ver sim/turno_noche.gd, TIPOS).
var recomendaciones: Array = []
## Recomendaciones mal formadas: [{recomendacion, error}]
var recomendaciones_invalidas: Array = []

## Hallazgos de las reglas "al_cerrar_dia".
var hallazgos_cierre: Array = []
## Todos los hallazgos del turno (aviso inmediato y debrief).
var hallazgos_turno: Array = []
## Resumen del turno de noche anterior (sim/turno_noche.gd), si lo hubo.
var noche_anterior: Dictionary = {}


## Valores medidos (sin casillas vacías) a partir de las mediciones del turno.
## mediciones: [{prueba, tanque, minuto, lecturas}] en orden de tiempo.
static func medidos(mediciones: Array) -> Dictionary:
	var valores := {}
	for m: Dictionary in mediciones:
		for lectura: String in m["lecturas"]:
			var clave: String = LECTURA_A_CLAVE.get(lectura, lectura)
			valores[clave] = m["lecturas"][lectura]
	return valores


## Balance de volumen (§9): inicial + construido − hueco − descarte − pérdidas
## − derrame = final esperado. Si el medido no cuadra, hay una pérdida (o una
## ganancia) que nadie vio.
static func balance_volumen(cuentas: Dictionary, final_medido: float) -> Dictionary:
	var b := {
		"inicial": float(cuentas.get("inicial", 0.0)),
		"construido": float(cuentas.get("construido", 0.0)),
		"hueco": float(cuentas.get("hueco", 0.0)),
		"descarte": float(cuentas.get("descarte", 0.0)),
		"perdidas": float(cuentas.get("perdidas", 0.0)),
		"derrame": float(cuentas.get("derrame", 0.0)),
	}
	b["final_esperado"] = b["inicial"] + b["construido"] - b["hueco"] - b["descarte"] \
		- b["perdidas"] - b["derrame"]
	b["final_medido"] = final_medido
	b["no_explicado"] = final_medido - b["final_esperado"]
	b["cuadra"] = absf(b["no_explicado"]) <= TOLERANCIA_BALANCE_BBL
	return b


## Arma el reporte con lo que el turno registró.
## turno: sim/turno.gd. recomendaciones: lista de sim/turno_noche.gd.
static func desde_turno(turno: RefCounted, recomendaciones: Array) -> RefCounted:
	var r = load("res://sim/reporte_diario.gd").new()
	r.dia = turno.dia
	r.profundidad_ft = turno.profundidad_ft
	r.minuto_entrega = turno.reloj.minuto
	r.horas = turno.horas_periodo
	var programa: Resource = turno.programa
	if programa != null:
		r.pozo = programa.pozo
		r.seccion = programa.seccion

	var valores := medidos(turno.mediciones)
	for m: Dictionary in turno.mediciones:
		for lectura: String in m["lecturas"]:
			r.origen[LECTURA_A_CLAVE.get(lectura, lectura)] = {
				"minuto": m["minuto"], "tanque": m["tanque"], "prueba": m["prueba"]}
	for fila in FILAS:
		var clave: String = fila[0]
		r.propiedades[clave] = valores.get(clave)
		if not valores.has(clave):
			r.casillas_vacias.append(clave)

	if programa != null:
		for p in programa.fuera_de_especificacion(valores):
			if valores.has(p["propiedad"]):
				r.fuera_de_especificacion.append(p)
		for propiedad in programa.rangos:
			if not valores.has(propiedad):
				r.sin_medir_del_programa.append(propiedad)

	r.volumen = balance_volumen(turno.volumen, turno.volumen_superficie())
	r.productos = turno.inventario.productos_del_turno()
	r.costo_dia = turno.inventario.costo_turno
	r.costo_acumulado = turno.inventario.costo_acumulado
	r.presupuesto = turno.inventario.presupuesto
	r.horas_equipos = turno.horas_equipos.duplicate()
	r.temperatura = turno.temperatura.duplicate()

	for rec in recomendaciones:
		var error := Noche.validar(rec, turno)
		if error == "":
			r.recomendaciones.append(rec)
		else:
			r.recomendaciones_invalidas.append({"recomendacion": rec, "error": error})
	r.noche_anterior = turno.resumen_noche_anterior
	return r


func medida(clave: String):
	return propiedades.get(clave)


func vacia(clave: String) -> bool:
	return clave in casillas_vacias


## Texto plano para depurar o para un primer prototipo de interfaz.
func texto() -> String:
	var lineas := PackedStringArray()
	lineas.append("REPORTE DIARIO DE LODO — %s %s — día %d (%.0f h) — %.0f ft" % [pozo, seccion, dia, horas, profundidad_ft])
	for fila in FILAS:
		var v = propiedades.get(fila[0])
		lineas.append("  %-24s %s %s" % [fila[1], "—" if v == null else str(v), fila[2]])
	for f in fuera_de_especificacion:
		lineas.append("  FUERA: " + f["texto"])
	lineas.append("Volumen: inicial %.1f + construido %.1f − hueco %.1f − descarte %.1f − pérdidas %.1f − derrame %.1f = %.1f (medido %.1f)" % [
		volumen["inicial"], volumen["construido"], volumen["hueco"], volumen["descarte"],
		volumen["perdidas"], volumen["derrame"], volumen["final_esperado"], volumen["final_medido"]])
	if not volumen["cuadra"]:
		lineas.append("  ¡No cuadra por %.1f bbl!" % volumen["no_explicado"])
	for p in productos:
		lineas.append("  %s: %.1f %s, USD %.0f" % [p["producto"], p["sacos"], p["unidad"], p["costo"]])
	lineas.append("Costo del período USD %.0f, acumulado USD %.0f" % [costo_dia, costo_acumulado])
	for rec in recomendaciones:
		lineas.append("  Recomendación: " + Noche.describir(rec))
	return "\n".join(lineas)
