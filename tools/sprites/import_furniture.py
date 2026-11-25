#!/usr/bin/env python3
"""Meubles PixelLab (tools/sprites/raw/meubles/*.png) -> game/assets/meubles/ :
on retire les marges transparentes ; le jeu cale le bas de l'image sur l'emprise du meuble."""
import glob
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "tools/sprites/raw/meubles")
OUT = os.path.join(ROOT, "game/assets/meubles")
os.makedirs(OUT, exist_ok=True)
n = 0
for f in sorted(glob.glob(os.path.join(SRC, "*.png"))):
    im = Image.open(f).convert("RGBA")
    box = im.getbbox()
    if box:
        im = im.crop(box)
    im.save(os.path.join(OUT, os.path.basename(f)))
    n += 1
print(n, "meubles")
