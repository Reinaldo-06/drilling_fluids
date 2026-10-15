extends RefCounted
## Catálogo de acciones del jugador: cuánto tiempo cuesta cada una y en qué
## estación se hace. Los números viven en data/turno/ (🧩, a calibrar jugando);
## este script solo los lee. El mapa usará minutos_caminar() para el costo de
## moverse entre estaciones (game-design-mechanics.md, Overworld).

const TIEMPOS := preload("res://data/turno/tiempos_acciones.tres")
const DISTANCIAS := preload("res://data/turno/distancias.tres")

## Estaciones del overworld (game-design-mechanics.md, tabla de estaciones).
const ESTACIONES := ["caseta", "tanques", "embudo", "bodega", "zarandas", "piso",
	"mud_logger", "oficina"]

## Dónde se hace cada acción.
const ESTACION_DE := {
	"laboratorio": "caseta",
	"transferir": "tanques",
	"orden_encuellador": "tanques",
	"tratar": "embudo",
	"avisar_driller": "piso",
	"entregar_reporte": "oficina",
	"revisar_balance": "mud_logger",
}

## Dónde está cada personaje (game-design-mechanics.md y simulation-logic.md §5).
const ESTACION_DE_PERSONAJE := {
	"driller": "piso",
	"toolpusher": "piso",
	"encuellador": "tanques",
	"mud_logger": "mud_logger",
	"company_man": "oficina",
	"cuadrillero": "zarandas",
}


static func minutos(clave: String) -> float:
	var v = TIEMPOS.valor(clave)
	assert(v != null, "Tiempo de acción desconocido: %s" % clave)
	return float(v)


static func es_estacion(nombre: String) -> bool:
	return nombre in ESTACIONES


## Minutos de caminata entre dos estaciones (0 si es la misma).
static func minutos_caminar(desde: String, hasta: String) -> float:
	if desde == hasta:
		return 0.0
	var a := desde if desde < hasta else hasta
	var b := hasta if desde < hasta else desde
	var v = DISTANCIAS.valor("%s|%s" % [a, b])
	assert(v != null, "Sin distancia entre %s y %s" % [desde, hasta])
	return float(v)


## Registro de una acción para el historial del turno y el debrief.
static func registro(tipo: String, minuto_inicio: float, duracion_min: float, datos: Dictionary = {}) -> Dictionary:
	return {"tipo": tipo, "minuto": minuto_inicio, "minutos": duracion_min, "datos": datos}
