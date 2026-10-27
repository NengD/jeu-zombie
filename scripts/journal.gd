extends RefCounted
## Journal du survivant : compteurs de la partie (statistiques), objectifs guidés et succès.
## Fonctions et variables statiques (comme commandes.gd) : `Journal.compter(clé, n)` appelé aux bons endroits
## (zombie._die, animal._mourir, bandit._mourir, player.craft, Game.maj_lieu_fouille, soins de morsure…),
## `Journal.maj(delta)` appelé à chaque image par journal_ui.gd (distance, série sans dégâts, lieux découverts,
## vérification des objectifs et succès une fois par seconde). `etat()` / `appliquer(d)` : clé « journal » de sauvegarde.gd.
## Clés : « zombies », « zombies_type:<kind> », « zombies_arme:<arme> », « animaux », « animaux:<kind> », « bandits »,
## « dist_pied » / « dist_vehicule » (m), « fabriques », « fab:<objet> », « fouilles », « morsures_soignees ».

static var compteurs := {}
static var decouverts := {}          # Game.cle_lieu(poi) -> true : lieux approchés
static var objectifs_faits := {}     # id -> jour
static var succes := {}              # id -> jour d'obtention
static var serie := 0.0              # secondes de jeu sans dégâts (en cours)
static var serie_max := 0.0
static var _partie := 0
static var _der_pos := Vector3.INF
static var _t := 0.0

## Objectifs guidés, dans l'ordre conseillé : {id, nom, aide, cle, n, recompense {xp: [compétence, qte]} ou {argent: n}}.
const OBJECTIFS := [
	{"id": "fouiller", "nom": "Fouiller 10 meubles", "aide": "[F] sur un meuble, un placard ou une voiture.", "cle": "fouilles", "n": 10, "rec": {"xp": ["exploration", 30]}},
	{"id": "fabriquer", "nom": "Fabriquer un objet", "aide": "Inventaire (Tab), colonne Fabrication : un bandage ou une arme de fortune.", "cle": "fabriques", "n": 1, "rec": {"xp": ["fabrication", 25]}},
	{"id": "zombies5", "nom": "Tuer 5 zombies", "aide": "Frappe de dos ou accroupi pour éviter d'en attirer d'autres.", "cle": "zombies", "n": 5, "rec": {"argent": 20}},
	{"id": "etabli", "nom": "Fabriquer un établi", "aide": "Il débloque les recettes d'atelier (armes, munitions, pièges).", "cle": "fab:etabli", "n": 1, "rec": {"xp": ["fabrication", 40]}},
	{"id": "feu", "nom": "Fabriquer un feu de camp", "aide": "Cuisiner, se réchauffer, sécher la viande.", "cle": "fab:feu_camp", "n": 1, "rec": {"xp": ["survie", 30]}},
	{"id": "lieu", "nom": "Fouiller un lieu entier", "aide": "Vide 80 % des meubles d'un lieu de la carte (M).", "cle": "lieux_fouilles", "n": 1, "rec": {"xp": ["exploration", 50]}},
	{"id": "decouvrir", "nom": "Découvrir 10 lieux", "aide": "Approche-toi des lieux marqués sur la carte (M).", "cle": "decouverts", "n": 10, "rec": {"argent": 40}},
	{"id": "base", "nom": "Construire une base", "aide": "[B] : murs, sols et portes (au moins 3 pièces).", "cle": "base", "n": 1, "rec": {"xp": ["fabrication", 60]}},
	{"id": "jours3", "nom": "Survivre 3 jours", "aide": "Mange, bois et dors à l'abri.", "cle": "jours", "n": 3, "rec": {"xp": ["survie", 60]}},
	{"id": "cerf", "nom": "Chasser un cerf", "aide": "À l'arc, sans bruit, dans les bois et les champs.", "cle": "animaux:cerf", "n": 1, "rec": {"xp": ["chasse", 60]}},
	{"id": "bandit", "nom": "Tuer un bandit", "aide": "Ils gardent des camps (M) : attaque de loin ou de nuit.", "cle": "bandits", "n": 1, "rec": {"argent": 60}},
	{"id": "commande", "nom": "Remplir une commande de marchand", "aide": "Chaque marchand a ses commandes du jour (en bas de sa boutique).", "cle": "commandes", "n": 1, "rec": {"argent": 30}},
	{"id": "potager", "nom": "Première récolte du potager", "aide": "Bac de culture posé dehors, graines, arrose ([F]) puis récolte le plant mûr.", "cle": "recolte_potager", "n": 1, "rec": {"xp": ["survie", 50]}},
	{"id": "voiture", "nom": "Réparer une voiture et la conduire", "aide": "Voiture garée : pièces auto, batterie et essence, puis [F] au volant.", "cle": "conduite", "n": 1, "rec": {"xp": ["fabrication", 80]}},
	{"id": "electricite", "nom": "Alimenter un appareil électrique", "aide": "Groupe électrogène ou panneau solaire à moins de 15 m d'une lampe ou d'un frigo.", "cle": "reseau", "n": 1, "rec": {"xp": ["fabrication", 60]}},
	{"id": "largage", "nom": "Atteindre un largage", "aide": "Écoute la radio et suis la fumée rouge (triangle sur la carte).", "cle": "largages", "n": 1, "rec": {"xp": ["exploration", 40]}},
	{"id": "jours7", "nom": "Survivre 7 jours", "aide": "", "cle": "jours", "n": 7, "rec": {"xp": ["survie", 120]}},
	{"id": "zombies100", "nom": "Tuer 100 zombies", "aide": "", "cle": "zombies", "n": 100, "rec": {"argent": 120}},
	{"id": "prison", "nom": "Fouiller la prison", "aide": "Au nord-ouest, bien gardée par des zombies.", "cle": "prison", "n": 1, "rec": {"xp": ["exploration", 150]}},
	{"id": "colosse", "nom": "Vaincre le Colosse", "aide": "Au fond de sa grotte (M) : viens bien armé.", "cle": "zombies_type:boss", "n": 1, "rec": {"argent": 300}},
]

## Succès : {id, nom, desc, cle, n}.
const SUCCES := [
	{"id": "premier_sang", "nom": "Premier sang", "desc": "Tuer un zombie.", "cle": "zombies", "n": 1},
	{"id": "boucher", "nom": "Boucher", "desc": "Tuer 100 zombies.", "cle": "zombies", "n": 100},
	{"id": "exterminateur", "nom": "Exterminateur", "desc": "Tuer 500 zombies.", "cle": "zombies", "n": 500},
	{"id": "maree", "nom": "Contre la marée", "desc": "Tuer 1 000 zombies.", "cle": "zombies", "n": 1000},
	{"id": "colosse", "nom": "Tueur de géant", "desc": "Vaincre le Colosse.", "cle": "zombies_type:boss", "n": 1},
	{"id": "arsenal", "nom": "Arsenal", "desc": "Tuer des zombies avec 8 armes différentes.", "cle": "armes_diff", "n": 8},
	{"id": "archer", "nom": "Robin des bois", "desc": "Tuer 25 zombies à l'arc.", "cle": "zombies_arme:arc", "n": 25},
	{"id": "pugiliste", "nom": "Pugiliste", "desc": "Tuer 10 zombies à mains nues.", "cle": "zombies_arme:poings", "n": 10},
	{"id": "chasseur", "nom": "Chasseur", "desc": "Chasser 10 animaux.", "cle": "animaux", "n": 10},
	{"id": "sanglier", "nom": "Gros gibier", "desc": "Abattre un sanglier.", "cle": "animaux:sanglier", "n": 1},
	{"id": "loup", "nom": "Chef de meute", "desc": "Abattre un loup.", "cle": "animaux:loup", "n": 1},
	{"id": "hors_la_loi", "nom": "Hors-la-loi", "desc": "Tuer un bandit.", "cle": "bandits", "n": 1},
	{"id": "justicier", "nom": "Justicier", "desc": "Tuer 25 bandits.", "cle": "bandits", "n": 25},
	{"id": "artisan", "nom": "Artisan", "desc": "Fabriquer 50 objets.", "cle": "fabriques", "n": 50},
	{"id": "industriel", "nom": "Industriel", "desc": "Fabriquer 250 objets.", "cle": "fabriques", "n": 250},
	{"id": "marcheur", "nom": "Marcheur", "desc": "Parcourir 10 km à pied.", "cle": "dist_pied", "n": 10000},
	{"id": "marathon", "nom": "Marathonien", "desc": "Parcourir 42 km à pied.", "cle": "dist_pied", "n": 42000},
	{"id": "routier", "nom": "Routier", "desc": "Parcourir 20 km en véhicule.", "cle": "dist_vehicule", "n": 20000},
	{"id": "explorateur", "nom": "Explorateur", "desc": "Découvrir 30 lieux.", "cle": "decouverts", "n": 30},
	{"id": "cartographe", "nom": "Cartographe", "desc": "Découvrir 100 lieux.", "cle": "decouverts", "n": 100},
	{"id": "pilleur", "nom": "Pilleur", "desc": "Fouiller entièrement 10 lieux.", "cle": "lieux_fouilles", "n": 10},
	{"id": "fouineur", "nom": "Fouineur", "desc": "Fouiller 500 meubles.", "cle": "fouilles", "n": 500},
	{"id": "survivant", "nom": "Survivant", "desc": "Survivre 7 jours.", "cle": "jours", "n": 7},
	{"id": "veteran", "nom": "Vétéran", "desc": "Survivre 30 jours.", "cle": "jours", "n": 30},
	{"id": "medecin", "nom": "Médecin de fortune", "desc": "Soigner 3 morsures.", "cle": "morsures_soignees", "n": 3},
	{"id": "intouchable", "nom": "Intouchable", "desc": "Rester 30 minutes de jeu sans prendre de dégâts.", "cle": "serie_max", "n": 1800},
	{"id": "proprietaire", "nom": "Propriétaire", "desc": "Construire une base.", "cle": "base", "n": 1},
	{"id": "riche", "nom": "Bas de laine", "desc": "Avoir 500 € en poche.", "cle": "argent", "n": 500},
	{"id": "un_des_leurs", "nom": "Un des leurs", "desc": "Se couvrir de tripes de zombie.", "cle": "deguise", "n": 1},
	{"id": "main_verte", "nom": "Main verte", "desc": "Récolter 20 légumes au potager.", "cle": "recolte_potager", "n": 20},
	{"id": "mecano", "nom": "Mécano", "desc": "Réparer une voiture et la conduire.", "cle": "conduite", "n": 1},
	{"id": "electricien", "nom": "Fée électricité", "desc": "Alimenter un appareil électrique.", "cle": "reseau", "n": 1},
	{"id": "fournisseur", "nom": "Fournisseur", "desc": "Remplir 10 commandes de marchands.", "cle": "commandes", "n": 10},
	{"id": "manne", "nom": "Manne céleste", "desc": "Atteindre 3 largages de ravitaillement.", "cle": "largages", "n": 3},
	{"id": "convoi", "nom": "Pillard de convoi", "desc": "Atteindre un convoi militaire accidenté.", "cle": "convois", "n": 1},
	{"id": "horde", "nom": "Dans l'œil de la horde", "desc": "Survivre au passage d'une horde migrante.", "cle": "hordes_survecues", "n": 1},
	{"id": "forteresse", "nom": "Forteresse", "desc": "Repousser 3 attaques contre ta base.", "cle": "attaques_repoussees", "n": 3},
]

const Commandes = preload("res://scripts/commandes.gd")
const LEGUMES_POTAGER := ["tomate", "carotte", "pomme_de_terre"]
static var _cmd_vues := {}           # commandes remplies déjà comptées (jour:marchand:n°)


static func compter(cle: String, n: float = 1.0) -> void:
	_verifier_partie()
	compteurs[cle] = compteurs.get(cle, 0.0) + n


static func valeur(cle: String) -> float:
	match cle:
		"jours":   # jours survécus
			return maxi(0, Game.day - 1)
		"lieux_fouilles":
			return Game.lieux_fouilles.size()
		"decouverts":
			return decouverts.size()
		"serie_max":
			return maxf(serie_max, serie)
		"base":
			return 1.0 if Game.position_base() != Vector3.INF else 0.0
		"argent":
			return Game.player.argent if Game.player else 0.0
		"prison":
			for k in Game.lieux_fouilles:
				if str(k).begins_with("Prison@"):
					return 1.0
			return 0.0
		"armes_diff":
			var n := 0
			for k in compteurs:
				if str(k).begins_with("zombies_arme:"):
					n += 1
			return n
	return compteurs.get(cle, 0.0)


## Le joueur a pris des dégâts : la série sans dégâts repart de zéro.
static func touche() -> void:
	serie_max = maxf(serie_max, serie)
	serie = 0.0


## Lieux comptés pour « découverts » (tous les lieux de la carte sauf les marchands en double).
static func total_lieux() -> int:
	var n := 0
	for poi in Game.pois:
		if not poi.get("marchand", false):
			n += 1
	return n


static func maj(delta: float) -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p) or not p.alive:
		return
	_verifier_partie()
	serie += delta
	var pos: Vector3 = p.global_position
	if _der_pos != Vector3.INF:
		var d := Vector2(pos.x - _der_pos.x, pos.z - _der_pos.z).length()
		if d < 20.0:   # au-delà : téléportation, chargement
			var v = p.get("vehicule")
			compter("dist_vehicule" if (v != null and v is Object and is_instance_valid(v)) else "dist_pied", d)
	_der_pos = pos
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	for poi in Game.pois:
		if poi.get("marchand", false):
			continue
		var k: String = Game.cle_lieu(poi)
		if decouverts.has(k):
			continue
		var r := 220.0 if Game.lieu_vaste(poi.name) else 50.0
		if Vector2(poi.pos.x - pos.x, poi.pos.z - pos.z).length() < r:
			decouverts[k] = true
	_suivre_systemes(p)
	_verifier_progres()


## Systèmes récents suivis sans toucher à leurs scripts : déguisement, conduite, réseau électrique,
## commandes remplies (sondés chaque seconde) et récolte du potager (signal Game.objet_recu près d'un bac).
static func _suivre_systemes(p: Node) -> void:
	if not Game.objet_recu.is_connected(_recu):
		Game.objet_recu.connect(_recu)
	var tr = p.get("tripes_t")
	if tr != null and float(tr) > 0.0:
		compteurs["deguise"] = 1.0
	var v = p.get("vehicule")
	if v != null and v is Object and is_instance_valid(v):
		compteurs["conduite"] = 1.0
	if not compteurs.has("reseau"):
		for a in p.get_tree().get_nodes_in_group("elec_conso"):
			if bool(a.get_meta("alimente", false)):
				compteurs["reseau"] = 1.0
				break
	for k in Commandes.par_marchand:
		var liste: Array = Commandes.par_marchand[k]
		for i in liste.size():
			if liste[i] is Dictionary and bool(liste[i].get("fait", false)):
				var cle := "%d:%s:%d" % [Commandes.jour, k, i]
				if not _cmd_vues.has(cle):
					_cmd_vues[cle] = true
					compter("commandes")


static func _recu(id: String, n: int) -> void:
	if n <= 0 or not id in LEGUMES_POTAGER or Game.player == null:
		return
	var pos: Vector3 = Game.player.global_position
	for b in Game.player.get_tree().get_nodes_in_group("placeables"):
		if b.get("kind") == "bac_culture" and b.global_position.distance_to(pos) < 4.0:
			compter("recolte_potager", n)
			return


static func _verifier_progres() -> void:
	for o in OBJECTIFS:
		if not objectifs_faits.has(o.id) and valeur(o.cle) >= o.n:
			objectifs_faits[o.id] = Game.day
			var rec: Dictionary = o.rec
			var gain := ""
			if rec.has("argent"):
				Game.player.gagner_argent(int(rec.argent))
				gain = "%d €" % int(rec.argent)
			if rec.has("xp"):
				Game.player.prog.gagner(rec.xp[0], int(rec.xp[1]))
				gain = "%d XP" % int(rec.xp[1])
			Game.msg("Objectif atteint : %s (+%s)" % [o.nom, gain])
	for s in SUCCES:
		if not succes.has(s.id) and valeur(s.cle) >= s.n:
			succes[s.id] = Game.day
			Game.msg("★ Succès débloqué : %s — %s" % [s.nom, s.desc])
			Game.play_ui("fouille", -2.0, 0.0, 1.6)


## Objectif conseillé : le premier pas encore atteint.
static func objectif_courant() -> Dictionary:
	for o in OBJECTIFS:
		if not objectifs_faits.has(o.id):
			return o
	return {}


static func _verifier_partie() -> void:
	var id := Game.player.get_instance_id() if Game.player else 0
	if _partie == 0:           # état chargé avant la création du joueur
		_partie = id
	elif id != 0 and id != _partie:
		_partie = id
		_vider()


static func _vider() -> void:
	compteurs = {}
	decouverts = {}
	objectifs_faits = {}
	succes = {}
	serie = 0.0
	serie_max = 0.0
	_cmd_vues = {}
	_der_pos = Vector3.INF


static func etat() -> Dictionary:
	return {"c": compteurs.duplicate(), "d": decouverts.keys(), "o": objectifs_faits.duplicate(),
			"s": succes.duplicate(), "serie": serie, "serie_max": serie_max, "cv": _cmd_vues.keys()}


## Rétablit l'état (chargement) ; {} = partie sans journal (ancienne sauvegarde).
static func appliquer(d: Dictionary) -> void:
	_vider()
	_partie = Game.player.get_instance_id() if Game.player else 0
	compteurs = (d.get("c", {}) as Dictionary).duplicate()
	for k in d.get("d", []):
		decouverts[str(k)] = true
	objectifs_faits = (d.get("o", {}) as Dictionary).duplicate()
	succes = (d.get("s", {}) as Dictionary).duplicate()
	serie = float(d.get("serie", 0.0))
	serie_max = float(d.get("serie_max", 0.0))
	for k in d.get("cv", []):
		_cmd_vues[str(k)] = true
