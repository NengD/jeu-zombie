extends SceneTree
## Crée modeles/armes/pioche.scn (repère des armes : manche vers -Z, origine = main droite,
## tête au bout du manche, pointe vers +Y et tranchant plat vers -Y ; low-poly).
## godot --headless --path . -s res://outils/godot/creer_pioche.gd


func _initialize():
	var racine := Node3D.new()
	racine.name = "pioche"
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color(0.45, 0.3, 0.17)
	bois.roughness = 0.8
	var fer := StandardMaterial3D.new()
	fer.albedo_color = Color(0.36, 0.36, 0.38)
	fer.metallic = 0.6
	fer.roughness = 0.45
	var manche := BoxMesh.new()
	manche.size = Vector3(0.036, 0.04, 0.88)
	_piece(racine, "Manche", manche, bois, Vector3(0, 0, -0.29), Vector3.ZERO)
	var douille := BoxMesh.new()
	douille.size = Vector3(0.055, 0.085, 0.07)
	_piece(racine, "Douille", douille, fer, Vector3(0, 0, -0.69), Vector3.ZERO)
	# pointe (vers +Y), légèrement recourbée vers l'arrière
	var pointe := CylinderMesh.new()
	pointe.top_radius = 0.004
	pointe.bottom_radius = 0.026
	pointe.height = 0.27
	pointe.radial_segments = 6
	pointe.rings = 1
	_piece(racine, "Pointe", pointe, fer, Vector3(0, 0.17, -0.715), Vector3(-0.22, 0, 0))
	# tranchant plat (vers -Y)
	var plat := CylinderMesh.new()
	plat.top_radius = 0.026
	plat.bottom_radius = 0.008
	plat.height = 0.22
	plat.radial_segments = 4
	plat.rings = 1
	var n := _piece(racine, "Tranchant", plat, fer, Vector3(0, -0.15, -0.71), Vector3(0.2, 0, 0))
	n.scale = Vector3(1.5, 1.0, 0.45)
	var ps := PackedScene.new()
	ps.pack(racine)
	print(ResourceSaver.save(ps, "res://modeles/armes/pioche.scn"))
	quit()


func _piece(parent: Node3D, nom: String, m: Mesh, mat: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	mi.owner = parent
	return mi
