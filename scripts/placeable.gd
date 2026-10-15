extends StaticBody3D
## Objets de base posés par le joueur : établi et barricade.
## (La caisse de stockage utilise loot_container.gd.)

var kind := "etabli"
var health := 250.0


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


func _part(pos: Vector3, size: Vector3, col: Color) -> void:
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


func _shape(pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	add_child(cs)


func get_prompt() -> String:
	if kind == "etabli":
		return "[F] Utiliser l'établi"
	return "Barricade (%d PV)" % int(health)


func interact(player: Node) -> void:
	if kind == "etabli":
		player.open_inventory()


## Les zombies frappent les barricades qui leur bloquent le passage.
func take_damage(amount: float, _from: Node = null) -> void:
	if kind != "barricade":
		return
	health -= amount
	if health <= 0.0:
		Game.msg("Une barricade a cédé !")
		queue_free()
