extends SkeletonModifier3D
## Corps vivant, calculé après l'animation et avant les pieds (pieds_ik.gd) et les bras (bras_ik.gd) :
##  - hanches tournées vers la direction de la marche, buste gardé face à la visée (marche de côté,
##    à reculons : l'animation est jouée à l'envers) ; sur place, les jambes restent en retard sur
##    le buste puis le rattrapent d'un petit pas de pivot ;
##  - corps penché dans les virages en courant ;
##  - tête (et un peu le cou) tournée vers un point regardé ;
##  - respiration (plus ample et rapide quand on est essoufflé), dos voûté et boiterie quand on est blessé ;
##  - réaction aux coups selon le côté touché (buste tordu et rejeté, tête secouée : ressort amorti).
## Les angles sont donnés dans le repère du monde ; le modèle peut être tourné (avant du squelette = +Z).

var corps: Node3D = null
var pieds: Node = null               # pieds_ik.gd : flexion du bassin (boiterie, pas de pivot)
var hanches_cible := 0.0             # angle des hanches par rapport au buste (rad, + = vers la gauche)
var inclinaison_cible := 0.0         # roulis du corps (rad, + = vers la droite)
var regard := Vector3.INF            # point regardé (monde) ; INF = droit devant
var regard_max := 1.2                # rotation de tête la plus grande (rad)
var souffle := 0.0                   # 0 = calme, 1 = à bout de souffle
var blessure := 0.0                  # 0 = en forme, 1 = gravement blessé
var vitesse := 0.0                   # vitesse au sol (m/s) : rythme de la boiterie
var pivot_actif := true              # jambes en retard sur le buste à l'arrêt

var _hanches := 0.0
var _inclinaison := 0.0
var _retard := 0.0                   # retard des jambes sur le buste (pas de pivot)
var _rattrape := false
var _yaw_avant := INF
var _tete := Vector2.ZERO            # lacet, tangage de la tête (lissés)
var _t := 0.0
var _phase_boite := 0.0
var _coup := Vector3.ZERO            # torsion (lacet), roulis, tangage du buste après un coup
var _coup_v := Vector3.ZERO
var _os := {}
var _racines: Array[int] = []      # os tournés avec les hanches : « Body » (ou le bassin) et les pieds rattachés à la racine


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for n in ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "clavicle_r"]:
		_os[n] = sk.find_bone(n)
	var corps_os := sk.find_bone("Body")
	_racines.append(corps_os if corps_os >= 0 else sk.find_bone("pelvis"))
	for n in ["foot_l", "foot_r"]:
		var b := sk.find_bone(n)
		if b >= 0 and not _descend_de(sk, b, _racines[0]):
			_racines.append(b)
	if _os.pelvis < 0 or _os.spine_01 < 0:
		_os.clear()


## Coup reçu venant de `depuis` (position monde de l'attaquant ou du tireur), force 0..1.
func coup(depuis: Vector3, force := 1.0) -> void:
	if corps == null:
		return
	var d := corps.global_position - depuis      # sens de la poussée
	d.y = 0.0
	if d.length_squared() < 0.0001:
		d = corps.global_basis.z
	d = d.normalized()
	var cote := d.dot(corps.global_basis.x)       # poussé vers sa droite = touché à gauche
	var arriere := d.dot(corps.global_basis.z)    # poussé en arrière = touché de face
	force = clampf(force, 0.2, 1.5)
	_coup_v += Vector3(cote * 11.0, cote * 9.0, arriere * 11.0) * force   # torsion, roulis, rejeté en arrière


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _os.is_empty() or corps == null:
		return
	_t += delta
	var inv := sk.global_transform.affine_inverse().basis
	var haut := (inv * Vector3.UP).normalized()
	var avant := (inv * -corps.global_basis.z).normalized()
	var droite := (inv * corps.global_basis.x).normalized()
	# --- pas de pivot : à l'arrêt, les jambes gardent leur direction puis rattrapent le buste
	var yaw := corps.global_rotation.y
	if _yaw_avant == INF:
		_yaw_avant = yaw
	var dyaw := wrapf(yaw - _yaw_avant, -PI, PI)
	_yaw_avant = yaw
	if pivot_actif and absf(hanches_cible) < 0.01 and vitesse < 0.3:
		_retard = clampf(_retard - dyaw, -1.2, 1.2)
		if absf(_retard) > 0.75:
			_rattrape = true
	else:
		_retard = move_toward(_retard, 0.0, delta * 6.0)
		_rattrape = false
	if _rattrape:
		_retard = move_toward(_retard, 0.0, delta * 5.0)
		if pieds:
			pieds.flexion_image = maxf(pieds.flexion_image, 0.04 * sin(clampf(absf(_retard) / 0.75, 0.0, 1.0) * PI))
		if absf(_retard) < 0.02:
			_rattrape = false
	_hanches = lerp_angle(_hanches, hanches_cible, minf(1.0, delta * 8.0))
	_inclinaison = lerpf(_inclinaison, inclinaison_cible, minf(1.0, delta * 5.0))
	var h := _hanches + _retard
	# --- ressort des coups
	var reste := minf(delta, 0.1)
	while reste > 0.0:
		var dt := minf(reste, 1.0 / 120.0)
		reste -= dt
		_coup_v += (-_coup * 90.0 - _coup_v * 11.0) * dt
		_coup += _coup_v * dt
	# --- bassin : hanches tournées autour du bassin, corps penché dans le virage autour du point au sol.
	# Personnages modulaires : les cuisses sont enfants de « Body » (parent du bassin) et les pieds de
	# « root » : on tourne « Body » (sinon le bassin) et les pieds qui ne le suivent pas.
	if absf(h) > 0.001 or absf(_inclinaison) > 0.001:
		var pivot := sk.get_bone_global_pose(_os.pelvis).origin
		var sol := sk.global_transform.affine_inverse() * corps.global_position
		var rh := Basis(haut, h)
		var ri := Basis(avant, _inclinaison * 0.6)
		for b in _racines:
			var g := sk.get_bone_global_pose(b)
			var o := pivot + rh * (g.origin - pivot)
			o = sol + ri * (o - sol)
			sk.set_bone_global_pose(b, Transform3D(ri * rh * g.basis, o))
	# --- colonne : ramène le buste face à la visée, reste du penché, coups, respiration, blessure
	var resp := sin(_t * TAU * lerpf(0.25, 0.85, souffle))
	var amp := lerpf(0.012, 0.07, souffle)
	var repartition := [0.45, 0.35, 0.2]
	var verts := ["spine_01", "spine_02", "spine_03"]
	for i in 3:
		var b: int = _os[verts[i]]
		if b < 0:
			continue
		var k: float = repartition[i]
		var g := sk.get_bone_global_pose(b)
		var rot := Basis(haut, -h * k + _coup.x * k)
		rot = Basis(avant, _inclinaison * 0.4 * k + _coup.y * k + blessure * 0.12 * k) * rot
		var tangage := _coup.z * k - blessure * 0.28 * k   # + = buste rejeté en arrière
		if i == 2:
			tangage += resp * amp          # la poitrine se soulève
		rot = Basis(droite, tangage) * rot
		sk.set_bone_global_pose(b, Transform3D(rot * g.basis, g.origin))
	# épaules qui montent à l'inspiration quand on est essoufflé
	if souffle > 0.05:
		for c in ["clavicle_l", "clavicle_r"]:
			var b: int = _os[c]
			if b < 0:
				continue
			var g := sk.get_bone_global_pose(b)
			var s := 1.0 if c == "clavicle_l" else -1.0
			sk.set_bone_global_pose(b, Transform3D(Basis(avant, s * maxf(resp, 0.0) * amp * 0.8) * g.basis, g.origin))
	# --- boiterie : le bassin plonge sur la jambe blessée (droite) une foulée sur deux
	if pieds and blessure > 0.05 and vitesse > 0.3:
		_phase_boite += delta * vitesse * 1.15
		pieds.flexion_image = maxf(pieds.flexion_image, blessure * 0.05 * maxf(0.0, sin(_phase_boite * PI)))
	# --- tête : vers le point regardé, sinon droit devant ; secouée par les coups
	var cible := Vector2.ZERO
	if regard != Vector3.INF and _os.Head >= 0:
		var tete_monde: Vector3 = sk.global_transform * sk.get_bone_global_pose(_os.Head).origin
		var v := regard - tete_monde
		var plat := Vector3(v.x, 0.0, v.z)
		if plat.length() > 0.05:
			var av := -corps.global_basis.z
			var lacet := atan2(av.cross(plat.normalized()).y, av.dot(plat.normalized()))
			var tangage := atan2(v.y, plat.length())
			if absf(lacet) < regard_max + 0.6:   # trop derrière : on ne se tord pas le cou
				cible = Vector2(clampf(lacet, -regard_max, regard_max), clampf(tangage, -0.6, 0.7))
	_tete = _tete.lerp(cible, minf(1.0, delta * 7.0))
	var secousse := Vector2(_coup.x * 1.2, _coup.z * 1.5)
	var tete := _tete + secousse
	if tete.length_squared() > 0.00001:
		for e in [["neck_01", 0.4], ["Head", 0.6]]:
			var b: int = _os[e[0]]
			if b < 0:
				continue
			var g := sk.get_bone_global_pose(b)
			var droite_os := (Basis(haut, tete.x * float(e[1])) * droite).normalized()
			var r := Basis(droite_os, tete.y * float(e[1])) * Basis(haut, tete.x * float(e[1]))
			sk.set_bone_global_pose(b, Transform3D(r * g.basis, g.origin))


static func _descend_de(sk: Skeleton3D, b: int, ancetre: int) -> bool:
	var p := sk.get_bone_parent(b)
	while p >= 0:
		if p == ancetre:
			return true
		p = sk.get_bone_parent(p)
	return false
