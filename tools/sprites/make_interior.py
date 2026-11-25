#!/usr/bin/env python3
"""Textures des bâtiments détaillés (sols, murs, portes, fenêtres, toits au mètre).

Dessinées par programme (pas de génération PixelLab) pour rester nettes au mètre
(16 px) et cohérentes entre elles. Sortie : game/assets/interieur/.
  sols.png         une ligne par sol (ordre de BuildingPlan.FLOORS), 4 variantes de 16 x 16
  murs.png         une ligne par matériau (enduit, granit, parpaing, bois) ;
                   colonnes : mur, fenêtre, porte fermée, porte ouverte, brèche (16 x WALL_H)
  toits16.png      une ligne par toit (ardoise, tôle), 4 quarts de la tuile pleine
  murs.json        couleurs du dessus des murs (chaperon) et hauteur
"""
import json
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game/assets/interieur")
WALL_H = 32
S = 16


def jitter(c, r, k=8):
    d = r.randint(-k, k)          # même écart sur les trois couleurs : pas de taches colorées
    return tuple(max(0, min(255, v + d + r.randint(-1, 1))) for v in c[:3]) + (255,)


def floor_tile(kind, var):
    r = random.Random(hash((kind, var)) & 0xffff)
    im = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(im)
    if kind == "parquet":
        base = (122, 84, 52)
        for row in range(4):
            y = row * 4
            off = (row * 7 + var * 3) % 16
            for x in range(-16, 16, 10):
                c = jitter(base, r, 10)
                d.rectangle([x + off, y, x + off + 9, y + 3], fill=c)
                d.line([x + off + 9, y, x + off + 9, y + 3], fill=(84, 56, 34, 255))
            d.line([0, y + 3, 15, y + 3], fill=(92, 62, 38, 255))
    elif kind == "carrelage":
        a, b = (176, 172, 160), (150, 146, 136)
        for ty in range(2):
            for tx in range(2):
                c = jitter(a if (tx + ty + var) % 2 == 0 else b, r, 4)
                d.rectangle([tx * 8, ty * 8, tx * 8 + 7, ty * 8 + 7], fill=c)
        d.line([0, 0, 15, 0], fill=(110, 106, 98, 255))
        d.line([0, 0, 0, 15], fill=(110, 106, 98, 255))
        d.line([8, 0, 8, 15], fill=(120, 116, 108, 255))
        d.line([0, 8, 15, 8], fill=(120, 116, 108, 255))
    elif kind == "beton":
        im.paste((118, 118, 112, 255), [0, 0, S, S])
        for _ in range(26):
            x, y = r.randrange(S), r.randrange(S)
            im.putpixel((x, y), jitter((118, 118, 112), r, 14))
        if var == 3:
            d.line([2, 11, 9, 8], fill=(92, 92, 88, 255))
    elif kind == "terre":
        im.paste((104, 84, 58, 255), [0, 0, S, S])
        for _ in range(40):
            x, y = r.randrange(S), r.randrange(S)
            im.putpixel((x, y), jitter((104, 84, 58), r, 16))
        for _ in range(3):
            x, y = r.randrange(S), r.randrange(S)
            d.line([x, y, x + 2, y], fill=(170, 150, 80, 255))   # brins de paille
    elif kind == "lino":
        base = (140, 128, 104)
        im.paste(base + (255,), [0, 0, S, S])
        for i in range(0, S, 4):
            d.line([0, i, 15, i], fill=jitter((128, 116, 94), r, 3))
        for _ in range(10):
            im.putpixel((r.randrange(S), r.randrange(S)), jitter(base, r, 10))
    elif kind == "dalles":
        im.paste((96, 94, 90, 255), [0, 0, S, S])
        rects = [(0, 0, 9, 6), (10, 0, 15, 6), (0, 7, 5, 15), (6, 7, 15, 15)]
        for x0, y0, x1, y1 in rects:
            d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=jitter((138, 134, 126), r, 10))
    return im


MATS = {
    "enduit": {"face": (196, 188, 170), "dark": (150, 142, 126), "cap": (120, 114, 104)},
    "granit": {"face": (150, 146, 138), "dark": (98, 96, 92), "cap": (110, 106, 100)},
    "parpaing": {"face": (160, 160, 154), "dark": (118, 118, 114), "cap": (124, 124, 120)},
    "bois": {"face": (112, 82, 54), "dark": (74, 52, 34), "cap": (86, 64, 44)},
}


def wall_face(mat, r):
    m = MATS[mat]
    im = Image.new("RGBA", (S, WALL_H), m["face"] + (255,))
    d = ImageDraw.Draw(im)
    if mat == "granit":
        y = 0
        while y < WALL_H:
            hgt = r.randint(4, 6)
            x = -r.randint(0, 5)
            while x < S:
                wdt = r.randint(5, 8)
                d.rectangle([x, y, x + wdt - 1, y + hgt - 1], fill=jitter(m["face"], r, 14), outline=m["dark"] + (255,))
                x += wdt
            y += hgt
    elif mat == "parpaing":
        for row, y in enumerate(range(0, WALL_H, 6)):
            off = 0 if row % 2 == 0 else 8
            for x in range(-8 + off, S, 16):
                d.rectangle([x, y, x + 15, y + 5], fill=jitter(m["face"], r, 5), outline=m["dark"] + (255,))
    elif mat == "bois":
        for x in range(0, S, 4):
            d.rectangle([x, 0, x + 3, WALL_H - 1], fill=jitter(m["face"], r, 8))
            d.line([x + 3, 0, x + 3, WALL_H - 1], fill=m["dark"] + (255,))
    else:   # enduit : taches et salissures en bas
        for _ in range(30):
            im.putpixel((r.randrange(S), r.randrange(WALL_H)), jitter(m["face"], r, 10))
        for x in range(S):
            for y in range(WALL_H - 4, WALL_H):
                if r.random() < 0.5:
                    im.putpixel((x, y), jitter(m["dark"], r, 8))
    d.line([0, WALL_H - 1, S - 1, WALL_H - 1], fill=m["dark"] + (255,))
    return im


def window(im, mat):
    d = ImageDraw.Draw(im)
    frame = (210, 206, 196, 255) if mat != "bois" else (150, 120, 84, 255)
    d.rectangle([2, 7, 13, 22], fill=frame)
    d.rectangle([3, 8, 12, 21], fill=(58, 76, 92, 255))
    d.line([3, 8, 7, 8], fill=(140, 170, 190, 255))
    d.line([3, 9, 5, 9], fill=(110, 140, 160, 255))
    d.line([8, 8, 8, 21], fill=frame)
    d.line([3, 14, 12, 14], fill=frame)
    d.line([1, 23, 14, 23], fill=(90, 86, 80, 255))      # appui
    return im


def door(im, mat, open_):
    d = ImageDraw.Draw(im)
    if open_:
        # ouverture : on voit l'intérieur sombre, linteau en haut
        d.rectangle([1, 3, 14, WALL_H - 1], fill=(0, 0, 0, 0))
        d.rectangle([1, 3, 2, WALL_H - 1], fill=(92, 66, 42, 255))   # battant contre le chambranle
        d.line([0, 2, 15, 2], fill=(80, 74, 66, 255))
        return im
    d.rectangle([2, 3, 13, WALL_H - 1], fill=(104, 72, 44, 255))
    d.rectangle([2, 3, 13, WALL_H - 1], outline=(66, 44, 26, 255))
    d.line([7, 4, 7, WALL_H - 2], fill=(84, 58, 36, 255))
    d.point((11, 14), fill=(200, 180, 90, 255))
    return im


def breach(im):
    r = random.Random(7)
    d = ImageDraw.Draw(im)
    top = [(x, r.randint(4, 12)) for x in range(0, S, 2)]
    for x, t in top:
        d.rectangle([x, 0, x + 1, t], fill=(0, 0, 0, 0))
        d.rectangle([x, t, x + 1, WALL_H - 1], fill=(0, 0, 0, 0)) if 4 < x < 12 else None
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    floors = ["parquet", "carrelage", "beton", "terre", "lino", "dalles"]
    sheet = Image.new("RGBA", (S * 4, S * len(floors)))
    for i, k in enumerate(floors):
        for v in range(4):
            sheet.paste(floor_tile(k, v), (v * S, i * S))
    sheet.save(os.path.join(OUT, "sols.png"))
    mats = list(MATS)
    walls = Image.new("RGBA", (S * 5 * 2, WALL_H * len(mats)))
    for i, m in enumerate(mats):
        for v in range(2):
            r = random.Random(i * 10 + v)
            base = wall_face(m, r)
            cols = [base.copy(), window(base.copy(), m), door(base.copy(), m, False), door(base.copy(), m, True), breach(base.copy())]
            for j, im in enumerate(cols):
                walls.paste(im, ((v * 5 + j) * S, i * WALL_H))
    walls.save(os.path.join(OUT, "murs.png"))
    roofs = Image.new("RGBA", (S * 4, S * 2))
    for i, n in enumerate(["toit_ardoise", "toit_tole"]):
        src = Image.open(os.path.join(ROOT, "game/assets/tiles/wang", n + ".png")).convert("RGBA")
        full = src.crop((15 * 32, 0, 16 * 32, 32))
        for q in range(4):
            roofs.paste(full.crop(((q % 2) * S, (q // 2) * S, (q % 2) * S + S, (q // 2) * S + S)), (q * S, i * S))
    roofs.save(os.path.join(OUT, "toits16.png"))
    json.dump({"wall_h": WALL_H, "materials": mats,
               "caps": {m: list(MATS[m]["cap"]) for m in mats},
               "dark": {m: list(MATS[m]["dark"]) for m in mats}},
              open(os.path.join(OUT, "murs.json"), "w"), indent=1)
    print("textures intérieures écrites dans", OUT)


if __name__ == "__main__":
    main()
