extends SceneTree
## Normalise les modèles « low-poly » de D_U (Sketchfab, licence CC Attribution) rangés dans
## outils/sources_du/*.glb : armes, accessoires, grenade, cartouches.
##
## Pour chaque arme :
##  - échelle réelle (les modèles D_U sont en décimètres : k = 0.1), canon vers -Z, haut vers +Y ;
##  - les cartouches et les chargeurs de rechange posés à côté de l'arme sont retirés ;
##  - les accessoires montés (lunettes, viseurs, silencieux, laser, poignée) sont retirés
##    (ils deviennent des accessoires séparés) ;
##  - le chargeur engagé devient le nœud « Chargeur » (origine = haut du chargeur, dans le puits) ;
##  - le cache-flammes / frein de bouche devient le nœud « DispositifBouche » (caché quand on visse un silencieux) ;
##  - origine = point de prise de la main droite (poignée).
## Les scènes sont écrites dans res://modeles/armes/<id>.scn (textures dans res://modeles/armes/tex/).
##
## Lancer : godot --headless --path . -s outils/godot/normaliser_du.gd [ids…]
## Repère « A » utilisé pour les réglages (o) : x = axe du canon, bas de l'arme à y = 0, arrière à z = 0.

const S := "res://outils/sources_du/"
const TEX := "res://modeles/armes/tex/"

# --------------------------------------------------------------------------- armes
# src, r (prise main droite, coordonnées du modèle source x/y), l (prise main gauche, idem),
# incl (inclinaison de la poignée, degrés), prise_l (garde / verticale / appui), garder (préfixes de parties à conserver),
# retirer (morceaux de noms de parties à enlever : accessoires montés, doublons), k (échelle, défaut 0.1)
const ARMES := {
	"glock19": {"src": "g19_gen_5_mos.glb", "r": Vector2(-0.62, -0.15), "incl": 18.0, "prise_l": "appui"},
	"mr920": {"src": "shadow_systems_mr920.glb", "r": Vector2(-0.62, -0.15), "incl": 18.0, "prise_l": "appui"},
	"m45a1": {"src": "colt_m45a1.glb", "r": Vector2(-0.79, -0.19), "incl": 18.0, "prise_l": "appui"},
	"desert_eagle": {"src": "desert_eagle_xix.glb", "r": Vector2(-0.85, -0.42), "incl": 15.0, "prise_l": "appui"},
	"mp5k": {"src": "hk_mp5k.glb", "r": Vector2(-1.08, -0.82), "l": Vector2(1.06, -0.6), "incl": 20.0, "prise_l": "verticale"},
	"mp7": {"src": "hk_mp7_a1.glb", "r": Vector2(-0.45, -0.38), "l": Vector2(0.8, -0.2), "incl": 15.0, "prise_l": "garde", "retirer": ["suppressor"]},
	"benelli_m4": {"src": "benelli_m4.glb", "r": Vector2(-1.72, -0.7), "l": Vector2(1.4, -0.38), "incl": 30.0, "prise_l": "garde"},
	"toz34": {"src": "toz-34.glb", "k": 0.0605, "r": Vector2(-2.33, -0.5), "l": Vector2(1.5, -0.2), "incl": 35.0, "prise_l": "garde", "retirer": ["Cube"]},
	"m4a1": {"src": "colt_m4a1.glb", "r": Vector2(-1.82, -0.72), "l": Vector2(1.0, -0.12), "incl": 22.0, "prise_l": "garde"},
	"m5_scw": {"src": "colt_m5_scw.glb", "r": Vector2(-1.82, -0.72), "l": Vector2(1.2, -0.1), "incl": 22.0, "prise_l": "garde"},
	"urgi": {"src": "urg-i_socom.glb", "r": Vector2(-1.82, -0.72), "l": Vector2(1.2, -0.1), "incl": 22.0, "prise_l": "garde", "retirer": ["vortex", "anpeq", "surefire", "magpul rvg"]},
	"lr300": {"src": "z-m_lr-300_ml.glb", "r": Vector2(-1.75, -0.72), "l": Vector2(1.1, -0.07), "incl": 22.0, "prise_l": "garde"},
	"mcx": {"src": "sig_sauer_mcx_legacy.glb", "r": Vector2(-1.75, -0.68), "l": Vector2(1.2, -0.07), "incl": 22.0, "prise_l": "garde"},
	"ak74": {"src": "ak-74.glb", "r": Vector2(-1.0, -0.64), "l": Vector2(2.0, -0.19), "incl": 20.0, "prise_l": "garde"},
	"ak74m": {"src": "ak-74m_zenitco.glb", "r": Vector2(-1.05, -0.68), "l": Vector2(2.0, -0.12), "incl": 20.0, "prise_l": "garde", "retirer": ["vzor1", "rk1 front grip"]},
	"draco": {"src": "mini_draco_ak.glb", "r": Vector2(-1.0, -0.64), "l": Vector2(1.95, -0.19), "incl": 20.0, "prise_l": "garde"},
	"uar10": {"src": "uar-10.glb", "r": Vector2(-1.95, -0.65), "l": Vector2(1.3, -0.08), "incl": 22.0, "prise_l": "garde", "retirer": ["uar10 scope"]},
	"mcx_spear": {"src": "sig_mcx_spear.glb", "r": Vector2(-1.33, -0.7), "l": Vector2(1.6, -0.1), "incl": 22.0, "prise_l": "garde", "retirer": ["eotech", "slx suppressor"]},
	"spear_assaulter": {"src": "sig_mcx_spear_assaulter.glb", "r": Vector2(-1.33, -0.7), "l": Vector2(1.4, -0.1), "incl": 22.0, "prise_l": "garde", "retirer": ["eotech"]},
	"c14": {"src": "c14_timberwolf.glb", "r": Vector2(-3.4, -0.35), "l": Vector2(0.5, 0.2), "incl": 15.0, "prise_l": "garde", "retirer": ["scope"]},
	"l96": {"src": "l96_a1_precision_marksman.glb", "k": 1.0, "r": Vector2(-0.135, -0.05), "l": Vector2(0.25, 0.005), "incl": 12.0, "prise_l": "garde", "retirer": ["hawke"]},
	"gepard": {"src": "gepard_m6_lynx.glb", "r": Vector2(-0.8, -0.45), "l": Vector2(1.2, -0.05), "incl": 15.0, "prise_l": "garde", "retirer": ["hawke"]},
	"mosin": {"src": "mosin_nagant_189130.glb", "r": Vector2(-3.0, -0.2), "l": Vector2(0.6, 0.17), "incl": 35.0, "prise_l": "garde", "retirer": ["clip"]},
	"marlin": {"src": "marlin_1895_gblsbl.glb", "r": Vector2(-1.85, -1.75), "l": Vector2(1.5, -1.42), "incl": 35.0, "prise_l": "garde", "garder": ["gbl", "lever gbl", "bolt gbl", "muzzle gbl", "spring gbl", "safe ? gbl", "trigga gbl", "hammer gbl"]},
	"mg5": {"src": "hk_mg5.glb", "r": Vector2(-1.65, -0.95), "l": Vector2(1.1, -0.6), "incl": 25.0, "prise_l": "garde", "retirer": ["belt"]},
}

# --------------------------------------------------------------------------- accessoires
# parties (morceaux de noms) extraites d'un modèle ; o = point de fixation (repère A de l'accessoire) ;
# fwd = direction source du « devant » (défaut +X)
const ACCESSOIRES := {
	"acc_holosun403": {"src": "collimator_set.glb", "parties": ["holosun 403r"], "o": "bas"},
	"acc_exps3": {"src": "collimator_set.glb", "parties": ["eotech exps3"], "o": "bas"},
	"acc_aimpoint": {"src": "collimator_set.glb", "parties": ["aimpoint comp m4"], "o": "bas"},
	"acc_uh1": {"src": "collimator_set.glb", "parties": ["vortex amg uh-1"], "o": "bas"},
	"acc_holosun510": {"src": "collimator_set.glb", "parties": ["holosun 510c"], "o": "bas"},
	"acc_xps2": {"src": "sig_mcx_spear.glb", "parties": ["eotech xps2"], "o": "bas"},
	"acc_vzor": {"src": "ak-74m_zenitco.glb", "parties": ["vzor1"], "o": "bas"},
	"acc_razor": {"src": "urg-i_socom.glb", "parties": ["vortex"], "o": "bas"},
	"acc_sb_scope": {"src": "c14_timberwolf.glb", "parties": ["scope"], "o": "bas"},
	"acc_hawke": {"src": "gepard_m6_lynx.glb", "parties": ["hawke"], "o": "bas"},
	"acc_uar_scope": {"src": "uar-10.glb", "parties": ["uar10 scope"], "o": "bas"},
	"acc_peq15": {"src": "urg-i_socom.glb", "parties": ["anpeq"], "o": "bas"},
	"acc_rvg": {"src": "urg-i_socom.glb", "parties": ["magpul rvg"], "o": "haut"},
	"acc_rk1": {"src": "ak-74m_zenitco.glb", "parties": ["rk1 front grip"], "o": "haut"},
	"acc_sil_socom": {"src": "urg-i_socom.glb", "parties": ["surefire"], "o": "arriere"},
	"acc_sil_slx": {"src": "sig_mcx_spear.glb", "parties": ["slx suppressor"], "o": "arriere"},
	"acc_sil_mp7": {"src": "hk_mp7_a1.glb", "parties": ["mp7 suppressor"], "o": "arriere"},
	"acc_sil_9mm": {"src": "muzzle_device_set.glb", "parties": ["sil 9mm"], "o": "arriere"},
	"acc_sil_556": {"src": "muzzle_device_set.glb", "parties": ["sil 5_56"], "o": "arriere"},
	"acc_sil_762": {"src": "muzzle_device_set.glb", "parties": ["sil 7_62"], "o": "arriere"},
	"acc_frein_9mm": {"src": "muzzle_device_set.glb", "parties": ["mb 9mm"], "o": "arriere"},
	"acc_frein_556": {"src": "muzzle_device_set.glb", "parties": ["mb 5_56"], "o": "arriere"},
	"acc_frein_762": {"src": "muzzle_device_set.glb", "parties": ["mb 7_62"], "o": "arriere"},
	# grenade et armes blanches
	"rgd5": {"src": "rgd-5.glb", "parties": [""], "o": "centre", "fwd": Vector3(0, 0, -1)},
	"couteau_km2000": {"src": "km2000.glb", "parties": [""], "o": "manche", "fwd": Vector3(-1, 0, 0)},
	# cartouches (icônes des munitions)
	"cart_9mm": {"src": "g19_gen_5_mos.glb", "parties": ["919_5"], "o": "centre", "fwd": Vector3(0, 1, 0)},
	"cart_45": {"src": "colt_m45a1.glb", "parties": ["45acp_0"], "o": "centre"},
	"cart_50ae": {"src": "desert_eagle_xix.glb", "parties": ["50ae_0"], "o": "centre", "fwd": Vector3(0, 1, 0)},
	"cart_46": {"src": "hk_mp7_a1.glb", "parties": ["4_6x30_0"], "o": "centre", "fwd": Vector3(0, 1, 0)},
	"cart_12": {"src": "benelli_m4.glb", "parties": ["1270n1_1"], "o": "centre"},
	"cart_556": {"src": "colt_m4a1.glb", "parties": ["55645_17"], "o": "centre", "fwd": Vector3(0, 1, 0)},
	"cart_545": {"src": "ak-74.glb", "parties": ["54539_10"], "o": "centre", "fwd": Vector3(0, 1, 0)},
	"cart_762x39": {"src": "mini_draco_ak.glb", "parties": ["7_62x39_10"], "o": "centre", "fwd": Vector3(0, 1, 0)},
	"cart_762": {"src": "uar-10.glb", "parties": ["76251_0"], "o": "centre", "fwd": Vector3(0, 1, 0)},
	"cart_762r": {"src": "mosin_nagant_189130.glb", "parties": ["76254_0"], "o": "centre", "fwd": Vector3(0, 1, 0)},
	"cart_338": {"src": "c14_timberwolf.glb", "parties": ["338lm_0"], "o": "centre", "fwd": Vector3(0, 1, 0)},
	"cart_127": {"src": "gepard_m6_lynx.glb", "parties": ["12799_0"], "o": "centre"},
	"cart_4570": {"src": "marlin_1895_gblsbl.glb", "parties": ["11_6x53_0"], "o": "centre", "fwd": Vector3(0, 1, 0)},
}

const MOTS_BOUCHE := ["flash hider", "compensator", "muzzle", "brake"]


func _parties(sc: Node) -> Node:
	var r := sc.find_child("GLTF_SceneRootNode", true, false)
	if r == null:
		r = sc
	while r.get_child_count() == 1 and not (r.get_child(0) is MeshInstance3D):
		r = r.get_child(0)
	return r


func _xf_global(n: Node) -> Transform3D:
	var t := Transform3D()
	var chaine := []
	var c := n
	while c:
		chaine.push_front(c)
		c = c.get_parent()
	for x in chaine:
		if x is Node3D:
			t = t * (x as Node3D).transform
	return t


## Maillages d'une partie : [[MeshInstance3D, transformation globale], …]
func _maillages(p: Node, out: Array) -> Array:
	if p is MeshInstance3D and p.mesh:
		out.append([p, _xf_global(p)])
	for c in p.get_children():
		_maillages(c, out)
	return out


func _aabb(ms: Array, xf := Transform3D()) -> AABB:
	var a = null
	for m in ms:
		var b: AABB = xf * m[1] * (m[0].mesh as Mesh).get_aabb()
		a = b if a == null else a.merge(b)
	return a if a != null else AABB()


func _nom(p: Node) -> String:
	return String(p.name).to_lower()


func _est_cartouche(n: String) -> bool:
	if n.is_empty() or not n[0].is_valid_int():
		return false
	return not ("mag" in n or "suppressor" in n or "box" in n)


func _est_chargeur(n: String) -> bool:
	if "release" in n or "catch" in n or "magrel" in n:
		return false
	return " mag" in n or n.begins_with("mag") or "ammo box" in n


var _mats := {}


## Copie autonome d'un matériau (textures copiées dans modeles/armes/tex).
func _materiau(m: Material) -> Material:
	if m == null:
		return null
	if _mats.has(m):
		return _mats[m]
	var c: Material = m.duplicate()
	if c is BaseMaterial3D:
		for prop in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "ao_texture", "emission_texture"]:
			var t = c.get(prop)
			if t is Texture2D:
				var nom := str(t.resource_path).get_file()
				if nom != "" and ResourceLoader.exists(TEX + nom):
					c.set(prop, load(TEX + nom))
				else:
					push_warning("texture non copiée : %s" % nom)
	_mats[m] = c
	return c


func _copie_maillage(mesh: Mesh) -> Mesh:
	var m: Mesh = mesh.duplicate()
	for s in m.get_surface_count():
		m.surface_set_material(s, _materiau(mesh.surface_get_material(s)))
	return m


func _ajouter(parent: Node3D, owner_: Node, ms: Array, xf: Transform3D, prefixe: String) -> void:
	var i := parent.get_child_count()
	for m in ms:
		var mi := MeshInstance3D.new()
		var nom_partie: String = m[2] if m.size() > 2 else ""
		nom_partie = nom_partie.validate_node_name().replace(" ", "_").replace("&", "_").replace("?", "")
		mi.name = "%s%d_%s" % [prefixe, i, nom_partie] if nom_partie != "" else "%s%d" % [prefixe, i]
		mi.mesh = _copie_maillage(m[0].mesh)
		mi.transform = xf * m[1]
		parent.add_child(mi)
		mi.owner = owner_
		i += 1


## x moyen des sommets à l'extrémité avant (axe du canon) dans le repère xf.
func _x_bouche(ms: Array, xf: Transform3D) -> Vector3:
	var pts := []
	var zmin := INF
	for m in ms:
		for f in (m[0].mesh as Mesh).get_faces():
			var p: Vector3 = xf * m[1] * f
			pts.append(p)
			zmin = minf(zmin, p.z)
	var s := Vector3.ZERO
	var n := 0
	for p in pts:
		if p.z < zmin + 0.01:
			s += p
			n += 1
	return s / maxf(1, n)


func _sauver(racine: Node3D, id: String) -> void:
	var ps := PackedScene.new()
	ps.pack(racine)
	var err := ResourceSaver.save(ps, "res://modeles/armes/%s.scn" % id, ResourceSaver.FLAG_COMPRESS)
	print(id, " -> ", error_string(err))
	racine.free()


func _arme(id: String, c: Dictionary) -> void:
	var sc: Node = load(S + c.src).instantiate()
	root.add_child(sc)
	var k: float = c.get("k", 0.1)
	var garder: Array = c.get("garder", [])
	var retirer: Array = c.get("retirer", [])
	var corps := []
	var culasse := []   # levier d'armement / culasse (main gauche au réarmement)
	var chargeurs := []   # [[nom, maillages]]
	var bouche := []
	for p in _parties(sc).get_children():
		var n := _nom(p)
		if not garder.is_empty():
			var ok := false
			for g in garder:
				if n.begins_with(g):
					ok = true
			if not ok:
				continue
		var sauter := false
		for r in retirer:
			if r.to_lower() in n:
				sauter = true
		if sauter or _est_cartouche(n):
			continue
		var ms := _maillages(p, [])
		if ms.is_empty():
			continue
		for m in ms:
			m.append(n)
		if _est_chargeur(n):
			chargeurs.append([n, ms])
			continue
		var dispositif := false
		for mot in MOTS_BOUCHE:
			if mot in n:
				dispositif = true
		if "charging handle" in n or "lever" in n or (culasse.is_empty() and ("bolt" in n or "slide" in n) and not "release" in n and not "catch" in n and not "stop" in n):
			if "charging handle" in n or "lever" in n:
				culasse = ms.duplicate()
			elif culasse.is_empty():
				culasse = ms.duplicate()
		if dispositif:
			bouche.append_array(ms)
		else:
			corps.append_array(ms)
	# chargeur engagé : celui dont le haut est le plus haut (les autres sont posés à côté)
	var charge := []
	var haut := -INF
	for ch in chargeurs:
		var a := _aabb(ch[1])
		if a.end.y > haut:
			haut = a.end.y
			charge = ch[1]
	# repère : +X -> -Z, échelle k
	var rot := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))
	var tout := corps + bouche + charge
	var a0 := _aabb(tout, Transform3D(rot.scaled(Vector3.ONE * k), Vector3.ZERO))
	var dec := Vector3(0, -a0.position.y, -a0.end.z)
	var xf_a := Transform3D(rot.scaled(Vector3.ONE * k), dec)
	var r2: Vector2 = c.r
	var o: Vector3 = xf_a * Vector3(r2.x, r2.y, 0.0)
	o.x = _x_bouche(corps + bouche, xf_a).x
	var xf := Transform3D(Basis(), -o) * xf_a
	var racine := Node3D.new()
	racine.name = id
	var arme := Node3D.new()
	arme.name = "Arme"
	racine.add_child(arme)
	arme.owner = racine
	_ajouter(arme, racine, corps, xf, "M")
	if not bouche.is_empty():
		var nb := Node3D.new()
		nb.name = "DispositifBouche"
		racine.add_child(nb)
		nb.owner = racine
		_ajouter(nb, racine, bouche, xf, "B")
	if not charge.is_empty():
		var ac := _aabb(charge, xf)
		var nc := Node3D.new()
		nc.name = "Chargeur"
		# origine : haut du chargeur, au centre (point d'insertion dans le puits)
		nc.position = Vector3(ac.get_center().x, ac.end.y, ac.get_center().z)
		racine.add_child(nc)
		nc.owner = racine
		_ajouter(nc, racine, charge, Transform3D(Basis(), -nc.position) * xf, "C")
	# données de prise en main (lues par les bras en vue 1re personne)
	racine.set_meta("incl", float(c.get("incl", 18.0)))
	racine.set_meta("prise_l", str(c.get("prise_l", "garde")))
	if c.has("l"):
		var l2: Vector2 = c.l
		var pl: Vector3 = xf * Vector3(l2.x, l2.y, 0.0)
		pl.x = 0.0
		racine.set_meta("L", pl)
	if not charge.is_empty():
		var ac2 := _aabb(charge, xf)
		racine.set_meta("chargeur_bas", Vector3(0.0, ac2.position.y, ac2.get_center().z))
	if culasse.size() > 0:
		var acu := _aabb(culasse, xf)
		racine.set_meta("culasse", acu.get_center())
	var at := _aabb(corps + bouche + charge, xf)
	print("   %s : taille %s, chargeur %s, bouche %d, A-origine %s" % [c.src, at.size.snapped(Vector3.ONE * 0.001), "oui" if not charge.is_empty() else "non", bouche.size(), o.snapped(Vector3.ONE * 0.001)])
	sc.queue_free()
	_sauver(racine, id)


func _accessoire(id: String, c: Dictionary) -> void:
	var sc: Node = load(S + c.src).instantiate()
	root.add_child(sc)
	var k: float = c.get("k", 0.1)
	var ms := []
	for p in _parties(sc).get_children():
		var n := _nom(p)
		for mot in c.parties:
			if mot == "" or mot.to_lower() in n:
				ms.append_array(_maillages(p, []))
				break
	if ms.is_empty():
		push_error("aucune partie pour " + id)
		return
	var fwd: Vector3 = c.get("fwd", Vector3(1, 0, 0))
	var up := Vector3(0, 1, 0) if absf(fwd.y) < 0.9 else Vector3(1, 0, 0)
	var rot := Basis(fwd.cross(up).normalized(), up, -fwd).inverse()
	var xf0 := Transform3D(rot.scaled(Vector3.ONE * k), Vector3.ZERO)
	var a := _aabb(ms, xf0)
	var o := a.get_center()
	match c.o:
		"bas":
			o.y = a.position.y
		"haut":
			o.y = a.end.y
		"arriere":
			o.z = a.end.z
		"manche":
			o.z = a.end.z - 0.07   # main à 7 cm du pommeau
	var xf := Transform3D(Basis(), -o) * xf0
	var racine := Node3D.new()
	racine.name = id
	_ajouter(racine, racine, ms, xf, "M")
	print("   %s : taille %s" % [id, a.size.snapped(Vector3.ONE * 0.001)])
	sc.queue_free()
	_sauver(racine, id)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://modeles/armes")
	var seuls := OS.get_cmdline_user_args()
	for id in ARMES:
		if seuls.is_empty() or id in seuls:
			_arme(id, ARMES[id])
	for id in ACCESSOIRES:
		if seuls.is_empty() or id in seuls:
			_accessoire(id, ACCESSOIRES[id])
	quit()
