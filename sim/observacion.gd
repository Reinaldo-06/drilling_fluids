class_name Observacion
extends Resource
## Una observación visual como dato (docs/game-design-mechanics.md,
## "Observación visual"). Es lo que el jugador ve al caminar por los tanques
## y las zarandas, sin entrar al laboratorio: la alarma entre chequeos.
##
## Regla de diseño: una observación puede decir que algo cambió y a veces qué
## familia de problema es. NUNCA identifica el contaminante químico; eso es
## trabajo del laboratorio (invariante 1). tests/test_observaciones.gd recorre
## todos los textos y lo verifica.
##
## Lee una sola variable del estado (método o variable de EstadoLodo) y la
## compara con "umbrales" ascendentes: el nivel es cuántos umbrales alcanza.
## Hay un texto por nivel, así que textos.size() == umbrales.size() + 1.

@export var id := ""
@export var nombre := ""
## Dónde se ve: "tanques", "caja_de_llegada", "zarandas".
@export var estaciones := PackedStringArray()
@export var variable := ""
@export var umbrales := PackedFloat64Array()
## Nombre corto de cada nivel (para la interfaz y las pruebas).
@export var niveles := PackedStringArray()
@export var textos := PackedStringArray()
## El nivel normal; cualquier otro es una alarma (también "fluido" en la viscosidad).
@export var nivel_normal := 0
## Si al llegar a la alarma hay que disparar un protocolo de seguridad.
@export var alerta_seguridad := false
## Qué sugiere, qué no dice y fuentes: nota de diseño, no se muestra al jugador.
@export_multiline var notas := ""


func valor(estado: Object) -> float:
	if estado.has_method(variable):
		return float(estado.call(variable))
	var v = estado.get(variable)
	assert(v != null, "Variable de observación desconocida: %s" % variable)
	return float(v)


func nivel(estado: Object) -> int:
	var x := valor(estado)
	var n := 0
	for u in umbrales:
		if x >= u:
			n += 1
	return n


func nombre_nivel(estado: Object) -> String:
	return niveles[nivel(estado)]


## Texto que ve el jugador con el estado actual.
func evaluar(estado: Object) -> String:
	return textos[nivel(estado)]


func es_alarma(estado: Object) -> bool:
	return nivel(estado) != nivel_normal


func visible_en(estacion: String) -> bool:
	return estacion in estaciones
