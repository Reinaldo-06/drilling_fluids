extends RefCounted
## Inventario de la bodega de químicos y costo de lo gastado
## (simulation-logic.md §9: productos usados, inventario, costo del día y
## acumulado). En sacos de cada producto (el tamaño del saco está en su .tres);
## el agua va en bbl y no se acaba.
##
## Costo por saco: data/turno/costos_productos.tres (🧩 valores ficticios).

const COSTOS := preload("res://data/turno/costos_productos.tres")
const CARPETA_PRODUCTOS := "res://data/productos"

## Producto que no se acaba (agua del taladro).
const ILIMITADOS := ["agua"]

## producto → sacos disponibles.
var sacos: Dictionary = {}
## producto → sacos gastados en el turno en curso.
var usados_turno: Dictionary = {}
var costo_turno := 0.0
var costo_acumulado := 0.0
## 🧩 Presupuesto de la sección (USD); 0 = sin presupuesto.
var presupuesto := 0.0

var _productos := {}


static func cargar_producto(id: String) -> Resource:
	var ruta := "%s/%s.tres" % [CARPETA_PRODUCTOS, id]
	if not ResourceLoader.exists(ruta):
		return null
	return load(ruta)


func producto(id: String) -> Resource:
	if not _productos.has(id):
		_productos[id] = cargar_producto(id)
	return _productos[id]


func agregar(id: String, cantidad: float) -> void:
	sacos[id] = float(sacos.get(id, 0.0)) + cantidad


func disponible(id: String) -> float:
	if id in ILIMITADOS:
		return INF
	return float(sacos.get(id, 0.0))


func costo_por_saco(id: String) -> float:
	return float(COSTOS.valor(id, 0.0))


## Saca hasta "cantidad" sacos (bbl si es agua) y suma su costo.
## Devuelve lo que realmente sacó (puede ser menos si no alcanza).
func consumir(id: String, cantidad: float) -> float:
	var sale := minf(maxf(cantidad, 0.0), disponible(id))
	if sale <= 0.0:
		return 0.0
	if not id in ILIMITADOS:
		sacos[id] = disponible(id) - sale
	usados_turno[id] = float(usados_turno.get(id, 0.0)) + sale
	var costo := sale * costo_por_saco(id)
	costo_turno += costo
	costo_acumulado += costo
	return sale


## [{producto, sacos, costo, quedan}] de lo gastado en el turno, por nombre.
func productos_del_turno() -> Array:
	var lista := []
	var ids := usados_turno.keys()
	ids.sort()
	for id in ids:
		lista.append({
			"producto": id,
			"sacos": usados_turno[id],
			"unidad": "bbl" if id in ILIMITADOS else "sacos",
			"costo": usados_turno[id] * costo_por_saco(id),
			"quedan": disponible(id),
		})
	return lista


## Cierra la cuenta del turno (el acumulado sigue).
func cerrar_turno() -> void:
	usados_turno.clear()
	costo_turno = 0.0


func sobre_presupuesto() -> bool:
	return presupuesto > 0.0 and costo_acumulado > presupuesto
