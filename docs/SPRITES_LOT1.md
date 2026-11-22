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

- Les tilesets à transitions demandent un petit changement de rendu : le sol sera dessiné
  sur une grille décalée d'une demi-case (« grille double »), chaque tuile choisie selon les
  4 coins. C'est prévu dans le code dès la réception du premier tileset.
- Les autres planches gardent la disposition de `game/scripts/world/tiles.gd`
  (`assets/tiles/ground.png`, `assets/tiles/decor.png`) : aucun changement de code.
- Règle reprise d'EXODE : défaut grave corrigé avant intégration, défaut mineur intégré
  et noté dans `docs/A_CORRIGER.md`.
