extends "res://tests/test_case.gd"
## Guiones de sección (sim/guion_seccion.gd, data/guiones/) ejecutados con
## sim/guion_ejecucion.gd. mud-programs.md (CAIMÁN-3), reference-wells.md §6
## (MÉDANO-5) y simulation-logic.md §10.

const Ejecucion := preload("res://sim/guion_ejecucion.gd")
const Tanque := preload("res://sim/tanque.gd")
const EstadoLodoScript := preload("res://sim/estado_lodo.gd")
const Base := preload("res://sim/lodos_base.gd")
const F := preload("res://sim/formulas.gd")

const BARITA := preload("res://data/productos/barita.tres")
const PVT := preload("res://data/eventos/monitor_pvt.tres")

const GUIONES := ["caiman_3_superficial", "caiman_3_intermedia", "caiman_3_produccion", "medano_5_sal"]


func _guion(id: String) -> Resource:
	return load("res://data/guiones/%s.tres" % id)


func _tanques(densidad := 0.0) -> Array:
	var lodo := Base.disperso_lignosulfonato()
	var tanques := [
		Tanque.crear("Proceso", 600.0, "proceso", 300.0, lodo.copiar()),
		Tanque.crear("Succión", 600.0, "succion", 300.0, lodo.copiar()),
		Tanque.crear("Reserva", 600.0, "reserva", 300.0, lodo.copiar(), false),
	]
	if densidad > 0.0:
		for t in tanques:
			t.tratar(BARITA, F.barita_lb_por_bbl(t.lodo.densidad(), densidad))
	return tanques


## Perfora de "desde" a "hasta" a "rop" ft/h en pasos de 10 min. Devuelve los ids avisados.
func _perforar(ej: RefCounted, tanques: Array, desde: float, hasta: float, rop := 60.0) -> Array:
	var ids: Array = []
	var prof := desde
	while prof < hasta:
		prof = minf(hasta, prof + rop / 6.0)
		for a in ej.paso(tanques, prof, 10.0):
			ids.append(a["id"])
	return ids


func test_guiones_validos() -> void:
	for id in GUIONES:
		var g := _guion(id)
		verificar(g != null, "%s existe" % id)
		if g == null:
			continue
		verificar(g.id == id, "%s: id = archivo" % id)
		verificar(not g.eventos.is_empty(), "%s: tiene eventos" % id)
		verificar(g.problemas().is_empty(), "%s: %s" % [id, g.problemas()])


func test_guiones_de_caiman_cubren_las_secciones_del_programa() -> void:
	var pozo = load("res://data/pozos/caiman_3.tres")
	var nombres := ["caiman_3_superficial", "caiman_3_intermedia", "caiman_3_produccion"]
	for i in pozo.secciones.size():
		var s = pozo.secciones[i]
		var g := _guion(nombres[i])
		verificar(g.seccion == s.seccion, "%s: sección %s" % [nombres[i], s.seccion])
		verificar_cerca(g.profundidad_desde, s.profundidad_desde, 1e-9, "%s: desde" % nombres[i])
		verificar_cerca(g.profundidad_hasta, s.profundidad_hasta, 1e-9, "%s: hasta" % nombres[i])


# mud-programs.md — "contaminación de cemento al iniciar la intermedia"
func test_intermedia_dispara_el_cemento_al_pasar_la_zapata() -> void:
	var tanques := _tanques()
	var pm0: float = tanques[0].lodo.pm()
	var ej := Ejecucion.new(_guion("caiman_3_intermedia"))
	verificar(ej.paso(tanques, 2490.0, 10.0).is_empty(), "antes de la zapata no pasa nada")
	var avisos: Array = ej.paso(tanques, 2500.0, 10.0)
	verificar(avisos.size() == 1 and avisos[0]["id"] == "c3i_cemento_zapata", "al llegar a la zapata")
	verificar(avisos[0]["quien_avisa"] == "driller", "lo avisa el driller")
	for i in 12:
		ej.paso(tanques, 2510.0, 10.0)
	verificar(tanques[0].lodo.pm() > pm0 + 0.5, "el Pm sube (%.2f → %.2f)" % [pm0, tanques[0].lodo.pm()])
	verificar(ej.disparados.has("c3i_lodo_espeso"), "el encuellador ve el lodo espeso (pH %.2f)" % tanques[0].lodo.ph())
	verificar(not ej.disparados.has("c3i_gas_conexion_1"), "el gas viene más abajo")


# simulation-logic.md §10.2 — gas de conexión que crece y pide subir la densidad
func test_gas_de_conexion_crece_y_pide_subir_peso() -> void:
	var tanques := _tanques()
	var ej := Ejecucion.new(_guion("caiman_3_intermedia"))
	var ids := _perforar(ej, tanques, 6000.0, 7100.0)
	var i1 := ids.find("c3i_gas_conexion_1")
	var i2 := ids.find("c3i_gas_conexion_2")
	var i3 := ids.find("c3i_subir_peso")
	verificar(i1 >= 0 and i2 > i1 and i3 > i2, "primero picos, después crecen, después el pedido: %s" % [ids])
	var pedido: Dictionary = ej.exigencias.get("c3i_subir_peso", {})
	var d := Ejecucion.densidad_activo(tanques)
	verificar_cerca(pedido.get("peso_minimo_ppg", 0.0), snappedf(d + 0.3, 0.1), 1e-9, "pide +0,3 ppg")
	verificar(not ej.perforacion_detenida(tanques), "el pedido no para la perforación")

	# Si no se sube, el pozo fluye y exige el peso de matada.
	ids = _perforar(ej, tanques, 7100.0, 7450.0)
	verificar("c3i_influjo" in ids, "sin subir el peso, influjo: %s" % [ids])
	var kmw := Ejecucion.EventoScript.redondear_arriba(F.peso_de_matada(d, 260.0, 7400.0))
	verificar_cerca(ej.exigencias["c3i_influjo"]["peso_minimo_ppg"], kmw, 1e-9, "peso de matada")
	verificar(ej.perforacion_detenida(tanques), "pozo cerrado hasta tener el peso")


func test_con_el_peso_correcto_no_hay_pedido_ni_influjo() -> void:
	var tanques := _tanques(10.5)
	var ej := Ejecucion.new(_guion("caiman_3_intermedia"))
	var ids := _perforar(ej, tanques, 6000.0, 8000.0)
	verificar("c3i_gas_conexion_1" in ids and "c3i_gas_conexion_2" in ids, "el gas igual aparece")
	verificar(not "c3i_subir_peso" in ids, "no hace falta pedir peso")
	verificar(not "c3i_influjo" in ids, "ni hay influjo")


func test_viaje_trae_gas_de_viaje_al_volver() -> void:
	var tanques := _tanques()
	var ej := Ejecucion.new(_guion("caiman_3_intermedia"))
	var ids := _perforar(ej, tanques, 5400.0, 5500.0)
	verificar("c3i_viaje_broca" in ids, "a 5.500 ft se cambia la broca")
	verificar(ej.perforacion_detenida(tanques), "en viaje")
	for i in 59:
		ej.paso(tanques, 5500.0, 10.0)
	verificar(not ej.disparados.has("c3i_gas_viaje"), "durante el viaje no hay gas de viaje")
	var avisos: Array = []
	for i in 2:
		avisos.append_array(ej.paso(tanques, 5500.0, 10.0))
	verificar(avisos.any(func(a): return a["id"] == "c3i_gas_viaje"), "al volver a circular, sí")
	# El lodo base no tiene barita: no hay sag.
	verificar(not ej.disparados.has("c3i_sag"), "sin barita no hay sag")


func test_superficial_tranquila_solo_el_viaje() -> void:
	# La filtración de las gravas ya no es un evento: sale de la formación
	# (Perforacion.tasa_filtracion; tests/test_operacion_pozo.gd).
	var tanques := _tanques()
	var ej := Ejecucion.new(_guion("caiman_3_superficial"))
	var ids := _perforar(ej, tanques, 0.0, 2500.0)
	verificar(ids == ["c3s_viaje_revestimiento"], "al final, el viaje: %s" % [ids])
	verificar(ej.debrief().size() == 1, "un renglón de debrief")
	for d in ej.debrief():
		verificar(not d["explicacion"].contains("{"), "%s: sin marcadores sin reemplazar" % d["id"])


func test_produccion_perdida_parcial() -> void:
	var tanques := _tanques()
	var ej := Ejecucion.new(_guion("caiman_3_produccion"))
	var ids := _perforar(ej, tanques, 8000.0, 8950.0, 50.0)
	verificar("c3p_perdida_parcial" in ids, "pérdida en la arena")


func test_medano_perdida_probable_solo_en_la_sal() -> void:
	var g := _guion("medano_5_sal")
	var fuera := Ejecucion.new(g, 7)
	var tanques := _tanques()
	for i in 600:   # 100 h a 1.200 ft: fuera de la ventana de la pérdida
		fuera.paso(tanques, 1200.0, 10.0)
	verificar(not fuera.disparados.has("m5_perdida_en_la_sal"), "arriba de la ventana no pasa")

	var dentro := Ejecucion.new(g, 7)
	tanques = _tanques()
	for i in 600:   # 100 h a 3.000 ft; λ = 0,04/h → P(no pasa) = e^−4 ≈ 2 %
		dentro.paso(tanques, 3000.0, 10.0)
		if dentro.disparados.has("m5_perdida_en_la_sal"):
			break
	verificar(dentro.disparados.has("m5_perdida_en_la_sal"), "dentro de la sal termina pasando (semilla fija)")


func test_avisos_y_explicaciones_sin_marcadores() -> void:
	# Todos los eventos de todos los guiones, disparados a mano sobre un lodo base.
	for id in GUIONES:
		var g := _guion(id)
		for e in g.eventos:
			var ej := Ejecucion.new(g)
			var a: Dictionary = ej.disparar(e, _tanques(), e.profundidad_ft)
			verificar(not a["texto"].contains("{"), "%s: aviso con marcador: %s" % [e.id, a["texto"]])
			verificar(not a["explicacion"].contains("{"), "%s: explicación con marcador" % e.id)


func test_company_man_pide_la_densidad_del_programa() -> void:
	# Decisión del autor: el pedido sigue el programa, no "la actual + 0,3".
	var tanques := _tanques()
	var ej := Ejecucion.new(_guion("caiman_3_intermedia"))
	ej.programa = load("res://data/programas/caiman_3_intermedia.tres")
	_perforar(ej, tanques, 6000.0, 7100.0)
	var pedido: Dictionary = ej.exigencias.get("c3i_subir_peso", {})
	verificar_cerca(pedido.get("peso_minimo_ppg", 0.0), 10.5, 1e-9, "pide los 10,5 ppg del programa")
	var aviso: Array = ej.historial.filter(func(a): return a["id"] == "c3i_subir_peso")
	verificar(aviso.size() == 1 and "10,5" in aviso[0]["texto"], "el aviso dice el valor del programa: %s" % str(aviso))
