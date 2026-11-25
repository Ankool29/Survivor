# Bâtiments détaillés — murs fins, vraies pièces, formes réelles

Objectif : des bâtiments dont la forme et les dimensions suivent les mesures réelles (contours du cadastre via OpenStreetMap), avec des murs fins, de vraies portes et fenêtres, et des pièces crédibles meublées. C'est aussi la base du réaménagement et de la construction par le joueur : les murs du joueur seront les mêmes.

Statut : **validé et intégré** (précision 1 m, murs abaissés quand on est dedans, étages plus tard).

Ce qui a été fait, et les écarts :
- **Orientation** : la grille est droite, donc chaque bâtiment est tourné sur son propre axe (autour de son centre) ; forme et dimensions sont gardées, seule l'orientation change. Les maisons mitoyennes redressées chacune de leur côté sont recollées (fentes d'un mètre bouchées).
- **Données** : 291 000 bâtiments détaillés sur la zone (emprise au mètre, type, rue la plus proche), dans `tiles/<tx>_<ty>.bld.json.gz`.
- **Plans** : maison, longère, immeuble, commerce, hangar, grange, annexe, bâtiment public, église ; portes extérieures côté rue (et porte de service), portes intérieures, fenêtres, sols par pièce. Fabriqués dans le jeu, toujours les mêmes pour un bâtiment donné.
- **Textures** : sols, murs (enduit, granit, parpaing, bois), portes, fenêtres et toits au mètre dessinés par programme (`tools/sprites/make_interior.py`) ; 35 meubles PixelLab.
- **Meubles** : posés contre les murs en gardant un passage ; ils bloquent le passage ; ceux à fouiller ont leur butin selon le meuble (frigo, armoire, armoire à pharmacie, établi, rayons selon le commerce…).
- **Affichage** : sous un toit intact, les murs intérieurs et les meubles ne sont créés qu'en entrant (beaucoup moins de travail pour le téléphone).
- **Pas encore** : les seuils de porte dehors (remplacés par l'encoche dans le toit au-dessus des portes), le démontage, les étages.

## 1. Ce qui change par rapport à aujourd'hui

| Aujourd'hui | Demain |
| --- | --- |
| Un mur occupe une case entière (2 m d'épaisseur) | Les murs sont posés **sur le bord des cases**, épais d'environ 25 cm à l'écran |
| Formes arrondies à 2 m et angles redressés jusqu'à 25° | Formes au **mètre près** ; seuls les angles presque droits (moins de 5°) sont redressés |
| Une seule grande pièce, meubles contre les murs | **Pièces** selon le type de bâtiment : entrée, cuisine, séjour, chambres, salle de bain, garage… |
| Une brèche sert de porte | **Portes** (qu'on ouvre et ferme) et **fenêtres** sur les murs extérieurs |
| Butin selon le lieu le plus proche | Butin **selon la pièce** : nourriture dans la cuisine, médicaments dans la salle de bain, outils au garage |

## 2. Une grille fine à l'intérieur des bâtiments

- Le monde garde ses cases de 2 m (terrain, routes, végétation : rien ne change dehors).
- **À l'intérieur des bâtiments, chaque case est coupée en 4 cases de 1 m.** Les murs suivent les bords de ces cases d'un mètre : une maison de 9 × 7 m fait exactement 9 × 7 m.
- Les collisions du joueur et des animaux se calculent sur cette grille fine dès qu'on est dans un bâtiment.

## 3. Des formes au plus près du réel

- Le contour OpenStreetMap (souvent issu du cadastre, précis au mètre) est conservé, puis posé sur la grille d'un mètre.
- On garde aussi le type de bâtiment (maison, ferme, immeuble, commerce, hangar, école, église…), le nombre d'étages quand il est connu, et la rue la plus proche (pour l'entrée).

## 4. Les pièces, inventées mais crédibles

Chaque bâtiment reçoit un plan tiré de son type et de sa taille, toujours le même pour un bâtiment donné :

| Type | Plan type |
| --- | --- |
| Maison, pavillon | Entrée côté rue, séjour et cuisine (partie jour), couloir, chambres, salle de bain et WC (partie nuit), parfois garage accolé |
| Longère, ferme | Pièces en enfilade avec chacune sa porte sur la cour, grande cheminée, étable ou grange au bout |
| Immeuble | Hall et cage d'escalier, appartements (même découpage qu'une maison, en plus petit) |
| Commerce | Salle de vente côté rue, réserve et petit bureau au fond |
| Hangar, atelier | Grand volume ouvert, un bureau ou un vestiaire dans un coin |
| École, mairie | Couloir central, salles de part et d'autre, sanitaires |
| Église, chapelle | Nef, chœur, sacristie |

Méthode : on découpe la surface en zones (jour, nuit, service) puis en pièces, avec des tailles minimales réalistes (une chambre fait au moins 9 m², un couloir 1 m de large). Si la forme ne s'y prête pas, on simplifie (studio, pièce unique).

## 5. Portes, fenêtres, sols

- **Portes** : entrée principale côté rue, porte de service à l'arrière ou sur la cour ; portes intérieures entre les pièces. Action « Ouvrir / Fermer » ; une porte fermée bloque les animaux.
- **Fenêtres** : tous les 3 à 4 m sur les murs extérieurs ; elles laissent voir dehors et plus tard se barricadent.
- **Sols** : parquet (séjour, chambres), carrelage (cuisine, salle de bain), béton (garage, hangar), terre battue ou pavés (étable).
- **Murs** : enduit clair ou granit pour les maisons bretonnes, parpaing pour les hangars, bardage bois pour les annexes.

## 6. Voir à l'intérieur (vue 3/4)

- Les murs ont une hauteur à l'écran, comme aujourd'hui. Quand on entre, le toit disparaît **et les murs situés devant le joueur (au sud) s'abaissent** à hauteur de plinthe, pour voir dans les pièces. On voit la pièce où l'on est et les pièces voisines.
- Dehors, les bâtiments restent fermés avec leur toit.

## 7. Meubles et butin par pièce

| Pièce | Meubles | Butin probable |
| --- | --- | --- |
| Cuisine | Évier, cuisinière, frigo, placards, table | Conserves, bouteilles, couteau, allumettes |
| Séjour | Canapé, table basse, buffet, cheminée ou poêle | Bougies, livres, couvertures |
| Chambre | Lit, armoire, commode | Vêtements, sac, couvertures |
| Salle de bain | Baignoire ou douche, lavabo, armoire à pharmacie | Bandages, médicaments |
| Garage, atelier | Établi, étagères, voiture parfois | Outils, corde, bidon, clous |
| Réserve | Étagères | Selon le commerce |

Les états actuels restent : la plupart des bâtiments intacts, quelques-uns au toit effondré (pièces envahies de végétation), quelques ruines.

## 8. Étapes de réalisation

1. **Données** : garder les contours réels, le type et les étages dans les tuiles de la carte (nouvelle génération sur GitHub).
2. **Grille fine** : murs sur les bords, collisions, portes qui s'ouvrent.
3. **Plans** : découpage en pièces, portes, fenêtres, sols.
4. **Affichage** : murs fins en vue 3/4, murs abaissés quand on est dedans, toits.
5. **Meubles et butin** par pièce.
6. **Sprites** PixelLab : jeux de murs (4 matières), portes, fenêtres, 5 sols, une trentaine de meubles — environ **100 générations** (on resterait vers 620 sur 2 000).

Les étages ne viennent pas encore : un escalier est dessiné mais fermé.

## Retouches (intérieurs façon Project Zomboid)

- Aménagement par type de pièce : meubles adossés aux murs, rangée cuisine continue, table entourée de chaises, cases devant les portes laissées libres.
- Une pièce coupée en morceaux séparés est scindée ; les miettes rejoignent leur voisine (sinon la pièce restait vide).
- En entrant, le toit d'un voisin accolé qui déborde sur notre bâtiment est aussi masqué.
