class_name Accessoires
extends RefCounted
## Accessoires d'armes : données, compatibilité, effets sur les statistiques
## et modèles 3D (modèles D_U, posés sur l'arme aux bons endroits, calculés à partir de sa géométrie).

## Emplacements, dans l'ordre d'affichage.
const EMPLACEMENTS := ["viseur", "bouche", "chargeur", "rail", "poignee"]
const NOMS_EMPLACEMENTS := {"viseur": "Viseur", "bouche": "Bouche du canon", "chargeur": "Chargeur",
		"rail": "Rail du dessus (laser-lampe)", "poignee": "Poignée avant"}

const POINTS_ROUGES := ["point_rouge", "viseur_reflex", "viseur_aimpoint", "viseur_holo", "viseur_xps2", "viseur_uh1"]
const LUNETTES := ["lunette", "lunette_uar", "lunette_hawke", "lunette_sb"]
const SILENCIEUX := ["silencieux", "silencieux_socom", "silencieux_9mm", "silencieux_mp7", "silencieux_762", "silencieux_slx"]

## Modèle 3D de chaque accessoire (modeles/armes/<modèle>.scn).
const MODELES := {
	"point_rouge": "acc_holosun403", "viseur_reflex": "acc_holosun510", "viseur_aimpoint": "acc_aimpoint",
	"viseur_holo": "acc_exps3", "viseur_xps2": "acc_xps2", "viseur_uh1": "acc_uh1", "viseur_pk": "acc_vzor",
	"lunette": "acc_razor", "lunette_uar": "acc_uar_scope", "lunette_hawke": "acc_hawke", "lunette_sb": "acc_sb_scope",
	"silencieux": "acc_sil_556", "silencieux_socom": "acc_sil_socom", "silencieux_9mm": "acc_sil_9mm",
	"silencieux_mp7": "acc_sil_mp7", "silencieux_762": "acc_sil_762", "silencieux_slx": "acc_sil_slx",
	"frein_9mm": "acc_frein_9mm", "frein_556": "acc_frein_556", "frein_762": "acc_frein_762",
	"laser": "acc_peq15", "poignee": "acc_rvg", "poignee_rk1": "acc_rk1",
}

## Effets : multiplicateurs (dispersion en visée / à la hanche / générale, bruit, dégâts, recul, capacité,
## temps de rechargement, champ de vision en visée), zoom des lunettes, lampe.
const EFFETS := {
	"point_rouge": {"dispersion_visee": 0.6, "fov_visee": 0.92},
	"viseur_reflex": {"dispersion_visee": 0.6, "fov_visee": 0.93},
	"viseur_aimpoint": {"dispersion_visee": 0.55, "fov_visee": 0.9},
	"viseur_holo": {"dispersion_visee": 0.5, "fov_visee": 0.9},
	"viseur_xps2": {"dispersion_visee": 0.52, "fov_visee": 0.9},
	"viseur_uh1": {"dispersion_visee": 0.5, "fov_visee": 0.9},
	"viseur_pk": {"dispersion_visee": 0.62, "fov_visee": 0.92},
	"lunette": {"dispersion_visee": 0.3, "fov_visee": 0.86, "dispersion": 1.1, "zoom": 4.0},
	"lunette_uar": {"dispersion_visee": 0.25, "fov_visee": 0.85, "dispersion": 1.15, "zoom": 6.0},
	"lunette_hawke": {"dispersion_visee": 0.2, "fov_visee": 0.84, "dispersion": 1.2, "zoom": 8.0},
	"lunette_sb": {"dispersion_visee": 0.15, "fov_visee": 0.82, "dispersion": 1.25, "zoom": 12.0},
	"silencieux": {"bruit": 0.3, "degats": 0.95},
	"silencieux_socom": {"bruit": 0.22, "degats": 0.96},
	"silencieux_9mm": {"bruit": 0.28, "degats": 0.93},
	"silencieux_mp7": {"bruit": 0.25, "degats": 0.95},
	"silencieux_762": {"bruit": 0.35, "degats": 0.95},
	"silencieux_slx": {"bruit": 0.3, "degats": 0.96},
	"frein_9mm": {"recul": 0.78},
	"frein_556": {"recul": 0.7, "bruit": 1.1},
	"frein_762": {"recul": 0.7, "bruit": 1.1},
	"chargeur_etendu": {"capacite": 1.6, "rechargement": 1.15},
	"laser": {"lampe": true, "dispersion_hanche": 0.6},
	"poignee": {"recul": 0.6, "dispersion": 0.85},
	"poignee_rk1": {"recul": 0.62, "dispersion": 0.85},
}

## Pièces de l'arme cachées quand on monte un accessoire (hausse repliée, plaque de la glissière…).
const CACHES_VISEUR := ["rear_sight", "rare_sight", "carry_handle", "reaar_iron_sight", "mos_cover", "mr920_cover"]

static var _compat := {}


## Accessoires compatibles pour chaque arme, par emplacement.
static func table() -> Dictionary:
	if not _compat.is_empty():
		return _compat
	var pr := POINTS_ROUGES
	var tous := POINTS_ROUGES + LUNETTES
	var b556 := ["silencieux", "silencieux_socom", "frein_556"]
	var b762 := ["silencieux_762", "frein_762"]
	var ch := ["chargeur_etendu"]
	var fusil := {"viseur": tous, "bouche": b556, "chargeur": ch, "rail": ["laser"], "poignee": ["poignee"]}
	_compat = {
		"glock19": {"viseur": ["point_rouge", "viseur_reflex"], "bouche": ["silencieux_9mm", "frein_9mm"], "chargeur": ch},
		"mr920": {"viseur": ["point_rouge", "viseur_reflex"], "bouche": ["silencieux_9mm", "frein_9mm"], "chargeur": ch},
		"m45a1": {"chargeur": ch},
		"desert_eagle": {"viseur": ["point_rouge", "viseur_reflex"], "chargeur": ch},
		"mp5k": {"viseur": pr, "bouche": ["silencieux_9mm"], "chargeur": ch},
		"mp7": {"viseur": pr, "bouche": ["silencieux_mp7"], "chargeur": ch, "rail": ["laser"]},
		"benelli_m4": {"viseur": pr, "rail": ["laser"]},
		"toz34": {},
		"m4a1": fusil, "m5_scw": fusil, "urgi": fusil, "lr300": fusil, "mcx": fusil,
		"ak74": {"viseur": ["viseur_pk"], "bouche": ["silencieux", "frein_556"], "chargeur": ch},
		"ak74m": {"viseur": tous + ["viseur_pk"], "bouche": b556, "chargeur": ch, "rail": ["laser"], "poignee": ["poignee_rk1", "poignee"]},
		"draco": {"viseur": ["viseur_pk"], "bouche": b762, "chargeur": ch},
		"uar10": {"viseur": tous, "bouche": b762, "chargeur": ch, "rail": ["laser"], "poignee": ["poignee"]},
		"mcx_spear": {"viseur": tous, "bouche": ["silencieux_slx"] + b762, "chargeur": ch, "rail": ["laser"], "poignee": ["poignee"]},
		"spear_assaulter": {"viseur": tous, "bouche": ["silencieux_slx"] + b762, "chargeur": ch, "rail": ["laser"], "poignee": ["poignee"]},
		"c14": {"viseur": LUNETTES, "bouche": ["silencieux_762"], "chargeur": ch},
		"l96": {"viseur": LUNETTES, "bouche": ["silencieux_762"], "chargeur": ch},
		"gepard": {"viseur": LUNETTES},
		"mosin": {"viseur": LUNETTES},
		"marlin": {"viseur": tous},
		"mg5": {"viseur": tous, "rail": ["laser"]},
	}
	return _compat


static func compatibles(arme: String, emplacement: String) -> Array:
	return table().get(arme, {}).get(emplacement, [])


static func emplacements(arme: String) -> Array:
	var out := []
	var c: Dictionary = table().get(arme, {})
	for e in EMPLACEMENTS:
		if c.has(e):
			out.append(e)
	return out


static func est_lunette(id: String) -> bool:
	return id in LUNETTES


## Statistiques d'une arme à feu avec ses accessoires.
static func stats(arme: String, base: Dictionary, accs: Dictionary) -> Dictionary:
	var w := base.duplicate()
	if w.get("type", "") != "gun":
		return w
	w["dispersion_visee"] = 0.45
	w["dispersion_hanche"] = 1.0
	w["fov_visee"] = 1.0
	w["lampe"] = false
	w["zoom"] = 0.0
	w["laser"] = false
	for emp in accs:
		var ef: Dictionary = EFFETS.get(accs[emp], {})
		if ef.has("dispersion_visee"):
			w.dispersion_visee *= ef.dispersion_visee
		if ef.has("dispersion_hanche"):
			w.dispersion_hanche *= ef.dispersion_hanche
			w.laser = true
		if ef.has("fov_visee"):
			w.fov_visee *= ef.fov_visee
		if ef.has("dispersion"):
			w.spread = float(w.spread) * ef.dispersion
		if ef.has("bruit"):
			w.noise = float(w.noise) * ef.bruit
		if ef.has("degats"):
			w.damage = float(w.damage) * ef.degats
		if ef.has("recul"):
			w.recoil = float(w.recoil) * ef.recul
		if ef.has("capacite"):
			w.mag = int(round(int(w.mag) * ef.capacite))
		if ef.has("rechargement"):
			w.reload = float(w.reload) * ef.rechargement
		if ef.has("zoom"):
			w.zoom = ef.zoom
		if ef.get("lampe", false):
			w.lampe = true
	w["silencieux"] = str(accs.get("bouche", "")) in SILENCIEUX
	return w


# ================================================================ points de montage
static var _points := {}


static func _meshes(modele: Node3D, filtre := "") -> Array:
	var out := []
	for g in modele.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = g
		if mi.has_meta("accessoire") or _dans_accessoire(mi, modele):
			continue
		if filtre != "" and not _sous(mi, modele, filtre):
			continue
		out.append(mi)
	return out


static func _dans_accessoire(n: Node, modele: Node) -> bool:
	var p := n
	while p != null and p != modele:
		if p.has_meta("accessoire"):
			return true
		p = p.get_parent()
	return false


static func _sous(n: Node, modele: Node, nom: String) -> bool:
	var p := n
	while p != null and p != modele:
		if p.name == nom:
			return true
		p = p.get_parent()
	return false


static func _xf_local(n: Node, modele: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p := n
	while p != modele and p != null:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


static func _sommets(ms: Array, modele: Node3D, exclure: Array = []) -> PackedVector3Array:
	var v := PackedVector3Array()
	for mi in ms:
		var nom := String(mi.name).to_lower()
		var sauter := false
		for e in exclure:
			if e in nom:
				sauter = true
		if sauter:
			continue
		var xf := _xf_local(mi, modele)
		for f in (mi as MeshInstance3D).mesh.get_faces():
			v.append(xf * f)
	return v


## Points de montage calculés sur la géométrie de l'arme (repère de l'arme : canon vers -Z, origine = poignée)
## et données de prise en main enregistrées dans le modèle (L, incl, prise_l, chargeur_bas, culasse).
static func points(arme: String, modele: Node3D) -> Dictionary:
	if _points.has(arme):
		return _points[arme]
	var tout := _sommets(_meshes(modele), modele)
	if tout.is_empty():
		return {}
	var mn := tout[0]
	var mx := tout[0]
	for v in tout:
		mn = mn.min(v)
		mx = mx.max(v)
	var bouche := _avant(tout)
	var corps := _sommets(_meshes(modele, "Arme"), modele)
	var canon := _avant(corps) if not corps.is_empty() else bouche
	var longue := (mx.z - mn.z) > 0.5
	var ch: Node3D = modele.get_node_or_null("Chargeur")
	var out := {
		"bouche": bouche, "canon": canon, "taille": mx - mn, "centre": (mx + mn) * 0.5,
		"incl": float(modele.get_meta("incl", 18.0)), "prise_l": str(modele.get_meta("prise_l", "garde")),
	}
	if modele.has_meta("L"):
		out["L"] = modele.get_meta("L")
	if modele.has_meta("culasse"):
		out["culasse"] = modele.get_meta("culasse")
	if ch:
		out["chargeur"] = ch.position
		out["chargeur_bas"] = modele.get_meta("chargeur_bas", ch.position + Vector3(0, -0.1, 0))
	# viseur : dessus de la carcasse (sans la hausse ni la poignée de transport), au-dessus du puits du chargeur
	var hors := ["rear_sight", "rare_sight", "carry_handle", "iron_sight", "front_sight", "reaar"]
	var dessus := _sommets(_meshes(modele, "Arme"), modele, hors)
	var zv := -0.03
	if longue:
		zv = (ch.position.z - 0.02) if ch else -0.14
	var plaque := _centre_partie(modele, "mos_cover")
	if plaque == Vector3.INF:
		plaque = _centre_partie(modele, "mr920_cover")
	if plaque != Vector3.INF:
		out["viseur"] = plaque
	else:
		out["viseur"] = Vector3(canon.x, _max_y(dessus, zv - 0.035, zv + 0.035, canon.x, mx.y), zv)
	# rail du dessus (module laser) : à l'avant du garde-main
	var l: Vector3 = out.get("L", Vector3(0, 0, canon.z * 0.45))
	var zr := l.z - 0.07 if longue else canon.z * 0.6
	out["rail"] = Vector3(canon.x, _max_y(dessus, zr - 0.02, zr + 0.02, canon.x, mx.y), zr)
	# poignée verticale : sous le garde-main, là où se pose la main gauche
	var zp := l.z
	out["poignee"] = Vector3(canon.x, _min_y(corps, zp - 0.015, zp + 0.015, canon.x, l.y), zp)
	# hausse (visée sans optique) : dessus de la hausse si l'arme en a une, sinon dessus de la carcasse
	var hausse := _haut_partie(modele, ["rear_sight", "rare_sight", "carry_handle", "reaar_iron_sight"])
	out["hausse"] = hausse if hausse != Vector3.INF else Vector3(canon.x, out.viseur.y + 0.006, out.viseur.z)
	_points[arme] = out
	return out


static func _avant(v: PackedVector3Array) -> Vector3:
	var zmin := INF
	for p in v:
		zmin = minf(zmin, p.z)
	var s := Vector3.ZERO
	var n := 0
	for p in v:
		if p.z < zmin + 0.006:
			s += p
			n += 1
	var b := s / maxf(1, n)
	b.z = zmin
	return b


static func _centre_partie(modele: Node3D, mot: String) -> Vector3:
	for mi in _meshes(modele, "Arme"):
		if mot in String(mi.name).to_lower():
			var a: AABB = _xf_local(mi, modele) * (mi as MeshInstance3D).get_aabb()
			return Vector3(a.get_center().x, a.position.y, a.get_center().z)
	return Vector3.INF


static func _haut_partie(modele: Node3D, mots: Array) -> Vector3:
	for mi in _meshes(modele, "Arme"):
		var nom := String(mi.name).to_lower()
		for mot in mots:
			if mot in nom:
				var a: AABB = _xf_local(mi, modele) * (mi as MeshInstance3D).get_aabb()
				return Vector3(a.get_center().x, a.end.y - 0.004, a.get_center().z)
	return Vector3.INF


static func _max_y(verts: PackedVector3Array, z0: float, z1: float, x0: float, defaut: float) -> float:
	var y := -INF
	for v in verts:
		if v.z >= z0 and v.z <= z1 and absf(v.x - x0) < 0.012:
			y = maxf(y, v.y)
	return defaut if y == -INF else y


static func _min_y(verts: PackedVector3Array, z0: float, z1: float, x0: float, defaut: float) -> float:
	var y := INF
	for v in verts:
		if v.z >= z0 and v.z <= z1 and absf(v.x - x0) < 0.015:
			y = minf(y, v.y)
	return defaut if y == INF else y


# ================================================================ modèles des accessoires
static var _infos := {}


## Données d'un accessoire mesurées sur son modèle : point de visée (verre du viseur ou oculaire de la lunette),
## rayon de l'oculaire, longueur (silencieux), émetteur (laser).
static func infos(acc: String) -> Dictionary:
	if _infos.has(acc):
		return _infos[acc]
	var d := {}
	var n := _charger(acc)
	if n:
		var verre := PackedVector3Array()
		var tout := PackedVector3Array()
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m: Mesh = (mi as MeshInstance3D).mesh
			var xf := _xf_local(mi, n)
			for s in m.get_surface_count():
				var mat := m.surface_get_material(s)
				var arr := m.surface_get_arrays(s)
				for v in arr[Mesh.ARRAY_VERTEX]:
					var p: Vector3 = xf * v
					tout.append(p)
					if mat and "glass" in mat.resource_name.to_lower():
						verre.append(p)
		var a := AABB(tout[0], Vector3.ZERO)
		for p in tout:
			a = a.expand(p)
		d["aabb"] = a
		if est_lunette(acc):
			# oculaire : sommets les plus en arrière
			var zmax := a.end.z
			var c := Vector3.ZERO
			var k := 0
			var ymin := INF
			var ymax := -INF
			for p in tout:
				if p.z > zmax - 0.004:
					c += p
					k += 1
					ymin = minf(ymin, p.y)
					ymax = maxf(ymax, p.y)
			c /= maxf(1, k)
			c.z = zmax
			d["visee"] = c
			d["rayon"] = clampf((ymax - ymin) * 0.5 * 0.85, 0.008, 0.03)
		elif not verre.is_empty():
			var av := AABB(verre[0], Vector3.ZERO)
			for p in verre:
				av = av.expand(p)
			d["visee"] = av.get_center()
		else:
			d["visee"] = Vector3(0, a.end.y * 0.6, 0)
		if acc == "laser":
			d["emetteur"] = Vector3(a.get_center().x + 0.012, a.get_center().y, a.position.z)
		d["longueur"] = a.size.z
		n.free()
	_infos[acc] = d
	return d


static func _charger(acc: String) -> Node3D:
	var p := "res://modeles/armes/%s.scn" % MODELES.get(acc, "")
	if not ResourceLoader.exists(p):
		return null
	return (load(p) as PackedScene).instantiate()


static var _mat_verre: StandardMaterial3D = null


## Pose les accessoires sur le modèle d'une arme. « lumiere » : ajoute la lumière de la lampe.
static func habiller(modele: Node3D, arme: String, accs: Dictionary, lumiere := false) -> void:
	for c in modele.get_children():
		if c.has_meta("accessoire"):
			modele.remove_child(c)
			c.queue_free()
	var pts := points(arme, modele)
	# pièces masquées selon les accessoires (hausse repliée, plaque de glissière, cache-flammes d'origine)
	var optique := accs.has("viseur")
	for mi in modele.find_children("*", "MeshInstance3D", true, false):
		var nom := String(mi.name).to_lower()
		for mot in CACHES_VISEUR:
			if mot in nom:
				(mi as MeshInstance3D).visible = not optique
	var db := modele.get_node_or_null("DispositifBouche")
	if db:
		db.visible = not accs.has("bouche")
	if accs.is_empty() or pts.is_empty():
		return
	for emp in accs:
		var n := modele_accessoire(accs[emp], lumiere)
		if n == null:
			continue
		n.set_meta("accessoire", true)
		n.set_meta("emplacement", emp)
		match emp:
			"bouche":
				n.position = pts.canon
			"viseur":
				n.position = pts.viseur
			"rail":
				n.position = pts.rail
			"poignee":
				n.position = pts.poignee
			_:
				continue
		modele.add_child(n)


## Modèle 3D d'un accessoire. Origine = point de fixation sur l'arme.
static func modele_accessoire(id: String, lumiere := false) -> Node3D:
	var n := _charger(id)
	if n == null:
		return null
	n.name = id
	var d := infos(id)
	if id in POINTS_ROUGES or id == "viseur_pk":
		# verre traité légèrement teinté (on voit à travers) et point rouge projeté au centre
		if _mat_verre == null:
			_mat_verre = StandardMaterial3D.new()
			_mat_verre.albedo_color = Color(0.55, 0.75, 0.7, 0.14)
			_mat_verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_mat_verre.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_mat_verre.cull_mode = BaseMaterial3D.CULL_DISABLED
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m: Mesh = (mi as MeshInstance3D).mesh
			for s in m.get_surface_count():
				var mat := m.surface_get_material(s)
				if mat and "glass" in mat.resource_name.to_lower():
					(mi as MeshInstance3D).set_surface_override_material(s, _mat_verre)
		var point := StandardMaterial3D.new()
		point.albedo_color = Color(1, 0.1, 0.05)
		point.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		point.emission_enabled = true
		point.emission = Color(1, 0.1, 0.05)
		var s3 := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.0011
		sm.height = 0.0022
		s3.mesh = sm
		s3.material_override = point
		s3.position = d.get("visee", Vector3.ZERO) + Vector3(0, 0, 0.002)
		n.add_child(s3)
	elif est_lunette(id):
		# oculaire : reçoit l'image grossie quand on vise
		var oc := MeshInstance3D.new()
		oc.name = "Oculaire"
		var qm := QuadMesh.new()
		var r: float = d.get("rayon", 0.019)
		qm.size = Vector2(r * 2.0, r * 2.0)
		oc.mesh = qm
		oc.position = d.get("visee", Vector3.ZERO) + Vector3(0, 0, 0.0015)
		var om := StandardMaterial3D.new()
		om.albedo_color = Color(0.05, 0.08, 0.1)
		om.metallic = 0.6
		om.roughness = 0.05
		oc.material_override = om
		n.add_child(oc)
	elif id == "laser":
		var e := Node3D.new()
		e.name = "Emetteur"
		e.position = d.get("emetteur", Vector3.ZERO)
		n.add_child(e)
		if lumiere:
			var sl := SpotLight3D.new()
			sl.name = "Lumiere"
			sl.spot_range = 32.0
			sl.spot_angle = 22.0
			sl.light_energy = 3.5
			sl.light_color = Color(1.0, 0.96, 0.88)
			sl.shadow_enabled = true
			sl.position = e.position + Vector3(-0.02, 0, 0)
			sl.visible = false
			n.add_child(sl)
	return n
