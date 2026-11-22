# Bâtiments intacts et toits

Objectif : des bâtiments quasiment intacts après 30 ans, où la végétation reprend légèrement le dessus ; on voit les toits de l'extérieur, et le toit du bâtiment où l'on entre disparaît pour montrer l'intérieur.

Statut : **validé et intégré** (toits en tuiles pleines à bords droits, relevés de 22 px).

## 1. Toits

- Chaque bâtiment a un toit qui couvre ses murs et son intérieur.
- Le toit est dessiné **décalé vers le haut** d'environ un mètre (vue 3/4) : on voit le mur du bas sous le toit, avec sa porte s'il en a une.
- Deux matériaux, choisis selon le bâtiment :
  - **ardoise** (maisons, la grande majorité en Bretagne) ;
  - **tôle** (hangars, ateliers, supermarchés, bâtiments notables et zones industrielles).
- Mousse et lichen sur les toits, dessinés dans les sprites.

## 2. Entrer dans un bâtiment

- Quand le joueur passe la porte, le toit de **ce** bâtiment disparaît (les maisons mitoyennes gardent le leur).
- Il réapparaît quand il ressort.
- Le joueur reste dessous le toit des autres bâtiments s'il passe derrière (le toit le cache).

## 3. État des bâtiments

| État | Part | Effet |
| --- | --- | --- |
| Intact | environ 85 % | Toit entier, murs continus, une porte. À l'intérieur : à l'abri de la pluie, +4 °C ressentis |
| Toit effondré | environ 10 % | Pas de toit, gravats et un jeune arbre à l'intérieur ; la pluie y mouille |
| Ruine | environ 5 % | Pas de toit, deux ou trois brèches dans les murs |

Le choix est fait par bâtiment, à la fabrication de la carte (toujours le même pour une même carte).

## 4. Végétation

- **Lierre** sur une partie des murs extérieurs (environ un mur sur cinq).
- Herbes et petits buissons le long des façades et dans les cours, comme aujourd'hui.

## 5. Données de carte

Le code de chaque case de bâtiment garde son sens (sol, mur, sol notable, porte) et reçoit en plus l'état du bâtiment et son type de toit. Régénération de la carte nécessaire (environ 20 minutes sur GitHub).

## 6. Sprites (PixelLab)

| Élément | Forme | Générations (estimation) |
| --- | --- | --- |
| Toit d'ardoise | jeu de tuiles à transitions, mode pro | 15 |
| Toit de tôle | jeu de tuiles à transitions, mode pro | 15 |
| Lierre sur mur (3 variantes), mousse, herbes de façade | une planche d'objets | 10 à 25 |
| **Total** | | **40 à 55** (environ 330 utilisées sur 2 000 aujourd'hui) |

## Validation

- [ ] Les rues de Quimperlé se lisent comme une ville : toits, façades, portes.
- [ ] Entrer et sortir d'une maison fait disparaître et réapparaître son toit, sans saccade.
- [ ] Les bâtiments effondrés et les ruines restent rares mais visibles.
- [ ] La pluie ne mouille pas sous un toit intact.
