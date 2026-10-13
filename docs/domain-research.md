# Investigación de dominio: fluidos de perforación

Base técnica para el diseño del juego de entrenamiento. Cubre los 5 bloques definidos en el plan: circulación de lodo, válvulas, químicos, propiedades monitoreadas y escenarios operativos.

> **Alcance y supuestos.** Este documento se limita a **lodos base agua (WBM)**, que son los que el juego va a simular. Existen también lodos base aceite (OBM) y sintéticos (SBM), con química y consideraciones ambientales distintas; quedan fuera de alcance.
>
> **Procedimiento de control de pozo canónico del juego:** **hard shut-in** (ver bloque 5). Se eligió por ser más rápido, de menor volumen de influjo y de secuencia más simple de enseñar y puntuar. El soft shut-in se documenta como contraste porque también es válido en la industria.

## 1. Sistema de circulación de lodo

El lodo (drilling mud) circula en un ciclo cerrado entre superficie y fondo de pozo:

1. **Bombas de lodo** (mud pumps, normalmente bombas de desplazamiento positivo reciprocantes) toman el lodo de los **tanques/pits activos** y lo impulsan a alta presión.
2. El lodo baja por el **standpipe** y la **sarta de perforación** (drill string) hasta la broca.
3. En la broca: enfría y lubrica la broca, y empieza a transportar los recortes (cuttings) de roca.
4. El lodo con cuttings sube por el **anular** (espacio entre la sarta y la pared del pozo) y ejerce presión hidrostática que estabiliza el pozo.
5. En superficie, el retorno pasa por el **flowline** hacia el **equipo de control de sólidos**, en esta secuencia:
   - **Shale shaker**: malla vibratoria que remueve los cuttings gruesos (>~100 μm). Primera línea de defensa.
   - **Sand trap**: compartimento de asentamiento por gravedad, inmediatamente después del shaker.
   - **Degasser**: remueve gas entrampado. **Va antes de los hidrociclones**, no después: los desander/desilter son alimentados por bombas centrífugas, que pierden eficiencia y cavitan con lodo cortado por gas.
   - **Desander**: hidrociclones que remueven sólidos medianos (~45–74 μm).
   - **Desilter**: hidrociclones más pequeños que remueven finos (~15–45 μm).
   - **Mud cleaner**: desilter montado sobre una malla fina; recupera barita mientras descarta sólidos de formación.
   - **Centrífuga decantadora**: última etapa, separa sólidos ultrafinos y permite recuperar barita o descartar fase líquida.
6. El lodo ya limpio vuelve a los **tanques activos**, listo para recircular.

Orden resumido: `shale shaker → sand trap → degasser → desander → desilter → mud cleaner → centrífuga`

Elementos adicionales relevantes para el juego: **trip tank** (monitorea volumen durante maniobras de sacada/metida de tubería, clave para detectar kicks) y **mud-gas separator** o "poor boy" (separa gas de alto volumen durante control de pozo, antes de que el flujo llegue al equipo normal).

**Fuentes:**
- [What is a mud circulation system and how does it work?](https://eureka.patsnap.com/article/what-is-a-mud-circulation-system-and-how-does-it-work)
- [Six Important Factors for Drilling Mud Circulation System](https://www.solidscontrolsystem.com/drilling-mud-circulation-system/)
- [Solids Control System Setup and Commissioning Guide — AiPu](https://www.aipusolidcontrol.com/news/1837.html)
- [Desander — Wikipedia](https://en.wikipedia.org/wiki/Desander)
- [Mud tank — Wikipedia](https://en.wikipedia.org/wiki/Mud_tank)
- [Drilling Rig Systems, Components and their Functions](https://lecture-notes.tiu.edu.iq/wp-content/uploads/2023/11/PTR-316-Theory-Lecture-7.pdf)

## 2. Válvulas relevantes

> **Distinción crítica para el juego:** la **válvula de la línea de choke (HCR)** y el **choke ajustable** son dos elementos distintos. La HCR es on/off (abre o cierra el paso a la línea de choke); el choke es estrangulable (regula presión de forma continua). Confundirlos borra justamente la diferencia entre hard y soft shut-in, así que en el esquema del juego deben ser dos objetos separados.

| Válvula / manifold | Tipo | Función | Cuándo se opera |
|---|---|---|---|
| **Válvulas de succión/descarga de bombas** | on/off | Controlan el flujo de lodo hacia/desde las bombas | Circulación normal, cambio de bomba |
| **Standpipe manifold** | on/off | Dirige el lodo presurizado hacia la sarta | Circulación normal de perforación |
| **Hopper de mezcla** | on/off | Permite succionar polvos/químicos hacia el flujo de lodo vía venturi | Tratamiento químico del lodo |
| **Válvulas de transferencia entre pits** | on/off | Mueven lodo entre tanques (activo, reserva, mezcla) | Ajustes de volumen/propiedades, preparación de lodo nuevo |
| **BOP (Blowout Preventer)** | on/off | Conjunto de preventores (anular, rams de tubería, rams ciegos) que sellan el pozo | Se cierra ante un kick confirmado |
| **Válvula de línea de choke (HCR)** | on/off | Abre el paso del anular hacia el choke manifold | En hard shut-in: se abre **después** de cerrar el BOP |
| **Choke ajustable** | estrangulable | Regula la contrapresión de retorno de forma continua | Durante la circulación de control de pozo, para mantener la presión de fondo constante |
| **Kill line** | on/off | Línea alterna para bombear lodo pesado directamente al pozo vía el BOP | Control de pozo, si la sarta no es utilizable |

**Fuentes:**
- [eTool: Oil and Gas Well Drilling — Blowout Preventers (OSHA)](https://www.osha.gov/etools/oil-and-gas/drilling/well-control-blowout-preventers)
- [Hard Shut In Procedure & Lineup In Well Control — Drilling Manual](https://www.drillingmanual.com/hard-shut-in-procedure-while-drilling/)
- [2 Types of Shut-In (Hard and Soft) — Drilling Formulas](https://www.drillingformulas.com/2-types-of-shut-in-hard-shut-in-and-soft-shut-in/)
- [Supplement — Well Control Equipment, Subunit Boundaries](https://www.safeocs.gov/file/Supplement%20-%20WCE%20-%20Subunit%20Boundaries.pdf)
- [Mud Mixing Hopper Unit — AiPu Solid Control](https://www.aipusolidcontrol.com/news/543.html)

## 3. Químicos y tratamiento del lodo

El lodo base típico es agua + **bentonita** + **sosa cáustica**. Sobre esa base se ajustan propiedades con aditivos específicos, agregados generalmente vía el **hopper de mezcla** (venturi: succiona el polvo/líquido hacia el flujo) hacia los tanques activos o de mezcla:

- **Densificantes** — Barita (sulfato de bario, SG ≈ 4.2, sólido inerte) y hematita (óxido de hierro, SG ≈ 5.0): aumentan el peso/densidad del lodo para controlar presión de formación.
- **Viscosificantes** — Bentonita (arcilla montmorillonita sódica) y polímeros (XC polymer, PHPA): aumentan viscosidad y capacidad de suspender/transportar cuttings.
- **Control de pérdida de filtrado** — CMC, almidón, HEC, CMHEC, carbonato de calcio como agente puenteante: reducen la cantidad de filtrado que invade la formación, formando un revoque (filter cake) delgado y de baja permeabilidad.
- **Control de pH (al alza)** — Sosa cáustica (NaOH) y cal: mantienen el pH alcalino necesario para la estabilidad de la bentonita y para prevenir corrosión.
- **Control de pH (a la baja) y contaminación por cemento** — SAPP (pirofosfato ácido de sodio) y ácido cítrico: bajan el pH y defloculan el lodo cuando se contamina con cemento o cal en exceso. Es el caso donde sí se agregan ácidos al sistema.
- **Inhibidores de arcillas/lutitas** — KCl (cloruro de potasio) y sal: aportan iones que inhiben el hinchamiento y dispersión de lutitas reactivas, evitando derrumbes de pared de pozo.
- **Defoamers**: controlan espuma, que falsea las lecturas de densidad y reduce la eficiencia de las bombas.
- **Biocidas**: controlan crecimiento bacteriano, que degrada los polímeros (almidón, CMC) del sistema.
- **LCM (lost circulation material)** — materiales obturantes fibrosos, granulares o laminares (cáscara de nuez, mica, celofán): sellan fracturas ante pérdida de circulación.

**Fuentes:**
- [Base Drilling Fluid — ScienceDirect Topics](https://www.sciencedirect.com/topics/engineering/base-drilling-fluid)
- [Mud Mixing Hopper Unit — AiPu Solid Control](https://www.aipusolidcontrol.com/news/543.html)
- [Vortex Mud Hopper — GN Solids Control](https://www.gnsolidscontrol.com/drilling/vortex-mud-hopper/)
- [Biodegradable Shale Inhibitors for Water Based Fluids](https://igj-iraq.org/igj/index.php/igj/article/download/2596/2113/29771)
- [A Comprehensive Guide for Oil & Gas Wells Drilling Fluids — Drillopedia](https://www.drillopedia.com/mud-drilling-fluid-essentials)

## 4. Propiedades del lodo monitoreadas

| Propiedad | Qué mide | Rango/nota típica |
|---|---|---|
| **Peso/densidad (mud weight)** | Presión hidrostática de la columna de lodo | Se reporta en ppg, lb/ft³, SG o gradiente (psi/ft) |
| **Viscosidad plástica (PV)** | Fricción entre sólidos y líquido | `PV = θ600 − θ300`, en cP. ~10–30 cP para operación eficiente |
| **Punto de cedencia (YP)** | Fuerzas de atracción entre partículas; resistencia al flujo inicial | `YP = θ300 − PV`, en lb/100 ft². Indica capacidad de limpieza de pozo |
| **Gel strength** | Fuerzas de atracción en estado estático (lecturas a 10 s, 10 min) | Reportado en lb/100 ft² |
| **pH** | Alcalinidad del sistema | Debe mantenerse alcalino (~9.5–11.5) para estabilidad de bentonita y control de corrosión |
| **Pérdida de filtrado API** | Volumen de filtrado en 30 min a 100 psi diferencial (API filter press) | A menor volumen, mejor control de filtrado |
| **Contenido de arena** | Partículas retenidas en malla 200 (>74 μm, abrasivas) | Medido con kit de contenido de arena |
| **Cloruros** | Salinidad del sistema | Agua de mezcla idealmente <500 ppm cloruros |

Estas propiedades se miden periódicamente (ej. cada reporte de lodo / mud report) y determinan qué acción tomar: agregar densificante, viscosificante, diluir, tratar pH, etc.

### 4.1 Cálculos de campo (base numérica para el juego)

**Presión hidrostática:**
```
P (psi) = 0.052 × MW (ppg) × TVD (ft)
```

**Ventana de lodo (mud weight window).** Es el concepto central de todo el manejo de fluidos: el peso del lodo debe mantenerse **entre dos paredes**.

```
presión de poro  <  peso del lodo  <  gradiente de fractura
      ↑                                      ↑
  muy liviano:                          muy pesado:
  influjo / kick               fractura la formación / pérdida de circulación
```

En zonas profundas o depletadas la ventana se angosta, y mantenerse dentro exige precisión creciente. Es el marco que une los dos modos de falla descritos en el bloque 5.

**ECD (densidad equivalente de circulación).** La presión de fondo al circular es mayor que la estática, porque se suma la pérdida de presión por fricción en el anular:
```
ECD (ppg) = MW (ppg) + APL (psi) / (0.052 × TVD (ft))
```
donde APL = pérdida de presión anular. Consecuencia operativa: un lodo que está dentro de la ventana en estático puede **fracturar la formación al circular**. Es también el mecanismo físico detrás del swab/surge (bloque 5) y el puente directo entre el estado de las válvulas/bombas y las propiedades del lodo.

**Peso de lodo de matada (kill mud weight)**, a partir de la presión de cierre en la sarta:
```
KMW (ppg) = MW (ppg) + SIDPP (psi) / (0.052 × TVD (ft))
```
donde SIDPP = presión de cierre en la sarta (shut-in drill pipe pressure). Este cálculo es el que conecta el manejo de válvulas con la adición química: define cuánta barita hace falta.

**Densificación con barita:**
```
sacos/100 bbl        = 1470 × (W2 − W1) / (35 − W2)
aumento de volumen   =  100 × (W2 − W1) / (35 − W2)   [bbl por 100 bbl]
```
W1 = peso actual (ppg), W2 = peso objetivo (ppg), 35 = equivalente en ppg de la barita (SG 4.2), 1470 = lb de barita por barril de sólido. Un saco = 100 lb. Nota didáctica: **subir el peso aumenta el volumen del sistema**, efecto que el juego puede enseñar explícitamente.

**Fuentes:**
- [Drilling Mud Properties Guide — Drilling Manual](https://www.drillingmanual.com/drilling-mud-fluid-properties/)
- [API Recommended values for PV, YP and Gel strength — ResearchGate](https://www.researchgate.net/figure/API-Recommended-values-for-Plastic-viscosity-PV-Yield-point-YP-and-Gel-strength_tbl3_337888882)
- [API fluid-loss test — SLB Glossary](https://glossary.slb.com/en/terms/a/api_fluid-loss_test)
- [Increase mud weight by adding barite — Drilling Formulas](https://www.drillingformulas.com/increase-mud-weight-by-adding-barite/)
- [Increase Mud Weight — formulas reference](https://docs.kws.tn/formulas/3/mud-weight.html)
- [Deciphering The Daily Mud Report](https://www.aade.org/application/files/1515/7365/8636/Deciphering_The_Daily_Mud_Report.pdf)
- [Drilling Fluid Basics — Water Well Journal](https://waterwelljournal.com/drilling-fluid-basics/)

## 5. Escenarios operativos típicos

- **Ajuste de peso de lodo mientras se perfora**: según la formación atravesada, se agrega barita (subir peso) o se diluye con agua/lodo base (bajar peso), monitoreando constantemente para mantenerse dentro de la ventana de lodo (§4.1) — ni sub- ni sobre-balanceado.

- **Kick y control de pozo**: ocurre cuando la presión de formación supera la presión hidrostática del lodo (causas típicas: peso de lodo insuficiente, **swabbing**, o **pérdida de circulación**). Se detecta por desviación entre "flow out" y "flow in", o ganancia de volumen en los tanques/trip tank.

  **Hard shut-in (procedimiento canónico del juego)** — la HCR permanece cerrada mientras se perfora:
  1. Levantar la sarta del fondo / espaciar (space out).
  2. Detener la rotación.
  3. Detener las bombas.
  4. Verificar flujo (flow check) — si el pozo fluye, se confirma el kick.
  5. **Cerrar el BOP** (preventor anular o rams de tubería).
  6. **Abrir la HCR** (línea de choke), con el choke cerrado: el pozo queda contenido por el choke.
  7. Registrar SIDPP, SICP y la ganancia en tanques → calcular el peso de lodo de matada (§4.1).
  8. Circular el lodo de matada regulando el **choke ajustable** para mantener la presión de fondo constante.

  **Contraste — soft shut-in**: la HCR se mantiene **abierta** mientras se perfora; ante un kick se cierra el BOP y luego se cierra el **choke**. Da control más fino del aumento de presión en el casing, pero los pasos extra permiten mayor influjo. Ambos procedimientos son válidos en la industria y la elección es política del operador; el juego enseña hard shut-in y menciona el soft como variante.

- **Pérdida de circulación**: el lodo se pierde hacia la formación (fracturas naturales o inducidas, zonas de alta permeabilidad) en vez de retornar a superficie. Es el modo de falla del *techo* de la ventana de lodo, y causa de kick si baja demasiado el nivel hidrostático. Se trata con LCM (material obturante) o reduciendo el peso del lodo / la ECD.

- **Swab/surge**: el movimiento de la sarta genera cambios transitorios de presión. Al **sacar** tubería (swab) la presión de fondo cae momentáneamente — puede inducir un kick; al **meter** tubería (surge) sube — puede fracturar la formación. Es el mismo mecanismo de la ECD aplicado al movimiento de la sarta, y la razón por la que la velocidad de maniobra se limita.

**Fuentes:**
- [Kicks — PetroWiki (SPE)](https://www.aec.edu.in/aec/Instruction_Material/Kicks%20-%20PetroWiki.pdf)
- [Hard Shut In Procedure & Lineup In Well Control — Drilling Manual](https://www.drillingmanual.com/hard-shut-in-procedure-while-drilling/)
- [Soft Shut In Procedure — Drilling Manual](https://www.drillingmanual.com/soft-shut-in-procedure-while-on-fixed/)
- [What is a well kick and how is it detected?](https://eureka.patsnap.com/article/what-is-a-well-kick-and-how-is-it-detected)
- [Well Control — Aberdeen Drilling Schools](https://faculty.ksu.edu.sa/sites/default/files/well_control_book.pdf)
