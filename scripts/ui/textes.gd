extends RefCounted
## Textes partagés : liste des touches et guide du joueur.

const TOUCHES := [
	["Se déplacer", "Z Q S D"],
	["Sprinter", "Maj"],
	["Sauter", "Espace"],
	["S'accroupir (plus discret)", "C ou Ctrl"],
	["Se pencher à gauche / à droite", "A / E"],
	["Frapper / tirer", "Clic gauche"],
	["Viser (armes à feu)", "Clic droit"],
	["Barre rapide (arme ou objet)", "1 à 5, molette"],
	["Recharger", "R"],
	["Se soigner", "H"],
	["Fouiller / utiliser", "F"],
	["Inventaire et fabrication", "Tab ou I"],
	["Carte", "M"],
	["Vue 1re / 3e personne", "V"],
	["Lampe torche / lampe de l'arme", "L"],
	["Inspecter l'arme (accessoires)", "T"],
	["Pause", "Échap"],
	["Aide en jeu", "F1"],
]

const GUIDE := """[b]LES BASES[/b]
• Fouille les meubles (armoires, casiers, frigos…) et les corps des zombies avec [b]F[/b].
• Surveille ta faim et ta soif : si l'une tombe à zéro, tu perds de la santé.
• La santé remonte doucement tant que tu es bien nourri et hydraté.
• Ton inventaire de base fait 8×5 cases. Un gilet et un sac à dos ajoutent de la place en plus : trouve de plus grands sacs !

[b]COMBAT[/b]
• Les armes à feu font beaucoup de bruit et attirent les zombies de loin. Les armes blanches sont discrètes.
• Viser la tête inflige 2,5× plus de dégâts et ignore l'armure des zombies policiers et militaires.
• Accroupi, tu es plus difficile à repérer. Penche-toi (A / E) pour regarder au coin d'un mur.
• La nuit, les zombies voient moins bien… sauf si ta lampe est allumée. Certains courent plus vite.

[b]INVENTAIRE[/b]
• Chaque objet occupe des cases : une conserve 1×1, un pistolet 2×1, un fusil d'assaut 4×2…
• Glisse-dépose les objets entre tes poches, ton sac et les meubles fouillés. [b]R[/b] pendant le glissement pour tourner un objet.
• Double-clic : utiliser / équiper. Ctrl + clic : transfert rapide. Clic droit : options (diviser une pile, jeter…).
• Lâcher un objet hors de la fenêtre le jette au sol (on peut le reprendre en fouillant le tas).
• Glisse un sac ou un gilet sur l'emplacement d'équipement pour l'équiper et profiter de son rangement.

[b]ACCESSOIRES D'ARMES[/b]
• Appuie sur [b]T[/b] pour inspecter ton arme à feu : fais-la tourner à la souris et pose ou retire ses accessoires.
• [b]Viseur point rouge / lunette[/b] : visée plus précise (la lunette zoome). [b]Silencieux[/b] : tes tirs attirent beaucoup moins les zombies.
• [b]Chargeur grande capacité[/b] : plus de balles par chargeur. [b]Lampe tactique[/b] : éclaire où tu vises (touche L). [b]Poignée[/b] : moins de recul.
• On les trouve au poste de police, à l'armurerie et à la base militaire. Silencieux artisanal et poignée se fabriquent à l'établi.

[b]BARRE RAPIDE[/b]
• Dans l'inventaire, glisse un objet sur un emplacement 1 à 5 de la barre rapide.
• Clic droit sur un emplacement pour le vider.
• Une arme dans un emplacement se prend en main ; un consommable (bandage, eau…) s'utilise directement.

[b]CONSTRUIRE SA BASE[/b]
1. Fabrique un établi (Tab) : 4 planches + 6 clous + 2 ferrailles.
2. Vide un bâtiment de tous ses zombies : le coin en haut à droite affiche « bâtiment sûr ».
3. Dans l'inventaire, sélectionne l'établi puis « Utiliser » : un fantôme vert apparaît.
   Clic gauche pour poser, molette ou R pour tourner, clic droit pour annuler.
4. Près de l'établi, les recettes [établi] se débloquent : munitions, armes, vestes, sac à dos, caisse de stockage…
5. Les barricades se posent n'importe où, par exemple dans une porte. Les zombies peuvent les casser.

[b]POINTS STRATÉGIQUES[/b] (touche M pour la carte)
• [b]Poste de police[/b] : pistolets, fusil à pompe, carabine, gilets pare-balles.
• [b]Base militaire[/b] : fusil d'assaut, gilet tactique, casque — très gardée ! Portail à l'est… et une brèche quelque part au nord.
• [b]Hôpital[/b] : bandages, trousses de soin, antidouleurs.
• [b]Supermarché[/b] : nourriture et boissons.
• [b]Armurerie[/b] : armes et munitions.
• [b]Quincaillerie[/b] : planches, clous, ferraille, haches.
• [b]Fermes et station-service[/b] : matériaux, nourriture, cuir."""


static func touches_texte() -> String:
	var lines: PackedStringArray = []
	for t in TOUCHES:
		lines.append("%s : %s" % [t[1], t[0]])
	return "\n".join(lines)
