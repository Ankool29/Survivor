# Survivor — notes pour Claude

Jeu de survie post-apo en monde ouvert, pixel art vu de dessus, France réelle à l'échelle 1:1
(prototype : Quimperlé). Godot 4.7, GDScript, cible mobile (testé sur Galaxy S25 Ultra).
Le joueur parle français : réponses, commentaires et docs en français.

## Façon de travailler
- Applique la skill `ponytail` sur toute tâche de code : plus petit changement qui règle le problème.
- Ne lis que les fichiers utiles à la tâche. Commence par ce plan, pas par une exploration du dépôt.
- Réponses courtes : ce qui a changé et comment le tester, sans récapituler chaque étape.
- Mets à jour `docs/A_CORRIGER.md` quand un défaut connu est corrigé ou découvert.

## Plan du code (`game/scripts/`)
- `main.gd` : scène principale, assemble tout (monde, joueur, survie, interface). Gros fichier : cherche avec grep avant de lire.
- `world/` : `zone_data` (lecture des zones), `chunk_manager` (morceaux 32×32 autour de la caméra),
  `world_gen` (contenu d'un morceau), `tiles` (catalogue des tuiles), `building_plan` + `interiors` (bâtiments détaillés).
- `survival/` : `survival` (temps, météo, besoins), `items`, `inventory`, `equipment`, `recipes`, `loot`, `world_mods` (changements sauvegardés).
- `fauna/` : `species` (fiches), `animal`, `fauna` (gestion autour du joueur).
- `game/` : `actions` (actions contextuelles), `atmosphere` (nuit, pluie, brouillard).
- `player/player.gd`, `ui/` (joystick, HUD, sac, carte).

Unités : 1 case = 2 m ; grille fine des bâtiments = 1 m. 1 s réelle = 1 min de jeu.

## Ailleurs
- `docs/` : cahiers d'étape (ETAPE1 à 4, BATIMENTS, BATIMENTS2) et `A_CORRIGER.md`. Lis seulement le cahier de l'étape en cours.
- `game/data/zones/` : généré par `tools/zone/` via GitHub Actions (`.github/workflows/zone.yml`). Ne pas modifier à la main.
- `tools/sprites/` : scripts d'import PixelLab. Ne pas dépasser 80 % du quota mensuel PixelLab.

## Test
Le joueur teste sur téléphone : `git pull` puis ouverture dans l'éditeur Godot Android (voir README).
Pas de Godot dans l'environnement de Claude : vérifie la syntaxe GDScript à la relecture.
