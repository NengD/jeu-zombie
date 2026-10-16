# JeuZombie — consignes pour Claude Code

## Règles de travail
- Toujours répondre en **français**.
- Après chaque modification, donner une **courte liste d'améliorations possibles** pour le jeu (3 à 6 idées).
- On peut utiliser des modèles 3D trouvés sur internet **s'ils sont gratuits** (CC0 ou CC BY ; créditer l'auteur dans `CREDITS.txt` et dans l'aide en jeu `scripts/ui/textes.gd`).
- Quand l'utilisateur dit « finis… je vais éteindre », terminer proprement et s'arrêter.

## Économiser les tokens (priorité)
- Ne lire que les parties utiles des fichiers (Grep, puis Read avec offset/limit) ; ne pas relire un fichier déjà lu.
- Modifier avec de petites éditions ciblées plutôt que de réécrire des fichiers entiers.
- Vérifier visuellement le minimum : une ou deux armes représentatives, images réduites, pas de rendu de toutes les armes.
- Filtrer les sorties de commandes (grep, tail) pour ne garder que les erreurs et les résultats utiles.
- Réponses courtes : ce qui a été fait, puis la liste d'améliorations (3 à 6 idées, une ligne chacune).
- Pour une grosse demande, faire un plan court et avancer étape par étape ; proposer une nouvelle session quand la conversation devient longue.

## Projet
- Jeu de survie zombie en monde ouvert, **Godot 4.7.2** (GDScript), dossier de projet : `E:\_jeu perso\JeuZombie\jeu-zombie`.
- Exe : `E:\_jeu perso\JeuZombie\build\JeuZombie.exe` (export « Windows Desktop » de `export_presets.cfg`).
- Dépôt GitHub : `NengD/jeu-zombie` (branche `main`).
- Téléchargements de l'utilisateur (modèles .glb) : `E:\_jeu perso\JeuZombie\telechargement`.

## Organisation
- `scripts/autoload/items.gd` : objets, armes (famille, calibre…), munitions, recettes, tables de butin.
- `scripts/autoload/game.gd` : état global, touches, sons, mode admin.
- `scripts/player.gd` : joueur (déplacements, vue 1re/3e personne, tir, rechargement, visée, lancer de grenade, inventaire).
- `scripts/fps_arms.gd` : bras et mains à cinq doigts en vue 1re personne (prises, rechargements, réarmement des verrous).
- `scripts/accessoires.gd` : accessoires d'armes (compatibilités, effets, points de montage calculés, visée des optiques).
- `scripts/zombie.gd` : IA des zombies, démembrement, zombies armés (arme qui tombe à leur mort).
- `scripts/grenade.gd` : grenade lancée et explosion.
- `scripts/world_gen.gd`, `scripts/relief.gd` : génération de la carte.
- `scripts/ui/*` : HUD, inventaire, inspection des armes (touche T), panneau admin (F2), aide (F1).
- `modeles/armes/*.scn` : armes et accessoires normalisés (canon vers -Z, origine = main droite, métadonnées de prise : `L`, `incl`, `prise_l`, `chargeur_bas`, `culasse` ; nœuds `Chargeur` et `DispositifBouche`).
- `outils/godot/normaliser_du.gd` : crée ces scènes à partir des `.glb` de D_U rangés dans `outils/sources_du/` (réglages de prise `r`/`l` dans le tableau ARMES).
- `outils/godot/generer_icones_armes.gd` : icônes des armes, accessoires et munitions.
- `outils/sons/generer_sons.py` : sons générés (python3 generer_sons.py <dossier de sortie>).

## Pièges connus
- Les scripts avec `class_name` ne sont reconnus qu'après un import dans l'éditeur : préférer `const X = preload("res://…")`.
- Les scènes de modèles ne doivent pas dépendre de fichiers de `outils/` (exclu de l'export).
- Vérifier visuellement les changements de prise en main avec des vues de profil (repère + origine).
