# Referencia del ingeniero de fluidos

Extraído del *Manual de Fluidos de Perforación* (API / M-I). Material orientado al rol del ingeniero de lodos: **síntoma → diagnóstico → tratamiento**, manejo de tanques y cálculos. Las citas indican capítulo y sección del manual.

> **Alcance:** lodos base agua (WBM). Unidades de campo (lb/bbl, bbl, ppg, mg/l), con equivalentes métricos donde el manual los da.

---

## 1. Matriz de contaminaciones

### 1.1 Tabla de reconocimiento rápido

Reproduce la Tabla 4 del manual (Cap. 4C, *Referencia Rápida*, 4C.21). Es la pieza más jugable del documento: el jugador ve los indicadores y debe deducir el contaminante.

| Contaminante | FV | PV | YP | Geles | Filtrado | pH | Pm | Pf | Mf | Cl⁻ | Ca²⁺ | Sólidos |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Cemento** | ↑ | — | ↑ | ↑ | ↑ | ↑ | ↑ | ↑ | ↑ | — | ↑ (y ↓ si pH>11,5) | — |
| **Yeso / anhidrita** | ↑ | — | ↑ | ↑ | ↑ | ↓ | ↓ | ↓ | ↓ | — | ↑ | — |
| **Sal** | ↑ | — | ↑ | ↑ | ↑ | ↓ | ↓ | ↓ | ↓ | ↑↑ | ↑ | — |
| **Carbonato / bicarbonato** | ↑ | — | ↑ | ↑ | ↑ | ↓ | ↓ | ↑ | ↑ | — | ↓ | — |
| **H₂S** | ↑ | — | ↑ | ↑ | ↑ | ↓ | ↓ | ↓ | ↓ | — | ↑ | — |
| **Sólidos (antiguos)** | ↑ | ↑ | — | ↑ | — | — | — | — | — | — | — | ↑ |
| **Sólidos (nuevos)** | ↑ | ↑ | ↑ | ↑ | ↑ | ↑ | ↑ | ↑ | ↑ | ↑ | ↑ | ↑ |

**La clave del diagnóstico diferencial** (Cap. 4C, *Introducción*, 4C.1): los cambios **físicos** (↑viscosidad, ↑geles, ↑filtrado por floculación) son prácticamente idénticos en **todos** los contaminantes químicos. Solo dicen *que hay* un contaminante. Para identificar *cuál*, hay que mirar las propiedades **químicas**: pH, Pm, Pf, Mf, cloruros y dureza de calcio.

Esto se traduce directo a mecánica: el panel de propiedades físicas dispara la alarma; el análisis químico resuelve el acertijo.

> Dato de calibración: los lodos con **MBT < 15 lb/bbl** son mucho menos afectados por contaminación química (Cap. 4C, 4C.1). La severidad escala con el contenido de sólidos arcillosos.

### 1.2 Dosis de tratamiento (Tabla 2, Cap. 4C, 4C.20)

`Fw` = fracción de agua de la retorta. Resultado en **lb/bbl**.

| Contaminante | Ion | Tratamiento | Concentración |
|---|---|---|---|
| CO₂ | Carbonato | Yeso (baja pH) | mg/l × Fw × 0,00100 |
| CO₂ | Carbonato | Cal (sube pH) | mg/l × Fw × 0,000432 |
| CO₂ | Bicarbonato | Cal (sube pH) | mg/l × Fw × 0,00424 |
| Yeso / anhidrita | Calcio | Carbonato de sodio | mg/l × Fw × 0,000928 |
| Yeso / anhidrita | Calcio | SAPP | mg/l × Fw × 0,000971 |
| Yeso / anhidrita | Calcio | Bicarbonato de sodio | mg/l × Fw × 0,00735 |
| Cal o cemento | Calcio e hidroxilo | Bicarbonato de sodio | lb/bbl exceso de cal × 1,135 |
| Cal o cemento | Calcio e hidroxilo | SAPP | lb/bbl exceso de cal × 1,150 |
| Cal o cemento | Calcio e hidroxilo | Ácido cítrico | lb/bbl exceso de cal × 1,893 |
| Agua dura o salada | Calcio y magnesio | Soda cáustica | mg/l × Fw × 0,00116 |
| H₂S | Sulfuro | Óxido de cinc + NaOH (pH > 10,5) | mg/l × Fw × 0,00091 |

> ⚠️ **Dos factores de esta tabla no cuadran con la estequiometría.** Verificando cada fila con los pesos moleculares, todas coinciden al 1–2 % salvo dos que aparecen **10 veces más altos**: CO₂/bicarbonato con cal (0,00424 → debería ser **0,000424**) y calcio con bicarbonato de sodio (0,00735 → debería ser **0,000735**). Probablemente es un error al pasar los datos del PDF. El código usa los valores estequiométricos (`sim/formulas.gd`). **Pendiente: confirmar contra el PDF en la máquina local.**

**Exceso de cal (lb/bbl)** = `0,26 × (Pm − (Pf × Fw))`  ·  métrico (kg/m³): `0,074178 × (Pm − (Pf × Fw))`

### 1.3 Cemento (Cap. 4C, *Contaminación de Cemento*, 4C.4–4C.7)

- **Qué es:** silicato de cal complejo, `Ca(OH)₂ → Ca²⁺ + 2OH⁻` (pH < 11,7). Aporta calcio **y** un floculante.
- **Fuente:** perforar tapones/zapatas de cemento. Ojo: **la barita a granel puede venir contaminada con cemento** desde el transporte, causando contaminación grave no anticipada.
- **Síntomas:** ↑viscosidad y geles, ↑filtrado, y sobre todo **↑pH, ↑Pm, ↑Pf** — el indicador principal es el salto de **Pm** y del exceso de cal calculado.
- **Trampa física:** a pH muy alto la cal se vuelve insoluble (>11,7), así que un lodo muy contaminado puede mostrar propiedades de flujo *bajas* en superficie y aun así gelificar en el fondo. A BHT alta hay que tratar **rápido y completo** o el lodo se solidifica.

**Tratamiento:**
1. Subir desfloculante (lignosulfonato, lignito). TANNATHIN, RESINEX, XP-20 funcionan bien con calcio alto.
2. **No añadir soda cáustica** con los desfloculantes: el cemento ya sube la alcalinidad.
3. Precipitar el calcio con **bicarbonato de sodio** o **SAPP** (ambos bajan pH y Pm).
4. Si hay mucho cemento: **ácido cítrico**, que precipita como citrato de calcio y baja el pH.
5. Con sistemas de polímeros: el pH alto hidroliza la poliacrilamida y el calcio precipita el poliacrilato → bajar pH y quitar Ca²⁺ cuanto antes.
6. Remover finos de cemento con el equipo de sólidos antes de que se disuelvan.

> ⚠️ **Regla dura:** **nunca usar carbonato de sodio para tratar cemento** — su pH es demasiado alto (Cap. 4C, 4C.6, observación explícita).
>
> ⚠️ **Regla de dosificación:** tratar primero con una cantidad **insuficiente**, observar, y recién después añadir más. Pasarse de carbonatos crea un problema de carbonatos.

### 1.4 Yeso / anhidrita (Cap. 4C, 4C.2–4C.4)

- **Qué es:** sulfato de calcio. `CaSO₄ → Ca²⁺ + SO₄²⁻`. El yeso (CaSO₄·2H₂O) es más soluble que la anhidrita (CaSO₄). Solubilidad controlada por pH, salinidad y temperatura: **sube el pH o la temperatura → baja la solubilidad; suben los cloruros → sube la solubilidad**.
- **Síntomas:** ↑viscosidad, geles y filtrado; **↑calcio en el filtrado**; **↓pH y ↓alcalinidad** (el yeso tiene pH 6–6,5).
- **Indicadores más confiables:** la combinación *bajada de pH/alcalinidad + subida de calcio en filtrado*.
- Los recortes pueden traer bolitas blandas de material soluble en ácido.

**Tratamiento:**
1. Subir desfloculante: lignosulfonato y lignito son eficaces con calcio presente (el **lignito quela** el calcio y lo retira).
2. Mantener **pH 9,5–10,5** con soda cáustica (NaOH) o potasa cáustica (KOH) — ese rango limita la solubilidad del yeso y mejora el rendimiento del lignosulfonato.
3. Precipitar el calcio: **carbonato de sodio preferido** (pH 11–11,4) sobre bicarbonato de sodio (pH 8–8,5), porque el bicarbonato genera un período intermedio con Ca(HCO₃)₂ soluble que puede ser tan problemático como la contaminación original. Alternativa: fosfatos (SAPP pH 4,8; STP/PHOS pH 8,0), limitados a **< 200 °F**.
4. Sobre 200 °F, el carbonato de sodio es el producto preferido.

**Si se perfora una sección grande:** convertir el sistema a base de calcio.
- **Lodo yeso:** exceso de 5–8 lb/bbl de yeso, pH 9,5–10,5, calcio soluble típico 600–1.200 mg/l. Habrá una "cresta" de viscosidad al añadir el yeso que baja tras una circulación.
- **Lodo cal:** pH > 11,5 para mantener la cal insoluble en exceso. Requiere mucha más soda cáustica → generalmente **se prefiere el lodo yeso**.
- Ambos necesitan controlador de filtrado tolerante al calcio (POLYPAC, POLY-SAL, RESINEX).

### 1.5 Sal (Cap. 4C, *Contaminación de Sal*, 4C.14–4C.16)

Tres sales naturales en orden de solubilidad creciente: **halita (NaCl) → silvita (KCl) → carnalita (KMgCl₃·6H₂O)**.

- **Mecanismo:** intercambio catiónico + acción de masas del catión dominante. El sodio flocula y luego **deshidrata** las arcillas: baja algo la PV (menos agua adsorbida) pero dispara **YP, geles y filtrado**.
- **Síntomas:** ↑viscosidad, ↑filtrado, **↑↑cloruros**, ↑dureza, ↓pH y Pf.
- El filtrado aumenta **en proporción directa** a la sal incorporada.
- Un **flujo de agua salada** es más dañino que perforar sal de roca: ya está disuelta y reacciona de inmediato.

**Tratamiento:**
1. Desfloculante (lignosulfonato) hasta desflocular las arcillas, más **dilución con agua dulce** — la dilución es la **única** forma económica de bajar cloruros (ni el sodio ni el cloruro se precipitan de forma rentable).
2. Soda cáustica para sostener **pH > 9,5**: la halita pura tiene pH 7, así que cuanta más sal, más NaOH. Por debajo de 9,5 los desfloculantes base ácido dejan de ser solubles y pierden eficacia.
3. Control de filtrado obligatorio sobre **10.000 mg/l** de cloruros (RESINEX, POLY-SAL, SP-101, MY-LO-JEL, POLYPAC, bentonita prehidratada).
4. **La bentonita nunca se añade seca** a un sistema salado: hay que prehidratarla y protegerla antes.

**Decisión clave de sección salina** (traducible a una bifurcación de nivel):
- Si la sal se **entuba pronto** → diluir con agua y controlar viscosidad.
- Si la sal queda **expuesta mucho tiempo** → **saturar el sistema con NaCl** para impedir el ensanchamiento del pozo. Si se usa almidón para filtrado, mantener NaCl ≈ **190.000 mg/l** para evitar fermentación, o usar biocida.

**Carnalita — caso especial y peligroso:**
- Aporta calcio **y** magnesio. El Mg²⁺ con OH⁻ precipita como **Mg(OH)₂**, una sustancia gelatinosa que actúa de viscosificador y espesa el lodo.
- La reacción arranca con apenas **0,03 lb/bbl de soda cáustica**. → **Si es posible, NO usar soda cáustica** con carnalita: la viscosidad empeora.
- Esta es la excepción a la regla general "si baja el pH, echa cáustica" — buen material para un nivel que castigue el piloto automático.
- Para controlar calcio en fluidos con mucho magnesio: **sulfato de sodio (Na₂SO₄)**, que lo fija hasta un máximo de 400 mg/l sin tocar potasio ni magnesio.

### 1.6 Magnesio / agua salada dura (Cap. 4C, 4C.16 y *Referencia Rápida* 4C.19)

- **Síntomas:** punto cedente y filtrado inestables; **dureza alta incluso después** de tratar el calcio con carbonato de sodio; bajada rápida de pH; el lodo **espesa** al añadir soda cáustica o carbonato de sodio.
- **Diagnóstico:** la valoración de dureza total mezcla calcio y magnesio → hay que **valorarlos por separado** para confirmar magnesio.
- **Tratamiento (solo contaminación leve, tipo agua salada):** subir pH a 11 con NaOH o KOH para precipitar el Mg(OH)₂, y **mantener** ese pH para que no se vuelva a solubilizar.
- ⚠️ **NO** aplicar este tratamiento a contaminación masiva de magnesio (carnalita).

### 1.7 Carbonatos / bicarbonatos (Cap. 4C, 4C.7–4C.13)

El manual lo llama "uno de los conceptos menos comprendidos y más complicados" de la química de lodos. Es el mejor candidato a nivel avanzado del juego.

- **Fuentes:** CO₂ del aire entrando por las **tolvas de mezcla**; **exceso de carbonato/bicarbonato de sodio al tratar cemento o yeso**; CO₂ de formación; degradación térmica de lignosulfonato/lignito **> 325 °F**; baritas impuras.
- **Síntomas:** geles altos y progresivos, **↑Pf con pH constante**, **diferencia Pf–Mf creciente**, YP alto. Puede llegar a solidificar el lodo.
- **Regla de cribado:** `Mf < 5 ml` → normalmente no hay problema. `Mf > 5 ml` **y** relación Mf/Pf creciente → muy probable contaminación de carbonatos; confirmar con pH/Pf o Garrett Gas Train.

**Química del tratamiento:**
- Solo el ion **CO₃²⁻** precipita con calcio. El **HCO₃⁻ no**, porque el Ca(HCO₃)₂ es soluble.
- Hay que convertir HCO₃⁻ → CO₃²⁻ subiendo el pH a **mínimo 10,3, sin exceder 11,3**. (La conversión total se completa a 11,7.)
- Mantener **calcio libre de 150–200 mg/l** en el sistema.

**Selección de fuente de calcio según pH** (regla de decisión limpia, ideal para el juego):

| pH del lodo | Tratamiento |
|---|---|
| < 10,3 | **Cal** — aporta hidroxilo (sube pH) y calcio |
| 10,3 – 11,3 | **Cal + yeso juntos** — calcio sin mover el pH |
| > 11,3 | **Yeso** — calcio y además baja el pH |

- Reacciones: `CO₃²⁻ + Ca(OH)₂ → CaCO₃↓ + 2OH⁻` · `CO₃²⁻ + CaSO₄ → CaCO₃↓ + SO₄²⁻`
- Las cantidades salen de los Gráficos I y II del manual (entrada: Pf y pH), **multiplicadas por la fracción de agua Fw**. Pueden hacer falta varias aplicaciones en varias circulaciones.

> 🎓 **La trampa pedagógica perfecta** (4C.11): al añadir soda cáustica el lodo *parece* desflocularse y la viscosidad baja — pero lo único que pasó es que los bicarbonatos se convirtieron en carbonatos. **El fenómeno se repite indefinidamente hasta identificar el problema real.** Un jugador que trate síntomas en vez de causas queda atrapado en este bucle. Mecánica lista para usar.

### 1.8 H₂S (Cap. 4C, 4C.17–4C.18)

El contaminante más severo y corrosivo del capítulo. Tóxico y destructivo para la tubería.

- **Identificación:** ↓pH; lodo o tubería **ennegrecidos** (FeS formado a partir de la barita); olor a huevo podrido; ↑viscosidad y filtrado; incrustaciones negras en la sarta.
- **Detección cuantitativa:** Garrett Gas Train (preciso) o prueba de Hach.

**Tratamiento:**
1. Subir el pH **inmediatamente a 11,5–12** con soda cáustica.
2. **Amortiguar con cal.**
3. **Precipitar con óxido de cinc:** `H₂S + ZnO → ZnS↓ + H₂O`. Dosis: **1 lb/bbl de ZnO elimina ~1.000 mg/l de sulfuros**; no exceder **2 lb/bbl** en pretratamiento. Añadir 1–2 lb/bbl de SPERSENE.
4. Si el H₂S fluye de la formación, **subir la densidad** del lodo para cortar el aporte.

> ⚠️ **Por qué el cinc no es opcional:** subir el pH convierte H₂S en sulfuro, pero **la reacción es reversible**. Si el pH cae, vuelve a ser H₂S venenoso. Por eso **siempre** hay que precipitarlo con una fuente de cinc, no solo alcalinizar.

### 1.9 Sólidos de perforación (Cap. 4C, 4C.1 y Cap. 5)

Económicamente **el contaminante de mayor impacto** sobre el costo del lodo, por encima de los químicos.

- **Sólidos "antiguos"** (ya dispersos): ↑densidad, ↑FV, **↑PV**, ↑geles, ↑%sólidos — sin cambios químicos. → **agua de dilución + equipo de remoción de sólidos**.
- **Sólidos "nuevos"** (recién incorporados): mueven *todo*, físico y químico. → agua de dilución + remoción mecánica + **diluyente químico**.
- La firma distintiva frente a los contaminantes químicos: **la PV sube** (los contaminantes químicos mueven YP y geles, no PV).

Tres vías de control (Cap. 5): **control mecánico**, **asentamiento**, **dilución o desplazamiento**.

---

## 2. Cálculos de manejo de tanques

Todo sale de dos ecuaciones (Cap. 9, *Cálculos de Ingeniería*):

```
Balance de masas:    V_total × ρ_total = Σ (V_i × ρ_i)
Balance de volúmenes: V_total = Σ V_i
```

El método del manual: dibujar el diagrama, tabular conocidas/incógnitas, despejar el balance de volúmenes y sustituir en el de masas.

**Constantes de campo:**

| Material | Densidad | Equivalencias |
|---|---|---|
| Barita (M-I BAR) | 35,0 lb/gal (SG 4,2) | 1.470 lb/bbl · 100 lb/saco · **14,7 sacos/bbl** |
| Agua dulce | 8,345 lb/gal | — |
| LGS (sólidos de baja gravedad) | 21,7 lb/gal (SG 2,6) | — |

### 2.1 Densificar con barita (Cap. 9, Ejemplo 4, 9.28)

```
Barita (lb/bbl) = 1.470 × (PL₂ − PL₁) / (35 − PL₂)        [PL en lb/gal]
Barita (kg/m³)  = 4.200 × (ρ₂ − ρ₁) / (4,2 − ρ₂)          [ρ en kg/l]

Volumen de barita (bbl) = V_inicial × (PL₂ − PL₁) / (35 − PL₂)
Aumento de volumen (bbl) = sacos de barita / 14,70
```

**Ejemplo del manual:** 1.000 bbl de 14,0 → 16,0 ppg
`V_bar = 1.000 × (16−14)/(35−16) = 105,3 bbl` → `105,3 × 1.470 / 100 = 1.548 sacos`
**Volumen final = 1.105,3 bbl.** Densificar **aumenta** el volumen del sistema — hay que tener dónde ponerlo.

### 2.2 Diluir / bajar densidad (Cap. 9, Ejemplo 5, 9.29)

Mismo balance, tratando el agua como un "lodo" de 8,345 ppg:

```
V_agua = V_inicial × (PL₁ − PL₂) / (PL₂ − 8,345)
```

**Ejemplo:** 1.000 bbl de 16,0 → 12,0 ppg requiere **1.094 bbl de agua**, con volumen final de **2.094 bbl**.

> 💡 **Observación del manual que es una mecánica de juego completa:** si el volumen de dilución necesario es tan grande, **suele ser más fácil y barato preparar 1.000 bbl de lodo nuevo que diluir el viejo**. El jugador debe comparar las dos rutas, no solo ejecutar la obvia.

### 2.3 Mezclar dos lodos

```
ρ_final = (V₁ρ₁ + V₂ρ₂) / (V₁ + V₂)
```

**Ejemplo (Cap. 9, 9.27):** preparar 1.000 bbl de 14,0 ppg a partir de lodos de 11,2 y 15,4 ppg →
`V₁ = 1.400/(15,4−11,2) = 333,3 bbl` de 11,2 ppg + **666,7 bbl** de 15,4 ppg.

### 2.4 Reducir sólidos manteniendo el peso (Cap. 9, Ejemplo 6, 9.30)

Se aplica el balance de masas usando **%sólidos** en vez de densidad, y luego se repone el peso con una lechada barita/agua.

**Ejemplo:** 1.000 bbl al 8% de sólidos → 6%, manteniendo 12,0 ppg:
`V_lechada = (8−6)/6 × 1.000 = 333,3 bbl`, volumen final 1.333,3 bbl.
Dentro de esa lechada: **45,7 bbl de barita (672 sacos) + 287,6 bbl de agua**.

### 2.5 Análisis de sólidos y volúmenes

```
Vol % LGS = 100 × (ρ_lodo − ρ_agua) / (ρ_LGS − ρ_agua)      [no densificado, agua dulce]

Volumen del pozo (bbl) = ID²(pulg) / 1.029 × L(ft)
Velocidad anular (ft/min) = 24,5 × gpm / (D_h² − D_p²)
Tiempo de retorno BU (min) = (D_h² − D_p²) / (1.029 × bbl/min)
```

---

## 3. Píldoras

Una píldora es un volumen discreto de fluido con propiedades distintas al sistema activo, bombeado para una tarea puntual.

| Tipo | Para qué | Notas del manual |
|---|---|---|
| **Barrido viscoso / de gel** | Limpieza del pozo: levantar camas de recortes | Barridos de alta viscosidad; se monitorea el retorno — la píldora debe volver cargada de sólidos (Cap. 14/15) |
| **Barrido de baja viscosidad / alta densidad** | Remover camas en pozo desviado por turbulencia | Cap. 15 |
| **LCM (pérdida de circulación)** | Sellar zonas de pérdida | Material fibroso/granular/laminar; G-SEAL, carbonato de calcio. Se colocan frente a la zona ladrona; pueden densificarse (Cap. 14) |
| **Desatascadora (aceite diesel)** | Liberar tubería pegada por presión diferencial | Procedimiento de colocación por presión, abajo (Cap. 15, 15.16–15.17) |
| **Píldora de HCl** | Disolver revoque con carbonato de calcio | `CaCO₃ + 2HCl → CaCl₂ + CO₂↑ + H₂O` (Cap. 4A) |

### 3.1 Colocación de píldora desatascadora (Cap. 15, 15.16–15.17)

La posición de la píldora no se adivina: **se calcula desde la presión anular**.

```
Longitud de columna (ft) = presión anular (psi) / diferencia de gradientes (psi/ft)
gradiente (psi/ft) = densidad (ppg) × 0,052
```

**Ejemplo del manual** — pozo 8½", tubería 4½", pegado a 10.000 ft, punto libre 7.300 ft, píldora de 100 bbl de diesel:
- Diesel 6,8 ppg → 0,3536 psi/ft · Lodo 10 ppg → 0,5200 psi/ft · **Δgradiente = 0,1664 psi/ft**
- Se bombean 100 bbl dentro de la sarta → presión en sarta 1.170 psi → columna = 1.170/0,1664 = **7.031 ft** (confirma que se colocaron los 100 bbl)
- Se desplaza; presión anular 185 psi → columna 1.112 ft → tope de la píldora a 8.888 ft
- Se desplazan 100 bbl más; anular 100 psi → columna 601 ft → tope a 8.287 ft
- Se desplazan 90 bbl (el tanque perdió 10 bbl → esos 10 se fueron al pozo abierto); anular 165 psi → columna 992 ft → **tope a 7.295 ft ≈ punto pegado (7.300 ft)** ✔

**Precauciones:** corregir por altura vertical en pozo direccional; medir los desplazamientos con cuentaemboladas o tanques de medición; el peso del lodo debe ser uniforme en todo el sistema.

> Mecánica implícita: **la pérdida en tanques es información**, no ruido. Si el tanque bajó 10 bbl, se bombean 90 en vez de 100. Un jugador que ignore el nivel de tanque coloca mal la píldora.

---

## 4. Cambio / desplazamiento de fluido

El manual no dedica un capítulo a esto; lo que aporta está disperso y se resume así:

- **Conversión de sistema** (Cap. 4C, 4C.4): cuando la contaminación es tan grande que no se puede mantener el lodo, se **convierte** el sistema — p. ej. a lodo yeso o lodo cal ante secciones gruesas de anhidrita. Se trata con soda cáustica + lignosulfonato + yeso adicional, aparece una cresta de viscosidad, y tras **una circulación** el tipo de lodo cambia y la viscosidad baja.
- **Dilución vs. lodo nuevo** (Cap. 9, 9.29): decisión económica explícita; por encima de cierto volumen de dilución conviene preparar lodo fresco.
- **Desplazamiento como control de sólidos** (Cap. 5): una de las tres vías válidas junto con el control mecánico y el asentamiento.
- **Tiempo de retorno (BU)** es la unidad natural para planificar un desplazamiento: `BU = volumen anular / caudal`.

> ⚠️ Vacío de la fuente: no hay procedimiento paso a paso de desplazamiento (baches separadores, secuencia, criterios de limpieza). Si el juego va a tener un nivel de cambio de fluido, hace falta otra fuente.

---

## 5. Diagnóstico de reología — "vi este número raro, ¿qué hago?"

Fórmulas base (Cap. 5, 5.4):
```
PV (cP)            = Θ600 − Θ300
YP (lb/100 ft²)    = Θ300 − PV = 2 × Θ300 − Θ600
```

**Regla de oro:** `PV ≈ sólidos` · `YP ≈ química`. Esa es la bifurcación raíz de todo el árbol de diagnóstico.

### 5.1 PV alta

**Significa sólidos**: cantidad, tamaño y forma de partículas, más la viscosidad de la fase fluida.

**Causas:** acumulación de sólidos perforados (si no se remueven rápido se siguen fracturando en partículas más finas al recircular); polímeros de cadena larga recién mezclados (POLY-PLUS, HEC, POLYPAC R, CMC); salmuera como fase continua; aceite emulsionado (actúa como sólido); baja temperatura.

**Tratamiento:** control mecánico de sólidos → asentamiento → dilución/desplazamiento. Si el problema es polímero recién añadido, el efecto es transitorio.

> **Límite práctico: `PV ≤ 2 × peso del lodo (ppg)`** (Cap. 5, 5.4). Umbral numérico listo para usar como criterio de "fuera de especificación" en el juego.
>
> Mantener la PV lo más baja posible: mejora la energía en la barrena, la limpieza anular, y reduce desgaste y consumo de combustible.

### 5.2 YP alto

**Significa floculación** — fuerzas electroquímicas de atracción entre partículas.

**Causas (Cap. 5, 5.5):**
1. Contaminantes solubles: **sal, cemento, anhidrita o yeso** → floculan las arcillas. *(→ ir a la sección 1)*
2. Trituración de arcillas por barrena y sarta → valencias de enlace roto en los bordes.
3. Sólidos inertes que acercan las partículas entre sí.
4. Lutitas hidratables perforadas → nuevos sólidos activos.
5. **Sub o sobre-tratamiento** con químicos cargados.
6. Biopolímeros ramificados (DUO-VIS, FLO-VIS, XCD).

**Tratamiento:**
1. **Desfloculantes aniónicos** — neutralizan las valencias de borde: taninos y ligninas (TANNATHIN, XP-20, K-17), fosfatos (PHOS, SAPP), lignosulfonatos (SPERSENE), poliacrilatos de bajo peso (TACKLE, SP-101).
2. Si la causa es **calcio o magnesio**: precipitarlos como insolubles (ver §1).
3. **Agua**: poco eficaz salvo con sólidos muy altos, y en lodos densificados **sube el filtrado y baja el peso** (obligando a re-densificar). Último recurso.

**Principio general:** aniónicos (carga negativa) → desfloculan y bajan viscosidad. Catiónicos (carga positiva) → floculan y suben viscosidad.

### 5.3 YP bajo

Añadir viscosificador comercial. También sube con cualquier cosa que flocule: p. ej. **poca cal en agua dulce con bentonita hidratada** sube el YP — pero la floculación daña el filtrado, las presiones de circulación y los geles. Referencia: en lodos de lignosulfonato disperso, el YP se mantiene ≈ al peso del lodo en ppg.

### 5.4 Geles altos

Tixotropía excesiva. Mismo origen químico que el YP alto. **Los carbonatos/bicarbonatos son la causa clásica de geles progresivos** (§1.7).

### 5.5 Limpieza de pozo en direccional / horizontal

La **LSRV** (lecturas a 6 y 3 RPM) predice la limpieza mejor que el YP, y sostiene la suspensión de barita en estático y dinámico. Un fluido puede tener YP alto y aun así no suspender barita (caso de CMC, PAC y HEC en agua: tienen YP pero no suspenden).

---

## 6. Programa de lodos

El manual solo lo define en el glosario:

> **Programa de Lodo:** plan o procedimiento propuesto o aplicado para el tipo y las propiedades de los fluidos de perforación usados en la perforación de un pozo, **respecto a la profundidad**. Factores que lo influyen: el **programa de revestimiento** y las características de la formación — tipo, competencia, **solubilidad**, temperatura y presión.

Lo esencial para el juego: el programa es **por secciones/profundidad**, atado al revestimiento, y anticipa la litología. De ahí sale la estructura natural de niveles: cada sección del pozo = un nivel, con su ventana de propiedades objetivo y sus contaminantes esperables.

> ⚠️ Vacío de la fuente: no hay formato ni ejemplo de programa de lodos real en el manual. El reporte diario sí existe (Cap. 9, 9.37) pero la sección solo describe la **distribución de copias**, no el contenido del formato.

---

## 7. Pruebas de laboratorio

| Prueba | Mide | Qué se concluye |
|---|---|---|
| **Balanza de lodo** | Densidad (ppg, lb/ft³, SG, gradiente) | Control de presión hidrostática |
| **Embudo Marsh** | Viscosidad embudo (seg/qt) | Indicador grueso de cambio; primera alarma de contaminación |
| **Viscosímetro FANN (VG)** | Θ600, Θ300, Θ200, Θ100, Θ6, Θ3 | PV, YP, viscosidad aparente, LSRV |
| **Geles (10 s / 10 min)** | Esfuerzos de gel (lb/100 ft²) | Tixotropía, suspensión de barita |
| **Filtro prensa API** | Filtrado en 30 min @ 100 psi | Control de filtrado y calidad del revoque |
| **Filtro prensa ATAP/HTHP** | Filtrado a alta P y T | Comportamiento real en fondo |
| **Retorta** | % agua, aceite y sólidos | **Da el Fw** de las fórmulas de tratamiento (§1.2) |
| **Azul de metileno (MBT)** | Capacidad de intercambio catiónico | Sólidos arcillosos reactivos. **MBT < 15 lb/bbl → poca sensibilidad a contaminación** |
| **pH (electrodo)** | Alcalinidad | Con cloruros altos, **usar sonda compensada para sales**; el papel pH lee bajo |
| **Pm** | Alcalinidad del lodo | Clave para **cemento** y para el exceso de cal |
| **Pf / Mf** | Alcalinidad del filtrado | Diagnóstico de **carbonatos/bicarbonatos** (relación Mf/Pf) |
| **Dureza total** | Ca²⁺ (y Mg²⁺) | **Valorar Ca y Mg por separado** para distinguir magnesio |
| **Cloruros** | Salinidad | Identifica **sal**; grado de saturación de NaCl |
| **Contenido de arena** | Partículas > malla 200 | Abrasividad, eficiencia del equipo de sólidos |
| **Garrett Gas Train (GGT)** | Carbonatos totales y sulfuros | Cuantitativo para **carbonatos** y **H₂S** |

Nota de cálculo: carbonatos de mg/l a milimoles/l → dividir entre **60** (bicarbonatos, entre **61**).

Trampa de medición documentada (Cap. 4A, 4A.29): el **lignito contiene 1,5–5% de calcio** y además lo acompleja. Una valoración de dureza puede indicar calcio suficiente cuando en realidad **no hay calcio disponible** para reaccionar con los carbonatos. 1 lb/bbl de lignito solubilizado puede acomplejar 200 mg/l de calcio.

---

## Fuente

*Manual de Fluidos de Perforación* — Procedimiento Estándar para las Pruebas de Fluidos de Perforación (API / M-I, Rev. A-1, 14-02-01). Capítulos usados: 3 (Pruebas), 4A (Química Básica), 4B (Química de Arcillas), 4C (Contaminación y Tratamiento), 5 (Reología e Hidráulica), 8 (Control de Sólidos), 9 (Cálculos de Ingeniería), 14 (Pérdida de Circulación), 15 (Pega de Tubería).
