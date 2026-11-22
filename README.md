# Survivor (titre provisoire)

Jeu de survie en monde ouvert, en pixel art vu de dessus, dans une France réelle
rendue à la nature 30 ans après une pandémie. Godot 4, jouable sur mobile.

- Concept : [Concept — Survie post-apo en France](https://claude.ai/artifact/P5sUvAzE4xM9eoHhxtnWb5)
- Étape en cours : [docs/ETAPE1.md](docs/ETAPE1.md) — monde test autour de Quimperlé

## Organisation

| Dossier | Contenu |
| --- | --- |
| `game/` | Projet Godot (ouvrir `game/project.godot`) |
| `game/data/zones/` | Zones générées depuis OpenStreetMap et l'IGN (ne pas modifier à la main) |
| `tools/zone/` | Outil de fabrication des zones et journaux |
| `.github/workflows/` | Fabrication automatique des zones par GitHub Actions |
| `docs/` | Cahiers d'étape et de sprites |

## Données

Cartographie © les contributeurs d'OpenStreetMap, sous licence ODbL.
Relief : IGN RGE ALTI (Licence Ouverte Etalab 2.0), ou Copernicus DEM GLO-30 à défaut.
