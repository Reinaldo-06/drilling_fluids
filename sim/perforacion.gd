extends RefCounted
## Perforación en el paso de simulación (simulation-logic.md §12.2 paso 1).
##
## Por cada paso de 10 min mientras el driller perfora:
## - Profundidad += ROP × Δt.
## - Consumo de volumen: el hueco nuevo se llena con lodo del activo
##   (Formulas.capacidad_bbl_por_ft; rig-tank-system.md §4 regla 4).
## - Sólidos generados = capacidad × ROP × (1 − porosidad) (§6.1).
## - Parte de la arcilla de una lutita reactiva se dispersa en el anular antes
##   de llegar a superficie: esa parte es coloidal, pasa todos los equipos y
##   entra como arcilla_activa (sube MBT, VP y PC). La inhibición del lodo (K⁺,
##   amina, PHPA, sal) reduce cuánta se dispersa (§13.5).
## - El resto pasa por el control de sólidos (sim/control_solidos.gd); lo que no
##   sacan entra al lodo como sólidos de baja gravedad (frac_lgs) con su volumen.
## - La lutita reactiva consume K⁺ (por intercambio, el Cl⁻ se queda y entra
##   Na⁺), amina y PHPA en proporción a los recortes (§13.1, §13.3, §13.5).
## - La formación con contaminante lo aplica por bbl de roca perforada.
## - El lodo pegado a los recortes descartados se pierde (§10.1).
## - Lutita frágil con densidad bajo su mínimo: derrumbes (reference-wells §2).
## Funciones estáticas y sin escena; pruebas en tests/test_perforacion.gd.

const EstadoLodoScript := preload("res://sim/estado_lodo.gd")
const TanqueScript := preload("res://sim/tanque.gd")
const FormacionScript := preload("res://sim/formacion.gd")
const Cinetica := preload("res://sim/cinetica.gd")
const F := preload("res://sim/formulas.gd")

const PASO_MIN := 10.0

# --- Dispersión e inhibición (🧩 calibración de juego, §13.5) ---
## CIC de referencia de una lutita reactiva típica (meq/100 g); la reactividad
## escala con CIC / CIC_REFERENCIA (tope 1,5).
const CIC_REFERENCIA := 20.0
## CIC de la bentonita comercial: convierte arcilla perforada en lb/bbl
## equivalentes de bentonita (lo que mide el MBT).
const CIC_BENTONITA := 80.0
## Fracción de los recortes de una lutita de referencia (montmorillonita, CIC
## 20) que se dispersa sin ninguna inhibición. 🧩
const DISPERSION_MAXIMA := 0.3
const DISPERSION_POR_TIPO := {"montmorillonita": 1.0, "illita": 0.6, "caolinita": 0.3, "ninguna": 0.0}
## Concentraciones que dan 63 % del efecto de cada inhibidor. KCl 15–35 lb/bbl
## (reference-wells §2) ≈ 20.000–45.000 mg/l de K⁺; amina 2–12 lb/bbl; PHPA
## 0,5–2 lb/bbl (§13.2). 🧩
const K_REFERENCIA_MG_L := 15000.0
const AMINA_REFERENCIA_LB := 3.0
const PHPA_REFERENCIA_LB := 1.0
## Peso de cada inhibidor (la amina es la más fuerte, §13.2; el PHPA es secundario).
const PESO_K := 0.7
const PESO_AMINA := 0.85
const PESO_PHPA := 0.5
## Sal: baja la actividad del agua. Tope de efecto con agua saturada. 🧩
const PESO_SAL := 0.3
const CL_SATURADO := 190000.0
## KCl en caolinita: la debilita (§13.1). Cuánto sube la dispersión. 🧩
const EMPEORA_K_CAOLINITA := 0.3

# --- Consumo por bbl de recorte de lutita de referencia (🧩) ---
## Fracción de los sitios de intercambio del recorte que alcanza el K⁺ en el viaje.
const CIC_ACCESIBLE := 0.3
const AMINA_LB_POR_BBL_RECORTE := 2.0
const PHPA_LB_POR_BBL_RECORTE := 1.5

## Pérdidas por filtración en formaciones permeables (simulation-logic.md §10.1):
## la tasa base de la formación escala con (filtrado API / referencia)² 🧩 —un
## revoque más delgado y menos permeable deja pasar menos— y baja con el
## carbonato de calcio que puentea las gargantas porales 🧩.
const FILTRADO_REFERENCIA_ML := 8.0
const EXPONENTE_FILTRADO := 2.0
const CACO3_REFERENCIA_LB := 10.0
const PUENTEO_MAXIMO := 0.8

## Derrumbes: bbl de roca extra por bbl generado, por cada ppg bajo el mínimo (tope 2 ppg). 🧩
const DERRUMBES_POR_PPG := 0.3


## Perfora "minutos" con lodo del tanque activo. "control" es un ControlSolidos
## (sim/control_solidos.gd) o null (sin equipos: todo lo generado entra al lodo).
## Devuelve totales: {"profundidad_ft", "pies", "hueco_bbl", "generados_bbl",
## "dispersos_bbl", "removidos_bbl", "retenidos_bbl", "lodo_en_recortes_bbl",
## "derrumbes_bbl", "arcilla_activa_lb_bbl", "k_consumido_mg_l",
## "amina_consumida_lb_bbl", "phpa_consumido_lb_bbl", "volumen_faltante_bbl",
## "inhibicion", "eficiencia"}.
static func avanzar_perforacion(tanque_activo: TanqueScript, formacion: FormacionScript,
		rop_ft_h: float, diametro_pulg: float, minutos: float, control: RefCounted = null,
		profundidad_ft := 0.0) -> Dictionary:
	var total := _resultado_vacio()
	total["profundidad_ft"] = profundidad_ft
	var restante := minutos
	while restante > 1e-9:
		var dt := minf(PASO_MIN, restante)
		var r := paso(tanque_activo, formacion, rop_ft_h, diametro_pulg, dt, control)
		for clave in r:
			if clave in ["inhibicion"]:
				total[clave] = r[clave]
			else:
				total[clave] += r[clave]
		restante -= dt
	total["profundidad_ft"] += total["pies"]
	total["eficiencia"] = total["removidos_bbl"] / total["generados_bbl"] if total["generados_bbl"] > 0.0 else 0.0
	return total


## Paso completo de §12.2 sobre una lista de tanques: perforación en el tanque
## activo que recibe el retorno, control de sólidos sobre ese tanque y cinética
## y homogenización (sim/cinetica.gd). El volumen del pozo crece con el hueco.
## Devuelve el resultado de avanzar_perforacion más "procesado" (de procesar).
static func avanzar_con_tiempo(tanques: Array, tanque_activo: TanqueScript, formacion: FormacionScript,
		rop_ft_h: float, diametro_pulg: float, minutos: float, control: RefCounted,
		caudal_gpm: float, profundidad_ft: float, volumen_pozo_bbl: float) -> Dictionary:
	var total := _resultado_vacio()
	total["profundidad_ft"] = profundidad_ft
	var procesado := {}
	var pozo := volumen_pozo_bbl
	var restante := minutos
	while restante > 1e-9:
		var dt := minf(PASO_MIN, restante)
		var r := paso(tanque_activo, formacion, rop_ft_h, diametro_pulg, dt, control)
		for clave in r:
			if clave == "inhibicion":
				total[clave] = r[clave]
			else:
				total[clave] += r[clave]
		pozo += r["hueco_bbl"]
		if control != null:
			var p: Dictionary = control.procesar(tanque_activo, dt)
			for clave in p:
				procesado[clave] = procesado.get(clave, 0.0) + p[clave]
		Cinetica.paso(tanques, dt, caudal_gpm, pozo)
		restante -= dt
	total["profundidad_ft"] += total["pies"]
	total["eficiencia"] = total["removidos_bbl"] / total["generados_bbl"] if total["generados_bbl"] > 0.0 else 0.0
	total["volumen_pozo_bbl"] = pozo
	total["procesado"] = procesado
	return total


## Un paso de perforación (dt ≤ 10 min recomendado). Ver avanzar_perforacion.
## "activos": tanques del sistema activo que comparten el llenado del hueco
## (por omisión, solo "t"). Si no alcanza el lodo para llenar el hueco nuevo, no
## se perfora (auditoría C2): "volumen_faltante_bbl" dice cuánto faltó.
static func paso(t: TanqueScript, formacion: FormacionScript, rop_ft_h: float,
		diametro_pulg: float, dt_min: float, control: RefCounted, activos: Array = []) -> Dictionary:
	var r := _resultado_vacio()
	if rop_ft_h <= 0.0 or dt_min <= 0.0:
		return r
	var lodo: EstadoLodoScript = t.lodo
	var pies := rop_ft_h * dt_min / 60.0
	var hueco := F.capacidad_bbl_por_ft(diametro_pulg) * pies
	var generados := hueco * (1.0 - formacion.porosidad)   # §6.1
	r["pies"] = pies
	r["hueco_bbl"] = hueco
	r["generados_bbl"] = generados

	# Derrumbes de lutita frágil: roca extra, gruesa, sin química (reference-wells §2).
	var derrumbes := 0.0
	if formacion.fragil_mecanicamente and lodo.densidad() < formacion.densidad_minima_estable_ppg:
		var deficit := minf(2.0, formacion.densidad_minima_estable_ppg - lodo.densidad())
		derrumbes = generados * DERRUMBES_POR_PPG * deficit
	r["derrumbes_bbl"] = derrumbes

	# Inhibición con el lodo como llega al fondo (antes de consumir).
	var inhib := inhibicion(lodo, formacion)
	r["inhibicion"] = inhib
	var dispersos := generados * fraccion_dispersa(formacion, inhib)
	r["dispersos_bbl"] = dispersos

	# 1. El hueco nuevo se llena con lodo del activo, repartido entre sus tanques
	# según el volumen de cada uno (están comunicados por las igualadoras).
	var tanques: Array = activos if not activos.is_empty() else [t]
	var disponible := 0.0
	for x in tanques:
		disponible += x.volumen_bbl
	if disponible - hueco <= 0.0:
		var vacio := _resultado_vacio()
		vacio["volumen_faltante_bbl"] = hueco - disponible
		return vacio
	for x in tanques:
		x.volumen_bbl -= hueco * x.volumen_bbl / disponible
	if t.volumen_bbl <= 0.0:
		return r
	var volumen_al_llegar := t.volumen_bbl

	# 2. Consumo de inhibidores por los recortes (todos los generados viajan en el lodo).
	_consumir_inhibidores(lodo, formacion, generados, volumen_al_llegar, r)

	# 3. Contaminante de la formación, por bbl de roca perforada.
	if formacion.contaminante != "" and formacion.contaminante_por_bbl_roca > 0.0:
		var c: Resource = load("res://data/contaminantes/%s.tres" % formacion.contaminante)
		assert(c != null, "Contaminante desconocido: %s" % formacion.contaminante)
		c.aplicar(lodo, formacion.contaminante_por_bbl_roca * generados / volumen_al_llegar)

	# 4. Recortes no dispersos (más derrumbes, gruesos) por el control de sólidos.
	var no_dispersos := generados - dispersos
	var clases := {
		"gruesos": no_dispersos * formacion.fraccion_gruesos + derrumbes,
		"medios": no_dispersos * formacion.fraccion_medios,
		"finos": no_dispersos * formacion.fraccion_finos(),
	}
	var removidos := 0.0
	var lodo_en_recortes := 0.0
	var retenidos := no_dispersos + derrumbes
	if control != null:
		var s: Dictionary = control.separar_recortes(clases)
		removidos = s["removido_bbl"]
		retenidos = s["retenido_bbl"]
		lodo_en_recortes = s["lodo_descartado_bbl"]
	r["removidos_bbl"] = removidos

	# 5. Lo que entra al lodo: retenidos + dispersos, con su volumen.
	var entra := retenidos + dispersos
	r["retenidos_bbl"] = entra
	var v := entra / t.volumen_bbl
	lodo.agregar_solidos_con_volumen(v)
	t.bentonita_sin_hidratar /= 1.0 + v
	t.volumen_bbl += entra
	var arcilla := dispersos * EstadoLodoScript.LB_LGS_POR_BBL \
		* formacion.cic_meq_100g / CIC_BENTONITA / t.volumen_bbl
	lodo.arcilla_activa += arcilla
	r["arcilla_activa_lb_bbl"] = arcilla

	# 6. El lodo pegado a los recortes descartados se va (§10.1).
	lodo_en_recortes = minf(lodo_en_recortes, t.volumen_bbl)
	t.volumen_bbl -= lodo_en_recortes
	r["lodo_en_recortes_bbl"] = lodo_en_recortes
	return r


## Inhibición del lodo frente a la arcilla de la formación: 0 = nada, 1 = toda.
## Puede ser negativa (KCl en caolinita la empeora, §13.1). 🧩
static func inhibicion(lodo: EstadoLodoScript, formacion: FormacionScript) -> float:
	var i_k := 1.0 - exp(-lodo.k / K_REFERENCIA_MG_L)
	var i_amina := 1.0 - exp(-lodo.amina / AMINA_REFERENCIA_LB)
	var i_phpa := 1.0 - exp(-lodo.phpa / PHPA_REFERENCIA_LB)
	var i_sal := PESO_SAL * clampf(lodo.cl / CL_SATURADO, 0.0, 1.0)
	var queda := (1.0 - PESO_AMINA * i_amina) * (1.0 - PESO_PHPA * i_phpa) * (1.0 - i_sal)
	if formacion.tipo_arcilla == "caolinita":
		queda *= 1.0 + EMPEORA_K_CAOLINITA * i_k
	elif formacion.tipo_arcilla != "ninguna":
		queda *= 1.0 - PESO_K * i_k
	return 1.0 - queda


## Fracción de los recortes que se dispersa (coloidal) con una inhibición dada.
static func fraccion_dispersa(formacion: FormacionScript, inhib: float) -> float:
	var reactividad := clampf(formacion.cic_meq_100g / CIC_REFERENCIA, 0.0, 1.5)
	var tipo: float = DISPERSION_POR_TIPO.get(formacion.tipo_arcilla, 0.0)
	return clampf(DISPERSION_MAXIMA * reactividad * tipo * (1.0 - inhib), 0.0, 0.6)


## K⁺ por intercambio (entra Na⁺, el Cl⁻ se queda), amina y PHPA, en proporción
## a los bbl de recorte y a la reactividad de la formación (§13.5).
static func _consumir_inhibidores(lodo: EstadoLodoScript, formacion: FormacionScript,
		recortes_bbl: float, volumen_bbl: float, r: Dictionary) -> void:
	if formacion.cic_meq_100g <= 0.0 or recortes_bbl <= 0.0:
		return
	var reactividad := clampf(formacion.cic_meq_100g / CIC_REFERENCIA, 0.0, 1.5)
	# meq de intercambio alcanzables: lb × 453,6 g × CIC/100 × fracción accesible.
	var meq := recortes_bbl * EstadoLodoScript.LB_LGS_POR_BBL * 453.592 \
		* formacion.cic_meq_100g / 100.0 * CIC_ACCESIBLE
	var litros_filtrado := volumen_bbl * 158.987 * lodo.fw()
	var k_mmol_l := minf(meq / litros_filtrado, lodo.k / EstadoLodoScript.MG_POR_MMOL_ION["k"])
	if k_mmol_l > 0.0:
		lodo.k -= k_mmol_l * EstadoLodoScript.MG_POR_MMOL_ION["k"]
		lodo.na += k_mmol_l * EstadoLodoScript.MG_POR_MMOL_ION["na"]
		r["k_consumido_mg_l"] += k_mmol_l * EstadoLodoScript.MG_POR_MMOL_ION["k"]
	var amina := minf(lodo.amina, AMINA_LB_POR_BBL_RECORTE * reactividad * recortes_bbl / volumen_bbl)
	lodo.amina -= amina
	r["amina_consumida_lb_bbl"] += amina
	var phpa := minf(lodo.phpa, PHPA_LB_POR_BBL_RECORTE * reactividad * recortes_bbl / volumen_bbl)
	lodo.phpa -= phpa
	r["phpa_consumido_lb_bbl"] += phpa


## La formación del nivel a una profundidad (la primera que la contiene).
## bbl/h que el lodo pierde hacia la formación mientras se la perfora.
static func tasa_filtracion(lodo: EstadoLodoScript, formacion: FormacionScript) -> float:
	if formacion == null or formacion.perdida_filtracion_bbl_h <= 0.0:
		return 0.0
	var relativo := clampf(lodo.filtrado_api() / FILTRADO_REFERENCIA_ML, 0.2, 3.0)
	var caco3_lb := lodo.frac_caco3 * EstadoLodoScript.DENSIDAD_CACO3_PPG * F.GAL_POR_BBL
	var puenteo := PUENTEO_MAXIMO * (1.0 - exp(-caco3_lb / CACO3_REFERENCIA_LB))
	return formacion.perdida_filtracion_bbl_h * pow(relativo, EXPONENTE_FILTRADO) * (1.0 - puenteo)


static func formacion_en(formaciones: Array, profundidad_ft: float) -> FormacionScript:
	for f in formaciones:
		if f.contiene(profundidad_ft):
			return f
	return null


static func _resultado_vacio() -> Dictionary:
	return {"profundidad_ft": 0.0, "pies": 0.0, "hueco_bbl": 0.0, "generados_bbl": 0.0,
		"dispersos_bbl": 0.0, "removidos_bbl": 0.0, "retenidos_bbl": 0.0,
		"lodo_en_recortes_bbl": 0.0, "derrumbes_bbl": 0.0, "arcilla_activa_lb_bbl": 0.0,
		"k_consumido_mg_l": 0.0, "amina_consumida_lb_bbl": 0.0, "phpa_consumido_lb_bbl": 0.0,
		"volumen_faltante_bbl": 0.0, "inhibicion": 0.0, "eficiencia": 0.0}
