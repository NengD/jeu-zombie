extends SkeletonModifier3D
## Bras du personnage placés par calcul (après l'animation) quand il tient une arme à feu :
## jambes et buste gardent leur animation (marche, course…), les bras tiennent l'arme
##  - au repos : arme contre le torse, canon vers l'avant et un peu vers le bas ;
##  - en visée : crosse à l'épaule, canon vers le point visé ;
## main droite sur la poignée, main gauche sous le garde-main (ou en appui sous la poignée du pistolet).
## Inverse cinématique à deux os (bras, avant-bras) calculée ici, sans dépendance externe.

var arme: Node3D = null            # modèle de l'arme tenue (enfant d'un BoneAttachment3D de la main droite)
var point_main_g = null            # point de la main gauche sur l'arme (repère de l'arme), null = une main
var poids := 0.0                   # 0 = animation seule, 1 = bras entièrement calculés
var visee := 0.0                   # 0 = arme au torse, 1 = en joue
var cible_visee := Vector3.ZERO    # point visé (monde)
var pistolet := false
var corps: Node3D = null           # le personnage (repère : -Z = avant)
var sprint := 0.0                  # 0..1 : arme contre la poitrine pendant le sprint
var main_g_seule := false         # arme de mêlée à deux mains : seule la main gauche est calculée (sur le manche)
var recharge := false              # rechargement en cours (pose donnée par FpsArms.reload_pose)
var recharge_rot := Vector3.ZERO   # inclinaison de l'arme (repère du personnage)
var recharge_off := Vector3.ZERO   # décalage de l'arme (repère du personnage)
var point_l_recharge = null        # point de la main gauche pendant le rechargement (repère de l'arme)
var main_g_tendue := false         # lancer de grenade : bras gauche tendu vers cible_visee
var achevement := -1.0             # coup de grâce à l'arme de mêlée : progression 0..1 (-1 = aucun)
var cible_achev := Vector3.ZERO    # tête du zombie à terre (monde)
var longueur_arme := 0.6           # longueur de l'arme de mêlée (m), pour amener la lame sur la cible
var arc := false                   # arc tenu par la main gauche (l'arme est le modèle de l'arc, scripts/arc.gd)
var arc_vise := 0.0                # 0 = arc baissé, 1 = levé en position de tir
var tension := 0.0                 # 0..1 : main droite de l'encoche jusqu'à la joue
var allonge := 0.64                # distance poignée -> ancre calculée (corde à pleine tension), lue par l'arc
const ARC_ROT_BUSTE := 1.0         # buste tourné de profil en position de tir (rad)

var _os := {}
var _repere_main := {}             # côté -> base « repère de la main » exprimée dans le repère de l'os
var _centre_poing_g := Vector3.ZERO   # centre du poing gauche (mains simples), repère de l'os de la main
var _centre_poing_d := Vector3.ZERO
var _tete := -1
var _vertebres: Array[int] = []       # os du buste penchés vers le point visé


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var poing_g: Node3D = sk.get_node_or_null("MainSimple_l/Poing")
	if poing_g:
		_centre_poing_g = poing_g.position
	var poing_d: Node3D = sk.get_node_or_null("MainSimple_r/Poing")
	if poing_d:
		_centre_poing_d = poing_d.position
	for n in ["head", "Head", "neck_01"]:
		if _tete < 0:
			_tete = sk.find_bone(n)
	for n in ["spine_01", "spine_02", "spine_03"]:
		var b := sk.find_bone(n)
		if b >= 0:
			_vertebres.append(b)
	for cote in ["_l", "_r"]:
		for n in ["upperarm", "lowerarm", "hand"]:
			_os[n + cote] = sk.find_bone(n + cote)
		# repère de la main (vers les doigts, largeur de la paume) au repos, vu depuis l'os
		var h: int = _os["hand" + cote]
		var g_h := sk.get_bone_global_rest(h)
		var x := (sk.get_bone_global_rest(sk.find_bone("middle_01" + cote)).origin - g_h.origin).normalized()
		var lat := sk.get_bone_global_rest(sk.find_bone("index_01" + cote)).origin - sk.get_bone_global_rest(sk.find_bone("pinky_01" + cote)).origin
		var z := (lat - x * lat.dot(x)).normalized()
		_repere_main[cote] = g_h.basis.orthonormalized().inverse() * Basis(x, z.cross(x), z)


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or poids <= 0.001 or arme == null or not is_instance_valid(arme) or corps == null or _os.is_empty():
		return
	var inv_sk := sk.global_transform.affine_inverse()
	# repère du personnage dans l'espace du squelette (x = droite, y = haut, -z = avant)
	var c := inv_sk * corps.global_transform
	var droite := c.basis.x.normalized()
	var haut := c.basis.y.normalized()
	var avant := -c.basis.z.normalized()
	var arme_dans_os := _chaine(arme, sk)
	# lancer de grenade : bras gauche tendu vers la cible (équilibre du geste), le bras droit garde l'animation
	if main_g_tendue:
		var e_g := sk.get_bone_global_pose(_os.upperarm_l).origin
		var dir_t := inv_sk * cible_visee - e_g
		dir_t = (dir_t - haut * dir_t.dot(haut) * 0.7).normalized()
		var lat_t := (droite - dir_t * droite.dot(dir_t)).normalized()   # paume vers le bas, pouce vers l'intérieur
		var base_t: Basis = Basis(dir_t, lat_t.cross(dir_t), lat_t) * (_repere_main._l as Basis).inverse()
		_bras(sk, "_l", Transform3D(base_t, e_g + dir_t * 0.52 - droite * 0.04), e_g - haut * 0.5 - droite * 0.3)
		return
	if arc:
		_arc(sk, inv_sk, droite, haut, avant)
		return
	# coup de grâce avec une arme de mêlée : arme levée puis abattue sur la tête du zombie à terre
	if achevement >= 0.0:
		_achever(sk, inv_sk, droite, haut, avant, arme_dans_os)
		return
	# arme de mêlée à deux mains : le bras droit garde son animation, la main gauche suit le manche
	if main_g_seule:
		_main_g_manche(sk, droite, haut, arme_dans_os)
		return
	# buste penché vers le point visé (haut / bas), réparti sur les vertèbres
	var dir_visee := (inv_sk * cible_visee - sk.get_bone_global_pose(_os.upperarm_r).origin).normalized()
	var tangage := asin(clampf(dir_visee.dot(haut), -1.0, 1.0))
	var k_buste := clampf(visee, 0.0, 1.0) * poids
	if not _vertebres.is_empty() and k_buste > 0.001:
		var angle := clampf(tangage, -0.9, 0.9) * 0.75 * k_buste / _vertebres.size()
		for v in _vertebres:
			var g := sk.get_bone_global_pose(v)
			sk.set_bone_global_pose(v, Transform3D(Basis(droite, angle) * g.basis, g.origin))
	var epaule_d := sk.get_bone_global_pose(_os.upperarm_r).origin
	var epaule_g := sk.get_bone_global_pose(_os.upperarm_l).origin
	var milieu := (epaule_d + epaule_g) * 0.5
	# --- position et orientation voulues pour l'arme (repère du squelette)
	dir_visee = (inv_sk * cible_visee - epaule_d).normalized()
	var w_repos: Transform3D
	var w_joue: Transform3D
	if pistolet:
		var dir_bas := (avant * 0.8 - haut * 0.6).normalized()
		w_repos = Transform3D(_base_canon(dir_bas, haut), milieu + avant * 0.3 - haut * 0.33)
		w_joue = Transform3D(_base_canon(dir_visee, haut), milieu + dir_visee * 0.52 - haut * 0.04)
	else:
		var dir_bas := (avant * 0.9 - haut * 0.28 - droite * 0.22).normalized()
		w_repos = Transform3D(_base_canon(dir_bas, haut), epaule_d + avant * 0.24 - haut * 0.2 - droite * 0.08)
		w_joue = Transform3D(_base_canon(dir_visee, haut), epaule_d + dir_visee * 0.24 + haut * 0.03 - droite * 0.07)
	# sprint : arme ramenée contre la poitrine (fusil en travers, canon vers le haut à gauche ; pistolet bas)
	if sprint > 0.001:
		var w_sprint: Transform3D
		if pistolet:
			w_sprint = Transform3D(_base_canon((avant * 0.45 - haut * 0.9).normalized(), avant), milieu + avant * 0.2 - haut * 0.3 + droite * 0.05)
		else:
			w_sprint = Transform3D(_base_canon((haut * 0.5 + avant * 0.35 - droite * 0.8).normalized(), haut), epaule_d + avant * 0.2 - haut * 0.32 - droite * 0.02)
		w_repos = w_repos.interpolate_with(w_sprint, sprint)
	var w_arme := w_repos.interpolate_with(w_joue, visee)
	# rechargement : arme ramenée devant le torse et inclinée (décalages exprimés dans le repère du personnage)
	if recharge:
		var rc := Basis(droite, haut, -avant)
		w_arme.basis = rc * Basis.from_euler(recharge_rot) * rc.inverse() * w_arme.basis
		w_arme.origin += rc * Vector3(recharge_off.x * 1.3, recharge_off.y * 0.75, recharge_off.z * 0.75)
	# main droite : là où la poignée de l'arme doit être
	var main_d := w_arme * arme_dans_os.affine_inverse()
	_bras(sk, "_r", main_d, epaule_d + droite * 0.35 - haut * 0.45 + avant * 0.05)
	# main gauche : sous le garde-main, paume vers le haut, doigts vers la droite de l'arme
	var pt_g = point_l_recharge if recharge and point_l_recharge != null else point_main_g
	if pt_g != null:
		var p_g: Vector3 = w_arme * Vector3(pt_g)
		var bx := w_arme.basis.orthonormalized()
		var doigts := (bx.x * 0.85 + bx.y * 0.2 - bx.z * 0.35).normalized()   # sous le garde-main, vers sa droite
		var lat := -bx.z
		lat = (lat - doigts * lat.dot(doigts)).normalized()
		var repere := Basis(doigts, lat.cross(doigts), lat)
		var base_main: Basis = repere * (_repere_main._l as Basis).inverse()
		# poing gauche (mains simples) : son centre juste sous le garde-main,
		# ou collé contre le poing droit pour un pistolet (prise à deux mains) ;
		# en rechargement, le poing va exactement au point demandé (chargeur, poche, culasse)
		var centre_voulu := p_g - bx.y * 0.03
		if recharge:
			centre_voulu = p_g
		elif pistolet:
			centre_voulu = w_arme.origin - bx.x * 0.05 - bx.y * 0.035 + bx.z * 0.01
		var poignet := centre_voulu - base_main * _centre_poing_g if _centre_poing_g != Vector3.ZERO else p_g - doigts * 0.075 - bx.y * 0.045
		_bras(sk, "_l", Transform3D(base_main, poignet), epaule_g - droite * 0.4 - haut * 0.45 + avant * 0.05)


## Main gauche sur le manche d'une arme de mêlée tenue par la main droite (même sens que la main droite).
func _main_g_manche(sk: Skeleton3D, droite: Vector3, haut: Vector3, arme_dans_os: Transform3D) -> void:
	if point_main_g == null:
		return
	var g_r := sk.get_bone_global_pose(_os.hand_r)
	var w_m: Transform3D = g_r * arme_dans_os
	var rep_r: Basis = g_r.basis.orthonormalized() * (_repere_main._r as Basis)
	var base_m: Basis = rep_r * (_repere_main._l as Basis).inverse()
	var centre_m: Vector3 = w_m * Vector3(point_main_g)
	var poignet_m := centre_m - base_m * _centre_poing_g
	_bras(sk, "_l", Transform3D(base_m, poignet_m), sk.get_bone_global_pose(_os.upperarm_l).origin - droite * 0.4 - haut * 0.45)


## Coup de grâce (progression `achevement`, impact à 0,58) :
##  - arme à deux mains (main_g_seule) : levée au-dessus de l'épaule puis abattue, debout ;
##  - lame / matraque : levée devant la poitrine puis plantée vers le bas (le corps est accroupi par l'animation).
func _achever(sk: Skeleton3D, inv_sk: Transform3D, droite: Vector3, haut: Vector3, avant: Vector3, arme_dans_os: Transform3D) -> void:
	var p := clampf(achevement, 0.0, 1.0)
	var cible: Vector3 = inv_sk * cible_achev
	# buste penché vers la tête visée (davantage au moment de l'impact)
	var k_b := smoothstep(0.2, 0.58, p) * (1.0 - smoothstep(0.8, 1.0, p)) * poids
	if not _vertebres.is_empty() and k_b > 0.001:
		var d0 := (cible - sk.get_bone_global_pose(_os.upperarm_r).origin).normalized()
		var angle := clampf(asin(clampf(d0.dot(haut), -1.0, 1.0)), -0.9, 0.3) * (0.45 if main_g_seule else 0.7) * k_b / _vertebres.size()
		for v in _vertebres:
			var g := sk.get_bone_global_pose(v)
			sk.set_bone_global_pose(v, Transform3D(Basis(droite, angle) * g.basis, g.origin))
	var e_d := sk.get_bone_global_pose(_os.upperarm_r).origin
	var e_g := sk.get_bone_global_pose(_os.upperarm_l).origin
	var milieu := (e_d + e_g) * 0.5
	var w_leve: Transform3D
	var w_frappe: Transform3D
	if main_g_seule:
		var dir_l := (haut * 0.85 - avant * 0.4).normalized()
		w_leve = Transform3D(_base_plan(dir_l, droite), e_d + haut * 0.12 + avant * 0.12 - droite * 0.12)
		var pivot := milieu + avant * 0.3 - haut * 0.2
		var dir_f := (cible - pivot).normalized()
		w_frappe = Transform3D(_base_plan(dir_f, droite), cible - dir_f * longueur_arme * 0.85)
	else:
		var dir_l := (avant * 0.25 - haut * 0.95).normalized()
		w_leve = Transform3D(_base_plan(dir_l, droite), milieu + avant * 0.35 + droite * 0.05 + haut * 0.02)
		var dir_f := (cible - w_leve.origin).normalized()
		w_frappe = Transform3D(_base_plan(dir_f, droite), cible - dir_f * longueur_arme * 0.75)
	var w: Transform3D
	if p < 0.4:
		w = w_leve
	elif p < 0.58 and main_g_seule:
		# arme à deux mains : passe par l'avant (horizontale à hauteur d'épaule), sinon l'interpolation
		# la plus courte entre « levée en arrière » et « pointe au sol » passerait derrière le dos
		var w_mi := Transform3D(_base_plan(avant, droite), e_d + avant * 0.4 - droite * 0.12 + haut * 0.02)
		var q := (p - 0.4) / 0.18
		q = q * q
		w = w_leve.interpolate_with(w_mi, q * 2.0) if q < 0.5 else w_mi.interpolate_with(w_frappe, q * 2.0 - 1.0)
	elif p < 0.58:
		var q := (p - 0.4) / 0.18
		w = w_leve.interpolate_with(w_frappe, q * q)
	elif p < 0.8:
		w = w_frappe
	else:
		w = w_frappe.interpolate_with(w_leve, smoothstep(0.8, 1.0, p))
	_bras(sk, "_r", w * arme_dans_os.affine_inverse(), e_d + droite * 0.4 - haut * 0.3)
	if main_g_seule:
		_main_g_manche(sk, droite, haut, arme_dans_os)


## Base d'une arme dont l'axe -Z suit dir, son axe X restant du côté de `cote` (plan de frappe vertical).
func _base_plan(dir: Vector3, cote: Vector3) -> Basis:
	var z := -dir.normalized()
	var x := (cote - z * cote.dot(z)).normalized()
	return Basis(x, z.cross(x), z)


## Base d'une arme dont le canon (axe -Z) suit dir.
func _base_canon(dir: Vector3, haut: Vector3) -> Basis:
	var z := -dir.normalized()
	var x := haut.cross(z).normalized()
	return Basis(x, z.cross(x), z)


## Transform de l'arme dans le repère de l'os de la main (chaîne BoneAttachment -> … -> arme).
func _chaine(n: Node3D, sk: Skeleton3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and not cur is BoneAttachment3D and cur != sk:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## Bras (épaule -> coude -> poignet) amené jusqu'à la main voulue, coude orienté vers pole.
func _bras(sk: Skeleton3D, cote: String, main: Transform3D, pole: Vector3) -> void:
	var b_haut: int = _os["upperarm" + cote]
	var b_bas: int = _os["lowerarm" + cote]
	var b_main: int = _os["hand" + cote]
	var g_haut := sk.get_bone_global_pose(b_haut)
	var g_bas := sk.get_bone_global_pose(b_bas)
	var g_main := sk.get_bone_global_pose(b_main)
	var a := g_haut.origin
	var l1 := sk.get_bone_rest(b_bas).origin.length()
	var l2 := sk.get_bone_rest(b_main).origin.length()
	var cible := main.origin
	var v := cible - a
	var d := clampf(v.length(), 0.05, (l1 + l2) * 0.995)
	var dir := v.normalized()
	# coude : dans le plan (épaule, poignet, pole)
	var vers_pole := pole - a
	var perp := (vers_pole - dir * vers_pole.dot(dir)).normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var coude := a + dir * (l1 * cos_a) + perp * (l1 * sqrt(1.0 - cos_a * cos_a))
	var poignet := a + dir * d
	# bras et avant-bras : rotation minimale de leur axe vers la nouvelle direction (torsion conservée)
	var n_haut := _orienter(g_haut.basis, sk.get_bone_rest(b_bas).origin, coude - a)
	var n_bas := _orienter(g_bas.basis, sk.get_bone_rest(b_main).origin, poignet - coude)
	var r_haut := Transform3D(n_haut, a)
	var r_bas := Transform3D(n_bas, coude)
	var r_main := Transform3D(main.basis.orthonormalized() * Basis.from_scale(g_main.basis.get_scale()), poignet)
	sk.set_bone_global_pose(b_haut, g_haut.interpolate_with(r_haut, poids))
	sk.set_bone_global_pose(b_bas, sk.get_bone_global_pose(b_bas).interpolate_with(r_bas, poids))
	sk.set_bone_global_pose(b_main, sk.get_bone_global_pose(b_main).interpolate_with(r_main, poids))


func _orienter(base: Basis, axe_local: Vector3, voulu: Vector3) -> Basis:
	var actuel := (base * axe_local).normalized()
	var v := voulu.normalized()
	if actuel.dot(v) > 0.99999:
		return base
	return Basis(Quaternion(actuel, v)) * base


## Arc : buste tourné de profil (épaule gauche vers la cible, tête ramenée vers la cible), bras gauche tendu,
## poignée sur la ligne ancre -> cible ; main droite sur la corde, tirée jusqu'à l'ancre (joue) selon `tension`.
## Arc baissé : tenu dans la main gauche le long de la jambe, branches vers le haut, corde vers l'extérieur.
func _arc(sk: Skeleton3D, inv_sk: Transform3D, droite: Vector3, haut: Vector3, avant: Vector3) -> void:
	var k_v := clampf(arc_vise, 0.0, 1.0)
	var k_s := smoothstep(0.0, 1.0, k_v)
	var cible := inv_sk * cible_visee
	if not _vertebres.is_empty() and k_v > 0.001:
		var d0 := (cible - sk.get_bone_global_pose(_os.upperarm_r).origin).normalized()
		var tangage := clampf(asin(clampf(d0.dot(haut), -1.0, 1.0)), -0.8, 0.8) * 0.7
		for v in _vertebres:
			var g := sk.get_bone_global_pose(v)
			var b := Basis(haut, ARC_ROT_BUSTE * k_s * poids / _vertebres.size()) * Basis(droite, tangage * k_v * poids / _vertebres.size())
			sk.set_bone_global_pose(v, Transform3D(b * g.basis, g.origin))
		# la tête ne suit pas le buste : elle reste tournée vers la cible
		if _tete >= 0:
			var gt := sk.get_bone_global_pose(_tete)
			sk.set_bone_global_pose(_tete, Transform3D(Basis(haut, -ARC_ROT_BUSTE * 0.85 * k_s * poids) * gt.basis, gt.origin))
	var e_g := sk.get_bone_global_pose(_os.upperarm_l).origin
	var l_bras := sk.get_bone_rest(_os.lowerarm_l).origin.length() + sk.get_bone_rest(_os.hand_l).origin.length()
	# ancre : coin de la bouche / joue droite ; la flèche part de là vers la cible
	var tete := sk.get_bone_global_pose(_tete).origin if _tete >= 0 else e_g + haut * 0.25
	var ancre := tete - haut * 0.05 + droite * 0.03 + avant * 0.07
	var dir := (cible - ancre).normalized()
	# poignée : sur la ligne de visée, à une longueur de bras (presque tendu) de l'épaule gauche
	var r := l_bras * 0.97
	var ae := ancre - e_g
	var b_q := dir.dot(ae)
	var disc := b_q * b_q - (ae.length_squared() - r * r)
	var k := -b_q + sqrt(disc) if disc > 0.0 else maxf(0.3, -b_q)
	k = clampf(k, 0.3, 0.68)
	var z_leve := (haut - dir * haut.dot(dir)).normalized()
	z_leve = z_leve.rotated(dir, -0.14)   # arc un peu incliné (branche du haut vers la droite)
	var leve := Transform3D(Basis(dir.cross(z_leve), dir, z_leve), ancre + dir * k)
	# baissé : poignée près de la hanche gauche, branche du haut un peu vers l'avant, dos de l'arc vers la jambe
	var z_bas := (haut + avant * 0.5 - droite * 0.1).normalized()
	var y_bas := (droite - z_bas * droite.dot(z_bas)).normalized()
	var bas := Transform3D(Basis(y_bas.cross(z_bas), y_bas, z_bas), e_g - haut * 0.5 + avant * 0.1 - droite * 0.07)
	var w_arc := bas.interpolate_with(leve, k_s)
	var base_g: Basis = w_arc.basis.orthonormalized() * (_repere_main._l as Basis).inverse()
	_bras(sk, "_l", Transform3D(base_g, w_arc.origin - base_g * _centre_poing_g), e_g - droite * 0.35 - haut * 0.45 + avant * 0.05)
	if k_v <= 0.001:
		allonge = 0.64
		return
	# repère réel de l'arc (le bras a pu ne pas atteindre la cible) : la main droite va sur l'encoche
	var g_l := sk.get_bone_global_pose(_os.hand_l)
	var reel := Transform3D(g_l.basis.orthonormalized() * (_repere_main._l as Basis), g_l * _centre_poing_g)
	var dir_r := reel.basis.y.normalized()
	allonge = clampf((reel.origin - ancre).dot(dir_r), 0.3, 0.7)
	var enc: Vector3 = reel * Vector3(0, lerpf(-0.14, -allonge, clampf(tension, 0.0, 1.0)), 0)
	var z_r := reel.basis.z.normalized()
	var base_d: Basis = Basis(dir_r, z_r.cross(dir_r), z_r) * (_repere_main._r as Basis).inverse()
	var p_sauve := poids
	poids *= k_v
	_bras(sk, "_r", Transform3D(base_d, enc - base_d * _centre_poing_d), enc + droite * 0.35 - dir_r * 0.25 + haut * 0.02)
	poids = p_sauve
