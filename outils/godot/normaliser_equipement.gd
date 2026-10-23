extends SceneTree
## Convertit les modèles d'équipement téléchargés (outils/sources_equipement/, Poly Pizza et OpenGameArt)
## en maillages uniques légers : res://modeles/equipement/<id>.res
##  - un seul ArrayMesh par modèle (surfaces regroupées par matériau), transformations appliquées
##  - repère du personnage : avant vers +Z (visage), haut +Y ; origine au centre de la boîte englobante
##  - taille réelle imposée sur un axe (après rotation)
## Lancer : godot --headless --path . -s res://outils/godot/normaliser_equipement.gd

const SRC := "res://outils/sources_equipement/"
const OUT := "res://modeles/equipement/"

# id : [fichier source, rotation Y (degrés), axe mesuré ("x", "y", "z"), taille (m), teinte des matériaux]
const CFG := {
	"bonnet": ["bonnet.glb", 0.0, "x", 0.225, Color(0.30, 0.32, 0.36)],
	"casquette": ["casquette.glb", -90.0, "x", 0.215, Color(0.25, 0.30, 0.22)],
	"casquette_police": ["casquette_police.glb", -90.0, "x", 0.235, Color(0.18, 0.2, 0.32)],
	"casque_chantier": ["casque_chantier.glb", 90.0, "x", 0.30, Color.WHITE],
	"casque_combat": ["casque_combat.obj", 0.0, "x", 0.27, Color(1.15, 1.25, 1.1)],
	"casque_integral": ["casque_integral.glb", 0.0, "x", 0.27, Color.WHITE],
	"lunettes": ["lunettes.glb", 0.0, "x", 0.20, Color.WHITE],
	"masque_gaz": ["masque_gaz.glb", 180.0, "x", 0.21, Color(0.6, 0.62, 0.55)],
	"sac_a_dos": ["sac_a_dos.glb", 180.0, "x", 0.40, Color.WHITE],
	"sac_militaire": ["sac_militaire.glb", 180.0, "x", 0.46, Color.WHITE],
	"sac_randonnee": ["sac_randonnee.glb", 180.0, "y", 0.62, Color.WHITE],
	"sac_chasse": ["sac_chasse.glb", 180.0, "y", 0.42, Color.WHITE],
	"sac_sport": ["sac_sport.glb", 0.0, "x", 0.58, Color(0.45, 0.5, 0.55)],
	"sacoche": ["sacoche.glb", 90.0, "z", 0.28, Color(0.9, 0.85, 0.75)],
}


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for id in CFG:
		_convertir(id, CFG[id])
	quit()


func _convertir(id: String, c: Array) -> void:
	var r = load(SRC + c[0])
	var n: Node3D
	if r is PackedScene:
		n = r.instantiate()
	else:
		n = Node3D.new()
		var mi0 := MeshInstance3D.new()
		mi0.mesh = r
		n.add_child(mi0)
	root.add_child(n)
	var rot := Transform3D(Basis(Vector3.UP, deg_to_rad(c[1])), Vector3.ZERO)
	# surfaces regroupées par matériau
	var groupes := {}   # couleur html -> [SurfaceTool, matériau]
	var boite := AABB()
	var premier := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var t: Transform3D = rot * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			var col := Color(0.5, 0.5, 0.5)
			if m is StandardMaterial3D:
				col = (m as StandardMaterial3D).albedo_color
			var cle := col.to_html(false)
			if not groupes.has(cle):
				var st0 := SurfaceTool.new()
				st0.begin(Mesh.PRIMITIVE_TRIANGLES)
				groupes[cle] = [st0, col]
			var st: SurfaceTool = groupes[cle][0]
			var a: Array = mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var nr: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] else PackedInt32Array(range(v.size()))
			for i in idx:
				var p: Vector3 = t * v[i]
				if nr.size() > i:
					st.set_normal((t.basis * nr[i]).normalized())
				st.add_vertex(p)
				boite = AABB(p, Vector3.ZERO) if premier else boite.expand(p)
				premier = false
	var axe: float = {"x": boite.size.x, "y": boite.size.y, "z": boite.size.z}[c[2]]
	var ech: float = c[3] / axe
	var centre := boite.get_center()
	var mesh := ArrayMesh.new()
	for cle in groupes:
		var st: SurfaceTool = groupes[cle][0]
		var arr := st.commit_to_arrays()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in v.size():
			v[i] = (v[i] - centre) * ech
		arr[Mesh.ARRAY_VERTEX] = v
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat := StandardMaterial3D.new()
		var col: Color = groupes[cle][1]
		var teinte: Color = c[4]
		mat.albedo_color = Color(clampf(col.r * teinte.r, 0, 1), clampf(col.g * teinte.g, 0, 1), clampf(col.b * teinte.b, 0, 1))
		mat.roughness = 0.8
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # modèles parfois ouverts (intérieur des casques)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	ResourceSaver.save(mesh, OUT + id + ".res")
	print("%s : %d surfaces, taille %s" % [id, mesh.get_surface_count(), (boite.size * ech)])
	n.queue_free()
