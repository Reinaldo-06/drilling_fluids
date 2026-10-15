extends RefCounted
## Resultado estándar de una acción del jugador (docs/plan-desarrollo.md, Paso 2).
##
## Toda acción que pasa por sim/sesion_turno.gd devuelve este diccionario, sea
## cual sea la acción, para que la interfaz tenga un solo formato que mostrar:
##   ok                 false si la acción no se hizo (y entonces minutos = 0)
##   accion             id de la acción ("tratar", "chequeo_rapido"…)
##   minutos            lo que costó, con la caminata ya incluida donde aplique
##   mensaje            qué pasó o por qué no se pudo, en español (feedback explícito)
##   hallazgos          reglas disparadas: [{id, titulo, tipo, explicacion, referencia}]
##   avisos             lo que el turno tiene para mostrar (alarmas, resultados…)
##   detalle            lo que devolvió la acción del turno, sin tocar
##   hora, minutos_restantes, estacion   estado del turno al terminar


static func de(accion: String, r: Dictionary, turno: RefCounted) -> Dictionary:
	var ok := not r.has("error")
	return {
		"ok": ok,
		"accion": accion,
		"minutos": float(r.get("minutos", 0.0)) if ok else 0.0,
		"mensaje": str(r["error"]) if not ok else _resumen(accion, r),
		"hallazgos": r.get("hallazgos", []),
		"avisos": turno.tomar_avisos(),
		"detalle": r,
		"hora": turno.reloj.hora_texto(),
		"minutos_restantes": turno.reloj.restante(),
		"estacion": turno.ubicacion,
	}


## Resultado de una acción que no se pudo hacer, con el porqué.
static func fallo(accion: String, mensaje: String, turno: RefCounted) -> Dictionary:
	return de(accion, {"error": mensaje}, turno)


static func _resumen(accion: String, r: Dictionary) -> String:
	var minutos := float(r.get("minutos", 0.0))
	var partes := PackedStringArray()
	match accion:
		"chequeo_rapido", "chequeo_completo":
			partes.append("%s terminado en %d min." % [
				"Chequeo rápido" if accion == "chequeo_rapido" else "Chequeo completo", roundi(minutos)])
			partes.append_array(_lecturas(r.get("lecturas", {})))
		"correr_prueba":
			if r.has("listo_en"):
				partes.append("Prueba en marcha: el resultado llega a los %d min del turno." % roundi(float(r["listo_en"])))
			else:
				partes.append("Prueba terminada en %d min." % roundi(minutos))
			partes.append_array(_lecturas(r.get("lecturas", {})))
		"tratar":
			partes.append("Echaste %d sacos (%.2f lb/bbl) en %d min; costo USD %.0f." % [
				roundi(float(r.get("cantidad", 0.0))), float(r.get("lb_bbl", 0.0)), roundi(minutos), float(r.get("costo", 0.0))])
		"ordenar_mezcla":
			partes.append("Orden dada. La mezcla toma unos %d min." % roundi(float(r.get("minutos_estimados", 0.0))))
			if str(r.get("aviso", "")) != "":
				partes.append(str(r["aviso"]))
		"transferir":
			partes.append("Pasaste %.0f bbl en %d min." % [float(r.get("movido_bbl", 0.0)), roundi(minutos)])
		_:
			partes.append("Hecho en %d min." % roundi(minutos))
	return "\n".join(partes)


## Las lecturas en una sola línea; la pantalla de laboratorio (Hito 2) les pondrá unidades.
static func _lecturas(lecturas: Dictionary) -> PackedStringArray:
	var l := PackedStringArray()
	for clave: String in lecturas:
		l.append("%s %s" % [clave.replace("_", " "), str(lecturas[clave])])
	return PackedStringArray([" · ".join(l)]) if not l.is_empty() else PackedStringArray()
