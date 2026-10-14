extends RefCounted
## Reloj de un turno de 12 h (720 min; CLAUDE.md, "Tiempo por turnos").
##
## No sabe nada de la simulación: avanza los minutos que pide una acción en
## pasos de, como mucho, 10 min (simulation-logic.md §12.2) y en cada paso
## llama al Callable que le pasa el turno. Nunca deja pasar del final del turno.

## Duración del turno de día jugado (decisión cerrada).
const DURACION_TURNO_MIN := 720.0
## Igual a Cinetica.PASO_MIN.
const PASO_MIN := 10.0
## 🧩 Hora de reloj a la que empieza el turno de día (para la interfaz).
const HORA_INICIO_DIA := 6

var minuto := 0.0
var duracion := DURACION_TURNO_MIN
var hora_inicio := HORA_INICIO_DIA


func restante() -> float:
	return maxf(0.0, duracion - minuto)


func terminado() -> bool:
	return minuto >= duracion - 1e-6


## ¿Entra una acción de "minutos" en lo que queda del turno?
func cabe(minutos: float) -> bool:
	return minuto + minutos <= duracion + 1e-6


## Avanza hasta "minutos" sin pasar del final. En cada paso llama
## al_paso.call(minuto_inicio_del_paso, dt_min) antes de mover la aguja.
## Devuelve los minutos que realmente avanzó.
func avanzar(minutos: float, al_paso: Callable = Callable()) -> float:
	var objetivo := minf(duracion, minuto + maxf(0.0, minutos))
	var inicio := minuto
	while minuto < objetivo - 1e-9:
		var dt := minf(PASO_MIN, objetivo - minuto)
		if al_paso.is_valid():
			al_paso.call(minuto, dt)
		minuto += dt
	minuto = maxf(minuto, objetivo)
	return minuto - inicio


## "HH:MM" de reloj de pared.
func hora_texto(en_minuto := -1.0) -> String:
	var m := minuto if en_minuto < 0.0 else en_minuto
	var total := int(round(m)) + hora_inicio * 60
	return "%02d:%02d" % [(total / 60) % 24, total % 60]
