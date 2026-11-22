#!/usr/bin/env python3
"""Zone à l'échelle réelle découpée en tuiles (appelé par build_zone.py quand
la configuration contient "tile").

Sortie (dossier --out) :
  meta.json            taille, échelle, tuiles, codes, sources
  tiles/<tx>_<ty>.bin.gz  pour chaque tuile non entièrement marine :
                       terrain, voies, bâtiments (TILE x TILE octets chacun, à la suite)
                       bâtiments : (bits 0-3) 1 sol, 2 mur, 3 sol de bâtiment notable, 4 porte ;
                       (bits 4-5) toit : 0 aucun, 1 ardoise, 2 tôle ; (bits 6-7) état :
                       0 intact, 1 toit effondré, 2 ruine
  elev.bin.gz          altitude en mètres (0-255), grille grossière (ELEV_STEP cases)
  pois.json, places.json
  preview.png          aperçu réduit pour la carte du jeu

Les grilles sont orientées ligne 0 au nord ; tuile (tx, ty) = cases
[tx*TILE, (tx+1)*TILE) x [ty*TILE, (ty+1)*TILE).
"""
import glob
import gzip
import json
import os

import numpy as np
import shapely
import shapely.affinity
from affine import Affine
from rasterio import features
from scipy import ndimage

from build_zone import (PREVIEW_COLORS, REAL_WIDTH_M, ROADS, TERRAIN, Collector, Grid, log,
                        read_elevation)

ELEV_STEP = 4          # une altitude toutes les 4 cases (8 m)
PREVIEW_STEP = 8       # un pixel d'aperçu pour 8 x 8 cases (16 m)


class SubGrid:
    """Grille d'une tuile (avec marge) : même interface que Grid pour rasterize."""

    def __init__(self, grid, col0, row0, w, h):
        self.cell = grid.cell
        self.shape = (h, w)
        self.transform = Affine(grid.cell, 0, grid.x0 + col0 * grid.cell, 0, -grid.cell,
                                grid.y1 - row0 * grid.cell)


def coarse_grid(cfg, step):
    c = dict(cfg)
    c["cells_per_km"] = cfg["cells_per_km"] / step
    g = Grid(c)
    return g


def orthogonalize(g, max_deg=25.0):
    """Redresse un bâtiment presque aligné sur la grille (sinon ses murs font des escaliers)."""
    try:
        g = g.simplify(0.6, preserve_topology=True)
        rect = g.minimum_rotated_rectangle
        xs, ys = rect.exterior.coords.xy
        dx, dy = xs[1] - xs[0], ys[1] - ys[0]
        ang = np.degrees(np.arctan2(dy, dx))
        ang = (ang + 45.0) % 90.0 - 45.0          # écart à l'axe le plus proche
        if abs(ang) <= max_deg and abs(ang) > 0.5:
            g = shapely.affinity.rotate(g, -ang, origin="centroid")
        return g
    except Exception:
        return g


def pick_doors(ids, bld, rd, inner):
    """Une porte par bâtiment (deux s'il est grand) : une case de mur droite qui donne
    sur l'extérieur, de préférence vers une voie, sinon vers le sud."""
    h, w = ids.shape
    wall = bld == 2
    ys, xs = np.nonzero(wall & inner)
    if len(ys) == 0:
        return
    k = ids[ys, xs]
    best = {}
    for d, (dy, dx) in enumerate(((1, 0), (0, -1), (0, 1), (-1, 0))):     # sud, ouest, est, nord
        oy, ox = ys + dy, xs + dx
        iy, ix = ys - dy, xs - dx
        ok = (oy >= 0) & (oy < h) & (ox >= 0) & (ox < w) & (iy >= 0) & (iy < h) & (ix >= 0) & (ix < w)
        oyc, oxc = np.clip(oy, 0, h - 1), np.clip(ox, 0, w - 1)
        iyc, ixc = np.clip(iy, 0, h - 1), np.clip(ix, 0, w - 1)
        outside = ids[oyc, oxc] != k
        indoor = (ids[iyc, ixc] == k) & (bld[iyc, ixc] != 2)
        # mur droit : les deux voisins le long du mur sont des murs du même bâtiment
        ay, ax = np.clip(ys + dx, 0, h - 1), np.clip(xs + dy, 0, w - 1)
        by, bx = np.clip(ys - dx, 0, h - 1), np.clip(xs - dy, 0, w - 1)
        straight = (ids[ay, ax] == k) & (ids[by, bx] == k) & wall[ay, ax] & wall[by, bx]
        cand = ok & outside & indoor & straight
        score = np.where(rd[oyc, oxc] > 0, 10.0, 0.0) + (3 - d) * 0.5 + ((ys * 7 + xs * 13) % 97) * 0.004
        for j in np.nonzero(cand)[0]:
            kk = int(k[j])
            if score[j] > best.get(kk, (-1, 0, 0))[0]:
                best[kk] = (score[j], ys[j], xs[j])
    for kk, (_, y, x) in best.items():
        bld[y, x] = 4


def burn(shapes, sub, out, all_touched=False):
    shapes = [(g, v) for g, v in shapes if g is not None and not g.is_empty]
    if shapes:
        features.rasterize(shapes, out=out, transform=sub.transform, all_touched=all_touched)


def build(cfg, src, out):
    grid = Grid(cfg)
    T = int(cfg["tile"])
    n_t = (grid.size + T - 1) // T
    os.makedirs(os.path.join(out, "tiles"), exist_ok=True)
    for old in glob.glob(os.path.join(out, "tiles", "*.bin.gz")) + glob.glob(os.path.join(out, "*.bin*")):
        os.remove(old)
    log("Zone %s : %d x %d cases de %.2f m, %d x %d tuiles de %d" % (
        cfg["name"], grid.size, grid.size, grid.cell, n_t, n_t, T))

    osm = sorted(glob.glob(os.path.join(src, "*.osm.pbf")) + glob.glob(os.path.join(src, "*.osm")))[0]
    col = Collector(grid, real=True)
    log("Lecture OSM :", osm)
    col.apply_file(osm, locations=True)
    log("  surfaces %d, cours d'eau %d, voies %d, batiments %d, lieux %d, noms %d" % (
        len(col.landcover), len(col.water_lines), len(col.roads), len(col.buildings),
        len(col.pois), len(col.places)))

    # --- Relief et mer, à basse résolution (8 m)
    eg = coarse_grid(cfg, ELEV_STEP)
    elev, elev_src = read_elevation(eg, src)
    low = ~np.isfinite(elev) | (elev <= 0.5)
    coast = np.zeros(eg.shape, dtype=np.uint8)
    burn([(g, 1) for g in col.coast], eg, coast, all_touched=True)
    labels, _ = ndimage.label(low & (coast == 0))
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    sea_c = np.isin(labels, border[border > 0])
    sea_c |= (coast > 0) & low & ndimage.binary_dilation(sea_c)
    e = np.where(np.isfinite(elev), elev, 0).astype(np.float32)
    e = ndimage.gaussian_filter(e, 1.0)
    e[sea_c] = 0
    elev8 = np.clip(np.round(e), 0, 255).astype(np.uint8)
    with gzip.open(os.path.join(out, "elev.bin.gz"), "wb", compresslevel=9) as f:
        f.write(elev8.tobytes())

    # --- Géométries prêtes à brûler (une fois pour toutes)
    log("Préparation des géométries…")
    land = sorted(col.landcover, key=lambda t: t[0])
    land_geoms = [g for _, g, _ in land]
    land_vals = [v for _, _, v in land]
    water = [g.buffer(1.5) if w == 1 else g.buffer(7.0) for g, w in col.water_lines]
    order = {5: 0, 4: 1, 6: 2, 3: 3, 2: 4, 1: 5}
    roads = sorted(col.roads, key=lambda t: order[t[0]])
    road_geoms = [g.buffer(REAL_WIDTH_M[c] / 2, cap_style="flat") for c, g in roads]
    road_vals = [c for c, _ in roads]
    bld_geoms = [orthogonalize(g) for g in col.buildings]
    bld_spec = col.building_special
    bld_roof = col.building_roof
    # État de chaque bâtiment (stable pour une même carte) : 0 intact, 1 toit effondré, 2 ruine
    rng = np.random.default_rng(1234)
    rr = rng.random(len(bld_geoms))
    bld_state = np.where(rr < 0.85, 0, np.where(rr < 0.95, 1, 2)).astype(np.uint8)
    trees = {name: shapely.STRtree(gs) if gs else None for name, gs in
             [("land", land_geoms), ("water", water), ("road", road_geoms), ("bld", bld_geoms)]}

    def query(name, box):
        t = trees[name]
        return [] if t is None else sorted(t.query(box))

    # --- Tuiles
    counts = {"terrain": np.zeros(256, np.int64), "roads": np.zeros(256, np.int64)}
    written = 0
    preview = np.zeros((grid.size // PREVIEW_STEP + 1, grid.size // PREVIEW_STEP + 1, 3), np.uint8)
    M = 2  # marge pour les murs et les portes en bord de tuile
    for ty in range(n_t):
        for tx in range(n_t):
            c0, r0 = tx * T, ty * T
            w = min(T, grid.size - c0)
            h = min(T, grid.size - r0)
            # mer : grille grossière agrandie
            sc = sea_c[r0 // ELEV_STEP:(r0 + h + ELEV_STEP - 1) // ELEV_STEP + 1,
                       c0 // ELEV_STEP:(c0 + w + ELEV_STEP - 1) // ELEV_STEP + 1]
            sea = np.repeat(np.repeat(sc, ELEV_STEP, 0), ELEV_STEP, 1)
            if sea.shape[0] < h or sea.shape[1] < w:
                sea = np.pad(sea, ((0, max(0, h - sea.shape[0])), (0, max(0, w - sea.shape[1]))), mode="edge")
            sea = sea[:h, :w]
            if sea.all():
                continue
            sub = SubGrid(grid, c0 - M, r0 - M, w + 2 * M, h + 2 * M)
            x0 = grid.x0 + (c0 - M) * grid.cell
            y1 = grid.y1 - (r0 - M) * grid.cell
            box = shapely.box(x0, y1 - (h + 2 * M) * grid.cell, x0 + (w + 2 * M) * grid.cell, y1)
            terr = np.full(sub.shape, TERRAIN["champ"], np.uint8)
            idx = query("land", box)
            burn([(land_geoms[i], land_vals[i]) for i in idx], sub, terr)
            wl = np.zeros(sub.shape, np.uint8)
            burn([(water[i], 1) for i in query("water", box)], sub, wl, all_touched=True)
            terr[wl > 0] = TERRAIN["eau"]
            rd = np.zeros(sub.shape, np.uint8)
            burn([(road_geoms[i], road_vals[i]) for i in query("road", box)], sub, rd, all_touched=True)
            ids = np.zeros(sub.shape, np.int32)
            bidx = query("bld", box)
            burn([(bld_geoms[i], k + 1) for k, i in enumerate(bidx)], sub, ids)
            bld = np.zeros(sub.shape, np.uint8)
            inside = ids > 0
            if inside.any():
                spec = np.array([False] + [bld_spec[i] for i in bidx])
                bld[inside] = np.where(spec[ids[inside]], 3, 1)
                edge = np.zeros(sub.shape, bool)
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    edge |= inside & (np.roll(np.roll(ids, dy, 0), dx, 1) != ids)
                bld[edge] = 2
                inner = np.zeros(sub.shape, bool)
                inner[M:M + h, M:M + w] = True
                pick_doors(ids, bld, rd, inner)
                # ruines : deux ou trois brèches de plus
                st_of = np.array([0] + [int(bld_state[i]) for i in bidx], np.uint8)
                rf_of = np.array([0] + [int(bld_roof[i]) for i in bidx], np.uint8)
                walls = np.nonzero((bld == 2) & inner & (st_of[ids] == 2))
                if len(walls[0]):
                    pick = (walls[0] * 31 + walls[1] * 17) % 23 == 0
                    bld[walls[0][pick], walls[1][pick]] = 4
                # code final : base | toit << 4 | état << 6 (toit 0 si effondré ou ruine)
                roof = np.where(st_of[ids] == 0, rf_of[ids], 0).astype(np.uint8)
                state = st_of[ids]
                bld = np.where(bld > 0, bld | (roof << 4) | (state << 6), 0).astype(np.uint8)
            # retirer la marge
            terr, rd, bld = (a[M:M + h, M:M + w] for a in (terr, rd, bld))
            terr[sea] = TERRAIN["mer"]
            rd[sea & (rd != 1) & (rd != 2)] = 0
            bld[sea] = 0
            if w < T or h < T:
                pad = lambda a, v: np.pad(a, ((0, T - h), (0, T - w)), constant_values=v)
                terr, rd, bld = pad(terr, TERRAIN["mer"]), pad(rd, 0), pad(bld, 0)
            with gzip.open(os.path.join(out, "tiles", "%d_%d.bin.gz" % (tx, ty)), "wb", compresslevel=9) as f:
                f.write(terr.tobytes() + rd.tobytes() + bld.tobytes())
            written += 1
            counts["terrain"] += np.bincount(terr.ravel(), minlength=256)
            counts["roads"] += np.bincount(rd.ravel(), minlength=256)
            # aperçu
            lut = np.zeros((256, 3), np.uint8)
            for k, c in PREVIEW_COLORS.items():
                lut[k] = c
            img = lut[terr[:h:PREVIEW_STEP, :w:PREVIEW_STEP]]
            rs = rd[:h:PREVIEW_STEP, :w:PREVIEW_STEP]
            img[rs > 0] = (205, 200, 190)
            img[np.isin(rs, (1, 2))] = (235, 190, 90)
            bs = bld[:h:PREVIEW_STEP, :w:PREVIEW_STEP]
            img[bs > 0] = (110, 96, 86)
            img[(bs >> 4 & 3) == 1] = (78, 84, 98)
            img[(bs >> 4 & 3) == 2] = (128, 126, 120)
            pr0, pc0 = r0 // PREVIEW_STEP, c0 // PREVIEW_STEP
            preview[pr0:pr0 + img.shape[0], pc0:pc0 + img.shape[1]] = img
        log("  rangée %d/%d (%d tuiles écrites)" % (ty + 1, n_t, written))

    # mer sur l'aperçu pour les tuiles non écrites + ombrage
    from PIL import Image
    ps = preview.shape[0]
    sea_small = np.array(Image.fromarray(sea_c.astype(np.uint8) * 255).resize((ps, ps), Image.NEAREST)) > 0
    preview[sea_small] = PREVIEW_COLORS[0]
    es = np.array(Image.fromarray(e).resize((ps, ps), Image.BILINEAR))
    gy, gx = np.gradient(es)
    shade = np.clip(1.0 - (gx - gy) * 0.05, 0.75, 1.2)
    preview = np.clip(preview * shade[..., None], 0, 255).astype(np.uint8)
    Image.fromarray(preview).save(os.path.join(out, "preview.png"), optimize=True)

    col.pois.sort(key=lambda p: (-p["area_m2"], p["kind"]))
    json.dump(col.pois, open(os.path.join(out, "pois.json"), "w"), ensure_ascii=False, indent=0)
    rank = {"city": 0, "town": 1, "suburb": 2, "village": 3, "hamlet": 4, "locality": 5, "isolated_dwelling": 6}
    col.places.sort(key=lambda p: (rank.get(p["kind"], 9), -p["population"], p["name"]))
    json.dump(col.places, open(os.path.join(out, "places.json"), "w"), ensure_ascii=False, indent=0)
    meta = {
        "name": cfg["name"], "title": cfg.get("title", cfg["name"]),
        "width": grid.size, "height": grid.size,
        "cells_per_km": grid.cells_per_km, "cell_m": grid.cell,
        "crs": "EPSG:2154", "origin_x": grid.x0, "origin_y": grid.y1,
        "mode": "reel", "tile": T, "tiles_x": n_t, "tiles_y": n_t,
        "tile_layers": ["terrain", "roads", "bld"],
        "elev_step": ELEV_STEP, "elev_w": eg.size, "elev_h": eg.size,
        "terrain_codes": TERRAIN, "road_codes": ROADS,
        "sources": ["OpenStreetMap contributors (ODbL)", elev_src],
        "counts": {
            "tiles": written,
            "terrain": {k: int(counts["terrain"][v]) for k, v in TERRAIN.items()},
            "roads": {k: int(counts["roads"][v]) for k, v in ROADS.items()},
            "pois": len(col.pois), "places": len(col.places), "buildings": len(col.buildings),
        },
    }
    json.dump(meta, open(os.path.join(out, "meta.json"), "w"), ensure_ascii=False, indent=1)
    log("Termine :", written, "tuiles ;", json.dumps(meta["counts"]["roads"]))
