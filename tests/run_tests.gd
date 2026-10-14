extends SceneTree
## Ejecutor de pruebas sin complementos externos.
##
## Uso: godot --headless --script res://tests/run_tests.gd
## Carga cada tests/test_*.gd, corre sus métodos test_* y sale con código 1
## si alguna falla.

const CARPETA := "res://tests"


func _initialize() -> void:
	var total := 0
	var fallas: Array[String] = []

	for archivo in DirAccess.get_files_at(CARPETA):
		if not (archivo.begins_with("test_") and archivo.ends_with(".gd")) or archivo == "test_case.gd":
			continue
		var script: Script = load("%s/%s" % [CARPETA, archivo])
		if script == null or not script.can_instantiate():
			# Un archivo que no compila es una falla, no "0 pruebas".
			total += 1
			fallas.append("%s: no compila o no se puede instanciar" % archivo)
			continue
		var caso: RefCounted = script.new()
		for metodo in caso.get_method_list():
			var nombre: String = metodo["name"]
			if not nombre.begins_with("test_"):
				continue
			total += 1
			caso.prueba_actual = "%s::%s" % [archivo, nombre]
			caso.call(nombre)
		fallas.append_array(caso.fallas)

	for falla in fallas:
		printerr("FALLA  ", falla)
	print("%d pruebas, %d fallas" % [total, fallas.size()])
	quit(1 if fallas.size() > 0 else 0)
