#!/bin/bash
# Refait le jeu jouable du dépôt (suivi par Git LFS), à la racine :
#   JeuZombie.exe (Windows) + JeuZombie.x86_64 (Linux) + JeuZombie.pck (données, communes aux deux).
# Il suffit ensuite de télécharger le dépôt et de lancer l'exe (ou sh Jouer_linux.sh) :
# Godot charge tout seul le .pck du même nom que le programme.
# Usage (Git Bash) : bash outils/construire_exe.sh
# Besoin : Godot 4.7.2 dans ../../godot/ et les modèles d'export windows_release_x86_64.exe
# et linux_release.x86_64 dans %APPDATA%/Godot/export_templates/4.7.2.stable/.
set -e
cd "$(dirname "$0")/.."
GODOT="../../godot/Godot_v4.7.2-stable_win64_console.exe"
MODELES="$APPDATA/Godot/export_templates/4.7.2.stable"
echo "Import des fichiers..."
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
echo "Export du jeu..."
rm -f JeuZombie.exe JeuZombie.pck
"$GODOT" --headless --path . --export-release "Windows Desktop" "JeuZombie.exe" 2>&1 | grep -iE "error" || true
[ -f JeuZombie.exe ] && [ -f JeuZombie.pck ] || { echo "Échec de l'export"; exit 1; }
# Linux : le modèle tel quel (il ne contient pas de données) ; il charge JeuZombie.pck comme l'exe Windows
cp -f "$MODELES/linux_release.x86_64" JeuZombie.x86_64
chmod +x JeuZombie.x86_64
git update-index --chmod=+x JeuZombie.x86_64 Jouer_linux.sh Lancer_le_jeu.sh 2>/dev/null || true
ls -l JeuZombie.exe JeuZombie.x86_64 JeuZombie.pck
echo "Terminé"
