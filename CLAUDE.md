# drilling_fluids — contexto para Claude

Juego 2D pixelado en **Godot** donde el jugador es un **ingeniero de fluidos de perforación**. Objetivo: que el autor (que trabaja en la industria) aprenda manejo de tanques, diagnóstico de propiedades y tratamiento de contaminaciones.

**Estado actual: diseño cerrado, sin código.** El siguiente paso es el esqueleto del proyecto Godot.

## Mapa de documentos

Leer en este orden antes de proponer nada:

| Documento | Qué contiene |
|---|---|
| `docs/game-design-mechanics.md` | **Empezar aquí.** Diseño del juego: núcleo jugable, overworld, ciclo de turno, progresión, arquitectura Godot. |
| `docs/mud-engineer-reference.md` | Datos del dominio: matriz de contaminaciones, cálculos de tanque, píldoras, diagnóstico reológico, pruebas de laboratorio. **Fuente de datos de la simulación.** |
| `docs/mud-programs.md` | 6 sistemas base agua, tabla de vulnerabilidades cruzadas, 3 pozos ficticios, formato del programa de lodos. **Contenido de los niveles.** |
| `docs/domain-research.md` | Entorno del taladro: circulación, válvulas, control de pozo. Hoy es **contexto**, no mecánica — relevante solo para la expansión futura de circulación. |

## Decisiones cerradas — no re-litigar

- **Rol:** ingeniería de fluidos únicamente. El jugador **no opera el BOP, el choke ni las bombas** — eso es trabajo del driller. El control de pozo le *ocurre* al jugador (hay un kick → densificar a peso de matada), no lo ejecuta.
- **Circulación:** fuera de alcance por ahora; expansión posterior.
- Lodos **base agua** únicamente.
- **Unidades de campo** (ppg, bbl, psi, lb/bbl, lb/100 ft², cP, mg/l). Las fórmulas traen constantes embebidas (0,052 · 1470 · 35); no convertir a métrico.
- **Pozos ficticios** con rangos plausibles. Nunca usar datos de pozos reales.
- **Overworld caminable** en vista cenital, estética pixel art estilo Pokémon FireRed.
- **Tiempo por turnos / días de pozo.**
- **Feedback explícito al fallar**: el juego explica el porqué, no solo marca el error.
- Documentación y UI **en español**.

## Invariantes de diseño — romper esto rompe el juego

1. **El estado del lodo debe incluir variables químicas** (Pm, Pf, Mf, dureza de calcio, cloruros), no solo físicas (densidad, PV, YP, filtrado). El núcleo del juego es que *los síntomas físicos no distinguen contaminantes — solo las pruebas químicas lo hacen*. Si se modela solo lo físico, el acertijo central deja de existir y hay que rehacer el modelo entero.

2. **Núcleo jugable en tres fases separadas:** alarma (algo se salió de rango) → acertijo (correr las pruebas químicas correctas) → tratamiento (químico + dosis + verificar). Cada prueba cuesta tiempo del turno: correr todas siempre debe ser posible pero caro.

3. **Contaminantes, pruebas y niveles son datos, no lógica.** Cada uno es un Resource de Godot. Agregar un contaminante nuevo = agregar un archivo, sin tocar código.

4. **Cada regla evaluable carga su explicación como dato** (predicado + texto juntos). Es lo que hace sostenible el feedback explícito.

5. **Separación simulación / presentación.** La simulación debe poder testearse sin árbol de escena visual. Las fórmulas del manual son casos de prueba con entrada y salida conocidas.

6. **El inventario aprobado del programa de lodos es la palanca de dificultad.** Quitar un producto sube la dificultad sin tocar la simulación.

## Próximos pasos

1. **Esqueleto del proyecto Godot** (no se ha creado). Definir primero la versión de Godot a usar.
2. Modelo de datos puro y testeable: estado del lodo (físico + químico), tanque, contaminante, prueba de laboratorio, programa de sección.
3. Implementar las fórmulas reales de `mud-engineer-reference.md` con pruebas unitarias.
4. Primer vertical slice: sección superficial del pozo CAIMÁN-3 — pruebas básicas, densificar, diluir.

**Pendientes de investigación:**
- Procedimiento de **desplazamiento / cambio de fluido** (baches, secuencia, criterios de limpieza). El manual API no lo trae y es el nivel más complejo del juego — hace falta otra fuente.
- **Gráficos I y II** de tratamiento de carbonatos: son imágenes del PDF y no sobrevivieron a la extracción de texto. **Solo recuperables en la máquina local** (ver abajo).
- Estética concreta: paleta, tamaño de tile, sprite del personaje.

## Límites importantes

- **No leer `~/Documents/QMax`.** Son archivos de la empresa y de clientes del autor. El autor pidió explícitamente no usarlos. Todo el contenido del juego es ficticio a propósito.
- **El manual PDF no está en el repositorio.** Es material con derechos de autor y este repo es público, así que está en `.gitignore` y vive solo en la máquina local del autor (`MANUAL_DE_FLUIDOS_DE_PERFORACION_API_pdf.pdf`). Una sesión en la nube **no tiene acceso a él**: trabajar con lo ya extraído en `docs/mud-engineer-reference.md` y no inventar citas del manual.
- Si hace falta dato técnico nuevo, buscarlo en fuentes públicas y **citar el enlace**, como hacen los documentos existentes.
