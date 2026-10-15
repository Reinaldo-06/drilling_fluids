class_name Caso
extends Resource
## Un caso jugable como dato (invariantes 3 y 4): una alarma, sus causas
## plausibles, la evidencia que permite distinguirlas, el tratamiento y cuándo
## se da por resuelto. Cada causa lleva su explicación; el juego explica el
## porqué tanto si aciertas como si fallas.
##
## El caso no sabe nada de la simulación: sim/seguimiento_caso.gd lleva el
## avance del jugador contra estos datos.

@export var id := ""
@export var titulo := ""
## Lo que ve el jugador al empezar el turno (resumen en la oficina).
@export_multiline var objetivo := ""
## Causas plausibles de la alarma: [{id, nombre, correcta (bool), explicacion}].
## "explicacion" dice por qué sí o por qué no, en función de la evidencia.
@export var causas: Array = []
## Evidencia que hay que reunir antes de diagnosticar. Ids: "balance_volumen"
## (el mud logger), "recortes" (las zarandas) y "niveles" (los tanques).
@export var evidencias_requeridas: PackedStringArray = []
## Nombre de cada evidencia, para decirle al jugador cuál le falta.
@export var nombres_de_evidencia: Dictionary = {}
@export_multiline var explicacion_sin_evidencia := ""
## Pérdida (bbl/h) por debajo de la cual se da por controlada.
@export var tasa_objetivo_bbl_h := 4.0
## Productos que cuentan como tratamiento del caso.
@export var productos_de_tratamiento: PackedStringArray = []
@export_multiline var explicacion_tratamiento_insuficiente := ""
@export_multiline var explicacion_exito := ""
@export var referencia := ""


func causa(id_causa: String) -> Dictionary:
	for c: Dictionary in causas:
		if c["id"] == id_causa:
			return c
	return {}


func causa_correcta() -> Dictionary:
	for c: Dictionary in causas:
		if c["correcta"]:
			return c
	return {}
