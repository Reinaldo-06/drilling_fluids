extends SceneTree
## Capturas reales del primer caso (necesita pantalla, p. ej. xvfb-run):
##   xvfb-run -a godot --path . --script res://tools/captura_caso.gd
## Salidas en docs/img/: caso_1_objetivo, caso_2_alarma, caso_3_balance,
## caso_4_diagnostico, caso_5_explicacion (×3).

const ESCALA := 3


func _init() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await _esperar(3)
	var ow: Node2D = main.overworld
	var sesion = main.escenario["sesion"]
	var puente = main.puente
	ow.dialogo._texto.visible_characters = -1
	await _esperar(3)
	_guardar("caso_1_objetivo")
	while ow.dialogo.abierto:
		ow.dialogo.avanzar()
	ow.jugador.bloqueado = false

	# pasa el tiempo hasta que suena el PVT
	var alarma := ""
	for k in 40:
		sesion.interactuar("caseta_lodos")
		var r: Dictionary = sesion.ejecutar("esperar", {"minutos": 10.0})
		for a in r["avisos"]:
			if a["tipo"] == "alarma_pvt":
				alarma = a["texto"]
		if main.escenario["turno"].seguimiento.alarma_vista:
			break
	puente.overworld.mostrar_dialogo([alarma], "Driller")
	puente._refrescar()
	await _esperar(70)
	ow.dialogo._texto.visible_characters = -1
	await _esperar(3)
	_guardar("caso_2_alarma")
	while ow.dialogo.abierto:
		ow.dialogo.avanzar()

	# el mud logger
	ow.interactuar_con(ow.mapa.estaciones["cabina_mud_logger"].celdas[0])
	await _esperar(4)
	puente.menu.confirmar()
	await _esperar(80)
	ow.dialogo._texto.visible_characters = -1
	await _esperar(3)
	_guardar("caso_3_balance")
	while ow.dialogo.abierto:
		ow.dialogo.avanzar()
	ow.jugador.bloqueado = false

	# diagnóstico: el asistente pregunta la causa
	sesion.interactuar("zarandas")
	sesion.ejecutar("observar")
	sesion.interactuar("tanque_succion")
	sesion.ejecutar("observar")
	ow.interactuar_con(ow.mapa.estaciones["caseta_lodos"].celdas[0])
	await _esperar(4)
	var idx: int = puente.menu.opciones.map(func(o): return o["accion"]).find("diagnosticar")
	puente.menu.seleccion = idx
	puente.menu.confirmar()
	await _esperar(4)
	_guardar("caso_4_diagnostico")
	puente.menu.seleccion = 1   # descarte excesivo
	puente.menu.confirmar()
	await _esperar(80)
	ow.dialogo._texto.visible_characters = -1
	await _esperar(3)
	_guardar("caso_5_explicacion")
	quit()


func _esperar(cuadros: int) -> void:
	for i in cuadros:
		await process_frame


func _guardar(nombre: String) -> void:
	var img := root.get_texture().get_image()
	img.resize(img.get_width() * ESCALA, img.get_height() * ESCALA, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path("res://docs/img/%s.png" % nombre))
	print("captura ", nombre)
