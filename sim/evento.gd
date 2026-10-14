class_name Evento
extends Resource
## Un evento del pozo como dato (invariantes 3 y 4): qué pasa, cuándo, quién
## avisa, con qué palabras y por qué, para el debrief.
##
## El evento LE OCURRE al jugador (CLAUDE.md, "Rol"): resta lodo del activo,
## suma ganancia en tanques, mete un contaminante, saca de servicio un equipo o
## exige un peso de matada. Nunca opera el BOP, el choke ni las bombas; eso lo
## hace el driller fuera de la simulación del lodo.
##
## Lo ejecuta sim/guion_ejecucion.gd. Los datos viven en data/eventos/*.tres y
## los guiones de sección (sim/guion_seccion.gd) los ordenan por profundidad.
##
## Fuentes: simulation-logic.md §4 (PVT), §10 (pérdidas, gas, viajes), §14
## (lodo de matada), §15 (sag); domain-research.md §4.1 (peso de matada).

const F := preload("res://sim/formulas.gd")

const TIPOS := ["perdida_circulacion", "influjo", "gas_fondo", "gas_conexion", "gas_viaje", "aviso",
	"viaje", "contaminacion", "sag", "falla_equipo"]
const DISPARADORES := ["profundidad", "tiempo", "condicion", "probabilidad"]
const QUIEN_AVISA := ["driller", "mud_logger", "company_man", "encuellador", "nadie"]

## Cortes de la clasificación de pérdidas (simulation-logic.md §10.1). Las
## fuentes coinciden en el orden de magnitud, no en los cortes: 🧩 se toman
## los frecuentes para lodo base agua.
const FILTRACION_MAX_BBL_H := 25.0
const PARCIAL_MAX_BBL_H := 100.0

## Variables que puede usar "condicion" (clase Expression de Godot):
##   profundidad  ft medidos en el momento
##   horas        horas de juego desde que empezó la sección
##   props        propiedades del lodo medio del activo (sim/propiedades_lodo.gd)
##   contexto     diccionario libre que pasa quien llama (perforando, caudal,
##                ids de eventos ya disparados en "disparados" y de los que
##                siguen en curso en "activos", acciones del jugador…)
const VARIABLES_CONDICION := ["profundidad", "horas", "props", "contexto"]

## Identificador único; coincide con el nombre del archivo.
@export var id := ""
## Título corto para la interfaz y el debrief.
@export var titulo := ""
@export_enum("perdida_circulacion", "influjo", "gas_fondo", "gas_conexion", "gas_viaje", "aviso",
	"viaje", "contaminacion", "sag", "falla_equipo") var tipo := "perdida_circulacion"

# --- Disparador ---
## "profundidad": al pasar profundidad_ft. "tiempo": a las tiempo_h de la sección.
## "condicion": cuando la expresión vale true. "probabilidad": tasa por hora 🧩.
@export_enum("profundidad", "tiempo", "condicion", "probabilidad") var disparador := "profundidad"
@export var profundidad_ft := 0.0
@export var tiempo_h := 0.0
@export_multiline var condicion := ""
## Tasa de ocurrencia por hora (λ): en un paso de Δt horas dispara con
## probabilidad 1 − e^(−λ·Δt). 🧩
@export var probabilidad_por_hora := 0.0
## Para "condicion" y "probabilidad": solo se evalúa entre profundidad_ft y
## profundidad_hasta_ft (0 = sin límite inferior/superior). Así una pérdida
## "probable en la sal" solo puede pasar dentro de la sal.
@export var profundidad_hasta_ft := 0.0

# --- Duración ---
## Horas que dura el efecto continuo (pérdida, contaminante que entra de a poco,
## viaje, equipo fuera de servicio). 0 = instantáneo.
@export var duracion_h := 0.0

# --- Parámetros por tipo ---
## Pérdida: bbl/h que se van a la formación mientras dura.
@export var tasa_perdida_bbl_h := 0.0
## Pérdida total: no vuelve lodo a superficie (simulation-logic.md §10.1).
@export var perdida_total := false
## Influjo: presión de cierre en la sarta y profundidad vertical.
@export var sidpp_psi := 0.0
@export var tvd_ft := 0.0
## Influjo: ganancia en tanques (bbl) que el PVT ve como ganancia real.
@export var ganancia_bbl := 0.0
## Contaminación: Contaminante de data/contaminantes/ y cantidad en su unidad
## (por bbl del activo). Si hay duración, entra repartida en ese tiempo.
@export var contaminante: Resource = null
@export var cantidad := 0.0
## Gas: unidades de gas que reporta el mud logger (solo informativo).
@export var gas_unidades := 0.0
## Gas o pedido del company man: cuánto pide subir la densidad (ppg).
@export var subir_densidad_ppg := 0.0
## Sag: oscilación de la densidad en la caja de llegada al volver a circular.
@export var variacion_densidad_ppg := 0.0
## Falla de equipo: id del equipo de control de sólidos que sale de servicio.
@export var equipo := ""
## Viaje: true si durante el evento no se perfora.
@export var detiene_perforacion := false

# --- Aviso y explicación ---
@export_enum("driller", "mud_logger", "company_man", "encuellador", "nadie") var quien_avisa := "driller"
## Lo que se le dice al jugador cuando pasa. Si quien_avisa es "nadie", es lo
## que el jugador ve si mira los tanques (no aparece solo).
@export_multiline var aviso := ""
## true si el aviso describe lo que se ve (lodo espeso, nivel que baja). Esos
## avisos nunca nombran el contaminante químico (invariante 1). false cuando es
## un hecho operativo ("perforamos el cemento de la zapata").
@export var aviso_es_observacion := true
## Por qué pasó y qué hacía falta, para el debrief (invariante 4).
@export_multiline var explicacion := ""
## Sección de docs/ de donde sale el evento.
@export var referencia := ""


## Si es false, una condición mal escrita no hace push_error (para pruebas).
var mostrar_errores := true


# ======================= Disparo =======================

## ¿Dispara en este paso? "estado" = {profundidad, horas, props, contexto}.
## "rng" solo se usa con disparador "probabilidad".
func debe_disparar(estado: Dictionary, dt_h: float, rng: RandomNumberGenerator) -> bool:
	var prof: float = estado.get("profundidad", 0.0)
	match disparador:
		"profundidad":
			return prof >= profundidad_ft
		"tiempo":
			return float(estado.get("horas", 0.0)) >= tiempo_h
		"condicion":
			return en_ventana(prof) and cumple_condicion(estado)
		"probabilidad":
			if not en_ventana(prof) or probabilidad_por_hora <= 0.0:
				return false
			if condicion != "" and not cumple_condicion(estado):
				return false
			return rng.randf() < 1.0 - exp(-probabilidad_por_hora * dt_h)
	return false


func en_ventana(prof: float) -> bool:
	if profundidad_ft > 0.0 and prof < profundidad_ft:
		return false
	if profundidad_hasta_ft > 0.0 and prof > profundidad_hasta_ft:
		return false
	return true


## Evalúa "condicion". Una condición vacía vale true; una mal escrita, false
## (con push_error, como el evaluador de reglas).
func cumple_condicion(estado: Dictionary) -> bool:
	if condicion.strip_edges() == "":
		return true
	var e := Expression.new()
	if e.parse(condicion, VARIABLES_CONDICION) != OK:
		if mostrar_errores:
			push_error("Evento %s: condición no compila: %s" % [id, e.get_error_text()])
		return false
	var r = e.execute([estado.get("profundidad", 0.0), estado.get("horas", 0.0),
		estado.get("props", {}), estado.get("contexto", {})], null, false)
	if e.has_execute_failed() or typeof(r) != TYPE_BOOL:
		if mostrar_errores:
			push_error("Evento %s: condición no devuelve bool" % id)
		return false
	return r


# ======================= Cálculos =======================

## "filtracion", "parcial", "severa" o "total" (simulation-logic.md §10.1).
static func clasificar_perdida(tasa_bbl_h: float, total := false) -> String:
	if total:
		return "total"
	if tasa_bbl_h <= FILTRACION_MAX_BBL_H:
		return "filtracion"
	if tasa_bbl_h <= PARCIAL_MAX_BBL_H:
		return "parcial"
	return "severa"


func clasificacion() -> String:
	return clasificar_perdida(tasa_perdida_bbl_h, perdida_total)


## Peso de matada exacto (domain-research.md §4.1) para la densidad actual.
func peso_de_matada(densidad_ppg: float) -> float:
	return F.peso_de_matada(densidad_ppg, sidpp_psi, tvd_ft)


## Peso de matada redondeado hacia arriba a 0,1 ppg, como se pide en el campo.
static func redondear_arriba(ppg: float) -> float:
	return ceilf(ppg * 10.0 - 1e-6) / 10.0


## bbl que se pierden en "dt_h" horas (la pérdida total vacía lo que circula:
## se usa la tasa dada como tope de lo que la bomba manda al pozo).
func perdida_en(dt_h: float) -> float:
	return maxf(tasa_perdida_bbl_h, 0.0) * dt_h


## Verificación de los datos: lista de problemas (vacía si está bien).
func problemas() -> Array[String]:
	var p: Array[String] = []
	if id == "":
		p.append("sin id")
	if not tipo in TIPOS:
		p.append("tipo desconocido %s" % tipo)
	if not disparador in DISPARADORES:
		p.append("disparador desconocido %s" % disparador)
	if not quien_avisa in QUIEN_AVISA:
		p.append("quien_avisa desconocido %s" % quien_avisa)
	if aviso.strip_edges() == "":
		p.append("sin aviso")
	if explicacion.strip_edges() == "":
		p.append("sin explicación")
	match tipo:
		"perdida_circulacion":
			if tasa_perdida_bbl_h <= 0.0 or duracion_h <= 0.0:
				p.append("pérdida sin tasa o duración")
		"influjo":
			if sidpp_psi <= 0.0 or tvd_ft <= 0.0:
				p.append("influjo sin SIDPP o TVD")
		"contaminacion":
			if contaminante == null or cantidad <= 0.0:
				p.append("contaminación sin contaminante o cantidad")
		"falla_equipo":
			if equipo == "" or duracion_h <= 0.0:
				p.append("falla sin equipo o duración")
	if disparador == "condicion" and condicion.strip_edges() == "":
		p.append("disparador por condición sin condición")
	if disparador == "condicion" or (disparador == "probabilidad" and condicion != ""):
		var e := Expression.new()
		if e.parse(condicion, VARIABLES_CONDICION) != OK:
			p.append("condición no compila: %s" % e.get_error_text())
	return p
