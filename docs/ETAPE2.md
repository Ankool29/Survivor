# Étape 2 — Survie de base

Objectif : donner une raison à chaque sortie. Le joueur doit boire, manger, dormir et se protéger du froid ; il ramasse, fabrique ses premiers outils, fouille les maisons et installe un premier camp.

Statut : **validé et intégré** (novembre 2026). Les chiffres sont des valeurs de départ, à régler en jouant.

Choix retenus : départ en début d'automne, vitesses des besoins du cahier, départ les mains vides (16 cases de sac).

Écarts avec la proposition :
- la gourde est une **bouteille en plastique** trouvée dans les maisons (vide, eau non traitée, eau bouillie) ;
- le froid est plus doux que prévu (seuil de confort à 10 °C ressentis), sinon on mourait en quelques minutes sous la pluie ;
- dormir : le personnage est couché en faisant pivoter le sprite au repos (l'animation générée n'était pas réussie) ;
- les icônes d'interface (jauges, météo) ne sont pas faites : jauges en couleurs avec leur nom ;
- on fouille les **meubles** (armoire, frigo, rayon, établi…) placés contre les murs des vrais bâtiments, et les épaves de voitures ;
- commandes clavier pour tester sur ordinateur : E ou Espace pour l'action, I ou Tab pour le sac.

Retours après premier essai (novembre 2026), intégrés :
- **sac** : toucher un objet le sélectionne, puis Utiliser, Jeter, Jeter tout (et Ranger avec un coffre ou un meuble ouvert) ;
- **fouille** : le meuble s'ouvre comme un coffre ; on prend objet par objet, ou tout d'un coup ; ce qu'on laisse y reste, et on peut y ranger des objets ;
- **carte** : zoom par pincement ou boutons (jusqu'à ×24), déplacement au doigt, bouton « Moi » ; villages puis hameaux et lieux notables apparaissent en zoomant ; échelle affichée ;
- **bâtiments** : redressés s'ils sont presque alignés sur la grille, murs continus, une porte par bâtiment (côté voie de préférence), sol jusqu'aux murs, meubles jamais sous un mur.

Hors étape 2 (étapes suivantes) : animaux et chasse, tribus, véhicules, voyage rapide, maladies détaillées, agriculture.

## 1. Le temps

| Élément | Règle proposée |
| --- | --- |
| Journée | 24 min réelles (1 min réelle = 1 h de jeu) |
| Saison | 7 jours de jeu ; année de 4 saisons (environ 11 h de jeu réel) |
| Départ | Début de l'automne, 8 h du matin (question ouverte n° 1) |
| Nuit | Écran assombri ; de 21 h à 6 h on voit à environ 8 cases autour de soi, davantage près d'un feu ou avec une torche |
| Météo | Beau, nuageux, pluie, brouillard ; tirée chaque demi-journée selon la saison. La pluie mouille le joueur |
| Pause | Le monde s'arrête quand l'appli est fermée ou mise en arrière-plan, et pendant que le sac ou la carte sont ouverts |

## 2. Les besoins

Quatre jauges de 0 à 100, affichées en coin d'écran, qui grossissent et clignotent sous 25.

| Jauge | Baisse | À zéro |
| --- | --- | --- |
| Soif | Vide en 1 jour de jeu (24 min) ; plus vite en courant ou s'il fait chaud | La santé baisse de 10 par heure de jeu |
| Faim | Vide en 2 jours de jeu | La santé baisse de 5 par heure |
| Fatigue | Vide en 20 h éveillé ; dormir 6 à 8 h la remplit | Marche ralentie, vision brouillée, puis évanouissement sur place |
| Chaleur | Suit la température ressentie (ci-dessous) | La santé baisse de 8 par heure (hypothermie) |

**Santé** (0 à 100) : elle remonte lentement quand les quatre jauges sont au-dessus de 50, plus vite en dormant. À 0, c'est la mort.

**Température ressentie** = température de la saison et de l'heure, moins la pluie (personnage mouillé), le vent en hauteur, plus les vêtements, un abri, ou un feu à moins de 4 cases.

## 3. Ce qu'on trouve dans la nature

On ramasse en touchant l'élément de décor ; certains demandent un outil. Ce qui est ramassé disparaît (repousse en quelques jours de jeu pour les plantes).

| Élément | À mains nues | Avec un outil | Saison |
| --- | --- | --- | --- |
| Arbres, arbres morts, bois au sol | Branches | Hache : bûches | Toute l'année |
| Buissons, aubépine | Branches, fibres | | |
| Ronces | Mûres (et une égratignure) | Couteau : sans dégâts | Fin d'été, automne |
| Pommier sauvage | Pommes | | Automne |
| Sol de forêt de feuillus | Champignons (dont certains toxiques) | | Automne |
| Herbes sèches, roseaux | Fibres | | |
| Rochers, cailloux | Pierres, parfois du silex | | |
| Eau douce (rivière, étang) | Boire sur place (risque de tomber malade) | Gourde : remplir | |

## 4. Fabrication (palier 1)

Liste de fabrication qui montre d'abord ce qui est faisable avec ce qu'on porte.

| Objet | Ingrédients | Usage |
| --- | --- | --- |
| Corde | 3 fibres | Base de nombreux objets |
| Couteau en silex | 1 silex, 1 branche, 1 corde | Couper ronces et fibres, préparer la nourriture |
| Hache de pierre | 2 pierres, 1 branche, 1 corde | Bûches, s'use (40 coups) |
| Lance | 2 branches, 1 couteau (non consommé), 1 corde | Défense (servira à la chasse à l'étape 3) |
| Torche | 1 branche, 2 fibres | Lumière la nuit, 1 h de jeu |
| Feu de camp | 6 branches, 4 pierres | Chaleur, lumière, cuisson, faire bouillir l'eau ; brûle 4 h par bûche ou 1 h par branche |
| Abri de branches | 12 branches, 6 fibres, 2 cordes | Dormir protégé de la pluie et du froid |
| Bandage | 1 tissu | Arrête un saignement, +15 santé |
| Eau bouillie | Gourde pleine + feu | Eau sans risque |
| Repas cuit | Champignons ou conserve + feu | Plus nourrissant, sans risque |
| Coffre de camp | 4 planches, 1 corde | Stockage de 12 cases au camp |

Les outils s'usent et se réparent pour moitié prix.

## 5. Fouiller les bâtiments

Chaque bâtiment se fouille une fois par partie : on touche un meuble à l'intérieur (armoire, frigo, carton, étagère) pour le vider. Les meubles sont placés par le jeu dans les bâtiments réels.

| Bâtiment (d'après OpenStreetMap) | Butin typique |
| --- | --- |
| Maison (la plupart) | Tissu, vêtements, conserves (une sur cinq périmée), bouteilles, bougies, parfois un outil |
| Supermarché, épicerie | Conserves, bouteilles, sacs ; déjà pillés à 80 % |
| Pharmacie, cabinet médical | Bandages, antiseptique, comprimés |
| Garage, station-service | Outils, ferraille, bidons |
| Quincaillerie | Outils, corde, clous, bâche |
| Ferme | Graines (pour plus tard), outils agricoles, bâche |
| Église, mairie, école | Peu de butin ; livres (recettes à découvrir plus tard) |

## 6. Le camp

On peut poser feu, abri et coffre n'importe où sur la terre ferme (hors routes et bâtiments). Dormir hors d'un abri ou d'un bâtiment est possible mais moins reposant et dangereux la nuit sous la pluie.

## 7. Mort et nouvelle partie

À la mort : un écran résume la partie (jours survécus, distance parcourue, bâtiments fouillés, cause de la mort), puis nouvelle partie : nouvelle graine, nouveau départ tiré au hasard, rien n'est gardé.

## 8. Sauvegarde

Sauvegarde automatique à chaque mise en arrière-plan de l'appli et toutes les 2 minutes : position, besoins, heure et météo, inventaire, constructions, et les changements du monde (objets ramassés, bâtiments fouillés), rangés par morceau de carte.

## 9. Interface

- Jauges en haut à gauche ; heure, jour et météo en haut à droite.
- Bouton d'action contextuel à droite, qui change selon ce qui est devant (ramasser, couper, boire, fouiller, dormir, allumer).
- Bouton Sac : inventaire (16 cases au départ) et fabrication sur le même écran.
- Boutons éloignés du bord droit (le panneau latéral de Samsung les cache aujourd'hui).
- Messages courts au-dessus du personnage (« Tu as soif », « Plus de place dans le sac »).

## 10. Sprites (lot 2, PixelLab)

| Élément | Forme | Générations (estimation) |
| --- | --- | --- |
| Icônes d'objets (environ 40) | Une planche d'objets 32 × 32 (jusqu'à 64 par appel) | 15 à 25 |
| Constructions et meubles : feu de camp, abri, coffre, armoire, frigo, carton, étagère, lit | Une planche de 16 objets 64 × 64 | 15 à 25 |
| Feu de camp animé | Animation de l'objet feu | 2 à 5 |
| Joueur : ramasser, frapper (hache), boire, dormir | 4 animations × 4 directions | environ 16 |
| Icônes d'interface (jauges, météo, boutons) | Une planche de petits objets | 10 à 25 |
| **Total** | | **60 à 95**, dans la limite des 80 % |

Nuit, pluie et brouillard sont faits par le jeu (filtre de couleur et particules), sans sprite.

## Validation de l'étape

- [ ] On peut survivre plusieurs jours en buvant, mangeant, dormant et en se chauffant, et mourir si on néglige un besoin.
- [ ] Fabriquer un couteau, une hache, un feu et un abri est faisable en moins d'une journée de jeu en partant de rien.
- [ ] Fouiller les maisons de Quimperlé rapporte un butin qui dépend du type de bâtiment.
- [ ] La sauvegarde reprend exactement où l'on s'est arrêté.
- [ ] Toujours fluide sur le S25 Ultra.

## Questions ouvertes

1. Saison de départ : début d'automne (baies et champignons, nuits fraîches) ou printemps (plus doux, moins de nourriture) ?
2. Vitesse des besoins : les durées ci-dessus (soif en 24 min réelles) vous conviennent-elles, ou plus lent pour une survie moins pressante ?
3. Faut-il un départ avec un peu d'équipement (sac vide, gourde) ou les mains vides ?
