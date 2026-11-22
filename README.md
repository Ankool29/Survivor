# Survivor (titre provisoire)

Jeu de survie en monde ouvert, en pixel art vu de dessus, dans une France réelle
rendue à la nature 30 ans après une pandémie. Godot 4, jouable sur mobile.

- Concept : [Concept — Survie post-apo en France](https://claude.ai/artifact/P5sUvAzE4xM9eoHhxtnWb5)
- Étape 1 (terminée) : [docs/ETAPE1.md](docs/ETAPE1.md) — monde à l'échelle réelle autour de Quimperlé
- Étape 2 (en test) : [docs/ETAPE2.md](docs/ETAPE2.md) — survie de base

## Organisation

| Dossier | Contenu |
| --- | --- |
| `game/` | Projet Godot (ouvrir `game/project.godot`) |
| `game/data/zones/` | Zones générées depuis OpenStreetMap et l'IGN (ne pas modifier à la main) |
| `tools/zone/` | Outil de fabrication des zones et journaux |
| `.github/workflows/` | Fabrication automatique des zones par GitHub Actions |
| `docs/` | Cahiers d'étape et de sprites |

## Tester sur le téléphone (Termux + éditeur Godot Android)

Première fois, dans Termux :

```
git clone https://github.com/Ankool29/Survivor ~/survivor
echo "alias majsv='cd ~/survivor && git pull && rsync -a --delete --exclude .godot ~/survivor/game/ /storage/emulated/0/Godot/survivor/'" >> ~/.bashrc
source ~/.bashrc
majsv
```

Ensuite, à chaque mise à jour : `majsv`, puis ouvrir le projet `Godot/survivor` dans l'éditeur.
Le projet vise Godot 4.7.

## Données

Cartographie © les contributeurs d'OpenStreetMap, sous licence ODbL.
Relief : IGN RGE ALTI (Licence Ouverte Etalab 2.0), ou Copernicus DEM GLO-30 à défaut.
