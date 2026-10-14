class_name Regla
extends Resource
## Una regla evaluable con su explicación, como dato (invariante 4).
##
## El predicado ("condicion") y el texto para el jugador ("explicacion") viven
## juntos en el mismo .tres de data/reglas/. Agregar una regla nueva = agregar
## un archivo, sin tocar código (invariante 3).
##
## "condicion" es una expresión de Godot (clase Expression) que se evalúa sobre
## el contexto que arma sim/evaluador_reglas.gd. Variables disponibles:
##   antes, despues  diccionarios de propiedades del lodo (sim/propiedades_lodo.gd)
##   previo          propiedades del chequeo anterior (para tendencias)
##   accion          lo que hizo el jugador (tipo, producto, lb_bbl, equipo…)
##   pruebas_corridas  ids de las pruebas corridas en el turno
##   programa        rangos y sistema de la sección (diccionario)
##   tratamientos_previos  productos ya aplicados en el turno
##   equipos         equipo de control de sólidos → encendido
## y las funciones auxiliares del evaluador (corrio, aprobado, sobre_maximo…).

## Identificador único; coincide con el nombre del archivo.
@export var id := ""
## Título corto para la interfaz y el debrief.
@export var titulo := ""
## "error": la acción empeora el lodo o rompe una regla dura del manual.
## "advertencia": la acción es dudosa o desperdicia producto.
## "consejo": hay una forma mejor de hacerlo.
@export_enum("error", "advertencia", "consejo") var tipo := "error"
## En qué momento del turno se evalúa.
@export_enum("al_tratar", "al_transferir", "al_cerrar_dia", "al_diagnosticar") var momento := "al_tratar"
## Expresión que vale true cuando la regla se dispara.
@export_multiline var condicion := ""
## Por qué está mal (o qué conviene), en español, para el jugador.
@export_multiline var explicacion := ""
## Las reglas se evalúan sobre lo que el jugador MIDIÓ (Props.de_medido): una
## regla nunca revela lo que nadie midió (invariante 1). Si además esto es true,
## la regla se revisa contra el estado real; si ahí se dispara y con lo medido
## no, queda solo para el debrief ("lo que de verdad había"), sin aviso
## inmediato.
@export var debrief_real := false
## Sección de docs/ de donde sale la regla.
@export var referencia := ""
