extends "res://tests/test_case.gd"
## Integración del turno con perforación, control de sólidos, eventos y PVT
## (sim/operacion_pozo.gd; simulation-logic.md §4, §6, §10.1 y §12.2).

const Turno := preload("res://sim/turno.gd")
const Tanque := preload("res://sim/tanque.gd")
const Base := preload("res://sim/lodos_base.gd")
const Operacion := preload("res://sim/operacion_pozo.gd")

const PROGRAMA := preload("res://data/programas/caiman_3_superficial.tres")
const SUPERFICIAL := preload("res://data/formaciones/caiman_3_superficial.tres")
const GUION_SUP := preload("res://data/guiones/caiman_3_superficial.tres")
const GUION_PROD := preload("res://data/guiones/caiman_3_produccion.tres")


func _turno(guion: Resource, profundidad: float) -> Array:
	var tanques := [
		Tanque.crear("Proceso", 500.0, "proceso", 300.0, Base.disperso_lignosulfonato()),
		Tanque.crear("Succión", 500.0, "succion", 300.0, Base.disperso_lignosulfonato()),
		Tanque.crear("Reserva", 500.0, "reserva", 200.0, Base.disperso_lignosulfonato(), false),
	]
	var t = Turno.crear(tanques, PROGRAMA, {"barita": 500.0})
	t.caudal_gpm = 700.0
	t.profundidad_ft = profundidad
	t.volumen_pozo_bbl = 0.15 * profundidad
	var o = Operacion.crear([SUPERFICIAL], guion, 60.0, 17.5)
	o.conectar(t)
	return [t, o]


func _tipos(avisos: Array) -> Array:
	return avisos.map(func(a): return a["tipo"])


func test_perforar_cuadra_el_balance_sin_eventos() -> void:
	var par := _turno(null, 500.0)
	var t = par[0]
	var vol0: float = t.volumen_superficie()
	t.esperar(120.0)
	verificar_cerca(t.profundidad_ft, 620.0, 0.5, "60 ft/h durante 2 h")
	verificar(t.volumen_superficie() < vol0, "el hueco y los recortes consumen volumen")
	var r = t.entregar_reporte()
	verificar(r.volumen["cuadra"], "sin pérdidas, el balance cuadra: %s" % str(r.volumen))
	verificar(t.horas_equipos.get("zaranda", 0.0) > 2.0, "las zarandas suman horas")


func test_filtracion_sin_avisar_la_detecta_el_pvt_y_el_balance() -> void:
	# c3s_filtracion_gravas: 12 bbl/h a 900 ft, nadie la avisa (guion superficial).
	var par := _turno(GUION_SUP, 880.0)
	var t = par[0]
	t.esperar(180.0)
	var tipos := _tipos(t.tomar_avisos())
	verificar("alarma_pvt" in tipos, "el PVT ve la pérdida: %s" % str(tipos))
	var r = t.entregar_reporte()
	verificar(not r.volumen["cuadra"], "el reporte no cuadra")
	verificar(r.volumen["no_explicado"] < -10.0, "faltan bbl sin explicar: %.1f" % r.volumen["no_explicado"])


func test_transferencia_avisada_no_da_alarma_de_pozo() -> void:
	var par := _turno(null, 500.0)
	var t = par[0]
	t.esperar(10.0)
	t.avisar_driller()
	t.transferir("Reserva", "Succión", 100.0)
	t.esperar(30.0)
	verificar(not "alarma_pvt" in _tipos(t.tomar_avisos()), "el driller sabía de la transferencia")


func test_falla_de_centrifuga_la_apaga_y_vuelve() -> void:
	var par := _turno(GUION_PROD, 500.0)
	var t = par[0]
	var o = par[1]
	o.control.encender("centrifuga", true)
	var falla: Resource = GUION_PROD.evento("c3p_falla_centrifuga")
	verificar(falla != null, "el guion de producción trae la falla de la centrífuga")
	if falla == null:
		return
	o.guion.disparar(falla, t.tanques, t.profundidad_ft)
	t.esperar(10.0)
	verificar(not o.control.equipo("centrifuga").encendido, "fuera de servicio")
	o.guion.terminar(falla.id)
	t.esperar(10.0)
	verificar(o.control.equipo("centrifuga").encendido, "vuelve al terminar la falla")
