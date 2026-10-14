extends RefCounted
## Base de las pruebas. Cada archivo tests/test_*.gd extiende este script y
## define métodos que empiezan con "test_".

var fallas: Array[String] = []
var prueba_actual := ""


func verificar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		fallas.append("%s: %s" % [prueba_actual, mensaje])


func verificar_cerca(obtenido: float, esperado: float, tolerancia: float, mensaje: String) -> void:
	verificar(absf(obtenido - esperado) <= tolerancia,
		"%s — esperado %s ± %s, obtenido %s" % [mensaje, esperado, tolerancia, obtenido])
