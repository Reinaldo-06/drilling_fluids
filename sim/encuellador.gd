extends RefCounted
## El encuellador ejecuta las mezclas largas en el embudo por orden del jugador
## (CLAUDE.md; simulation-logic.md §5 y §8).
##
## Cola de mezclas: trabaja una a la vez, en el orden en que se las dieron.
## Avanza con el reloj del turno (paso 3 de §12.2, "acciones en curso"): en
## cada paso vacía los sacos que le da el ritmo, los saca de la bodega y los
## agrega al tanque. Si se acaba el producto, para y avisa. Al terminar avisa.
##
## El producto entra de a poco, saco a saco: el tanque va cambiando durante la
## mezcla, como en el embudo real.

## Encuellador solo (decisión del autor, simulation-logic.md §8). 👷
const RITMO_SACOS_H := 50.0
## Con cuadrilla de piso prestada por el driller (emergencias). 🧩
const RITMO_CUADRILLA_SACOS_H := 250.0

## Mezclas pendientes; la primera es la que está haciendo. Cada una:
## {producto_id, producto, sacos, hechos, tanque, cuadrilla, minuto_orden}
var cola: Array = []
## Mezclas terminadas o interrumpidas (con "estado": "terminada" | "sin_producto").
var historial: Array = []


static func ritmo(cuadrilla: bool) -> float:
	return RITMO_CUADRILLA_SACOS_H if cuadrilla else RITMO_SACOS_H


## Minutos que tarda una mezcla de "sacos" sacos.
static func minutos_mezcla(sacos: float, cuadrilla := false) -> float:
	return sacos / ritmo(cuadrilla) * 60.0


func ocupado() -> bool:
	return not cola.is_empty()


## Agrega una mezcla a la cola y la devuelve.
func ordenar(producto_id: String, producto: Resource, sacos: float, tanque: Resource,
		cuadrilla := false, minuto := 0.0) -> Dictionary:
	var mezcla := {
		"producto_id": producto_id, "producto": producto, "sacos": sacos, "hechos": 0.0,
		"tanque": tanque, "cuadrilla": cuadrilla, "minuto_orden": minuto,
	}
	cola.append(mezcla)
	return mezcla


## Minutos hasta que termine todo lo que tiene en cola.
func minutos_pendientes() -> float:
	var total := 0.0
	for m in cola:
		total += minutos_mezcla(m["sacos"] - m["hechos"], m["cuadrilla"])
	return total


## Trabaja dt_min minutos. Devuelve {"aplicado": [...], "avisos": [...]}:
## aplicado = {producto_id, sacos, tanque, volumen_agregado_bbl, rebalse_bbl}
## avisos   = {tipo: "termine" | "sin_producto", texto, mezcla}
func avanzar(dt_min: float, inventario: RefCounted) -> Dictionary:
	var aplicado: Array = []
	var avisos: Array = []
	var tiempo := dt_min
	while tiempo > 1e-9 and not cola.is_empty():
		var m: Dictionary = cola[0]
		var r := ritmo(m["cuadrilla"])
		var faltan: float = m["sacos"] - m["hechos"]
		var posibles := minf(faltan, r * tiempo / 60.0)
		var sacados: float = inventario.consumir(m["producto_id"], posibles)
		if sacados > 1e-9:
			aplicado.append(_aplicar(m, sacados))
			m["hechos"] += sacados
		tiempo -= sacados / r * 60.0
		if m["sacos"] - m["hechos"] <= 1e-6:
			m["hechos"] = m["sacos"]
			_cerrar(m, "terminada")
			avisos.append({"tipo": "termine", "mezcla": m,
				"texto": "Encuellador: terminé de mezclar %d sacos de %s en %s." % [
					roundi(m["sacos"]), m["producto"].nombre, m["tanque"].nombre]})
		elif sacados < posibles - 1e-9:
			_cerrar(m, "sin_producto")
			avisos.append({"tipo": "sin_producto", "mezcla": m,
				"texto": "Encuellador: se acabó el %s en la bodega. Mezclé %d de %d sacos en %s." % [
					m["producto"].nombre, floori(m["hechos"] + 1e-6), roundi(m["sacos"]), m["tanque"].nombre]})
	return {"aplicado": aplicado, "avisos": avisos}


func _aplicar(m: Dictionary, sacos: float) -> Dictionary:
	var tanque: Resource = m["tanque"]
	var producto: Resource = m["producto"]
	var resultado := {"volumen_agregado_bbl": 0.0, "rebalse_bbl": 0.0}
	if tanque.volumen_bbl > 0.0:
		resultado = tanque.tratar(producto, sacos * producto.lb_por_saco / tanque.volumen_bbl)
	return {
		"producto_id": m["producto_id"], "sacos": sacos, "tanque": tanque,
		"volumen_agregado_bbl": resultado["volumen_agregado_bbl"],
		"rebalse_bbl": resultado["rebalse_bbl"],
	}


func _cerrar(m: Dictionary, estado: String) -> void:
	m["estado"] = estado
	cola.erase(m)
	historial.append(m)
