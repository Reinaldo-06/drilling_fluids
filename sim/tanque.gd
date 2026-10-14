extends Resource
## Un tanque del taladro: volumen, capacidad y el estado del lodo que contiene.
##
## Modelo de docs/rig-tank-system.md §6: nombre, capacidad, volumen, estado del
## lodo, agitado, en_sistema_activo y rol. Las reglas de mezcla y volumen son las
## de rig-tank-system.md §4 (balance de masas de mud-engineer-reference.md §2).
##
## Lo que el tanque guarda además del EstadoLodo:
## - bentonita_sin_hidratar: bentonita seca agregada que todavía no rinde
##   (simulation-logic.md §8). Su volumen de sólidos ya está en lodo.frac_lgs;
##   la cinética (sim/cinetica_tanques.gd) la va pasando a lodo.bentonita.
## - sedimento: indicador 0–1 de barita y sólidos asentados en un tanque sin
##   agitar (rig-tank-system.md §4 regla 6). Solo es una observación por ahora.

const EstadoLodoScript := preload("res://sim/estado_lodo.gd")
const F := preload("res://sim/formulas.gd")

const ROLES := ["llegada", "trampa", "proceso", "succion", "reserva", "fractanque", "pildora"]

## Campos del estado que están en mg/l (o ml de ácido por ml) de FILTRADO: al
## mezclar se ponderan por volumen de agua (volumen × Fw), no por volumen de lodo.
## Todo lo demás (fracciones de fase, lb/bbl de productos, cal en exceso,
## Mg(OH)₂ precipitado) está "por bbl de lodo" y se pondera por volumen de lodo.
const CAMPOS_POR_AGUA := ["oh", "co3", "hco3", "ca", "mg", "na", "k", "cl", "so4", "sulfuro",
	"alc_org_pf", "alc_org_mf"]

@export var nombre := ""
@export var capacidad_bbl := 0.0
@export var volumen_bbl := 0.0
@export_enum("llegada", "trampa", "proceso", "succion", "reserva", "fractanque", "pildora") var rol := "proceso"
@export var agitado := true
@export var en_sistema_activo := true

var lodo: EstadoLodoScript = EstadoLodoScript.new()
## lb por bbl de lodo de bentonita agregada que aún no hidrata.
var bentonita_sin_hidratar := 0.0
## Edad efectiva (h) del lote sin hidratar; llega a TIEMPO_HIDRATACION_H y rinde todo.
var edad_bentonita_h := 0.0
## 0 = todo en suspensión, 1 = fondo lleno de sólidos asentados.
var sedimento := 0.0


static func crear(nombre_: String, capacidad: float, rol_: String, volumen := 0.0,
		lodo_: EstadoLodoScript = null, activo := true) -> Resource:
	assert(rol_ in ROLES, "Rol desconocido: %s" % rol_)
	var t = load("res://sim/tanque.gd").new()
	t.nombre = nombre_
	t.capacidad_bbl = capacidad
	t.rol = rol_
	t.volumen_bbl = volumen
	t.en_sistema_activo = activo
	t.agitado = rol_ != "trampa"  # la trampa de arena no se agita a propósito (§2)
	if lodo_ != null:
		t.lodo = lodo_
	return t


func espacio_libre_bbl() -> float:
	return maxf(0.0, capacidad_bbl - volumen_bbl)


# ======================= Transferencias =======================

## Mueve lodo de este tanque a "destino" con la bomba de transferencia.
## Mezclar es promediar por volumen (rig-tank-system.md §4 regla 1, §2.3 del manual).
## No rebasa la capacidad del destino ni saca más de lo que hay.
## Devuelve los bbl que realmente se movieron.
func transferir(destino: Resource, bbl: float) -> float:
	var movido := minf(maxf(bbl, 0.0), minf(volumen_bbl, destino.espacio_libre_bbl()))
	if movido <= 0.0:
		return 0.0
	destino.recibir(self, movido)
	volumen_bbl -= movido
	return movido


## Recibe "bbl" del lodo de "origen" y mezcla. No toca el volumen del origen.
func recibir(origen: Resource, bbl: float) -> void:
	if volumen_bbl <= 0.0:
		lodo = origen.lodo.copiar() as EstadoLodoScript
		bentonita_sin_hidratar = origen.bentonita_sin_hidratar
		edad_bentonita_h = origen.edad_bentonita_h
		volumen_bbl = bbl
		return
	mezclar_con(origen.lodo, origen.bentonita_sin_hidratar, origen.edad_bentonita_h,
		bbl / volumen_bbl)
	volumen_bbl += bbl


## Mezcla este tanque con "fraccion" bbl de otro lodo por cada bbl propio.
## La usa tanto la transferencia como la homogenización del activo.
func mezclar_con(otro: EstadoLodoScript, otro_sin_hidratar: float, otra_edad: float,
		fraccion: float) -> void:
	lodo = mezclar(lodo, 1.0, otro, fraccion)
	var masa_propia := bentonita_sin_hidratar
	var masa_otra := otro_sin_hidratar * fraccion
	if masa_propia + masa_otra > 0.0:
		edad_bentonita_h = (masa_propia * edad_bentonita_h + masa_otra * otra_edad) \
			/ (masa_propia + masa_otra)
	bentonita_sin_hidratar = (masa_propia + masa_otra) / (1.0 + fraccion)


## Lodo resultante de mezclar va bbl de "a" con vb bbl de "b" (§2.3 del manual).
## Lo que está por bbl de lodo se pondera por volumen; los iones del filtrado,
## por volumen de agua (ver CAMPOS_POR_AGUA). Así la masa de cada ion se
## conserva y la densidad de la mezcla sale lineal, como en el manual.
## Recorre todas las variables del estado, así un campo nuevo de EstadoLodo
## se mezcla por volumen sin tocar este código.
static func mezclar(a: EstadoLodoScript, va: float, b: EstadoLodoScript, vb: float) -> EstadoLodoScript:
	var r := a.copiar() as EstadoLodoScript
	var total := va + vb
	if total <= 0.0:
		return r
	var agua_a := va * a.fw()
	var agua_b := vb * b.fw()
	for propiedad in a.get_property_list():
		if not (propiedad["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if propiedad["type"] != TYPE_FLOAT:
			continue
		var campo: String = propiedad["name"]
		var xa: float = a.get(campo)
		var xb: float = b.get(campo)
		if campo in CAMPOS_POR_AGUA:
			if agua_a + agua_b > 0.0:
				r.set(campo, (agua_a * xa + agua_b * xb) / (agua_a + agua_b))
		else:
			r.set(campo, (va * xa + vb * xb) / total)
	# Al juntar dos aguas pueden reaccionar (Ca²⁺ de uno con CO₃²⁻ del otro).
	# TODO: pedir a EstadoLodo un método público equilibrar().
	r._equilibrar()
	return r


# ======================= Tratamientos =======================

## Aplica un Producto a "lb_bbl" (lb por bbl de lodo inicial; bbl/bbl si es agua).
## Barita, bentonita y agua suman volumen: el estado queda por bbl de lodo final
## y el tanque crece por (1 + v), como en EstadoLodo.agregar_barita /
## agregar_agua (manual §2.1 y §2.2). Si no cabe, el exceso se rebalsa y se pierde.
## La bentonita entra sin hidratar y rinde con el tiempo (simulation-logic.md §8).
## Devuelve {"sacos", "volumen_agregado_bbl", "rebalse_bbl"}.
func tratar(producto: Resource, lb_bbl: float) -> Dictionary:
	var sacos: float = 0.0 if producto.efecto == "agua" else producto.sacos(volumen_bbl, lb_bbl)
	var v := volumen_agregado_por_bbl(producto.efecto, lb_bbl)
	producto.aplicar(lodo, lb_bbl)
	bentonita_sin_hidratar /= 1.0 + v
	if producto.efecto == "bentonita":
		# agregar_bentonita la sumó como hidratada; se pasa al lote sin hidratar.
		var nueva := lb_bbl / (1.0 + v)
		lodo.bentonita -= nueva
		if bentonita_sin_hidratar + nueva > 0.0:
			edad_bentonita_h *= bentonita_sin_hidratar / (bentonita_sin_hidratar + nueva)
		bentonita_sin_hidratar += nueva
	var agregado := volumen_bbl * v
	volumen_bbl += agregado
	var rebalse := maxf(0.0, volumen_bbl - capacidad_bbl)
	volumen_bbl -= rebalse
	return {"sacos": sacos, "volumen_agregado_bbl": agregado, "rebalse_bbl": rebalse}


## bbl que suma el producto por bbl de lodo inicial. Los químicos disueltos se
## toman sin volumen (unas pocas lb/bbl; error < 1 %).
static func volumen_agregado_por_bbl(efecto: String, cantidad: float) -> float:
	match efecto:
		"barita":
			return cantidad / F.LB_BARITA_POR_BBL                       # 1.470 lb/bbl, §2.1
		"bentonita":
			return cantidad / (F.DENSIDAD_LGS_PPG * F.GAL_POR_BBL)      # SG 2,6
		"agua":
			return cantidad                                             # bbl por bbl, §2.2
	return 0.0
