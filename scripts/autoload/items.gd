extends Node
## Base de données des objets, recettes de craft et tables de loot.
## Pour ajouter un objet : ajoute une entrée dans DB. Pour une recette : dans RECIPES.

const DB := {
	# --- nourriture / boisson / soins
	"conserve": {"name": "Conserve", "type": "food", "food": 35.0, "weight": 0.4},
	"barre": {"name": "Barre de céréales", "type": "food", "food": 15.0, "weight": 0.1},
	"ration": {"name": "Ration militaire", "type": "food", "food": 60.0, "water": 10.0, "weight": 0.5},
	"eau": {"name": "Bouteille d'eau", "type": "drink", "water": 45.0, "weight": 0.5},
	"soda": {"name": "Soda", "type": "drink", "water": 25.0, "food": 5.0, "weight": 0.35},
	"bandage": {"name": "Bandage", "type": "heal", "heal": 15.0, "weight": 0.1},
	"trousse": {"name": "Trousse de soin", "type": "heal", "heal": 100.0, "weight": 0.6},
	"antidouleur": {"name": "Antidouleurs", "type": "heal", "heal": 10.0, "weight": 0.05},
	"medicament": {"name": "Médicaments anti-nausée", "type": "heal", "heal": 5.0, "weight": 0.05, "desc": "Guérit l'intoxication (viande crue)."},
	# --- matériaux
	"tissu": {"name": "Tissu", "type": "material", "weight": 0.1},
	"planche": {"name": "Planche", "type": "material", "weight": 1.0},
	"clous": {"name": "Clous", "type": "material", "weight": 0.05},
	"ferraille": {"name": "Ferraille", "type": "material", "weight": 0.6},
	"ruban": {"name": "Ruban adhésif", "type": "material", "weight": 0.1},
	"poudre": {"name": "Poudre à canon", "type": "material", "weight": 0.1},
	"alcool": {"name": "Alcool", "type": "material", "weight": 0.4},
	"cuir": {"name": "Cuir", "type": "material", "weight": 0.3},
	"ciment": {"name": "Sac de ciment", "type": "material", "weight": 3.0},
	"marteau": {"name": "Marteau de construction", "type": "outil", "weight": 0.8},
	"piece_auto": {"name": "Pièces auto", "type": "material", "weight": 1.2},
	"essence": {"name": "Jerrican d'essence", "type": "material", "weight": 2.5},
	"cle_molette": {"name": "Clé à molette", "type": "outil", "weight": 0.5},
	"plume": {"name": "Plumes", "type": "material", "weight": 0.01, "desc": "Empennage des flèches."},
	# --- récolte (hache : arbres ; pioche : rochers ; les deux : épaves de voitures)
	"buche": {"name": "Bûche", "type": "material", "weight": 2.5, "desc": "Bois coupé à la hache. À fendre en planches à l'établi, ou à brûler."},
	"pierre": {"name": "Pierre", "type": "material", "weight": 1.2, "desc": "Cassée à la pioche. Foyers, pointes de flèches, ciment."},
	"minerai": {"name": "Minerai de fer", "type": "material", "weight": 1.5, "desc": "Trouvé parfois en cassant les rochers. Fondu au feu : ferraille."},
	"pneu": {"name": "Pneu", "type": "material", "weight": 6.0, "desc": "Démonté d'une épave. Barricades lourdes."},
	"batterie": {"name": "Batterie de voiture", "type": "material", "weight": 9.0, "desc": "Démontée d'une épave. Alimente un projecteur."},
	# --- chasse : produits du dépeçage
	"viande_crue": {"name": "Viande crue", "type": "food", "food": 18.0, "weight": 0.4, "cru": true, "desc": "À cuire au feu de camp ou au brasero. Crue, elle peut rendre malade."},
	"peau": {"name": "Peau brute", "type": "material", "weight": 0.8, "desc": "À tanner pour obtenir du cuir."},
	"os": {"name": "Os", "type": "material", "weight": 0.2, "desc": "Pointes de flèches, outils, bouillon."},
	"graisse": {"name": "Graisse animale", "type": "material", "weight": 0.2, "desc": "Sert au tannage et à la cuisine."},
	"viande_cuite": {"name": "Viande cuite", "type": "food", "food": 45.0, "weight": 0.35, "desc": "Cuite au feu : nourrissante et sans danger."},
	"viande_sechee": {"name": "Viande séchée", "type": "food", "food": 32.0, "weight": 0.15, "desc": "Séchée au séchoir : légère, se garde, sans danger."},
	"bouillon": {"name": "Bouillon d'os", "type": "drink", "water": 35.0, "food": 15.0, "weight": 0.5, "desc": "Os mijotés dans l'eau : désaltère et nourrit un peu."},
	"ragout": {"name": "Ragoût de chasse", "type": "food", "food": 85.0, "water": 15.0, "weight": 0.7, "desc": "Plat complet : rassasie longtemps."},
	# --- munitions
	"mun_9mm": {"name": "Balles 9×19 mm", "type": "ammo", "weight": 0.012, "modele": "cart_9mm"},
	"mun_45": {"name": "Balles .45 ACP", "type": "ammo", "weight": 0.021, "modele": "cart_45"},
	"mun_50ae": {"name": "Balles .50 AE", "type": "ammo", "weight": 0.033, "modele": "cart_50ae"},
	"mun_46": {"name": "Balles 4.6×30 mm", "type": "ammo", "weight": 0.007, "modele": "cart_46"},
	"mun_12": {"name": "Cartouches calibre 12", "type": "ammo", "weight": 0.04, "modele": "cart_12"},
	"mun_556": {"name": "Balles 5.56×45 mm", "type": "ammo", "weight": 0.012, "modele": "cart_556"},
	"mun_545": {"name": "Balles 5.45×39 mm", "type": "ammo", "weight": 0.011, "modele": "cart_545"},
	"mun_762x39": {"name": "Balles 7.62×39 mm", "type": "ammo", "weight": 0.016, "modele": "cart_762x39"},
	"mun_762": {"name": "Balles 7.62×51 mm", "type": "ammo", "weight": 0.024, "modele": "cart_762"},
	"mun_762r": {"name": "Balles 7.62×54R", "type": "ammo", "weight": 0.022, "modele": "cart_762r"},
	"mun_338": {"name": "Balles .338 Lapua", "type": "ammo", "weight": 0.046, "modele": "cart_338"},
	"mun_127": {"name": "Balles 12.7×99 mm", "type": "ammo", "weight": 0.11, "modele": "cart_127"},
	"mun_4570": {"name": "Balles .45-70", "type": "ammo", "weight": 0.03, "modele": "cart_4570"},
	"fleche": {"name": "Flèche", "type": "ammo", "weight": 0.03, "desc": "Munition de l'arc. Souvent récupérable après le tir."},
	# --- armes blanches
	"poings": {"name": "Poings", "type": "melee", "damage": 9.0, "rate": 0.5, "range": 1.6, "stamina": 5.0, "len": 0.0, "color": Color(0.8, 0.6, 0.5)},
	"batte": {"name": "Batte de baseball", "type": "melee", "damage": 36.0, "rate": 0.8, "range": 2.2, "stamina": 14.0, "len": 0.85, "color": Color(0.55, 0.38, 0.2), "weight": 1.0},
	"batte_cloutee": {"name": "Batte cloutée", "type": "melee", "damage": 52.0, "rate": 0.85, "range": 2.2, "stamina": 15.0, "len": 0.85, "color": Color(0.45, 0.3, 0.18), "weight": 1.2},
	"machette": {"name": "Machette", "type": "melee", "damage": 46.0, "rate": 0.6, "range": 2.0, "stamina": 11.0, "len": 0.6, "color": Color(0.6, 0.62, 0.65), "weight": 0.8},
	"pioche": {"name": "Pioche", "type": "melee", "damage": 60.0, "rate": 1.2, "range": 2.1, "stamina": 22.0, "len": 0.85, "color": Color(0.45, 0.45, 0.47), "weight": 2.6, "desc": "Arme lourde ; casse les rochers (pierre, minerai) et démonte les épaves."},
	"hache": {"name": "Hache", "type": "melee", "damage": 65.0, "rate": 1.05, "range": 2.1, "stamina": 20.0, "len": 0.75, "color": Color(0.5, 0.15, 0.1), "weight": 1.8},
	"matraque": {"name": "Matraque", "type": "melee", "damage": 30.0, "rate": 0.55, "range": 1.9, "stamina": 9.0, "len": 0.55, "color": Color(0.1, 0.1, 0.1), "weight": 0.6},
	"couteau_km2000": {"name": "Couteau de combat KM2000", "type": "melee", "damage": 31.0, "rate": 0.4, "range": 1.7, "stamina": 7.0, "len": 0.3, "color": Color(0.2, 0.2, 0.2), "weight": 0.35},
	# --- arc (modèle construit par le code) : maintenir le clic pour bander, relâcher pour tirer
	"arc": {"name": "Arc de chasse", "type": "arc", "ammo": "fleche", "damage": 95.0, "range": 75.0, "noise": 3.0, "len": 0.0, "weight": 1.1, "desc": "Maintenir le clic gauche pour bander, relâcher pour tirer : plus la corde est tendue, plus la flèche va loin et fait mal. Presque silencieux. Les flèches se ramassent souvent."},
	# --- armes à feu : modèles « low-poly » de D_U (Sketchfab, CC Attribution — voir CREDITS.txt)
	# famille : prise en main et accessoires ; calibre = munition ; pitch : hauteur du son du tir
	# semi : pas de pompe ; verrou / levier : réarmement manuel après chaque tir ; cartouches : chargement une à une ;
	# perforant : nombre de zombies traversés par la balle
	"glock19": {"name": "Glock 19 (9 mm)", "type": "gun", "famille": "pistolet", "ammo": "mun_9mm", "sound": "tir_pistolet", "damage": 32.0, "rate": 0.15, "mag": 15, "spread": 1.2, "noise": 45.0, "reload": 1.4, "auto": false, "pellets": 1, "range": 80.0, "recoil": 0.024, "len": 0.19, "weight": 0.7, "optique_glissiere": true},
	"mr920": {"name": "Shadow Systems MR920 (9 mm)", "type": "gun", "famille": "pistolet", "ammo": "mun_9mm", "sound": "tir_pistolet", "damage": 32.0, "rate": 0.15, "mag": 17, "spread": 1.1, "noise": 45.0, "reload": 1.4, "auto": false, "pellets": 1, "range": 80.0, "recoil": 0.023, "len": 0.19, "weight": 0.75, "optique_glissiere": true},
	"m45a1": {"name": "Colt M45A1 (.45 ACP)", "type": "gun", "famille": "pistolet", "ammo": "mun_45", "sound": "tir_pistolet", "damage": 45.0, "rate": 0.2, "mag": 8, "spread": 1.0, "noise": 52.0, "reload": 1.5, "auto": false, "pellets": 1, "range": 80.0, "recoil": 0.035, "len": 0.22, "weight": 1.1, "pitch": 0.92},
	"desert_eagle": {"name": "Desert Eagle (.50 AE)", "type": "gun", "famille": "pistolet", "ammo": "mun_50ae", "sound": "tir_pistolet", "damage": 85.0, "rate": 0.38, "mag": 7, "spread": 0.9, "noise": 70.0, "reload": 1.7, "auto": false, "pellets": 1, "range": 90.0, "recoil": 0.08, "len": 0.27, "weight": 2.0, "pitch": 0.8},
	"mp5k": {"name": "HK MP5K (9 mm)", "type": "gun", "famille": "smg", "ammo": "mun_9mm", "sound": "tir_pistolet", "damage": 28.0, "rate": 0.067, "mag": 30, "spread": 2.0, "noise": 55.0, "reload": 2.0, "auto": true, "pellets": 1, "range": 70.0, "recoil": 0.016, "len": 0.57, "weight": 2.5, "pitch": 1.1},
	"mp7": {"name": "HK MP7A1 (4.6 mm)", "type": "gun", "famille": "smg", "ammo": "mun_46", "sound": "tir_pistolet", "damage": 26.0, "rate": 0.063, "mag": 40, "spread": 1.6, "noise": 50.0, "reload": 2.0, "auto": true, "pellets": 1, "range": 90.0, "recoil": 0.013, "len": 0.42, "weight": 1.9, "pitch": 1.2},
	"benelli_m4": {"name": "Benelli M4 (calibre 12)", "type": "gun", "famille": "pompe", "ammo": "mun_12", "sound": "tir_pompe", "damage": 17.0, "rate": 0.3, "mag": 7, "spread": 4.5, "noise": 78.0, "reload": 2.6, "auto": false, "pellets": 8, "range": 40.0, "recoil": 0.085, "len": 1.02, "weight": 3.8, "semi": true, "cartouches": true},
	"toz34": {"name": "Fusil de chasse TOZ-34 (calibre 12)", "type": "gun", "famille": "pompe", "ammo": "mun_12", "sound": "tir_pompe", "damage": 19.0, "rate": 0.25, "mag": 2, "spread": 3.5, "noise": 80.0, "reload": 2.0, "auto": false, "pellets": 9, "range": 45.0, "recoil": 0.1, "len": 1.15, "weight": 3.3, "cassant": true, "cartouches": true},
	"m4a1": {"name": "Colt M4A1 (5.56 mm)", "type": "gun", "famille": "fusil", "ammo": "mun_556", "sound": "tir_fusil", "damage": 36.0, "rate": 0.075, "mag": 30, "spread": 1.2, "noise": 85.0, "reload": 2.3, "auto": true, "pellets": 1, "range": 160.0, "recoil": 0.022, "len": 0.8, "weight": 3.2},
	"m5_scw": {"name": "Colt M5 SCW (5.56 mm)", "type": "gun", "famille": "fusil", "ammo": "mun_556", "sound": "tir_fusil", "damage": 34.0, "rate": 0.07, "mag": 30, "spread": 1.5, "noise": 88.0, "reload": 2.2, "auto": true, "pellets": 1, "range": 120.0, "recoil": 0.026, "len": 0.64, "weight": 2.9},
	"urgi": {"name": "URG-I SOCOM (5.56 mm)", "type": "gun", "famille": "fusil", "ammo": "mun_556", "sound": "tir_fusil", "damage": 36.0, "rate": 0.075, "mag": 30, "spread": 1.1, "noise": 85.0, "reload": 2.3, "auto": true, "pellets": 1, "range": 170.0, "recoil": 0.021, "len": 0.86, "weight": 3.4},
	"lr300": {"name": "Z-M LR-300 (5.56 mm)", "type": "gun", "famille": "fusil", "ammo": "mun_556", "sound": "tir_fusil", "damage": 36.0, "rate": 0.08, "mag": 30, "spread": 1.15, "noise": 85.0, "reload": 2.3, "auto": true, "pellets": 1, "range": 160.0, "recoil": 0.021, "len": 0.8, "weight": 3.0},
	"mcx": {"name": "SIG MCX Legacy (5.56 mm)", "type": "gun", "famille": "fusil", "ammo": "mun_556", "sound": "tir_fusil", "damage": 36.0, "rate": 0.075, "mag": 30, "spread": 1.2, "noise": 85.0, "reload": 2.3, "auto": true, "pellets": 1, "range": 160.0, "recoil": 0.02, "len": 0.89, "weight": 3.1},
	"ak74": {"name": "AK-74 (5.45 mm)", "type": "gun", "famille": "ak", "ammo": "mun_545", "sound": "tir_fusil", "damage": 38.0, "rate": 0.092, "mag": 30, "spread": 1.4, "noise": 88.0, "reload": 2.4, "auto": true, "pellets": 1, "range": 150.0, "recoil": 0.025, "len": 0.94, "weight": 3.4, "pitch": 0.95},
	"ak74m": {"name": "AK-74M Zenitco (5.45 mm)", "type": "gun", "famille": "ak", "ammo": "mun_545", "sound": "tir_fusil", "damage": 38.0, "rate": 0.092, "mag": 30, "spread": 1.25, "noise": 88.0, "reload": 2.4, "auto": true, "pellets": 1, "range": 160.0, "recoil": 0.022, "len": 0.91, "weight": 3.6, "pitch": 0.95},
	"draco": {"name": "Mini Draco (7.62×39)", "type": "gun", "famille": "ak", "ammo": "mun_762x39", "sound": "tir_fusil", "damage": 42.0, "rate": 0.1, "mag": 30, "spread": 2.4, "noise": 95.0, "reload": 2.3, "auto": true, "pellets": 1, "range": 90.0, "recoil": 0.04, "len": 0.44, "weight": 2.4, "pitch": 0.88},
	"uar10": {"name": "UAR-10 (7.62×51, semi-auto)", "type": "gun", "famille": "dmr", "ammo": "mun_762", "sound": "tir_fusil", "damage": 62.0, "rate": 0.22, "mag": 20, "spread": 0.5, "noise": 95.0, "reload": 2.6, "auto": false, "pellets": 1, "range": 250.0, "recoil": 0.045, "len": 1.03, "weight": 4.5, "pitch": 0.85, "perforant": 1},
	"mcx_spear": {"name": "SIG MCX Spear (7.62 mm)", "type": "gun", "famille": "dmr", "ammo": "mun_762", "sound": "tir_fusil", "damage": 55.0, "rate": 0.085, "mag": 20, "spread": 1.0, "noise": 95.0, "reload": 2.5, "auto": true, "pellets": 1, "range": 220.0, "recoil": 0.035, "len": 0.96, "weight": 4.2, "pitch": 0.85},
	"spear_assaulter": {"name": "SIG Spear Assaulter (7.62 mm)", "type": "gun", "famille": "dmr", "ammo": "mun_762", "sound": "tir_fusil", "damage": 52.0, "rate": 0.085, "mag": 20, "spread": 1.3, "noise": 98.0, "reload": 2.4, "auto": true, "pellets": 1, "range": 160.0, "recoil": 0.04, "len": 0.81, "weight": 3.9, "pitch": 0.85},
	"c14": {"name": "PGW C14 Timberwolf (.338 Lapua)", "type": "gun", "famille": "sniper", "ammo": "mun_338", "sound": "tir_fusil", "damage": 160.0, "rate": 1.3, "mag": 5, "spread": 0.1, "noise": 115.0, "reload": 3.0, "auto": false, "pellets": 1, "range": 400.0, "recoil": 0.1, "len": 1.23, "weight": 7.0, "pitch": 0.7, "verrou": true, "perforant": 3},
	"l96": {"name": "L96A1 (7.62×51)", "type": "gun", "famille": "sniper", "ammo": "mun_762", "sound": "tir_fusil", "damage": 120.0, "rate": 1.2, "mag": 10, "spread": 0.15, "noise": 105.0, "reload": 2.8, "auto": false, "pellets": 1, "range": 350.0, "recoil": 0.08, "len": 1.18, "weight": 6.5, "pitch": 0.75, "verrou": true, "perforant": 2},
	"gepard": {"name": "Gepárd M6 Lynx (12.7 mm)", "type": "gun", "famille": "sniper", "ammo": "mun_127", "sound": "tir_fusil", "damage": 260.0, "rate": 0.9, "mag": 5, "spread": 0.2, "noise": 130.0, "reload": 3.5, "auto": false, "pellets": 1, "range": 450.0, "recoil": 0.16, "len": 1.21, "weight": 11.5, "pitch": 0.6, "perforant": 4},
	"mosin": {"name": "Mosin-Nagant 91/30 (7.62×54R)", "type": "gun", "famille": "sniper", "ammo": "mun_762r", "sound": "tir_fusil", "damage": 110.0, "rate": 1.2, "mag": 5, "spread": 0.3, "noise": 100.0, "reload": 2.5, "auto": false, "pellets": 1, "range": 300.0, "recoil": 0.08, "len": 1.24, "weight": 4.0, "pitch": 0.78, "verrou": true, "cartouches": true, "perforant": 2},
	"marlin": {"name": "Marlin 1895 (.45-70)", "type": "gun", "famille": "levier", "ammo": "mun_4570", "sound": "tir_fusil", "damage": 95.0, "rate": 0.8, "mag": 6, "spread": 0.5, "noise": 95.0, "reload": 2.5, "auto": false, "pellets": 1, "range": 150.0, "recoil": 0.09, "len": 1.14, "weight": 3.5, "pitch": 0.72, "levier": true, "cartouches": true, "perforant": 1},
	"mg5": {"name": "HK MG5 (7.62 mm, mitrailleuse)", "type": "gun", "famille": "mitrailleuse", "ammo": "mun_762", "sound": "tir_fusil", "damage": 52.0, "rate": 0.075, "mag": 100, "spread": 2.4, "noise": 100.0, "reload": 6.0, "auto": true, "pellets": 1, "range": 200.0, "recoil": 0.035, "len": 1.12, "weight": 11.0, "pitch": 0.9},
	# --- objets à lancer
	"rgd5": {"name": "Grenade RGD-5", "type": "lancer", "minuterie": 3.6, "explosion": [190.0, 6.5], "weight": 0.31, "desc": "Clic gauche : dégoupiller et lancer. Explose 3,5 s plus tard."},
	# --- vêtements / armures
	"veste_cuir": {"name": "Veste en cuir", "type": "armor", "slot": "torse", "armor": 0.1, "weight": 1.2},
	"veste_renforcee": {"name": "Veste renforcée", "type": "armor", "slot": "torse", "armor": 0.22, "weight": 2.0},
	"gilet_police": {"name": "Gilet pare-balles (police)", "type": "armor", "slot": "torse", "armor": 0.35, "weight": 3.0},
	"gilet_militaire": {"name": "Gilet tactique militaire", "type": "armor", "slot": "torse", "armor": 0.5, "weight": 4.5},
	"casque_moto": {"name": "Casque de moto", "type": "armor", "slot": "tete", "armor": 0.1, "weight": 1.2},
	"casque_police": {"name": "Casque anti-émeute", "type": "armor", "slot": "tete", "armor": 0.15, "weight": 1.4},
	"casque_militaire": {"name": "Casque militaire", "type": "armor", "slot": "tete", "armor": 0.2, "weight": 1.5},
	"sac_a_dos": {"name": "Sac à dos", "type": "armor", "slot": "dos", "capacity": 15.0, "armor": 0.0, "weight": 0.8},
	"sac_militaire": {"name": "Sac militaire", "type": "armor", "slot": "dos", "capacity": 30.0, "armor": 0.0, "weight": 1.5},
	"sac_toile": {"name": "Sac en toile", "type": "armor", "slot": "dos", "armor": 0.0, "weight": 0.4},
	"capuche_cuir": {"name": "Capuche de cuir", "type": "armor", "slot": "tete", "armor": 0.06, "weight": 0.5},
	"sac_chasse": {"name": "Sac de chasse en cuir", "type": "armor", "slot": "dos", "capacity": 20.0, "armor": 0.0, "weight": 1.0},
	# --- équipement porté visible (modèles 3D : outils/godot/normaliser_equipement.gd)
	"casque_chantier": {"name": "Casque de chantier", "type": "armor", "slot": "tete", "armor": 0.08, "weight": 0.5, "desc": "Coque en plastique rigide."},
	"casquette": {"name": "Casquette", "type": "armor", "slot": "tete", "armor": 0.01, "weight": 0.1},
	"casquette_police": {"name": "Casquette de police", "type": "armor", "slot": "tete", "armor": 0.03, "weight": 0.15},
	"bonnet": {"name": "Bonnet", "type": "armor", "slot": "tete", "armor": 0.02, "weight": 0.1},
	"masque_gaz": {"name": "Masque à gaz", "type": "armor", "slot": "visage", "armor": 0.05, "weight": 0.8, "desc": "Protège le visage des morsures et des éclaboussures."},
	"lunettes": {"name": "Lunettes de protection", "type": "armor", "slot": "visage", "armor": 0.02, "weight": 0.1, "desc": "Protègent les yeux des éclats."},
	"sac_randonnee": {"name": "Sac de randonnée", "type": "armor", "slot": "dos", "capacity": 25.0, "armor": 0.0, "weight": 1.3, "desc": "Grand sac avec un tapis de sol roulé."},
	"sac_sport": {"name": "Sac de sport", "type": "armor", "slot": "dos", "capacity": 10.0, "armor": 0.0, "weight": 0.6, "desc": "Porté en bandoulière dans le dos."},
	# --- objets à placer (base)
	"etabli": {"name": "Établi (à placer)", "type": "placeable", "weight": 6.0},
	"feu_camp": {"name": "Feu de camp (à placer)", "type": "placeable", "weight": 3.0, "desc": "Station de cuisson. Se pose dehors comme dedans."},
	"plan_couture": {"name": "Plan de couture (à placer)", "type": "placeable", "weight": 5.0, "desc": "Station pour coudre les vêtements, sacs et cuirs."},
	"barricade": {"name": "Barricade (à placer)", "type": "placeable", "weight": 4.0},
	"caisse_stockage": {"name": "Caisse de stockage (à placer)", "type": "placeable", "weight": 4.0},
	"piques": {"name": "Piques en bois (piège à placer)", "type": "placeable", "weight": 5.0},
	"barbeles": {"name": "Barbelés (piège à placer)", "type": "placeable", "weight": 4.0},
	"projecteur": {"name": "Projecteur (à placer)", "type": "placeable", "weight": 4.0},
	"lit": {"name": "Lit de camp (à placer)", "type": "placeable", "weight": 6.0, "desc": "À poser dans ta base : [F] la nuit pour dormir jusqu'au matin, si aucun zombie ne rôde."},
	"torche": {"name": "Torche (à planter)", "type": "placeable", "weight": 0.5, "desc": "Se plante n'importe où : éclaire les alentours la nuit."},
	"collet": {"name": "Collet à lapin (piège à placer)", "type": "placeable", "weight": 0.2, "desc": "À poser dehors, loin de la ville : un lapin s'y prend au bout de quelques minutes si personne ne rôde autour."},
	"piege_machoires": {"name": "Piège à mâchoires (à placer)", "type": "placeable", "weight": 3.0, "desc": "Se referme sur le premier zombie qui marche dessus : grosse blessure, immobilisé 7 s. [F] pour le réarmer."},
	"recuperateur_eau": {"name": "Récupérateur d'eau de pluie (à placer)", "type": "placeable", "weight": 5.0, "desc": "À poser dehors : se remplit quand il pleut (jusqu'à 4 bouteilles d'eau)."},
	"sechoir": {"name": "Séchoir à viande (à placer)", "type": "placeable", "weight": 4.0, "desc": "[F] pour y suspendre la viande crue : elle sèche en quelques minutes (moins vite sous la pluie)."},
	# accessoires d'armes (vue d'inspection : touche T) — modèles D_U
	"point_rouge": {"name": "Point rouge Holosun HS403R", "type": "accessoire", "desc": "Viseur point rouge compact : visée bien plus précise."},
	"viseur_reflex": {"name": "Viseur reflex Holosun 510C", "type": "accessoire", "desc": "Viseur ouvert à large fenêtre (va aussi sur les pistolets à plaque optique)."},
	"viseur_aimpoint": {"name": "Aimpoint CompM4", "type": "accessoire", "desc": "Point rouge à tube, très robuste : visée précise."},
	"viseur_holo": {"name": "Viseur holographique EOTech EXPS3", "type": "accessoire", "desc": "Réticule holographique : visée rapide et précise."},
	"viseur_xps2": {"name": "Viseur holographique EOTech XPS2", "type": "accessoire", "desc": "Holographique compact."},
	"viseur_uh1": {"name": "Viseur holographique Vortex UH-1", "type": "accessoire", "desc": "Holographique à grande fenêtre."},
	"viseur_pk": {"name": "Point rouge Vzor-1 (rail latéral AK)", "type": "accessoire", "desc": "Point rouge russe pour AK."},
	"lunette": {"name": "Lunette Vortex Razor 1-6×24", "type": "accessoire", "desc": "Lunette à faible grossissement (×4) : polyvalente."},
	"lunette_uar": {"name": "Lunette tactique 3-9×", "type": "accessoire", "desc": "Lunette ×6 pour tir à moyenne distance."},
	"lunette_hawke": {"name": "Lunette Hawke Endurance", "type": "accessoire", "desc": "Lunette de précision ×8."},
	"lunette_sb": {"name": "Lunette Schmidt & Bender 5-25×56", "type": "accessoire", "desc": "Lunette de tireur d'élite ×12 : pour les très longues distances."},
	"silencieux": {"name": "Silencieux 5.56 mm", "type": "accessoire", "desc": "Bouche : tirs beaucoup moins bruyants (fusils 5.56 / 5.45)."},
	"silencieux_socom": {"name": "Silencieux SureFire SOCOM RC2", "type": "accessoire", "desc": "Silencieux 5.56 haut de gamme : encore plus discret."},
	"silencieux_9mm": {"name": "Silencieux 9 mm", "type": "accessoire", "desc": "Bouche : pistolets et pistolets-mitrailleurs (canon fileté)."},
	"silencieux_mp7": {"name": "Silencieux MP7", "type": "accessoire", "desc": "Silencieux dédié au MP7."},
	"silencieux_762": {"name": "Silencieux 7.62 mm", "type": "accessoire", "desc": "Bouche : fusils 7.62 et fusils de précision."},
	"silencieux_slx": {"name": "Silencieux SLX (Spear)", "type": "accessoire", "desc": "Silencieux dédié aux SIG Spear."},
	"frein_9mm": {"name": "Compensateur 9 mm", "type": "accessoire", "desc": "Bouche : moins de recul."},
	"frein_556": {"name": "Frein de bouche 5.56 mm", "type": "accessoire", "desc": "Bouche : beaucoup moins de recul, un peu plus de bruit."},
	"frein_762": {"name": "Frein de bouche 7.62 mm", "type": "accessoire", "desc": "Bouche : beaucoup moins de recul, un peu plus de bruit."},
	"chargeur_etendu": {"name": "Chargeur grande capacité", "type": "accessoire", "desc": "Chargeur : +60 % de munitions (pas de modèle), rechargement un peu plus long."},
	"laser": {"name": "Module laser-lampe AN/PEQ-15", "type": "accessoire", "desc": "Rail du dessus : laser (tir à la hanche plus précis) et lampe (touche L)."},
	"poignee": {"name": "Poignée verticale Magpul RVG", "type": "accessoire", "desc": "Sous le garde-main : moins de recul, la main gauche la tient."},
	"poignee_rk1": {"name": "Poignée RK-1", "type": "accessoire", "desc": "Poignée d'AK : moins de recul."},
}

# Taille dans l'inventaire (largeur, hauteur en cases). Par défaut 1×1.
const SIZES := {
	"eau": [1, 2], "ration": [1, 2], "trousse": [2, 2], "alcool": [1, 2], "planche": [1, 3], "cuir": [2, 1],
	"matraque": [1, 3], "machette": [1, 3], "batte": [1, 4], "batte_cloutee": [1, 4], "hache": [1, 4], "pioche": [2, 4],
	"buche": [1, 2], "pneu": [2, 2], "batterie": [2, 1],
	"veste_cuir": [2, 2], "veste_renforcee": [2, 3], "gilet_police": [2, 3], "gilet_militaire": [3, 3],
	"casque_moto": [2, 2], "casque_police": [2, 2], "casque_militaire": [2, 2],
	"sac_toile": [2, 2], "sac_a_dos": [3, 3], "sac_militaire": [3, 4], "sac_chasse": [3, 3], "capuche_cuir": [2, 2],
	"casque_chantier": [2, 2], "casquette": [2, 1], "casquette_police": [2, 1], "bonnet": [1, 1], "masque_gaz": [2, 2], "lunettes": [2, 1], "sac_randonnee": [3, 4], "sac_sport": [3, 2], "ragout": [1, 2], "bouillon": [1, 2],
	"etabli": [3, 2], "feu_camp": [2, 2], "plan_couture": [3, 2], "barricade": [2, 3], "caisse_stockage": [2, 2], "ciment": [2, 2], "marteau": [1, 2], "essence": [2, 2], "piece_auto": [2, 1], "cle_molette": [1, 2], "piques": [2, 2], "barbeles": [2, 2], "projecteur": [1, 3], "torche": [1, 3], "lit": [2, 3],
	"couteau_km2000": [1, 2], "arc": [1, 4], "peau": [2, 2], "viande_crue": [1, 1],
	"glock19": [2, 1], "mr920": [2, 1], "m45a1": [2, 1], "desert_eagle": [2, 2],
	"mp5k": [3, 2], "mp7": [2, 2], "benelli_m4": [5, 1], "toz34": [5, 1],
	"m4a1": [4, 2], "m5_scw": [3, 2], "urgi": [4, 2], "lr300": [4, 2], "mcx": [4, 2],
	"ak74": [4, 2], "ak74m": [4, 2], "draco": [2, 2], "uar10": [5, 2], "mcx_spear": [5, 2], "spear_assaulter": [4, 2],
	"c14": [6, 2], "l96": [6, 2], "gepard": [6, 2], "mosin": [6, 1], "marlin": [5, 1], "mg5": [6, 2],
	"lunette": [2, 1], "lunette_uar": [2, 1], "lunette_hawke": [2, 1], "lunette_sb": [2, 1], "viseur_aimpoint": [1, 1],
	"silencieux": [2, 1], "silencieux_socom": [2, 1], "silencieux_9mm": [2, 1], "silencieux_mp7": [2, 1], "silencieux_762": [2, 1], "silencieux_slx": [2, 1],
	"chargeur_etendu": [1, 2], "poignee": [1, 1], "poignee_rk1": [1, 1], "laser": [1, 1],
}

# Quantité maximale par case (piles). Par défaut 1.
const STACKS := {
	"mun_9mm": 60, "mun_556": 60, "mun_12": 24, "mun_45": 40, "mun_50ae": 28, "mun_46": 60, "mun_545": 60, "mun_762x39": 60,
	"mun_762": 40, "mun_762r": 40, "mun_338": 20, "mun_127": 10, "mun_4570": 20, "fleche": 20, "plume": 20, "viande_crue": 4, "peau": 2, "os": 6, "graisse": 4, "viande_cuite": 4, "medicament": 5, "collet": 5, "rgd5": 3, "clous": 50, "tissu": 10, "ferraille": 5, "planche": 4, "ruban": 3,
	"poudre": 10, "cuir": 3, "piece_auto": 3, "buche": 4, "pierre": 10, "minerai": 10, "bandage": 5, "antidouleur": 5, "barre": 4, "soda": 2, "conserve": 2,
}

# Grille de rangement apportée par les vêtements et sacs (largeur, hauteur).
const GRIDS := {
	"sac_toile": [4, 3], "sac_a_dos": [6, 5], "sac_militaire": [7, 7], "sac_chasse": [5, 5], "sac_randonnee": [6, 6], "sac_sport": [5, 3],
	"veste_cuir": [4, 2], "veste_renforcee": [4, 2], "gilet_police": [5, 2], "gilet_militaire": [6, 3],
}

# Icônes (images) : res://icones/<id>.png ou .svg
const CATEGORY_COLORS := {
	"food": Color(0.95, 0.75, 0.45), "drink": Color(0.55, 0.8, 1.0), "heal": Color(1.0, 0.45, 0.45),
	"material": Color(0.82, 0.8, 0.75), "ammo": Color(0.95, 0.82, 0.4), "armor": Color(0.6, 0.85, 0.55),
	"placeable": Color(0.85, 0.65, 0.4), "melee": Color(0.85, 0.85, 0.9), "gun": Color(0.85, 0.85, 0.9),
	"accessoire": Color(0.7, 0.8, 0.95), "lancer": Color(0.95, 0.6, 0.4), "outil": Color(0.95, 0.75, 0.35), "arc": Color(0.85, 0.72, 0.5),
}

# Catégories de l'arbre des recettes (ordre d'affichage) et stations de fabrication.
const CATEGORIES_FAB := [["outils", "Outils et matériaux"], ["armes", "Armes"], ["munitions", "Munitions"], ["soins", "Soins"], ["nourriture", "Nourriture"], ["vetements", "Vêtements"], ["construction", "Construction"]]
const STATIONS := {"": "à la main", "etabli": "Établi", "feu": "Feu de camp ou brasero", "couture": "Plan de couture"}

# cat : catégorie ; station : "" (à la main), "etabli", "feu", "couture" ;
# duree : secondes par objet (raccourcie par le niveau de fabrication) ; niv : niveau de fabrication requis
const RECIPES := [
	{"out": "bandage", "qty": 1, "needs": {"tissu": 2}, "cat": "soins", "station": "", "duree": 2.0, "niv": 0},
	# --- recettes de fortune, à la main, sans station
	{"out": "fleche", "qty": 2, "needs": {"planche": 1}, "cat": "munitions", "station": "", "duree": 6.0, "niv": 0},
	{"out": "torche", "qty": 1, "needs": {"planche": 1, "tissu": 1, "alcool": 1}, "cat": "outils", "station": "", "duree": 3.0, "niv": 0},
	{"out": "torche", "qty": 1, "needs": {"buche": 1, "tissu": 1, "graisse": 1}, "cat": "outils", "station": "", "duree": 3.0, "niv": 0},
	{"out": "trousse", "qty": 1, "needs": {"bandage": 2, "alcool": 1, "antidouleur": 1}, "cat": "soins", "station": "etabli", "duree": 6.0, "niv": 2},
	{"out": "etabli", "qty": 1, "needs": {"planche": 4, "clous": 6, "ferraille": 2}, "cat": "construction", "station": "", "duree": 8.0, "niv": 0},
	{"out": "feu_camp", "qty": 1, "needs": {"planche": 2, "tissu": 1}, "cat": "construction", "station": "", "duree": 4.0, "niv": 0},
	{"out": "plan_couture", "qty": 1, "needs": {"planche": 3, "clous": 4, "tissu": 2}, "cat": "construction", "station": "", "duree": 6.0, "niv": 1},
	{"out": "barricade", "qty": 1, "needs": {"planche": 3, "clous": 4}, "cat": "construction", "station": "", "duree": 5.0, "niv": 0},
	{"out": "piques", "qty": 1, "needs": {"planche": 3, "clous": 2}, "cat": "construction", "station": "", "duree": 5.0, "niv": 0},
	{"out": "lit", "qty": 1, "needs": {"planche": 4, "clous": 4, "tissu": 4}, "cat": "construction", "station": "etabli", "duree": 8.0, "niv": 0},
	{"out": "recuperateur_eau", "qty": 1, "needs": {"ferraille": 3, "tissu": 2, "planche": 2}, "cat": "construction", "station": "etabli", "duree": 8.0, "niv": 1},
	{"out": "sechoir", "qty": 1, "needs": {"planche": 4, "clous": 2}, "cat": "construction", "station": "", "duree": 6.0, "niv": 0},
	{"out": "piege_machoires", "qty": 1, "needs": {"ferraille": 5, "clous": 3}, "cat": "construction", "station": "etabli", "duree": 8.0, "niv": 2},
	{"out": "caisse_stockage", "qty": 1, "needs": {"planche": 4, "clous": 4}, "cat": "construction", "station": "etabli", "duree": 6.0, "niv": 0},
	{"out": "barbeles", "qty": 1, "needs": {"ferraille": 4, "clous": 2}, "cat": "construction", "station": "etabli", "duree": 6.0, "niv": 1},
	{"out": "projecteur", "qty": 1, "needs": {"ferraille": 3, "ruban": 1, "tissu": 1}, "cat": "construction", "station": "etabli", "duree": 8.0, "niv": 3},
	{"out": "marteau", "qty": 1, "needs": {"ferraille": 2, "planche": 1}, "cat": "outils", "station": "", "duree": 4.0, "niv": 0},
	{"out": "ferraille", "qty": 2, "needs": {"piece_auto": 1}, "cat": "outils", "station": "", "duree": 3.0, "niv": 0},
	# --- ressources récoltées (bûches, pierres, minerai, pièces d'épaves)
	{"out": "planche", "qty": 3, "needs": {"buche": 1}, "cat": "outils", "station": "etabli", "duree": 5.0, "niv": 0},
	{"out": "planche", "qty": 1, "needs": {"buche": 1}, "cat": "outils", "station": "", "duree": 8.0, "niv": 0},
	{"out": "ferraille", "qty": 2, "needs": {"minerai": 2, "buche": 1}, "cat": "outils", "station": "feu", "duree": 12.0, "niv": 2},
	{"out": "ciment", "qty": 1, "needs": {"pierre": 4, "eau": 1}, "cat": "construction", "station": "etabli", "duree": 10.0, "niv": 2},
	{"out": "pioche", "qty": 1, "needs": {"ferraille": 4, "buche": 1, "ruban": 1}, "cat": "armes", "station": "etabli", "duree": 14.0, "niv": 2},
	{"out": "hache", "qty": 1, "needs": {"ferraille": 3, "buche": 1, "ruban": 1}, "cat": "armes", "station": "etabli", "duree": 12.0, "niv": 1},
	{"out": "feu_camp", "qty": 1, "needs": {"buche": 2, "pierre": 3}, "cat": "construction", "station": "", "duree": 4.0, "niv": 0},
	{"out": "barricade", "qty": 1, "needs": {"pneu": 2, "planche": 1}, "cat": "construction", "station": "", "duree": 5.0, "niv": 0},
	{"out": "projecteur", "qty": 1, "needs": {"batterie": 1, "ferraille": 2, "ruban": 1}, "cat": "construction", "station": "etabli", "duree": 8.0, "niv": 2},
	{"out": "fleche", "qty": 4, "needs": {"planche": 1, "plume": 2, "pierre": 1}, "cat": "munitions", "station": "", "duree": 6.0, "niv": 1},
	{"out": "batte_cloutee", "qty": 1, "needs": {"batte": 1, "clous": 6, "ruban": 1}, "cat": "armes", "station": "etabli", "duree": 5.0, "niv": 1},
	{"out": "arc", "qty": 1, "needs": {"planche": 2, "cuir": 1, "tissu": 2}, "cat": "armes", "station": "etabli", "duree": 12.0, "niv": 2},
	{"out": "fleche", "qty": 5, "needs": {"planche": 1, "plume": 2, "ferraille": 1}, "cat": "munitions", "station": "", "duree": 5.0, "niv": 1},
	{"out": "fleche", "qty": 4, "needs": {"planche": 1, "tissu": 1, "ferraille": 1}, "cat": "munitions", "station": "", "duree": 5.0, "niv": 1},
	{"out": "veste_cuir", "qty": 1, "needs": {"cuir": 3, "tissu": 2}, "cat": "vetements", "station": "couture", "duree": 10.0, "niv": 1},
	{"out": "sac_a_dos", "qty": 1, "needs": {"tissu": 6, "ruban": 1}, "cat": "vetements", "station": "couture", "duree": 10.0, "niv": 2},
	{"out": "veste_renforcee", "qty": 1, "needs": {"veste_cuir": 1, "ferraille": 3, "ruban": 2}, "cat": "vetements", "station": "etabli", "duree": 10.0, "niv": 3},
	# --- chasse et cuisine (feu de camp ou brasero)
	{"out": "viande_cuite", "qty": 1, "needs": {"viande_crue": 1}, "cat": "nourriture", "station": "feu", "duree": 8.0, "niv": 0},
	{"out": "bouillon", "qty": 1, "needs": {"os": 2, "eau": 1}, "cat": "nourriture", "station": "feu", "duree": 10.0, "niv": 1},
	{"out": "ragout", "qty": 1, "needs": {"viande_cuite": 2, "conserve": 1, "eau": 1}, "cat": "nourriture", "station": "feu", "duree": 14.0, "niv": 2},
	{"out": "cuir", "qty": 1, "needs": {"peau": 2, "graisse": 1}, "cat": "vetements", "station": "feu", "duree": 15.0, "niv": 1},
	{"out": "bonnet", "qty": 1, "needs": {"tissu": 2}, "cat": "vetements", "station": "couture", "duree": 6.0, "niv": 0},
	{"out": "sac_sport", "qty": 1, "needs": {"tissu": 4, "ruban": 1}, "cat": "vetements", "station": "couture", "duree": 10.0, "niv": 0},
	{"out": "sac_randonnee", "qty": 1, "needs": {"sac_a_dos": 1, "cuir": 2, "tissu": 3}, "cat": "vetements", "station": "couture", "duree": 16.0, "niv": 2},
	{"out": "capuche_cuir", "qty": 1, "needs": {"cuir": 2, "tissu": 1}, "cat": "vetements", "station": "couture", "duree": 8.0, "niv": 1},
	{"out": "sac_chasse", "qty": 1, "needs": {"cuir": 4, "tissu": 2}, "cat": "vetements", "station": "couture", "duree": 14.0, "niv": 2},
	{"out": "fleche", "qty": 5, "needs": {"planche": 1, "plume": 2, "os": 1}, "cat": "munitions", "station": "", "duree": 6.0, "niv": 1},
	{"out": "collet", "qty": 2, "needs": {"ferraille": 1, "planche": 1}, "cat": "outils", "station": "", "duree": 4.0, "niv": 1},
	{"out": "mun_9mm", "qty": 10, "needs": {"poudre": 1, "ferraille": 1}, "cat": "munitions", "station": "etabli", "duree": 6.0, "niv": 2},
	{"out": "mun_12", "qty": 5, "needs": {"poudre": 1, "ferraille": 1}, "cat": "munitions", "station": "etabli", "duree": 6.0, "niv": 2},
	{"out": "mun_45", "qty": 8, "needs": {"poudre": 1, "ferraille": 1}, "cat": "munitions", "station": "etabli", "duree": 6.0, "niv": 3},
	{"out": "mun_556", "qty": 10, "needs": {"poudre": 2, "ferraille": 1}, "cat": "munitions", "station": "etabli", "duree": 7.0, "niv": 4},
	{"out": "mun_545", "qty": 10, "needs": {"poudre": 2, "ferraille": 1}, "cat": "munitions", "station": "etabli", "duree": 7.0, "niv": 4},
	{"out": "mun_762", "qty": 8, "needs": {"poudre": 2, "ferraille": 1}, "cat": "munitions", "station": "etabli", "duree": 8.0, "niv": 5},
]

# Tables de loot : [id, poids, min, max]
const LOOT := {
	"maison": [["casquette", 1.5, 1, 1], ["bonnet", 1.5, 1, 1], ["sac_sport", 1, 1, 1], ["conserve", 10, 1, 2], ["eau", 9, 1, 2], ["soda", 6, 1, 2], ["barre", 6, 1, 3], ["tissu", 10, 1, 3], ["bandage", 6, 1, 2], ["antidouleur", 3, 1, 1], ["alcool", 3, 1, 1], ["batte", 3, 1, 1], ["couteau_km2000", 1, 1, 1], ["planche", 4, 1, 2], ["clous", 4, 3, 8], ["ruban", 4, 1, 1], ["veste_cuir", 1, 1, 1], ["sac_a_dos", 1, 1, 1], ["casque_moto", 1, 1, 1], ["mun_9mm", 1, 3, 8], ["mun_12", 0.8, 2, 5], ["glock19", 0.3, 1, 1], ["m45a1", 0.15, 1, 1]],
	"magasin": [["casquette", 2, 1, 1], ["bonnet", 2, 1, 1], ["lunettes", 1, 1, 1], ["sac_sport", 1.5, 1, 1], ["conserve", 12, 1, 3], ["eau", 12, 1, 3], ["soda", 10, 1, 3], ["barre", 10, 1, 4], ["tissu", 6, 1, 3], ["sac_a_dos", 2, 1, 1], ["ruban", 3, 1, 2], ["alcool", 4, 1, 1], ["cuir", 2, 1, 2], ["batte", 1, 1, 1]],
	"bureau": [["barre", 6, 1, 2], ["soda", 6, 1, 1], ["eau", 5, 1, 1], ["ruban", 5, 1, 2], ["tissu", 4, 1, 2], ["antidouleur", 3, 1, 1], ["ferraille", 3, 1, 1], ["mun_9mm", 0.5, 2, 6]],
	"quincaillerie": [["casque_chantier", 3, 1, 1], ["lunettes", 3, 1, 1], ["masque_gaz", 1, 1, 1], ["planche", 12, 2, 4], ["clous", 12, 6, 15], ["ferraille", 10, 1, 3], ["ruban", 8, 1, 2], ["hache", 2, 1, 1], ["pioche", 1.5, 1, 1], ["machette", 2, 1, 1], ["batte", 2, 1, 1], ["ciment", 5, 1, 2], ["marteau", 2, 1, 1]],
	"hopital": [["masque_gaz", 1, 1, 1], ["medicament", 6, 1, 2], ["bandage", 12, 1, 3], ["trousse", 5, 1, 1], ["antidouleur", 10, 1, 2], ["alcool", 8, 1, 1], ["tissu", 8, 2, 4], ["eau", 4, 1, 1]],
	"pharmacie": [["medicament", 8, 1, 2], ["bandage", 12, 1, 3], ["antidouleur", 12, 1, 3], ["trousse", 6, 1, 1], ["alcool", 5, 1, 1], ["tissu", 4, 1, 2], ["eau", 3, 1, 1], ["soda", 2, 1, 1], ["barre", 2, 1, 1]],
	"garage": [["lunettes", 2, 1, 1], ["casque_chantier", 1, 1, 1], ["ferraille", 12, 1, 3], ["piece_auto", 10, 1, 2], ["ruban", 8, 1, 2], ["essence", 5, 1, 1], ["cle_molette", 3, 1, 1], ["clous", 5, 3, 10], ["marteau", 1.5, 1, 1], ["batte", 1, 1, 1], ["soda", 2, 1, 1]],
	"bar": [["alcool", 12, 1, 2], ["soda", 10, 1, 3], ["eau", 7, 1, 2], ["conserve", 6, 1, 2], ["barre", 5, 1, 2], ["tissu", 2, 1, 2], ["batte", 0.8, 1, 1]],
	"armurerie": [["mun_9mm", 12, 8, 20], ["mun_45", 6, 6, 14], ["mun_12", 10, 4, 10], ["mun_50ae", 2, 4, 10], ["mun_4570", 3, 4, 10], ["mun_762r", 3, 5, 15], ["mun_762", 2, 5, 12], ["mun_556", 3, 10, 20], ["poudre", 8, 1, 3], ["couteau_km2000", 2, 1, 1], ["machette", 3, 1, 1],
		["glock19", 2, 1, 1], ["mr920", 1.5, 1, 1], ["m45a1", 1.5, 1, 1], ["desert_eagle", 0.6, 1, 1], ["toz34", 1.2, 1, 1], ["benelli_m4", 0.8, 1, 1], ["marlin", 1, 1, 1], ["mosin", 0.8, 1, 1], ["lr300", 0.5, 1, 1],
		["point_rouge", 1.5, 1, 1], ["viseur_reflex", 1.5, 1, 1], ["viseur_aimpoint", 1, 1, 1], ["lunette", 0.8, 1, 1], ["lunette_hawke", 0.5, 1, 1], ["silencieux_9mm", 0.8, 1, 1], ["frein_9mm", 1, 1, 1], ["chargeur_etendu", 1.5, 1, 1], ["poignee", 1, 1, 1], ["laser", 0.6, 1, 1]],
	"police": [["casquette_police", 4, 1, 1], ["masque_gaz", 1.5, 1, 1], ["mun_9mm", 12, 6, 18], ["mun_45", 4, 4, 10], ["mun_12", 8, 3, 8], ["mun_556", 4, 5, 15], ["matraque", 5, 1, 1], ["glock19", 3, 1, 1], ["mr920", 1.5, 1, 1], ["m45a1", 1.5, 1, 1], ["mp5k", 1, 1, 1], ["benelli_m4", 1.2, 1, 1], ["m4a1", 0.6, 1, 1],
		["gilet_police", 3, 1, 1], ["casque_police", 3, 1, 1], ["bandage", 5, 1, 2], ["barre", 4, 1, 2], ["laser", 1.5, 1, 1], ["point_rouge", 1.2, 1, 1], ["chargeur_etendu", 1.2, 1, 1], ["silencieux_9mm", 0.5, 1, 1], ["rgd5", 0.5, 1, 1]],
	"militaire": [["masque_gaz", 3, 1, 1], ["lunettes", 1.5, 1, 1], ["mun_556", 10, 10, 30], ["mun_545", 7, 10, 30], ["mun_762", 6, 8, 20], ["mun_9mm", 5, 10, 20], ["mun_46", 2, 10, 30], ["ration", 10, 1, 2], ["eau", 6, 1, 2], ["trousse", 4, 1, 1], ["gilet_militaire", 2, 1, 1], ["casque_militaire", 3, 1, 1], ["sac_militaire", 2, 1, 1], ["poudre", 4, 1, 3], ["machette", 2, 1, 1], ["couteau_km2000", 2, 1, 1],
		["m4a1", 1.2, 1, 1], ["ak74", 1, 1, 1], ["m5_scw", 0.8, 1, 1], ["mp7", 0.6, 1, 1], ["rgd5", 3, 1, 2],
		["viseur_holo", 1.5, 1, 1], ["viseur_xps2", 1.2, 1, 1], ["viseur_uh1", 1, 1, 1], ["viseur_pk", 1, 1, 1], ["lunette", 1, 1, 1], ["poignee", 1.5, 1, 1], ["poignee_rk1", 1, 1, 1], ["chargeur_etendu", 2, 1, 1], ["frein_556", 1.2, 1, 1], ["silencieux", 0.8, 1, 1], ["laser", 1.2, 1, 1]],
	"armurerie_mil": [["mun_556", 12, 20, 45], ["mun_545", 8, 20, 45], ["mun_762", 8, 15, 35], ["mun_762x39", 4, 15, 30], ["mun_338", 2, 5, 10], ["mun_127", 1, 3, 6], ["gilet_militaire", 5, 1, 1], ["casque_militaire", 5, 1, 1], ["poudre", 5, 2, 4], ["rgd5", 4, 1, 3],
		["urgi", 1.5, 1, 1], ["mcx", 1.2, 1, 1], ["ak74m", 1.2, 1, 1], ["draco", 1, 1, 1], ["uar10", 1, 1, 1], ["mcx_spear", 0.8, 1, 1], ["spear_assaulter", 0.8, 1, 1], ["l96", 0.6, 1, 1], ["c14", 0.4, 1, 1], ["mg5", 0.4, 1, 1], ["gepard", 0.2, 1, 1],
		["lunette_uar", 1.5, 1, 1], ["lunette_hawke", 1, 1, 1], ["lunette_sb", 0.6, 1, 1], ["viseur_holo", 1.5, 1, 1], ["silencieux_socom", 0.8, 1, 1], ["silencieux_762", 1, 1, 1], ["silencieux_slx", 0.6, 1, 1], ["frein_762", 1.2, 1, 1], ["silencieux_mp7", 0.6, 1, 1]],
	"station": [["soda", 10, 1, 3], ["barre", 10, 1, 3], ["eau", 8, 1, 2], ["ferraille", 6, 1, 2], ["ruban", 6, 1, 2], ["alcool", 3, 1, 1], ["batte", 1, 1, 1], ["ciment", 1.5, 1, 1]],
	"ferme": [["conserve", 8, 1, 3], ["eau", 6, 1, 2], ["planche", 10, 2, 4], ["clous", 8, 4, 10], ["ferraille", 6, 1, 3], ["hache", 3, 1, 1], ["pioche", 2, 1, 1], ["cuir", 6, 1, 3], ["tissu", 6, 1, 3], ["mun_12", 4, 2, 6], ["mun_4570", 2, 2, 6], ["mun_762r", 1.5, 3, 8], ["toz34", 0.6, 1, 1], ["marlin", 0.4, 1, 1], ["mosin", 0.3, 1, 1], ["arc", 0.6, 1, 1], ["fleche", 2, 2, 6], ["plume", 3, 2, 6]],
	"camp_bandit": [["bonnet", 2, 1, 1], ["masque_gaz", 0.5, 1, 1], ["sac_sport", 1, 1, 1], ["mun_9mm", 10, 8, 20], ["mun_12", 8, 4, 10], ["mun_45", 5, 6, 14], ["mun_545", 4, 10, 20], ["mun_762r", 4, 5, 12], ["mun_4570", 3, 4, 8],
		["bandage", 6, 1, 3], ["trousse", 2, 1, 1], ["antidouleur", 4, 1, 2], ["conserve", 6, 1, 3], ["eau", 5, 1, 2], ["alcool", 4, 1, 2],
		["ferraille", 5, 1, 3], ["poudre", 4, 1, 3], ["glock19", 1.5, 1, 1], ["mr920", 1, 1, 1], ["draco", 0.6, 1, 1], ["rgd5", 1.2, 1, 2],
		["point_rouge", 0.8, 1, 1], ["silencieux_9mm", 0.6, 1, 1], ["machette", 1.5, 1, 1], ["sac_a_dos", 1, 1, 1], ["gilet_police", 0.6, 1, 1]],
	"camping": [["sac_randonnee", 2, 1, 1], ["bonnet", 3, 1, 1], ["casquette", 2, 1, 1], ["conserve", 10, 1, 2], ["eau", 10, 1, 2], ["barre", 8, 1, 3], ["soda", 6, 1, 2], ["tissu", 8, 1, 3], ["bandage", 5, 1, 2], ["alcool", 3, 1, 1], ["couteau_km2000", 1, 1, 1], ["hache", 1.5, 1, 1], ["arc", 1.2, 1, 1], ["fleche", 4, 3, 8], ["sac_a_dos", 1.5, 1, 1], ["ruban", 3, 1, 1], ["mun_12", 0.8, 2, 4]],
	"chasseur": [["bonnet", 2, 1, 1], ["casquette", 2, 1, 1], ["mun_12", 10, 3, 8], ["mun_4570", 6, 3, 8], ["mun_762r", 5, 4, 10], ["fleche", 8, 3, 8], ["plume", 4, 2, 6], ["conserve", 6, 1, 2], ["eau", 5, 1, 2], ["cuir", 6, 1, 3], ["bandage", 4, 1, 2], ["hache", 1.5, 1, 1], ["couteau_km2000", 1.5, 1, 1], ["arc", 1.2, 1, 1], ["toz34", 0.8, 1, 1], ["marlin", 0.8, 1, 1], ["mosin", 0.6, 1, 1], ["lunette", 0.6, 1, 1]],
	"cachette": [["mun_9mm", 8, 10, 25], ["mun_556", 5, 10, 25], ["mun_12", 6, 4, 10], ["trousse", 6, 1, 2], ["medicament", 5, 1, 2], ["bandage", 8, 2, 4], ["conserve", 8, 2, 4], ["eau", 8, 2, 3], ["ration", 5, 1, 3], ["glock19", 2, 1, 1], ["m45a1", 1.2, 1, 1], ["toz34", 1.2, 1, 1], ["ak74", 0.6, 1, 1], ["m4a1", 0.5, 1, 1], ["sac_a_dos", 2, 1, 1], ["rgd5", 1.5, 1, 2], ["point_rouge", 1, 1, 1], ["silencieux_9mm", 0.8, 1, 1]],
	"grange": [["planche", 12, 2, 5], ["clous", 10, 4, 12], ["ferraille", 10, 1, 3], ["cuir", 6, 1, 2], ["hache", 3, 1, 1], ["pioche", 2, 1, 1], ["machette", 1.5, 1, 1], ["ciment", 3, 1, 2], ["ruban", 4, 1, 1], ["mun_12", 1.5, 2, 5]],
	"infeste": [["mun_9mm", 10, 6, 18], ["mun_12", 7, 3, 8], ["mun_556", 5, 6, 15], ["mun_545", 3, 6, 15], ["mun_45", 3, 4, 10], ["trousse", 4, 1, 1], ["bandage", 8, 1, 3], ["conserve", 8, 1, 3], ["eau", 8, 1, 2], ["sac_a_dos", 2, 1, 1], ["poudre", 4, 1, 3],
		["glock19", 1.2, 1, 1], ["desert_eagle", 0.5, 1, 1], ["mp5k", 0.6, 1, 1], ["toz34", 0.6, 1, 1], ["ak74", 0.4, 1, 1], ["rgd5", 1.5, 1, 2], ["point_rouge", 1, 1, 1], ["chargeur_etendu", 1, 1, 1]],
	"boss": [["mun_762", 8, 30, 60], ["mun_338", 4, 10, 20], ["mun_127", 3, 5, 10], ["gilet_militaire", 4, 1, 1], ["casque_militaire", 4, 1, 1], ["sac_militaire", 4, 1, 1], ["trousse", 6, 2, 3], ["rgd5", 5, 2, 4],
		["mg5", 3, 1, 1], ["c14", 3, 1, 1], ["gepard", 2, 1, 1], ["l96", 2, 1, 1], ["lunette_sb", 4, 1, 1], ["silencieux_762", 3, 1, 1]],
	"zombie_civil": [["casquette", 1, 1, 1], ["bonnet", 0.8, 1, 1], ["barre", 4, 1, 1], ["tissu", 6, 1, 2], ["bandage", 2, 1, 1], ["antidouleur", 1, 1, 1], ["mun_9mm", 1, 2, 5], ["alcool", 0.6, 1, 1]],
	"zombie_police": [["casquette_police", 2, 1, 1], ["mun_9mm", 10, 4, 12], ["mun_45", 3, 3, 8], ["mun_12", 3, 2, 6], ["matraque", 3, 1, 1], ["bandage", 4, 1, 1], ["casque_police", 1, 1, 1]],
	"zombie_boss": [["mun_762", 10, 20, 40], ["trousse", 6, 1, 2], ["gilet_militaire", 3, 1, 1], ["ration", 6, 1, 3], ["rgd5", 4, 1, 3], ["mg5", 2, 1, 1]],
	"zombie_militaire": [["masque_gaz", 1, 1, 1], ["mun_556", 8, 6, 20], ["mun_545", 5, 6, 20], ["ration", 5, 1, 1], ["trousse", 1.5, 1, 1], ["casque_militaire", 1, 1, 1], ["rgd5", 1.2, 1, 1]],
}


func info(id: String) -> Dictionary:
	return DB.get(id, {})


# ---------------------------------------------------------------- prix (€) chez les marchands
const PRIX := {
	"eau": 6, "soda": 5, "barre": 5, "conserve": 9, "ration": 14,
	"bandage": 10, "antidouleur": 8, "trousse": 45,
	"tissu": 2, "planche": 3, "clous": 1, "ferraille": 4, "ruban": 4, "poudre": 3, "alcool": 6, "cuir": 5, "ciment": 12,
	"marteau": 20, "arc": 120, "fleche": 3, "plume": 1, "viande_crue": 4, "peau": 4, "os": 1, "graisse": 2, "viande_cuite": 8, "bouillon": 6, "ragout": 16, "medicament": 15, "collet": 6, "sac_chasse": 90, "piece_auto": 6, "essence": 18, "buche": 2, "pierre": 1, "minerai": 4, "pneu": 5, "batterie": 25, "pioche": 45, "cle_molette": 12, "rgd5": 60, "etabli": 60, "feu_camp": 15, "plan_couture": 40, "barricade": 25, "caisse_stockage": 35, "piques": 20, "barbeles": 35, "projecteur": 45, "torche": 6, "lit": 40,
	"sac_toile": 25, "sac_a_dos": 70, "sac_militaire": 150, "sac_randonnee": 110, "sac_sport": 40, "poings": 0,
}
const PRIX_FAMILLE := {"pistolet": 180, "smg": 380, "pompe": 300, "fusil": 260, "levier": 280, "ak": 520, "dmr": 650, "sniper": 750, "mitrailleuse": 1200}
## Recul par famille d'arme (la valeur « recoil » de chaque arme reste la base) :
## haut / lat = part du recul en tangage / en lacet ; montee = vitesse à laquelle la visée monte (1/s) ;
## retour = vitesse du retour au centre (1/s) après delai (s) sans tirer ; arme_rot (rad) / arme_recul (m) = coup
## de l'arme tenue (relevée, poussée vers l'arrière) ; raideur / amort = ressort de l'arme ; secousse = caméra.
const RECUL_FAMILLE := {
	"pistolet": {"haut": 1.0, "lat": 0.35, "montee": 45.0, "retour": 8.0, "delai": 0.06, "arme_rot": 0.45, "arme_recul": 0.15, "raideur": 520.0, "amort": 34.0, "secousse": 0.8},
	"smg": {"haut": 0.75, "lat": 0.45, "montee": 30.0, "retour": 9.0, "delai": 0.045, "arme_rot": 0.3, "arme_recul": 0.12, "raideur": 320.0, "amort": 26.0, "secousse": 0.5},
	"fusil": {"haut": 0.8, "lat": 0.22, "montee": 26.0, "retour": 7.0, "delai": 0.05, "arme_rot": 0.25, "arme_recul": 0.12, "raideur": 280.0, "amort": 24.0, "secousse": 0.6},
	"ak": {"haut": 0.9, "lat": 0.35, "montee": 26.0, "retour": 6.5, "delai": 0.05, "arme_rot": 0.27, "arme_recul": 0.13, "raideur": 260.0, "amort": 22.0, "secousse": 0.7},
	"mitrailleuse": {"haut": 0.75, "lat": 0.4, "montee": 24.0, "retour": 6.0, "delai": 0.05, "arme_rot": 0.2, "arme_recul": 0.1, "raideur": 240.0, "amort": 22.0, "secousse": 0.7},
	"dmr": {"haut": 1.05, "lat": 0.3, "montee": 22.0, "retour": 5.0, "delai": 0.1, "arme_rot": 0.25, "arme_recul": 0.1, "raideur": 200.0, "amort": 18.0, "secousse": 0.9},
	"pompe": {"haut": 1.45, "lat": 0.5, "montee": 22.0, "retour": 3.2, "delai": 0.16, "arme_rot": 0.32, "arme_recul": 0.1, "raideur": 140.0, "amort": 13.0, "secousse": 1.7},
	"levier": {"haut": 1.2, "lat": 0.3, "montee": 20.0, "retour": 3.5, "delai": 0.15, "arme_rot": 0.25, "arme_recul": 0.08, "raideur": 140.0, "amort": 13.0, "secousse": 1.3},
	"sniper": {"haut": 1.25, "lat": 0.2, "montee": 18.0, "retour": 2.8, "delai": 0.22, "arme_rot": 0.22, "arme_recul": 0.075, "raideur": 120.0, "amort": 12.0, "secousse": 1.4},
}
const PRIX_MUNITION := {"mun_9mm": 1, "mun_45": 1, "mun_46": 2, "mun_12": 2, "mun_4570": 3, "mun_50ae": 3, "mun_545": 2, "mun_556": 2, "mun_762x39": 2, "mun_762": 3, "mun_762r": 2, "mun_338": 6, "mun_127": 8}


## Prix d'achat d'une unité chez un marchand.
func prix(id: String) -> int:
	if PRIX.has(id):
		return PRIX[id]
	if PRIX_MUNITION.has(id):
		return PRIX_MUNITION[id]
	var it := info(id)
	match it.get("type", ""):
		"gun":
			return PRIX_FAMILLE.get(it.get("famille", ""), 350)
		"melee":
			return int(float(it.get("damage", 20.0)) * 1.6)
		"armor":
			return int(40.0 + float(it.get("armor", 0.0)) * 500.0)
		"accessoire":
			return 90
		"food", "drink":
			return 6
		"heal":
			return 10
	return 5


## Prix de revente d'une unité (les marchands rachètent à 40 %).
## Un objet fabricable ne se revend jamais plus de 80 % du prix de ses ingrédients :
## acheter, fabriquer puis revendre ne rapporte rien (pas d'argent infini).
func prix_vente(id: String) -> int:
	var p := prix(id)
	if p <= 0:
		return 0
	var v := int(p * 0.4)
	for r in RECIPES:
		if r.out == id:
			var cout := 0.0
			for ing in r.needs:
				cout += prix(ing) * int(r.needs[ing])
			v = mini(v, int(cout * 0.8 / maxf(1.0, float(r.qty))))
	return maxi(1, v)


## Démontage : la moitié des ingrédients de la recette la moins chère qui fabrique l'objet (par lot de `qty`),
## jamais plus que ce qu'il a coûté. Ni la nourriture ni les matériaux transformés (planche, ferraille, cuir, ciment).
const PART_DEMONTAGE := 0.5
const NON_DEMONTABLES := ["planche", "ferraille", "cuir", "ciment"]


func recette_demontage(id: String) -> Dictionary:
	if id in NON_DEMONTABLES:
		return {}
	var best := {}
	var best_cout := INF
	for r in RECIPES:
		if r.out != id or r.cat == "nourriture":
			continue
		var cout := 0.0
		for ing in r.needs:
			cout += prix(ing) * int(r.needs[ing])
		cout /= float(r.qty)
		if cout < best_cout:
			best_cout = cout
			best = r
	return best


## Ce que rend le démontage, ex. « 2 ferrailles, 0–1 bûche » (une demi-unité = une chance sur deux).
func texte_demontage(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	for ing in r.needs:
		var x := float(r.needs[ing]) * PART_DEMONTAGE
		var bas := int(floor(x))
		parts.append(("%d" % bas if x == floor(x) else "%d–%d" % [bas, bas + 1]) + " " + nom(ing))
	return ", ".join(parts)


func nom(id: String) -> String:
	return info(id).get("name", id)


## Clé stable d'une recette (favoris) : produit + ingrédients.
func cle_recette(r: Dictionary) -> String:
	return "%s|%s" % [r.out, ",".join(r.needs.keys())]


func size(id: String) -> Vector2i:
	var a: Array = SIZES.get(id, [1, 1])
	return Vector2i(a[0], a[1])


func stack(id: String) -> int:
	return int(STACKS.get(id, 1))


func grid(id: String) -> Vector2i:
	var a: Array = GRIDS.get(id, [0, 0])
	return Vector2i(a[0], a[1])


func category_color(id: String) -> Color:
	return CATEGORY_COLORS.get(info(id).get("type", ""), Color(0.8, 0.8, 0.8))


var _icons := {}


func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var tex: Texture2D = null
	for ext in ["png", "svg"]:
		var p := "res://icones/%s.%s" % [id, ext]
		if ResourceLoader.exists(p):
			tex = load(p)
			break
	_icons[id] = tex
	return tex


func is_weapon(id: String) -> bool:
	var t = info(id).get("type", "")
	return t == "melee" or t == "gun" or t == "lancer" or t == "arc"


## Famille d'une arme à feu (pistolet, smg, pompe, fusil, ak, dmr, sniper, levier, mitrailleuse).
func famille(id: String) -> String:
	return str(info(id).get("famille", ""))


## Rechargement cartouche par cartouche (fusils à pompe / cassants, verrou à lame-chargeur, levier).
func a_cartouches(id: String) -> bool:
	return bool(info(id).get("cartouches", false))


## Toutes les armes à feu (mode admin, tests…).
func armes_a_feu() -> Array:
	var out := []
	for id in DB:
		if DB[id].get("type", "") == "gun":
			out.append(id)
	return out


## Tire au hasard le contenu d'un conteneur. rolls = nombre de tirages.
## Quantité de munitions trouvées (toutes les tables) : un peu rares, pour que la mêlée reste utile.
const FACTEUR_MUNITIONS := 0.7
## Argent trouvé en fouillant un meuble de cette table : [chance, min, max] (sinon 30 %, 5–25 €).
const ARGENT_TABLE := {"bar": [0.6, 8, 35], "magasin": [0.35, 5, 25], "pharmacie": [0.3, 5, 20]}


func roll_loot(table: String, rolls: int, empty_chance: float = 0.2) -> Dictionary:
	var out := {}
	if not LOOT.has(table) or randf() < empty_chance:
		return out
	var entries: Array = LOOT[table]
	var total := 0.0
	for e in entries:
		total += float(e[1])
	for r in rolls:
		var pick := randf() * total
		for e in entries:
			pick -= float(e[1])
			if pick <= 0.0:
				var n := randi_range(int(e[2]), int(e[3]))
				if info(e[0]).get("type", "") == "ammo":
					n = maxi(1, roundi(n * FACTEUR_MUNITIONS))
				out[e[0]] = int(out.get(e[0], 0)) + n
				break
	return out


func describe(found: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in found:
		parts.append("%d× %s" % [found[id], nom(id)])
	return ", ".join(parts)
