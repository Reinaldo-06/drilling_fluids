extends "res://tests/test_case.gd"
## Perforación en el paso de simulación: consumo de volumen, entrada de sólidos,
## lutita reactiva e inhibición, contaminante de formación y lutita frágil
## (simulation-logic.md §6.1, §10.1, §12.2, §13.5; rig-tank-system.md §4;
## reference-wells.md §2).

const Perforacion := preload("res://sim/perforacion.gd")
const ControlSolidos := preload("res://sim/control_solidos.gd")
const FormacionScript := preload("res://sim/formacion.gd")
const Tanque := preload("res://sim/tanque.gd")
const Base := preload("res://sim/lodos_base.gd")
const F := preload("res://sim/formulas.gd")

const SUPERFICIAL := preload("res://data/formaciones/caiman_3_superficial.tres")
const CEMENTO := preload("res://data/formaciones/caiman_3_cemento_zapata.tres")
const INTERMEDIA := preload("res://data/formaciones/caiman_3_intermedia_superior.tres")
const LUTITA := preload("res://data/formaciones/caiman_3_lutita_reactiva.tres")
const ARENA := preload("res://data/formaciones/caiman_3_arena_productora.tres")
const FRAGIL := preload("res://data/formaciones/piedemonte_2_lutita_fragil.tres")
const KCL := preload("res://data/productos/kcl.tres")


func _formacion_inerte(porosidad: float) -> FormacionScript:
	var f := FormacionScript.new()
	f.porosidad = porosidad
	return f


func _activo(volumen := 600.0) -> Tanque:
	return Tanque.crear("Succión", 1000.0, "succion", volumen, Base.disperso_lignosulfonato())


func _lodo_inhibido() -> Tanque:
	var t := _activo()
	t.tratar(KCL, 20.0)                      # ~20.000 mg/l de K⁺
	t.lodo.agregar_aditivo("phpa", 1.5)
	t.lodo.agregar_aditivo("amina", 4.0)
	return t


# §6.1 — ejemplo publicado: 26", 62 ft/h, φ 0,25 → ~30 bbl/h
func test_ejemplo_solidos_generados() -> void:
	var r := Perforacion.avanzar_perforacion(_activo(2000.0), _formacion_inerte(0.25), 62.0, 26.0, 60.0)
	verificar_cerca(r["generados_bbl"], 30.5, 0.2, "26²/1.029,4 × 62 × 0,75")
	verificar_cerca(r["pies"], 62.0, 1e-6, "una hora a 62 ft/h")
	verificar_cerca(r["retenidos_bbl"], r["generados_bbl"], 1e-6, "sin equipos todo entra al lodo")


# §6.1 y §12.5 — CAIMÁN-3 superficial: 17½", 80 ft/h, φ 0,30 → ~17 bbl/h y ~3,3 retenidos al 80 %
func test_calibracion_caiman_superficial() -> void:
	var control := ControlSolidos.crear_estandar()
	verificar_cerca(control.eficiencia_remocion(), 0.80, 0.02, "los cuatro equipos buenos ≈ 80 %")
	var r := Perforacion.avanzar_perforacion(_activo(), SUPERFICIAL, 80.0, 17.5, 60.0, control, 1000.0)
	verificar_cerca(r["generados_bbl"], 16.66, 0.1, "0,2975 × 80 × 0,70")
	verificar_cerca(r["retenidos_bbl"], 3.3, 0.4, "≈ 3,3 bbl/h se quedan en el lodo")
	verificar_cerca(r["profundidad_ft"], 1080.0, 1e-6, "profundidad nueva")


# rig-tank-system.md §4 regla 4 — el hueco nuevo se llena con lodo del activo
func test_volumen_del_activo_baja() -> void:
	var t := _activo()
	var r := Perforacion.avanzar_perforacion(t, SUPERFICIAL, 80.0, 17.5, 60.0, ControlSolidos.crear_estandar())
	verificar_cerca(r["hueco_bbl"], 23.8, 0.1, "0,2975 bbl/ft × 80 ft")
	verificar(r["lodo_en_recortes_bbl"] > 0.0, "se va lodo pegado a los recortes (§10.1)")
	var esperado: float = 600.0 - r["hueco_bbl"] + r["retenidos_bbl"] - r["lodo_en_recortes_bbl"]
	verificar_cerca(t.volumen_bbl, esperado, 1e-6, "balance de volumen")
	verificar(t.volumen_bbl < 580.0, "el activo baja más de 20 bbl en una hora (%.1f)" % t.volumen_bbl)


func test_tanque_vacio_reporta_faltante() -> void:
	var t := _activo(3.0)
	var r := Perforacion.avanzar_perforacion(t, SUPERFICIAL, 80.0, 17.5, 60.0)
	verificar(r["volumen_faltante_bbl"] > 0.0, "no alcanza para llenar el hueco")
	verificar(t.volumen_bbl >= 0.0, "el volumen no queda negativo")


# §6.1 y §7 — con los equipos apagados la VP sube más
func test_pv_sube_mas_con_equipos_apagados() -> void:
	var apagado := _activo()
	var encendido := _activo()
	var vp0 := apagado.lodo.vp()
	var control_off := ControlSolidos.crear_estandar()
	for tipo in ["zaranda", "desarenador", "deslimador", "centrifuga"]:
		control_off.encender(tipo, false)
	Perforacion.avanzar_perforacion(apagado, SUPERFICIAL, 80.0, 17.5, 240.0, control_off)
	Perforacion.avanzar_perforacion(encendido, SUPERFICIAL, 80.0, 17.5, 240.0, ControlSolidos.crear_estandar())
	verificar(encendido.lodo.vp() > vp0, "aun con equipos entra algo de sólido")
	verificar(apagado.lodo.vp() - vp0 > 3.0 * (encendido.lodo.vp() - vp0),
		"apagados la VP sube mucho más (%.1f contra %.1f)" % [apagado.lodo.vp(), encendido.lodo.vp()])
	verificar(apagado.lodo.lgs_pct() > encendido.lodo.lgs_pct(), "y el % de LGS")


func test_malla_rota_baja_la_eficiencia() -> void:
	var control := ControlSolidos.crear_estandar()
	var buena: float = control.eficiencia_remocion()
	control.fijar_estado("zaranda", "malla_rota")
	verificar(control.eficiencia_remocion() < buena - 0.1, "una malla rota deja pasar recortes")


# §13.5 — lutita reactiva: sin inhibidor sube más el MBT; el K⁺ se consume y el Cl⁻ no
func test_lutita_reactiva_e_inhibicion() -> void:
	var sin := _activo()
	var con := _lodo_inhibido()
	var mbt_sin := sin.lodo.mbt()
	var mbt_con := con.lodo.mbt()
	var k0 := con.lodo.k
	var cl0 := con.lodo.cl
	var phpa0 := con.lodo.phpa
	var amina0 := con.lodo.amina
	var rs := Perforacion.avanzar_perforacion(sin, LUTITA, 60.0, 12.25, 240.0, ControlSolidos.crear_estandar(), 3200.0)
	var rc := Perforacion.avanzar_perforacion(con, LUTITA, 60.0, 12.25, 240.0, ControlSolidos.crear_estandar(), 3200.0)
	var sube_sin := sin.lodo.mbt() - mbt_sin
	var sube_con := con.lodo.mbt() - mbt_con
	verificar(sube_sin > 2.0, "sin inhibidor la arcilla se dispersa (MBT +%.1f)" % sube_sin)
	verificar(sube_con < 0.4 * sube_sin, "inhibido sube mucho menos (+%.1f contra +%.1f)" % [sube_con, sube_sin])
	verificar(rc["inhibicion"] > 0.8, "KCl + PHPA + amina inhiben (%.2f)" % rc["inhibicion"])
	verificar(rs["inhibicion"] < 0.2, "el lodo disperso casi no inhibe (%.2f)" % rs["inhibicion"])
	verificar(con.lodo.k < k0 - 200.0, "el K⁺ se consume (%.0f → %.0f)" % [k0, con.lodo.k])
	verificar(con.lodo.cl > 0.95 * cl0, "los cloruros casi no bajan: la trampa de §13.1")
	verificar(con.lodo.phpa < phpa0 and con.lodo.amina < amina0, "se gastan PHPA y amina")
	verificar(sin.lodo.pc() > _activo().lodo.pc(), "la arcilla activa sube el PC")


# §13.1 — KCl en caolinita no ayuda: dispersa más
func test_kcl_en_caolinita() -> void:
	var con_k := _activo()
	con_k.tratar(KCL, 20.0)
	var sin_k := _activo()
	verificar(Perforacion.inhibicion(con_k.lodo, ARENA) < Perforacion.inhibicion(sin_k.lodo, ARENA),
		"el KCl empeora la caolinita")
	verificar(Perforacion.inhibicion(con_k.lodo, LUTITA) > Perforacion.inhibicion(sin_k.lodo, LUTITA),
		"y ayuda en montmorillonita")


# mud-programs.md, CAIMÁN-3 — el cemento de la zapata contamina al perforarlo
func test_cemento_de_la_zapata() -> void:
	var t := _activo(700.0)
	var pm0 := t.lodo.pm()
	var ca0 := t.lodo.ca
	Perforacion.avanzar_perforacion(t, CEMENTO, 60.0, 12.25, 90.0, ControlSolidos.crear_estandar(), 2420.0)
	verificar(t.lodo.pm() > pm0 + 1.0, "sube el Pm (%.2f → %.2f)" % [pm0, t.lodo.pm()])
	verificar(t.lodo.finos_cemento > 0.0, "quedan finos de cemento por disolver")
	verificar(t.lodo.ph() > 11.0, "sube el pH (%.2f)" % t.lodo.ph())
	verificar(t.lodo.ca >= ca0, "el calcio no baja")


# reference-wells.md §2 (PIEDEMONTE-2) — derrumbes por densidad baja, sin química
func test_lutita_fragil() -> void:
	var liviano := _activo()
	var r := Perforacion.avanzar_perforacion(liviano, FRAGIL, 40.0, 12.25, 60.0, ControlSolidos.crear_estandar())
	verificar(r["derrumbes_bbl"] > 0.0, "con 9 ppg y mínimo 10,8 se derrumba")
	verificar(r["arcilla_activa_lb_bbl"] < 0.1, "pero el MBT casi no sube: no es química")
	var pesado := _activo()
	pesado.lodo.agregar_barita(F.barita_lb_por_bbl(pesado.lodo.densidad(), 11.0))
	var r2 := Perforacion.avanzar_perforacion(pesado, FRAGIL, 40.0, 12.25, 60.0, ControlSolidos.crear_estandar())
	verificar_cerca(r2["derrumbes_bbl"], 0.0, 1e-9, "con densidad sobre el mínimo no se derrumba")


func test_formaciones_por_profundidad() -> void:
	var lista := [SUPERFICIAL, CEMENTO, INTERMEDIA, LUTITA, ARENA]
	verificar(Perforacion.formacion_en(lista, 1000.0) == SUPERFICIAL, "superficial")
	verificar(Perforacion.formacion_en(lista, 2450.0) == CEMENTO, "cemento al iniciar la intermedia")
	verificar(Perforacion.formacion_en(lista, 3500.0) == LUTITA, "lutita reactiva desde 3.200 ft")
	verificar(Perforacion.formacion_en(lista, 9000.0) == ARENA, "arena productora")
	for i in range(lista.size() - 1):
		verificar_cerca(lista[i].base_ft, lista[i + 1].tope_ft, 1e-9, "sin huecos entre formaciones")


# §12.2 — perforación + control + cinética: el pozo crece y el activo se homogeniza
func test_avanzar_con_tiempo() -> void:
	var a := _activo(300.0)
	var b := Tanque.crear("Proceso", 500.0, "proceso", 300.0, Base.disperso_lignosulfonato())
	var r := Perforacion.avanzar_con_tiempo([a, b], a, SUPERFICIAL, 80.0, 17.5, 120.0,
		ControlSolidos.crear_estandar(), 600.0, 1000.0, 300.0)
	verificar_cerca(r["volumen_pozo_bbl"], 300.0 + r["hueco_bbl"], 1e-6, "el pozo crece con el hueco")
	verificar(b.lodo.frac_lgs > Base.disperso_lignosulfonato().frac_lgs, "los sólidos llegan al otro tanque")
