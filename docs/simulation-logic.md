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
| 7 | Control de sólidos: eficiencia de cada equipo, tasa de dilución | pendiente |
| 8 | Mezcla con el embudo: sacos por hora, tiempo de hidratación de bentonita y polímeros | pendiente |
| 9 | Reporte diario de lodo: qué contiene, costos, inventario | pendiente |
| 10 | Eventos: pérdidas, influjo, gas de conexión, maniobras (viajes) desde la vista del ingeniero | pendiente |
| 11 | Temperatura del lodo: entrada y salida, efecto en reología | pendiente |

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
