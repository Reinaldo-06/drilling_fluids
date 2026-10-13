# Diseño del juego: el ingeniero de fluidos

Juego 2D pixelado por niveles en Godot. El jugador **es el ingeniero de fluidos de perforación**: mantiene el lodo dentro de especificación, diagnostica contaminaciones y trata el sistema.

Documentos hermanos:
- `docs/domain-research.md` — entorno del taladro, circulación, válvulas, control de pozo.
- `docs/mud-engineer-reference.md` — matriz de contaminaciones, cálculos de tanque, píldoras, diagnóstico reológico. **Es la fuente de datos del juego.**
- `docs/mud-programs.md` — catálogo de sistemas base agua, vulnerabilidades cruzadas y programas de pozo ficticios. **Es el contenido de los niveles.**
- `docs/rig-tank-system.md` — estructura de tanques del taladro, conexiones, dinámica del lodo en superficie y cambio de fluido.

## Visión

Estética **pixel art cenital estilo Pokémon FireRed**: acogedora, legible, sin pretensión de simulador fotorrealista. El tono buscado es el de un trabajo tranquilo que de pronto te pone un problema difícil encima.

Lo que el juego enseña, en orden de prioridad:
1. **Manejo de tanques** — densificar, diluir, transferir, calcular volúmenes.
2. **Diagnóstico** — "vi un PV alto / un pH que subió solo, ¿qué pasó y qué hago?"
3. **Tratamiento de contaminaciones** — cemento, cal, yeso/anhidrita, sal, carbonatos, sólidos.
4. **Píldoras y cambios de fluido**.
5. **Seguir un programa de lodos** por sección de pozo.

## Decisiones de alcance

- **Rol: ingeniería de fluidos únicamente.** Laboratorio, tanques, válvulas, embudo de mezcla, transferencias, dosificación, píldoras, reporte. El driller, el BOP y las bombas son del resto de la cuadrilla: actúan solos y te generan eventos. **La circulación queda como expansión posterior**, no se construye ahora.
- Lodos **base agua (WBM)**.
- **Unidades de campo** (ppg, bbl, psi, lb/bbl, lb/100 ft², cP, mg/l).
- **Pozos ficticios** con parámetros plausibles.
- **Overworld caminable** en vista cenital.
- **Tiempo por turnos / días de pozo.**
- **Feedback explícito al fallar.**

> **Corrección de rol respecto al diseño anterior.** La versión previa ponía el clímax en cerrar el BOP y operar el choke. Ese es el trabajo del driller, no del ingeniero de fluidos. El control de pozo permanece como **contexto que le cae encima al jugador** (hay un kick → hay que densificar a peso de matada con la barita y el volumen disponibles), no como algo que el jugador opere.

## El núcleo jugable: síntoma → diagnóstico → tratamiento

Este es el hallazgo que estructura todo el juego, y viene del manual, no de una invención de diseño:

> **Los síntomas físicos son casi idénticos en todas las contaminaciones** (sube la viscosidad, suben los geles, sube el filtrado). **Solo las pruebas químicas identifican cuál es** (Pm, Pf, Mf, dureza de calcio, cloruros).

De ahí salen tres fases separadas y una estructura de juego limpia:

| Fase | Qué ve el jugador | Qué debe hacer |
|---|---|---|
| **1. Alarma** | Una propiedad física se salió de rango | Darse cuenta de que hay un problema |
| **2. Acertijo** | Los síntomas físicos no distinguen la causa | Ir al laboratorio y correr **las pruebas químicas correctas** |
| **3. Tratamiento** | Ya identificó el contaminante | Elegir químico, calcular dosis, aplicar y verificar |

Es exactamente la estructura de un combate Pokémon, pero el "tipo" del rival está oculto y hay que ganárselo con pruebas. La Tabla 4 del manual (4C.21) — flechas ↑/↓ de cada contaminante sobre FV, PV, YP, geles, filtrado, pH, Pm, Pf, Mf, Cl⁻, Ca²⁺ — es la tabla de tipos, ya tabulada por la API.

**Coste del diagnóstico.** Cada prueba consume tiempo del turno. Correr todas siempre es posible pero caro: el jugador aprende a elegir la prueba que más discrimina. Ahí está el verdadero aprendizaje.

## El taladro como overworld

Mapa cenital caminable. Cada estación es un lugar al que hay que ir físicamente — eso da memoria espacial del equipo, que tiene valor de entrenamiento real.

| Estación | Qué se hace |
|---|---|
| **Caseta de lodos (laboratorio)** | Correr pruebas: balanza, embudo Marsh, reómetro, filtro prensa API/HTHP, retorta, MBT, titulaciones Pf/Mf/Pm, dureza, cloruros, pH |
| **Tanques / pits** | Ver volúmenes y niveles, observar el lodo, transferir entre tanques, tomar muestra |
| **Embudo de mezcla** (*hopper*) | Vaciar sacos de producto al sistema activo o al tanque de mezcla |
| **Bodega de químicos** | Inventario y costo de productos |
| **Zarandas / control de sólidos** | Estado del equipo, observar retorno y recortes, evaluar si el problema es de sólidos (clave para PV alto) |
| **Piso de perforación** | Hablar con el driller: profundidad, formación que se está atravesando, avisos |
| **Oficina / company man** | Programa de lodos, entregar el reporte diario |

Caminar cuesta tiempo del turno. No es relleno: obliga a planear el recorrido, que es parte del oficio.

## Ciclo de juego (día de pozo)

1. **Inicio del turno** — el driller informa profundidad y formación en curso. Posible aviso de evento.
2. **Chequeo de rutina** — tomar muestra, correr el set básico de pruebas (ver abajo).
3. **Comparar contra el programa de lodos** — ¿está en especificación para esta sección?
4. **Ronda por los tanques** — observar el lodo durante el turno (ver *Observación visual*). Es el sistema de alarma entre chequeos.
5. **Diagnosticar** si algo se salió — pruebas químicas dirigidas.
6. **Tratar** — calcular dosis, adicionar por el embudo de mezcla, transferir, preparar píldora.
7. **Verificar** — volver a correr la prueba y confirmar que el tratamiento funcionó.
8. **Cerrar el día** — entregar el reporte de lodo; el pozo avanza en profundidad.

El tiempo del turno es el recurso escaso. El costo de productos es el segundo.

### Cómo conviven el chequeo de rutina y el acertijo

El chequeo de rutina incluye las pruebas químicas básicas, así que podría parecer que resuelve el acertijo solo. No lo hace, por tres razones:

- **Es una foto del inicio del turno.** Las contaminaciones ocurren *después*, mientras se perfora. A media jornada el jugador solo tiene lo que ve en los tanques.
- **Re-correr todo cuesta caro.** Cuando una observación dispara la alarma, el jugador decide qué pruebas repetir. Correr el set completo otra vez siempre es posible, pero se come el turno.
- **Las pruebas ampliadas no están en la rutina.** Separar calcio y magnesio, el Garrett Gas Train, la MBT o el filtrado HTHP solo se corren si el jugador sospecha algo. Ahí se resuelven los casos difíciles (carbonatos, carnalita, H₂S).

## Chequeo de rutina

Set básico que se corre al inicio de cada turno. Los tiempos son una **propuesta inicial** a calibrar jugando, sobre un turno de 12 h (720 min).

| Prueba | Muestra | Tiempo activo | Espera | Revela |
|---|---|---|---|---|
| **Balanza de lodo** (atmosférica) | Lodo | 5 min | — | Densidad. **Lee bajo si hay aire o gas atrapado** |
| **Viscosímetro Fann** (600/300/6/3 RPM) | Lodo | 10 min | — | Θ600, Θ300 → **PV, YP, VA**; Θ6/Θ3 para limpieza |
| **Geles 10 s / 10 min** | Lodo | 5 min | 10 min | Geles; tixotropía |
| **Filtrado API** (30 min @ 100 psi) | Lodo | 5 min | **30 min** | Filtrado (ml/30 min), revoque. **Produce el filtrado** para las pruebas químicas |
| **pH** | Lodo | 2 min | — | pH |
| **Pm** | Lodo | 10 min | — | Alcalinidad del lodo; exceso de cal |
| **Pf / Mf** | **Filtrado** | 10 min | — | Alcalinidad del filtrado; relación Mf/Pf |
| **Cloruros** | **Filtrado** | 10 min | — | Cl⁻ |
| **Dureza (Ca²⁺)** | **Filtrado** | 10 min | — | Calcio en filtrado |
| **Retorta** | Lodo | 5 min | **60 min** | % agua, % aceite, % sólidos → **Fw** y reparto de sólidos (ver abajo) |

`VA (cP) = Θ600 / 2`. La viscosidad aparente del Fann es el número que corresponde a lo que el jugador "ve" en los tanques.

**Dependencia real que es mecánica:** Pf/Mf, cloruros y dureza se corren sobre el **filtrado**, así que no se pueden hacer hasta que el filtro prensa termine. Las pruebas con espera (geles, filtrado) corren en paralelo: el jugador las arranca y mientras tanto hace otra cosa. Planear el orden en el laboratorio es parte del oficio.

**Pruebas ampliadas** (fuera de la rutina, para el acertijo): MBT, calcio y magnesio por separado, Garrett Gas Train, contenido de arena, filtrado HTHP, balanza presurizada.

### Qué se ve en la retorta

La retorta calienta una muestra de lodo hasta evaporar el agua (y el aceite, si hay), los condensa en una probeta graduada y deja los sólidos en la cámara. El jugador lee tres números: **% agua, % aceite y % sólidos** en volumen.

De ahí salen dos cosas que el juego usa:

1. **Fw = % agua / 100.** Es la fracción de agua que piden todas las fórmulas de dosis (`mud-engineer-reference.md` §1.2). Sin retorta, el jugador dosifica con un Fw viejo o supuesto, y la dosis sale mal.
2. **Qué tipo de sólidos hay.** Con la densidad del lodo y el % sólidos se separan los sólidos en **pesados** (barita, SG ~4,2) y **livianos** (LGS: arcilla y sólidos perforados, SG ~2,6). Esto conecta directo con la regla `PV alta = sólidos`:
   - % sólidos alto y casi todo **barita** → el lodo está pesado a propósito; la PV alta es esperable.
   - % sólidos alto y mucho **LGS** → hay **sólidos perforados acumulados**: dilución o control de sólidos.

La retorta tarda en la vida real (una fuente habla de dos horas o más con el calentamiento a 950 °F); los 60 min de espera son una propuesta a calibrar. Corre en paralelo con el filtro prensa.

Fuentes: [Retort Analysis Drilling Fluid — Drilling Manual](https://www.drillingmanual.com/retort-analysis-drilling-fluid/), [Suspended solids — SLB Energy Glossary](https://glossary.slb.com/en/terms/s/suspended_solids), [US 5519214 — Method for analysis of drilling fluids (USPTO)](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/5519214). El reparto barita/LGS sale del balance de masas de `mud-engineer-reference.md` §2 con densidades supuestas de 4,2 y 2,6; es aproximado, igual que en el campo.

## Observación visual

Lo que el jugador ve al caminar por los tanques y las zarandas, sin entrar al laboratorio. Cuesta solo el tiempo de caminar. Es el **sistema de alarma** entre chequeos.

**Regla de diseño:** una observación puede decir *que algo cambió* y a veces *qué familia de problema es*. **Nunca identifica el contaminante químico.** Eso sigue siendo trabajo del laboratorio (invariante 1).

Cada observación se deriva del estado de la simulación con umbrales, y es un **Resource**, igual que las pruebas: qué variable la genera, qué umbrales, qué texto muestra, dónde se ve.

| Observación | Dónde se ve | Qué la genera | Qué sugiere | Qué no dice |
|---|---|---|---|---|
| **Espuma y burbujas** en la superficie | Tanques, caja de llegada, zarandas | Aire o gas atrapado: embudo de mezcla, pistolas de lodo, agitación fuerte, aditivos con tensoactivos, gas de formación | Hay aire o gas en el lodo | Si es aire de superficie o gas del pozo. Para eso: balanza presurizada y comparar llegada contra succión |
| **Viscosidad a ojo**: cómo corre el lodo por la canaleta, el remolino del agitador, cómo escurre de la jarra | Tanques, zarandas | VA y geles, en cuatro niveles: *fluido · normal · espeso · muy espeso* | Que la viscosidad cambió | Si es PV (sólidos) o YP (química). Para eso: Fann |
| **Lodo rebosando las zarandas** | Zarandas | Viscosidad alta o mallas tapadas | Se está perdiendo lodo en superficie | La causa de la viscosidad |
| **Cantidad y forma de recortes** | Zarandas | Tasa de penetración y estabilidad del pozo | Derrumbes (*cavings*): astillados → posible sobrepresión; en bloque → esfuerzos en lutitas | Nada químico. Es información para el company man sobre el peso del lodo |
| **Nivel de tanques** fuera de lo esperado | Tanques | Ganancia o pérdida de volumen | Posible kick o pérdida de circulación → avisar al driller | — |
| **Lodo ennegrecido y olor a huevo podrido** | Caja de llegada, zarandas | Sulfuros (H₂S) | **H₂S**: emergencia de seguridad | La concentración. Para eso: Garrett Gas Train |
| **Sedimento en el fondo** de un tanque | Tanques sin agitar | Asentamiento de barita y sólidos | Hay que agitar antes de transferir o usar ese lodo | — |

### Trampas que salen de la observación

- **Espuma y balanza.** Con aire atrapado la balanza atmosférica lee **bajo**. El jugador que ve "densidad baja" y densifica termina **sobre-densificado** cuando el aire se va. Lo correcto: antiespumante y revisar la fuente (embudo de mezcla, pistolas), y confirmar con balanza presurizada.
- **"Se ve espeso" no es un diagnóstico.** Diluir porque el lodo se ve espeso es correcto si es PV alto (sólidos) y un error si es YP alto (química). El ojo no distingue; el Fann sí.
- **Muestra en el lugar equivocado.** Lo que viene del pozo se ve primero en la caja de llegada. La muestra de succión es lo que entra al pozo, después de los equipos de sólidos.

**Fuentes de la observación visual:**
- [Air-cut mud](https://glossary.slb.com/en/terms/a/air-cut_mud), [Gas-cut mud](https://glossary.slb.com/en/terms/g/gas-cut_mud) y [Pressurized mud balance](https://glossary.slb.com/en/terms/p/pressurized_mud_balance) — SLB Energy Glossary: el aire y el gas bajan la densidad leída; la balanza presurizada elimina ese efecto.
- [EP 0339762 — defoamer para lodos base agua (EPO)](https://data.epo.org/publication-server/rest/v1.2/patents/EP0339762NWA2/document.html): la espuma baja el peso del lodo, afecta bombas y desgasificadores, y altera la reología.
- [Defoamer Anti-Foam Agent for Drilling Fluids — PP Drilling Fluids](https://ppdrillingfluids.in/defoamer-anti-foam-agent-for-drilling-fluids/): causas comunes de espuma (agitación, gas, aditivos con tensoactivos, aire en el manejo). Es material de proveedor.
- [An Observation from Cavings at Shale Shakers — Search and Discovery](https://www.searchanddiscovery.com/documents/2012/41095kumar/ndx_kumar) y [Cavings — Wild Well Control](https://www.wildwell.com/glossary/cavings-heaving-or-spalling-shale): formas de derrumbes y lo que indican.
- [Mud tank — Wikipedia](https://en.wikipedia.org/wiki/Mud_tank): agitadores para evitar asentamiento.
- H₂S: `mud-engineer-reference.md` §1.8.

## Manejo de tanques

El eje que el jugador más quiere dominar. Operaciones disponibles, todas con su cálculo real (fórmulas en `mud-engineer-reference.md`):

- **Densificar** con barita: material requerido y **aumento de volumen** resultante — el sistema se llena al densificar, y eso hay que manejarlo.
- **Diluir** con agua o lodo base: baja densidad y también baja sólidos; compite con el control mecánico de sólidos como solución al PV alto.
- **Transferir entre tanques**: activo, reserva, mezcla, píldoras.
- **Preparar una píldora**: viscosa, pesada, de LCM, desatascadora. Calcular volumen y altura de columna.
- **Cambio / desplazamiento de fluido**: planificar el reemplazo del sistema.
- **Construir lodo nuevo** en el tanque de mezcla.
- **Reponer volumen**: el sistema pierde lodo cada día (hueco nuevo, descarte de sólidos), así que hay que construir lodo de forma continua.

La estructura de tanques, sus conexiones y las reglas de mezcla están en `rig-tank-system.md`. Los tanques y sus conexiones son un **layout por taladro** (Resource): un taladro con poca reserva es más difícil sin tocar la simulación.

> **Cambio de fluido:** `rig-tank-system.md` §5 propone una secuencia (construir en reserva, desplazar, desviar viejo / interfase / nuevo, reasignar tanques). Es una **síntesis por validar** con el autor: las fuentes públicas cubren poco el procedimiento en superficie entre dos lodos base agua.

## Diagnóstico de reología

Regla estructural que el juego enseña explícitamente:

```
PV alto  →  problema de SÓLIDOS    →  dilución o control mecánico de sólidos
YP alto  →  problema QUÍMICO       →  floculación / contaminación → tratar la causa
```

Con umbral duro del manual: `PV ≤ 2 × peso del lodo`. Superarlo es señal de carga de sólidos.

Esto convierte "vi un PV alto" en un árbol de decisión aprendible, y es deliberadamente lo primero que el juego enseña después de las pruebas básicas.

## Trampas pedagógicas

Situaciones donde la respuesta obvia es la equivocada. Son el contenido de mayor valor del juego, porque castigan el piloto automático:

- **Bucle de carbonatos (4C.11)** — echar soda cáustica *parece* desflocular, pero solo convierte HCO₃⁻ → CO₃²⁻ y el síntoma reaparece indefinidamente. El jugador puede quedarse atrapado tratando el efecto en vez de la causa.
- **Carbonato de sodio sobre cemento** — nunca; el manual lo prohíbe explícitamente.
- **Soda cáustica con carnalita** — 0,03 lb/bbl ya espesa el sistema.
- **Cemento: dosis deliberadamente insuficiente** — se trata por debajo del estequiométrico a propósito.
- **Selección de calcio por pH** — `<10,3` cal · `10,3–11,3` cal + yeso · `>11,3` yeso.
- **Formación de sal** — no se "corrige": se satura el lodo con sal a propósito. Enseña que no toda desviación es un problema que arreglar; a veces el programa cambia.

## Programa de lodos (quest log)

Documento in-game que define, **por sección de pozo**, los rangos objetivo de cada propiedad, los **productos aprobados** (que son el inventario legal de esa sección), las advertencias de formación y los criterios de cambio de fluido. Formato completo y programas de ejemplo en `mud-programs.md`.

Al cambiar de sección cambian las especificaciones **y el inventario**, de modo que el jugador no puede memorizar un solo set de números ni una sola receta.

## Progresión

Los "niveles" son **secciones de pozo**, y luego pozos completos. El fluido cambia entre secciones porque **la amenaza cambia** — esa es la lección estructural (ver `mud-programs.md`):

1. **Superficial** — bentonítico simple. Tutorial real: pruebas básicas, densificar, diluir. Errores perdonables.
2. **Intermedia** — según el pozo, disperso (pelea con el PV y los sólidos) o KCl/PHPA (frágil ante calcio: la contaminación de cemento es catastrófica).
3. **Sal** — saturación deliberada. **El jugador pierde la prueba de cloruros** como instrumento, porque ya está en el techo: la deducción se vuelve genuinamente más difícil por una razón real.
4. **Producción (RDF)** — invierte las reglas aprendidas: **la barita está prohibida**, y cualquier sólido de perforación arruina el objetivo.
5. **Pozos completos** con cambios de fluido y eventos encadenados.

## Feedback explícito al fallar

El juego **explica el porqué**, no solo marca el error. Dos momentos: aviso inmediato y debrief de fin de día. Toda regla evaluable carga su explicación **como dato**, no como texto suelto en la lógica.

Ejemplos del catálogo (se amplía con la matriz del reference):

| Fallo | Explicación |
|---|---|
| Tratar sin diagnosticar | Los síntomas físicos no distinguen contaminantes; sin prueba química estás adivinando |
| Soda cáustica repetida en carbonatos | Solo conviertes bicarbonato en carbonato: el síntoma vuelve. Hay que remover el carbonato, no subir el pH |
| Diluir ante un YP alto | YP alto es química, no sólidos. Diluir gasta producto y no ataca la causa |
| Sobre-densificar | Pasaste el techo de la ventana y además subiste el volumen del sistema |
| Carbonato de sodio sobre cemento | Prohibido por el manual: empeora el sistema |
| Tratar la sal como contaminación | En formación salina el programa pide saturar, no corregir |

## Modelo de simulación

Se usan **las fórmulas reales** del manual donde existen (están en `mud-engineer-reference.md`): densificación con barita y su aumento de volumen, mezcla por volumen, dosis de tratamiento (ej. `carbonato de sodio = mg/l × Fw × 0,000928`, `exceso de cal = 0,26(Pm − Pf·Fw)`), altura de columna de píldora.

Se **simplifican** con modelos lineales con techos/pisos: evolución de PV/YP/geles por adición, degradación pasiva por avance de perforación (ingreso de sólidos), cinética de los tratamientos (un tratamiento no actúa instantáneo: tarda ciclos de circulación).

El estado químico del lodo debe incluir las variables que el diagnóstico necesita — Pm, Pf, Mf, dureza de calcio, cloruros — no solo las físicas. **Sin eso, el acertijo central no existe.**

El estado también necesita **aire atrapado** (fracción de volumen). No es una propiedad que se reporte, pero genera la observación de espuma y hace que la balanza atmosférica lea bajo.

## Arquitectura en Godot (conceptual)

- **Separación simulación / presentación**: el estado del lodo, los tanques y la química viven en nodos de datos independientes de sprites y mapa. Testeable sin árbol visual (GUT); las fórmulas del manual son casos de prueba con entrada y salida conocidas.
- **Estado del lodo por tanque**: recurso con propiedades físicas *y químicas*.
- **Contaminante como dato**: cada uno declara su firma de efectos sobre cada prueba (la Tabla 4 convertida en Resource) y sus tratamientos válidos e inválidos. Agregar un contaminante nuevo = agregar un Resource, sin tocar lógica.
- **Prueba de laboratorio como dato**: qué variables revela, cuánto tiempo activo y de espera cuesta, sobre qué muestra se corre (lodo o filtrado).
- **Observación como dato**: qué variable la genera, umbrales, texto, estación donde se ve.
- **Tanque, conexión y layout del taladro como datos**: ver `rig-tank-system.md` §6.
- **Nivel/sección como Resource**: profundidad, formación, programa de lodos aplicable, eventos guionados, inventario disponible.
- **Reglas con explicación embebida**: predicado + texto, juntos.
- **Overworld**: TileMap cenital con estaciones como áreas interactuables; el costo en tiempo de caminar lo arbitra el gestor de turno.

## Pendientes

1. **Validar con el autor** la secuencia de cambio de fluido y las preguntas de `rig-tank-system.md` §7.
2. Recuperar los **Gráficos I y II** de tratamiento de carbonatos leyendo esas páginas del PDF como imagen (no sobrevivieron a la extracción de texto).
3. Calibrar constantes de los modelos simplificados y los tiempos de las pruebas — se ajustan jugando.
4. Estética concreta: paleta, tamaño de tile, sprite del personaje.
