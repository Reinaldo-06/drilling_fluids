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


func _turno(guion: Resource, profundidad: float, formacion: Resource = SUPERFICIAL) -> Array:
	var tanques := [
		Tanque.crear("Proceso", 500.0, "proceso", 300.0, Base.disperso_lignosulfonato()),
		Tanque.crear("Succión", 500.0, "succion", 300.0, Base.disperso_lignosulfonato()),
		Tanque.crear("Reserva", 500.0, "reserva", 200.0, Base.disperso_lignosulfonato(), false),
	]
	var t = Turno.crear(tanques, PROGRAMA, {"barita": 500.0, "pac": 20.0})
	t.caudal_gpm = 700.0
	t.profundidad_ft = profundidad
	t.volumen_pozo_bbl = 0.15 * profundidad
	var o = Operacion.crear([formacion], guion, 60.0, 17.5)
	o.conectar(t)
	return [t, o]


func _tipos(avisos: Array) -> Array:
	return avisos.map(func(a): return a["tipo"])


func test_perforar_cuadra_el_balance_sin_eventos() -> void:
	var impermeable: Resource = SUPERFICIAL.duplicate()
	impermeable.perdida_filtracion_bbl_h = 0.0
	var par := _turno(null, 500.0, impermeable)
	var t = par[0]
	var vol0: float = t.volumen_superficie()
	t.esperar(120.0)
	verificar_cerca(t.profundidad_ft, 620.0, 0.5, "60 ft/h durante 2 h")
	verificar(t.volumen_superficie() < vol0, "el hueco y los recortes consumen volumen")
	var r = t.entregar_reporte()
	verificar(r.volumen["cuadra"], "sin pérdidas, el balance cuadra: %s" % str(r.volumen))
	verificar(t.horas_equipos.get("zaranda", 0.0) > 2.0, "las zarandas suman horas")


func test_filtracion_sin_avisar_la_detecta_el_pvt_y_el_balance() -> void:
	# Filtración de las gravas superficiales (~8 bbl/h, sale de la formación): nadie la avisa.
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


func test_transferir_dentro_del_activo_no_alarma() -> void:
	var par := _turno(null, 500.0)
	var t = par[0]
	var r: Dictionary = t.transferir("Proceso", "Succión", 50.0)
	verificar(t.alarmas_pvt == 0, "el total del activo no cambia")
	verificar(not "transferir_sin_avisar" in r["hallazgos"].map(func(h): return h["id"]),
		"la regla no se dispara")


# --- Pérdidas por filtración según la formación (decisión del autor) ---

const PRODUCTORA := preload("res://data/formaciones/caiman_3_arena_productora.tres")
const LUTITA := preload("res://data/formaciones/caiman_3_lutita_reactiva.tres")
const Perforacion := preload("res://sim/perforacion.gd")
const PAC := preload("res://data/productos/pac.tres")
const CACO3 := preload("res://data/productos/carbonato_de_calcio.tres")


func test_arenas_pierden_y_lutitas_no() -> void:
	var lodo = Base.disperso_lignosulfonato()
	var arena: float = Perforacion.tasa_filtracion(lodo, SUPERFICIAL)
	verificar(arena >= 1.0 and arena <= 10.0, "filtración en las gravas, 1–10 bbl/h: %.1f" % arena)
	verificar(Perforacion.tasa_filtracion(lodo, PRODUCTORA) > 0.0, "la arena productora también")
	verificar_cerca(Perforacion.tasa_filtracion(lodo, LUTITA), 0.0, 1e-9, "la lutita no pierde")


func test_subir_el_controlador_de_filtrado_baja_la_perdida() -> void:
	var lodo = Base.disperso_lignosulfonato()
	var antes: float = Perforacion.tasa_filtracion(lodo, SUPERFICIAL)
	PAC.aplicar(lodo, 1.0)
	var con_pac: float = Perforacion.tasa_filtracion(lodo, SUPERFICIAL)
	verificar(con_pac < 0.85 * antes, "1 lb/bbl de PAC: %.1f → %.1f bbl/h" % [antes, con_pac])
	CACO3.aplicar(lodo, 10.0)
	var con_caco3: float = Perforacion.tasa_filtracion(lodo, SUPERFICIAL)
	verificar(con_caco3 < 0.6 * con_pac, "10 lb/bbl de CaCO₃ puentea: %.1f → %.1f bbl/h" % [con_pac, con_caco3])


func test_la_orden_de_sacos_de_pac_reduce_lo_perdido_en_el_turno() -> void:
	var par_sin := _turno(null, 500.0)   # el par guarda viva la operación
	var par_con := _turno(null, 500.0)
	var sin = par_sin[0]
	var con = par_con[0]
	# 12 sacos de PAC (600 lb, ~1 lb/bbl en el activo) por el obrero de patio.
	con.ordenar_mezcla("pac", 12.0, "Succión", false, "obrero_patio")
	sin.esperar(240.0)
	con.esperar(240.0)
	var perdido_sin: float = -sin.entregar_reporte().volumen["no_explicado"]
	var perdido_con: float = -con.entregar_reporte().volumen["no_explicado"]
	verificar(perdido_sin > 20.0, "sin tratar se pierden ~8 bbl/h: %.1f bbl en 4 h" % perdido_sin)
	verificar(perdido_con < perdido_sin - 3.0, "con PAC se pierde menos: %.1f contra %.1f" % [perdido_con, perdido_sin])


# --- Volumen: se conserva y la succión tiene mínimo (auditoría C2) ---

func test_el_hueco_sale_de_todo_el_activo_y_las_bombas_paran_sin_nivel() -> void:
	var impermeable: Resource = SUPERFICIAL.duplicate()
	impermeable.perdida_filtracion_bbl_h = 0.0
	var par := _turno(null, 500.0, impermeable)
	var t = par[0]
	var o = par[1]
	o.rop_ft_h = 80.0
	t.esperar(240.0)
	var proceso: float = t.tanque("Proceso").volumen_bbl
	var succion: float = t.tanque("Succión").volumen_bbl
	verificar(absf(proceso - succion) < 0.15 * proceso,
		"los dos tanques del activo bajan parejo (proceso %.0f, succión %.0f)" % [proceso, succion])
	t.esperar(470.0)
	verificar(o.bombas_paradas, "con la succión bajo el mínimo, el driller para las bombas")
	verificar(t.tanque("Succión").volumen_bbl >= t.tanque("Succión").minimo_bbl() - 15.0,
		"no se sigue vaciando: %.0f bbl" % t.tanque("Succión").volumen_bbl)
	var avisos: Array = t.tomar_avisos()
	verificar(avisos.any(func(a): return a["tipo"] == "bombas_paradas"), "el driller avisa por qué paró")
	var profundidad: float = t.profundidad_ft
	t.esperar(5.0)
	verificar_cerca(t.profundidad_ft, profundidad, 1e-9, "sin bombas no se perfora")
	var r = t.entregar_reporte()
	verificar(r.volumen["cuadra"], "el volumen se conserva: %s" % str(r.volumen))


func test_con_volumen_de_la_reserva_las_bombas_vuelven() -> void:
	var par := _turno(null, 500.0)
	var t = par[0]
	var o = par[1]
	t.tanque("Succión").volumen_bbl = 100.0
	t.tanque("Proceso").volumen_bbl = 100.0
	t.esperar(10.0)
	verificar(o.bombas_paradas, "100 bbl en una succión de 500: bajo el mínimo")
	t.avisar_driller()
	t.transferir("Reserva", "Succión", 100.0)
	t.esperar(10.0)
	verificar(not o.bombas_paradas, "con nivel, vuelven las bombas")
	verificar(t.caudal_gpm > 0.0, "y el caudal")


# --- Cemento de la zapata: se rota dentro del revestidor, una sola fuente (auditoría C4) ---

const GUION_INT := preload("res://data/guiones/caiman_3_intermedia.tres")
const PROGRAMA_INT := preload("res://data/programas/caiman_3_intermedia.tres")
const CEMENTO := preload("res://data/formaciones/caiman_3_cemento_zapata.tres")
const INTERMEDIA_SUP := preload("res://data/formaciones/caiman_3_intermedia_superior.tres")


func _intermedia() -> Array:
	var tanques := [
		Tanque.crear("Proceso", 500.0, "proceso", 400.0, Base.disperso_lignosulfonato()),
		Tanque.crear("Succión", 500.0, "succion", 400.0, Base.disperso_lignosulfonato()),
		Tanque.crear("Reserva", 500.0, "reserva", 300.0, Base.disperso_lignosulfonato(), false),
	]
	var t = Turno.crear(tanques, PROGRAMA_INT, {"barita": 500.0})
	t.caudal_gpm = 600.0
	t.profundidad_ft = PROGRAMA_INT.profundidad_de_arranque()
	t.volumen_pozo_bbl = 0.15 * 2500.0
	var o = Operacion.crear([CEMENTO, INTERMEDIA_SUP], GUION_INT, 60.0, 12.25)
	o.conectar(t)
	return [t, o]


func test_la_intermedia_arranca_en_el_collar_flotador_y_rota_el_cemento() -> void:
	verificar_cerca(PROGRAMA_INT.profundidad_de_arranque(), 2420.0, 1e-9, "80 ft sobre la zapata")
	var par := _intermedia()
	var t = par[0]
	var pm0: float = t.tanque("Succión").lodo.pm()
	t.esperar(60.0)   # 60 ft: todavía en el cemento
	verificar(t.profundidad_ft > 2420.0 and t.profundidad_ft < 2500.0, "rotando cemento a %.0f ft" % t.profundidad_ft)
	var avisos: Array = t.tomar_avisos()
	var del_cemento: Array = avisos.filter(func(a): return a.get("id", "") == "c3i_cemento_zapata")
	verificar(del_cemento.size() == 1 and del_cemento[0]["quien_avisa"] == "driller",
		"el driller avisa una vez que rota cemento")
	verificar(t.tanque("Succión").lodo.pm() > pm0 + 0.3, "el Pm sube: la contaminación sale de perforarlo")
	verificar(t.tanque("Succión").lodo.finos_cemento > 0.0, "entran finos de cemento")


func test_el_cemento_contamina_una_sola_vez() -> void:
	# Antes (C4) el cemento entraba por la formación Y por el evento. Ahora la
	# cal aportada es la de los pies de cemento rotados y nada más.
	var par := _intermedia()
	var t = par[0]
	t.esperar(100.0)    # 100 min a 60 ft/h → pasa los 80 ft de cemento
	verificar(t.profundidad_ft > 2500.0, "ya en formación nueva: %.0f ft" % t.profundidad_ft)
	var cal_y_finos: float = t.tanque("Succión").lodo.cal_exceso + t.tanque("Succión").lodo.finos_cemento
	var cemento_bbl: float = 80.0 * 0.1458   # 12,25" → ~0,146 bbl/ft
	var cal_maxima: float = CEMENTO.contaminante_por_bbl_roca * cemento_bbl * (1.0 - CEMENTO.porosidad) / 800.0
	verificar(cal_y_finos > 0.0 and cal_y_finos < 0.2 + cal_maxima + 0.1,
		"cal total %.2f lb/bbl ≤ base 0,2 + lo que aportan 80 ft de cemento (%.2f)" % [cal_y_finos, cal_maxima])
	var historial: Array = par[1].guion.historial
	verificar(historial.filter(func(a): return a["id"] == "c3i_cemento_zapata").size() == 1, "un solo aviso")
	verificar(not historial.any(func(a): return a["tipo"] == "contaminacion"), "ningún evento contamina además")
