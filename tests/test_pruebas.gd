extends "res://tests/test_case.gd"
## Pruebas de laboratorio como datos (data/pruebas/): lecturas del instrumento
## con su resolución, requisitos del filtrado y orden del laboratorio.
## Referencias: game-design-mechanics.md ("Chequeo de rutina"),
## mud-engineer-reference.md §7, simulation-logic.md §3, §11 y §13.4.
##
## No dependen de las constantes de calibración del lodo: cada lectura se
## compara con la propiedad del estado redondeada al paso del instrumento.

const EstadoLodoScript := preload("res://sim/estado_lodo.gd")
const PruebaScript := preload("res://sim/prueba_laboratorio.gd")
const Lab := preload("res://sim/laboratorio.gd")
const Base := preload("res://sim/lodos_base.gd")

## La tabla del chequeo de rutina y las ampliadas que el estado ya permite.
const IDS := [
	"balanza", "embudo_marsh", "ph", "fann", "geles", "filtrado_api", "pm", "pf_mf",
	"cloruros", "dureza", "retorta", "balanza_presurizada", "mbt", "calcio_magnesio",
	"potasio", "ggt_sulfuros", "ggt_carbonatos",
]
const SOBRE_FILTRADO := ["pf_mf", "cloruros", "dureza", "calcio_magnesio", "potasio",
	"ggt_sulfuros", "ggt_carbonatos"]


func _todas_hechas() -> Dictionary:
	return {"hechas": IDS}


## Lodo base con un poco de todo para que ninguna lectura salga en cero.
func _lodo_completo():
	var lodo = Base.disperso_lignosulfonato()
	lodo.mg = 50.0
	lodo.k = 12345.0
	lodo.sulfuro = 37.0
	lodo.hco3 = 80.0
	lodo.cl = 23456.0
	lodo.frac_aceite = 0.02
	return lodo


func test_todas_las_pruebas_existen_y_son_coherentes() -> void:
	var todas := Lab.cargar_todas()
	for id in IDS:
		verificar(todas.has(id), "falta data/pruebas/%s.tres" % id)
		if not todas.has(id):
			continue
		var p: Resource = todas[id]
		verificar(p.get_script() == PruebaScript, "%s: no es una PruebaLaboratorio" % id)
		verificar(not p.lecturas.is_empty(), "%s: no entrega lecturas" % id)
		verificar(p.minutos_activos > 0, "%s: sin tiempo activo" % id)
		for req in p.requiere:
			verificar(todas.has(req), "%s requiere %s, que no existe" % [id, req])
		if id in SOBRE_FILTRADO:
			verificar(p.muestra == "filtrado" and "filtrado_api" in p.requiere,
				"%s se corre sobre el filtrado y debe requerir el filtrado API" % id)
	verificar(todas["filtrado_api"].produce == "filtrado", "el filtrado API produce el filtrado")


func test_lecturas_con_la_resolucion_del_instrumento() -> void:
	var lodo = _lodo_completo()
	for id in IDS:
		var p: Resource = Lab.cargar(id)
		var r: Dictionary = p.ejecutar(lodo, _todas_hechas())
		verificar(not r.has("error"), "%s: %s" % [id, r.get("error", "")])
		for spec: Dictionary in p.lecturas:
			var v: float = r.get(spec["nombre"], -1.0)
			var paso: float = spec["resolucion"]
			if spec.has("limite_fino") and v > float(spec["limite_fino"]):
				paso = spec["resolucion_gruesa"]
			verificar(is_equal_approx(snappedf(v, paso), v),
				"%s/%s = %s no es múltiplo de %s" % [id, spec["nombre"], v, paso])


func test_lecturas_son_el_estado_redondeado() -> void:
	var lodo = _lodo_completo()
	var h := _todas_hechas()
	var r: Dictionary = Lab.cargar("ph").ejecutar(lodo, h)
	verificar_cerca(r["ph"], snappedf(lodo.ph(), 0.1), 1e-6, "pH a 0,1")
	r = Lab.cargar("pm").ejecutar(lodo, h)
	verificar_cerca(r["pm"], snappedf(lodo.pm(), 0.05), 1e-6, "Pm a 0,05 ml")
	r = Lab.cargar("pf_mf").ejecutar(lodo, h)
	verificar_cerca(r["pf"], snappedf(lodo.pf(), 0.05), 1e-6, "Pf a 0,05 ml")
	verificar_cerca(r["mf"], snappedf(lodo.mf(), 0.05), 1e-6, "Mf a 0,05 ml")
	r = Lab.cargar("embudo_marsh").ejecutar(lodo, h)
	verificar_cerca(r["viscosidad_embudo"], roundf(lodo.viscosidad_embudo()), 1e-6, "embudo a 1 s")
	r = Lab.cargar("filtrado_api").ejecutar(lodo, h)
	verificar_cerca(r["filtrado_api"], snappedf(lodo.filtrado_api(), 0.1), 1e-6, "filtrado a 0,1 ml")


func test_cloruros_cambian_de_paso_con_titulante_concentrado() -> void:
	var lodo = EstadoLodoScript.new()
	var p := Lab.cargar("cloruros")
	var h := {"hechas": ["filtrado_api"]}
	lodo.cl = 1234.0
	verificar_cerca(p.ejecutar(lodo, h)["cl"], 1250.0, 1e-6, "paso fino de 50 mg/l")
	lodo.cl = 123456.0
	verificar_cerca(p.ejecutar(lodo, h)["cl"], 123500.0, 1e-6, "paso grueso de 500 mg/l")


func test_dureza_suma_magnesio_y_la_ampliada_lo_separa() -> void:
	var lodo = EstadoLodoScript.new()
	lodo.ca = 400.0
	lodo.mg = 5.0 * 24.31          # 5 mmol/l = 200 mg/l como calcio
	var h := {"hechas": ["filtrado_api"]}
	verificar_cerca(Lab.cargar("dureza").ejecutar(lodo, h)["dureza_total"], 600.0, 1e-6,
		"la dureza total cuenta el magnesio como calcio")
	var r: Dictionary = Lab.cargar("calcio_magnesio").ejecutar(lodo, h)
	verificar_cerca(r["ca"], 400.0, 1e-6, "calcio solo")
	verificar_cerca(r["mg"], 121.0, 1.0, "magnesio por diferencia")


func test_balanza_atmosferica_lee_bajo_con_aire_y_la_presurizada_no() -> void:
	var lodo = Base.disperso_lignosulfonato()
	var atm := Lab.cargar("balanza")
	var pres := Lab.cargar("balanza_presurizada")
	verificar_cerca(atm.ejecutar(lodo)["densidad"], pres.ejecutar(lodo)["densidad"], 1e-6,
		"sin aire las dos balanzas leen igual")
	lodo.aire = 0.05
	var d_atm: float = atm.ejecutar(lodo)["densidad"]
	var d_pres: float = pres.ejecutar(lodo)["densidad"]
	verificar(d_atm < d_pres - 0.2, "con 5 %% de aire la atmosférica lee bajo (%.1f vs %.1f)" % [d_atm, d_pres])
	verificar_cerca(d_pres, snappedf(lodo.densidad(), 0.1), 1e-6, "la presurizada lee la densidad real")
	verificar_cerca(d_atm, snappedf(lodo.densidad_balanza_atmosferica(), 0.1), 1e-6,
		"la atmosférica lee la densidad con aire")


func test_pruebas_sobre_filtrado_no_corren_sin_filtrado() -> void:
	var lodo = Base.disperso_lignosulfonato()
	for id in SOBRE_FILTRADO:
		var p: Resource = Lab.cargar(id)
		var sin: Dictionary = p.ejecutar(lodo)
		verificar(sin.has("error") and sin.size() == 1, "%s corrió sin filtrado" % id)
		verificar("filtrado" in sin.get("error", ""), "%s: el error explica que falta el filtrado" % id)
		var con: Dictionary = p.ejecutar(lodo, {"hechas": ["filtrado_api"]})
		verificar(not con.has("error"), "%s no corre con el filtrado hecho" % id)


func test_fann_calcula_vp_pc_va_con_las_lecturas_del_dial() -> void:
	var lodo = _lodo_completo()
	var r: Dictionary = Lab.cargar("fann").ejecutar(lodo)
	for clave in ["fann_600", "fann_300", "fann_6", "fann_3"]:
		verificar(is_equal_approx(r[clave], roundf(r[clave])), "%s es lectura entera" % clave)
	verificar_cerca(r["vp"], r["fann_600"] - r["fann_300"], 1e-6, "VP = Θ600 − Θ300")
	verificar_cerca(r["pc"], r["fann_300"] - r["vp"], 1e-6, "PC = Θ300 − VP")
	verificar_cerca(r["va"], r["fann_600"] / 2.0, 1e-6, "VA = Θ600 / 2")
	verificar(r["fann_600"] > r["fann_300"] and r["fann_300"] >= r["fann_6"] \
		and r["fann_6"] >= r["fann_3"] and r["fann_3"] > 0.0,
		"lecturas ordenadas por velocidad: %s" % r)


func test_fann_en_frio_lee_mas_alto() -> void:
	var lodo = _lodo_completo()
	var p := Lab.cargar("fann")
	var caliente: Dictionary = p.ejecutar(lodo)
	var frio: Dictionary = p.ejecutar(lodo, {"copa_termica": false})
	verificar(frio["fann_600"] > caliente["fann_600"], "Θ600 en frío sube")
	verificar_cerca(frio["fann_600"], caliente["fann_600"] * PruebaScript.FACTOR_FANN_EN_FRIO, 1.0,
		"sube según el factor de diseño")
	var geles := Lab.cargar("geles")
	verificar(geles.ejecutar(lodo, {"copa_termica": false})["gel_10min"] >= geles.ejecutar(lodo)["gel_10min"],
		"los geles en frío no bajan")


func test_retorta_cierra_en_100_y_da_fw() -> void:
	var lodo = _lodo_completo()
	var r: Dictionary = Lab.cargar("retorta").ejecutar(lodo)
	verificar_cerca(r["agua_pct"] + r["aceite_pct"] + r["solidos_pct"], 100.0, 1e-6, "agua + aceite + sólidos")
	verificar_cerca(r["fw"], r["agua_pct"] / 100.0, 1e-6, "Fw = % agua / 100")
	verificar_cerca(r["fw"], lodo.fw(), 0.005, "Fw cerca del real")


func test_chequeos_de_rutina() -> void:
	var ids_completo := []
	for p in Lab.chequeo("completo"):
		ids_completo.append(p.id)
	ids_completo.sort()
	var esperado := ["balanza", "cloruros", "dureza", "fann", "filtrado_api", "geles", "pf_mf", "ph", "pm"]
	verificar(ids_completo == esperado, "chequeo completo (CLAUDE.md): %s" % [ids_completo])
	var rapido := Lab.planificar(Lab.chequeo("rapido"))
	verificar(rapido["total_min"] <= 10, "el chequeo rápido no pasa de 10 min (%d)" % rapido["total_min"])
	var diaria := Lab.chequeo("diaria")
	verificar(diaria.size() == 1 and diaria[0].id == "retorta", "la retorta es la prueba diaria")


func test_chequeo_completo_en_paralelo_es_mas_corto_que_la_suma() -> void:
	var pruebas := Lab.chequeo("completo")
	var plan := Lab.planificar(pruebas)
	verificar(not plan.has("error"), plan.get("error", ""))
	verificar(plan["total_min"] < plan["suma_min"],
		"con esperas en paralelo: %d min contra %d en serie" % [plan["total_min"], plan["suma_min"]])
	# Camino crítico: filtrado (5 + 30) y después las tres titulaciones del filtrado.
	verificar(plan["total_min"] >= 35 + 30, "no puede ser más corto que el camino crítico")

	var por_id := {}
	for paso in plan["cronograma"]:
		por_id[paso["id"]] = paso
	verificar(por_id.size() == pruebas.size(), "todas las pruebas quedan planificadas")
	for id in ["pf_mf", "cloruros", "dureza"]:
		verificar(por_id[id]["inicio"] >= por_id["filtrado_api"]["fin"], "%s espera el filtrado" % id)
	# El jugador hace una sola cosa a la vez.
	var activos: Array = plan["cronograma"].duplicate()
	activos.sort_custom(func(a, b): return a["inicio"] < b["inicio"])
	for i in range(1, activos.size()):
		verificar(activos[i]["inicio"] >= activos[i - 1]["fin_activo"],
			"%s arranca antes de terminar %s" % [activos[i]["id"], activos[i - 1]["id"]])
	# El Fann sirve a una prueba a la vez (los geles lo ocupan 10 min).
	var f: Dictionary = por_id["fann"]
	var g: Dictionary = por_id["geles"]
	verificar(f["fin"] <= g["inicio"] or g["fin"] <= f["inicio"], "Fann y geles no se pisan")


func test_planificar_sin_filtrado_da_error() -> void:
	var plan := Lab.planificar([Lab.cargar("pf_mf")])
	verificar(plan.has("error") and "filtrado_api" in plan["faltan"], "pide el filtrado API")
	plan = Lab.planificar([Lab.cargar("pf_mf")], ["filtrado_api"])
	verificar(not plan.has("error") and plan["total_min"] == 10, "con filtrado previo corre de inmediato")
