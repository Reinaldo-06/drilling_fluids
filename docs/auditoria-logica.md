# Auditoría de la lógica de simulación

Revisión hecha con 228 pruebas pasando. Cada hallazgo dice qué falta o está mal, dónde, por qué importa en la realidad (con fuente cuando aplica) y una propuesta que respeta las invariantes de `CLAUDE.md`. Las cifras salen de sondeos corridos sobre el código; las líneas de código son aproximadas y pueden moverse.

Estado: **pendiente**. Ir tachando lo que se resuelva.

Hallazgos:

- [Crítico](#crítico): C1 a C6.
- [Importante](#importante): I1 a I13.
- [Menor](#menor).
- [Calibración contrastada](#calibración--contrastada).
- [Preguntas para el autor](#preguntas-para-el-autor).
- [Revisión del mapa](#revisión-del-mapa-overworld).

---

## Crítico

### ~~C1. Las reglas le revelan el contaminante al jugador~~ ✅ resuelto

**Resolución.**

- Las reglas se evalúan sobre las lecturas del tanque (`Props.de_medido`); lo no medido es NAN y no dispara nada.
- Para el "después" se usa lo medido más el cambio que causó la acción (`Props.proyectar`).
- Las reglas con `debrief_real = true` también se revisan contra el estado real. Si solo ahí se disparan, quedan en el debrief con `fuente: "real"`, sin aviso.
- El cierre del día usa solo lo medido.
- Pruebas en `tests/test_turno.gd`.

Hallazgo original:

**Qué pasa.** Las reglas `al_tratar` se evalúan sobre el estado interno del lodo, no sobre lo medido.

Un sondeo lo muestra. El jugador echa 0,01 lb/bbl de soda sin correr ninguna prueba y recibe «Soda cáustica con magnesio (carnalita)». Con un saco ya sabe qué contaminante hay.

Lo mismo pasa con estas reglas:

- `carbonato_de_sodio_sobre_cemento`
- `soda_caustica_en_carbonatos`
- `soda_caustica_sobre_cemento`

Al cerrar el día, lo no medido se rellena con el valor real.

**Dónde.**

- `sim/turno.gd`: `_evaluar` y `entregar_reporte` (`Props.de(t.lodo)` y luego `merge` de lo medido).
- `data/reglas/soda_caustica_con_carnalita.tres` y `carbonato_de_sodio_sobre_cemento.tres`.

**Por qué importa.** Rompe la invariante 1 y la fase 2: el acertijo se resuelve sin laboratorio.

**Propuesta.**

- Dar a las reglas dos contextos, `medido` (la última lectura con su hora) y `real`. Cada `.tres` declara `fuente`.
- Las reglas de aviso inmediato solo leen `medido`.
- Las que leen `real` van al debrief, con el texto «lo que de verdad había».
- Al cerrar el día, usar solo lo medido.

### ~~C2. El volumen no se conserva y la succión se vacía perforando~~ ✅ resuelto

**Resolución.**

- El hueco nuevo sale de todos los tanques del activo según su volumen.
- Si no alcanza el lodo, no se perfora.
- `Tanque.minimo_bbl()` vale por omisión el 25 % de la capacidad de la succión 🧩 (pregunta 4). Bajo ese mínimo, el driller para las bombas (caudal 0, no se perfora) y avisa con su explicación. Cuando vuelve el nivel, vuelven las bombas.
- Pruebas en `tests/test_operacion_pozo.gd`, incluido que el balance cuadra.

Hallazgo original:

**Qué pasa.** Un sondeo perfora 17½" a 80 ft/h:

- A la hora 9 la succión llega a 0 bbl, y el tanque de proceso sigue con 243 bbl.
- La profundidad sube 240 ft más.
- Ese hueco nuevo no se descuenta de ningún tanque.

**Dónde.**

- `sim/perforacion.gd`, función `paso`: `pies` se fija antes de mirar el volumen, y nadie usa `volumen_faltante_bbl`.
- `sim/operacion_pozo.gd`, función `_perforar`.
- `sim/cinetica.gd`: la homogenización iguala la composición, no los niveles.

**Por qué importa.** Con nivel bajo, la bomba forma vórtice y pierde la succión. Además, quedarse sin lodo con el pozo abierto es un problema de control de pozo. Fuentes: [Pumps & Systems](https://www.pumpsandsystems.com/guidelines-submergence-air-entrainment), [NOV](https://assets.nov.com/NCP4N68N/at/hx874gwq47r2pgzhhkp7zrb/Trouble_Shooting_Centrifugal_Pumps.pdf).

**Propuesta.**

- Repartir el hueco entre los tanques del activo según su volumen, como hace `restar_del_activo`.
- Agregar `Tanque.volumen_minimo_bbl`. Bajo ese mínimo, el driller para las bombas y aparece un aviso con su explicación.
- Si no hay volumen, `pies` = 0.
- Agregar una prueba de conservación (tanques + pozo).

### C3. La catástrofe del cemento en KCl/PHPA no existe

**Qué pasa.** Se agrega 1 lb/bbl de cemento:

| Sistema | PC | Gel 10 min | PHPA | ¿Sale del programa? |
|---|---|---|---|---|
| KCl/PHPA | 15 → 20 | 14 → 20 | intacto a pH 12,4 | no |
| Spud | 16 → 41 | — | — | sí |

La tabla de vulnerabilidades sale al revés. Hay dos causas:

- La floculación escala con el MBT, con piso de 0,2.
- Ni el pH ni el calcio afectan al PHPA.

El campo `vulnerabilidades` de los sistemas no lo lee ningún código.

**Dónde.** `sim/estado_lodo.gd` (floculación), `sim/sistema_lodo.gd` y `data/eventos/c3i_cemento_zapata.tres`. La explicación de ese evento promete la hidrólisis.

**Por qué importa.** Es el evento central de CAIMÁN-3. El pH alto hidroliza el PHPA y el Ca²⁺ lo precipita ([US 5028341](https://patents.justia.com/patent/5028341)). Contra el cemento se pretrata con bicarbonato ([SLB](https://glossary.slb.com/terms/s/sodium_bicarbonate), [Drilling Manual](https://www.drillingmanual.com/mud-contamination-cement-precautions/)).

**Propuesta.**

- Hidrólisis del PHPA que crece con el pH por encima de ~10 y con la temperatura.
- Pérdida de PHPA activo por Ca²⁺, que también sume a la floculación y al filtrado.
- Constantes como dato 🧩.
- Variable `nh3` para el olor a amoníaco.
- Prueba de Tabla 4 por sistema que exija el orden spud < disperso < KCl/PHPA.

### C4. El cemento de la zapata está en el hueco de 17½" y se cuenta dos veces

**Qué pasa.**

- La formación `caiman_3_cemento_zapata` va de 2.420 a 2.510 ft, así que se perfora cemento antes de bajar el revestidor.
- El evento `c3i_cemento_zapata` vuelve a meter cemento.

**Por qué importa.** En la realidad el cemento se rota dentro del revestidor, sin hueco nuevo.

**Propuesta.** Una operación del guion, «rotar cemento»:

- no avanza la profundidad;
- no consume hueco;
- aporta un contaminante por cada pie rotado.

Debe quedar una sola fuente de cemento.

### C5. El pozo no tiene composición

**Qué pasa.**

- Sólidos y contaminantes entran directo a la succión.
- Los contaminantes de los eventos entran de golpe a todo el activo.
- El pozo es solo un número.

**Dónde.** `sim/operacion_pozo.gd`, `sim/guion_ejecucion.gd` (`aplicar_contaminante`) y `sim/cinetica.gd`.

**Por qué importa.** Sin composición no se puede enseñar:

- la caja de llegada frente a la succión;
- el gas de fondo arriba;
- la interfase del desplazamiento;
- las píldoras.

Además, el cambio de fluido es el hito de progresión.

**Propuesta.** Un pozo con sarta y anular. El anular funciona como un tren de bloques de flujo pistón (~10 bbl 🧩). En cada paso:

1. Entra lodo de la succión.
2. El bloque del fondo sale a la caja de llegada (un tanque con rol `llegada`) con los recortes y contaminantes de su momento.

### C6. No hay píldoras ni material de pérdida

**Qué pasa.**

- No se puede bombear el tanque de píldoras.
- No existe producto LCM.
- Nadie llama a `terminar()`.
- `c3p_perdida_parcial` dura 4 h haga lo que haga el jugador.
- No hay barrido viscoso ni píldora de viaje.

**Por qué importa.** Las píldoras son la prioridad 4 del diseño, y aquí un tratamiento correcto no tiene efecto. Fuentes: [SLB Trip pill](https://glossary.slb.com/en/terms/t/trip_pill), [IWCF](https://www.iwcf.org/wp-content/uploads/2025/11/EX-0037-Drilling-English-BL-10.2-Formula-Sheet_New.pdf).

**Propuesta.**

- Acción `bombear_pildora(tanque, bbl)`, sobre C5.
- Productos LCM como dato, con `tamano_um` y `sello`.
- El evento declara `d50_requerido_um` y `sello_requerido`.
- Una píldora adecuada que llega a la zona reduce la tasa de pérdida. Una inadecuada no, y explica por qué.

---

## Importante

**I1. SIDPP fijo.** `c3i_influjo` dispara con MW < 10,2 ppg, siempre con 260 psi. Con 10,19 ppg el peso de matada es 10,9, que pasa el máximo del programa (10,8). Entonces `sobre_densificar` castiga al jugador por obedecer.

Propuesta:

- `Formacion.presion_poro_ppg` y `gradiente_fractura_ppg` como datos.
- SIDPP = 0,052·TVD·(Pporo − MW).
- `sobre_densificar` no se dispara con una exigencia de matada activa.

Fuente: [IADC WSP](https://iadc.org/wp-content/uploads/2025/04/WSP-FormulaSheet_FieldUnits_rev4.pdf).

**I2. Sin ECD ni gradiente de fractura.** `Formulas.ecd` no se usa, y sobre-densificar no tiene consecuencia física.

Propuesta: ECD = MW + ΔP anular, con ΔP función de PC, VP, caudal y geometría 🧩. Si la ECD pasa el gradiente de fractura, aparece una pérdida inducida.

Fuentes: [GA Drilling](https://www.gadrilling.com/glossary/equivalent-circulating-density-ecd), [Enhanced Drilling](https://blog.enhanced-drilling.com/formation-limit-testing-lot-fit-drilling-pressure-window).

**I3. La sal no se satura.**

| NaCl agregado | Cl⁻ resultante | Densidad |
|---|---|---|
| 126 lb/bbl | 218.000 mg/l | 10,27 ppg |
| 186 lb/bbl | 322.000 mg/l | — |

Ninguno de esos valores es posible. A saturación, Cl⁻ ≈ 189.000 mg/l ([US 7635667](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/7635667), [SLB](https://glossary.slb.com/terms/s/saltwater_mud)).

Propuesta:

- Tope de sal disuelta; el resto queda como sólido.
- La sal disuelta suma volumen.
- Un lodo bajo saturación disuelve la sal de la formación y agranda el hueco.

**I4. El yeso no tiene solubilidad.** 8 lb/bbl dan Ca 5.470 mg/l. El sistema cálcico armado según su programa sale floculado al máximo, con PC 34,5 y filtrado 17. Lo real con 2–4 lb/bbl de exceso es Ca 600–1.200 mg/l ([World Oil](https://worldoil.com/magazine/2000/june-2000/supplement/00-06_fluids2000-intro-htm-jun-2000/), [SLB](https://glossary.slb.com/terms/g/gyp_mud)).

Propuesta:

- Ksp del CaSO₄ que dependa de los cloruros, con `yeso_exceso` como reserva.
- Medir el daño por calcio contra un «Ca de equilibrio» del sistema.

**I5. El bucle de carbonatos va al revés del diseño.** La soda empeora el PC sin parar, porque el CO₃²⁻ pesa el doble que el HCO₃⁻. Además no hay una fuente continua de CO₂.

No hay fuente pública de que la soda adelgace de forma transitoria, así que queda **no verificado**. Newpark dice que con CO₂ «las propiedades no responden» ([Newpark](https://newpark.com/contaminants)). Ver la pregunta 1.

**I6. El gas no mete aire al lodo.** Nadie cambia `aire`, así que la espuma, la trampa de la balanza y la balanza presurizada nunca aparecen.

Propuesta:

- Los eventos de gas suman aire en la llegada.
- El embudo suma aire por saco.
- El aire sale con un τ que crece con geles y PC.
- Producto antiespumante.

Fuentes: [EP 0339762](https://data.epo.org/publication-server/rest/v1.2/patents/EP0339762NWA2/document.html), [US 6357906](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/6357906).

**I7. Hay un solo filtrado para todo.** `correr_prueba` usa el último filtrado del turno, de cualquier tanque, y lo da por fresco.

Propuesta: guardar el filtrado por tanque y por hora, y mostrar la edad de la muestra.

**~~I8. La casilla de calcio del reporte.~~** ✅ El Ca lo llena `calcio_magnesio` y la dureza total, `dureza`. Sigue abierta la pregunta 7 (qué especifica el programa). `FILAS` dice que el Ca lo mide `dureza`, pero `dureza.tres` devuelve `dureza_total`.

Propuesta: alinear las claves y decidir si el programa pide Ca o dureza (pregunta 7).

**I9. No hay temperatura.** `Turno.temperatura` está siempre vacía y falta la temperatura de fondo (BHT). Eso deja afuera:

- la reología en fondo;
- la degradación del almidón y la goma xantana;
- el SAPP, que no sirve sobre 200 °F;
- el lignosulfonato, que libera CO₂ sobre 325 °F.

Propuesta: gradiente geotérmico como dato, temperatura de salida simple y degradación por producto.

**I10. Faltan productos y pruebas.**

- Productos: antiespumante, biocida, LCM, sulfato de sodio (manual §1.5), KOH y grados de CaCO₃.
- Pruebas: amina, PHPA, contenido de arena, HTHP y prueba piloto. La piloto es trivial con `EstadoLodo.copiar()`.

Fuentes: [OGJ, PHPA](https://ogj.com/home/article/17219889/method-aids-calculation-of-phpa-depletion-rates), [US 5557103](https://patents.google.com/patent/US5557103), [SLB XC](https://glossary.slb.com/terms/x/xc_polymer), [SLB bactericida](https://glossary.slb.com/terms/b/bactericide).

**I11. Solo existe un lodo base, el disperso.** CAIMÁN-3 usa bentonítico, KCl/PHPA y RDF. El KCl/PHPA armado según su programa da filtrado 12,8 ml (el programa pide 4–6) y MBT 0.

Propuesta: un lodo base por sistema, como dato, con una prueba de que cumple su programa.

**I12. La falsa alarma del PVT no cuesta nada.** Nadie usa `enganches_alarma_pvt` ni `minutos_perdidos_falsa_alarma`.

Propuesta: parar la perforación esos minutos y cobrarlos como tiempo de taladro.

**I13. El RDF no pierde CaCO₃ en los equipos.** `procesar` solo saca barita y sólidos livianos, aunque el CaCO₃ tiene densidad parecida a la de los sólidos perforados ([US 6983798](https://patents.google.com/patent/US6983798)).

Propuesta: agregar `eficiencia_caco3` por equipo.

---

## Menor

- **Prehidratación ficticia.** El flag solo apaga la regla. Propuesta: preparar la bentonita en otro tanque y transferirla, o que el flag la haga entrar ya hidratada.
- **El sedimento no hace nada.** Transferir desde un tanque asentado no manda lodo más liviano (`rig-tank-system.md` §4, regla 6).
- **Observaciones sin variable detrás.** Faltan recortes, derrumbes (ya calculados), nivel de tanques, sedimento y grumos. El rebose de zarandas no descarta lodo.
- **Retorta sin corrección por sal.** Con salmuera, el reparto entre barita y sólidos de baja gravedad sale mal ([SLB](https://glossary.slb.com/terms/t/total_solids)).
- **El spud filtra demasiado poco.** El modelo da 7,5 ml con 20 lb/bbl; API admite ~15 ml ([US 4371626](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/4371626)). Esto también afecta la filtración de la superficial.
- **La noche solo repone con agua.** Así diluye KCl, PHPA y barita. Falta la opción de reponer con premezcla de la reserva.
- **Logística y ambiente.** No hay camiones ni tiempos de entrega, el agua es infinita y no hay costo ni límite de descarte.
- **El influjo y el sag no dejan rastro.** El influjo trae lodo idéntico; un flujo de agua salada debería traer sal. El sag es solo texto.
- **Lignito.** No acompleja calcio, aunque su descripción lo promete.
- **Observación de H₂S.** «Olor a huevo podrido… gas tóxico» casi identifica el contaminante. Propuesta: que la alarma la dé el detector de gas y que el sulfuro solo lo cuantifique el GGT.

## Calibración 🧩 contrastada

- **En rango:** costos por saco, umbral del PVT de 10 bbl, 50 sacos/h, filtración de 1–10 bbl/h.
- **Fuera de rango:**
  - filtrado del spud;
  - Ca del yeso sin tope;
  - Cl⁻ sin tope;
  - piso de 0,2 de reactividad por MBT;
  - umbral de carbonatos: solo da síntomas físicos desde ~6.000 mg/l de HCO₃⁻.

## Preguntas para el autor

1. **Soda sobre carbonatos.** ¿Adelgaza un rato y el problema vuelve, o empeora enseguida? ¿De dónde viene el CO₂ que no para: el embudo, la formación o la degradación?
2. **Cemento en KCl/PHPA.** ¿Cómo se ve en campo? ¿A qué Ca o pH empieza el daño? ¿Se pretrata con bicarbonato y con cuánto?
3. **Rotar el cemento.** ¿Cuántos pies de cemento hay entre el cuello flotador y la zapata? ¿Cuántos pies nuevos se perforan antes de la prueba de integridad (FIT/LOT)? ¿Participa el ingeniero de lodos?
4. **Volumen mínimo.** ¿Cuánto se mantiene en la succión y en el activo? ¿Quién para las bombas?
5. **Gas y espuma.** ¿Cuánto baja la balanza atmosférica con gas? ¿Cuánto tarda en limpiarse el lodo? ¿Se usa antiespumante?
6. **Píldoras.** ¿Qué se hace de rutina (barrido, píldora de viaje)? ¿Con qué receta y volumen? ¿Cómo se elige el tamaño del material de pérdida?
7. **Calcio.** ¿El reporte lleva Ca o dureza total? ¿Qué especifica el programa?
8. **Noche.** ¿Se repone con premezcla o con agua? ¿Hay un ingeniero de noche?
9. **Logística.** ¿Cada cuánto llegan los camiones de químicos y de agua? ¿Hay costos o límites de descarte?

---

## Revisión del mapa (overworld)

Pendientes encontrados al revisar `docs/img/overworld.png`:

1. **El múltiple no llega al activo.** El múltiple de transferencia conecta reservas, fractanques y píldoras, pero no la succión ni el proceso.
2. **Faltan equipos.** No están el desgasificador, el desarenador, el deslimador ni la centrífuga.
3. **Falta la segunda ruta de retorno.** Son dos: la canal y la centrífuga.
4. **Falta adónde va el descarte.** No hay caja ni fosa de recortes.
5. **Piezas sin conexión.** El tanque de agua, el embudo de abajo y su bomba no se conectan a ningún tanque.
6. **Válvula igualadora mal ubicada.** Está al frente de los tanques, no en la pared entre succión y proceso.
7. **La encuelladora está frente a la succión y no junto al embudo.** Su ficha dice «tanques».

Pregunta abierta: ¿en qué orden van los compartimientos? La propuesta es trampa de arena → desgasificador → desarenador → deslimador → proceso (con centrífuga) → succión, más una canal que se pueda desviar.
