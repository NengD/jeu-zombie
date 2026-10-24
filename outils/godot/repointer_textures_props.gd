extends SceneTree
## Scènes de modeles/props dont une texture pointe encore vers outils/ (exclu de l'export) : texture copiée à la main
## dans modeles/props/tex/ (puis --import), ce script la repointe. Lancer : godot --headless --path . -s res://outils/godot/repointer_textures_props.gd
const COULEURS := {"White": Color(0.92, 0.92, 0.9), "Red": Color(0.75, 0.08, 0.08), "Windows": Color(0.12, 0.16, 0.2),
	"Bumper": Color(0.25, 0.25, 0.27), "Lights": Color(0.95, 0.9, 0.7), "Grey": Color(0.45, 0.45, 0.47), "Material": Color(0.1, 0.1, 0.1)}
func _initialize() -> void:
	for f in DirAccess.get_files_at("res://modeles/props"):
		if not f.ends_with(".scn"):
			continue
		var ps: PackedScene = load("res://modeles/props/" + f)
		var n: Node = ps.instantiate()
		var modif := false
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var m = mi.mesh.surface_get_material(s)
				if m is BaseMaterial3D and m.albedo_texture and m.albedo_texture.resource_path.begins_with("res://outils"):
					print(f, " : ", m.resource_name, " ", m.albedo_texture.resource_path)
					var c: StandardMaterial3D = m.duplicate()
					var nom: String = m.albedo_texture.resource_path.get_file().replace("camionnette_1387 Van", "camionnette_van").replace("moto_1388 Motorcycle", "moto_motorcycle")
					c.albedo_texture = load("res://modeles/props/tex/" + nom)
					mi.mesh.surface_set_material(s, c)
					modif = true
		if modif:
			var p2 := PackedScene.new()
			p2.pack(n)
			print(" -> ", ResourceSaver.save(p2, "res://modeles/props/" + f, ResourceSaver.FLAG_COMPRESS))
	quit()
