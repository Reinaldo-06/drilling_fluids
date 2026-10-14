extends Resource
## Tabla de valores de diseño del turno como dato (invariante 3): tiempos de
## las acciones, distancias entre estaciones y costo de los productos viven en
## data/turno/*.tres y se calibran sin tocar código. Todos son 🧩.

@export var id := ""
@export_multiline var descripcion := ""
@export var valores: Dictionary = {}


func valor(clave: String, por_omision = null):
	return valores.get(clave, por_omision)
