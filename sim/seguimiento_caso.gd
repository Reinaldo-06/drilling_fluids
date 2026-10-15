extends RefCounted
## Avance del jugador en un caso (sim/caso.gd): alarma → evidencia → diagnóstico
## → tratamiento → verificación. Devuelve hallazgos con la forma de las reglas
## ({id, titulo, tipo, explicacion, referencia}) para que la interfaz los
## muestre igual que el resto del feedback.

var caso: Resource
var alarma_vista := false
## evidencia → minuto del turno en que se reunió.
var evidencias: Dictionary = {}
var diagnostico := ""
var diagnostico_correcto := false
## producto del caso → sacos usados.
var tratado: Dictionary = {}
var ultima_tasa := -1.0
var verificado := false
var resuelto := false


func _init(caso_: Resource = null) -> void:
	caso = caso_


func registrar_alarma() -> void:
	alarma_vista = true


func registrar_evidencia(id: String, minuto: float) -> void:
	if not evidencias.has(id):
		evidencias[id] = minuto


func faltan_evidencias() -> Array:
	var f: Array = []
	for id in caso.evidencias_requeridas:
		if not evidencias.has(id):
			f.append(id)
	return f


## El jugador formula su diagnóstico. "no_se" y "" piden más evidencia.
func registrar_diagnostico(id: String) -> Array:
	var h: Array = []
	if id == "" or id == "no_se":
		h.append(_hallazgo("caso_sin_diagnostico", "Todavía sin diagnóstico", "consejo",
			"Está bien no apresurarse. Reúne la evidencia que falta (%s) y compara." % _nombres(faltan_evidencias())))
		return h
	var causa: Dictionary = caso.causa(id)
	if causa.is_empty():
		return [_hallazgo("caso_diagnostico_desconocido", "Diagnóstico desconocido", "error",
			"Ese diagnóstico no está entre las causas que se pueden elegir en este caso.")]
	diagnostico = id
	diagnostico_correcto = bool(causa["correcta"])
	var faltan := faltan_evidencias()
	if not faltan.is_empty():
		h.append(_hallazgo("caso_diagnostico_sin_evidencia", "Diagnóstico sin evidencia", "advertencia",
			"%s Te falta: %s." % [caso.explicacion_sin_evidencia, _nombres(faltan)]))
	h.append(_hallazgo("caso_diagnostico_" + ("correcto" if diagnostico_correcto else "incorrecto"),
		"%s: %s" % ["Diagnóstico acertado" if diagnostico_correcto else "Diagnóstico equivocado", causa["nombre"]],
		"consejo" if diagnostico_correcto else "error", str(causa["explicacion"])))
	return h


func registrar_tratamiento(producto: String, sacos: float) -> void:
	if producto in caso.productos_de_tratamiento:
		tratado[producto] = float(tratado.get(producto, 0.0)) + sacos


## El mud logger dio la pérdida actual (bbl/h). Después de tratar, dice si ya
## está controlada o qué falta. Devuelve hallazgos.
func registrar_balance(tasa_bbl_h: float) -> Array:
	ultima_tasa = tasa_bbl_h
	if tratado.is_empty():
		return []
	if tasa_bbl_h <= caso.tasa_objetivo_bbl_h:
		verificado = true
		resuelto = diagnostico_correcto
		var exito: String = caso.explicacion_exito
		if not diagnostico_correcto:
			exito += " Ojo: la pérdida bajó pero no diagnosticaste la causa; la próxima vez dilo antes de tratar."
		return [_hallazgo("caso_resuelto", "Pérdida controlada", "consejo", exito)]
	verificado = false
	return [_hallazgo("caso_tratamiento_insuficiente", "La pérdida sigue", "advertencia",
		"%s Hoy se pierden %.1f bbl/h y el objetivo es %.1f." % [
			caso.explicacion_tratamiento_insuficiente, tasa_bbl_h, caso.tasa_objetivo_bbl_h])]


## Pasos del caso con su estado, para el resumen del turno.
func pasos() -> Array:
	return [
		{"texto": "Notar la pérdida de volumen", "hecho": alarma_vista or evidencias.has("balance_volumen")},
		{"texto": "Reunir evidencia (%s)" % _nombres(caso.evidencias_requeridas),
			"hecho": faltan_evidencias().is_empty()},
		{"texto": "Diagnosticar la causa", "hecho": diagnostico_correcto},
		{"texto": "Tratar con el controlador de filtrado y el puenteo", "hecho": not tratado.is_empty()},
		{"texto": "Verificar que la pérdida baje de %.0f bbl/h" % caso.tasa_objetivo_bbl_h, "hecho": verificado},
	]


func resumen() -> Dictionary:
	return {"titulo": caso.titulo, "objetivo": caso.objetivo, "pasos": pasos(),
		"resuelto": resuelto, "ultima_tasa": ultima_tasa}


func _nombres(ids) -> String:
	var n: PackedStringArray = []
	for id in ids:
		n.append(str(caso.nombres_de_evidencia.get(id, id)))
	return ", ".join(n)


func _hallazgo(id: String, titulo: String, tipo: String, explicacion: String) -> Dictionary:
	return {"id": id, "titulo": titulo, "tipo": tipo, "explicacion": explicacion, "referencia": caso.referencia}
