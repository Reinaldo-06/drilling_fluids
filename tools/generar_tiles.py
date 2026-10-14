#!/usr/bin/env python3
"""Genera el arte del overworld: tiles 16x16, la fuente pixel y la tabla del atlas.

Todo el arte es original y se dibuja píxel a píxel con PIL, con una paleta
propia inspirada en la estética de las consolas portátiles de 32 bits
(colores cálidos, contorno oscuro, una luz y una sombra por material).

Uso (desde la raíz del proyecto):
    python3 tools/generar_tiles.py

Salidas:
    assets/tiles/tileset.png          atlas de 16 columnas x N filas, cuadro 16x16
    assets/tiles/muestras/*.png       cada tile suelto, para mirarlo de cerca
    assets/fuentes/fuente_pixel.png   hoja de glifos (blanco sobre transparente)
    assets/fuentes/fuente_pixel.fnt   descriptor BMFont en texto
    game/overworld/atlas_tiles.gd     tabla nombre -> coordenada del atlas

El script es reproducible: usa semillas fijas, así que correrlo dos veces da
los mismos PNG byte a byte.
"""

import os
import random

from PIL import Image

RAIZ = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
T = 16  # lado del tile en píxeles
COLUMNAS = 16

# ---------------------------------------------------------------------------
# Paleta
# ---------------------------------------------------------------------------
CONTORNO = (40, 36, 48)
SOMBRA_SUELO = (150, 132, 104)

GRAVA = (198, 182, 150)
GRAVA_OSC = (166, 148, 118)
GRAVA_CLARA = (226, 214, 186)

PASTO = (112, 176, 80)
PASTO_OSC = (84, 148, 64)
PASTO_CLARO = (148, 204, 104)

TIERRA = (178, 150, 110)
TIERRA_OSC = (150, 124, 90)

METAL = (150, 158, 172)
METAL_OSC = (110, 118, 134)
METAL_CLARO = (196, 204, 214)
METAL_MUY_OSC = (76, 84, 100)

AMARILLO = (232, 192, 64)
AMARILLO_OSC = (184, 144, 40)

LODO = (132, 100, 72)
LODO_OSC = (106, 80, 58)
LODO_CLARO = (160, 128, 94)

ARENA = (150, 124, 84)
ARENA_OSC = (120, 98, 66)
ARENA_CLARA = (176, 152, 108)

RESERVA = (124, 112, 78)  # lodo nuevo, más oliva
RESERVA_OSC = (100, 90, 62)
RESERVA_CLARA = (150, 138, 98)

PILDORA = (126, 118, 122)  # lodo pesado, gris de barita
PILDORA_OSC = (100, 94, 98)
PILDORA_CLARA = (156, 148, 150)

ACERO_AZUL = (92, 118, 150)
ACERO_AZUL_OSC = (70, 92, 120)
ACERO_AZUL_CLARO = (124, 150, 182)

TECHO_CASETA = (64, 140, 148)
TECHO_CASETA_OSC = (48, 112, 120)
TECHO_CASETA_CLARO = (104, 176, 180)

TECHO_BODEGA = (182, 82, 62)
TECHO_BODEGA_OSC = (146, 62, 48)
TECHO_BODEGA_CLARO = (214, 120, 92)

TECHO_TRAILER = (214, 214, 206)
TECHO_TRAILER_OSC = (180, 180, 172)
TECHO_TRAILER_CLARO = (238, 238, 232)

PARED = (226, 212, 172)
PARED_OSC = (196, 180, 140)
PARED_TRAILER = (236, 236, 228)
PARED_TRAILER_OSC = (200, 200, 196)

VIDRIO = (112, 168, 216)
VIDRIO_CLARO = (176, 216, 240)
MADERA = (150, 102, 64)
MADERA_OSC = (112, 74, 46)

TORRE = (214, 96, 52)
TORRE_OSC = (160, 66, 36)

VERDE_VALVULA = (64, 168, 84)
ROJO_VALVULA = (206, 60, 52)
AZUL_MOTOR = (64, 110, 176)
AZUL_MOTOR_OSC = (44, 80, 136)

SACO = (234, 226, 204)
SACO_OSC = (196, 186, 158)


# ---------------------------------------------------------------------------
# Utilidades de dibujo
# ---------------------------------------------------------------------------
def nuevo(color=(0, 0, 0, 0)):
    return Image.new("RGBA", (T, T), color)


def px(img, x, y, color):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color if len(color) == 4 else color + (255,))


def rect(img, x0, y0, x1, y1, color):
    """Rectángulo lleno, extremos incluidos."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, color)


def marco(img, x0, y0, x1, y1, color):
    for x in range(x0, x1 + 1):
        px(img, x, y0, color)
        px(img, x, y1, color)
    for y in range(y0, y1 + 1):
        px(img, x0, y, color)
        px(img, x1, y, color)


def circulo(img, cx, cy, r, color, relleno=True):
    for y in range(T):
        for x in range(T):
            d2 = (x - cx + 0.5) ** 2 + (y - cy + 0.5) ** 2
            if relleno and d2 <= r * r:
                px(img, x, y, color)
            elif not relleno and r * r - 2 * r <= d2 <= r * r:
                px(img, x, y, color)


def moteado(img, base, oscuro, claro, semilla, densidad=0.12):
    rnd = random.Random(semilla)
    rect(img, 0, 0, T - 1, T - 1, base)
    for y in range(T):
        for x in range(T):
            r = rnd.random()
            if r < densidad:
                px(img, x, y, oscuro)
            elif r < densidad * 1.7:
                px(img, x, y, claro)


def grava(semilla=1):
    img = nuevo()
    moteado(img, GRAVA, GRAVA_OSC, GRAVA_CLARA, semilla)
    return img


# ---------------------------------------------------------------------------
# Tiles sueltos
# ---------------------------------------------------------------------------
def t_pasto(semilla, flores=False):
    img = nuevo()
    rnd = random.Random(semilla)
    rect(img, 0, 0, T - 1, T - 1, PASTO)
    for _ in range(9):
        x, y = rnd.randrange(T), rnd.randrange(1, T)
        px(img, x, y, PASTO_OSC)
        px(img, x, y - 1, PASTO_OSC)
        px(img, x + 1, y, PASTO_CLARO)
    if flores:
        for _ in range(3):
            x, y = rnd.randrange(1, T - 1), rnd.randrange(1, T - 1)
            c = rnd.choice([(232, 96, 96), (248, 232, 120), (240, 240, 240)])
            px(img, x, y, c)
            px(img, x - 1, y, c)
            px(img, x + 1, y, c)
            px(img, x, y - 1, c)
            px(img, x, y + 1, c)
            px(img, x, y, (248, 200, 64))
    return img


def t_arbol():
    img = t_pasto(31)
    # sombra
    for x in range(3, 14):
        px(img, x, 15, PASTO_OSC)
    rect(img, 7, 11, 8, 14, MADERA_OSC)
    px(img, 7, 11, MADERA)
    circulo(img, 8, 7, 7, (32, 72, 48))
    circulo(img, 8, 7, 6, (52, 112, 64))
    circulo(img, 7, 6, 4, (72, 136, 72))
    circulo(img, 6, 5, 2, (96, 160, 84))
    return img


def t_tierra():
    img = nuevo()
    moteado(img, TIERRA, TIERRA_OSC, (196, 170, 128), 7, 0.08)
    return img


def t_mesa_rotaria():
    img = piso_perforacion_base()
    circulo(img, 8, 8, 7, CONTORNO)
    circulo(img, 8, 8, 6, (96, 96, 104))
    circulo(img, 8, 8, 5, (120, 120, 128))
    rect(img, 5, 5, 10, 10, (64, 64, 72))
    rect(img, 6, 6, 9, 9, (88, 88, 96))
    rect(img, 7, 7, 8, 8, (20, 18, 24))
    px(img, 4, 4, METAL_CLARO)
    return img


def piso_perforacion_base():
    img = nuevo()
    rect(img, 0, 0, T - 1, T - 1, (132, 124, 116))
    for i in range(0, T, 8):
        for j in range(T):
            px(img, i, j, (108, 102, 94))
            px(img, j, i, (108, 102, 94))
    for (x, y) in [(3, 3), (11, 3), (3, 11), (11, 11)]:
        px(img, x, y, (160, 152, 144))
    return img


def t_pata_torre():
    img = piso_perforacion_base()
    rect(img, 2, 2, 13, 13, CONTORNO)
    rect(img, 3, 3, 12, 12, TORRE)
    rect(img, 5, 5, 10, 10, TORRE_OSC)
    for i in range(3, 13):
        px(img, i, i, (240, 140, 90))
        px(img, 15 - i, i, (240, 140, 90))
    rect(img, 7, 7, 8, 8, CONTORNO)
    return img


def t_consola():
    img = piso_perforacion_base()
    rect(img, 1, 3, 14, 14, CONTORNO)
    rect(img, 2, 4, 13, 13, (72, 84, 108))
    rect(img, 3, 5, 12, 9, (32, 40, 48))
    rect(img, 4, 6, 11, 8, (104, 200, 152))
    for x in (5, 8, 10):
        px(img, x, 7, (40, 120, 88))
    px(img, 4, 11, (224, 64, 56))
    px(img, 7, 11, AMARILLO)
    px(img, 10, 11, (96, 200, 120))
    rect(img, 2, 13, 13, 13, (52, 60, 80))
    return img


def t_zaranda():
    img = grava(41)
    rect(img, 0, 1, 15, 15, CONTORNO)
    rect(img, 1, 2, 14, 14, METAL_OSC)
    rect(img, 2, 3, 13, 13, (172, 176, 160))
    for i in range(3, 14, 2):
        for j in range(3, 14):
            px(img, i, j, (140, 146, 128))
    rnd = random.Random(5)
    for _ in range(14):
        px(img, rnd.randrange(2, 14), rnd.randrange(3, 14), LODO)
    for _ in range(5):
        px(img, rnd.randrange(2, 14), rnd.randrange(3, 14), (90, 84, 80))
    rect(img, 1, 2, 14, 2, METAL_CLARO)
    rect(img, 6, 0, 9, 1, METAL_MUY_OSC)
    return img


def t_caja_llegada():
    img = grava(43)
    rect(img, 1, 1, 14, 15, CONTORNO)
    rect(img, 2, 2, 13, 14, METAL)
    rect(img, 4, 4, 11, 12, LODO_OSC)
    rect(img, 5, 5, 10, 11, LODO)
    px(img, 6, 6, LODO_CLARO)
    px(img, 9, 9, LODO_CLARO)
    px(img, 7, 9, (236, 232, 220))
    px(img, 8, 10, (236, 232, 220))
    rect(img, 2, 2, 13, 2, METAL_CLARO)
    return img


def t_embudo():
    img = grava(47)
    rect(img, 1, 1, 14, 14, CONTORNO)
    rect(img, 2, 2, 13, 13, METAL_CLARO)
    rect(img, 4, 4, 11, 11, METAL)
    rect(img, 6, 6, 9, 9, METAL_OSC)
    rect(img, 7, 7, 8, 8, CONTORNO)
    for i in range(2, 7):
        px(img, i, i, METAL_OSC)
        px(img, 15 - i, i, METAL_OSC)
        px(img, i, 15 - i, METAL_OSC)
        px(img, 15 - i, 15 - i, METAL_OSC)
    rect(img, 2, 13, 13, 13, METAL_OSC)
    return img


def t_bomba_centrifuga():
    img = grava(53)
    rect(img, 1, 4, 10, 12, CONTORNO)
    rect(img, 2, 5, 9, 11, AZUL_MOTOR)
    for x in range(3, 9, 2):
        rect(img, x, 5, x, 11, AZUL_MOTOR_OSC)
    rect(img, 2, 5, 9, 5, (110, 150, 210))
    circulo(img, 12, 8, 4, CONTORNO)
    circulo(img, 12, 8, 3, METAL)
    px(img, 12, 8, METAL_MUY_OSC)
    px(img, 11, 7, METAL_CLARO)
    rect(img, 1, 13, 14, 13, GRAVA_OSC)
    return img


def tubo_h(img, y0=6):
    rect(img, 0, y0, T - 1, y0 + 3, CONTORNO)
    rect(img, 0, y0 + 1, T - 1, y0 + 2, (104, 112, 128))
    rect(img, 0, y0 + 1, T - 1, y0 + 1, (152, 160, 176))


def tubo_v(img, x0=6):
    rect(img, x0, 0, x0 + 3, T - 1, CONTORNO)
    rect(img, x0 + 1, 0, x0 + 2, T - 1, (104, 112, 128))
    rect(img, x0 + 1, 0, x0 + 1, T - 1, (152, 160, 176))


def t_valvula(horizontal, abierta):
    img = grava(61)
    if horizontal:
        tubo_h(img)
    else:
        tubo_v(img)
    color = VERDE_VALVULA if abierta else ROJO_VALVULA
    rect(img, 5, 5, 10, 10, CONTORNO)
    rect(img, 6, 6, 9, 9, METAL_OSC)
    circulo(img, 8, 8, 6, CONTORNO, relleno=False)
    circulo(img, 8, 8, 5, color, relleno=False)
    # rayos del volante: abiertos en cruz, cerrados en equis
    if abierta:
        for i in range(3, 13):
            px(img, i, 7, color)
            px(img, 7, i, color)
    else:
        for i in range(4, 12):
            px(img, i, i, color)
            px(img, 15 - i, i, color)
    rect(img, 7, 7, 8, 8, CONTORNO)
    return img


def t_pared_tanque():
    img = nuevo()
    rect(img, 0, 0, T - 1, T - 1, (124, 132, 148))
    for x in range(1, T, 4):
        rect(img, x, 2, x, 12, (100, 108, 124))
        rect(img, x + 1, 2, x + 1, 12, (146, 154, 168))
    rect(img, 0, 0, T - 1, 1, METAL_CLARO)
    rect(img, 0, 13, T - 1, 13, METAL_OSC)
    rect(img, 0, 14, T - 1, 15, SOMBRA_SUELO)
    return img


def pared_base(color, oscuro):
    img = nuevo()
    rect(img, 0, 0, T - 1, T - 1, color)
    for y in range(3, 13, 3):
        rect(img, 0, y, T - 1, y, oscuro)
    rect(img, 0, 13, T - 1, 13, oscuro)
    rect(img, 0, 14, T - 1, 15, SOMBRA_SUELO)
    return img


def t_pared(trailer=False):
    return pared_base(PARED_TRAILER, PARED_TRAILER_OSC) if trailer else pared_base(PARED, PARED_OSC)


def t_ventana(trailer=False):
    img = t_pared(trailer)
    rect(img, 3, 2, 12, 10, CONTORNO)
    rect(img, 4, 3, 11, 9, VIDRIO)
    rect(img, 4, 3, 7, 3, VIDRIO_CLARO)
    px(img, 4, 4, VIDRIO_CLARO)
    rect(img, 4, 6, 11, 6, (240, 240, 236))
    rect(img, 7, 3, 7, 9, (240, 240, 236))
    return img


def t_puerta(trailer=False):
    img = t_pared(trailer)
    madera, madera_osc = ((104, 120, 150), (76, 90, 118)) if trailer else (MADERA, MADERA_OSC)
    rect(img, 3, 1, 12, 13, CONTORNO)
    rect(img, 4, 2, 11, 13, madera)
    rect(img, 5, 3, 10, 6, madera_osc)
    rect(img, 5, 8, 10, 12, madera_osc)
    px(img, 10, 8, AMARILLO)
    rect(img, 2, 14, 13, 15, (170, 166, 160))
    return img


def t_sacos():
    img = grava(71)
    rect(img, 1, 11, 14, 14, MADERA_OSC)
    for x in range(1, 15, 3):
        rect(img, x, 11, x + 1, 13, MADERA)
    for (x0, y0) in [(1, 6), (8, 6), (4, 1)]:
        rect(img, x0, y0, x0 + 6, y0 + 5, CONTORNO)
        rect(img, x0 + 1, y0 + 1, x0 + 5, y0 + 4, SACO)
        rect(img, x0 + 1, y0 + 4, x0 + 5, y0 + 4, SACO_OSC)
        px(img, x0 + 3, y0 + 2, (200, 70, 60))
    return img


def t_porton():
    img = grava(73)
    rect(img, 0, 5, T - 1, 6, CONTORNO)
    rect(img, 0, 10, T - 1, 11, CONTORNO)
    rect(img, 0, 5, T - 1, 5, AMARILLO)
    rect(img, 0, 10, T - 1, 10, AMARILLO)
    for x in range(0, T, 4):
        rect(img, x, 5, x, 11, AMARILLO_OSC)
    for x in range(1, T, 4):
        px(img, x, 8, (40, 40, 40))
    return img


def t_letrero():
    img = grava(79)
    rect(img, 7, 9, 8, 14, MADERA_OSC)
    rect(img, 1, 2, 14, 10, CONTORNO)
    rect(img, 2, 3, 13, 9, (240, 236, 220))
    for y in (4, 6, 8):
        rect(img, 4, y, 11, y, (120, 120, 128))
    rect(img, 2, 3, 13, 3, (226, 74, 56))
    return img


def t_tanque_agua():
    img = grava(83)
    circulo(img, 8, 8, 7, CONTORNO)
    circulo(img, 8, 8, 6, (88, 140, 196))
    circulo(img, 7, 7, 3, (130, 180, 226))
    px(img, 8, 8, CONTORNO)
    return img


# ---------------------------------------------------------------------------
# Tiles con máscara de vecinos (autotile de 16 variantes)
# Bits: N=1, E=2, S=4, O=8. Un bit en 1 = el vecino es del mismo tipo.
# ---------------------------------------------------------------------------
N, E, S, O = 1, 2, 4, 8


def relleno_lodo(base, osc, claro, semilla, sedimento=False):
    def dibujar(img):
        rnd = random.Random(semilla)
        rect(img, 0, 0, T - 1, T - 1, base)
        for _ in range(4):
            x, y = rnd.randrange(0, T - 4), rnd.randrange(1, T - 1)
            px(img, x, y, claro)
            px(img, x + 1, y - 1, claro)
            px(img, x + 2, y - 1, claro)
            px(img, x + 3, y, claro)
        for _ in range(6):
            px(img, rnd.randrange(T), rnd.randrange(T), osc)
        if sedimento:
            for _ in range(10):
                px(img, rnd.randrange(T), rnd.randrange(T), (92, 76, 52))
    return dibujar


def bordes_tanque(img, mascara, luz=METAL_CLARO, medio=METAL, sombra=None):
    """Borde de chapa de un tanque visto desde arriba: contorno + 2 px de pared."""
    if not mascara & N:
        rect(img, 0, 0, T - 1, 0, CONTORNO)
        rect(img, 0, 1, T - 1, 1, luz)
        rect(img, 0, 2, T - 1, 2, medio)
        if sombra:
            rect(img, 0, 3, T - 1, 3, sombra)
    if not mascara & S:
        rect(img, 0, T - 3, T - 1, T - 3, medio)
        rect(img, 0, T - 2, T - 1, T - 2, luz)
        rect(img, 0, T - 1, T - 1, T - 1, CONTORNO)
    if not mascara & O:
        rect(img, 0, 0, 0, T - 1, CONTORNO)
        rect(img, 1, 0, 1, T - 1, luz)
        rect(img, 2, 0, 2, T - 1, medio)
        if sombra:
            rect(img, 3, 0 if mascara & N else 3, 3, T - 1, sombra)
    if not mascara & E:
        rect(img, T - 3, 0, T - 3, T - 1, medio)
        rect(img, T - 2, 0, T - 2, T - 1, luz)
        rect(img, T - 1, 0, T - 1, T - 1, CONTORNO)
    # esquinas exteriores redondeadas un píxel
    for (bit_a, bit_b, x, y) in [(N, O, 0, 0), (N, E, T - 1, 0), (S, O, 0, T - 1), (S, E, T - 1, T - 1)]:
        if not mascara & bit_a and not mascara & bit_b:
            px(img, x, y, (0, 0, 0, 0))


def bloque_lodo(base, osc, claro, semilla, sedimento=False):
    rellenar = relleno_lodo(base, osc, claro, semilla, sedimento)

    def hacer(mascara):
        img = nuevo()
        rellenar(img)
        bordes_tanque(img, mascara, sombra=osc)
        return img
    return hacer


def bloque_fractanque(mascara):
    img = nuevo()
    rect(img, 0, 0, T - 1, T - 1, ACERO_AZUL)
    for y in range(2, T, 4):
        rect(img, 0, y, T - 1, y, ACERO_AZUL_OSC)
        rect(img, 0, y + 1, T - 1, y + 1, ACERO_AZUL_CLARO)
    bordes_tanque(img, mascara, luz=ACERO_AZUL_CLARO, medio=ACERO_AZUL_OSC)
    if mascara == (E | S | O) or mascara == (E | S):
        circulo(img, 8, 9, 3, CONTORNO)
        circulo(img, 8, 9, 2, ACERO_AZUL_OSC)
    return img


def bloque_techo(base, osc, claro, rayas="h"):
    def hacer(mascara):
        img = nuevo()
        rect(img, 0, 0, T - 1, T - 1, base)
        if rayas == "h":
            for y in range(1, T, 3):
                rect(img, 0, y, T - 1, y, osc)
        else:
            for x in range(1, T, 3):
                rect(img, x, 0, x, T - 1, osc)
                rect(img, x + 1, 0, x + 1, T - 1, claro)
        if not mascara & N:
            rect(img, 0, 0, T - 1, 0, CONTORNO)
            rect(img, 0, 1, T - 1, 1, claro)
        if not mascara & S:
            rect(img, 0, T - 2, T - 1, T - 2, osc)
            rect(img, 0, T - 1, T - 1, T - 1, CONTORNO)
        if not mascara & O:
            rect(img, 0, 0, 0, T - 1, CONTORNO)
            rect(img, 1, 1 if not mascara & N else 0, 1, T - 2, claro)
        if not mascara & E:
            rect(img, T - 1, 0, T - 1, T - 1, CONTORNO)
            rect(img, T - 2, 1 if not mascara & N else 0, T - 2, T - 2, osc)
        return img
    return hacer


def bloque_plancha(mascara):
    img = nuevo()
    rect(img, 0, 0, T - 1, T - 1, METAL)
    for y in range(0, T, 4):
        for x in range(0, T, 4):
            dx = 1 if (y // 4) % 2 == 0 else 3
            px(img, x + dx, y + 1, METAL_CLARO)
            px(img, x + dx + 1, y + 2, METAL_OSC)
    if not mascara & N:
        rect(img, 0, 0, T - 1, 0, METAL_OSC)
    if not mascara & S:
        rect(img, 0, T - 1, T - 1, T - 1, METAL_MUY_OSC)
    if not mascara & O:
        rect(img, 0, 0, 0, T - 1, METAL_OSC)
    if not mascara & E:
        rect(img, T - 1, 0, T - 1, T - 1, METAL_MUY_OSC)
    return img


def bloque_piso_perforacion(mascara):
    img = piso_perforacion_base()
    if not mascara & N:
        rect(img, 0, 0, T - 1, 0, CONTORNO)
        for x in range(0, T):
            px(img, x, 1, AMARILLO if (x // 2) % 2 == 0 else CONTORNO)
    if not mascara & S:
        for x in range(0, T):
            px(img, x, T - 2, AMARILLO if (x // 2) % 2 == 0 else CONTORNO)
        rect(img, 0, T - 1, T - 1, T - 1, CONTORNO)
    if not mascara & O:
        rect(img, 0, 0, 0, T - 1, CONTORNO)
        for y in range(0, T):
            px(img, 1, y, AMARILLO if (y // 2) % 2 == 0 else CONTORNO)
    if not mascara & E:
        for y in range(0, T):
            px(img, T - 2, y, AMARILLO if (y // 2) % 2 == 0 else CONTORNO)
        rect(img, T - 1, 0, T - 1, T - 1, CONTORNO)
    return img


def bloque_tuberia(mascara):
    img = grava(91)
    horizontal = mascara & (E | O)
    vertical = mascara & (N | S)
    if not horizontal and not vertical:
        horizontal = E | O
    # tramos desde el centro hacia cada vecino conectado
    def tramo_h(x0, x1):
        rect(img, x0, 6, x1, 9, CONTORNO)
        rect(img, x0, 7, x1, 8, (104, 112, 128))
        rect(img, x0, 7, x1, 7, (152, 160, 176))

    def tramo_v(y0, y1):
        rect(img, 6, y0, 9, y1, CONTORNO)
        rect(img, 7, y0, 8, y1, (104, 112, 128))
        rect(img, 7, y0, 7, y1, (152, 160, 176))

    solo_h = horizontal and not vertical
    solo_v = vertical and not horizontal
    if solo_h:
        tramo_h(0, T - 1)
    elif solo_v:
        tramo_v(0, T - 1)
    else:
        if mascara & O:
            tramo_h(0, 9)
        if mascara & E:
            tramo_h(6, T - 1)
        if mascara & N:
            tramo_v(0, 9)
        if mascara & S:
            tramo_v(6, T - 1)
        rect(img, 7, 7, 8, 8, (104, 112, 128))
        px(img, 7, 7, (152, 160, 176))
    # bridas cada tile
    if solo_h:
        rect(img, 2, 5, 2, 10, CONTORNO)
    if solo_v:
        rect(img, 5, 2, 10, 2, CONTORNO)
    return img


def bloque_cerca(mascara):
    img = grava(97)
    gris, gris_claro = (112, 116, 124), (172, 176, 184)
    if mascara & (E | O):
        x0 = 0 if mascara & O else 7
        x1 = T - 1 if mascara & E else 8
        rect(img, x0, 5, x1, 5, gris)
        rect(img, x0, 9, x1, 9, gris)
        for x in range(x0, x1 + 1):
            if (x % 2) == 0:
                px(img, x, 7, gris_claro)
                px(img, x + 1, 6, gris_claro)
                px(img, x + 1, 8, gris_claro)
    if mascara & (N | S):
        y0 = 0 if mascara & N else 7
        y1 = T - 1 if mascara & S else 8
        rect(img, 6, y0, 6, y1, gris)
        rect(img, 9, y0, 9, y1, gris)
        for y in range(y0, y1 + 1, 2):
            px(img, 7, y, gris_claro)
            px(img, 8, y + 1, gris_claro)
    rect(img, 6, 4, 9, 11, CONTORNO)
    rect(img, 7, 5, 8, 10, (150, 154, 162))
    px(img, 7, 5, gris_claro)
    return img


def bloque_maquina(mascara):
    img = nuevo()
    rect(img, 0, 0, T - 1, T - 1, (84, 92, 108))
    for y in range(3, T, 5):
        rect(img, 0, y, T - 1, y, (64, 70, 84))
        rect(img, 0, y + 1, T - 1, y + 1, (110, 118, 134))
    for (x, y) in [(4, 6), (11, 6), (4, 12), (11, 12)]:
        px(img, x, y, AMARILLO)
    bordes_tanque(img, mascara, luz=(120, 128, 144), medio=(64, 70, 84))
    return img


# ---------------------------------------------------------------------------
# Catálogo del atlas. El orden define las coordenadas: no reordenar sin
# regenerar game/overworld/atlas_tiles.gd (el script lo hace solo).
# ---------------------------------------------------------------------------
SUELTOS = [
    ("grava", lambda: grava(1)),
    ("grava_b", lambda: grava(2)),
    ("grava_c", lambda: grava(3)),
    ("pasto", lambda: t_pasto(11)),
    ("pasto_b", lambda: t_pasto(12)),
    ("pasto_flores", lambda: t_pasto(13, flores=True)),
    ("arbol", t_arbol),
    ("tierra", t_tierra),
    ("mesa_rotaria", t_mesa_rotaria),
    ("pata_torre", t_pata_torre),
    ("consola", t_consola),
    ("zaranda", t_zaranda),
    ("caja_llegada", t_caja_llegada),
    ("embudo", t_embudo),
    ("bomba_centrifuga", t_bomba_centrifuga),
    ("tanque_agua", t_tanque_agua),
    ("valvula_h_abierta", lambda: t_valvula(True, True)),
    ("valvula_h_cerrada", lambda: t_valvula(True, False)),
    ("valvula_v_abierta", lambda: t_valvula(False, True)),
    ("valvula_v_cerrada", lambda: t_valvula(False, False)),
    ("pared_tanque", t_pared_tanque),
    ("pared", lambda: t_pared(False)),
    ("ventana", lambda: t_ventana(False)),
    ("puerta", lambda: t_puerta(False)),
    ("pared_trailer", lambda: t_pared(True)),
    ("ventana_trailer", lambda: t_ventana(True)),
    ("puerta_trailer", lambda: t_puerta(True)),
    ("sacos", t_sacos),
    ("porton", t_porton),
    ("letrero", t_letrero),
]

CON_MASCARA = [
    ("lodo_activo", bloque_lodo(LODO, LODO_OSC, LODO_CLARO, 101)),
    ("lodo_arena", bloque_lodo(ARENA, ARENA_OSC, ARENA_CLARA, 102, sedimento=True)),
    ("lodo_reserva", bloque_lodo(RESERVA, RESERVA_OSC, RESERVA_CLARA, 103)),
    ("lodo_pildora", bloque_lodo(PILDORA, PILDORA_OSC, PILDORA_CLARA, 104)),
    ("fractanque", bloque_fractanque),
    ("techo_caseta", bloque_techo(TECHO_CASETA, TECHO_CASETA_OSC, TECHO_CASETA_CLARO, "h")),
    ("techo_bodega", bloque_techo(TECHO_BODEGA, TECHO_BODEGA_OSC, TECHO_BODEGA_CLARO, "v")),
    ("techo_trailer", bloque_techo(TECHO_TRAILER, TECHO_TRAILER_OSC, TECHO_TRAILER_CLARO, "h")),
    ("plancha", bloque_plancha),
    ("piso_perforacion", bloque_piso_perforacion),
    ("tuberia", bloque_tuberia),
    ("cerca", bloque_cerca),
    ("maquina", bloque_maquina),
]


def generar_atlas():
    filas_sueltos = (len(SUELTOS) + COLUMNAS - 1) // COLUMNAS
    filas = filas_sueltos + len(CON_MASCARA)
    atlas = Image.new("RGBA", (COLUMNAS * T, filas * T), (0, 0, 0, 0))
    coords_sueltos = {}
    filas_mascara = {}
    muestras = os.path.join(RAIZ, "assets", "tiles", "muestras")
    os.makedirs(muestras, exist_ok=True)
    for i, (nombre, fn) in enumerate(SUELTOS):
        c, f = i % COLUMNAS, i // COLUMNAS
        img = fn()
        atlas.paste(img, (c * T, f * T))
        img.save(os.path.join(muestras, nombre + ".png"))
        coords_sueltos[nombre] = (c, f)
    for j, (nombre, fn) in enumerate(CON_MASCARA):
        f = filas_sueltos + j
        filas_mascara[nombre] = f
        for mascara in range(16):
            img = fn(mascara)
            atlas.paste(img, (mascara * T, f * T))
        # muestra: un bloque 3x3 armado con las máscaras correctas
        muestra = Image.new("RGBA", (3 * T, 3 * T))
        for yy in range(3):
            for xx in range(3):
                m = 0
                if yy > 0:
                    m |= N
                if xx < 2:
                    m |= E
                if yy < 2:
                    m |= S
                if xx > 0:
                    m |= O
                muestra.paste(fn(m), (xx * T, yy * T))
        muestra.save(os.path.join(muestras, nombre + ".png"))
    destino = os.path.join(RAIZ, "assets", "tiles", "tileset.png")
    atlas.save(destino)
    return coords_sueltos, filas_mascara


def escribir_tabla_gd(coords_sueltos, filas_mascara):
    lineas = [
        "extends RefCounted",
        "## Tabla del atlas assets/tiles/tileset.png.",
        "## GENERADO por tools/generar_tiles.py — no editar a mano.",
        "",
        "const LADO := %d" % T,
        "const RUTA := \"res://assets/tiles/tileset.png\"",
        "",
        "## Tiles sueltos: nombre -> coordenada en el atlas.",
        "const SUELTOS := {",
    ]
    for nombre, (c, f) in coords_sueltos.items():
        lineas.append("\t\"%s\": Vector2i(%d, %d)," % (nombre, c, f))
    lineas += [
        "}",
        "",
        "## Tiles con máscara de vecinos: nombre -> fila. La columna es la máscara",
        "## (N=1, E=2, S=4, O=8; bit en 1 = el vecino es del mismo tipo).",
        "const FILAS_MASCARA := {",
    ]
    for nombre, f in filas_mascara.items():
        lineas.append("\t\"%s\": %d," % (nombre, f))
    lineas += ["}", ""]
    destino = os.path.join(RAIZ, "game", "overworld", "atlas_tiles.gd")
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    with open(destino, "w", encoding="utf-8") as f:
        f.write("\n".join(lineas))


# ---------------------------------------------------------------------------
# Fuente pixel (5 px de ancho máximo, celda de 10 px de alto)
# Filas de la celda: 0 acento de mayúscula · 1-7 mayúscula · 3-7 minúscula
# · 1-2 acento de minúscula · 8-9 descendentes. Línea base bajo la fila 7.
# Las mayúsculas y los dígitos se escriben con 7 filas (filas 1-7 de la celda);
# el resto con 9 filas (filas 1-9).
# ---------------------------------------------------------------------------
MAYUS = {
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
    "J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    ".": [".", ".", ".", ".", ".", ".", "#"],
    ":": [".", ".", "#", ".", ".", ".", "#"],
    "!": ["#", "#", "#", "#", "#", ".", "#"],
    "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
    "-": ["...", "...", "...", "###", "...", "...", "..."],
    "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
    "=": ["....", "....", "####", "....", "####", "....", "...."],
    "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
    "(": [".#", "#.", "#.", "#.", "#.", "#.", ".#"],
    ")": ["#.", ".#", ".#", ".#", ".#", ".#", "#."],
    "%": ["##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##"],
    "\"": ["#.#", "#.#", "...", "...", "...", "...", "..."],
    "'": ["#", "#", ".", ".", ".", ".", "."],
    "°": [".#.", "#.#", ".#.", "...", "...", "...", "..."],
    "·": [".", ".", ".", "#", ".", ".", "."],
    "²": ["##.", "..#", ".#.", "###", "...", "...", "..."],
    "*": [".....", "#.#.#", ".###.", "#####", ".###.", "#.#.#", "....."],
    "<": ["...#", "..#.", ".#..", "#...", ".#..", "..#.", "...#"],
    ">": ["#...", ".#..", "..#.", "...#", "..#.", ".#..", "#..."],
    "_": ["....", "....", "....", "....", "....", "....", "####"],
    "▼": [".....", ".....", "#####", ".###.", "..#..", ".....", "....."],
    "→": [".....", "...#.", "....#", "#####", "....#", "...#.", "....."],
}

MINUS = {
    "a": [".....", ".....", ".###.", "....#", ".####", "#...#", ".####", ".....", "....."],
    "b": ["#....", "#....", "####.", "#...#", "#...#", "#...#", "####.", ".....", "....."],
    "c": ["....", "....", ".###", "#...", "#...", "#...", ".###", "....", "...."],
    "d": ["....#", "....#", ".####", "#...#", "#...#", "#...#", ".####", ".....", "....."],
    "e": [".....", ".....", ".###.", "#...#", "#####", "#....", ".###.", ".....", "....."],
    "f": ["..##", ".#..", "###.", ".#..", ".#..", ".#..", ".#..", "....", "...."],
    "g": [".....", ".....", ".####", "#...#", "#...#", "#...#", ".####", "....#", ".###."],
    "h": ["#....", "#....", "####.", "#...#", "#...#", "#...#", "#...#", ".....", "....."],
    "i": ["#", ".", "#", "#", "#", "#", "#", ".", "."],
    "j": ["..#", "...", "..#", "..#", "..#", "..#", "..#", "#.#", ".#."],
    "k": ["#...", "#...", "#..#", "#.#.", "##..", "#.#.", "#..#", "....", "...."],
    "l": ["#.", "#.", "#.", "#.", "#.", "#.", ".#", "..", ".."],
    "m": [".....", ".....", "##.#.", "#.#.#", "#.#.#", "#.#.#", "#.#.#", ".....", "....."],
    "n": [".....", ".....", "####.", "#...#", "#...#", "#...#", "#...#", ".....", "....."],
    "o": [".....", ".....", ".###.", "#...#", "#...#", "#...#", ".###.", ".....", "....."],
    "p": [".....", ".....", "####.", "#...#", "#...#", "#...#", "####.", "#....", "#...."],
    "q": [".....", ".....", ".####", "#...#", "#...#", "#...#", ".####", "....#", "....#"],
    "r": ["....", "....", "#.##", "##..", "#...", "#...", "#...", "....", "...."],
    "s": [".....", ".....", ".####", "#....", ".###.", "....#", "####.", ".....", "....."],
    "t": [".#..", ".#..", "###.", ".#..", ".#..", ".#..", "..##", "....", "...."],
    "u": [".....", ".....", "#...#", "#...#", "#...#", "#...#", ".####", ".....", "....."],
    "v": [".....", ".....", "#...#", "#...#", "#...#", ".#.#.", "..#..", ".....", "....."],
    "w": [".....", ".....", "#...#", "#...#", "#.#.#", "#.#.#", ".#.#.", ".....", "....."],
    "x": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", ".....", "....."],
    "y": [".....", ".....", "#...#", "#...#", "#...#", "#...#", ".####", "....#", ".###."],
    "z": [".....", ".....", "#####", "...#.", "..#..", ".#...", "#####", ".....", "....."],
    ",": ["..", "..", "..", "..", "..", "..", ".#", ".#", "#."],
    ";": ["..", "..", ".#", "..", "..", "..", ".#", ".#", "#."],
    "¡": ["#", ".", "#", "#", "#", "#", "#", "#", "."],
    "¿": [".....", ".....", "..#..", ".....", "..#..", ".#...", "#....", "#...#", ".###."],
}

AGUDO = [".#", "#."]
TILDE = [".#.#", "#.#."]
DIERESIS = ["#.#"]

ALTO_CELDA = 10
BASE = 8
INTERLINEA = 12


def celda_vacia(ancho):
    return [["."] * ancho for _ in range(ALTO_CELDA)]


def poner(celda, filas, fila0, col0=0):
    for i, fila in enumerate(filas):
        for j, ch in enumerate(fila):
            if ch == "#":
                celda[fila0 + i][col0 + j] = "#"


def glifo_mayus(filas):
    celda = celda_vacia(len(filas[0]))
    poner(celda, filas, 1)
    return celda


def glifo_minus(filas):
    celda = celda_vacia(len(filas[0]))
    poner(celda, filas, 1)
    return celda


def con_acento_minus(base, acento, quitar_punto=False):
    filas = [list(f) for f in MINUS[base]]
    if quitar_punto:
        filas[0] = ["."] * len(filas[0])
    ancho = max(len(filas[0]), len(acento[0]))
    celda = celda_vacia(ancho)
    desplazamiento = (ancho - len(filas[0])) // 2
    poner(celda, ["".join(f) for f in filas], 1, desplazamiento)
    col = max(0, (ancho - len(acento[0]) + 1) // 2)
    fila0 = 2 - len(acento) + 1  # el acento termina en la fila 2
    poner(celda, acento, fila0, col)
    return celda


def con_acento_mayus(base, acento):
    filas = list(MAYUS[base])
    # aplastar a 6 filas quitando una fila repetida para dejar sitio al acento
    for i in range(len(filas) - 1):
        if filas[i] == filas[i + 1]:
            del filas[i]
            break
    else:
        del filas[1]
    ancho = max(len(filas[0]), len(acento[0]))
    celda = celda_vacia(ancho)
    poner(celda, filas, 2, (ancho - len(filas[0])) // 2)
    col = max(0, (ancho - len(acento[0]) + 1) // 2)
    poner(celda, acento[-2:], 0 if len(acento) == 2 else 1, col)
    return celda


def generar_fuente():
    glifos = {}
    for ch, filas in MAYUS.items():
        glifos[ch] = glifo_mayus(filas)
    for ch, filas in MINUS.items():
        glifos[ch] = glifo_minus(filas)
    for base, acentuada in zip("aeiou", "áéíóú"):
        glifos[acentuada] = con_acento_minus(base, AGUDO, quitar_punto=(base == "i"))
    glifos["ñ"] = con_acento_minus("n", TILDE)
    glifos["ü"] = con_acento_minus("u", DIERESIS)
    for base, acentuada in zip("AEIOU", "ÁÉÍÓÚ"):
        glifos[acentuada] = con_acento_mayus(base, AGUDO)
    glifos["Ñ"] = con_acento_mayus("N", TILDE)
    glifos["Ü"] = con_acento_mayus("U", DIERESIS)

    # recortar columnas vacías a izquierda y derecha
    recortados = {}
    for ch, celda in glifos.items():
        cols = [j for j in range(len(celda[0])) if any(celda[i][j] == "#" for i in range(ALTO_CELDA))]
        if not cols:
            recortados[ch] = [[]] * ALTO_CELDA
            continue
        a, b = min(cols), max(cols)
        recortados[ch] = [fila[a:b + 1] for fila in celda]

    ancho_hoja, x, y = 256, 0, 0
    posiciones = {}
    for ch, celda in recortados.items():
        w = len(celda[0])
        if x + w + 1 > ancho_hoja:
            x, y = 0, y + ALTO_CELDA + 1
        posiciones[ch] = (x, y, w)
        x += w + 1
    alto_hoja = 1
    while alto_hoja < y + ALTO_CELDA + 1:
        alto_hoja *= 2
    hoja = Image.new("RGBA", (ancho_hoja, alto_hoja), (0, 0, 0, 0))
    for ch, celda in recortados.items():
        x0, y0, w = posiciones[ch]
        for i in range(ALTO_CELDA):
            for j in range(w):
                if celda[i][j] == "#":
                    hoja.putpixel((x0 + j, y0 + i), (255, 255, 255, 255))
    carpeta = os.path.join(RAIZ, "assets", "fuentes")
    os.makedirs(carpeta, exist_ok=True)
    hoja.save(os.path.join(carpeta, "fuente_pixel.png"))

    lineas = [
        'info face="PixelCampo" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1' % ALTO_CELDA,
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0" % (INTERLINEA, BASE, ancho_hoja, alto_hoja),
        'page id=0 file="fuente_pixel.png"',
        "chars count=%d" % (len(posiciones) + 1),
        "char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=3 page=0 chnl=15",
    ]
    for ch, (x0, y0, w) in posiciones.items():
        lineas.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15"
            % (ord(ch), x0, y0, w, ALTO_CELDA, w + 1)
        )
    with open(os.path.join(carpeta, "fuente_pixel.fnt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lineas) + "\n")


if __name__ == "__main__":
    sueltos, filas = generar_atlas()
    escribir_tabla_gd(sueltos, filas)
    generar_fuente()
    print("tileset: %d sueltos, %d filas con máscara" % (len(sueltos), len(filas)))
