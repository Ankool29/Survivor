# Étape 3 — Faune et chasse

Objectif : peupler le monde. Trente ans sans humains ont laissé la nature reprendre : le gibier abonde, les prédateurs sont revenus, et les chiens retournés à l'état sauvage chassent en meute. Le joueur chasse pour manger et se vêtir, et apprend à éviter ce qui peut le tuer.

Statut : **proposition, à valider**. Les chiffres sont des valeurs de départ, à régler en jouant.

## 1. Les animaux du prototype

| Animal | Milieu | Comportement | Ce qu'il donne |
| --- | --- | --- | --- |
| Lapin | Prairies, friches, lisières | Fuit très vite à 6 cases ; se terre la nuit | Petite viande, peau de lapin |
| Chevreuil | Bois, lisières, champs à l'aube et au crépuscule | Fuit à 12 cases, en bonds ; en petits groupes | 4 viandes, peau, os, tendons |
| Sanglier | Bois de feuillus, maïs et champs abandonnés | Fuit en général ; charge si on l'approche à moins de 4 cases ou s'il est blessé | 6 viandes, peau épaisse, défenses, graisse |
| Renard | Partout, surtout près des villages | Discret, fuit ; rôde la nuit autour des camps | Peau de renard, petite viande |
| Chien sauvage | Villes, zones industrielles, périphéries | En meute de 3 à 6 ; suit le joueur à distance, attaque s'il est blessé, seul la nuit ou s'il fuit | 2 viandes, peau |
| Loup | Grands bois, la nuit surtout (rares) | En meute ; évite le joueur le jour, dangereux la nuit et en hiver | 3 viandes, peau de loup |
| Corbeaux, mouettes | Ciel, littoral, décharges | Décor vivant : s'envolent quand on approche, tournent au-dessus des carcasses | — |
| Poissons | Rivières (Laïta, Ellé, Isole), étangs | Invisibles ; pêche à la ligne ou au piège | Poisson |

Les loups sont plausibles : ils recolonisent déjà la Bretagne aujourd'hui, et trente ans sans chasse ni routes leur laissent le champ libre.

## 2. Comment le monde est peuplé

- **Pas de simulation de chaque bête sur 50 km.** Chaque zone de 64 × 64 cases porte des effectifs par espèce, selon son milieu (bois, prairie, ville…), qui se reconstituent avec le temps.
- Autour du joueur (environ 40 cases, un peu plus que l'écran), les bêtes de ces effectifs apparaissent hors de vue et vivent vraiment : elles broutent, se déplacent, dorment, fuient. Celles qui s'éloignent trop retournent dans les effectifs de leur zone.
- Ce qu'on tue est retiré des effectifs : vider un bois de ses chevreuils a un effet pendant plusieurs jours de jeu.
- Activité selon l'heure : chevreuils à l'aube et au crépuscule, sangliers et renards la nuit, lapins le jour près des terriers.

## 3. Sens et discrétion

- Chaque animal voit (cône devant lui), entend (le joueur qui court s'entend deux fois plus loin) et sent (sous le vent, il détecte le joueur deux fois plus loin). Le vent change avec la météo et s'affiche dans le coin.
- **S'accroupir** (nouveau bouton) : avance lentement, divise par deux la distance à laquelle on est repéré. Hautes herbes, landes et sous-bois cachent davantage.
- **Traces** : en zoomant de près, empreintes et crottes près des passages, pour savoir ce qui vit là.

## 4. Chasser

| Moyen | Fabrication | Usage |
| --- | --- | --- |
| Lance (existe) | 2 branches, 1 corde, couteau | Corps à corps ; peut être lancée (portée 6 cases), à ramasser ensuite |
| Arc et flèches | Arc : 1 branche souple, 1 tendon ou corde, couteau ; flèches : branche, silex, plumes | Portée 15 cases ; viser en maintenant le bouton, relâcher pour tirer |
| Collet | 1 corde | Posé sur un passage de lapins ; à relever (peut attraper un renard) |
| Nasse | 4 branches, 2 cordes | Posée dans l'eau ; donne des poissons au fil du temps |
| Ligne de pêche | Fibre, os (hameçon) | Près de l'eau : action « Pêcher », quelques minutes de jeu |

- Une bête touchée mais pas tuée fuit en laissant une piste de sang à suivre.
- **Dépecer** une carcasse prend du temps (couteau obligatoire) ; elle attire les charognards (corbeaux, renards, chiens) si on la laisse.

## 5. Se défendre

- Les attaques font perdre de la santé et peuvent provoquer un **saignement** (la santé baisse jusqu'à un bandage).
- Frapper avec la lance ou la hache ; un feu allumé tient les bêtes à distance la nuit ; un abri fermé (à faire plus tard) protège en dormant.
- Les animaux sont dessinés **au-dessus des herbes mais sous les toits**, et la nuit on devine leurs yeux à la lumière d'une torche.

## 6. Ce que ça apporte au reste

| Nouveaux objets | Usage |
| --- | --- |
| Viande crue (petite, grande), poisson cru | À cuire au feu (crue : risque de maladie) |
| Peaux (lapin, renard, chevreuil, sanglier, loup) | Vêtements chauds (étape suivante : séchage et tannage) |
| Os, tendons, graisse, plumes, défenses | Hameçons, cordes d'arc, flèches, torches qui durent plus longtemps |
| Viande séchée | Feu + 3 viandes crues + sel ou fumée ; se conserve longtemps |

La viande crue se gâte en 2 jours de jeu ; cuite, en 4 ; séchée, elle se garde.

## 7. Sprites (PixelLab)

- 7 animaux en personnages 4 directions (lapin, chevreuil, sanglier, renard, chien, loup, corbeau), avec marche, course, et pour certains attaque ou mort.
- Carcasses, collet, nasse, arc, flèches, traces, nouvelles icônes d'objets.
- Estimation : **environ 120 générations** ; on resterait vers 490 sur 2 000, loin de la limite de 1 600.

## 8. Questions ouvertes

1. Loups et chiens sauvages dès le départ, ou seulement le chien sauvage au début (le loup plus tard, plus rare) ?
2. Arc dès cette étape, ou seulement la lance, les pièges et la pêche (l'arc à l'étape suivante) ?
3. Le joueur s'accroupit avec un bouton, ou en marchant lentement (petit déplacement du joystick) ?
