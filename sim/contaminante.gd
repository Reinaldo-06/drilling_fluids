class_name Contaminante
extends Resource
## Un contaminante como dato (invariante 3). Agregar uno nuevo = un .tres en
## data/contaminantes/, sin tocar código.
##
## "aportes" dice qué le hace a la composición por unidad que entra; las claves
## las interpreta EstadoLodo.aplicar_aportes(). Los síntomas no se declaran:
## salen solos de la composición, y tests/test_tabla4.gd verifica que coincidan
## con la Tabla 4 del manual.

@export var nombre := ""
@export_multiline var descripcion := ""
## Unidad en que se mide "cantidad" al aplicarlo (para la interfaz y el guion del nivel).
@export var unidad := ""
@export var aportes: Dictionary = {}


func aplicar(estado: RefCounted, cantidad: float) -> void:
	estado.aplicar_aportes(aportes, cantidad)
