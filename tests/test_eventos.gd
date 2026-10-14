extends "res://tests/test_case.gd"
## Eventos como dato (sim/evento.gd, data/eventos/) y monitor de tanques PVT
## (sim/monitor_tanques.gd). simulation-logic.md §4, §10, §14 y §15.

const EventoScript := preload("res://sim/evento.gd")
const Ejecucion := preload("res://sim/guion_ejecucion.gd")
const GuionScript := preload("res://sim/guion_seccion.gd")
const Tanque := preload("res://sim/tanque.gd")
const EstadoLodoScript := preload("res://sim/estado_lodo.gd")
const Base := preload("res://sim/lodos_base.gd")
const F := preload("res://sim/formulas.gd")

const BARITA := preload("res://data/productos/barita.tres")
const PVT := preload("res://data/eventos/monitor_pvt.tres")

## Palabras que un aviso de observación no puede decir (invariante 1): nombres
## de contaminantes químicos y de los iones que los delatan.
const PROHIBIDAS := ["cemento", "cal", "calcio", "yeso", "anhidrita", "sal", "salmuera",
	"carbonato", "carbonatos", "bicarbonato", "magnesio", "carnalita", "h2s", "sulfuro",
	"sulfuros", "sulfhídrico", "cloruro", "cloruros", "potasio", "co2"]


func _ev(id: String) -> Resource:
	return load("res://data/eventos/%s.tres" % id)


## Lodo de 10 ppg exactos: agua dulce + barita.
func _lodo_10_ppg() -> EstadoLodoScript:
	var lodo := EstadoLodoScript.new()
	lodo.frac_barita = (10.0 - F.DENSIDAD_AGUA_PPG) / (F.DENSIDAD_BARITA_PPG - F.DENSIDAD_AGUA_PPG)
	return lodo


func _tanques(lodo: EstadoLodoScript = null) -> Array:
	var l := lodo if lodo != null else Base.disperso_lignosulfonato()
	return [
		Tanque.crear("Proceso", 500.0, "proceso", 300.0, l.copiar()),
		Tanque.crear("Succión", 500.0, "succion", 300.0, l.copiar()),
		Tanque.crear("Reserva", 500.0, "reserva", 300.0, l.copiar(), false),
	]


static func _palabras(texto: String) -> Array:
	var r: Array = []
	var actual := ""
	for c in texto.to_lower():
		if c.unicode_at(0) >= 128 or (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			actual += c
		else:
			if actual != "":
				r.append(actual)
			actual = ""
	if actual != "":
		r.append(actual)
	return r


# ======================= Datos =======================

func test_catalogo_completo_y_valido() -> void:
	var eventos := Ejecucion.cargar_catalogo()
	verificar(eventos.size() >= 12, "hay eventos en data/eventos (%d)" % eventos.size())
	var tipos := {}
	for e in eventos:
		verificar(e.problemas().is_empty(), "%s: %s" % [e.id, e.problemas()])
		verificar(e.quien_avisa in EventoScript.QUIEN_AVISA, "%s: quién avisa" % e.id)
		verificar(e.aviso.strip_edges() != "", "%s: aviso vacío" % e.id)
		verificar(e.explicacion.strip_edges() != "", "%s: explicación vacía" % e.id)
		verificar(e.referencia.strip_edges() != "", "%s: sin referencia" % e.id)
		var archivo: String = e.resource_path.get_file().trim_suffix(".tres")
		verificar(e.id == archivo, "%s: el id coincide con el archivo" % e.id)
		tipos[e.tipo] = true
	# "contaminacion" sigue soportado (ver el test de abajo) pero el catálogo ya no
	# trae ninguno: el cemento de la zapata sale de perforarlo (auditoría C4).
	for t in ["perdida_circulacion", "influjo", "gas_conexion", "gas_viaje", "viaje",
			"sag", "falla_equipo"]:
		verificar(tipos.has(t), "hay al menos un evento de tipo %s" % t)


func test_avisos_de_observacion_no_nombran_el_contaminante() -> void:
	var prohibidas := PROHIBIDAS.duplicate()
	for archivo in DirAccess.get_files_at("res://data/contaminantes"):
		if archivo.ends_with(".tres"):
			for p in _palabras(load("res://data/contaminantes/" + archivo).nombre):
				if p.length() > 2:
					prohibidas.append(p)
	var observaciones := 0
	for e in Ejecucion.cargar_catalogo():
		if not e.aviso_es_observacion:
			continue
		observaciones += 1
		for p in _palabras(e.aviso):
			verificar(not p in prohibidas, "%s: el aviso dice «%s»" % [e.id, p])
	verificar(observaciones >= 5, "hay avisos de observación para revisar")
	# Los "nadie" son siempre observación: se ven en los tanques.
	for e in Ejecucion.cargar_catalogo():
		if e.quien_avisa == "nadie":
			verificar(e.aviso_es_observacion, "%s: lo que nadie avisa se observa" % e.id)


func test_monitor_pvt_tiene_textos() -> void:
	for campo in ["aviso_ganancia", "aviso_perdida", "explicacion_falsa_ganancia",
			"explicacion_falsa_perdida", "explicacion_ganancia", "explicacion_perdida",
			"explicacion_mixta"]:
		verificar(String(PVT.get(campo)).strip_edges() != "", "monitor_pvt: %s vacío" % campo)


# ======================= Pérdidas =======================

# simulation-logic.md §10.1
func test_clasificacion_de_perdidas() -> void:
	verificar(EventoScript.clasificar_perdida(12.0) == "filtracion", "12 bbl/h es filtración")
	verificar(EventoScript.clasificar_perdida(25.0) == "filtracion", "25 bbl/h todavía es filtración")
	verificar(EventoScript.clasificar_perdida(60.0) == "parcial", "60 bbl/h es parcial")
	verificar(EventoScript.clasificar_perdida(150.0) == "severa", "150 bbl/h es severa")
	verificar(EventoScript.clasificar_perdida(0.0, true) == "total", "sin retorno es total")
	verificar(_ev("c3p_perdida_parcial").clasificacion() == "parcial", "la de producción es parcial")


func test_perdida_parcial_resta_el_volumen_en_el_tiempo() -> void:
	var tanques := _tanques()
	var ej := Ejecucion.new()
	var e := _ev("c3p_perdida_parcial")   # 60 bbl/h durante 4 h
	ej.disparar(e, tanques, 8900.0)
	ej.paso(tanques, 8900.0, 60.0)
	verificar_cerca(tanques[0].volumen_bbl + tanques[1].volumen_bbl, 540.0, 1e-6, "una hora: 60 bbl")
	for i in 30:   # 5 h más en pasos de 10 min: la pérdida termina a las 4 h
		ej.paso(tanques, 8900.0, 10.0)
	verificar_cerca(tanques[0].volumen_bbl + tanques[1].volumen_bbl, 360.0, 1e-6, "4 h × 60 = 240 bbl")
	verificar_cerca(tanques[0].volumen_bbl, tanques[1].volumen_bbl, 1e-6, "se reparte por volumen")
	verificar_cerca(tanques[2].volumen_bbl, 300.0, 1e-9, "la reserva no se toca")
	verificar_cerca(ej.perdido_bbl(e.id), 240.0, 1e-6, "lleva la cuenta de lo perdido")
	verificar(not ej.esta_activo(e.id), "terminó")


func test_terminar_una_perdida_la_corta() -> void:
	var tanques := _tanques()
	var ej := Ejecucion.new()
	ej.disparar(_ev("c3p_perdida_parcial"), tanques, 8900.0)
	ej.paso(tanques, 8900.0, 30.0)
	verificar(ej.terminar("c3p_perdida_parcial"), "la píldora selló")
	ej.paso(tanques, 8900.0, 120.0)
	verificar_cerca(tanques[0].volumen_bbl + tanques[1].volumen_bbl, 570.0, 1e-6, "solo media hora de pérdida")


# ======================= Influjo =======================

# domain-research.md §4.1; tests/test_formulas.gd: 10 ppg, SIDPP 520, TVD 10.000 → 11,0
func test_influjo_calcula_peso_de_matada() -> void:
	var e := EventoScript.new()
	e.id = "prueba_influjo"
	e.tipo = "influjo"
	e.sidpp_psi = 520.0
	e.tvd_ft = 10000.0
	e.ganancia_bbl = 20.0
	e.quien_avisa = "driller"
	e.aviso = "SIDPP {sidpp} psi, TVD {tvd} ft, lodo {densidad} ppg: matada {peso_matada} ppg."
	e.explicacion = "KMW = MW + SIDPP / (0,052 × TVD)"
	verificar_cerca(e.peso_de_matada(10.0), 11.0, 1e-9, "fórmula")

	var tanques := _tanques(_lodo_10_ppg())
	var guion := GuionScript.new()
	guion.eventos = [e]
	var ej := Ejecucion.new(guion)
	var aviso := ej.disparar(e, tanques, 10000.0)
	verificar_cerca(aviso["datos"]["peso_matada"], 11.0, 1e-9, "peso de matada redondeado")
	verificar(aviso["texto"] == "SIDPP 520 psi, TVD 10.000 ft, lodo 10,0 ppg: matada 11,0 ppg.",
		"texto con formato de campo: %s" % aviso["texto"])
	verificar_cerca(tanques[0].volumen_bbl + tanques[1].volumen_bbl, 620.0, 1e-6, "la ganancia entra al activo")
	verificar_cerca(tanques[2].volumen_bbl, 300.0, 1e-9, "la reserva no cambia")
	verificar(ej.perforacion_detenida(tanques), "sin peso de matada no se perfora")

	for t in tanques:
		if t.en_sistema_activo:
			t.tratar(BARITA, F.barita_lb_por_bbl(10.0, 11.0))
	verificar(ej.exigencia_cumplida(e.id, tanques), "con 11,0 ppg se cumple")
	verificar(not ej.perforacion_detenida(tanques), "y se puede seguir")


func test_redondeo_del_peso_de_matada() -> void:
	verificar_cerca(EventoScript.redondear_arriba(10.676), 10.7, 1e-9, "10,676 → 10,7")
	verificar_cerca(EventoScript.redondear_arriba(11.0), 11.0, 1e-9, "11,0 se queda")
	verificar_cerca(EventoScript.redondear_arriba(10.61), 10.7, 1e-9, "siempre hacia arriba")


# ======================= Contaminación, equipos, viajes =======================

func test_contaminacion_de_un_evento_cambia_el_estado() -> void:
	# El tipo "contaminacion" lo usan los eventos que traen un contaminante de
	# afuera (barita sucia, agua de mezcla). El cemento de la zapata NO: sale de
	# perforarlo (auditoría C4). Aquí se arma un evento de prueba, 0,4 lb/bbl en 1,5 h.
	var tanques := _tanques()
	var antes: EstadoLodoScript = tanques[0].lodo.copiar()
	var ej := Ejecucion.new()
	var e := EventoScript.new()
	e.id = "prueba_contaminacion"
	e.tipo = "contaminacion"
	e.contaminante = load("res://data/contaminantes/cemento.tres")
	e.cantidad = 0.4
	e.duracion_h = 1.5
	ej.disparar(e, tanques, 2500.0)
	for i in 9:
		ej.paso(tanques, 2500.0, 10.0)
	var lodo: EstadoLodoScript = tanques[0].lodo
	verificar(not ej.esta_activo(e.id), "ya entró todo")
	verificar_cerca(lodo.finos_cemento - antes.finos_cemento, 0.2, 1e-6, "la mitad entra como finos")
	verificar(lodo.pm() > antes.pm() + 0.5, "sube el Pm (%.2f → %.2f)" % [antes.pm(), lodo.pm()])
	verificar(lodo.ph() > antes.ph(), "sube el pH")
	verificar(tanques[2].lodo.finos_cemento == antes.finos_cemento, "la reserva no se contamina")



func test_falla_de_equipo_y_viaje_duran_lo_dicho() -> void:
	var tanques := _tanques()
	var ej := Ejecucion.new()
	ej.disparar(_ev("c3p_falla_centrifuga"), tanques)
	ej.disparar(_ev("c3i_viaje_broca"), tanques)
	ej.paso(tanques, 5500.0, 60.0)
	verificar("centrifuga" in ej.equipos_fuera(), "la centrífuga está fuera")
	verificar(ej.perforacion_detenida(tanques), "en viaje no se perfora")
	ej.paso(tanques, 5500.0, 7.0 * 60.0)
	verificar(ej.equipos_fuera().is_empty(), "a las 8 h vuelve la centrífuga")
	verificar(ej.perforacion_detenida(tanques), "el viaje sigue")
	ej.paso(tanques, 5500.0, 2.0 * 60.0)
	verificar(not ej.perforacion_detenida(tanques), "a las 10 h termina el viaje")
	verificar_cerca(tanques[0].volumen_bbl, 300.0, 1e-9, "ni el viaje ni la falla mueven volumen")


func test_condicion_mal_escrita_no_dispara() -> void:
	var e := EventoScript.new()
	e.id = "roto"
	e.disparador = "condicion"
	e.condicion = "props.densidad <"
	e.mostrar_errores = false
	verificar(not e.problemas().is_empty(), "problemas() la detecta")
	verificar(not e.cumple_condicion({"props": {"densidad": 9.0}}), "y no dispara")


# ======================= Monitor PVT (§4) =======================

func _monitor() -> Resource:
	return PVT.duplicate()


func test_pvt_transferencia_avisada_no_alarma() -> void:
	var tanques := _tanques()
	var m := _monitor()
	m.referenciar(tanques)
	tanques[2].transferir(tanques[1], 80.0)
	m.transferencia(80.0, true)
	verificar(not m.leer(tanques)["alarma"], "avisada: el PVT la espera")


func test_pvt_transferencia_sin_avisar_es_falsa_alarma() -> void:
	var tanques := _tanques()
	var m := _monitor()
	m.referenciar(tanques)
	tanques[2].transferir(tanques[1], 80.0)
	m.transferencia(80.0, false)
	var r: Dictionary = m.leer(tanques)
	verificar(r["alarma"] and r["nueva"], "suena")
	verificar(r["tipo"] == "ganancia", "la lee como ganancia")
	verificar(r["falsa"], "es falsa: la causó el jugador")
	verificar(r["explicacion"] == m.explicacion_falsa_ganancia, "explica la falsa alarma")
	verificar(r["minutos_perdidos"] > 0.0, "cuesta tiempo")
	verificar(r["aviso"].contains("80"), "el driller dice cuánto")
	verificar(not m.leer(tanques)["nueva"], "no se repite hasta reconocerla")
	m.reconocer(tanques)
	verificar(not m.leer(tanques)["alarma"], "reconocida, vuelve a cero")

	# Al revés: sacar del activo sin avisar.
	tanques[1].transferir(tanques[2], 50.0)
	m.transferencia(-50.0, false)
	r = m.leer(tanques)
	verificar(r["falsa"] and r["tipo"] == "perdida", "falsa alarma de pérdida")


func test_pvt_perdida_real_es_alarma_verdadera() -> void:
	var tanques := _tanques()
	var m := _monitor()
	m.referenciar(tanques)
	var ej := Ejecucion.new()
	ej.disparar(_ev("c3p_perdida_parcial"), tanques, 8900.0)
	ej.paso(tanques, 8900.0, 5.0)
	verificar(not m.leer(tanques)["alarma"], "5 bbl todavía no pasan el umbral")
	ej.paso(tanques, 8900.0, 30.0)
	var r: Dictionary = m.leer(tanques)
	verificar(r["alarma"] and not r["falsa"], "alarma verdadera")
	verificar(r["tipo"] == "perdida", "de pérdida")
	verificar(r["explicacion"] == m.explicacion_perdida, "explica la pérdida real")
	verificar_cerca(r["sin_explicar_bbl"], -35.0, 1e-6, "35 bbl que tomó el pozo")


func test_pvt_ganancia_real_y_mixta() -> void:
	var tanques := _tanques(_lodo_10_ppg())
	var m := _monitor()
	m.referenciar(tanques)
	# El jugador saca 30 bbl sin avisar y a la vez el pozo devuelve 50.
	tanques[1].transferir(tanques[2], 30.0)
	m.transferencia(-30.0, false)
	Ejecucion.sumar_al_activo(tanques, 50.0)
	var r: Dictionary = m.leer(tanques)
	verificar(r["alarma"] and not r["falsa"], "hay algo real detrás")
	verificar(r["tipo"] == "ganancia", "neto: ganancia de 20")
	verificar(r["explicacion"] == m.explicacion_mixta, "explica que se mezclaron")
	verificar_cerca(r["sin_explicar_bbl"], 50.0, 1e-6, "lo del pozo son 50 bbl")
