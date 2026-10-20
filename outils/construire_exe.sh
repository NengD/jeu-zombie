#!/bin/bash
# Refait le jeu jouable du dépôt : JeuZombie.exe + JeuZombie.pck à la racine (suivis par Git LFS).
# Il suffit ensuite de télécharger le dépôt et de lancer JeuZombie.exe (Godot charge tout seul le .pck du même nom).
# Usage (Git Bash) : bash outils/construire_exe.sh
# Besoin : Godot 4.7.2 dans ../../godot/ et le modèle d'export windows_release_x86_64 installé
# (%APPDATA%/Godot/export_templates/4.7.2.stable/).
set -e
cd "$(dirname "$0")/.."
GODOT="../../godot/Godot_v4.7.2-stable_win64_console.exe"
echo "Import des fichiers..."
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
echo "Export du jeu..."
rm -f JeuZombie.exe JeuZombie.pck
"$GODOT" --headless --path . --export-release "Windows Desktop" "JeuZombie.exe" 2>&1 | grep -iE "error" || true
[ -f JeuZombie.exe ] && [ -f JeuZombie.pck ] || { echo "Échec de l'export"; exit 1; }
ls -l JeuZombie.exe JeuZombie.pck
echo "Terminé"
