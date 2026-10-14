# Contexto y prompt para planificar con otro asistente

Copia desde la línea `---` hasta el final y pégalo en el chat. El texto es autocontenido: el asistente no necesita ver el repositorio. Si puede leer GitHub, el repositorio es público: `reinaldo-06/drilling_fluids`, rama `claude/archivos-disponibles-fdps0n`.

---

## Contexto del proyecto

Estoy haciendo un **juego 2D en pixel art, en Godot 4.7.2 (GDScript)**. El jugador es un **ingeniero de fluidos de perforación** (lodos base agua) en un taladro petrolero. El objetivo es aprender, como en un simulador, tres cosas: el manejo de tanques, el diagnóstico de propiedades y el tratamiento de contaminaciones. Trabajo en la industria y soy nuevo en ella. La documentación y la interfaz van en español, y las unidades son de campo (ppg, bbl, psi, lb/bbl, lb/100 ft², cP, mg/l).

### Decisiones cerradas (no se discuten)

- **El rol es solo fluidos.** El jugador no opera BOP, choke ni bombas; eso lo hace el perforador. Un kick *le ocurre* al jugador, y su trabajo es densificar al peso de matada.
- **La circulación hidráulica detallada queda para una expansión posterior.**
- **La vista es cenital y caminable, al estilo Pokémon FireRed.** El jugador camina hasta las válvulas para operarlas.
- **El tiempo avanza por días de pozo.** El jugador juega el turno de día (12 h) y la noche se simula según las recomendaciones que dejó en el reporte. El reporte diario cubre 24 h.
- **Hay tres tipos de chequeo:**
  - rápido (densidad, embudo y pH; ≤ 10 min), varias veces al día;
  - completo (balanza, Fann con VP, PC y VA, geles, filtrado API, pH, Pm, Pf/Mf, cloruros y dureza), al inicio del turno;
  - retorta, una vez al día.
- **El encuellador o el obrero de patio hacen las mezclas largas en el embudo**, a 50 sacos/h; con cuadrilla prestada, 250.
- **Hay dos embudos de mezcla**: uno arriba, en el tanque de píldoras, y otro abajo, junto a la bomba centrífuga.
- **Los tanques son:** dos reservas, fractanques y el sistema activo, que se usa en circuito corto durante los preparativos. El cambio de fluido se hace por desplazamiento directo, sin espaciador.
- **Un tratamiento se ve en una vuelta del lodo**, que depende de la profundidad, el caudal y el volumen en superficie.
- **La densidad se sube según el programa**, que trae una tabla por profundidad.
- **Las pérdidas por filtración dependen de la formación.** Las arenas pierden lodo, y se responde subiendo el controlador de filtrado y con puenteo.
- **Al fallar, el juego explica el porqué.**
- **Los pozos son ficticios.** Los programas públicos sirven solo como patrón.

### Invariantes de diseño

1. **El estado del lodo incluye química** (Pm, Pf, Mf, calcio, cloruros…), no solo física. Los síntomas físicos no distinguen contaminantes; solo las pruebas químicas lo hacen. Ese es el acertijo central.
2. **El núcleo tiene tres fases:** alarma (algo sale de rango) → acertijo (correr las pruebas químicas correctas, que cuestan tiempo) → tratamiento (químico, dosis y verificación).
3. **Contaminantes, pruebas, productos, eventos y niveles son datos** (Resources de Godot), no lógica.
4. **Cada regla evaluable carga su explicación como dato.**
5. **Simulación y presentación van separadas.** La simulación se prueba sin escena visual.
6. **El inventario aprobado del programa es la palanca de dificultad.**

### Lo que ya existe (228 pruebas automáticas pasando)

- **Química del lodo.** El lodo se guarda por composición y las propiedades se derivan de ella. Incluye equilibrio ácido-base con tampón, alcalinidades API, cal en exceso, finos de cemento, Mg(OH)₂ y CaCO₃. Reproduce la tabla de efectos de contaminantes del manual API.
- **7 contaminantes:** cemento, yeso, sal, carbonatos, H₂S, sólidos perforados y carnalita.
- **21 productos con dosis.**
- **Tanques con mezcla y paso de tiempo de 10 min.** Hay homogenización del activo, hidratación de bentonita y asentamiento.
- **17 pruebas de laboratorio y 4 observaciones visuales**, con la resolución de cada instrumento y un planificador de tiempos del laboratorio.
- **19 reglas con explicación** y el programa de lodos de un pozo ficticio en 3 secciones. Hay 7 sistemas de lodo.
- **Perforación por formaciones:** sólidos, arcilla activa, inhibición, consumo de inhibidores y contaminantes de formación. El control de sólidos incluye zaranda, desarenador, deslimador y centrífuga, con fallas.
- **Eventos guionados:** pérdidas, influjo con peso de matada, gas, viajes, sag y fallas de equipo. Hay alarma de nivel de tanques (PVT) con falsas alarmas.
- **Turno de 12 h.** Cada acción cuesta minutos e incluye la caminata hasta su lugar. Hay inventario, costos, reporte diario con balance de volumen y noche simulada.
- **Overworld caminable con 7 personajes y diálogos.** Todavía no está conectado a la simulación.

### Lo que encontró una auditoría (pendiente)

**Crítico**

1. **Las reglas leen el estado real**, así que un aviso al tratar puede revelar el contaminante sin medir. Rompe la invariante 1. *(En arreglo.)*
2. **El volumen no se conserva al vaciarse un tanque**, y falta el volumen mínimo de succión. *(En arreglo.)*
3. **El cemento casi no daña al KCl/PHPA.** Falta que el pH alto y el calcio degraden el PHPA.
4. **El cemento de la zapata se modela como formación perforada**, cuando debería ser cemento rotado dentro del revestidor.
5. **El pozo no tiene composición.** Por eso faltan el retraso de fondo arriba, la interfase de desplazamiento y la ubicación de píldoras.
6. **No hay píldoras ni material de pérdida** (LCM), así que un tratamiento correcto no detiene una pérdida.

**Importante**

- Presión de poro y gradiente de fractura por formación, y ECD con pérdidas inducidas.
- Saturación de sal y solubilidad del yeso.
- El gas mete aire al lodo (espuma, balanza presurizada) y falta un antiespumante.
- Temperatura y degradación de polímeros.
- Lodos base para cada sistema.
- Filtrado por tanque y por hora.
- Faltan productos: antiespumante, biocida, LCM, sulfato de sodio y KOH.
- Faltan pruebas: amina, PHPA, contenido de arena, HTHP y prueba piloto.
- La falsa alarma del PVT no cuesta tiempo.
- El CaCO₃ no se pierde en los equipos de sólidos.

**Mapa**

- El múltiple de transferencia no conecta con el activo.
- Faltan desgasificador, desarenador, deslimador y centrífuga.
- Falta la segunda ruta de retorno (canal y centrífuga) y el depósito de recortes.

**Preguntas de campo que solo yo puedo contestar**

1. ¿Cómo se comporta la soda sobre los carbonatos?
2. ¿Cómo se ve el cemento en un lodo KCl/PHPA, y se pretrata con bicarbonato?
3. ¿Cuántos pies de cemento se rotan y cuándo se hace la prueba FIT/LOT?
4. ¿Cuál es el volumen mínimo en la succión?
5. ¿Cuánto baja la balanza con gas?
6. ¿Qué píldoras se hacen de rutina?
7. ¿El reporte lleva calcio o dureza?
8. ¿Con qué se repone el volumen de noche?
9. ¿Cómo es la logística de camiones y descarte?
10. ¿En qué orden van los compartimientos de tanques?

### Siguiente gran paso previsto

Un **primer día jugable** (vertical slice) en la sección superficial del pozo ficticio CAIMÁN-3:

- conectar el mapa al turno, de modo que caminar e interactuar consuma tiempo y las válvulas muevan lodo;
- pantallas de laboratorio, de tanques y de reporte;
- pruebas básicas, densificar y diluir.

---

## Prompt

Actúa como productor técnico y diseñador de sistemas de un juego educativo-simulador. Con el contexto de arriba, arma un **plan de desarrollo estructurado** para llegar de donde estoy a una versión jugable y luego a una completa.

Quiero, en este orden:

1. **Hitos.** Entre 4 y 7, desde el *primer día jugable* hasta el *pozo completo de 3 secciones con cambio de fluido*. Para cada hito, di qué puede hacer el jugador al terminarlo y un criterio de aceptación verificable.
2. **Tareas de cada hito.** Agrúpalas por área: simulación, datos, interfaz/overworld, contenido y pruebas. Marca las dependencias entre tareas.
3. **Orden de los hallazgos de la auditoría.** Ubica cada uno en un hito. Justifica qué bloquea al núcleo jugable y qué puede esperar.
4. **Preguntas de campo.** Para cada una, indica en qué hito necesito tener la respuesta y qué supuesto provisional puedo usar mientras tanto.
5. **Riesgos.** Los 5 principales (de diseño, de realismo y técnicos), con su mitigación.
6. **Qué NO hacer todavía.** Una lista de cosas para posponer y no dispersarme.

Restricciones:

- Respeta las decisiones cerradas y las invariantes. No propongas modelar solo lo físico, ni que el jugador opere bombas o el BOP, ni pasar a unidades métricas.
- Cada mecánica nueva debe poder expresarse como dato (Resource) más una regla con explicación.
- Prioriza que el núcleo **alarma → pruebas químicas → tratamiento → verificación** sea divertido y justo antes de agregar amplitud.
- Si afirmas algo técnico de la industria, dime si es práctica general o si conviene verificarlo.

Formato: títulos por sección, tablas donde ayuden y frases cortas. Al final, dame los **3 primeros pasos concretos para esta semana**.
