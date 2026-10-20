#!/bin/sh
# Lance le jeu sous Linux (version exportée JeuZombie.x86_64 + JeuZombie.pck).
# Utilisation : sh Jouer_linux.sh   (marche même si le zip a perdu le droit d'exécution)
cd "$(dirname "$0")" || exit 1
if [ ! -f JeuZombie.x86_64 ] || [ ! -f JeuZombie.pck ]; then
	echo "JeuZombie.x86_64 ou JeuZombie.pck introuvable dans $(pwd)"
	exit 1
fi
chmod +x JeuZombie.x86_64 2>/dev/null
exec ./JeuZombie.x86_64 "$@"
