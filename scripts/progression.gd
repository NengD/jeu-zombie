class_name Progression
extends RefCounted
## Niveaux, attributs et compétences du survivant.
## - Niveau global : chaque niveau donne 1 point d'attribut (endurance, santé, soif, faim).
## - Compétences Combat / Fabrication / Exploration / Survie / Chasse : XP propre, niveaux 1 à 10 ;
##   chaque niveau de compétence donne 1 point de talent à dépenser dans sa branche de l'arbre.
## Les actions rapportent de l'XP de compétence et de l'XP globale.

signal niveau_global(n: int)
signal niveau_competence(comp: String, n: int)
signal xp_gagnee(comp: String, qte: int)

const COMPETENCES := ["combat", "fabrication", "exploration", "survie", "chasse"]
const NOMS := {"combat": "Combat", "fabrication": "Fabrication", "exploration": "Exploration", "survie": "Survie", "chasse": "Chasse"}
const NIVEAU_MAX_COMP := 10

const ATTRIBUTS := {
	"endurance": {"nom": "Endurance", "desc": "+10 d'endurance max et récupération +8 %"},
	"sante": {"nom": "Santé", "desc": "+10 de santé max"},
	"soif": {"nom": "Soif", "desc": "La soif baisse 7 % moins vite"},
	"faim": {"nom": "Faim", "desc": "La faim baisse 7 % moins vite"},
}

## Arbre de compétences : chaque talent est un nœud d'une branche (`br`), relié à son parent
## (`apres`, "" = départ de la branche) ; `niv` = niveau de compétence requis, `d` = distance au
## centre (rang), `l` = décalage sur le côté. Coût : 1 point de talent de la compétence (`comp`).
const BRANCHES := {
	"melee": {"nom": "Corps à corps", "comp": "combat"},
	"tir": {"nom": "Armes à feu", "comp": "combat"},
	"fabrication": {"nom": "Fabrication", "comp": "fabrication"},
	"exploration": {"nom": "Exploration", "comp": "exploration"},
	"survie": {"nom": "Survie", "comp": "survie"},
	"chasse": {"nom": "Chasse et arc", "comp": "chasse"},
}
const TALENTS := {
	# --- combat : corps à corps
	"coup_puissant": {"comp": "combat", "br": "melee", "apres": "", "d": 1, "l": 0, "niv": 1, "nom": "Coup puissant", "desc": "+25 % de dégâts au corps à corps."},
	"lame_aiguisee": {"comp": "combat", "br": "melee", "apres": "coup_puissant", "d": 2, "l": -1, "niv": 2, "nom": "Lame aiguisée", "desc": "Hache, machette et couteau : +20 % de dégâts et plus de sang."},
	"souffle": {"comp": "combat", "br": "melee", "apres": "coup_puissant", "d": 2, "l": 0, "niv": 3, "nom": "Second souffle", "desc": "Les coups au corps à corps coûtent 30 % d'endurance en moins."},
	"frappeur": {"comp": "combat", "br": "melee", "apres": "coup_puissant", "d": 2, "l": 1, "niv": 3, "nom": "Frappeur", "desc": "Battes et matraque repoussent les zombies à chaque coup."},
	"charge_rapide": {"comp": "combat", "br": "melee", "apres": "souffle", "d": 3, "l": 0, "niv": 4, "nom": "Concentration", "desc": "Le coup puissant se charge 40 % plus vite."},
	"robuste": {"comp": "combat", "br": "melee", "apres": "souffle", "d": 3, "l": -1, "niv": 5, "nom": "Peau dure", "desc": "Tu subis 15 % de dégâts en moins."},
	"balayage": {"comp": "combat", "br": "melee", "apres": "charge_rapide", "d": 4, "l": 1, "niv": 6, "nom": "Grand balayage", "desc": "Le balayage latéral touche jusqu'à deux zombies."},
	"critique": {"comp": "combat", "br": "melee", "apres": "charge_rapide", "d": 4, "l": 0, "niv": 7, "nom": "Coup critique", "desc": "20 % de chances d'infliger double dégâts au corps à corps."},
	"brute": {"comp": "combat", "br": "melee", "apres": "critique", "d": 5, "l": 0, "niv": 8, "nom": "Brute", "desc": "Un coup puissant chargé à fond renverse toujours le zombie."},
	# --- combat : armes à feu
	"main_sure": {"comp": "combat", "br": "tir", "apres": "", "d": 1, "l": 0, "niv": 1, "nom": "Main sûre", "desc": "Tirs 25 % plus précis (armes à feu et arc)."},
	"recharge_rapide": {"comp": "combat", "br": "tir", "apres": "main_sure", "d": 2, "l": 0, "niv": 2, "nom": "Recharge rapide", "desc": "Rechargement 25 % plus rapide."},
	"tir_hanche": {"comp": "combat", "br": "tir", "apres": "main_sure", "d": 2, "l": 1, "niv": 3, "nom": "Tir instinctif", "desc": "Tir sans viser 30 % plus précis."},
	"tireur": {"comp": "combat", "br": "tir", "apres": "recharge_rapide", "d": 3, "l": 0, "niv": 4, "nom": "Tireur d'élite", "desc": "+20 % de dégâts avec les armes à feu."},
	"gachette": {"comp": "combat", "br": "tir", "apres": "tireur", "d": 4, "l": 1, "niv": 6, "nom": "Doigt léger", "desc": "Cadence de tir 15 % plus rapide."},
	"balistique": {"comp": "combat", "br": "tir", "apres": "tireur", "d": 4, "l": -1, "niv": 7, "nom": "Balistique", "desc": "Portée des armes à feu +25 %."},
	"sang_froid": {"comp": "combat", "br": "tir", "apres": "tireur", "d": 5, "l": 0, "niv": 9, "nom": "Sang-froid", "desc": "Recul des armes réduit de 35 %."},
	# --- fabrication
	"econome": {"comp": "fabrication", "br": "fabrication", "apres": "", "d": 1, "l": 0, "niv": 1, "nom": "Économe", "desc": "30 % de chances de récupérer un matériau en fabriquant."},
	"soigneur": {"comp": "fabrication", "br": "fabrication", "apres": "econome", "d": 2, "l": 1, "niv": 1, "nom": "Soigneur", "desc": "Les soins rendent 30 % de santé en plus."},
	"charpentier": {"comp": "fabrication", "br": "fabrication", "apres": "econome", "d": 2, "l": 0, "niv": 3, "nom": "Charpentier", "desc": "Barricades et établis posés ont 60 % de solidité en plus."},
	"cartoucherie": {"comp": "fabrication", "br": "fabrication", "apres": "econome", "d": 2, "l": -1, "niv": 2, "nom": "Cartoucherie", "desc": "Les munitions fabriquées sont 50 % plus nombreuses."},
	"cuisinier": {"comp": "fabrication", "br": "fabrication", "apres": "charpentier", "d": 3, "l": 1, "niv": 4, "nom": "Débrouillard", "desc": "Nourriture et boissons nourrissent 25 % de plus."},
	"artisan_rapide": {"comp": "fabrication", "br": "fabrication", "apres": "charpentier", "d": 3, "l": -1, "niv": 5, "nom": "Mains agiles", "desc": "Fabrication 25 % plus rapide."},
	"atelier": {"comp": "fabrication", "br": "fabrication", "apres": "charpentier", "d": 4, "l": 0, "niv": 6, "nom": "Atelier portatif", "desc": "Fabrique les recettes d'établi partout."},
	"recuperateur": {"comp": "fabrication", "br": "fabrication", "apres": "artisan_rapide", "d": 4, "l": -1, "niv": 7, "nom": "Récupérateur", "desc": "Le démontage rend 50 % de matériaux en plus."},
	"maitre_artisan": {"comp": "fabrication", "br": "fabrication", "apres": "atelier", "d": 5, "l": 0, "niv": 8, "nom": "Maître artisan", "desc": "Une chance sur deux d'obtenir un objet fabriqué en double (hors munitions)."},
	# --- exploration
	"fouilleur": {"comp": "exploration", "br": "exploration", "apres": "", "d": 1, "l": 0, "niv": 1, "nom": "Fouilleur", "desc": "Les meubles contiennent plus d'objets."},
	"discret": {"comp": "exploration", "br": "exploration", "apres": "fouilleur", "d": 2, "l": 1, "niv": 1, "nom": "Pas de loup", "desc": "Les zombies te repèrent de 30 % moins loin."},
	"poches": {"comp": "exploration", "br": "exploration", "apres": "fouilleur", "d": 2, "l": 0, "niv": 3, "nom": "Poches profondes", "desc": "+1 rangée à ton inventaire de base (8×6)."},
	"coureur": {"comp": "exploration", "br": "exploration", "apres": "fouilleur", "d": 2, "l": -1, "niv": 2, "nom": "Coureur", "desc": "Sprint 12 % plus rapide."},
	"marathonien": {"comp": "exploration", "br": "exploration", "apres": "coureur", "d": 3, "l": -1, "niv": 4, "nom": "Marathonien", "desc": "Le sprint consomme 35 % d'endurance en moins."},
	"poches2": {"comp": "exploration", "br": "exploration", "apres": "poches", "d": 4, "l": 0, "niv": 6, "nom": "Poches de cargo", "desc": "+1 rangée supplémentaire (8×7)."},
	"vue_percante": {"comp": "exploration", "br": "exploration", "apres": "poches2", "d": 5, "l": 0, "niv": 8, "nom": "Œil de lynx", "desc": "Les meubles contiennent encore plus d'objets."},
	# --- survie (XP : récolte, manger, boire, se soigner, encaisser des coups)
	"regeneration": {"comp": "survie", "br": "survie", "apres": "", "d": 1, "l": 0, "niv": 1, "nom": "Régénération", "desc": "La santé remonte deux fois plus vite quand tu es nourri et hydraté."},
	"bucheron": {"comp": "survie", "br": "survie", "apres": "regeneration", "d": 2, "l": 1, "niv": 2, "nom": "Bûcheron", "desc": "Arbres et rochers : récolte comme avec 2 niveaux de survie de plus."},
	"endurci": {"comp": "survie", "br": "survie", "apres": "regeneration", "d": 2, "l": 0, "niv": 3, "nom": "Endurci", "desc": "L'endurance remonte 25 % plus vite."},
	"frugal": {"comp": "survie", "br": "survie", "apres": "regeneration", "d": 2, "l": -1, "niv": 2, "nom": "Frugal", "desc": "La faim et la soif baissent 15 % moins vite."},
	"estomac": {"comp": "survie", "br": "survie", "apres": "frugal", "d": 3, "l": -1, "niv": 4, "nom": "Estomac de fer", "desc": "Risque d'intoxication par la viande crue divisé par deux."},
	"adrenaline": {"comp": "survie", "br": "survie", "apres": "endurci", "d": 3, "l": 0, "niv": 5, "nom": "Adrénaline", "desc": "Sous 25 % de santé : +20 % de dégâts et de vitesse."},
	"increvable": {"comp": "survie", "br": "survie", "apres": "adrenaline", "d": 5, "l": 0, "niv": 8, "nom": "Increvable", "desc": "Une fois par jour, une blessure mortelle te laisse à 15 de santé."},
	# --- chasse et arc (XP : flèches qui touchent, animaux tués, dépeçage, collets, cuisine au feu)
	"archer": {"comp": "chasse", "br": "chasse", "apres": "", "d": 1, "l": 0, "niv": 1, "nom": "Archer", "desc": "+20 % de dégâts avec les flèches."},
	"depeceur": {"comp": "chasse", "br": "chasse", "apres": "archer", "d": 2, "l": 1, "niv": 2, "nom": "Dépeceur", "desc": "Le dépeçage rend une viande et une peau de plus."},
	"tension_rapide": {"comp": "chasse", "br": "chasse", "apres": "archer", "d": 2, "l": 0, "niv": 4, "nom": "Bras d'archer", "desc": "L'arc se bande 35 % plus vite."},
	"pisteur": {"comp": "chasse", "br": "chasse", "apres": "archer", "d": 2, "l": -1, "niv": 3, "nom": "Pisteur", "desc": "Les animaux te repèrent de 30 % moins loin."},
	"chef": {"comp": "chasse", "br": "chasse", "apres": "depeceur", "d": 3, "l": 1, "niv": 6, "nom": "Cuisine de camp", "desc": "Recettes au feu : une chance sur deux d'avoir une portion de plus."},
	"recup_fleches": {"comp": "chasse", "br": "chasse", "apres": "tension_rapide", "d": 3, "l": 0, "niv": 5, "nom": "Flèches solides", "desc": "Les flèches plantées se récupèrent presque toujours."},
	"tir_mortel": {"comp": "chasse", "br": "chasse", "apres": "recup_fleches", "d": 4, "l": 0, "niv": 8, "nom": "Tir mortel", "desc": "Une flèche bandée à fond fait 50 % de dégâts en plus."},
}

var niveau := 1
var xp := 0
var points := 0
var attributs := {"endurance": 0, "sante": 0, "soif": 0, "faim": 0}
var comp := {}          # nom -> {"niv": int, "xp": int, "points": int}
var talents: Array = []
var lieux_vus := {}     # bâtiments/points d'intérêt déjà découverts


func _init() -> void:
	for c in COMPETENCES:
		comp[c] = {"niv": 0, "xp": 0, "points": 0}


static func xp_niveau(n: int) -> int:
	return int(100.0 * pow(n, 1.45))


static func xp_comp(n: int) -> int:
	return int(60.0 * pow(n + 1, 1.5))


func a(talent: String) -> bool:
	return talent in talents


## Gagne de l'XP dans une compétence (et autant d'XP globale).
func gagner(c: String, qte: int) -> void:
	if qte <= 0:
		return
	xp_gagnee.emit(c, qte)
	xp += qte
	while xp >= xp_niveau(niveau):
		xp -= xp_niveau(niveau)
		niveau += 1
		points += 1
		niveau_global.emit(niveau)
	if not comp.has(c):
		return
	var d: Dictionary = comp[c]
	if d.niv >= NIVEAU_MAX_COMP:
		return
	d.xp += qte
	while d.niv < NIVEAU_MAX_COMP and d.xp >= xp_comp(d.niv):
		d.xp -= xp_comp(d.niv)
		d.niv += 1
		d.points += 1
		niveau_competence.emit(c, d.niv)


func peut_debloquer(t: String) -> bool:
	return raison_bloque(t) == ""


## Pourquoi un talent ne peut pas être débloqué ("" = il peut l'être).
func raison_bloque(t: String) -> String:
	if not TALENTS.has(t):
		return "Talent inconnu"
	if a(t):
		return "Déjà acquis"
	var info: Dictionary = TALENTS[t]
	var d: Dictionary = comp[info.comp]
	if info.apres != "" and not a(info.apres):
		return "Débloque d'abord « %s »" % TALENTS[info.apres].nom
	if d.niv < info.niv:
		return "Il faut le niveau %d en %s (tu es niveau %d)" % [info.niv, NOMS[info.comp], d.niv]
	if d.points <= 0:
		return "Plus de point de %s" % NOMS[info.comp]
	return ""


func debloquer(t: String) -> bool:
	if not peut_debloquer(t):
		return false
	comp[TALENTS[t].comp].points -= 1
	talents.append(t)
	return true


func ameliorer(attr: String) -> bool:
	if points <= 0 or not attributs.has(attr):
		return false
	points -= 1
	attributs[attr] += 1
	return true


## Talents gardés à la réinitialisation (les rangées de poches ne se retirent pas).
const GARDES_REINIT := ["poches", "poches2"]


## Prix de la réinitialisation (€) : grandit avec le niveau.
func cout_reinit() -> int:
	return 100 + 40 * niveau


## Points rendus par une réinitialisation (talents, attributs).
func points_investis() -> int:
	var n := 0
	for t in talents:
		if not t in GARDES_REINIT:
			n += 1
	for k in attributs:
		n += int(attributs[k])
	return n


## Rend tous les points de talent et d'attribut dépensés.
func reinitialiser() -> void:
	var gardes: Array = []
	for t in talents:
		if t in GARDES_REINIT:
			gardes.append(t)
		elif TALENTS.has(t):
			comp[TALENTS[t].comp].points += 1
	talents = gardes
	for k in attributs:
		points += int(attributs[k])
		attributs[k] = 0


# ---------------------------------------------------------------- effets
func sante_max() -> float:
	return 100.0 + 10.0 * attributs.sante


func endurance_max() -> float:
	return 100.0 + 10.0 * attributs.endurance


func recup_endurance() -> float:
	return (1.0 + 0.08 * attributs.endurance) * (1.25 if a("endurci") else 1.0)


func faim_mult() -> float:
	return pow(0.93, attributs.faim) * (0.85 if a("frugal") else 1.0)


func soif_mult() -> float:
	return pow(0.93, attributs.soif) * (0.85 if a("frugal") else 1.0)


func lignes_inventaire() -> int:
	return 5 + (1 if a("poches") else 0) + (1 if a("poches2") else 0)


# ---------------------------------------------------------------- sauvegarde
func vers_dict() -> Dictionary:
	return {"niveau": niveau, "xp": xp, "points": points, "attributs": attributs, "comp": comp,
			"talents": talents, "lieux": lieux_vus.keys()}


func depuis_dict(d: Dictionary) -> void:
	niveau = int(d.get("niveau", 1))
	xp = int(d.get("xp", 0))
	points = int(d.get("points", 0))
	var at: Dictionary = d.get("attributs", {})
	for k in attributs:
		attributs[k] = int(at.get(k, 0))
	var cd: Dictionary = d.get("comp", {})
	for c in COMPETENCES:
		var x: Dictionary = cd.get(c, {})
		comp[c] = {"niv": int(x.get("niv", 0)), "xp": int(x.get("xp", 0)), "points": int(x.get("points", 0))}
	talents = []
	for t in d.get("talents", []):
		if TALENTS.has(str(t)):
			talents.append(str(t))
	lieux_vus = {}
	for l in d.get("lieux", []):
		lieux_vus[str(l)] = true
