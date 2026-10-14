# Plan de desarrollo — Drilling Fluids
**Juego educativo de fluidos de perforación | Godot 4.7.2 | GDScript**

> Documento de planificación basado en `contexto-plan-gpt.md` y en la revisión estática del repositorio `Reinaldo-06/drilling_fluids`.  
> **Estado de referencia:** validar la rama activa y volver a ejecutar las pruebas antes de tomar las cifras de auditoría como estado actual. El contexto menciona 228 pruebas; la revisión documental de `main` indica 234. No se asume que ambas ramas estén sincronizadas.

---

## Referencia técnica (Paso 1, registrada)

| Dato | Valor |
|---|---|
| Rama de trabajo | `claude/archivos-disponibles-fdps0n` |
| `main` | mismo commit que la rama |
| Commit | `8235e75` |
| Godot | 4.7.2.stable.official.ed1daf0bf |
| Pruebas | **234 pasando, 0 fallas** (23 archivos en `tests/`); después de C4, 236 |

Las 228 del contexto eran anteriores a C1 y C2; el estado real es 234.

**Estado de los hallazgos de Hito 0 contra el código:**

| Hallazgo | Estado | Dónde |
|---|---|---|
| C1. Reglas revelan el contaminante | ✅ corregido, con regresiones | `tests/test_turno.gd` |
| C2. Volumen y succión mínima | ✅ corregido, con regresiones | `tests/test_operacion_pozo.gd` |
| C3. Cemento en KCl/PHPA | ⏳ abierto | `docs/auditoria-logica.md` |
| C4. Cemento de zapata como formación | ✅ corregido (supuesto: 80 ft de cemento) | `tests/test_operacion_pozo.gd` |
| I8. Calcio/dureza en el reporte | ✅ corregido (queda la pregunta 7) | `sim/reporte_diario.gd` |

Estado y detalle de cada hallazgo: `docs/auditoria-logica.md`.

---

## 1. Objetivo y criterio de éxito

Construir primero un **día jugable completo en la sección superficial del pozo ficticio CAIMÁN-3** y luego ampliar el juego hasta completar un pozo de tres secciones, incluido el cambio de fluido.

El núcleo jugable debe mantener esta secuencia:

**Alarma → pruebas de diagnóstico → tratamiento → verificación → reporte.**

El juego enseña al jugador a gestionar tanques, diagnosticar propiedades y tratar contaminaciones de lodos base agua. El jugador es ingeniero de fluidos: no opera el BOP, el choke ni las bombas de perforación. Si ocurre un influjo, su responsabilidad es preparar el lodo al peso de matada indicado por el programa.

### Decisiones de diseño que no se deben reabrir

- Vista cenital caminable, inspirada en Pokémon FireRed.
- El tiempo avanza por días de pozo. El jugador trabaja un turno diurno de 12 horas; la noche se simula con base en las recomendaciones del reporte.
- El reporte diario cubre 24 horas.
- Chequeo rápido: densidad, embudo y pH; hasta 10 minutos, varias veces por día.
- Chequeo completo al inicio del turno: balanza, Fann (VP, PC y VA), geles, filtrado API, pH, Pm, Pf/Mf, cloruros y dureza.
- Retorta una vez por día.
- Las mezclas largas en el embudo las hace el encuellador u obrero de patio: 50 sacos/h, o 250 sacos/h con cuadrilla prestada.
- Hay dos embudos de mezcla: tanque de píldoras y zona inferior junto a la bomba centrífuga.
- Dos tanques de reserva, fractanques y sistema activo. El activo se usa en circuito corto durante preparativos.
- Cambio de fluido por desplazamiento directo, sin espaciador.
- Un tratamiento se manifiesta cuando el lodo tratado llega al punto relevante tras una vuelta, calculada según profundidad, caudal y volumen en superficie.
- La densidad se programa por profundidad.
- La filtración depende de la formación; las arenas pueden requerir controlador de filtrado y puenteo.
- El juego explica los fallos con reglas explicativas cargadas como datos.
- Los pozos son ficticios; los programas públicos solo sirven como patrones.
- Las mecánicas se expresan como Resources de Godot más reglas explicativas. Simulación y presentación permanecen separadas.

---

## 2. Hitos de desarrollo

### Hito 0 — Congelar una versión de referencia y cerrar defectos críticos

**Resultado para el jugador:** todavía no añade contenido jugable; deja una base confiable para integrar sin introducir errores silenciosos.

**Tareas**

- **Simulación**
  - [ ] Revisar los arreglos de conservación de volumen, volumen mínimo de succión y diagnóstico sin medición.
  - [ ] Confirmar que ninguna regla de tratamiento revela directamente el contaminante a partir del estado interno.
  - [ ] Corregir el efecto del cemento en KCl/PHPA, incluyendo el efecto de pH alto y calcio sobre PHPA, con una regla cuantitativa documentada.
  - [ ] Corregir el tratamiento del cemento de la zapata: distinguir cemento rotado dentro del revestidor de sólidos generados al perforar una formación.
- **Datos**
  - [ ] Confirmar que contaminantes, productos, pruebas, reglas, eventos y niveles están definidos como Resources o datos equivalentes ya adoptados por el proyecto.
  - [ ] Asegurar que cada regla evaluable incluye una explicación para el jugador.
- **Interfaz/overworld**
  - [ ] Identificar las señales que emite el mapa y quién debe conectarlas.
  - [ ] Definir el contrato de interacción entre overworld, gestor del turno y simulación.
- **Contenido**
  - [ ] Definir el escenario de un día de CAIMÁN-3 con una alarma que se pueda diagnosticar y tratar.
- **Pruebas**
  - [ ] Elegir la rama de referencia y registrar commit.
  - [ ] Ejecutar todas las pruebas y guardar el resultado.
  - [ ] Añadir regresiones para conservación de volumen, succión mínima, diagnóstico y cemento.

**Dependencias:** ninguna; es la base de los hitos siguientes.

**Aceptación verificable**
- La suite automatizada pasa en la rama de referencia.
- Las pruebas demuestran que vaciar/transferir conserva el balance de volumen y no permite operar por debajo del mínimo de succión.
- Una acción de tratamiento no identifica por sí sola el contaminante no medido.
- El escenario inicial usa una regla de cemento coherente con el sistema de lodo elegido.

---

### Hito 1 — Primer día jugable: caminar, interactuar y consumir tiempo

**Resultado para el jugador:** puede recorrer la locación, hablar con personajes, llegar a estaciones e interactuar durante el turno de 12 horas.

**Tareas**

- **Simulación**
  - [ ] Crear o completar un punto de entrada único para acciones del turno: caminar, interactuar, ejecutar prueba, transferir y tratar.
  - [ ] Cada acción valida condiciones, descuenta tiempo una sola vez y devuelve resultado estructurado.
- **Datos**
  - [ ] Definir en datos estaciones, costos de tiempo, distancias o tiempos de caminata, válvulas y conexiones permitidas.
- **Interfaz/overworld**
  - [ ] Conectar señales de movimiento e interacción al gestor del turno.
  - [ ] Mostrar hora/minutos restantes, estación actual y mensajes de resultado.
  - [ ] Bloquear o explicar acciones que no se pueden realizar por distancia, estado de válvula o condiciones del equipo.
- **Contenido**
  - [ ] Incorporar instrucciones iniciales breves y un objetivo del turno.
- **Pruebas**
  - [ ] Probar que caminar consume el tiempo esperado.
  - [ ] Probar que una interacción no descuenta tiempo dos veces.
  - [ ] Probar que al agotarse el turno no se ejecutan acciones incompatibles con el cierre.

**Dependencias:** Hito 0.

**Aceptación verificable**
- Una persona puede iniciar la partida, caminar hasta una estación e interactuar sin usar herramientas de depuración.
- El reloj cambia de manera visible y coincide con el tiempo calculado por la simulación.
- La simulación se puede probar sin cargar la escena visual.

---

### Hito 2 — Laboratorio: alarma, pruebas y diagnóstico justo

**Resultado para el jugador:** detecta una desviación, decide qué pruebas ejecutar y obtiene evidencia suficiente para distinguir causas que se parecen visualmente.

**Tareas**

- **Simulación**
  - [ ] Conectar el planificador de tiempos del laboratorio a las acciones del turno.
  - [ ] Separar observaciones visuales, resultados de instrumentos y estado químico interno.
  - [ ] Aplicar resolución, incertidumbre o límites de cada instrumento según los datos disponibles.
  - [ ] Mantener el acertijo: los síntomas físicos no bastan cuando las causas son indistinguibles; las pruebas químicas aportan discriminación.
- **Datos**
  - [ ] Definir cada prueba con duración, instrumento, rango/resolución, costo y resultados posibles.
  - [ ] Definir las reglas de interpretación y sus explicaciones como datos.
- **Interfaz/overworld**
  - [ ] Construir la pantalla del laboratorio para chequeo rápido, completo y retorta.
  - [ ] Mostrar resultados medidos, unidades de campo y hora de finalización.
  - [ ] Mostrar una alarma sin revelar automáticamente la causa.
- **Contenido**
  - [ ] Crear un caso de práctica con al menos dos causas plausibles y pruebas que permitan diferenciarlas.
- **Pruebas**
  - [ ] Probar que las pruebas consumen el tiempo definido.
  - [ ] Probar que no se muestra información química no medida.
  - [ ] Probar que la combinación de resultados permite diagnosticar el caso.
  - [ ] Probar chequeo rápido, completo y retorta con sus frecuencias y tiempos previstos.

**Dependencias:** Hitos 0 y 1.

**Aceptación verificable**
- El jugador puede recibir una alarma, elegir pruebas y formular un diagnóstico a partir de los resultados.
- Dos estados químicos que produzcan síntomas físicos parecidos no se distinguen antes de ejecutar la prueba discriminante.
- Todas las pantallas usan unidades de campo: ppg, bbl, psi, lb/bbl, lb/100 ft², cP y mg/l según corresponda.

---

### Hito 3 — Tanques, válvulas, mezcla, densificación y dilución

**Resultado para el jugador:** puede mover lodo entre tanques, mezclar productos y ajustar densidad sin romper balances de volumen ni la lógica de succión.

**Tareas**

- **Simulación**
  - [ ] Conectar cada válvula del mapa a una ruta hidráulica de superficie válida.
  - [ ] Implementar y probar transferencias, mezcla, homogenización del activo, hidratación de bentonita y asentamiento.
  - [ ] Aplicar límites de capacidad, caudal, volumen disponible y volumen mínimo de succión.
  - [ ] Implementar densificación y dilución de acuerdo con el programa de profundidad.
  - [ ] Evitar aplicar el efecto de un producto antes de que la mezcla y el tiempo correspondientes se hayan completado.
- **Datos**
  - [ ] Definir conexiones de tanques, capacidad, restricciones, productos, dosis y tiempos.
  - [ ] Registrar el programa de densidad por profundidad para CAIMÁN-3.
- **Interfaz/overworld**
  - [ ] Crear pantalla de tanques con volumen, nivel, estado del lodo y conexiones.
  - [ ] Permitir caminar a válvulas y abrir/cerrar solo las rutas habilitadas.
  - [ ] Crear pantalla de mezcla con producto, dosis, cantidad de sacos y tiempo estimado.
- **Contenido**
  - [ ] Diseñar una tarea de densificación y otra de dilución con criterios de aceptación explícitos.
  - [ ] Representar los dos embudos y las cuadrillas con sus ritmos de mezcla.
- **Pruebas**
  - [ ] Probar conservación de masa/volumen según el modelo definido.
  - [ ] Probar capacidad de tanque, succión mínima, rutas inválidas y válvulas cerradas.
  - [ ] Probar la evolución temporal de la mezcla.
  - [ ] Probar que el jugador no puede saltarse el tiempo de preparación.

**Dependencias:** Hitos 0 y 1; Hito 2 para que los ajustes respondan a un diagnóstico.

**Aceptación verificable**
- El jugador densifica o diluye un tanque y observa cambios coherentes al terminar la mezcla.
- Cada transferencia tiene origen, destino, volumen y efecto de tiempo registrados.
- Los balances de volumen y las restricciones de succión pasan pruebas automatizadas.

---

### Hito 4 — Primer ciclo completo de diagnóstico y tratamiento

**Resultado para el jugador:** completa un día de CAIMÁN-3: detecta un problema, investiga, trata, verifica y entrega el reporte.

**Tareas**

- **Simulación**
  - [ ] Conectar la alarma al estado observable, sin revelar el contaminante oculto.
  - [ ] Ejecutar tratamientos con producto, dosis, mezcla, tiempo de llegada y verificación.
  - [ ] Calcular la vuelta del lodo según profundidad, caudal y volumen de superficie dentro del alcance actual.
  - [ ] Implementar cierre de turno y simulación nocturna a partir del reporte y las recomendaciones.
- **Datos**
  - [ ] Crear el evento inicial como datos: condiciones previas, alarma, causas posibles, reglas, tratamientos válidos y explicaciones.
  - [ ] Definir criterios de éxito y consecuencias de errores recuperables.
- **Interfaz/overworld**
  - [ ] Conectar laboratorio, tanques, diálogo de personajes, reloj y reporte.
  - [ ] Mostrar avisos de éxito/fallo explicando la regla, sin revelar información que el jugador no haya medido.
  - [ ] Crear la pantalla de reporte diario con balance de volumen y recomendaciones nocturnas.
- **Contenido**
  - [ ] Diseñar el guion de un turno de 12 h con objetivos opcionales y una condición de cierre.
  - [ ] Incluir un tratamiento correcto y al menos una opción incorrecta que tenga una explicación didáctica.
- **Pruebas**
  - [ ] Crear prueba de integración desde inicio del turno hasta reporte.
  - [ ] Probar la llegada del tratamiento y la verificación posterior.
  - [ ] Probar que la noche simula 12 h y el reporte cubre 24 h.
  - [ ] Probar que las decisiones erróneas dan retroalimentación comprensible y no alteran el estado de forma imposible.

**Dependencias:** Hitos 1, 2 y 3.

**Aceptación verificable**
- Una partida se puede completar de principio a fin sin consola ni edición manual del estado.
- El jugador puede identificar el problema mediante pruebas, aplicar el tratamiento, confirmar si funcionó y entregar el reporte.
- La partida genera un reporte de 24 h consistente con las acciones del día y la simulación de la noche.

**Esta es la primera versión que conviene considerar una vertical slice jugable.**

---

### Hito 5 — Contaminaciones, pérdidas y eventos de perforación

**Resultado para el jugador:** responde a eventos variados de perforación y contaminación, usando las pruebas y tratamientos apropiados.

**Tareas**

- **Simulación**
  - [ ] Incorporar composición del pozo, retraso de fondo a superficie, interfase de desplazamiento y ubicación de píldoras.
  - [ ] Añadir píldoras y material de pérdida (LCM), con colocación, volumen, llegada y criterios de éxito.
  - [ ] Corregir la entrada de cemento de zapata y modelar cemento rotado dentro del revestidor.
  - [ ] Mejorar la degradación del KCl/PHPA ante cemento, pH alto y calcio con base técnica documentada.
  - [ ] Integrar los eventos ya previstos: pérdidas, influjo, gas, viajes, sag y fallas de equipos, con límites claros para el rol del ingeniero de fluidos.
- **Datos**
  - [ ] Expresar eventos, contaminantes, píldoras, productos y reglas mediante Resources.
  - [ ] Incluir explicaciones y requisitos para cada tratamiento.
- **Interfaz/overworld**
  - [ ] Añadir pantallas o controles para preparar y ubicar píldoras y gestionar el material de pérdida.
  - [ ] Mostrar estados del evento y su progreso sin revelar información no medida.
- **Contenido**
  - [ ] Diseñar escenarios progresivos por formación.
  - [ ] Añadir pérdidas asociadas a formaciones permeables y tratamientos que requieran puenteo cuando aplique.
- **Pruebas**
  - [ ] Probar tiempos de circulación, llegada y desplazamiento.
  - [ ] Probar que una píldora correctamente formulada y colocada puede resolver el escenario definido.
  - [ ] Probar eventos de influjo sin convertir al jugador en operador de bombas o BOP.
  - [ ] Probar que los eventos no se activan en estados incompatibles.

**Dependencias:** Hito 4 y composición del pozo.

**Aceptación verificable**
- Al menos tres escenarios de evento distintos se completan mediante decisiones, pruebas y tratamientos coherentes.
- Las píldoras se transportan y actúan según el modelo de pozo; no funcionan de forma instantánea ni global.
- Un tratamiento de pérdida solo funciona si el material, la colocación y las condiciones del escenario son adecuados.

---

### Hito 6 — Pozo completo de tres secciones y cambio de fluido

**Resultado para el jugador:** completa las tres secciones del pozo ficticio, sigue el programa por profundidad y realiza el cambio de fluido por desplazamiento directo.

**Tareas**

- **Simulación**
  - [ ] Incorporar programas por sección, cambios de formación, objetivos de densidad y restricciones operativas.
  - [ ] Modelar el cambio de fluido por desplazamiento directo, sin espaciador.
  - [ ] Validar el volumen de desplazamiento, la interfase y el criterio de finalización.
  - [ ] Incorporar solo los refinamientos hidráulicos necesarios para respaldar decisiones de fluidos en este alcance.
- **Datos**
  - [ ] Completar los programas ficticios de las tres secciones, productos aprobados y restricciones de cada sistema.
  - [ ] Usar pozos/programas públicos solo como patrones, no como datos reales del pozo ficticio.
- **Interfaz/overworld**
  - [ ] Comunicar cambios de sección, profundidad, programa vigente y progreso del pozo.
  - [ ] Integrar el reporte final y el historial de tratamientos.
- **Contenido**
  - [ ] Crear progresión de dificultad y consecuencias acumulativas.
  - [ ] Verificar continuidad entre secciones y cambio de sistema de lodo.
- **Pruebas**
  - [ ] Ejecutar una partida completa de las tres secciones.
  - [ ] Probar balances de volumen durante el cambio de fluido.
  - [ ] Probar objetivos de densidad por profundidad y criterios de aceptación final.
  - [ ] Realizar pruebas de regresión de todas las mecánicas anteriores.

**Dependencias:** Hitos 0–5.

**Aceptación verificable**
- Una partida completa cubre las tres secciones y respeta los programas de lodo.
- El cambio de fluido se realiza por desplazamiento directo, con balance de volumen e interfase verificables.
- Todas las pruebas de simulación e integración pasan en la versión candidata.

---

## 3. Orden recomendado de trabajo

El orden de ejecución recomendado es:

1. **Congelar rama y pruebas.** Confirmar la rama de trabajo, commit, versión de Godot y número real de pruebas.
2. **Cerrar C1/C2 con regresiones.** No avanzar sobre supuestos acerca de volumen o diagnóstico.
3. **Resolver C3/C4.** Cemento y sistema KCl/PHPA afectan el escenario inicial.
4. **Definir el contrato de integración.** Una única ruta para acciones, costos de tiempo, validación y resultados.
5. **Conectar overworld y turno.** Movimiento, interacción, reloj y válvulas.
6. **Construir laboratorio.** Mostrar mediciones, no variables internas.
7. **Construir pantalla de tanques.** Transferencias, niveles, mezcla, densificación y dilución.
8. **Construir reporte.** Balance de volumen, resumen de 24 h y recomendaciones nocturnas.
9. **Completar el día de CAIMÁN-3.** Prueba de integración de la secuencia completa.
10. **Añadir composición del pozo y transporte.** Resolver C5 antes de píldoras y desplazamientos.
11. **Añadir LCM y eventos progresivos.** Resolver C6 y ampliar escenarios.
12. **Completar las tres secciones y cambio de fluido.** Solo cuando la vertical slice sea estable.

**Regla de trabajo:** no comenzar una mecánica nueva hasta que la anterior tenga criterio de aceptación y pruebas. Si una mecánica altera química, volumen o tiempo, debe tener al menos una prueba automatizada de éxito y otra de condición límite o fallo.

---

## 4. Ubicación de todos los hallazgos de auditoría

### Hallazgos críticos

| Hallazgo | Hito | Justificación |
|---|---:|---|
| C1. Reglas revelan el contaminante sin medir | 0 y regresión continua | Rompe el acertijo central y hace injusto el diagnóstico. |
| C2. Volumen no conservado y falta mínimo de succión | 0 y regresión continua | Rompe la gestión de tanques y permite estados físicamente imposibles. |
| C3. Cemento afecta poco al KCl/PHPA | 0 | El cemento debe causar una consecuencia que pueda investigarse en el escenario inicial. |
| C4. Cemento de zapata como formación perforada | 0 | Causa errores de origen y balance de sólidos. |
| C5. El pozo no tiene composición | 5 | Bloquea el modelado fiable del transporte, llegada de tratamientos e interfases. |
| C6. No hay píldoras ni LCM | 5 | No bloquea el primer caso de diagnóstico, pero sí el aprendizaje de control de pérdidas. |

### Hallazgos importantes

| Hallazgo | Hito sugerido | Motivo |
|---|---:|---|
| Presión de poro y gradiente de fractura por formación; ECD y pérdidas inducidas | 6, o antes si el escenario los necesita | Añadir cuando afecten una decisión concreta de fluidos; validar el modelo antes de enseñar cifras. |
| Saturación de sal y solubilidad del yeso | 5 | Importante para escenarios de contaminación salina y yeso. |
| Gas: aireación/espuma, balanza presurizada y antiespumante | 5 | Requiere escenario, prueba y tratamiento de gas bien definidos. |
| Temperatura y degradación de polímeros | 6 | Puede esperar a que el ciclo principal funcione; adelantar si es clave para el sistema seleccionado. |
| Lodos base para cada sistema | 0–3 | Necesario para que densificación, dilución y tratamiento partan de un estado definido. |
| Filtrado por tanque y por hora | 3–5 | Incorporar cuando las decisiones de filtrado tengan efecto visible en el escenario. |
| Productos faltantes: antiespumante, biocida, LCM, sulfato de sodio y KOH | 5–6 | Añadir según escenarios y reglas que los requieran, no como catálogo aislado. |
| Pruebas faltantes: amina, PHPA, arena, HTHP y prueba piloto | 2–5 | Priorizar solo las pruebas necesarias para diferenciar causas o verificar un tratamiento. |
| Falsa alarma PVT no cuesta tiempo | 1–4 | Corregir cuando se conecten las alarmas y acciones del turno. |
| CaCO₃ no se pierde en equipos de sólidos | 3–5 | Importante para balance de composición y respuesta del control de sólidos. |

### Hallazgos del mapa

| Hallazgo | Hito | Motivo |
|---|---:|---|
| Múltiple de transferencia no conecta con el activo | 3 | Impide transferencias válidas en el sistema activo. |
| Faltan desgasificador, desarenador, deslimador y centrífuga | 3–5 | Añadir equipos según los escenarios de control de sólidos y gas. |
| Falta segunda ruta de retorno (canal y centrífuga) y depósito de recortes | 3–5 | Necesario para representar la ruta de retorno y el destino de los sólidos cuando corresponda. |

Los elementos que la auditoría marque como resueltos deben volver a probarse, pero no deben reimplementarse automáticamente.

---

## 5. Preguntas de campo que debe responder el autor

Estas preguntas no se deben resolver inventando una práctica universal. Se proponen supuestos provisionales para poder avanzar en programación, pero deben sustituirse por decisiones documentadas antes de que el escenario correspondiente se considere técnicamente validado.

| Pregunta | Cuándo responder | Supuesto provisional para desarrollo |
|---|---|---|
| 1. ¿Cómo se comporta la soda sobre los carbonatos? | Hito 0 si afecta reglas existentes; como máximo antes de escenarios de carbonatos (5) | No codificar una regla universal. Crear casos de prueba y dejar la regla parametrizada hasta validar el comportamiento con una referencia técnica o práctica de campo. |
| 2. ¿Cómo se ve el cemento en KCl/PHPA y se pretrata con bicarbonato? | Hito 0 | El cemento activa un escenario de contaminación con resultados observables; no asumir que el bicarbonato es siempre el tratamiento correcto. Validar apariencia, química y tratamiento antes de cerrar el contenido. |
| 3. ¿Cuántos pies de cemento se rotan y cuándo se hace FIT/LOT? | Antes de fijar el guion de la sección superficial (hito 0–4) | Usar profundidad de cemento y punto de prueba como parámetros explícitos del programa ficticio. No afirmar un número universal ni fijar FIT/LOT sin el programa de pozo. |
| 4. ¿Cuál es el volumen mínimo en la succión? | Hito 0 | Usar un parámetro por tanque/sistema, editable en datos, y bloquear transferencias que lo violen. El valor debe venir de la configuración validada del pozo. |
| 5. ¿Cuánto baja la balanza con gas? | Antes del escenario de gas (hito 5) | No usar una reducción fija universal. Modelar la lectura como función configurable de aireación/gas y del método de medición; validar con datos de referencia. |
| 6. ¿Qué píldoras se hacen de rutina? | Antes de implementar píldoras/LCM (hito 5) | Empezar con un catálogo pequeño de píldoras definidas por objetivo, composición, volumen, colocación y tiempo de llegada; no llamarlas “de rutina” hasta validar. |
| 7. ¿El reporte lleva calcio o dureza? | Hito 4 | Mantener campos separados en los datos y permitir configurar el reporte. Confirmar el formato real antes de congelar la plantilla. |
| 8. ¿Con qué se repone el volumen de noche? | Hito 4 | Definir una política nocturna explícita en los datos del pozo, con tipo de fluido, volumen y condiciones; no reponer automáticamente sin registrar balance. |
| 9. ¿Cómo es la logística de camiones y descarte? | Hito 6, o antes si afecta inventario/costos | Usar eventos simplificados de llegada, capacidad, tiempo y descarte autorizado. No modelar normativa o logística real sin confirmar jurisdicción y práctica. |
| 10. ¿En qué orden van los compartimientos de tanques? | Hito 0–3 | Representar el orden como conexiones configurables en datos y validarlo contra el esquema de superficie elegido para CAIMÁN-3. |

**Separación de certeza técnica**

- **Decisión del proyecto:** lo definido en las decisiones cerradas de este documento.
- **Supuesto de prototipo:** parámetros temporales que permiten desarrollar sin afirmar que son universales.
- **Práctica general por validar:** principios que dependen de equipo, programa de lodos, formación y procedimiento del operador.
- **Dato validado de campo:** respuesta confirmada por el autor o por una fuente técnica aplicable, con referencia registrada.

---

## 6. Riesgos principales y mitigación

| Riesgo | Consecuencia | Mitigación |
|---|---|---|
| 1. El jugador descubre el contaminante sin hacer pruebas | Se pierde el núcleo de investigación | Las reglas de presentación solo usan observaciones y resultados medidos; añadir pruebas negativas de filtración de información. |
| 2. La interfaz y la simulación duplican la lógica | Estados divergentes y errores difíciles de reproducir | Simulación como fuente de verdad; interfaz como presentación y entrada de acciones; pruebas sin escena visual. |
| 3. Se añaden demasiadas mecánicas antes de cerrar el primer día | Proyecto amplio pero nunca jugable | Congelar alcance de la vertical slice; aceptar nuevas funciones solo si son necesarias para completar su ciclo. |
| 4. El realismo se codifica con valores universales que no aplican al pozo | Enseñanza incorrecta y pérdida de confianza | Parametrizar valores por programa/formación/sistema; documentar la fuente y pedir validación de campo cuando corresponda. |
| 5. El estado de las ramas y la auditoría diverge | Se corrigen problemas ya resueltos o se omiten regresiones | Registrar rama y commit; ejecutar la suite desde una instalación limpia; actualizar auditoría junto con cada corrección. |

---

## 7. Qué NO hacer todavía

- No construir circulación hidráulica detallada completa; queda para una expansión posterior.
- No convertir al jugador en operador del BOP, choke o bombas.
- No cambiar la vista cenital por una experiencia de conducción o simulación en primera persona.
- No cambiar las unidades de campo a métricas.
- No añadir decenas de contaminantes, productos o pruebas sin un escenario que los necesite.
- No añadir modelos avanzados de ECD, temperatura, solubilidad o degradación antes de definir qué decisión de juego respaldan.
- No construir un sistema de misiones complejo, árbol de habilidades, economía extensa o progresión cosmética antes de terminar el primer día.
- No hacer que las reglas lean el estado químico oculto para mostrar mensajes diagnósticos.
- No introducir valores de campo “típicos” sin marcar su origen y alcance.
- No refactorizar toda la arquitectura si basta con añadir contratos claros entre el mapa, el turno y la simulación.
- No considerar una mecánica terminada solo porque la escena se vea bien: debe pasar sus pruebas y tener un criterio de aceptación verificable.

---

## 8. Plan de trabajo para esta semana

### Paso 1 — Establecer la referencia técnica

- [ ] Confirmar rama y commit que se usarán.
- [ ] Ejecutar Godot y toda la suite automatizada.
- [ ] Registrar versión de Godot, cantidad de pruebas y resultado.
- [ ] Comparar la auditoría con el estado real del código; marcar cada hallazgo como abierto, corregido o pendiente de validación.

**Entregable:** una referencia reproducible del proyecto.

### Paso 2 — Diseñar y probar el contrato de integración

- [ ] Dibujar el flujo overworld → acción del turno → simulación → resultado → interfaz.
- [ ] Enumerar señales actuales del mapa y sus consumidores.
- [ ] Definir el resultado estándar de una acción: éxito/fallo, minutos consumidos, mensaje explicativo y cambios de estado.
- [ ] Añadir pruebas para tiempo de caminata, interacción y ausencia de doble descuento.

**Entregable:** integración mínima con reloj visible y una interacción funcional.

### Paso 3 — Cerrar el primer caso de CAIMÁN-3

- [ ] Elegir una sola alarma y definir las causas plausibles.
- [ ] Elegir las pruebas mínimas que permiten diferenciarlas.
- [ ] Definir un tratamiento, su dosis, el tiempo de preparación y el momento de verificación.
- [ ] Crear la pantalla mínima del laboratorio y el resumen del turno.
- [ ] Automatizar una prueba de integración del flujo completo.

**Entregable:** un caso jugable de diagnóstico y tratamiento, aunque el resto del mapa todavía sea provisional.

---

## 9. Definición de “terminado” para cada tarea

Una tarea no se considera terminada hasta cumplir todo lo aplicable:

1. La mecánica tiene un dato/Resource y una regla explícita con explicación.
2. El comportamiento se puede probar sin la escena visual cuando pertenece a la simulación.
3. Se han probado el caso correcto, una condición límite y un fallo pertinente.
4. La interfaz presenta unidades de campo y no revela datos ocultos.
5. El costo de tiempo y los cambios de volumen/composición quedan registrados.
6. La documentación y la auditoría reflejan el estado real.
7. La prueba de integración que cubre la mecánica pasa.

## 10. Criterio para declarar la primera versión jugable

La vertical slice de CAIMÁN-3 está lista cuando un jugador puede, sin ayuda de depuración:

- iniciar el turno;
- caminar e interactuar con estaciones;
- ejecutar el chequeo correspondiente;
- recibir una alarma sin conocer automáticamente su causa;
- elegir pruebas y leer sus resultados;
- seleccionar y preparar un tratamiento;
- respetar tiempos de mezcla y llegada;
- verificar el resultado;
- cerrar el turno y consultar el reporte de 24 horas;
- recibir una explicación útil si toma una decisión equivocada.

Solo después de cumplir este criterio se debe ampliar el contenido hacia píldoras, pérdidas, eventos adicionales, las tres secciones y el cambio de fluido.
