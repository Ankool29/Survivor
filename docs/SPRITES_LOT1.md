# Lot de sprites 1 — Monde test (PixelLab)

But : remplacer les graphismes provisoires de l'étape 1. Rien d'autre (pas d'animaux,
pas d'objets d'inventaire, pas d'intérieurs détaillés : ce sera pour les lots suivants).

## Direction artistique

- Pixel art, vue de dessus en 3/4 (style Stardew Valley, plus terne et plus sauvage).
- Tuiles de 32 × 32 px ; objets hauts (arbres, murs) en 32 × 64 px, posés sur le bas de la case.
- Lumière venant du nord-ouest, ombres portées vers le sud-est.
- Palette commune, fixée par le premier tileset validé (herbe haute ↔ friche) puis réutilisée comme référence.
- Ambiance : Bretagne 30 ans après l'abandon. Végétation dense, béton gris-vert, rouille, aucune trace de vie humaine récente.

## Contenu

| # | Élément | Forme | Générations (estimation) |
| --- | --- | --- | --- |
| 1 | Transitions de sol : herbe haute ↔ friche, eau douce, mer, sable, chemin de terre, asphalte, béton, sol de forêt (feuillus), sol de forêt (résineux), lande, marais | 11 tilesets à transitions (16 tuiles chacun) | 11 |
| 2 | Sols simples : voie ferrée, pont, carrelage, sol de bâtiment, roche | 5 tuiles avec 4 variantes | 5 |
| 3 | Arbres : chêne, hêtre, pin maritime, sapin, jeune bouleau | 5 objets 32 × 64 | 5 |
| 4 | Petite végétation : buisson, ronces, ajonc en fleur, roseaux | 4 objets | 4 |
| 5 | Divers : rocher, épave de voiture, gravats, tombe, poteau électrique | 5 objets | 5 |
| 6 | Ruines : mur, angle, mur brisé, ouverture, pan effondré | kit de 5 pièces | 5 |
| 7 | Joueur : survivant (veste, sac à dos), 4 directions | 1 personnage | 1 |
| 8 | Animations du joueur : repos, marche, course | 3 animations | 3 |
| | **Total** | | **environ 39** |

## Ordre de production

1. Tileset herbe haute ↔ friche : sert de test de style et fixe la palette. **Validation avant la suite.**
2. Le joueur et sa marche : valident l'échelle personnage / décor.
3. Le reste par familles (sols, arbres, ruines), chacune intégrée et montrée avant la suivante.

## Intégration

- Les tilesets à transitions viennent de l'outil « Create tileset » de PixelLab (1 génération
  en version standard), exportés au format « dual-grid 15 tuiles ». Le sol sera alors dessiné
  sur une grille décalée d'une demi-case (« grille double »), chaque tuile choisie selon les
  4 coins. Ce changement de rendu sera fait à la réception du premier tileset.
- Les autres planches gardent la disposition de `game/scripts/world/tiles.gd`
  (`assets/tiles/ground.png`, `assets/tiles/decor.png`) : aucun changement de code.
- Règle reprise d'EXODE : défaut grave corrigé avant intégration, défaut mineur intégré
  et noté dans `docs/A_CORRIGER.md`.

## Avancement

| Élément | Statut | Notes |
| --- | --- | --- |
| Style de référence | validé | Mode pro, vue 3/4 basse, palette « Bretagne abandonnée » (25 couleurs), herbe de référence commune |
| 11 transitions de sol | intégrées | friche, lande, feuillus, résineux, marais, chemin, sable, béton, asphalte (2e version), eau (2e version), mer |
| Joueur | intégré | 4 directions, repos (4 images), marche (6), course (6) ; 13 générations |
| Arbres et végétation, objets divers | intégrés | 32 objets en 2 planches de 16 (outil « objet 1 direction ») ; 25 générations |
| Murs de ruines, sols de bâtiments, ballast, ponts | intégrés | mur en relief (25 tuiles, coins à 3 états : herbe, dessus, face), sol de ruine, ballast ; ponts = dalle de béton ; 45 générations |

Les réponses brutes de PixelLab sont gardées dans `tools/sprites/raw/` ; `tools/sprites/import_wang.py`
les convertit en planches pour le jeu (`game/assets/tiles/`).

# Lot de sprites 2 — Survie de base

| Élément | Statut | Notes |
| --- | --- | --- |
| 34 icônes d'objets (32 × 32) | intégrées | une planche de l'outil « objet 1 direction » |
| 16 meubles et constructions (feu éteint et allumé, abri, coffre, armoire, frigo, rayon, établi, lit…) | intégrés | une planche de 16 |
| Animations du joueur : ramasser, frapper, boire (4 directions) | intégrées | animations personnalisées, 1 génération par direction |
| Dormir | abandonné | l'animation générée ne couchait pas le personnage |

Coût du lot 2 : environ 35 générations. Total depuis le début : environ 350 sur 2 000.
