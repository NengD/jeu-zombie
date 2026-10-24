extends SceneTree
## Génère des arbres réalistes (tronc et branches texturés + amas de feuilles en « cartes »)
## dans res://modeles/arbres/arbre_<n>.res (ArrayMesh à 2 surfaces : écorce, feuillage).
## Lancer : godot --headless --path . -s res://outils/godot/generer_arbres.gd

const OUT := "res://modeles/arbres/"
var rng := RandomNumberGenerator.new()
var st_bois: SurfaceTool
var st_feuil: SurfaceTool
var centre_houppier := Vector3.ZERO


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var ecorce := StandardMaterial3D.new()
	ecorce.albedo_texture = load("res://textures/ecorce_albedo.jpg")
	ecorce.normal_enabled = true
	ecorce.normal_texture = load("res://textures/ecorce_normal.png")
	ecorce.roughness = 0.95
	ecorce.vertex_color_use_as_albedo = true
	var feuilles := StandardMaterial3D.new()
	feuilles.albedo_texture = load("res://textures/feuillage_albedo.png")
	feuilles.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	feuilles.alpha_scissor_threshold = 0.5
	feuilles.cull_mode = BaseMaterial3D.CULL_DISABLED
	feuilles.roughness = 0.85
	feuilles.vertex_color_use_as_albedo = true
	feuilles.backlight_enabled = true
	feuilles.backlight = Color(0.25, 0.3, 0.1)
	var aiguilles: StandardMaterial3D = feuilles.duplicate()
	aiguilles.albedo_texture = load("res://textures/aiguilles_albedo.png")
	for i in 4:
		rng.seed = 100 + i
		_feuillu(i, ecorce, feuilles)
	for i in 2:
		rng.seed = 200 + i
		_conifere(i, ecorce, aiguilles)
	# variété : épicéa étroit, jeune arbre, arbres morts, buissons fleuris
	rng.seed = 202
	_conifere(2, ecorce, aiguilles, true)
	rng.seed = 300
	_jeune(0, ecorce, feuilles)
	for i in 2:
		rng.seed = 400 + i
		_mort(i, ecorce)
	for i in 2:
		rng.seed = 500 + i
		_buisson_fleuri(i, ecorce, feuilles)
	quit()


func _debut() -> void:
	st_bois = SurfaceTool.new()
	st_bois.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_feuil = SurfaceTool.new()
	st_feuil.begin(Mesh.PRIMITIVE_TRIANGLES)


func _fin(nom: String, m_bois: Material, m_feuil: Material) -> ArrayMesh:
	st_bois.generate_tangents()
	var mesh := st_bois.commit()
	mesh.surface_set_material(0, m_bois)
	if m_feuil:
		st_feuil.commit(mesh)
		mesh.surface_set_material(1, m_feuil)
	var err := ResourceSaver.save(mesh, OUT + nom + ".res", ResourceSaver.FLAG_COMPRESS)
	print(nom, " surfaces ", mesh.get_surface_count(), " err ", err)
	return mesh


## Cylindre conique le long d'une polyligne (points + rayons).
func _branche(pts: Array, rayons: Array, cotes := 7) -> void:
	var anneaux := []
	for i in pts.size():
		var dir: Vector3 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var ref := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		var u := dir.cross(ref).normalized()
		var v := dir.cross(u).normalized()
		var anneau := []
		for k in cotes + 1:
			var a := TAU * k / cotes
			var n := (u * cos(a) + v * sin(a))
			anneau.append([pts[i] + n * rayons[i], n])
		anneaux.append(anneau)
	var long := 0.0
	var longs := [0.0]
	for i in range(1, pts.size()):
		long += pts[i].distance_to(pts[i - 1])
		longs.append(long)
	for i in pts.size() - 1:
		for k in cotes:
			var quad := [[i, k], [i + 1, k], [i + 1, k + 1], [i, k], [i + 1, k + 1], [i, k + 1]]
			for q in quad:
				var e: Array = anneaux[q[0]][q[1]]
				st_bois.set_normal(e[1])
				st_bois.set_color(Color(1, 1, 1))
				st_bois.set_uv(Vector2(float(q[1]) / cotes * 2.0, -longs[q[0]] * 1.0))
				st_bois.add_vertex(e[0])


## Carte de feuillage : quad orienté aléatoirement, normales « bombées » vers l'extérieur du houppier.
func _carte(c: Vector3, taille: float, teinte: Color) -> void:
	var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
	var u := b.x * taille * 0.5
	var v := b.y * taille * 0.5
	var coins := [c - u - v, c + u - v, c + u + v, c - u + v]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for i in [0, 1, 2, 0, 2, 3]:
		var n: Vector3 = (coins[i] - centre_houppier).normalized()
		st_feuil.set_normal(n)
		st_feuil.set_color(teinte)
		st_feuil.set_uv(uvs[i])
		st_feuil.add_vertex(coins[i])


func _courbe(depart: Vector3, dir: Vector3, longueur: float, segs: int, courbure: float, gravite: float) -> Array:
	var pts := [depart]
	var p := depart
	var d := dir.normalized()
	for i in segs:
		d = (d + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5), rng.randf_range(-1, 1)) * courbure + Vector3.DOWN * gravite).normalized()
		p += d * longueur / segs
		pts.append(p)
	return pts


func _feuillu(idx: int, m_bois: Material, m_feuil: Material) -> void:
	_debut()
	var h := rng.randf_range(5.5, 8.0)
	var r0 := rng.randf_range(0.18, 0.28)
	var tronc := _courbe(Vector3.ZERO, Vector3.UP, h * 0.62, 6, 0.08, 0.0)
	var rayons := []
	for i in tronc.size():
		rayons.append(r0 * lerpf(1.25 if i == 0 else 1.0, 0.55, float(i) / (tronc.size() - 1)))
	_branche(tronc, rayons, 9)
	var haut: Vector3 = tronc[tronc.size() - 1]
	centre_houppier = haut + Vector3(0, h * 0.18, 0)
	var teinte_base := Color(0.82, 0.85, 0.75).lerp(Color(0.75, 0.8, 0.6), rng.randf())
	# branches principales
	var nb := rng.randi_range(6, 9)
	for b in nb:
		var t := rng.randf_range(0.45, 1.0)
		var i0 := int(t * (tronc.size() - 1))
		var base: Vector3 = tronc[i0]
		var ang := TAU * b / nb + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), rng.randf_range(0.6, 1.2), sin(ang))
		var lg := h * rng.randf_range(0.3, 0.45)
		var br := _courbe(base, dir, lg, 4, 0.25, 0.05)
		var rb := []
		for i in br.size():
			rb.append(r0 * 0.45 * lerpf(1.0, 0.25, float(i) / (br.size() - 1)))
		_branche(br, rb, 6)
		# rameaux secondaires + feuillage
		for k in range(1, br.size()):
			var p: Vector3 = br[k]
			for s in 2:
				var d2 := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.0, 0.8), rng.randf_range(-1, 1))
				var r2 := _courbe(p, d2, lg * 0.35, 2, 0.3, 0.1)
				_branche(r2, [r0 * 0.12, r0 * 0.07, r0 * 0.03], 4)
				for q in r2:
					for c in 3:
						var pc: Vector3 = q + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.3, 0.5), rng.randf_range(-0.5, 0.5))
						var teinte := teinte_base * rng.randf_range(0.75, 1.1)
						teinte.a = 1.0
						_carte(pc, rng.randf_range(1.1, 1.7), teinte)
	# couronne du sommet
	for c in 30:
		var pc := centre_houppier + Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(-0.5, 1.8), rng.randf_range(-1.6, 1.6))
		_carte(pc, rng.randf_range(1.2, 1.8), teinte_base * rng.randf_range(0.8, 1.1))
	_fin("arbre_%d" % idx, m_bois, m_feuil)


func _conifere(idx: int, m_bois: Material, m_feuil: Material, etroit := false) -> void:
	_debut()
	var h := rng.randf_range(8.0, 12.0) * (1.15 if etroit else 1.0)
	var r0 := rng.randf_range(0.2, 0.3)
	var tronc := _courbe(Vector3.ZERO, Vector3.UP, h, 8, 0.03, 0.0)
	var rayons := []
	for i in tronc.size():
		rayons.append(r0 * lerpf(1.2, 0.05, float(i) / (tronc.size() - 1)))
	_branche(tronc, rayons, 8)
	centre_houppier = Vector3(0, h * 0.5, 0)
	var etages := 14
	for e in etages:
		var t := lerpf(0.18, 0.97, float(e) / (etages - 1))
		var y := h * t
		var portee := lerpf(2.6, 0.4, t) * rng.randf_range(0.85, 1.1) * (0.8 if etroit else 1.0)
		var nb := int(lerpf(9, 4, t))
		for b in nb:
			var ang := TAU * b / nb + rng.randf_range(-0.3, 0.3) + e
			var d := Vector3(cos(ang), -0.15, sin(ang))
			var p0 := Vector3(0, y, 0)
			var br := _courbe(p0, d, portee, 2, 0.1, 0.12)
			_branche(br, [r0 * 0.25, r0 * 0.12, r0 * 0.03], 4)
			# cartes d'aiguilles le long de la branche (à plat, légèrement tombantes)
			for q in 3:
				var pc: Vector3 = p0.lerp(br[2], 0.3 + q * 0.3)
				var dirb: Vector3 = (br[2] - p0).normalized()
				var lat := dirb.cross(Vector3.UP).normalized()
				var lg := portee * 0.55
				var la := portee * 0.35
				var coins := [pc - dirb * lg * 0.5 - lat * la, pc + dirb * lg * 0.5 - lat * la + Vector3.DOWN * 0.15,
						pc + dirb * lg * 0.5 + lat * la + Vector3.DOWN * 0.15, pc - dirb * lg * 0.5 + lat * la]
				var uvs := [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
				var teinte := Color(1, 1, 1) * rng.randf_range(0.75, 1.05)
				teinte.a = 1.0
				for i in [0, 1, 2, 0, 2, 3]:
					st_feuil.set_normal((coins[i] - centre_houppier).normalized().lerp(Vector3.UP, 0.4).normalized())
					st_feuil.set_color(teinte)
					st_feuil.set_uv(uvs[i])
					st_feuil.add_vertex(coins[i])
	_fin("sapin_%d" % idx, m_bois, m_feuil)


## Jeune feuillu : tronc fin, quelques branches, houppier clairsemé (mis à l'échelle comme les autres).
func _jeune(idx: int, m_bois: Material, m_feuil: Material) -> void:
	_debut()
	var h := rng.randf_range(3.2, 4.2)
	var tronc := _courbe(Vector3.ZERO, Vector3.UP, h * 0.7, 5, 0.06, 0.0)
	var rayons := []
	for i in tronc.size():
		rayons.append(lerpf(0.08, 0.03, float(i) / (tronc.size() - 1)))
	_branche(tronc, rayons, 6)
	centre_houppier = tronc[tronc.size() - 1] + Vector3(0, 0.4, 0)
	var teinte_base := Color(0.8, 0.9, 0.62)
	for b in 5:
		var i0 := rng.randi_range(2, tronc.size() - 1)
		var ang := TAU * b / 5.0 + rng.randf_range(-0.4, 0.4)
		var br := _courbe(tronc[i0], Vector3(cos(ang), 1.0, sin(ang)), h * 0.3, 3, 0.25, 0.0)
		_branche(br, [0.03, 0.018, 0.008, 0.004], 4)
		for q in br:
			for c in 2:
				_carte(q + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.1, 0.4), rng.randf_range(-0.3, 0.3)),
						rng.randf_range(0.7, 1.1), teinte_base * rng.randf_range(0.8, 1.1))
	_fin("jeune_%d" % idx, m_bois, m_feuil)


## Arbre mort : tronc sec et grisé, branches nues cassées, sans feuillage.
func _mort(idx: int, m_bois: Material) -> void:
	_debut()
	var h := rng.randf_range(5.0, 7.5)
	var r0 := rng.randf_range(0.2, 0.3)
	var tronc := _courbe(Vector3.ZERO, Vector3.UP, h * (0.75 if idx == 0 else 0.45), 6, 0.1, 0.0)
	var rayons := []
	for i in tronc.size():
		rayons.append(r0 * lerpf(1.25 if i == 0 else 1.0, 0.45, float(i) / (tronc.size() - 1)))
	_branche(tronc, rayons, 8)
	var nb := rng.randi_range(7, 10) if idx == 0 else 3
	for b in nb:
		var i0 := rng.randi_range(2, tronc.size() - 1)
		var ang := rng.randf() * TAU
		var br := _courbe(tronc[i0], Vector3(cos(ang), rng.randf_range(0.3, 1.0), sin(ang)), h * rng.randf_range(0.25, 0.45), 3, 0.35, 0.05)
		_branche(br, [r0 * 0.4, r0 * 0.25, r0 * 0.12, r0 * 0.04], 5)
		var bout: Vector3 = br[br.size() - 1]
		_branche(_courbe(bout, Vector3(rng.randf_range(-1, 1), 0.6, rng.randf_range(-1, 1)), h * 0.1, 2, 0.4, 0.0), [r0 * 0.05, r0 * 0.03, r0 * 0.01], 4)
	# bois sec : écorce grisée (couleur de sommet)
	var arr := st_bois.commit_to_arrays()
	var cols := PackedColorArray()
	cols.resize((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	cols.fill(Color(0.72, 0.68, 0.64))
	arr[Mesh.ARRAY_COLOR] = cols
	st_bois = SurfaceTool.new()
	st_bois.create_from_arrays(arr)
	_fin("mort_%d" % idx, m_bois, null)


## Buisson fleuri (décor des jardins et de la campagne) : touffe de rameaux et de cartes de feuilles,
## une partie teintée en fleurs. Enregistré comme décor : res://modeles/props/buisson_fleuri_<n>.scn.
func _buisson_fleuri(idx: int, m_bois: Material, m_feuil: Material) -> void:
	_debut()
	centre_houppier = Vector3(0, 0.55, 0)
	var fleur: Color = [Color(1.0, 0.62, 0.8), Color(1.0, 0.95, 0.6)][idx % 2]
	st_fleur = SurfaceTool.new()
	st_fleur.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in 9:
		var ang := TAU * b / 9.0 + rng.randf_range(-0.3, 0.3)
		var br := _courbe(Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1)), Vector3(cos(ang) * 0.6, 1.0, sin(ang) * 0.6), rng.randf_range(0.7, 1.0), 2, 0.3, 0.0)
		_branche(br, [0.025, 0.015, 0.005], 4)
		for q in br:
			for c in 3:
				var pc: Vector3 = q + Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.1, 0.25), rng.randf_range(-0.25, 0.25))
				var t := Color(0.75, 0.85, 0.6) * rng.randf_range(0.8, 1.05)
				t.a = 1.0
				_carte(pc, rng.randf_range(0.45, 0.7), t)
				if rng.randf() < 0.85:
					# fleurs : petites cartes claires posées sur le feuillage (3e surface, texture blanchie)
					var st_f := st_feuil
					st_feuil = st_fleur
					_carte(pc + (pc - centre_houppier).normalized() * 0.08, rng.randf_range(0.28, 0.42), fleur * rng.randf_range(0.9, 1.0))
					st_feuil = st_f
	var mesh := _fin("buisson_fleuri_%d" % idx, m_bois, m_feuil)
	st_fleur.commit(mesh)
	mesh.surface_set_material(2, _mat_fleurs(m_feuil))
	var racine := Node3D.new()
	racine.name = "buisson_fleuri_%d" % idx
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	racine.add_child(mi)
	mi.owner = racine
	var ps := PackedScene.new()
	ps.pack(racine)
	ResourceSaver.save(ps, "res://modeles/props/buisson_fleuri_%d.scn" % idx, ResourceSaver.FLAG_COMPRESS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + "buisson_fleuri_%d.res" % idx))
	# taille pour Decor (modeles/props/tailles.json)
	var a := mesh.get_aabb()
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://modeles/props/tailles.json"))
	d["buisson_fleuri_%d" % idx] = [snappedf(a.size.x, 0.001), snappedf(a.size.y, 0.001), snappedf(a.size.z, 0.001)]
	var fa := FileAccess.open("res://modeles/props/tailles.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(d, "\t"))


var st_fleur: SurfaceTool


## Matériau des fleurs : même découpe que le feuillage mais texture blanchie (la couleur vient des sommets).
func _mat_fleurs(m_feuil: StandardMaterial3D) -> StandardMaterial3D:
	var img: Image = m_feuil.albedo_texture.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(0.85 + c.r * 0.15, 0.85 + c.g * 0.15, 0.85 + c.b * 0.15, c.a))
	img.resize(128, 128)
	var m: StandardMaterial3D = m_feuil.duplicate()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.backlight_enabled = false
	return m
