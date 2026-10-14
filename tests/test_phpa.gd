extends "res://tests/test_case.gd"
## Cemento en KCl/PHPA (auditoría C3; simulation-logic.md §13.3). El calcio
## entrecruza el PHPA y el pH alto lo hidroliza. Fuente (calcio dañino desde
## ~500 mg/l, "el fluido se vuelve viscoso", pretratamiento con bicarbonato):
## https://patents.justia.com/patent/5028341 y
## https://www.drillingmanual.com/mud-contamination-cement-precautions/

const Base := preload("res://sim/lodos_base.gd")
const Cinetica := preload("res://sim/cinetica.gd")
const Tanque := preload("res://sim/tanque.gd")
const Perforacion := preload("res://sim/perforacion.gd")

const CEMENTO := preload("res://data/contaminantes/cemento.tres")
const BICARBONATO := preload("res://data/productos/bicarbonato_de_sodio.tres")
const ACIDO_CITRICO := preload("res://data/productos/acido_citrico.tres")
const LUTITA := preload("res://data/formaciones/caiman_3_lutita_reactiva.tres")
const PROGRAMA := preload("res://data/programas/caiman_3_intermedia.tres")


func _tanque() -> Resource:
	return Tanque.crear("Succión", 500.0, "succion", 400.0, Base.kcl_phpa())


func _correr(t: Resource, pasos: int) -> void:
	for i in pasos:
		Cinetica.paso([t], 10.0, 600.0, 400.0)


func test_el_lodo_kcl_phpa_es_estable_un_dia() -> void:
	var t := _tanque()
	_correr(t, 144)
	verificar_cerca(t.lodo.phpa, 1.0, 1e-9, "sin cemento el PHPA no se degrada")
	verificar_cerca(t.lodo.phpa_danado, 0.0, 1e-9, "ni se entrecruza")


func test_el_cemento_degrada_el_phpa_en_vueltas() -> void:
	var t := _tanque()
	CEMENTO.aplicar(t.lodo, 0.5)
	_correr(t, 12)   # 2 h
	verificar(t.lodo.phpa < 0.6, "pH alto y calcio: queda %.2f de 1,0 lb/bbl de PHPA" % t.lodo.phpa)
	verificar(t.lodo.phpa_danado > 0.1, "parte precipita entrecruzada: %.2f lb/bbl" % t.lodo.phpa_danado)


func test_el_phpa_danado_espesa_y_se_pierde_control_de_filtrado() -> void:
	var sano := _tanque()
	var contaminado := _tanque()
	CEMENTO.aplicar(contaminado.lodo, 0.5)
	var pc_justo_despues: float = contaminado.lodo.pc()
	var filtrado_justo_despues: float = contaminado.lodo.filtrado_api()
	_correr(contaminado, 48)   # 8 h
	verificar(contaminado.lodo.pc() > pc_justo_despues + 2.0,
		"el lodo se sigue espesando: PC %.1f → %.1f" % [pc_justo_despues, contaminado.lodo.pc()])
	verificar(contaminado.lodo.pc() > PROGRAMA.rangos["pc"][1], "PC fuera del programa (%.1f)" % contaminado.lodo.pc())
	verificar(contaminado.lodo.gel_10min() > PROGRAMA.rangos["gel_10min"][1], "gel de 10 min fuera del programa")
	verificar(contaminado.lodo.filtrado_api() > filtrado_justo_despues, "el filtrado empeora al perder PHPA")
	verificar(contaminado.lodo.filtrado_api() > sano.lodo.filtrado_api() + 2.0, "y queda sobre el lodo sano")


func test_sin_phpa_activo_se_pierde_la_inhibicion() -> void:
	var sano := _tanque()
	var contaminado := _tanque()
	CEMENTO.aplicar(contaminado.lodo, 0.5)
	_correr(contaminado, 48)
	verificar(Perforacion.inhibicion(contaminado.lodo, LUTITA) < Perforacion.inhibicion(sano.lodo, LUTITA),
		"con menos PHPA, la lutita se dispersa más")


func test_calcio_entrecruza_y_el_ph_solo_hidroliza() -> void:
	var con_calcio := _tanque()
	con_calcio.lodo.agregar_ion("ca", 800.0)
	_correr(con_calcio, 12)
	verificar(con_calcio.lodo.phpa_danado > 0.1, "calcio alto sin pH alto: entrecruza (%.2f)" % con_calcio.lodo.phpa_danado)

	var con_ph := _tanque()
	con_ph.lodo.fijar_ph(11.5)
	_correr(con_ph, 12)
	verificar(con_ph.lodo.phpa < 0.9, "pH alto solo: el PHPA se hidroliza (%.2f)" % con_ph.lodo.phpa)
	verificar_cerca(con_ph.lodo.phpa_danado, 0.0, 1e-9, "pero sin calcio no precipita ni espesa")


func test_pretratar_con_bicarbonato_evita_el_entrecruzamiento() -> void:
	# mud-engineer-reference.md §1.3 y las fuentes arriba: el bicarbonato captura el calcio.
	var sin := _tanque()
	var con := _tanque()
	con.tratar(BICARBONATO, 1.0)
	CEMENTO.aplicar(sin.lodo, 0.5)
	CEMENTO.aplicar(con.lodo, 0.5)
	_correr(sin, 24)
	_correr(con, 24)
	verificar(con.lodo.phpa_danado < 0.2 * sin.lodo.phpa_danado + 1e-9,
		"con pretratamiento casi no hay PHPA dañado (%.2f contra %.2f)" % [con.lodo.phpa_danado, sin.lodo.phpa_danado])
	verificar(con.lodo.phpa > sin.lodo.phpa + 0.2, "y queda más PHPA activo (%.2f contra %.2f)" % [con.lodo.phpa, sin.lodo.phpa])
	verificar(con.lodo.pc() < PROGRAMA.rangos["pc"][1], "el PC se queda dentro del programa")


func test_tratar_en_dos_pasos_frena_el_daño() -> void:
	var sin := _tanque()
	var tratado := _tanque()
	CEMENTO.aplicar(sin.lodo, 0.5)
	CEMENTO.aplicar(tratado.lodo, 0.5)
	_correr(sin, 2)
	_correr(tratado, 2)
	tratado.tratar(BICARBONATO, 0.5)
	tratado.tratar(ACIDO_CITRICO, 0.4)   # el segundo tratamiento que pide el manual
	_correr(sin, 24)
	_correr(tratado, 24)
	verificar(tratado.lodo.phpa > sin.lodo.phpa + 0.2,
		"tratado conserva PHPA (%.2f contra %.2f)" % [tratado.lodo.phpa, sin.lodo.phpa])
	verificar(tratado.lodo.ph() < sin.lodo.ph() - 0.5, "y el pH baja")


func test_el_phpa_danado_viaja_con_la_mezcla() -> void:
	var a := _tanque()
	a.lodo.phpa_danado = 0.4
	var b := Tanque.crear("Proceso", 500.0, "proceso", 400.0, Base.kcl_phpa())
	b.mezclar_con(a.lodo, 0.0, 1.0)
	verificar(b.lodo.phpa_danado > 0.0, "la mezcla reparte el PHPA dañado")
	verificar_cerca(a.lodo.copiar().phpa_danado, 0.4, 1e-12, "copiar lo conserva")
