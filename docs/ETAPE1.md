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

- **Morceaux** de 32 × 32 cases, fabriqués sur un autre cœur du processeur (un à la fois), puis posés en environ 1 ms ; déchargés au-delà de la vue.
- **Fabrication déterministe** : chaque case donne toujours le même résultat (variante de sol, arbre, ruine), calculé à partir de ses coordonnées et de la graine de la partie.
- **30 ans d'abandon** : champs devenus friches et broussailles, routes fissurées et envahies, ponts parfois effondrés, quartiers en ruine.
- **Villes stylisées** : les grandes rues réelles sont tracées (les petites rues de moins de 500 m sont omises en ville, faute de place à cette échelle), et les îlots entre elles sont remplis de bâtiments à taille humaine, plus serrés là où la densité réelle est forte. Les grands bâtiments réels (supermarché, église, hôpital) sont placés à leur emplacement.
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
- [ ] La pose d'un morceau prend moins de 8 ms (mesuré : environ 1 ms sur ordinateur ; la fabrication, 10 à 30 ms, se fait en arrière-plan).
- [ ] La carte et le nom du lieu permettent de s'orienter.

## Essai à l'échelle réelle (novembre 2026)

Zone `quimperle_reel` : Quimperlé sur 5 × 5 km, **1 case = 2 m** (500 cases par km).

- Vrais bâtiments d'OpenStreetMap : chaque bâtiment est tracé à sa place, avec ses murs (environ 7 % de brèches) et son sol de ruine ; sol carrelé pour les bâtiments notables.
- Vraies largeurs de voies (voie rapide 14 m, rue 5 m, sentier 2,5 m), sentiers et voies de service inclus, aucune rue omise.
- Décor environ 4,5 fois moins dense par case, ponts effondrés par blocs de 64 m.
- Vitesse de marche : environ 5 m/s (2,5 cases par seconde).
- Données compressées (gzip) : environ 1,2 Mo pour la zone.
- Bouton « Changer de carte » pour passer d'une zone à l'autre.

Retour après essai : nettement mieux qu'à l'échelle compressée, mais trop en ruine (voir `A_CORRIGER.md`, n° 10).

À décider : passer toute la carte à l'échelle réelle (et le découpage des données en paquets que cela demande), garder les deux, ou une échelle intermédiaire.
