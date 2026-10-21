extends Node3D
## Arc de chasse construit par le code (tenu par la main gauche).
## Repère : X = vers les doigts de la main d'arc, Y = vers l'avant (sens de la flèche), Z = vers le haut (branches).
## La corde passe par l'encoche (repère de l'arc) : au repos juste derrière la poignée, tirée jusqu'à la joue.

const DEMI := 0.62                 # demi-longueur de l'arc (pointe des branches)
const BAND := -0.14                # corde au repos (distance poignée-corde)
const ALLONGE := 0.64              # allonge à pleine tension
const LONGUEUR_FLECHE := 0.72

var corde_h: MeshInstance3D
var corde_b: MeshInstance3D
var fleche: Node3D                 # flèche encochée (visible pendant la tension)
var _pointe_h := Vector3.ZERO
var _pointe_b := Vector3.ZERO


func _ready() -> void:
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color(0.36, 0.22, 0.12)
	bois.roughness = 0.6
	var cuir := StandardMaterial3D.new()
	cuir.albedo_color = Color(0.12, 0.1, 0.09)
	_boite(Vector3.ZERO, Vector3(0.034, 0.042, 0.13), cuir)          # poignée gainée
	# branches : arc de cercle léger, pointes ramenées vers l'archer (recourbées au bout)
	for s in [1.0, -1.0]:
		var prec := _branche(0.0, s)
		for i in range(1, 9):
			var t := i / 8.0
			var pt := _branche(t, s)
			_segment(prec, pt, lerpf(0.03, 0.014, t), lerpf(0.022, 0.012, t), bois)
			prec = pt
		if s > 0.0:
			_pointe_h = prec
		else:
			_pointe_b = prec
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.85, 0.82, 0.72)
	corde_h = _cylindre(0.0028, mc)
	corde_b = _cylindre(0.0028, mc)
	# flèche encochée : pointe vers +Y
	fleche = Node3D.new()
	add_child(fleche)
	var fut := _boite(Vector3(0, LONGUEUR_FLECHE / 2.0, 0), Vector3(0.008, LONGUEUR_FLECHE, 0.008), _mat(Color(0.62, 0.48, 0.3)))
	fut.reparent(fleche, false)
	var pointe := _boite(Vector3(0, LONGUEUR_FLECHE + 0.02, 0), Vector3(0.018, 0.045, 0.006), _mat(Color(0.5, 0.5, 0.52)))
	pointe.reparent(fleche, false)
	for k in 2:
		var pl := _boite(Vector3(0, 0.08, 0), Vector3(0.002 if k == 0 else 0.024, 0.1, 0.024 if k == 0 else 0.002), _mat(Color(0.85, 0.2, 0.15)))
		pl.reparent(fleche, false)
	fleche.visible = false
	maj(0.0, false)


## Point de la branche (t = 0 à la poignée, 1 à la pointe), s = +1 branche du haut, -1 du bas.
func _branche(t: float, s: float) -> Vector3:
	var z := 0.065 + (DEMI - 0.065) * t
	var y := 0.025 - 0.11 * t * t - (0.05 * smoothstep(0.82, 1.0, t))
	return Vector3(0, y, s * z)


## Corde et flèche pour une tension donnée (0 = au repos, 1 = pleine allonge).
func maj(tension: float, avec_fleche: bool, allonge := ALLONGE) -> void:
	var enc := Vector3(0, lerpf(BAND, -allonge, clampf(tension, 0.0, 1.0)), 0)
	_tendre(corde_h, _pointe_h, enc)
	_tendre(corde_b, enc, _pointe_b)
	fleche.visible = avec_fleche
	fleche.position = enc


func _tendre(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := maxf(d.length(), 0.001)
	var y := d / l
	var x := y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).normalized()
	var z := x.cross(y)
	m.transform = Transform3D(Basis(x, y * l, z), (a + b) * 0.5)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _boite(p: Vector3, s: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	add_child(mi)
	return mi


func _segment(a: Vector3, b: Vector3, epais: float, larg: float, m: Material) -> void:
	var mi := _boite((a + b) * 0.5, Vector3(larg, epais, (b - a).length() + 0.004), m)
	var d := (b - a).normalized()
	var x := Vector3.RIGHT
	var y := d.cross(x).normalized()
	mi.basis = Basis(x, y, d)


func _cylindre(r: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 1.0
	cm.radial_segments = 4
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
