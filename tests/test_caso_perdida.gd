extends "res://tests/test_case.gd"
## Primer caso jugable de CAIMÁN-3 (plan de desarrollo, Paso 3): el activo pierde
## lodo en las gravas de la superficial. Alarma → evidencia → diagnóstico →
## tratamiento → verificación, jugado solo con las acciones del menú.
## Fuente de la física: simulation-logic.md §10.1 (filtración según la formación,
## PAC y puenteo con carbonato de calcio).

const Escenarios := preload("res://sim/escenarios.gd")
const Seguimiento := preload("res://sim/seguimiento_caso.gd")
const CASO := preload("res://data/casos/caiman_3_perdida_gravas.tres")


func _juego() -> Dictionary:
	var e: Dictionary = Escenarios.caiman_3_superficial()
	return {"s": e["sesion"], "t": e["turno"], "seg": e["turno"].seguimiento, "alarma": {}}


## Va a una estación del mapa y hace una acción con parámetros.
func _hacer(j: Dictionary, estacion: String, accion: String, params := {}) -> Dictionary:
	j["s"].interactuar(estacion)
	return j["s"].ejecutar(accion, params)


## Deja pasar el tiempo de a 10 min hasta que suena el PVT. Guarda el aviso en
## j["alarma"] (cada acción consume la lista de avisos del turno).
func _hasta_la_alarma(j: Dictionary) -> void:
	for i in 40:
		j["s"].interactuar("caseta_lodos")
		var r: Dictionary = j["s"].ejecutar("esperar", {"minutos": 10.0})
		for a in r["avisos"]:
			if a["tipo"] == "alarma_pvt":
				j["alarma"] = a
		if j["seg"].alarma_vista:
			return


func _ids(r: Dictionary) -> Array:
	return r["hallazgos"].map(func(h): return h["id"])


## Ordena una mezcla a la misma dosis (sacos) en cada tanque del activo.
func _tratar(j: Dictionary, quien: String, producto: String, sacos: float, tanques := ["Succión", "Proceso"]) -> void:
	for tanque in tanques:
		var r := _hacer(j, "tanque_succion", "ordenar_mezcla",
			{"producto": producto, "sacos": sacos, "tanque": tanque, "quien": quien})
		verificar(r["ok"], "orden de %s: %s" % [producto, r["mensaje"]])


# --- Datos del caso ---

func test_el_caso_esta_bien_formado() -> void:
	verificar(CASO.causas.size() == 3, "tres causas plausibles")
	verificar(CASO.causas.filter(func(c): return c["correcta"]).size() == 1, "una sola correcta")
	for c: Dictionary in CASO.causas:
		verificar(str(c["explicacion"]).length() > 60, "%s trae su explicación" % c["id"])
	for id in CASO.evidencias_requeridas:
		verificar(CASO.nombres_de_evidencia.has(id), "la evidencia %s tiene nombre" % id)
	var programa: Resource = load("res://data/programas/caiman_3_superficial.tres")
	for p in CASO.productos_de_tratamiento:
		if p != "bentonita":
			verificar(programa.puede_usar(p), "el programa aprueba %s" % p)


# --- 1. La alarma ---

func test_la_perdida_dispara_la_alarma_sin_nombrar_la_causa() -> void:
	var j := _juego()
	_hasta_la_alarma(j)
	verificar(j["seg"].alarma_vista, "el PVT dio la alarma")
	var aviso: Dictionary = j["alarma"]
	verificar(not aviso.is_empty(), "hay aviso de alarma")
	var texto := (str(aviso["texto"]) + str(aviso.get("quien_avisa", ""))).to_lower()
	for prohibida in ["filtra", "grava", "arena", "formaci", "permeab", "pac", "carbonato"]:
		verificar(not texto.contains(prohibida), "la alarma no dice '%s': %s" % [prohibida, texto])
	verificar(j["t"].reloj.minuto < 180.0, "salta pronto: %.0f min" % j["t"].reloj.minuto)


# --- 2. La evidencia ---

func test_el_mud_logger_mide_la_perdida_sin_decir_la_causa() -> void:
	var j := _juego()
	_hasta_la_alarma(j)
	var r := _hacer(j, "cabina_mud_logger", "revisar_balance")
	verificar(r["ok"], r["mensaje"])
	var tasa: float = r["detalle"]["perdida_bbl_h"]
	verificar(tasa >= 6.0 and tasa <= 11.0, "mide ~8,5 bbl/h: %.1f" % tasa)
	verificar(r["minutos"] == 5.0, "cuesta 5 min, sin caminata del mapa")
	for prohibida in ["filtra", "grava", "formaci"]:
		verificar(not r["mensaje"].to_lower().contains(prohibida), "no dice la causa ('%s')" % prohibida)
	verificar(j["seg"].evidencias.has("balance_volumen"), "queda como evidencia")


func test_las_zarandas_y_los_tanques_descartan_otras_causas() -> void:
	var j := _juego()
	_hasta_la_alarma(j)
	var z := _hacer(j, "zarandas", "observar")
	verificar(z["ok"], z["mensaje"])
	verificar(z["mensaje"].contains("arena y grava"), "los recortes: %s" % z["mensaje"])
	verificar(z["mensaje"].contains("mallas están enteras"), "y las mallas están bien")
	var t := _hacer(j, "tanque_succion", "observar")
	verificar(t["mensaje"].contains("Succión") and t["mensaje"].contains("bbl de 500"), "los niveles")
	verificar(t["mensaje"].contains("No hay derrames"), "y no hay derrames")
	verificar(j["seg"].faltan_evidencias() == ["balance_volumen"], "solo falta el balance")


func test_con_una_malla_rota_el_descarte_si_se_ve() -> void:
	var j := _juego()
	var o = Escenarios.caiman_3_superficial()["operacion"]
	o.control.fijar_estado("zaranda", "malla_rota")
	var textos: Array = o._observar(j["t"], "zarandas")
	verificar(" ".join(textos).contains("malla rota"), "una malla rota se ve en las zarandas")


# --- 3. El diagnóstico ---

func test_diagnosticar_sin_evidencia_lo_advierte() -> void:
	var j := _juego()
	_hasta_la_alarma(j)
	var r := _hacer(j, "caseta_lodos", "diagnosticar", {"diagnostico": "filtracion_formacion"})
	verificar("caso_diagnostico_sin_evidencia" in _ids(r), "advierte: %s" % str(_ids(r)))
	verificar("caso_diagnostico_correcto" in _ids(r), "aunque acertó, lo explica")
	verificar(r["hallazgos"].all(func(h): return h["explicacion"].length() > 30), "cada hallazgo trae su porqué")


func test_un_diagnostico_equivocado_se_explica_con_la_evidencia() -> void:
	var j := _juego()
	_hasta_la_alarma(j)
	_hacer(j, "cabina_mud_logger", "revisar_balance")
	_hacer(j, "zarandas", "observar")
	_hacer(j, "tanque_succion", "observar")
	var r := _hacer(j, "caseta_lodos", "diagnosticar", {"diagnostico": "descarte_excesivo"})
	verificar("caso_diagnostico_incorrecto" in _ids(r), "es un error")
	verificar(not "caso_diagnostico_sin_evidencia" in _ids(r), "con toda la evidencia ya no advierte eso")
	var explicacion: String = r["hallazgos"].filter(func(h): return h["id"] == "caso_diagnostico_incorrecto")[0]["explicacion"]
	verificar(explicacion.contains("zarandas") and explicacion.contains("balance"), "dice por qué no: %s" % explicacion)
	verificar(not j["seg"].diagnostico_correcto, "no cuenta como acierto")
	var ok := _hacer(j, "caseta_lodos", "diagnosticar", {"diagnostico": "filtracion_formacion"})
	verificar("caso_diagnostico_correcto" in _ids(ok) and j["seg"].diagnostico_correcto, "y se puede corregir")


func test_no_se_pide_mas_evidencia() -> void:
	var j := _juego()
	var r := _hacer(j, "caseta_lodos", "diagnosticar", {"diagnostico": "no_se"})
	verificar("caso_sin_diagnostico" in _ids(r) and not j["seg"].diagnostico_correcto, "aconseja reunir evidencia")


# --- 4. Tratamiento y verificación ---

func _hasta_el_diagnostico(j: Dictionary) -> void:
	_hasta_la_alarma(j)
	_hacer(j, "cabina_mud_logger", "revisar_balance")
	_hacer(j, "zarandas", "observar")
	_hacer(j, "tanque_succion", "observar")
	_hacer(j, "caseta_lodos", "diagnosticar", {"diagnostico": "filtracion_formacion"})


func test_solo_pac_no_alcanza_y_se_dice() -> void:
	var j := _juego()
	_hasta_el_diagnostico(j)
	_tratar(j, "encuellador", "pac", 8.0)      # 1 lb/bbl, el máximo del programa
	_hacer(j, "caseta_lodos", "esperar", {"minutos": 240.0})
	var r := _hacer(j, "cabina_mud_logger", "revisar_balance")
	verificar("caso_tratamiento_insuficiente" in _ids(r), "dice que la pérdida sigue: %s" % str(_ids(r)))
	verificar(r["detalle"]["perdida_bbl_h"] > CASO.tasa_objetivo_bbl_h, "%.1f bbl/h" % r["detalle"]["perdida_bbl_h"])
	verificar(not j["seg"].resuelto, "no está resuelto")
	var explicacion: String = r["hallazgos"][0]["explicacion"]
	verificar(explicacion.contains("carbonato de calcio"), "y dice qué falta: %s" % explicacion)


func test_el_caso_completo_con_pac_y_puenteo() -> void:
	var j := _juego()
	_hasta_el_diagnostico(j)
	var antes: float = _hacer(j, "cabina_mud_logger", "revisar_balance")["detalle"]["perdida_bbl_h"]
	# PAC por el encuellador y, en paralelo, carbonato de calcio por los dos (10 lb/bbl)
	_tratar(j, "encuellador", "pac", 8.0)
	_tratar(j, "encuellador", "carbonato_de_calcio", 80.0, ["Succión"])
	_tratar(j, "obrero_patio", "carbonato_de_calcio", 80.0, ["Proceso"])
	_hacer(j, "caseta_lodos", "esperar", {"minutos": 120.0})
	_hacer(j, "caseta_lodos", "esperar", {"minutos": 120.0})
	var r := _hacer(j, "cabina_mud_logger", "revisar_balance")
	var despues: float = r["detalle"]["perdida_bbl_h"]
	verificar(despues <= CASO.tasa_objetivo_bbl_h, "la pérdida bajó de %.1f a %.1f bbl/h" % [antes, despues])
	verificar("caso_resuelto" in _ids(r), "el mud logger lo confirma: %s" % str(_ids(r)))
	verificar(j["seg"].resuelto and j["seg"].verificado, "el caso está resuelto")
	verificar(j["seg"].pasos().all(func(p): return p["hecho"]), "todos los pasos hechos")
	verificar(not j["s"].estado()["terminado"], "y sobra turno: %.0f min restantes" % j["s"].estado()["minutos_restantes"])
	var oficina := _hacer(j, "oficina_company_man", "ver_resumen")
	verificar(oficina["mensaje"].contains("[x] Verificar"), "el resumen lo muestra: %s" % oficina["mensaje"])
	var rep := _hacer(j, "oficina_company_man", "entregar_reporte")
	verificar(rep["detalle"]["reporte"].caso["resuelto"], "y el reporte lo lleva")
	verificar(rep["detalle"]["reporte"].texto().contains("(resuelto)"), "también en el texto")


func test_el_carbonato_de_calcio_solo_tambien_ayuda_pero_el_pac_afina() -> void:
	# Cada tratamiento aporta algo distinto: el PAC baja el filtrado, el carbonato puentea.
	var solo_pac := _juego()
	var solo_caco3 := _juego()
	_hasta_el_diagnostico(solo_pac)
	_hasta_el_diagnostico(solo_caco3)
	_tratar(solo_pac, "encuellador", "pac", 8.0)
	_tratar(solo_caco3, "encuellador", "carbonato_de_calcio", 80.0, ["Succión"])
	_tratar(solo_caco3, "obrero_patio", "carbonato_de_calcio", 80.0, ["Proceso"])
	_hacer(solo_pac, "caseta_lodos", "esperar", {"minutos": 240.0})
	_hacer(solo_caco3, "caseta_lodos", "esperar", {"minutos": 240.0})
	var a: float = _hacer(solo_pac, "cabina_mud_logger", "revisar_balance")["detalle"]["perdida_bbl_h"]
	var b: float = _hacer(solo_caco3, "cabina_mud_logger", "revisar_balance")["detalle"]["perdida_bbl_h"]
	verificar(b < a, "10 lb/bbl de carbonato (%.1f) pierde menos que 1 lb/bbl de PAC (%.1f)" % [b, a])


func test_esperar_sin_tratar_no_resuelve_nada() -> void:
	var j := _juego()
	_hasta_el_diagnostico(j)
	_hacer(j, "caseta_lodos", "esperar", {"minutos": 240.0})
	var r := _hacer(j, "cabina_mud_logger", "revisar_balance")
	verificar(r["detalle"]["perdida_bbl_h"] > CASO.tasa_objetivo_bbl_h, "la pérdida sigue: %.1f" % r["detalle"]["perdida_bbl_h"])
	verificar(not j["seg"].resuelto and r["hallazgos"].is_empty(), "sin tratamiento no hay veredicto")


func test_tratar_sin_diagnosticar_resuelve_pero_se_avisa() -> void:
	var j := _juego()
	_hasta_la_alarma(j)
	_tratar(j, "encuellador", "pac", 8.0)
	_tratar(j, "encuellador", "carbonato_de_calcio", 80.0, ["Succión"])
	_tratar(j, "obrero_patio", "carbonato_de_calcio", 80.0, ["Proceso"])
	_hacer(j, "caseta_lodos", "esperar", {"minutos": 240.0})
	var r := _hacer(j, "cabina_mud_logger", "revisar_balance")
	verificar(r["detalle"]["perdida_bbl_h"] <= CASO.tasa_objetivo_bbl_h, "el tratamiento funciona igual")
	verificar(not j["seg"].resuelto, "pero sin diagnóstico no se da por resuelto")
	verificar(r["hallazgos"][0]["explicacion"].contains("no diagnosticaste"), "y lo dice")


func test_el_programa_manda_sin_pac_no_hay_forma_de_tratar() -> void:
	# Palanca de dificultad (invariante 6): sacar el PAC del programa lo impide.
	var j := _juego()
	var sin_pac: Resource = j["t"].programa.duplicate()
	sin_pac.productos_aprobados = PackedStringArray(Array(sin_pac.productos_aprobados).filter(func(p): return p != "pac"))
	j["t"].programa = sin_pac
	var nombres: Array = j["s"].opciones_de("ordenar_mezcla", "producto").map(func(o): return o["nombre"])
	verificar(not nombres.any(func(n): return n.begins_with("PAC")), "el menú ya no ofrece PAC: %s" % str(nombres))
