extends "res://tests/test_case.gd"
## Paso del tiempo: homogenización del activo, disolución lenta de cal,
## prehidratación de bentonita y asentamiento (simulation-logic.md §2, §8, §12.2;
## rig-tank-system.md §4; mud-engineer-reference.md §1.3).

const Tanque := preload("res://sim/tanque.gd")
const Cinetica := preload("res://sim/cinetica.gd")
const EstadoLodoScript := preload("res://sim/estado_lodo.gd")
const Base := preload("res://sim/lodos_base.gd")
const F := preload("res://sim/formulas.gd")

const BENTONITA := preload("res://data/productos/bentonita.tres")


func _lodo_con_cl(cl: float) -> EstadoLodoScript:
	var lodo := EstadoLodoScript.new()
	lodo.frac_lgs = 0.05
	lodo.cl = cl
	return lodo


# §2 — ejemplo de calibración: 546 bbl en el pozo + 600 en superficie a 600 gpm ≈ 80 min
func test_ciclo_completo() -> void:
	var tanques := [
		Tanque.crear("Proceso", 400.0, "proceso", 300.0, _lodo_con_cl(1000.0)),
		Tanque.crear("Succión", 400.0, "succion", 300.0, _lodo_con_cl(1000.0)),
		Tanque.crear("Reserva", 400.0, "reserva", 300.0, _lodo_con_cl(1000.0), false),
	]
	var ciclo := Cinetica.ciclo_completo_min(tanques, 600.0, 546.0)
	verificar_cerca(ciclo, 1146.0 / (600.0 / 42.0), 1e-6, "(pozo + activo) / caudal")
	verificar_cerca(ciclo, 80.2, 0.1, "≈ 80 min (la reserva no cuenta)")
	verificar(is_inf(Cinetica.ciclo_completo_min(tanques, 0.0, 546.0)), "sin caudal no hay ciclo")


# §4 reglas 2 y 3 — lo agregado en un tanque activo se reparte en ciclos; la reserva no se entera.
func test_homogenizacion_del_activo() -> void:
	var proceso = Tanque.crear("Proceso", 400.0, "proceso", 300.0, _lodo_con_cl(1000.0))
	var succion = Tanque.crear("Succión", 400.0, "succion", 300.0, _lodo_con_cl(7000.0))
	var reserva = Tanque.crear("Reserva", 400.0, "reserva", 300.0, _lodo_con_cl(20000.0), false)
	var tanques := [proceso, succion, reserva]
	var ciclo := Cinetica.ciclo_completo_min(tanques, 600.0, 546.0)

	Cinetica.avanzar(tanques, ciclo, 600.0, 546.0)
	var diferencia: float = succion.lodo.cl - proceso.lodo.cl
	verificar_cerca(diferencia, 6000.0 * exp(-1.0), 30.0, "tras un ciclo queda 1/e de la diferencia")
	verificar_cerca(proceso.lodo.cl + succion.lodo.cl, 8000.0, 1e-6, "se conserva la sal")

	Cinetica.avanzar(tanques, 12.0 * 60.0, 600.0, 546.0)
	verificar_cerca(proceso.lodo.cl, 4000.0, 1.0, "parejo después de varios ciclos")
	verificar_cerca(succion.lodo.cl, 4000.0, 1.0, "parejo después de varios ciclos")
	verificar_cerca(reserva.lodo.cl, 20000.0, 1e-9, "la reserva está aislada")


func test_sin_circular_no_homogeniza() -> void:
	var proceso = Tanque.crear("Proceso", 400.0, "proceso", 300.0, _lodo_con_cl(1000.0))
	var succion = Tanque.crear("Succión", 400.0, "succion", 300.0, _lodo_con_cl(7000.0))
	Cinetica.avanzar([proceso, succion], 120.0, 0.0, 546.0)
	verificar_cerca(succion.lodo.cl, 7000.0, 1e-9, "sin bombas cada tanque sigue igual")


# Decisión del autor: sin tratamientos, las propiedades no derivan solas durante
# un día; la cal en exceso es reserva y no se disuelve sola.
func test_lodo_base_estable_un_dia() -> void:
	var t = Tanque.crear("Succión", 800.0, "succion", 600.0, Base.disperso_lignosulfonato())
	var ph0: float = t.lodo.ph()
	var ca0: float = t.lodo.ca
	Cinetica.avanzar([t], 24.0 * 60.0, 600.0, 600.0)
	verificar_cerca(t.lodo.ph(), ph0, 0.05, "el pH no deriva en un día")
	verificar_cerca(t.lodo.ca, ca0, 5.0, "el calcio no deriva en un día")


# mud-engineer-reference.md §1.3 punto 6 — los finos de cemento se disuelven, y
# (decisión del autor) el efecto se ve en pocas vueltas del lodo, no en horas fijas.
func test_finos_de_cemento_se_disuelven_en_vueltas() -> void:
	var lodo = Base.disperso_lignosulfonato()
	lodo.finos_cemento = 0.5
	var t = Tanque.crear("Succión", 800.0, "succion", 600.0, lodo)
	var ph0: float = t.lodo.ph()
	var pm0: float = t.lodo.pm()
	var vuelta: float = Cinetica.ciclo_completo_min([t], 600.0, 600.0)
	Cinetica.avanzar([t], vuelta, 600.0, 600.0)
	verificar(t.lodo.finos_cemento < 0.5 * 0.4, "en una vuelta se disuelve más del 60 %% (%.2f lb/bbl)" % t.lodo.finos_cemento)
	verificar(t.lodo.ph() > ph0 + 0.3, "el pH ya subió en una vuelta (%.2f → %.2f)" % [ph0, t.lodo.ph()])
	Cinetica.avanzar([t], 3.0 * vuelta, 600.0, 600.0)
	verificar(t.lodo.finos_cemento < 0.5 * 0.02, "en cuatro vueltas casi no quedan finos")
	# Disolver no crea ni destruye alcalinidad: el Pm (lodo entero) se conserva.
	verificar_cerca(t.lodo.pm(), pm0, 0.1, "el Pm se conserva")


# Con más caudal (vuelta más corta) los finos se disuelven antes.
func test_vuelta_mas_corta_disuelve_antes() -> void:
	var lento = Base.disperso_lignosulfonato()
	lento.finos_cemento = 0.5
	var rapido = lento.copiar()
	var t1 = Tanque.crear("A", 800.0, "succion", 600.0, lento)
	var t2 = Tanque.crear("B", 800.0, "succion", 600.0, rapido)
	Cinetica.avanzar([t1], 60.0, 300.0, 600.0)
	Cinetica.avanzar([t2], 60.0, 900.0, 600.0)
	verificar(t2.lodo.finos_cemento < t1.lodo.finos_cemento, "a 900 gpm quedan menos finos que a 300 gpm")


func test_cal_no_pasa_de_saturacion() -> void:
	var lodo := EstadoLodoScript.new()
	lodo.finos_cemento = 3.0
	var t = Tanque.crear("Píldora", 100.0, "pildora", 50.0, lodo, false)
	Cinetica.avanzar([t], 24.0 * 60.0, 0.0, 0.0)
	verificar(t.lodo.oh <= EstadoLodoScript.OH_MAX_CAL_MG_L + 1e-6, "OH⁻ no pasa de saturación")
	verificar_cerca(t.lodo.oh, EstadoLodoScript.OH_MAX_CAL_MG_L, 1.0, "llega a saturación")
	verificar(t.lodo.cal_exceso > 0.0, "lo que no cabe en solución queda como cal en exceso")


# simulation-logic.md §8 — prehidratación: parcial a las 3 h, completa a las 6 h.
func test_bentonita_prehidrata_en_agua_dulce() -> void:
	var t = Tanque.crear("Reserva", 400.0, "reserva", 300.0, EstadoLodoScript.new(), false)
	t.tratar(BENTONITA, 25.0)
	var total: float = t.bentonita_sin_hidratar
	verificar(t.volumen_bbl > 300.0, "los sólidos suman volumen desde el principio")
	verificar(t.lodo.frac_lgs > 0.0, "y cuentan en la fase sólida")
	verificar_cerca(t.lodo.bentonita, 0.0, 1e-9, "recién agregada no rinde")
	var pc0: float = t.lodo.pc()

	Cinetica.avanzar([t], 3.0 * 60.0, 0.0, 0.0)
	verificar_cerca(t.lodo.bentonita / total, 0.5, 0.01, "a las 3 h rinde la mitad")
	var pc3: float = t.lodo.pc()

	Cinetica.avanzar([t], 3.0 * 60.0, 0.0, 0.0)
	verificar_cerca(t.lodo.bentonita, total, 1e-6, "a las 6 h rinde todo")
	verificar_cerca(t.bentonita_sin_hidratar, 0.0, 1e-9, "no queda nada sin hidratar")
	verificar(t.lodo.pc() > pc3 and pc3 > pc0, "el punto cedente sube con la hidratación")


func test_bentonita_no_hidrata_en_salmuera() -> void:
	var t = Tanque.crear("Reserva", 400.0, "reserva", 300.0, _lodo_con_cl(20000.0), false)
	t.tratar(BENTONITA, 25.0)
	Cinetica.avanzar([t], 6.0 * 60.0, 0.0, 0.0)
	verificar_cerca(t.lodo.bentonita, 0.0, 1e-9, "con Cl⁻ alto no rinde")
	verificar(t.bentonita_sin_hidratar > 20.0, "sigue sin hidratar")


func test_bentonita_hidrata_lento_con_sal_intermedia() -> void:
	var t = Tanque.crear("Reserva", 400.0, "reserva", 300.0, _lodo_con_cl(6500.0), false)
	t.tratar(BENTONITA, 25.0)
	var total: float = t.bentonita_sin_hidratar
	Cinetica.avanzar([t], 6.0 * 60.0, 0.0, 0.0)
	verificar_cerca(t.lodo.bentonita / total, 0.5, 0.01, "a mitad de velocidad rinde la mitad en 6 h")


# El lote sin hidratar viaja con el lodo y conserva su edad.
func test_bentonita_sin_hidratar_se_transfiere() -> void:
	var reserva = Tanque.crear("Reserva", 400.0, "reserva", 300.0, EstadoLodoScript.new(), false)
	reserva.tratar(BENTONITA, 20.0)
	Cinetica.avanzar([reserva], 3.0 * 60.0, 0.0, 0.0)
	var pildora = Tanque.crear("Píldora", 100.0, "pildora", 0.0, null, false)
	reserva.transferir(pildora, 50.0)
	verificar_cerca(pildora.edad_bentonita_h, 3.0, 1e-6, "conserva la edad")
	Cinetica.avanzar([reserva, pildora], 3.0 * 60.0, 0.0, 0.0)
	verificar_cerca(pildora.bentonita_sin_hidratar, 0.0, 1e-9, "termina a las 6 h en la píldora")
	verificar_cerca(pildora.lodo.bentonita, reserva.lodo.bentonita, 1e-6, "igual que en la reserva")


# rig-tank-system.md §4 regla 6 — tanque sin agitar asienta; agitar resuspende.
func test_asentamiento_sin_agitar() -> void:
	var t = Tanque.crear("Reserva", 400.0, "reserva", 300.0, _lodo_con_cl(1000.0), false)
	t.agitado = false
	Cinetica.avanzar([t], 60.0, 0.0, 0.0)
	var s1: float = t.sedimento
	Cinetica.avanzar([t], 5.0 * 60.0, 0.0, 0.0)
	verificar(s1 > 0.0 and t.sedimento > s1, "el sedimento crece con el tiempo")
	t.agitado = true
	Cinetica.avanzar([t], 2.0 * 60.0, 0.0, 0.0)
	verificar(t.sedimento < 0.05, "agitando se resuspende")


func test_pasos_de_10_minutos() -> void:
	# 25 min = 10 + 10 + 5: el resultado es el mismo que en tres pasos sueltos.
	var a = Tanque.crear("A", 600.0, "succion", 500.0, Base.disperso_lignosulfonato())
	var b = Tanque.crear("B", 600.0, "succion", 500.0, Base.disperso_lignosulfonato())
	Cinetica.avanzar([a], 25.0, 0.0, 0.0)
	Cinetica.paso([b], 10.0, 0.0, 0.0)
	Cinetica.paso([b], 10.0, 0.0, 0.0)
	Cinetica.paso([b], 5.0, 0.0, 0.0)
	verificar_cerca(a.lodo.oh, b.lodo.oh, 1e-9, "mismo OH⁻")
