extends RefCounted
## Textes partagés : liste des touches et guide du joueur.

const TOUCHES := [
	["Se déplacer", "Z Q S D"],
	["Sprinter", "Maj"],
	["Sauter", "Espace"],
	["S'accroupir (plus discret)", "C ou Ctrl"],
	["Se pencher à gauche / à droite", "A / E"],
	["Frapper / tirer", "Clic gauche"],
	["Viser (armes à feu) / parer (mêlée)", "Clic droit"],
	["Barre rapide (arme ou objet)", "1 à 5, molette"],
	["Recharger", "R"],
	["Se soigner", "H"],
	["Fouiller / utiliser", "F"],
	["Inventaire et fabrication", "Tab ou I"],
	["Carte", "M"],
	["Vue 1re / 3e personne", "V"],
	["Lampe torche / lampe de l'arme", "L"],
	["Inspecter l'arme (accessoires)", "T"],
	["Personnage : niveaux et compétences", "K"],
	["Pause", "Échap"],
	["Sauvegarde rapide / chargement", "F5 / F9"],
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

[b]NIVEAUX ET COMPÉTENCES[/b] (touche K)
• Chaque action rapporte de l'XP : tuer des zombies (Combat), fabriquer et construire (Fabrication), fouiller et découvrir des bâtiments (Exploration).
• Niveau global : +1 point d'attribut à placer en Endurance, Santé, Soif ou Faim.
• Chaque niveau de compétence donne 1 point de talent : débloque des bonus (dégâts, recharge, soins, munitions, discrétion, poches plus grandes…).

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
• [b]Fermes et station-service[/b] : matériaux, nourriture, cuir.
• [b]Villages[/b] (Saint-Aubin au nord, Hameau des Sources à l'ouest) : maisons à toit de tuiles, épicerie, mairie, église.
• [b]Carambolages[/b] (repères rouges) : zones infestées sur l'autoroute, une trentaine de zombies et des coffres bien remplis.
• [b]Grotte du Colosse[/b] (repère violet) : le BOSS, un zombie géant de 2 500 PV qui charge et frappe le sol. Prends une lampe ! Sa cache contient le meilleur butin du jeu.

[b]MODE ADMIN[/b] (bouton dans le menu principal, rien n'est sauvegardé)
• N : voler (Espace monte, Ctrl descend, Maj rapide). F2 : panneau admin (tous les objets, téléportation, heure, zombies, boss, niveaux).

[b]PAYSAGE[/b]
• Collines, lacs et rivière au nord de la ville (on peut marcher dans l'eau, lentement). Un pont la traverse sur l'autoroute.
• Cabane de pêche au bord de l'étang, antenne relais sur le point le plus haut. La carte (M) montre le relief et l'eau.

[b]CORPS À CORPS[/b]
• Estoc au couteau, coup en arc (batte, machette…), coup vertical (hache, masse). Clic droit : parade (80 % de dégâts en moins, repousse le zombie).

[b]ZOMBIES[/b]
• Coureurs, gros zombies, rampants. Bras et jambes peuvent être arrachés ; sans jambes, le zombie rampe.

[b]VISÉE ET RECHARGEMENT[/b]
• En visant, on regarde vraiment dans le viseur : hausse et guidon, verre du point rouge, ou lunette grossissante avec réticule.
• Rechargement réaliste : chargeur changé ; à vide, il tombe au sol et on réarme. Fusil à pompe et revolver : une cartouche à la fois.

[b]BÂTIMENTS ET PORTES[/b]
• Toutes les portes s'ouvrent et se ferment avec F. Les zombies ne savent pas les ouvrir : ils tapent dedans jusqu'à les enfoncer.
• Les immeubles se visitent en entier : un escalier relie tous les étages, chacun avec ses meubles… et ses habitants."""


static func touches_texte() -> String:
	var lines: PackedStringArray = []
	for t in TOUCHES:
		lines.append("%s : %s" % [t[1], t[0]])
	return "\n".join(lines)
