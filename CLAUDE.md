# drilling_fluids — contexto para Claude

Juego 2D pixelado en **Godot** donde el jugador es un **ingeniero de fluidos de perforación**. Objetivo: que el autor (que trabaja en la industria) aprenda manejo de tanques, diagnóstico de propiedades y tratamiento de contaminaciones.

**Estado actual: simulación completa del turno y overworld caminable, todavía sin conectar entre sí.** Proyecto Godot 4.7.2 con: química del lodo con equilibrio ácido-base (Tabla 4 entera), 7 contaminantes, 21 productos, tanques y tiempo, 17 pruebas de laboratorio y 4 observaciones, 19 reglas con explicación, programa de CAIMÁN-3; perforación con formaciones y control de sólidos; eventos guionados y PVT; turno de 12 h con acciones, encuellador, inventario, reporte diario y noche simulada (`sim/operacion_pozo.gd` los engancha). Overworld de la locación (`game/overworld/`) con 7 personajes (`docs/personajes.md`). 245 pruebas pasando. Resumen en `simulation-logic.md` §12.7–12.8. Siguiente paso: unir el overworld al turno (señales `interactuado`/`caminado` → acciones y reloj) y las pantallas de laboratorio, tanques y reporte. Estructura y cómo correr las pruebas en `README.md`.

## Mapa de documentos

Leer en este orden antes de proponer nada:

| Documento | Qué contiene |
|---|---|
| `docs/game-design-mechanics.md` | **Empezar aquí.** Diseño del juego: núcleo jugable, overworld, ciclo de turno, progresión, arquitectura Godot. |
| `docs/mud-engineer-reference.md` | Datos del dominio: matriz de contaminaciones, cálculos de tanque, píldoras, diagnóstico reológico, pruebas de laboratorio. **Fuente de datos de la simulación.** |
| `docs/mud-programs.md` | 7 sistemas base agua, tabla de vulnerabilidades cruzadas, 3 pozos ficticios, formato del programa de lodos. **Contenido de los niveles.** |
| `docs/rig-tank-system.md` | Tanques del taladro: qué contiene cada uno, cómo se conectan, reglas de mezcla y volumen, cambio de fluido (validado en parte por el autor). **Base del manejo de tanques.** |
| `docs/simulation-logic.md` | Reglas de simulación contrastadas con fuentes (≥ 2 por dato), con marca de confianza y lista de temas pendientes. **Antes de implementar una regla, buscarla aquí.** |
| `docs/reference-wells.md` | Programas y casos **públicos** de otras cuencas (Pérmica, Colombia, Medio Oriente, mar del Norte) usados como referencia de patrones, y tres pozos ficticios derivados (MÉDANO-5, PIEDEMONTE-2, ESTRATO-9). |
| `docs/plan-desarrollo.md` | **Plan vigente:** hitos 0–6, orden de trabajo, riesgos, qué no hacer, referencia técnica. |
| `docs/auditoria-logica.md` | Auditoría de la lógica: hallazgos críticos, importantes y menores, con propuestas y preguntas para el autor. **Lista de trabajo pendiente.** |
| `docs/domain-research.md` | Entorno del taladro: circulación, válvulas, control de pozo. Hoy es **contexto**, no mecánica — relevante solo para la expansión futura de circulación. |

## Decisiones cerradas — no re-litigar

- **Rol:** ingeniería de fluidos únicamente. El jugador **no opera el BOP, el choke ni las bombas** — eso es trabajo del driller. El control de pozo le *ocurre* al jugador (hay un kick → densificar a peso de matada), no lo ejecuta.
- **Circulación:** fuera de alcance por ahora; expansión posterior.
- Lodos **base agua** únicamente.
- **Unidades de campo** (ppg, bbl, psi, lb/bbl, lb/100 ft², cP, mg/l). Las fórmulas traen constantes embebidas (0,052 · 1470 · 35); no convertir a métrico.
- **Pozos ficticios** con rangos plausibles. Nunca copiar un pozo real; los programas públicos de pozos reales sirven solo como **referencia de patrones** (`docs/reference-wells.md`).
- **Overworld caminable** en vista cenital, estética pixel art estilo Pokémon FireRed.
- **Tiempo por turnos / días de pozo.** El jugador juega el turno de día (12 h); el turno de noche corre simulado según las recomendaciones que dejó en el reporte.
- **Feedback explícito al fallar**: el juego explica el porqué, no solo marca el error.
- Documentación y UI **en español**.
- **Motor: Godot 4.7.2 (stable)**, la última estable de mantenimiento al momento de decidir. No usar betas ni versiones de desarrollo.
- **Chequeos:** rápido (densidad, embudo, pH; lo hace el jugador, ≤ 10 min) varias veces por turno; **completo** (balanza, Fann con PV/YP/VA, geles, filtrado API, pH, Pm, Pf/Mf, cloruros, dureza) al inicio del turno y opcional a media jornada; **retorta** (da Fw) una vez al día. Detalle en `game-design-mechanics.md`.
- **El jugador opera las válvulas de tanques** caminando hasta ellas. El "hopper" se llama **embudo de mezcla** en el juego; hay dos (arriba en el tanque de píldoras y abajo junto a la bomba centrífuga).
- **Las mezclas largas en el embudo las ejecuta el encuellador** por orden del jugador, a 50 sacos/h (250 con cuadrilla prestada en emergencias). `simulation-logic.md` §5 y §8.
- **Modelo de simulación:** cada tanque guarda la composición; la floculación y todas las propiedades se derivan. Paso de 10 min de juego. `simulation-logic.md` §12.
- **El efecto de un cambio se ve en una vuelta del lodo** (depende de profundidad, caudal y volumen en superficie), no en horas fijas. Sin tratamientos, el lodo no deriva solo: la cal en exceso es reserva; solo los finos de cemento se disuelven, en pocas vueltas.
- **Cambio de fluido entre lodos base agua: desplazamiento directo**, sin bache espaciador. Layout base: dos reservas + fractanques; circuito corto en el activo durante los preparativos (`rig-tank-system.md` §5).
- **La densidad se sube por programa** (tabla por profundidad en cada sección); el company man pide el valor del programa.
- **Pérdidas por filtración según la formación**: las arenas permeables pierden; se responde subiendo el controlador de filtrado (y puenteo). Las órdenes de sacos van al **encuellador o al obrero de patio**.
- **El reporte diario cubre 24 h** (noche anterior + turno de día).
- **Observación visual** (espuma, viscosidad a ojo, recortes, nivel, color/olor, sedimento) es la alarma entre chequeos. Nunca identifica el contaminante químico.

## Invariantes de diseño — romper esto rompe el juego

1. **El estado del lodo debe incluir variables químicas** (Pm, Pf, Mf, dureza de calcio, cloruros), no solo físicas (densidad, PV, YP, filtrado). El núcleo del juego es que *los síntomas físicos no distinguen contaminantes — solo las pruebas químicas lo hacen*. Si se modela solo lo físico, el acertijo central deja de existir y hay que rehacer el modelo entero.

2. **Núcleo jugable en tres fases separadas:** alarma (algo se salió de rango) → acertijo (correr las pruebas químicas correctas) → tratamiento (químico + dosis + verificar). Cada prueba cuesta tiempo del turno: correr todas siempre debe ser posible pero caro.

3. **Contaminantes, pruebas y niveles son datos, no lógica.** Cada uno es un Resource de Godot. Agregar un contaminante nuevo = agregar un archivo, sin tocar código.

4. **Cada regla evaluable carga su explicación como dato** (predicado + texto juntos). Es lo que hace sostenible el feedback explícito.

5. **Separación simulación / presentación.** La simulación debe poder testearse sin árbol de escena visual. Las fórmulas del manual son casos de prueba con entrada y salida conocidas.

6. **El inventario aprobado del programa de lodos es la palanca de dificultad.** Quitar un producto sube la dificultad sin tocar la simulación.

## Próximos pasos

1. ~~Esqueleto del proyecto Godot 4.7.2~~ ✅ hecho. Pruebas: `godot --headless --path . --script res://tests/run_tests.gd`.
2. Modelo de datos según `simulation-logic.md` §12: ✅ estado del lodo, contaminantes, productos, tanque y tiempo, pruebas, observaciones, reglas, programa (§12.7); perforación, control de sólidos, eventos, PVT, turno y reporte (§12.8). Falta: layout de compartimientos y conexiones del taladro en la simulación (las válvulas del mapa aún no mueven lodo).
3. Fórmulas reales de `mud-engineer-reference.md`: ✅ las de tanque, volumen, presión, reología, dosis y píldoras están en `sim/formulas.gd` con pruebas. Faltan las que dependan del modelo de estado.
4. Primer vertical slice: sección superficial del pozo CAIMÁN-3 — pruebas básicas, densificar, diluir. Falta la interfaz: unir `game/overworld/overworld.gd` (señales) con `sim/turno.gd`, caja de laboratorio, vista de tanques y reporte.

**Pendientes de investigación:**
- Procedimiento de **desplazamiento / cambio de fluido**: secuencia en `rig-tank-system.md` §5, ya validada en parte por el autor. Quedan abiertos el criterio para desviar retornos y la composición del circuito corto (§7).
- **Dos factores de la Tabla 2** salen 10 veces altos en `mud-engineer-reference.md` §1.2 (bicarbonato con cal y calcio con bicarbonato de sodio). El código usa los estequiométricos. **Confirmar contra el PDF local.**
- **Gráficos I y II** de tratamiento de carbonatos: son imágenes del PDF y no sobrevivieron a la extracción de texto. **Solo recuperables en la máquina local** (ver abajo).
- Estética concreta: paleta, tamaño de tile, sprite del personaje.

## Convenciones de código

- GDScript, nombres en **español sin tildes** (`barita_lb_por_bbl`, no `bariteLbPerBbl`).
- `sim/` no puede depender de nada de `game/` (invariante 5).
- Toda fórmula nueva lleva prueba en `tests/` con un ejemplo numérico de `docs/`, citando la sección.
- Las pruebas cargan scripts con `preload`, no por `class_name`, para que corran en modo `--headless` sin importar el proyecto en el editor.

## Límites importantes

- **No leer `~/Documents/QMax`.** Son archivos de la empresa y de clientes del autor. El autor pidió explícitamente no usarlos. Todo el contenido del juego es ficticio a propósito.
- **El manual PDF no está en el repositorio.** Es material con derechos de autor y este repo es público, así que está en `.gitignore` y vive solo en la máquina local del autor (`MANUAL_DE_FLUIDOS_DE_PERFORACION_API_pdf.pdf`). Una sesión en la nube **no tiene acceso a él**: trabajar con lo ya extraído en `docs/mud-engineer-reference.md` y no inventar citas del manual.
- Si hace falta dato técnico nuevo, buscarlo en fuentes públicas y **citar el enlace**, como hacen los documentos existentes.
