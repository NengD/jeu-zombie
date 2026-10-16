class_name Accessoires
extends RefCounted
## Accessoires d'armes : données, compatibilité, effets sur les statistiques
## et modèles 3D (posés sur l'arme aux bons endroits, calculés à partir de sa géométrie).

## Emplacements, dans l'ordre d'affichage.
const EMPLACEMENTS := ["viseur", "bouche", "chargeur", "rail", "poignee"]
const NOMS_EMPLACEMENTS := {"viseur": "Viseur", "bouche": "Bouche du canon", "chargeur": "Chargeur",
		"rail": "Rail (lampe)", "poignee": "Poignée"}

## Accessoires compatibles pour chaque arme, par emplacement.
const COMPAT := {
	"pistolet": {"viseur": ["point_rouge"], "bouche": ["silencieux", "silencieux_artisanal"], "chargeur": ["chargeur_etendu"], "rail": ["lampe_tactique"]},
	"revolver": {"viseur": ["point_rouge"]},
	"fusil_pompe": {"viseur": ["point_rouge"], "rail": ["lampe_tactique"], "poignee": ["poignee"]},
	"fusil_artisanal": {"rail": ["lampe_tactique"]},
	"carabine": {"viseur": ["point_rouge", "lunette"], "bouche": ["silencieux", "silencieux_artisanal"], "chargeur": ["chargeur_etendu"], "rail": ["lampe_tactique"], "poignee": ["poignee"]},
	"fusil_assaut": {"viseur": ["point_rouge", "lunette"], "bouche": ["silencieux", "silencieux_artisanal"], "chargeur": ["chargeur_etendu"], "rail": ["lampe_tactique"], "poignee": ["poignee"]},
}

## Effets : multiplicateurs (précision = dispersion, bruit, dégâts, recul, capacité, champ de vision en visée).
const EFFETS := {
	"point_rouge": {"dispersion_visee": 0.6, "fov_visee": 0.92},
	"lunette": {"dispersion_visee": 0.3, "fov_visee": 0.86, "dispersion": 1.15},
	"silencieux": {"bruit": 0.3, "degats": 0.93},
	"silencieux_artisanal": {"bruit": 0.55, "degats": 0.9, "dispersion": 1.1},
	"chargeur_etendu": {"capacite": 1.6, "rechargement": 1.15},
	"lampe_tactique": {"lampe": true},
	"poignee": {"recul": 0.55, "dispersion": 0.8},
}


static func compatibles(arme: String, emplacement: String) -> Array:
	return COMPAT.get(arme, {}).get(emplacement, [])


static func emplacements(arme: String) -> Array:
	var out := []
	var c: Dictionary = COMPAT.get(arme, {})
	for e in EMPLACEMENTS:
		if c.has(e):
			out.append(e)
	return out


## Statistiques d'une arme à feu avec ses accessoires.
static func stats(arme: String, base: Dictionary, accs: Dictionary) -> Dictionary:
	var w := base.duplicate()
	if w.get("type", "") != "gun":
		return w
	w["dispersion_visee"] = 0.45
	w["fov_visee"] = 1.0
	w["lampe"] = false
	for emp in accs:
		var ef: Dictionary = EFFETS.get(accs[emp], {})
		if ef.has("dispersion_visee"):
			w.dispersion_visee *= ef.dispersion_visee
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
		if ef.get("lampe", false):
			w.lampe = true
	w["silencieux"] = accs.has("bouche")
	return w


# ================================================================ modèles 3D
static var _points := {}

## Corrections mesurées sur les vues de profil des modèles : dessus de la carcasse (viseur),
## bas du chargeur (et son inclinaison, en degrés, positive = bas du chargeur vers l'avant).
const POINTS_FIXES := {
	"fusil_assaut": {"viseur": Vector3(0, 0.124, -0.07), "chargeur": Vector3(0, -0.058, -0.236), "incl_chargeur": 46.0},
	"carabine": {"viseur": Vector3(0, 0.12, -0.03), "chargeur": Vector3(0, -0.136, -0.13), "incl_chargeur": 8.0},
	"pistolet": {"viseur": Vector3(0, 0.085, -0.03), "chargeur": Vector3(0, -0.061, 0.022), "incl_chargeur": -18.0, "rail": Vector3(0, 0.034, -0.075)},
	"revolver": {"viseur": Vector3(0, 0.072, -0.03)},
	"fusil_pompe": {"viseur": Vector3(0, 0.086, -0.02)},
}


## Points de montage calculés sur la géométrie de l'arme (repère de l'arme : canon vers -Z, origine = poignée).
static func points(arme: String, modele: Node3D) -> Dictionary:
	if _points.has(arme):
		return _points[arme]
	var verts := PackedVector3Array()
	for g in modele.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = g
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != modele and n != null:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for f in mi.mesh.get_faces():
			verts.append(xf * f)
	if verts.is_empty():
		return {}
	var mn := verts[0]
	var mx := verts[0]
	for v in verts:
		mn = mn.min(v)
		mx = mx.max(v)
	var lg := mx.z - mn.z
	# bouche : moyenne des sommets à l'extrémité avant
	var b := Vector3.ZERO
	var nb := 0
	for v in verts:
		if v.z < mn.z + 0.015:
			b += v
			nb += 1
	var bouche := b / maxf(1, nb)
	bouche.z = mn.z
	var longue := lg > 0.5
	# dessus de la carcasse au-dessus de la poignée (viseur)
	var zv := -0.02 if not longue else -0.12
	var haut := _max_y(verts, zv - 0.06, zv + 0.06, mn.y)
	# dessous du canon (lampe, poignée)
	var zr := bouche.z * 0.55 if longue else bouche.z * 0.6
	var bas_r := _min_y(verts, zr - 0.04, zr + 0.04, bouche.y - 0.05)
	var zp := bouche.z * 0.4
	var bas_p := _min_y(verts, zp - 0.04, zp + 0.04, bouche.y - 0.06)
	# chargeur : point le plus bas juste devant la poignée
	var zc := -0.05 if not longue else -0.17
	var bas_c := _min_y(verts, zc - 0.05, zc + 0.05, mn.y)
	var out := {
		"bouche": Vector3(bouche.x, bouche.y, bouche.z),
		"viseur": Vector3(bouche.x, haut, zv),
		"rail": Vector3(bouche.x, bas_r, zr),
		"poignee": Vector3(bouche.x, bas_p, zp),
		"chargeur": Vector3(bouche.x, bas_c, zc),
		"taille": mx - mn, "centre": (mx + mn) * 0.5, "incl_chargeur": 0.0,
	}
	for k in POINTS_FIXES.get(arme, {}):
		out[k] = POINTS_FIXES[arme][k]
	_points[arme] = out
	return out


static func _max_y(verts: PackedVector3Array, z0: float, z1: float, defaut: float) -> float:
	var y := -INF
	for v in verts:
		if v.z >= z0 and v.z <= z1:
			y = maxf(y, v.y)
	return defaut if y == -INF else y


static func _min_y(verts: PackedVector3Array, z0: float, z1: float, defaut: float) -> float:
	var y := INF
	for v in verts:
		if v.z >= z0 and v.z <= z1:
			y = minf(y, v.y)
	return defaut if y == INF else y


## Pose les accessoires sur le modèle d'une arme. « lumiere » : ajoute la lumière de la lampe.
static func habiller(modele: Node3D, arme: String, accs: Dictionary, lumiere := false) -> void:
	for c in modele.get_children():
		if c.has_meta("accessoire"):
			c.queue_free()
	if accs.is_empty():
		return
	var pts := points(arme, modele)
	if pts.is_empty():
		return
	for emp in accs:
		var n := modele_accessoire(accs[emp], lumiere)
		if n == null:
			continue
		n.set_meta("accessoire", true)
		n.position = pts.get(emp, Vector3.ZERO)
		if emp == "chargeur":
			n.rotation.x = deg_to_rad(float(pts.get("incl_chargeur", 0.0)))
		if emp == "rail" and float(Items.info(arme).get("len", 0.3)) < 0.4:
			n.scale = Vector3.ONE * 0.7
		modele.add_child(n)


static func _mat(c: Color, metal := 0.4, rough := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


static func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, axe_z := true, r2 := -1.0, creux := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	if creux:
		cm.cap_top = false
		cm.cap_bottom = false
	cm.top_radius = r if r2 < 0.0 else r2
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	if axe_z:
		mi.rotation.x = PI / 2.0
	parent.add_child(mi)
	return mi


static func _boite(parent: Node3D, s: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Modèle 3D d'un accessoire. Origine = point de fixation sur l'arme.
static func modele_accessoire(id: String, lumiere := false) -> Node3D:
	var n := Node3D.new()
	n.name = id
	var noir := _mat(Color(0.06, 0.06, 0.065), 0.5, 0.45)
	var mat_noir := _mat(Color(0.1, 0.1, 0.1), 0.2, 0.8)
	match id:
		"point_rouge":
			_boite(n, Vector3(0.024, 0.012, 0.05), Vector3(0, 0.006, 0), noir)
			var noir_creux := noir.duplicate()
			noir_creux.cull_mode = BaseMaterial3D.CULL_DISABLED
			_cyl(n, 0.017, 0.045, Vector3(0, 0.03, 0), noir_creux, true, -1.0, true)
			# verre traité (légèrement teinté) : on voit à travers, le point rouge est projeté au centre
			var verre := _mat(Color(0.55, 0.75, 0.7, 0.16), 0.0, 0.02)
			verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			verre.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_cyl(n, 0.0155, 0.001, Vector3(0, 0.03, -0.021), verre)
			var point := _mat(Color(1, 0.1, 0.05))
			point.emission_enabled = true
			point.emission = Color(1, 0.1, 0.05)
			point.emission_energy_multiplier = 4.0
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.0012
			sm.height = 0.0024
			s.mesh = sm
			s.material_override = point
			s.position = Vector3(0, 0.03, -0.019)
			n.add_child(s)
		"lunette":
			# lunette basse : colliers serrés autour du tube, embases courtes posées sur le rail
			var h := 0.03
			for z in [-0.05, 0.05]:
				_cyl(n, 0.0178, 0.01, Vector3(0, h, z), noir)
				_boite(n, Vector3(0.014, h - 0.012, 0.01), Vector3(0, (h - 0.012) / 2.0, z), noir)
			_boite(n, Vector3(0.016, 0.004, 0.125), Vector3(0, 0.002, 0), noir)
			_cyl(n, 0.015, 0.2, Vector3(0, h, 0), noir)
			_cyl(n, 0.015, 0.05, Vector3(0, h, -0.12), noir, true, 0.023)
			_cyl(n, 0.018, 0.04, Vector3(0, h, 0.115), noir, true, 0.015)
			_cyl(n, 0.008, 0.009, Vector3(0, h + 0.019, 0), noir, false)
			var tour := _cyl(n, 0.008, 0.009, Vector3(0.019, h, 0), noir, false)
			tour.rotation.z = PI / 2.0
			var verre := _mat(Color(0.15, 0.25, 0.35), 0.8, 0.05)
			_cyl(n, 0.021, 0.003, Vector3(0, h, -0.146), verre)
			# oculaire (côté œil) : reçoit l'image grossie quand on vise
			var oc := MeshInstance3D.new()
			oc.name = "Oculaire"
			var qm := QuadMesh.new()
			qm.size = Vector2(0.038, 0.038)
			oc.mesh = qm
			oc.position = Vector3(0, 0.03, 0.1365)
			var om := _mat(Color(0.05, 0.08, 0.1), 0.6, 0.05)
			oc.material_override = om
			n.add_child(oc)
		"silencieux":
			_cyl(n, 0.017, 0.17, Vector3(0, 0, -0.085), noir)
			_cyl(n, 0.019, 0.012, Vector3(0, 0, -0.006), noir)
		"silencieux_artisanal":
			var ruban := _mat(Color(0.55, 0.55, 0.58), 0.1, 0.7)
			_cyl(n, 0.024, 0.16, Vector3(0, 0, -0.08), _mat(Color(0.35, 0.33, 0.3), 0.6, 0.6))
			for z in [-0.02, -0.08, -0.14]:
				_cyl(n, 0.026, 0.02, Vector3(0, 0, z), ruban)
		"chargeur_etendu":
			# rallonge sous le chargeur d'origine (le haut touche le bas du chargeur)
			_boite(n, Vector3(0.026, 0.045, 0.05), Vector3(0, -0.0215, 0.0), noir)
			_boite(n, Vector3(0.03, 0.01, 0.056), Vector3(0, -0.047, 0.0), noir)
		"lampe_tactique":
			_boite(n, Vector3(0.02, 0.012, 0.03), Vector3(0, -0.006, 0), noir)
			_cyl(n, 0.016, 0.1, Vector3(0, -0.026, -0.02), noir)
			_cyl(n, 0.019, 0.025, Vector3(0, -0.026, -0.075), noir)
			var lentille := _mat(Color(1, 0.97, 0.85))
			lentille.emission_enabled = true
			lentille.emission = Color(1, 0.95, 0.8)
			lentille.emission_energy_multiplier = 1.5
			_cyl(n, 0.016, 0.002, Vector3(0, -0.026, -0.088), lentille)
			if lumiere:
				var sl := SpotLight3D.new()
				sl.name = "Lumiere"
				sl.spot_range = 30.0
				sl.spot_angle = 22.0
				sl.light_energy = 3.5
				sl.light_color = Color(1.0, 0.96, 0.88)
				sl.shadow_enabled = true
				sl.position = Vector3(0, -0.026, -0.1)
				sl.visible = false
				n.add_child(sl)
		"poignee":
			_boite(n, Vector3(0.02, 0.012, 0.035), Vector3(0, -0.006, 0), noir)
			_cyl(n, 0.014, 0.09, Vector3(0, -0.055, 0), mat_noir, false, 0.016)
		_:
			return null
	return n
