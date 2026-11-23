# Étape 4 — Vêtements et équipement

Objectif : rendre l'hiver survivable et donner un usage aux peaux. Le joueur s'habille avec ce qu'il trouve, puis fabrique ses propres vêtements de peau et de fourrure. Chaque pièce compte contre le froid, la pluie et les blessures.

Statut : **validé et intégré**. Les chiffres sont des valeurs de départ, à régler en jouant.

Choix retenus : le personnage change d'apparence selon le vêtement de torse (4 tenues : civile, ciré, cuir, fourrure) ; la charge se compte en cases et en poids.

Écarts avec la proposition :
- 7 emplacements : le carquois a le sien (ceinture) ; porté, il fait tenir 60 flèches dans une seule case ;
- départ habillé : veste de travail, pantalon de travail, chaussures de rando et sac de courses, déjà usés ;
- tendre une peau se fait d'un coup (grattage compris) sur le cadre de séchage ; les cendres se ramassent dans un feu éteint (une poignée par heure de feu) ;
- sans sac : 12 cases et 25 kg (sac de courses +6, sac à dos +15, sac en cuir +22, sac de rando +30) ; au-delà, on ralentit un peu (jusqu’à 40 % à double charge) et on se fatigue plus ; à plus de 150 %, on ne peut plus courir ; les vêtements portés comptent peu ;
- « Jeter » pose désormais l'objet par terre, où on peut le reprendre ;
- le ciré a une capuche : il protège aussi la tête de la pluie ; des gants évitent les égratignures des ronces.

## 1. L'équipement porté

Six emplacements, affichés dans un nouvel onglet « Équipement » du sac (silhouette avec une case par emplacement) :

| Emplacement | Exemples trouvés | Exemples fabriqués |
| --- | --- | --- |
| Tête | Bonnet, casquette, capuche | Bonnet de fourrure |
| Torse | Tee-shirt, pull, ciré, veste, doudoune | Gilet de peau, manteau de fourrure |
| Jambes | Jean, pantalon de travail, pantalon de pluie | Pantalon de peau |
| Pieds | Baskets, bottes en caoutchouc, chaussures de rando | Mocassins, bottes fourrées |
| Mains | Gants de jardin, gants de laine | Moufles de fourrure |
| Dos | Sac de courses, sac à dos, sac de rando | Sac en cuir, carquois |

Le pull et le manteau actuels deviennent des pièces de torse. Le personnage garde la même apparence quels que soient ses vêtements (un sprite par tenue coûterait trop de générations PixelLab) : seules les icônes changent.

## 2. Ce que fait chaque pièce

| Valeur | Effet |
| --- | --- |
| Chaleur | Degrés ajoutés à la température ressentie (la somme de tout ce qu'on porte) |
| Imperméabilité | Part de la pluie arrêtée : un ciré protège, un pull se gorge d'eau |
| Protection | Réduit les dégâts des morsures et des coups, et le risque de saignement |
| Bruit | Un ciré ou une doudoune s'entendent : les animaux repèrent le joueur de plus loin |
| Usure | Chaque pièce s'use (pluie, ronces, morsures) et finit déchirée ; on la répare |

Exemples : doudoune +9 °C mais bruyante et vite trempée ; ciré breton +2 °C mais imperméable ; manteau de loup +10 °C, protection moyenne, silencieux.

## 3. Mouillé et sécher

- Une jauge « mouillé » monte sous la pluie (selon l'imperméabilité), en traversant un gué ou en tombant à l'eau.
- Mouillé, un vêtement perd jusqu'aux deux tiers de sa chaleur : la pluie froide de novembre devient le vrai danger de l'hiver breton.
- On sèche près d'un feu (vite) ou sous un toit (lentement).

## 4. Travailler les peaux

| Étape | Ce qu'il faut | Temps |
| --- | --- | --- |
| Gratter la peau | Peau fraîche, couteau ou grattoir en os | 20 min |
| Faire sécher | Un cadre de séchage (4 branches, 1 corde), posé au camp | 1 jour |
| Tanner | Peau sèche, graisse, cendres d'un feu | 2 jours au cadre |
| Résultat | **Cuir** (chevreuil, sanglier, chien) ou **fourrure** (lapin, renard, loup) | — |

- Une peau oubliée fraîche dans le sac pourrit en 3 jours, comme la viande.
- **Couture** : aiguille en os (os + couteau) et fil de tendon ou de fibres. Un nécessaire de couture se trouve aussi dans les maisons.
- **Réparer** : un bout de tissu, de cuir ou de fourrure et l'aiguille remettent une pièce en état.

Recettes de départ : bonnet de fourrure (2 fourrures de lapin), moufles (2 lapin), gilet de peau (2 cuirs), manteau de fourrure (2 fourrures de renard ou 1 de loup + 1 cuir), pantalon de peau (2 cuirs), mocassins (1 cuir), bottes fourrées (1 cuir + 1 fourrure), sac en cuir (3 cuirs, 2 cordes), carquois (1 cuir : les flèches ne prennent plus de place dans le sac).

## 5. Le sac

- Le sac porté décide du nombre de cases : sans sac 12, sac de courses 16, sac à dos 20, sac de rando 28, sac en cuir 24.
- Les vêtements portés ne prennent pas de place dans le sac.
- Changer de sac vide l'ancien dans le nouveau ; ce qui ne rentre pas tombe au sol.

## 6. Trouver des vêtements

Le butin des maisons gagne des armoires et commodes à vêtements, et les magasins de vêtements ou de sport (repérés sur la carte) deviennent des lieux intéressants. Les vêtements trouvés sont souvent usés.

## 7. Au passage : une faune plus farouche

Comme demandé, les animaux deviennent plus craintifs et plus durs à chasser : distances de repérage augmentées, chiens et loups qui suivent de loin et n'attaquent que si le joueur est blessé, acculé la nuit ou en plein hiver, sanglier qui ne charge que surpris de près ou blessé.

## 8. Sprites (PixelLab)

- Environ 35 icônes (vêtements trouvés et fabriqués, cuir, fourrures, aiguille, grattoir, nécessaire de couture) en une planche de 64.
- Cadre de séchage, vide et avec une peau, en décor.
- Estimation : **une quinzaine de générations** ; on resterait vers 455 sur 2 000.
