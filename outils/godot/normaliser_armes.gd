extends SceneTree
## Normalise les modèles d'armes téléchargés : taille réelle, canon/lame vers -Z, origine = poignée.
## Sauvegarde des scènes autonomes dans res://modeles/armes/<id>.scn
const S := "res://modeles/sources/cc0/"
# id: [source, axe long ('x','y','z'), sens (+1 = la bouche/la tête est du côté +), longueur visée (0 = garder), part poignée depuis l'arrière, hauteur poignée (0..1)]
const CFG := {
	"pistolet": [S + "ug__pistol_4.glb", "x", 1, 0.19, 0.22, 0.42],
	"revolver": [S + "ug__revolver_2.glb", "x", 1, 0.27, 0.2, 0.45],
	"fusil_pompe": [S + "ug__shotgun_1.glb", "x", 1, 1.0, 0.36, 0.45],
	"carabine": [S + "ug__assault_rifle2_2.glb", "x", 1, 0.84, 0.36, 0.48],
	"fusil_assaut": ["res://modeles/sources/ak47/SKM_AK47.fbx", "z", 1, 0.88, 0.3, 0.42],
	"couteau": [S + "sv__knife.glb", "y", 1, 0.3, 0.14, 0.5],
	"machette": [S + "ph__machete.glb", "y", 1, 0.0, 0.1, 0.5],
	"hache": [S + "ph__wooden_axe_02.glb", "y", 1, 0.0, 0.1, 0.5],
	"pied_de_biche": [S + "ph__crowbar_01.glb", "y", 1, 0.0, 0.15, 0.5],
	"masse": [S + "ph__sledgehammer_01.glb", "y", 1, 0.9, 0.08, 0.5],
	"cle_tuyau": [S + "ph__pipe_wrench.glb", "y", -1, 0.0, 0.15, 0.5],
	"batte_cloutee": [S + "zk__wooden_bat_barbed.glb", "z", 1, 0.86, 0.1, 0.5],
}

func _collect(n: Node, xf: Transform3D, out: Array):
	var t = xf * n.transform if n is Node3D else xf
	if n is MeshInstance3D and n.mesh:
		out.append([n, t])
	for c in n.get_children(): _collect(c, t, out)

func _ak_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://modeles/sources/ak47/T_AK47_C.png")
	m.normal_enabled = true
	m.normal_texture = load("res://modeles/sources/ak47/T_AK47_N.png")
	var rmao = load("res://modeles/sources/ak47/T_AK47_RMAO.png")
	m.roughness_texture = rmao
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.metallic = 1.0
	m.metallic_texture = rmao
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.ao_enabled = true
	m.ao_texture = rmao
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	return m

func _initialize():
	DirAccess.make_dir_recursive_absolute("res://modeles/armes")
	for id in CFG:
		var c: Array = CFG[id]
		var src = load(c[0]).instantiate()
		var meshes := []
		_collect(src, Transform3D.IDENTITY, meshes)
		var a = null
		for m in meshes:
			var b: AABB = m[1] * m[0].mesh.get_aabb()
			a = b if a == null else a.merge(b)
		var axis: String = c[1]
		var sgn: int = c[2]
		var ai: int = {"x": 0, "y": 1, "z": 2}[axis]
		var length: float = a.size[ai]
		var k: float = 1.0 if c[3] == 0.0 else c[3] / length
		# poignée : depuis l'arrière (côté opposé à la bouche/tête)
		var grip: Vector3 = a.get_center()
		var back: float = a.position[ai] if sgn > 0 else a.end[ai]
		grip[ai] = back + sgn * c[4] * length
		if axis != "y":
			grip.y = a.position.y + c[5] * a.size.y
		# rotation : direction de la bouche (axe source * sgn) -> -Z ; haut -> +Y
		var fwd := Vector3.ZERO
		fwd[ai] = sgn
		var up := Vector3.UP if axis != "y" else Vector3(0, 0, 1)
		if axis == "y":
			# lame vers -Z, tranchant vers le bas : la face +Z source devient le haut
			up = Vector3(1, 0, 0) if id in ["masse", "cle_tuyau", "couteau"] else Vector3(0, 0, 1)
		var basis_src := Basis(fwd.cross(up).normalized(), up, -fwd)  # colonnes: x, y, z (z = -fwd)
		var rot := basis_src.inverse()
		var root3 := Node3D.new()
		root3.name = id
		var xf_all := Transform3D(rot.scaled(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis(), -grip)
		var i := 0
		for m in meshes:
			var mi := MeshInstance3D.new()
			mi.name = "Maillage%d" % i
			var mesh: Mesh = m[0].mesh.duplicate()
			for s in mesh.get_surface_count():
				var mat = m[0].get_surface_override_material(s)
				if mat == null:
					mat = mesh.surface_get_material(s)
				if id == "fusil_assaut":
					mat = _ak_material()
				if mat:
					mesh.surface_set_material(s, mat)
			mi.mesh = mesh
			mi.transform = xf_all * m[1]
			root3.add_child(mi)
			mi.owner = root3
			i += 1
		var ps := PackedScene.new()
		ps.pack(root3)
		var err := ResourceSaver.save(ps, "res://modeles/armes/%s.scn" % id)
		print(id, " -> ", err, "  longueur source ", snappedf(length, 0.01), " k=", snappedf(k, 0.001))
	quit()
