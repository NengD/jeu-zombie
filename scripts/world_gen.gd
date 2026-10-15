extends Node3D
## Génère le monde : ville (majoritaire), campagne, points stratégiques,
## meubles fouillables et zombies gardiens.
## Toute la géométrie statique est regroupée par « chunks » pour les performances.
## Pour remplacer plus tard par des modèles Blender : remplacer les appels à
## _building() / _car() / arbres par des instances de scènes .glb.

const LootContainer = preload("res://scripts/loot_container.gd")

const BLOCK := 46.0      # taille d'un pâté de maisons (route comprise)
const ROAD := 10.0       # largeur des routes
const NB := 7            # nombre de pâtés par côté
const CHUNK := 64.0
const WALL_T := 0.3
const INT_H := 3.3       # hauteur intérieure du rez-de-chaussée
const DOOR_W := 1.8
const DOOR_H := 2.4

const C_ASPHALT := Color(0.16, 0.16, 0.17)
const C_DIRT := Color(0.36, 0.29, 0.2)
const C_LINE := Color(0.75, 0.72, 0.6)
const C_WINDOW := Color(0.09, 0.11, 0.14)
const C_FLOOR := Color(0.4, 0.36, 0.31)

const HOUSE_COLORS := [Color(0.62, 0.55, 0.45), Color(0.55, 0.42, 0.36), Color(0.7, 0.67, 0.58), Color(0.5, 0.52, 0.48), Color(0.6, 0.5, 0.4), Color(0.47, 0.36, 0.3)]
const CITY_COLORS := [Color(0.5, 0.5, 0.52), Color(0.42, 0.4, 0.38), Color(0.55, 0.5, 0.44), Color(0.36, 0.38, 0.42), Color(0.6, 0.58, 0.55), Color(0.45, 0.33, 0.28)]
const CAR_COLORS := [Color(0.5, 0.1, 0.1), Color(0.15, 0.2, 0.35), Color(0.6, 0.6, 0.6), Color(0.1, 0.1, 0.1), Color(0.35, 0.38, 0.3), Color(0.55, 0.45, 0.3), Color(0.8, 0.8, 0.78)]

# [nom, taille (long. le long du mur, hauteur, profondeur), couleur]
const FURN := {
	"maison": [["Armoire", Vector3(1.2, 2.0, 0.6), Color(0.4, 0.28, 0.18)], ["Commode", Vector3(1.0, 0.9, 0.5), Color(0.45, 0.32, 0.2)], ["Placard de cuisine", Vector3(1.8, 0.95, 0.6), Color(0.75, 0.73, 0.68)], ["Réfrigérateur", Vector3(0.8, 1.9, 0.7), Color(0.85, 0.85, 0.82)]],
	"magasin": [["Étagère", Vector3(2.0, 1.8, 0.5), Color(0.5, 0.5, 0.52)], ["Comptoir", Vector3(2.2, 1.0, 0.7), Color(0.4, 0.3, 0.22)], ["Frigo vitré", Vector3(1.6, 2.0, 0.7), Color(0.6, 0.7, 0.75)]],
	"bureau": [["Bureau", Vector3(1.6, 0.8, 0.8), Color(0.45, 0.35, 0.25)], ["Armoire métallique", Vector3(1.0, 1.9, 0.5), Color(0.45, 0.47, 0.5)], ["Casier", Vector3(0.6, 1.9, 0.5), Color(0.4, 0.42, 0.45)]],
	"quincaillerie": [["Étagère d'outils", Vector3(2.4, 1.8, 0.6), Color(0.55, 0.35, 0.15)], ["Étagère", Vector3(2.0, 1.8, 0.5), Color(0.5, 0.5, 0.52)], ["Bac à matériaux", Vector3(1.4, 0.8, 0.9), Color(0.4, 0.4, 0.3)]],
	"hopital": [["Armoire à pharmacie", Vector3(1.0, 1.9, 0.5), Color(0.85, 0.85, 0.88)], ["Chariot médical", Vector3(0.9, 1.0, 0.6), Color(0.7, 0.72, 0.75)], ["Bureau", Vector3(1.6, 0.8, 0.8), Color(0.45, 0.35, 0.25)]],
	"armurerie": [["Vitrine", Vector3(1.8, 1.0, 0.6), Color(0.3, 0.3, 0.32)], ["Râtelier", Vector3(2.0, 1.9, 0.4), Color(0.25, 0.2, 0.15)], ["Coffre", Vector3(1.0, 1.2, 0.8), Color(0.2, 0.2, 0.22)]],
	"police": [["Casier", Vector3(0.6, 1.9, 0.5), Color(0.3, 0.35, 0.45)], ["Bureau", Vector3(1.6, 0.8, 0.8), Color(0.45, 0.35, 0.25)], ["Armoire à armes", Vector3(1.4, 2.0, 0.6), Color(0.2, 0.22, 0.28)]],
	"militaire": [["Caisse militaire", Vector3(1.4, 0.7, 0.8), Color(0.3, 0.35, 0.2)], ["Casier militaire", Vector3(0.7, 1.9, 0.5), Color(0.28, 0.32, 0.2)], ["Caisse de munitions", Vector3(1.0, 0.5, 0.6), Color(0.25, 0.3, 0.18)]],
	"armurerie_mil": [["Râtelier militaire", Vector3(2.0, 1.9, 0.5), Color(0.22, 0.26, 0.16)], ["Caisse de munitions", Vector3(1.0, 0.5, 0.6), Color(0.25, 0.3, 0.18)], ["Caisse militaire", Vector3(1.4, 0.7, 0.8), Color(0.3, 0.35, 0.2)]],
	"station": [["Étagère", Vector3(2.0, 1.8, 0.5), Color(0.5, 0.5, 0.52)], ["Comptoir", Vector3(2.2, 1.0, 0.7), Color(0.4, 0.3, 0.22)], ["Frigo vitré", Vector3(1.6, 2.0, 0.7), Color(0.6, 0.7, 0.75)]],
	"ferme": [["Armoire", Vector3(1.2, 2.0, 0.6), Color(0.4, 0.28, 0.18)], ["Commode", Vector3(1.0, 0.9, 0.5), Color(0.45, 0.32, 0.2)], ["Placard de cuisine", Vector3(1.8, 0.95, 0.6), Color(0.6, 0.5, 0.4)], ["Coffre", Vector3(1.0, 0.7, 0.6), Color(0.35, 0.25, 0.15)]],
	"grange": [["Caisse en bois", Vector3(1.2, 1.0, 1.0), Color(0.5, 0.38, 0.22)], ["Établi de ferme", Vector3(2.0, 0.95, 0.8), Color(0.45, 0.33, 0.2)], ["Étagère", Vector3(2.0, 1.8, 0.5), Color(0.45, 0.4, 0.35)]],
}

var rng := RandomNumberGenerator.new()
var sts := {}         # chunk -> SurfaceTool
var bodies := {}      # chunk -> StaticBody3D
var mat: StandardMaterial3D
var reserved: Array = []   # Rect2 occupés (pour placer les arbres)
var guards: Array = []     # zombies à placer : {pos, kind, radius}
var trees: Array = []      # Vector3
var spawn_point := Vector3.ZERO
var spawn_zone: Dictionary = {}
var half := 0.0


func build(seed_value: int) -> Vector3:
	rng.seed = seed_value
	half = NB * BLOCK / 2.0
	Game.city_half = half
	mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.92
	_ground()
	_city()
	_countryside()
	_military_base(Vector3(-255, 0, -250))
	_trees()
	_commit()
	return spawn_point


# ================================================================ géométrie
func _chunk(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))


func _box(c: Vector3, s: Vector3, col: Color, solid := true) -> void:
	var k := _chunk(c)
	if not sts.has(k):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts[k] = st
	_box_faces(sts[k], c, s, col)
	if solid:
		if not bodies.has(k):
			var b := StaticBody3D.new()
			b.collision_layer = Game.LAYER_WORLD
			b.collision_mask = 0
			add_child(b)
			bodies[k] = b
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = s
		cs.shape = sh
		cs.position = c
		bodies[k].add_child(cs)


const FACES := [
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
]


func _box_faces(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	for f in FACES:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var hn := absf(n.dot(h))
		var hu := absf(u.dot(h))
		var hv := absf(v.dot(h))
		var base := c + n * hn
		var p0 := base - u * hu - v * hv
		var p1 := base + u * hu - v * hv
		var p2 := base + u * hu + v * hv
		var p3 := base - u * hu + v * hv
		var uv0 := Vector2(0, 0)
		var uv2 := Vector2(hu, hv)  # 1 unité de texture = 2 m
		# Godot : faces avant dans le sens horaire
		for p in [[p0, uv0], [p2, uv2], [p1, Vector2(uv2.x, 0)], [p0, uv0], [p3, Vector2(0, uv2.y)], [p2, uv2]]:
			st.set_normal(n)
			st.set_color(col)
			st.set_uv(p[1])
			st.add_vertex(p[0])


func _flat(r: Rect2, y: float, col: Color) -> void:
	_box(Vector3(r.position.x + r.size.x / 2.0, y, r.position.y + r.size.y / 2.0), Vector3(r.size.x, 0.02, r.size.y), col, false)


func _reserve(r: Rect2, map_col := Color(0, 0, 0, 0)) -> void:
	reserved.append(r)
	if map_col.a > 0.0:
		Game.map_rects.append({"rect": r, "color": map_col})


func _commit() -> void:
	for k in sts:
		var mi := MeshInstance3D.new()
		mi.mesh = sts[k].commit()
		mi.material_override = mat
		add_child(mi)
	sts.clear()


# ================================================================ sol
func _ground() -> void:
	var size := Game.map_half * 2.0 + 300.0
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.27, 0.31, 0.19)
	gm.roughness = 1.0
	mi.material_override = gm
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)
	# limites invisibles de la carte
	var m := Game.map_half
	for e in [[Vector3(m, 5, 0), Vector3(1, 10, 2 * m)], [Vector3(-m, 5, 0), Vector3(1, 10, 2 * m)], [Vector3(0, 5, m), Vector3(2 * m, 10, 1)], [Vector3(0, 5, -m), Vector3(2 * m, 10, 1)]]:
		var cs2 := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = e[1]
		cs2.shape = bs
		cs2.position = e[0]
		body.add_child(cs2)
	# sol bétonné de la ville
	_flat(Rect2(-half - 8, -half - 8, 2 * half + 16, 2 * half + 16), 0.006, Color(0.33, 0.33, 0.31))
	Game.map_rects.append({"rect": Rect2(-half - 8, -half - 8, 2 * half + 16, 2 * half + 16), "color": Color(0.22, 0.22, 0.22)})


# ================================================================ routes
## Route alignée sur un axe entre a et b (coordonnées x,z).
func _road(a: Vector2, b: Vector2, width: float, col := C_ASPHALT, lines := true) -> void:
	var r := Rect2(minf(a.x, b.x) - width / 2.0, minf(a.y, b.y) - width / 2.0, absf(b.x - a.x) + width, absf(b.y - a.y) + width)
	# découpe en tronçons pour le regroupement par chunk
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	var length := r.size.x if along_x else r.size.y
	var pieces := maxi(1, ceili(length / 40.0))
	for i in pieces:
		var pr: Rect2
		if along_x:
			pr = Rect2(r.position.x + r.size.x * i / pieces, r.position.y, r.size.x / pieces, r.size.y)
		else:
			pr = Rect2(r.position.x, r.position.y + r.size.y * i / pieces, r.size.x, r.size.y / pieces)
		_flat(pr, 0.02, col)
	_reserve(r, Color(0.12, 0.12, 0.12) if col == C_ASPHALT else Color(0.35, 0.28, 0.18))
	if lines:
		var d := 0.0
		while d < length - 4.0:
			if along_x:
				_box(Vector3(r.position.x + d + 2.0, 0.035, (a.y + b.y) / 2.0), Vector3(3.0, 0.01, 0.15), C_LINE, false)
			else:
				_box(Vector3((a.x + b.x) / 2.0, 0.035, r.position.y + d + 2.0), Vector3(0.15, 0.01, 3.0), C_LINE, false)
			d += 7.0


func _car(c: Vector3, along_x: bool, col: Color) -> void:
	var body := Vector3(4.3, 0.9, 1.9) if along_x else Vector3(1.9, 0.9, 4.3)
	var cab := Vector3(2.2, 0.7, 1.75) if along_x else Vector3(1.75, 0.7, 2.2)
	_box(c + Vector3(0, 0.75, 0), body, col)
	_box(c + Vector3(0, 1.55, 0), cab, col.darkened(0.15))
	# vitres
	_box(c + Vector3(0, 1.55, 0), cab + Vector3(0.04, -0.2, 0.04), C_WINDOW, false)
	# roues (sombres, visuelles)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var off := Vector3(sx * 1.4, 0.35, sz * 0.85) if along_x else Vector3(sz * 0.85, 0.35, sx * 1.4)
			_box(c + off, Vector3(0.7, 0.7, 0.3) if along_x else Vector3(0.3, 0.7, 0.7), Color(0.05, 0.05, 0.05), false)


# ================================================================ bâtiments
func _building(c: Vector3, w: float, d: float, h: float, col: Color, doors: Array, kind: String, label := "", partition := false, furn := -1, map_col := Color(0.5, 0.5, 0.5)) -> Dictionary:
	var t := WALL_T
	var x0 := c.x - w / 2.0
	var x1 := c.x + w / 2.0
	var z0 := c.z - d / 2.0
	var z1 := c.z + d / 2.0
	h = maxf(h, INT_H + 0.3)
	_box(Vector3(c.x, 0.015, c.z), Vector3(w - 0.1, 0.03, d - 0.1), C_FLOOR, false)
	var door_list: Array = []
	var outward := {"n": Vector3(0, 0, -1), "s": Vector3(0, 0, 1), "w": Vector3(-1, 0, 0), "e": Vector3(1, 0, 0)}
	for side in ["n", "s", "w", "e"]:
		var along_x: bool = side == "n" or side == "s"
		var fixed: float
		match side:
			"n": fixed = z0 + t / 2.0
			"s": fixed = z1 - t / 2.0
			"w": fixed = x0 + t / 2.0
			_: fixed = x1 - t / 2.0
		var a0: float = x0 if along_x else z0 + t
		var a1: float = x1 if along_x else z1 - t
		var has_door: bool = side in doors
		var dc := (a0 + a1) / 2.0
		if has_door:
			var spread := maxf(0.0, (a1 - a0) / 2.0 - 2.5)
			if partition and not along_x:
				dc = c.z + (d / 4.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			else:
				dc += rng.randf_range(-spread, spread) * 0.5
			var dp := Vector3(dc, 0, fixed) if along_x else Vector3(fixed, 0, dc)
			var o: Vector3 = outward[side]
			door_list.append({"pos": dp, "out": dp + o * 1.5, "inn": dp - o * 1.5})
			_wall(along_x, fixed, a0, dc - DOOR_W / 2.0, 0.0, INT_H, col)
			_wall(along_x, fixed, dc + DOOR_W / 2.0, a1, 0.0, INT_H, col)
			_wall(along_x, fixed, dc - DOOR_W / 2.0, dc + DOOR_W / 2.0, DOOR_H, INT_H, col.darkened(0.2))
		else:
			_wall(along_x, fixed, a0, a1, 0.0, INT_H, col)
		# fenêtres décoratives (façade extérieure)
		var face: float = fixed + (outward[side].z if along_x else outward[side].x) * (t / 2.0 + 0.02)
		var y := 1.1
		while y + 1.0 < h:
			var a := a0 + 2.0
			while a < a1 - 2.0:
				var skip := has_door and y < INT_H and absf(a - dc) < 2.0
				if not skip:
					var wc := C_WINDOW if rng.randf() > 0.12 else Color(0.02, 0.02, 0.02)
					if along_x:
						_box(Vector3(a, y + 0.55, face), Vector3(1.3, 1.1, 0.05), wc, false)
					else:
						_box(Vector3(face, y + 0.55, a), Vector3(0.05, 1.1, 1.3), wc, false)
				a += 3.6
			y += 3.4 if y < INT_H else 3.2
	# plafond + étages (volume plein au-dessus du rez-de-chaussée)
	_box(Vector3(c.x, INT_H + 0.15, c.z), Vector3(w, 0.3, d), col.darkened(0.25))
	if h > INT_H + 0.6:
		_box(Vector3(c.x, (INT_H + 0.3 + h) / 2.0, c.z), Vector3(w, h - INT_H - 0.3, d), col)
	_box(Vector3(c.x, h + 0.1, c.z), Vector3(w + 0.3, 0.2, d + 0.3), col.darkened(0.45), false)
	# cloison intérieure
	var placed: Array = []
	if partition and d >= 12.0:
		var gx := rng.randf_range(x0 + 2.5, x1 - 2.5)
		_wall(true, c.z, x0 + t, gx - 1.0, 0.0, INT_H, col.lightened(0.15))
		_wall(true, c.z, gx + 1.0, x1 - t, 0.0, INT_H, col.lightened(0.15))
		placed.append(Rect2(x0, c.z - 0.5, gx - 1.3 - x0, 1.0))
		placed.append(Rect2(gx + 1.3, c.z - 0.5, x1 - gx - 1.3, 1.0))
		placed.append(Rect2(gx - 1.5, c.z - 2.0, 3.0, 4.0))  # garder le passage libre
	var zone := {
		"aabb": AABB(Vector3(x0 + t, 0.0, z0 + t), Vector3(w - 2 * t, INT_H, d - 2 * t)),
		"doors": door_list, "kind": kind, "name": label, "center": c,
	}
	Game.zones.append(zone)
	_reserve(Rect2(x0 - 1.0, z0 - 1.0, w + 2.0, d + 2.0))
	Game.map_rects.append({"rect": Rect2(x0, z0, w, d), "color": map_col})
	if furn < 0:
		furn = clampi(int(w * d / 28.0), 2, 12)
	_furnish(zone, kind, furn, placed)
	return zone


func _wall(along_x: bool, fixed: float, a0: float, a1: float, y0: float, y1: float, col: Color) -> void:
	if a1 - a0 < 0.05 or y1 - y0 < 0.05:
		return
	var mid := (a0 + a1) / 2.0
	var cy := (y0 + y1) / 2.0
	if along_x:
		_box(Vector3(mid, cy, fixed), Vector3(a1 - a0, y1 - y0, WALL_T), col)
	else:
		_box(Vector3(fixed, cy, mid), Vector3(WALL_T, y1 - y0, a1 - a0), col)


func _furnish(zone: Dictionary, kind: String, count: int, placed: Array) -> void:
	var furn_set: Array = FURN.get(kind, FURN["maison"])
	var ab: AABB = zone.aabb
	var ix0 := ab.position.x
	var ix1 := ab.position.x + ab.size.x
	var iz0 := ab.position.z
	var iz1 := ab.position.z + ab.size.z
	var n := 0
	var tries := 0
	while n < count and tries < count * 15:
		tries += 1
		var f: Array = furn_set[rng.randi() % furn_set.size()]
		var sz: Vector3 = f[1]
		var side: String = ["n", "s", "w", "e"][rng.randi() % 4]
		var size3: Vector3
		var pos: Vector3
		if side == "n" or side == "s":
			if ix1 - ix0 < sz.x + 0.4:
				continue
			size3 = sz
			pos.x = rng.randf_range(ix0 + sz.x / 2.0 + 0.1, ix1 - sz.x / 2.0 - 0.1)
			pos.z = iz0 + sz.z / 2.0 + 0.03 if side == "n" else iz1 - sz.z / 2.0 - 0.03
		else:
			if iz1 - iz0 < sz.x + 0.4:
				continue
			size3 = Vector3(sz.z, sz.y, sz.x)
			pos.z = rng.randf_range(iz0 + sz.x / 2.0 + 0.1, iz1 - sz.x / 2.0 - 0.1)
			pos.x = ix0 + sz.z / 2.0 + 0.03 if side == "w" else ix1 - sz.z / 2.0 - 0.03
		var rect := Rect2(pos.x - size3.x / 2.0, pos.z - size3.z / 2.0, size3.x, size3.z)
		var ok := true
		for r in placed:
			if r.grow(0.25).intersects(rect):
				ok = false
				break
		if ok:
			for dp in zone.doors:
				if Vector2(dp.pos.x, dp.pos.z).distance_to(Vector2(pos.x, pos.z)) < 2.6:
					ok = false
					break
		if not ok:
			continue
		placed.append(rect)
		_container(pos, size3, f[2], f[0], kind)
		n += 1


func _container(pos: Vector3, size: Vector3, col: Color, label: String, table: String, rolls := -1) -> Node3D:
	var c = LootContainer.new()
	if rolls < 0:
		rolls = 1 + (1 if size.x * size.y * size.z > 1.0 else 0) + (1 if rng.randf() < 0.35 else 0)
	c.setup(label, table, size, col, rolls)
	add_child(c)
	c.position = pos
	return c


func _residents(zone: Dictionary, chance: float, max_n: int, kind := "civil") -> void:
	if zone == spawn_zone or rng.randf() > chance:
		return
	for i in rng.randi_range(1, max_n):
		guards.append({"pos": _random_in(zone, 1.2), "kind": kind, "radius": 4.0})


func _random_in(zone: Dictionary, margin: float) -> Vector3:
	var ab: AABB = zone.aabb
	return Vector3(rng.randf_range(ab.position.x + margin, ab.end.x - margin), 0.1, rng.randf_range(ab.position.z + margin, ab.end.z - margin))


func _poi(label: String, pos: Vector3, col: Color) -> void:
	Game.pois.append({"name": label, "pos": pos, "color": col})


# ================================================================ ville
func _city() -> void:
	for i in NB + 1:
		var c := -half + i * BLOCK
		_road(Vector2(c, -half - 5), Vector2(c, half + 5), ROAD)
		_road(Vector2(-half - 5, c), Vector2(half + 5, c), ROAD)
	# lampadaires éteints aux carrefours
	for i in NB + 1:
		for j in NB + 1:
			var p := Vector3(-half + i * BLOCK + 6.0, 0, -half + j * BLOCK + 6.0)
			_box(p + Vector3(0, 3.0, 0), Vector3(0.18, 6.0, 0.18), Color(0.2, 0.2, 0.22))
			_box(p + Vector3(-0.6, 6.0, 0), Vector3(1.4, 0.15, 0.3), Color(0.2, 0.2, 0.22), false)
	var specials := {
		Vector2i(2, 2): "police", Vector2i(4, 4): "hopital", Vector2i(4, 2): "supermarche",
		Vector2i(2, 4): "armurerie", Vector2i(1, 3): "quincaillerie", Vector2i(3, 3): "parc",
		Vector2i(5, 1): "parc",
	}
	var spawn_block := Vector2i(1, NB - 1)
	for bi in NB:
		for bj in NB:
			var bc := Vector3(-half + (bi + 0.5) * BLOCK, 0, -half + (bj + 0.5) * BLOCK)
			var key := Vector2i(bi, bj)
			var outer := bi == 0 or bj == 0 or bi == NB - 1 or bj == NB - 1
			if specials.has(key):
				match specials[key]:
					"police": _police(bc)
					"hopital": _hospital(bc)
					"supermarche": _supermarket(bc)
					"armurerie": _small_special(bc, "armurerie", "Armurerie", Color(0.3, 0.28, 0.27), Color(0.75, 0.3, 0.2))
					"quincaillerie": _small_special(bc, "quincaillerie", "Quincaillerie", Color(0.55, 0.45, 0.3), Color(0.8, 0.6, 0.2))
					"parc": _park(bc)
			elif outer:
				_residential(bc, key == spawn_block)
			elif rng.randf() < 0.35:
				_apartments(bc)
			else:
				_commercial(bc)
	# voitures abandonnées
	for n in 55:
		var i := rng.randi_range(0, NB)
		var along := rng.randf_range(-half, half)
		var line := -half + i * BLOCK
		if fposmod(along + half, BLOCK) < 9.0 or fposmod(along + half, BLOCK) > BLOCK - 9.0:
			continue
		var lane := 2.4 * (1.0 if rng.randf() < 0.5 else -1.0)
		var col: Color = CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(rng.randf_range(0.0, 0.35))
		if rng.randf() < 0.5:
			_car(Vector3(along, 0, line + lane), true, col)
		else:
			_car(Vector3(line + lane, 0, along), false, col)


func _doors_toward_roads(qx: float, qz: float) -> Array:
	var opts := []
	opts.append("e" if qx > 0 else "w")
	opts.append("s" if qz > 0 else "n")
	return [opts[rng.randi() % 2]]


func _residential(bc: Vector3, is_spawn: bool) -> void:
	var first := true
	for qx in [-1.0, 1.0]:
		for qz in [-1.0, 1.0]:
			var w := rng.randf_range(9.0, 12.5)
			var d := rng.randf_range(8.0, 11.0)
			var c := bc + Vector3(qx * 8.5, 0, qz * 8.5)
			var h := INT_H + 0.3 if rng.randf() < 0.5 else 6.6
			var col: Color = HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()]
			var doors := _doors_toward_roads(qx, qz)
			var z := _building(c, w, d, h, col, doors, "maison", "", false, -1, Color(0.45, 0.4, 0.35))
			if is_spawn and first:
				spawn_zone = z
				var dr: Dictionary = z.doors[0]
				spawn_point = dr.out + (dr.out - dr.pos).normalized() * 1.0
				first = false
			else:
				_residents(z, 0.4, 2)
			# petit muret de jardin
			if rng.randf() < 0.5:
				var gx: float = bc.x + qx * 17.0
				_box(Vector3(gx, 0.4, bc.z + qz * 8.5), Vector3(0.25, 0.8, 14.0), Color(0.45, 0.43, 0.4))
	_reserve(Rect2(bc.x - 18, bc.z - 18, 36, 36))


func _commercial(bc: Vector3) -> void:
	for sx in [-1.0, 1.0]:
		var w := rng.randf_range(13.0, 16.0)
		var d := rng.randf_range(26.0, 33.0)
		var h := rng.randf_range(7.0, 16.0)
		var col: Color = CITY_COLORS[rng.randi() % CITY_COLORS.size()]
		var kind: String = ["magasin", "bureau", "maison", "magasin"][rng.randi() % 4]
		var doors := ["e" if sx > 0 else "w"]
		if rng.randf() < 0.5:
			doors.append("s" if rng.randf() < 0.5 else "n")
		var z := _building(bc + Vector3(sx * 9.5, 0, 0), w, d, h, col, doors, kind, "", true, -1, Color(0.5, 0.5, 0.5))
		_residents(z, 0.55, 3)


func _apartments(bc: Vector3) -> void:
	var w := rng.randf_range(26.0, 32.0)
	var d := rng.randf_range(26.0, 32.0)
	var col: Color = CITY_COLORS[rng.randi() % CITY_COLORS.size()]
	var z := _building(bc, w, d, rng.randf_range(14.0, 26.0), col, ["n", "s"], "maison", "", true, 12, Color(0.47, 0.47, 0.5))
	_residents(z, 0.8, 4)


func _park(bc: Vector3) -> void:
	_flat(Rect2(bc.x - 18, bc.z - 18, 36, 36), 0.01, Color(0.25, 0.33, 0.18))
	Game.map_rects.append({"rect": Rect2(bc.x - 18, bc.z - 18, 36, 36), "color": Color(0.2, 0.35, 0.18)})
	for i in 14:
		trees.append(bc + Vector3(rng.randf_range(-16, 16), 0, rng.randf_range(-16, 16)))
	for i in 5:
		var p := bc + Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
		_box(p + Vector3(0, 0.45, 0), Vector3(1.8, 0.12, 0.5), Color(0.4, 0.28, 0.16))
	_box(bc + Vector3(0, 1.0, 0), Vector3(2.5, 2.0, 2.5), Color(0.5, 0.5, 0.48))
	_box(bc + Vector3(0, 3.0, 0), Vector3(0.8, 2.0, 0.8), Color(0.35, 0.4, 0.38))
	_reserve(Rect2(bc.x - 2, bc.z - 2, 4, 4))


func _police(bc: Vector3) -> void:
	var z := _building(bc + Vector3(0, 0, -3), 28.0, 20.0, 8.0, Color(0.38, 0.42, 0.5), ["s", "n"], "police", "Poste de police", true, 14, Color(0.25, 0.4, 0.75))
	# bandeau bleu
	_box(bc + Vector3(0, 3.0, 7.0 + 0.2), Vector3(10.0, 0.6, 0.1), Color(0.1, 0.2, 0.6), false)
	for i in 3:
		var col := Color(0.9, 0.9, 0.9) if i % 2 == 0 else Color(0.1, 0.15, 0.4)
		_car(bc + Vector3(-8.0 + i * 6.0, 0, 13.0), true, col)
	_poi("Poste de police", bc, Color(0.35, 0.55, 1.0))
	for i in 5:
		guards.append({"pos": _random_in(z, 1.0), "kind": "police", "radius": 6.0})
	for i in 4:
		guards.append({"pos": bc + Vector3(rng.randf_range(-12, 12), 0.1, rng.randf_range(10, 15)), "kind": "police", "radius": 8.0})


func _hospital(bc: Vector3) -> void:
	var z := _building(bc, 32.0, 26.0, 16.0, Color(0.78, 0.78, 0.75), ["s", "e"], "hopital", "Hôpital", true, 16, Color(0.85, 0.85, 0.85))
	_box(bc + Vector3(0, 5.5, 13.2), Vector3(3.0, 0.8, 0.1), Color(0.8, 0.1, 0.1), false)
	_box(bc + Vector3(0, 5.5, 13.2), Vector3(0.8, 3.0, 0.1), Color(0.8, 0.1, 0.1), false)
	_poi("Hôpital", bc, Color(1.0, 0.35, 0.35))
	for i in 7:
		guards.append({"pos": _random_in(z, 1.0), "kind": "patient", "radius": 6.0})
	for i in 4:
		guards.append({"pos": bc + Vector3(rng.randf_range(-14, 14), 0.1, 15.5), "kind": "patient", "radius": 8.0})


func _supermarket(bc: Vector3) -> void:
	var z := _building(bc + Vector3(0, 0, -3), 32.0, 24.0, 6.5, Color(0.6, 0.55, 0.48), ["s"], "magasin", "Supermarché", false, 8, Color(0.85, 0.65, 0.3))
	# rayons au centre
	var ab: AABB = z.aabb
	for i in 4:
		var x := ab.position.x + 6.0 + i * 5.5
		_container(Vector3(x, 0, ab.get_center().z - 1.0), Vector3(1.0, 1.6, 9.0), Color(0.55, 0.55, 0.58), "Rayon", "magasin", 3)
	for i in 3:
		_car(bc + Vector3(-10.0 + i * 9.0, 0, 14.0), false, CAR_COLORS[rng.randi() % CAR_COLORS.size()])
	_poi("Supermarché", bc, Color(1.0, 0.75, 0.3))
	for i in 6:
		guards.append({"pos": _random_in(z, 1.0), "kind": "civil", "radius": 8.0})


func _small_special(bc: Vector3, kind: String, label: String, col: Color, map_col: Color) -> void:
	var z := _building(bc + Vector3(-8.0, 0, -8.0), 15.0, 12.0, 4.5, col, ["n", "w"], kind, label, false, 8, map_col)
	_poi(label, bc + Vector3(-8.0, 0, -8.0), map_col)
	for i in 3:
		guards.append({"pos": _random_in(z, 1.0), "kind": "civil", "radius": 5.0})
	# maisons sur le reste du pâté
	for q in [Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var c := bc + Vector3(q.x * 8.5, 0, q.y * 8.5)
		var hz := _building(c, rng.randf_range(9, 12), rng.randf_range(8, 11), 6.6, HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()], _doors_toward_roads(q.x, q.y), "maison", "", false, -1, Color(0.45, 0.4, 0.35))
		_residents(hz, 0.4, 2)


# ================================================================ campagne
func _countryside() -> void:
	var hx := -half + 4 * BLOCK   # autoroute nord-sud
	var hz := -half + 3 * BLOCK   # autoroute est-ouest
	var m := Game.map_half
	_road(Vector2(hx, half + 5), Vector2(hx, m), 11.0)
	_road(Vector2(hx, -m), Vector2(hx, -half - 5), 11.0)
	_road(Vector2(half + 5, hz), Vector2(m, hz), 11.0)
	_road(Vector2(-m, hz), Vector2(-half - 5, hz), 11.0)
	# voitures sur l'autoroute
	for i in 18:
		var t := rng.randf_range(half + 20, m - 20) * (1.0 if rng.randf() < 0.5 else -1.0)
		var col: Color = CAR_COLORS[rng.randi() % CAR_COLORS.size()].darkened(0.3)
		if rng.randf() < 0.5:
			_car(Vector3(hx + rng.randf_range(-3, 3), 0, t), false, col)
		else:
			_car(Vector3(t, 0, hz + rng.randf_range(-3, 3)), true, col)
	_gas_station(Vector3(half + 70.0, 0, hz + 20.0))
	_farm(Vector3(-250, 0, 210), hx, hz, "Ferme des Peupliers")
	_farm(Vector3(250, 0, 245), hx, hz, "Ferme du Moulin")
	_farm(Vector3(265, 0, -215), hx, hz, "Ferme Bellevue")
	# maisons isolées le long des routes
	for i in 7:
		var along := rng.randf_range(half + 30, m - 40) * (1.0 if rng.randf() < 0.5 else -1.0)
		var off := 18.0 * (1.0 if rng.randf() < 0.5 else -1.0)
		var c: Vector3
		var doors: Array
		if rng.randf() < 0.5:
			c = Vector3(hx + off, 0, along)
			doors = ["w" if off > 0 else "e"]
		else:
			c = Vector3(along, 0, hz + off)
			doors = ["n" if off > 0 else "s"]
		if _overlaps(Rect2(c.x - 8, c.z - 8, 16, 16)):
			continue
		var z := _building(c, rng.randf_range(9, 12), rng.randf_range(8, 10), 6.6, HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()], doors, "maison", "", false, -1, Color(0.45, 0.4, 0.35))
		_residents(z, 0.5, 2)


func _overlaps(r: Rect2) -> bool:
	for o in reserved:
		if o.intersects(r):
			return true
	return false


func _gas_station(c: Vector3) -> void:
	var z := _building(c + Vector3(0, 0, 6), 13.0, 9.0, 4.0, Color(0.7, 0.68, 0.6), ["n"], "station", "Station-service", false, 6, Color(0.95, 0.85, 0.3))
	# auvent + pompes
	for p in [Vector3(-6, 0, -6), Vector3(6, 0, -6), Vector3(-6, 0, -1), Vector3(6, 0, -1)]:
		_box(c + p + Vector3(0, 2.4, 0), Vector3(0.4, 4.8, 0.4), Color(0.8, 0.8, 0.8))
	_box(c + Vector3(0, 5.0, -3.5), Vector3(15.0, 0.4, 8.0), Color(0.8, 0.15, 0.1))
	for x in [-2.5, 2.5]:
		_box(c + Vector3(x, 0.8, -3.5), Vector3(0.8, 1.6, 0.6), Color(0.85, 0.85, 0.8))
	_reserve(Rect2(c.x - 8, c.z - 8, 16, 12))
	_poi("Station-service", c, Color(1.0, 0.9, 0.3))
	for i in 2:
		guards.append({"pos": _random_in(z, 1.0), "kind": "civil", "radius": 6.0})


func _farm(c: Vector3, hx: float, hz: float, label: String) -> void:
	var house := _building(c, 12.0, 10.0, 6.6, Color(0.66, 0.6, 0.5), ["s"], "ferme", label, false, 6, Color(0.6, 0.45, 0.3))
	var barn := _building(c + Vector3(20, 0, -2), 16.0, 20.0, 8.0, Color(0.5, 0.18, 0.13), ["w", "e"], "grange", "Grange", false, 7, Color(0.6, 0.25, 0.2))
	_residents(house, 0.7, 2)
	_residents(barn, 0.8, 3)
	_poi(label, c, Color(0.85, 0.6, 0.35))
	# champs et clôtures
	for i in 4:
		var dir := signf(c.z)
		var fc := c + Vector3(-30.0 + (i % 2) * 48.0, 0, dir * (30.0 + floorf(i / 2.0) * 34.0))
		var r := Rect2(fc.x - 20, fc.z - 15, 40, 30)
		if _overlaps(r):
			continue
		var fcol: Color = [Color(0.45, 0.4, 0.2), Color(0.35, 0.3, 0.18), Color(0.3, 0.38, 0.18)][i % 3]
		_flat(r, 0.012, fcol)
		Game.map_rects.append({"rect": r, "color": fcol.darkened(0.2)})
		reserved.append(r)
		# clôture (avec ouverture)
		_box(Vector3(fc.x, 0.5, r.position.y), Vector3(40, 1.0, 0.12), Color(0.4, 0.3, 0.2))
		_box(Vector3(fc.x - 10.5, 0.5, r.end.y), Vector3(19, 1.0, 0.12), Color(0.4, 0.3, 0.2))
		_box(Vector3(fc.x + 10.5, 0.5, r.end.y), Vector3(19, 1.0, 0.12), Color(0.4, 0.3, 0.2))
	# chemin de terre jusqu'à la route
	var start := Vector2(c.x, c.z + 12.0)
	if absf(c.x - hx) < absf(c.z - hz):
		_road(start, Vector2(hx, start.y), 5.0, C_DIRT, false)
	else:
		_road(start, Vector2(start.x, hz), 5.0, C_DIRT, false)


# ================================================================ base militaire
func _military_base(c: Vector3) -> void:
	var w := 100.0
	var d := 90.0
	var x0 := c.x - w / 2.0
	var x1 := c.x + w / 2.0
	var z0 := c.z - d / 2.0
	var z1 := c.z + d / 2.0
	var wall_col := Color(0.5, 0.5, 0.47)
	var hgt := 4.5
	_flat(Rect2(x0, z0, w, d), 0.01, Color(0.4, 0.38, 0.33))
	Game.map_rects.append({"rect": Rect2(x0, z0, w, d), "color": Color(0.3, 0.35, 0.22)})
	# murs d'enceinte : portail à l'est, brèche au nord
	_box(Vector3(c.x, hgt / 2.0, z1), Vector3(w, hgt, 0.6), wall_col)
	_box(Vector3(x0, hgt / 2.0, c.z), Vector3(0.6, hgt, d), wall_col)
	var breach_x := c.x - 18.0
	_box(Vector3((x0 + breach_x - 1.6) / 2.0, hgt / 2.0, z0), Vector3(breach_x - 1.6 - x0, hgt, 0.6), wall_col)
	_box(Vector3((breach_x + 1.6 + x1) / 2.0, hgt / 2.0, z0), Vector3(x1 - breach_x - 1.6, hgt, 0.6), wall_col)
	for i in 4:  # gravats de la brèche
		_box(Vector3(breach_x + rng.randf_range(-3, 3), 0.3, z0 + rng.randf_range(-2.5, 2.5)), Vector3(rng.randf_range(0.6, 1.2), 0.6, rng.randf_range(0.6, 1.2)), wall_col.darkened(0.2), false)
	var gate := 4.0
	_box(Vector3(x1, hgt / 2.0, (z0 + c.z - gate) / 2.0), Vector3(0.6, hgt, c.z - gate - z0), wall_col)
	_box(Vector3(x1, hgt / 2.0, (c.z + gate + z1) / 2.0), Vector3(0.6, hgt, z1 - c.z - gate), wall_col)
	# barbelés (visuels)
	_box(Vector3(c.x, hgt + 0.3, z1), Vector3(w, 0.5, 0.3), Color(0.25, 0.25, 0.25), false)
	_box(Vector3(x0, hgt + 0.3, c.z), Vector3(0.3, 0.5, d), Color(0.25, 0.25, 0.25), false)
	# miradors
	for p in [Vector3(x0 + 3, 0, z0 + 3), Vector3(x1 - 3, 0, z0 + 3), Vector3(x0 + 3, 0, z1 - 3), Vector3(x1 - 3, 0, z1 - 3)]:
		for o in [Vector3(-1.5, 0, -1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, 1.5)]:
			_box(p + o + Vector3(0, 3.5, 0), Vector3(0.3, 7.0, 0.3), Color(0.35, 0.3, 0.22))
		_box(p + Vector3(0, 7.1, 0), Vector3(4.0, 0.25, 4.0), Color(0.35, 0.3, 0.22))
		_box(p + Vector3(0, 8.6, 0), Vector3(4.2, 0.2, 4.2), Color(0.3, 0.33, 0.22), false)
	# bâtiments
	var hangar := _building(c + Vector3(22, 0, -24), 26.0, 18.0, 9.0, Color(0.4, 0.43, 0.35), ["w", "n"], "militaire", "Hangar", false, 10, Color(0.35, 0.42, 0.28))
	var cas1 := _building(c + Vector3(-25, 0, 25), 24.0, 10.0, 4.0, Color(0.45, 0.47, 0.38), ["n"], "militaire", "Caserne", false, 8, Color(0.35, 0.42, 0.28))
	var cas2 := _building(c + Vector3(10, 0, 30), 24.0, 10.0, 4.0, Color(0.45, 0.47, 0.38), ["n"], "militaire", "Caserne", false, 8, Color(0.35, 0.42, 0.28))
	var arm := _building(c + Vector3(-35, 0, -25), 12.0, 10.0, 4.0, Color(0.32, 0.35, 0.28), ["e"], "armurerie_mil", "Armurerie militaire", false, 6, Color(0.6, 0.7, 0.3))
	# camions et sacs de sable
	_car(c + Vector3(30, 0, 5), false, Color(0.28, 0.32, 0.2))
	_car(c + Vector3(36, 0, 8), false, Color(0.28, 0.32, 0.2))
	_car(c + Vector3(-10, 0, -5), true, Color(0.28, 0.32, 0.2))
	for p in [Vector3(42, 0, -8), Vector3(42, 0, 8), Vector3(10, 0, 0), Vector3(-15, 0, 10), Vector3(-30, 0, -8)]:
		_box(c + p + Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 5.0), Color(0.45, 0.4, 0.3))
	_reserve(Rect2(x0 - 2, z0 - 2, w + 4, d + 4))
	_poi("Base militaire", c, Color(0.6, 0.8, 0.3))
	# chemin d'accès vers l'autoroute
	_road(Vector2(x1 + 3.0, c.z), Vector2(-half + 4 * BLOCK, c.z), 7.0, C_DIRT, false)
	# gardiens
	for i in 18:
		var p := Vector3(rng.randf_range(x0 + 4, x1 - 4), 0.1, rng.randf_range(z0 + 4, z1 - 4))
		if not Game.find_zone(p + Vector3.UP).is_empty():
			continue
		guards.append({"pos": p, "kind": "militaire", "radius": 14.0})
	for zz in [hangar, cas1, cas2]:
		for i in 3:
			guards.append({"pos": _random_in(zz, 1.0), "kind": "militaire", "radius": 5.0})
	for i in 4:
		guards.append({"pos": _random_in(arm, 1.0), "kind": "militaire", "radius": 3.0})
	for i in 4:
		guards.append({"pos": Vector3(x1 + rng.randf_range(4, 14), 0.1, c.z + rng.randf_range(-6, 6)), "kind": "militaire", "radius": 10.0})


# ================================================================ arbres
func _trees() -> void:
	var m := Game.map_half - 10.0
	var centers := []
	for i in 14:
		centers.append(Vector3(rng.randf_range(-m, m), 0, rng.randf_range(-m, m)))
	var candidates := trees.duplicate()
	for cc in centers:
		for i in 45:
			candidates.append(cc + Vector3(rng.randfn(0, 22), 0, rng.randfn(0, 22)))
	for i in 250:
		candidates.append(Vector3(rng.randf_range(-m, m), 0, rng.randf_range(-m, m)))
	var park_count := trees.size()
	var final: Array = []
	for idx in candidates.size():
		var p: Vector3 = candidates[idx]
		if absf(p.x) > m or absf(p.z) > m:
			continue
		if idx >= park_count:
			if absf(p.x) < half + 10 and absf(p.z) < half + 10:
				continue
			var r := Rect2(p.x - 2.5, p.z - 2.5, 5, 5)
			if _overlaps(r):
				continue
		final.append(p)
	trees = final
	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.28
	trunk.height = 3.2
	trunk_mm.mesh = trunk
	trunk_mm.instance_count = trees.size()
	var crown_mm := MultiMesh.new()
	crown_mm.transform_format = MultiMesh.TRANSFORM_3D
	crown_mm.use_colors = true
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 2.4
	crown.height = 6.0
	crown.radial_segments = 8
	crown_mm.mesh = crown
	crown_mm.instance_count = trees.size()
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_WORLD
	add_child(body)
	for i in trees.size():
		var p: Vector3 = trees[i]
		var s := rng.randf_range(0.8, 1.35)
		trunk_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), p + Vector3(0, 1.6 * s, 0)))
		crown_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), p + Vector3(0, 5.4 * s, 0)))
		crown_mm.set_instance_color(i, Color(0.16, 0.26, 0.12).lerp(Color(0.3, 0.32, 0.14), rng.randf()))
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3 * s
		cyl.height = 3.2 * s
		cs.shape = cyl
		cs.position = p + Vector3(0, 1.6 * s, 0)
		body.add_child(cs)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.3, 0.22, 0.15)
	var cm := StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.roughness = 0.95
	var mi1 := MultiMeshInstance3D.new()
	mi1.multimesh = trunk_mm
	mi1.material_override = tm
	add_child(mi1)
	var mi2 := MultiMeshInstance3D.new()
	mi2.multimesh = crown_mm
	mi2.material_override = cm
	add_child(mi2)
