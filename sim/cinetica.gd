extends RefCounted
## Paso del tiempo en los tanques de superficie.
##
## Pasos de 10 min de juego (decisión cerrada; simulation-logic.md §12.2). En
## cada paso, en el orden de §12.2:
##   4. Química y cinética: disolución lenta de cal en exceso (finos de cemento),
##      hidratación de la bentonita, asentamiento en tanques sin agitar.
##   5. Homogenización del sistema activo en un ciclo completo.
## Perforación, control de sólidos, transferencias por válvulas y eventos
## (pasos 1–3, 6 y 7) todavía no existen.
## Funciones estáticas y sin escena: se prueban en tests/test_tiempo.gd.

const EstadoLodoScript := preload("res://sim/estado_lodo.gd")
const F := preload("res://sim/formulas.gd")
const TanqueScript := preload("res://sim/tanque.gd")

const PASO_MIN := 10.0

## Finos de cemento y cal sin disolver: se disuelven mientras el OH⁻ esté bajo
## saturación (mud-engineer-reference.md §1.3 punto 6: "remover los finos antes
## de que se disuelvan"). Cada hora se disuelve 1 − e^(−1/τ) de lo que queda,
## sin pasar de la saturación de EstadoLodo.OH_MAX_CAL_MG_L. 🧩
const TAU_DISOLUCION_CAL_H := 4.0

## Bentonita: rinde de forma lineal y llega al 100 % a las 6 h en agua dulce
## (simulation-logic.md §8; rango de campo 4–6 h). 🧩
const TIEMPO_HIDRATACION_H := 6.0
## Con cloruros altos casi no hidrata (§8; mud-engineer-reference.md §1.5).
## Velocidad plena hasta CL_HIDRATA_PLENO y nula desde CL_NO_HIDRATA, lineal
## entre ambos. El inicio coincide con el umbral de floculación por sal de
## EstadoLodo. 🧩
const CL_HIDRATA_PLENO := 3000.0
const CL_NO_HIDRATA := 10000.0
## Agua dura: hidrata más lento (§8). Mismo esquema con el calcio. 🧩
const CA_HIDRATA_PLENO := 200.0
const CA_NO_HIDRATA := 1000.0

## Asentamiento sin agitar (rig-tank-system.md §4 regla 6; simulation-logic.md
## §15). El sedimento crece hacia 1 con esta constante, más lento si el lodo
## tiene geles (los geles sostienen la barita). Agitando se resuspende. 🧩
const TAU_ASENTAMIENTO_H := 2.0
const GEL_QUE_DUPLICA_TAU := 10.0      ## lb/100 ft² de gel a 10 min
const TAU_RESUSPENSION_H := 0.5


## Avanza "minutos" de juego sobre una lista de tanques. caudal_gpm = 0 significa
## sin circular (no hay homogenización). volumen_pozo_bbl alarga el ciclo.
static func avanzar(tanques: Array, minutos: float, caudal_gpm: float, volumen_pozo_bbl: float) -> void:
	var restante := minutos
	while restante > 1e-9:
		var dt := minf(PASO_MIN, restante)
		paso(tanques, dt, caudal_gpm, volumen_pozo_bbl)
		restante -= dt


static func paso(tanques: Array, dt_min: float, caudal_gpm: float, volumen_pozo_bbl: float) -> void:
	var dt_h := dt_min / 60.0
	for t: TanqueScript in tanques:
		if t.volumen_bbl <= 0.0:
			continue
		disolver_cal(t.lodo, dt_h)
		hidratar_bentonita(t, dt_h)
		asentar(t, dt_h)
	homogenizar_activo(tanques, dt_min, caudal_gpm, volumen_pozo_bbl)


# ======================= Cinética =======================

## Cal en exceso que pasa a solución: 2 OH⁻ y 1 Ca²⁺ por mmol, igual que
## EstadoLodo.agregar_cal, pero de a poco.
static func disolver_cal(lodo: EstadoLodoScript, dt_h: float) -> void:
	if lodo.cal_exceso <= 0.0 or lodo.oh >= EstadoLodoScript.OH_MAX_CAL_MG_L:
		return
	var fw: float = lodo.fw()
	var mmol_disponible: float = lodo.cal_exceso * EstadoLodoScript.MMOL_CAL_POR_LB_BBL / fw
	var mmol_espacio: float = (EstadoLodoScript.OH_MAX_CAL_MG_L - lodo.oh) \
		/ (2.0 * EstadoLodoScript.MG_POR_MEQ_OH)
	var disuelto := minf(mmol_disponible * (1.0 - exp(-dt_h / TAU_DISOLUCION_CAL_H)), mmol_espacio)
	lodo.oh += disuelto * 2.0 * EstadoLodoScript.MG_POR_MEQ_OH
	lodo.ca += disuelto * EstadoLodoScript.MG_POR_MMOL_CA
	lodo.cal_exceso = maxf(0.0, lodo.cal_exceso - disuelto * fw / EstadoLodoScript.MMOL_CAL_POR_LB_BBL)
	# El OH⁻ nuevo puede reaccionar (Mg²⁺ → Mg(OH)₂, HCO₃⁻ → CO₃²⁻, Ca²⁺ + CO₃²⁻).
	lodo._equilibrar()


## 1 en agua dulce y blanda; baja con cloruros y calcio altos (§8).
static func factor_hidratacion(lodo: EstadoLodoScript) -> float:
	var por_cl := 1.0 - clampf((lodo.cl - CL_HIDRATA_PLENO) / (CL_NO_HIDRATA - CL_HIDRATA_PLENO), 0.0, 1.0)
	var por_ca := 1.0 - clampf((lodo.ca - CA_HIDRATA_PLENO) / (CA_NO_HIDRATA - CA_HIDRATA_PLENO), 0.0, 1.0)
	return minf(por_cl, por_ca)


## Lote sin hidratar de edad efectiva E: rinde Δt_ef / (T − E) de lo que queda,
## que es una rampa lineal de 0 a 100 % en T. Con agua salada o dura la edad
## avanza más lento (Δt_ef = Δt × factor).
static func hidratar_bentonita(t: TanqueScript, dt_h: float) -> void:
	if t.bentonita_sin_hidratar <= 0.0:
		return
	var dt_ef := dt_h * factor_hidratacion(t.lodo)
	if dt_ef <= 0.0:
		return
	var falta := TIEMPO_HIDRATACION_H - t.edad_bentonita_h
	var fraccion := 1.0 if dt_ef >= falta else dt_ef / falta
	var rinde: float = t.bentonita_sin_hidratar * fraccion
	t.lodo.bentonita += rinde
	t.bentonita_sin_hidratar -= rinde
	t.edad_bentonita_h = minf(TIEMPO_HIDRATACION_H, t.edad_bentonita_h + dt_ef)
	if t.bentonita_sin_hidratar < 1e-9:
		t.bentonita_sin_hidratar = 0.0
		t.edad_bentonita_h = 0.0


static func asentar(t: TanqueScript, dt_h: float) -> void:
	if t.agitado:
		t.sedimento *= exp(-dt_h / TAU_RESUSPENSION_H)
		return
	var tau := TAU_ASENTAMIENTO_H * (1.0 + t.lodo.gel_10min() / GEL_QUE_DUPLICA_TAU)
	t.sedimento += (1.0 - t.sedimento) * (1.0 - exp(-dt_h / tau))


# ======================= Homogenización =======================

## Ciclo completo = (volumen del pozo + volumen activo) / caudal
## (simulation-logic.md §2). Devuelve INF si no se circula.
static func ciclo_completo_min(tanques: Array, caudal_gpm: float, volumen_pozo_bbl: float) -> float:
	if caudal_gpm <= 0.0:
		return INF
	return F.minutos_para_volumen(volumen_pozo_bbl + volumen_activo_bbl(tanques), caudal_gpm)


static func volumen_activo_bbl(tanques: Array) -> float:
	var total := 0.0
	for t in tanques:
		if t.en_sistema_activo:
			total += t.volumen_bbl
	return total


## Cada tanque activo se acerca a la media del activo en 1 − e^(−Δt/ciclo)
## (rig-tank-system.md §4 regla 2). Equivale a cambiar esa fracción de su lodo
## por lodo medio, así la masa de cada componente se conserva.
## La reserva y los demás tanques fuera del activo no se tocan (§4 regla 3).
## Simplificación 🧩: el lodo del pozo no se guarda aparte; solo alarga el ciclo.
static func homogenizar_activo(tanques: Array, dt_min: float, caudal_gpm: float, volumen_pozo_bbl: float) -> void:
	var activos: Array = []
	for t in tanques:
		if t.en_sistema_activo and t.volumen_bbl > 0.0:
			activos.append(t)
	if activos.size() < 2:
		return
	var ciclo := ciclo_completo_min(tanques, caudal_gpm, volumen_pozo_bbl)
	if is_inf(ciclo):
		return
	var f := 1.0 - exp(-dt_min / ciclo)

	# Media del activo: se mezclan todos los tanques uno tras otro.
	var media := TanqueScript.new()
	media.capacidad_bbl = INF
	for t in activos:
		media.recibir(t, t.volumen_bbl)

	for t in activos:
		t.mezclar_con(media.lodo, media.bentonita_sin_hidratar, media.edad_bentonita_h, f / (1.0 - f))
