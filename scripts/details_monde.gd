extends Node3D
## Détails du monde pour le réalisme :
##  - décalques : saleté et coulures au pied des façades, taches d'huile, fissures, traces de sang
##    sur les routes et trottoirs de la ville ;
##  - herbe haute qui ondule au vent, par parcelles autour du joueur (campagne, parcs).

const HerbeShader = preload("res://shaders/herbe.gdshader")

var world: Node
var rng := RandomNumberGenerator.new()
static var _tex := {}

# herbe
const PARCELLE := 12.0
var rayon_parcelles := 5          # parcelles chargées autour du joueur (dans chaque direction)
var densite := 700                # brins (touffes) par parcelle
var parcelles := {}               # Vector2i -> MultiMeshInstance3D
var a_creer: Array = []
var herbe_mesh: ArrayMesh
var herbe_mat: ShaderMaterial
var fleur_mesh: ArrayMesh
var fleur_mat: ShaderMaterial
const COULEURS_FLEURS := [Color(0.95, 0.94, 0.88), Color(0.95, 0.85, 0.25), Color(0.62, 0.45, 0.85), Color(0.85, 0.22, 0.18), Color(0.98, 0.7, 0.8)]
var centre_actuel := Vector2i(999999, 999999)


func installer(p_world: Node, graine: int) -> void:
	world = p_world
	rng.seed = graine + 991
	_decalques_facades()
	_decalques_sol()
	herbe_mesh = _touffe()
	herbe_mat = ShaderMaterial.new()
	herbe_mat.shader = HerbeShader
	fleur_mesh = _fleurs()
	fleur_mat = ShaderMaterial.new()
	fleur_mat.shader = preload("res://shaders/fleur.gdshader")
	_routes_abimees()
	_dechets()
	_regler_qualite()
	Game.graphismes_changes.connect(_regler_qualite)


func _regler_qualite() -> void:
	var q: int = Game.qualite
	rayon_parcelles = [0, 3, 4, 6][q]
	densite = [0, 350, 550, 800][q]
	herbe_mat.set_shader_parameter("distance_max", (rayon_parcelles + 0.5) * PARCELLE)
	fleur_mat.set_shader_parameter("distance_max", (rayon_parcelles + 0.5) * PARCELLE)
	for k in parcelles:
		parcelles[k].queue_free()
	parcelles.clear()
	a_creer.clear()
	centre_actuel = Vector2i(999999, 999999)


# ================================================================ textures de décalques
## Textures générées une fois : tache de saleté, coulures verticales, fissure, flaque de sang, huile.
static func texture(nom: String) -> Texture2D:
	if _tex.has(nom):
		return _tex[nom]
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var bruit := FastNoiseLite.new()
	bruit.seed = hash(nom)
	bruit.frequency = 0.02
	bruit.fractal_octaves = 5
	var r2 := RandomNumberGenerator.new()
	r2.seed = hash(nom)
	var fissure := []
	if nom == "fissure":
		# ligne brisée avec embranchements
		var p := Vector2(20, n / 2.0)
		var dir := Vector2(1, 0)
		while p.x < n - 20:
			var q := p + dir.rotated(r2.randf_range(-0.6, 0.6)) * r2.randf_range(8, 18)
			fissure.append([p, q])
			if r2.randf() < 0.25:
				fissure.append([q, q + Vector2(r2.randf_range(-10, 10), r2.randf_range(-30, 30))])
			p = q
	for y in n:
		for x in n:
			var u := Vector2(x, y) / n * 2.0 - Vector2.ONE
			var b := bruit.get_noise_2d(x, y) * 0.5 + 0.5
			var c := Color(0, 0, 0, 0)
			match nom:
				"salete":
					var a := clampf((1.0 - u.length()) * 1.6, 0.0, 1.0) * smoothstep(0.35, 0.75, b)
					c = Color(0.12, 0.1, 0.08, a * 0.75)
				"coulures":
					# noir en bas, coulures qui descendent, transparent en haut (v = 0 en haut)
					var v := float(y) / n
					var filet := bruit.get_noise_2d(x * 3.0, 0.0) * 0.5 + 0.5
					var a := smoothstep(0.25, 1.0, v + filet * 0.45) * smoothstep(1.0, 0.85, absf(u.x))
					c = Color(0.08, 0.07, 0.06, a * 0.8 * (0.6 + b * 0.4))
				"huile":
					var a := clampf((1.0 - u.length() * 1.1) * 2.0, 0.0, 1.0) * smoothstep(0.3, 0.6, b)
					c = Color(0.02, 0.02, 0.025, a * 0.85)
				"sang":
					var d := u.length() + (b - 0.5) * 0.7
					var a := smoothstep(0.75, 0.55, d)
					# gouttes autour
					var g := bruit.get_noise_2d(x * 4.0, y * 4.0)
					if g > 0.55 and d < 1.0:
						a = maxf(a, 1.0)
					c = Color(0.23, 0.02, 0.02, a * 0.9)
				"nid":
					# nid-de-poule : fond sombre et humide, bord de gravillons clairs, contour irrégulier
					var d := u.length() + (b - 0.5) * 0.5
					var fond := smoothstep(0.62, 0.5, d)
					var bord := smoothstep(0.8, 0.62, d) * (1.0 - fond)
					var grain := bruit.get_noise_2d(x * 6.0, y * 6.0) * 0.5 + 0.5
					c = Color(0.05, 0.05, 0.05, fond * 0.95)
					if bord > 0.0:
						c = Color(0.32 + grain * 0.15, 0.31 + grain * 0.14, 0.29 + grain * 0.12, bord * 0.85)
				"bord":
					# bord de route effrité : arraché côté v = 1, découpe irrégulière, gravillons
					var v := float(y) / n
					var limite := 0.45 + (b - 0.5) * 0.5
					var a := smoothstep(limite, limite + 0.08, v) * smoothstep(1.0, 0.75, absf(u.x))
					var g2 := bruit.get_noise_2d(x * 5.0, y * 5.0) * 0.5 + 0.5
					c = Color(0.2 + g2 * 0.12, 0.18 + g2 * 0.1, 0.14 + g2 * 0.08, a * 0.9)
				"suie":
					# traînée de suie qui monte (v = 0 en haut) : panache noir, plus dense en bas
					var v2 := 1.0 - float(y) / n
					var largeur := 0.35 + v2 * 0.55 + (b - 0.5) * 0.35
					var a := smoothstep(largeur, largeur * 0.55, absf(u.x)) * smoothstep(1.0, 0.25, v2) * (0.55 + b * 0.45)
					c = Color(0.03, 0.025, 0.02, clampf(a, 0.0, 1.0) * 0.92)
				"fissure":
					var dmin := 99.0
					for s in fissure:
						dmin = minf(dmin, Geometry2D.get_closest_point_to_segment(Vector2(x, y), s[0], s[1]).distance_to(Vector2(x, y)))
					var a := smoothstep(2.6, 0.6, dmin)
					c = Color(0.04, 0.04, 0.04, a * 0.9)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[nom] = t
	return t


func _decal(nom: String, pos: Vector3, taille: Vector3, rot_y: float, base := Basis.IDENTITY, fondu := 70.0) -> Decal:
	var d := Decal.new()
	d.texture_albedo = texture(nom)
	d.size = taille
	d.position = pos
	d.basis = base * Basis(Vector3.UP, rot_y)
	d.upper_fade = 0.2
	d.lower_fade = 0.4
	d.distance_fade_enabled = true
	d.distance_fade_begin = fondu
	d.distance_fade_length = 15.0
	d.cull_mask = 1
	add_child(d)
	return d


## Coulures et saleté au pied des façades de chaque bâtiment.
func _decalques_facades() -> void:
	for z in Game.zones:
		var ab: AABB = z.aabb
		if ab.size.x < 3.0 or ab.size.z < 3.0:
			continue
		var y := ab.position.y
		# bâtiment incendié (1 sur 10) : grandes traînées de suie qui montent du sol et des fenêtres
		if rng.randf() < 0.1:
			for i in rng.randi_range(1, 3):
				var cote_s := rng.randi() % 4
				var t_s := rng.randf_range(0.15, 0.85)
				var ps: Vector3
				var ns: Vector3
				match cote_s:
					0:
						ps = Vector3(ab.position.x + ab.size.x * t_s, y, ab.position.z)
						ns = Vector3(0, 0, -1)
					1:
						ps = Vector3(ab.position.x + ab.size.x * t_s, y, ab.end.z)
						ns = Vector3(0, 0, 1)
					2:
						ps = Vector3(ab.position.x, y, ab.position.z + ab.size.z * t_s)
						ns = Vector3(-1, 0, 0)
					_:
						ps = Vector3(ab.end.x, y, ab.position.z + ab.size.z * t_s)
						ns = Vector3(1, 0, 0)
				var hs := minf(ab.size.y, rng.randf_range(4.0, 7.0))
				var bs := Basis(ns.cross(Vector3.UP).normalized(), ns, Vector3.UP)
				_decal("suie", ps + Vector3(0, hs / 2.0 + rng.randf_range(0.0, 1.5), 0), Vector3(rng.randf_range(2.5, 4.5), 0.8, hs), 0.0, bs)
		for cote in 4:
			var long := ab.size.x if cote < 2 else ab.size.z
			var nb := clampi(int(long / 6.0), 1, 4)
			for k in nb:
				if rng.randf() < 0.35:
					continue
				var t := (k + rng.randf_range(0.2, 0.8)) / nb
				var p: Vector3
				var normale: Vector3
				match cote:
					0:
						p = Vector3(ab.position.x + ab.size.x * t, y, ab.position.z)
						normale = Vector3(0, 0, -1)
					1:
						p = Vector3(ab.position.x + ab.size.x * t, y, ab.end.z)
						normale = Vector3(0, 0, 1)
					2:
						p = Vector3(ab.position.x, y, ab.position.z + ab.size.z * t)
						normale = Vector3(-1, 0, 0)
					_:
						p = Vector3(ab.end.x, y, ab.position.z + ab.size.z * t)
						normale = Vector3(1, 0, 0)
				# le décalque projette selon son -Y local : on le couche contre le mur
				var haut := rng.randf_range(1.4, 2.8)
				var base := Basis(normale.cross(Vector3.UP).normalized(), normale, Vector3.UP)
				_decal("coulures", p + Vector3(0, haut / 2.0, 0), Vector3(rng.randf_range(2.0, 4.5), 0.8, haut), 0.0, base)


## Routes abîmées : nids-de-poule, bords effrités, herbe qui pousse dans les fissures et le long des bords.
func _routes_abimees() -> void:
	var touffes: Array = []
	for rt in world.routes:
		var r: Rect2 = rt.r
		var le_long_x: bool = rt.x
		var longueur := r.size.x if le_long_x else r.size.y
		var largeur := r.size.y if le_long_x else r.size.x
		if longueur < 4.0 or largeur < 2.0:
			continue
		var rot := 0.0 if le_long_x else PI / 2.0
		var en_ville := Game.in_city(Vector3(r.get_center().x, 0.0, r.get_center().y))
		# point de la route : t le long (0..1), s en travers (0..1)
		var pt := func(t: float, s: float) -> Vector3:
			var x: float = r.position.x + (t * r.size.x if le_long_x else s * r.size.x)
			var z: float = r.position.y + (s * r.size.y if le_long_x else t * r.size.y)
			return Vector3(x, Game.hauteur(x, z), z)
		# nids-de-poule (un tous les 35 m environ)
		for i in int(longueur / (70.0 if en_ville else 140.0) * rng.randf_range(0.6, 1.4)):
			var p: Vector3 = pt.call(rng.randf(), rng.randf_range(0.15, 0.85))
			var tl := rng.randf_range(0.7, 1.6)
			_decal("nid", p + Vector3(0, 0.25, 0), Vector3(tl, 1.0, tl * rng.randf_range(0.7, 1.0)), rng.randf() * TAU)
		# bords effrités et herbe le long des deux bords
		for cote in [0.0, 1.0]:
			var pas := 1.6
			var t := rng.randf() * pas
			while t < longueur:
				var u := t / longueur
				if en_ville and rng.randf() < 0.025:
					var e: Vector3 = pt.call(u, cote)
					var base := Basis(Vector3.UP, rot + (PI if cote > 0.5 else 0.0))
					_decal("bord", e + Vector3(0, 0.25, 0), Vector3(rng.randf_range(2.0, 4.0), 1.0, 1.2), 0.0, base)
				if rng.randf() < 0.4:
					var s: float = cote + (rng.randf_range(0.02, 0.12) / largeur) * (1.0 if cote < 0.5 else -1.0)
					var g: Vector3 = pt.call(u, s)
					var k := rng.randf_range(0.3, 0.65)
					touffes.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(k, k * rng.randf_range(0.7, 1.2), k)), g + Vector3(0, -0.02, 0)), Color(1.0, 1.0, 0.85, rng.randf())])
				t += pas
		# herbe dans les fissures, au milieu de la chaussée (rare)
		for i in int(longueur / 20.0):
			var g2: Vector3 = pt.call(rng.randf(), rng.randf_range(0.2, 0.8))
			for j in rng.randi_range(2, 4):
				var k2 := rng.randf_range(0.25, 0.45)
				var dec := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
				touffes.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * k2), g2 + dec + Vector3(0, -0.02, 0)), Color(1.1, 1.05, 0.7, rng.randf())])
	_multimesh_par_cases(herbe_mesh, herbe_mat, touffes, 100.0)


## Déchets dans la ville : feuilles mortes, papiers et cartons le long des murs et sur les trottoirs.
func _dechets() -> void:
	var feuilles: Array = []
	var papiers: Array = []
	var cartons: Array = []
	var couleurs_feuilles := [Color(0.55, 0.35, 0.12), Color(0.68, 0.45, 0.15), Color(0.45, 0.3, 0.14), Color(0.62, 0.52, 0.2), Color(0.5, 0.22, 0.1)]
	var pose := func(p: Vector3, taille: Vector3, angle: float) -> Transform3D:
		# à plat, légèrement incliné, tourné au hasard
		var b := Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15)) * Basis.from_scale(taille)
		return Transform3D(b, Vector3(p.x, Game.hauteur(p.x, p.z) + 0.02, p.z))
	for z in Game.zones:
		var ab: AABB = z.aabb
		if ab.size.x < 3.0 or ab.size.z < 3.0 or ab.position.y > 1.0:
			continue
		# le long de chaque mur, à l'extérieur : amas de feuilles et papiers
		for cote in 4:
			var long := ab.size.x if cote < 2 else ab.size.z
			for i in int(long / 3.0):
				if rng.randf() < 0.55:
					continue
				var t := rng.randf()
				var ecart := rng.randf_range(0.15, 0.9)
				var p: Vector3
				match cote:
					0: p = Vector3(ab.position.x + ab.size.x * t, 0, ab.position.z - ecart)
					1: p = Vector3(ab.position.x + ab.size.x * t, 0, ab.end.z + ecart)
					2: p = Vector3(ab.position.x - ecart, 0, ab.position.z + ab.size.z * t)
					_: p = Vector3(ab.end.x + ecart, 0, ab.position.z + ab.size.z * t)
				if not Game.find_zone(p + Vector3.UP).is_empty():
					continue
				for j in rng.randi_range(6, 16):
					var q := p + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
					var tf := rng.randf_range(0.1, 0.16)
					var cf: Color = couleurs_feuilles[rng.randi() % couleurs_feuilles.size()]
					feuilles.append([pose.call(q, Vector3(tf, 1.0, tf * 1.4), rng.randf() * TAU), cf.darkened(rng.randf_range(0.0, 0.25))])
				if rng.randf() < 0.35:
					var g := rng.randf_range(0.55, 0.9)
					papiers.append([pose.call(p + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)), Vector3(0.21, 1.0, 0.29), rng.randf() * TAU), Color(g, g, g * 0.95)])
				if rng.randf() < 0.08:
					cartons.append([pose.call(p, Vector3(rng.randf_range(0.35, 0.6), 1.0, rng.randf_range(0.3, 0.5)), rng.randf() * TAU), Color(0.55, 0.42, 0.28).darkened(rng.randf_range(0.0, 0.3))])
	# papiers épars dans les rues de chaque ville
	for pv in _points_villes(500):
		var p2: Vector3 = pv
		if not Game.find_zone(p2 + Vector3.UP).is_empty():
			continue
		var g3 := rng.randf_range(0.5, 0.92)
		papiers.append([pose.call(p2, Vector3(0.21, 1.0, 0.29) * rng.randf_range(0.7, 1.2), rng.randf() * TAU), Color(g3, g3, g3 * 0.93)])
	var plat := QuadMesh.new()
	plat.size = Vector2(1, 1)
	plat.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.95
	_multimesh_par_cases(plat, mat, feuilles + papiers, 90.0)
	var boite := BoxMesh.new()
	boite.size = Vector3(1, 0.05, 1)
	_multimesh_par_cases(boite, mat, cartons, 110.0)


## Objets nombreux et fixes, regroupés par cases de 48 m (chacune dessinée seulement de près).
func _multimesh_par_cases(mesh: Mesh, mat: Material, objets: Array, distance: float) -> void:
	var cases := {}
	for o in objets:
		var p: Vector3 = (o[0] as Transform3D).origin
		var c := Vector2i(floori(p.x / 48.0), floori(p.z / 48.0))
		if not cases.has(c):
			cases[c] = []
		cases[c].append(o)
	for c in cases:
		var liste: Array = cases[c]
		var centre := Vector3((c.x + 0.5) * 48.0, 0.0, (c.y + 0.5) * 48.0)
		centre.y = (liste[0][0] as Transform3D).origin.y
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = liste.size()
		for i in liste.size():
			var xf: Transform3D = liste[i][0]
			xf.origin -= centre
			mm.set_instance_transform(i, xf)
			mm.set_instance_color(i, liste[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.position = centre
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = distance
		mmi.visibility_range_end_margin = 8.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)


## Taches d'huile, fissures, saleté et un peu de sang sur les routes et trottoirs de la ville.
func _decalques_sol() -> void:
	for pv in _points_villes(420):
		var p: Vector3 = pv
		if not Game.find_zone(p + Vector3.UP).is_empty():
			continue
		var r := rng.randf()
		var nom := "salete"
		var s := rng.randf_range(1.5, 4.0)
		if r < 0.25:
			nom = "huile"
			s = rng.randf_range(0.8, 2.2)
		elif r < 0.55:
			nom = "fissure"
			s = rng.randf_range(1.5, 3.5)
		elif r < 0.62:
			nom = "sang"
			s = rng.randf_range(0.8, 2.0)
		_decal(nom, p + Vector3(0, 0.2, 0), Vector3(s, 1.2, s), rng.randf() * TAU)


# ================================================================ herbe
## Une touffe de 7 brins effilés, courbés, de hauteurs variées (UV.y = 0 au pied, 1 au bout).
func _touffe() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 4321
	for b in 7:
		var ang := r.randf() * TAU
		var dir := Vector3(cos(ang), 0, sin(ang))
		var lat := dir.cross(Vector3.UP)
		var base := Vector3(r.randf_range(-0.12, 0.12), 0, r.randf_range(-0.12, 0.12))
		var h := r.randf_range(0.35, 0.75)
		var larg := r.randf_range(0.025, 0.04)
		var courbe := r.randf_range(0.08, 0.25)
		var segs := 3
		var prec_g := base - lat * larg
		var prec_d := base + lat * larg
		for s in range(1, segs + 1):
			var t := float(s) / segs
			var centre := base + Vector3(0, h * t, 0) + dir * courbe * t * t
			var w := larg * (1.0 - t * 0.95)
			var g := centre - lat * w
			var d := centre + lat * w
			var t0 := float(s - 1) / segs
			for v in [[prec_g, t0], [prec_d, t0], [d, t], [prec_g, t0], [d, t], [g, t]]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(0.0, v[1]))
				st.add_vertex(v[0])
			prec_g = g
			prec_d = d
	return st.commit()


## Petit groupe de 3 fleurs : tige fine (UV.x = 0) et corolle en croix (UV.x = 1) ; UV.y = hauteur relative.
func _fleurs() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 977
	for f in 3:
		var base := Vector3(r.randf_range(-0.1, 0.1), 0, r.randf_range(-0.1, 0.1))
		var h := r.randf_range(0.32, 0.55)
		var ang := r.randf() * TAU
		var lat := Vector3(cos(ang), 0, sin(ang)) * 0.008
		var haut := base + Vector3(r.randf_range(-0.04, 0.04), h, r.randf_range(-0.04, 0.04))
		# tige
		for v in [[base - lat, 0.0], [base + lat, 0.0], [haut + lat, 1.0], [base - lat, 0.0], [haut + lat, 1.0], [haut - lat, 1.0]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.0, v[1]))
			st.add_vertex(v[0])
		# corolle : deux carrés croisés, un peu inclinés
		var t := r.randf_range(0.06, 0.09)
		for k in 2:
			var a2 := ang + k * PI / 2.0
			var u := Vector3(cos(a2), 0.0, sin(a2)) * t
			var w := Vector3(-sin(a2), 0.35, cos(a2)).normalized() * t
			var c := haut + Vector3(0, 0.01, 0)
			for v2 in [c - u - w, c + u - w, c + u + w, c - u - w, c + u + w, c - u + w]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(1.0, 1.0))
				st.add_vertex(v2)
	return st.commit()


func _process(_delta: float) -> void:
	var p = Game.player
	if p == null or rayon_parcelles <= 0:
		return
	var c := Vector2i(floori(p.global_position.x / PARCELLE), floori(p.global_position.z / PARCELLE))
	if c != centre_actuel:
		centre_actuel = c
		# retirer les parcelles trop loin, demander les nouvelles (les plus proches d'abord)
		for k in parcelles.keys():
			if absi(k.x - c.x) > rayon_parcelles + 1 or absi(k.y - c.y) > rayon_parcelles + 1:
				parcelles[k].queue_free()
				parcelles.erase(k)
		a_creer.clear()
		for dz in range(-rayon_parcelles, rayon_parcelles + 1):
			for dx in range(-rayon_parcelles, rayon_parcelles + 1):
				var k := c + Vector2i(dx, dz)
				if not parcelles.has(k):
					a_creer.append(k)
		a_creer.sort_custom(func(a, b): return (a - c).length_squared() < (b - c).length_squared())
	# quelques parcelles par image pour ne pas saccader
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 2500:   # 2,5 ms par image au plus
		if a_creer.is_empty():
			break
		var k: Vector2i = a_creer.pop_front()
		parcelles[k] = _parcelle(k)


## obstacles : routes et constructions proches (préfiltrés par parcelle pour aller vite).
func _herbe_ici(x: float, z: float, obstacles: Array = []) -> bool:
	var p := Vector3(x, 0, z)
	if Game.in_city(p):
		return false
	var rel = Game.relief
	if rel == null or rel.dans_eau(x, z) or rel.dans_eau(x + 1.5, z) or rel.dans_eau(x, z + 1.5):
		return false
	if rel.pente(x, z) > 0.45:
		return false
	for r in obstacles:
		if (r as Rect2).has_point(Vector2(x, z)):
			return false
	for c in Game.sans_herbe:
		if Vector2(x - c[0].x, z - c[0].z).length() < float(c[1]):
			return false
	return true


func _parcelle(k: Vector2i) -> Node3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = herbe_mesh
	var r := RandomNumberGenerator.new()
	r.seed = hash(k) + 17
	var fleurs := []
	var xfs := []
	var x0 := k.x * PARCELLE
	var z0 := k.y * PARCELLE
	# parcelle hors zone d'herbe (ville, route…) : test rapide sur 5 points
	var zone := Rect2(x0 - 1.0, z0 - 1.0, PARCELLE + 2.0, PARCELLE + 2.0)
	var obstacles := []
	for rt in world.routes:
		var rg: Rect2 = (rt.r as Rect2).grow(0.6)
		if rg.intersects(zone):
			obstacles.append(rg)
	for rr in world.reserved:
		if (rr as Rect2).intersects(zone):
			obstacles.append(rr)
	var possible := false
	for e in [[0.5, 0.5], [0.1, 0.1], [0.9, 0.1], [0.1, 0.9], [0.9, 0.9]]:
		if _herbe_ici(x0 + e[0] * PARCELLE, z0 + e[1] * PARCELLE, obstacles):
			possible = true
	if possible:
		for i in densite:
			var x := x0 + r.randf() * PARCELLE
			var z := z0 + r.randf() * PARCELLE
			# touffes regroupées par plaques (bruit simple)
			if sin(x * 0.35) * sin(z * 0.41) + sin(x * 0.11 + z * 0.13) < -0.6:
				continue
			if not _herbe_ici(x, z, obstacles):
				continue
			var y: float = Game.hauteur(x, z)
			var s := r.randf_range(0.7, 1.4)
			var teinte := Color(r.randf_range(0.85, 1.1), r.randf_range(0.9, 1.1), r.randf_range(0.8, 1.0), r.randf())
			# plaques d'herbe sèche (jaunie, plus claire)
			var sec := clampf(sin(x * 0.07 + 1.3) * sin(z * 0.05 - 0.4) * 1.6 + r.randf_range(-0.35, 0.35) - 0.25, 0.0, 1.0)
			if sec > 0.0:
				teinte = Color(lerpf(teinte.r, 1.45, sec), lerpf(teinte.g, 1.12, sec), lerpf(teinte.b, 0.55, sec), teinte.a)
			xfs.append([Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.8, 1.3), s)), Vector3(x, y - 0.03, z)), teinte])
			# fleurs des champs, par petits groupes
			if r.randf() < 0.08:
				var fc: Color = COULEURS_FLEURS[int(absf(sin(x * 0.13) * cos(z * 0.11)) * 97.0) % COULEURS_FLEURS.size()]
				fleurs.append([Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * r.randf_range(0.8, 1.25)), Vector3(x, y - 0.02, z)), Color(fc.r, fc.g, fc.b, r.randf())])
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i][0])
		mm.set_instance_color(i, xfs[i][1])
	mmi.multimesh = mm
	mmi.material_override = herbe_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	if not fleurs.is_empty():
		var mf := MultiMesh.new()
		mf.transform_format = MultiMesh.TRANSFORM_3D
		mf.use_colors = true
		mf.mesh = fleur_mesh
		mf.instance_count = fleurs.size()
		for i in fleurs.size():
			mf.set_instance_transform(i, fleurs[i][0])
			mf.set_instance_color(i, fleurs[i][1])
		var mif := MultiMeshInstance3D.new()
		mif.multimesh = mf
		mif.material_override = fleur_mat
		mif.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.add_child(mif)   # libérée avec la parcelle
	return mmi


## Points au hasard dans les villes : n pour la ville de départ, en proportion de la surface pour les autres.
func _points_villes(n: int) -> Array:
	var res := []
	var villes: Array = Game.villes if not Game.villes.is_empty() else [{"c": Vector3.ZERO, "demi": Game.city_half}]
	for v in villes:
		var d: float = v.demi
		var nv := int(n * (d * d) / (Game.city_half * Game.city_half))
		for i in nv:
			res.append(Vector3(v.c.x + rng.randf_range(-d, d), 0.0, v.c.z + rng.randf_range(-d, d)))
	return res
