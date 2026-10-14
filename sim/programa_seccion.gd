class_name ProgramaSeccion
extends Resource
## Programa de lodos de una sección de pozo: el "quest log" del nivel.
##
## Formato en docs/mud-programs.md ("Formato del programa de lodos"): encabezado,
## especificación de propiedades (mín–máx), productos aprobados con su
## concentración de mantenimiento, advertencias y criterios de cambio de fluido.
##
## Invariante 6: "productos_aprobados" es el inventario legal de la sección y la
## palanca de dificultad. Quitar un id de la lista sube la dificultad sin tocar
## la simulación (ver sin_producto()).

const Props := preload("res://sim/propiedades_lodo.gd")

# --- Encabezado ---
@export var pozo := ""
@export var seccion := ""
@export var diametro := ""
@export var profundidad_desde := 0.0   ## ft
@export var profundidad_hasta := 0.0   ## ft
## Id del sistema en data/sistemas/ (p. ej. "bentonitico").
@export var sistema := ""
@export_multiline var objetivo := ""

# --- Especificación ---
## Propiedad → [mín, máx]. Las claves son las de sim/propiedades_lodo.gd.
@export var rangos: Dictionary = {}

## Programa de densidad: [[desde_ft, ppg], ...] en orden de profundidad. La
## densidad se sube por programa a medida que se profundiza (decisión del
## autor); el company man la pide según esta tabla. Vacío = sin tabla.
@export var densidad_programada: Array = []

# --- Inventario ---
## Ids de data/productos/ que se pueden usar en la sección.
@export var productos_aprobados: PackedStringArray = []
## Producto → [mín, máx] lb/bbl de mantenimiento (referencia para el jugador).
@export var concentraciones: Dictionary = {}
## Productos que el programa pide pero que todavía no existen en data/productos/.
## No se pueden usar hasta que alguien cree su .tres; tests/test_programa.gd
## avisa cuando aparece el archivo, para moverlos a productos_aprobados.
@export var productos_por_crear: PackedStringArray = []

# --- Riesgos y cierre ---
@export var advertencias: PackedStringArray = []
@export_multiline var criterios_cambio_fluido := ""
## Explicaciones propias de la sección, por "<propiedad>_alto" o "<propiedad>_bajo".
## Reemplazan a las genéricas de EXPLICACIONES.
@export var explicaciones: Dictionary = {}


const NOMBRES := {
	"densidad": "Densidad", "embudo": "Viscosidad de embudo", "vp": "VP", "pc": "PC (YP)",
	"gel_10s": "Gel 10 s", "gel_10min": "Gel 10 min", "filtrado": "Filtrado API",
	"ph": "pH", "pf": "Pf", "mf": "Mf", "pm": "Pm", "ca": "Calcio", "mg": "Magnesio",
	"cl": "Cloruros", "k": "Potasio (K⁺)", "mbt": "MBT", "lgs_pct": "Sólidos livianos",
	"solidos_pct": "Sólidos totales",
}

const UNIDADES := {
	"densidad": "ppg", "embudo": "s/qt", "vp": "cP", "pc": "lb/100 ft²",
	"gel_10s": "lb/100 ft²", "gel_10min": "lb/100 ft²", "filtrado": "ml/30 min",
	"ph": "", "pf": "ml", "mf": "ml", "pm": "ml", "ca": "mg/l", "mg": "mg/l",
	"cl": "mg/l", "k": "mg/l", "mbt": "lb/bbl", "lgs_pct": "%", "solidos_pct": "%",
}

const DECIMALES := {
	"densidad": 2, "embudo": 0, "vp": 0, "pc": 0, "gel_10s": 0, "gel_10min": 0,
	"filtrado": 1, "ph": 1, "pf": 2, "mf": 2, "pm": 2, "ca": 0, "mg": 0, "cl": 0,
	"k": 0, "mbt": 1, "lgs_pct": 1, "solidos_pct": 1,
}

## Por qué importa cada desvío (mud-engineer-reference.md §1 y §5,
## game-design-mechanics.md "Diagnóstico de reología").
const EXPLICACIONES := {
	"densidad_alto": "Pasaste el techo de la ventana: más presión contra la formación (riesgo de pérdida de circulación), menos ROP y más volumen en el sistema. Se baja diluyendo o con control de sólidos.",
	"densidad_bajo": "Por debajo del piso de la ventana el lodo puede no contener la presión de formación ni sostener las paredes del hueco. Densifica con barita, si el programa la aprueba.",
	"embudo_alto": "El embudo solo dice que el lodo está más espeso. No dice por qué: corre el Fann para separar VP (sólidos) de PC (química).",
	"embudo_bajo": "El lodo está muy delgado: puede no limpiar el hueco ni suspender recortes.",
	"vp_alto": "VP alta es un problema de sólidos (mud-engineer-reference.md §5.1): control mecánico de sólidos o dilución.",
	"vp_bajo": "VP baja casi nunca es un problema; revisa que la muestra sea representativa.",
	"pc_alto": "PC alto es un problema químico, de floculación (§5.2). Diluir no ataca la causa: corre las pruebas químicas para saber qué contaminante es.",
	"pc_bajo": "Con poco punto cedente el lodo no levanta los recortes. Sube la viscosidad con el viscosificante del programa.",
	"gel_10s_alto": "Geles altos piden presión de bomba para romper circulación y pueden indicar floculación o carbonatos.",
	"gel_10s_bajo": "Geles bajos: los recortes y la barita no quedan suspendidos cuando se para la bomba.",
	"gel_10min_alto": "Geles progresivos son una firma de floculación y de carbonatos (§1.7).",
	"gel_10min_bajo": "Geles bajos: riesgo de asentamiento de recortes y barita en las paradas.",
	"filtrado_alto": "Mucho filtrado deja revoque grueso, invade la formación y favorece la pega diferencial. Sube el controlador de filtrado o trata la floculación que lo causa.",
	"filtrado_bajo": "Filtrado más bajo que lo pedido: estás gastando controlador de filtrado de más.",
	"ph_alto": "pH alto: con polímeros los hidroliza; con cemento es señal de cal libre. Mira Pm y Pf antes de tratar.",
	"ph_bajo": "pH bajo: los desfloculantes pierden eficacia y puede indicar yeso, sal, H₂S o carbonatos. Corre las pruebas químicas antes de echar soda cáustica.",
	"pf_alto": "Pf alto con pH estable puede ser carbonatos (§1.7).",
	"pf_bajo": "Pf bajo: poca alcalinidad del filtrado.",
	"mf_alto": "Mf alto (sobre 5 ml) y relación Mf/Pf creciente: muy probable contaminación de carbonatos (§1.7).",
	"mf_bajo": "Mf bajo: poca alcalinidad total del filtrado.",
	"pm_alto": "Pm alto es cal sin disolver: cemento o cal en exceso (§1.3).",
	"pm_bajo": "Pm bajo: no hay reserva de alcalinidad.",
	"ca_alto": "Calcio alto flocula las arcillas y precipita polímeros. Viene de cemento, yeso o anhidrita, o del agua de mezcla: mira Pm y pH para saber cuál (§1.3, §1.4).",
	"ca_bajo": "Calcio por debajo de lo que pide el programa: el sistema perdió su reserva de calcio.",
	"mg_alto": "Magnesio alto: agua dura o carnalita. Con magnesio la soda cáustica precipita Mg(OH)₂ y espesa (§1.5, §1.6).",
	"cl_alto": "Cloruros altos: sal de la formación o del agua. La única forma económica de bajarlos es diluir con agua dulce (§1.5).",
	"cl_bajo": "Cloruros bajos para el sistema: la salmuera se diluyó.",
	"k_alto": "Potasio por encima de lo necesario: estás gastando KCl.",
	"k_bajo": "Potasio bajo: la inhibición se está agotando. El K⁺ se consume en las arcillas; los cloruros no bajan y engañan (simulation-logic.md §13.1).",
	"mbt_alto": "MBT alto: está entrando arcilla activa. Más reactividad ante contaminantes químicos y PV que sube (§1.1).",
	"mbt_bajo": "MBT bajo: poca bentonita para dar viscosidad y revoque.",
	"lgs_pct_alto": "Demasiados sólidos livianos: sólidos de perforación acumulados. Control de sólidos o dilución (§1.9).",
	"solidos_pct_alto": "Demasiados sólidos en el lodo. Mira la retorta para saber si es barita o sólidos perforados.",
}


func puede_usar(producto_id: String) -> bool:
	return productos_aprobados.has(producto_id)


## Copia del programa sin un producto: la palanca de dificultad del invariante 6.
## No modifica el recurso cargado (load() lo comparte entre quienes lo usan).
func sin_producto(producto_id: String) -> Resource:
	var copia: Resource = duplicate(true)
	var lista: PackedStringArray = copia.productos_aprobados.duplicate()
	var i := lista.find(producto_id)
	if i >= 0:
		lista.remove_at(i)
	copia.productos_aprobados = lista
	return copia


## Propiedades fuera de rango. `estado` es un EstadoLodo o un diccionario de
## propiedades. Cada entrada: propiedad, nombre, valor, rango [mín, máx],
## sentido ("alto" | "bajo"), unidad y texto para el jugador.
func fuera_de_especificacion(estado) -> Array:
	var props := Props.de(estado)
	var resultado: Array = []
	for propiedad: String in rangos:
		if not props.has(propiedad):
			push_warning("Programa %s: propiedad desconocida '%s'" % [seccion, propiedad])
			continue
		var rango: Array = rangos[propiedad]
		var valor: float = props[propiedad]
		var sentido := ""
		if valor > float(rango[1]) + 1e-9:
			sentido = "alto"
		elif valor < float(rango[0]) - 1e-9:
			sentido = "bajo"
		if sentido == "":
			continue
		resultado.append({
			"propiedad": propiedad,
			"nombre": NOMBRES.get(propiedad, propiedad),
			"valor": valor,
			"rango": rango,
			"sentido": sentido,
			"unidad": UNIDADES.get(propiedad, ""),
			"texto": _texto(propiedad, valor, rango, sentido),
		})
	return resultado


func dentro_de_especificacion(estado) -> bool:
	return fuera_de_especificacion(estado).is_empty()


## Lo que ven las condiciones de las reglas como "programa".
func como_diccionario() -> Dictionary:
	return {
		"pozo": pozo, "seccion": seccion, "sistema": sistema,
		"rangos": rangos, "aprobados": Array(productos_aprobados),
	}


func _texto(propiedad: String, valor: float, rango: Array, sentido: String) -> String:
	var dec: int = DECIMALES.get(propiedad, 2)
	var unidad: String = UNIDADES.get(propiedad, "")
	var sufijo := (" " + unidad) if unidad != "" else ""
	var clave := "%s_%s" % [propiedad, sentido]
	var porque: String = explicaciones.get(clave, EXPLICACIONES.get(clave, ""))
	var texto := "%s %s%s: el programa de %s pide %s–%s%s." % [
		NOMBRES.get(propiedad, propiedad), _num(valor, dec), sufijo, seccion,
		_num(rango[0], dec), _num(rango[1], dec), sufijo]
	if porque != "":
		texto += " " + porque
	return texto


## Número con coma decimal y punto de miles, como en los documentos.
static func _num(x: float, decimales: int) -> String:
	var s: String = ("%." + str(decimales) + "f") % absf(x)
	var partes := s.split(".")
	var entero: String = partes[0]
	var con_miles := ""
	while entero.length() > 3:
		con_miles = "." + entero.substr(entero.length() - 3) + con_miles
		entero = entero.substr(0, entero.length() - 3)
	con_miles = entero + con_miles
	var r := con_miles + ("," + partes[1] if partes.size() > 1 else "")
	return ("-" if x < 0.0 else "") + r


## Densidad que pide el programa a "profundidad_ft" (0 si no hay tabla).
func densidad_en(profundidad_ft: float) -> float:
	var ppg := 0.0
	for tramo in densidad_programada:
		if profundidad_ft >= float(tramo[0]):
			ppg = float(tramo[1])
	return ppg
