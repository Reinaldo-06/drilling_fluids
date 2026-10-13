# Sistema de tanques del taladro

Cómo está organizado el sistema de superficie, qué contiene cada tanque, cómo se conectan y cómo se mueve el lodo entre ellos. Es la base del **manejo de tanques** y del **cambio de fluido** en el juego.

Documentos hermanos: `docs/domain-research.md` (circulación y control de sólidos, §1) · `docs/mud-engineer-reference.md` (cálculos de tanque, §2; desplazamiento, §4) · `docs/game-design-mechanics.md` (diseño).

> **Nivel de confianza.** La disposición general (secuencia de equipos, sistema activo y reserva, tanque de píldoras, tanque de viaje) está respaldada por las fuentes citadas al final. **El procedimiento de cambio de fluido en superficie (§5)** combina fuentes escasas con lo que el autor confirmó desde su experiencia de campo (marcado como *autor*). Las preguntas que siguen abiertas están en §7.

---

## 1. Idea general

El lodo recorre un circuito cerrado. Sale de los tanques, baja por la sarta, sube por el anular cargado de recortes y vuelve a superficie por el *flowline*. En superficie pasa por los equipos de control de sólidos, en orden de partícula gruesa a fina, y termina en el tanque de succión, de donde las bombas lo vuelven a tomar.

Los tanques son módulos sobre patín de unos 8 ft de alto, 10 ft de ancho y 30 ft de largo, divididos internamente en compartimientos. Los compartimientos se comunican por puertos, vertederos y líneas entre módulos.

**Dos rutas de retorno al activo** (*autor*): una **por la canal**, después de pasar por zarandas, desgasificador, desarenador y deslimador; y otra **por la centrífuga**, que toma lodo de un compartimiento y devuelve el lodo limpio al activo.

```
              ┌──────────── POZO ────────────┐
              │                              │
          flowline                       bombas de lodo
              │                              ▲
              ▼                              │
  ┌───────────────────────────────────────────────────────────────┐
  │ SISTEMA ACTIVO                                                │
  │                                                               │
  │  [caja de llegada] → ZARANDAS → trampa de arena               │
  │                                    │                          │
  │   RUTA 1 — por la canal            ▼                          │
  │   desgasificador → desarenador → deslimador ──┐               │
  │                                               ▼               │
  │   RUTA 2 — por la centrífuga        ┌──────────────────────┐  │
  │   (toma de un compartimiento) ─────►│ TANQUES ACTIVOS      │──┼──► bombas
  │                                     │ (succión + mezcla)   │  │
  │                                     └──────────────────────┘  │
  │                                               ▲               │
  │                          EMBUDO DE MEZCLA ────┘               │
  │                          (hopper)                             │
  └───────────────────────────────────────────────────────────────┘
          ▲  bomba de transferencia / múltiple (válvulas)  │
          │                                                 ▼
  ┌─────────────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
  │ RESERVA 1 · RESERVA 2│ │ FRACTANQUES  │ │ PÍLDORA      │ │ VIAJE        │
  │ lodo nuevo, exceso,  │ │ ~500 bbl c/u │ │ (slug)       │ │ (trip tank)  │
  │ lodo pesado          │ │ almacenaje   │ │ ~70 bbl      │ │ fuera del    │
  │ fuera del activo     │ │ temporal     │ │              │ │ activo       │
  └─────────────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
```

---

## 2. Qué contiene cada tanque

| Tanque / compartimiento | Qué hay dentro | Agitación | Papel en el juego |
|---|---|---|---|
| **Caja de llegada** (*possum belly*) | Retorno del pozo recién salido del flowline | — | Primer lugar para **observar el retorno**: gas, espuma, recortes |
| **Zarandas** (*shale shakers*) | Mallas vibratorias; descartan recortes gruesos (>~100 μm) | — | Observar **cantidad y forma de recortes**; lodo rebosando si está muy viscoso |
| **Trampa de arena** | Primer compartimiento bajo las zarandas; asienta sólidos por gravedad | **No se agita** a propósito | Se vacía por el fondo; descartar es perder volumen |
| **Compartimientos de proceso** | Alimentan y reciben del desgasificador, desarenador, deslimador y centrífuga | Sí | El equipo de sólidos **succiona de un compartimiento y descarga en el siguiente** |
| **Succión** | Lodo ya procesado, listo para bombear | Sí | **Donde se toma la muestra** del lodo que entra al pozo. Suele tener el embudo de mezcla |
| **Reserva** (dos en el layout base, *autor*) | Lodo nuevo, exceso de lodo, otro tipo de lodo o lodo pesado para control de pozo | Según el tanque | **No es parte del sistema activo.** Aquí se construye el lodo nuevo |
| **Fractanques** (*frac tanks*) | Tanques portátiles de almacenaje, ~500 bbl cada uno | Opcional | **Almacenaje temporal** en un cambio de fluido: el lodo viejo o el nuevo mientras se cambia todo el volumen (*autor*) |
| **Píldoras / slug** | Volumen pequeño separado (ej. 73 bbl en un sistema comercial) | Sí | Preparar píldoras sin tocar el activo |
| **Viaje** (*trip tank*) | Tanque pequeño y calibrado para medir el llenado del pozo en maniobras | — | **Del driller.** Contexto: genera avisos de kick o pérdida |

**Agitadores y pistolas de lodo.** Los compartimientos agitados tienen agitadores de impulsor largo para que los sólidos no se asienten. Las pistolas de lodo (*mud guns*) en las esquinas disparan lodo a presión para remover lo asentado. Un tanque sin agitar asienta barita y sólidos en el fondo.

**Tamaño.** El volumen activo va desde unos cientos de barriles en un taladro pequeño de tierra hasta varios miles en aguas profundas. Dos ejemplos comerciales: 620 bbl activos más 73 bbl de píldora, y 1.318 bbl activos. **El tanque de viaje no cuenta** en el volumen activo.

---

## 3. Cómo se conectan

| Conexión | Cómo funciona | Quién la controla en el juego |
|---|---|---|
| **Vertedero / puerto entre compartimientos** | El lodo pasa por gravedad al siguiente compartimiento cuando sube el nivel | Pasivo: siempre abierto en el activo |
| **Línea igualadora** (*equalizer*) | Conecta por el fondo dos módulos para que niveles y lodo se igualen | El jugador la abre o cierra |
| **Succión y descarga de los equipos de sólidos** | Bomba centrífuga toma de un compartimiento, el equipo procesa; el *overflow* limpio va al siguiente compartimiento y el *underflow* sale como descarte | Encender o apagar el equipo (estado del equipo) |
| **Bomba de transferencia y múltiple** | Mueve lodo entre cualquier par de tanques, incluyendo reserva ↔ activo y fractanques | El jugador: **abre y cierra las válvulas**, elige origen, destino y volumen |
| **Embudo de mezcla** (*hopper*) | Embudo donde se vacían los sacos de producto. Abajo tiene un venturi: el lodo pasa a alta velocidad y succiona el polvo hacia la línea, que descarga en el tanque de succión o de mezcla | El jugador: producto, cantidad, tanque destino |
| **Succión de bombas de lodo** | Las bombas toman del último tanque activo de la serie | El driller. El jugador decide **qué tanque es succión** solo en un cambio de fluido |

> **Decisión (*autor*):** en la práctica el ingeniero de lodos da instrucciones y también opera. En el juego, **el jugador camina hasta las válvulas y las mueve él mismo**. Alinear mal una válvula es un error posible y explicable.

> **Relación con la decisión "circulación fuera de alcance".** El juego no simula hidráulica de bombas ni del pozo. Bombear, circular y desplazar se abstraen como *mover X bbl de un tanque al pozo y recibir X bbl del pozo en otro tanque*, con el tiempo de retorno (BU, `mud-engineer-reference.md` §2.5) como reloj. Eso es suficiente para el manejo de tanques y el cambio de fluido sin abrir la expansión de circulación.

---

## 4. Dinámica del lodo en superficie

Estas son las reglas que el modelo de tanques debe respetar. Todas salen del balance de masas y volúmenes de `mud-engineer-reference.md` §2.

1. **Mezclar es promediar por volumen.** Al transferir lodo de A a B, la densidad y las concentraciones del destino quedan como `(V_A·x_A + V_B·x_B) / (V_A + V_B)`. Es la fórmula §2.3 aplicada a cada propiedad que se mezcla linealmente: densidad, concentraciones químicas (Ca²⁺, Cl⁻, productos), % sólidos. **La reología no es lineal**; se aproxima y se calibra jugando.

2. **El sistema activo se homogeniza al circular.** Lo que entra por el embudo de mezcla en el tanque de succión no está en todo el activo de inmediato. Se reparte en **ciclos de circulación**. Por eso un tratamiento tarda en verse en la prueba.

3. **La reserva está aislada.** Una contaminación que llega del pozo afecta solo al activo. El lodo en reserva no se entera. Eso protege el lodo nuevo y hace que transferir desde reserva sea una forma de diluir con lodo limpio.

4. **El volumen se consume.** Cada día de perforación el sistema pierde lodo:
   - **Hueco nuevo:** `bbl = ID² / 1.029 × pies perforados` (§2.5). El pozo se llena con lodo del activo.
   - **Descarte de sólidos:** zarandas, trampa de arena, underflow de hidrociclones.
   - **Pérdidas al pozo** si hay un evento de pérdida de circulación.
   El jugador tiene que **reponer volumen** construyendo lodo en reserva o en mezcla. Es una presión constante de fondo, no un evento.

5. **Densificar y diluir hacen crecer el volumen** (§2.1 y §2.2). Hay que tener capacidad libre. Un activo lleno obliga a mandar lodo a reserva o descartarlo antes de tratar.

6. **Tanque sin agitar = asentamiento.** Barita y sólidos se van al fondo. Transferir desde un tanque asentado manda lodo más liviano y deja el pesado atrás. Hay que agitar antes de usarlo.

7. **El tanque de succión no es el retorno.** La muestra de succión es lo que entra al pozo. Una muestra en la caja de llegada es lo que sale: ahí se ve primero el gas, la espuma o un contaminante que viene del fondo.

---

## 5. Cambio de fluido en superficie

El desplazamiento cambia **todo el volumen**, el del pozo y el de superficie, por un sistema nuevo. En los pozos ficticios ocurre al cambiar de sección, por ejemplo antes de entrar a la sal en MORICHE-12.

### 5.1 Secuencia

1. **Calcular el volumen necesario.** Volumen del pozo (§2.5) más el volumen activo de superficie que va a quedar con el sistema nuevo, más un margen para la interfase.
2. **Reducir el activo a un circuito corto** (*autor*). Se sigue circulando con pocos compartimientos del activo, y así quedan libres los demás tanques para los preparativos.
3. **Construir el lodo nuevo** en las reservas y en los tanques liberados, con el embudo de mezcla, hasta que esté **dentro de la especificación de la nueva sección**. El jugador tiene que correr pruebas sobre el lodo nuevo antes de usarlo.
4. **Preparar dónde va el lodo viejo.** Los **fractanques** reciben el lodo viejo o completan el almacenaje (*autor*). Si no alcanza la capacidad, el cambio se hace **por etapas**, con más riesgo de mezcla.
5. **Desplazamiento directo, sin bache espaciador** (*autor*), entre dos lodos base agua.
6. **Alinear y desplazar.** La succión pasa a la reserva con lodo nuevo. Los retornos se dirigen, en orden:
   - **lodo viejo** → reserva de almacenamiento o descarte;
   - **interfase** (mezcla de los dos) → descarte;
   - **lodo nuevo limpio** → tanques activos.
7. **Detectar la interfase.** Por la densidad en la caja de llegada, cuando los dos lodos difieren en peso, y por lo que se ve en las zarandas. El reloj es el tiempo de retorno: la interfase llega aproximadamente un BU después de empezar a bombear el lodo nuevo.
8. **Reasignar los tanques.** La reserva que tenía el lodo nuevo pasa a ser parte del activo. Verificar el sistema completo con el chequeo de rutina.

### 5.2 Por qué es el nivel más difícil

- **Decisión de desvío.** Desviar los retornos al activo **demasiado pronto** contamina el lodo nuevo con la interfase. **Demasiado tarde** descarta lodo nuevo que costó dinero.
- **Capacidad de superficie.** Hace falta espacio para el lodo nuevo, el viejo y la interfase al mismo tiempo. Las dos reservas no alcanzan para todo el volumen; por eso existen los fractanques y el circuito corto. Con poca capacidad, el desplazamiento por etapas mezcla más.
- **Válvulas.** El jugador las mueve una por una. Una válvula mal alineada manda lodo nuevo al descarte o interfase al activo.
- **Compatibilidad.** Algunos pares de fluidos reaccionan en la interfase. Ejemplo dentro del catálogo: lodo cálcico contra KCl/PHPA, porque el calcio precipita el polímero (ver la tabla de vulnerabilidades de `mud-programs.md`).
- **Todo lo anterior a la vez**: volúmenes, construcción de lodo en especificación, pruebas y tiempo.

---

## 6. Modelo para el juego

Traducción directa a datos, respetando los invariantes de `CLAUDE.md`:

- **Tanque** (Resource): nombre, capacidad (bbl), volumen actual, estado del lodo (físico + químico), `agitado: bool`, `en_sistema_activo: bool`, `rol` (llegada, trampa, proceso, succión, reserva, fractanque, píldora).
- **Conexión** (Resource): origen, destino, tipo (`vertedero`, `igualadora`, `transferencia`, `embudo_mezcla`, `equipo_solidos`, `canal`), y una **válvula** abierta o cerrada que el jugador opera en el overworld.
- **Layout del taladro** (Resource por pozo): la lista de tanques y conexiones. **Cambiar el taladro = cambiar un archivo.** Un taladro con poca reserva hace más difícil el cambio de fluido sin tocar la simulación, igual que el inventario aprobado.
- **Simulación de superficie:** función pura que, dado el layout, el estado de cada tanque y las acciones del turno, devuelve el nuevo estado. Se prueba sin escena visual.

Primer vertical slice (CAIMÁN-3, superficial): un layout mínimo con **trampa de arena, un compartimiento de proceso, succión, una reserva y el tanque de píldoras**. Las dos rutas de retorno, la segunda reserva y los fractanques entran cuando llegue el nivel de cambio de fluido. Suficiente para densificar, diluir, transferir y reponer volumen.

---

## 7. Respuestas del autor y preguntas abiertas

**Respondido:**
- Entre lodos base agua se **desplaza directo**, sin bache espaciador.
- Retornos al activo por **dos rutas**: canal (zarandas → desgasificador → desarenador → deslimador) y centrífuga.
- El **jugador mueve las válvulas**.
- Layout base: **dos reservas** y **fractanques** para almacenar; **circuito corto** en el activo durante los preparativos.

**Abierto:**
1. **Criterio para desviar los retornos** durante el desplazamiento: ¿se decide por densidad en la llegada, por embudo Marsh, a ojo en las zarandas o por emboladas bombeadas? Mientras no se defina, el juego usa densidad y observación en zarandas.
2. **Circuito corto:** ¿qué compartimientos quedan circulando y cuáles se liberan?
3. **Volumen de interfase típico** en un cambio de sistema base agua. Solo encontré un caso de 75 bbl, y era de lodo a fluido de completamiento.
4. **Reutilización del lodo viejo.** ¿Se guarda en fractanques para otro pozo o se descarta casi siempre?

---

## Fuentes

- [Mud tank — Wikipedia](https://en.wikipedia.org/wiki/Mud_tank): compartimientos, trampa de arena, agitadores, pistolas de lodo, línea de succión.
- [US 11713634 — Systems and methods to efficiently cool drilling mud (USPTO)](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11713634): tamaño de módulos, divisiones internas, puertos entre tanques y líneas entre módulos.
- [US 12442261 — Systems and methods to efficiently cool drilling mud (USPTO)](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/12442261): roles de los tanques (asentamiento, activo, slug); la bomba succiona del último tanque activo.
- [BRANDT Ideal Mud Tank System — spec sheet (NOV)](https://assets.nov.com/NCP4N68N/at/npsz7hkgx4stwwpk343x9h/BRANDT_Ideal_Mud_Tank_System_Spec_Sheet_English.pdf): 1.318 bbl activos, trampa de arena con pistola de lodo.
- [BRANDT Rapid Mud Tank System (NOV)](https://assets.nov.com/NCP4N68N/at/gm24g4r6hpw7vhjptmr45/BRANDT_Rapid_Mud_Tank_System_English.pdf): 620 bbl activos, tanque de píldora de 73 bbl, igualadora de fondo, tanque de viaje fuera del volumen activo.
- [Calculating drilling fluid volume — DEV Community](https://dev.to/__b202a7ac/calculating-drilling-fluid-volume-for-various-well-comprehensive-guides-2217): sistema activo frente a reserva; rango de volúmenes.
- [Shell offshore drilling — discharge of drilling mud (informe de incidente)](https://www.sites.google.com/site/metropolitanforensics/accident-investigation-report--shell-offshore-drilling-discharge-of-drilling-mud-in-the-gulf-of-mexico): definición y uso del tanque slug.
- [US 10857488 — System for separating solids from a fluid stream (USPTO)](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10857488): hidrociclones que succionan de un compartimiento; overflow al siguiente, underflow a descarte; vertederos.
- [Deepwater fluid displacement needs special approaches — Oil & Gas Journal](https://www.ogj.com/general-interest/companies/article/17224301/special-report-deepwater-fluid-displacement-needs-special-approaches): desplazamiento directo e indirecto, espaciadores, capacidad de superficie.
- [Rotating and reciprocating swivel apparatus and method — US 9546531 (USPTO)](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9546531): desplazamiento por etapas cuando falta almacenamiento y riesgo de mezcla.
- [Drilling fluid displacement process — US 4474240 (USPTO)](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/4474240): la densidad como indicador de la interfase.
- [Mud engineer's guidelines on his/her first hitch — LinkedIn](https://www.linkedin.com/pulse/mud-engineers-guidelines-hisher-first-hitch-ejabofo-aghomishe): observar las zarandas durante el desplazamiento; reasignar tanques de reserva a activo.
- [Exceptional Displacement and Wellbore Cleanup — JPT (SPE)](https://jpt.spe.org/exceptional-displacement-and-wellbore-cleanup): ejemplo de 75 bbl de interfase.
- [45ft Frac Tank — SCF](https://scf.com.au/products-services/tank-containers/frac-tanks/45ft-frac-tank): fractanque de 500 bbl (77 m³) para almacenar lodo.
- [Name that oil and gas storage container — FracTracker](https://www.fractracker.org/2015/02/name-that-storage-container): fractanques en sitio de perforación.
