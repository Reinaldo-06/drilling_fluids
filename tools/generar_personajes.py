#!/usr/bin/env python3
"""Genera las hojas de sprites de los personajes (pixel art original).

Uso (desde la raíz del repo):
    python3 tools/generar_personajes.py

Salida:
    assets/personajes/<id>.png   hoja 48×128: 3 columnas × 4 filas de 16×32
                                 columnas: quieto, paso A, paso B
                                 filas: abajo, izquierda, derecha, arriba
    docs/img/personajes.png      vista previa: los 7 mirando abajo, ×4

Los cuadros se dibujan con plantillas de texto (un carácter = un píxel) y una
paleta por personaje. Es reproducible: no usa azar. Diseño en docs/personajes.md.
"""
from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
ANCHO, ALTO = 16, 32

# --- Plantillas -------------------------------------------------------------
# Claves:
#   .  transparente          o  contorno
#   H  casco                 h  brillo del casco
#   R  pelo                  L  pelo largo (pelo si lo tiene, si no transparente)
#   S  piel                  s  sombra de piel
#   E  ojo                   M  bigote (pelo si lo tiene, si no piel)
#   C  ropa del torso        c  sombra del torso
#   V  chaleco (color del chaleco si lo tiene, si no ropa)
#   W  cinta reflectiva      B  cinturón y botas
#   P  pantalón              p  sombra del pantalón

CABEZA_FRENTE = [
    "......oooo......",
    "....ooHhHHoo....",
    "...oHhhHHHHHo...",
    "..oHhHHHHHHHHo..",
    "..oHHHHHHHHHHo..",
    ".oooooooooooooo.",
    "..oRRRRRRRRRRo..",
    "..oRSSSSSSSSRo..",
    "..oSSESSSSESSo..",
    "..LSSESSSSESSL..",
    "..LoSSSMMSSSoL..",
    "..L.oossssoo.L..",
]
TORSO_FRENTE = [
    "...oCCssssCCo...",
    "..oCVCCCCCCVCo..",
    ".oCCVCCCCCCVCCo.",
    ".oCcWWWWWWWWcCo.",
    ".oSoCVCCCCVCoSo.",
    ".ooocCCCCCCcooo.",
    "...oBBBBBBBBo...",
]
PIERNAS_FRENTE = {
    "quieto": [
        "...oPPPPPPPPo...",
        "...oPPPooPPPo...",
        "...oPPpo.oPPo...",
        "...oPPo..oPPo...",
        "..oBBBo..oBBBo..",
        "..ooooo..ooooo..",
    ],
    "paso_a": [
        "...oPPPPPPPPo...",
        "...oPPPooPPPo...",
        "...oPPpo.oBBo...",
        "...oPPo..oooo...",
        "..oBBBo.........",
        "..ooooo.........",
    ],
    "paso_b": [
        "...oPPPPPPPPo...",
        "...oPPPooPPPo...",
        "...oBBo.opPPo...",
        "...oooo..oPPo...",
        ".........oBBBo..",
        ".........ooooo..",
    ],
}

CABEZA_ESPALDA = [
    "......oooo......",
    "....ooHHHHoo....",
    "...oHHHhhHHHo...",
    "..oHHHHHHHHHHo..",
    "..oHHHHHHHHHHo..",
    ".oooooooooooooo.",
    "..oRRRRRRRRRRo..",
    "..oRRRRRRRRRRo..",
    "..oRRRRRRRRRRo..",
    "..LRRRRRRRRRRL..",
    "..LoRRRRRRRRoL..",
    "..LLoossssooLL..",
]
TORSO_ESPALDA = [
    "...oCCCCCCCCo...",
    "..oCVCCCCCCVCo..",
    ".oCCVVVVVVVVCCo.",
    ".oCcWWWWWWWWcCo.",
    ".oSoCVVVVVVCoSo.",
    ".ooocCCCCCCcooo.",
    "...oBBBBBBBBo...",
]

CABEZA_LADO = [  # mirando a la izquierda
    "......oooo......",
    "....ooHHHhoo....",
    "...oHHHHHhhHo...",
    "..oHHHHHHHHhHo..",
    "..oHHHHHHHHHHo..",
    "ooooooooooooooo.",
    "..oRRRRRRRRRRo..",
    "..oSSSSSRRRRRo..",
    "..oSESSSSRRRRo..",
    ".oSSSSSSSRRRLo..",
    "..oMsSSSSSRRLo..",
    "...ooSSSSooLL...",
]
TORSO_LADO = [
    "....oCsssCCo....",
    "...oCCCCCVCCo...",
    "...oCCCCCVCCo...",
    "...oWWWWWWWWo...",
    "...oCCSSCVCCo...",
    "...ocCSScCCco...",
    "...oBBBBBBBBo...",
]
PIERNAS_LADO = {
    "quieto": [
        "....oPPPPPPo....",
        "....oPPPPPPo....",
        "....oPPPPPPo....",
        "....oPPPPPPo....",
        "...oBBBBBBBo....",
        "...ooooooooo....",
    ],
    "paso_a": [
        "....oPPPPPPo....",
        "...oPPPopPPPo...",
        "..oPPPo.oPPPo...",
        "..oPPo...oPPo...",
        ".oBBBo...oBBBo..",
        ".ooooo...ooooo..",
    ],
    "paso_b": [
        "....oPPPPPPo....",
        "....oPPpPPPo....",
        "...oPPo.oPPo....",
        "...oPPo.oPPPo...",
        "..oBBBo.oBBBBo..",
        "..ooooo.oooooo..",
    ],
}

PIERNAS_ESPALDA = PIERNAS_FRENTE


def _cuadro(cabeza, torso, piernas, brazo=0):
    filas = cabeza + torso + piernas
    filas = ["." * ANCHO] * (ALTO - len(filas)) + filas
    assert len(filas) == ALTO and all(len(f) == ANCHO for f in filas), "plantilla mal formada"
    filas = list(filas)
    if brazo:
        # Balanceo de brazos en los pasos: una mano sube un píxel.
        i = ALTO - len(piernas) - 3
        a, b = list(filas[i]), list(filas[i - 1])
        col = 2 if brazo < 0 else ANCHO - 3
        if a[col] == "S":
            b[col], a[col] = "S", "C"
            filas[i], filas[i - 1] = "".join(a), "".join(b)
    return filas


def _espejo(filas):
    return [f[::-1] for f in filas]


def plantillas():
    """Devuelve {fila: [quieto, paso_a, paso_b]} de plantillas 16×32."""
    abajo = [
        _cuadro(CABEZA_FRENTE, TORSO_FRENTE, PIERNAS_FRENTE["quieto"]),
        _cuadro(CABEZA_FRENTE, TORSO_FRENTE, PIERNAS_FRENTE["paso_a"], brazo=+1),
        _cuadro(CABEZA_FRENTE, TORSO_FRENTE, PIERNAS_FRENTE["paso_b"], brazo=-1),
    ]
    izquierda = [
        _cuadro(CABEZA_LADO, TORSO_LADO, PIERNAS_LADO["quieto"]),
        _cuadro(CABEZA_LADO, TORSO_LADO, PIERNAS_LADO["paso_a"]),
        _cuadro(CABEZA_LADO, TORSO_LADO, PIERNAS_LADO["paso_b"]),
    ]
    derecha = [_espejo(f) for f in izquierda]
    arriba = [
        _cuadro(CABEZA_ESPALDA, TORSO_ESPALDA, PIERNAS_ESPALDA["quieto"]),
        _cuadro(CABEZA_ESPALDA, TORSO_ESPALDA, PIERNAS_ESPALDA["paso_b"], brazo=+1),
        _cuadro(CABEZA_ESPALDA, TORSO_ESPALDA, PIERNAS_ESPALDA["paso_a"], brazo=-1),
    ]
    return [abajo, izquierda, derecha, arriba]


# --- Personajes -------------------------------------------------------------
CONTORNO = (34, 30, 42)
OJO = (34, 30, 42)
CINTA = (232, 236, 220)
PIELES = {
    "clara": ((246, 206, 168), (214, 164, 124)),
    "media": ((222, 168, 120), (182, 128, 86)),
    "morena": ((178, 118, 76), (138, 86, 54)),
}

PERSONAJES = {
    # id: casco, ropa, pantalón, piel, pelo, pelo largo, bigote, chaleco
    "jugador": dict(casco=(64, 132, 220), ropa=(70, 96, 170), pantalon=(52, 70, 128),
                    piel="media", pelo=(70, 46, 30), largo=False, bigote=False, chaleco=None),
    "driller": dict(casco=(236, 196, 52), ropa=(206, 92, 40), pantalon=(150, 64, 32),
                    piel="morena", pelo=(30, 26, 26), largo=False, bigote=True, chaleco=None),
    "encuellador": dict(casco=(240, 140, 40), ropa=(60, 120, 100), pantalon=(44, 88, 74),
                        piel="media", pelo=(40, 28, 24), largo=True, bigote=False, chaleco=None),
    "company_man": dict(casco=(244, 244, 238), ropa=(200, 214, 230), pantalon=(60, 68, 96),
                        piel="clara", pelo=(110, 64, 36), largo=True, bigote=False, chaleco=(234, 120, 40)),
    "mud_logger": dict(casco=(150, 90, 200), ropa=(110, 112, 124), pantalon=(76, 78, 90),
                       piel="clara", pelo=(196, 150, 70), largo=True, bigote=False, chaleco=None),
    "toolpusher": dict(casco=(244, 244, 238), ropa=(170, 40, 46), pantalon=(110, 28, 34),
                       piel="morena", pelo=(170, 168, 164), largo=False, bigote=True, chaleco=None),
    "cuadrillero": dict(casco=(80, 180, 70), ropa=(70, 140, 200), pantalon=(48, 100, 150),
                        piel="morena", pelo=(26, 22, 22), largo=False, bigote=False, chaleco=None),
}
ORDEN = list(PERSONAJES)


def _aclarar(c, f=1.25):
    return tuple(min(255, int(v * f + 18)) for v in c)


def _oscurecer(c, f=0.72):
    return tuple(int(v * f) for v in c)


def paleta(p):
    piel, piel_s = PIELES[p["piel"]]
    chaleco = p["chaleco"] or p["ropa"]
    return {
        "o": CONTORNO, "E": OJO, "W": CINTA,
        "H": p["casco"], "h": _aclarar(p["casco"]),
        "R": p["pelo"], "L": p["pelo"] if p["largo"] else None,
        "M": p["pelo"] if p["bigote"] else piel,
        "S": piel, "s": piel_s,
        "C": p["ropa"], "c": _oscurecer(p["ropa"]), "V": chaleco,
        "B": (58, 44, 36), "P": p["pantalon"], "p": _oscurecer(p["pantalon"]),
    }


def dibujar_cuadro(filas, pal):
    img = Image.new("RGBA", (ANCHO, ALTO), (0, 0, 0, 0))
    for y, fila in enumerate(filas):
        for x, ch in enumerate(fila):
            if ch == ".":
                continue
            color = pal[ch]
            if color is not None:
                img.putpixel((x, y), color + (255,))
    return img


def hoja(pid):
    pal = paleta(PERSONAJES[pid])
    img = Image.new("RGBA", (ANCHO * 3, ALTO * 4), (0, 0, 0, 0))
    for fila, cuadros in enumerate(plantillas()):
        for col, filas in enumerate(cuadros):
            img.paste(dibujar_cuadro(filas, pal), (col * ANCHO, fila * ALTO))
    return img


def vista_previa(hojas, escala=4):
    celda = ANCHO * escala + 24
    alto_texto = 14
    img = Image.new("RGBA", (celda * len(hojas), ALTO * escala + alto_texto + 8), (236, 232, 214, 255))
    dibujo = ImageDraw.Draw(img)
    for i, (pid, h) in enumerate(hojas.items()):
        cuadro = h.crop((0, 0, ANCHO, ALTO)).resize((ANCHO * escala, ALTO * escala), Image.NEAREST)
        x = i * celda + 12
        img.alpha_composite(cuadro, (x, 4))
        ancho_txt = dibujo.textlength(pid)
        dibujo.text((i * celda + (celda - ancho_txt) / 2, ALTO * escala + 6), pid, fill=CONTORNO)
    return img


def main():
    destino = RAIZ / "assets" / "personajes"
    destino.mkdir(parents=True, exist_ok=True)
    hojas = {}
    for pid in ORDEN:
        hojas[pid] = hoja(pid)
        hojas[pid].save(destino / f"{pid}.png")
    (RAIZ / "docs" / "img").mkdir(parents=True, exist_ok=True)
    vista_previa(hojas).save(RAIZ / "docs" / "img" / "personajes.png")
    print(f"{len(hojas)} hojas en {destino}")


if __name__ == "__main__":
    main()
