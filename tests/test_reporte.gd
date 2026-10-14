extends "res://tests/test_case.gd"
## Reporte diario y turno de noche simulado (simulation-logic.md §9;
## game-design-mechanics.md, "Turnos por día de pozo").

const Turno := preload("res://sim/turno.gd")
const Reporte := preload("res://sim/reporte_diario.gd")
const Noche := preload("res://sim/turno_noche.gd")
const Tanque := preload("res://sim/tanque.gd")
const Base := preload("res://sim/lodos_base.gd")

const PROGRAMA := preload("res://data/programas/caiman_3_superficial.tres")


func _turno() -> RefCounted:
	var tanques := [
		Tanque.crear("Proceso", 600.0, "proceso", 300.0, Base.disperso_lignosulfonato()),
		Tanque.crear("Succión", 600.0, "succion", 300.0, Base.disperso_lignosulfonato()),
		Tanque.crear("Reserva", 600.0, "reserva", 200.0, Base.disperso_lignosulfonato(), false),
	]
	return Turno.crear(tanques, PROGRAMA, {"barita": 500.0, "soda_caustica": 20.0, "pac": 10.0})


## Doble de prueba de la perforación: el hueco nuevo se lleva "bbl_paso" del
## activo en cada paso. Si registra=false, es una pérdida que nadie vio.
func _perforacion(bbl_por_10_min: float, registra: bool) -> Callable:
	return func(turno, dt):
		var bbl: float = bbl_por_10_min * dt / 10.0
		turno.tanque("Proceso").volumen_bbl -= bbl
		if registra:
			turno.registrar_volumen("hueco", bbl)


func test_reporte_deja_vacias_las_pruebas_no_corridas() -> void:
	var t := _turno()
	t.chequeo_rapido()
	var r = t.entregar_reporte()
	verificar(r.medida("densidad") != null and r.medida("embudo") != null and r.medida("ph") != null,
		"lo del chequeo rápido está")
	for clave in ["vp", "pc", "gel_10s", "filtrado", "pf", "mf", "pm", "cl", "ca", "mbt", "fw"]:
		verificar(r.medida(clave) == null and r.vacia(clave), "%s queda vacía" % clave)
	verificar("vp" in r.sin_medir_del_programa and "mbt" in r.sin_medir_del_programa,
		"el company man pregunta por lo que el programa pide y no se midió")
	verificar(not "densidad" in r.sin_medir_del_programa, "la densidad sí se midió")
	verificar(r.texto().contains("REPORTE DIARIO"), "texto para depurar")


func test_reporte_compara_lo_medido_con_el_programa() -> void:
	var t := _turno()
	t.chequeo_rapido()
	var r = t.entregar_reporte()
	# El disperso de base tiene pH 10; la superficial pide 8,5–9,5.
	var props: Array = r.fuera_de_especificacion.map(func(f): return f["propiedad"])
	verificar("ph" in props, "pH fuera de programa")
	verificar(not "mbt" in props, "lo no medido no se compara (está en sin_medir)")
	verificar("lodo_fuera_de_programa" in r.hallazgos_cierre.map(func(h): return h["id"]),
		"regla al cerrar el día")


func test_balance_de_volumen_cuadra_sin_perdidas() -> void:
	var t := _turno()
	t.enganches_antes.append(_perforacion(2.0, true))
	t.tratar("agua", 0.1, "Succión")             # 30 bbl construidos
	t.ordenar_mezcla("barita", 30.0, "Succión")  # suma volumen de barita
	t.transferir("Reserva", "Proceso", 50.0)      # movimiento interno: no cambia el total
	t.esperar(120.0)
	var r = t.entregar_reporte()
	var v: Dictionary = r.volumen
	verificar(v["cuadra"], "cuadra (no explicado %.3f bbl)" % v["no_explicado"])
	verificar(v["hueco"] > 20.0, "el hueco se llevó lodo")
	verificar(v["construido"] > 30.0, "agua + barita")
	verificar_cerca(v["final_esperado"], v["inicial"] + v["construido"] - v["hueco"] - v["descarte"]
		- v["perdidas"] - v["derrame"], 1e-9, "fórmula del balance")


func test_balance_de_volumen_detecta_perdida_no_vista() -> void:
	var t := _turno()
	t.enganches_antes.append(_perforacion(2.0, true))
	t.enganches_despues.append(_perforacion(0.5, false))  # filtración que nadie registra
	t.esperar(200.0)
	var r = t.entregar_reporte()
	verificar(not r.volumen["cuadra"], "no cuadra")
	verificar(r.volumen["no_explicado"] < -5.0, "faltan unos 11 bbl (dio %.1f)" % r.volumen["no_explicado"])


func test_reporte_lleva_productos_y_costo() -> void:
	var t := _turno()
	t.tratar("soda_caustica", 0.25, "Succión")
	var r = t.entregar_reporte()
	verificar(r.productos.size() == 1 and r.productos[0]["producto"] == "soda_caustica", "producto usado")
	verificar_cerca(r.costo_dia, 2.0 * t.inventario.costo_por_saco("soda_caustica"), 1e-6, "costo del día")
	verificar_cerca(r.costo_acumulado, r.costo_dia, 1e-6, "acumulado del primer día")
	verificar(r.hallazgos_turno.size() > 0, "lleva los hallazgos del turno para el debrief")


func test_recomendaciones_invalidas_se_marcan() -> void:
	var t := _turno()
	var r = t.entregar_reporte([
		{"tipo": "mantener_producto", "producto": "pac", "lb_bbl": 1.0},
		{"tipo": "inventada"},
		{"tipo": "mantener_producto", "producto": "kriptonita", "lb_bbl": 1.0},
		{"tipo": "agua", "bbl_h": 5.0, "tanque": "Tanque 9"},
	])
	verificar(r.recomendaciones.size() == 1, "una válida")
	verificar(r.recomendaciones_invalidas.size() == 3, "tres inválidas, con su motivo")


func test_noche_aplica_mantenimiento_de_producto() -> void:
	var recs := [
		{"tipo": "agua", "bbl_h": 10.0, "tanque": "Succión"},
		{"tipo": "mantener_producto", "producto": "pac", "lb_bbl": 1.0, "tanque": "Succión"},
	]
	var t := _turno()
	var pac0: float = t.tanque("Succión").lodo.pac
	t.entregar_reporte(recs)
	var resumen: Dictionary = t.simular_noche()

	var control := _turno()
	control.entregar_reporte([{"tipo": "agua", "bbl_h": 10.0, "tanque": "Succión"}])
	control.simular_noche()

	# 120 bbl de agua × 1 lb/bbl = 120 lb de PAC → 2 sacos de 50 lb (quedan 20 lb a cuenta).
	verificar_cerca(t.inventario.disponible("pac"), 8.0, 1e-6, "usó 2 sacos de PAC")
	verificar_cerca(resumen["volumen"]["construido"], 120.0, 1e-6, "120 bbl de agua en 12 h")
	verificar(resumen["volumen"]["cuadra"], "el balance de la noche cuadra")
	var pac: float = t.tanque("Succión").lodo.pac
	var pac_control: float = control.tanque("Succión").lodo.pac
	verificar(pac > pac_control + 0.1, "con la recomendación queda más PAC (%.3f vs %.3f)" % [pac, pac_control])
	verificar(pac_control < pac0, "sin ella el agua lo diluye")
	verificar(resumen["acciones"].size() >= 2, "la noche deja registro de lo que hizo")
	verificar(resumen["costo"] > 0.0, "la noche cuesta")

	t.iniciar_dia()
	verificar(t.dia == 2 and t.reloj.minuto == 0.0, "día 2 a las 06:00")
	var r2 = t.entregar_reporte()
	verificar(r2.noche_anterior.has("acciones"), "el reporte siguiente trae el resumen de la noche")
	verificar(r2.costo_acumulado >= resumen["costo"], "el acumulado sigue")


func test_noche_mantiene_el_ph() -> void:
	var t := _turno()
	var ph0: float = t.tanque("Succión").lodo.ph()
	t.entregar_reporte([{"tipo": "mantener_ph", "min": ph0 + 0.4, "max": ph0 + 1.0, "tanque": "Succión"}])
	t.simular_noche()
	verificar(t.inventario.disponible("soda_caustica") < 20.0, "la cuadrilla echó soda")
	verificar(t.tanque("Succión").lodo.ph() >= ph0 + 0.3, "el pH subió al rango (%.2f)" % t.tanque("Succión").lodo.ph())


func test_reporte_cubre_24_horas() -> void:
	# Decisión del autor: el reporte diario cubre la noche anterior y el turno de día.
	var t := _turno()
	var r1 = t.entregar_reporte([{"tipo": "agua", "bbl_h": 10.0, "tanque": "Succión"}])
	verificar_cerca(r1.horas, 12.0, 1e-6, "el primer día solo tiene turno de día")
	var noche: Dictionary = t.simular_noche()
	t.iniciar_dia()
	t.tratar("soda_caustica", 0.1, "Succión")
	var r2 = t.entregar_reporte()
	verificar_cerca(r2.horas, 24.0, 1e-6, "día 2: 24 h")
	verificar(r2.volumen["construido"] >= 120.0 - 1e-6, "el agua de la noche entra al balance: %.1f" % r2.volumen["construido"])
	verificar(r2.volumen["cuadra"], "el balance de 24 h cuadra")
	verificar(r2.costo_dia > noche["costo"], "costo de la noche más el del día")
	var nombres: Array = r2.productos.map(func(p): return p["producto"])
	verificar(nombres.size() >= 2, "productos de la noche y del día: %s" % str(nombres))
