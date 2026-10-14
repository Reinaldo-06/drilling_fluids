extends RefCounted
## Carga de imágenes y fuente que funciona con y sin el proyecto importado.
##
## Primero intenta leer el archivo crudo (así corren las pruebas `--headless`
## sin `--import`); si no está (por ejemplo, en un juego exportado) usa el
## recurso importado.

const RUTA_FUENTE := "res://assets/fuentes/fuente_pixel.fnt"

static var _cache_imagenes := {}
static var _fuente: Font = null


## Imagen del archivo, o null si no existe.
static func cargar_imagen(ruta: String) -> Image:
	if _cache_imagenes.has(ruta):
		return _cache_imagenes[ruta]
	var imagen: Image = null
	var absoluta := ProjectSettings.globalize_path(ruta)
	if FileAccess.file_exists(absoluta):
		imagen = Image.load_from_file(absoluta)
	elif ResourceLoader.exists(ruta):
		var tex := load(ruta) as Texture2D
		if tex != null:
			imagen = tex.get_image()
	if imagen != null:
		_cache_imagenes[ruta] = imagen
	return imagen


static func cargar_textura(ruta: String) -> Texture2D:
	var imagen := cargar_imagen(ruta)
	if imagen == null:
		return null
	return ImageTexture.create_from_image(imagen)


## Fuente pixel del juego (BMFont generada por tools/generar_tiles.py).
## Si falta, devuelve la fuente por defecto del tema.
static func fuente() -> Font:
	if _fuente != null:
		return _fuente
	var absoluta := ProjectSettings.globalize_path(RUTA_FUENTE)
	if FileAccess.file_exists(absoluta):
		var f := FontFile.new()
		if f.load_bitmap_font(absoluta) == OK:
			_fuente = f
	if _fuente == null and ResourceLoader.exists(RUTA_FUENTE):
		_fuente = load(RUTA_FUENTE) as Font
	if _fuente == null:
		_fuente = ThemeDB.fallback_font
	return _fuente


## Tamaño de letra con el que la fuente pixel se ve nítida.
const TAMANO_FUENTE := 10
