extends "res://tests/test_case.gd"
## Contrato overworld ↔ turno (docs/plan-desarrollo.md, Paso 2): tiempo cobrado
## una sola vez, nada a distancia, resultado estándar y turno terminado.

const Turno := preload("res://sim/turno.gd")
const Sesion := preload("res://sim/sesion_turno.gd")
const Accion := preload("res://sim/accion.gd")
const Tanque := preload("res://sim/tanque.gd")
const Base := preload("res://sim/lodos_base.gd")

const PROGRAMA := preload("res://data/programas/caiman_3_superficial.tres")
const TABLA := preload("res://data/turno/estaciones_mapa.tres")
const MAPA := preload("res://game/overworld/mapa_locacion.gd")


func _sesion():
	var tanques := [
		Tanque.crear("Proceso", 500.0, "proceso", 300.0, Base.disperso_lignosulfonato()),
		Tanque.crear("Succión", 500.0, "succion", 300.0, Base.disperso_lignosulfonato()),
		Tanque.crear("Reserva", 500.0, "reserva", 200.0, Base.disperso_lignosulfonato(), false),
	]
	var t = Turno.crear(tanques, PROGRAMA, {"barita": 500.0, "soda_caustica": 20.0, "pac": 10.0})
	return Sesion.crear(t)


const CLAVES_RESULTADO := ["ok", "accion", "minutos", "mensaje", "hallazgos", "avisos",
	"detalle", "hora", "minutos_restantes", "estacion"]


func _es_resultado_estandar(r: Dictionary, nombre: String) -> void:
	for clave in CLAVES_RESULTADO:
		verificar(r.has(clave), "%s: el resultado trae %s" % [nombre, clave])
	verificar(r["mensaje"] is String, "%s: mensaje en texto" % nombre)


# --- Datos: el puente cubre todo el mapa ---

func test_cada_estacion_del_mapa_esta_en_la_tabla() -> void:
	var tabla: Dictionary = TABLA.valor("estaciones")
	for e in MAPA.ESTACIONES:
		verificar(tabla.has(e["id"]), "la estación %s del mapa tiene traducción" % e["id"])
	for id in tabla:
		var est: String = tabla[id]["estacion"]
		verificar(Accion.es_estacion(est), "%s: %s es una estación del turno" % [id, est])
		for a in tabla[id]["acciones"]:
			verificar(TABLA.valor("acciones").has(a), "%s ofrece una acción conocida (%s)" % [id, a])
			if Accion.ESTACION_DE.has(a):
				verificar(Accion.ESTACION_DE[a] == est, "%s: %s se hace en %s" % [id, a, Accion.ESTACION_DE[a]])


# --- 1. El tiempo se cobra una sola vez ---

func test_caminar_cuesta_por_casilla() -> void:
	var s = _sesion()
	var r: Dictionary = s.al_caminar(10)
	_es_resultado_estandar(r, "caminar")
	verificar_cerca(r["minutos"], 10.0 * Accion.minutos("caminar_casilla"), 1e-9, "10 casillas")
	verificar_cerca(s.turno.reloj.minuto, 10.0 * Accion.minutos("caminar_casilla"), 1e-9, "el reloj coincide")
	s.al_caminar(1)
	verificar_cerca(s.turno.reloj.minuto, 11.0 * Accion.minutos("caminar_casilla"), 1e-9, "se acumula")


func test_interactuar_no_cuesta_tiempo() -> void:
	var s = _sesion()
	var m0: float = s.turno.reloj.minuto
	var r: Dictionary = s.interactuar("caseta_lodos")
	verificar(r["ok"] and not r["menu"].is_empty(), "la caseta ofrece acciones")
	verificar_cerca(s.turno.reloj.minuto, m0, 1e-9, "abrir el menú es gratis")


func test_una_accion_no_suma_la_caminata_de_la_tabla() -> void:
	# En el mapa la caminata ya se cobró casilla por casilla: el chequeo rápido
	# cuesta solo lo suyo (10 min), aunque el turno estuviera "lejos" en la tabla.
	var s = _sesion()
	s.interactuar("caseta_lodos")
	s.turno.ubicacion = "oficina"   # forzado: con la tabla, volver a la caseta costaría 6 min
	var m0: float = s.turno.reloj.minuto
	var r: Dictionary = s.ejecutar("chequeo_rapido")
	verificar(r["ok"], "el chequeo se hizo: %s" % r["mensaje"])
	verificar(r["minutos"] <= 10.0 + 1e-9, "dura lo que dura el chequeo, no más (%.1f min)" % r["minutos"])
	verificar_cerca(s.turno.reloj.minuto - m0, r["minutos"], 1e-9, "el reloj avanzó una sola vez")
	verificar(not r["mensaje"].is_empty() and r["mensaje"].contains("densidad"), "dice las lecturas")


func test_sin_mapa_el_turno_sigue_cobrando_la_caminata_de_la_tabla() -> void:
	# El modo de la sesión no cambia el comportamiento de antes.
	var tanques := [Tanque.crear("Succión", 500.0, "succion", 300.0, Base.disperso_lignosulfonato())]
	var t = Turno.crear(tanques, PROGRAMA, {"pac": 10.0})
	t.ubicacion = "oficina"
	var r: Dictionary = t.chequeo_rapido()
	verificar(r["minutos"] >= Accion.minutos_caminar("oficina", "caseta") + 5.0, "suma la caminata de la tabla")


# --- 2. Nada a distancia ---

func test_no_se_actua_sin_interactuar_ni_despues_de_alejarse() -> void:
	var s = _sesion()
	var r: Dictionary = s.ejecutar("chequeo_rapido")
	verificar(not r["ok"] and r["mensaje"].contains("lejos"), "sin estación no hay acción: %s" % r["mensaje"])
	verificar_cerca(r["minutos"], 0.0, 1e-9, "y no cuesta")
	s.interactuar("caseta_lodos")
	s.al_caminar(1)
	verificar(not s.ejecutar("chequeo_rapido")["ok"], "caminar invalida la estación")
	s.interactuar("caseta_lodos")
	verificar(s.ejecutar("chequeo_rapido")["ok"], "volver a interactuar la restablece")


func test_la_estacion_solo_ofrece_lo_suyo() -> void:
	var s = _sesion()
	s.interactuar("bodega_quimicos")
	var r: Dictionary = s.ejecutar("chequeo_rapido")
	verificar(not r["ok"] and r["mensaje"].contains("no se hace aquí"), "en la bodega no hay laboratorio")
	var inv: Dictionary = s.ejecutar("inventario")
	verificar(inv["ok"] and inv["detalle"]["inventario"].has("barita"), "pero sí se ve el inventario")
	verificar_cerca(inv["minutos"], 0.0, 1e-9, "consultarlo no cuesta")


func test_faltan_parametros_se_explica_cual() -> void:
	var s = _sesion()
	s.interactuar("embudo_abajo")
	var r: Dictionary = s.ejecutar("tratar", {"producto": "soda_caustica"})
	verificar(not r["ok"] and r["mensaje"].contains("lb_bbl"), "dice qué falta: %s" % r["mensaje"])


# --- 3. Resultado estándar y feedback ---

func test_tratar_en_el_embudo_y_el_resultado_trae_hallazgos() -> void:
	var s = _sesion()
	s.interactuar("embudo_abajo")
	var r: Dictionary = s.ejecutar("tratar", {"producto": "soda_caustica", "lb_bbl": 0.25, "tanque": "Succión"})
	_es_resultado_estandar(r, "tratar")
	verificar(r["ok"], r["mensaje"])
	verificar_cerca(r["minutos"], 5.0 + 2.0 / 50.0 * 60.0, 1e-6, "5 min + 2 sacos a 50/h, sin caminata")
	verificar(r["hallazgos"].any(func(h): return h["id"] == "tratar_sin_diagnosticar"),
		"las reglas explican: soda sin pruebas químicas")
	verificar(r["hallazgos"].all(func(h): return h["explicacion"] != ""), "cada hallazgo trae su porqué")


func test_un_fallo_no_gasta_tiempo_y_explica() -> void:
	var s = _sesion()
	s.interactuar("embudo_abajo")
	var m0: float = s.turno.reloj.minuto
	var r: Dictionary = s.ejecutar("tratar", {"producto": "soda_caustica", "lb_bbl": 50.0, "tanque": "Succión"})
	_es_resultado_estandar(r, "fallo")
	verificar(not r["ok"] and r["mensaje"].contains("bodega"), "explica: %s" % r["mensaje"])
	verificar_cerca(s.turno.reloj.minuto, m0, 1e-9, "no se gastó tiempo")


# --- Personajes y válvulas ---

func test_hablar_cuesta_y_valvulas_se_anotan_sin_costo() -> void:
	var s = _sesion()
	var r: Dictionary = s.hablar_con("driller")
	verificar(r["ok"], r["mensaje"])
	verificar_cerca(r["minutos"], Accion.minutos("hablar"), 1e-9, "hablar cuesta lo de la tabla, sin caminata")
	verificar(s.hablar_con("cuadrillero")["ok"], "el obrero de patio también está en el turno")
	var m0: float = s.turno.reloj.minuto
	s.valvula("valvula_reserva_1", true)
	verificar(s.valvulas["valvula_reserva_1"], "queda anotada")
	verificar_cerca(s.turno.reloj.minuto, m0, 1e-9, "no cuesta")


# --- 4. Fin del turno ---

func test_con_el_turno_terminado_solo_queda_el_reporte() -> void:
	var s = _sesion()
	s.turno.reloj.minuto = s.turno.reloj.duracion - 0.1
	var r: Dictionary = s.al_caminar(5)
	verificar(not r["ok"], "no entran 5 casillas (%s)" % r["mensaje"])
	verificar_cerca(s.turno.reloj.minuto, s.turno.reloj.duracion - 0.1, 1e-9, "y no se gastó nada")
	s.turno.reloj.minuto = s.turno.reloj.duracion
	verificar(not s.al_caminar(1)["ok"], "terminado: no se camina")
	var caseta: Dictionary = s.interactuar("caseta_lodos")
	verificar(caseta["menu"].is_empty() and caseta["mensaje"].contains("reporte"), "la caseta ya no ofrece nada")
	verificar(not s.ejecutar("chequeo_rapido")["ok"], "no se corre laboratorio")
	var oficina: Dictionary = s.interactuar("oficina_company_man")
	verificar(oficina["menu"].size() == 1 and oficina["menu"][0]["accion"] == "entregar_reporte",
		"la oficina sí: el reporte")
	var rep: Dictionary = s.ejecutar("entregar_reporte")
	verificar(rep["ok"] and rep["detalle"]["tarde"], "se entrega tarde y se dice")


func test_el_reporte_se_entrega_con_tiempo() -> void:
	var s = _sesion()
	s.interactuar("oficina_company_man")
	var rep: Dictionary = s.ejecutar("entregar_reporte")
	verificar(rep["ok"], rep["mensaje"])
	verificar_cerca(rep["minutos"], Accion.minutos("entregar_reporte"), 1e-9, "cuesta lo suyo")
	verificar(not rep["detalle"]["tarde"], "a tiempo")


func test_estado_para_el_reloj_visible() -> void:
	var s = _sesion()
	var e: Dictionary = s.estado()
	verificar(e["hora"] == "06:00" and e["minutos_restantes"] == 720.0, "arranca a las 06:00 con 720 min")
	s.al_caminar(20)
	verificar(s.estado()["hora"] == "06:03", "20 casillas = 3 min: %s" % s.estado()["hora"])


# --- Escenario jugable de punta a punta ---

const Escenarios := preload("res://sim/escenarios.gd")


func test_un_dia_de_caiman_3_superficial_de_punta_a_punta() -> void:
	var e: Dictionary = Escenarios.caiman_3_superficial()
	var s = e["sesion"]
	var t = e["turno"]
	# Recorre la locación, hace el chequeo rápido, deja pasar el día y entrega el reporte.
	s.al_caminar(5)
	verificar(s.interactuar("caseta_lodos")["ok"], "llega a la caseta")
	var chequeo: Dictionary = s.ejecutar("chequeo_rapido")
	verificar(chequeo["ok"], chequeo["mensaje"])
	verificar(s.ejecutar("esperar", {"minutos": 300.0})["ok"], "pasan 5 horas")
	s.interactuar("tanque_succion")
	verificar(t.profundidad_ft > Escenarios.PROFUNDIDAD_INICIAL_FT + 200.0, "se perforó: %.0f ft" % t.profundidad_ft)
	s.interactuar("oficina_company_man")
	var reporte: Dictionary = s.ejecutar("entregar_reporte")
	verificar(reporte["ok"], reporte["mensaje"])
	var r = reporte["detalle"]["reporte"]
	verificar(r.horas == 12.0, "el primer día cubre 12 h")
	verificar(not r.volumen["cuadra"], "la filtración de las gravas deja volumen sin explicar")
	var noche: Dictionary = t.simular_noche()
	verificar(noche["minutos"] > 0.0, "y la noche corre")


func test_el_turno_de_doce_horas_perfora_la_jornada_completa() -> void:
	var e: Dictionary = Escenarios.caiman_3_superficial()
	var s = e["sesion"]
	s.interactuar("caseta_lodos")
	s.ejecutar("esperar", {"minutos": 720.0})
	verificar(s.estado()["terminado"], "el día se acaba")
	verificar(e["turno"].profundidad_ft > Escenarios.PROFUNDIDAD_INICIAL_FT + 500.0, "perforó la jornada")
