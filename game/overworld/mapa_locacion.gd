extends RefCounted
## Datos del mapa de la locación: la grilla, la leyenda, las estaciones y dónde
## se para cada personaje. Es solo dato; `mapa.gd` lo convierte en TileMapLayer.
##
## Recorrido del lodo en el mapa (de izquierda a derecha y vuelta):
## piso de perforación → flowline (fila 4) → caja de llegada → zarandas →
## trampa de arena → compartimiento de proceso → succión → bombas de lodo →
## línea de alta presión de vuelta al piso. Las reservas, los fractanques y el
## tanque de píldoras están fuera del activo y se conectan por el múltiple de
## transferencia (fila 22) con sus válvulas.

const ANCHO := 44
const ALTO := 30

## Una letra por casilla. Ver LEYENDA.
const FILAS := [
	":::T:::::T:::::::T::::::::T:::::::T:::::T:::",
	":##########################################:",
	":#........................................#:",
	":#.DDDDDDDDD..............................#:",
	":#.DXDDDDDXD---------------------.........#T",
	":#.DDDDDDDDD....................-.........#:",
	"T#.DDDDDDDDD...............SSSSCC.........#:",
	":#.DDDDODDDD.VV.===========SSSSCC==H==....#:",
	":#.DDDDDcDDD.VV.MMMMMNNNNNNAAAA...PPP.....#:",
	":#.DDDDDDDDD.||.MMMMMNNNNNNAAAA...PPP.-...#:",
	":#.DXDDDDDXD....MMMMMNNNNNNAAAA...PPP.-...#:",
	":#.DDDDDDDDD....|||||||||||||||...|||.-...#:",
	":#.....------KK======================.-...#T",
	":#...........KK...HB.o................-...#:",
	"T#.ggggg..Z.....ss....aaaaaa.bbbbbb...-...#:",
	":#.ggggg..............aaaaaa.bbbbbb...o...#:",
	":#.WUuUW..............wvdvvw.wdvwvwss.-...#:",
	":#.........L..........................-...#:",
	":#............RRRRRR.QQQQQQ...........-...#:",
	":#.eeeeeee....RRRRRR.QQQQQQ...........-...#:",
	":#.eeeeeee....RRRRRR.QQQQQQ...........-...#T",
	":#.WUWuWUW....||||||.||||||...........-...#:",
	"T#..........B----o------o------o-------...#:",
	":#.............................-..........#:",
	":#..........................FFFFFF.GGGGGG.#:",
	":#..........................FFFFFF.GGGGGG.#:",
	":#..........................||||||.||||||.#:",
	":#........................................#T",
	":###################YYY####################:",
	"::::::T::::::::T::::::::::::::T:::::::T:::::",
]

## Letra → [tipo, sólido]. El tipo es:
## - un nombre de `SUELTOS` del atlas (tile fijo),
## - "m:<fila>" para un tile con máscara de vecinos (autotile),
## - "v:<fila>" para variantes al azar fijo (grava, pasto),
## - "valvula" (se elige horizontal o vertical y abierta o cerrada).
const LEYENDA := {
	".": ["v:grava", false],
	":": ["v:pasto", false],
	"T": ["arbol", true],
	"#": ["m:cerca", true],
	"Y": ["porton", true],
	"D": ["m:piso_perforacion", false],
	"X": ["pata_torre", true],
	"O": ["mesa_rotaria", true],
	"c": ["consola", true],
	"-": ["m:tuberia", false],
	"o": ["valvula", true],
	"V": ["m:lodo_activo", true],
	"M": ["m:lodo_activo", true],
	"N": ["m:lodo_activo", true],
	"A": ["m:lodo_arena", true],
	"P": ["m:lodo_pildora", true],
	"R": ["m:lodo_reserva", true],
	"Q": ["m:lodo_reserva", true],
	"F": ["m:fractanque", true],
	"G": ["m:fractanque", true],
	"|": ["pared_tanque", true],
	"S": ["zaranda", true],
	"C": ["caja_llegada", true],
	"=": ["m:plancha", false],
	"H": ["embudo", true],
	"B": ["bomba_centrifuga", true],
	"K": ["m:maquina", true],
	"s": ["sacos", true],
	"a": ["m:techo_caseta", true],
	"b": ["m:techo_bodega", true],
	"e": ["m:techo_trailer", true],
	"g": ["m:techo_trailer", true],
	"w": ["pared", true],
	"v": ["ventana", true],
	"d": ["puerta", true],
	"W": ["pared_trailer", true],
	"U": ["ventana_trailer", true],
	"u": ["puerta_trailer", true],
	"Z": ["tanque_agua", true],
	"L": ["letrero", true],
}

## Variantes para los tipos "v:". Se eligen por la posición (siempre igual).
const VARIANTES := {
	"grava": ["grava", "grava", "grava", "grava_b", "grava_c"],
	"pasto": ["pasto", "pasto", "pasto_b", "pasto", "pasto_flores"],
}

## Letras que cuentan como "del mismo tipo" para la máscara de vecinos.
## Las que no aparecen aquí solo se unen consigo mismas: así cada
## compartimiento de tanque muestra su propio borde.
const GRUPOS_MASCARA := {
	"D": "piso", "X": "piso", "O": "piso", "c": "piso",
	"-": "tubo", "o": "tubo",
	"#": "cerca", "Y": "cerca",
}

const INICIO_JUGADOR := Vector2i(24, 17)

## Estaciones interactuables. `rects` en casillas; la estación ocupa las
## casillas sólidas dentro de esos rectángulos (se interactúa mirándolas).
## `grupo` agrupa estaciones para los datos que hablan de "tanques" en general
## (por ejemplo `data/observaciones/*.tres`, campo `estaciones`).
## `puestos` son casillas transitables donde se paran los personajes.
const ESTACIONES := [
	{"id": "piso_perforacion", "nombre": "Piso de perforación", "grupo": "piso_perforacion",
		"rects": [Rect2i(7, 7, 1, 1), Rect2i(8, 8, 1, 1)],
		"puestos": [Vector2i(9, 8), Vector2i(5, 9), Vector2i(7, 10)],
		"texto": "Consola del perforador: profundidad, ROP, peso sobre la broca, presión de bomba, caudal y volumen de tanques."},
	{"id": "tanque_viaje", "nombre": "Tanque de viaje", "grupo": "tanques",
		"rects": [Rect2i(13, 7, 2, 3)], "puestos": [],
		"texto": "Tanque de viaje. Es del perforador: mide el llenado del pozo en las maniobras."},
	{"id": "bombas_lodo", "nombre": "Bombas de lodo", "grupo": "bombas_lodo",
		"rects": [Rect2i(13, 12, 2, 2)], "puestos": [],
		"texto": "Bombas de lodo. Toman de la succión y mandan el lodo al pozo. Las opera el perforador."},
	{"id": "caja_de_llegada", "nombre": "Caja de llegada", "grupo": "caja_de_llegada",
		"rects": [Rect2i(31, 6, 2, 2)], "puestos": [Vector2i(33, 6)],
		"texto": "Caja de llegada. Aquí llega el retorno del pozo por el flowline: lo primero que sale del fondo se ve aquí."},
	{"id": "zarandas", "nombre": "Zarandas", "grupo": "zarandas",
		"rects": [Rect2i(27, 6, 4, 2)], "puestos": [Vector2i(28, 5)],
		"texto": "Zarandas. Las mallas descartan los recortes gruesos. Mira la cantidad y la forma de los recortes."},
	{"id": "trampa_arena", "nombre": "Trampa de arena", "grupo": "tanques",
		"rects": [Rect2i(27, 8, 4, 4)], "puestos": [],
		"texto": "Trampa de arena. No se agita: asienta los sólidos que pasan las zarandas."},
	{"id": "tanque_proceso", "nombre": "Tanque de proceso", "grupo": "tanques",
		"rects": [Rect2i(21, 8, 6, 4)], "puestos": [],
		"texto": "Compartimiento de proceso. Alimenta y recibe los equipos de control de sólidos."},
	{"id": "tanque_succion", "nombre": "Tanque de succión", "grupo": "tanques",
		"rects": [Rect2i(16, 8, 5, 4)], "puestos": [Vector2i(20, 13), Vector2i(15, 12)],
		"texto": "Tanque de succión. De aquí toman las bombas: la muestra de succión es lo que entra al pozo."},
	{"id": "valvula_igualadora", "nombre": "Válvula igualadora", "grupo": "valvulas",
		"rects": [Rect2i(21, 13, 1, 1)], "puestos": [], "abierta": true,
		"texto": "Línea igualadora entre succión y proceso."},
	{"id": "embudo_abajo", "nombre": "Embudo de mezcla", "grupo": "embudos",
		"rects": [Rect2i(18, 13, 2, 1), Rect2i(16, 14, 2, 1)], "puestos": [Vector2i(17, 13)],
		"texto": "Embudo de mezcla junto a la bomba centrífuga. Por aquí entran los sacos al sistema activo."},
	{"id": "tanque_pildora", "nombre": "Tanque de píldoras", "grupo": "tanques",
		"rects": [Rect2i(34, 8, 3, 4)], "puestos": [],
		"texto": "Tanque de píldoras. Volumen pequeño para preparar píldoras sin tocar el activo."},
	{"id": "embudo_arriba", "nombre": "Embudo del tanque de píldoras", "grupo": "embudos",
		"rects": [Rect2i(35, 7, 1, 1)], "puestos": [],
		"texto": "Embudo de mezcla de arriba, sobre el tanque de píldoras."},
	{"id": "valvula_pildora", "nombre": "Válvula del tanque de píldoras", "grupo": "valvulas",
		"rects": [Rect2i(38, 15, 1, 1)], "puestos": [], "abierta": false,
		"texto": "Línea del tanque de píldoras al múltiple de transferencia."},
	{"id": "caseta_lodos", "nombre": "Caseta de lodos", "grupo": "caseta_lodos",
		"rects": [Rect2i(22, 14, 6, 3)], "puestos": [Vector2i(26, 17)],
		"texto": "Caseta de lodos. El laboratorio: balanza, embudo Marsh, Fann, filtro prensa, retorta y titulaciones."},
	{"id": "bodega_quimicos", "nombre": "Bodega de químicos", "grupo": "bodega_quimicos",
		"rects": [Rect2i(29, 14, 6, 3), Rect2i(35, 16, 2, 1)],
		"puestos": [Vector2i(32, 17), Vector2i(28, 17)],
		"texto": "Bodega de químicos. Inventario y costo de los productos aprobados en el programa."},
	{"id": "cabina_mud_logger", "nombre": "Cabina del mud logger", "grupo": "cabina_mud_logger",
		"rects": [Rect2i(3, 14, 5, 3)], "puestos": [Vector2i(7, 17), Vector2i(2, 17)],
		"texto": "Cabina del mud logger: gas de fondo, gas de conexión y cambios en los recortes."},
	{"id": "oficina_company_man", "nombre": "Oficina del company man", "grupo": "oficina_company_man",
		"rects": [Rect2i(3, 19, 7, 3)], "puestos": [Vector2i(8, 22), Vector2i(4, 22)],
		"texto": "Oficina del company man. Programa de lodos, reporte diario, desvíos y costos."},
	{"id": "reserva_1", "nombre": "Reserva 1", "grupo": "tanques",
		"rects": [Rect2i(14, 18, 6, 4)], "puestos": [],
		"texto": "Reserva 1. Fuera del activo: aquí se construye el lodo nuevo."},
	{"id": "reserva_2", "nombre": "Reserva 2", "grupo": "tanques",
		"rects": [Rect2i(21, 18, 6, 4)], "puestos": [],
		"texto": "Reserva 2. Fuera del activo: lodo nuevo, exceso o lodo pesado."},
	{"id": "valvula_reserva_1", "nombre": "Válvula de la reserva 1", "grupo": "valvulas",
		"rects": [Rect2i(17, 22, 1, 1)], "puestos": [], "abierta": false,
		"texto": "Múltiple de transferencia, línea de la reserva 1."},
	{"id": "valvula_reserva_2", "nombre": "Válvula de la reserva 2", "grupo": "valvulas",
		"rects": [Rect2i(24, 22, 1, 1)], "puestos": [], "abierta": false,
		"texto": "Múltiple de transferencia, línea de la reserva 2."},
	{"id": "valvula_fractanques", "nombre": "Válvula de los fractanques", "grupo": "valvulas",
		"rects": [Rect2i(31, 22, 1, 1)], "puestos": [], "abierta": false,
		"texto": "Múltiple de transferencia, línea de los fractanques."},
	{"id": "fractanque_1", "nombre": "Fractanque 1", "grupo": "tanques",
		"rects": [Rect2i(28, 24, 6, 3)], "puestos": [],
		"texto": "Fractanque 1, unos 500 bbl. Almacenaje temporal en un cambio de fluido."},
	{"id": "fractanque_2", "nombre": "Fractanque 2", "grupo": "tanques",
		"rects": [Rect2i(35, 24, 6, 3)], "puestos": [],
		"texto": "Fractanque 2, unos 500 bbl. Almacenaje temporal en un cambio de fluido."},
]

## Personajes del contrato con el agente I: id → estación por defecto.
## Si `data/personajes/<id>.tres` trae otra `estacion` conocida, manda el dato.
const PERSONAJES := {
	"driller": "piso_perforacion",
	"toolpusher": "piso_perforacion",
	"encuellador": "tanque_succion",
	"company_man": "oficina_company_man",
	"mud_logger": "cabina_mud_logger",
	"cuadrillero": "bodega_quimicos",
}

## Nombres de estación que pueden venir en los datos con otra forma.
const ALIAS_ESTACION := {
	"tanques": "tanque_succion",
	"piso": "piso_perforacion",
	"laboratorio": "caseta_lodos",
	"bodega": "bodega_quimicos",
	"oficina": "oficina_company_man",
	"embudo": "embudo_abajo",
	"embudo_de_mezcla": "embudo_abajo",
}
