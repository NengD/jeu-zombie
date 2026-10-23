extends AnimatableBody3D
## Pièce de construction de base posée au marteau : fondation, plancher, murs, porte, escalier…
## Les pièces d'une même base partagent une grille (cases de 3 m, étages de 3 m) portée par
## un nœud Base (son repère = dessus de la première fondation). Trois matériaux :
## bois -> tôle -> parpaing, de plus en plus solides. Les zombies tapent dans les pièces
## qui leur barrent le chemin (groupe « barricade »).

const S := 3.0        # côté d'une case
const H := 3.0        # hauteur d'un étage (plancher compris)
const EP := 0.2       # épaisseur des murs et planchers
const HM := H - EP    # hauteur d'un mur
const PORTE_L := 1.2  # ouverture de porte
const PORTE_H := 2.2

## genre : case (sur une case), bord (sur un côté de case), escalier, porte (dans un encadrement)
const PIECES := {
	"fondation": {"nom": "Fondation", "genre": "case", "cout": {"planche": 4, "clous": 4}, "pv": 1.5},
	"mur": {"nom": "Mur", "genre": "bord", "cout": {"planche": 3, "clous": 3}, "pv": 1.0},
	"plancher": {"nom": "Plancher / plafond", "genre": "case", "cout": {"planche": 3, "clous": 3}, "pv": 1.0},
	"mur_porte": {"nom": "Encadrement de porte", "genre": "bord", "cout": {"planche": 2, "clous": 2}, "pv": 0.9},
	"porte": {"nom": "Porte", "genre": "porte", "cout": {"planche": 2, "clous": 2, "ferraille": 1}, "pv": 0.7},
	"mur_fenetre": {"nom": "Mur à fenêtre", "genre": "bord", "cout": {"planche": 2, "clous": 3}, "pv": 0.85},
	"demi_mur": {"nom": "Demi-mur", "genre": "bord", "cout": {"planche": 2, "clous": 2}, "pv": 0.6},
	"escalier": {"nom": "Escalier", "genre": "escalier", "cout": {"planche": 4, "clous": 4}, "pv": 0.8},
}
const ORDRE := ["fondation", "mur", "plancher", "mur_porte", "porte", "mur_fenetre", "demi_mur", "escalier"]
const TIERS := [
	{"nom": "bois", "tex": "planches", "tuile": 1.6, "pv": 250.0},
	{"nom": "tôle", "tex": "tole", "tuile": 1.4, "pv": 550.0},
	{"nom": "parpaing", "tex": "parpaing", "tuile": 1.2, "pv": 1000.0},
]
## coût pour passer au matériau suivant (index du matériau visé)
const COUT_TIER := {1: {"ferraille": 3, "clous": 2}, 2: {"ciment": 2, "ferraille": 1}}

static var _mats := {}

var type := "mur"
var tier := 0
var cles: Array = []      # emplacements occupés dans la grille de la base
var rot := 0.0            # orientation dans le repère de la base
var pv := 250.0
var ouverte := false      # porte


# ---------------------------------------------------------------- données
static func cout_amelioration(t: String, vers: int) -> Dictionary:
	var k: float = {"fondation": 1.5, "demi_mur": 0.7, "porte": 0.7}.get(t, 1.0)
	var res := {}
	var base: Dictionary = COUT_TIER.get(vers, {})
	for m in base:
		res[m] = int(ceil(float(base[m]) * k))
	return res


static func tier_max(t: String) -> int:
	return 1 if t == "porte" else TIERS.size() - 1


static func texte_cout(cout: Dictionary) -> String:
	var parts := []
	for m in cout:
		parts.append("%s ×%d" % [Items.nom(m), cout[m]])
	return ", ".join(parts)


## Position et orientation d'un emplacement dans le repère de la base.
static func position_cle(cle: String) -> Vector3:
	var p := cle.split(":")
	var a := int(p[1])
	var b := int(p[2])
	var niv := int(p[3])
	match p[0]:
		"c", "e":
			return Vector3(a * S, niv * H, b * S)
	return Vector3(a * S / 2.0, niv * H, b * S / 2.0)


static func rotation_bord(cle: String) -> float:
	# côté entre deux cases voisines sur X : le mur court le long de Z
	return PI / 2.0 if absi(int(cle.split(":")[1])) % 2 == 1 else 0.0


static func materiau(n: int) -> StandardMaterial3D:
	if _mats.has(n):
		return _mats[n]
	var d: Dictionary = TIERS[n]
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	var tex: String = d.tex
	if ResourceLoader.exists("res://textures/%s_albedo.jpg" % tex):
		m.albedo_texture = load("res://textures/%s_albedo.jpg" % tex)
		if ResourceLoader.exists("res://textures/%s_normal.png" % tex):
			m.normal_enabled = true
			m.normal_texture = load("res://textures/%s_normal.png" % tex)
		if ResourceLoader.exists("res://textures/%s_rough.jpg" % tex):
			m.roughness_texture = load("res://textures/%s_rough.jpg" % tex)
			m.roughness = 1.0
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / float(d.tuile)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		m.albedo_color = [Color(0.55, 0.4, 0.25), Color(0.6, 0.62, 0.65), Color(0.7, 0.7, 0.68)][n]
	if n == 0:
		m.albedo_color = Color(0.78, 0.6, 0.42)   # bois brut (la texture de planches est claire)
	if n == 1 and tex == "tole":
		m.metallic = 0.5
	_mats[n] = m
	return m


## Construit les maillages (et les formes de collision si demandé) d'une pièce dans le nœud n.
static func maillages(n: Node3D, t: String, n_tier: int, collisions: bool, mat: Material = null) -> void:
	var m: Material = mat if mat else materiau(n_tier)
	var l := S + EP
	match t:
		"fondation":
			_boite(n, Vector3(S, 0.4, S), Vector3(0, -0.2, 0), m, collisions)
			_boite(n, Vector3(S - 0.12, 1.3, S - 0.12), Vector3(0, -1.05, 0), m, collisions)
		"plancher":
			_boite(n, Vector3(S, EP, S), Vector3(0, -EP / 2.0, 0), m, collisions)
		"mur":
			_boite(n, Vector3(l, HM, EP), Vector3(0, HM / 2.0, 0), m, collisions)
		"demi_mur":
			_boite(n, Vector3(l, 1.2, EP), Vector3(0, 0.6, 0), m, collisions)
		"mur_fenetre":
			var fl := 1.2
			var cote := (l - fl) / 2.0
			_boite(n, Vector3(l, 1.0, EP), Vector3(0, 0.5, 0), m, collisions)
			_boite(n, Vector3(l, HM - 2.0, EP), Vector3(0, 2.0 + (HM - 2.0) / 2.0, 0), m, collisions)
			for sx in [-1.0, 1.0]:
				_boite(n, Vector3(cote, 1.0, EP), Vector3(sx * (fl / 2.0 + cote / 2.0), 1.5, 0), m, collisions)
		"mur_porte":
			var cote := (l - PORTE_L) / 2.0
			_boite(n, Vector3(l, HM - PORTE_H, EP), Vector3(0, PORTE_H + (HM - PORTE_H) / 2.0, 0), m, collisions)
			for sx in [-1.0, 1.0]:
				_boite(n, Vector3(cote, PORTE_H, EP), Vector3(sx * (PORTE_L / 2.0 + cote / 2.0), PORTE_H / 2.0, 0), m, collisions)
		"porte":
			# origine sur la charnière, battant vers +X
			var pm: Material = mat if mat else (materiau(0) if n_tier == 0 else _metal_porte())
			_boite(n, Vector3(PORTE_L - 0.04, PORTE_H - 0.04, 0.08), Vector3(PORTE_L / 2.0, PORTE_H / 2.0, 0), pm, collisions)
			var poignee := StandardMaterial3D.new()
			poignee.albedo_color = Color(0.25, 0.25, 0.27)
			poignee.metallic = 0.8
			poignee.roughness = 0.35
			_boite(n, Vector3(0.12, 0.04, 0.16), Vector3(PORTE_L - 0.15, 1.05, 0), mat if mat else poignee, false)
		"escalier":
			# monte vers -Z, de l'étage (y = 0) à l'étage suivant (y = H)
			var nb := 10
			for k in nb:
				_boite(n, Vector3(1.6, H / nb, S / nb), Vector3(0, (k + 0.5) * H / nb, S / 2.0 - (k + 0.5) * S / nb), m, false)
			for sx in [-1.0, 1.0]:
				_boite(n, Vector3(0.08, 0.5, sqrt(S * S + H * H)), Vector3(sx * 0.84, H / 2.0, 0), m, false, Vector3(atan2(H, S), 0, 0))
			if collisions:
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(1.6, 0.12, sqrt(S * S + H * H))
				cs.shape = bs
				cs.position = Vector3(0, H / 2.0, 0)
				cs.rotation.x = atan2(H, S)
				n.add_child(cs)
	if mat == null:
		_habillage(n, t, n_tier)


# ---------------------------------------------------------------- habillage (sans collision)
## Détails selon le matériau : bois = poteaux d'angle et traverses ; tôle = panneaux ondulés sur une
## ossature ; parpaing = chaînages d'angle et chaperon. Portes et fenêtres : cadres, écharpe, barreaux.
static func _habillage(n: Node3D, t: String, n_tier: int) -> void:
	var l := S + EP
	var h: float = {"mur": HM, "demi_mur": 1.2, "mur_fenetre": HM, "mur_porte": HM}.get(t, 0.0)
	if h > 0.0:
		var poteau: StandardMaterial3D = _mat_detail("poteau") if n_tier < 2 else _mat_detail("beton")
		var p := 0.16 if n_tier < 2 else 0.24
		for sx in [-1.0, 1.0]:
			_deco(n, Vector3(p, h, EP + 0.06), Vector3(sx * (l / 2.0 - p / 2.0), h / 2.0, 0), poteau)
		match n_tier:
			0:
				# traverses horizontales des deux côtés (en haut et en bas)
				for y in ([0.25, h - 0.3] if h > 2.0 else [0.25, h - 0.15]):
					for sz in [-1.0, 1.0]:
						_deco(n, Vector3(l - 2.0 * p, 0.12, 0.04), Vector3(0, y, sz * (EP / 2.0 + 0.02)), poteau)
			1:
				# tôle ondulée sur les deux faces (hors ouvertures)
				for sz in [-1.0, 1.0]:
					for r in _zones_pleines(t, l, h):
						var mi := MeshInstance3D.new()
						mi.mesh = _ondule(r.size.x, r.size.y)
						mi.material_override = materiau(1)
						mi.position = Vector3(r.position.x + r.size.x / 2.0, r.position.y + r.size.y / 2.0, sz * (EP / 2.0 + 0.02))
						mi.rotation.y = 0.0 if sz > 0.0 else PI
						mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						n.add_child(mi)
			2:
				_deco(n, Vector3(l + 0.04, 0.08, EP + 0.1), Vector3(0, h + 0.04, 0), _mat_detail("beton"))   # chaperon
		var cadre: StandardMaterial3D = _mat_detail("poteau") if n_tier == 0 else _mat_detail("metal")
		if t == "mur_fenetre":
			for sz in [-1.0, 1.0]:
				_deco(n, Vector3(1.32, 0.08, 0.05), Vector3(0, 1.0, sz * (EP / 2.0 + 0.025)), cadre)
				_deco(n, Vector3(1.32, 0.08, 0.05), Vector3(0, 2.0, sz * (EP / 2.0 + 0.025)), cadre)
				for sx in [-1.0, 1.0]:
					_deco(n, Vector3(0.08, 1.0, 0.05), Vector3(sx * 0.62, 1.5, sz * (EP / 2.0 + 0.025)), cadre)
			# barreaux (tôle, parpaing) ou croisillon de planches (bois)
			if n_tier == 0:
				_deco(n, Vector3(1.3, 0.1, 0.04), Vector3(0, 1.5, 0), cadre, Vector3(0, 0, 0.6))
			else:
				for k in 5:
					_deco(n, Vector3(0.025, 1.0, 0.025), Vector3(-0.5 + k * 0.25, 1.5, 0), _mat_detail("metal"))
		elif t == "mur_porte":
			for sz in [-1.0, 1.0]:
				_deco(n, Vector3(PORTE_L + 0.16, 0.1, 0.05), Vector3(0, PORTE_H + 0.05, sz * (EP / 2.0 + 0.025)), cadre)
				for sx in [-1.0, 1.0]:
					_deco(n, Vector3(0.08, PORTE_H, 0.05), Vector3(sx * (PORTE_L / 2.0 + 0.04), PORTE_H / 2.0, sz * (EP / 2.0 + 0.025)), cadre)
	elif t == "porte":
		var cadre: StandardMaterial3D = _mat_detail("poteau") if n_tier == 0 else _mat_detail("metal")
		for sz in [-1.0, 1.0]:
			var z: float = sz * 0.055
			# traverses haute et basse, écharpe en Z (porte de grange) ; renforts sur la porte en tôle
			_deco(n, Vector3(PORTE_L - 0.12, 0.12, 0.03), Vector3(PORTE_L / 2.0, 0.3, z), cadre)
			_deco(n, Vector3(PORTE_L - 0.12, 0.12, 0.03), Vector3(PORTE_L / 2.0, PORTE_H - 0.3, z), cadre)
			var diag := Vector2(PORTE_L - 0.2, PORTE_H - 0.6)
			_deco(n, Vector3(0.11, diag.length(), 0.03), Vector3(PORTE_L / 2.0, PORTE_H / 2.0, z), cadre, Vector3(0, 0, -atan2(diag.x, diag.y)))
	elif t == "fondation" and n_tier > 0:
		_deco(n, Vector3(S + 0.04, 0.06, S + 0.04), Vector3(0, -0.4, 0), _mat_detail("beton"))


## Parties pleines d'un mur (rectangles dans le plan X/Y) : autour des ouvertures.
static func _zones_pleines(t: String, l: float, h: float) -> Array:
	var x0 := -l / 2.0 + 0.16
	var w := l - 0.32
	match t:
		"mur_fenetre":
			var c := (w - 1.2) / 2.0
			return [Rect2(x0, 0.0, w, 1.0), Rect2(x0, 2.0, w, h - 2.0), Rect2(x0, 1.0, c, 1.0), Rect2(0.6, 1.0, c, 1.0)]
		"mur_porte":
			var c2 := (w - PORTE_L) / 2.0
			return [Rect2(x0, PORTE_H, w, h - PORTE_H), Rect2(x0, 0.0, c2, PORTE_H), Rect2(PORTE_L / 2.0, 0.0, c2, PORTE_H)]
	return [Rect2(x0, 0.0, w, h)]


static var _ondules := {}


## Panneau de tôle ondulée (largeur X, hauteur Y), ondes verticales tous les 7,6 cm, face vers +Z.
static func _ondule(w: float, h: float) -> ArrayMesh:
	var cle := "%.2f_%.2f" % [w, h]
	if _ondules.has(cle):
		return _ondules[cle]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nb := maxi(2, int(w / 0.038))
	for i in nb:
		var xa := -w / 2.0 + w * i / nb
		var xb := -w / 2.0 + w * (i + 1) / nb
		var za := 0.02 * sin(i * PI / 2.0)
		var zb := 0.02 * sin((i + 1) * PI / 2.0)
		var nrm := Vector3(-(zb - za), 0, xb - xa).normalized()
		for v in [Vector3(xa, -h / 2.0, za), Vector3(xb, -h / 2.0, zb), Vector3(xb, h / 2.0, zb),
				Vector3(xa, -h / 2.0, za), Vector3(xb, h / 2.0, zb), Vector3(xa, h / 2.0, za)]:
			st.set_normal(nrm)
			st.set_uv(Vector2(v.x, v.y))
			st.add_vertex(v)
	var m := st.commit()
	_ondules[cle] = m
	return m


static func _mat_detail(nom: String) -> StandardMaterial3D:
	var cle := "detail_" + nom
	if _mats.has(cle):
		return _mats[cle]
	var m: StandardMaterial3D = materiau(0).duplicate() if nom == "poteau" else StandardMaterial3D.new()
	match nom:
		"poteau":
			m.albedo_color = Color(0.55, 0.4, 0.27)   # bois plus sombre que les planches
		"beton":
			m.albedo_color = Color(0.62, 0.61, 0.58)
			m.roughness = 0.95
		"metal":
			m.albedo_color = Color(0.3, 0.3, 0.32)
			m.metallic = 0.7
			m.roughness = 0.45
	_mats[cle] = m
	return m


static func _deco(n: Node3D, taille: Vector3, pos: Vector3, m: Material, r := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = r
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)


static func _metal_porte() -> StandardMaterial3D:
	if _mats.has("porte_metal"):
		return _mats["porte_metal"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.57, 0.6)
	m.metallic = 0.6
	m.roughness = 0.5
	if ResourceLoader.exists("res://textures/metal_peint_albedo.jpg"):
		m.albedo_texture = load("res://textures/metal_peint_albedo.jpg")
		m.uv1_triplanar = true
	_mats["porte_metal"] = m
	return m


static func _boite(n: Node3D, taille: Vector3, pos: Vector3, m: Material, collision: bool, r := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = r
	n.add_child(mi)
	if collision:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = taille
		cs.shape = bs
		cs.position = pos
		cs.rotation = r
		n.add_child(cs)


# ---------------------------------------------------------------- pièce
func setup(p_type: String, p_tier: int, p_cles: Array, p_rot: float) -> void:
	type = p_type
	tier = p_tier
	cles = p_cles
	rot = p_rot
	sync_to_physics = false
	collision_layer = Game.LAYER_WORLD | Game.LAYER_INTERACT
	collision_mask = 0
	add_to_group("construction")
	add_to_group("barricade")
	pv = pv_max()
	_reconstruire()


func pv_max() -> float:
	return float(TIERS[tier].pv) * float(PIECES[type].pv)


func nom_complet() -> String:
	return "%s en %s" % [PIECES[type].nom, TIERS[tier].nom]


func _reconstruire() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	maillages(self, type, tier, true)


## Place la pièce dans sa base (position tirée de son premier emplacement).
func placer() -> void:
	var cle: String = cles[0]
	if type == "porte":
		var r := rotation_bord(cle)
		position = position_cle(cle) + Basis(Vector3.UP, r) * Vector3(-PORTE_L / 2.0, 0, 0)
		rot = r
		rotation.y = rot + (deg_to_rad(95.0) if ouverte else 0.0)
	else:
		position = position_cle(cle)
		rotation.y = rot


func get_prompt() -> String:
	if type == "porte":
		return "[F] Fermer la porte" if ouverte else "[F] Ouvrir la porte"
	return ""


func interact(_player: Node) -> void:
	if type != "porte":
		return
	ouverte = not ouverte
	Game.play_3d("fouille", global_position + Vector3.UP, -6.0, 0.15, 20.0)
	var tw := create_tween()
	tw.tween_property(self, "rotation:y", rot + (deg_to_rad(95.0) if ouverte else 0.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Les zombies tapent dans la pièce qui leur barre le passage.
func take_damage(amount: float, _from: Node = null) -> void:
	if type == "porte" and ouverte:
		return
	pv -= amount
	Game.play_3d("coup", global_position + Vector3.UP, -3.0, 0.2, 35.0)
	if pv <= 0.0:
		Game.msg("%s a cédé !" % nom_complet())
		Game.play_3d("construire", global_position + Vector3.UP, 0.0, 0.2, 40.0)
		detruire()


## Retire la pièce de la grille (et la porte de son encadrement).
func detruire() -> void:
	var base := get_parent()
	if base and base.has_method("liberer"):
		base.liberer(self)
		if type == "mur_porte":
			var p = base.occ.get("p" + String(cles[0]).substr(1))
			if p and is_instance_valid(p):
				p.detruire()
	queue_free()


func vers_dict() -> Dictionary:
	return {"t": type, "n": tier, "c": cles, "r": rot, "pv": pv, "o": ouverte}


# ---------------------------------------------------------------- base
## Repère commun d'un ensemble de pièces, avec la grille des emplacements occupés.
class Base extends Node3D:
	var occ := {}     # cle -> pièce

	func _ready() -> void:
		add_to_group("base_construction")

	func ajouter(p: Node) -> void:
		add_child(p)
		for c in p.cles:
			occ[c] = p
		p.placer()

	func liberer(p: Node) -> void:
		for c in p.cles:
			if occ.get(c) == p:
				occ.erase(c)
		if occ.is_empty():
			queue_free()

	func a(cle: String) -> bool:
		return occ.has(cle) and is_instance_valid(occ[cle])

	func vers_dict() -> Dictionary:
		var pieces := []
		for c in get_children():
			if c.has_method("vers_dict"):
				pieces.append(c.vers_dict())
		return {"o": [global_position.x, global_position.y, global_position.z], "r": rotation.y, "p": pieces}
