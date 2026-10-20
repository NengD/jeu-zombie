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
	"bandage": {"name": "Bandage", "type": "heal", "heal": 20.0, "weight": 0.1},
	"trousse": {"name": "Trousse de soin", "type": "heal", "heal": 60.0, "weight": 0.6},
	"antidouleur": {"name": "Antidouleurs", "type": "heal", "heal": 10.0, "weight": 0.05},
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
	# --- armes blanches
	"poings": {"name": "Poings", "type": "melee", "damage": 9.0, "rate": 0.5, "range": 1.6, "stamina": 5.0, "len": 0.0, "color": Color(0.8, 0.6, 0.5)},
	"batte": {"name": "Batte de baseball", "type": "melee", "damage": 36.0, "rate": 0.8, "range": 2.2, "stamina": 14.0, "len": 0.85, "color": Color(0.55, 0.38, 0.2), "weight": 1.0},
	"batte_cloutee": {"name": "Batte cloutée", "type": "melee", "damage": 52.0, "rate": 0.85, "range": 2.2, "stamina": 15.0, "len": 0.85, "color": Color(0.45, 0.3, 0.18), "weight": 1.2},
	"machette": {"name": "Machette", "type": "melee", "damage": 46.0, "rate": 0.6, "range": 2.0, "stamina": 11.0, "len": 0.6, "color": Color(0.6, 0.62, 0.65), "weight": 0.8},
	"hache": {"name": "Hache", "type": "melee", "damage": 65.0, "rate": 1.05, "range": 2.1, "stamina": 20.0, "len": 0.75, "color": Color(0.5, 0.15, 0.1), "weight": 1.8},
	"matraque": {"name": "Matraque", "type": "melee", "damage": 30.0, "rate": 0.55, "range": 1.9, "stamina": 9.0, "len": 0.55, "color": Color(0.1, 0.1, 0.1), "weight": 0.6},
	"couteau_km2000": {"name": "Couteau de combat KM2000", "type": "melee", "damage": 31.0, "rate": 0.4, "range": 1.7, "stamina": 7.0, "len": 0.3, "color": Color(0.2, 0.2, 0.2), "weight": 0.35},
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
	# --- objets à placer (base)
	"etabli": {"name": "Établi (à placer)", "type": "placeable", "weight": 6.0},
	"barricade": {"name": "Barricade (à placer)", "type": "placeable", "weight": 4.0},
	"caisse_stockage": {"name": "Caisse de stockage (à placer)", "type": "placeable", "weight": 4.0},
	"piques": {"name": "Piques en bois (piège à placer)", "type": "placeable", "weight": 5.0},
	"barbeles": {"name": "Barbelés (piège à placer)", "type": "placeable", "weight": 4.0},
	"projecteur": {"name": "Projecteur (à placer)", "type": "placeable", "weight": 4.0},
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
	"matraque": [1, 3], "machette": [1, 3], "batte": [1, 4], "batte_cloutee": [1, 4], "hache": [1, 4],
	"veste_cuir": [2, 2], "veste_renforcee": [2, 3], "gilet_police": [2, 3], "gilet_militaire": [3, 3],
	"casque_moto": [2, 2], "casque_police": [2, 2], "casque_militaire": [2, 2],
	"sac_toile": [2, 2], "sac_a_dos": [3, 3], "sac_militaire": [3, 4],
	"etabli": [3, 2], "barricade": [2, 3], "caisse_stockage": [2, 2], "ciment": [2, 2], "marteau": [1, 2], "piques": [2, 2], "barbeles": [2, 2], "projecteur": [1, 3],
	"couteau_km2000": [1, 2],
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
	"mun_762": 40, "mun_762r": 40, "mun_338": 20, "mun_127": 10, "mun_4570": 20, "rgd5": 3, "clous": 50, "tissu": 10, "ferraille": 5, "planche": 4, "ruban": 3,
	"poudre": 10, "cuir": 3, "bandage": 5, "antidouleur": 5, "barre": 4, "soda": 2, "conserve": 2,
}

# Grille de rangement apportée par les vêtements et sacs (largeur, hauteur).
const GRIDS := {
	"sac_toile": [4, 3], "sac_a_dos": [6, 5], "sac_militaire": [7, 7],
	"veste_cuir": [4, 2], "veste_renforcee": [4, 2], "gilet_police": [5, 2], "gilet_militaire": [6, 3],
}

# Icônes (images) : res://icones/<id>.png ou .svg
const CATEGORY_COLORS := {
	"food": Color(0.95, 0.75, 0.45), "drink": Color(0.55, 0.8, 1.0), "heal": Color(1.0, 0.45, 0.45),
	"material": Color(0.82, 0.8, 0.75), "ammo": Color(0.95, 0.82, 0.4), "armor": Color(0.6, 0.85, 0.55),
	"placeable": Color(0.85, 0.65, 0.4), "melee": Color(0.85, 0.85, 0.9), "gun": Color(0.85, 0.85, 0.9),
	"accessoire": Color(0.7, 0.8, 0.95), "lancer": Color(0.95, 0.6, 0.4), "outil": Color(0.95, 0.75, 0.35),
}

# bench = true : nécessite d'être près d'un établi
const RECIPES := [
	{"out": "bandage", "qty": 1, "needs": {"tissu": 2}, "bench": false},
	{"out": "etabli", "qty": 1, "needs": {"planche": 4, "clous": 6, "ferraille": 2}, "bench": false},
	{"out": "barricade", "qty": 1, "needs": {"planche": 3, "clous": 4}, "bench": false},
	{"out": "marteau", "qty": 1, "needs": {"ferraille": 2, "planche": 1}, "bench": false},
	{"out": "piques", "qty": 1, "needs": {"planche": 3, "clous": 2}, "bench": false},
	{"out": "barbeles", "qty": 1, "needs": {"ferraille": 4, "clous": 2}, "bench": true},
	{"out": "projecteur", "qty": 1, "needs": {"ferraille": 3, "ruban": 1, "tissu": 1}, "bench": true},
	{"out": "caisse_stockage", "qty": 1, "needs": {"planche": 4, "clous": 4}, "bench": true},
	{"out": "trousse", "qty": 1, "needs": {"bandage": 2, "alcool": 1, "antidouleur": 1}, "bench": true},
	{"out": "batte_cloutee", "qty": 1, "needs": {"batte": 1, "clous": 6, "ruban": 1}, "bench": true},
	{"out": "veste_renforcee", "qty": 1, "needs": {"veste_cuir": 1, "ferraille": 3, "ruban": 2}, "bench": true},
	{"out": "veste_cuir", "qty": 1, "needs": {"cuir": 3, "tissu": 2}, "bench": true},
	{"out": "sac_a_dos", "qty": 1, "needs": {"tissu": 6, "ruban": 1}, "bench": true},
	{"out": "mun_9mm", "qty": 10, "needs": {"poudre": 1, "ferraille": 1}, "bench": true},
	{"out": "mun_12", "qty": 5, "needs": {"poudre": 1, "ferraille": 1}, "bench": true},
	{"out": "mun_556", "qty": 10, "needs": {"poudre": 2, "ferraille": 1}, "bench": true},
	{"out": "mun_45", "qty": 8, "needs": {"poudre": 1, "ferraille": 1}, "bench": true},
	{"out": "mun_545", "qty": 10, "needs": {"poudre": 2, "ferraille": 1}, "bench": true},
	{"out": "mun_762", "qty": 8, "needs": {"poudre": 2, "ferraille": 1}, "bench": true},
]

# Tables de loot : [id, poids, min, max]
const LOOT := {
	"maison": [["conserve", 10, 1, 2], ["eau", 9, 1, 2], ["soda", 6, 1, 2], ["barre", 6, 1, 3], ["tissu", 10, 1, 3], ["bandage", 6, 1, 2], ["antidouleur", 3, 1, 1], ["alcool", 3, 1, 1], ["batte", 3, 1, 1], ["couteau_km2000", 1, 1, 1], ["planche", 4, 1, 2], ["clous", 4, 3, 8], ["ruban", 4, 1, 1], ["veste_cuir", 1, 1, 1], ["sac_a_dos", 1, 1, 1], ["casque_moto", 1, 1, 1], ["mun_9mm", 1, 3, 8], ["mun_12", 0.8, 2, 5], ["glock19", 0.3, 1, 1], ["m45a1", 0.15, 1, 1]],
	"magasin": [["conserve", 12, 1, 3], ["eau", 12, 1, 3], ["soda", 10, 1, 3], ["barre", 10, 1, 4], ["tissu", 6, 1, 3], ["sac_a_dos", 2, 1, 1], ["ruban", 3, 1, 2], ["alcool", 4, 1, 1], ["cuir", 2, 1, 2], ["batte", 1, 1, 1]],
	"bureau": [["barre", 6, 1, 2], ["soda", 6, 1, 1], ["eau", 5, 1, 1], ["ruban", 5, 1, 2], ["tissu", 4, 1, 2], ["antidouleur", 3, 1, 1], ["ferraille", 3, 1, 1], ["mun_9mm", 0.5, 2, 6]],
	"quincaillerie": [["planche", 12, 2, 4], ["clous", 12, 6, 15], ["ferraille", 10, 1, 3], ["ruban", 8, 1, 2], ["hache", 2, 1, 1], ["machette", 2, 1, 1], ["batte", 2, 1, 1], ["ciment", 5, 1, 2], ["marteau", 2, 1, 1]],
	"hopital": [["bandage", 12, 1, 3], ["trousse", 5, 1, 1], ["antidouleur", 10, 1, 2], ["alcool", 8, 1, 1], ["tissu", 8, 2, 4], ["eau", 4, 1, 1]],
	"armurerie": [["mun_9mm", 12, 8, 20], ["mun_45", 6, 6, 14], ["mun_12", 10, 4, 10], ["mun_50ae", 2, 4, 10], ["mun_4570", 3, 4, 10], ["mun_762r", 3, 5, 15], ["mun_762", 2, 5, 12], ["mun_556", 3, 10, 20], ["poudre", 8, 1, 3], ["couteau_km2000", 2, 1, 1], ["machette", 3, 1, 1],
		["glock19", 2, 1, 1], ["mr920", 1.5, 1, 1], ["m45a1", 1.5, 1, 1], ["desert_eagle", 0.6, 1, 1], ["toz34", 1.2, 1, 1], ["benelli_m4", 0.8, 1, 1], ["marlin", 1, 1, 1], ["mosin", 0.8, 1, 1], ["lr300", 0.5, 1, 1],
		["point_rouge", 1.5, 1, 1], ["viseur_reflex", 1.5, 1, 1], ["viseur_aimpoint", 1, 1, 1], ["lunette", 0.8, 1, 1], ["lunette_hawke", 0.5, 1, 1], ["silencieux_9mm", 0.8, 1, 1], ["frein_9mm", 1, 1, 1], ["chargeur_etendu", 1.5, 1, 1], ["poignee", 1, 1, 1], ["laser", 0.6, 1, 1]],
	"police": [["mun_9mm", 12, 6, 18], ["mun_45", 4, 4, 10], ["mun_12", 8, 3, 8], ["mun_556", 4, 5, 15], ["matraque", 5, 1, 1], ["glock19", 3, 1, 1], ["mr920", 1.5, 1, 1], ["m45a1", 1.5, 1, 1], ["mp5k", 1, 1, 1], ["benelli_m4", 1.2, 1, 1], ["m4a1", 0.6, 1, 1],
		["gilet_police", 3, 1, 1], ["casque_police", 3, 1, 1], ["bandage", 5, 1, 2], ["barre", 4, 1, 2], ["laser", 1.5, 1, 1], ["point_rouge", 1.2, 1, 1], ["chargeur_etendu", 1.2, 1, 1], ["silencieux_9mm", 0.5, 1, 1], ["rgd5", 0.5, 1, 1]],
	"militaire": [["mun_556", 10, 10, 30], ["mun_545", 7, 10, 30], ["mun_762", 6, 8, 20], ["mun_9mm", 5, 10, 20], ["mun_46", 2, 10, 30], ["ration", 10, 1, 2], ["eau", 6, 1, 2], ["trousse", 4, 1, 1], ["gilet_militaire", 2, 1, 1], ["casque_militaire", 3, 1, 1], ["sac_militaire", 2, 1, 1], ["poudre", 4, 1, 3], ["machette", 2, 1, 1], ["couteau_km2000", 2, 1, 1],
		["m4a1", 1.2, 1, 1], ["ak74", 1, 1, 1], ["m5_scw", 0.8, 1, 1], ["mp7", 0.6, 1, 1], ["rgd5", 3, 1, 2],
		["viseur_holo", 1.5, 1, 1], ["viseur_xps2", 1.2, 1, 1], ["viseur_uh1", 1, 1, 1], ["viseur_pk", 1, 1, 1], ["lunette", 1, 1, 1], ["poignee", 1.5, 1, 1], ["poignee_rk1", 1, 1, 1], ["chargeur_etendu", 2, 1, 1], ["frein_556", 1.2, 1, 1], ["silencieux", 0.8, 1, 1], ["laser", 1.2, 1, 1]],
	"armurerie_mil": [["mun_556", 12, 20, 45], ["mun_545", 8, 20, 45], ["mun_762", 8, 15, 35], ["mun_762x39", 4, 15, 30], ["mun_338", 2, 5, 10], ["mun_127", 1, 3, 6], ["gilet_militaire", 5, 1, 1], ["casque_militaire", 5, 1, 1], ["poudre", 5, 2, 4], ["rgd5", 4, 1, 3],
		["urgi", 1.5, 1, 1], ["mcx", 1.2, 1, 1], ["ak74m", 1.2, 1, 1], ["draco", 1, 1, 1], ["uar10", 1, 1, 1], ["mcx_spear", 0.8, 1, 1], ["spear_assaulter", 0.8, 1, 1], ["l96", 0.6, 1, 1], ["c14", 0.4, 1, 1], ["mg5", 0.4, 1, 1], ["gepard", 0.2, 1, 1],
		["lunette_uar", 1.5, 1, 1], ["lunette_hawke", 1, 1, 1], ["lunette_sb", 0.6, 1, 1], ["viseur_holo", 1.5, 1, 1], ["silencieux_socom", 0.8, 1, 1], ["silencieux_762", 1, 1, 1], ["silencieux_slx", 0.6, 1, 1], ["frein_762", 1.2, 1, 1], ["silencieux_mp7", 0.6, 1, 1]],
	"station": [["soda", 10, 1, 3], ["barre", 10, 1, 3], ["eau", 8, 1, 2], ["ferraille", 6, 1, 2], ["ruban", 6, 1, 2], ["alcool", 3, 1, 1], ["batte", 1, 1, 1], ["ciment", 1.5, 1, 1]],
	"ferme": [["conserve", 8, 1, 3], ["eau", 6, 1, 2], ["planche", 10, 2, 4], ["clous", 8, 4, 10], ["ferraille", 6, 1, 3], ["hache", 3, 1, 1], ["cuir", 6, 1, 3], ["tissu", 6, 1, 3], ["mun_12", 4, 2, 6], ["mun_4570", 2, 2, 6], ["mun_762r", 1.5, 3, 8], ["toz34", 0.6, 1, 1], ["marlin", 0.4, 1, 1], ["mosin", 0.3, 1, 1]],
	"camp_bandit": [["mun_9mm", 10, 8, 20], ["mun_12", 8, 4, 10], ["mun_45", 5, 6, 14], ["mun_545", 4, 10, 20], ["mun_762r", 4, 5, 12], ["mun_4570", 3, 4, 8],
		["bandage", 6, 1, 3], ["trousse", 2, 1, 1], ["antidouleur", 4, 1, 2], ["conserve", 6, 1, 3], ["eau", 5, 1, 2], ["alcool", 4, 1, 2],
		["ferraille", 5, 1, 3], ["poudre", 4, 1, 3], ["glock19", 1.5, 1, 1], ["mr920", 1, 1, 1], ["draco", 0.6, 1, 1], ["rgd5", 1.2, 1, 2],
		["point_rouge", 0.8, 1, 1], ["silencieux_9mm", 0.6, 1, 1], ["machette", 1.5, 1, 1], ["sac_a_dos", 1, 1, 1], ["gilet_police", 0.6, 1, 1]],
	"grange": [["planche", 12, 2, 5], ["clous", 10, 4, 12], ["ferraille", 10, 1, 3], ["cuir", 6, 1, 2], ["hache", 3, 1, 1], ["machette", 1.5, 1, 1], ["ciment", 3, 1, 2], ["ruban", 4, 1, 1], ["mun_12", 1.5, 2, 5]],
	"infeste": [["mun_9mm", 10, 6, 18], ["mun_12", 7, 3, 8], ["mun_556", 5, 6, 15], ["mun_545", 3, 6, 15], ["mun_45", 3, 4, 10], ["trousse", 4, 1, 1], ["bandage", 8, 1, 3], ["conserve", 8, 1, 3], ["eau", 8, 1, 2], ["sac_a_dos", 2, 1, 1], ["poudre", 4, 1, 3],
		["glock19", 1.2, 1, 1], ["desert_eagle", 0.5, 1, 1], ["mp5k", 0.6, 1, 1], ["toz34", 0.6, 1, 1], ["ak74", 0.4, 1, 1], ["rgd5", 1.5, 1, 2], ["point_rouge", 1, 1, 1], ["chargeur_etendu", 1, 1, 1]],
	"boss": [["mun_762", 8, 30, 60], ["mun_338", 4, 10, 20], ["mun_127", 3, 5, 10], ["gilet_militaire", 4, 1, 1], ["casque_militaire", 4, 1, 1], ["sac_militaire", 4, 1, 1], ["trousse", 6, 2, 3], ["rgd5", 5, 2, 4],
		["mg5", 3, 1, 1], ["c14", 3, 1, 1], ["gepard", 2, 1, 1], ["l96", 2, 1, 1], ["lunette_sb", 4, 1, 1], ["silencieux_762", 3, 1, 1]],
	"zombie_civil": [["barre", 4, 1, 1], ["tissu", 6, 1, 2], ["bandage", 2, 1, 1], ["antidouleur", 1, 1, 1], ["mun_9mm", 1, 2, 5], ["alcool", 0.6, 1, 1]],
	"zombie_police": [["mun_9mm", 10, 4, 12], ["mun_45", 3, 3, 8], ["mun_12", 3, 2, 6], ["matraque", 3, 1, 1], ["bandage", 4, 1, 1], ["casque_police", 1, 1, 1]],
	"zombie_boss": [["mun_762", 10, 20, 40], ["trousse", 6, 1, 2], ["gilet_militaire", 3, 1, 1], ["ration", 6, 1, 3], ["rgd5", 4, 1, 3], ["mg5", 2, 1, 1]],
	"zombie_militaire": [["mun_556", 8, 6, 20], ["mun_545", 5, 6, 20], ["ration", 5, 1, 1], ["trousse", 1.5, 1, 1], ["casque_militaire", 1, 1, 1], ["rgd5", 1.2, 1, 1]],
}


func info(id: String) -> Dictionary:
	return DB.get(id, {})


# ---------------------------------------------------------------- prix (€) chez les marchands
const PRIX := {
	"eau": 6, "soda": 5, "barre": 5, "conserve": 9, "ration": 14,
	"bandage": 10, "antidouleur": 8, "trousse": 45,
	"tissu": 2, "planche": 3, "clous": 1, "ferraille": 4, "ruban": 4, "poudre": 3, "alcool": 6, "cuir": 5, "ciment": 12,
	"marteau": 20, "rgd5": 60, "etabli": 60, "barricade": 25, "caisse_stockage": 35, "piques": 20, "barbeles": 35, "projecteur": 45,
	"sac_toile": 25, "sac_a_dos": 70, "sac_militaire": 150, "poings": 0,
}
const PRIX_FAMILLE := {"pistolet": 180, "smg": 380, "pompe": 300, "fusil": 260, "levier": 280, "ak": 520, "dmr": 650, "sniper": 750, "mitrailleuse": 1200}
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


func nom(id: String) -> String:
	return info(id).get("name", id)


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
	return t == "melee" or t == "gun" or t == "lancer"


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
