extends RefCounted
## Équipement porté visible sur un personnage low-poly (Quaternius, os nommés comme UAL) :
##  - casques, bonnets, masques, sacs : maillages rigides (modeles/equipement/*.res, outils/godot/normaliser_equipement.gd)
##    accrochés à un os par un BoneAttachment3D (suivent l'animation, les bras et pieds calculés)
##  - gilets : buste d'un autre personnage Quaternius (même squelette) à la place du buste du personnage
##  - vestes : haut du personnage recoloré (matériaux partagés de Perso._recolore, pas de ShaderMaterial)
## Positions données dans le repère du squelette au repos (avant = +Z, haut = +Y), relatives à l'origine de l'os.

const Perso = preload("res://scripts/perso.gd")
const DOSSIER := "res://modeles/equipement/%s.res"

# objet -> modèle, os, position (m), rotation (degrés), échelle, couleur imposée (facultatives), cheveux cachés
const PIECES := {
	"casque_moto": {"m": "casque_integral", "os": "Head", "pos": Vector3(0, 0.135, 0.005), "rot": Vector3(0, 180, 0), "ech": 0.92, "cheveux": true},
	"casque_police": {"m": "casque_integral", "os": "Head", "pos": Vector3(0, 0.135, 0.005), "rot": Vector3(0, 180, 0), "ech": 0.92, "col": Color(0.08, 0.09, 0.12), "cheveux": true},
	"casque_militaire": {"m": "casque_combat", "os": "Head", "pos": Vector3(0, 0.17, -0.005), "cheveux": true},
	"casque_chantier": {"m": "casque_chantier", "os": "Head", "pos": Vector3(0, 0.215, 0.01), "cheveux": true},
	"bonnet": {"m": "bonnet", "os": "Head", "pos": Vector3(0, 0.215, -0.01), "cheveux": true},
	"capuche_cuir": {"m": "bonnet", "os": "Head", "pos": Vector3(0, 0.19, -0.02), "ech": 1.12, "col": Color(0.36, 0.22, 0.13), "cheveux": true},
	"casquette": {"m": "casquette", "os": "Head", "pos": Vector3(0, 0.235, 0.035), "cheveux": true},
	"casquette_police": {"m": "casquette_police", "os": "Head", "pos": Vector3(0, 0.245, 0.03), "cheveux": true},
	"lunettes": {"m": "lunettes", "os": "Head", "pos": Vector3(0, 0.1, 0.03)},
	"masque_gaz": {"m": "masque_gaz", "os": "Head", "pos": Vector3(0, 0.03, 0.05)},
	"sac_toile": {"m": "sacoche", "os": "pelvis", "pos": Vector3(0.2, -0.04, -0.02)},
	"sac_a_dos": {"m": "sac_a_dos", "os": "spine_03", "pos": Vector3(0, -0.08, -0.15)},
	"sac_militaire": {"m": "sac_militaire", "os": "spine_03", "pos": Vector3(0, -0.1, -0.15)},
	"sac_randonnee": {"m": "sac_randonnee", "os": "spine_03", "pos": Vector3(0, -0.04, -0.17)},
	"sac_chasse": {"m": "sac_chasse", "os": "spine_03", "pos": Vector3(0, -0.08, -0.17)},
	"sac_sport": {"m": "sac_sport", "os": "spine_03", "pos": Vector3(0, -0.02, -0.13), "rot": Vector3(0, 0, 20)},
}
# corrections par modèle de personnage (femmes : tête et buste plus petits)
const AJUST := {
	"f_": {"Head": [Vector3(0, -0.01, -0.005), 0.94], "spine_03": [Vector3(0, 0.0, 0.02), 0.92], "pelvis": [Vector3(-0.02, 0.0, 0.0), 0.95]},
}
# gilets : buste d'un personnage Quaternius ; couleurs [matériau principal, matériau sombre]
const GILETS := {
	"gilet_police": [Color(0.12, 0.14, 0.22), Color(0.06, 0.06, 0.07)],
	"gilet_militaire": [Color(0.33, 0.36, 0.22), Color(0.17, 0.18, 0.12)],
}
# couvre-chefs intégrés aux têtes (casque jaune de l'ouvrier) et sacs intégrés aux bustes, cachés
const COUVRE_CHEFS := ["Worker_Yellow"]
# (sac intégré : triangles de ces matériaux derrière le dos (z) ou au-dessus des épaules (y), au repos)
const SAC_INTEGRE := {"f_adventurer": {"z": -0.055, "y": 1.465, "mats": ["LightGreen", "Gold", "Green"]}}
const BUSTE_GILET := {"h_": ["h_swat", "Swat_Body"], "f_": ["f_soldier", "Soldier_Body"]}
# vestes : couleurs des vêtements du haut (du plus clair au plus sombre)
const VESTES := {
	"veste_cuir": [Color(0.42, 0.26, 0.15), Color(0.30, 0.18, 0.10)],
	"veste_renforcee": [Color(0.30, 0.28, 0.26), Color(0.20, 0.16, 0.12)],
}

# armes rangées : dos (sans sac : à la surface du dos, relatif à spine_03), cuisse droite, hanche gauche (relatifs à pelvis)
const DOS_Z := -0.11
const ARMES_DOS := [[Vector3(0.0, -0.02, 0.0), 32.0], [Vector3(0.0, -0.06, 0.0), -38.0]]   # [position, inclinaison (degrés, + = canon vers l'épaule gauche)]
const ARME_CUISSE := Vector3(-0.2, -0.12, 0.0)
const ARME_HANCHE := Vector3(0.19, -0.06, 0.0)

static var _maillages := {}
static var _filtres := {}   # maillages du personnage privés de surfaces (cheveux, sac intégré)
static var _bustes := {}


## Met à jour l'équipement visible. equip = {"tete": entrée, "torse": …, "dos": …, "visage": …}.
static func appliquer(modele: Node3D, equip: Dictionary) -> void:
	var sk: Skeleton3D = null
	for s in modele.find_children("*", "Skeleton3D", true, false):
		sk = s
		break
	if sk == null:
		return
	var id_modele: String = modele.get_meta("modele", "h_adventurer")
	var sexe := "f_" if id_modele.begins_with("f_") else "h_"
	for c in sk.get_children():
		if c.has_meta("equip") and not c.has_meta("arme_rangee"):
			sk.remove_child(c)
			c.queue_free()
	sk.set_meta("dos_z", DOS_Z)
	sk.set_meta("sacoche", false)
	var ids := []
	for s in equip:
		var e = equip[s]
		if e is Dictionary and not e.is_empty():
			ids.append(e.id)
	var cheveux := true
	for id in ids:
		var p: Dictionary = PIECES.get(id, {})
		if p.is_empty():
			continue
		_accrocher(sk, p, sexe)
		if p.get("cheveux", false):
			cheveux = false
	var torse := ""
	for id in ids:
		if GILETS.has(id) or VESTES.has(id):
			torse = id
	var tete_libre := cheveux
	for mi in sk.get_children():
		if not (mi is MeshInstance3D) or mi.has_meta("equip"):
			continue
		var nom := String(mi.name)
		if nom == "Backpack":
			mi.visible = false   # sac d'origine de l'aventurier : remplacé par le sac porté
		elif nom.ends_with("_Head"):
			_poser(mi, [], func(m: String): return not tete_libre and (m.begins_with("Hair") or m in COUVRE_CHEFS))
		elif nom.ends_with("_Body"):
			_buste(sk, mi, torse, sexe, SAC_INTEGRE.get(id_modele, {}))


static func _maillage(nom: String) -> Mesh:
	if not _maillages.has(nom):
		var ch := DOSSIER % nom
		_maillages[nom] = load(ch) if ResourceLoader.exists(ch) else null
	return _maillages[nom]


static func _accrocher(sk: Skeleton3D, p: Dictionary, sexe: String) -> void:
	var mesh := _maillage(p.m)
	var os: String = p.os
	var b := sk.find_bone(os)
	if mesh == null or b < 0:
		return
	var aj: Array = AJUST.get(sexe, {}).get(os, [Vector3.ZERO, 1.0])
	var repos := sk.get_bone_global_rest(b)
	var ech: float = p.get("ech", 1.0) * aj[1]
	var r: Vector3 = p.get("rot", Vector3.ZERO)
	var voulu := Transform3D(Basis.from_euler(r * PI / 180.0).scaled(Vector3.ONE * ech), repos.origin + p.pos * aj[1] + aj[0])
	if os == "spine_03":   # dos du sac : les armes rangées passent par-dessus
		sk.set_meta("dos_z", p.pos.z * aj[1] + aj[0].z - mesh.get_aabb().size.z * 0.5 * ech)
	elif os == "pelvis":
		sk.set_meta("sacoche", true)
	var ba := BoneAttachment3D.new()
	ba.bone_name = os
	ba.set_meta("equip", true)
	sk.add_child(ba)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = repos.affine_inverse() * voulu
	if p.has("col"):
		for s in mesh.get_surface_count():
			mi.set_surface_override_material(s, Perso._recolore(mesh.surface_get_material(s), p.col))
	ba.add_child(mi)


## Applique à un maillage du personnage des couleurs (par surface d'origine, null = d'origine) et cache
## les surfaces dont le matériau d'origine vérifie `cacher` (maillage sans ces surfaces, gardé en cache).
static func _poser(mi: MeshInstance3D, couleurs: Array, cacher: Callable) -> void:
	var origine: Mesh = mi.get_meta("eq_mesh", mi.mesh)
	if not mi.has_meta("eq_mesh"):
		var l := []
		for s in origine.get_surface_count():
			l.append(mi.get_surface_override_material(s))
		mi.set_meta("eq_mesh", origine)
		mi.set_meta("eq_mats", l)
	var mats: Array = mi.get_meta("eq_mats")
	var garder := []
	for s in origine.get_surface_count():
		var m := origine.surface_get_material(s)
		if not cacher.call(String(m.resource_name) if m else ""):
			garder.append(s)
	var cible: Mesh = origine
	if garder.size() < origine.get_surface_count():
		var cle := "%d_%s" % [origine.get_instance_id(), str(garder)]
		if not _filtres.has(cle):
			var am := ArrayMesh.new()
			for s in garder:
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, origine.surface_get_arrays(s), [], {}, origine.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
				am.surface_set_material(am.get_surface_count() - 1, origine.surface_get_material(s))
			_filtres[cle] = am
		cible = _filtres[cle]
	mi.mesh = cible
	for k in garder.size():
		var s: int = garder[k]
		var c = couleurs[s] if s < couleurs.size() else null
		if c is Color:
			mi.set_surface_override_material(k, Perso._recolore(origine.surface_get_material(s), c))
		else:
			mi.set_surface_override_material(k, mats[s])


## Haut du personnage : buste de gilet, haut recoloré (veste) ou d'origine ; sac intégré au buste caché.
static func _buste(sk: Skeleton3D, corps: MeshInstance3D, torse: String, sexe: String, sac: Dictionary) -> void:
	if not sac.is_empty() and not corps.has_meta("eq_mesh"):
		corps.mesh = _sans_sac(corps.mesh, sac)
	var origine: Mesh = corps.get_meta("eq_mesh", corps.mesh)
	var cacher := func(_m: String): return false
	# veste : vêtements recolorés (clair / sombre selon la luminosité d'origine)
	var cols: Array = VESTES.get(torse, [])
	var couleurs := []
	var peau: Material = null
	for s in origine.get_surface_count():
		var m := origine.surface_get_material(s)
		var nom := String(m.resource_name) if m else ""
		couleurs.append(null)
		if nom.begins_with("Skin"):
			var mats: Array = corps.get_meta("eq_mats", [])
			peau = mats[s] if s < mats.size() and mats[s] else corps.get_surface_override_material(s)
		elif not cols.is_empty() and m is StandardMaterial3D:
			couleurs[s] = cols[0] if (m as StandardMaterial3D).albedo_color.v > 0.35 else cols[1]
	_poser(corps, couleurs, cacher)
	corps.visible = true
	if not GILETS.has(torse):
		return
	var src: Array = BUSTE_GILET[sexe]
	if not _bustes.has(src[0]):
		var n: Node3D = load(Perso.MOD % src[0]).instantiate()
		var b: MeshInstance3D = n.find_child(src[1], true, false)
		_bustes[src[0]] = [b.mesh, b.skin] if b else []
		n.free()
	var d: Array = _bustes[src[0]]
	if d.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.set_meta("equip", true)
	mi.mesh = d[0]
	mi.skin = d[1]
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	var cg: Array = GILETS[torse]
	for s in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(s)
		var nom := String(m.resource_name) if m else ""
		if nom.begins_with("Skin"):
			mi.set_surface_override_material(s, peau)
		elif m:
			var v: float = (m as StandardMaterial3D).albedo_color.v if m is StandardMaterial3D else 0.5
			mi.set_surface_override_material(s, Perso._recolore(m, cg[0] if v > 0.2 else cg[1]))
	corps.visible = false


## Maillage du buste sans le sac intégré au modèle (triangles choisis par SAC_INTEGRE).
static func _sans_sac(origine: Mesh, sac: Dictionary) -> Mesh:
	var cle := "sac_%d" % origine.get_instance_id()
	if _filtres.has(cle):
		return _filtres[cle]
	var am := ArrayMesh.new()
	for s in origine.get_surface_count():
		var a: Array = origine.surface_get_arrays(s)
		var m := origine.surface_get_material(s)
		if m and String(m.resource_name) in sac.mats and a[Mesh.ARRAY_INDEX]:
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			var garde := PackedInt32Array()
			for t in idx.size() / 3:
				var c: Vector3 = (v[idx[t * 3]] + v[idx[t * 3 + 1]] + v[idx[t * 3 + 2]]) / 3.0
				if c.z >= sac.z and (c.y <= sac.y or absf(c.x) > 0.35):
					garde.append_array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
			a[Mesh.ARRAY_INDEX] = garde
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, origine.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		am.surface_set_material(s, m)
	_filtres[cle] = am
	return am


## Armes rangées visibles : armes = [[id, nœud du modèle], …] (armes de la barre rapide qu'on ne tient pas).
## Fusils, arc et armes longues dans le dos (deux au plus, en croix, par-dessus le sac), pistolet à la cuisse droite,
## couteau / matraque à la hanche gauche (devant la sacoche si elle est portée).
static func armes_rangees(modele: Node3D, armes: Array) -> void:
	var sk: Skeleton3D = null
	for s in modele.find_children("*", "Skeleton3D", true, false):
		sk = s
		break
	if sk == null:
		return
	for c in sk.get_children():
		if c.has_meta("arme_rangee"):
			sk.remove_child(c)
			c.queue_free()
	var sexe := "f_" if String(modele.get_meta("modele", "")).begins_with("f_") else "h_"
	var items: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Items")   # autoload (aussi depuis les outils)
	var n_dos := 0
	var cuisse := false
	var hanche := false
	for a in armes:
		var id: String = a[0]
		var n: Node3D = a[1]
		var it: Dictionary = items.info(id)
		var t: String = it.get("type", "")
		var os := ""
		var b := Basis.IDENTITY
		var pos := Vector3.ZERO
		if t == "gun" and it.get("famille", "") == "pistolet":
			if cuisse:
				continue
			cuisse = true
			os = "pelvis"
			pos = ARME_CUISSE
			b = Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))   # canon vers le bas, flanc vers l'extérieur
		elif t == "melee" and float(it.get("len", 0.0)) < 0.58:
			if hanche:
				continue
			hanche = true
			os = "pelvis"
			pos = ARME_HANCHE + (Vector3(0.0, 0.0, 0.09) if sk.get_meta("sacoche", false) else Vector3.ZERO)
			b = Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))    # lame vers le bas
		elif t in ["gun", "melee", "arc"]:
			if n_dos >= ARMES_DOS.size():
				continue
			var cfg: Array = ARMES_DOS[n_dos]
			n_dos += 1
			os = "spine_03"
			var ang := deg_to_rad(cfg[1] * (0.45 if t == "arc" else 1.0))   # arc (long) presque droit
			var d := Vector3(sin(ang), cos(ang), 0.0)          # vers le haut, penché vers une épaule
			var x := Vector3(0, 0, -1)                         # flanc de l'arme contre le dos
			if t == "arc":   # repère de l'arc : X doigts, Y avant, Z haut (branches)
				b = Basis(x, d.cross(x), d)
			else:            # canon (ou tête de l'arme) vers -Z
				b = Basis(x, (-d).cross(x), -d)
			pos = cfg[0] + Vector3(0, 0, float(sk.get_meta("dos_z", DOS_Z)) - 0.035 - 0.03 * (n_dos - 1))
		else:
			continue
		var ib := sk.find_bone(os)
		if ib < 0:
			continue
		var aj: Array = AJUST.get(sexe, {}).get(os, [Vector3.ZERO, 1.0])
		var repos := sk.get_bone_global_rest(ib)
		var ba := BoneAttachment3D.new()
		ba.bone_name = os
		ba.set_meta("equip", true)
		ba.set_meta("arme_rangee", true)
		sk.add_child(ba)
		ba.add_child(n)
		# centre de l'arme (boîte englobante de ses maillages) sur le point voulu
		var boite := AABB()
		var premier := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var ab: AABB = (n.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
			boite = ab if premier else boite.merge(ab)
			premier = false
		if t == "arc":
			boite = AABB()   # arc : centré sur sa poignée (origine), la corde allonge sa boîte
		var cible: Vector3 = repos.origin + pos * aj[1] + aj[0]
		n.transform = repos.affine_inverse() * Transform3D(b, cible - b * boite.get_center())
