class_name PruebaLaboratorio
extends Resource
## Una prueba de laboratorio como dato (invariante 3). Agregar una prueba nueva
## = un .tres en data/pruebas/, sin tocar código, mientras use fuentes que ya
## existan (ver _fuente()).
##
## La prueba NO devuelve la verdad interna del estado: devuelve lo que muestra
## el instrumento, con su resolución (balanza a 0,1 ppg, dial del Fann entero,
## titulaciones a 0,05 ml…). Diseño en docs/game-design-mechanics.md
## ("Chequeo de rutina") y docs/mud-engineer-reference.md §7.
##
## Cada elemento de "lecturas" es un diccionario:
##   nombre      clave de la lectura en el resultado
##   fuente      de dónde sale el valor (método o variable de EstadoLodo, o una
##               fuente derivada de _fuente(); puede usar lecturas previas)
##   unidad      para la interfaz
##   resolucion  paso del instrumento (la lectura se redondea a este paso)
##   limite_fino / resolucion_gruesa  (opcional) por encima de limite_fino se
##               lee con resolucion_gruesa: titulante más concentrado o dilución
##   frio        (opcional) la lectura sube si se corre sin copa térmica
## El orden importa: una fuente derivada (VP del Fann, Fw de la retorta) usa
## las lecturas ya redondeadas, igual que el cálculo a mano en la caseta.

## 🧩 El Fann sin copa térmica (lodo a temperatura ambiente en vez de 120 °F)
## lee más alto. Factor de diseño, a calibrar (docs/simulation-logic.md §11).
const FACTOR_FANN_EN_FRIO := 1.15

## 🧩 Θ6 y Θ3 no están en el estado: se derivan con un modelo tipo
## Herschel-Bulkley entre Θ300 y Θ600, con un esfuerzo de cedencia a baja
## velocidad estimado como una fracción del gel de 10 s.
const FRACCION_GEL_A_TAU0 := 0.75

const MG_POR_MMOL_CA := 40.08
const MG_POR_MMOL_MG := 24.31
const MG_POR_MMOL_CO3 := 60.01
const MG_POR_MMOL_HCO3 := 61.02

@export var id := ""
@export var nombre := ""
@export_multiline var descripcion := ""
@export_enum("lodo", "filtrado") var muestra := "lodo"
@export var minutos_activos := 5
## Tiempo en que la prueba corre sola (filtro prensa, retorta, gel de 10 min).
@export var minutos_espera := 0
## Ids de pruebas que tienen que haber terminado antes (p. ej. el filtrado API).
@export var requiere := PackedStringArray()
@export_enum("rapido", "completo", "diaria", "ampliada") var nivel := "completo"
## Chequeos de rutina que la incluyen: "rapido", "completo", "diaria".
@export var chequeos := PackedStringArray()
## Equipo que queda ocupado durante la prueba, incluida la espera ("" = ninguno).
@export var equipo := ""
## Qué deja para otras pruebas (el filtrado API deja "filtrado").
@export var produce := ""
@export var lecturas: Array = []


## Requisitos que faltan dadas las pruebas ya terminadas.
func faltantes(hechas: Array) -> PackedStringArray:
	var faltan := PackedStringArray()
	for req in requiere:
		if not req in hechas:
			faltan.append(req)
	return faltan


func minutos_totales() -> int:
	return minutos_activos + minutos_espera


## Corre la prueba sobre el estado y devuelve las lecturas del instrumento.
## condiciones:
##   "hechas": Array de ids de pruebas ya terminadas (para los requisitos)
##   "copa_termica": bool, false si el Fann se corre en frío (por defecto true)
## Si falta un requisito devuelve {"error": texto} sin lecturas.
func ejecutar(estado: RefCounted, condiciones: Dictionary = {}) -> Dictionary:
	var faltan := faltantes(condiciones.get("hechas", []))
	if not faltan.is_empty():
		var texto := "%s no se puede correr todavía: falta %s." % [nombre, ", ".join(faltan)]
		if muestra == "filtrado":
			texto += " Se corre sobre el filtrado, que sale del filtro prensa API (30 min)."
		return {"error": texto}

	var resultado := {}
	for spec: Dictionary in lecturas:
		var valor := _fuente(spec["fuente"], estado, resultado)
		if spec.get("frio", false) and not condiciones.get("copa_termica", true):
			valor *= FACTOR_FANN_EN_FRIO
		resultado[spec["nombre"]] = redondear(maxf(0.0, valor), spec)
	return resultado


## Redondea al paso del instrumento.
static func redondear(valor: float, spec: Dictionary) -> float:
	var paso: float = spec.get("resolucion", 0.0)
	if spec.has("limite_fino") and valor > float(spec["limite_fino"]):
		paso = spec["resolucion_gruesa"]
	if paso <= 0.0:
		return valor
	return snappedf(valor, paso)


func unidad(nombre_lectura: String) -> String:
	for spec: Dictionary in lecturas:
		if spec["nombre"] == nombre_lectura:
			return spec.get("unidad", "")
	return ""


## Valor sin redondear de una fuente. Primero las fuentes derivadas; si no, un
## método o variable de EstadoLodo con ese nombre.
func _fuente(nombre_fuente: String, estado: RefCounted, previas: Dictionary) -> float:
	match nombre_fuente:
		"fann_6":
			return _fann_bajo(estado, 6.0)
		"fann_3":
			return _fann_bajo(estado, 3.0)
		# VP, PC y VA se calculan con las lecturas de dial ya redondeadas.
		"fann_vp":
			return previas["fann_600"] - previas["fann_300"]
		"fann_pc":
			return previas["fann_300"] - previas["vp"]
		"fann_va":
			return previas["fann_600"] / 2.0
		# Dureza total con EDTA expresada como calcio.
		"dureza_total":
			return estado.ca + estado.mg * MG_POR_MMOL_CA / MG_POR_MMOL_MG
		# Magnesio = dureza total − calcio, convertido de "como Ca" a Mg.
		"mg_por_diferencia":
			return (previas["dureza_total"] - previas["ca"]) * MG_POR_MMOL_MG / MG_POR_MMOL_CA
		# Retorta: lee volúmenes; los sólidos son lo que queda.
		"retorta_agua_pct":
			return 100.0 * estado.fw()
		"retorta_aceite_pct":
			return 100.0 * estado.frac_aceite
		"retorta_solidos_pct":
			return 100.0 - previas["agua_pct"] - previas["aceite_pct"]
		"retorta_fw":
			return previas["agua_pct"] / 100.0
		# GGT: carbonatos solubles totales expresados como CO₃²⁻.
		"carbonatos_totales":
			return estado.co3 + estado.hco3 * MG_POR_MMOL_CO3 / MG_POR_MMOL_HCO3
	if estado.has_method(nombre_fuente):
		return float(estado.call(nombre_fuente))
	var valor = estado.get(nombre_fuente)
	assert(valor != null, "Fuente de lectura desconocida: %s" % nombre_fuente)
	return float(valor)


## 🧩 Lectura del Fann a baja velocidad (rpm): τ0 + (Θ300 − τ0)·(N/300)^n,
## con n sacado de Θ600 y Θ300. Se calcula sin redondear, a 120 °F.
static func _fann_bajo(estado: RefCounted, rpm: float) -> float:
	var t600: float = estado.lectura_600()
	var t300: float = estado.lectura_300()
	var tau0 := clampf(FRACCION_GEL_A_TAU0 * estado.gel_10s(), 0.0, 0.9 * t300)
	var n := log((t600 - tau0) / (t300 - tau0)) / log(2.0)
	return tau0 + (t300 - tau0) * pow(rpm / 300.0, n)
