extends CharacterBody3D
## Animaux sauvages : cerf et biche (modèles animés de Quaternius), sanglier, lapin et faisan (modèles Poly by Google
## découpés en tête et pattes animées par le code, cf. outils/godot/normaliser_animaux.gd).
## Ils paissent autour de leur point de départ, entendent les bruits (Game.make_noise), voient le joueur
## (moins s'il est accroupi ou caché) et fuient ; le sanglier peut charger. Loups et chiens sauvages (Quaternius, animés)
## chassent en meute ; les corbeaux s'envolent en alertant les zombies ; vaches, chevaux (Quaternius) et moutons dans
## les fermes, peu farouches. Mort : [F] pour dépecer au couteau.
## Placés et retirés par cases autour du joueur (scripts/faune.gd).

enum Etat { PAIT, FUIT, CHARGE, MORT }

# pv, vitesse de marche, vitesse de fuite, distance de vue (m), finesse de l'ouïe, rayon et hauteur du corps
const TYPES := {
	"cerf": {"nom": "Cerf", "pv": 140.0, "marche": 1.6, "fuite": 11.0, "vue": 38.0, "ouie": 1.6, "rayon": 0.35, "haut": 1.5},
	"biche": {"nom": "Biche", "pv": 100.0, "marche": 1.5, "fuite": 11.5, "vue": 40.0, "ouie": 1.7, "rayon": 0.32, "haut": 1.2},
	"sanglier": {"nom": "Sanglier", "pv": 170.0, "marche": 1.2, "fuite": 8.5, "vue": 20.0, "ouie": 1.2, "rayon": 0.38, "haut": 0.85},
	"lapin": {"nom": "Lapin", "pv": 18.0, "marche": 0.9, "fuite": 8.0, "vue": 15.0, "ouie": 1.3, "rayon": 0.14, "haut": 0.3},
	"faisan": {"nom": "Faisan", "pv": 14.0, "marche": 0.7, "fuite": 9.5, "vue": 17.0, "ouie": 1.4, "rayon": 0.14, "haut": 0.35, "vole": true},
	# prédateurs en meute : attaquent dès qu'ils voient le joueur (« degats » par morsure, « charge » = vitesse d'attaque)
	"loup": {"nom": "Loup", "pv": 90.0, "marche": 1.4, "fuite": 10.0, "vue": 32.0, "ouie": 1.6, "rayon": 0.28, "haut": 0.9, "meute": true, "degats": 10.0, "charge": 9.0},
	"chien": {"nom": "Chien sauvage", "pv": 60.0, "marche": 1.5, "fuite": 9.0, "vue": 26.0, "ouie": 1.5, "rayon": 0.25, "haut": 0.75, "meute": true, "degats": 9.0, "charge": 8.5},
	# oiseau qui s'envole quand on approche, en alertant les zombies alentour
	"corbeau": {"nom": "Corbeau", "pv": 8.0, "marche": 0.5, "fuite": 10.0, "vue": 24.0, "ouie": 1.8, "rayon": 0.12, "haut": 0.3, "vole": true},
	# bêtes de ferme abandonnées : peu farouches, fuient sur une courte distance
	"vache": {"nom": "Vache", "pv": 240.0, "marche": 0.9, "fuite": 5.5, "vue": 12.0, "ouie": 1.0, "rayon": 0.45, "haut": 1.4, "ferme": true},
	"cheval": {"nom": "Cheval", "pv": 190.0, "marche": 1.4, "fuite": 12.0, "vue": 26.0, "ouie": 1.4, "rayon": 0.4, "haut": 1.6, "ferme": true},
	"cheval_blanc": {"nom": "Cheval", "pv": 190.0, "marche": 1.4, "fuite": 12.0, "vue": 26.0, "ouie": 1.4, "rayon": 0.4, "haut": 1.6, "ferme": true},
	"mouton": {"nom": "Mouton", "pv": 50.0, "marche": 0.8, "fuite": 6.0, "vue": 16.0, "ouie": 1.2, "rayon": 0.28, "haut": 0.8, "ferme": true},
}
# ce que rend le dépeçage : [min, max]
const DEPECAGE := {
	"cerf": {"viande_crue": [4, 6], "peau": [2, 3], "os": [2, 3], "graisse": [1, 2]},
	"biche": {"viande_crue": [3, 4], "peau": [2, 2], "os": [1, 2], "graisse": [1, 1]},
	"sanglier": {"viande_crue": [3, 5], "peau": [2, 2], "os": [1, 2], "graisse": [2, 3]},
	"lapin": {"viande_crue": [1, 1], "peau": [1, 1], "os": [0, 1]},
	"faisan": {"viande_crue": [1, 1], "plume": [4, 8], "os": [0, 1]},
	"loup": {"viande_crue": [2, 3], "peau": [1, 2], "os": [1, 2], "graisse": [0, 1]},
	"chien": {"viande_crue": [1, 2], "peau": [1, 1], "os": [1, 1]},
	"corbeau": {"plume": [3, 6], "os": [0, 1]},
	"vache": {"viande_crue": [6, 9], "peau": [3, 4], "os": [3, 4], "graisse": [2, 3]},
	"cheval": {"viande_crue": [5, 8], "peau": [3, 3], "os": [3, 4], "graisse": [1, 2]},
	"cheval_blanc": {"viande_crue": [5, 8], "peau": [3, 3], "os": [3, 4], "graisse": [1, 2]},
	"mouton": {"viande_crue": [2, 4], "peau": [1, 2], "tissu": [1, 3], "os": [1, 2], "graisse": [1, 1]},
}
const LAMES := ["couteau_km2000", "machette", "hache"]
const GRAVITE := 18.0

var kind := "lapin"
var etat := Etat.PAIT
var pv := 20.0
var maison := Vector3.ZERO          # point autour duquel il pait
var faune: Node = null              # gestionnaire qui l'a placé (scripts/faune.gd)
var case_faune := Vector2i.ZERO
var t_etat := 0.0
var vise := Vector3.ZERO            # point vers lequel il marche en paissant
var broute := false
var menace := Vector3.ZERO          # ce qu'il fuit
var vue_t := 0.0
var attaque_t := 0.0
var vol := false                     # faisan en vol
var vol_t := 0.0
var mort_t := 0.0
var depece := false
var vitesse_h := 0.0
var cap := 0.0                       # orientation voulue (rad)
var ap: AnimationPlayer = null       # cerf / biche
var anim := ""
var reaction_t := 0.0               # sursaut quand il est touché (Idle_HitReact), avant de fuir ou de charger
var repos_anim := "Idle"            # variante de repos (Idle, Idle_2, tête basse), changée de temps en temps
var repos_t := 0.0
var modele: Node3D
var pattes: Array = []               # [pivot, phase] des modèles faits par le code
var tete: Node3D = null
var corps_modele: Node3D = null     # corps du modèle découpé (bascule en vol)
var ailes: Array = []
var phase := 0.0
var _mats := {}


func preparer(p_kind: String, pos: Vector3) -> void:
	kind = p_kind
	position = pos
	maison = pos
	pv = TYPES[kind].pv


func _ready() -> void:
	add_to_group("animaux")
	collision_layer = Game.LAYER_ZOMBIE     # touché par les balles, les flèches et la mêlée
	collision_mask = Game.LAYER_WORLD
	floor_snap_length = 0.4
	var t: Dictionary = TYPES[kind]
	var cs := CollisionShape3D.new()
	var forme := CapsuleShape3D.new()
	forme.radius = t.rayon
	forme.height = maxf(t.haut, t.rayon * 2.0 + 0.01)
	cs.shape = forme
	cs.position.y = forme.height / 2.0
	add_child(cs)
	_construire()
	cap = randf() * TAU
	rotation.y = cap
	t_etat = randf_range(1.0, 6.0)
	broute = true
	Game.noise_made.connect(_bruit)


func nom() -> String:
	return TYPES[kind].nom


# ================================================================ comportement
func _physics_process(delta: float) -> void:
	var p = Game.player
	if etat == Etat.MORT:
		mort_t += delta
		if mort_t > 600.0 or (mort_t > 30.0 and p and global_position.distance_to(p.global_position) > 220.0):
			queue_free()
			return
		if not is_on_floor():
			velocity = Vector3(0, velocity.y - GRAVITE * delta, 0)
			move_and_slide()
		return
	if p == null:
		return
	var d_joueur: float = global_position.distance_to(p.global_position)
	if d_joueur > 170.0:
		return                       # trop loin : immobile (le gestionnaire le retirera)
	vue_t -= delta
	if vue_t <= 0.0:
		vue_t = 0.3
		_percevoir(p, d_joueur)
	t_etat -= delta
	attaque_t = maxf(0.0, attaque_t - delta)
	var t: Dictionary = TYPES[kind]
	var voulu := 0.0
	match etat:
		Etat.PAIT:
			if t_etat <= 0.0:
				broute = not broute or randf() < 0.3
				t_etat = randf_range(3.0, 9.0) if broute else randf_range(2.0, 5.0)
				if not broute:
					var a := randf() * TAU
					vise = maison + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 14.0)
			if not broute:
				var v := vise - global_position
				v.y = 0.0
				if v.length() < 0.8:
					broute = true
					t_etat = randf_range(3.0, 8.0)
				else:
					cap = atan2(-v.x, -v.z)
					voulu = t.marche
		Etat.FUIT:
			var v := global_position - menace
			v.y = 0.0
			if t_etat <= 0.0 or v.length() > 70.0:
				_calmer()
			else:
				cap = atan2(-v.x, -v.z) + sin(Time.get_ticks_msec() * 0.0013 + get_instance_id()) * 0.35
				voulu = t.fuite
		Etat.CHARGE:
			var v: Vector3 = p.global_position - global_position
			v.y = 0.0
			cap = atan2(-v.x, -v.z)
			voulu = float(t.get("charge", 8.5))
			var meute: bool = t.get("meute", false)
			if v.length() < (1.3 if meute else 1.5) and attaque_t <= 0.0 and p.alive:
				attaque_t = 1.5 if meute else 1.6
				p.take_damage(float(t.get("degats", 22.0)), self)
				Game.play_3d("grogne2", global_position, 2.0 if not meute else -2.0, 0.1, 40.0, 1.5 if meute else 1.0)
				if randf() < (0.15 if meute else 0.45):
					_fuir(p.global_position, 7.0)
			elif meute and v.length() < 1.6:
				voulu = 0.0   # au contact : mord sur place
			if t_etat <= 0.0 or not p.alive:
				_fuir(p.global_position, 6.0)
	# rotation progressive, déplacement, gravité
	rotation.y = lerp_angle(rotation.y, cap, minf(1.0, delta * (7.0 if voulu > 3.0 else 3.0)))
	vitesse_h = move_toward(vitesse_h, voulu, delta * (14.0 if voulu > vitesse_h else 8.0))
	var avant := -global_basis.z
	velocity.x = avant.x * vitesse_h
	velocity.z = avant.z * vitesse_h
	if vol:
		_voler(delta)
	elif not is_on_floor():
		velocity.y -= GRAVITE * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	# bloqué contre un obstacle en paissant : autre direction
	if etat == Etat.PAIT and not broute and get_real_velocity().length() < voulu * 0.3 and voulu > 0.0:
		var a := randf() * TAU
		vise = global_position + Vector3(cos(a), 0, sin(a)) * 8.0
	_animer(delta)


func _voler(delta: float) -> void:
	vol_t += delta
	var montee := 4.0 if kind == "corbeau" else 1.4
	velocity.y = lerpf(velocity.y, 3.2 if vol_t < montee else -1.6, minf(1.0, delta * 3.0))
	if vol_t > montee + 0.2 and is_on_floor():
		vol = false


func _percevoir(p: Node, d: float) -> void:
	if not p.alive or etat == Etat.CHARGE or (Game.admin and Game.admin_invisible):
		return
	var portee: float = TYPES[kind].vue * (0.7 if p.prog.a("pisteur") else 1.0)
	if p.crouching:
		portee *= 0.45 if Vector2(p.velocity.x, p.velocity.z).length() > 0.5 else 0.3
	if p.cache_buisson:
		portee *= 0.5
	if p.sprinting:
		portee *= 1.3
	if Game.is_night() and not TYPES[kind].get("meute", false):
		portee *= 0.7
	if d < portee:
		_alerte(p.global_position, d)


func _bruit(pos: Vector3, rayon: float) -> void:
	if etat == Etat.MORT or not is_inside_tree():
		return
	var d := global_position.distance_to(pos)
	if d < rayon * float(TYPES[kind].ouie):
		_alerte(pos, d)


func _alerte(pos: Vector3, d: float) -> void:
	if etat == Etat.FUIT:
		menace = pos
		t_etat = maxf(t_etat, 4.0)
		return
	if etat == Etat.CHARGE:
		return
	var t: Dictionary = TYPES[kind]
	if t.get("meute", false) and pv > float(t.pv) * 0.35 and Game.player and Game.player.alive:
		_charger()
	elif kind == "sanglier" and d < 16.0 and randf() < 0.55 and Game.player and Game.player.alive:
		_charger()
	elif t.get("ferme", false):
		_fuir(pos, randf_range(2.5, 4.5))
	else:
		_fuir(pos, randf_range(6.0, 10.0))


func _fuir(depuis: Vector3, duree: float) -> void:
	etat = Etat.FUIT
	menace = depuis
	t_etat = duree
	if TYPES[kind].get("vole", false) and not vol:
		vol = true
		vol_t = 0.0
		velocity.y = 4.0
		Game.play_3d("vent_leger", global_position, -6.0, 0.2, 30.0)
		if kind == "corbeau":
			# l'envol des corbeaux attire les zombies alentour
			t_etat = maxf(t_etat, 12.0)
			Game.make_noise.call_deferred(global_position, 22.0)
	elif kind in ["cerf", "biche"] and randf() < 0.5:
		Game.play_3d("souffle", global_position, -10.0, 0.2, 35.0)


func _charger(propager := true) -> void:
	var meute: bool = TYPES[kind].get("meute", false)
	if etat == Etat.CHARGE:
		return
	etat = Etat.CHARGE
	t_etat = 14.0 if meute else 7.0
	Game.play_3d("grogne1", global_position, 0.0 if not meute else -4.0, 0.15, 45.0, 1.45 if meute else 1.0)
	if meute and propager:
		for a in get_tree().get_nodes_in_group("animaux"):
			if a != self and a.kind == kind and a.global_position.distance_to(global_position) < 45.0:
				a._charger(false)


func _calmer() -> void:
	etat = Etat.PAIT
	maison = global_position
	broute = true
	t_etat = randf_range(2.0, 5.0)


# ================================================================ dégâts / mort
func take_hit(dmg: float, pos: Vector3, from: Vector3) -> void:
	if etat == Etat.MORT:
		return
	Game.signaler_degats(self, dmg, pv, pos, from, false)
	pv -= dmg
	Game.spawn_blood(pos, get_parent())
	var tue := pv <= 0.0
	if not tue and ap:
		var reac := "Idle_HitReact%d" % randi_range(1, 2)
		if ap.has_animation(reac):
			reaction_t = 0.3
			anim = reac
			ap.play(reac, 0.05)
			ap.speed_scale = 1.4
	Game.hit_confirmed.emit(false, tue)
	if tue:
		_mourir()
	elif kind == "sanglier" and from.distance_to(global_position) < 30.0 and randf() < 0.7:
		_charger()
	elif TYPES[kind].get("meute", false) and pv > float(TYPES[kind].pv) * 0.35:
		_charger()
	else:
		_fuir(from, randf_range(8.0, 12.0))


func take_damage(amount: float, from: Node = null) -> void:
	take_hit(amount, global_position + Vector3.UP * 0.5, (from as Node3D).global_position if from is Node3D else global_position)


func _mourir() -> void:
	etat = Etat.MORT
	vol = false
	velocity = Vector3.ZERO
	remove_from_group("animaux")
	add_to_group("carcasses")
	collision_layer = Game.LAYER_INTERACT
	collision_mask = Game.LAYER_WORLD
	if Game.player:
		Game.player.prog.gagner("chasse", 10)
		Game.player.prog.gagner("survie", 3)
	if faune and is_instance_valid(faune):
		faune.mort(self)
	if ap and ap.has_animation("Death"):
		ap.play("Death")
		return
	for pa in pattes:
		pa[0].rotation.x = 0.0
	# couché sur le flanc
	var tw := create_tween()
	tw.tween_property(modele, "rotation:z", PI / 2.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(modele, "position:y", float(TYPES[kind].rayon) * 0.7, 0.35)


func _lame(player: Node) -> String:
	for l in LAMES:
		if player.count(l) > 0:
			return l
	return ""


func get_prompt() -> String:
	if etat != Etat.MORT or depece:
		return ""
	if Game.player and _lame(Game.player) == "":
		return "%s mort (il faut une lame pour le dépecer)" % nom()
	return "[F] Dépecer : %s" % nom()


func interact(player: Node) -> void:
	if etat != Etat.MORT or depece:
		return
	if _lame(player) == "":
		Game.msg("Il te faut un couteau (ou une machette, une hache) pour dépecer.")
		return
	depece = true
	if player.has_method("geste"):
		player.geste("depecage")
	for id in DEPECAGE[kind]:
		var r: Array = DEPECAGE[kind][id]
		var n := randi_range(int(r[0]), int(r[1]))
		if id in ["viande_crue", "peau"] and player.prog.a("depeceur"):
			n += 1
		if n > 0:
			player.add_item(id, n)
	var nf := int(get_meta("fleches", 0))
	if nf > 0:
		player.add_item("fleche", nf)
	player.prog.gagner("chasse", 12)
	Game.play_ui("fouille", -4.0, 0.1, 0.8)
	Game.play_3d("impact", global_position, -10.0, 0.2, 15.0)
	Effets.flaque(get_parent(), global_position)
	queue_free()


# ================================================================ modèles et animations
const Effets = preload("res://scripts/effets.gd")


func _construire() -> void:
	modele = Node3D.new()
	add_child(modele)
	var m := ModeleUtil.charger("res://modeles/animaux/%s.scn" % kind)
	if m:
		modele.add_child(m)
		ap = ModeleUtil.anim_player(m)
		if ap:
			ModeleUtil.boucler(ap, ["Idle", "Idle_2", "Idle_Headlow", "Idle_2_HeadLow", "Eating", "Walk", "Gallop"])
			ap.playback_default_blend_time = 0.25
			return
		# modèle fixe découpé (outils/godot/normaliser_animaux.gd) : tête et pattes articulées
		var t := m.find_child("Tete", true, false)
		if t:
			tete = t
		for p in m.find_children("Patte*", "", true, false):
			pattes.append([p, float(p.get_meta("phase", 0.0))])
		corps_modele = m.find_child("Corps", true, false)
		return
	match kind:
		"cerf", "biche":
			_quadrupede(Color(0.55, 0.38, 0.22), 1.0, 0.95)
		"sanglier":
			_quadrupede(Color(0.38, 0.3, 0.22), 0.62, 1.0)
		"lapin":
			_lapin()
		"faisan":
			_faisan()


const ModeleUtil = preload("res://scripts/modele_util.gd")


func _mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.95
		_mats[k] = m
	return _mats[k]


func _piece(parent: Node3D, mesh: Mesh, pos: Vector3, col: Color, rot := Vector3.ZERO, ombre := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col)
	mi.position = pos
	mi.rotation = rot
	if not ombre:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _boite(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


static func _boule(r: float, h := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0.0 else h
	s.radial_segments = 8
	s.rings = 5
	return s


## Quadrupède trapu (sanglier, ou cerf de secours) : corps, tête basse avec groin et défenses, crinière, pattes.
func _quadrupede(col: Color, h_patte: float, l_corps: float) -> void:
	var sombre := col.darkened(0.35)
	var hc := h_patte * 0.62
	var corps := _piece(modele, _boule(0.3, 0.6), Vector3(0, hc + 0.12, 0), col)
	corps.scale = Vector3(1.0, 1.0, l_corps / 0.6 * 1.05)
	_piece(modele, _boite(Vector3(0.07, 0.08, l_corps * 0.5)), Vector3(0, hc + 0.38, -0.08), sombre)   # crinière
	tete = Node3D.new()
	tete.position = Vector3(0, hc + 0.12, -l_corps * 0.55)
	modele.add_child(tete)
	var crane := _piece(tete, _boule(0.17, 0.32), Vector3(0, 0, -0.12), col)
	crane.scale = Vector3(1.0, 1.0, 1.5)
	_piece(tete, CylinderMesh.new(), Vector3(0, -0.06, -0.38), sombre.darkened(0.2), Vector3(PI / 2.0, 0, 0)).scale = Vector3(0.12, 0.1, 0.12)
	for s in [-1.0, 1.0]:
		_piece(tete, _boite(Vector3(0.025, 0.09, 0.025)), Vector3(s * 0.08, -0.03, -0.36), Color(0.92, 0.9, 0.82), Vector3(0.5, 0, s * 0.4), false)   # défenses
		_piece(tete, _boite(Vector3(0.07, 0.12, 0.03)), Vector3(s * 0.1, 0.16, -0.02), sombre, Vector3(0, 0, s * 0.4), false)   # oreilles
	_piece(modele, _boite(Vector3(0.03, 0.18, 0.03)), Vector3(0, hc + 0.18, l_corps * 0.52), sombre, Vector3(0.5, 0, 0), false)   # queue
	for x in [-0.15, 0.15]:
		for z in [-l_corps * 0.36, l_corps * 0.36]:
			var piv := Node3D.new()
			piv.position = Vector3(x, hc, z)
			modele.add_child(piv)
			_piece(piv, _boite(Vector3(0.09, hc, 0.1)), Vector3(0, -hc / 2.0, 0), sombre)
			_piece(piv, _boite(Vector3(0.08, 0.05, 0.1)), Vector3(0, -hc + 0.02, -0.02), Color(0.12, 0.1, 0.09), Vector3.ZERO, false)
			pattes.append([piv, 0.0 if (x < 0.0) == (z < 0.0) else PI])


func _lapin() -> void:
	var col := Color(0.52, 0.44, 0.36)
	var corps := _piece(modele, _boule(0.1, 0.2), Vector3(0, 0.12, 0.02), col)
	corps.scale = Vector3(1.0, 1.0, 1.5)
	tete = Node3D.new()
	tete.position = Vector3(0, 0.2, -0.13)
	modele.add_child(tete)
	_piece(tete, _boule(0.065), Vector3.ZERO, col)
	for s in [-1.0, 1.0]:
		_piece(tete, _boite(Vector3(0.045, 0.13, 0.018)), Vector3(s * 0.028, 0.1, 0.02), col.lightened(0.12), Vector3(0.3, 0, s * 0.15), false)
	_piece(tete, _boule(0.012), Vector3(0, -0.01, -0.065), Color(0.2, 0.12, 0.12), Vector3.ZERO, false)
	_piece(modele, _boule(0.035), Vector3(0, 0.16, 0.17), Color(0.95, 0.95, 0.92), Vector3.ZERO, false)   # queue blanche
	for z in [-0.08, 0.08]:
		for x in [-0.05, 0.05]:
			var piv := Node3D.new()
			piv.position = Vector3(x, 0.06, z)
			modele.add_child(piv)
			_piece(piv, _boite(Vector3(0.035, 0.06, 0.08 if z > 0.0 else 0.03)), Vector3(0, -0.03, -0.01), col.darkened(0.15), Vector3.ZERO, false)
			pattes.append([piv, 0.0 if z < 0.0 else PI])


func _faisan() -> void:
	var cuivre := Color(0.62, 0.32, 0.12)
	var corps := _piece(modele, _boule(0.1, 0.19), Vector3(0, 0.2, 0.0), cuivre)
	corps.scale = Vector3(1.0, 1.0, 1.6)
	tete = Node3D.new()
	tete.position = Vector3(0, 0.3, -0.15)
	modele.add_child(tete)
	_piece(tete, _boite(Vector3(0.05, 0.12, 0.05)), Vector3(0, -0.02, 0.02), Color(0.1, 0.35, 0.3), Vector3(-0.3, 0, 0))   # cou vert
	_piece(tete, _boule(0.04), Vector3(0, 0.05, -0.01), Color(0.1, 0.3, 0.35))
	_piece(tete, _boite(Vector3(0.05, 0.035, 0.03)), Vector3(0, 0.05, -0.03), Color(0.8, 0.1, 0.08), Vector3.ZERO, false)   # caroncule rouge
	_piece(tete, _boite(Vector3(0.012, 0.012, 0.035)), Vector3(0, 0.04, -0.06), Color(0.8, 0.75, 0.55), Vector3.ZERO, false)   # bec
	_piece(tete, TorusMesh.new(), Vector3(0, -0.06, 0.02), Color(0.95, 0.95, 0.9), Vector3.ZERO, false).scale = Vector3(0.05, 0.05, 0.05)   # collier blanc
	_piece(modele, _boite(Vector3(0.04, 0.012, 0.46)), Vector3(0, 0.27, 0.36), cuivre.darkened(0.25), Vector3(-0.3, 0, 0), false)   # longue queue
	for s in [-1.0, 1.0]:
		var aile := Node3D.new()
		aile.position = Vector3(s * 0.085, 0.25, 0.0)
		modele.add_child(aile)
		_piece(aile, _boite(Vector3(0.12, 0.018, 0.22)), Vector3(s * 0.06, 0, 0.03), cuivre.darkened(0.2), Vector3.ZERO, false)
		aile.rotation.z = s * -1.35   # repliée le long du corps
		ailes.append([aile, s])
		var piv := Node3D.new()
		piv.position = Vector3(s * 0.04, 0.12, 0.02)
		modele.add_child(piv)
		_piece(piv, _boite(Vector3(0.015, 0.12, 0.015)), Vector3(0, -0.06, 0), Color(0.5, 0.45, 0.4), Vector3.ZERO, false)
		pattes.append([piv, 0.0 if s < 0.0 else PI])


func _jouer(nom_anim: String, vitesse := 1.0) -> void:
	if ap == null or not ap.has_animation(nom_anim):
		return
	if anim != nom_anim:
		anim = nom_anim
		ap.play(nom_anim)
	ap.speed_scale = vitesse


func _animer(delta: float) -> void:
	var v := vitesse_h
	if ap:
		if reaction_t > 0.0:
			reaction_t -= delta
			return
		repos_t -= delta
		if repos_t <= 0.0:
			repos_t = randf_range(5.0, 10.0)
			repos_anim = ["Idle", "Idle", "Idle_2", "Idle_Headlow", "Idle_2_HeadLow"].pick_random()
			if not ap.has_animation(repos_anim):
				repos_anim = "Idle"
		if etat == Etat.CHARGE and attaque_t > 0.6:
			_jouer("Attack" if ap.has_animation("Attack") else "Attack_Headbutt", 1.3)
		elif v > 4.0:
			_jouer("Gallop", v / 9.0)
		elif v > 0.3:
			_jouer("Walk", v / 1.6)
		else:
			_jouer("Eating" if broute and etat == Etat.PAIT else repos_anim)
		return
	# modèles faits par le code : pattes qui balancent, corps qui oscille, tête qui broute
	phase += delta * (v * (9.0 if kind in ["lapin", "faisan", "corbeau"] else 5.0) + 0.001)
	var amp := clampf(v * 0.25, 0.0, 0.8)
	if corps_modele:
		# modèle découpé : pattes courtes, angles plus petits ; le faisan replie les pattes et bascule en vol
		amp = clampf(v * 0.12, 0.0, 0.45 if kind == "lapin" else 0.6)
		if TYPES[kind].get("vole", false):
			var incl := -0.35 if vol else 0.0
			modele.rotation.x = lerpf(modele.rotation.x, incl, minf(1.0, delta * 5.0))
			modele.position.y = absf(sin(phase)) * 0.02 * float(not vol)
			for pa in pattes:
				pa[0].rotation.x = lerpf(pa[0].rotation.x, 1.1, minf(1.0, delta * 8.0)) if vol else sin(phase + pa[1]) * amp
			if tete:
				var picore := 1.0 if (broute and etat == Etat.PAIT and v < 0.3) else 0.0
				tete.rotation.x = -0.5 * picore * maxf(0.0, sin(Time.get_ticks_msec() * 0.006)) + sin(phase) * 0.12 * float(v > 0.3)
			return
	if kind == "lapin":
		# bonds : tout le corps saute, pattes arrière ensemble
		modele.position.y = absf(sin(phase * 0.5)) * clampf(v * 0.05, 0.0, 0.25)
		for pa in pattes:
			pa[0].rotation.x = sin(phase * 0.5 + pa[1] * 0.5) * amp
	else:
		modele.position.y = absf(sin(phase)) * clampf(v * 0.012, 0.0, 0.06)
		for pa in pattes:
			pa[0].rotation.x = sin(phase + pa[1]) * amp
	if tete:
		var bas := 1.0 if (broute and etat == Etat.PAIT and v < 0.3) else 0.0
		tete.rotation.x = lerpf(tete.rotation.x, (-0.35 if corps_modele else -0.6) * bas + sin(phase * 0.3) * 0.05 * bas, minf(1.0, delta * 4.0))
	for a in ailes:
		var cible: float = a[1] * (-1.35 if not vol else sin(Time.get_ticks_msec() * 0.03) * 0.9)
		a[0].rotation.z = lerpf(a[0].rotation.z, cible, minf(1.0, delta * 12.0))
