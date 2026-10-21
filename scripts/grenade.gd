extends RigidBody3D
## Grenade lancée (modèle RGD-5 de D_U) : rebondit au sol puis explose à la fin de la minuterie.

const Effets = preload("res://scripts/effets.gd")
const ModeleUtil = preload("res://scripts/modele_util.gd")

var minuterie := 3.5
var degats := 190.0
var rayon := 6.5
var _rebond_t := 0.0


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
	var m := ModeleUtil.arme(id)
	if m:
		add_child(m)
	body_entered.connect(_contact)


func _physics_process(delta: float) -> void:
	minuterie -= delta
	_rebond_t = maxf(0.0, _rebond_t - delta)
	if minuterie <= 0.0:
		exploser(get_parent(), global_position + Vector3.UP * 0.1, degats, rayon)
		queue_free()


func _contact(_b: Node) -> void:
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
