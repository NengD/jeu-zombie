# JeuZombie — consignes pour Claude Code

## Règles de travail
- Toujours répondre en **français**.
- Après chaque modification, donner une **courte liste d'améliorations possibles** pour le jeu (3 à 6 idées).
- On peut utiliser des modèles 3D trouvés sur internet **s'ils sont gratuits** (CC0 ou CC BY ; créditer l'auteur dans `CREDITS.txt` et dans l'aide en jeu `scripts/ui/textes.gd`).
- Quand l'utilisateur dit « finis… je vais éteindre », terminer proprement et s'arrêter.
- À la fin de chaque demande terminée (et vérifiée), faire un commit et un **push sur GitHub** (`NengD/jeu-zombie`, branche `main`) pour que le dépôt ait toujours la version la plus récente. Message de commit court en français. Ne pas pousser les fichiers générés (`.godot/`). L'exe et le .pck ne sont refaits et poussés que sur demande.

## Économiser les tokens (priorité)
- Ne lire que les parties utiles des fichiers (Grep, puis Read avec offset/limit) ; ne pas relire un fichier déjà lu.
- Modifier avec de petites éditions ciblées plutôt que de réécrire des fichiers entiers.
- Vérifier visuellement le minimum : une ou deux armes représentatives, images réduites, pas de rendu de toutes les armes.
- Filtrer les sorties de commandes (grep, tail) pour ne garder que les erreurs et les résultats utiles.
- Réponses courtes : ce qui a été fait, puis la liste d'améliorations (3 à 6 idées, une ligne chacune).
- Pour une grosse demande, faire un plan court et avancer étape par étape ; proposer une nouvelle session quand la conversation devient longue.

## Projet
- Jeu de survie zombie en monde ouvert, **Godot 4.7.2** (GDScript), dossier de projet : `E:\_jeu perso\JeuZombie\jeu-zombie`.
- Jeu jouable : `JeuZombie.exe` + `JeuZombie.pck` **à la racine du dépôt**, suivis par **Git LFS** (fichiers > 100 Mo ; quota gratuit 10 Go). On télécharge le dépôt et on lance l'exe (modèle officiel `windows_release_x86_64`, il charge tout seul le `.pck` du même nom). Les refaire avec `bash outils/construire_exe.sh` **seulement quand l'utilisateur le demande** (« refais l'exe ») : chaque version ajoute ~145 Mo au stockage LFS. Modèle d'export installé dans `%APPDATA%/Godot/export_templates/4.7.2.stable/` (Windows release seulement). Un lanceur maison (exe C#) a été essayé : supprimé par McAfee, ne pas refaire.
- Dépôt GitHub : `NengD/jeu-zombie` (branche `main`).
- Téléchargements de l'utilisateur (modèles .glb) : `E:\_jeu perso\JeuZombie\telechargement`.

## Organisation
- `scripts/autoload/items.gd` : objets, armes (famille, calibre…), munitions, recettes, tables de butin.
- `scripts/autoload/game.gd` : état global, touches, sons, mode admin.
- `scripts/player.gd` : joueur (déplacements, vue 3e personne (caméra à ressort `bras_camera` sur l'épaule, `recul_camera()` ajouté aux portées ; plus de vue 1re personne : seul `hand_weapon` est affiché), coup de mêlée + coup puissant (clic maintenu), animations du corps calées sur les coups (`_anim_corps`), tir, rechargement, visée, lancer de grenade, inventaire).
- `scripts/fps_arms.gd` : ancien code 1re personne, ne sert plus que de bibliothèque de fonctions statiques (`hand_points` = points de prise, `arme_a_cartouches`, `evenements` du rechargement) ; ne plus l'instancier.
- `outils/godot/captures_tenue_armes.gd -- <dossier> arme1 arme2…` : planche de tenue d'arme (repos / en joue, côtés droit et gauche).
- `scripts/accessoires.gd` : accessoires d'armes (compatibilités, effets, points de montage calculés, visée des optiques).
- `scripts/zombie.gd` : IA des zombies, démembrement, zombies armés (arme qui tombe à leur mort).
- `scripts/grenade.gd` : grenade lancée et explosion.
- `scripts/bandit.gd` : bandits armés (patrouille, ouïe, vue, combat à distance, alerte du camp, butin). `scripts/camp_bandits.gd` : camps (tentes, brasero, sacs de sable, caisses `camp_bandit`), créés par `main.gd` (`_creer_camps`, état sauvegardé par camp).
- Rendu : qualité Bas/Moyen/Élevé/Ultra (`Game.qualite`, menu Paramètres et pause) appliquée par `day_night.gd` (`appliquer_qualite`) et `game.gd` (`_appliquer_rendu`). SDFGI désactivé (intérieurs délavés). `outils/godot/captures_rendu.gd -- <dossier> <préfixe> <qualité>` : captures de comparaison + FPS.
- `scripts/bras_ik.gd` : bras calculés après l'animation (SkeletonModifier3D, IK deux os) pour tenir les armes à feu : au torse au repos, en joue vers `cible_visee` (buste penché vers le point visé), rechargement (`recharge*`, pose de `FpsArms.reload_pose`, chargeur en main gauche `chargeur_main`), armes de mêlée à deux mains (`main_g_seule`, pendant coup / charge / parade), arme contre la poitrine au sprint (`sprint`), goupille de grenade arrachée de la main gauche (`goupille_t`, puis `_jeter_grenade`, bras gauche tendu `main_g_tendue`), coup de grâce à l'arme de mêlée (`achevement` : deux mains levée puis abattue, lame accroupi plantée ; `player.achev_mode`) ; utilisé par le joueur (`_maj_bras`) et les bandits. `scripts/pieds_ik.gd` : pieds posés sur le sol (pentes, marches), bassin abaissé ; coup de talon du coup de grâce (`coup_pied`, `cible_pied`) ; joueur + zombies et bandits à moins de 22 m (`pieds_ik.active`). Réticule dynamique (`hud.gd`, écart = `player.dispersion()` + bloom des tirs, rouge sur un ennemi, croix orange `_point_bloque` quand un obstacle coupe la ligne tête → point visé). `outils/godot/captures_animations.gd` : planche de comparaison mannequin UAL / personnage (profil, face, mains).
- Personnages : low-poly Quaternius (21 modèles, `modeles/persos_mod/`, générés par `outils/godot/generer_persos_modulaires.gd` depuis `outils/sources_persos_modulaires/` : os renommés comme UAL (doigts : os 1 = métacarpe, phalanges 2-4 -> 01-03), 36 animations UAL transférées (repère de chaque os aligné : direction + torsion ; pieds rattachés aux mollets) ; mains détaillées retirées et remplacées par des poings low-poly rigides (`_mains_simples`, nœuds `MainSimple_l/_r`), `Prise` main droite). Choix et couleurs par type dans `perso.gd` (`MODELES`, `_creer_modulaire`, sang `shaders/sang_perso.gdshader`). Ancien mannequin UAL (`modeles/persos/`) gardé comme source des animations.
- Textures du monde : stylisées low-poly (`outils/godot/styliser_textures.gd`) à partir des photos Poly Haven 2k (`outils/sources_textures/`) ; retour aux photos : `outils/godot/installer_textures.gd`.
- Ambiance (créée par `main.gd` `_creer_ambiance`) : `eclairage_rues.gd` (lampadaires la nuit, seules les plus proches éclairent), `details_monde.gd` (décalques générés + herbe en parcelles MultiMesh autour du joueur, `shaders/herbe.gdshader`), `meteo.gd` (pluie, flaques, sols mouillés, `Game.pluie`). Variable d'environnement `SANS_FACADES=1` : désactive ces effets et les détails de façade (test de performance).
- `outils/sources_props/` : modèles Poly Haven téléchargés (gltf 1k), convertis par `outils/godot/normaliser_props.gd` (PROP=id).
- `scripts/construction.gd` : pièces de construction de base (fondation, murs, porte, plancher, escalier ; bois → tôle → parpaing) et nœud `Base` (grille 3 m, emplacements `c:`/`b:`/`e:`/`p:`).
- `scripts/vendeur.gd` + `scripts/ui/boutique_ui.gd` : marchands du marché des survivants (créé par `main.gd` près du départ), achat / revente (prix dans `items.gd`, argent `player.argent`).
- `scripts/constructeur.gd` : mode construction (touche B, marteau), aimantation, aperçu, [G] renforcer/réparer, [X] démonter.
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
- Nouvelles images (icônes .svg/.png) : lancer `godot --headless --path . --import` sinon elles ne s'affichent pas hors éditeur.
