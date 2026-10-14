extends Node2D
## Escena de arranque: hoy abre directo el overworld de la locación.
## Aquí se conectarán el gestor de turno (señal `caminado`) y las pantallas de
## cada estación (señal `interactuado`).

@onready var overworld: Node2D = $Overworld
