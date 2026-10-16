extends Node3D
## Bras du joueur en vue 1re personne : les mains tiennent réellement l'arme
## (cinématique inverse à 2 segments : bras + avant-bras), et animation de rechargement.
## Placé comme enfant de la caméra : toutes les positions sont en espace caméra.

const UPPER := 0.34
const FORE := 0.33
const SHOULDER_R := Vector3(0.19, -0.30, 0.04)
const SHOULDER_L := Vector3(-0.17, -0.30, 0.04)
const POLE_R := Vector3(0.7, -1.0, 0.4)
const POLE_L := Vector3(-0.7, -1.0, 0.4)

const SKIN := Color(0.86, 0.66, 0.52)
const SLEEVE := Color(0.32, 0.38, 0.30)
const GLOVE := Color(0.18, 0.16, 0.14)

# Armes tenues à deux mains (main gauche le long du manche)
const HAND_SCALE := 0.85
# Formes de main : [paume, doigts, doigts 2, pouce] = [décalage, taille], puis position du poignet.
# Repère de l'arme : -Z = avant, +Y = haut, +X = droite (miroir pour la main gauche).
const HAND_LAYOUTS := {
	# poignée pistolet (verticale)
	"poignee": [[Vector3(0.026, 0.0, 0.008), Vector3(0.02, 0.08, 0.07)], [Vector3(0.0, -0.002, -0.03), Vector3(0.058, 0.075, 0.02)],
		[Vector3(-0.026, -0.002, -0.012), Vector3(0.016, 0.07, 0.04)], [Vector3(-0.02, 0.045, 0.0), Vector3(0.018, 0.018, 0.055)], Vector3(0.03, -0.01, 0.06)],
	# garde-main (barre horizontale le long de l'arme), main par-dessous
	"garde": [[Vector3(0.0, -0.03, 0.0), Vector3(0.058, 0.02, 0.085)], [Vector3(-0.03, -0.008, 0.0), Vector3(0.018, 0.045, 0.08)],
		[Vector3(-0.024, 0.016, 0.0), Vector3(0.012, 0.012, 0.075)], [Vector3(0.028, -0.008, 0.012), Vector3(0.016, 0.035, 0.05)], Vector3(0.0, -0.06, 0.05)],
	# manche (arme blanche), tenu le long de -Z
	"manche": [[Vector3(0.026, 0.0, 0.0), Vector3(0.02, 0.06, 0.08)], [Vector3(0.0, -0.026, 0.0), Vector3(0.05, 0.02, 0.08)],
		[Vector3(-0.024, -0.006, 0.0), Vector3(0.016, 0.04, 0.075)], [Vector3(0.0, 0.028, 0.02), Vector3(0.022, 0.016, 0.05)], Vector3(0.03, -0.035, 0.035)],
	# poing fermé
	"poing": [[Vector3(0.0, 0.0, 0.0), Vector3(0.07, 0.06, 0.085)], [Vector3(0.0, -0.005, -0.045), Vector3(0.068, 0.05, 0.03)],
		[Vector3(-0.02, -0.03, -0.035), Vector3(0.025, 0.02, 0.03)], [Vector3(-0.038, 0.0, -0.02), Vector3(0.018, 0.04, 0.03)], Vector3(0.0, -0.01, 0.06)],
}

var layouts := {"R": "poignee", "L": "garde"}


func layout_of(side: String) -> String:
	return layouts.get(side, "poignee")


const TWO_HANDED_MELEE := ["batte", "batte_cloutee", "hache", "masse"]
const SHELL_FED := ["fusil_pompe", "fusil_artisanal", "revolver"]

var parts := {}   # "R"/"L" -> {upper, fore, hand, thumb}
var mag: MeshInstance3D
var shell: MeshInstance3D


func _ready() -> void:
	for side in ["R", "L"]:
		parts[side] = {
			"upper": _seg(0.05, SLEEVE),
			"fore": _seg(0.042, SLEEVE),
			"cuff": _seg(0.044, SLEEVE.darkened(0.25)),
			"palm": _box(Vector3.ONE, GLOVE),
			"fing": _box(Vector3.ONE, GLOVE.lightened(0.08)),
			"fing2": _box(Vector3.ONE, GLOVE.lightened(0.08)),
			"thumb": _box(Vector3.ONE, GLOVE),
		}
	mag = _box(Vector3(0.03, 0.13, 0.06), Color(0.12, 0.12, 0.12))
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


func _seg(radius: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.9
	cm.bottom_radius = radius
	cm.height = 1.0
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = _mat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 2   # invisible pour la caméra de la lunette
	add_child(mi)
	return mi


func _box(size: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 2
	add_child(mi)
	return mi


## Place un segment (cylindre d'axe Y) entre a et b.
func _place(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		mi.visible = false
		return
	mi.visible = true
	var y := d / l
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y * l, z), (a + b) * 0.5)


func _ik(s: Vector3, t: Vector3, pole: Vector3) -> Array:
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
	return [s + n * a + p * h]


func _arm(side: String, shoulder: Vector3, hand_xf: Transform3D, pole: Vector3, show: bool) -> void:
	var pr: Dictionary = parts[side]
	for k in pr:
		pr[k].visible = show
	if not show:
		return
	var hand_pos := hand_xf.origin
	var hb := hand_xf.basis.orthonormalized()
	var lay: Array = HAND_LAYOUTS.get(layout_of(side), HAND_LAYOUTS["poignee"])
	var mir := -1.0 if side == "L" else 1.0
	var keys := ["palm", "fing", "fing2", "thumb"]
	for i in 4:
		var off: Vector3 = lay[i][0] * HAND_SCALE
		var size: Vector3 = lay[i][1] * HAND_SCALE
		off.x *= mir
		var mi: MeshInstance3D = pr[keys[i]]
		mi.transform = Transform3D(hb.scaled(size), hand_pos + hb * off)
	var wrist_off: Vector3 = lay[4] * HAND_SCALE
	wrist_off.x *= mir
	var wrist := hand_pos + hb * wrist_off
	var elbow: Vector3 = _ik(shoulder, wrist, pole)[0]
	_place(pr.upper, shoulder, elbow)
	_place(pr.fore, elbow, wrist)
	_place(pr.cuff, wrist.lerp(elbow, 0.12), wrist)


## Points de prise en main (repère de l'arme, mètres). Main droite = poignée (origine).
static func hand_points(id: String, w: Dictionary) -> Dictionary:
	var t: String = w.get("type", "")
	var length: float = w.get("len", 0.3)
	var res := {"R": Vector3(0, -0.035, 0.02), "L": null}
	if t == "gun":
		if length < 0.4:
			res.L = Vector3(-0.03, -0.06, 0.025)          # main d'appui sous la poignée
			res["culasse"] = Vector3(0.0, 0.035, 0.03)    # arrière de la glissière
		else:
			res.L = Vector3(0, -0.035, -length * 0.5)     # garde-main
			res["culasse"] = Vector3(-0.035, 0.03, -0.1)  # levier d'armement
		res["well"] = Vector3(0, -0.08, -minf(length * 0.08, 0.06))
	elif t == "melee":
		res.R = Vector3(0, 0, 0)
		if id in TWO_HANDED_MELEE:
			res.L = Vector3(0, 0, 0.11)
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
	return id in SHELL_FED


## Évènements sonores du rechargement : [[progression, nom], ...]
static func evenements(id: String, vide: bool, n_cart: int) -> Array:
	if id in SHELL_FED:
		var ev := []
		var cyc := 0.7 / maxf(1, n_cart)
		for i in n_cart:
			ev.append([0.12 + cyc * (i + 0.5), "cartouche"])
		if id == "revolver":
			ev.push_front([0.06, "barillet"])
			ev.append([0.88, "barillet"])
		else:
			ev.append([0.9, "pompe"])
		return ev
	if vide:
		return [[0.12, "chargeur_sort"], [0.15, "lacher"], [0.61, "chargeur_in"], [0.79, "culasse"]]
	return [[0.13, "chargeur_sort"], [0.67, "chargeur_in"]]


## Pose de rechargement : {rot, off (arme), L (point de la main gauche, repère arme), mag (chargeur en main), shell}
static func reload_pose(id: String, w: Dictionary, p: float, pts: Dictionary, vide := false, n_cart := 3) -> Dictionary:
	p = clampf(p, 0.0, 1.0)
	var out := {"rot": Vector3.ZERO, "off": Vector3.ZERO, "L": pts.L, "mag": false, "shell": false}
	var grip_l: Vector3 = pts.L if pts.L != null else Vector3(-0.03, -0.06, 0.02)
	var longue: bool = float(w.get("len", 0.3)) >= 0.4
	if id in SHELL_FED:
		var revolver := id == "revolver"
		var port := Vector3(0.0, -0.01, -0.06) if not revolver else Vector3(0.0, 0.02, -0.03)
		var below := port + Vector3(-0.05, -0.2, 0.08)
		var incl := Vector3(0.25, 0.3, -0.6) if not revolver else Vector3(0.35, 0.4, -0.9)
		out.rot = _cles([[0.0, Vector3.ZERO], [0.1, incl], [0.82, incl], [0.95, Vector3.ZERO]], p)
		var ob := Vector3(-0.28, 0.12, 0.06)
		out.off = _cles([[0.0, Vector3.ZERO], [0.1, ob], [0.82, ob], [0.95, Vector3.ZERO]], p)
		var cyc := 0.7 / maxf(1, n_cart)
		if p < 0.12:
			out.L = grip_l.lerp(below, smoothstep(0.0, 1.0, p / 0.12))
		elif p < 0.82:
			var q := fmod((p - 0.12) / cyc, 1.0)
			out.L = below.lerp(port, sin(q * PI))
			out.shell = q < 0.55
		else:
			var q2 := (p - 0.82) / 0.18
			out.L = below.lerp(grip_l, smoothstep(0.0, 1.0, minf(q2 * 1.6, 1.0)))
			if not revolver and q2 > 0.5:
				# pompe : la main tire le garde-main vers l'arrière puis le repousse
				var pq := (q2 - 0.5) / 0.5
				out.L = grip_l + Vector3(0, 0, 0.08 * sin(pq * PI))
				out.off.z += 0.02 * sin(pq * PI)
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
		out.mag = (p > 0.14 and p < 0.34) or (p > 0.44 and p < 0.68)
		out.rot = _cles([[0.0, Vector3.ZERO], [0.12, r1], [0.66, r1], [0.69, r1 + Vector3(0.06, 0, 0)], [0.74, r1], [0.92, Vector3.ZERO]], p)
		out.off = _cles([[0.0, Vector3.ZERO], [0.12, o1], [0.66, o1], [0.68, o1 + Vector3(0, 0.014, 0)], [0.72, o1], [0.92, Vector3.ZERO]], p)
		return out
	# rechargement à vide : le chargeur tombe, nouveau chargeur, puis armement
	var culasse: Vector3 = pts.get("culasse", Vector3(0, 0.03, 0.02))
	var tire := culasse + Vector3(0, 0, 0.08)
	var r2 := Vector3(0.15, 0.1, -0.4) if longue else Vector3(0.2, -0.1, -0.35)
	var o2 := Vector3(-0.22, 0.12, 0.06)
	out.L = _cles([[0.0, grip_l], [0.1, well], [0.16, well + Vector3(0, -0.03, 0)], [0.3, poche], [0.38, poche], [0.53, sous], [0.6, bosse], [0.63, well], [0.72, culasse], [0.78, tire], [0.82, culasse], [0.97, grip_l]], p)
	out.mag = p > 0.38 and p < 0.62
	out.rot = _cles([[0.0, Vector3.ZERO], [0.1, r1], [0.6, r1], [0.62, r1 + Vector3(0.06, 0, 0)], [0.7, r2], [0.84, r2], [0.97, Vector3.ZERO]], p)
	out.off = _cles([[0.0, Vector3.ZERO], [0.1, o1], [0.6, o1], [0.61, o1 + Vector3(0, 0.014, 0)], [0.7, o2], [0.79, o2 + Vector3(0, 0, 0.025)], [0.84, o2], [0.97, Vector3.ZERO]], p)
	return out


## Mise à jour à chaque image. weapon_xf : repère de l'arme en espace caméra (null = poings).
func update(id: String, w: Dictionary, weapon_xf, reload_p: float, swing: float, vide := false, n_cart := 3) -> void:
	mag.visible = false
	shell.visible = false
	if weapon_xf == null:
		# poings levés, coup de poing avec la droite
		var punch := sin(swing * PI)
		layouts = {"R": "poing", "L": "poing"}
		var hr := Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0.16, -0.17 + punch * 0.05, -0.36 - punch * 0.22))
		var hl := Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(-0.15, -0.19, -0.33))
		_arm("R", SHOULDER_R, hr, POLE_R, true)
		_arm("L", SHOULDER_L, hl, POLE_L, true)
		return
	var xf: Transform3D = weapon_xf
	var pts := hand_points(id, w)
	var is_gun: bool = w.get("type", "") == "gun"
	var short_gun: bool = is_gun and float(w.get("len", 0.3)) < 0.4
	layouts = {"R": "poignee" if is_gun else "manche", "L": ("poignee" if short_gun else "garde") if is_gun else "manche"}
	var lp = pts.L
	if reload_p >= 0.0 and w.get("type", "") == "gun":
		var pose := reload_pose(id, w, reload_p, pts, vide, n_cart)
		lp = pose.L
		if pose.mag and lp != null:
			mag.visible = true
			mag.transform = Transform3D(xf.basis.orthonormalized(), xf * (lp + Vector3(0, 0.06, -0.02)))
		if pose.shell and lp != null:
			shell.visible = true
			shell.transform = Transform3D(xf.basis.orthonormalized() * Basis(Vector3.RIGHT, PI / 2.0), xf * (lp + Vector3(0, 0.04, 0)))
	var basis_r := xf.basis
	var hand_r := Transform3D(basis_r, xf * pts.R)
	_arm("R", SHOULDER_R, hand_r, POLE_R, true)
	if lp != null:
		var hand_l := Transform3D(basis_r * Basis(Vector3.FORWARD, 0.4), xf * lp)
		_arm("L", SHOULDER_L, hand_l, POLE_L, true)
	else:
		_arm("L", SHOULDER_L, Transform3D(), POLE_L, false)
