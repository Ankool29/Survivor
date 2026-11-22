# Étape 1 — Monde test : le pays de Quimperlé

Objectif : marcher librement dans une zone de 50 × 50 km autour de Quimperlé,
fabriquée à partir des vraies données, de façon fluide sur un Samsung Galaxy S25 Ultra.

Concept général : [Concept — Survie post-apo en France](https://claude.ai/artifact/P5sUvAzE4xM9eoHhxtnWb5).

## Décisions qui s'appliquent

| Sujet | Choix |
| --- | --- |
| Vue | De dessus en 3/4, tuiles de 32 × 32 px |
| Échelle | 32 cases par km (une case ≈ 31 m réels, lue comme 1 à 2 m) |
| Zone | 50 × 50 km centrés sur Quimperlé, soit 1 600 × 1 600 cases |
| Époque | 30 ans après la pandémie |
| Mort | Définitive ; nouvelle partie, départ tiré au hasard |
| Moteur | Godot 4.5, GDScript |

## 1. Données de la zone

L'atelier de Claude n'a pas accès aux sites de données. Le travail est donc fait
par GitHub Actions (`.github/workflows/zone.yml`), qui :

1. télécharge l'extrait OpenStreetMap de la Bretagne (Geofabrik) et le découpe à la zone ;
2. télécharge le relief IGN RGE ALTI (service WMS de la Géoplateforme), ou Copernicus DEM à défaut ;
3. lance `tools/zone/build_zone.py`, qui produit `game/data/zones/quimperle/` ;
4. enregistre le résultat et son journal dans le dépôt.

Le workflow se relance seul quand `tools/zone/` change.

Format produit (une valeur d'un octet par case, ligne 0 au nord) :

| Fichier | Contenu |
| --- | --- |
| `terrain.bin` | Type de sol : mer, eau, sable, prairie, champ, 3 forêts, lande, marais, urbain, industriel, roche, cimetière, parc |
| `roads.bin` | Voie : voie rapide (4 cases de large), principale (3), secondaire (2), rue (2), chemin (1), rail (1) |
| `density.bin` | Part de la case couverte de bâtiments réels (0-255) |
| `elev.bin` | Altitude en mètres (0-255) |
| `pois.json` | Lieux notables : hôpital, supermarché, église, gare, château d'eau… |
| `places.json` | Noms des villes, bourgs et hameaux |
| `meta.json` | Échelle, origine Lambert-93, codes, sources à citer |

Mentions obligatoires : « © les contributeurs d'OpenStreetMap (ODbL) » et « IGN » (ou Copernicus).

## 2. Monde en jeu

- **Morceaux** de 32 × 32 cases, chargés autour du joueur (un par image au plus pour éviter les saccades), déchargés au-delà.
- **Fabrication déterministe** : chaque case donne toujours le même résultat (variante de sol, arbre, ruine), calculé à partir de ses coordonnées et de la graine de la partie.
- **30 ans d'abandon** : champs devenus friches et broussailles, routes fissurées et envahies, ponts parfois effondrés, quartiers en ruine.
- **Villes stylisées** : les rues réelles sont tracées, et les îlots entre elles sont remplis de bâtiments à taille humaine, plus serrés là où la densité réelle est forte. Les grands bâtiments réels (supermarché, église, hôpital) sont placés à leur emplacement.
- **Relief** : ombrage doux des pentes, calculé à partir de l'altitude.
- **Collisions** : mer, eau profonde et murs bloquent ; marais et broussailles ralentissent.

## 3. Joueur et interface

- Joystick virtuel à gauche, clavier (ZQSD / flèches) pour tester sur ordinateur.
- Vitesse : 4 cases par seconde à pied.
- Zoom par pincement (×1 à ×4).
- Bouton Carte : toute la zone en aperçu, position du joueur (en étape 1, la carte est entièrement visible pour tester).
- Bandeau : nom du lieu le plus proche (« Près de Quimperlé »).
- Départ tiré au hasard sur la terre ferme ; bouton « Nouveau départ ».

## 4. Graphismes

Graphismes provisoires générés par le jeu (couleurs et motifs), remplacés par le
lot de sprites 1 de PixelLab (`docs/SPRITES_LOT1.md`). Les numéros de tuiles sont
fixés dans `game/scripts/world/tiles.gd` pour que le remplacement ne touche pas au code.

## Validation de l'étape

- [ ] La zone générée ressemble au pays de Quimperlé (Laïta, forêt de Carnoët, Lorient, la côte).
- [ ] Marcher et traverser une ville ne saccade pas sur le S25 Ultra.
- [ ] Le chargement d'un morceau prend moins de 8 ms.
- [ ] La carte et le nom du lieu permettent de s'orienter.
