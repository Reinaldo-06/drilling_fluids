class_name Producto
extends Resource
## Un producto del inventario como dato (invariante 3 y 6). El programa de lodos
## de cada sección lista qué productos están aprobados; quitar uno sube la
## dificultad sin tocar la simulación.
##
## Cómo actúa sobre el lodo lo dice "efecto":
## - "quimico": se disuelve y reacciona según "reaccion" (por mol de producto,
##   ver EstadoLodo.agregar_quimico) y "peso_molecular".
## - "cal": Ca(OH)₂, se disuelve hasta saturar y el resto queda en exceso.
## - "barita", "bentonita": suman volumen de sólidos.
## - "aditivo": suma lb/bbl al campo "aditivo" del estado (lignosulfonato, pac, xc).
## - "agua": diluye; la cantidad va en bbl por bbl de lodo.

@export var nombre := ""
@export_multiline var descripcion := ""
@export_enum("quimico", "cal", "barita", "bentonita", "aditivo", "agua") var efecto := "quimico"
@export var aditivo := ""
@export var peso_molecular := 0.0
@export var reaccion: Dictionary = {}
## Para el tiempo de mezcla en el embudo (50 sacos/h con el encuellador).
@export var lb_por_saco := 50.0


func aplicar(estado: RefCounted, cantidad: float) -> void:
	match efecto:
		"quimico":
			estado.agregar_quimico(reaccion, peso_molecular, cantidad)
		"cal":
			estado.agregar_cal(cantidad)
		"barita":
			estado.agregar_barita(cantidad)
		"bentonita":
			estado.agregar_bentonita(cantidad)
		"aditivo":
			estado.agregar_aditivo(aditivo, cantidad)
		"agua":
			estado.agregar_agua(cantidad)


## Sacos para tratar un volumen (bbl) a una concentración (lb/bbl).
func sacos(volumen_bbl: float, lb_bbl: float) -> float:
	return volumen_bbl * lb_bbl / lb_por_saco
