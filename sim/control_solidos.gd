extends RefCounted
## Control de sólidos del taladro: los equipos encendidos, su estado y lo que
## sacan (simulation-logic.md §6.1, §7 y §12.2 paso 2; rig-tank-system.md §1–§4).
##
## Dos efectos, en el orden del paso de simulación:
## 1. separar_recortes(): en la ENTRADA, los recortes que vuelven del pozo pasan
##    por zarandas → desarenador → deslimador. Lo que no sacan entra al lodo.
##    La "eficiencia de remoción" de §6.1 = removido / generado (API RP 13C).
## 2. procesar(): cada hidrociclón y la centrífuga toman su caudal del tanque y
##    descartan, por pasada, sólidos perforados dispersos, barita y finos de
##    cemento (manual §1.3 punto 6: sacarlos antes de que se disuelvan).
##    Con lodo densificado los hidrociclones botan barita (cerca de la mitad de
##    la que procesa el deslimador, §7) y la densidad baja; la centrífuga la
##    recupera y descarta los livianos.
## Todo descarte resta volumen: sólidos más el lodo que se va pegado.
## Sin escena: se prueba en tests/test_control_solidos.gd.

const EquipoScript := preload("res://sim/equipo_solidos.gd")
const TanqueScript := preload("res://sim/tanque.gd")
const F := preload("res://sim/formulas.gd")

const PASO_MIN := 10.0
const CLASES := ["gruesos", "medios", "finos"]
## Orden del circuito de retorno: ruta 1 por la canal (rig-tank-system.md §1).
const ORDEN := ["zaranda", "desarenador", "deslimador", "centrifuga"]
const RUTAS_ESTANDAR := [
	"res://data/equipos/zaranda.tres",
	"res://data/equipos/desarenador.tres",
	"res://data/equipos/deslimador.tres",
	"res://data/equipos/centrifuga.tres",
]

var equipos: Array = []


## Juego estándar del taladro (los cuatro equipos encendidos y buenos). Cada
## equipo es una copia: cambiar su estado no toca el .tres compartido.
static func crear_estandar() -> RefCounted:
	var c = load("res://sim/control_solidos.gd").new()
	for ruta in RUTAS_ESTANDAR:
		c.agregar(load(ruta))
	return c


func agregar(equipo: Resource) -> Resource:
	var copia: Resource = equipo.duplicate()
	equipos.append(copia)
	equipos.sort_custom(func(a, b): return ORDEN.find(a.tipo) < ORDEN.find(b.tipo))
	return copia


func equipo(tipo: String) -> Resource:
	for e in equipos:
		if e.tipo == tipo:
			return e
	return null


func encender(tipo: String, valor := true) -> void:
	var e := equipo(tipo)
	if e != null:
		e.encendido = valor


func fijar_estado(tipo: String, estado: String) -> void:
	assert(estado in EquipoScript.ESTADOS, "Estado desconocido: %s" % estado)
	var e := equipo(tipo)
	if e != null:
		e.estado = estado


# ======================= Entrada: recortes =======================

## Separa los recortes que llegan del pozo. "clases" = {"gruesos", "medios",
## "finos"} en bbl de sólido. Devuelve {"removido_bbl", "retenido_bbl",
## "lodo_descartado_bbl", "retenido_por_clase"}.
func separar_recortes(clases: Dictionary) -> Dictionary:
	var removido := 0.0
	var lodo_descartado := 0.0
	var restante := {}
	for clase in CLASES:
		restante[clase] = float(clases.get(clase, 0.0))
	for e in equipos:
		var sacado_equipo := 0.0
		for clase in CLASES:
			var sacado: float = restante[clase] * e.eficiencia_entrada(clase)
			restante[clase] -= sacado
			sacado_equipo += sacado
		removido += sacado_equipo
		lodo_descartado += sacado_equipo * e.lodo_por_bbl_solido()
	var retenido := 0.0
	for clase in CLASES:
		retenido += restante[clase]
	return {"removido_bbl": removido, "retenido_bbl": retenido,
		"lodo_descartado_bbl": lodo_descartado, "retenido_por_clase": restante}


## Eficiencia de remoción combinada (removido / generado) para un reparto de
## tamaños dado (§6.1). Con los cuatro equipos buenos ≈ 0,80 en el reparto por
## defecto de la formación (calibración CAIMÁN-3, §6.1 y §12.5). 🧩
func eficiencia_remocion(gruesos := 0.66, medios := 0.22) -> float:
	var r := separar_recortes({"gruesos": gruesos, "medios": medios,
		"finos": maxf(0.0, 1.0 - gruesos - medios)})
	return r["removido_bbl"]


# ======================= Por pasada: lodo del tanque =======================

## Procesa el lodo de un tanque durante "minutos". Devuelve lo descartado:
## {"barita_bbl", "perforados_bbl", "lodo_bbl", "descarte_bbl", "finos_cemento_lb"}.
func procesar(tanque: TanqueScript, minutos: float) -> Dictionary:
	var total := {"barita_bbl": 0.0, "perforados_bbl": 0.0, "lodo_bbl": 0.0,
		"descarte_bbl": 0.0, "finos_cemento_lb": 0.0}
	var restante := minutos
	while restante > 1e-9:
		var dt := minf(PASO_MIN, restante)
		var r := _procesar_paso(tanque, dt)
		for clave in total:
			total[clave] += r[clave]
		restante -= dt
	return total


func _procesar_paso(tanque: TanqueScript, dt_min: float) -> Dictionary:
	var r := {"barita_bbl": 0.0, "perforados_bbl": 0.0, "lodo_bbl": 0.0,
		"descarte_bbl": 0.0, "finos_cemento_lb": 0.0}
	for e in equipos:
		var f: float = e.factor()
		if f <= 0.0 or e.caudal_gpm <= 0.0 or tanque.volumen_bbl <= 0.0:
			continue
		var lodo = tanque.lodo
		var volumen: float = tanque.volumen_bbl
		# Fracción del tanque que pasa por el equipo en este paso.
		var pasada := minf(1.0, e.caudal_gpm / F.GAL_POR_BBL * dt_min / volumen)

		# Finos de cemento: no tienen volumen en el modelo, solo se van.
		var cemento: float = lodo.finos_cemento * pasada * clampf(e.eficiencia_finos_cemento * f, 0.0, 1.0)
		lodo.finos_cemento -= cemento
		r["finos_cemento_lb"] += cemento * volumen

		# Sólidos (bbl) que el equipo intenta sacar en esta pasada.
		var barita: float = lodo.frac_barita * volumen * pasada * clampf(e.eficiencia_barita * f, 0.0, 1.0)
		var perforados: float = lodo.frac_perforados_separables(tanque.bentonita_sin_hidratar) \
			* volumen * pasada * clampf(e.eficiencia_perforados_lodo * f, 0.0, 1.0)
		var solidos := barita + perforados
		if solidos <= 0.0:
			continue
		# Tope del underflow: el cono no descarga más de lo que da su boquilla
		# (y con conos tapados descarga menos).
		if e.descarte_max_bbl_h > 0.0:
			var tope: float = e.descarte_max_bbl_h * f * dt_min / 60.0 * e.solidos_en_descarte
			if solidos > tope:
				barita *= tope / solidos
				perforados *= tope / solidos
				solidos = tope
		_sacar(tanque, "frac_barita", barita)
		_sacar(tanque, "frac_lgs", perforados)
		# El lodo que se va pegado al descarte sale entero: no cambia la composición.
		var lodo_ido := minf(solidos * e.lodo_por_bbl_solido(), tanque.volumen_bbl)
		tanque.volumen_bbl -= lodo_ido
		r["barita_bbl"] += barita
		r["perforados_bbl"] += perforados
		r["lodo_bbl"] += lodo_ido
		r["descarte_bbl"] += solidos + lodo_ido
	return r


## Saca "bbl" de una fase del tanque: el lodo se re-expresa por bbl restante.
func _sacar(tanque: TanqueScript, campo: String, bbl: float) -> void:
	if bbl <= 0.0 or tanque.volumen_bbl <= 0.0:
		return
	var v := bbl / tanque.volumen_bbl
	var sacado: float = tanque.lodo.quitar_solidos(campo, v)
	if sacado <= 0.0:
		return
	tanque.bentonita_sin_hidratar /= 1.0 - sacado
	tanque.volumen_bbl *= 1.0 - sacado
