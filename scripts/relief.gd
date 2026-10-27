extends RefCounted
## Relief de la campagne : collines, lacs et rivière sur une grille de hauteurs (un point tous les 4 m).
## Les zones occupées (ville, routes, bâtiments, champs…) restent plates à la hauteur 0 ;
## les collines montent doucement à partir de 6 m de ces zones.

const PAS := 5.0          # pas de la grille du relief (m) : carte de 5 km
const NIVEAU_EAU := -0.9          # surface des lacs et de la rivière

var n := 0                        # nombre de points par côté
var demi := 0.0                   # la grille couvre [-demi, +demi] en x et en z
var h := PackedFloat32Array()     # hauteurs (m)
var rive := PackedFloat32Array()  # 0..1 : proximité de l'eau (berges en terre)
var plat := PackedByteArray()     # 1 = zone occupée (plate)

# rivière : z = centre + a1 sin(x / l1 + p1) + a2 sin(x / l2 + p2)
var riv_centre := 372.0
var riv_p1 := 0.0
var riv_p2 := 0.0
const RIV_A1 := 18.0
const RIV_L1 := 70.0
const RIV_A2 := 8.0
const RIV_L2 := 23.0
const RIV_DEMI_LARGEUR := 6.0
const RIV_PROF := 1.3

var lacs: Array = []              # {c: Vector2, r: float, p: [phases], prof: float}


# ---------------------------------------------------------------- rivière
func riviere_z(x: float) -> float:
	return riv_centre + RIV_A1 * sin(x / RIV_L1 + riv_p1) + RIV_A2 * sin(x / RIV_L2 + riv_p2)


func riviere_pente(x: float) -> float:
	return RIV_A1 / RIV_L1 * cos(x / RIV_L1 + riv_p1) + RIV_A2 / RIV_L2 * cos(x / RIV_L2 + riv_p2)


func dist_riviere(x: float, z: float) -> float:
	var s := riviere_pente(x)
	return absf(z - riviere_z(x)) / sqrt(1.0 + s * s)


# ---------------------------------------------------------------- lacs
## Rayon du lac dans la direction de l'angle a (bord irrégulier).
static func rayon_lac(l: Dictionary, a: float) -> float:
	var p: Array = l.p
	return float(l.r) * (1.0 + 0.18 * sin(3.0 * a + float(p[0])) + 0.09 * sin(5.0 * a + float(p[1])) + 0.05 * sin(8.0 * a + float(p[2])))


# ---------------------------------------------------------------- lecture
func hauteur(x: float, z: float) -> float:
	if n == 0:
		return 0.0
	var fx := (x + demi) / PAS
	var fz := (z + demi) / PAS
	var i := clampi(floori(fx), 0, n - 2)
	var j := clampi(floori(fz), 0, n - 2)
	var u := clampf(fx - i, 0.0, 1.0)
	var v := clampf(fz - j, 0.0, 1.0)
	var a := h[j * n + i]
	var b := h[j * n + i + 1]
	var c := h[(j + 1) * n + i]
	var d := h[(j + 1) * n + i + 1]
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


func dans_eau(x: float, z: float) -> bool:
	return hauteur(x, z) < NIVEAU_EAU - 0.05


## Point dans un lac (pas la rivière) : les lacs gèlent en hiver, la rivière coule toujours.
func dans_lac(x: float, z: float, marge := 0.0) -> bool:
	for l in lacs:
		var c: Vector2 = l.c
		var d := Vector2(x - c.x, z - c.y)
		if d.length() < rayon_lac(l, d.angle()) * 1.15 + marge:
			return true
	return false


## Pente (0 = plat, 1 = vertical) au point donné.
func pente(x: float, z: float) -> float:
	var dx := hauteur(x + 2.0, z) - hauteur(x - 2.0, z)
	var dz := hauteur(x, z + 2.0) - hauteur(x, z - 2.0)
	var nrm := Vector3(-dx, 4.0, -dz).normalized()
	return 1.0 - nrm.y


# ---------------------------------------------------------------- génération
func generer(graine: int, map_half: float, occupe: Array) -> void:
	demi = map_half + 150.0
	n = int(round(2.0 * demi / PAS)) + 1
	var nn := n * n
	h.resize(nn)
	rive.resize(nn)
	plat.resize(nn)
	h.fill(0.0)
	rive.fill(0.0)
	plat.fill(0)
	# 1. zones occupées
	for r in occupe:
		var rr: Rect2 = r
		var i0 := clampi(floori((rr.position.x - 2.0 + demi) / PAS), 0, n - 1)
		var i1 := clampi(ceili((rr.end.x + 2.0 + demi) / PAS), 0, n - 1)
		var j0 := clampi(floori((rr.position.y - 2.0 + demi) / PAS), 0, n - 1)
		var j1 := clampi(ceili((rr.end.y + 2.0 + demi) / PAS), 0, n - 1)
		for j in range(j0, j1 + 1):
			var base := j * n
			for i in range(i0, i1 + 1):
				plat[base + i] = 1
	# 2. distance aux zones occupées (chanfrein en deux passes)
	var dist := PackedFloat32Array()
	dist.resize(nn)
	for k in nn:
		dist[k] = 0.0 if plat[k] == 1 else 1.0e6
	var dg := PAS * 1.4142
	for j in n:
		for i in n:
			var k := j * n + i
			var d := dist[k]
			if d == 0.0:
				continue
			if i > 0:
				d = minf(d, dist[k - 1] + PAS)
			if j > 0:
				d = minf(d, dist[k - n] + PAS)
				if i > 0:
					d = minf(d, dist[k - n - 1] + dg)
				if i < n - 1:
					d = minf(d, dist[k - n + 1] + dg)
			dist[k] = d
	for j in range(n - 1, -1, -1):
		for i in range(n - 1, -1, -1):
			var k := j * n + i
			var d := dist[k]
			if d == 0.0:
				continue
			if i < n - 1:
				d = minf(d, dist[k + 1] + PAS)
			if j < n - 1:
				d = minf(d, dist[k + n] + PAS)
				if i < n - 1:
					d = minf(d, dist[k + n + 1] + dg)
				if i > 0:
					d = minf(d, dist[k + n - 1] + dg)
			dist[k] = d
	# 3. collines
	var bruit := FastNoiseLite.new()
	bruit.seed = graine
	bruit.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	bruit.frequency = 1.0 / 420.0
	bruit.fractal_type = FastNoiseLite.FRACTAL_FBM
	bruit.fractal_octaves = 4
	var bruit2 := FastNoiseLite.new()
	bruit2.seed = graine + 7
	bruit2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	bruit2.frequency = 1.0 / 95.0
	for j in n:
		var z := -demi + j * PAS
		for i in n:
			var k := j * n + i
			if dist[k] == 0.0:
				continue
			var x := -demi + i * PAS
			var masque := smoothstep(6.0, 75.0, dist[k])
			var b := bruit.get_noise_2d(x, z) * 0.5 + 0.5
			var colline := pow(clampf((b - 0.28) / 0.6, 0.0, 1.0), 1.6) * 32.0
			var ondul := (bruit2.get_noise_2d(x, z) * 0.5 + 0.5) * 2.5
			var bord := maxf(absf(x), absf(z))
			var rempart := smoothstep(map_half - 50.0, map_half + 130.0, bord) * 38.0
			h[k] = (colline + ondul + rempart) * masque
	# 4. rivière et lacs creusés
	var zmin := riv_centre - RIV_A1 - RIV_A2 - 20.0
	var zmax := riv_centre + RIV_A1 + RIV_A2 + 20.0
	var j0r := clampi(floori((zmin + demi) / PAS), 0, n - 1)
	var j1r := clampi(ceili((zmax + demi) / PAS), 0, n - 1)
	for j in range(j0r, j1r + 1):
		var z := -demi + j * PAS
		for i in n:
			var x := -demi + i * PAS
			var dn := dist_riviere(x, z) / RIV_DEMI_LARGEUR
			_creuser(j * n + i, dn, RIV_PROF)
	for l in lacs:
		var c: Vector2 = l.c
		var rm: float = float(l.r) * 1.35 + 12.0
		var i0 := clampi(floori((c.x - rm + demi) / PAS), 0, n - 1)
		var i1 := clampi(ceili((c.x + rm + demi) / PAS), 0, n - 1)
		var j0 := clampi(floori((c.y - rm + demi) / PAS), 0, n - 1)
		var j1 := clampi(ceili((c.y + rm + demi) / PAS), 0, n - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var p := Vector2(-demi + i * PAS, -demi + j * PAS) - c
				var dn := p.length() / rayon_lac(l, p.angle())
				_creuser(j * n + i, dn, float(l.prof))


## Creuse le point k selon sa distance normalisée au bord de l'eau (dn = 1 au bord).
func _creuser(k: int, dn: float, prof: float) -> void:
	if dn < 1.0:
		var fond := 0.1 - (absf(NIVEAU_EAU) + 0.1 + prof) * (1.0 - dn * dn)
		h[k] = minf(h[k], fond)
	if dn < 1.6:
		rive[k] = maxf(rive[k], smoothstep(1.6, 0.85, dn))


# ---------------------------------------------------------------- maillage et collision
func normale(i: int, j: int) -> Vector3:
	var il := maxi(i - 1, 0)
	var ir := mini(i + 1, n - 1)
	var jd := maxi(j - 1, 0)
	var ju := mini(j + 1, n - 1)
	var dx := h[j * n + ir] - h[j * n + il]
	var dz := h[ju * n + i] - h[jd * n + i]
	return Vector3(-dx / ((ir - il) * PAS), 1.0, -dz / ((ju - jd) * PAS)).normalized()


## Le sol est maillé en tuiles de TUILE × TUILE cellules (160 m), construites à la demande (chargement par morceaux).
const TUILE := 32


func nb_tuiles() -> int:
	return ceili(float(n - 1) / TUILE)


## Centre (en x, z) de la tuile (ci, cj).
func centre_tuile(ci: int, cj: int) -> Vector3:
	return Vector3(-demi + (ci + 0.5) * TUILE * PAS, 0.0, -demi + (cj + 0.5) * TUILE * PAS)


## Maillage de la tuile (ci, cj) du sol.
func tuile(ci: int, cj: int, materiau: Material) -> MeshInstance3D:
	var i0 := ci * TUILE
	var j0 := cj * TUILE
	var i1 := mini(i0 + TUILE, n - 1)
	var j1 := mini(j0 + TUILE, n - 1)
	var w := i1 - i0 + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var k := j * n + i
			var y := h[k]
			verts.append(Vector3(-demi + i * PAS, y, -demi + j * PAS))
			var nr := normale(i, j)
			norms.append(nr)
			var roche := smoothstep(0.9, 0.7, nr.y)
			var terre := rive[k] * (1.0 - roche)
			var sec := smoothstep(12.0, 30.0, y) * (1.0 - roche)
			cols.append(Color(roche, terre, sec))
	for j in range(j1 - j0):
		for i in range(w - 1):
			var a := j * w + i
			idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, materiau)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	return mi


func construire_collision(parent: Node3D, couche: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = couche
	body.collision_mask = 0
	parent.add_child(body)
	var hm := HeightMapShape3D.new()
	hm.map_width = n
	hm.map_depth = n
	var data := PackedFloat32Array()
	data.resize(n * n)
	for k in n * n:
		data[k] = h[k] / PAS
	hm.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = hm
	cs.scale = Vector3(PAS, PAS, PAS)
	body.add_child(cs)


## Image de la carte : relief ombré, eau en bleu (limitée à la zone jouable).
func image_carte(map_half: float) -> Image:
	var i0 := int(round((-map_half + demi) / PAS))
	var taille := int(round(2.0 * map_half / PAS)) + 1
	var img := Image.create(taille, taille, false, Image.FORMAT_RGB8)
	var lum := Vector3(-0.6, 0.6, -0.5).normalized()
	for j in taille:
		for i in taille:
			var gi := i0 + i
			var gj := i0 + j
			var k := gj * n + gi
			var y := h[k]
			var c: Color
			if y < NIVEAU_EAU:
				c = Color(0.16, 0.3, 0.42).lerp(Color(0.1, 0.2, 0.32), clampf((NIVEAU_EAU - y) / 1.5, 0.0, 1.0))
			else:
				var nr := normale(gi, gj)
				var ombre := clampf(nr.dot(lum) * 1.6, 0.35, 1.25)
				c = Color(0.2, 0.25, 0.15).lerp(Color(0.36, 0.34, 0.24), smoothstep(4.0, 30.0, y))
				c = c * ombre
				c.a = 1.0
			img.set_pixel(i, j, c)
	return img
