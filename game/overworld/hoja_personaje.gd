extends RefCounted
## Contrato de sprites con el agente I (personajes):
## `assets/personajes/<id>.png`, hoja de 3 columnas x 4 filas, cuadro 16x32
## (hoja 48x128). Columnas: quieto, paso A, paso B. Filas: abajo, izquierda,
## derecha, arriba.
##
## Si el PNG no existe (o no tiene el tamaño del contrato) se genera un
## marcador de posición: un muñeco de color con la dirección marcada, y el
## personaje lleva encima su inicial.

const Recursos := preload("res://game/overworld/recursos.gd")

const ANCHO_CUADRO := 16
const ALTO_CUADRO := 32
const COLUMNAS := 3
const FILAS := 4
const FILA_ABAJO := 0
const FILA_IZQUIERDA := 1
const FILA_DERECHA := 2
const FILA_ARRIBA := 3

const COLORES := {
	"jugador": Color8(232, 120, 48),
	"driller": Color8(64, 112, 184),
	"encuellador": Color8(72, 152, 88),
	"company_man": Color8(232, 232, 224),
	"mud_logger": Color8(152, 96, 168),
	"toolpusher": Color8(208, 64, 56),
	"cuadrillero": Color8(224, 184, 56),
}


static func ruta(id: String) -> String:
	return "res://assets/personajes/%s.png" % id


static func fila_de(direccion: Vector2i) -> int:
	match direccion:
		Vector2i.LEFT:
			return FILA_IZQUIERDA
		Vector2i.RIGHT:
			return FILA_DERECHA
		Vector2i.UP:
			return FILA_ARRIBA
	return FILA_ABAJO


## Devuelve {"imagen": Image, "marcador": bool}.
static func cargar(id: String) -> Dictionary:
	var imagen := Recursos.cargar_imagen(ruta(id))
	if imagen != null and imagen.get_width() == ANCHO_CUADRO * COLUMNAS \
			and imagen.get_height() == ALTO_CUADRO * FILAS:
		return {"imagen": imagen, "marcador": false}
	return {"imagen": marcador(id), "marcador": true}


static func inicial(id: String) -> String:
	if id == "company_man":
		return "C"
	if id == "mud_logger":
		return "M"
	return id.substr(0, 1).to_upper()


## Hoja de marcador con el mismo formato del contrato.
static func marcador(id: String) -> Image:
	var color: Color = COLORES.get(id, Color8(160, 160, 160))
	var oscuro := color.darkened(0.35)
	var contorno := Color8(40, 36, 48)
	var piel := Color8(236, 196, 156)
	var casco := Color8(248, 248, 240) if id != "company_man" else Color8(232, 200, 64)
	var img := Image.create(ANCHO_CUADRO * COLUMNAS, ALTO_CUADRO * FILAS, false, Image.FORMAT_RGBA8)
	for fila in FILAS:
		for col in COLUMNAS:
			var x0 := col * ANCHO_CUADRO
			var y0 := fila * ALTO_CUADRO
			# piernas: en los pasos una se adelanta
			var dy_izq := -1 if col == 1 else 0
			var dy_der := -1 if col == 2 else 0
			_rect(img, x0 + 4, y0 + 24 + dy_izq, x0 + 7, y0 + 30 + dy_izq, contorno)
			_rect(img, x0 + 8, y0 + 24 + dy_der, x0 + 11, y0 + 30 + dy_der, contorno)
			_rect(img, x0 + 5, y0 + 24 + dy_izq, x0 + 6, y0 + 29 + dy_izq, Color8(64, 72, 104))
			_rect(img, x0 + 9, y0 + 24 + dy_der, x0 + 10, y0 + 29 + dy_der, Color8(64, 72, 104))
			# cuerpo (overol)
			_rect(img, x0 + 3, y0 + 15, x0 + 12, y0 + 25, contorno)
			_rect(img, x0 + 4, y0 + 16, x0 + 11, y0 + 24, color)
			_rect(img, x0 + 4, y0 + 22, x0 + 11, y0 + 22, oscuro)
			# cabeza y casco
			_rect(img, x0 + 4, y0 + 7, x0 + 11, y0 + 15, contorno)
			_rect(img, x0 + 5, y0 + 9, x0 + 10, y0 + 14, piel)
			_rect(img, x0 + 3, y0 + 5, x0 + 12, y0 + 9, contorno)
			_rect(img, x0 + 4, y0 + 6, x0 + 11, y0 + 8, casco)
			# hacia dónde mira
			match fila:
				FILA_ABAJO:
					img.set_pixel(x0 + 6, y0 + 11, contorno)
					img.set_pixel(x0 + 9, y0 + 11, contorno)
				FILA_IZQUIERDA:
					img.set_pixel(x0 + 5, y0 + 11, contorno)
					_rect(img, x0 + 9, y0 + 9, x0 + 10, y0 + 14, casco)
				FILA_DERECHA:
					img.set_pixel(x0 + 10, y0 + 11, contorno)
					_rect(img, x0 + 5, y0 + 9, x0 + 6, y0 + 14, casco)
				FILA_ARRIBA:
					_rect(img, x0 + 5, y0 + 9, x0 + 10, y0 + 14, casco)
	return img


static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			img.set_pixel(x, y, color)
