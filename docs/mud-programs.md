# Programas de lodo y sistemas base agua (ficticios)

Catálogo de sistemas y programas **inventados pero plausibles**, para alimentar el quest log del juego. Ningún dato proviene de pozos reales. Rangos y concentraciones están dentro de lo que la industria usa; los pozos, nombres y secuencias son ficción.

Documentos hermanos: `docs/mud-engineer-reference.md` (contaminaciones y cálculos) · `docs/game-design-mechanics.md` (diseño).

## Por qué cambia el fluido entre secciones

Esta es la lección central del documento: **el fluido no cambia por capricho, cambia porque el problema cambia.** Cada sección del pozo tiene una amenaza dominante, y el sistema se elige para enfrentarla.

| Sección | Amenaza dominante | Qué le pide al fluido |
|---|---|---|
| **Superficial** | Formación no consolidada, derrumbes, alta tasa de penetración, enorme volumen de recortes | Limpiar el hueco y ser **barato y desechable**. La inhibición no sirve de nada aquí |
| **Intermedia** | Lutitas reactivas que se hinchan, presión de formación creciente, zonas de anhidrita o sal | **Inhibición química** y densidad controlada |
| **Sal** | La sal se disuelve en agua dulce y lava el hueco | Agua **ya saturada de sal**, para que no pueda disolver más |
| **Yacimiento** | Cualquier sólido o filtrado que invada daña la permeabilidad y mata la producción | **No dañar**: sólidos mínimos, puenteo removible con ácido, nada de barita |

Corolario pedagógico: un fluido excelente en una sección es una mala elección en otra. El jugador no puede aprender "el lodo bueno" — tiene que aprender a leer el problema.

## Catálogo de sistemas base agua

### 1. Bentonítico nativo — "Spud Mud"

**Sección típica:** superficial (26", 17½")

| Aditivo | Dosis | Función |
|---|---|---|
| Bentonita | 15–25 lb/bbl | Viscosidad y limpieza del hueco |
| Carbonato de sodio (soda ash) | 0,25–1 lb/bbl | Trata la dureza del agua de mezcla |
| Soda cáustica | 0,25–0,5 lb/bbl | pH |

**Propiedades objetivo:** densidad 8,4–9,2 ppg · FV 35–45 s · PV 5–12 cP · YP 15–30 lb/100ft² · filtrado sin control · pH 8,5–9,5

**Fuerte en:** costo bajísimo, tolerancia al abuso, barridos viscosos para limpiar.
**Débil en:** ninguna inhibición, sin control de filtrado, no soporta densidad alta.
**Nota de juego:** el sistema del tutorial. Pocas variables, errores perdonables.

### 2. Disperso con lignosulfonato

**Sección típica:** intermedia, en formaciones poco reactivas

| Aditivo | Dosis | Función |
|---|---|---|
| Bentonita | 8–15 lb/bbl | Base de viscosidad |
| Lignosulfonato | 2–8 lb/bbl | Dispersante / adelgazante |
| Lignito | 2–6 lb/bbl | Control de filtrado y estabilidad térmica |
| Soda cáustica | 0,5–1,5 lb/bbl | pH alto, necesario para activar el lignosulfonato |
| Barita | según necesidad | Densidad |

**Propiedades objetivo:** densidad 9,5–12,5 ppg · PV 12–25 cP · YP 8–16 lb/100ft² · filtrado 5–8 ml · pH 9,5–10,5

**Fuerte en:** tolera contaminación y carga de sólidos mejor que cualquier otro; barato de mantener.
**Débil en:** acumula sólidos → **PV sube sin parar**; no inhibe lutitas; el pH alto exige vigilancia.
**Nota de juego:** el sistema donde el jugador pelea con el PV y aprende la regla `PV ≈ sólidos`.

### 3. Inhibido KCl / Polímero (PHPA)

**Sección típica:** intermedia con lutitas reactivas

| Aditivo | Dosis | Función |
|---|---|---|
| KCl | 10–25 lb/bbl (3–7 %) | Inhibición iónica de lutitas |
| PHPA | 0,5–2 lb/bbl | Encapsula recortes y protege la lutita |
| Goma xantan (XC) | 0,5–1,5 lb/bbl | Viscosidad y suspensión |
| Almidón modificado | 2–6 lb/bbl | Control de filtrado |
| Soda cáustica | 0,25–0,75 lb/bbl | pH |
| Barita | según necesidad | Densidad |

**Propiedades objetivo:** densidad 9,0–11,5 ppg · PV 10–20 cP · YP 15–25 lb/100ft² · filtrado 4–6 ml · pH 9,0–9,5 · K⁺ 15.000–30.000 mg/l

**Fuerte en:** excelente estabilidad de pozo, recortes firmes, bajo contenido de sólidos.
**Débil en:** **el calcio lo destruye** — una contaminación de cemento precipita el sistema; caro; el pH por encima de ~10 degrada el almidón.
**Nota de juego:** el sistema más frágil y el más instructivo. Aquí la contaminación de cemento es una catástrofe real, no un número que sube.

### 4. Salado saturado

**Sección típica:** atravesando domo o estrato de sal

| Aditivo | Dosis | Función |
|---|---|---|
| NaCl | hasta saturación (~126 lb/bbl) | Impide que el lodo disuelva la formación |
| Almidón modificado | 4–8 lb/bbl | Control de filtrado (tolera la salinidad) |
| Goma xantan | 1–2 lb/bbl | Viscosidad en agua salada |
| Soda cáustica | 0,25–0,5 lb/bbl | pH |
| Barita | según necesidad | Densidad |

**Propiedades objetivo:** densidad 10,0–12,0 ppg · PV 15–30 cP · YP 12–20 lb/100ft² · filtrado 6–10 ml · pH 9,0–10,0 · **cloruros ~188.000 mg/l (saturado)**

**Fuerte en:** único sistema que no lava un estrato de sal.
**Débil en:** viscosidad difícil de manejar, la bentonita no hidrata en salmuera saturada, riesgo de carnalita (magnesio).
**Nota de juego — la mejor idea del catálogo:** con los cloruros saturados, **el jugador pierde la prueba de cloruros como instrumento de diagnóstico**. Ya está en el techo, no puede subir más. Tiene que deducir con las otras pruebas. La sección de sal es genuinamente más difícil, y lo es por una razón real.

### 5. Cálcico (cal / yeso)

**Sección típica:** intermedia con anhidrita o yeso, o tramos donde se espera contaminación de cemento

| Aditivo | Dosis | Función |
|---|---|---|
| Cal hidratada o yeso | 0,5–2 / 2–6 lb/bbl | Fuente de calcio deliberada |
| Bentonita | 10–15 lb/bbl | Base |
| Lignosulfonato | 3–6 lb/bbl | Dispersante |
| CMC o almidón | 2–4 lb/bbl | Filtrado |
| Soda cáustica | 0,5–1 lb/bbl | pH |

**Propiedades objetivo:** densidad 9,5–12,0 ppg · PV 12–22 cP · YP 10–18 lb/100ft² · filtrado 4–8 ml · pH 9,5–10,5 (cal) · Ca²⁺ 600–1.200 mg/l

**Fuerte en:** **ya está contaminado de calcio a propósito**, así que una contaminación adicional de cemento o anhidrita casi no lo mueve.
**Débil en:** riesgo de floculación por temperatura, más difícil de controlar el filtrado.
**Nota de juego:** enseña el concepto más contraintuitivo del oficio — a veces se agrega el contaminante a propósito para volverse inmune a él.

### 6. Drill-in de yacimiento (RDF)

**Sección típica:** formación objetivo / productora

| Aditivo | Dosis | Función |
|---|---|---|
| Salmuera de KCl o NaCl | base | Fase líquida limpia, sin sólidos |
| Goma xantan | 1–2 lb/bbl | Viscosidad y suspensión |
| Almidón modificado | 4–8 lb/bbl | Control de filtrado |
| CaCO₃ dimensionado (fino/medio/grueso) | 15–40 lb/bbl | Puenteo **soluble en ácido** |
| Soda cáustica | mínima | pH |

**Propiedades objetivo:** densidad 8,6–10,5 ppg · PV 8–15 cP · YP 15–25 lb/100ft² · filtrado API 4–6 ml · sólidos de perforación ~0 · pH 9,0–9,5

**Fuerte en:** no daña la formación; el revoque se remueve después con ácido y se recupera la permeabilidad.
**Débil en:** **prohibida la barita** (es insoluble y daña permanentemente); densidad limitada por la salmuera; carísimo; cualquier sólido de perforación que entre arruina el propósito.
**Nota de juego:** invierte las reglas aprendidas. La herramienta favorita del jugador para subir densidad —la barita— aquí está prohibida. Tiene que densificar con salmuera más pesada o aceptar el límite.

## Vulnerabilidades cruzadas

El mismo contaminante hace daño muy distinto según el sistema. Esta tabla es la que hace que cambiar de sección cambie el juego:

| Contaminante | Spud | Lignosulfonato | KCl/PHPA | Salado | Cálcico | RDF |
|---|---|---|---|---|---|---|
| **Cemento** | leve | moderado | **crítico** | moderado | **inmune** | crítico |
| **Anhidrita/yeso** | leve | moderado | alto | moderado | **inmune** | alto |
| **Sal** | moderado | moderado | alto | **inmune** | moderado | moderado |
| **Carbonatos** | leve | **alto** | alto | moderado | moderado | alto |
| **Sólidos de perforación** | tolerado | **alto (PV)** | moderado | alto | moderado | **crítico** |
| **Magnesio / carnalita** | leve | moderado | alto | **crítico** | alto | alto |

## Programas de pozo (ficticios)

### Pozo CAIMÁN-3 — llanos, convencional

| Sección | Diámetro | Profundidad | Sistema | Densidad | Nota del programa |
|---|---|---|---|---|---|
| Superficial | 17½" | 0–2.500 ft | Bentonítico | 8,6–9,0 ppg | Barridos viscosos cada parada |
| Intermedia | 12¼" | 2.500–8.000 ft | KCl/PHPA | 9,5–10,8 ppg | Lutita reactiva desde 3.200 ft |
| Producción | 8½" | 8.000–9.600 ft | RDF | 9,0–9,6 ppg | Arena productora; CaCO₃ dimensionado |

**Evento guionado:** contaminación de cemento al iniciar la intermedia, justo después de cementar el revestimiento superficial. Golpea al sistema más vulnerable a calcio.

### Pozo MORICHE-12 — con tramo salino

| Sección | Diámetro | Profundidad | Sistema | Densidad | Nota del programa |
|---|---|---|---|---|---|
| Superficial | 17½" | 0–2.000 ft | Bentonítico | 8,6–9,2 ppg | — |
| Intermedia | 12¼" | 2.000–6.500 ft | Disperso lignosulfonato | 9,8–11,5 ppg | Formación poco reactiva; vigilar PV |
| Sal | 12¼" | 6.500–8.200 ft | Salado saturado | 10,5–11,8 ppg | **Cambio de fluido** antes de entrar a la sal |
| Producción | 8½" | 8.200–9.400 ft | RDF | 9,4–10,0 ppg | — |

**Evento guionado:** el cambio de fluido completo antes del tramo salino. Y dentro de la sal, aparición de carnalita (magnesio) — donde la soda cáustica es precisamente lo que *no* hay que echar.

### Pozo SALITRE-7 — intermedia con anhidrita

| Sección | Diámetro | Profundidad | Sistema | Densidad | Nota del programa |
|---|---|---|---|---|---|
| Superficial | 17½" | 0–2.800 ft | Bentonítico | 8,6–9,0 ppg | — |
| Intermedia | 12¼" | 2.800–7.500 ft | Cálcico (yeso) | 10,0–11,6 ppg | Anhidrita esperada desde 4.000 ft |
| Producción | 8½" | 7.500–8.900 ft | RDF | 9,2–9,8 ppg | Pérdida de circulación probable |

**Evento guionado:** el jugador llega con un sistema ya inmunizado y descubre que la "contaminación" no lo afecta — la lección de que el sistema correcto evita el problema en vez de tener que curarlo.

## Formato del programa de lodos

El manual API no trae un formato, así que este es el que usa el juego. Es lo que el jugador consulta en la oficina:

**Encabezado:** pozo · sección · diámetro · intervalo de profundidad · sistema de fluido · objetivo de la sección.

**Especificación de propiedades** (rango mínimo–máximo): densidad · viscosidad de embudo · PV · YP · geles 10s/10min · filtrado API · pH · y las químicas que apliquen al sistema (Cl⁻, Ca²⁺, K⁺, Pf/Mf).

**Productos aprobados** con concentración de mantenimiento — define el inventario disponible, y por tanto qué tratamientos son legales en esa sección.

**Advertencias de la sección:** formaciones esperadas, contaminaciones probables, riesgos (pérdida de circulación, lutita reactiva, sal).

**Criterios de cambio de fluido:** a qué profundidad y bajo qué condición se desplaza al siguiente sistema.

## Notas de diseño

- **El programa es el quest log.** Cambiar de sección cambia la especificación, el inventario aprobado y las amenazas. El jugador no puede memorizar un set de números.
- **El inventario aprobado es la palanca de dificultad más limpia.** Quitar un producto del programa hace el problema más difícil sin tocar la simulación.
- **El cambio de fluido es el nivel más complejo** y merece ser un hito, no un trámite: implica planear volúmenes, construir el sistema nuevo en tanques de reserva y desplazar sin contaminar.
- **Cada sistema redefine qué pruebas sirven.** El caso del salado saturado (cloruros en el techo, instrumento inutilizado) es el ejemplo más fuerte y debería guiar el diseño de las demás secciones.

**Fuentes consultadas para calibrar rangos y paquetes de aditivos:**
- [Water Based Drilling Fluid Systems Applications & Mixing — Drilling Manual](https://www.drillingmanual.com/water-based-drilling-fluid-systems/)
- [A Comprehensive Guide for Oil & Gas Wells Drilling Fluids — Drillopedia](https://www.drillopedia.com/mud-drilling-fluid-essentials)
- [AADE — Sized calcium carbonate in reservoir drill-in fluids](https://www.aade.org/application/files/1916/5237/7019/AADE-22-FTCE-052_-_Ryabtsev_et_al.pdf)
- [High Performance Water Base Fluid — Newpark](https://www.newpark.com/assets/pdfs/High_Performance_Water_Base_Fluid_Improves_Rate_of_Penetration_and_Lowers_Torque._Successful_Application_and_Results_Achieved_by%20Drilling_a_Horizontal_Section_Through_the_Reservoir.pdf)
- [Appendix F: Mud Program (ejemplo público de programa por sección)](https://ocdimage.emnrd.nm.gov/Imaging/FileStore/santafeadmin/CF/250804/13589_175_CF.pdf)
