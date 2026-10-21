extends Node3D
## Bras et mains du joueur en vue 1re personne.
## Mains réalistes à cinq doigts (paume, trois phalanges par doigt, pouce, ongles) dont les doigts
## se referment sur ce qu'elles tiennent ; bras posés par cinématique inverse (bras + avant-bras).
## Placé comme enfant de la caméra : toutes les positions sont en espace caméra.

const UPPER := 0.34
const FORE := 0.33
const SHOULDER_R := Vector3(0.24, -0.4, 0.1)
const SHOULDER_L := Vector3(-0.3, -0.38, 0.06)
const POLE_R := Vector3(0.7, -1.0, 0.4)
const POLE_L := Vector3(-1.0, -0.8, 0.3)

const PEAU := Color(0.78, 0.58, 0.46)
const ONGLE := Color(0.86, 0.7, 0.64)
const MANCHE := Color(0.24, 0.30, 0.24)
const ECHELLE := 0.85

# Prises mesurées sur les modèles 3D (vues de profil) : poignée (R), garde-main (L, dessous),
# inclinaison de la poignée vers l'arrière (degrés).
# Prises en main : lues dans le modèle de l'arme (métadonnées écrites par outils/godot/normaliser_du.gd) :
# origine = main droite, L = main gauche, incl = inclinaison de la poignée, prise_l = garde / verticale / appui.

# ---------------------------------------------------------------- géométrie de la main (droite)
# Repère de la main : doigts tendus vers -Z, paume vers -Y, pouce du côté -X. Origine = centre de la paume.
# [base de la 1re phalange, longueurs des 3 phalanges, rayon, écart]
const DOIGTS := [
	[Vector3(-0.028, 0.002, -0.043), [0.043, 0.026, 0.021], 0.0093, -0.07],
	[Vector3(-0.009, 0.003, -0.046), [0.047, 0.029, 0.023], 0.0097, 0.0],
	[Vector3(0.010, 0.002, -0.044), [0.044, 0.027, 0.022], 0.0091, 0.06],
	[Vector3(0.027, -0.001, -0.038), [0.034, 0.021, 0.019], 0.0081, 0.13],
]
const POUCE_BASE := Vector3(-0.026, -0.010, 0.014)
const POUCE_DIR := Vector3(-0.68, -0.2, -0.7)
const POUCE_LONG := [0.042, 0.031, 0.025]
# direction du pouce selon la prise (sinon POUCE_DIR) : le long du garde-main, le long de la carcasse…
const POUCE_POSE := {"verticale": Vector3(-0.45, -0.22, -0.86), "garde": Vector3(-0.95, -0.12, -0.28), "poignee": Vector3(-0.45, -0.22, -0.86), "detente": Vector3(-0.45, -0.22, -0.86),
	"appui": Vector3(-0.55, -0.2, -0.8), "chargeur": Vector3(-0.8, -0.2, -0.55)}
const POUCE_RAYON := 0.0115
const POIGNET := Vector3(0.0, 0.003, 0.052)

const TWO_HANDED_MELEE := ["batte", "batte_cloutee", "hache", "pioche"]

# Poses : angles de flexion (degrés) [1re, 2e, 3e phalange] pour index, majeur, annulaire, auriculaire, puis pouce.
const POSES := {
	"ouverte": [[12, 14, 8], [14, 16, 8], [16, 18, 10], [18, 20, 10], [8, 8, 5]],
	"poignee": [[18, 22, 12], [78, 92, 62], [82, 94, 64], [84, 96, 66], [38, 30, 18]],
	"detente": [[48, 68, 38], [78, 92, 62], [82, 94, 64], [84, 96, 66], [38, 30, 18]],
	"garde": [[66, 74, 50], [70, 78, 52], [72, 80, 54], [74, 82, 56], [8, 12, 6]],
	"appui": [[62, 72, 48], [66, 76, 50], [70, 78, 52], [72, 80, 52], [14, 16, 10]],
	"manche": [[82, 96, 68], [86, 98, 70], [88, 100, 70], [90, 100, 72], [48, 42, 30]],
	"poing": [[96, 108, 72], [98, 110, 74], [100, 110, 74], [102, 110, 74], [56, 52, 36]],
	"chargeur": [[48, 54, 38], [54, 58, 40], [58, 62, 42], [62, 66, 44], [28, 26, 18]],
	"verticale": [[70, 84, 58], [76, 90, 62], [80, 92, 64], [82, 94, 66], [38, 30, 18]],
	"pince": [[42, 56, 48], [86, 98, 70], [90, 100, 70], [92, 100, 72], [36, 34, 30]],
}

# Orientation de la main pour chaque prise, dans le repère de l'arme (colonnes : axes X, Y, Z de la main)
# et décalage du centre de la paume par rapport au point de prise.
static func _prise(nom: String, gauche: bool) -> Array:
	match nom:
		"poignee":
			# paume sur le côté droit de la poignée, doigts autour de l'avant (l'inclinaison est ajoutée par arme)
			return [Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)), Vector3(0.024, 0.0, 0.02)]
		"garde":
			return [Basis(Vector3(0, 0, -1), Vector3(0, -1, 0), Vector3(-1, 0, 0)), Vector3(-0.022, -0.026, 0.0)]
		"appui":
			# main d'appui sur le côté gauche, doigts enroulés autour de ceux de la main droite
			return [Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)), Vector3(-0.026, -0.006, 0.006)]
		"manche":
			if gauche:
				return [Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)), Vector3(-0.024, 0.012, 0.0)]
			return [Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)), Vector3(0.024, 0.012, 0.0)]
		"verticale":
			# main gauche sur une poignée verticale : paume sur le côté gauche, doigts autour de l'avant
			return [Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)), Vector3(-0.024, -0.03, 0.012)]
		"culasse":
			# main droite qui saisit le levier d'armement / la culasse (côté droit)
			return [Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)), Vector3(0.03, 0.0, 0.02)]
		"chargeur", "pince":
			return [Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)), Vector3(-0.034, -0.01, 0.0)]
	return [Basis.IDENTITY, Vector3.ZERO]


var parts := {}       # "R"/"L" -> {bras, coude, avant, manchette, poignet, segs: [], ongles: [], paume: [...]}
var mag: MeshInstance3D
var shell: MeshInstance3D
var mat_peau: StandardMaterial3D
var mat_ongle: StandardMaterial3D
var mat_manche: StandardMaterial3D
var temps := 0.0
var geo := {}       # points mesurés sur le modèle de l'arme tenue (fournis par le joueur)
var pompe := 0.0      # 0..1 : réarmement (culasse à verrou) après le tir
var mag_reel: Node3D = null    # copie du vrai chargeur de l'arme (tenue en main pendant le rechargement)
var cart_reel: Node3D = null   # cartouche de l'arme (rechargement une à une)
var echelle := ECHELLE  # taille des mains : celle de l'arme tenue (les armes sont réduites en vue 1re personne)


func _ready() -> void:
	mat_peau = StandardMaterial3D.new()
	mat_peau.albedo_color = PEAU
	mat_peau.roughness = 0.62
	mat_peau.rim_enabled = true
	mat_peau.rim = 0.25
	mat_peau.rim_tint = 0.6
	mat_ongle = StandardMaterial3D.new()
	mat_ongle.albedo_color = ONGLE
	mat_ongle.roughness = 0.35
	mat_manche = StandardMaterial3D.new()
	mat_manche.albedo_color = MANCHE
	mat_manche.roughness = 0.92
	if ResourceLoader.exists("res://textures/tissu_albedo.jpg"):
		mat_manche.albedo_texture = load("res://textures/tissu_albedo.jpg")
	for side in ["R", "L"]:
		var p := {
			"bras": _cyl(0.052, 0.046, mat_manche),
			"coude": _sphere(0.047, mat_manche),
			"avant": _cyl(0.045, 0.037, mat_manche),
			"manchette": _cyl(0.04, 0.04, mat_manche),
			"poignet": _cyl(0.024, 0.021, mat_peau),
			"segs": [],
			"articulations": [],
			"ongles": [],
			"paume": _sphere(0.5, mat_peau),
			"jointures": _capsule(0.0115, 0.062, mat_peau),
			"talon": _capsule(0.0125, 0.056, mat_peau),
			"thenar": _sphere(0.019, mat_peau),
		}
		for f in 4:
			var lg: Array = DOIGTS[f][1]
			var r: float = DOIGTS[f][2]
			for k in 3:
				p.segs.append(_capsule(r * (1.0 - 0.08 * k), lg[k], mat_peau))
			p.ongles.append(_boite(Vector3(r * 1.35, 0.0015, r * 1.4), mat_ongle))
		for k in 3:
			p.segs.append(_capsule(POUCE_RAYON * (1.0 - 0.1 * k), POUCE_LONG[k], mat_peau))
		p.ongles.append(_boite(Vector3(POUCE_RAYON * 1.35, 0.0015, POUCE_RAYON * 1.4), mat_ongle))
		parts[side] = p
	mag = _boite(Vector3(0.03, 0.13, 0.06), _mat(Color(0.12, 0.12, 0.12)))
	shell = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.009
	cm.bottom_radius = 0.009
	cm.height = 0.06
	shell.mesh = cm
	shell.material_override = _mat(Color(0.75, 0.15, 0.1))
	shell.layers = 2
	add_child(shell)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


func _ajoute(mi: MeshInstance3D, m: Material) -> MeshInstance3D:
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 2   # invisible pour la caméra de la lunette
	add_child(mi)
	return mi


func _cyl(r_haut: float, r_bas: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_haut
	cm.bottom_radius = r_bas
	cm.height = 1.0
	cm.radial_segments = 14
	mi.mesh = cm
	return _ajoute(mi, m)


func _capsule(r: float, longueur: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = longueur + 2.0 * r
	cm.radial_segments = 10
	cm.rings = 4
	mi.mesh = cm
	return _ajoute(mi, m)


func _sphere(r: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	return _ajoute(mi, m)


func _boite(size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	return _ajoute(mi, m)


## Base orthonormée dont l'axe Y suit « dir ».
static func _base_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## Place un cylindre (axe Y, hauteur 1) entre a et b.
func _place(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		mi.visible = false
		return
	mi.visible = true
	var bs := _base_y(d)
	var k := echelle / ECHELLE
	mi.transform = Transform3D(Basis(bs.x * k, bs.y * l, bs.z * k), (a + b) * 0.5)


func _ik(s: Vector3, t: Vector3, pole: Vector3) -> Vector3:
	var u := UPPER
	var f := FORE
	var v := t - s
	var d := v.length()
	var n := v / maxf(d, 0.001)
	if d > u + f:
		var k := d / (u + f)
		u *= k
		f *= k
	d = clampf(d, 0.05, u + f - 0.0001)
	var a := (u * u - f * f + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, u * u - a * a))
	var p := (pole - n * pole.dot(n)).normalized()
	return s + n * a + p * h


## Articulations d'un doigt (repère main droite) : renvoie les 4 points de la base au bout.
static func _chaine(base: Vector3, dir0: Vector3, lateral: Vector3, longueurs: Array, angles: Array) -> Array:
	var pts := [base]
	var d := dir0
	var p := base
	for k in 3:
		d = d.rotated(lateral, -deg_to_rad(float(angles[k])))
		p = p + d * float(longueurs[k])
		pts.append(p)
	return pts


## Pose la main : xf = repère de la main en espace caméra (origine = centre de la paume).
func _main(side: String, xf: Transform3D, pose: String, variation: float) -> void:
	var pr: Dictionary = parts[side]
	var miroir := -1.0 if side == "L" else 1.0
	var angles: Array = POSES.get(pose, POSES["ouverte"])
	var sc := echelle
	var b := xf.basis.orthonormalized()
	var o := xf.origin
	var M := func(v: Vector3) -> Vector3: return o + b * (Vector3(v.x * miroir, v.y, v.z) * sc)
	var MD := func(v: Vector3) -> Vector3: return b * Vector3(v.x * miroir, v.y, v.z)
	# paume
	# paume : ellipsoïde légèrement aplati
	pr.paume.transform = Transform3D(Basis(b.x * sc * 0.074, b.y * sc * 0.03, b.z * sc * 0.086), M.call(Vector3(0.0, 0.001, -0.002)))
	pr.jointures.transform = Transform3D(_base_y(MD.call(Vector3(1, 0, 0))).scaled(Vector3(sc, sc, sc)), M.call(Vector3(0.0, 0.0, -0.038)))
	pr.talon.transform = Transform3D(_base_y(MD.call(Vector3(1, 0, -0.15))).scaled(Vector3(sc, sc, sc)), M.call(Vector3(0.004, -0.002, 0.036)))
	pr.thenar.transform = Transform3D(Basis(b.x * sc * 1.1, b.y * sc * 0.75, b.z * sc * 1.5), M.call(Vector3(-0.024, -0.009, 0.014)))
	# doigts
	var i := 0
	for f in 5:
		var pts: Array
		var rayon: float
		var a: Array = angles[f].duplicate()
		var bruit := sin(temps * 1.3 + f * 1.7) * 2.5 * variation
		for k in 3:
			a[k] = float(a[k]) + bruit
		if f < 4:
			var dd: Array = DOIGTS[f]
			var ecart: float = float(dd[3]) * (1.0 - clampf(float(a[0]) / 100.0, 0.0, 0.8))
			var dir0 := Vector3(0, 0, -1).rotated(Vector3.UP, -ecart)
			var lat := Vector3(1, 0, 0).rotated(Vector3.UP, -ecart)
			pts = _chaine(dd[0], dir0, lat, dd[1], a)
			rayon = dd[2]
		else:
			var d0: Vector3 = POUCE_POSE.get(pose, POUCE_DIR).normalized()
			var lat2 := d0.cross(Vector3(0.75, -0.55, 0.0)).normalized()
			pts = _chaine(POUCE_BASE, d0, -lat2, POUCE_LONG, a)
			rayon = POUCE_RAYON
		for k in 3:
			var mi: MeshInstance3D = pr.segs[i]
			var pa: Vector3 = M.call(pts[k])
			var pb: Vector3 = M.call(pts[k + 1])
			mi.transform = Transform3D(_base_y(pb - pa).scaled(Vector3(sc, sc, sc)), (pa + pb) * 0.5)
			i += 1
		# ongle sur le dessus de la dernière phalange
		var dbout: Vector3 = (pts[3] - pts[2]).normalized()
		var dessus := Vector3(0, 1, 0).rotated(Vector3(1, 0, 0), 0.0)
		dessus = (dessus - dbout * dessus.dot(dbout)).normalized()
		var centre_ongle: Vector3 = pts[3] - dbout * rayon * 0.7 + dessus * rayon * 0.62
		var ny: Vector3 = MD.call(dessus)
		var nz: Vector3 = MD.call(dbout)
		var nx := ny.cross(nz).normalized()
		pr.ongles[f].transform = Transform3D(Basis(nx * sc, ny * sc, nz * sc), M.call(centre_ongle))


## Bras complet : épaule → coude (IK) → poignet, puis la main.
func _arm(side: String, shoulder: Vector3, hand_xf: Transform3D, pole: Vector3, show: bool, pose := "ouverte", variation := 1.0) -> void:
	var pr: Dictionary = parts[side]
	for k in pr:
		if pr[k] is Array:
			for m in pr[k]:
				m.visible = show
		else:
			pr[k].visible = show
	if not show:
		return
	_main(side, hand_xf, pose, variation)
	var miroir := -1.0 if side == "L" else 1.0
	var wrist: Vector3 = hand_xf.origin + hand_xf.basis.orthonormalized() * (Vector3(POIGNET.x * miroir, POIGNET.y, POIGNET.z) * echelle)
	var elbow := _ik(shoulder, wrist, pole)
	_place(pr.bras, shoulder, elbow)
	pr.coude.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * echelle / ECHELLE), elbow)
	var fin_manche := elbow.lerp(wrist, 0.9)
	_place(pr.avant, elbow, fin_manche)
	_place(pr.manchette, fin_manche.lerp(elbow, 0.08), fin_manche)
	_place(pr.poignet, fin_manche.lerp(elbow, 0.03), wrist)


## Points de prise en main (repère de l'arme, mètres). Main droite = poignée (origine).
## geo : points mesurés sur le modèle 3D de l'arme (Accessoires.points) quand il est disponible.
static func hand_points(id: String, w: Dictionary, geo := {}) -> Dictionary:
	var t: String = w.get("type", "")
	var length: float = w.get("len", 0.3)
	var res := {"R": Vector3.ZERO, "L": null}
	if t == "gun":
		var longue := length >= 0.4
		if geo.has("L"):
			res.L = geo.L
		elif longue:
			res.L = Vector3(0, -0.035, -length * 0.4)
		else:
			res.L = Vector3(0.0, -0.012, -0.004)     # main d'appui sous la poignée
		res["prise_l"] = str(geo.get("prise_l", "garde" if longue else "appui"))
		res["incl"] = float(geo.get("incl", 18.0))
		# bas du chargeur (la main le saisit là) et levier d'armement
		res["well"] = geo.get("chargeur_bas", Vector3(0, -0.08, -minf(length * 0.08, 0.06)))
		var cu: Vector3 = geo.get("culasse", Vector3(0.0, 0.035, 0.03) if not longue else Vector3(-0.035, 0.03, -0.1))
		res["culasse"] = Vector3(cu.x - 0.025 if longue else cu.x, cu.y, cu.z + (0.03 if not longue else 0.0))
		res["culasse_d"] = Vector3(cu.x + 0.03, cu.y, cu.z)
		res["mag_dec"] = geo.get("chargeur", res.well) - res.well
	elif t == "melee":
		res.R = Vector3(0, 0, 0)
		if id in TWO_HANDED_MELEE:
			res.L = Vector3(0, 0, 0.11)
	elif t == "lancer":
		res.R = Vector3.ZERO
	return res


## Interpolation entre clés [[p, valeur], ...] avec accélération / décélération douces.
static func _cles(cles: Array, p: float):
	if p <= float(cles[0][0]):
		return cles[0][1]
	for i in range(1, cles.size()):
		var p1: float = cles[i][0]
		if p <= p1:
			var p0: float = cles[i - 1][0]
			var t := smoothstep(0.0, 1.0, (p - p0) / maxf(p1 - p0, 0.0001))
			return cles[i - 1][1].lerp(cles[i][1], t)
	return cles[cles.size() - 1][1]


static func arme_a_cartouches(id: String) -> bool:
	return Items.a_cartouches(id)


## Évènements sonores du rechargement : [[progression, nom], ...]
static func evenements(id: String, vide: bool, n_cart: int) -> Array:
	var info := Items.info(id)
	if Items.a_cartouches(id):
		var ev := []
		var cyc := 0.7 / maxf(1, n_cart)
		if info.get("cassant", false):
			ev.append([0.05, "ouvrir"])
		elif info.get("verrou", false) or info.get("levier", false):
			ev.append([0.05, "culasse"])
		for i in n_cart:
			ev.append([0.12 + cyc * (i + 0.5), "cartouche"])
		ev.append([0.9, "culasse"])
		return ev
	if vide:
		return [[0.12, "chargeur_sort"], [0.15, "lacher"], [0.61, "chargeur_in"], [0.79, "culasse"]]
	return [[0.13, "chargeur_sort"], [0.67, "chargeur_in"]]


## Pose de rechargement : {rot, off (arme), L (point de la main gauche, repère arme), mag (chargeur en main), shell}
static func reload_pose(id: String, w: Dictionary, p: float, pts: Dictionary, vide := false, n_cart := 3) -> Dictionary:
	p = clampf(p, 0.0, 1.0)
	var out := {"rot": Vector3.ZERO, "off": Vector3.ZERO, "L": pts.L, "mag": false, "mag_arme": true, "shell": false, "prise": pts.get("prise_l", "garde" if float(w.get("len", 0.3)) >= 0.4 else "appui")}
	var grip_l: Vector3 = pts.L if pts.L != null else Vector3(-0.03, -0.06, 0.02)
	var longue: bool = float(w.get("len", 0.3)) >= 0.4
	if Items.a_cartouches(id):
		var info := Items.info(id)
		var manuelle: bool = info.get("verrou", false) or info.get("levier", false)
		var cassant: bool = info.get("cassant", false)
		var port := Vector3(0.0, -0.01, -0.06)
		if manuelle:
			port = Vector3(pts.culasse_d) + Vector3(-0.03, 0.0, -0.04)
		elif cassant:
			port = Vector3(0.0, 0.03, -0.1)
		var below := port + Vector3(-0.05, -0.2, 0.08)
		var incl := Vector3(0.25, 0.3, -0.6)
		if cassant:
			incl = Vector3(0.55, 0.2, -0.3)   # canons basculés vers le bas pour les ouvrir
		out.rot = _cles([[0.0, Vector3.ZERO], [0.1, incl], [0.82, incl], [0.95, Vector3.ZERO]], p)
		var ob := Vector3(-0.28, 0.12, 0.06)
		out.off = _cles([[0.0, Vector3.ZERO], [0.1, ob], [0.82, ob], [0.95, Vector3.ZERO]], p)
		var cyc := 0.7 / maxf(1, n_cart)
		if p < 0.12:
			out.L = grip_l.lerp(below, smoothstep(0.0, 1.0, p / 0.12))
			out.prise = "pince" if p > 0.06 else out.prise
		elif p < 0.82:
			var q := fmod((p - 0.12) / cyc, 1.0)
			out.L = below.lerp(port, sin(q * PI))
			out.shell = q < 0.55
			out.prise = "pince"
		else:
			var q2 := (p - 0.82) / 0.18
			out.L = below.lerp(grip_l, smoothstep(0.0, 1.0, minf(q2 * 1.6, 1.0)))
		return out
	# ------------------------------------------------ armes à chargeur
	var well: Vector3 = pts.get("well", Vector3(0, -0.08, -0.04))
	var sous := well + Vector3(0.01, -0.13, 0.03)
	var poche := well + Vector3(0.12, -0.45, 0.2)
	var bosse := well + Vector3(0, 0.018, 0)
	# l'arme est ramenée devant soi et inclinée pour voir le puits du chargeur
	var r1 := Vector3(0.3, 0.38, 0.6) if longue else Vector3(0.35, 0.3, 0.45)
	var o1 := Vector3(-0.32, 0.15, 0.1) if longue else Vector3(-0.24, 0.12, 0.05)
	if not vide:
		out.L = _cles([[0.0, grip_l], [0.12, well], [0.2, sous], [0.34, poche], [0.44, poche], [0.58, sous], [0.65, bosse], [0.7, well], [0.88, grip_l]], p)
		out.mag = (p > 0.12 and p < 0.34) or (p > 0.44 and p < 0.7)
		out.mag_arme = not (p > 0.12 and p < 0.7)
		if p > 0.07 and p < 0.76:
			out.prise = "chargeur"
		out.rot = _cles([[0.0, Vector3.ZERO], [0.12, r1], [0.66, r1], [0.69, r1 + Vector3(0.06, 0, 0)], [0.74, r1], [0.92, Vector3.ZERO]], p)
		out.off = _cles([[0.0, Vector3.ZERO], [0.12, o1], [0.66, o1], [0.68, o1 + Vector3(0, 0.014, 0)], [0.72, o1], [0.92, Vector3.ZERO]], p)
		return out
	# rechargement à vide : le chargeur tombe, nouveau chargeur, puis armement
	var culasse: Vector3 = pts.get("culasse", Vector3(0, 0.03, 0.02))
	var tire := culasse + Vector3(0, 0, 0.08)
	var r2 := Vector3(0.15, 0.1, -0.4) if longue else Vector3(0.2, -0.1, -0.35)
	var o2 := Vector3(-0.22, 0.12, 0.06)
	out.L = _cles([[0.0, grip_l], [0.1, well], [0.16, well + Vector3(0, -0.03, 0)], [0.3, poche], [0.38, poche], [0.53, sous], [0.6, bosse], [0.63, well], [0.72, culasse], [0.78, tire], [0.82, culasse], [0.97, grip_l]], p)
	out.mag = p > 0.38 and p < 0.63
	out.mag_arme = p < 0.12 or p >= 0.63
	if p > 0.06 and p < 0.66:
		out.prise = "chargeur"
	elif p >= 0.66 and p < 0.88:
		out.prise = "pince"
	out.rot = _cles([[0.0, Vector3.ZERO], [0.1, r1], [0.6, r1], [0.62, r1 + Vector3(0.06, 0, 0)], [0.7, r2], [0.84, r2], [0.97, Vector3.ZERO]], p)
	out.off = _cles([[0.0, Vector3.ZERO], [0.1, o1], [0.6, o1], [0.61, o1 + Vector3(0, 0.014, 0)], [0.7, o2], [0.79, o2 + Vector3(0, 0, 0.025)], [0.84, o2], [0.97, Vector3.ZERO]], p)
	return out


## Mise à jour à chaque image. weapon_xf : repère de l'arme en espace caméra (null = poings).
## tir : 0..1 (index sur la détente) ; coup_gauche : le coup de poing part de la main gauche.
func update(id: String, w: Dictionary, weapon_xf, reload_p: float, swing: float, vide := false, n_cart := 3, tir := 0.0, coup_gauche := false) -> void:
	temps += get_process_delta_time()
	mag.visible = false
	shell.visible = false
	if mag_reel and is_instance_valid(mag_reel):
		mag_reel.visible = false
	if cart_reel and is_instance_valid(cart_reel):
		cart_reel.visible = false
	if weapon_xf == null:
		echelle = 0.8
		# garde de boxe ; coup de poing (droite ou gauche) avec rotation du poing
		var punch := sin(swing * PI)
		var garde := Vector3(0, sin(temps * 2.0) * 0.004, 0)
		var br := Basis(Vector3(0, 0, 1), deg_to_rad(62)) * Basis(Vector3.RIGHT, 0.25)
		var bl := Basis(Vector3(0, 0, 1), deg_to_rad(-62)) * Basis(Vector3.RIGHT, 0.25)
		var pr_r := Vector3(0.15, -0.17, -0.35) + garde
		var pr_l := Vector3(-0.14, -0.18, -0.32) + garde
		if coup_gauche:
			pr_l += Vector3(0.05, 0.05, -0.24) * punch
			bl = bl.slerp(Basis(Vector3(0, 0, 1), deg_to_rad(-88)), punch)
			pr_r += Vector3(0.01, 0.01, 0.03) * punch
		else:
			pr_r += Vector3(-0.05, 0.05, -0.24) * punch
			br = br.slerp(Basis(Vector3(0, 0, 1), deg_to_rad(88)), punch)
			pr_l += Vector3(-0.01, 0.01, 0.03) * punch
		_arm("R", SHOULDER_R, Transform3D(br, pr_r), POLE_R, true, "poing", 0.0)
		_arm("L", SHOULDER_L, Transform3D(bl, pr_l), POLE_L, true, "poing", 0.0)
		return
	var xf: Transform3D = weapon_xf
	var bw := xf.basis.orthonormalized()
	echelle = clampf(xf.basis.get_scale().x, 0.5, 0.95)
	var pts := hand_points(id, w, geo)
	var info := Items.info(id)
	var is_gun: bool = w.get("type", "") == "gun"
	var short_gun: bool = is_gun and float(w.get("len", 0.3)) < 0.4
	var prise_r := "poignee" if is_gun else "manche"
	var prise_l: String = str(pts.get("prise_l", "appui" if short_gun else "garde")) if is_gun else "manche"
	var lp = pts.L
	if reload_p >= 0.0 and is_gun:
		var pose := reload_pose(id, w, reload_p, pts, vide, n_cart)
		lp = pose.L
		prise_l = pose.get("prise", prise_l)
		if pose.mag and lp != null:
			# le vrai chargeur de l'arme, tenu par le bas
			var m3: Node3D = mag_reel if mag_reel and is_instance_valid(mag_reel) else mag
			m3.visible = true
			if m3 == mag:
				m3.transform = Transform3D(bw, xf * (lp + Vector3(0, 0.06, -0.02)))
			else:
				m3.transform = Transform3D(xf.basis, xf * (Vector3(lp) + Vector3(pts.mag_dec)))
		if pose.shell and lp != null:
			if cart_reel and is_instance_valid(cart_reel):
				cart_reel.visible = true
				cart_reel.transform = Transform3D(xf.basis * Basis(Vector3.RIGHT, -0.5), xf * (lp + Vector3(0, 0.02, -0.01)))
			else:
				shell.visible = true
				shell.transform = Transform3D(bw * Basis(Vector3.RIGHT, PI / 2.0), xf * (lp + Vector3(0, 0.04, 0)))
	# main droite
	var gr := _prise(prise_r, false)
	var incl := Basis(Vector3.RIGHT, -deg_to_rad(float(pts.get("incl", 15.0)))) if is_gun else Basis.IDENTITY
	var hand_r := Transform3D(bw * incl * gr[0], xf * (pts.R + incl * Vector3(gr[1])))
	var pose_r := prise_r
	if is_gun and tir > 0.0:
		pose_r = "detente" if tir > 0.35 else "poignee"
	if is_gun and pompe > 0.0 and info.get("verrou", false) and reload_p < 0.0:
		# réarmement de la culasse à verrou : la main droite saisit le levier, le tire en arrière puis le repousse
		var gc := _prise("culasse", false)
		var cu: Vector3 = pts.culasse_d
		var k := smoothstep(0.0, 0.22, pompe) * (1.0 - smoothstep(0.78, 1.0, pompe))
		var tire := sin(clampf((pompe - 0.22) / 0.56, 0.0, 1.0) * PI) * 0.085
		var cible := Transform3D(bw * gc[0], xf * (cu + Vector3(gc[1]) + Vector3(0, 0.01 * sin(pompe * PI), tire)))
		hand_r = hand_r.interpolate_with(cible, k)
		if k > 0.5:
			pose_r = "pince"
	_arm("R", SHOULDER_R, hand_r, POLE_R, true, pose_r, 1.0)
	# main gauche
	if lp != null:
		var gl := _prise(prise_l, true)
		var il := incl if prise_l == "appui" else (Basis(Vector3.RIGHT, -0.15) if prise_l == "verticale" else Basis.IDENTITY)
		var hand_l := Transform3D(bw * il * gl[0], xf * (Vector3(lp) + il * Vector3(gl[1])))
		_arm("L", SHOULDER_L, hand_l, POLE_L, true, prise_l, 1.0)
	else:
		_arm("L", SHOULDER_L, Transform3D(), POLE_L, false)
