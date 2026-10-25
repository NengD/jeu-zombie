extends SceneTree
## Convertit les animaux téléchargés (outils/sources_animaux/) en scènes du jeu : res://modeles/animaux/<id>.scn
##  - cerf, biche : « Ultimate Animated Animal Pack » de Quaternius (CC0), animés
##  - sanglier, lapin, faisan : modèles fixes Poly by Google (CC BY 3.0) découpés en morceaux articulés
##    (nœuds « Tete » et « Patte* », méta « phase ») que animal.gd anime par le code
##  - avant de l'animal vers -Z, pieds à y = 0, hauteur imposée, textures réduites à 256 px
## Lancer : godot --headless --path . -s res://outils/godot/normaliser_animaux.gd

const SRC := "res://outils/sources_animaux/"
const OUT := "res://modeles/animaux/"
# id : [fichier source, hauteur totale visée (m), rotation pour mettre l'avant vers -Z]
const CFG := {"cerf": ["stag", 2.05, PI], "biche": ["deer", 1.5, PI],
	"sanglier": ["boar", 0.85, PI], "lapin": ["lapin", 0.3, PI], "faisan": ["pheasant", 0.42, PI],
	# lot 2 : loup, chien, vache, chevaux (Quaternius CC0, animés) ; mouton (Quaternius CC0) et corbeau (Poly by Google CC BY) découpés
	"loup": ["loup", 0.9, PI], "chien": ["chien", 0.75, PI], "vache": ["vache", 1.5, PI], "cheval": ["cheval", 1.8, PI],
	"cheval_blanc": ["cheval_blanc", 1.75, PI], "mouton": ["mouton", 0.9, PI, true], "corbeau": ["corbeau", 0.32, PI]}
# découpage des modèles fixes : sorte, haut des pattes (part de la hauteur),
# tête = avant du corps (part de la longueur) au-dessus de y_tete (part de la hauteur)
const DECOUPE := {
	"sanglier": {"sorte": "quad", "patte": 0.34, "tete": 0.24, "y_tete": 0.0},
	"lapin": {"sorte": "lapin", "patte": 0.2, "tete": 0.32, "y_tete": 0.35},
	"faisan": {"sorte": "oiseau", "patte": 0.3, "tete": 0.3, "y_tete": 0.62},
	"mouton": {"sorte": "quad", "patte": 0.34, "tete": 0.26, "y_tete": 0.3},
	"corbeau": {"sorte": "oiseau", "patte": 0.25, "tete": 0.3, "y_tete": 0.55},
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var seuls := OS.get_environment("ANIMAL").split(",", false)
	for id in CFG:
		if seuls.size() > 0 and not seuls.has(id):
			continue
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(SRC + CFG[id][0] + ".glb", st) != OK:
			push_error("lecture impossible : " + CFG[id][0])
			continue
		var modele: Node3D = doc.generate_scene(st)
		var racine := Node3D.new()
		racine.name = id
		racine.add_child(modele)
		modele.rotation.y = CFG[id][2]
		if CFG[id].size() > 3:
			# modèle exporté couché (axe haut = +Z) : redressé
			modele.basis = Basis(Vector3.UP, PI / 2.0) * Basis(Vector3(0, 0, -1), Vector3(0, -1, 0), Vector3(-1, 0, 0)) * Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -PI / 2.0) * modele.basis
		var k: float = CFG[id][1] / _boite(modele, Transform3D.IDENTITY).size.y
		modele.scale = Vector3.ONE * k
		var boite := _boite(modele, Transform3D.IDENTITY)
		var centre := boite.get_center()
		modele.position = Vector3(-centre.x, -boite.position.y, -centre.z)
		for m in modele.find_children("*", "MeshInstance3D", true, false):
			_reduire_textures(m)
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if DECOUPE.has(id):
			var morceaux := _decouper(modele, DECOUPE[id])
			racine.remove_child(modele)
			modele.free()
			racine.add_child(morceaux)
			_proprietaire(morceaux, racine)
		else:
			_proprietaire(modele, racine)
		var ps := PackedScene.new()
		ps.pack(racine)
		var err := ResourceSaver.save(ps, OUT + id + ".scn", ResourceSaver.FLAG_COMPRESS)
		print(id, " : hauteur ", CFG[id][1], " m, échelle ", k, ", longueur ", boite.size.z, " m -> ", err)
	quit()


## Regroupe les triangles du modèle (repère de la racine) en corps / tête / pattes articulés.
func _decouper(modele: Node3D, d: Dictionary) -> Node3D:
	var tris := []   # [partie, matériau, [p0, p1, p2], [n0, n1, n2], [uv0, uv1, uv2], [c0, c1, c2]]
	var b := _boite(modele, Transform3D.IDENTITY)
	var h := b.size.y
	var y_patte: float = h * d.patte
	var z_tete: float = b.position.z + b.size.z * d.tete
	var y_tete: float = h * d.y_tete
	var z_mil := b.get_center().z
	for m in modele.find_children("*", "MeshInstance3D", true, false):
		var xf := _xf(m, modele)
		var mesh: Mesh = (m as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			var mat := (m as MeshInstance3D).get_surface_override_material(s)
			if mat == null:
				mat = mesh.surface_get_material(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] else PackedVector3Array()
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] else PackedVector2Array()
			var col: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] else PackedColorArray()
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] else PackedInt32Array(range(v.size()))
			for t in range(0, idx.size(), 3):
				var p := []
				var nn := []
				var uu := []
				var cc := []
				for j in 3:
					var i: int = idx[t + j]
					p.append(xf * v[i])
					nn.append((xf.basis * n[i]).normalized() if n.size() > 0 else Vector3.UP)
					uu.append(uv[i] if uv.size() > 0 else Vector2.ZERO)
					cc.append(col[i] if col.size() > 0 else Color.WHITE)
				var c: Vector3 = (p[0] + p[1] + p[2]) / 3.0
				var partie := "Corps"
				if c.z < z_tete and c.y > y_tete:
					partie = "Tete"
				elif c.y < y_patte:
					match d.sorte:
						"oiseau":
							partie = "Patte_g" if c.x < 0.0 else "Patte_d"
						_:
							partie = ("PatteAv" if c.z < z_mil else "PatteAr") + ("_g" if c.x < 0.0 else "_d")
				tris.append([partie, mat, p, nn, uu, cc])
	# pivots : haut des pattes, cou
	var somme := {}
	for tr in tris:
		var c: Vector3 = (tr[2][0] + tr[2][1] + tr[2][2]) / 3.0
		if not somme.has(tr[0]):
			somme[tr[0]] = [Vector3.ZERO, 0, INF]
		somme[tr[0]][0] += c
		somme[tr[0]][1] += 1
		for q in tr[2]:
			somme[tr[0]][2] = minf(somme[tr[0]][2], q.z)
	var pivots := {"Corps": Vector3.ZERO}
	for partie in somme:
		var moy: Vector3 = somme[partie][0] / float(somme[partie][1])
		if partie.begins_with("Patte"):
			pivots[partie] = Vector3(moy.x, y_patte, moy.z)
		elif partie == "Tete":
			pivots[partie] = Vector3(0.0, moy.y, z_tete + (z_tete - somme[partie][2]) * 0.15)
	var res := Node3D.new()
	res.name = "Animal"
	var outils := {}
	for tr in tris:
		var cle := [tr[0], tr[1]]
		if not outils.has(cle):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			outils[cle] = st
		var st2: SurfaceTool = outils[cle]
		for j in 3:
			st2.set_normal(tr[3][j])
			st2.set_uv(tr[4][j])
			st2.set_color(tr[5][j])
			st2.add_vertex(tr[2][j] - pivots[tr[0]])
	for partie in pivots:
		var piv := Node3D.new()
		piv.name = partie
		piv.position = pivots[partie]
		res.add_child(piv)
		var am := ArrayMesh.new()
		for cle in outils:
			if cle[0] == partie:
				var st3: SurfaceTool = outils[cle]
				st3.index()
				st3.commit(am)
				am.surface_set_material(am.get_surface_count() - 1, cle[1])
		var mi := MeshInstance3D.new()
		mi.name = "Maillage"
		mi.mesh = am
		piv.add_child(mi)
		if partie.begins_with("Patte"):
			# balancement : pattes en diagonale (quadrupède), avant / arrière ensemble (lapin), alternées (oiseau)
			var gauche: bool = partie.ends_with("_g")
			var avant: bool = partie.begins_with("PatteAv")
			var ph := 0.0
			match d.sorte:
				"quad":
					ph = 0.0 if gauche == avant else PI
				"lapin":
					ph = 0.0 if avant else PI
				_:
					ph = 0.0 if gauche else PI
			piv.set_meta("phase", ph)
	return res


func _xf(n: Node, jusqua: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var c := n
	while c != null:
		if c is Node3D:
			xf = (c as Node3D).transform * xf
		if c == jusqua:
			break
		c = c.get_parent()
	return xf


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
