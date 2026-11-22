#!/usr/bin/env python3
"""Fabrique une zone de jeu a partir de donnees geographiques reelles.

Entrees (dossier --src) :
  - un extrait OpenStreetMap (.osm.pbf ou .osm) qui couvre la zone ;
  - le relief : grilles IGN (ign_*.bil, telechargees par fetch_sources.py)
    ou, a defaut, des tuiles Copernicus DEM (dem_*.tif).

Sortie (dossier --out), lue par le jeu (game/scripts/world/zone_data.gd) :
  meta.json      taille, echelle, origine, codes, sources a citer
  terrain.bin    1 octet par case : type de sol (voir TERRAIN)
  roads.bin      1 octet par case : type de voie (voir ROADS)
  density.bin    1 octet par case : part du sol couverte de batiments (0-255)
  elev.bin       1 octet par case : altitude en metres (0-255)
  pois.json      lieux notables (hopital, supermarche, eglise, gare...)
  places.json    noms des villes, bourgs et hameaux
  preview.png    apercu colore de la zone

Grille : ligne 0 au nord, colonne 0 a l'ouest. Projection Lambert-93.
"""
import argparse
import glob
import json
import math
import os
import sys

import numpy as np
import osmium
import pyproj
import rasterio
import shapely
from affine import Affine
from rasterio import features
from rasterio.warp import Resampling, reproject
from scipy import ndimage
from shapely import wkb

# --- Codes partages avec le jeu (garder en phase avec zone_data.gd) ---------
TERRAIN = {
    "mer": 0, "eau": 1, "sable": 2, "prairie": 3, "champ": 4,
    "foret_feuillus": 5, "foret_resineux": 6, "foret_mixte": 7,
    "lande": 8, "marais": 9, "urbain": 10, "industriel": 11,
    "roche": 12, "cimetiere": 13, "parc": 14,
}
ROADS = {
    "aucune": 0, "voie_rapide": 1, "principale": 2, "secondaire": 3,
    "rue": 4, "chemin": 5, "rail": 6,
}
# Largeur dessinee, en cases (une case = 1/32 km)
ROAD_WIDTH = {1: 4, 2: 3, 3: 2, 4: 1, 5: 1, 6: 1}
# En ville, les petites rues plus courtes que ceci sont omises : a 31 m par case,
# garder toutes les rues ne laisserait aucune place aux batiments.
URBAN_STREET_MIN_M = 500
URBAN_DENSITY = 30
# Mode « reel » (echelle 1:1) : largeur des voies en metres
REAL_WIDTH_M = {1: 14.0, 2: 8.0, 3: 6.5, 4: 5.0, 5: 2.5, 6: 4.0}
HIGHWAY_REAL_EXTRA = {"service": 4, "footway": 5, "path": 5, "cycleway": 5, "bridleway": 5,
                      "steps": 5, "pedestrian": 4}
HIGHWAY = {
    "motorway": 1, "trunk": 1, "motorway_link": 2, "trunk_link": 2,
    "primary": 2, "primary_link": 2,
    "secondary": 3, "secondary_link": 3, "tertiary": 3, "tertiary_link": 3,
    "residential": 4, "unclassified": 4, "living_street": 4, "pedestrian": 4,
    "track": 5,
}
PREVIEW_COLORS = {
    0: (38, 72, 112), 1: (64, 112, 160), 2: (214, 200, 150), 3: (140, 170, 90),
    4: (176, 168, 96), 5: (52, 102, 48), 6: (36, 78, 52), 7: (46, 92, 50),
    8: (130, 120, 80), 9: (90, 120, 100), 10: (150, 140, 130), 11: (120, 110, 110),
    12: (130, 130, 120), 13: (120, 130, 110), 14: (110, 150, 80),
}

# Toits de tôle : hangars, ateliers, commerces ; les autres bâtiments ont un toit d'ardoise
METAL_ROOF = {"industrial", "warehouse", "retail", "commercial", "garage", "garages", "barn",
              "farm_auxiliary", "hangar", "shed", "supermarket", "service", "manufacture",
              "storage_tank", "greenhouse", "carport", "transportation", "sports_hall"}
SLATE_KINDS = {"eglise", "mairie", "chateau", "musee", "bibliotheque", "ecole", "ferme", "pharmacie"}

POI_KINDS = {
    ("amenity", "hospital"): "hopital", ("amenity", "clinic"): "hopital",
    ("amenity", "pharmacy"): "pharmacie", ("amenity", "doctors"): "pharmacie",
    ("shop", "supermarket"): "supermarche", ("shop", "convenience"): "epicerie",
    ("shop", "hardware"): "quincaillerie", ("shop", "doityourself"): "quincaillerie",
    ("shop", "car_repair"): "garage", ("amenity", "fuel"): "station_service",
    ("amenity", "school"): "ecole", ("amenity", "college"): "ecole",
    ("amenity", "library"): "bibliotheque", ("amenity", "townhall"): "mairie",
    ("amenity", "police"): "gendarmerie", ("amenity", "fire_station"): "pompiers",
    ("amenity", "place_of_worship"): "eglise", ("railway", "station"): "gare",
    ("man_made", "water_tower"): "chateau_eau", ("man_made", "lighthouse"): "phare",
    ("historic", "castle"): "chateau", ("historic", "monument"): "monument",
    ("historic", "memorial"): "monument", ("tourism", "museum"): "musee",
    ("landuse", "military"): "militaire", ("amenity", "marketplace"): "marche",
    ("shop", "farm"): "ferme", ("place", "farm"): "ferme",
}
PLACE_KINDS = {"city", "town", "village", "hamlet", "suburb", "isolated_dwelling", "locality"}


def log(*a):
    print(*a, flush=True)


class Grid:
    def __init__(self, cfg):
        self.cells_per_km = cfg["cells_per_km"]
        self.cell = 1000.0 / self.cells_per_km
        self.size = int(round(cfg["size_km"] * self.cells_per_km))
        self.to_l93 = pyproj.Transformer.from_crs(4326, 2154, always_xy=True)
        self.to_wgs = pyproj.Transformer.from_crs(2154, 4326, always_xy=True)
        cx, cy = self.to_l93.transform(cfg["center_lon"], cfg["center_lat"])
        half = self.size * self.cell / 2
        self.x0 = cx - half
        self.y1 = cy + half
        self.transform = Affine(self.cell, 0, self.x0, 0, -self.cell, self.y1)
        self.shape = (self.size, self.size)

    def bbox_wgs(self, margin_m=2000):
        xs = [self.x0 - margin_m, self.x0 + self.size * self.cell + margin_m]
        ys = [self.y1 - self.size * self.cell - margin_m, self.y1 + margin_m]
        pts = [self.to_wgs.transform(x, y) for x in xs for y in ys]
        lons = [p[0] for p in pts]
        lats = [p[1] for p in pts]
        return min(lons), min(lats), max(lons), max(lats)

    def project(self, geom):
        def f(coords):
            x, y = self.to_l93.transform(coords[:, 0], coords[:, 1])
            return np.column_stack([x, y])
        return shapely.transform(geom, f)

    def to_cell(self, x, y):
        return (x - self.x0) / self.cell, (self.y1 - y) / self.cell


class Collector(osmium.SimpleHandler):
    """Lit l'extrait OSM et range les geometries par usage."""

    def __init__(self, grid, real=False):
        super().__init__()
        self.grid = grid
        self.real = real
        self.building_special = []
        self.building_roof = []       # 1 ardoise, 2 tôle
        self.wkb = osmium.geom.WKBFactory()
        self.landcover = []   # (priorite, geometrie, code terrain)
        self.water_lines = []  # (geometrie, largeur en cases)
        self.coast = []
        self.roads = []        # (code, geometrie)
        self.buildings = []
        self.pois = []
        self.places = []

    # -- utilitaires
    def _geom(self, hexwkb):
        try:
            return self.grid.project(wkb.loads(hexwkb, hex=True))
        except Exception:
            return None

    @staticmethod
    def _poi_kind(tags):
        for (k, v), kind in POI_KINDS.items():
            if tags.get(k) == v:
                return kind
        return None

    def _add_poi(self, kind, geom, tags):
        c = geom.centroid if geom.geom_type != "Point" else geom
        col, row = self.grid.to_cell(c.x, c.y)
        if not (0 <= col < self.grid.size and 0 <= row < self.grid.size):
            return
        area = geom.area if geom.geom_type in ("Polygon", "MultiPolygon") else 0.0
        self.pois.append({
            "kind": kind, "x": round(col, 1), "y": round(row, 1),
            "area_m2": round(area), "name": tags.get("name", ""),
        })

    # -- noeuds
    def node(self, n):
        tags = n.tags
        if "place" in tags and tags["place"] in PLACE_KINDS and "name" in tags:
            g = self._geom(self.wkb.create_point(n))
            if g is None:
                return
            col, row = self.grid.to_cell(g.x, g.y)
            if 0 <= col < self.grid.size and 0 <= row < self.grid.size:
                pop = tags.get("population", "")
                self.places.append({
                    "name": tags["name"], "kind": tags["place"],
                    "x": round(col, 1), "y": round(row, 1),
                    "population": int(pop) if pop.isdigit() else 0,
                })
        kind = self._poi_kind(tags)
        if kind:
            g = self._geom(self.wkb.create_point(n))
            if g is not None:
                self._add_poi(kind, g, tags)

    # -- chemins (lignes)
    def way(self, w):
        tags = w.tags
        hw = tags.get("highway")
        rw = tags.get("railway")
        ww = tags.get("waterway")
        coast = tags.get("natural") == "coastline"
        if self.real and hw in HIGHWAY_REAL_EXTRA and hw not in HIGHWAY:
            hw_code = HIGHWAY_REAL_EXTRA[hw]
        else:
            hw_code = HIGHWAY.get(hw)
        if not (hw_code or rw == "rail" or ww in ("river", "canal", "stream", "ditch", "drain") or coast):
            return
        try:
            g = self._geom(self.wkb.create_linestring(w))
        except Exception:
            return
        if g is None:
            return
        if hw_code and tags.get("tunnel") != "yes":
            self.roads.append((hw_code, g))
        elif rw == "rail" and tags.get("tunnel") != "yes":
            self.roads.append((ROADS["rail"], g))
        elif ww in ("river", "canal"):
            self.water_lines.append((g, 2))
        elif ww in ("stream", "ditch", "drain"):
            self.water_lines.append((g, 1))
        elif coast:
            self.coast.append(g)

    # -- surfaces (polygones et multipolygones)
    def area(self, a):
        tags = a.tags
        code = None
        prio = 0
        natural = tags.get("natural")
        landuse = tags.get("landuse")
        leisure = tags.get("leisure")
        if natural == "wood" or landuse == "forest":
            lt = tags.get("leaf_type", "")
            code = {"broadleaved": "foret_feuillus", "needleleaved": "foret_resineux"}.get(lt, "foret_mixte")
            prio = 3
        elif natural in ("scrub", "heath"):
            code, prio = "lande", 3
        elif natural == "wetland":
            code, prio = "marais", 4
        elif natural in ("grassland",) or landuse in ("meadow", "grass", "village_green"):
            code, prio = "prairie", 2
        elif landuse in ("farmland", "orchard", "vineyard", "farmyard", "allotments"):
            code, prio = "champ", 1
        elif landuse in ("residential", "retail", "commercial"):
            code, prio = "urbain", 2
        elif landuse in ("industrial", "railway", "port"):
            code, prio = "industriel", 2
        elif landuse == "cemetery":
            code, prio = "cimetiere", 5
        elif leisure in ("park", "garden", "golf_course", "pitch"):
            code, prio = "parc", 4
        elif natural in ("beach", "sand", "dune"):
            code, prio = "sable", 5
        elif natural in ("bare_rock", "scree", "cliff") or landuse == "quarry":
            code, prio = "roche", 5
        elif natural == "water" or landuse in ("reservoir", "basin") or tags.get("waterway") == "riverbank":
            code, prio = "eau", 8
        is_building = "building" in tags and tags.get("building") != "no"
        kind = self._poi_kind(tags)
        if code is None and not is_building and not kind:
            return
        try:
            g = self._geom(self.wkb.create_multipolygon(a))
        except Exception:
            return
        if g is None or g.is_empty:
            return
        if code is not None:
            self.landcover.append((prio, g, TERRAIN[code]))
        if is_building:
            self.buildings.append(g)
            self.building_special.append(bool(kind))
            btag = tags.get("building", "yes")
            metal = btag in METAL_ROOF or (kind and kind not in SLATE_KINDS) or \
                (btag == "yes" and g.area > 900)
            self.building_roof.append(2 if metal else 1)
            if not kind and g.area > 1500:
                b = tags.get("building")
                kind = {"industrial": "entrepot", "warehouse": "entrepot", "retail": "magasin",
                        "commercial": "magasin", "church": "eglise", "chapel": "eglise",
                        "school": "ecole", "hospital": "hopital", "farm": "ferme",
                        "barn": "ferme", "farm_auxiliary": "ferme"}.get(b, "grand_batiment")
        if kind:
            self._add_poi(kind, g, tags)


def plausible(arr):
    """Vrai si la grille ressemble a des altitudes en metres (ou a de la mer)."""
    ok = np.isfinite(arr) & (arr > -100) & (arr < 5000)
    nodata = np.isfinite(arr) & (arr < -1000) & (arr > -1e6)
    return (ok | nodata).mean() > 0.98


def read_elevation(grid, src):
    """Altitude par case (float32, NaN = mer ou absence de donnee)."""
    out = np.full(grid.shape, np.nan, dtype=np.float32)
    ign = sorted(glob.glob(os.path.join(src, "ign_*.bil")))
    if ign:
        meta = json.load(open(os.path.join(src, "ign_tiles.json")))
        for t in meta["tiles"]:
            path = os.path.join(src, t["file"])
            if not os.path.exists(path):
                continue
            raw = np.fromfile(path, dtype="<f4")
            if raw.size != t["w"] * t["h"]:
                log("  tuile IGN de taille inattendue :", t["file"])
                continue
            arr = raw.reshape(t["h"], t["w"])
            if not plausible(arr):
                arr = np.fromfile(path, dtype=">f4").reshape(t["h"], t["w"])
            if not plausible(arr):
                log("  tuile IGN illisible :", t["file"])
                continue
            arr = np.where(arr < -1000, np.nan, arr)
            out[t["row"]:t["row"] + t["h"], t["col"]:t["col"] + t["w"]] = arr
        log("  relief : IGN RGE ALTI,", int(np.isfinite(out).sum()), "cases renseignees")
        return out, "IGN RGE ALTI (Licence Ouverte Etalab 2.0)"
    dems = sorted(glob.glob(os.path.join(src, "dem_*.tif")))
    for path in dems:
        with rasterio.open(path) as ds:
            tmp = np.full(grid.shape, np.nan, dtype=np.float32)
            reproject(source=rasterio.band(ds, 1), destination=tmp,
                      src_transform=ds.transform, src_crs=ds.crs, src_nodata=ds.nodata,
                      dst_transform=grid.transform, dst_crs="EPSG:2154", dst_nodata=np.nan,
                      resampling=Resampling.bilinear)
            out = np.where(np.isfinite(tmp), tmp, out)
    if dems:
        log("  relief : Copernicus DEM,", int(np.isfinite(out).sum()), "cases renseignees")
        return out, "Copernicus DEM GLO-30 (ESA)"
    log("  relief : aucune donnee, terrain plat")
    return np.zeros(grid.shape, dtype=np.float32), "aucune"


def rasterize(shapes, grid, out, all_touched=False):
    shapes = [(g, v) for g, v in shapes if g is not None and not g.is_empty]
    if shapes:
        features.rasterize(shapes, out=out, transform=grid.transform, all_touched=all_touched)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True)
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--bbox-only", action="store_true", help="affiche la boite lon/lat et s'arrete")
    args = ap.parse_args()
    cfg = json.load(open(args.config))
    grid = Grid(cfg)
    if args.bbox_only:
        print("%.5f,%.5f,%.5f,%.5f" % grid.bbox_wgs())
        return
    os.makedirs(args.out, exist_ok=True)
    if cfg.get("tile"):
        from build_tiled import build
        build(cfg, args.src, args.out)
        return
    log("Zone %s : %d x %d cases de %.2f m" % (cfg["name"], grid.size, grid.size, grid.cell))

    osm_files = sorted(glob.glob(os.path.join(args.src, "*.osm.pbf")) + glob.glob(os.path.join(args.src, "*.osm")))
    if not osm_files:
        sys.exit("Aucun fichier OSM dans " + args.src)
    real = cfg.get("mode") == "reel"
    col = Collector(grid, real)
    log("Lecture OSM :", osm_files[0])
    col.apply_file(osm_files[0], locations=True)
    log("  surfaces %d, cours d'eau %d, voies %d, batiments %d, lieux %d, noms %d" % (
        len(col.landcover), len(col.water_lines), len(col.roads), len(col.buildings),
        len(col.pois), len(col.places)))

    # --- Relief et mer
    elev, elev_src = read_elevation(grid, args.src)
    terrain = np.full(grid.shape, TERRAIN["champ"], dtype=np.uint8)
    # Mer : cases basses ou sans altitude reliees au bord de la zone
    low = ~np.isfinite(elev) | (elev <= 0.5)
    coast = np.zeros(grid.shape, dtype=np.uint8)
    rasterize([(g, 1) for g in col.coast], grid, coast, all_touched=True)
    candidates = low & (coast == 0)
    labels, n = ndimage.label(candidates)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    border = border[border > 0]
    sea = np.isin(labels, border)
    # Les lignes de cote basses rejoignent la mer si elles la touchent
    sea |= (coast > 0) & low & ndimage.binary_dilation(sea)

    # --- Occupation du sol, par priorite croissante
    for prio in sorted({p for p, _, _ in col.landcover}):
        rasterize([(g, v) for p, g, v in col.landcover if p == prio], grid, terrain)
    # Cours d'eau lineaires
    wl = np.zeros(grid.shape, dtype=np.uint8)
    if real:
        rasterize([(g.buffer(1.5), 1) for g, w in col.water_lines if w == 1], grid, wl, all_touched=True)
        rasterize([(g.buffer(7.0), 1) for g, w in col.water_lines if w == 2], grid, wl)
    else:
        rasterize([(g, 1) for g, w in col.water_lines if w == 1], grid, wl, all_touched=True)
        rasterize([(g.buffer(grid.cell * 0.9), 1) for g, w in col.water_lines if w == 2], grid, wl)
    terrain[wl > 0] = TERRAIN["eau"]
    terrain[sea] = TERRAIN["mer"]

    # --- Batiments : part de la case couverte (calcul a 4x la resolution)
    k = 4
    fine = np.zeros((grid.size * k, grid.size * k), dtype=np.uint8)
    fine_tr = Affine(grid.cell / k, 0, grid.x0, 0, -grid.cell / k, grid.y1)
    if col.buildings:
        features.rasterize(((g, 1) for g in col.buildings), out=fine, transform=fine_tr)
    density = fine.reshape(grid.size, k, grid.size, k).mean(axis=(1, 3))
    density = np.clip(density * 255, 0, 255).astype(np.uint8)
    density[sea] = 0
    del fine

    # --- Rues de ville : on ne garde que les longues
    urban_mask = ndimage.uniform_filter(density.astype(np.float32), 5) > URBAN_DENSITY
    kept, dropped = [], 0
    for c, g in col.roads:
        if not real and c == 4 and g.length < URBAN_STREET_MIN_M:
            pts = [g.interpolate(f, normalized=True) for f in (0.1, 0.5, 0.9)]
            cells = [grid.to_cell(p.x, p.y) for p in pts]
            inside = [urban_mask[min(max(int(r), 0), grid.size - 1), min(max(int(q), 0), grid.size - 1)] for q, r in cells]
            if sum(inside) >= 2:
                dropped += 1
                continue
        kept.append((c, g))
    col.roads = kept
    log("  rues de ville omises :", dropped)

    # --- Voies, des petites aux grandes (les grandes passent dessus)
    roads = np.zeros(grid.shape, dtype=np.uint8)
    for code in (5, 4, 6, 3, 2, 1):
        w = ROAD_WIDTH[code]
        geoms = [g for c, g in col.roads if c == code]
        if not geoms:
            continue
        if real:
            rasterize([(g.buffer(REAL_WIDTH_M[code] / 2, cap_style="flat"), code) for g in geoms], grid, roads,
                      all_touched=REAL_WIDTH_M[code] <= grid.cell * 1.5)
            continue
        if w <= 1:
            rasterize([(g, code) for g in geoms], grid, roads, all_touched=True)
        else:
            rasterize([(g.buffer(grid.cell * w / 2, cap_style="flat"), code) for g in geoms], grid, roads)
    roads[sea & (roads != 1) & (roads != 2)] = 0

    # --- Batiments reels (mode reel) : 1 sol, 2 mur, 3 sol de batiment notable
    bld = None
    if real and col.buildings:
        ids = np.zeros(grid.shape, dtype=np.int32)
        features.rasterize(((g, i + 1) for i, g in enumerate(col.buildings)), out=ids, transform=grid.transform)
        bld = np.zeros(grid.shape, dtype=np.uint8)
        inside = ids > 0
        special = np.array([False] + col.building_special)
        bld[inside] = np.where(special[ids[inside]], 3, 1)
        edge = np.zeros(grid.shape, dtype=bool)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nb = np.roll(np.roll(ids, dy, axis=0), dx, axis=1)
            edge |= inside & (nb != ids)
        bld[edge] = 2
        bld[sea] = 0
        log("  batiments reels : %d, cases de mur %d" % (len(col.buildings), int(edge.sum())))

    # --- Altitude finale : lissee (le modele peut inclure arbres et toits)
    e = np.where(np.isfinite(elev), elev, 0).astype(np.float32)
    e = ndimage.gaussian_filter(e, 1.5)
    e[sea] = 0
    elev8 = np.clip(np.round(e), 0, 255).astype(np.uint8)

    # --- Ecriture
    import gzip
    for old in glob.glob(os.path.join(args.out, "*.bin")):
        os.remove(old)
    layers = {"terrain": terrain, "roads": roads, "density": density, "elev": elev8}
    if bld is not None:
        layers["bld"] = bld
    for lname, arr in layers.items():
        with gzip.open(os.path.join(args.out, lname + ".bin.gz"), "wb", compresslevel=9) as f:
            f.write(np.ascontiguousarray(arr).tobytes())
    col.pois.sort(key=lambda p: (-p["area_m2"], p["kind"]))
    json.dump(col.pois, open(os.path.join(args.out, "pois.json"), "w"), ensure_ascii=False, indent=0)
    order = {"city": 0, "town": 1, "suburb": 2, "village": 3, "hamlet": 4, "locality": 5, "isolated_dwelling": 6}
    col.places.sort(key=lambda p: (order.get(p["kind"], 9), -p["population"], p["name"]))
    json.dump(col.places, open(os.path.join(args.out, "places.json"), "w"), ensure_ascii=False, indent=0)
    meta = {
        "name": cfg["name"], "title": cfg.get("title", cfg["name"]),
        "width": grid.size, "height": grid.size,
        "cells_per_km": grid.cells_per_km, "cell_m": grid.cell,
        "crs": "EPSG:2154", "origin_x": grid.x0, "origin_y": grid.y1,
        "mode": "reel" if real else "compresse", "layers": list(layers),
        "terrain_codes": TERRAIN, "road_codes": ROADS,
        "sources": ["OpenStreetMap contributors (ODbL)", elev_src],
        "counts": {
            "terrain": {name: int((terrain == v).sum()) for name, v in TERRAIN.items()},
            "roads": {name: int((roads == v).sum()) for name, v in ROADS.items()},
            "pois": len(col.pois), "places": len(col.places),
        },
    }
    json.dump(meta, open(os.path.join(args.out, "meta.json"), "w"), ensure_ascii=False, indent=1)
    write_preview(terrain, roads, density, e, sea, os.path.join(args.out, "preview.png"), bld)
    log("Termine :", json.dumps(meta["counts"], ensure_ascii=False))


def write_preview(terrain, roads, density, e, sea, path, bld=None):
    from PIL import Image
    lut = np.zeros((256, 3), dtype=np.float32)
    for k, c in PREVIEW_COLORS.items():
        lut[k] = c
    img = lut[terrain]
    # ombrage du relief
    gy, gx = np.gradient(e)
    shade = np.clip(1.0 - (gx - gy) * 0.08, 0.7, 1.25)
    img = img * shade[..., None]
    d = density.astype(np.float32)[..., None] / 255.0
    img = img * (1 - d * 0.8) + np.array([90, 70, 70]) * d * 0.8
    road_col = {1: (230, 120, 60), 2: (240, 200, 90), 3: (230, 230, 200), 4: (205, 200, 190),
                5: (160, 130, 90), 6: (60, 60, 60)}
    for k, c in road_col.items():
        img[roads == k] = c
    if bld is not None:
        img[bld == 1] = (150, 132, 112)
        img[bld == 3] = (170, 150, 120)
        img[bld == 2] = (70, 60, 56)
    img = np.clip(img, 0, 255).astype(np.uint8)
    Image.fromarray(img).save(path, optimize=True)


if __name__ == "__main__":
    main()
