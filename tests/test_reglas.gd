extends "res://tests/test_case.gd"
## Reglas con explicación (invariante 4): cada regla del catálogo se dispara en
## su escenario y NO se dispara en el escenario correcto equivalente.
##
## Los escenarios físicos (densidad, VP, PC) se arman como diccionarios para no
## depender de la calibración del modelo; los químicos aplican contaminantes y
## productos reales sobre el lodo base y verifican primero la premisa.

const Evaluador := preload("res://sim/evaluador_reglas.gd")
const Base := preload("res://sim/lodos_base.gd")
const Props := preload("res://sim/propiedades_lodo.gd")
const F := preload("res://sim/formulas.gd")

## Trampas y fallos documentados que el catálogo tiene que cubrir.
const OBLIGATORIAS := [
	"carbonato_de_sodio_sobre_cemento", "soda_caustica_con_carnalita", "diluir_ante_pc_alto",
	"tratar_sin_diagnosticar", "soda_caustica_en_carbonatos", "sobre_densificar",
	"estimar_kcl_con_cloruros", "hidrociclones_con_lodo_densificado", "transferir_sin_avisar",
	"producto_no_aprobado", "vp_sobre_dos_veces_peso", "calcio_carbonatos_cal_con_ph_alto",
	"calcio_carbonatos_yeso_con_ph_bajo", "calcio_carbonatos_cal_sin_yeso",
]

## Todas las pruebas químicas corridas: aísla cada escenario de "tratar sin diagnosticar".
const QUIMICAS := ["pm", "pf_mf", "dureza", "cloruros"]

var _catalogo: Array = []


func _reglas() -> Array:
	if _catalogo.is_empty():
		_catalogo = Evaluador.cargar_catalogo()
	return _catalogo


func _programa(nombre: String) -> Resource:
	return load("res://data/programas/caiman_3_%s.tres" % nombre)


## ids de las reglas que se disparan en ese momento y contexto.
func _disparadas(momento: String, contexto: Dictionary) -> Array:
	var ev = Evaluador.new()
	var ids: Array = []
	for h in ev.evaluar(_reglas(), momento, contexto):
		ids.append(h["id"])
	verificar(ev.errores.is_empty(), "condiciones sin errores: %s" % [ev.errores])
	return ids


func _dispara(id: String, momento: String, contexto: Dictionary) -> bool:
	return id in _disparadas(momento, contexto)


func _contaminado(nombre: String, cantidad: float):
	var lodo = Base.disperso_lignosulfonato()
	load("res://data/contaminantes/%s.tres" % nombre).aplicar(lodo, cantidad)
	return lodo


func _tratar(producto: String, antes, extra := {}) -> Dictionary:
	var ctx := {"antes": antes, "accion": {"tipo": "tratar", "producto": producto},
		"pruebas_corridas": QUIMICAS}
	ctx.merge(extra, true)
	return ctx


# ======================= Catálogo =======================

func test_catalogo_cubre_las_trampas_documentadas() -> void:
	var ids: Array = []
	for r in _reglas():
		ids.append(r.id)
	for id in OBLIGATORIAS:
		verificar(id in ids, "falta la regla %s" % id)


func test_toda_regla_tiene_explicacion_y_referencia() -> void:
	for r in _reglas():
		verificar(r.titulo != "", "%s: título vacío" % r.id)
		verificar(r.explicacion.length() > 80, "%s: explicación vacía o demasiado corta" % r.id)
		verificar(".md" in r.referencia, "%s: la referencia no cita un documento" % r.id)
		var docs := RegEx.create_from_string("[\\w-]+\\.md")
		for m in docs.search_all(r.referencia):
			var doc := m.get_string()
			verificar(FileAccess.file_exists("res://docs/" + doc) or doc == "CLAUDE.md",
				"%s: no existe docs/%s" % [r.id, doc])
		verificar(r.tipo in ["error", "advertencia", "consejo"], "%s: tipo inválido" % r.id)
		verificar(r.momento in ["al_tratar", "al_transferir", "al_cerrar_dia", "al_diagnosticar"],
			"%s: momento inválido" % r.id)


func test_id_coincide_con_el_archivo() -> void:
	for archivo in DirAccess.get_files_at(Evaluador.CARPETA):
		archivo = archivo.trim_suffix(".remap")
		if archivo.ends_with(".tres"):
			var r = load(Evaluador.CARPETA + "/" + archivo)
			verificar(r.id == archivo.get_basename(), "%s tiene id %s" % [archivo, r.id])


## Toda condición compila y se evalúa sin error con el contexto vacío,
## y con el contexto vacío ninguna se dispara.
func test_condiciones_validas_en_contexto_vacio() -> void:
	var ev = Evaluador.new()
	for r in _reglas():
		verificar(not ev.cumple(r, {}), "%s se dispara sin acción" % r.id)
	verificar(ev.errores.is_empty(), "errores: %s" % [ev.errores])


func test_condicion_rota_se_reporta_sin_disparar() -> void:
	var rota := preload("res://sim/regla.gd").new()
	rota.id = "rota"
	rota.condicion = "antes.propiedad_que_no_existe > 1"
	var ev = Evaluador.new()
	ev.mostrar_errores = false
	verificar(not ev.cumple(rota, {}), "no se dispara")
	verificar(ev.errores.size() == 1, "queda registrado el error")


func test_hallazgos_ordenados_y_filtrados_por_momento() -> void:
	var prog := _programa("produccion")
	# Barita sin pruebas, no aprobada y sobre-densificando: varias reglas a la vez.
	var ctx := {"antes": {"densidad": 9.4}, "despues": {"densidad": 9.9}, "programa": prog,
		"accion": {"tipo": "tratar", "producto": "barita", "afecta_activo": true}}
	var ev = Evaluador.new()
	var hallazgos: Array = ev.evaluar(_reglas(), "al_tratar", ctx)
	verificar(hallazgos.size() >= 2, "varias reglas")
	for i in range(1, hallazgos.size()):
		verificar(Evaluador.ORDEN_TIPO[hallazgos[i - 1]["tipo"]] <= Evaluador.ORDEN_TIPO[hallazgos[i]["tipo"]],
			"errores primero")
	for h in hallazgos:
		verificar(h["explicacion"] != "" and h["referencia"] != "", "%s trae su explicación" % h["id"])
	# afecta_activo sin aviso solo cuenta al transferir.
	verificar(not "transferir_sin_avisar" in _disparadas("al_tratar", ctx), "filtra por momento")


# ======================= Una prueba por trampa =======================

# §1.3 — nunca carbonato de sodio sobre cemento
func test_carbonato_de_sodio_sobre_cemento() -> void:
	var cemento = _contaminado("cemento", 1.0)
	verificar(cemento.cal_exceso > 0.25, "premisa: el cemento deja cal en exceso")
	verificar(_dispara("carbonato_de_sodio_sobre_cemento", "al_tratar", _tratar("carbonato_de_sodio", cemento)),
		"se dispara con cemento")
	var yeso = Base.disperso_lignosulfonato()
	yeso.cal_exceso = 0.0
	load("res://data/contaminantes/yeso.tres").aplicar(yeso, 1.0)
	var ctx := _tratar("carbonato_de_sodio", yeso)
	verificar(not _dispara("carbonato_de_sodio_sobre_cemento", "al_tratar", ctx),
		"no se dispara sobre yeso sin cal en exceso")
	verificar(_disparadas("al_tratar", ctx).is_empty(), "el tratamiento correcto del yeso no dispara nada")


# §1.3 — no soda cáustica con cemento
func test_soda_caustica_sobre_cemento() -> void:
	verificar(_dispara("soda_caustica_sobre_cemento", "al_tratar",
		_tratar("soda_caustica", _contaminado("cemento", 1.0))), "se dispara con cemento")
	var limpio = Base.disperso_lignosulfonato()
	limpio.cal_exceso = 0.0
	verificar(not _dispara("soda_caustica_sobre_cemento", "al_tratar", _tratar("soda_caustica", limpio)),
		"no se dispara sin cal en exceso")


# §1.3 — tratar por debajo del estequiométrico
func test_cemento_dosis_completa() -> void:
	var cemento = _contaminado("cemento", 1.0)
	var completa := F.dosis_por_exceso_de_cal("bicarbonato_de_sodio",
		F.exceso_de_cal(cemento.pm(), cemento.pf(), cemento.fw()))
	var ctx := _tratar("bicarbonato_de_sodio", cemento)
	ctx["accion"]["lb_bbl"] = completa
	verificar(_dispara("cemento_dosis_completa", "al_tratar", ctx), "dosis completa avisa")
	ctx["accion"]["lb_bbl"] = completa * 0.6
	verificar(not _dispara("cemento_dosis_completa", "al_tratar", ctx), "dosis parcial no avisa")
	verificar(_disparadas("al_tratar", ctx).is_empty(), "el tratamiento correcto no dispara nada")


# §1.5 — soda cáustica con carnalita
func test_soda_caustica_con_carnalita() -> void:
	var carnalita = Base.disperso_lignosulfonato()
	carnalita.oh = 0.0
	carnalita.agregar_ion("mg", 3000.0)
	verificar(_dispara("soda_caustica_con_carnalita", "al_tratar", _tratar("soda_caustica", carnalita)),
		"se dispara con magnesio alto")
	var sin_mg = Base.disperso_lignosulfonato()
	sin_mg.cal_exceso = 0.0
	verificar(not _dispara("soda_caustica_con_carnalita", "al_tratar", _tratar("soda_caustica", sin_mg)),
		"no se dispara sin magnesio")


# §5 — diluir ante PC alto sin VP alta
func test_diluir_ante_pc_alto() -> void:
	var prog := _programa("superficial")
	var pc_alto := {"densidad": 8.8, "vp": 9.0, "pc": 40.0}
	verificar(_dispara("diluir_ante_pc_alto", "al_tratar", _tratar("agua", pc_alto, {"programa": prog})),
		"PC alto con VP normal: diluir es error")
	var ambos := {"densidad": 8.8, "vp": 16.0, "pc": 40.0}
	verificar(not _dispara("diluir_ante_pc_alto", "al_tratar", _tratar("agua", ambos, {"programa": prog})),
		"con VP alta diluir es correcto")
	var pesado := {"densidad": 9.3, "vp": 9.0, "pc": 40.0}
	verificar(not _dispara("diluir_ante_pc_alto", "al_tratar", _tratar("agua", pesado, {"programa": prog})),
		"diluir para bajar densidad es legítimo")


# Núcleo jugable — tratar sin diagnosticar
func test_tratar_sin_diagnosticar() -> void:
	var lodo = Base.disperso_lignosulfonato()
	lodo.cal_exceso = 0.0
	var ctx := _tratar("sapp", lodo, {"pruebas_corridas": ["embudo_marsh", "fann", "balanza"]})
	verificar(_dispara("tratar_sin_diagnosticar", "al_tratar", ctx), "solo pruebas físicas: dispara")
	ctx["pruebas_corridas"] = ["fann", "pm"]
	verificar(not _dispara("tratar_sin_diagnosticar", "al_tratar", ctx), "con Pm corrido no dispara")
	var barita := _tratar("barita", lodo, {"pruebas_corridas": []})
	verificar(not _dispara("tratar_sin_diagnosticar", "al_tratar", barita), "densificar no es tratar químico")


# §1.7 (4C.11) — bucle de carbonatos
func test_soda_caustica_repetida_en_carbonatos() -> void:
	var carb = _contaminado("carbonatos", 9000.0)
	verificar(carb.mf() > 5.0, "premisa: Mf > 5")
	var ctx := _tratar("soda_caustica", carb, {"tratamientos_previos": ["soda_caustica"]})
	verificar(_dispara("soda_caustica_en_carbonatos", "al_tratar", ctx), "soda repetida en carbonatos")
	ctx["tratamientos_previos"] = []
	verificar(not _dispara("soda_caustica_en_carbonatos", "al_tratar", ctx),
		"primera soda sin tendencia conocida: no dispara")
	# Mf/Pf creciendo respecto del chequeo anterior también la delata.
	ctx["previo"] = {"mf": 3.0, "pf": 1.0}
	verificar(_dispara("soda_caustica_en_carbonatos", "al_tratar", ctx), "Mf/Pf creciente")
	var limpio = Base.disperso_lignosulfonato()
	limpio.cal_exceso = 0.0
	verificar(not _dispara("soda_caustica_en_carbonatos", "al_tratar",
		_tratar("soda_caustica", limpio, {"tratamientos_previos": ["soda_caustica"]})),
		"soda repetida sin carbonatos no dispara")


# §1.7 — fuente de calcio según el pH
func test_fuente_de_calcio_segun_ph() -> void:
	var carb := func(ph: float) -> Dictionary:
		return {"ph": ph, "pf": 1.0, "mf": 7.0, "mf_carbonatos": 5.0}
	verificar(_dispara("calcio_carbonatos_cal_con_ph_alto", "al_tratar", _tratar("cal", carb.call(11.6))),
		"cal con pH > 11,3")
	verificar(not _dispara("calcio_carbonatos_cal_con_ph_alto", "al_tratar", _tratar("cal", carb.call(9.8))),
		"cal con pH < 10,3 es lo correcto")
	verificar(_disparadas("al_tratar", _tratar("cal", carb.call(9.8))).is_empty(), "cal bajo 10,3: nada")
	verificar(_dispara("calcio_carbonatos_yeso_con_ph_bajo", "al_tratar", _tratar("yeso", carb.call(9.8))),
		"yeso con pH < 10,3")
	verificar(_disparadas("al_tratar", _tratar("yeso", carb.call(11.6))).is_empty(), "yeso sobre 11,3: nada")
	verificar(_dispara("calcio_carbonatos_cal_sin_yeso", "al_tratar", _tratar("cal", carb.call(10.8))),
		"cal sola entre 10,3 y 11,3")
	verificar(not _dispara("calcio_carbonatos_cal_sin_yeso", "al_tratar",
		_tratar("cal", carb.call(10.8), {"tratamientos_previos": ["yeso"]})), "cal + yeso: correcto")
	# Sin carbonatos, la cal no dispara ninguna de las tres.
	verificar(_disparadas("al_tratar", _tratar("cal", {"ph": 11.6, "pf": 1.0, "mf": 1.5})).is_empty(),
		"sin carbonatos no aplica")
	# Con el lodo real contaminado: pH bajo, el yeso es la elección equivocada.
	var real = _contaminado("carbonatos", 9000.0)
	verificar(real.ph() < 10.3, "premisa: los carbonatos bajan el pH")
	verificar(_dispara("calcio_carbonatos_yeso_con_ph_bajo", "al_tratar", _tratar("yeso", real)),
		"yeso sobre el lodo real con bicarbonatos")


func test_sobre_densificar() -> void:
	var prog := _programa("superficial")
	var antes = Base.disperso_lignosulfonato()
	var despues = antes.copiar()
	load("res://data/productos/barita.tres").aplicar(despues, 40.0)
	verificar(despues.densidad() > 9.0, "premisa: 40 lb/bbl de barita pasan de 9,0 ppg")
	var ctx := _tratar("barita", antes, {"despues": despues, "programa": prog})
	verificar(_dispara("sobre_densificar", "al_tratar", ctx), "pasa el techo del programa")
	ctx["antes"] = {"densidad": 8.6}
	ctx["despues"] = {"densidad": 8.9}
	verificar(not _dispara("sobre_densificar", "al_tratar", ctx), "dentro de la ventana no dispara")
	verificar(_disparadas("al_tratar", ctx).is_empty(), "densificar bien no dispara nada")


# §13.1 — cloruros ≠ KCl
func test_estimar_kcl_con_cloruros() -> void:
	var ctx := {"antes": {"cl": 40000.0, "k": 4000.0},
		"accion": {"tipo": "diagnosticar", "diagnostico": "potasio_suficiente"},
		"pruebas_corridas": ["cloruros"]}
	verificar(_dispara("estimar_kcl_con_cloruros", "al_diagnosticar", ctx), "solo cloruros")
	ctx["pruebas_corridas"] = ["cloruros", "potasio"]
	verificar(not _dispara("estimar_kcl_con_cloruros", "al_diagnosticar", ctx), "con prueba de K⁺")


# §7 — hidrociclones con lodo densificado
func test_hidrociclones_con_lodo_densificado() -> void:
	var densificado = Base.disperso_lignosulfonato()
	load("res://data/productos/barita.tres").aplicar(densificado, 40.0)
	var ctx := {"despues": densificado, "equipos": {"desarenador": true, "centrifuga": false}}
	verificar(_dispara("hidrociclones_con_lodo_densificado", "al_cerrar_dia", ctx), "desarenador con barita")
	ctx["equipos"] = {"desarenador": false, "deslimador": false, "centrifuga": true}
	verificar(not _dispara("hidrociclones_con_lodo_densificado", "al_cerrar_dia", ctx), "centrífuga: correcto")
	ctx = {"despues": Base.disperso_lignosulfonato(), "equipos": {"desarenador": true, "deslimador": true}}
	verificar(not _dispara("hidrociclones_con_lodo_densificado", "al_cerrar_dia", ctx),
		"sin barita los hidrociclones son la herramienta barata")


# §4 — avisar antes de transferir
func test_transferir_sin_avisar() -> void:
	var accion := {"tipo": "transferir", "origen": "reserva_1", "destino": "activo",
		"afecta_activo": true, "aviso_driller": false}
	verificar(_dispara("transferir_sin_avisar", "al_transferir", {"accion": accion}), "sin aviso")
	accion["aviso_driller"] = true
	verificar(not _dispara("transferir_sin_avisar", "al_transferir", {"accion": accion}), "con aviso")
	var entre_reservas := {"tipo": "transferir", "origen": "reserva_1", "destino": "fractanque",
		"afecta_activo": false}
	verificar(not _dispara("transferir_sin_avisar", "al_transferir", {"accion": entre_reservas}),
		"entre tanques fuera del activo no hace falta")


# Invariante 6 — producto no aprobado
func test_producto_no_aprobado() -> void:
	var prod := _programa("produccion")
	verificar(_dispara("producto_no_aprobado", "al_tratar", _tratar("barita", {}, {"programa": prod})),
		"barita en el RDF")
	verificar(not _dispara("producto_no_aprobado", "al_tratar", _tratar("xc", {}, {"programa": prod})),
		"XC sí está aprobado")
	verificar(not _dispara("producto_no_aprobado", "al_tratar", _tratar("barita", {})),
		"sin programa no hay restricción")
	# La palanca de dificultad: quitar un producto lo vuelve ilegal sin tocar la simulación.
	var sup := _programa("superficial")
	verificar(not _dispara("producto_no_aprobado", "al_tratar", _tratar("soda_caustica", {}, {"programa": sup})),
		"soda aprobada en la superficial")
	verificar(_dispara("producto_no_aprobado", "al_tratar",
		_tratar("soda_caustica", {}, {"programa": sup.sin_producto("soda_caustica")})),
		"al quitarla del programa deja de ser legal")


# §5.1 — VP ≤ 2 × peso
func test_vp_sobre_dos_veces_peso() -> void:
	var ctx := {"antes": {"densidad": 9.0, "vp": 20.0}, "pruebas_corridas": ["fann"]}
	verificar(_dispara("vp_sobre_dos_veces_peso", "al_diagnosticar", ctx), "VP 20 con 9 ppg")
	verificar(F.vp_excede_limite(20.0, 9.0), "coincide con Formulas.vp_excede_limite")
	ctx["antes"] = {"densidad": 9.0, "vp": 16.0}
	verificar(not _dispara("vp_sobre_dos_veces_peso", "al_diagnosticar", ctx), "VP 16 con 9 ppg")
	ctx = {"antes": {"densidad": 9.0, "vp": 20.0}, "pruebas_corridas": []}
	verificar(not _dispara("vp_sobre_dos_veces_peso", "al_diagnosticar", ctx), "sin Fann no se sabe")


# §13 — pH alto con PHPA
func test_soda_caustica_hidroliza_phpa() -> void:
	var ctx := _tratar("soda_caustica", {"ph": 9.3}, {"despues": {"ph": 10.4},
		"programa": _programa("intermedia")})
	verificar(_dispara("soda_caustica_hidroliza_phpa", "al_tratar", ctx), "pH > 10 en KCl/PHPA")
	ctx["despues"] = {"ph": 9.5}
	verificar(not _dispara("soda_caustica_hidroliza_phpa", "al_tratar", ctx), "pH 9,5 está bien")
	ctx = _tratar("soda_caustica", {"ph": 9.3}, {"despues": {"ph": 10.4}, "programa": _programa("superficial")})
	verificar(not _dispara("soda_caustica_hidroliza_phpa", "al_tratar", ctx), "sin PHPA no aplica")


# §1.5 — bentonita seca en lodo salado
func test_bentonita_seca_en_lodo_salado() -> void:
	var salado = _contaminado("sal", 12.0)
	verificar(salado.cl > 10000.0, "premisa: la sal sube los cloruros")
	verificar(_dispara("bentonita_seca_en_lodo_salado", "al_tratar", _tratar("bentonita", salado)), "seca")
	var ctx := _tratar("bentonita", salado)
	ctx["accion"]["prehidratada"] = true
	verificar(not _dispara("bentonita_seca_en_lodo_salado", "al_tratar", ctx), "prehidratada")
	verificar(not _dispara("bentonita_seca_en_lodo_salado", "al_tratar",
		_tratar("bentonita", Base.disperso_lignosulfonato())), "agua dulce")


func test_lodo_fuera_de_programa_al_cerrar() -> void:
	var prog := _programa("superficial")
	var bien := {"densidad": 8.8, "embudo": 40.0, "vp": 9.0, "pc": 20.0, "gel_10s": 8.0,
		"gel_10min": 15.0, "ph": 9.0, "ca": 80.0, "mbt": 20.0}
	verificar(not _dispara("lodo_fuera_de_programa", "al_cerrar_dia", {"despues": bien, "programa": prog}),
		"dentro del programa")
	var mal := bien.duplicate()
	mal["densidad"] = 9.3
	verificar(_dispara("lodo_fuera_de_programa", "al_cerrar_dia", {"despues": mal, "programa": prog}),
		"densidad fuera")


# Integración con el agente C: los ids que usan las reglas tienen que existir en data/pruebas/.
func test_ids_de_pruebas_existen_en_el_laboratorio() -> void:
	var Evaluador = load("res://sim/evaluador_reglas.gd")
	for id: String in Evaluador.PRUEBAS:
		verificar(ResourceLoader.exists("res://data/pruebas/%s.tres" % id), "la prueba '%s' no existe en data/pruebas/" % id)
	var regex := RegEx.new()
	regex.compile("corrio(?:_alguna)?\\(([^)]*)\\)")
	for archivo in DirAccess.get_files_at("res://data/reglas"):
		if not archivo.ends_with(".tres"):
			continue
		var regla: Resource = load("res://data/reglas/" + archivo)
		for m in regex.search_all(regla.condicion):
			for id in m.get_string(1).replace("[", "").replace("]", "").replace("\"", "").split(","):
				id = id.strip_edges()
				if id == "" or id == "p":
					continue
				verificar(id in Evaluador.PRUEBAS or id in Evaluador.PRUEBAS_FUTURAS,
					"%s pide la prueba '%s', que no está en PRUEBAS" % [archivo, id])
