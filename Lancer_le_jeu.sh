#!/bin/sh
# Lance le jeu directement depuis le projet sous Linux (toujours la dernière version du code).
# Besoin : Godot 4.7.2 (commande « godot » dans le PATH, ou variable GODOT=/chemin/vers/godot).
cd "$(dirname "$0")" || exit 1
GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" > /dev/null 2>&1; then
	echo "Godot introuvable : installe Godot 4.7.2 ou lance avec GODOT=/chemin/vers/godot sh Lancer_le_jeu.sh"
	exit 1
fi
echo "Préparation des fichiers..."
"$GODOT" --headless --path . --import > /dev/null 2>&1
exec "$GODOT" --path .
