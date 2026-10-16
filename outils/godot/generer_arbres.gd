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
	quit()


func _debut() -> void:
	st_bois = SurfaceTool.new()
	st_bois.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_feuil = SurfaceTool.new()
	st_feuil.begin(Mesh.PRIMITIVE_TRIANGLES)


func _fin(nom: String, m_bois: Material, m_feuil: Material) -> void:
	st_bois.generate_tangents()
	var mesh := st_bois.commit()
	mesh.surface_set_material(0, m_bois)
	st_feuil.commit(mesh)
	mesh.surface_set_material(1, m_feuil)
	var err := ResourceSaver.save(mesh, OUT + nom + ".res", ResourceSaver.FLAG_COMPRESS)
	print(nom, " surfaces ", mesh.get_surface_count(), " sommets ", mesh.surface_get_array_len(0) + mesh.surface_get_array_len(1), " err ", err)


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


func _conifere(idx: int, m_bois: Material, m_feuil: Material) -> void:
	_debut()
	var h := rng.randf_range(8.0, 12.0)
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
		var portee := lerpf(2.6, 0.4, t) * rng.randf_range(0.85, 1.1)
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
