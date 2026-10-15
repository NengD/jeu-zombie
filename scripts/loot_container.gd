extends StaticBody3D
## Meuble fouillable (armoire, casier, caisse…) ou caisse de stockage du joueur.

var label := "Meuble"
var table := "maison"
var rolls := 2
var searched := false
var is_storage := false
var contents := {}   # pour les caisses de stockage
var mesh_i: MeshInstance3D
var mat: StandardMaterial3D


func setup(p_label: String, p_table: String, size: Vector3, col: Color, p_rolls := 2) -> void:
	label = p_label
	table = p_table
	rolls = p_rolls
	collision_layer = Game.LAYER_WORLD | Game.LAYER_INTERACT
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position.y = size.y / 2.0
	add_child(cs)
	mesh_i = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh_i.mesh = bm
	mesh_i.position.y = size.y / 2.0
	mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	mesh_i.material_override = mat
	mesh_i.visibility_range_end = 140.0
	add_child(mesh_i)


func get_prompt() -> String:
	if is_storage:
		return "[F] Ouvrir : %s" % label
	if searched:
		return "%s (déjà fouillé)" % label
	return "[F] Fouiller : %s" % label


func interact(player: Node) -> void:
	if is_storage:
		player.open_storage(self)
		return
	if searched:
		Game.msg("%s : déjà fouillé." % label)
		return
	searched = true
	mat.albedo_color = mat.albedo_color.darkened(0.45)
	Game.make_noise(global_position, 5.0)
	Game.play_ui("fouille", -4.0)
	var found := Items.roll_loot(table, rolls)
	if found.is_empty():
		Game.msg("%s : rien d'utile." % label)
		return
	for id in found:
		player.add_item(id, found[id])
	Game.msg("Trouvé : " + Items.describe(found))
