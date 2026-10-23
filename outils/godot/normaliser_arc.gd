extends SceneTree
## Arc recourbé « Wooden Bow » et flèche « Arrow » de Quaternius (CC0, Poly Pizza ; outils/sources_arc/)
## -> res://modeles/armes/arc_corps.res et fleche.res (ArrayMesh) utilisés par scripts/arc.gd et scripts/fleche.gd.
## Repère de l'arc (celui de arc.gd) : X = doigts de la main d'arc, Y = avant, Z = haut ; poignée à l'origine.
## La corde du modèle est retirée (le jeu la tend lui-même) ; métadonnées du maillage : pointe_h, pointe_b (attaches
## de la corde), band (corde au repos, Y). Flèche : encoche à l'origine, pointe vers +Y, longueur « longueur ».
## Lancer : godot --headless --path . -s res://outils/godot/normaliser_arc.gd

const LONG_ARC := 1.3        # pointe à pointe (m)
const LONG_FLECHE := 0.78    # encoche -> pointe (m)


func _initialize() -> void:
	# --- arc : sommets du glb (repère du maillage, avant la transformation du nœud) -> repère glTF (x, z, -y) * 100
	var m := _maillage("arc_quat")
	var corde: PackedVector3Array = m.surface_get_arrays(2)[Mesh.ARRAY_VERTEX]
	var x_corde := 0.0
	var haut := 0.0
	for v in corde:
		x_corde += v.x / corde.size()
	var bois: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v in bois:
		haut = maxf(haut, absf(v.z))
	var xmin := INF
	var xmax := -INF
	for v in bois:

		if true:   # avant de la poignée (milieu de l'arc) = x le plus petit
			xmin = minf(xmin, v.x)
			xmax = maxf(xmax, v.x)
	var k := LONG_ARC / (2.0 * haut)
	var x_poignee := xmin + 0.0004   # main : 2-3 cm derrière l'avant de la poignée
	var ky := k * 0.72               # arc un peu aplati : corde à ~22 cm de la poignée
	print("poignée x ", xmin, " .. ", xmax, " corde x ", x_corde, " haut ", haut)
	# glTF -> arc : x_arc = y_maillage, y_arc = -(x - poignée), z_arc = z_maillage
	var xf := Transform3D(Basis(Vector3(0, -ky, 0), Vector3(k, 0, 0), Vector3(0, 0, k)), Vector3(0, x_poignee * ky, 0))
	var arc := ArrayMesh.new()
	for s in 2:
		_ajouter(arc, m, s, xf)
	var bout := xf * Vector3(x_corde, 0, haut)
	arc.set_meta("pointe_h", Vector3(0, bout.y, bout.z))
	arc.set_meta("pointe_b", Vector3(0, bout.y, -bout.z))
	arc.set_meta("band", bout.y)
	print("arc : échelle ", k, ", pointes ", arc.get_meta("pointe_h"), ", corde au repos y = ", bout.y, " -> ",
		ResourceSaver.save(arc, "res://modeles/armes/arc_corps.res"))
	# --- flèche : axe z du maillage = longueur (pointe vers +z)
	var f := _maillage("fleche_quat")
	var zmin := INF
	var zmax := -INF
	for s in f.get_surface_count():
		for v in f.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			zmin = minf(zmin, v.z)
			zmax = maxf(zmax, v.z)
	var kf := LONG_FLECHE / (zmax - zmin)
	var xff := Transform3D(Basis(Vector3(kf, 0, 0), Vector3(0, 0, -kf), Vector3(0, kf, 0)), Vector3(0, -zmin * kf, 0))
	var fl := ArrayMesh.new()
	for s in f.get_surface_count():
		_ajouter(fl, f, s, xff)
	fl.set_meta("longueur", LONG_FLECHE)
	print("flèche : échelle ", kf, " -> ", ResourceSaver.save(fl, "res://modeles/armes/fleche.res"))
	quit()


func _maillage(nom: String) -> ArrayMesh:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file("res://outils/sources_arc/%s.glb" % nom, st)
	var n: Node = doc.generate_scene(st)
	return (n.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh


func _ajouter(dest: ArrayMesh, src: ArrayMesh, s: int, xf: Transform3D) -> void:
	var st := SurfaceTool.new()
	st.create_from(src, s)
	var a := st.commit_to_arrays()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	for i in v.size():
		v[i] = xf * v[i]
		if n.size() > 0:
			n[i] = (xf.basis * n[i]).normalized()
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = n
	a[Mesh.ARRAY_TANGENT] = null
	dest.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	var mat := (src.surface_get_material(s) as BaseMaterial3D).duplicate() as BaseMaterial3D
	mat.roughness = 0.75
	dest.surface_set_material(dest.get_surface_count() - 1, mat)
