#!/usr/bin/env python3
"""Telecharge le relief de la zone (lance par GitHub Actions, qui a acces a internet).

1. IGN RGE ALTI via le service WMS de la Geoplateforme, decoupe en tuiles ;
2. a defaut, tuiles Copernicus DEM GLO-30 (AWS Open Data).
L'extrait OpenStreetMap est telecharge par le workflow (curl + osmium extract).
"""
import argparse
import json
import math
import os
import sys
import time
import urllib.request

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from build_zone import Grid, plausible  # noqa: E402

IGN_WMS = ("https://data.geopf.fr/wms-r/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap"
           "&LAYERS=ELEVATION.ELEVATIONGRIDCOVERAGE.HIGHRES&STYLES=&CRS=EPSG:2154"
           "&BBOX={x0},{y0},{x1},{y1}&WIDTH={w}&HEIGHT={h}&FORMAT=image/x-bil;bits=32")
COP = ("https://copernicus-dem-30m.s3.amazonaws.com/Copernicus_DSM_COG_10_{t}_DEM/"
       "Copernicus_DSM_COG_10_{t}_DEM.tif")


def get(url, path, tries=3):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "survivor-zone-builder"})
            with urllib.request.urlopen(req, timeout=120) as r, open(path, "wb") as f:
                f.write(r.read())
            return True
        except Exception as e:  # noqa: BLE001
            print("  echec (%s) : %s" % (i + 1, e), flush=True)
            time.sleep(3 * (i + 1))
    return False


def fetch_ign(grid, out, tile=400):
    tiles = []
    n = math.ceil(grid.size / tile)
    for r in range(n):
        for c in range(n):
            w = min(tile, grid.size - c * tile)
            h = min(tile, grid.size - r * tile)
            x0 = grid.x0 + c * tile * grid.cell
            y1 = grid.y1 - r * tile * grid.cell
            url = IGN_WMS.format(x0=x0, y0=y1 - h * grid.cell, x1=x0 + w * grid.cell, y1=y1, w=w, h=h)
            name = "ign_%d_%d.bil" % (r, c)
            path = os.path.join(out, name)
            if not get(url, path):
                return False
            raw = np.fromfile(path, dtype="<f4")
            if raw.size != w * h:
                print("  reponse IGN inattendue (%d octets) :" % os.path.getsize(path),
                      open(path, "rb").read(300), flush=True)
                return False
            if not plausible(raw) and not plausible(np.fromfile(path, dtype=">f4")):
                print("  valeurs IGN implausibles", flush=True)
                return False
            tiles.append({"file": name, "row": r * tile, "col": c * tile, "w": w, "h": h})
    json.dump({"tiles": tiles}, open(os.path.join(out, "ign_tiles.json"), "w"))
    print("  IGN : %d tuiles" % len(tiles), flush=True)
    return True


def fetch_copernicus(grid, out):
    lon0, lat0, lon1, lat1 = grid.bbox_wgs(0)
    ok = 0
    for lat in range(math.floor(lat0), math.floor(lat1) + 1):
        for lon in range(math.floor(lon0), math.floor(lon1) + 1):
            t = "%s%02d_00_%s%03d_00" % ("N" if lat >= 0 else "S", abs(lat), "E" if lon >= 0 else "W", abs(lon))
            if get(COP.format(t=t), os.path.join(out, "dem_%s.tif" % t)):
                ok += 1
    print("  Copernicus : %d tuiles" % ok, flush=True)
    return ok > 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    grid = Grid(json.load(open(args.config)))
    os.makedirs(args.out, exist_ok=True)
    print("Relief IGN...", flush=True)
    if fetch_ign(grid, args.out):
        return
    for f in os.listdir(args.out):
        if f.startswith("ign_"):
            os.remove(os.path.join(args.out, f))
    print("Relief Copernicus...", flush=True)
    if not fetch_copernicus(grid, args.out):
        print("Aucun relief : la zone sera plate.", flush=True)


if __name__ == "__main__":
    main()
