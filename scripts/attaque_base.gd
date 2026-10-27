extends Node
## Attaques contre la base du joueur (nœud « AttaqueBase » de main.gd).
## main.declencher_horde lance la horde (zombies `assaut`) et appelle `debut` : chaque zombie est envoyé sur la pièce
## la plus faible de la base (porte, puis bois, tôle, parpaing ; murs et portes du rez-de-chaussée, ceux du pourtour
## d'abord) et tape dedans ; une pièce détruite ouvre une brèche par laquelle les suivants entrent.
## Parfois des bandits profitent de l'attaque. Repère « Horde » sur la boussole et la carte (`reperes`), du côté
## d'où elle vient, dès l'alerte. Fin à l'aube ou quand la horde est tuée : XP de survie, compteurs du journal
## (`attaques_base`, `attaques_repoussees`, `pieces_perdues`). Admin (F2) : `lancer_maintenant()`.

const Construction = preload("res://scripts/construction.gd")
const Bandit = preload("res://scripts/bandit.gd")
const Journal = preload("res://scripts/journal.gd")
const CAMP_BANDITS := 2000
const COULEUR := Color(1.0, 0.25, 0.2)

static var reperes: Array = []

var active := false
var base: Node3D = null
var centre := Vector3.ZERO
var angle := 0.0
var zombies: Array = []
var bandits: Array = []          # bandits de l'attaque (encore là après la fin : ils repartent)
var breches: Array = []          # positions des pièces détruites pendant l'attaque
var detruites := 0
var suivies: Array = []          # [pièce, position] des murs et portes de la base attaquée
var _t := 0.0
var _compte_avant := -1.0
@onready var main = get_parent()


## Horde lancée par main.declencher_horde (zombies réels près de la base).
func debut(p_base: Node3D, p_centre: Vector3, p_angle: float, liste: Array) -> void:
	if active:
		zombies.append_array(liste)   # deuxième vague pendant l'attaque
		return
	active = true
	base = p_base
	centre = p_centre
	angle = p_angle
	zombies = liste.duplicate()
	breches = []
	detruites = 0
	_suivre_pieces()
	for z in zombies:
		z.set_meta("ab_t", randf() * 2.0)
	_bandits_opportunistes()


## Point d'apparition d'où l'on voit la base (pas de maison entre les deux : les zombies n'ont pas de recherche de chemin).
func chemin_libre(p: Vector3, c: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, c + Vector3.UP * 1.0, Game.LAYER_WORLD)
	var hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.collider is Construction


## Admin (F2) : attaque immédiate de la plus grande base.
func lancer_maintenant() -> void:
	var b: Node3D = main._base_principale()
	if b == null:
		Game.msg("Pas de base à attaquer (au moins 4 pièces de construction).")
		return
	main.horde_compte = -1.0
	main.horde_base = null
	main.horde_angle = randf() * TAU
	_radio()
	Game.msg("!! ALERTE : une horde attaque ta base par %s !" % main._nom_direction(main.horde_angle))
	main.declencher_horde(b)


func _radio() -> void:
	var ev = main.get_node_or_null("Evenements")
	if ev and ev.has_method("_jouer_radio"):
		ev._jouer_radio()


func _bandits_opportunistes() -> void:
	var chance := minf(0.12 + 0.05 * Game.semaine() + 0.05 * Game.difficulte + (0.15 if Game.sang_actif() else 0.0), 0.5)
	if randf() > chance:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var a := angle + rng.randf_range(0.7, 1.2) * (1.0 if rng.randf() < 0.5 else -1.0)
	var c := centre + Vector3(cos(a), 0, sin(a)) * 50.0
	var nb := rng.randi_range(2, 3 + mini(Game.semaine(), 2))
	var poses := 0
	for k in nb * 4:
		if poses >= nb:
			break
		var p := c + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
		if (Game.relief and Game.relief.dans_eau(p.x, p.z)) or not Game.find_zone(p + Vector3.UP).is_empty():
			continue
		p.y = Game.hauteur(p.x, p.z) + 0.1
		var b = Bandit.new()
		b.setup(CAMP_BANDITS, centre, rng)
		main.add_child(b)
		b.global_position = p
		b.state = Bandit.ALERTE
		b.cible_pos = centre
		bandits.append(b)
		poses += 1
	if poses > 0:
		Game.msg("Des bandits profitent de l'attaque : %d s'approchent de ta base par %s !" % [poses, main._nom_direction(a)])


func _process(delta: float) -> void:
	# alerte de main.annoncer_horde : message radio et repère du côté d'où la horde viendra
	var compte: float = main.horde_compte
	if compte > 0.0 and _compte_avant <= 0.0:
		_radio()
	_compte_avant = compte
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	_maj_bandits()
	if active:
		_maj_attaque()
	_maj_reperes(compte)


func _maj_reperes(compte: float) -> void:
	var liste := []
	if compte > 0.0 and main.horde_base and is_instance_valid(main.horde_base) and not is_nan(main.horde_angle):
		var c: Vector3 = main._centre_base(main.horde_base)
		var p := c + Vector3(cos(main.horde_angle), 0, sin(main.horde_angle)) * 45.0
		liste.append({"nom": "Horde en approche", "x": p.x, "z": p.z, "couleur": COULEUR})
	elif active:
		var m := Vector3.ZERO
		var n := 0
		for z in zombies:
			if _vivant(z):
				m += z.global_position
				n += 1
		if n > 0:
			m /= n
			liste.append({"nom": "Attaque (%d)" % n, "x": m.x, "z": m.z, "couleur": COULEUR})
	reperes = liste


func _vivant(z) -> bool:
	return is_instance_valid(z) and z.state != z.State.DEAD


func _maj_attaque() -> void:
	_verifier_breches()
	var restants := 0
	var en_assaut := 0
	for z in zombies:
		if not _vivant(z):
			continue
		restants += 1
		if not z.assaut:
			continue
		en_assaut += 1
		_guider(z)
	if not is_instance_valid(base) or base.is_queued_for_deletion():
		_fin("rasee")
	elif restants == 0:
		_fin("tuee")
	elif en_assaut == 0:
		_fin("aube")


## Envoie le zombie sur la pièce la plus faible (ou la brèche), et le fait taper dedans s'il est collé à elle.
func _guider(z) -> void:
	if z.get_meta("ab_dedans", false):
		return
	var t: float = z.get_meta("ab_t", 0.0) - 0.25
	var piece = z.get_meta("ab_piece") if z.has_meta("ab_piece") else null
	if t <= 0.0 or (piece != null and not is_instance_valid(piece)):
		t = 2.0
		piece = _choisir(z)
		z.set_meta("ab_piece", piece)
	z.set_meta("ab_t", t)
	if piece is Vector3:
		# brèche : on passe, puis on fonce au centre de la base
		z.assaut_pos = piece
		if _plat(z.global_position, piece) < 1.6:
			z.set_meta("ab_dedans", true)
			z.assaut_pos = centre
		return
	if piece == null:
		z.assaut_pos = centre
		return
	var pt := _point(piece)
	z.assaut_pos = pt
	# collé à la pièce (le rayon de zombie._steer peut la manquer) : coup direct
	if z.voit_joueur or _plat(z.global_position, pt) > 1.5 or z.attack_t > 0.0:
		return
	if piece.type == "porte" and piece.ouverte:
		return
	z.attack_t = 1.2
	z.lunge = 1.0
	z._anim("attaque", 1.0, 0.8)
	_frapper(piece, z.damage * 1.5, z)


func _frapper(piece: Node, degats: float, z: Node) -> void:
	piece.take_damage(degats, z)


## Pièces suivies pendant l'attaque : celle qui disparaît (cassée par _frapper ou par zombie._steer) fait une brèche.
func _suivre_pieces() -> void:
	suivies = []
	if not is_instance_valid(base):
		return
	for p in base.get_children():
		if p is Construction and not p.type in ["fondation", "plancher", "escalier"]:
			suivies.append([p, _point(p)])


func _verifier_breches() -> void:
	for s in suivies.duplicate():
		if is_instance_valid(s[0]) and not s[0].is_queued_for_deletion():
			continue
		suivies.erase(s)
		breches.append(s[1])
		detruites += 1
		Journal.compter("pieces_perdues")


func _choisir(z) -> Variant:
	var zp: Vector3 = z.global_position
	var best: Variant = null
	var bs := INF
	for b in breches:
		var s := _plat(zp, b) * 6.0 - 300.0
		if s < bs:
			bs = s
			best = b
	if not is_instance_valid(base):
		return best
	for p in base.get_children():
		if not p is Construction or p.is_queued_for_deletion() or p.pv <= 0.0:
			continue
		var genre: String = Construction.PIECES[p.type].genre
		if genre != "bord" and genre != "porte":
			continue
		var cle: String = p.cles[0]
		if int(cle.split(":")[3]) != 0:
			continue
		if p.type == "mur_porte" and base.a("p" + cle.substr(1)):
			continue   # l'encadrement : on vise la porte qu'il porte
		var s: float = p.pv * (0.5 if p.type == "porte" else 1.0)
		if p.type == "porte" and p.ouverte:
			s = -200.0
		elif p.type == "mur_porte":
			s = -150.0   # encadrement sans porte : passage ouvert
		if _interieur(cle):
			s += 2000.0
		s += _plat(zp, _point(p)) * 6.0
		if s < bs:
			bs = s
			best = p
	return best


## Côté entre deux fondations : mur intérieur (on attaque d'abord le pourtour).
func _interieur(cle: String) -> bool:
	var q := cle.split(":")
	var a := int(q[1])
	var b := int(q[2])
	var n := q[3]
	var c1: String
	var c2: String
	if absi(a) % 2 == 1:
		c1 = "c:%d:%d:%s" % [(a - 1) / 2, b / 2, n]
		c2 = "c:%d:%d:%s" % [(a + 1) / 2, b / 2, n]
	else:
		c1 = "c:%d:%d:%s" % [a / 2, (b - 1) / 2, n]
		c2 = "c:%d:%d:%s" % [a / 2, (b + 1) / 2, n]
	return base.a(c1) and base.a(c2)


## Milieu de l'emplacement de la pièce (à hauteur du sol de la base).
func _point(p: Node) -> Vector3:
	return base.to_global(Construction.position_cle(p.cles[0]))


func _plat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _fin(raison: String) -> void:
	active = false
	var tues := 0
	for z in zombies:
		if not _vivant(z):
			tues += 1
		elif is_instance_valid(z):
			z.assaut = false
			for m in ["ab_piece", "ab_t", "ab_dedans"]:
				z.remove_meta(m)
	var vivant: bool = Game.player and Game.player.alive
	if vivant and raison != "rasee":
		Journal.compter("attaques_base")
		var xp := 30 + 3 * tues
		if raison == "tuee":
			Journal.compter("attaques_repoussees")
			xp += 40
			Game.msg("Attaque repoussée ! %d zombies abattus, %d pièce(s) perdue(s) : +%d XP de survie." % [tues, detruites, xp])
		else:
			Game.msg("Le jour se lève : la horde se disperse. %d zombies abattus, %d pièce(s) perdue(s) : +%d XP de survie." % [tues, detruites, xp])
		Game.player.prog.gagner("survie", xp)
		Game.play_ui("niveau", -6.0)
	elif raison == "rasee":
		Game.msg("Ta base a été rasée par la horde…")
	zombies = []
	base = null
	# les bandits de l'attaque repartent
	for b in bandits:
		if is_instance_valid(b) and b.state != Bandit.MORT:
			b.maison = centre + Vector3(cos(angle + PI), 0, sin(angle + PI)) * 400.0
			b.cible_pos = b.maison
			if b.state == Bandit.PATROUILLE:
				b.state = Bandit.ALERTE


func _maj_bandits() -> void:
	for b in bandits.duplicate():
		if not is_instance_valid(b):
			bandits.erase(b)
		elif not active and b.state != Bandit.MORT and Game.player and b.global_position.distance_to(Game.player.global_position) > 150.0:
			bandits.erase(b)
			b.queue_free()
