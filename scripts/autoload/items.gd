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
	# --- munitions
	"mun_9mm": {"name": "Balles 9 mm", "type": "ammo", "weight": 0.01},
	"mun_12": {"name": "Cartouches cal. 12", "type": "ammo", "weight": 0.04},
	"mun_556": {"name": "Balles 5.56 mm", "type": "ammo", "weight": 0.012},
	# --- armes blanches
	"poings": {"name": "Poings", "type": "melee", "damage": 9.0, "rate": 0.5, "range": 1.6, "stamina": 5.0, "len": 0.0, "color": Color(0.8, 0.6, 0.5)},
	"couteau": {"name": "Couteau", "type": "melee", "damage": 28.0, "rate": 0.42, "range": 1.7, "stamina": 7.0, "len": 0.3, "color": Color(0.75, 0.75, 0.8), "weight": 0.3},
	"batte": {"name": "Batte de baseball", "type": "melee", "damage": 36.0, "rate": 0.8, "range": 2.2, "stamina": 14.0, "len": 0.85, "color": Color(0.55, 0.38, 0.2), "weight": 1.0},
	"batte_cloutee": {"name": "Batte cloutée", "type": "melee", "damage": 52.0, "rate": 0.85, "range": 2.2, "stamina": 15.0, "len": 0.85, "color": Color(0.45, 0.3, 0.18), "weight": 1.2},
	"machette": {"name": "Machette", "type": "melee", "damage": 46.0, "rate": 0.6, "range": 2.0, "stamina": 11.0, "len": 0.6, "color": Color(0.6, 0.62, 0.65), "weight": 0.8},
	"machette_art": {"name": "Machette artisanale", "type": "melee", "damage": 38.0, "rate": 0.65, "range": 1.9, "stamina": 12.0, "len": 0.55, "color": Color(0.5, 0.45, 0.4), "weight": 0.9},
	"hache": {"name": "Hache", "type": "melee", "damage": 65.0, "rate": 1.05, "range": 2.1, "stamina": 20.0, "len": 0.75, "color": Color(0.5, 0.15, 0.1), "weight": 1.8},
	"pied_de_biche": {"name": "Pied-de-biche", "type": "melee", "damage": 34.0, "rate": 0.65, "range": 1.9, "stamina": 10.0, "len": 0.56, "color": Color(0.3, 0.3, 0.32), "weight": 1.5},
	"masse": {"name": "Masse", "type": "melee", "damage": 80.0, "rate": 1.4, "range": 2.2, "stamina": 28.0, "len": 0.9, "color": Color(0.3, 0.3, 0.3), "weight": 4.0},
	"cle_tuyau": {"name": "Clé à tuyau", "type": "melee", "damage": 30.0, "rate": 0.6, "range": 1.7, "stamina": 9.0, "len": 0.4, "color": Color(0.5, 0.15, 0.1), "weight": 1.2},
	"matraque": {"name": "Matraque", "type": "melee", "damage": 30.0, "rate": 0.55, "range": 1.9, "stamina": 9.0, "len": 0.55, "color": Color(0.1, 0.1, 0.1), "weight": 0.6},
	# --- armes à feu : aucune pour l'instant (les nouveaux modèles 3D vont être ajoutés).
	# Modèle d'entrée : "id": {"name": …, "type": "gun", "sound": "tir_pistolet", "damage", "rate", "mag", "ammo": "mun_9mm",
	#   "spread", "noise", "reload", "auto", "pellets", "range", "recoil", "len", "color", "weight"}
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
	# accessoires d'armes (vue d'inspection : touche T) : aucun pour l'instant
}

# Taille dans l'inventaire (largeur, hauteur en cases). Par défaut 1×1.
const SIZES := {
	"eau": [1, 2], "ration": [1, 2], "trousse": [2, 2], "alcool": [1, 2], "planche": [1, 3], "cuir": [2, 1],
	"couteau": [1, 2], "matraque": [1, 3], "machette": [1, 3], "machette_art": [1, 3], "batte": [1, 4], "batte_cloutee": [1, 4], "hache": [1, 4], "pied_de_biche": [1, 3], "masse": [1, 4], "cle_tuyau": [1, 2],
	"veste_cuir": [2, 2], "veste_renforcee": [2, 3], "gilet_police": [2, 3], "gilet_militaire": [3, 3],
	"casque_moto": [2, 2], "casque_police": [2, 2], "casque_militaire": [2, 2],
	"sac_toile": [2, 2], "sac_a_dos": [3, 3], "sac_militaire": [3, 4],
	"etabli": [3, 2], "barricade": [2, 3], "caisse_stockage": [2, 2],
}

# Quantité maximale par case (piles). Par défaut 1.
const STACKS := {
	"mun_9mm": 60, "mun_556": 60, "mun_12": 24, "clous": 50, "tissu": 10, "ferraille": 5, "planche": 4, "ruban": 3,
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
	"accessoire": Color(0.7, 0.8, 0.95),
}

# bench = true : nécessite d'être près d'un établi
const RECIPES := [
	{"out": "bandage", "qty": 1, "needs": {"tissu": 2}, "bench": false},
	{"out": "etabli", "qty": 1, "needs": {"planche": 4, "clous": 6, "ferraille": 2}, "bench": false},
	{"out": "barricade", "qty": 1, "needs": {"planche": 3, "clous": 4}, "bench": false},
	{"out": "caisse_stockage", "qty": 1, "needs": {"planche": 4, "clous": 4}, "bench": true},
	{"out": "trousse", "qty": 1, "needs": {"bandage": 2, "alcool": 1, "antidouleur": 1}, "bench": true},
	{"out": "batte_cloutee", "qty": 1, "needs": {"batte": 1, "clous": 6, "ruban": 1}, "bench": true},
	{"out": "machette_art", "qty": 1, "needs": {"ferraille": 3, "ruban": 1, "tissu": 1}, "bench": true},
	{"out": "veste_renforcee", "qty": 1, "needs": {"veste_cuir": 1, "ferraille": 3, "ruban": 2}, "bench": true},
	{"out": "veste_cuir", "qty": 1, "needs": {"cuir": 3, "tissu": 2}, "bench": true},
	{"out": "sac_a_dos", "qty": 1, "needs": {"tissu": 6, "ruban": 1}, "bench": true},
	{"out": "mun_9mm", "qty": 10, "needs": {"poudre": 1, "ferraille": 1}, "bench": true},
	{"out": "mun_12", "qty": 5, "needs": {"poudre": 1, "ferraille": 1}, "bench": true},
	{"out": "mun_556", "qty": 10, "needs": {"poudre": 2, "ferraille": 1}, "bench": true},
]

# Tables de loot : [id, poids, min, max]
const LOOT := {
	"maison": [["conserve", 10, 1, 2], ["eau", 9, 1, 2], ["soda", 6, 1, 2], ["barre", 6, 1, 3], ["tissu", 10, 1, 3], ["bandage", 6, 1, 2], ["antidouleur", 3, 1, 1], ["alcool", 3, 1, 1], ["couteau", 3, 1, 1], ["batte", 2, 1, 1], ["planche", 4, 1, 2], ["clous", 4, 3, 8], ["ruban", 4, 1, 1], ["pied_de_biche", 1, 1, 1], ["cle_tuyau", 1, 1, 1], ["veste_cuir", 1, 1, 1], ["sac_a_dos", 1, 1, 1], ["casque_moto", 1, 1, 1], ["mun_9mm", 1, 3, 8]],
	"magasin": [["conserve", 12, 1, 3], ["eau", 12, 1, 3], ["soda", 10, 1, 3], ["barre", 10, 1, 4], ["tissu", 6, 1, 3], ["sac_a_dos", 2, 1, 1], ["ruban", 3, 1, 2], ["alcool", 4, 1, 1], ["cuir", 2, 1, 2]],
	"bureau": [["barre", 6, 1, 2], ["soda", 6, 1, 1], ["eau", 5, 1, 1], ["ruban", 5, 1, 2], ["tissu", 4, 1, 2], ["antidouleur", 3, 1, 1], ["ferraille", 3, 1, 1]],
	"quincaillerie": [["planche", 12, 2, 4], ["clous", 12, 6, 15], ["ferraille", 10, 1, 3], ["ruban", 8, 1, 2], ["hache", 2, 1, 1], ["machette", 2, 1, 1], ["batte", 2, 1, 1], ["pied_de_biche", 3, 1, 1], ["masse", 1.5, 1, 1], ["cle_tuyau", 3, 1, 1]],
	"hopital": [["bandage", 12, 1, 3], ["trousse", 5, 1, 1], ["antidouleur", 10, 1, 2], ["alcool", 8, 1, 1], ["tissu", 8, 2, 4], ["eau", 4, 1, 1]],
	"armurerie": [["mun_9mm", 12, 8, 20], ["mun_12", 10, 4, 10], ["poudre", 8, 1, 3], ["couteau", 4, 1, 1], ["machette", 3, 1, 1]],
	"police": [["mun_9mm", 12, 6, 18], ["mun_12", 8, 3, 8], ["mun_556", 4, 5, 15], ["matraque", 5, 1, 1], ["gilet_police", 3, 1, 1], ["casque_police", 3, 1, 1], ["bandage", 5, 1, 2], ["barre", 4, 1, 2]],
	"militaire": [["mun_556", 12, 10, 30], ["mun_9mm", 6, 10, 20], ["ration", 10, 1, 2], ["eau", 6, 1, 2], ["trousse", 4, 1, 1], ["gilet_militaire", 2, 1, 1], ["casque_militaire", 3, 1, 1], ["sac_militaire", 2, 1, 1], ["poudre", 4, 1, 3], ["machette", 2, 1, 1]],
	"armurerie_mil": [["mun_556", 12, 20, 45], ["gilet_militaire", 5, 1, 1], ["casque_militaire", 5, 1, 1], ["poudre", 5, 2, 4]],
	"station": [["soda", 10, 1, 3], ["barre", 10, 1, 3], ["eau", 8, 1, 2], ["ferraille", 6, 1, 2], ["ruban", 6, 1, 2], ["alcool", 3, 1, 1], ["cle_tuyau", 2, 1, 1], ["pied_de_biche", 1.5, 1, 1]],
	"ferme": [["conserve", 8, 1, 3], ["eau", 6, 1, 2], ["planche", 10, 2, 4], ["clous", 8, 4, 10], ["ferraille", 6, 1, 3], ["hache", 3, 1, 1], ["cuir", 6, 1, 3], ["tissu", 6, 1, 3], ["mun_12", 4, 2, 6]],
	"grange": [["planche", 12, 2, 5], ["clous", 10, 4, 12], ["ferraille", 10, 1, 3], ["cuir", 6, 1, 2], ["hache", 3, 1, 1], ["ruban", 4, 1, 1], ["masse", 1.5, 1, 1], ["pied_de_biche", 2, 1, 1]],
	"infeste": [["mun_9mm", 10, 6, 18], ["mun_12", 7, 3, 8], ["mun_556", 5, 6, 15], ["trousse", 4, 1, 1], ["bandage", 8, 1, 3], ["conserve", 8, 1, 3], ["eau", 8, 1, 2], ["sac_a_dos", 2, 1, 1], ["poudre", 4, 1, 3]],
	"boss": [["mun_556", 10, 30, 60], ["gilet_militaire", 4, 1, 1], ["casque_militaire", 4, 1, 1], ["sac_militaire", 4, 1, 1], ["trousse", 6, 2, 3]],
	"zombie_civil": [["barre", 4, 1, 1], ["tissu", 6, 1, 2], ["bandage", 2, 1, 1], ["antidouleur", 1, 1, 1], ["mun_9mm", 1, 2, 5]],
	"zombie_police": [["mun_9mm", 10, 4, 12], ["matraque", 3, 1, 1], ["bandage", 4, 1, 1], ["casque_police", 1, 1, 1]],
	"zombie_boss": [["mun_556", 10, 20, 40], ["trousse", 6, 1, 2], ["gilet_militaire", 3, 1, 1], ["ration", 6, 1, 3]],
	"zombie_militaire": [["mun_556", 10, 6, 20], ["ration", 5, 1, 1], ["trousse", 1.5, 1, 1], ["casque_militaire", 1, 1, 1]],
}


func info(id: String) -> Dictionary:
	return DB.get(id, {})


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
	return t == "melee" or t == "gun"


## Tire au hasard le contenu d'un conteneur. rolls = nombre de tirages.
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
				out[e[0]] = int(out.get(e[0], 0)) + n
				break
	return out


func describe(found: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in found:
		parts.append("%d× %s" % [found[id], nom(id)])
	return ", ".join(parts)
