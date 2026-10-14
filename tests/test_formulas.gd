extends "res://tests/test_case.gd"
## Casos de prueba tomados de los ejemplos de docs/. Si un número cambia aquí,
## tiene que cambiar primero en el documento de origen.

const F := preload("res://sim/formulas.gd")


# mud-engineer-reference.md §2.1 — 1.000 bbl de 14,0 a 16,0 ppg
func test_densificar_ejemplo_manual() -> void:
	verificar_cerca(F.volumen_barita_bbl(1000, 14.0, 16.0), 105.3, 0.05, "volumen de barita")
	verificar(ceili(F.sacos_barita(1000, 14.0, 16.0)) == 1548, "sacos de barita (manual: 1.548)")
	verificar_cerca(1000 + F.aumento_volumen_por_sacos(F.sacos_barita(1000, 14.0, 16.0)), 1105.3, 0.05, "volumen final")
	verificar_cerca(F.barita_lb_por_bbl(14.0, 16.0), 154.7, 0.05, "lb/bbl de barita")


# mud-engineer-reference.md §2.2 — 1.000 bbl de 16,0 a 12,0 ppg
func test_diluir_ejemplo_manual() -> void:
	verificar_cerca(F.agua_dilucion_bbl(1000, 16.0, 12.0), 1094.0, 0.5, "agua de dilución")


# mud-engineer-reference.md §2.3 — 1.000 bbl de 14,0 con lodos de 11,2 y 15,4
func test_mezcla_ejemplo_manual() -> void:
	var liviano := F.volumen_liviano_para_mezcla(1000, 14.0, 11.2, 15.4)
	verificar_cerca(liviano, 333.3, 0.05, "volumen de 11,2 ppg")
	verificar_cerca(1000 - liviano, 666.7, 0.05, "volumen de 15,4 ppg")
	verificar_cerca(F.densidad_mezcla(liviano, 11.2, 1000 - liviano, 15.4), 14.0, 0.001, "densidad resultante")


# mud-engineer-reference.md §2.4 — 1.000 bbl de 8 % a 6 % de sólidos, 12,0 ppg
func test_reducir_solidos_ejemplo_manual() -> void:
	var r := F.reducir_solidos(1000, 8.0, 6.0, 12.0)
	verificar_cerca(r["lechada"], 333.3, 0.05, "volumen de lechada")
	verificar_cerca(r["barita"], 45.7, 0.05, "barita en la lechada")
	verificar_cerca(r["agua"], 287.6, 0.05, "agua en la lechada")
	verificar(roundi(r["sacos"]) == 672, "sacos (manual: 672)")


func test_lgs_porcentaje() -> void:
	verificar_cerca(F.lgs_porcentaje(F.DENSIDAD_AGUA_PPG), 0.0, 0.0001, "agua sola no tiene sólidos")
	verificar_cerca(F.lgs_porcentaje(9.0), 4.90, 0.01, "lodo de 9,0 ppg")


# simulation-logic.md §2 — ejemplo de AAPG
func test_tiempo_de_retorno_ejemplo_aapg() -> void:
	var salida := F.salida_bomba_bbl_por_emb(0.0962)
	verificar_cerca(salida, 0.0914, 0.0001, "salida por embolada")
	var emb := F.emboladas(378.9, salida)
	verificar_cerca(emb, 4146.0, 3.0, "emboladas de retorno")
	verificar_cerca(emb / 98.0, 42.3, 0.1, "minutos a 98 emb/min")


# simulation-logic.md §2 — calibración CAIMÁN-3 superficial
func test_retorno_caiman_superficial() -> void:
	var anular := F.capacidad_anular_bbl_por_ft(17.5, 5.0) * 2000
	verificar_cerca(anular, 546.4, 0.5, "volumen anular")
	verificar_cerca(F.minutos_para_volumen(anular, 600), 38.2, 0.2, "retorno de fondo a 600 gpm")


# simulation-logic.md §6.1 — hueco de 26", 62 ft/h, porosidad 0,25
func test_solidos_generados_ejemplo() -> void:
	verificar_cerca(F.solidos_generados_bbl_h(26.0, 62.0, 0.25), 30.5, 0.1, "sólidos generados")


# domain-research.md §4.1
func test_presion_y_peso_de_matada() -> void:
	verificar_cerca(F.presion_hidrostatica_psi(10.0, 10000), 5200.0, 0.001, "presión hidrostática")
	verificar_cerca(F.peso_de_matada(10.0, 520.0, 10000), 11.0, 0.0001, "peso de matada")
	verificar_cerca(F.ecd(10.0, 260.0, 10000), 10.5, 0.0001, "ECD")


# mud-engineer-reference.md §5
func test_reologia() -> void:
	verificar_cerca(F.vp(45, 28), 17.0, 0.0, "VP")
	verificar_cerca(F.pc(45, 28), 11.0, 0.0, "PC")
	verificar_cerca(F.va(45), 22.5, 0.0, "VA")
	verificar(F.vp_excede_limite(25.0, 12.0) == true, "VP 25 en lodo de 12 ppg excede el límite")
	verificar(F.vp_excede_limite(20.0, 12.0) == false, "VP 20 en lodo de 12 ppg no excede")


# mud-engineer-reference.md §1.2
func test_dosis_y_exceso_de_cal() -> void:
	verificar_cerca(F.exceso_de_cal(5.0, 1.0, 0.9), 1.066, 0.0001, "exceso de cal")
	verificar_cerca(F.dosis_por_ion("calcio_carbonato_de_sodio", 400, 0.9), 0.334, 0.001, "carbonato de sodio para 400 mg/l de Ca")
	verificar_cerca(F.dosis_por_exceso_de_cal("acido_citrico", 1.0), 1.893, 0.0001, "ácido cítrico por lb/bbl de exceso de cal")


# mud-engineer-reference.md §3.1 — píldora de diesel 6,8 ppg en lodo de 10 ppg
func test_columna_pildora_ejemplo_manual() -> void:
	verificar_cerca(F.longitud_columna_pildora_ft(1170, 10.0, 6.8), 7031.0, 1.0, "100 bbl en la sarta")
	verificar_cerca(F.longitud_columna_pildora_ft(185, 10.0, 6.8), 1112.0, 1.0, "primer desplazamiento")
	verificar_cerca(F.longitud_columna_pildora_ft(100, 10.0, 6.8), 601.0, 1.0, "segundo desplazamiento")
	verificar_cerca(F.longitud_columna_pildora_ft(165, 10.0, 6.8), 992.0, 1.0, "posición final")
