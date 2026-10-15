extends "res://tests/test_case.gd"
## Puente overworld ↔ turno (Paso 2): las señales reales del mapa llegan a la
## sesión y la interfaz muestra el reloj, el menú y el porqué. Sin ventana.

const ESCENA := preload("res://game/overworld/overworld.tscn")
const Puente := preload("res://game/puente_turno.gd")
const Hud := preload("res://game/ui/hud_turno.gd")
const Menu := preload("res://game/ui/menu_acciones.gd")
const Escenarios := preload("res://sim/escenarios.gd")
const Accion := preload("res://sim/accion.gd")


func _montar() -> Dictionary:
	var arbol := Engine.get_main_loop() as SceneTree
	var ow: Node2D = ESCENA.instantiate()
	arbol.root.add_child(ow)
	ow.construir()
	var e: Dictionary = Escenarios.caiman_3_superficial()
	var puente := Puente.new()
	arbol.root.add_child(puente)
	puente.conectar(ow, e["sesion"])
	return {"ow": ow, "puente": puente, "sesion": e["sesion"], "turno": e["turno"]}


func _interactuar_con(m: Dictionary, id_estacion: String) -> void:
	# el camino real: el jugador "mira" una casilla de la estación y aprieta interactuar
	var celda: Vector2i = m["ow"].mapa.estaciones[id_estacion].celdas[0]
	m["ow"].interactuar_con(celda)


func _limpiar(m: Dictionary) -> void:
	m["puente"].free()
	m["ow"].free()


# --- Textos puros ---

func test_texto_del_reloj() -> void:
	var estado := {"dia": 1, "hora": "06:00", "minutos_restantes": 720.0, "terminado": false}
	verificar(Hud.texto_de(estado) == "Día 1  06:00  (720 min)", Hud.texto_de(estado))
	estado["terminado"] = true
	verificar(Hud.texto_de(estado).contains("FIN DEL TURNO"), "avisa que terminó")


func test_texto_de_las_opciones_del_menu() -> void:
	var activa := {"accion": "a", "nombre": "Chequeo rápido", "habilitada": true}
	var apagada := {"accion": "b", "nombre": "Tratar", "habilitada": false}
	verificar(Menu.texto_de_opcion(activa, true) == "> Chequeo rápido", "flecha en la elegida")
	verificar(Menu.texto_de_opcion(apagada, false) == "  Tratar (pronto)", "las apagadas lo dicen")


# --- Del mapa al turno ---

func test_caminar_avanza_el_reloj_visible() -> void:
	var m := _montar()
	m["ow"].caminado.emit(1)
	m["ow"].caminado.emit(1)
	verificar_cerca(m["turno"].reloj.minuto, 2.0 * Accion.minutos("caminar_casilla"), 1e-9, "dos pasos, dos casillas")
	verificar(m["puente"].hud._texto.text.begins_with("Día 1  06:00"), "reloj: %s" % m["puente"].hud._texto.text)
	_limpiar(m)


func test_interactuar_con_la_caseta_abre_el_menu() -> void:
	var m := _montar()
	_interactuar_con(m, "caseta_lodos")
	var menu: Node = m["puente"].menu
	verificar(menu.abierto, "se abrió el menú")
	verificar(m["ow"].jugador.bloqueado, "el jugador no camina mientras elige")
	var por_accion := {}
	for o in menu.opciones:
		por_accion[o["accion"]] = o["habilitada"]
	verificar(por_accion.get("chequeo_rapido", false), "el chequeo rápido se puede hacer")
	verificar(por_accion.has("correr_prueba") and not por_accion["correr_prueba"],
		"correr una prueba espera su pantalla")
	verificar_cerca(m["turno"].reloj.minuto, 0.0, 1e-9, "abrir el menú no cuesta")
	_limpiar(m)


func test_elegir_una_accion_la_ejecuta_y_la_cuenta() -> void:
	var m := _montar()
	_interactuar_con(m, "caseta_lodos")
	var menu: Node = m["puente"].menu
	var i: int = menu.opciones.map(func(o): return o["accion"]).find("chequeo_rapido")
	menu.seleccion = i
	menu.confirmar()
	verificar(not menu.abierto, "el menú se cierra")
	verificar(m["turno"].reloj.minuto > 0.0 and m["turno"].reloj.minuto <= 10.0, "cuesta lo del chequeo")
	var dialogo: Node = m["ow"].dialogo
	verificar(dialogo.abierto and dialogo.paginas.size() > 0, "se muestra el resultado")
	verificar(" ".join(dialogo.paginas).contains("densidad"), "con las lecturas: %s" % str(dialogo.paginas))
	_limpiar(m)


func test_las_opciones_apagadas_no_se_pueden_elegir() -> void:
	var m := _montar()
	_interactuar_con(m, "embudo_abajo")
	var menu: Node = m["puente"].menu
	menu.seleccion = 0
	verificar(not menu.opciones[0]["habilitada"], "tratar espera su pantalla (Hito 3)")
	menu.confirmar()
	verificar(menu.abierto, "sigue abierto")
	verificar_cerca(m["turno"].reloj.minuto, 0.0, 1e-9, "y no pasó nada")
	_limpiar(m)


func test_estacion_sin_acciones_muestra_su_texto() -> void:
	var m := _montar()
	_interactuar_con(m, "zarandas")
	verificar(not m["puente"].menu.abierto, "no hay menú")
	verificar(m["ow"].dialogo.abierto and " ".join(m["ow"].dialogo.paginas).contains("mallas"),
		"muestra qué es: %s" % str(m["ow"].dialogo.paginas))
	_limpiar(m)


func test_hablar_con_un_personaje_cuesta() -> void:
	var m := _montar()
	m["ow"].hablado_con.emit("driller")
	verificar_cerca(m["turno"].reloj.minuto, Accion.minutos("hablar"), 1e-9, "hablar son 10 min")
	_limpiar(m)


func test_las_valvulas_se_anotan_en_la_sesion() -> void:
	var m := _montar()
	_interactuar_con(m, "valvula_reserva_1")
	verificar(m["sesion"].valvulas.has("valvula_reserva_1"), "la válvula llegó a la sesión")
	_limpiar(m)


func test_al_terminar_el_turno_se_avisa_una_sola_vez() -> void:
	var m := _montar()
	m["turno"].reloj.minuto = m["turno"].reloj.duracion
	m["ow"].caminado.emit(1)
	verificar(m["ow"].dialogo.abierto and " ".join(m["ow"].dialogo.paginas).contains("terminó"), "avisa que terminó")
	m["ow"].dialogo.avanzar()
	while m["ow"].dialogo.abierto:
		m["ow"].dialogo.avanzar()
	m["ow"].caminado.emit(1)
	verificar(not m["ow"].dialogo.abierto, "no repite el aviso en cada paso")
	verificar(m["puente"].hud._texto.text.contains("FIN DEL TURNO"), "el reloj lo marca")
	_limpiar(m)


func test_el_dialogo_respeta_los_saltos_de_linea() -> void:
	var paginas: Array[String] = load("res://game/ui/dialogo.gd").paginar(["uno\ndos\ntres"])
	verificar(paginas.size() == 2 and paginas[0] == "uno\ndos" and paginas[1] == "tres",
		"dos líneas por página: %s" % str(paginas))
