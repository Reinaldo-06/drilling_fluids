class_name GuionSeccion
extends Resource
## Guion de una sección de pozo: los eventos que le pueden pasar, como dato.
##
## Es la parte "qué pasa" del nivel; el programa de lodos (sim/programa_seccion.gd)
## es la parte "qué se pide". Un guion nuevo = un .tres en data/guiones/ que
## referencia eventos de data/eventos/, sin tocar código (invariante 3).
## Lo ejecuta sim/guion_ejecucion.gd.

@export var id := ""
@export var pozo := ""
@export var seccion := ""
@export var profundidad_desde := 0.0   ## ft
@export var profundidad_hasta := 0.0   ## ft
@export_multiline var descripcion := ""
## Eventos (sim/evento.gd). El orden no importa: cada uno trae su disparador.
@export var eventos: Array = []


func evento(id_evento: String) -> Resource:
	for e in eventos:
		if e.id == id_evento:
			return e
	return null


## Eventos con disparador por profundidad, ordenados de arriba hacia abajo.
func por_profundidad() -> Array:
	var r: Array = eventos.filter(func(e): return e.disparador == "profundidad")
	r.sort_custom(func(a, b): return a.profundidad_ft < b.profundidad_ft)
	return r


## Problemas de datos del guion y de sus eventos (vacío si está bien).
func problemas() -> Array[String]:
	var p: Array[String] = []
	var ids := {}
	for e in eventos:
		if e == null:
			p.append("%s: evento nulo" % id)
			continue
		if ids.has(e.id):
			p.append("%s: evento repetido %s" % [id, e.id])
		ids[e.id] = true
		for x in e.problemas():
			p.append("%s/%s: %s" % [id, e.id, x])
		if e.disparador == "profundidad" and \
				(e.profundidad_ft < profundidad_desde or e.profundidad_ft > profundidad_hasta):
			p.append("%s/%s: profundidad fuera de la sección" % [id, e.id])
	return p
