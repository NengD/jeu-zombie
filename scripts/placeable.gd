extends StaticBody3D
## Objets de base posés par le joueur : établi et barricade.
## (La caisse de stockage utilise loot_container.gd.)

var kind := "etabli"
var health := 250.0
var health_max := 250.0


func setup(p_kind: String) -> void:
	kind = p_kind
	collision_layer = Game.LAYER_WORLD | Game.LAYER_INTERACT
	collision_mask = 0
	var wood := Color(0.5, 0.36, 0.2)
	match kind:
		"etabli":
			add_to_group("workbench")
			_part(Vector3(0, 0.9, 0), Vector3(2.0, 0.1, 0.9), wood)
			for x in [-0.9, 0.9]:
				for z in [-0.38, 0.38]:
					_part(Vector3(x, 0.43, z), Vector3(0.1, 0.86, 0.1), wood.darkened(0.2))
			_part(Vector3(0, 0.25, 0), Vector3(1.8, 0.05, 0.8), wood.darkened(0.1))
			_part(Vector3(0.7, 1.05, 0.25), Vector3(0.25, 0.2, 0.2), Color(0.3, 0.3, 0.35))  # étau
			_part(Vector3(-0.5, 0.98, -0.1), Vector3(0.5, 0.06, 0.3), Color(0.4, 0.4, 0.42))  # outils
			_shape(Vector3(0, 0.5, 0), Vector3(2.0, 1.0, 0.9))
		"barricade":
			add_to_group("barricade")
			for y in [0.4, 1.15, 1.9]:
				_part(Vector3(0, y, 0), Vector3(2.1, 0.28, 0.08), wood.lightened(randf() * 0.15))
			for x in [-0.8, 0.8]:
				_part(Vector3(x, 1.2, 0.07), Vector3(0.12, 2.4, 0.06), wood.darkened(0.25))
			_shape(Vector3(0, 1.2, 0), Vector3(2.1, 2.4, 0.2))
		"piques":
			# rondin couché et pieux taillés en pointe, tournés vers l'avant (-Z)
			health = 200.0
			collision_layer = Game.LAYER_INTERACT
			_part(Vector3(0, 0.12, 0.15), Vector3(2.0, 0.22, 0.22), wood.darkened(0.3))
			for k in 7:
				var x := -0.9 + k * 0.3
				var pieu := _part(Vector3(x, 0.45, -0.1), Vector3(0.09, 1.1, 0.09), wood.lightened(randf() * 0.2))
				pieu.rotation.x = -0.75
				var pointe := _part(Vector3(x, 0.86, -0.53), Vector3(0.05, 0.18, 0.05), wood.lightened(0.35))
				pointe.rotation.x = -0.75
			_shape(Vector3(0, 0.25, 0), Vector3(2.0, 0.5, 0.6))
			_zone_piege(Vector3(2.2, 1.2, 1.4))
		"barbeles":
			health = 160.0
			collision_layer = Game.LAYER_INTERACT
			var acier := Color(0.45, 0.45, 0.47)
			for x in [-1.1, 0.0, 1.1]:
				_part(Vector3(x, 0.45, 0), Vector3(0.06, 0.9, 0.06), wood.darkened(0.35))
			for k in 6:
				var spire := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.36
				tm.outer_radius = 0.4
				spire.mesh = tm
				var m := StandardMaterial3D.new()
				m.albedo_color = acier
				m.metallic = 0.8
				m.roughness = 0.4
				spire.material_override = m
				spire.position = Vector3(-1.0 + k * 0.4, 0.42, 0)
				spire.rotation = Vector3(0, 0, PI / 2.0 + randf_range(-0.2, 0.2))
				add_child(spire)
			_shape(Vector3(0, 0.25, 0), Vector3(2.4, 0.5, 0.5))
			_zone_piege(Vector3(2.6, 1.2, 1.1))
		"projecteur":
			# trépied, mât, phare orienté vers l'avant (-Z) et un peu vers le sol
			health = 120.0
			var noir := Color(0.12, 0.12, 0.13)
			for a in 3:
				var pied := _part(Vector3(sin(a * TAU / 3.0) * 0.22, 0.35, cos(a * TAU / 3.0) * 0.22), Vector3(0.04, 0.8, 0.04), noir)
				pied.rotation = Vector3(cos(a * TAU / 3.0) * 0.45, 0, -sin(a * TAU / 3.0) * 0.45)
			_part(Vector3(0, 1.2, 0), Vector3(0.05, 1.0, 0.05), noir)
			var tete := Node3D.new()
			tete.position = Vector3(0, 1.75, 0)
			tete.rotation.x = -0.28
			add_child(tete)
			var boitier := _part(Vector3.ZERO, Vector3(0.45, 0.32, 0.22), noir)
			remove_child(boitier)
			tete.add_child(boitier)
			verre = MeshInstance3D.new()
			var vm := BoxMesh.new()
			vm.size = Vector3(0.4, 0.27, 0.02)
			verre.mesh = vm
			verre.position = Vector3(0, 0, -0.115)
			mat_verre = StandardMaterial3D.new()
			mat_verre.albedo_color = Color(0.9, 0.9, 0.85)
			mat_verre.emission_enabled = true
			mat_verre.emission = Color(1.0, 0.95, 0.8)
			verre.material_override = mat_verre
			tete.add_child(verre)
			lumiere = SpotLight3D.new()
			lumiere.spot_range = 38.0
			lumiere.spot_angle = 32.0
			lumiere.light_energy = 7.0
			lumiere.light_color = Color(1.0, 0.95, 0.82)
			lumiere.shadow_enabled = false
			lumiere.position = Vector3(0, 0, -0.15)
			tete.add_child(lumiere)
			_shape(Vector3(0, 0.95, 0), Vector3(0.6, 1.9, 0.6))
			_maj_projecteur()
	health_max = health


## Réparation au marteau (mode construction, touche G).
const COUT_REPARATION := {"piques": {"planche": 1, "clous": 1}, "barbeles": {"ferraille": 1, "clous": 1}, "barricade": {"planche": 1, "clous": 1}}


func nom_piege() -> String:
	return {"piques": "Piques en bois", "barbeles": "Barbelés", "barricade": "Barricade"}.get(kind, kind)


func _part(pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


func _shape(pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	add_child(cs)


func get_prompt() -> String:
	match kind:
		"etabli":
			return "[F] Utiliser l'établi"
		"piques":
			return "Piques en bois (%d PV)" % int(health)
		"barbeles":
			return "Barbelés (%d PV)" % int(health)
		"projecteur":
			return "[F] Projecteur : %s" % ("automatique (s'allume la nuit)" if mode == 0 else MODES[mode])
	return "Barricade (%d PV)" % int(health)


# ---------------------------------------------------------------- pièges
var zone: Area3D = null
var piege_t := 0.0


## Zone où les zombies se blessent (piques) ou s'empêtrent (barbelés).
func _zone_piege(taille: Vector3) -> void:
	add_to_group("piege")
	zone = Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = Game.LAYER_ZOMBIE
	zone.monitorable = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = taille
	cs.shape = bs
	cs.position = Vector3(0, taille.y / 2.0, 0)
	zone.add_child(cs)
	add_child(zone)


# ---------------------------------------------------------------- projecteur
const MODES := ["auto", "allumé", "éteint"]
var mode := 0                     # auto = s'allume à la nuit tombée
var lumiere: SpotLight3D = null
var verre: MeshInstance3D = null
var mat_verre: StandardMaterial3D = null
var projecteur_t := 0.0


func _maj_projecteur() -> void:
	if lumiere == null:
		return
	var on := mode == 1 or (mode == 0 and Game.is_night())
	lumiere.visible = on
	mat_verre.emission_energy_multiplier = 4.0 if on else 0.0


func _physics_process(delta: float) -> void:
	if lumiere:
		projecteur_t -= delta
		if projecteur_t <= 0.0:
			projecteur_t = 1.0
			_maj_projecteur()
		return
	if zone == null:
		return
	piege_t -= delta
	if piege_t > 0.0:
		return
	piege_t = 0.5
	var touche := false
	for z in zone.get_overlapping_bodies():
		if not z.has_method("take_hit") or z.get("state") == 3:   # 3 = mort
			continue
		touche = true
		if kind == "piques":
			z.take_hit(14.0, z.global_position + Vector3.UP * 0.8, global_position)
			z.ralentir(0.6, 0.5)
			health -= 7.0
		else:
			z.take_hit(3.0, z.global_position + Vector3.UP * 0.6, global_position)
			z.ralentir(1.2, 0.25)
			health -= 2.5
	if touche:
		Game.play_3d("impact" if kind == "piques" else "impact_metal", global_position + Vector3.UP * 0.5, -10.0, 0.2, 25.0)
	if health <= 0.0:
		Game.msg("%s détruits par les zombies." % ("Les piques sont" if kind == "piques" else "Les barbelés sont"))
		queue_free()


func interact(player: Node) -> void:
	if kind == "etabli":
		player.open_inventory()
	elif kind == "projecteur":
		mode = (mode + 1) % MODES.size()
		_maj_projecteur()
		Game.play_ui("clic_vide", -6.0, 0.05, 1.4)


## Les zombies frappent les barricades qui leur bloquent le passage.
func take_damage(amount: float, _from: Node = null) -> void:
	if kind != "barricade":
		return
	health -= amount
	if health <= 0.0:
		Game.msg("Une barricade a cédé !")
		queue_free()
