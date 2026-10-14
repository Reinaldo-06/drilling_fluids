extends "res://tests/test_case.gd"
## Tanques: mezcla por volumen, capacidad y tratamientos que suman volumen
## (rig-tank-system.md §4; mud-engineer-reference.md §2.1 y §2.3).

const Tanque := preload("res://sim/tanque.gd")
const EstadoLodoScript := preload("res://sim/estado_lodo.gd")
const Base := preload("res://sim/lodos_base.gd")
const F := preload("res://sim/formulas.gd")


## Lodo de agua dulce y barita a una densidad dada (sin sólidos livianos).
func _lodo_de(densidad: float) -> EstadoLodoScript:
	var lodo := EstadoLodoScript.new()
	lodo.frac_barita = (densidad - F.DENSIDAD_AGUA_PPG) / (F.DENSIDAD_BARITA_PPG - F.DENSIDAD_AGUA_PPG)
	return lodo


func _producto(nombre: String) -> Resource:
	return load("res://data/productos/%s.tres" % nombre)


# §2.3 — 333,3 bbl de 11,2 ppg + 666,7 bbl de 15,4 ppg = 1.000 bbl de 14,0 ppg
func test_mezcla_del_manual() -> void:
	var liviano = Tanque.crear("Reserva 1", 500.0, "reserva", 333.3, _lodo_de(11.2), false)
	var pesado = Tanque.crear("Reserva 2", 1200.0, "reserva", 666.7, _lodo_de(15.4), false)
	var movido: float = liviano.transferir(pesado, 333.3)
	verificar_cerca(movido, 333.3, 1e-6, "se mueve todo el liviano")
	verificar_cerca(pesado.volumen_bbl, 1000.0, 1e-6, "volumen final")
	verificar_cerca(pesado.lodo.densidad(), 14.0, 0.005, "densidad de la mezcla")
	verificar_cerca(liviano.volumen_bbl, 0.0, 1e-6, "el origen queda vacío")


# Los iones del filtrado se ponderan por agua: Cl⁻ = Σ V·Fw·Cl / Σ V·Fw
func test_cloruros_ponderados_por_agua() -> void:
	var a := EstadoLodoScript.new()
	a.frac_lgs = 0.10            # Fw 0,90
	a.cl = 20000.0
	var b := EstadoLodoScript.new()
	b.frac_barita = 0.30         # Fw 0,70
	b.cl = 1000.0
	var ta = Tanque.crear("A", 400.0, "proceso", 100.0, a)
	var tb = Tanque.crear("B", 400.0, "succion", 100.0, b)
	ta.transferir(tb, 100.0)
	var esperado := (100.0 * 0.9 * 20000.0 + 100.0 * 0.7 * 1000.0) / (100.0 * 0.9 + 100.0 * 0.7)
	verificar_cerca(tb.lodo.cl, esperado, 0.01, "Cl⁻ ponderado por agua (11.687,5)")
	verificar_cerca(tb.lodo.fw(), 0.80, 1e-9, "Fw ponderado por volumen")
	verificar_cerca(tb.lodo.frac_barita, 0.15, 1e-9, "barita ponderada por volumen")
	# La densidad sale lineal en volumen, como en el manual §2.3.
	verificar_cerca(tb.lodo.densidad(), (a.densidad() + b.densidad()) / 2.0, 1e-6, "densidad lineal")


# Al juntar dos aguas reaccionan: Ca²⁺ de una con CO₃²⁻ de la otra precipita.
func test_mezclar_reacciona() -> void:
	var a := EstadoLodoScript.new()
	a.ca = 400.0
	var b := EstadoLodoScript.new()
	b.co3 = 600.0
	var r = Tanque.mezclar(a, 1.0, b, 1.0)
	# 200 mg/l de Ca (5 mmol) contra 300 mg/l de CO₃ (5 mmol): precipitan casi todo,
	# hasta el producto de solubilidad efectivo del CaCO₃ (ver EstadoLodo).
	verificar(r.ca < 10.0, "el calcio precipita (%.1f mg/l)" % r.ca)
	verificar(r.co3 < 10.0, "el carbonato precipita (%.1f mg/l)" % r.co3)


# §2.1 — 1.000 bbl de 14 → 16 ppg con la barita de Formulas: 1.105,3 bbl
func test_densificar_tanque() -> void:
	var t = Tanque.crear("Succión", 1500.0, "succion", 1000.0, _lodo_de(14.0))
	var lb := F.barita_lb_por_bbl(14.0, 16.0)
	var r: Dictionary = t.tratar(_producto("barita"), lb)
	verificar_cerca(t.volumen_bbl, 1105.3, 0.05, "volumen final")
	verificar_cerca(t.lodo.densidad(), 16.0, 1e-6, "densidad final")
	verificar_cerca(r["sacos"], F.sacos_barita(1000.0, 14.0, 16.0), 0.5, "sacos (1.548)")
	verificar_cerca(r["rebalse_bbl"], 0.0, 1e-9, "no rebalsa")


# Densificar un tanque casi lleno rebalsa (rig-tank-system.md §4 regla 5).
func test_densificar_sin_espacio_rebalsa() -> void:
	var t = Tanque.crear("Succión", 1050.0, "succion", 1000.0, _lodo_de(14.0))
	var r: Dictionary = t.tratar(_producto("barita"), F.barita_lb_por_bbl(14.0, 16.0))
	verificar_cerca(t.volumen_bbl, 1050.0, 1e-9, "queda lleno")
	verificar_cerca(r["rebalse_bbl"], 55.3, 0.05, "lo que no cabe se pierde")


# §2.2 — diluir con agua también suma volumen
func test_diluir_tanque() -> void:
	var t = Tanque.crear("Activo", 2500.0, "proceso", 1000.0, _lodo_de(16.0))
	t.tratar(_producto("agua"), F.agua_dilucion_bbl(1000.0, 16.0, 12.0) / 1000.0)
	verificar_cerca(t.volumen_bbl, 2094.0, 1.0, "volumen final")
	verificar_cerca(t.lodo.densidad(), 12.0, 1e-6, "densidad final")


# Un químico disuelto no cambia el volumen y los sacos salen de Producto.sacos.
func test_quimico_sin_volumen() -> void:
	var t = Tanque.crear("Succión", 600.0, "succion", 500.0, Base.disperso_lignosulfonato())
	var r: Dictionary = t.tratar(_producto("soda_caustica"), 0.25)
	verificar_cerca(t.volumen_bbl, 500.0, 1e-9, "mismo volumen")
	verificar_cerca(r["sacos"], _producto("soda_caustica").sacos(500.0, 0.25), 1e-9, "sacos")
	verificar(t.lodo.ph() > 10.5, "sube el pH")


func test_capacidad_respetada() -> void:
	var origen = Tanque.crear("Reserva", 500.0, "reserva", 300.0, _lodo_de(10.0), false)
	var destino = Tanque.crear("Píldora", 100.0, "pildora", 70.0, _lodo_de(12.0), false)
	var movido: float = origen.transferir(destino, 80.0)
	verificar_cerca(movido, 30.0, 1e-9, "solo cabe lo libre")
	verificar_cerca(destino.volumen_bbl, 100.0, 1e-9, "destino lleno")
	verificar_cerca(origen.volumen_bbl, 270.0, 1e-9, "origen descuenta lo movido")
	destino.volumen_bbl = 0.0
	movido = origen.transferir(destino, 1000.0)
	verificar_cerca(movido, 100.0, 1e-9, "no rebasa la capacidad")
	var chico = Tanque.crear("Trampa", 100.0, "trampa", 20.0, _lodo_de(9.0))
	movido = chico.transferir(origen, 50.0)
	verificar_cerca(movido, 20.0, 1e-9, "no se saca más de lo que hay")
	verificar_cerca(chico.transferir(origen, -5.0), 0.0, 1e-9, "cantidad negativa no mueve")


# Transferir a un tanque vacío copia el lodo; no lo comparte.
func test_transferir_a_vacio_copia() -> void:
	var origen = Tanque.crear("Reserva", 500.0, "reserva", 300.0, _lodo_de(10.0), false)
	var destino = Tanque.crear("Fractanque", 500.0, "fractanque", 0.0, null, false)
	origen.transferir(destino, 100.0)
	verificar_cerca(destino.lodo.densidad(), 10.0, 1e-9, "misma densidad")
	destino.lodo.cl = 5000.0
	verificar_cerca(origen.lodo.cl, 0.0, 1e-9, "el origen no cambia al tocar el destino")


# Integración A + B: lo disuelto en el filtrado (incluido el CO₂) se mezcla por
# volumen de agua: el carbono total disuelto se conserva al mezclar.
func test_carbono_disuelto_se_conserva_por_agua() -> void:
	var a := EstadoLodoScript.new()
	a.hco3 = 1220.0
	a.co2 = 440.0
	a.equilibrar()
	var b := EstadoLodoScript.new()
	b.frac_barita = 0.2          # menos agua por bbl
	var carbono := func(e) -> float: return e.co3 / 60.01 + e.hco3 / 61.02 + e.co2 / 44.01
	var r = Tanque.mezclar(a, 1.0, b, 1.0)
	var esperado: float = carbono.call(a) * a.fw() / (a.fw() + b.fw())
	verificar_cerca(carbono.call(r), esperado, 0.01, "mmol de carbono por litro de agua")
