# Sistema de tanques del taladro

Cómo está organizado el sistema de superficie, qué contiene cada tanque, cómo se conectan y cómo se mueve el lodo entre ellos. Es la base del **manejo de tanques** y del **cambio de fluido** en el juego.

Documentos hermanos: `docs/domain-research.md` (circulación y control de sólidos, §1) · `docs/mud-engineer-reference.md` (cálculos de tanque, §2; desplazamiento, §4) · `docs/game-design-mechanics.md` (diseño).

> **Nivel de confianza.** La disposición general (secuencia de equipos, sistema activo y reserva, tanque de píldoras, tanque de viaje) está respaldada por las fuentes citadas al final. **El procedimiento de cambio de fluido en superficie (§5) es una síntesis**: las fuentes públicas lo cubren poco. Está escrito para que el autor, que trabaja en la industria, lo valide o corrija. Las preguntas abiertas están en §7.

---

## 1. Idea general

El lodo recorre un circuito cerrado. Sale de los tanques, baja por la sarta, sube por el anular cargado de recortes y vuelve a superficie por el *flowline*. En superficie pasa por los equipos de control de sólidos, en orden de partícula gruesa a fina, y termina en el tanque de succión, de donde las bombas lo vuelven a tomar.

Los tanques son módulos sobre patín de unos 8 ft de alto, 10 ft de ancho y 30 ft de largo, divididos internamente en compartimientos. Los compartimientos se comunican por puertos, vertederos y líneas entre módulos.

```
              ┌──────────── POZO ────────────┐
              │                              │
          flowline                       bombas de lodo
              │                              ▲
              ▼                              │
  ┌───────────────────────────────────────────────────────────────┐
  │ SISTEMA ACTIVO                                                │
  │                                                               │
  │  [caja de llegada] → ZARANDAS                                  │
  │                         │                                     │
  │                         ▼                                     │
  │  ┌─────────────┬──────────────┬──────────────┬──────────────┐ │
  │  │ TRAMPA DE   │ DESGASIFIC.  │ DESARENADOR  │  SUCCIÓN     │ │
  │  │ ARENA       │ / DESLIMADOR │ / CENTRÍFUGA │  (+ mezcla)  │─┼──► bombas
  │  │ sin agitar  │ agitado      │ agitado      │  agitado     │ │
  │  └─────────────┴──────────────┴──────────────┴──────────────┘ │
  │        flujo por vertedero / puertos  ───────────►            │
  │                                                 ▲             │
  │                                         HOPPER ─┘             │
  └───────────────────────────────────────────────────────────────┘
          ▲  bomba de transferencia / múltiple  │
          │                                      ▼
  ┌──────────────────────┐   ┌────────────────┐   ┌───────────────┐
  │ RESERVA 1 / RESERVA 2│   │ TANQUE PÍLDORA │   │ TANQUE VIAJE  │
  │ lodo nuevo, exceso,  │   │ (slug)         │   │ (trip tank)   │
  │ lodo pesado          │   │ ~70 bbl        │   │ fuera del     │
  │ fuera del activo     │   │                │   │ activo        │
  └──────────────────────┘   └────────────────┘   └───────────────┘
```

---

## 2. Qué contiene cada tanque

| Tanque / compartimiento | Qué hay dentro | Agitación | Papel en el juego |
|---|---|---|---|
| **Caja de llegada** (*possum belly*) | Retorno del pozo recién salido del flowline | — | Primer lugar para **observar el retorno**: gas, espuma, recortes |
| **Zarandas** (*shale shakers*) | Mallas vibratorias; descartan recortes gruesos (>~100 μm) | — | Observar **cantidad y forma de recortes**; lodo rebosando si está muy viscoso |
| **Trampa de arena** | Primer compartimiento bajo las zarandas; asienta sólidos por gravedad | **No se agita** a propósito | Se vacía por el fondo; descartar es perder volumen |
| **Compartimientos de proceso** | Alimentan y reciben del desgasificador, desarenador, deslimador y centrífuga | Sí | El equipo de sólidos **succiona de un compartimiento y descarga en el siguiente** |
| **Succión** | Lodo ya procesado, listo para bombear | Sí | **Donde se toma la muestra** del lodo que entra al pozo. Suele tener el hopper |
| **Reserva** | Lodo nuevo, exceso de lodo, otro tipo de lodo o lodo pesado para control de pozo | Según el tanque | **No es parte del sistema activo.** Aquí se construye el lodo nuevo |
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
| **Bomba de transferencia y múltiple** | Mueve lodo entre cualquier par de tanques, incluyendo reserva ↔ activo | El jugador: **origen, destino, volumen** |
| **Hopper** | Venturi que succiona producto en polvo o líquido hacia el flujo; suele descargar en succión o en mezcla | El jugador: producto, cantidad, tanque destino |
| **Succión de bombas de lodo** | Las bombas toman del último tanque activo de la serie | El driller. El jugador decide **qué tanque es succión** solo en un cambio de fluido |

> **Relación con la decisión "circulación fuera de alcance".** El juego no simula hidráulica de bombas ni del pozo. Bombear, circular y desplazar se abstraen como *mover X bbl de un tanque al pozo y recibir X bbl del pozo en otro tanque*, con el tiempo de retorno (BU, `mud-engineer-reference.md` §2.5) como reloj. Eso es suficiente para el manejo de tanques y el cambio de fluido sin abrir la expansión de circulación.

---

## 4. Dinámica del lodo en superficie

Estas son las reglas que el modelo de tanques debe respetar. Todas salen del balance de masas y volúmenes de `mud-engineer-reference.md` §2.

1. **Mezclar es promediar por volumen.** Al transferir lodo de A a B, la densidad y las concentraciones del destino quedan como `(V_A·x_A + V_B·x_B) / (V_A + V_B)`. Es la fórmula §2.3 aplicada a cada propiedad que se mezcla linealmente: densidad, concentraciones químicas (Ca²⁺, Cl⁻, productos), % sólidos. **La reología no es lineal**; se aproxima y se calibra jugando.

2. **El sistema activo se homogeniza al circular.** Lo que entra por el hopper en el tanque de succión no está en todo el activo de inmediato. Se reparte en **ciclos de circulación**. Por eso un tratamiento tarda en verse en la prueba.

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

## 5. Cambio de fluido en superficie (síntesis, por validar)

El desplazamiento cambia todo el lodo del pozo y de superficie por un sistema nuevo. En los pozos ficticios ocurre al cambiar de sección, por ejemplo antes de entrar a la sal en MORICHE-12.

### 5.1 Secuencia propuesta

1. **Calcular el volumen necesario.** Volumen del pozo (§2.5) más el volumen activo de superficie que va a quedar con el sistema nuevo, más un margen para la interfase.
2. **Construir el lodo nuevo en reserva.** En tanques aislados del activo, con hopper o mezcla, hasta que esté **dentro de la especificación de la nueva sección**. El jugador tiene que correr pruebas sobre el lodo nuevo antes de usarlo.
3. **Decidir qué se hace con el lodo viejo.** Guardarlo en otra reserva si se va a reutilizar, o descartarlo. Si no hay capacidad, el cambio no se puede hacer de una vez y se hace **por etapas**, con más riesgo de mezcla.
4. **Bache espaciador** (opcional según el par de fluidos). Un volumen intermedio compatible con ambos fluidos que separa el viejo del nuevo. Las fuentes lo exigen en desplazamientos a fluido de completamiento; para un cambio entre dos lodos base agua puede no hacer falta.
5. **Alinear y desplazar.** La succión pasa a la reserva con lodo nuevo. Los retornos se dirigen, en orden:
   - **lodo viejo** → reserva de almacenamiento o descarte;
   - **interfase** (mezcla de los dos) → descarte;
   - **lodo nuevo limpio** → tanques activos.
6. **Detectar la interfase.** Por la densidad en la caja de llegada, cuando los dos lodos difieren en peso, y por lo que se ve en las zarandas. El reloj es el tiempo de retorno: la interfase llega aproximadamente un BU después de empezar a bombear el lodo nuevo.
7. **Reasignar los tanques.** La reserva que tenía el lodo nuevo pasa a ser parte del activo. Verificar el sistema completo con el chequeo de rutina.

### 5.2 Por qué es el nivel más difícil

- **Decisión de desvío.** Desviar los retornos al activo **demasiado pronto** contamina el lodo nuevo con la interfase. **Demasiado tarde** descarta lodo nuevo que costó dinero.
- **Capacidad de superficie.** Hace falta espacio para el lodo nuevo, el viejo y la interfase al mismo tiempo. Con poca capacidad, el desplazamiento por etapas mezcla más.
- **Compatibilidad.** Algunos pares de fluidos reaccionan en la interfase. Ejemplo dentro del catálogo: lodo cálcico contra KCl/PHPA, porque el calcio precipita el polímero (ver la tabla de vulnerabilidades de `mud-programs.md`).
- **Todo lo anterior a la vez**: volúmenes, construcción de lodo en especificación, pruebas y tiempo.

---

## 6. Modelo para el juego

Traducción directa a datos, respetando los invariantes de `CLAUDE.md`:

- **Tanque** (Resource): nombre, capacidad (bbl), volumen actual, estado del lodo (físico + químico), `agitado: bool`, `en_sistema_activo: bool`, `rol` (llegada, trampa, proceso, succión, reserva, píldora).
- **Conexión** (Resource): origen, destino, tipo (`vertedero`, `igualadora`, `transferencia`, `hopper`, `equipo_solidos`), abierta o cerrada.
- **Layout del taladro** (Resource por pozo): la lista de tanques y conexiones. **Cambiar el taladro = cambiar un archivo.** Un taladro con poca reserva hace más difícil el cambio de fluido sin tocar la simulación, igual que el inventario aprobado.
- **Simulación de superficie:** función pura que, dado el layout, el estado de cada tanque y las acciones del turno, devuelve el nuevo estado. Se prueba sin escena visual.

Primer vertical slice (CAIMÁN-3, superficial): un layout mínimo con **trampa de arena, un compartimiento de proceso, succión, una reserva y el tanque de píldoras**. Suficiente para densificar, diluir, transferir y reponer volumen.

---

## 7. Preguntas para el autor

Cosas que las fuentes públicas no resuelven y que conviene validar con experiencia de campo:

1. **Desplazamiento entre dos lodos base agua.** ¿Se usa bache espaciador o se desplaza directo? ¿Cómo se decide en la práctica cuándo desviar retornos al activo: densidad, viscosidad de embudo, a ojo en las zarandas, por emboladas?
2. **Volumen de interfase típico** en un cambio de sistema base agua. Solo encontré un caso de 75 bbl, y era de lodo a fluido de completamiento.
3. **Quién mueve las válvulas de tanques en la práctica.** ¿El ingeniero de lodos da la instrucción y el encuellador (*derrickman*) las opera? Afecta si el jugador "camina hasta la válvula" o "da la orden".
4. **Layout típico en tu experiencia.** ¿Cuántos tanques de reserva, dónde va el hopper, el tanque de píldoras es independiente o un compartimiento?
5. **Reutilización del lodo viejo.** ¿Se guarda para otro pozo o se descarta casi siempre?

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
