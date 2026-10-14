extends "res://tests/test_case.gd"
## Turno de día: reloj de 720 min, acciones con costo de tiempo, laboratorio
## con esperas en paralelo, encuellador, transferencias y reglas.
## Referencias: CLAUDE.md (turno de 12 h, chequeo rápido ≤ 10 min, 50 sacos/h
## y 250 con cuadrilla), simulation-logic.md §3, §4, §8 y §12.2–12.3,
## game-design-mechanics.md ("Chequeo de rutina").

const Turno := preload("res://sim/turno.gd")
const Reloj := preload("res://sim/reloj.gd")
const Accion := preload("res://sim/accion.gd")
const Encuellador := preload("res://sim/encuellador.gd")
const Inventario := preload("res://sim/turno_inventario.gd")
const Lab := preload("res://sim/laboratorio.gd")
const Tanque := preload("res://sim/tanque.gd")
const Base := preload("res://sim/lodos_base.gd")

const PROGRAMA := preload("res://data/programas/caiman_3_superficial.tres")


func _turno() -> RefCounted:
	var tanques := [
		Tanque.crear("Proceso", 500.0, "proceso", 300.0, Base.disperso_lignosulfonato()),
		Tanque.crear("Succión", 500.0, "succion", 300.0, Base.disperso_lignosulfonato()),
		Tanque.crear("Reserva", 500.0, "reserva", 200.0, Base.disperso_lignosulfonato(), false),
	]
	return Turno.crear(tanques, PROGRAMA, {"barita": 500.0, "soda_caustica": 20.0,
		"bentonita": 100.0, "pac": 10.0})


func _ids(hallazgos: Array) -> Array:
	return hallazgos.map(func(h): return h["id"])


# --- Reloj ---

func test_reloj_no_pasa_del_turno() -> void:
	var r := Reloj.new()
	var pasos := [0]
	var avanzado := r.avanzar(800.0, func(_m, _dt): pasos[0] += 1)
	verificar_cerca(avanzado, 720.0, 1e-9, "avanza solo hasta el final del turno")
	verificar_cerca(r.minuto, 720.0, 1e-9, "720 min = 12 h")
	verificar(pasos[0] == 72, "pasos de 10 min (dio %d)" % pasos[0])
	verificar(r.terminado() and not r.cabe(1.0), "no entra nada más")
	verificar(r.hora_texto() == "18:00", "el turno de día va de 06:00 a 18:00")

	var t := _turno()
	t.esperar(1000.0)
	verificar_cerca(t.reloj.minuto, 720.0, 1e-9, "esperar tampoco pasa de 720")
	verificar(t.chequeo_rapido().has("error"), "sin tiempo, la acción se rechaza")
	verificar_cerca(t.reloj.minuto, 720.0, 1e-9, "y no gasta tiempo")


func test_caminar_cuesta_la_tabla() -> void:
	var t := _turno()
	verificar(t.ubicacion == "caseta", "el turno empieza en la caseta")
	var r: Dictionary = t.caminar("oficina")
	verificar_cerca(r["minutos"], Accion.minutos_caminar("caseta", "oficina"), 1e-9, "minutos de la tabla")
	verificar_cerca(Accion.minutos_caminar("oficina", "caseta"), Accion.minutos_caminar("caseta", "oficina"), 1e-9, "simétrica")
	verificar(t.caminar("luna").has("error"), "estación inexistente")
	for a in Accion.ESTACIONES:
		for b in Accion.ESTACIONES:
			verificar(Accion.minutos_caminar(a, b) >= 0.0, "hay distancia %s–%s" % [a, b])


# --- Laboratorio ---

func test_chequeo_rapido_no_pasa_de_10_min() -> void:
	var t := _turno()
	var r: Dictionary = t.chequeo_rapido()
	verificar(r["minutos"] <= 10.0, "chequeo rápido ≤ 10 min (dio %s)" % r["minutos"])
	verificar(r["lecturas"].has("densidad") and r["lecturas"].has("ph") and r["lecturas"].has("viscosidad_embudo"),
		"densidad, embudo y pH")


func test_chequeo_completo_cuesta_lo_del_planificador() -> void:
	var t := _turno()
	var plan := Lab.planificar(Lab.chequeo("completo"))
	var r: Dictionary = t.chequeo_completo()
	verificar_cerca(r["minutos"], plan["total_min"], 1e-9, "lo que da el planificador")
	verificar_cerca(t.reloj.minuto, plan["total_min"], 1e-9, "el reloj avanzó eso")
	verificar(r["minutos"] < plan["suma_min"], "las esperas corren en paralelo")
	for id in ["fann", "filtrado_api", "pf_mf", "dureza", "cloruros", "pm"]:
		verificar(id in t.pruebas_corridas, "corrió %s" % id)

	# Con retorta: el planificador la mete en paralelo con el filtro prensa.
	var t2 := _turno()
	var plan2 := Lab.planificar(Lab.chequeo("completo") + Lab.chequeo("diaria"))
	verificar_cerca(t2.chequeo_completo("", true)["minutos"], plan2["total_min"], 1e-9, "con retorta")


func test_prueba_con_espera_corre_en_paralelo() -> void:
	var t := _turno()
	verificar(t.correr_prueba("pf_mf").has("error"), "Pf/Mf necesita el filtrado")
	var r: Dictionary = t.correr_prueba("filtrado_api")
	verificar_cerca(r["minutos"], 5.0, 1e-9, "el jugador solo pone la prueba (5 min activos)")
	verificar_cerca(r["listo_en"], 35.0, 1e-9, "listo a los 30 min de espera")
	t.correr_prueba("ph")
	verificar(not "filtrado_api" in t.pruebas_corridas, "todavía corre")
	t.esperar(40.0)
	verificar("filtrado_api" in t.pruebas_corridas, "terminó mientras el jugador hacía otra cosa")
	var pf: Dictionary = t.correr_prueba("pf_mf")
	verificar(pf.has("lecturas") and pf["lecturas"].has("pf"), "ahora sí hay Pf")
	verificar(t.correr_prueba("no_existe").has("error"), "prueba inexistente")


# --- Encuellador ---

func test_mezcla_de_100_sacos_tarda_2_h_y_24_min_con_cuadrilla() -> void:
	verificar_cerca(Encuellador.minutos_mezcla(100.0), 120.0, 1e-9, "50 sacos/h")
	verificar_cerca(Encuellador.minutos_mezcla(100.0, true), 24.0, 1e-9, "250 sacos/h")

	for cuadrilla in [false, true]:
		var t := _turno()
		t.cuadrilla_disponible = cuadrilla
		var r: Dictionary = t.ordenar_mezcla("barita", 100.0, "Succión", cuadrilla)
		var inicio: float = r["mezcla"]["minuto_orden"]
		var esperado := 24.0 if cuadrilla else 120.0
		t.esperar(esperado - (t.reloj.minuto - inicio) - 1.0)
		verificar(t.encuellador.ocupado(), "un minuto antes sigue mezclando")
		t.esperar(1.0)
		verificar(not t.encuellador.ocupado(), "terminó a los %s min" % esperado)
		verificar_cerca(t.inventario.disponible("barita"), 400.0, 1e-6, "sacó 100 sacos de la bodega")
		var avisos: Array = t.tomar_avisos().filter(func(a): return a["tipo"] == "encuellador_termine")
		verificar(avisos.size() == 1, "avisa que terminó")
		verificar(t.tanque("Succión").lodo.densidad() > t.tanque("Proceso").lodo.densidad() + 0.5,
			"la barita entró al tanque")
	var sin_permiso := _turno()
	verificar(sin_permiso.ordenar_mezcla("barita", 10.0, "Succión", true).has("error"),
		"sin cuadrilla prestada no hay 250 sacos/h")


func test_encuellador_para_si_se_acaba_el_producto() -> void:
	var t := _turno()
	var d0: float = t.tanque("Succión").lodo.pac
	var r: Dictionary = t.ordenar_mezcla("pac", 15.0, "Succión")
	verificar(r["aviso"] != "", "avisa al ordenar que no alcanza")
	t.esperar(60.0)
	verificar(not t.encuellador.ocupado(), "paró")
	verificar_cerca(t.inventario.disponible("pac"), 0.0, 1e-6, "usó los 10 sacos que había")
	verificar(t.encuellador.historial[0]["estado"] == "sin_producto", "quedó registrada como incompleta")
	verificar_cerca(t.tanque("Succión").lodo.pac - d0, 10.0 * 50.0 / 300.0, 0.01, "entraron 10 sacos de PAC")


# --- Transferencias y reglas ---

func test_transferir_sin_avisar_dispara_la_regla() -> void:
	var t := _turno()
	var r: Dictionary = t.transferir("Reserva", "Succión", 60.0)
	verificar("transferir_sin_avisar" in _ids(r["hallazgos"]), "hallazgo de la regla")
	verificar("transferir_sin_avisar" in _ids(t.hallazgos), "queda para el debrief")
	verificar(t.alarmas_pvt == 1, "falsa alarma del PVT")
	verificar_cerca(r["movido_bbl"], 60.0, 1e-9, "movió 60 bbl")
	verificar_cerca(r["minutos"], Accion.minutos_caminar("caseta", "tanques") + Accion.minutos("abrir_valvulas")
		+ 60.0 / Accion.minutos("transferencia_bbl_por_min"), 1e-9, "caminar + válvulas + bomba")

	var t2 := _turno()
	t2.avisar_driller()
	verificar(t2.ubicacion == "piso", "fue al piso a avisar")
	var r2: Dictionary = t2.transferir("Reserva", "Succión", 60.0)
	verificar(not "transferir_sin_avisar" in _ids(r2["hallazgos"]), "con aviso no hay hallazgo")
	verificar(t2.alarmas_pvt == 0, "ni alarma")
	var r3: Dictionary = t2.transferir("Reserva", "Succión", 10.0)
	verificar("transferir_sin_avisar" in _ids(r3["hallazgos"]), "el aviso vale para una transferencia")


func test_tratar_gasta_inventario_costo_y_evalua_reglas() -> void:
	var t := _turno()
	var r: Dictionary = t.tratar("soda_caustica", 0.25, "Succión")
	verificar_cerca(r["cantidad"], 2.0, 1e-9, "0,25 lb/bbl × 300 bbl = 75 lb → 2 sacos de 50 lb")
	verificar_cerca(r["lb_bbl"], 100.0 / 300.0, 1e-9, "se echan sacos enteros")
	verificar_cerca(t.inventario.disponible("soda_caustica"), 18.0, 1e-9, "salen de la bodega")
	verificar_cerca(r["costo"], 2.0 * t.inventario.costo_por_saco("soda_caustica"), 1e-6, "costo de 2 sacos")
	verificar("tratar_sin_diagnosticar" in _ids(r["hallazgos"]), "soda sin pruebas químicas")
	verificar(t.ubicacion == "embudo", "se trata en el embudo")
	verificar(t.tratar("soda_caustica", 10.0, "Succión").has("error"), "no alcanza la bodega")
	verificar(t.tratar("xc", 0.5, "Succión").has("error"), "producto sin existencias")


func test_enganches_corren_en_cada_paso() -> void:
	var t := _turno()
	var llamadas := {"antes": 0, "despues": 0, "min": 0.0}
	t.enganches_antes.append(func(turno, dt):
		llamadas["antes"] += 1
		llamadas["min"] += dt)
	t.enganches_despues.append(func(_turno, _dt): llamadas["despues"] += 1)
	t.esperar(60.0)
	verificar(llamadas["antes"] == 6 and llamadas["despues"] == 6, "6 pasos de 10 min")
	verificar_cerca(llamadas["min"], 60.0, 1e-9, "el enganche recibe dt")
