class_name MonitorTanques
extends Resource
## Totalizador de volumen de tanques (PVT), simulation-logic.md §4 y §12.2 paso 7.
##
## Compara el volumen del activo contra el que espera: el de la última
## referencia más los cambios que alguien le avisó al driller. Lo que no cuadra
## por más del umbral dispara una alarma de ganancia (posible influjo) o de
## pérdida (posible pérdida de circulación).
##
## El PVT no sabe de dónde viene la diferencia. El monitor sí lleva la cuenta
## de las transferencias que el jugador hizo SIN avisar, para poder distinguir:
##   falsa      la diferencia se explica entera por esas transferencias.
##   verdadera  queda una diferencia que no movió nadie en superficie: el pozo
##              tomó o devolvió lodo (eventos de sim/guion_ejecucion.gd).
## Los textos del aviso y del debrief son datos (invariante 4): los trae
## data/eventos/monitor_pvt.tres.

## Diferencia que dispara la alarma (bbl). 🧩 Los PVT se configuran con umbrales
## de unos pocos bbl a decenas, según el taladro; 10 bbl es un valor típico de
## juego y el mismo orden que el corte de la filtración por hora (§10.1).
@export var umbral_bbl := 10.0
## Tiempo que pierde la cuadrilla con una falsa alarma: parar, revisar flujo,
## buscar la causa. 🧩
@export var minutos_perdidos_falsa_alarma := 20.0
## Quién le avisa al jugador cuando suena el PVT.
@export_enum("driller", "mud_logger", "company_man", "encuellador", "nadie") var quien_avisa := "driller"

@export_multiline var aviso_ganancia := ""
@export_multiline var aviso_perdida := ""
@export_multiline var explicacion_falsa_ganancia := ""
@export_multiline var explicacion_falsa_perdida := ""
@export_multiline var explicacion_ganancia := ""
@export_multiline var explicacion_perdida := ""
## Hubo una transferencia sin avisar Y además el pozo tomó o devolvió lodo.
@export_multiline var explicacion_mixta := ""
@export var referencia := "simulation-logic.md §4"

## Volumen que el PVT espera en el activo (bbl).
var esperado_bbl := 0.0
## Neto que entró al activo por transferencias sin avisar desde la referencia.
var sin_aviso_bbl := 0.0
## Ya se dio la alarma por la diferencia actual (no se repite hasta reconocer).
var alarma_activa := false


## Toma el volumen actual como referencia (al empezar o después de una alarma).
func referenciar(tanques: Array) -> void:
	esperado_bbl = volumen_activo(tanques)
	sin_aviso_bbl = 0.0
	alarma_activa = false


## El driller sabe que el activo cambia en "bbl" (+ entra, − sale): transferencia
## avisada, mezcla de barita o agua, hueco nuevo que se llena…
func cambio_avisado(bbl: float) -> void:
	esperado_bbl += bbl


## Registra una transferencia que cambia el activo en "bbl_al_activo" (+ desde
## la reserva hacia el activo, − del activo hacia afuera). Una transferencia
## entre dos tanques del activo no cambia el total: no hace falta registrarla.
func transferencia(bbl_al_activo: float, avisada: bool) -> void:
	if avisada:
		esperado_bbl += bbl_al_activo
	else:
		sin_aviso_bbl += bbl_al_activo


## Lectura del PVT. Devuelve:
##   alarma        bool: la diferencia pasa el umbral
##   nueva         bool: es la primera lectura con esta alarma (para avisar una vez)
##   tipo          "ganancia", "perdida" o ""
##   diferencia_bbl     real − esperado
##   sin_explicar_bbl   lo que no explican las transferencias sin avisar (= el pozo)
##   falsa         bool: alarma causada solo por transferencias sin avisar
##   quien_avisa, aviso, explicacion, referencia
##   minutos_perdidos   tiempo de la cuadrilla (solo en falsas alarmas)
func leer(tanques: Array) -> Dictionary:
	var real := volumen_activo(tanques)
	var diferencia := real - esperado_bbl
	var del_pozo := diferencia - sin_aviso_bbl
	var r := {
		"alarma": false, "nueva": false, "tipo": "", "diferencia_bbl": diferencia,
		"sin_explicar_bbl": del_pozo, "falsa": false, "quien_avisa": quien_avisa,
		"aviso": "", "explicacion": "", "referencia": referencia, "minutos_perdidos": 0.0,
	}
	if absf(diferencia) <= umbral_bbl:
		return r
	r["alarma"] = true
	r["nueva"] = not alarma_activa
	alarma_activa = true
	var ganancia := diferencia > 0.0
	r["tipo"] = "ganancia" if ganancia else "perdida"
	r["aviso"] = (aviso_ganancia if ganancia else aviso_perdida) \
		.replace("{bbl}", str(int(roundf(absf(diferencia)))))
	if absf(del_pozo) <= umbral_bbl:
		r["falsa"] = true
		r["explicacion"] = explicacion_falsa_ganancia if ganancia else explicacion_falsa_perdida
		r["minutos_perdidos"] = minutos_perdidos_falsa_alarma
	elif absf(sin_aviso_bbl) > 1e-6:
		r["explicacion"] = explicacion_mixta
	else:
		r["explicacion"] = explicacion_ganancia if ganancia else explicacion_perdida
	return r


## El driller reconoce la alarma: el volumen actual pasa a ser la referencia.
func reconocer(tanques: Array) -> void:
	referenciar(tanques)


static func volumen_activo(tanques: Array) -> float:
	var total := 0.0
	for t in tanques:
		if t.en_sistema_activo:
			total += t.volumen_bbl
	return total
