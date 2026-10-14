extends "res://game/overworld/caminante.gd"
## Personaje no jugable. Lee sus datos de `data/personajes/<id>.tres`
## (Resource `sim/personaje.gd` del agente I: id, nombre, rol, estacion,
## dialogos). Si el archivo no existe, usa datos genéricos para que el mapa
## funcione igual.

const SITUACION_POR_DEFECTO := "saludo"

const ROLES_GENERICOS := {
	"driller": "Perforador",
	"toolpusher": "Toolpusher",
	"encuellador": "Encuellador",
	"company_man": "Company man",
	"mud_logger": "Mud logger",
	"cuadrillero": "Cuadrillero",
}

var nombre := ""
var rol := ""
var estacion := ""
var dialogos := {}
var desde_archivo := false
## Dirección a la que vuelve después de hablar.
var direccion_reposo := Vector2i.DOWN


static func ruta_datos(id: String) -> String:
	return "res://data/personajes/%s.tres" % id


## Datos del personaje, del archivo si existe o genéricos si no.
static func leer_datos(id: String) -> Dictionary:
	var rol_generico: String = ROLES_GENERICOS.get(id, id.capitalize())
	var datos := {
		"nombre": rol_generico,
		"rol": rol_generico,
		"estacion": "",
		"dialogos": {SITUACION_POR_DEFECTO: [
			"Buen día, ingeniero. Soy el %s." % rol_generico.to_lower(),
			"Cualquier cosa del lodo, me avisa.",
		]},
		"desde_archivo": false,
	}
	var ruta := ruta_datos(id)
	if not ResourceLoader.exists(ruta):
		return datos
	var recurso := load(ruta)
	if recurso == null:
		return datos
	for campo in ["nombre", "rol", "estacion"]:
		var valor = recurso.get(campo)
		if valor is String and valor != "":
			datos[campo] = valor
	var d = recurso.get("dialogos")
	if d is Dictionary and not d.is_empty():
		datos["dialogos"] = d
	datos["desde_archivo"] = true
	return datos


func cargar_datos(id: String) -> void:
	configurar(id)
	var d := leer_datos(id)
	nombre = d["nombre"]
	rol = d["rol"]
	estacion = d["estacion"]
	dialogos = d["dialogos"]
	desde_archivo = d["desde_archivo"]


## Líneas para una situación; cae en "saludo" si la situación no existe.
func lineas(situacion := SITUACION_POR_DEFECTO) -> Array[String]:
	var resultado: Array[String] = []
	var crudo = dialogos.get(situacion, dialogos.get(SITUACION_POR_DEFECTO, []))
	if crudo is String:
		resultado.append(crudo)
	elif crudo is Array or crudo is PackedStringArray:
		for l in crudo:
			resultado.append(str(l))
	if resultado.is_empty():
		resultado.append("...")
	return resultado


func titulo() -> String:
	if rol != "" and rol != nombre:
		return "%s (%s)" % [nombre, rol.to_lower()]
	return nombre


func _process(delta: float) -> void:
	avanzar(delta)
