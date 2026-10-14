extends Node2D
## Una estación del overworld: un lugar del taladro con el que se interactúa
## mirándolo y apretando la tecla de interactuar. Solo guarda datos; la
## reacción la decide quien escuche `overworld.interactuado(id)`.

var id := ""
var nombre := ""
## Grupo para datos generales ("tanques", "valvulas", "embudos"...).
var grupo := ""
## Texto corto que se muestra al interactuar mientras no haya pantalla propia.
var texto := ""
## Casillas sólidas que ocupa la estación.
var celdas: Array[Vector2i] = []
## Casillas transitables donde se paran los personajes de esta estación.
var puestos: Array[Vector2i] = []


func es_valvula() -> bool:
	return grupo == "valvulas"
