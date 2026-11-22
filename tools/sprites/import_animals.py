#!/usr/bin/env python3
"""Assemble les animaux PixelLab (exports zip décompressés) en planches pour le jeu.

Entrée : tools/sprites/raw/faune/<nom>/Idle/{rotations,animations/<anim>/<dir>}/*.png
         (directions sud, est, nord ; l'ouest est l'est retourné)
Sortie : game/assets/characters/<nom>.png et <nom>.json (même format que le joueur).
"""
import glob
import json
import os

import numpy as np
from PIL import Image, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ANIMALS = ["lapin", "chevreuil", "sanglier", "renard", "chien", "loup"]
ANIMS = ["repos", "marche", "course", "attaque"]
DIRS = ["south", "west", "east", "north"]


def frames(src, anim, d):
    flip = d == "west"
    dd = "east" if flip else d
    if anim == "repos":
        files = [os.path.join(src, "rotations", dd + ".png")]
    else:
        files = sorted(glob.glob(os.path.join(src, "animations", anim, dd, "*.png")))
        if not files:
            return None
    ims = [Image.open(f).convert("RGBA") for f in files]
    return [ImageOps.mirror(i) for i in ims] if flip else ims


def main(name):
    src = os.path.join(ROOT, "tools/sprites/raw/faune", name, "Idle")
    rows = []
    for anim in ANIMS:
        for d in DIRS:
            f = frames(src, anim, d)
            if f:
                rows.append((anim, d, f))
    w, h = rows[0][2][0].size
    cols = max(len(f) for _, _, f in rows)
    sheet = Image.new("RGBA", (w * cols, h * len(rows)))
    for r, (_, _, fr) in enumerate(rows):
        for c, im in enumerate(fr):
            sheet.paste(im, (c * w, r * h))
    a = np.array(rows[2][2][0])[..., 3]          # repos, est : vue de profil
    feet = int(np.nonzero(a.any(axis=1))[0].max())
    out = os.path.join(ROOT, "game/assets/characters")
    sheet.save(os.path.join(out, name + ".png"))
    meta = {"frame_w": w, "frame_h": h, "feet_y": feet, "directions": DIRS,
            "anims": [{"name": a, "dir": d, "row": i, "frames": len(f)} for i, (a, d, f) in enumerate(rows)]}
    json.dump(meta, open(os.path.join(out, name + ".json"), "w"), indent=1)
    print(name, sheet.size, "pieds à", feet, len(rows), "lignes")


if __name__ == "__main__":
    for n in ANIMALS:
        main(n)
