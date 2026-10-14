class_name SistemaLodo
extends Resource
## Un sistema de lodo base agua del catálogo (docs/mud-programs.md, "Catálogo de
## sistemas base agua"), como dato. Los programas de sección (sim/programa_seccion.gd)
## lo nombran por id y fijan sus propios rangos; los de aquí son los típicos.

@export var id := ""
@export var nombre := ""
@export var seccion_tipica := ""
## Aditivo → [mín, máx] lb/bbl. Las claves son ids de data/productos/ cuando el
## producto existe; si no, el nombre previsto (p. ej. "phpa", "almidon").
@export var aditivos: Dictionary = {}
## Propiedad → [mín, máx] típicos del sistema (claves de sim/propiedades_lodo.gd).
@export var rangos_tipicos: Dictionary = {}
@export_multiline var fuerte_en := ""
@export_multiline var debil_en := ""
@export_multiline var nota_de_juego := ""
## Contaminante → "tolerado" | "leve" | "moderado" | "alto" | "critico" | "inmune"
## (tabla de vulnerabilidades cruzadas de mud-programs.md).
@export var vulnerabilidades: Dictionary = {}
