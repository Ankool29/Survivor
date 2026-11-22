#!/usr/bin/env python3
"""Assemble un personnage PixelLab (export zip décompressé) en planche pour le jeu.

Entrée : tools/sprites/raw/<nom>/Idle/animations/<anim>/<direction>/<n>.png
Sortie : game/assets/characters/<nom>.png  (une ligne par animation et direction,
         une colonne par image) et <nom>.json (disposition, taille, pieds).
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ANIMS = [("repos", "breathing_idle"), ("marche", "walking"), ("course", "running")]
DIRS = ["south", "west", "east", "north"]


def main(name):
    src = os.path.join(ROOT, "tools/sprites/raw", name, "Idle")
    rows = []
    for anim, folder in ANIMS:
        for d in DIRS:
            files = sorted(glob.glob(os.path.join(src, "animations", folder, d, "*.png")),
                           key=lambda p: int(os.path.basename(p)[:-4].split("_")[-1]))
            if not files:
                files = [os.path.join(src, "rotations", d + ".png")]
            rows.append((anim, d, [Image.open(f).convert("RGBA") for f in files]))
    w, h = rows[0][2][0].size
    cols = max(len(f) for _, _, f in rows)
    sheet = Image.new("RGBA", (w * cols, h * len(rows)))
    for r, (_, _, frames) in enumerate(rows):
        for c, im in enumerate(frames):
            sheet.paste(im, (c * w, r * h))
    # Pieds : plus basse ligne opaque de la vue de face au repos
    a = np.array(rows[0][2][0])[..., 3]
    feet = int(np.nonzero(a.any(axis=1))[0].max())
    out = os.path.join(ROOT, "game/assets/characters")
    os.makedirs(out, exist_ok=True)
    sheet.save(os.path.join(out, name + ".png"))
    meta = {"frame_w": w, "frame_h": h, "feet_y": feet, "directions": DIRS,
            "anims": [{"name": a, "dir": d, "row": i, "frames": len(f)} for i, (a, d, f) in enumerate(rows)]}
    json.dump(meta, open(os.path.join(out, name + ".json"), "w"), indent=1)
    print(name, sheet.size, "pieds à", feet, [(a, d, len(f)) for a, d, f in rows[::4]])


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "joueur")
