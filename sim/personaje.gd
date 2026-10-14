class_name Personaje
extends Resource
## Un personaje (jugador o NPC) como dato. Diseño en docs/personajes.md.
##
## No depende de nada de escena: la presentación lee "estacion" para ubicarlo
## en el mapa, "hoja" para el sprite y llama a lineas() para llenar la caja de
## diálogo. Agregar un personaje = agregar un .tres en data/personajes/ y su
## hoja en assets/personajes/ (invariante 3).
##
## Regla de diseño (invariante 1): ningún personaje identifica un contaminante
## químico a partir de síntomas. Pueden contar lo que ven o lo que saben de la
## operación, nunca diagnosticar por el jugador. tests/test_personajes.gd lo
## verifica sobre todos los textos.

## Estaciones del overworld donde un personaje suele estar.
const ESTACIONES := [
	"piso_perforacion", "tanques", "oficina", "cabina_mud_logger",
	"caseta_lodos", "zarandas", "bodega",
]
## Situación por defecto cuando la pedida no existe.
const SITUACION_POR_DEFECTO := "saludo"
## Límite de la caja de diálogo a 240×160 px: 2 líneas de 32 caracteres.
const CARACTERES_POR_LINEA := 32
const LINEAS_POR_PAGINA := 2

## Identificador único; coincide con el nombre del archivo y del PNG.
@export var id := ""
## Nombre que se muestra en la caja de diálogo.
@export var nombre := ""
## Rol en el taladro (texto para la interfaz).
@export var rol := ""
## Id de la estación donde suele estar (ver ESTACIONES).
@export var estacion := ""
## Hoja de sprites 48×128 (3 columnas × 4 filas de 16×32).
@export var hoja := ""
## Retrato opcional para la caja de diálogo; vacío si no hay.
@export var retrato := ""
## Situación → páginas de la caja de diálogo (Array de String).
@export var dialogos: Dictionary = {}
## Personalidad y notas de diseño; no se muestra al jugador.
@export_multiline var notas := ""


func tiene(situacion: String) -> bool:
	return dialogos.has(situacion)


## Páginas para una situación, con {variables} reemplazadas desde "contexto".
## Cae en "saludo" si la situación no existe. Una variable que no está en el
## contexto se deja tal cual, para que se note en las pruebas.
func lineas(situacion: String, contexto := {}) -> Array:
	var clave := situacion if dialogos.has(situacion) else SITUACION_POR_DEFECTO
	var paginas: Array = dialogos.get(clave, [])
	var salida := []
	for pagina in paginas:
		var texto := String(pagina)
		for variable in contexto:
			texto = texto.replace("{%s}" % variable, str(contexto[variable]))
		salida.append(texto)
	return salida


## Parte un texto en líneas de a lo sumo "ancho" caracteres, por palabras.
## Lo usa la caja de diálogo y las pruebas del límite de página.
static func partir_en_lineas(texto: String, ancho := CARACTERES_POR_LINEA) -> PackedStringArray:
	var lineas_salida := PackedStringArray()
	var actual := ""
	for palabra in texto.split(" ", false):
		if actual.is_empty():
			actual = palabra
		elif actual.length() + 1 + palabra.length() <= ancho:
			actual += " " + palabra
		else:
			lineas_salida.append(actual)
			actual = palabra
	if not actual.is_empty():
		lineas_salida.append(actual)
	return lineas_salida
