class_name Pozo
extends Resource
## Un pozo ficticio: sus secciones en orden de profundidad (docs/mud-programs.md,
## "Programas de pozo"). Cada sección es un ProgramaSeccion.

@export var nombre := ""
@export_multiline var descripcion := ""
## ProgramaSeccion en orden de profundidad.
@export var secciones: Array = []
@export_multiline var evento_guionado := ""


## La sección que corresponde a una profundidad (ft), o null fuera del pozo.
func seccion_a(profundidad_ft: float) -> Resource:
	for s in secciones:
		if profundidad_ft >= s.profundidad_desde and profundidad_ft < s.profundidad_hasta:
			return s
	if not secciones.is_empty() and is_equal_approx(profundidad_ft, secciones[-1].profundidad_hasta):
		return secciones[-1]
	return null
