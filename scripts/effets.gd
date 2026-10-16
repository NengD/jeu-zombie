extends RefCounted
## Effets de tir : flamme de bouche, fumée, douilles éjectées, impacts (trous, étincelles, poussière).
## Les textures sont dessinées par le code (aucune image à fournir).

static var _tex := {}
static var _mats := {}
static var _trous: Array = []       # impacts posés (les plus anciens disparaissent)
static var _douilles: Array = []
const MAX_TROUS := 90
const MAX_DOUILLES := 40


# ================================================================ textures
static func _texture(nom: String) -> Texture2D:
	if _tex.has(nom):
		return _tex[nom]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(nom)
	var rayons := []
	for i in 7:
		rayons.append([rng.randf() * TAU, rng.randf_range(0.5, 1.0)])
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE
			var d := p.length()
			var a := 0.0
			var c := Color.WHITE
			match nom:
				"flamme":
					# étoile : cœur blanc, branches jaunes-orangées
					var ang := p.angle()
					var branche := 0.0
					for r in rayons:
						var da := absf(angle_difference(ang, float(r[0])))
						branche = maxf(branche, (1.0 - smoothstep(0.0, 0.32, da)) * float(r[1]))
					a = clampf((1.0 - d) * 1.6 * (0.35 + branche), 0.0, 1.0)
					a = maxf(a, clampf(1.0 - d * 2.6, 0.0, 1.0))
					c = Color(1.0, 0.95, 0.75).lerp(Color(1.0, 0.55, 0.15), clampf(d * 1.4, 0.0, 1.0))
				"fumee":
					var bruit := sin(p.x * 7.0 + rayons[0][0] * 3.0) * sin(p.y * 6.0 + rayons[1][0] * 3.0) * 0.15
					a = clampf((1.0 - d) * 0.9 + bruit, 0.0, 1.0) * 0.8
					c = Color(0.8, 0.8, 0.78)
				"trou":
					# trou sombre au centre, éclats et suie autour
					var ang2 := p.angle()
					var fissure := 0.0
					for r in rayons:
						var da2 := absf(angle_difference(ang2, float(r[0])))
						fissure = maxf(fissure, (1.0 - smoothstep(0.0, 0.06, da2)) * (1.0 - smoothstep(0.2, 0.9 * float(r[1]), d)))
					if d < 0.2:
						a = 1.0
						c = Color(0.02, 0.02, 0.02)
					else:
						a = clampf((1.0 - smoothstep(0.2, 0.75, d)) * 0.75 + fissure * 0.8, 0.0, 1.0)
						c = Color(0.12, 0.1, 0.09)
				"etincelle":
					a = clampf(1.0 - d * 1.2, 0.0, 1.0)
					c = Color(1.0, 0.85, 0.5)
				"sang":
					# éclaboussure : tache irrégulière et gouttelettes
					var ang3 := p.angle()
					var bord := 0.45
					for r in rayons:
						bord += 0.12 * float(r[1]) * cos(3.0 * ang3 + float(r[0]))
					a = 1.0 - smoothstep(bord - 0.08, bord, d)
					for r in rayons:
						var g := Vector2(cos(float(r[0])), sin(float(r[0]))) * (0.55 + 0.35 * float(r[1]))
						a = maxf(a, 1.0 - smoothstep(0.04, 0.07, p.distance_to(g)))
					c = Color(0.35, 0.02, 0.02)
				"flaque":
					var ang4 := p.angle()
					var bord2 := 0.75 + 0.1 * sin(3.0 * ang4 + float(rayons[0][0])) + 0.06 * sin(5.0 * ang4 + float(rayons[1][0]))
					a = (1.0 - smoothstep(bord2 - 0.1, bord2, d)) * 0.92
					c = Color(0.25, 0.01, 0.01).lerp(Color(0.4, 0.03, 0.02), d)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	var t := ImageTexture.create_from_image(img)
	_tex[nom] = t
	return t


static func _materiau(nom: String) -> StandardMaterial3D:
	if _mats.has(nom):
		return _mats[nom]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match nom:
		"flamme":
			m.albedo_texture = _texture("flamme")
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_color = Color(1.0, 0.9, 0.7)
		"fumee":
			m.albedo_texture = _texture("fumee")
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.vertex_color_use_as_albedo = true
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"poussiere":
			m.albedo_texture = _texture("fumee")
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.vertex_color_use_as_albedo = true
		"etincelle":
			m.albedo_texture = _texture("etincelle")
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.vertex_color_use_as_albedo = true
		"trou":
			m.albedo_texture = _texture("trou")
			m.roughness = 1.0
		"sang", "flaque":
			m.albedo_texture = _texture(nom)
			m.roughness = 0.25
			m.metallic_specular = 0.7
		"goutte":
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			m.albedo_color = Color(0.4, 0.02, 0.02)
			m.roughness = 0.3
		"laiton":
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			m.albedo_color = Color(0.78, 0.6, 0.25)
			m.metallic = 0.85
			m.roughness = 0.3
		"cartouche":
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			m.albedo_color = Color(0.7, 0.12, 0.08)
			m.roughness = 0.5
	_mats[nom] = m
	return m


static func _plus_tard(noeud: Node, delai: float) -> void:
	noeud.get_tree().create_timer(delai).timeout.connect(func(): if is_instance_valid(noeud): noeud.queue_free())


# ================================================================ flamme de bouche
## Flamme posée sur le modèle de l'arme (suit l'arme). « calque » : 2 en vue 1re personne.
static func flamme(parent: Node3D, pos: Vector3, taille: float, calque := 1) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.z = randf() * TAU
	parent.add_child(n)
	var mat := _materiau("flamme")
	# face avant (étoile) et deux plans en croix le long du canon
	for k in 3:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = calque
		if k == 0:
			qm.size = Vector2(taille, taille)
		else:
			qm.size = Vector2(taille * 0.7, taille * 1.6)
			mi.rotation = Vector3(PI / 2.0, 0.0, 0.0) if k == 1 else Vector3(PI / 2.0, 0.0, PI / 2.0)
			mi.position = Vector3(0, 0, -taille * 0.6)
		mi.mesh = qm
		n.add_child(mi)
	_plus_tard(n, 0.045)


# ================================================================ fumée
static func fumee(monde: Node, pos: Vector3, dir: Vector3, quantite := 6, grise := true) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = quantite
	p.lifetime = 1.4
	p.explosiveness = 0.9
	var qm := QuadMesh.new()
	qm.size = Vector2(0.18, 0.18)
	p.mesh = qm
	p.material_override = _materiau("fumee" if grise else "poussiere")
	p.direction = dir
	p.spread = 25.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, 0.35, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	var courbe := Curve.new()
	courbe.add_point(Vector2(0, 0.4))
	courbe.add_point(Vector2(1, 2.2))
	p.scale_amount_curve = courbe
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.85, 0.82, 0.35) if grise else Color(0.55, 0.48, 0.38, 0.6))
	g.set_color(1, Color(0.85, 0.85, 0.82, 0.0) if grise else Color(0.55, 0.48, 0.38, 0.0))
	p.color_ramp = g
	monde.add_child(p)
	p.global_position = pos
	p.emitting = true
	_plus_tard(p, 2.0)


# ================================================================ douilles
static func douille(monde: Node, pos: Vector3, vitesse: Vector3, cartouche := false) -> void:
	_douilles = _douilles.filter(func(d): return is_instance_valid(d))
	if _douilles.size() >= MAX_DOUILLES:
		var vieille = _douilles.pop_front()
		if is_instance_valid(vieille):
			vieille.queue_free()
	var rb := RigidBody3D.new()
	rb.collision_layer = 0
	rb.collision_mask = Game.LAYER_WORLD
	rb.mass = 0.02
	rb.continuous_cd = true
	var r := 0.009 if cartouche else 0.0045
	var h := 0.06 if cartouche else 0.022
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = h
	cs.shape = cyl
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = _materiau("cartouche" if cartouche else "laiton")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rb.add_child(mi)
	rb.contact_monitor = true
	rb.max_contacts_reported = 1
	var son := [false]
	rb.body_entered.connect(func(_b):
		if not son[0] and is_instance_valid(rb):
			son[0] = true
			Game.play_3d("douille%d" % randi_range(1, 3), rb.global_position, -12.0, 0.15, 14.0))
	monde.add_child(rb)
	rb.global_position = pos
	rb.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
	rb.linear_velocity = vitesse
	rb.angular_velocity = Vector3(randf_range(-25, 25), randf_range(-25, 25), randf_range(-25, 25))
	_douilles.append(rb)
	_plus_tard(rb, 20.0)


# ================================================================ impacts
## Impact de balle sur le décor : trou, éclats (étincelles ou poussière), petit nuage.
static func impact(monde: Node, pos: Vector3, normale: Vector3, metal: bool) -> void:
	_trous = _trous.filter(func(t): return is_instance_valid(t))
	if _trous.size() >= MAX_TROUS:
		var vieux = _trous.pop_front()
		if is_instance_valid(vieux):
			vieux.queue_free()
	var trou := MeshInstance3D.new()
	var qm := QuadMesh.new()
	var s := randf_range(0.07, 0.11)
	qm.size = Vector2(s, s)
	trou.mesh = qm
	trou.material_override = _materiau("trou")
	trou.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	monde.add_child(trou)
	var nrm := normale.normalized()
	var haut := Vector3.UP if absf(nrm.y) < 0.95 else Vector3.FORWARD
	trou.global_transform = Transform3D(Basis.looking_at(-nrm, haut).rotated(nrm, randf() * TAU), pos + nrm * 0.006)
	_trous.append(trou)
	_plus_tard(trou, 120.0)
	# éclats
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 10 if metal else 8
	p.lifetime = 0.35 if metal else 0.8
	p.explosiveness = 1.0
	var qp := QuadMesh.new()
	qp.size = Vector2(0.02, 0.02) if metal else Vector2(0.05, 0.05)
	p.mesh = qp
	p.material_override = _materiau("etincelle" if metal else "poussiere")
	p.direction = nrm
	p.spread = 40.0
	p.initial_velocity_min = 2.0 if metal else 0.6
	p.initial_velocity_max = 6.0 if metal else 2.0
	p.gravity = Vector3(0, -9.8, 0) if metal else Vector3(0, -2.0, 0)
	var g := Gradient.new()
	if metal:
		g.set_color(0, Color(1.0, 0.9, 0.6, 1.0))
		g.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
	else:
		g.set_color(0, Color(0.6, 0.55, 0.48, 0.8))
		g.set_color(1, Color(0.6, 0.55, 0.48, 0.0))
	p.color_ramp = g
	monde.add_child(p)
	p.global_position = pos + nrm * 0.02
	p.emitting = true
	_plus_tard(p, 1.5)
	if not metal:
		fumee(monde, pos + nrm * 0.05, nrm, 3, false)
	Game.play_3d("impact_metal" if metal else "impact_mur", pos, -8.0, 0.2, 35.0)



# ================================================================ éclair du tir
## Lumière brève du coup de feu (éclaire murs et sol, surtout la nuit).
static func eclair(monde: Node, pos: Vector3, nuit: bool) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.78, 0.45)
	l.light_energy = 5.0 if nuit else 2.5
	l.omni_range = 13.0 if nuit else 8.0
	l.shadow_enabled = nuit
	monde.add_child(l)
	l.global_position = pos
	_plus_tard(l, 0.055)


# ================================================================ sang
static var _taches: Array = []
const MAX_TACHES := 70


static func _poser_tache(monde: Node, pos: Vector3, nrm: Vector3, taille: float, nom := "sang") -> MeshInstance3D:
	_taches = _taches.filter(func(t): return is_instance_valid(t))
	if _taches.size() >= MAX_TACHES:
		var vieille = _taches.pop_front()
		if is_instance_valid(vieille):
			vieille.queue_free()
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(taille, taille)
	mi.mesh = qm
	mi.material_override = _materiau(nom)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	monde.add_child(mi)
	var n := nrm.normalized()
	var haut := Vector3.UP if absf(n.y) < 0.95 else Vector3.FORWARD
	mi.global_transform = Transform3D(Basis.looking_at(-n, haut).rotated(n, randf() * TAU), pos + n * (0.008 + randf() * 0.004))
	_taches.append(mi)
	_plus_tard(mi, 180.0)
	return mi


## Gerbe de sang : gouttes, tache sur le mur derrière la cible et au sol.
static func gerbe_sang(monde: Node, pos: Vector3, dir: Vector3, force := 1.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = int(10 * force) + 4
	p.lifetime = 0.7
	p.explosiveness = 1.0
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.024
	sm.radial_segments = 6
	sm.rings = 3
	p.mesh = sm
	p.material_override = _materiau("goutte")
	p.direction = dir.normalized()
	p.spread = 30.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0 * force
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	monde.add_child(p)
	p.global_position = pos
	p.emitting = true
	_plus_tard(p, 1.2)
	var espace: PhysicsDirectSpaceState3D = (monde as Node3D).get_world_3d().direct_space_state if monde is Node3D else null
	if espace == null:
		return
	# mur derrière
	var q := PhysicsRayQueryParameters3D.create(pos, pos + dir.normalized() * 2.5, Game.LAYER_WORLD)
	var hit := espace.intersect_ray(q)
	if not hit.is_empty():
		_poser_tache(monde, hit.position, hit.normal, randf_range(0.35, 0.6) * force)
	# sol
	var q2 := PhysicsRayQueryParameters3D.create(pos + dir.normalized() * randf_range(0.2, 0.9), pos + Vector3.DOWN * 3.0, Game.LAYER_WORLD)
	var hit2 := espace.intersect_ray(q2)
	if not hit2.is_empty():
		_poser_tache(monde, hit2.position, hit2.normal, randf_range(0.25, 0.45) * force)


## Flaque de sang qui s'étend sous un corps.
static func flaque(monde: Node, pos: Vector3) -> void:
	var espace: PhysicsDirectSpaceState3D = (monde as Node3D).get_world_3d().direct_space_state if monde is Node3D else null
	if espace == null:
		return
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 2.0, Game.LAYER_WORLD)
	var hit := espace.intersect_ray(q)
	if hit.is_empty():
		return
	var mi := _poser_tache(monde, hit.position, hit.normal, 1.3, "flaque")
	mi.scale = Vector3.ONE * 0.15
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 5.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
