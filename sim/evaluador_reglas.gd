extends RefCounted
## Evalúa las reglas de data/reglas/ (sim/regla.gd) sobre una acción del jugador.
##
## Invariante 4: cada regla trae su predicado y su explicación como dato. Este
## script solo arma el contexto, corre la condición con la clase Expression de
## Godot y devuelve los hallazgos. No sabe nada de reglas concretas.
##
## Contexto de entrada (todas las claves son opcionales):
##   antes, despues, previo  EstadoLodo o diccionario de propiedades. Si falta
##                           "despues" se usa "antes" (al diagnosticar no hay
##                           cambio); si falta "previo" también.
##   accion                  diccionario; ver ACCION_POR_OMISION.
##   pruebas_corridas        ids de pruebas corridas en el turno (ver PRUEBAS).
##   programa                ProgramaSeccion o diccionario {sistema, rangos, aprobados}.
##   tratamientos_previos    ids de productos ya aplicados en el turno.
##   equipos                 equipo de control de sólidos → encendido (bool).
##
## Las funciones públicas de abajo (corrio, aprobado, sobre_maximo…) se pueden
## llamar desde las condiciones: Expression usa este objeto como base.

const Props := preload("res://sim/propiedades_lodo.gd")
const F := preload("res://sim/formulas.gd")

const CARPETA := "res://data/reglas"

const VARIABLES := ["antes", "despues", "previo", "accion", "pruebas_corridas",
	"programa", "tratamientos_previos", "equipos"]

## tipo: "tratar" (agregar producto; agua = diluir, barita = densificar),
##       "transferir", "equipo", "diagnosticar", "cerrar_dia".
const ACCION_POR_OMISION := {
	"tipo": "", "producto": "", "lb_bbl": 0.0, "volumen_bbl": 0.0,
	"prehidratada": false,
	"origen": "", "destino": "", "afecta_activo": false, "aviso_driller": false,
	"equipo": "", "encendido": false,
	"diagnostico": "",
}

## Ids de prueba que usan las condiciones. Deben coincidir con data/pruebas/.
## Ids de data/pruebas/ (tests/test_reglas.gd verifica que existan).
const PRUEBAS := ["balanza", "balanza_presurizada", "embudo_marsh", "fann", "geles",
	"filtrado_api", "ph", "pm", "pf_mf", "cloruros", "dureza", "retorta", "mbt",
	"calcio_magnesio", "ggt_sulfuros", "ggt_carbonatos", "potasio"]
## Pruebas que las reglas pueden pedir pero todavía no existen como dato.
const PRUEBAS_FUTURAS := ["amina"]

const ORDEN_TIPO := {"error": 0, "advertencia": 1, "consejo": 2}

## Mensajes de reglas mal escritas (condición que no compila o falla al correr).
var errores: Array[String] = []
## Si es false, los errores solo se guardan en "errores" (para pruebas).
var mostrar_errores := true

var _ctx: Dictionary = {}
var _hay_programa := false


## Carga todas las reglas de la carpeta.
static func cargar_catalogo(carpeta := CARPETA) -> Array:
	var reglas: Array = []
	for archivo in DirAccess.get_files_at(carpeta):
		archivo = archivo.trim_suffix(".remap")  # así se ven en un juego exportado
		if archivo.ends_with(".tres"):
			reglas.append(load("%s/%s" % [carpeta, archivo]))
	return reglas


## Reglas del momento dado que se disparan. Cada hallazgo es un diccionario
## {id, titulo, tipo, explicacion, referencia}; primero los errores.
func evaluar(reglas: Array, momento: String, contexto: Dictionary) -> Array:
	var hallazgos: Array = []
	for regla in reglas:
		if regla.momento != momento:
			continue
		if cumple(regla, contexto):
			hallazgos.append({
				"id": regla.id, "titulo": regla.titulo, "tipo": regla.tipo,
				"explicacion": regla.explicacion, "referencia": regla.referencia,
			})
	hallazgos.sort_custom(func(a, b): return ORDEN_TIPO[a["tipo"]] < ORDEN_TIPO[b["tipo"]])
	return hallazgos


## true si la condición de la regla vale en el contexto (sin mirar el momento).
func cumple(regla: Resource, contexto: Dictionary) -> bool:
	_ctx = normalizar(contexto)
	var expresion := Expression.new()
	if expresion.parse(regla.condicion, VARIABLES) != OK:
		_registrar_error(regla, "no compila: " + expresion.get_error_text())
		return false
	var valores: Array = []
	for nombre in VARIABLES:
		valores.append(_ctx[nombre])
	var resultado = expresion.execute(valores, self, false)
	if expresion.has_execute_failed():
		_registrar_error(regla, "falla al evaluar: " + expresion.get_error_text())
		return false
	if typeof(resultado) != TYPE_BOOL:
		_registrar_error(regla, "no devuelve bool sino %s" % type_string(typeof(resultado)))
		return false
	return resultado


## Contexto completo, con todas las claves, a partir de uno parcial.
func normalizar(contexto: Dictionary) -> Dictionary:
	var antes = contexto.get("antes")
	var ctx := {
		"antes": Props.de(antes),
		"despues": Props.de(contexto.get("despues", antes)),
		"previo": Props.de(contexto.get("previo", antes)),
		"pruebas_corridas": Array(contexto.get("pruebas_corridas", [])),
		"tratamientos_previos": Array(contexto.get("tratamientos_previos", [])),
		"equipos": Dictionary(contexto.get("equipos", {})),
	}
	var accion: Dictionary = ACCION_POR_OMISION.duplicate()
	accion.merge(contexto.get("accion", {}), true)
	ctx["accion"] = accion

	var programa = contexto.get("programa")
	_hay_programa = programa != null
	var prog := {"pozo": "", "seccion": "", "sistema": "", "rangos": {}, "aprobados": []}
	if programa is Dictionary:
		prog.merge(programa, true)
	elif programa != null:
		prog = programa.como_diccionario()
	ctx["programa"] = prog
	return ctx


# ======================= Funciones para las condiciones =======================

## ¿Se corrió esta prueba en el turno?
func corrio(prueba: String) -> bool:
	return prueba in _ctx["pruebas_corridas"]


func corrio_alguna(pruebas: Array) -> bool:
	for p in pruebas:
		if corrio(p):
			return true
	return false


## ¿El programa aprueba el producto? Sin programa todo está permitido.
func aprobado(producto: String) -> bool:
	if not _hay_programa:
		return true
	return producto in _ctx["programa"]["aprobados"]


## ¿El valor pasa el máximo del programa? false si el programa no fija esa propiedad.
func sobre_maximo(propiedad: String, valor: float) -> bool:
	var rangos: Dictionary = _ctx["programa"]["rangos"]
	return rangos.has(propiedad) and valor > float(rangos[propiedad][1]) + 1e-9


func bajo_minimo(propiedad: String, valor: float) -> bool:
	var rangos: Dictionary = _ctx["programa"]["rangos"]
	return rangos.has(propiedad) and valor < float(rangos[propiedad][0]) - 1e-9


## Cuántas propiedades de "despues" quedan fuera del programa.
func fuera_de_programa() -> int:
	var n := 0
	for propiedad: String in _ctx["programa"]["rangos"]:
		var valor: float = _ctx["despues"].get(propiedad, 0.0)
		if sobre_maximo(propiedad, valor) or bajo_minimo(propiedad, valor):
			n += 1
	return n


## Cuántas veces se aplicó el producto antes en el turno.
func veces_tratado(producto: String) -> int:
	return _ctx["tratamientos_previos"].count(producto)


## a / b sin dividir por cero (para relaciones como Mf/Pf).
func razon(a: float, b: float) -> float:
	return a / maxf(b, 0.01)


func encendido(equipo: String) -> bool:
	return bool(_ctx["equipos"].get(equipo, false))


## Dosis estequiométrica completa (lb/bbl) para eliminar el exceso de cal con
## el producto (mud-engineer-reference.md §1.2). INF si el producto no trata cemento.
func dosis_cemento(producto: String, pm: float, pf: float, fw: float) -> float:
	if not F.FACTOR_EXCESO_CAL.has(producto):
		return INF
	return F.dosis_por_exceso_de_cal(producto, F.exceso_de_cal(pm, pf, fw))


func _registrar_error(regla: Resource, mensaje: String) -> void:
	var texto := "Regla %s %s" % [regla.id, mensaje]
	errores.append(texto)
	if mostrar_errores:
		push_error(texto)
