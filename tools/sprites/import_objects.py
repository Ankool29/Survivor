#!/usr/bin/env python3
"""Copie les objets PixelLab (tools/sprites/raw/objets/<nom>.png) dans le jeu.

Sortie : game/assets/decor/<nom>.png et decor.json ({nom: {w, h, foot}}),
« foot » étant la plus basse ligne non transparente (le pied de l'objet).
"""
import glob
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "tools/sprites/raw/objets")
OUT = os.path.join(ROOT, "game/assets/decor")

os.makedirs(OUT, exist_ok=True)
meta = {}
for path in sorted(glob.glob(os.path.join(SRC, "*.png"))):
    name = os.path.basename(path)[:-4]
    im = Image.open(path).convert("RGBA")
    a = np.array(im)[..., 3]
    rows = np.nonzero(a.any(axis=1))[0]
    meta[name] = {"w": im.width, "h": im.height, "foot": int(rows.max()) if len(rows) else im.height - 1}
    im.save(os.path.join(OUT, name + ".png"))
json.dump(meta, open(os.path.join(OUT, "decor.json"), "w"), indent=1)
print(len(meta), "objets")
