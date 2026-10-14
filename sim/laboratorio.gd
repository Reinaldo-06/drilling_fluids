extends RefCounted
## El laboratorio de la caseta de lodos: carga las pruebas (datos) y planifica
## el orden en que el jugador las corre.
##
## Regla del orden (docs/game-design-mechanics.md, "Chequeo de rutina"):
## - el jugador hace una sola cosa a la vez: las partes activas van en serie;
## - las esperas (filtro prensa, retorta, gel de 10 min) corren solas, en
##   paralelo con lo que el jugador haga mientras tanto;
## - una prueba no arranca hasta que terminaron sus requisitos (Pf/Mf,
##   cloruros, dureza y K⁺ esperan el filtrado);
## - un equipo (Fann, filtro prensa, retorta…) sirve a una prueba a la vez,
##   incluida su espera: los geles ocupan el Fann durante los 10 min.

const CARPETA := "res://data/pruebas"


static func cargar(id: String) -> Resource:
	return load("%s/%s.tres" % [CARPETA, id])


## Todas las pruebas de data/pruebas/, por id.
static func cargar_todas() -> Dictionary:
	var todas := {}
	for archivo in DirAccess.get_files_at(CARPETA):
		# En un juego exportado los .tres pueden aparecer como .tres.remap.
		var nombre := archivo.trim_suffix(".remap")
		if nombre.ends_with(".tres"):
			var prueba: Resource = load("%s/%s" % [CARPETA, nombre])
			todas[prueba.id] = prueba
	return todas


## Pruebas que forman un chequeo de rutina: "rapido", "completo" o "diaria".
static func chequeo(tipo: String) -> Array:
	var lista := []
	var todas := cargar_todas()
	var ids := todas.keys()
	ids.sort()
	for id in ids:
		if tipo in todas[id].chequeos:
			lista.append(todas[id])
	return lista


## Planifica las pruebas en el orden más corto que encuentra (voraz: primero
## lo que tiene la espera más larga, para arrancarla cuanto antes).
## "hechas_antes": ids ya terminados (p. ej. un filtrado de hace un rato).
## Devuelve {"total_min", "suma_min", "cronograma": [{id, inicio, fin_activo, fin}]}
## o {"error", "faltan"} si alguna prueba necesita otra que no está en la lista.
static func planificar(pruebas: Array, hechas_antes: Array = []) -> Dictionary:
	var ids_disponibles := hechas_antes.duplicate()
	for p in pruebas:
		ids_disponibles.append(p.id)
	var faltan := PackedStringArray()
	for p in pruebas:
		for req in p.faltantes(ids_disponibles):
			if not req in faltan:
				faltan.append(req)
	if not faltan.is_empty():
		return {"error": "Faltan pruebas requeridas: %s." % ", ".join(faltan), "faltan": faltan}

	var fin_por_id := {}
	for id in hechas_antes:
		fin_por_id[id] = 0
	var equipo_libre := {}
	var pendientes := pruebas.duplicate()
	var cronograma := []
	var t := 0
	var total := 0
	var suma := 0

	while not pendientes.is_empty():
		var elegida: Resource = null
		for p in pendientes:
			if _lista(p, t, fin_por_id, equipo_libre) \
					and (elegida == null or p.minutos_espera > elegida.minutos_espera):
				elegida = p
		if elegida == null:
			# Nada puede arrancar: avanzar hasta que termine algo.
			var proximo := -1
			for fin in fin_por_id.values() + equipo_libre.values():
				if fin > t and (proximo < 0 or fin < proximo):
					proximo = fin
			assert(proximo > t, "Planificación trabada")
			t = proximo
			continue
		var fin_activo: int = t + elegida.minutos_activos
		var fin: int = fin_activo + elegida.minutos_espera
		cronograma.append({"id": elegida.id, "inicio": t, "fin_activo": fin_activo, "fin": fin})
		fin_por_id[elegida.id] = fin
		if elegida.equipo != "":
			equipo_libre[elegida.equipo] = fin
		pendientes.erase(elegida)
		total = maxi(total, fin)
		suma += elegida.minutos_totales()
		t = fin_activo

	return {"total_min": total, "suma_min": suma, "cronograma": cronograma}


static func _lista(p: Resource, t: int, fin_por_id: Dictionary, equipo_libre: Dictionary) -> bool:
	for req in p.requiere:
		if not fin_por_id.has(req) or fin_por_id[req] > t:
			return false
	return equipo_libre.get(p.equipo, 0) <= t
