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
var centre_actuel := Vector2i(999999, 999999)


func installer(p_world: Node, graine: int) -> void:
	world = p_world
	rng.seed = graine + 991
	_decalques_facades()
	_decalques_sol()
	herbe_mesh = _touffe()
	herbe_mat = ShaderMaterial.new()
	herbe_mat.shader = HerbeShader
	_regler_qualite()
	Game.graphismes_changes.connect(_regler_qualite)


func _regler_qualite() -> void:
	var q: int = Game.qualite
	rayon_parcelles = [0, 3, 4, 6][q]
	densite = [0, 350, 550, 800][q]
	herbe_mat.set_shader_parameter("distance_max", (rayon_parcelles + 0.5) * PARCELLE)
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


## Taches d'huile, fissures, saleté et un peu de sang sur les routes et trottoirs de la ville.
func _decalques_sol() -> void:
	var demi: float = Game.city_half
	var nb := 420
	for k in nb:
		var p := Vector3(rng.randf_range(-demi, demi), 0.0, rng.randf_range(-demi, demi))
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
			xfs.append([Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.8, 1.3), s)), Vector3(x, y - 0.03, z)),
					Color(r.randf_range(0.85, 1.1), r.randf_range(0.9, 1.1), r.randf_range(0.8, 1.0), r.randf())])
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i][0])
		mm.set_instance_color(i, xfs[i][1])
	mmi.multimesh = mm
	mmi.material_override = herbe_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi
