extends Node3D
## Flèche tirée à l'arc : vol en cloche (gravité réduite, pour le jeu), se plante dans les cibles
## et le décor. Plantée dans le décor : souvent ramassable ([F]) ; dans une créature : parfois
## récupérée en fouillant ou en dépeçant le corps (méta « fleches » de la créature).

const Effets = preload("res://scripts/effets.gd")
const GRAVITE := 4.5
const LONGUEUR := 0.72
const MAX_PLANTEES := 40

var vitesse := Vector3.ZERO
var degats := 50.0
var tireur: Node3D = null
var exclus: Array[RID] = []
var en_vol := true
var age := 0.0
var recuperable := false


## Petit corps à ramasser (collision d'interaction seulement) au milieu de la flèche plantée.
class Ramassage extends StaticBody3D:
	func get_prompt() -> String:
		return "[F] Ramasser la flèche"

	func interact(player: Node) -> void:
		player.add_item("fleche", 1)
		Game.play_ui("fouille", -10.0, 0.1, 1.5)
		get_parent().queue_free()


func tirer(par: Node3D, depart: Vector3, v: Vector3, dmg: float) -> void:
	tireur = par
	vitesse = v
	degats = dmg
	if par is CollisionObject3D:
		exclus.append((par as CollisionObject3D).get_rid())
	position = depart


func _ready() -> void:
	_construire()
	_orienter()


## Modèle : pointe à l'origine, fût vers +Z (l'avant de la flèche est -Z).
func _construire() -> void:
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color(0.62, 0.48, 0.3)
	var fut := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0045
	cm.bottom_radius = 0.0045
	cm.height = LONGUEUR
	cm.radial_segments = 5
	cm.rings = 1
	fut.mesh = cm
	fut.material_override = bois
	fut.rotation.x = PI / 2.0
	fut.position.z = LONGUEUR / 2.0
	fut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fut)
	var pointe := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.0
	pm.bottom_radius = 0.011
	pm.height = 0.05
	pm.radial_segments = 4
	pm.rings = 1
	pointe.mesh = pm
	var acier := StandardMaterial3D.new()
	acier.albedo_color = Color(0.5, 0.5, 0.52)
	acier.metallic = 0.7
	pointe.material_override = acier
	pointe.rotation.x = -PI / 2.0
	pointe.position.z = 0.0
	add_child(pointe)
	var plume := StandardMaterial3D.new()
	plume.albedo_color = Color(0.85, 0.2, 0.15)
	plume.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 3:
		var p := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.11, 0.025)
		p.mesh = q
		p.material_override = plume
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# trois pennes autour du fût, chacune dans un plan qui contient l'axe
		var piv := Node3D.new()
		piv.rotation.z = k * TAU / 3.0
		add_child(piv)
		p.rotation = Vector3(0, PI / 2.0, 0)
		p.position = Vector3(0, 0.012, LONGUEUR - 0.08)
		piv.add_child(p)


func _orienter() -> void:
	if vitesse.length_squared() > 0.01:
		var d := vitesse.normalized()
		var haut := Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD
		global_basis = Basis.looking_at(d, haut)


func _physics_process(delta: float) -> void:
	age += delta
	if not en_vol:
		if age > (300.0 if recuperable else 20.0):
			queue_free()
		return
	if age > 5.0:
		queue_free()
		return
	vitesse.y -= GRAVITE * delta
	var depl := vitesse * delta
	var de := global_position
	var q := PhysicsRayQueryParameters3D.create(de, de + depl, Game.LAYER_WORLD | Game.LAYER_ZOMBIE, exclus)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = de + depl
		_orienter()
		return
	_planter(hit)


func _planter(hit: Dictionary) -> void:
	en_vol = false
	age = 0.0
	var dir := vitesse.normalized()
	var col: Object = hit.collider
	global_position = hit.position + dir * 0.09   # la pointe s'enfonce un peu
	var depart: Vector3 = tireur.global_position if tireur and is_instance_valid(tireur) else global_position - dir
	if col and col.has_method("take_hit"):
		Game.tir_discret = true
		col.take_hit(degats, hit.position, depart)
		Game.tir_discret = false
		Game.spawn_blood(hit.position, get_parent())
		Effets.gerbe_sang(get_parent(), hit.position, dir, 0.7)
		Game.play_3d("impact", hit.position, -8.0, 0.2, 20.0)
		if tireur and tireur.get("prog") != null:
			tireur.prog.gagner("combat", 3)
		# plantée dans la créature : suit son corps ; récupérable une fois sur deux en fouillant / dépeçant
		recuperable = randf() < 0.5
		if recuperable and col is Node:
			(col as Node).set_meta("fleches", int((col as Node).get_meta("fleches", 0)) + 1)
		if col is Node3D:
			reparent(col as Node3D, true)
		recuperable = true    # visible tant que le corps reste (disparaît avec lui)
		return
	# décor : trois fois sur quatre on peut la ramasser
	Game.play_3d("impact_mur", hit.position, -14.0, 0.2, 18.0)
	Game.make_noise(hit.position, 5.0)
	recuperable = randf() < 0.75
	if recuperable:
		var r := Ramassage.new()
		r.name = "Ramassage"
		r.collision_layer = Game.LAYER_INTERACT
		r.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 0.22
		cs.shape = sp
		r.add_child(cs)
		r.position = Vector3(0, 0, LONGUEUR * 0.6)
		add_child(r)
	else:
		rotate_object_local(Vector3.RIGHT, randf_range(0.3, 0.7))   # brisée : penche
	add_to_group("fleches_plantees")
	var plantees := get_tree().get_nodes_in_group("fleches_plantees")
	if plantees.size() > MAX_PLANTEES:
		plantees[0].queue_free()
