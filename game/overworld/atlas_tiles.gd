extends RefCounted
## Tabla del atlas assets/tiles/tileset.png.
## GENERADO por tools/generar_tiles.py — no editar a mano.

const LADO := 16
const RUTA := "res://assets/tiles/tileset.png"

## Tiles sueltos: nombre -> coordenada en el atlas.
const SUELTOS := {
	"grava": Vector2i(0, 0),
	"grava_b": Vector2i(1, 0),
	"grava_c": Vector2i(2, 0),
	"pasto": Vector2i(3, 0),
	"pasto_b": Vector2i(4, 0),
	"pasto_flores": Vector2i(5, 0),
	"arbol": Vector2i(6, 0),
	"tierra": Vector2i(7, 0),
	"mesa_rotaria": Vector2i(8, 0),
	"pata_torre": Vector2i(9, 0),
	"consola": Vector2i(10, 0),
	"zaranda": Vector2i(11, 0),
	"caja_llegada": Vector2i(12, 0),
	"embudo": Vector2i(13, 0),
	"bomba_centrifuga": Vector2i(14, 0),
	"tanque_agua": Vector2i(15, 0),
	"valvula_h_abierta": Vector2i(0, 1),
	"valvula_h_cerrada": Vector2i(1, 1),
	"valvula_v_abierta": Vector2i(2, 1),
	"valvula_v_cerrada": Vector2i(3, 1),
	"pared_tanque": Vector2i(4, 1),
	"pared": Vector2i(5, 1),
	"ventana": Vector2i(6, 1),
	"puerta": Vector2i(7, 1),
	"pared_trailer": Vector2i(8, 1),
	"ventana_trailer": Vector2i(9, 1),
	"puerta_trailer": Vector2i(10, 1),
	"sacos": Vector2i(11, 1),
	"porton": Vector2i(12, 1),
	"letrero": Vector2i(13, 1),
}

## Tiles con máscara de vecinos: nombre -> fila. La columna es la máscara
## (N=1, E=2, S=4, O=8; bit en 1 = el vecino es del mismo tipo).
const FILAS_MASCARA := {
	"lodo_activo": 2,
	"lodo_arena": 3,
	"lodo_reserva": 4,
	"lodo_pildora": 5,
	"fractanque": 6,
	"techo_caseta": 7,
	"techo_bodega": 8,
	"techo_trailer": 9,
	"plancha": 10,
	"piso_perforacion": 11,
	"tuberia": 12,
	"cerca": 13,
	"maquina": 14,
}
