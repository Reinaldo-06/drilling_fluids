extends Node2D
## Escena de arranque: el overworld de la locación con el turno de CAIMÁN-3
## (superficial) conectado. Las señales del mapa pasan por game/puente_turno.gd
## a la sesión (sim/sesion_turno.gd); el escenario sale de sim/escenarios.gd.

const Escenarios := preload("res://sim/escenarios.gd")
const Puente := preload("res://game/puente_turno.gd")

@onready var overworld: Node2D = $Overworld

var escenario: Dictionary
var puente: Node


func _ready() -> void:
	escenario = Escenarios.caiman_3_superficial()
	puente = Puente.new()
	puente.name = "PuenteTurno"
	add_child(puente)
	puente.conectar(overworld, escenario["sesion"])
