# Diseño del juego: el ingeniero de fluidos

Juego 2D pixelado por niveles en Godot. El jugador **es el ingeniero de fluidos de perforación**: mantiene el lodo dentro de especificación, diagnostica contaminaciones y trata el sistema.

Documentos hermanos:
- `docs/domain-research.md` — entorno del taladro, circulación, válvulas, control de pozo.
- `docs/mud-engineer-reference.md` — matriz de contaminaciones, cálculos de tanque, píldoras, diagnóstico reológico. **Es la fuente de datos del juego.**
- `docs/mud-programs.md` — catálogo de sistemas base agua, vulnerabilidades cruzadas y programas de pozo ficticios. **Es el contenido de los niveles.**

## Visión

Estética **pixel art cenital estilo Pokémon FireRed**: acogedora, legible, sin pretensión de simulador fotorrealista. El tono buscado es el de un trabajo tranquilo que de pronto te pone un problema difícil encima.

Lo que el juego enseña, en orden de prioridad:
1. **Manejo de tanques** — densificar, diluir, transferir, calcular volúmenes.
2. **Diagnóstico** — "vi un PV alto / un pH que subió solo, ¿qué pasó y qué hago?"
3. **Tratamiento de contaminaciones** — cemento, cal, yeso/anhidrita, sal, carbonatos, sólidos.
4. **Píldoras y cambios de fluido**.
5. **Seguir un programa de lodos** por sección de pozo.

## Decisiones de alcance

- **Rol: ingeniería de fluidos únicamente.** Laboratorio, tanques, hopper, transferencias, dosificación, píldoras, reporte. El driller, el BOP y las bombas son del resto de la cuadrilla: actúan solos y te generan eventos. **La circulación queda como expansión posterior**, no se construye ahora.
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
| **Tanques / pits** | Ver volúmenes y niveles, transferir entre tanques, tomar muestra |
| **Hopper de mezcla** | Adicionar producto al sistema activo |
| **Bodega de químicos** | Inventario y costo de productos |
| **Zarandas / control de sólidos** | Estado del equipo, evaluar si el problema es de sólidos (clave para PV alto) |
| **Piso de perforación** | Hablar con el driller: profundidad, formación que se está atravesando, avisos |
| **Oficina / company man** | Programa de lodos, entregar el reporte diario |

Caminar cuesta tiempo del turno. No es relleno: obliga a planear el recorrido, que es parte del oficio.

## Ciclo de juego (día de pozo)

1. **Inicio del turno** — el driller informa profundidad y formación en curso. Posible aviso de evento.
2. **Chequeo de rutina** — tomar muestra, correr el set básico de pruebas.
3. **Comparar contra el programa de lodos** — ¿está en especificación para esta sección?
4. **Diagnosticar** si algo se salió — pruebas químicas dirigidas.
5. **Tratar** — calcular dosis, adicionar por el hopper, transferir, preparar píldora.
6. **Verificar** — volver a correr la prueba y confirmar que el tratamiento funcionó.
7. **Cerrar el día** — entregar el reporte de lodo; el pozo avanza en profundidad.

El tiempo del turno es el recurso escaso. El costo de productos es el segundo.

## Manejo de tanques

El eje que el jugador más quiere dominar. Operaciones disponibles, todas con su cálculo real (fórmulas en `mud-engineer-reference.md`):

- **Densificar** con barita: material requerido y **aumento de volumen** resultante — el sistema se llena al densificar, y eso hay que manejarlo.
- **Diluir** con agua o lodo base: baja densidad y también baja sólidos; compite con el control mecánico de sólidos como solución al PV alto.
- **Transferir entre tanques**: activo, reserva, mezcla, píldoras.
- **Preparar una píldora**: viscosa, pesada, de LCM, desatascadora. Calcular volumen y altura de columna.
- **Cambio / desplazamiento de fluido**: planificar el reemplazo del sistema.
- **Construir lodo nuevo** en el tanque de mezcla.

> **Hueco de fuente:** el manual API no trae procedimiento de desplazamiento/cambio de fluido (baches, secuencia, criterios de limpieza). El **formato de programa de lodos ya está resuelto** en `mud-programs.md`; el procedimiento de desplazamiento sigue pendiente de otra fuente.

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

## Arquitectura en Godot (conceptual)

- **Separación simulación / presentación**: el estado del lodo, los tanques y la química viven en nodos de datos independientes de sprites y mapa. Testeable sin árbol visual (GUT); las fórmulas del manual son casos de prueba con entrada y salida conocidas.
- **Estado del lodo por tanque**: recurso con propiedades físicas *y químicas*.
- **Contaminante como dato**: cada uno declara su firma de efectos sobre cada prueba (la Tabla 4 convertida en Resource) y sus tratamientos válidos e inválidos. Agregar un contaminante nuevo = agregar un Resource, sin tocar lógica.
- **Prueba de laboratorio como dato**: qué variables revela, cuánto tiempo cuesta.
- **Nivel/sección como Resource**: profundidad, formación, programa de lodos aplicable, eventos guionados, inventario disponible.
- **Reglas con explicación embebida**: predicado + texto, juntos.
- **Overworld**: TileMap cenital con estaciones como áreas interactuables; el costo en tiempo de caminar lo arbitra el gestor de turno.

## Pendientes

1. Fuente para el **procedimiento de desplazamiento / cambio de fluido** (baches, secuencia, criterios de limpieza) — el manual API no lo trae y es el nivel más complejo del juego.
2. Recuperar los **Gráficos I y II** de tratamiento de carbonatos leyendo esas páginas del PDF como imagen (no sobrevivieron a la extracción de texto).
3. Calibrar constantes de los modelos simplificados — se ajustan jugando.
4. Definir el set de pruebas del "chequeo de rutina" inicial y su costo en tiempo.
5. Estética concreta: paleta, tamaño de tile, sprite del personaje.
