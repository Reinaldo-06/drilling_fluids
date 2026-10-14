extends "res://tests/test_case.gd"
## Control de sólidos por pasada: hidrociclones con lodo densificado, centrífuga,
## sólidos dispersos y finos de cemento (simulation-logic.md §7;
## mud-engineer-reference.md §1.3 punto 6 y §1.9).

const ControlSolidos := preload("res://sim/control_solidos.gd")
const Tanque := preload("res://sim/tanque.gd")
const Cinetica := preload("res://sim/cinetica.gd")
const Base := preload("res://sim/lodos_base.gd")
const F := preload("res://sim/formulas.gd")


func _solo(tipos: Array) -> RefCounted:
	var c := ControlSolidos.crear_estandar()
	for e in c.equipos:
		e.encendido = e.tipo in tipos
	return c


func _densificado(ppg: float) -> Tanque:
	var lodo := Base.disperso_lignosulfonato()
	lodo.agregar_barita(F.barita_lb_por_bbl(lodo.densidad(), ppg))
	return Tanque.crear("Succión", 1000.0, "succion", 600.0, lodo)


func test_equipos_como_datos() -> void:
	var c := ControlSolidos.crear_estandar()
	verificar(c.equipos.size() == 4, "cuatro equipos")
	verificar(c.equipos[0].tipo == "zaranda" and c.equipos[3].tipo == "centrifuga", "en el orden del circuito")
	verificar_cerca(c.equipo("desarenador").punto_corte_um, 40.0, 1e-9, "desarenador ~40 μm (§7)")
	verificar_cerca(c.equipo("deslimador").punto_corte_um, 20.0, 1e-9, "deslimador ~20 μm (§7)")
	c.encender("deslimador", false)
	var otro := ControlSolidos.crear_estandar()
	verificar(otro.equipo("deslimador").encendido, "apagar uno no toca el .tres compartido")


# §7 — trampa: con lodo densificado los hidrociclones botan barita y bajan la densidad
func test_hidrociclones_botan_barita() -> void:
	var t := _densificado(12.0)
	var d0 := t.lodo.densidad()
	var v0 := t.volumen_bbl
	var r: Dictionary = _solo(["desarenador", "deslimador"]).procesar(t, 60.0)
	verificar(r["barita_bbl"] > 3.0, "botan barita (%.1f bbl en una hora)" % r["barita_bbl"])
	verificar(t.lodo.densidad() < d0 - 0.1, "la densidad baja (%.2f → %.2f)" % [d0, t.lodo.densidad()])
	verificar_cerca(t.volumen_bbl, v0 - r["descarte_bbl"], 1e-6, "el descarte resta volumen")


# §7 — la centrífuga recupera la barita y descarta los livianos
func test_centrifuga_recupera_barita() -> void:
	var ciclones := _densificado(12.0)
	var centrifuga := _densificado(12.0)
	var d0 := centrifuga.lodo.densidad()
	var lgs0 := centrifuga.lodo.frac_perforados_separables()
	var rh: Dictionary = _solo(["desarenador", "deslimador"]).procesar(ciclones, 60.0)
	var rc: Dictionary = _solo(["centrifuga"]).procesar(centrifuga, 60.0)
	verificar(rc["barita_bbl"] < 0.15 * rh["barita_bbl"], "pierde mucho menos barita")
	verificar(d0 - centrifuga.lodo.densidad() < 0.25 * (d0 - ciclones.lodo.densidad()),
		"la densidad casi no cambia (%.2f)" % centrifuga.lodo.densidad())
	verificar(centrifuga.lodo.frac_perforados_separables() < lgs0, "saca sólidos perforados")


# §7 — sin densificar, los hidrociclones son la herramienta barata contra la VP alta
func test_hidrociclones_bajan_vp_sin_densificar() -> void:
	var t := Tanque.crear("Succión", 1000.0, "succion", 600.0, Base.disperso_lignosulfonato())
	t.lodo.agregar_solidos(0.03)   # sólidos viejos de más
	var vp0: float = t.lodo.vp()
	var mbt0: float = t.lodo.mbt()
	ControlSolidos.crear_estandar().procesar(t, 120.0)
	verificar(t.lodo.vp() < vp0, "baja la VP (%.1f → %.1f)" % [vp0, t.lodo.vp()])
	verificar(t.lodo.bentonita >= 12.0 - 1e-6, "no sacan bentonita (coloidal)")
	verificar(t.lodo.mbt() >= mbt0 - 1e-6, "el MBT no baja")


# mud-engineer-reference.md §1.3 punto 6 — sacar los finos de cemento antes de que se disuelvan
func test_equipos_sacan_finos_de_cemento() -> void:
	var apagado := Tanque.crear("Succión", 1000.0, "succion", 600.0, Base.disperso_lignosulfonato())
	var encendido := Tanque.crear("Succión", 1000.0, "succion", 600.0, Base.disperso_lignosulfonato())
	for t in [apagado, encendido]:
		t.lodo.finos_cemento = 0.5
	var control := ControlSolidos.crear_estandar()
	var sacado := 0.0
	for _i in 6:
		sacado += control.procesar(encendido, 10.0)["finos_cemento_lb"]
		Cinetica.paso([encendido], 10.0, 600.0, 546.0)
		Cinetica.paso([apagado], 10.0, 600.0, 546.0)
	verificar(sacado > 0.0, "los equipos descartan finos")
	verificar(encendido.lodo.finos_cemento < apagado.lodo.finos_cemento, "quedan menos finos")
	verificar(encendido.lodo.pm() < apagado.lodo.pm(), "y el Pm queda más bajo")
	verificar(encendido.lodo.ca < apagado.lodo.ca, "y se disuelve menos calcio")


func test_conos_tapados_y_apagados() -> void:
	var a := _densificado(12.0)
	var b := _densificado(12.0)
	var tapados := _solo(["deslimador"])
	tapados.fijar_estado("deslimador", "conos_tapados")
	var ra: Dictionary = _solo(["deslimador"]).procesar(a, 60.0)
	var rb: Dictionary = tapados.procesar(b, 60.0)
	verificar(rb["descarte_bbl"] < ra["descarte_bbl"], "conos tapados descartan menos")
	var c := _densificado(12.0)
	var rc: Dictionary = _solo([]).procesar(c, 60.0)
	verificar_cerca(rc["descarte_bbl"], 0.0, 1e-12, "todo apagado no descarta nada")
