# Pozos de referencia (públicos) y pozos ficticios derivados

Para que los niveles no dependan de un solo pozo, se revisaron programas de lodos y casos **públicos** de varias cuencas. Se usan **como referencia de patrones** (estructura de secciones, sistemas, rangos, problemas típicos). **Ningún pozo del juego copia un pozo real**: los pozos del juego siguen siendo ficticios (decisión cerrada en `CLAUDE.md`).

Documentos hermanos: `docs/mud-programs.md` (sistemas y pozos del juego) · `docs/simulation-logic.md` (reglas verificadas).

> **Acceso:** varias fuentes (formularios de Nuevo México, reportes noruegos) no se pudieron abrir desde la sesión en la nube porque la red bloquea esos dominios. Lo que sigue sale de lo que muestran las búsquedas. Las cifras son de pozos reales y solo sirven para calibrar rangos.

---

## 1. Cuenca Pérmica (Delaware), EE. UU. — sal y pérdidas

Fuente: formularios públicos de permiso de perforación (APD) de la División de Conservación de Petróleo de Nuevo México. Varios pozos coinciden en el patrón. ✅

| Sección | Fluido | Densidad | Embudo | Filtrado |
|---|---|---|---|---|
| Superficial (hasta ~950–1.100 ft) | Lodo de inicio de agua dulce (*spud mud*) | 8,6–9,0 ppg | 32–34 s | sin control |
| Intermedia, **a través de la sal** (Salado, Castile) hasta la base de la sal (~4.700 ft) | **Salmuera saturada** | 9,8–10,2 ppg | 28–45 s | sin control |
| Bajo la sal | Salmuera cortada con polímero, o sistema de hidróxidos mixtos | 8,5–9,6 ppg | 32–35 s | ~15 ml |

Patrones útiles:
- La sal se perfora con **salmuera saturada**, igual que el sistema salado del juego.
- El revestimiento superficial protege las arenas de agua dulce.
- **Zonas de pérdida** marcadas en el programa: dentro de la sal (Salado) y más abajo (Brushy Canyon).
- Exigen **material de pérdida y densificante en sitio en todo momento** (barita, bentonita, fibra de cedro, cascarilla de algodón) y **monitoreo de volumen de tanques** desde el inicio. Esto coincide con `simulation-logic.md` §4 y §14.
- Bajo la sal se **cambia de fluido**: es un caso real de cambio de sistema entre secciones.

Fuentes: [APD 30-025-42986](https://ocdimage.emnrd.nm.gov/Imaging/FileStore/Hobbs/WF/300991/30025429860000_1_WF.pdf) · [APD 30-025-41945](https://ocdimage.emnrd.nm.gov/Imaging/FileStore/Hobbs/WF/256746/30025419450000_1_WF.pdf) · [APD 30-025-44184](https://ocdimage.emnrd.nm.gov/imaging/filestore/hobbs/WF/311539/30025441840000_2_WF.pdf) · [APD 30-025-44191](https://ocdimage.emnrd.nm.gov/Imaging/FileStore/Hobbs/WF/311585/30025441910000_2_WF.pdf) · [APD 30-025-44161](https://ocdimage.emnrd.nm.gov/imaging/filestore/Hobbs/WF/311628/30025441610000_3_WF.pdf) · [APD 30-025-45963](https://ocdimage.emnrd.nm.gov/imaging/filestore/hobbs/WF/318505/30025459630000_4_WF.pdf)

---

## 2. Llanos y piedemonte, Colombia — lutitas problemáticas

- Las lutitas **Carbonera, León y Villeta** son de las más problemáticas en Colombia. En la Carbonera, la inestabilidad (derrumbes, escalones) dificulta la limpieza y lleva a empaquetamientos y pega de tubería. ✅ (OGJ; Redalyc)
- **Matiz importante:** un análisis de rayos X citado por OGJ encontró que la Carbonera y la León **no son arcillas que se hinchen**. La inestabilidad es sobre todo **mecánica**, no química. Una inhibición química más fuerte no resuelve el problema por sí sola. ⚠️ (una fuente)
- En el piedemonte también pesa la interacción química lodo–lutita (flujo de agua). En Cupiagua, el peso del lodo se diseña considerando la trayectoria y los planos de debilidad de la lutita. ✅ (Redalyc, UIS)
- Guía general de KCl/polímero (patente, no específica de Llanos): KCl de 15–35 lb/bbl, pH 8,5–10, calcio soluble < 300 mg/l. ⚠️

Fuentes: [Optimized drilling fluids benefit tough Andean wells — OGJ](https://www.ogj.com/drilling-production/drilling-operations/article/17224831/optimized-drilling-fluids-benefit-tough-andean-wells) · [Llanos basin — AAPG Wiki](https://wiki.aapg.org/Llanos_basin) · [Inestabilidad de lutitas en el piedemonte — Redalyc](https://www.redalyc.org/pdf/465/46518503002.pdf) · [Trayectorias y pesos de lodo en Cupiagua — UIS](https://noesis.uis.edu.co/bitstreams/b7f7c94e-a53c-4e16-bafe-df0df4b75101/download) · [US 9550932 — estabilizante de lutitas](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9550932)

---

## 3. Medio Oriente — anhidrita, yeso y ventana estrecha

- **Formación Gachsaran (Irán):** anhidrita, yeso y marga. En el campo Kupal concentró la mayoría de los problemas: **pérdidas excesivas, influjos, hueco apretado y pega de tubería**, con repasos, pesca y desvíos. La ventana de peso de lodo es **muy estrecha** en algunos tramos. ✅ (Springer, J. Pet. Expl. Prod. Tech. 2020; DOAJ)
- **Campo Nahr Umr (Irak):** perforar anhidrita de la formación Rus causó **coágulos, PC y geles muy altos y problemas de filtrado**, porque el lodo no tenía aditivos para controlar y precipitar calcio. Se resolvió con más químicos y **un lodo nuevo resistente al calcio**. ✅ (AADE; coincide con `mud-engineer-reference.md` §1.4)

Fuentes: [Gachsaran, campo Kupal — Springer](https://link.springer.com/article/10.1007/s13202-020-00834-3) · [Mismo artículo — DOAJ](https://doaj.org/article/957527a61d3746bfbc1c4bdf9e5d719e) · [Contaminación de calcio en Nahr Umr — AADE](https://www.aade.org/download_file/1410/396)

---

## 4. Mar del Norte y mar de Noruega — KCl, glicol y pega diferencial

- Secciones de 12¼" perforadas con **KCl/polímero** (~30 lb/bbl de KCl) y con sistemas de **glicol** (Glydril). ⚠️ (reportes de pozo individuales)
- En un pozo, el peso se subió a 1,27 SG para bajar revestimiento y **se bajó a 1,20 SG por pega diferencial**: subir el peso tiene un costo. ⚠️
- Para lutitas muy reactivas también se usan fluidos inhibidos sin arcilla en lugar del KCl/polímero/glicol estándar. ⚠️ (AADE, Halliburton)

Fuentes: [Pozo 2/15-? — reporte de Dresser (Sodir)](https://factpages.sodir.no/pbl/wellbore_documents/439_02_31_2_15_Well_summary_by_Dresser.pdf) · [Reporte geoquímico con datos de lodo (Sodir 99_1)](https://factpages.sodir.no/pbl/geochemical_pdfs/99_1.pdf) · [Reporte geoquímico (Sodir 1921_1)](https://factpages.sodir.no/pbl/geochemical_pdfs/1921_1.pdf) · [AADE-04-DF-HO-01](https://www.aade.org/download_file/2474/485)

---

## 5. Datos abiertos para más adelante

- **Volve (Equinor):** unos 40.000 archivos de un campo cerrado del mar del Norte, con datos de perforación en tiempo real y reportes. Licencia abierta para formación e investigación; requiere registro. Útil para calibrar parámetros de perforación (tema 1 de `simulation-logic.md`). [Equinor — Volve](https://www.equinor.com/en/what-we-do/digitalisation-in-our-dna/volve-field-data-village-download.html) · [JPT](https://jpt.spe.org/equinor-releases-subsurface-and-production-data-ncs-field)
- **Utah FORGE (geotermia, EE. UU.):** reportes diarios, resumen de perforación de 74 páginas y mud log del pozo 16A(78)-32, públicos. Útil para temperatura alta. [Resumen de perforación — OpenEI](https://gdr.openei.org/submissions/1296) · [Datos de perforación — data.gov](https://catalog.data.gov/dataset/utah-forge-well-16b78-32-drilling-data-adebd)

---

## 6. Pozos ficticios propuestos

Cada uno toma el **patrón** de una región y enseña algo que CAIMÁN-3 no enseña. Los nombres, profundidades y valores son inventados dentro de los rangos de arriba.

### MÉDANO-5 — sal y pérdidas (inspirado en la cuenca Pérmica)

| Sección | Diámetro | Profundidad | Sistema | Densidad | Nota |
|---|---|---|---|---|---|
| Superficial | 17½" | 0–1.000 ft | Bentonítico | 8,6–9,0 ppg | Proteger arenas de agua dulce |
| Sal | 12¼" | 1.000–4.600 ft | Salado saturado | 9,8–10,2 ppg | Pérdidas probables en la sal |
| Bajo la sal | 8¾" | 4.600–9.500 ft | Polímero en salmuera cortada | 8,6–9,4 ppg | **Cambio de fluido** al salir de la sal |

**Lo que enseña:** saturar a propósito, tener material de pérdida en sitio, y un cambio de fluido real entre secciones.

### PIEDEMONTE-2 — lutita que no es química (inspirado en el piedemonte colombiano)

| Sección | Diámetro | Profundidad | Sistema | Densidad | Nota |
|---|---|---|---|---|---|
| Superficial | 17½" | 0–2.200 ft | Bentonítico | 8,6–9,2 ppg | — |
| Intermedia | 12¼" | 2.200–9.000 ft | KCl/PHPA | 10,0–11,8 ppg | Lutita frágil desde 5.000 ft; ventana estrecha |
| Producción | 8½" | 9.000–11.000 ft | RDF | 9,4–10,2 ppg | — |

**Lo que enseña:** aparecen derrumbes en las zarandas y la reacción automática es subir la inhibición, **pero la lutita no es reactiva**: el MBT y el K⁺ están bien. Lo que funciona es subir la densidad dentro de la ventana y mejorar la limpieza. Subir de más causa pérdidas. Aquí la observación de recortes (en bloque o astillados) es la pista clave.

### ESTRATO-9 — anhidrita gruesa (inspirado en el Medio Oriente)

| Sección | Diámetro | Profundidad | Sistema | Densidad | Nota |
|---|---|---|---|---|---|
| Superficial | 17½" | 0–1.800 ft | Bentonítico | 8,6–9,0 ppg | — |
| Intermedia | 12¼" | 1.800–7.200 ft | Disperso → **cálcico (yeso)** | 10,2–11,8 ppg | Anhidrita gruesa desde 3.500 ft; ventana estrecha |
| Producción | 8½" | 7.200–8.600 ft | RDF | 9,4–10,0 ppg | Pérdidas probables |

**Lo que enseña:** el jugador empieza con un lodo disperso, ve la contaminación de calcio repetirse y tiene que decidir **convertir el sistema a lodo yeso** a mitad de sección (`mud-engineer-reference.md` §1.4), en vez de seguir gastando carbonato de sodio.

### Otras ideas sin desarrollar

- **Pega diferencial por exceso de peso** (patrón del mar del Norte): evento en el que subir la densidad para estabilizar provoca pega.
- **Pozo caliente** (patrón de Utah FORGE): degradación de polímeros y floculación térmica (`simulation-logic.md` §6.2 y §11).

## Pendiente

- Pasar MÉDANO-5, PIEDEMONTE-2 y ESTRATO-9 a `mud-programs.md` y a datos (`data/programas/`) cuando el programa de sección esté implementado.
- Validar con el autor si los patrones coinciden con su experiencia.
