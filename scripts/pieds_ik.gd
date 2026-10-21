extends SkeletonModifier3D
## Pieds posés sur le sol réel (pentes, marches d'escalier) après l'animation :
## chaque pied suit la hauteur du sol sous lui (en gardant la levée de la marche),
## le bassin descend pour que la jambe la plus basse atteigne le sol, la cheville s'incline selon la pente.
## Inverse cinématique à deux os (cuisse, mollet) ; les pieds ne sont pas enfants des mollets (squelette Quaternius).

var corps: CharacterBody3D = null
var masque := 1                    # couches du décor (Game.LAYER_WORLD)
var coup_pied := -1.0              # coup de grâce : progression 0..1 du coup de talon du pied droit (-1 = aucun)
var cible_pied := Vector3.ZERO     # point frappé (monde), la tête du zombie à terre

var _os := {}
var _l1 := {}                      # longueur cuisse (hanche -> genou)
var _l2 := {}                      # longueur mollet (genou -> cheville)
var _axe_mollet := {}              # direction genou -> cheville dans le repère de l'os du mollet
var _ecart := {"_l": 0.0, "_r": 0.0}   # décalage vertical lissé de chaque pied (m)
var _normale := {"_l": Vector3.UP, "_r": Vector3.UP}
var _bassin := 0.0
var penche := 0.0                  # se pencher (A / E) : inclinaison du buste en radians (+ = à droite), pieds au sol
var _vertebres: Array[int] = []


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_os["pelvis"] = sk.find_bone("pelvis")
	for n in ["spine_01", "spine_02", "spine_03"]:
		if sk.find_bone(n) >= 0:
			_vertebres.append(sk.find_bone(n))
	for c in ["_l", "_r"]:
		for n in ["thigh", "calf", "foot"]:
			_os[n + c] = sk.find_bone(n + c)
			if _os[n + c] < 0:
				_os.clear()
				return
		var g_t := sk.get_bone_global_rest(_os["thigh" + c])
		var g_c := sk.get_bone_global_rest(_os["calf" + c])
		var g_f := sk.get_bone_global_rest(_os["foot" + c])
		_l1[c] = g_t.origin.distance_to(g_c.origin)
		_l2[c] = g_c.origin.distance_to(g_f.origin)
		_axe_mollet[c] = g_c.basis.inverse() * (g_f.origin - g_c.origin)


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _os.is_empty() or corps == null or _os.pelvis < 0:
		return
	var au_sol := corps.is_on_floor()
	var xf_sk := sk.global_transform
	var inv_sk := xf_sk.affine_inverse()
	var sol_y := corps.global_position.y
	var k := minf(1.0, delta * 14.0)
	var espace := corps.get_world_3d().direct_space_state
	var pieds_monde := {}
	for c in ["_l", "_r"]:
		var f: Vector3 = xf_sk * sk.get_bone_global_pose(_os["foot" + c]).origin
		pieds_monde[c] = f
		var d := 0.0
		var n := Vector3.UP
		if au_sol:
			var q := PhysicsRayQueryParameters3D.create(Vector3(f.x, sol_y + 0.5, f.z), Vector3(f.x, sol_y - 0.6, f.z), masque, [corps.get_rid()])
			var hit := espace.intersect_ray(q)
			if not hit.is_empty():
				d = clampf(hit.position.y - sol_y, -0.45, 0.45)
				n = hit.normal
		_ecart[c] = lerpf(_ecart[c], d, k)
		_normale[c] = (_normale[c] as Vector3).lerp(n, k).normalized()
	_bassin = lerpf(_bassin, minf(minf(_ecart._l, _ecart._r), 0.0), k)
	var talon := coup_pied >= 0.0 and coup_pied <= 1.0
	if absf(penche) > 0.001 and not _vertebres.is_empty():
		# buste penché sur le côté autour de l'axe avant (le bassin et les jambes ne bougent pas)
		var axe := (inv_sk.basis * -corps.global_basis.z).normalized()
		for v in _vertebres:
			var gv := sk.get_bone_global_pose(v)
			sk.set_bone_global_pose(v, Transform3D(Basis(axe, penche / _vertebres.size()) * gv.basis, gv.origin))
	if not talon and absf(_bassin) < 0.002 and absf(_ecart._l) < 0.002 and absf(_ecart._r) < 0.002:
		return
	var haut_sk := (inv_sk.basis * Vector3.UP)   # 1 m vers le haut dans l'espace du squelette (échelle comprise)
	var avant_sk := (inv_sk.basis * -corps.global_basis.z).normalized()
	var cibles := {}
	for c in ["_l", "_r"]:
		cibles[c] = (pieds_monde[c] as Vector3) + Vector3.UP * float(_ecart[c])
	var bassin := _bassin
	if talon:
		# coup de talon : pied levé, écrasé sur la cible, puis reposé (bassin un peu fléchi)
		var hanche: Vector3 = xf_sk * sk.get_bone_global_pose(_os.thigh_r).origin
		var t := cible_pied
		var h := Vector3(t.x - hanche.x, 0.0, t.z - hanche.z)
		if h.length() > 0.6:
			h = h.normalized() * 0.6
		t = Vector3(hanche.x + h.x, maxf(t.y, sol_y) + 0.07, hanche.z + h.z)
		var leve := t.lerp(cibles._r, 0.35) + Vector3.UP * 0.42
		var p := coup_pied
		var pied: Vector3 = cibles._r
		if p < 0.36:
			pied = (cibles._r as Vector3).lerp(leve, smoothstep(0.0, 1.0, p / 0.36))
		elif p < 0.56:
			var q := (p - 0.36) / 0.2
			pied = leve.lerp(t, q * q)
		elif p < 0.75:
			pied = t
		else:
			pied = t.lerp(cibles._r, smoothstep(0.0, 1.0, (p - 0.75) / 0.25))
		cibles._r = pied
		bassin += -0.1 * sin(clampf(p, 0.0, 1.0) * PI)
	var gp := sk.get_bone_global_pose(_os.pelvis)
	gp.origin += haut_sk * bassin
	sk.set_bone_global_pose(_os.pelvis, gp)
	for c in ["_l", "_r"]:
		var n_sol: Vector3 = Vector3.UP if (talon and c == "_r") else _normale[c]
		_jambe(sk, c, inv_sk * (cibles[c] as Vector3), avant_sk, (inv_sk.basis * n_sol).normalized(), haut_sk.normalized())


func _jambe(sk: Skeleton3D, c: String, cible: Vector3, avant: Vector3, normale: Vector3, haut: Vector3) -> void:
	var b_t: int = _os["thigh" + c]
	var b_c: int = _os["calf" + c]
	var b_f: int = _os["foot" + c]
	var g_t := sk.get_bone_global_pose(b_t)
	var g_c := sk.get_bone_global_pose(b_c)
	var g_f := sk.get_bone_global_pose(b_f)
	var l1: float = _l1[c]
	var l2: float = _l2[c]
	var a := g_t.origin
	var v := cible - a
	var d := clampf(v.length(), 0.05, (l1 + l2) * 0.999)
	var dir := v.normalized()
	# genou vers l'avant (là où l'animation le met, poussé un peu en avant)
	var pole := g_c.origin + avant * 0.3
	var vers_pole := pole - a
	var perp := (vers_pole - dir * vers_pole.dot(dir)).normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var genou := a + dir * (l1 * cos_a) + perp * (l1 * sqrt(1.0 - cos_a * cos_a))
	var cheville := a + dir * d
	var n_t := _orienter(g_t.basis, sk.get_bone_rest(b_c).origin, genou - a)
	sk.set_bone_global_pose(b_t, Transform3D(n_t, a))
	var n_c := _orienter(g_c.basis, _axe_mollet[c], cheville - genou)
	sk.set_bone_global_pose(b_c, Transform3D(n_c, genou))
	# pied : même orientation qu'animé, incliné selon la pente du sol
	var incl := Basis(Quaternion(haut, normale)) if haut.dot(normale) < 0.9999 else Basis.IDENTITY
	sk.set_bone_global_pose(b_f, Transform3D(incl * g_f.basis, cheville))


func _orienter(base: Basis, axe_local: Vector3, voulu: Vector3) -> Basis:
	var actuel := (base * axe_local).normalized()
	var v := voulu.normalized()
	if actuel.dot(v) > 0.99999:
		return base
	return Basis(Quaternion(actuel, v)) * base
