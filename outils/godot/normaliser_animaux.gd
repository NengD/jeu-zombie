extends SceneTree
## Convertit les animaux de Quaternius (« Ultimate Animated Animal Pack », CC0, outils/sources_animaux/)
## en scènes du jeu : res://modeles/animaux/<id>.scn
##  - avant de l'animal vers -Z, pieds à y = 0, hauteur imposée, textures réduites à 256 px
## Lancer : godot --headless --path . -s res://outils/godot/normaliser_animaux.gd

const SRC := "res://outils/sources_animaux/"
const OUT := "res://modeles/animaux/"
# id : [fichier source, hauteur totale visée (m)]
const CFG := {"cerf": ["stag", 2.05], "biche": ["deer", 1.5]}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for id in CFG:
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(SRC + CFG[id][0] + ".glb", st) != OK:
			push_error("lecture impossible : " + CFG[id][0])
			continue
		var modele: Node3D = doc.generate_scene(st)
		var boite := _boite(modele, Transform3D.IDENTITY)
		var k: float = CFG[id][1] / boite.size.y
		var racine := Node3D.new()
		racine.name = id
		racine.add_child(modele)
		modele.scale = Vector3.ONE * k
		modele.rotation.y = PI          # glTF : avant vers +Z
		var centre := boite.get_center()
		modele.position = Vector3(centre.x * k, -boite.position.y * k, -centre.z * k)
		for m in modele.find_children("*", "MeshInstance3D", true, false):
			_reduire_textures(m)
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_proprietaire(modele, racine)
		var ps := PackedScene.new()
		ps.pack(racine)
		var err := ResourceSaver.save(ps, OUT + id + ".scn", ResourceSaver.FLAG_COMPRESS)
		print(id, " : hauteur ", CFG[id][1], " m, échelle ", k, ", longueur ", boite.size.z * k, " m -> ", err)
	quit()


func _boite(n: Node, xf: Transform3D) -> AABB:
	var b := AABB()
	var premier := true
	if n is Node3D:
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		b = xf * (n as MeshInstance3D).get_aabb()
		premier = false
	for c in n.get_children():
		var bc := _boite(c, xf)
		if bc.size != Vector3.ZERO:
			b = bc if premier else b.merge(bc)
			premier = false
	return b


func _reduire_textures(m: MeshInstance3D) -> void:
	for s in m.mesh.get_surface_count():
		var mat := m.mesh.surface_get_material(s)
		if mat is BaseMaterial3D and mat.albedo_texture:
			var img: Image = mat.albedo_texture.get_image()
			if img and img.get_width() > 256:
				img.resize(256, 256 * img.get_height() / img.get_width())
				mat.albedo_texture = ImageTexture.create_from_image(img)


func _proprietaire(n: Node, racine: Node) -> void:
	for c in n.get_children():
		c.owner = racine
		_proprietaire(c, racine)
	if n != racine:
		n.owner = racine
