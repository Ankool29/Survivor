#!/usr/bin/env python3
"""Convertit les jeux de tuiles PixelLab (transitions herbe <-> X) pour le jeu.

Entrée : tools/sprites/raw/wang_<nom>.json (réponse de GET /v2/tilesets/{id}).
Sortie :
  game/assets/tiles/base_herbe.png      la tuile d'herbe pleine (32 x 32)
  game/assets/tiles/wang/<nom>.png      16 tuiles en ligne, rangées par coins
                                        (NO=8, NE=4, SO=2, SE=1 ; bit à 1 = sol X)
                                        l'herbe y est rendue transparente

Toutes les transitions partagent la même herbe (image de référence PixelLab) :
un pixel identique à l'herbe au même endroit devient transparent, ce qui
permet d'empiler les sols par couches dans le jeu (grille double).
"""
import base64
import glob
import io
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, "tools/sprites/raw")
OUT = os.path.join(ROOT, "game/assets/tiles")


def decode(im):
    b = im["base64"].split(",", 1)[-1]
    return np.array(Image.open(io.BytesIO(base64.b64decode(b))).convert("RGBA"))


def tiles_by_mask(data):
    out = {}
    for t in data["tileset"]["tiles"]:
        c = t["corners"]
        m = (8 if c["NW"] == "upper" else 0) | (4 if c["NE"] == "upper" else 0) \
            | (2 if c["SW"] == "upper" else 0) | (1 if c["SE"] == "upper" else 0)
        out[m] = decode(t["image"])
    return out


STATE = {"lower": 0, "upper": 1, "transition": 2}


def import_cliff(name, data, grass):
    """Jeu en relief (mur, falaise) : coins à 3 états. Planche de N tuiles en ligne
    + <nom>.json : code (NO*27 + NE*9 + SO*3 + SE) -> index de tuile."""
    tiles = data["tileset"]["tiles"]
    size = decode(tiles[0]["image"]).shape[0]
    sheet = np.zeros((size, size * len(tiles), 4), dtype=np.uint8)
    lookup = {}
    for i, t in enumerate(tiles):
        im = decode(t["image"])
        if grass is not None:
            im[(im == grass).all(axis=2)] = 0
        sheet[:, i * size:(i + 1) * size] = im
        c = t["corners"]
        code = STATE[c["NW"]] * 27 + STATE[c["NE"]] * 9 + STATE[c["SW"]] * 3 + STATE[c["SE"]]
        lookup.setdefault(str(code), i)
    Image.fromarray(sheet).save(os.path.join(OUT, "wang", name + ".png"))
    json.dump({"tiles": len(tiles), "lookup": lookup}, open(os.path.join(OUT, "wang", name + ".json"), "w"))


def main():
    files = sorted(glob.glob(os.path.join(RAW, "wang_*.json")), key=lambda f: "mur" in f)
    if not files:
        sys.exit("Aucun fichier dans " + RAW)
    os.makedirs(os.path.join(OUT, "wang"), exist_ok=True)
    grass = None
    report = []
    for path in files:
        name = os.path.basename(path)[5:-5]
        data = json.load(open(path))
        if any("transition" in t["corners"].values() for t in data["tileset"]["tiles"]):
            import_cliff(name, data, grass)
            report.append("%s : mur en relief, %d tuiles" % (name, len(data["tileset"]["tiles"])))
            continue
        tiles = tiles_by_mask(data)
        if len(tiles) != 16:
            print("  %s : %d tuiles au lieu de 16, ignoré" % (name, len(tiles)))
            continue
        g = tiles[0]
        if grass is None:
            grass = g
            Image.fromarray(grass).save(os.path.join(OUT, "base_herbe.png"))
        same = (g == grass).all(axis=2).mean()
        size = g.shape[0]
        sheet = np.zeros((size, size * 16, 4), dtype=np.uint8)
        for m in range(16):
            t = tiles[m].copy()
            t[(t == grass).all(axis=2)] = 0
            sheet[:, m * size:(m + 1) * size] = t
        Image.fromarray(sheet).save(os.path.join(OUT, "wang", name + ".png"))
        report.append("%s : herbe identique à %.0f %%" % (name, same * 100))
    # Ponts : même dalle que le béton, dessinée au-dessus de l'eau
    beton = os.path.join(OUT, "wang", "beton.png")
    if os.path.exists(beton):
        Image.open(beton).save(os.path.join(OUT, "wang", "pont.png"))
    print("\n".join(report))


if __name__ == "__main__":
    main()
