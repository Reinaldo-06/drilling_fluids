# Lógica de simulación — verificación contra fuentes

Documento de trabajo para que la dinámica del juego se comporte **como un simulador**. Cada regla de simulación se contrasta con fuentes públicas antes de entrar al diseño.

Documentos hermanos: `docs/game-design-mechanics.md` (diseño) · `docs/rig-tank-system.md` (tanques) · `docs/mud-engineer-reference.md` (datos del manual).

## Protocolo de verificación

- Cada dato se contrasta con **al menos dos fuentes independientes**. Patentes, glosarios técnicos (SLB), wikis profesionales (AAPG, PetroWiki), manuales públicos y publicaciones del sector cuentan. Material de proveedores cuenta como fuente, pero se marca.
- Cada regla lleva una marca de confianza:
  - ✅ **verificado**: dos o más fuentes coinciden.
  - ⚠️ **una fuente**: falta contrastar.
  - 🧩 **diseño**: decisión de juego o síntesis propia, no un hecho de campo.
  - 👷 **autor**: confirmado por la experiencia de campo del autor.
- **Videos de YouTube:** no son accesibles desde la sesión en la nube (la red bloquea el dominio). Si el autor encuentra videos útiles, puede pegar la transcripción en el chat y se procesa igual que cualquier otra fuente.

## Temas

| # | Tema | Estado |
|---|---|---|
| 1 | Parámetros que se ven en el taladro | ✅ hecho |
| 2 | Tiempos de circulación: emboladas, retorno de fondo, ciclo completo | ✅ hecho |
| 3 | Frecuencia de pruebas y puntos de muestreo | ✅ hecho |
| 4 | Monitoreo de volumen de tanques y falsas alarmas | ✅ hecho |
| 5 | Quién hace qué en la cuadrilla (encuellador, mud logger, driller, company man) | ✅ hecho |
| 6 | Cómo cambian las propiedades al perforar: sólidos, temperatura, degradación | ✅ hecho |
| 7 | Control de sólidos: eficiencia de cada equipo, tasa de dilución | ✅ hecho (faltan % de eficiencia por equipo) |
| 8 | Mezcla con el embudo: sacos por hora, tiempo de hidratación de bentonita y polímeros | ✅ hecho |
| 9 | Reporte diario de lodo: qué contiene, costos, inventario | ✅ hecho |
| 10 | Eventos: pérdidas, influjo, gas de conexión, maniobras (viajes) desde la vista del ingeniero | ✅ hecho |
| 11 | Temperatura del lodo: entrada y salida, efecto en reología | ✅ hecho |
| 12 | **Modelo consolidado**: variables de estado y qué cambia en cada hora de juego (une los temas 1–11) | ✅ hecho (propuesta) |
| 13 | Lutitas reactivas e inhibición: sales, aminas, PHPA, prueba de K⁺ | ✅ hecho |
| 14 | Lodo de matada: cómo prepara el ingeniero el peso de matada y el lodo pesado de reserva | ✅ hecho |
| 15 | Asentamiento de barita (*sag*) en tanques y en el pozo | ✅ hecho |

---

## 1. Parámetros que se ven en el taladro

**Qué es real.** La consola del driller y el sistema de registro muestran de forma continua: profundidad, **ROP** (tasa de penetración), **WOB** (peso sobre la broca), **RPM**, **torque**, **carga en el gancho** (*hookload*), **presión de bomba** (*standpipe*), **emboladas y caudal** de bombas, **flujo de retorno** (% de flujo en el flowline) y **volumen de tanques**. ✅
El WOB no se mide en la broca: se calcula a partir de la carga en el gancho. ✅

**Cómo entra al juego.**
- En el **piso de perforación** hay un panel de solo lectura con estos parámetros. El jugador no los controla (decisión cerrada: no opera bombas ni perforación), pero los **lee** y le dan información. 🧩
- Los que alimentan la simulación del lodo:
  - **ROP y diámetro** → cuánto sólido perforado entra al lodo por hora y cuánto hueco nuevo hay que llenar. 🧩
  - **Caudal de bombas** → velocidad de circulación (tema 2).
  - **Volumen de tanques y flujo de retorno** → detección de pérdidas o influjo (tema 4).
- Torque, hookload y presión de bomba pueden mostrar síntomas de problemas del pozo (empaquetamiento, limpieza deficiente), que se leen **cruzando varios canales**, no uno solo. ⚠️ (una fuente informal; contrastar en el tema 10)

Fuentes: [Cornell University Borehole Observatory — Pason drilling parameters (GDR / OpenEI)](https://gdr.openei.org/submissions/1849) · [US 4507735 — Method and apparatus for monitoring and controlling well drilling parameters](https://patents.justia.com/patent/4507735) · [Estimation of the free rotating hook load for WOB estimation (UiS)](https://uis.brage.unit.no/uis-xmlui/handle/11250/3018193) · [Multi-parameter drilling instrumentation system (proveedor)](https://www.goldsupplier.com/provide/p119545127.html)

---

## 2. Tiempos de circulación

**Qué es real.** ✅ (AAPG Wiki, Drilling Manual, ToolGrit coinciden en método)

```
Salida de bomba (bbl/emb)   = desplazamiento teórico × eficiencia volumétrica (~95 %)
Capacidad (bbl/ft)          = ID² / 1.029,4
Volumen anular (bbl/ft)     = (D_hueco² − D_tubería²) / 1.029,4
Emboladas superficie→broca  = volumen interno de la sarta / salida por embolada
Emboladas de retorno (lag)  = volumen anular / salida por embolada
Tiempo (min)                = emboladas / emboladas por minuto
```

Ejemplo de AAPG: bomba triplex de 0,0962 bbl/emb al 95 % → 0,0914 bbl/emb. Un anular de 378,9 bbl son 4.146 emboladas, unos **42 min a 98 emb/min**.

Las fórmulas son las mismas de `mud-engineer-reference.md` §2.5, así que hay coherencia con el manual.

**Cómo entra al juego.**
- **Retorno de fondo** (*bottoms up*): cuánto tarda en llegar a superficie lo que pasa en el fondo. Un contaminante perforado aparece en la caja de llegada **un retorno después** de entrar al lodo. 🧩
- **Ciclo completo** = (volumen del pozo + volumen activo de superficie) / caudal. Es el tiempo que tarda un tratamiento en **homogenizarse** en todo el sistema. 🧩
- **Ejemplo de calibración** para CAIMÁN-3 superficial (cálculo propio con las fórmulas de arriba): hueco de 17½" a 2.000 ft con tubería de 5" → anular ≈ 546 bbl. A 600 gpm (≈ 14,3 bbl/min) el retorno de fondo es ≈ **38 min**. Con 600 bbl en superficie, el ciclo completo es ≈ **84 min**. Un tratamiento tarda alrededor de hora y media en verse parejo en las pruebas. 🧩

Fuentes: [AAPG Wiki — cálculo de lag](https://wiki.aapg.org/Special:MobileDiff/1399) · [Lag Time In Drilling — Drilling Manual](https://www.drillingmanual.com/drilling-lag-time-calculations-calculator/) · [Lag Time Planning Guide — ToolGrit](https://www.toolgrit.com/guides/lag-time-bottoms-up)

---

## 3. Frecuencia de pruebas y puntos de muestreo

**Qué es real.**
- El ingeniero llena el **reporte de lodo** cada día, con resultados de pruebas hechas **varias veces al día**, más uso de productos, inventario y recomendaciones. ✅ (SLB Glossary, Rigzone)
- Los procedimientos estándar de prueba para lodos base agua están en **API RP 13B-1** (densidad, viscosidad y geles, filtrado, agua/aceite/sólidos, arena, pH, alcalinidad, cloruros). ✅
- **Puntos de muestreo:** tanque activo (bien mezclado), flowline (retorno) y succión. ✅ (coincide con `rig-tank-system.md` §4, regla 7)
- **Frecuencias de referencia** de una guía del sector (no del estándar API): densidad, viscosidad de embudo y pH **por parada o cada hora**; reología completa, geles, filtrado API y cloruros **2 a 4 veces al día**; retorta y HTHP **una vez al día**. ⚠️ (una fuente; contrastar)

**Cómo entra al juego.** Esto ajusta el diseño del chequeo de rutina:
- **Chequeos rápidos frecuentes** (densidad, embudo, pH): varias veces por turno, **los hace el propio jugador** y cuestan **10 min de juego como máximo** en total. Son la segunda capa de alarma, junto con la observación visual. 👷
- **Chequeo completo** (Fann, geles, filtrado, químicas): una o dos veces por turno de 12 h, en vez de "uno al inicio". 🧩
- **Retorta**: una vez al día, no en cada chequeo. 🧩
- En el campo, las mediciones rápidas las hace un técnico de la empresa de fluidos. En el juego **las hace el jugador** para mantenerlo en el ciclo de observación. 👷

Fuentes: [Mud report — SLB Energy Glossary](https://glossary.slb.com/en/terms/m/mud_report) · [How to perform mud testing during drilling operations — Rigzone](https://www.rigzone.com/insights/operational-questions-8/how-to-perform-mud-testing-during-drilling-operations-1009) · [API RP 13B-1 (ficha del estándar)](https://standards.nimonik.com/products/api/rp-13b-1/) · [What does testing tell me about drilling fluids — The Driller](https://www.thedriller.com/articles/91946-what-does-testing-tell-me-about-drilling-fluids?v=preview)

---

## 4. Monitoreo de volumen de tanques

**Qué es real.**
- El **totalizador de volumen de tanques** (PVT) mide el volumen de los tanques activos y alarma ante cambios inesperados. ✅ (Pason, patentes)
- Si nadie movió lodo en superficie: **ganancia de volumen → posible influjo (kick)**; **pérdida → posible pérdida de circulación**. ✅
- **Las transferencias entre tanques generan falsas alarmas**: el sistema las confunde con ganancias o pérdidas del pozo. ✅ (dos patentes)
- El nivel de tanques **reacciona tarde**; la medición de flujo en el flowline detecta antes. ✅
- Que el pozo siga fluyendo con bombas apagadas puede ser un kick, pero también expansión térmica, compresibilidad o "respiración" del pozo. ⚠️

**Cómo entra al juego.** Mecánica directa:
- **Avisar antes de transferir.** Si el jugador mueve lodo entre tanques activos o desde reserva sin avisar al driller y al mud logger, el PVT dispara una alarma falsa: se para la perforación, se pierde tiempo y el driller se queja. El juego explica por qué. 🧩
- **Pérdida o ganancia real** llega como evento: el jugador la ve en el nivel de tanques o se la informan. Su trabajo es la respuesta de fluidos (material de pérdida, densificar), no el control del pozo. 🧩

Fuentes: [Pit Volume Totalizer — Pason](https://pason.com/products/pit-volume-totalizer-pvt) · [US 6234250 — Real time wellbore pit volume monitoring](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/6234250) · [WO 2021087509 — Automated kick and loss detection](https://patents.google.com/patent/WO2021087509A1) · [Insights into automatic gain/loss detection (SPE)](https://file.streaming.spe.org/wp-content/uploads/2024/02/22130907/Insights-Into-the-Physical-Phenomena-That-Influence-Automatic-GainLoss-Detection-During-Drilling-Operations.pdf) · [Offshore Engineer, sep/oct 2014](https://magazines.marinelink.com/Magazines/OffshoreEngineer/201409/page/66)

---

## 5. Quién hace qué en la cuadrilla

**Qué es real.**
- **Toolpusher**: jefe del taladro en sitio, responsable de todas las cuadrillas. ✅ (Wikipedia *Roughneck*, Motive)
- **Driller** (perforador): dirige su cuadrilla y opera el taladro desde la consola; mantiene los parámetros de perforación. ✅
- **Encuellador** (*derrickman*): además de trabajar en la torre durante los viajes, se ocupa del sistema de lodo: **mide densidad y viscosidad de embudo, mezcla químicos, vigila el nivel de los tanques y reporta pérdidas o ganancias al driller**. Depende del driller, pero en lo químico **sigue las instrucciones del ingeniero de lodos**. ✅ (Drilling Manual, Wikipedia, varias ofertas de empleo)
- **Company man**: representante de la operadora en sitio. Hace cumplir el programa de perforación aprobado y supervisa la calidad de los servicios de terceros, incluido el de lodos. Reporta al superintendente de perforación. ✅ (Penn State PNG 301, Rigzone, ofertas de empleo)
- **Mud logger**: monitorea gas, recortes y parámetros para evaluación geológica; es un rol distinto al de ingeniero de lodos. ⚠️ (una fuente los confunde; se toma como distintos por el resto del material)
- A quién reporta el ingeniero de lodos **depende del contrato**. Las fuentes no lo fijan. ⚠️

**Cómo entra al juego.** Personajes no jugables, cada uno con un papel claro:
- **Driller**: informa profundidad, formación y eventos al inicio del turno; **hay que avisarle antes de transferir** (tema 4). 🧩
- **Encuellador**: en el campo hace parte del trabajo de tanques. En el juego **el jugador hace sus propias mediciones** (decisión del autor), pero el encuellador puede **ejecutar mezclas largas** en el embudo cuando el jugador se las ordena, liberando tiempo del turno a cambio de supervisar el resultado. 👷
- **Company man**: recibe el reporte diario y evalúa contra el programa de lodos. Es quien **pide explicaciones** cuando algo sale de especificación o el costo sube. 🧩
- **Mud logger**: avisa de gas y cambios en recortes; otra fuente de alarma. 🧩

Fuentes: [Roughneck — Wikipedia](https://en.wikipedia.org/wiki/Roughneck) · [Derrickhand — Wikipedia](https://en.wikipedia.org/wiki/Derrickhand) · [Derrickman Job Description — Drilling Manual](https://www.drillingmanual.com/derrickman-job-description-requirements-role/) · [Drilling crew — Motive](https://gomotive.com/glossary/oil-and-gas/drilling-crew/) · [Derrickhand — oferta de empleo (Seventy Seven Energy)](https://app.energyhire.com/job-board/derrickhand-oklahoma-el-reno-ok-48f08ca7-2847-4b7d-bdaf-2d60ff14c836) · [Derrickman — Lewis Energy](https://uscareers-lewisenergy.icims.com/jobs/11143/derrickman/job) · [Company man — Penn State PNG 301](https://www.e-education.psu.edu/png301/node/900) · [Well site supervisor — Rigzone](https://www.rigzone.com/insights/job-descriptions-2/responsibilities-of-a-well-site-supervisor-in-oil-operations-249) · [Mud Man — oferta de empleo](https://jobnow.ng/mud-man-at-an-oil-and-gas-drilling-services-company-myrtle-management-consultants-limited/)

---

## 6. Cómo cambian las propiedades al perforar

### 6.1 Entrada de sólidos

**Qué es real.**
- El volumen de sólidos que genera la broca sale del diámetro, la ROP y la porosidad de la formación: `sólidos (bbl/h) = capacidad del hueco (bbl/ft) × ROP (ft/h) × (1 − porosidad)`. Ejemplo publicado: hueco de 26", ROP 62 ft/h, porosidad 0,25 → **~30 bbl/h** de sólidos que el equipo tiene que remover. ✅ (el ejemplo cuadra con la fórmula de capacidad de §2: 26²/1.029,4 × 62 × 0,75 = 30,5)
- **Eficiencia de remoción** = sólidos removidos / sólidos generados por la broca. Lo que no se remueve se queda en el lodo. ✅ (dos fuentes; definición de API RP 13C)
- Para mantener los sólidos perforados por debajo de un máximo hay que **diluir**. API RP 13C compara la dilución necesaria con remoción contra la que haría falta sin remoción. ✅
- Con **sólidos de baja gravedad por encima de 3–5 %** la tasa de penetración cae de forma importante. ⚠️ (una fuente)

**Cómo entra al juego.**
- Cada hora de perforación entra al lodo `generados × (1 − eficiencia)` de sólidos perforados. Sube el % LGS, la PV y el MBT si la formación es arcillosa. 🧩
- La **eficiencia** depende del estado del equipo de sólidos (zarandas con mallas buenas, desarenador, deslimador y centrífuga encendidos). Un equipo apagado o una malla rota sube la entrada de sólidos. Valores concretos: tema 7. 🧩
- Ejemplo de calibración, CAIMÁN-3 superficial (cálculo propio): 17½", ROP 80 ft/h, porosidad 0,30 → 0,2975 × 80 × 0,70 ≈ **17 bbl/h generados**. Con 80 % de eficiencia quedan ≈ **3,3 bbl/h** en el sistema. 🧩

### 6.2 Temperatura

**Qué es real.**
- Al subir la temperatura, los lodos base agua con polímeros **se adelgazan**: en un estudio con CMC/PAC de 20 a 80 °C la PV cayó 78,5 % y el esfuerzo de corte 58,8 %. ✅ (estudio de laboratorio + patente)
- Excepción: en lodos con mucha arcilla, la temperatura puede **dispersar y flocular** las arcillas y **espesar** el lodo. ✅ (patente; coincide con el manual sobre floculación térmica del lodo cálcico, `mud-programs.md`)
- Los polímeros naturales y modificados (almidón, CMC) **se degradan** a alta temperatura (sobre ~115 °C según una revisión) y son atacados por bacterias. ✅ (revisión + `mud-engineer-reference.md` §1.5 sobre fermentación del almidón y biocidas + `domain-research.md` §3)

**Cómo entra al juego.**
- Las pruebas de superficie se corren a temperatura de superficie. El juego puede mostrar que **el lodo en fondo es más delgado** que lo que mide el Fann en la caseta, y que en pozos calientes los polímeros se gastan más rápido (hay que reponer más). 🧩
- Fermentación del almidón: sin biocida o sin salinidad alta, el almidón se degrada con los días y **sube el filtrado**. Otra causa de alarma que no es contaminación. 🧩

Fuentes: [US 8522896 — Consistent drilling fluids engineering and management](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/8522896) · [Solids Control Systems — Oil & Gas Journal](https://www.ogj.com/home/article/17297942/solids-control-systems-scs) · [Drilled-solids removal system performance — IADC Lexicon](https://iadclexicon.org/glossary/global-standards/page/164/) · [AADE — cálculos de remoción y dilución (API RP 13C)](https://www.aade.org/download_file/force/4755/649) · [Jurnal Teknologi (UTM) — LGS y ROP](https://journals.utm.my/jurnalteknologi/article/download/9091/5416/25260) · [Solids control — Drilling Manual](https://www.drillingmanual.com/solids-control/) · [US 9518434 — Managing properties of a circulating wellbore fluid](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9518434) · [Safi et al., Int. J. Applied Mechanics and Engineering, 2023](https://doaj.org/article/7e8976cba55b48ad8c3370a7009f5250) · [Revisión de polímeros para lodos base agua (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC7178333)

---

## 7. Control de sólidos

**Qué es real.**
- Cada equipo tiene un **punto de corte**: el tamaño de partícula del que descarta la mitad. Valores típicos: **desarenador ~40 μm** (rango 45–74 μm según la fuente), **deslimador ~20 μm** (rango 15–44 μm). Las zarandas sacan lo grueso (>~100 μm, según la malla) y la **centrífuga** llega a los finos. ✅ (Drilling Manual, Triflo, varias fichas; coincide con `domain-research.md` §1)
- **La barita mide entre 2 y 80 μm.** Por eso, con lodo densificado, **el desarenador y el deslimador botan barita** por el *underflow* (cerca de la mitad). En lodo densificado se usa la **centrífuga para recuperar barita** y descartar sólidos livianos, a menudo dos centrífugas en serie. ✅ (Drilling Manual, patente US 3964557, OneMine, Trenchless Technology)
- La centrífuga trabaja sobre una **derivación** del activo: no pasa todo el volumen por ella. ✅
- No encontré porcentajes de eficiencia confiables por equipo; dependen del modelo y del estado. ⚠️

**Cómo entra al juego.**
- Cada equipo tiene un interruptor y un estado (mallas buenas o rotas, conos tapados). La eficiencia total del tema 6.1 sale de los equipos encendidos. Los porcentajes se calibran jugando. 🧩
- **Trampa realista:** con lodo densificado, dejar encendidos desarenador y deslimador **baja la densidad y bota barita** (plata). Lo correcto es apagarlos y usar la centrífuga. El juego explica por qué. 🧩
- Con lodo sin densificar, los hidrociclones son la herramienta barata contra el PV alto, antes que diluir. 🧩

Fuentes: [Solids Control Equipment in Oil & Gas — Drilling Manual](https://www.drillingmanual.com/solids-control-equipment-in-oil-gas/) · [Solids Control Equipment — Triflo](https://triflo.com/?p=1287) · [US 3964557 — Treatment of weighted drilling mud](https://patents.google.com/patent/US3964557) · [Mechanical Treatment of Weighted Drilling Muds — OneMine](https://onemine.org/documents/drilling-fluids-and-cement-mechanical-treatment-of-weighted-drilling-muds) · [Decanter centrifuges for barite recovery — Trenchless Technology](https://digital.trenchlesstechnology.com/articles/common-challenges-relative-to-the-use-of-decanter-centrifuges-for-barite-recovery) · [US 10233706 — Recovering barite from drilling fluid](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10233706)

---

## 8. Mezcla con el embudo

**Qué es real.**
- El embudo es un venturi: una bomba centrífuga pasa lodo a alta velocidad por una boquilla bajo el cono y succiona el producto seco, que se dispersa e hidrata. ✅ (SLB Glossary, Trenchlesspedia, proveedor)
- **Ritmo de mezcla de barita con embudo convencional: ~200–300 sacos/h.** Una persona cortando sacos sola: **~40–50 sacos/h**. Los sistemas a granel (silos) son mucho más rápidos. ⚠️ (una fuente con cifras; el uso de silos de barita a granel lo confirma también Wikipedia *Derrickhand*)
- **El embudo no es el cuello de botella.** Una ficha de proveedor da 990 ft³/h de barita en polvo a 1.000 gpm (~61 t/h, más de 1.000 sacos/h; la ficha escribe "2.100 lb/h", que no cuadra con las otras dos cifras y debe ser por minuto). El ritmo real lo pone **la gente que corta y vacía sacos**. ✅ (ficha del proveedor + la guía anterior coinciden en que el límite es manual)
- Regla práctica de campo: sacos de barita por cada 100 bbl = `1.470 × (W2 − W1) / (35 − W2)`, la misma fórmula del manual. ✅ (Drilling Formulas, KWS, `mud-engineer-reference.md` §2.1)
- **Prehidratar** bentonita y polímeros (como XC) en agua dulce antes de agregarlos a un lodo salado o muy tratado mejora su rendimiento. La bentonita **no hidrata** en salmuera. ✅ (SLB Glossary, estudio Trisakti, `mud-engineer-reference.md` §1.5)
- **Tiempo de prehidratación de la bentonita: 4 a 6 h** según guías de campo. Mínimo citado: 2–3 h; laboratorio: hasta 16 h. Toma **más tiempo o no hidrata** si el agua es dura, si el pH está fuera de 8,5–9,5 o si hay cloruros altos. Dejarla toda la noche es seguro, pero ninguna fuente lo exige. ✅ (Drilling for Gas, Globat Mud School, estudio de cemento en Geofluids, Lone Star Drills)
- Bentonita sin hidratar se ve como "requesón" en la malla del embudo Marsh. Los polímeros agregados muy rápido forman **ojos de pescado** (grumos sin dispersar). ✅ (The Driller, patente)

**Cómo entra al juego.**
- **Ritmos de mezcla del juego** (punto de partida, a calibrar jugando): 🧩
  - **Encuellador solo: 50 sacos/h.** Es la mezcla normal del turno. 👷 (confirmado por el autor)
  - **Encuellador + cuadrilla de piso: 250 sacos/h.** Solo cuando el driller presta gente: en una emergencia (kick, densificar a peso de matada) o si el jugador lo pide y el driller acepta.
- **Densificar lleva horas.** El ejemplo del manual (1.548 sacos de barita, `mud-engineer-reference.md` §2.1) son **~6 h con cuadrilla** o **~31 h con el encuellador solo**. Por eso densificar a peso de matada es una carrera contra el tiempo, y por eso conviene tener lodo pesado en reserva. 🧩
- **El encuellador mezcla** (decisión del autor): el jugador ordena producto, cantidad, embudo y tanque; el encuellador tarda según el ritmo de sacos. Mientras tanto, el jugador hace otra cosa. 👷
- **Bentonita prehidratada**: se prepara en un tanque de reserva con agua dulce tratada. **Rinde de forma gradual y llega al 100 % a las 6 h** (rango de campo 4–6 h; el autor estimó 8 h, que queda como margen seguro). Usarla antes rinde menos viscosidad. El jugador puede ver el avance con el embudo Marsh o a ojo (grumos tipo "requesón" en la malla). Con agua dura, pH fuera de 8,5–9,5 o salinidad alta, hidrata más lento o no hidrata, y el juego explica por qué. 🧩
- **Polímeros a la carrera** → ojos de pescado: el producto rinde menos y aparece la observación de grumos en la malla. 🧩

Fuentes: [Mud hopper — SLB Energy Glossary](https://glossary.slb.com/terms/m/mud_hopper) · [Mud hopper — Trenchlesspedia](https://trenchlesspedia.com/definition/4208/mud-hopper-horizontal-directional-drilling) · [Ritmos de mezcla de barita — oilandgasbmps.org](https://oilandgasbmps.org/view.php?id=4540) · [Drilling fluid mixing hopper — PP Drilling Fluids (proveedor)](https://ppdrillingfluids.in/drilling-fluid-mixing-hopper/) · [Prehydration — SLB Energy Glossary](https://glossary.slb.com/terms/p/prehydration) · [Prehidratación de bentonita — Trisakti](https://e-journal.trisakti.ac.id/index.php/petro/article/download/16154/9498) · [Tips for productivity on HDD mixing systems — The Driller](https://thedriller.com/articles/91812-tips-for-productivity-on-hdd-mixing-systems) · [Derrickhand — Wikipedia](https://en.wikipedia.org/wiki/Derrickhand) · [Mixing Hoppers — ficha de proveedor (HMHW)](https://hmhw.com/wp-content/uploads/2023/09/Mixing-Hoppers.pdf) · [Increase mud weight by adding barite — Drilling Formulas](https://www.drillingformulas.com/increase-mud-weight-by-adding-barite/) · [Increase Mud Weight — KWS](https://docs.kws.tn/formulas/3/mud-weight.html) · [Bentonite Mud — Drilling for Gas](https://drillingforgas.com/drilling-fluids/mud-types/bentonite-mud/) · [How to mix bentonite spud mud on the rig — Globat Mud School](https://blog.globatmudschool.com/how-to-mix-bentonite-spud-mud-on-the-rig/) · [Effect of bentonite prehydration time — Geofluids (Wiley), 2021](https://onlinelibrary.wiley.com/doi/10.1155/2021/9957159) · [Drilling Mud Guide — Lone Star Drills](https://www.lonestardrills.com/everything-you-need-to-know-about-mud/) · [Prehydrate — SLB Energy Glossary](https://glossary.slb.com/en/terms/p/prehydrate)

---

## 9. Reporte diario de lodo

**Qué es real.** El reporte diario incluye: ✅ (SLB Glossary, PetroSkills, OilGasLeads, plantillas públicas de reporte)
- **Propiedades**: densidad de entrada y salida, reología (VP, PC, geles), filtrado, químicas (pH, cloruros, alcalinidades, dureza).
- **Análisis de sólidos**: sólidos de alta y baja gravedad, sólidos perforados.
- **Horas de uso de los equipos de control de sólidos.**
- **Temperatura** de entrada y salida del pozo (exigida en al menos un reglamento público).
- **Productos usados**, inventario y **costo del día y acumulado**.
- **Contabilidad de volumen**: de dónde salió y a dónde fue cada barril.
- **Recomendaciones** para el turno siguiente.

**Cómo entra al juego.** Es el cierre del día (paso 8 del ciclo). 🧩
- El reporte **se llena solo con las pruebas que el jugador corrió**. Una casilla vacía es visible y el company man la pregunta.
- **Balance de volumen**: volumen inicial + lodo construido − hueco nuevo − descarte de sólidos − pérdidas = volumen final. Si no cuadra, hay una pérdida que nadie vio. Es un acertijo propio.
- **Costo acumulado contra presupuesto** de la sección: el company man reacciona si se pasa.
- **Recomendaciones**: el jugador elige qué deja indicado para el día siguiente; el debrief compara con lo que pasó.

Fuentes: [Mud report — SLB Energy Glossary](https://glossary.slb.com/en/terms/m/mud_report) · ["Clear as Mud?" How to read a mud report — PetroSkills](https://petroskills.com/mudwebinar) · [How to decode a Daily Drilling Report — OilGasLeads](https://oilgasleads.com/how-to-decode-a-daily-drilling-report-ddr/) · [Daily mud reports, pozo geotérmico HON-GT-01 (plantilla pública)](https://geothermie.nl/images/Onderzoeken-en-rapporten/31_07_15_Verstoppingen/E15014_appx_3.4_GWW_HON-GT-01-S2_Daily_mud_reports.pdf) · [Annex 5 — Daily Drilling Report (Autoridad danesa)](https://offshore.at.dk/en/regulations/wea-guidelines/well-operations/annex-5/)

---

## 10. Eventos desde la vista del ingeniero

### 10.1 Pérdida de circulación

**Qué es real.** La clasificación por tasa **varía entre fuentes y operadoras**. Rangos frecuentes para lodo base agua: ✅ (varias fuentes coinciden en el orden de magnitud, no en los cortes)
- **Filtración** (*seepage*): hasta ~10–25 bbl/h.
- **Parcial**: ~25–100 bbl/h (hay fuentes que la extienden mucho más).
- **Severa**: >100 bbl/h, hasta 500 bbl/h o más.
- **Total**: no vuelve lodo a superficie.
- El tipo de formación importa tanto como la tasa (alta permeabilidad, fisuras, fracturas). ✅
- Ojo: con la ROP también se va lodo pegado a los recortes; hay que descontarlo antes de declarar una pérdida. ⚠️

**Cómo entra al juego.** 🧩
- El evento llega por el **nivel de tanques** (tema 4) o por el driller. El jugador mide la tasa con el balance de volumen.
- Respuesta de fluidos según la severidad: filtración → material de pérdida fino en el sistema; parcial → **píldora de material de pérdida** (`mud-engineer-reference.md` §3); severa o total → píldora más grande, bajar densidad si la ventana lo permite y avisar al company man.
- Mientras tanto hay que **reponer volumen** rápido, lo que se cruza con los ritmos de mezcla (tema 8).

### 10.2 Gas

**Qué es real.** ✅ (AAPG Wiki, Spec2000, Rigzone)
- **Gas de fondo** (*background*): el que sale al triturar la roca; es la línea base.
- **Gas de conexión**: entra cuando se paran las bombas para hacer una conexión. Significa que en ese momento el lodo está **bajo balance** en alguna zona.
- **Gas de viaje**: el que aparece después de sacar o meter tubería, al circular el fondo arriba.
- Gas de fondo en aumento y picos de conexión **anuncian una zona permeable o con sobrepresión**. El mud logger avisa al driller y al company man, que pueden pedir **subir densidad**.

**Cómo entra al juego.** 🧩
- El mud logger reporta gas de fondo y picos de conexión. Si los picos crecen, el company man pide subir la densidad (por ejemplo +0,2 ppg) y el jugador ejecuta la densificación.
- El gas llega a superficie **un retorno de fondo después** (tema 2) y se ve como espuma o burbujas, con la balanza leyendo bajo (observación visual).

### 10.3 Maniobras (viajes)

**Qué es real.** Durante un viaje no se perfora; el pozo se llena desde el tanque de viaje y el gas de viaje aparece al volver a circular. ✅ (temas 4 y 10.2)

**Cómo entra al juego.** 🧩 Un viaje es un tiempo sin entrada de sólidos ni consumo de hueco, ideal para tratar el sistema, construir lodo y preparar píldoras. Al volver a circular puede aparecer gas de viaje.

Fuentes: [Pérdidas de circulación — Univ. de Bagdad](https://joe.uobaghdad.edu.iq/index.php/main/article/download/210/184/361) · [Lost circulation zones and LCM strategy — iFactory](https://ifactoryapp.com/industries/oil-and-gas/lost-circulation-zones-lcm-treatment-strategy) · [Loss of Circulation Guide — Chevron Phillips](https://www.cpchem.com/sites/default/files/2020-04/LOSS%20OF%20CIRCULATION%20Guide.pdf) · [US 10479918 — Two-component lost circulation pill](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10479918) · [Universidad de Benin — pérdidas de circulación](https://repository.uniben.edu/sites/default/files/2026-04/FINAL.pdf) · [AAPG Wiki — gas de fondo, conexión y viaje](https://wiki.aapg.org/Special:MobileDiff/16391) · [Mud logging basics — Spec2000](https://spec2000.net/log-data-acquisition/logging-mud-logging-and-mud-gas-logging-mwd.htm) · [Role of mud logging — Rigzone](https://www.rigzone.com/insights/how-it-works-3/what-is-the-role-of-mud-logging-in-monitoring-drilling-conditions-545)

---

## 11. Temperatura del lodo

**Qué es real.**
- El lodo sale del pozo más caliente de lo que entra; el reporte registra **temperatura de entrada y salida**. ✅ (tema 9)
- Es habitual reportar la reología **a 120 °F** (49 °C) y no a temperatura ambiente, para acercarse a las condiciones de flowline. ✅ (boletín de producto Newpark + estudio PMC con pruebas a 120 °F)
- El gradiente geotérmico y el caudal son los factores que más pesan en la temperatura del lodo en el pozo. La expansión térmica del lodo puede bajar su densidad efectiva en pozos calientes. ⚠️
- No hay un valor estándar de temperatura en el flowline; depende del pozo. ⚠️

**Cómo entra al juego.** 🧩
- El Fann de la caseta tiene una **copa térmica**: la prueba se corre a 120 °F. Correrla en frío da lecturas más altas que las reales y el juego lo puede marcar.
- Temperatura de salida = función de la profundidad y del caudal (modelo simple, a calibrar). Sirve para el efecto de la temperatura en la reología (tema 6.2) y para la degradación de polímeros.

Fuentes: [Temperature-dependent behaviour of WBM rheological models (PMC)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6197678/) · [TerraTherm product bulletin — Newpark](https://www.newpark.com/assets/pdfs/TerraTherm%20Product%20Bulletin.pdf) · [Drilling fluid rheology in geothermal drilling, a review — Geothermics](https://gdr.openei.org/files/1446/Geothermics_Significance%20and%20complications%20of%20drilling%20fluid%20rheology%20in%20geothermal%20drilling%20A%20review.pdf) · [US 6807854 — Thermal profile of a drilling fluid](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/6807854) · [Energies 10(3):268 (2017)](https://ideas.repec.org/a/gam/jeners/v10y2017i3p268-d91303.html)

---

## 12. Modelo consolidado de simulación

Une los temas 1–11 en una sola lógica. Todo este tema es **diseño** 🧩 construido sobre reglas ya verificadas; cada paso cita el tema de origen.

### 12.1 Idea central: guardar composición, derivar propiedades

El estado de cada tanque **no guarda PV, YP ni filtrado**. Guarda **de qué está hecho el lodo**, y las propiedades se calculan a partir de eso cuando alguien corre una prueba.

| Grupo | Variables guardadas |
|---|---|
| Volumen | bbl, temperatura |
| Fases | % agua, % aceite, **% barita**, **% sólidos livianos** (bentonita + perforados), **aire atrapado** |
| Química del agua | pH, OH⁻ libre, Ca²⁺, Mg²⁺, Na⁺, Cl⁻, K⁺, CO₃²⁻, HCO₃⁻, SO₄²⁻, sulfuros |
| Productos | lb/bbl activos de cada producto (bentonita hidratada, lignosulfonato, lignito, PAC/almidón, XC, PHPA, amina, cal en exceso…) y su **edad** (para hidratación y degradación) |
| Alcalinidad sin disolver | **cal en exceso** (lb/bbl): cal y finos de cemento; separa Pm de Pf·Fw |
| Alcalinidad orgánica | aporte de lignosulfonato y lignito a Pf y Mf |

**La floculación es la pieza clave.** No se guarda: **se calcula** a partir de la química del agua (calcio, magnesio, cloruros, Mf alto, sulfuros), escalada por el MBT y descontando el desfloculante. Así, al tratar la causa química la floculación baja sola. Todo contaminante químico **sube la floculación**; los desfloculantes la bajan. De la floculación salen YP, geles y filtrado. Así, **por construcción, los síntomas físicos de todos los contaminantes químicos se parecen**, y lo único que los distingue es la química del agua. El invariante 1 queda garantizado por el modelo, no por cuidado al escribir cada contaminante. (`mud-engineer-reference.md` §1.1)

**Propiedades derivadas** (funciones puras, se calibran jugando):
- Densidad ← fases (balance de masas, `mud-engineer-reference.md` §2), menos el aire si la balanza no es presurizada (observación visual).
- **PV ← sólidos** (% livianos y barita) + polímeros + temperatura. (§5.1 del manual; tema 6.2)
- **YP y geles ← floculación** + bentonita + XC. (§5.2 del manual)
- Filtrado ← bentonita, controladores de filtrado vivos (no degradados) y floculación.
- Pm, Pf, Mf, dureza, cloruros ← química del agua directamente.
- MBT ← bentonita + arcilla perforada.

### 12.2 Paso de simulación

**Un paso = 10 min de juego.** Las tasas están en "por hora" y se escalan. Orden de cada paso:

1. **Perforación** (si el driller está perforando): profundidad += ROP. El hueco nuevo se llena con lodo del activo. Entran sólidos `capacidad × ROP × (1 − porosidad)`. La formación del programa aporta su contaminante si corresponde. (temas 1, 6.1)
2. **Control de sólidos**: cada equipo encendido remueve su fracción. Los hidrociclones con lodo densificado botan barita. Todo descarte resta volumen. (tema 7)
3. **Acciones en curso**: transferencias por válvulas abiertas, mezcla del encuellador a 50 sacos/h o 250 con cuadrilla, prehidratación avanzando. (temas 4, 8; `rig-tank-system.md` §4)
4. **Química y cinética**: los tratamientos reaccionan de a poco, la bentonita hidrata hasta llegar al 100 % a las 6 h, los polímeros se degradan con la temperatura y las bacterias, entra CO₂ por el embudo. (temas 6.2, 8; `mud-engineer-reference.md` §1.7)
5. **Homogenización**: el activo se mezcla en un ciclo completo `(volumen del pozo + activo) / caudal`. Lo que pasa en el fondo llega a la caja de llegada un retorno de fondo después. (tema 2)
6. **Eventos**: los guionados del nivel y los aleatorios (pérdidas, gas). (tema 10)
7. **Detección**: el PVT compara volumen esperado contra real. Una transferencia sin avisar dispara una falsa alarma. Se actualizan las observaciones visuales. (temas 4, 11; observación visual)

### 12.3 Tiempo del jugador

- Caminar, observar, correr pruebas y mover válvulas **consumen minutos** del reloj del turno. Al avanzar el reloj corren los pasos de simulación que correspondan.
- Las pruebas con espera (geles, filtrado, retorta) corren en paralelo al jugador.
- Una prueba **lee el estado en el momento y lugar de la muestra**: succión, caja de llegada o un tanque. Si el lodo cambió después, la prueba ya está vieja.

### 12.4 Contaminante como dato

Cada contaminante (un Resource) declara, por unidad que entra:
- qué agrega a la **química del agua** (por ejemplo, cemento: Ca²⁺ + OH⁻; yeso: Ca²⁺ + SO₄²⁻ y baja el pH; sal: Na⁺ + Cl⁻);
- cuánto sube la **floculación**, escalado por el MBT (`mud-engineer-reference.md` §1.1: MBT < 15 lb/bbl → poco efecto);
- la **vulnerabilidad por sistema** (`mud-programs.md`, tabla de vulnerabilidades);
- sus **tratamientos válidos e inválidos**, cada uno con su explicación (invariante 4).

### 12.5 Calibración inicial (CAIMÁN-3 superficial)

| Dato | Valor | Origen |
|---|---|---|
| Retorno de fondo | ~38 min | tema 2 |
| Ciclo completo | ~84 min | tema 2 |
| Sólidos generados | ~17 bbl/h | tema 6.1 |
| Sólidos que quedan (80 % de eficiencia) | ~3,3 bbl/h | tema 6.1 |
| Mezcla normal | 50 sacos/h | tema 8 👷 |
| Bentonita al 100 % | 6 h | tema 8 |
| Chequeo rápido | ≤ 10 min | tema 3 👷 |

---

## 13. Lutitas reactivas e inhibición

Las arcillas de la lutita absorben agua, se hinchan y se dispersan. Eso desestabiliza el pozo, ensucia el lodo con arcilla fina (sube MBT, PV y YP) y hace recortes blandos que se pegan a la broca. Se combate con **tres familias de inhibidores** que actúan de forma distinta y se combinan.

### 13.1 Sales

**Qué es real.**
- **KCl**: el K⁺ reemplaza a los cationes hidratados de la arcilla y mantiene unidas sus láminas. Es muy eficaz en lutitas con **alta capacidad de intercambio** (montmorillonita, illita). En lutitas ricas en **caolinita** puede debilitarlas. ✅ (Drilling Manual, patente US 6818596, estudio ACS 2025)
- **Otras sales (NaCl, CaCl₂, formiato de potasio)**: bajan la **actividad del agua** del lodo y así frenan el paso de agua hacia la lutita por ósmosis. ✅ (Drilling Manual, patentes)
- **CaCl₂** es la sal divalente más barata y el calcio inhibe, pero puede dejar la arcilla **blanda y pegajosa**. ⚠️
- Concentraciones de estudios: KCl eficaz desde **1–2 % en peso** en algunas formaciones; **7 %** con glicol en otra. No hay un valor universal: depende de la lutita. ✅ (dos estudios coinciden en que depende de la formación)
- **El K⁺ se consume** en las arcillas; **el Cl⁻ se queda** en el agua. ✅ (SLB Glossary, Drilling Manual)
- Hay límites ambientales al cloruro que se puede descartar (en EE. UU., 3.000 ppm en la locación). ⚠️

**Trampa realista:** medir **cloruros** para estimar cuánto KCl queda **engaña**. Los cloruros siguen altos mientras el potasio ya se gastó, así que la inhibición parece buena cuando no lo es. La SLB cuenta que esto le dio mala fama a los primeros lodos de potasio. El jugador tiene que correr la **prueba de K⁺**, no fiarse de los cloruros. ✅

### 13.2 Aminas

**Qué es real.**
- Las aminas (poliaminas, éter-aminas) se **protonan** en el agua, reemplazan a los cationes de la arcilla y se pegan a las láminas por atracción electrostática y puentes de hidrógeno. Actúan **como el potasio pero más fuerte**: se meten entre las láminas e impiden que entre agua. ✅ (patente CN 104592955, estudio PMC, varias patentes)
- Dosis en patentes: **1–18 lb/bbl**, preferida **2–12 lb/bbl**; otra patente da **0,5–10 lb/bbl**. La dosis exacta se ajusta **probando con la lutita del pozo**. ✅ (varias patentes coinciden)
- Se usan como **inhibidor principal**, con el **PHPA como secundario**: la amina trabaja entre las láminas y el PHPA, que es una molécula grande, por fuera. ✅ (Drilling Manual + estudio de lodos de alto desempeño con aminas)
- En lodos con PHPA el **pH se mantiene cerca de 9,0**: un pH alto dispersa las arcillas e **hidroliza el PHPA**, liberando amoníaco. ✅ (Drilling Manual + estudio Trisakti, pH 9 estable)
- Existen pruebas colorimétricas para medir la amina en el lodo. ⚠️ (patente US 11401805)

### 13.3 PHPA

**Qué es real.** ✅ (temas anteriores + patentes)
- **Encapsula** recortes y recubre la pared: los recortes no se hidratan ni se pegan entre sí ni a la broca.
- Se gasta pegado a los recortes que salen por las zarandas.
- Es sensible al **pH alto** (hidrólisis, sobre todo en caliente), al **calcio** y a la **sal**. Por eso una contaminación de cemento es catastrófica en el sistema KCl/PHPA (`mud-programs.md`).

### 13.4 Cómo se mide en el campo

- **Prueba de K⁺** (API): al filtrado se le agrega perclorato de sodio, que precipita perclorato de potasio. Se centrifuga y el volumen del precipitado se convierte a K⁺ con una **curva de calibración** hecha en el taladro. Sirve para K⁺ alto (> 5.000 mg/l). Para K⁺ bajo hay una titulación con tetrafenilborato. ✅ (SLB Glossary, Drilling Manual, API RP 13B de 1980)
- **MBT** en aumento: entra arcilla activa que no se está inhibiendo. ⚠️ (tema 13 original)
- **Pruebas de inhibición de laboratorio**: dispersión por rolado en caliente (10 g de recortes, 16 h a 150 °F, se tamiza y se pesa lo recuperado), hinchamiento lineal y tiempo de succión capilar. Se usan para **elegir el inhibidor y la dosis** antes de perforar, no durante el turno. ✅ (revisión KFUPM, patentes, AADE)

### 13.5 Cómo entra al juego

🧩 Todo lo de esta sección es diseño sobre lo anterior.

- **Lutita como dato del nivel**: cada formación declara su **reactividad** (capacidad de intercambio) y su **tipo de arcilla** (montmorillonita, illita, caolinita). Eso decide qué inhibidor funciona: el KCl ayuda en montmorillonita e illita y **puede empeorar la caolinita**.
- **Inhibición del sistema** = combinación de K⁺, amina activa, PHPA activo y actividad del agua (sal). Cada hora en lutita reactiva:
  - se consumen K⁺, amina y PHPA en proporción a los sólidos perforados (tema 6.1);
  - la arcilla que no queda inhibida entra como **arcilla activa** y sube MBT, PV y YP;
  - los recortes se ven **blandos y pegajosos** en las zarandas (observación visual) y aumenta el riesgo de embolamiento.
- **Pruebas**: se agregan a las ampliadas la **prueba de K⁺** (propuesta: 20 min, necesita filtrado) y la **prueba de amina** (propuesta: 15 min).
- **Trampas**:
  - cloruros altos ≠ potasio suficiente (13.1);
  - subir el pH con soda cáustica en un sistema con PHPA lo hidroliza (13.2);
  - KCl en lutita de caolinita (13.1);
  - echar más inhibidor no siempre arregla el embolamiento (tema 13 original).
- **Planificación**: antes de una sección con lutita reactiva, el jugador puede pedir una **prueba de inhibición a la base** con recortes de pozos vecinos (resultado al día siguiente) para elegir el inhibidor y la dosis. Es la versión de juego de "probar con la lutita del pozo".

Fuentes: [Shale inhibitor mechanisms & products — Drilling Manual](https://www.drillingmanual.com/shale-inhibitor-mechanisms/) · [Assessment of KCl inhibition efficiency — Ind. Eng. Chem. Res. (ACS)](https://pubs.acs.org/iecred/article/64/45/21523/3735166/Assessment-of-KCl-Inhibition-Efficiency-in-Water) · [Laboratory evaluation of shale inhibitors (Kurdistan)](https://d-nb.info/1202239749/34) · [US 6355600 — CaCl₂ con poliacrilamida catiónica](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/6355600) · [Water-based glycol drilling muds — OSTI](https://www.osti.gov/biblio/372394) · [Potassium ion — SLB Energy Glossary](https://glossary.slb.com/en/terms/p/potassium_ion) · [Potassium ion & KCl test — Drilling Manual](https://www.drillingmanual.com/potassium-ion-kcl-in-drilling-fluid-test/) · [US 9574126 — Glycol ether amines como inhibidores](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9574126) · [US 7572756 — Shale hydration inhibition agent](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/7572756) · [CN 104592955 — Polyamine shale inhibitor](https://patents.google.com/patent/CN104592955A/en) · [Melamine cross-linked polyammonium inhibitor (PMC)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5915987/) · [Polyamine inhibitor effects on hydrated shale — ScienceDirect](https://www.sciencedirect.com/science/article/pii/S2405656122000177) · [High-performance WBM based on amine derivatives — ResearchGate](https://www.researchgate.net/publication/241788564_Development_of_High-Performance_Water-Based_Mud_Formulation_Based_on_Amine_Derivatives) · [Water based drilling fluid systems — Drilling Manual](https://www.drillingmanual.com/water-based-drilling-fluid-systems/) · [Polyamine vs KCl polymer mud — Trisakti](https://e-journal.trisakti.ac.id/index.php/jeeset/article/view/22150) · [US 11401805 — Colorimetric detection of amine inhibitors](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11401805) · [US 7351680 — High performance water-based mud system](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/7351680) · [US 4526693 — Shale and salt stabilizing drilling fluid](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/4526693) · [Experimental methods for testing inhibitors — KFUPM](https://pure.kfupm.edu.sa/en/publications/experimental-and-analytical-methods-for-testing-inhibitors-and-fl/) · [Bit balling — Journal of Petroleum Research (RIPI)](https://pr.ripi.ir/article_1493_en.html)

---

## 14. Lodo de matada

**Qué es real.**
- **Lodo de matada**: lodo lo bastante pesado para que su presión hidrostática detenga el influjo. Tiene que estar **disponible rápido**, o se puede perder el control del pozo. ✅ (SLB Glossary, `domain-research.md` §4.1 con la fórmula del peso de matada)
- Se prepara **densificando parte del sistema o un lodo de reserva** con barita. ✅ (SLB Glossary, material de curso)
- Si el lodo ya tiene muchos sólidos, densificarlo sin diluir antes puede dejarlo **demasiado espeso para bombear**. Una **prueba piloto** en el laboratorio dice cuánto diluir antes de agregar la barita. ⚠️ (SLB Glossary; coherente con `mud-engineer-reference.md` §2.4 y §5.1)
- La barita es el producto que **más se consume** en un pozo. ✅ (dos fuentes)
- No encontré una norma pública de stock mínimo de barita en sitio; depende del operador y de la jurisdicción. ⚠️

**Cómo entra al juego.** 🧩
- Ante un kick, el driller entrega la presión de cierre y el jugador calcula el **peso de matada** (`domain-research.md` §4.1) y los **sacos** (`mud-engineer-reference.md` §2.1).
- Con 250 sacos/h (tema 8), el tiempo de preparación es el reloj del evento. **Tener lodo pesado en reserva** o barita suficiente en bodega decide si la emergencia sale bien.
- **Prueba piloto** como acción de laboratorio general: el jugador mezcla una muestra pequeña con el tratamiento que piensa aplicar y ve el resultado antes de gastar producto en el sistema. Cuesta tiempo (propuesta: 15 min), pero evita errores caros. Sirve para cualquier tratamiento, no solo para densificar.

Fuentes: [Kill-weight mud — SLB Energy Glossary](https://glossary.slb.com/en/terms/k/kill-weight_mud) · [Weighted mud — SLB Energy Glossary](https://glossary.slb.com/en/terms/w/weighted_mud) · [Mud weighting — SlideShare](https://www.slideshare.net/slideshow/mud-weighting/56307173) · [Especificación de barita — OGDCL](https://ogdcl.com/sites/default/files/tender-file/18088.PDF) · [Mud Weight Window — AES Fluids](https://aesfluids.com/?p=1456)

---

## 15. Asentamiento de barita (*sag*)

**Qué es real.**
- La barita se asienta sobre todo a **bajas tasas de corte**: lodo poco viscoso a baja velocidad, sin circular o en pozos desviados. Hay sag **estático** (sin circulación) y **dinámico** (circulando lento). ✅ (varios artículos AADE, OGJ, Drilling Manual)
- La lectura de **6 RPM** del Fann es una aproximación gruesa del riesgo; los **geles** ayudan a evitar el sag estático. ✅
- La mayoría de los casos de campo revisados coincidieron con **bajar revestimiento**, sobre todo **después de adelgazar el lodo**. ⚠️ (una fuente)
- Se han visto variaciones de densidad de hasta **±4 ppg en el flowline** al circular después de un sag. ✅ (AADE + OGJ)
- En tanques, sin agitación, la barita también se asienta (`rig-tank-system.md` §4, regla 6). ✅

**Cómo entra al juego.** 🧩
- Si el jugador **adelgaza demasiado un lodo densificado** (6 RPM y geles bajos) y luego hay un tiempo sin circular (viaje, revestimiento), al volver a circular el chequeo rápido de densidad en la caja de llegada muestra **lodo liviano y después pesado**. Es una consecuencia retardada de una decisión anterior.
- Es una trampa del tipo "arreglé un problema y creé otro": bajar viscosidad para controlar la PV puede causar sag.

Fuentes: [Barite sag causes, indications & prevention — Drilling Manual](https://drillingmanual.com/barite-sag-prevention-causes-indications) · [Monitoring of barite sag important in deviated drilling — Oil & Gas Journal](https://www.ogj.com/home/article/17238331/monitoring-of-barite-sag-important-in-deviated-drilling) · [AADE — barite sag](https://www.aade.org/download_file/2687/490) · [AADE — barite sag (2)](https://www.aade.org/download_file/1439/396) · [Rheological characterization — Nordic Rheology Society](https://nordicrheologysociety.org/Content/Transactions/2003/Ahmadi%20Tehrani%20Rheological%20Characterization%20of%20Oil-Based%20Drilling%20Fluids%20%E2%80%93.pdf)

### 12.6 Implementación (estado actual)

- `sim/estado_lodo.gd`: estado por composición y propiedades derivadas.
  - Alcalinidades con las **relaciones API**: `Pf = OH⁻/340 + CO₃²⁻/1200`, `Mf = OH⁻/340 + CO₃²⁻/600 + HCO₃⁻/1220` (mg/l), más el aporte orgánico. `Pm = Pf·Fw + cal en exceso / 0,26`, que es la fórmula del manual al revés.
  - Reacciones del manual como completas: HCO₃⁻ + OH⁻ → CO₃²⁻; cal + 2 HCO₃⁻ → CaCO₃ + CO₃²⁻; Ca²⁺ + CO₃²⁻ → CaCO₃; Mg²⁺ + 2 OH⁻ → Mg(OH)₂.
  - La cal se disuelve hasta saturar (pH ≈ 12,4); el resto queda en exceso.
  - Un ácido consume, en orden: OH⁻, CO₃²⁻ → HCO₃⁻, alcalinidad orgánica, cal en exceso (libera Ca²⁺) y HCO₃⁻.
- `sim/contaminante.gd` + `data/contaminantes/*.tres`: cemento, yeso, sal, carbonatos, H₂S y sólidos perforados como datos.
- `tests/test_tabla4.gd`: **los seis contaminantes reproducen las 12 flechas de la Tabla 4.**
- `sim/producto.gd` + `data/productos/*.tres`: 15 productos (soda cáustica, carbonato y bicarbonato de sodio, SAPP, ácido cítrico, cal, yeso, óxido de cinc, lignosulfonato, PAC, XC, bentonita, barita, KCl, agua). Los químicos declaran su **reacción por mol** y su peso molecular; la conversión lb/bbl → mmol/l usa Fw igual que las fórmulas del manual, así **la dosis calculada con la Tabla 2 trata exactamente lo medido**.
- **Regla de orden de las reacciones:** bicarbonatos y carbonatos consumen primero la **cal sólida** y después lo disuelto (es lo que suponen las fórmulas de tratamiento del manual). Los ácidos atacan primero lo disuelto.
- `tests/test_tratamientos.gd`: cada contaminación tratada con la dosis del manual. Resultados que salen solos del modelo y conviene conocer:
  - **Bicarbonato sobre cemento** con la dosis de exceso de cal elimina la cal sólida pero **deja soda en solución**: el Pm baja, el Pf sube y el calcio disuelto sigue. Hace falta un segundo tratamiento (SAPP o ácido cítrico) para bajar pH y calcio.
  - **Carbonato de sodio sobre cemento** deja todavía más alcalinidad: es la trampa del manual.
  - **Con cal en exceso**, el carbonato de sodio se gasta primero en ella y la dosis calculada con el calcio no alcanza. Hay que mirar el Pm antes de tratar el calcio.
  - **Cal sobre bicarbonatos** con la dosis 1:1 elimina los carbonatos pero deja el pH sobre 11,3: por eso el manual pide combinar cal y yeso según el pH.
- **Pendiente de calibrar:** el pH no tiene amortiguación fuera de OH⁻ y carbonatos. Sin alcalinidad cae a 7 (en el campo quedaría cerca de 8,5–9) y 0,1 lb/bbl de soda lo sube a casi 12. Las constantes de VP, PC, geles y filtrado son provisionales.
- **Sólidos nuevos** (la fila de la Tabla 4 que mueve todo) queda para cuando exista la perforación en el paso de simulación.

### 12.7 Primera ronda de agentes (integrada)

Cuatro agentes trabajaron en paralelo, cada uno con archivos propios. Resumen de lo integrado:

**Química (agente B)** — `sim/estado_lodo.gd`
- **Equilibrio ácido-base:** cada cambio conserva la alcalinidad total y el carbono inorgánico; el pH sale de repartirlos entre OH⁻, CO₂/HCO₃⁻/CO₃²⁻ (pKa 6,35 y 10,33) y un **tampón** de lignosulfonato y bentonita (pKa 8,5/9,5/10,5 🧩). Pf y Mf suman la base del tampón.
- Capacidad del lignosulfonato anclada a la regla de SLB "1 saco de soda por 4 de lignosulfonato" ✅ ([Caustic soda](https://www.slb.com/products-and-services/innovating-in-oil-and-gas/well-construction/drilling-fluids/drilling-fluid-additives/alkalinity-control/caustic-soda), [SPERSENE](https://www.slb.com/products-and-services/innovating-in-oil-and-gas/well-construction/drilling-fluids/drilling-fluid-additives/thinners-and-dispersants/spersene-chrome-lignosulfonate)).
- Resultado: yeso, sal y H₂S bajan el pH a 8,9–9,4 (antes 7); desde pH 8,5, 0,25 lb/bbl de soda → 9,5 y 0,5 → 10,5.
- El lignosulfonato entra ácido y rinde menos bajo pH 9,5. CaCO₃ precipita hasta un Ksp efectivo (1e-8 🧩); Mg(OH)₂ precipita y **se redisuelve si baja el pH** (§1.6). ZnO + HS⁻ → ZnS + OH⁻.
- **Carnalita** como contaminante; dureza total y de calcio por separado.
- `mezclar()` y `equilibrar()` públicos.

**Tanques y tiempo (agente A)** — `sim/tanque.gd`, `sim/cinetica.gd`
- `transferir` respeta capacidad; la mezcla **delega en `EstadoLodo.mezclar`** (lo disuelto por volumen de agua, lo demás por volumen de lodo). `tratar` hace crecer el volumen con barita, bentonita y agua, con rebalse.
- Pasos de 10 min: homogenización del activo en 1−e^(−Δt/ciclo) 🧩, reserva aislada; cal en exceso se disuelve con τ = 4 h 🧩; bentonita hidrata en rampa hasta el 100 % a las 6 h, más lento con Cl⁻ o Ca²⁺ altos 🧩; indicador de asentamiento en tanques sin agitar.

**Laboratorio y observación (agente C)** — `sim/prueba_laboratorio.gd`, `sim/laboratorio.gd`, `sim/observacion.gd`
- 17 pruebas como datos, con la **resolución del instrumento** (balanza 0,1 ppg, dial del Fann entero, Pf a 0,05 ml…). Balanza atmosférica lee bajo con aire; Fann sin copa térmica ×1,15 🧩; Θ6/Θ3 derivados 🧩. Las pruebas sobre filtrado lo exigen.
- Planificador del laboratorio: chequeo completo 67 min con esperas en paralelo, contra 107 en serie.
- 4 observaciones (espuma, viscosidad a ojo, rebose de zarandas, lodo ennegrecido). Ningún texto nombra un contaminante (lo verifica una prueba).

**Reglas y programa (agente D)** — `sim/regla.gd`, `sim/evaluador_reglas.gd`, `sim/programa_seccion.gd`
- 19 reglas con condición (expresión de Godot) y explicación como dato; momentos: al tratar, al transferir, al diagnosticar, al cerrar el día.
- Programas de CAIMÁN-3 (tres secciones), los 7 sistemas y el pozo como datos. `puede_usar` y `sin_producto` son la palanca de dificultad.
- Umbrales provisionales 🧩: cemento = cal en exceso > 0,25 lb/bbl; carnalita = Mg > 2.000 mg/l; carbonatos = Mf > 5 y Mf de carbonatos > 2,5; lodo densificado = 2 % de barita.

**Correcciones al integrar**
- Los ids de pruebas de las reglas no coincidían con los del laboratorio (`reologia` → `fann`, etc.). Alineados, con una prueba que lo verifica.
- El tanque mezclaba `tampon_base`, `co2` y `mg_oh2` por volumen de lodo; ahora usa la mezcla del estado (por volumen de agua).
- El ejecutor de pruebas cuenta como falla un archivo que no compila.

**Decisiones abiertas**
- **Deriva del lodo base:** la cal en exceso del lodo base (0,2 lb/bbl) se disuelve con el tiempo y sube el pH de 10,0 a 11,0 y el calcio de 120 a 442 mg/l en un día, sin que el jugador haga nada. Quitarla rompe la fila de carbonatos de la Tabla 4 (el Pf baja en vez de subir). Opciones: separar "finos de cemento" (se disuelven) de "cal de tratamiento" (inerte), alargar τ, o aceptar la deriva como mecánica (el jugador la corrige con su tratamiento de mantenimiento).
- Productos que piden los programas y no existen: PHPA, almidón, CaCO₃ dimensionado (y lignito, NaCl, amina para otros sistemas).
- Variables que piden las observaciones y no existen: sedimento visible al transferir, mallas tapadas, temperatura de la muestra, nivel de tanques, recortes.
- Solubilidad de Ca(OH)₂ con Ksp (hoy tope fijo de OH⁻); mecanismo real de la caída de pH por yeso y sal (hoy ácidos calibrados).
