extends RefCounted
## Commandes des marchands : chaque marchand demande 1 à 3 choses liées à son métier (« apporte 5 peaux »,
## « 40 balles 9 mm », « nettoie le camp de bandits au nord »), renouvelées chaque jour (Game.day),
## payées en argent + XP. Tirage fixe par marchand et par jour ; l'état (jour, commandes, faites) est sauvegardé :
## Commandes.etat() / Commandes.appliquer(d) (sauvegarde.gd, clé « commandes »).
## Utilisé par boutique_ui.gd (section COMMANDES) ; une commande = {type: "objet", id, n} ou {type: "camp", i, dir},
## + prix (€), xp, comp (compétence), fait. Prix = 75 % de la valeur + 8 € : moins que le prix d'achat chez le marchand
## (pas d'argent facile en achetant puis rendant), plus que la revente (40–70 %) ; l'XP est la vraie récompense.

# métier : [objet, quantité min, max] ; compétence qui gagne l'XP
const DEMANDES := {
	"boucher": {"comp": "chasse", "liste": [["peau", 2, 5], ["viande_crue", 3, 8], ["poisson_cru", 2, 5], ["plume", 6, 12], ["graisse", 2, 4], ["cuir", 2, 3]]},
	"medecin": {"comp": "survie", "liste": [["bandage", 3, 6], ["attelle", 1, 2], ["alcool", 2, 3], ["antidouleur", 2, 4], ["trousse", 1, 1], ["antibiotiques", 1, 2]]},
	"armurier": {"comp": "combat", "liste": [["mun_9mm", 30, 60], ["mun_12", 12, 24], ["mun_556", 30, 60], ["mun_545", 30, 60], ["mun_762", 16, 32], ["mun_46", 30, 60], ["fleche", 10, 20], ["poudre", 3, 6]]},
	"quincaillier": {"comp": "fabrication", "liste": [["planche", 8, 16], ["buche", 4, 8], ["pierre", 8, 16], ["ferraille", 5, 10], ["clous", 20, 40], ["minerai", 3, 6]]},
	"epicier": {"comp": "survie", "liste": [["pomme", 4, 8], ["raisin", 3, 6], ["epi_mais", 3, 6], ["eau", 3, 5], ["poisson_cuit", 2, 4], ["viande_sechee", 2, 4], ["conserve", 3, 5]]},
	"mecanicien": {"comp": "fabrication", "liste": [["piece_auto", 2, 4], ["batterie", 1, 1], ["pneu", 2, 3], ["essence", 1, 2], ["ferraille", 6, 10]]},
}
const CAMP_PORTEE := 1600.0          # camp de bandits proposé par l'armurier s'il est à moins de cette distance
const CAMP_PRIX := 180
const CAMP_XP := 90

static var jour := -1
static var par_marchand := {}        # clé du marchand -> Array de commandes
static var _partie := 0              # joueur de la partie en cours (nouvelle partie = tout remis à zéro)


static func cle(v: Node) -> String:
	var p: Vector3 = v.global_position
	return "%s|%d|%d" % [v.metier, roundi(p.x), roundi(p.z)]


## Commandes du jour de ce marchand (tirées à la première visite du jour).
static func liste(v: Node) -> Array:
	_verifier_partie()
	if Game.day != jour:
		jour = Game.day
		par_marchand = {}
	var k := cle(v)
	if not par_marchand.has(k):
		par_marchand[k] = _tirer(v, k)
	return par_marchand[k]


static func _verifier_partie() -> void:
	var id := Game.player.get_instance_id() if Game.player else 0
	if _partie == 0:           # état chargé avant la création du joueur
		_partie = id
	elif id != _partie:
		_partie = id
		jour = -1
		par_marchand = {}


static func _tirer(v: Node, k: String) -> Array:
	var d: Dictionary = DEMANDES.get(v.metier, {})
	if d.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s#%d" % [k, jour])
	var res := []
	if v.metier == "armurier":
		var camp := _camp_proche(v, rng)
		if not camp.is_empty():
			res.append(camp)
	var choix: Array = d.liste.duplicate()
	var nb := rng.randi_range(1, 3) - res.size()
	for i in maxi(nb, 0):
		if choix.is_empty():
			break
		var e: Array = choix.pop_at(rng.randi() % choix.size())
		if not Items.DB.has(e[0]):
			continue
		var n := rng.randi_range(int(e[1]), int(e[2]))
		var valeur := float(Items.prix(e[0]) * n)
		res.append({"type": "objet", "id": e[0], "n": n, "prix": roundi(valeur * 0.75 + 8.0),
				"xp": roundi(15.0 + valeur / 3.0), "comp": d.comp, "fait": false})
	return res


## Armurier : nettoyer le camp de bandits encore occupé le plus proche (une fois sur deux).
static func _camp_proche(v: Node, rng: RandomNumberGenerator) -> Dictionary:
	var main: Node = Game.player.get_parent() if Game.player else null
	if main == null or not main.has_method("infos_primes") or rng.randf() < 0.5:
		return {}
	var best := {}
	for e in main.infos_primes(v.global_position):
		if e.restants > 0 and e.dist < CAMP_PORTEE and (best.is_empty() or e.dist < best.dist):
			best = e
	if best.is_empty():
		return {}
	return {"type": "camp", "i": best.i, "dir": best.dir, "dist": best.dist, "prix": CAMP_PRIX + 15 * int(best.restants),
			"xp": CAMP_XP, "comp": "combat", "fait": false}


static func texte(c: Dictionary) -> String:
	if c.type == "camp":
		return "Nettoyer le camp de bandits au %s (%d m)" % [c.dir, c.dist]
	return "Apporter %d × %s" % [c.n, Items.nom(c.id)]


## Ce qui manque encore (texte vide = commande prête à rendre).
static func manque(c: Dictionary, p: Node) -> String:
	if c.fait:
		return ""
	if c.type == "camp":
		var main: Node = p.get_parent()
		if main.has_method("infos_primes") and int(c.i) < main.camps.size():
			var r: int = main.camps[int(c.i)].vivants()
			return "" if r <= 0 else "%d bandit(s) restant(s)" % r
		return "camp introuvable"
	var a: int = p.count(c.id)
	return "" if a >= int(c.n) else "tu en as %d / %d" % [a, c.n]


## Rend la commande : retire les objets, paie, donne l'XP. Renvoie vrai si c'est fait.
static func rendre(c: Dictionary, p: Node) -> bool:
	if c.fait or manque(c, p) != "":
		return false
	if c.type == "objet":
		p.remove_item(c.id, int(c.n))
		Game.recu(c.id, -int(c.n))
	c.fait = true
	p.gagner_argent(int(c.prix))
	p.prog.gagner(str(c.comp), int(c.xp))
	Game.msg("Commande remplie : %d € et %d XP (%s)." % [c.prix, c.xp, c.comp])
	Game.play_ui("construire", -2.0, 0.0, 1.3)
	return true


## État pour la sauvegarde.
static func etat() -> Dictionary:
	return {"jour": jour, "m": par_marchand.duplicate(true)}


## Rétablit l'état (chargement) ; {} = nouvelle partie.
static func appliquer(d: Dictionary) -> void:
	_partie = Game.player.get_instance_id() if Game.player else 0
	jour = int(d.get("jour", -1))
	par_marchand = (d.get("m", {}) as Dictionary).duplicate(true)
