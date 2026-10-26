extends Node
## Mode construction (touche B, marteau requis) : choix de la pièce à la molette, aperçu
## aimanté sur la grille de la base visée, pose au clic gauche, [G] renforcer / réparer,
## [X] démonter. Le joueur est en mode « placing = construction » pendant ce temps.

const Construction = preload("res://scripts/construction.gd")
const S := Construction.S
const H := Construction.H
const PORTEE := 7.0

var player: CharacterBody3D
var idx := 0                 # pièce choisie (Construction.ORDRE)
var tour := 0                # quarts de tour ajoutés (escalier)
var fantome: Node3D = null
var fantome_type := ""
var mat_ok: StandardMaterial3D
var mat_ko: StandardMaterial3D
# emplacement calculé
var valide := false
var raison := ""
var cible_base: Node3D = null
var cible_cles: Array = []
var cible_rot := 0.0
var cible_xf := Transform3D.IDENTITY      # repère de la base (ou de la nouvelle base)
var visee: Node = null                     # pièce visée (pour renforcer / démonter)
var visee_objet: Node = null               # piège ou barricade visé (pour réparer)


func _ready() -> void:
	mat_ok = _mat_fantome(Color(0.3, 1.0, 0.4, 0.35))
	mat_ko = _mat_fantome(Color(1.0, 0.25, 0.2, 0.35))


func _mat_fantome(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.no_depth_test = false
	return m


func type_choisi() -> String:
	return Construction.ORDRE[idx]


# ---------------------------------------------------------------- mode
func basculer() -> void:
	if player.placing == "construction":
		player.cancel_placement()
		return
	if player.count("marteau") <= 0 and not Game.admin:
		Game.msg("Il te faut un marteau de construction (fabrication : 2 ferraille + 1 planche).")
		return
	player.cancel_placement()
	player.placing = "construction"
	Game.msg("Construction : molette = pièce, R = tourner, G = renforcer / réparer, X = démonter, B = quitter.")


## Appelé par player.cancel_placement().
func nettoyer() -> void:
	if fantome and is_instance_valid(fantome):
		fantome.queue_free()
	fantome = null
	fantome_type = ""
	visee = null


func entree(event: InputEvent) -> bool:
	if event.is_action_pressed("tirer"):
		poser()
	elif event.is_action_pressed("viser") or event.is_action_pressed("pause") or event.is_action_pressed("construire"):
		player.cancel_placement()
	elif event.is_action_pressed("arme_suiv"):
		idx = (idx + 1) % Construction.ORDRE.size()
	elif event.is_action_pressed("arme_prec"):
		idx = (idx - 1 + Construction.ORDRE.size()) % Construction.ORDRE.size()
	elif event.is_action_pressed("recharger"):
		tour = (tour + 1) % 4
	elif event.is_action_pressed("ameliorer") and event is InputEventWithModifiers and event.shift_pressed:
		_toute_la_base()
	elif event.is_action_pressed("ameliorer"):
		_ameliorer()
	elif event.is_action_pressed("demonter"):
		_demonter()
	else:
		return false
	return true


# ---------------------------------------------------------------- mise à jour (chaque image)
func maj() -> void:
	var t := type_choisi()
	var space := player.get_world_3d().direct_space_state
	var from: Vector3 = player.camera.global_position
	var fwd: Vector3 = -player.camera.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * (PORTEE + player.recul_camera()), Game.LAYER_WORLD, [player.get_rid()])
	var hit := space.intersect_ray(q)
	visee = null
	var pt: Vector3 = from + fwd * 4.0
	var nrm := Vector3.UP
	if not hit.is_empty():
		pt = hit.position
		nrm = hit.normal
		if hit.collider is Node and hit.collider.is_in_group("construction"):
			visee = hit.collider
	# piège ou barricade visé (réparation au marteau)
	visee_objet = null
	if visee == null:
		var q2 := PhysicsRayQueryParameters3D.create(from, from + fwd * (4.0 + player.recul_camera()), Game.LAYER_WORLD | Game.LAYER_INTERACT, [player.get_rid()])
		var h2 := space.intersect_ray(q2)
		if not h2.is_empty() and h2.collider.get("health_max") != null and h2.collider.kind in h2.collider.COUT_REPARATION:
			visee_objet = h2.collider
	_calculer(t, pt, nrm)
	_maj_fantome(t)
	player.prompt = _texte(t)


func _calculer(t: String, pt: Vector3, nrm: Vector3) -> void:
	valide = false
	raison = ""
	cible_base = _base_proche(pt)
	cible_cles = []
	cible_rot = 0.0
	var genre: String = Construction.PIECES[t].genre
	if cible_base == null:
		if t != "fondation":
			raison = "Commence par une fondation."
			cible_xf = Transform3D(Basis(Vector3.UP, player.rotation.y), pt)
			return
		_fondation_libre(pt)
		return
	cible_xf = cible_base.global_transform
	var loc: Vector3 = cible_base.to_local(pt + nrm * 0.25)
	match genre:
		"case":
			_choisir_case(t, loc)
		"bord":
			_choisir_bord(loc)
		"escalier":
			_choisir_escalier(loc)
		"porte":
			_choisir_porte()
	if valide:
		_verifier_place(t)


## Base dont une pièce est proche du point visé.
func _base_proche(pt: Vector3) -> Node3D:
	var meilleure: Node3D = null
	var dmin := 5.0
	for b in get_tree().get_nodes_in_group("base_construction"):
		for p in b.get_children():
			var d: float = (p as Node3D).global_position.distance_to(pt)
			if d < dmin:
				dmin = d
				meilleure = b
	return meilleure


## Première fondation : nouvelle base posée sur le terrain, tournée comme le joueur.
func _fondation_libre(pt: Vector3) -> void:
	var b := Basis(Vector3.UP, player.rotation.y)
	var hauts := _hauteurs_coins(Transform3D(b, pt), [])
	if hauts.is_empty():
		raison = "Il faut poser la fondation sur le sol."
		cible_xf = Transform3D(b, pt)
		return
	var haut: float = hauts.max() + 0.12
	cible_xf = Transform3D(b, Vector3(pt.x, haut, pt.z))
	cible_cles = ["c:0:0:0"]
	if haut - hauts.min() > 1.5:
		raison = "Terrain trop en pente."
		return
	if not Game.find_zone(cible_xf.origin + Vector3.UP * 0.5).is_empty():
		raison = "Impossible dans un bâtiment existant."
		return
	if player.global_position.distance_to(cible_xf.origin) > PORTEE:
		raison = "Trop loin."
		return
	valide = true
	_verifier_place("fondation")


## Hauteur du sol sous les quatre coins d'une case (vide si un coin est dans le vide).
func _hauteurs_coins(xf: Transform3D, exclus: Array) -> Array:
	var space := player.get_world_3d().direct_space_state
	var res := []
	for c in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1), Vector3.ZERO]:
		var w: Vector3 = xf * (c * (S / 2.0 - 0.1))
		var q := PhysicsRayQueryParameters3D.create(w + Vector3.UP * 3.0, w + Vector3.DOWN * 4.0, Game.LAYER_WORLD, exclus)
		var h := space.intersect_ray(q)
		if h.is_empty():
			return []
		res.append(h.position.y)
	return res


func _choisir_case(t: String, loc: Vector3) -> void:
	var i0 := roundi(loc.x / S)
	var j0 := roundi(loc.z / S)
	var niv := 0 if t == "fondation" else maxi(1, roundi((loc.y + 0.3) / H))
	var cases := []
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = Vector2i(i0, j0) + d
		cases.append([Vector2(c.x * S - loc.x, c.y * S - loc.z).length(), c])
	cases.sort_custom(func(a, b): return a[0] < b[0])
	for e in cases:
		var c: Vector2i = e[1]
		var cle := "c:%d:%d:%d" % [c.x, c.y, niv]
		cible_cles = [cle]
		if cible_base.a(cle):
			_refus("Emplacement occupé.")
			continue
		if t == "fondation":
			if not (_a_case(c + Vector2i(1, 0), 0) or _a_case(c - Vector2i(1, 0), 0) or _a_case(c + Vector2i(0, 1), 0) or _a_case(c - Vector2i(0, 1), 0)):
				_refus("Une fondation doit toucher une autre fondation.")
				continue
			var exclus := []
			for p in cible_base.get_children():
				exclus.append(p.get_rid())
			var hauts := _hauteurs_coins(cible_xf * Transform3D(Basis(), Vector3(c.x * S, 0, c.y * S)), exclus)
			var top: float = cible_base.global_position.y
			if hauts.is_empty() or hauts.min() < top - 1.5:
				_refus("Terrain trop bas ici.")
				continue
			if hauts.max() > top + 0.3:
				_refus("Terrain trop haut ici.")
				continue
		else:
			# plancher : sur des murs de l'étage du dessous, ou à côté d'un autre plancher
			var appui := false
			for b in _bords(c):
				if cible_base.a("b:%d:%d:%d" % [b.x, b.y, niv - 1]):
					appui = true
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _a_case(c + d, niv):
					appui = true
			if not appui:
				_refus("Un plancher doit reposer sur des murs.")
				continue
		valide = true
		return
	cible_cles = ["c:%d:%d:%d" % [cases[0][1].x, cases[0][1].y, niv]]


## Garde la raison du refus du candidat le plus proche.
func _refus(r: String) -> void:
	if raison == "":
		raison = r


func _a_case(c: Vector2i, niv: int) -> bool:
	return cible_base.a("c:%d:%d:%d" % [c.x, c.y, niv])


## Côtés d'une case (coordonnées doublées).
func _bords(c: Vector2i) -> Array:
	return [Vector2i(2 * c.x + 1, 2 * c.y), Vector2i(2 * c.x - 1, 2 * c.y), Vector2i(2 * c.x, 2 * c.y + 1), Vector2i(2 * c.x, 2 * c.y - 1)]


func _choisir_bord(loc: Vector3) -> void:
	var niv := maxi(0, floori((loc.y + 0.2) / H))
	var c0 := Vector2i(roundi(loc.x / S), roundi(loc.z / S))
	var bords := []
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		for b in _bords(c0 + Vector2i(d)):
			bords.append([Vector2(b.x * S / 2.0 - loc.x, b.y * S / 2.0 - loc.z).length(), b])
	bords.sort_custom(func(a, b): return a[0] < b[0])
	for e in bords.slice(0, 4):
		var b: Vector2i = e[1]
		var cle := "b:%d:%d:%d" % [b.x, b.y, niv]
		cible_cles = [cle]
		cible_rot = Construction.rotation_bord(cle)
		if cible_base.a(cle):
			_refus("Emplacement occupé.")
			continue
		# cases de part et d'autre du côté
		var ca := Vector2i(floori(b.x / 2.0), floori(b.y / 2.0))
		var cb := Vector2i(ceili(b.x / 2.0), ceili(b.y / 2.0))
		if _a_case(ca, niv) or _a_case(cb, niv) or cible_base.a("b:%d:%d:%d" % [b.x, b.y, niv - 1]):
			valide = true
			return
		_refus("Il faut un plancher ou une fondation.")
	# rien de possible : l'aperçu reste sur le côté le plus proche
	cible_cles = ["b:%d:%d:%d" % [bords[0][1].x, bords[0][1].y, niv]]
	cible_rot = Construction.rotation_bord(cible_cles[0])


func _choisir_escalier(loc: Vector3) -> void:
	var c := Vector2i(roundi(loc.x / S), roundi(loc.z / S))
	var niv := maxi(0, floori((loc.y + 0.2) / H))
	# l'escalier monte dans la direction du regard (+ quarts de tour avec R)
	var avant: Vector3 = cible_base.global_basis.inverse() * (-player.global_basis.z)
	var base_rot := snappedf(atan2(-avant.x, -avant.z), PI / 2.0)
	cible_rot = base_rot + tour * PI / 2.0
	cible_cles = ["e:%d:%d:%d" % [c.x, c.y, niv], "c:%d:%d:%d" % [c.x, c.y, niv + 1]]
	if not _a_case(c, niv):
		raison = "Un escalier se pose sur un plancher ou une fondation."
		return
	if cible_base.a(cible_cles[0]) or cible_base.a(cible_cles[1]):
		raison = "Emplacement occupé (rien au-dessus de l'escalier)."
		return
	valide = true


func _choisir_porte() -> void:
	if visee == null or visee.type != "mur_porte" or visee.get_parent() != cible_base:
		raison = "Vise un encadrement de porte."
		return
	var cle := "p" + String(visee.cles[0]).substr(1)
	cible_cles = [cle]
	cible_rot = Construction.rotation_bord(cle)
	if cible_base.a(cle):
		raison = "Il y a déjà une porte."
		return
	valide = true


## Pas de joueur ni de zombie dans le volume de la pièce, et pas trop loin.
func _verifier_place(t: String) -> void:
	var pos: Vector3 = cible_xf * Construction.position_cle(cible_cles[0])
	if player.global_position.distance_to(pos) > PORTEE + 1.5:
		valide = false
		raison = "Trop loin."
		return
	var taille := Vector3(S - 0.2, 0.5, S - 0.2)
	var centre := Vector3(0, -0.2, 0)
	match Construction.PIECES[t].genre:
		"bord":
			taille = Vector3(S, Construction.HM - 0.1, 0.3)
			centre = Vector3(0, Construction.HM / 2.0, 0)
		"escalier":
			taille = Vector3(1.6, H - 0.2, S - 0.2)
			centre = Vector3(0, H / 2.0, 0)
		"porte":
			return
	var sq := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = taille
	sq.shape = bs
	sq.transform = cible_xf * Transform3D(Basis(Vector3.UP, cible_rot), Construction.position_cle(cible_cles[0])) * Transform3D(Basis(), centre)
	sq.collision_mask = Game.LAYER_PLAYER | Game.LAYER_ZOMBIE
	if not player.get_world_3d().direct_space_state.intersect_shape(sq, 1).is_empty():
		valide = false
		raison = "Quelqu'un gêne."


# ---------------------------------------------------------------- aperçu
func _maj_fantome(t: String) -> void:
	if fantome_type != t:
		if fantome and is_instance_valid(fantome):
			fantome.queue_free()
		fantome = Node3D.new()
		fantome.top_level = true
		player.get_parent().add_child(fantome)
		Construction.maillages(fantome, t, 0, false, mat_ok)
		for mi in fantome.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fantome_type = t
	fantome.visible = not cible_cles.is_empty()
	if cible_cles.is_empty():
		return
	var cle: String = cible_cles[0]
	var local := Transform3D(Basis(Vector3.UP, cible_rot), Construction.position_cle(cle))
	if t == "porte":
		local = Transform3D(Basis(Vector3.UP, cible_rot), Construction.position_cle(cle) + Basis(Vector3.UP, cible_rot) * Vector3(-Construction.PORTE_L / 2.0, 0, 0))
	fantome.global_transform = cible_xf * local
	var m := mat_ok if valide else mat_ko
	for mi in fantome.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m


func _texte(t: String) -> String:
	var cout: Dictionary = Construction.PIECES[t].cout
	var l1 := "CONSTRUCTION — %s (bois) : %s" % [Construction.PIECES[t].nom, Construction.texte_cout(cout)]
	if not valide and raison != "":
		l1 += "   ✖ " + raison
	var l2 := ""
	if visee and is_instance_valid(visee):
		l2 = "\nVisé : %s %d/%d PV" % [visee.nom_complet(), int(visee.pv), int(visee.pv_max())]
		if visee.pv < visee.pv_max() - 0.5:
			l2 += "  — [G] réparer : " + Construction.texte_cout(_cout_reparation(visee))
		elif visee.tier < Construction.tier_max(visee.type):
			l2 += "  — [G] renforcer en %s : %s" % [Construction.TIERS[visee.tier + 1].nom, Construction.texte_cout(Construction.cout_amelioration(visee.type, visee.tier + 1))]
		l2 += "  — [X] démonter"
		var tb := _plan_base(visee.get_parent())
		if not tb.pieces.is_empty():
			l2 += "\n[Maj+G] %s toute la base (%d) : %s" % ["réparer" if tb.mode == "reparer" else "renforcer d'un niveau", tb.pieces.size(), Construction.texte_cout(tb.cout)]
	elif visee_objet and is_instance_valid(visee_objet):
		l2 = "\nVisé : %s %d/%d PV" % [visee_objet.nom_piege(), int(visee_objet.health), int(visee_objet.health_max)]
		if visee_objet.health < visee_objet.health_max - 0.5:
			l2 += "  — [G] réparer : " + Construction.texte_cout(visee_objet.COUT_REPARATION[visee_objet.kind])
	return l1 + l2 + "\n[Clic gauche] poser · [Molette] pièce · [R] tourner · [B] quitter"


# ---------------------------------------------------------------- actions
func _payer(cout: Dictionary) -> bool:
	if Game.admin:
		return true
	var manque := []
	for m in cout:
		if player.count(m) < int(cout[m]):
			manque.append("%d %s" % [int(cout[m]) - player.count(m), Items.nom(m).to_lower()])
	if not manque.is_empty():
		Game.msg("Il manque : " + ", ".join(manque))
		return false
	for m in cout:
		player.remove_item(m, int(cout[m]))
	return true


func poser() -> void:
	if not valide:
		Game.msg(raison)
		return
	if not _marteau_ok():
		return
	var t := type_choisi()
	if not _payer(Construction.PIECES[t].cout):
		return
	var base: Node3D = cible_base
	if base == null:
		base = Construction.Base.new()
		player.get_parent().add_child(base)
		base.global_transform = cible_xf
	var p = Construction.new()
	p.setup(t, 0, cible_cles.duplicate(), cible_rot)
	if player.prog.a("charpentier"):
		p.pv *= 1.6
	base.ajouter(p)
	Game.play_ui("construire", -3.0, 0.1)
	Game.make_noise(player.global_position, 8.0)
	player.user("marteau", 1)
	player.prog.gagner("fabrication", 4)


func _cout_reparation(p: Node) -> Dictionary:
	var base: Dictionary = Construction.PIECES[p.type].cout if p.tier == 0 else Construction.cout_amelioration(p.type, p.tier)
	var res := {}
	for m in base:
		res[m] = maxi(1, int(ceil(float(base[m]) * 0.4)))
	return res


func _ameliorer() -> void:
	if not _marteau_ok():
		return
	if visee == null and visee_objet and is_instance_valid(visee_objet):
		_reparer_objet(visee_objet)
		return
	if visee == null or not is_instance_valid(visee):
		Game.msg("Vise une pièce de ta base.")
		return
	if visee.pv < visee.pv_max() - 0.5:
		if _payer(_cout_reparation(visee)):
			visee.pv = visee.pv_max()
			player.user("marteau", 1)
			Game.play_ui("construire", -4.0, 0.1, 1.1)
			Game.msg("Réparé : " + visee.nom_complet())
		return
	if visee.tier >= Construction.tier_max(visee.type):
		Game.msg("%s est déjà au plus solide." % visee.nom_complet())
		return
	if not _payer(Construction.cout_amelioration(visee.type, visee.tier + 1)):
		return
	visee.tier += 1
	visee.pv = visee.pv_max()
	visee._reconstruire()
	Game.play_ui("construire", -2.0, 0.1, 0.9)
	player.user("marteau", 1)
	player.prog.gagner("fabrication", 6)
	Game.msg("Renforcé : " + visee.nom_complet())


## Toute la base visée d'un coup : s'il y a des dégâts, tout réparer (pièces, pièges et barricades
## à moins de 25 m) ; sinon renforcer chaque pièce d'un niveau. Coût total payé en une fois.
var _plan_cache := {}
var _plan_t := -1.0


func _plan_base(base: Node) -> Dictionary:
	var t := Time.get_ticks_msec() / 1000.0
	if _plan_t >= 0.0 and t - _plan_t < 0.5 and _plan_cache.get("base") == base:
		return _plan_cache
	_plan_t = t
	var abimees: Array = []
	var a_renforcer: Array = []
	var objets: Array = []
	if base and is_instance_valid(base):
		for p in base.get_children():
			if not p is Construction:
				continue
			if p.pv < p.pv_max() - 0.5:
				abimees.append(p)
			elif p.tier < Construction.tier_max(p.type):
				a_renforcer.append(p)
		for o in get_tree().get_nodes_in_group("placeables"):
			if o.kind in o.COUT_REPARATION and o.health < o.health_max - 0.5 \
					and o.global_position.distance_to((base as Node3D).global_position) < 25.0:
				objets.append(o)
	var plan := {"base": base, "mode": "reparer", "pieces": abimees + objets, "cout": {}}
	if plan.pieces.is_empty():
		plan.mode = "renforcer"
		plan.pieces = a_renforcer
	for p in plan.pieces:
		var c: Dictionary
		if p is Construction:
			c = _cout_reparation(p) if plan.mode == "reparer" else Construction.cout_amelioration(p.type, p.tier + 1)
		else:
			c = p.COUT_REPARATION[p.kind]
		for m in c:
			plan.cout[m] = int(plan.cout.get(m, 0)) + int(c[m])
	_plan_cache = plan
	return plan


func _toute_la_base() -> void:
	if visee == null or not is_instance_valid(visee):
		Game.msg("Vise une pièce de ta base.")
		return
	_plan_t = -1.0
	var plan := _plan_base(visee.get_parent())
	if plan.pieces.is_empty():
		Game.msg("Toute la base est déjà au plus solide.")
		return
	if not _marteau_ok():
		return
	if not _payer(plan.cout):
		return
	for p in plan.pieces:
		if not is_instance_valid(p):
			continue
		if p is Construction:
			if plan.mode == "renforcer":
				p.tier += 1
				p._reconstruire()
			p.pv = p.pv_max()
		else:
			p.health = p.health_max
	_plan_t = -1.0
	Game.play_ui("construire", -2.0, 0.1, 0.9)
	player.user("marteau", plan.pieces.size())
	player.prog.gagner("fabrication", (3 if plan.mode == "reparer" else 6) * plan.pieces.size())
	Game.msg("%s : %d élément(s)." % ["Base réparée" if plan.mode == "reparer" else "Base renforcée", plan.pieces.size()])


## Piège ou barricade : réparation complète pour un peu de matériaux.
func _reparer_objet(o: Node) -> void:
	if o.health >= o.health_max - 0.5:
		Game.msg("%s : en parfait état." % o.nom_piege())
		return
	if not _marteau_ok():
		return
	if not _payer(o.COUT_REPARATION[o.kind]):
		return
	o.health = o.health_max
	player.user("marteau", 1)
	Game.play_ui("construire", -4.0, 0.1, 1.1)
	player.prog.gagner("fabrication", 2)
	Game.msg("Réparé : " + o.nom_piege())


func _demonter() -> void:
	if visee == null or not is_instance_valid(visee):
		Game.msg("Vise une pièce de ta base.")
		return
	var base: Node3D = visee.get_parent()
	var cle: String = visee.cles[0]
	var parts := cle.split(":")
	# une pièce qui en porte d'autres ne peut pas être démontée
	if parts[0] == "c":
		var c := Vector2i(int(parts[1]), int(parts[2]))
		var niv := int(parts[3])
		for b in _bords(c):
			if base.a("b:%d:%d:%d" % [b.x, b.y, niv]):
				Game.msg("Démonte d'abord les murs posés dessus.")
				return
		if base.a("e:%d:%d:%d" % [c.x, c.y, niv]):
			Game.msg("Démonte d'abord l'escalier.")
			return
	if visee.type == "mur_porte" and base.a("p" + cle.substr(1)):
		Game.msg("Démonte d'abord la porte.")
		return
	# on récupère la moitié du bois
	var cout: Dictionary = Construction.PIECES[visee.type].cout
	for m in cout:
		var n := int(cout[m]) / 2
		if n > 0:
			player.add_item(m, n)
	Game.play_ui("construire", -6.0, 0.1, 1.2)
	Game.msg("Démonté : " + visee.nom_complet())
	visee.detruire()
	visee = null


## Marteau usé (items.gd « durab ») : 1 point par pose, renforcement ou réparation ; cassé = plus de construction.
func _marteau_ok() -> bool:
	if Game.admin or not player.est_cassee("marteau"):
		return true
	Game.msg("Ton marteau est cassé : répare-le avec un kit de réparation (clic droit dans l'inventaire).")
	return false
