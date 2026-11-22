# Étape 3 — Faune et chasse

Objectif : peupler le monde. Trente ans sans humains ont laissé la nature reprendre : le gibier abonde, les prédateurs sont revenus, et les chiens retournés à l'état sauvage chassent en meute. Le joueur chasse pour manger et se vêtir, et apprend à éviter ce qui peut le tuer.

Statut : **validé, en cours**. Les chiffres sont des valeurs de départ, à régler en jouant.

Choix retenus : chiens sauvages et loups dès le départ, arc dès cette étape, bouton « S'accroupir ».

Intégré (novembre 2026) :
- 6 animaux animés (lapin, chevreuil, sanglier, renard, chien sauvage, loup), qui apparaissent hors de l'écran selon le terrain et l'heure, et disparaissent quand on s'éloigne ; ce qu'on tue manque quelques jours ;
- sens : vue (moins dans le dos et la nuit), bruit (course, accroupi), odeur selon le vent, affiché en haut à droite ; couvert des hautes herbes et des bois ;
- **arc** : maintenir « Tirer » pour viser (la visée s'accroche à l'animal le plus proche dans l'axe, en anticipant sa course), relâcher pour tirer ; une bête touchée saigne et laisse une piste de sang ; les flèches ratées restent souvent au sol, celles plantées se récupèrent en dépeçant ;
- corps à corps avec la meilleure arme du sac (lance, hache, couteau, poings) ; chiens et loups tournent autour du joueur et attaquent surtout la nuit, s'il fuit, s'il est blessé ; deux bêtes mordent à la fois ; un feu les tient à distance, une torche aussi la nuit ;
- morsures : perte de santé, parfois **saignement** (arrêté par un bandage) ;
- dépecer au couteau ; carcasses qui attirent chiens, renards et loups, et pourrissent en 2 jours ;
- collets (lapins, parfois un renard), nasses posées dans l'eau, ligne de pêche ;
- cuisson au feu (griller, cuire) et viande **fumée** qui se garde ; viande et poisson crus se gâtent.

Écarts avec la proposition :
- la lance ne se lance pas (corps à corps seulement) ;
- pas encore de corbeaux, d'empreintes, ni d'yeux qui brillent la nuit ;
- pas de plumes : les flèches se font avec 2 branches et 1 silex (4 flèches) ; l'arc avec 2 branches et 2 cordes (les tendons donnent de la corde) ;
- près de l'eau, le bouton propose « Pêcher » si on a une ligne et qu'on n'a pas soif, sinon « Boire » ;
- commandes clavier : C pour s'accroupir, F maintenu pour viser.

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
