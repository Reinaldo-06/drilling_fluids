extends RefCounted
## Escenarios jugables ya armados: tanques, inventario, perforación, eventos y
## la sesión del turno (sim/sesion_turno.gd). El juego arranca de aquí; las
## pruebas también. Todo ficticio y calibrable (🧩).

const Turno := preload("res://sim/turno.gd")
const Sesion := preload("res://sim/sesion_turno.gd")
const Operacion := preload("res://sim/operacion_pozo.gd")
const Tanque := preload("res://sim/tanque.gd")
const Base := preload("res://sim/lodos_base.gd")
const F := preload("res://sim/formulas.gd")

const PROGRAMA_SUPERFICIAL := "res://data/programas/caiman_3_superficial.tres"
const FORMACION_SUPERFICIAL := "res://data/formaciones/caiman_3_superficial.tres"
const GUION_SUPERFICIAL := "res://data/guiones/caiman_3_superficial.tres"
const CASO_PERDIDA := "res://data/casos/caiman_3_perdida_gravas.tres"

## 🧩 Sacos de cada producto aprobado en la bodega al empezar.
const SACOS_INICIALES := 60.0
## 🧩 Arranque de la broca y ROP de la superficial (17½").
const PROFUNDIDAD_INICIAL_FT := 800.0
const ROP_FT_H := 60.0
const DIAMETRO_PULG := 17.5
const CAUDAL_GPM := 700.0


## Superficial de CAIMÁN-3, con el lodo base disperso en el activo y lodo nuevo
## en la reserva 1. Devuelve {"turno", "operacion", "sesion"}.
static func caiman_3_superficial(semilla := 1) -> Dictionary:
	var programa: Resource = load(PROGRAMA_SUPERFICIAL)
	var tanques := [
		Tanque.crear("Proceso", 500.0, "proceso", 400.0, Base.disperso_lignosulfonato()),
		Tanque.crear("Succión", 500.0, "succion", 400.0, Base.disperso_lignosulfonato()),
		Tanque.crear("Reserva 1", 500.0, "reserva", 450.0, Base.disperso_lignosulfonato(), false),
		Tanque.crear("Reserva 2", 500.0, "reserva", 0.0, null, false),
	]
	var inventario := {}
	for id in programa.productos_aprobados:
		if id != "agua":
			inventario[id] = SACOS_INICIALES
	inventario["pac"] = 40.0
	inventario["carbonato_de_calcio"] = 200.0   # 10 lb/bbl en 800 bbl son 160 sacos
	var turno = Turno.crear(tanques, programa, inventario)
	turno.caudal_gpm = CAUDAL_GPM
	turno.profundidad_ft = PROFUNDIDAD_INICIAL_FT
	turno.volumen_pozo_bbl = F.capacidad_bbl_por_ft(DIAMETRO_PULG) * PROFUNDIDAD_INICIAL_FT
	var operacion = Operacion.crear([load(FORMACION_SUPERFICIAL)], load(GUION_SUPERFICIAL),
		ROP_FT_H, DIAMETRO_PULG, semilla)
	operacion.conectar(turno)
	turno.activar_caso(load(CASO_PERDIDA))
	return {"turno": turno, "operacion": operacion, "sesion": Sesion.crear(turno)}
