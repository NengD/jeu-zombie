extends RigidBody3D
## Grenade lancée (modèle RGD-5 de D_U) : rebondit au sol puis explose à la fin de la minuterie.
## Cocktail Molotov (« feu » dans items.gd) : se brise au premier choc et laisse une zone de feu au sol (ZoneFeu).

const Effets = preload("res://scripts/effets.gd")
const ModeleUtil = preload("res://scripts/modele_util.gd")

var minuterie := 3.5
var degats := 190.0
var rayon := 6.5
var _rebond_t := 0.0
var feu := false          # Molotov : se brise au contact


func preparer(id: String) -> void:
	var info := Items.info(id)
	minuterie = float(info.get("minuterie", 3.5))
	var ex: Array = info.get("explosion", [190.0, 6.5])
	degats = float(ex[0])
	rayon = float(ex[1])
	collision_layer = 0
	collision_mask = Game.LAYER_WORLD
	mass = 0.31
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.3
	pm.friction = 0.8
	physics_material_override = pm
	angular_damp = 1.5
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.035
	cs.shape = sp
	add_child(cs)
	var m: Node3D = null
	if info.get("feu", false):
		m = bouteille()
		m.position.y = -0.12                     # tourne autour du milieu de la bouteille
	else:
		m = ModeleUtil.arme(id)
	if m:
		add_child(m)
	feu = bool(info.get("feu", false))
	if feu:
		minuterie = 8.0
		mass = 0.5
	body_entered.connect(_contact)


func _physics_process(delta: float) -> void:
	minuterie -= delta
	_rebond_t = maxf(0.0, _rebond_t - delta)
	if minuterie <= 0.0:
		if feu:
			_briser()
			return
		exploser(get_parent(), global_position + Vector3.UP * 0.1, degats, rayon)
		queue_free()


func _contact(_b: Node) -> void:
	if feu:
		_briser.call_deferred()
		return
	if _rebond_t <= 0.0 and linear_velocity.length() > 1.5:
		_rebond_t = 0.25
		Game.play_3d("douille1", global_position, -2.0, 0.2, 20.0)


## Explosion : dégâts dégressifs (arrêtés par les murs), zombies renversés, souffle, lumière, fumée, bruit.
static func exploser(monde: Node, pos: Vector3, degats_max: float, r: float) -> void:
	var espace: PhysicsDirectSpaceState3D = monde.get_viewport().world_3d.direct_space_state
	for z in monde.get_tree().get_nodes_in_group("zombies") + monde.get_tree().get_nodes_in_group("bandits"):
		if not is_instance_valid(z) or not (z is Node3D):
			continue
		var centre: Vector3 = (z as Node3D).global_position + Vector3.UP * 0.9
		var d := pos.distance_to(centre)
		if d > r:
			continue
		var q := PhysicsRayQueryParameters3D.create(pos, centre, Game.LAYER_WORLD)
		if not espace.intersect_ray(q).is_empty():
			continue
		var k := 1.0 - d / r
		var dmg := degats_max * (0.35 + 0.65 * k)
		if z.has_method("renverser") and k > 0.35:
			z.renverser(randf_range(2.0, 3.5))
		elif z.has_method("repousser"):
			z.repousser(centre - pos, 6.0 * k, 0.9)
		Game.explosion_joueur = true
		z.take_hit(dmg, centre, pos)
		Game.explosion_joueur = false
	var p = Game.player
	if p and is_instance_valid(p):
		var cp: Vector3 = p.global_position + Vector3.UP * 1.0
		var dp := pos.distance_to(cp)
		if dp < r * 1.6:
			var q2 := PhysicsRayQueryParameters3D.create(pos, cp, Game.LAYER_WORLD)
			var abrite := not espace.intersect_ray(q2).is_empty()
			if dp < r and not abrite:
				var kp := 1.0 - dp / r
				p.take_damage(degats_max * 0.6 * kp * kp, null, pos)
			# souffle : la caméra tremble même à l'abri
			if "rec_rvel" in p:
				var f := clampf(1.0 - dp / (r * 1.6), 0.0, 1.0)
				p.rec_rvel += Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-4, 4)) * f
				p.rec_vel += Vector3(randf_range(-0.6, 0.6), 0.8, 0.0) * f
	# effets
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.35)
	l.light_energy = 14.0
	l.omni_range = r * 3.0
	l.shadow_enabled = true
	monde.add_child(l)
	l.global_position = pos + Vector3.UP * 0.5
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.35)
	tw.tween_callback(l.queue_free)
	_boule(monde, pos, r)
	for i in 5:
		var dir := Vector3(randf_range(-1, 1), randf_range(0.6, 1.4), randf_range(-1, 1)).normalized()
		Effets.fumee(monde, pos + dir * 0.3, dir, 10, i % 2 == 0)
	Effets.impact(monde, pos, Vector3.UP, false)
	Game.play_3d("explosion", pos, 6.0, 0.08, 220.0)
	Game.make_noise(pos, 140.0)


## Boule de feu qui gonfle puis s'éteint.
static func _boule(monde: Node, pos: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.62, 0.2, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Color(1.0, 0.5, 0.15)
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	monde.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * r * 0.55, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.32)
	tw.tween_callback(mi.queue_free)


## Molotov : la bouteille se brise, le sol s'embrase (zone posée sur le sol sous le point de choc).
func _briser() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var monde := get_parent()
	var pos := global_position
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.3, pos + Vector3.DOWN * 4.0, Game.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		pos = hit.position
	var z := ZoneFeu.new()
	z.rayon = 3.0 * rayon / 6.5          # talent grenadier : rayon et dégâts ×1,3
	z.dps = 26.0 * degats / 190.0
	monde.add_child(z)
	z.global_position = pos + Vector3.UP * 0.05
	Game.play_3d("impact", pos, 2.0, 0.1, 40.0, 1.6)
	Game.play_3d("explosion", pos, -10.0, 0.1, 60.0, 1.8)
	Game.make_noise(pos, 45.0)
	queue_free()


## Molotov en vol : modèle res://modeles/objets/molotov.scn (outils/godot/creer_molotov.gd), chiffon enflammé.
## Sans le modèle : bouteille faite de cylindres.
static func bouteille() -> Node3D:
	var modele := ModeleUtil.charger("res://modeles/objets/molotov.scn")
	if modele:
		var fm := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.07, 0.1)
		fm.mesh = q
		fm.material_override = ZoneFeu.materiau_flamme()
		fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fm.position.y = 0.3 + q.size.y * 0.4
		modele.add_child(fm)
		return modele
	var n := Node3D.new()
	var corps := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = 0.16
	corps.mesh = cm
	var mv := StandardMaterial3D.new()
	mv.albedo_color = Color(0.25, 0.45, 0.2, 0.75)
	mv.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mv.roughness = 0.15
	corps.material_override = mv
	n.add_child(corps)
	var col := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.012
	cc.bottom_radius = 0.03
	cc.height = 0.07
	col.mesh = cc
	col.material_override = mv
	col.position.y = 0.115
	n.add_child(col)
	var chiffon := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.06, 0.03)
	chiffon.mesh = bm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.75, 0.68, 0.55)
	chiffon.material_override = mt
	chiffon.position.y = 0.17
	n.add_child(chiffon)
	var fl := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.13)
	fl.mesh = qm
	fl.material_override = ZoneFeu.materiau_flamme()
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fl.position.y = 0.23
	n.add_child(fl)
	return n


## Zone de feu au sol : brûle zombies, bandits et joueur pendant `duree` s (dégâts par 0,5 s), flammes, lumière, crépitement.
class ZoneFeu extends Node3D:
	var rayon := 3.0
	var dps := 26.0
	var duree := 7.0
	var _t := 0.0
	var _tick := 0.0
	var _flammes: Array = []
	var _lumiere: OmniLight3D

	static func materiau_flamme() -> StandardMaterial3D:
		var mf := StandardMaterial3D.new()
		mf.albedo_texture = Effets._texture("flamme")
		mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mf.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mf.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mf.albedo_color = Color(1.0, 0.6, 0.25)
		return mf

	func _ready() -> void:
		var mf := materiau_flamme()
		var n := int(clampf(rayon * rayon * 1.6, 8, 24))
		for k in n:
			var f := MeshInstance3D.new()
			var q := QuadMesh.new()
			var s := randf_range(0.6, 1.1)
			q.size = Vector2(0.7, 1.0) * s
			f.mesh = q
			f.material_override = mf
			f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var a := randf() * TAU
			var r := sqrt(randf()) * rayon * 0.85
			f.position = Vector3(cos(a) * r, 0.4 * s, sin(a) * r)
			f.set_meta("s", s)
			add_child(f)
			_flammes.append(f)
		# sol noirci
		var sol := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2.ONE * rayon * 2.0
		sol.mesh = pm
		var ms := StandardMaterial3D.new()
		ms.albedo_color = Color(0.05, 0.04, 0.03, 0.7)
		ms.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sol.material_override = ms
		sol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sol.position.y = 0.02
		add_child(sol)
		_lumiere = OmniLight3D.new()
		_lumiere.light_color = Color(1.0, 0.55, 0.25)
		_lumiere.light_energy = 5.0
		_lumiere.omni_range = rayon * 4.0
		_lumiere.position.y = 1.0
		add_child(_lumiere)

	func _physics_process(delta: float) -> void:
		_t += delta
		var fin := clampf((duree - _t) / 1.5, 0.0, 1.0)     # les flammes baissent sur la dernière 1,5 s
		for k in _flammes.size():
			var f: MeshInstance3D = _flammes[k]
			f.scale = Vector3.ONE * fin * (0.8 + 0.25 * sin(_t * (8.0 + k * 1.7) + k))
		_lumiere.light_energy = fin * (4.0 + 1.5 * sin(_t * 17.0) + randf())
		_tick -= delta
		if _tick <= 0.0 and fin > 0.2:
			_tick = 0.5
			_bruler(dps * 0.5)
		if _t >= duree:
			queue_free()

	func _bruler(dmg: float) -> void:
		var c := global_position
		for z in get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("bandits"):
			if not is_instance_valid(z) or not (z is Node3D) or not z.has_method("take_hit"):
				continue
			var p: Vector3 = (z as Node3D).global_position
			if absf(p.y - c.y) > 2.0 or Vector2(p.x - c.x, p.z - c.z).length() > rayon:
				continue
			Game.explosion_joueur = true
			z.take_hit(dmg, p + Vector3.UP * 0.5, c)
			Game.explosion_joueur = false
		var pl = Game.player
		if pl and is_instance_valid(pl) and pl.has_method("take_damage"):
			var pp: Vector3 = pl.global_position
			if absf(pp.y - c.y) < 2.0 and Vector2(pp.x - c.x, pp.z - c.z).length() < rayon:
				pl.take_damage(dmg * 0.6, null, c)
		if randf() < 0.5:
			Effets.fumee(get_parent(), c + Vector3(randf_range(-1, 1), 0.6, randf_range(-1, 1)) * rayon * 0.5, Vector3.UP, 4, true)
