extends Node
## Faune : animaux placés par cases de 128 m autour du joueur (comme le chargement par morceaux),
## selon le milieu de la case : forêt (cerfs, sangliers, lapins), champs (faisans, lapins, quelques cerfs),
## campagne ouverte (un peu de tout, moins nombreux). Rien en ville ni dans l'eau.
## Une case quittée garde ses survivants ; elle se repeuple le lendemain.

const Animal = preload("res://scripts/animal.gd")
const CASE := 128.0
const RAYON_APPARITION := 230.0    # cases peuplées quand leur centre est à moins de cette distance
const RAYON_DISPARITION := 340.0
const DIST_MIN := 60.0              # jamais placés sous les yeux du joueur
const MAX_ANIMAUX := 28
const SEUIL_FORET := 22             # arbres par case de 128 m
const Saisons = preload("res://scripts/saisons.gd")
const HIVER := 0.6                  # part des animaux gardés en hiver (sauf les loups)

var world: Node = null
var arbres := {}                    # case -> nombre d'arbres
var champs := {}                    # case -> true (au moins un champ)
var fermes := {}                    # case -> position de la ferme (bêtes de ferme abandonnées)
var cases := {}                     # case -> {"jour": int, "restants": Array (types), "vivants": Array}
var t := 0.0


func installer(w: Node) -> void:
	world = w
	for tr in w.trees:
		var c := _case(tr)
		arbres[c] = int(arbres.get(c, 0)) + 1
	for r in w.get("champs") if w.get("champs") != null else []:
		var rr: Rect2 = r
		for x in range(floori(rr.position.x / CASE), floori(rr.end.x / CASE) + 1):
			for z in range(floori(rr.position.y / CASE), floori(rr.end.y / CASE) + 1):
				champs[Vector2i(x, z)] = true
	for poi in Game.pois:
		if String(poi.name).begins_with("Ferme"):
			fermes[_case(poi.pos)] = poi.pos


static func _case(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CASE), floori(p.z / CASE))


static func _centre(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CASE, 0.0, (c.y + 0.5) * CASE)


## Milieu d'une case : "foret", "champs", "campagne" ou "" (ville, hors carte).
func milieu(c: Vector2i) -> String:
	var ce := _centre(c)
	if Game.in_city(ce) or absf(ce.x) > Game.map_half - 60.0 or absf(ce.z) > Game.map_half - 60.0:
		return ""
	if int(arbres.get(c, 0)) >= SEUIL_FORET:
		return "foret"
	if champs.has(c):
		return "champs"
	return "campagne"


func _process(delta: float) -> void:
	_maj_traces(delta)
	t -= delta
	if t > 0.0:
		return
	t = 1.0
	var p = Game.player
	if p == null or not p.alive or world == null:
		return
	var pp: Vector3 = p.global_position
	var pc := _case(pp)
	var nb := get_tree().get_nodes_in_group("animaux").size()
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var c := pc + Vector2i(dx, dz)
			var ce := _centre(c)
			if Vector2(ce.x - pp.x, ce.z - pp.z).length() > RAYON_APPARITION:
				continue
			var e: Dictionary = cases.get(c, {})
			if not e.is_empty() and not e.vivants.is_empty():
				continue
			if e.is_empty() or int(e.jour) != Game.day:
				e = {"jour": Game.day, "restants": _composition(c), "vivants": []}
				cases[c] = e
			if not e.restants.is_empty() and nb < MAX_ANIMAUX:
				nb += _peupler(c, e, pp)
	# cases lointaines : on retire les animaux (les survivants reviendront avec la case)
	for c in cases.keys():
		var ce := _centre(c)
		if Vector2(ce.x - pp.x, ce.z - pp.z).length() < RAYON_DISPARITION:
			continue
		var e: Dictionary = cases[c]
		for a in e.vivants:
			if is_instance_valid(a):
				if a.etat != Animal.Etat.MORT:
					e.restants.append(a.kind)
				a.queue_free()
		e.vivants.clear()


## Animaux d'une case pour la journée (même tirage pour une même carte, une même case et un même jour).
func _composition(c: Vector2i) -> Array:
	var m := milieu(c)
	if m == "":
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Game.graine_monde, c.x, c.y, Game.day])
	var out: Array = []
	if fermes.has(c):
		# bêtes abandonnées dans les prés de la ferme
		for i in rng.randi_range(1, 3):
			out.append("vache")
		for i in rng.randi_range(0, 2):
			out.append("cheval" if rng.randf() < 0.6 else "cheval_blanc")
		for i in rng.randi_range(2, 5):
			out.append("mouton")
		return out
	match m:
		"foret":
			if rng.randf() < 0.5:
				out.append("cerf")
				for i in rng.randi_range(1, 2):
					out.append("biche")
			if rng.randf() < 0.35:
				for i in rng.randi_range(1, 3):
					out.append("sanglier")
			if rng.randf() < 0.4:
				for i in rng.randi_range(1, 2):
					out.append("lapin")
			if rng.randf() < (0.16 if Game.is_night() else 0.09):
				for i in rng.randi_range(3, 5):
					out.append("loup")
		"champs":
			if rng.randf() < 0.5:
				for i in rng.randi_range(1, 3):
					out.append("faisan")
			if rng.randf() < 0.55:
				for i in rng.randi_range(1, 3):
					out.append("lapin")
			if rng.randf() < 0.2:
				out.append("biche" if rng.randf() < 0.6 else "cerf")
			if rng.randf() < 0.35:
				for i in rng.randi_range(2, 5):
					out.append("corbeau")
		"campagne":
			if rng.randf() < 0.25:
				for i in rng.randi_range(1, 2):
					out.append("lapin")
			if rng.randf() < 0.15:
				out.append("faisan")
			if rng.randf() < 0.1:
				out.append("biche")
			if rng.randf() < 0.06:
				out.append("sanglier")
			if rng.randf() < 0.07:
				for i in rng.randi_range(2, 4):
					out.append("chien")
			if rng.randf() < 0.2:
				for i in rng.randi_range(2, 4):
					out.append("corbeau")
	if Saisons.saison() == "hiver":
		# hiver : gibier plus rare (≈ ×0,6) ; les loups, eux, rôdent toujours
		out = out.filter(func(k): return k == "loup" or rng.randf() < HIVER)
	return out


## Place les animaux restants de la case : en groupe autour d'un point valide, loin du joueur.
func _peupler(c: Vector2i, e: Dictionary, pp: Vector3) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Game.graine_monde, c.x, c.y, Game.day, 7])
	var centre_groupe := Vector3.INF
	for essai in 12:
		var q := _centre(c) + Vector3(rng.randf_range(-54.0, 54.0), 0.0, rng.randf_range(-54.0, 54.0))
		if fermes.has(c):
			# dans les prés, devant la ferme (côté opposé à la grange)
			var fp: Vector3 = fermes[c]
			q = fp + Vector3(rng.randf_range(-40.0, 20.0), 0.0, signf(fp.z) * rng.randf_range(28.0, 60.0))
		if _valide(q, pp):
			centre_groupe = q
			break
	if centre_groupe == Vector3.INF:
		return 0                         # case sans place (bâtiments, eau, joueur trop près) : on réessaiera
	var parent: Node = get_parent()
	var n := 0
	for k in e.restants:
		var pos := centre_groupe + Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-6.0, 6.0))
		if not _valide(pos, pp):
			pos = centre_groupe
		pos.y = Game.hauteur(pos.x, pos.z) + 0.05
		var a = Animal.new()
		a.preparer(str(k), pos)
		a.faune = self
		a.case_faune = c
		parent.add_child(a)
		e.vivants.append(a)
		n += 1
	e.restants.clear()
	return n


func _valide(q: Vector3, pp: Vector3) -> bool:
	if Vector2(q.x - pp.x, q.z - pp.z).length() < DIST_MIN:
		return false
	if Game.in_city(q) or (Game.relief and Game.relief.dans_eau(q.x, q.z)):
		return false
	q.y = Game.hauteur(q.x, q.z)
	if not Game.find_zone(q + Vector3.UP * 1.0).is_empty():
		return false                     # dans un bâtiment
	return Game.relief == null or Game.relief.pente(q.x, q.z) < 0.45


## Un animal est mort : il ne reviendra pas avec sa case (jusqu'au lendemain).
func mort(a: Node) -> void:
	var e: Dictionary = cases.get(a.case_faune, {})
	if not e.is_empty():
		e.vivants.erase(a)


## Nombre d'animaux vivants (tests, admin).
func compter() -> Dictionary:
	var d := {}
	for a in get_tree().get_nodes_in_group("animaux"):
		d[a.kind] = int(d.get(a.kind, 0)) + 1
	return d


# ---------------------------------------------------------------- traces dans la neige
## Sur la neige (Game.enneige > 0,25), les animaux sauvages à moins de TRACE_PORTEE du joueur laissent une piste :
## une foulée (deux empreintes, sabots ou pattes) tous les ~2,5 m, carrés posés sur le sol dans deux MultiMesh
## (sabots / pattes : une passe de rendu chacun), instances recyclées (TRACES_MAX par MultiMesh), effacées en
## TRACE_DUREE s (assez pour suivre une piste) ; un tour sur les animaux toutes les 0,2 s.
## Pas de traces pour les oiseaux ni pour les bêtes de ferme (elles tournent dans leur pré et videraient la réserve).
const TRACES_MAX := 80
const TRACE_DUREE := 240.0
const TRACE_PORTEE := 90.0
const FOULEE := {"lapin": 1.4, "loup": 2.4, "chien": 2.2, "sanglier": 2.0}   # sinon 2,6 m (cerf, biche)
const PATTES := ["lapin", "loup", "chien"]   # empreintes à coussinets ; les autres : sabots fendus
const SANS_TRACE := ["faisan", "corbeau"]
var pistes := {}                  # false (sabots) / true (pattes) -> {mm: MultiMesh, i: prochaine instance, t: [âge…]}
var _traces_t := 0.0
var _fondu_t := 0.0


func _maj_traces(delta: float) -> void:
	_fondu_t -= delta
	if _fondu_t <= 0.0 and not pistes.is_empty():
		# vieillissement (1 fois par seconde) : les empreintes pâlissent puis disparaissent, ou fondent avec la neige
		_fondu_t = 1.0
		for p in pistes.values():
			var mm: MultiMesh = p.mm
			for i in TRACES_MAX:
				var age: float = p.t[i]
				if age < 0.0:
					continue
				age += 1.0
				var a := clampf(1.0 - age / TRACE_DUREE, 0.0, 1.0) * clampf(Game.enneige * 2.0, 0.0, 1.0)
				if a <= 0.02:
					p.t[i] = -1.0
					mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
				else:
					p.t[i] = age
					mm.set_instance_color(i, Color(1, 1, 1, a))
	_traces_t -= delta
	if _traces_t > 0.0 or Game.enneige <= 0.25 or Game.player == null:
		return
	_traces_t = 0.2
	var pp: Vector3 = Game.player.global_position
	for a in get_tree().get_nodes_in_group("animaux"):
		if a.kind in SANS_TRACE or a.vol or Animal.TYPES[a.kind].get("ferme", false) or a.global_position.distance_squared_to(pp) > TRACE_PORTEE * TRACE_PORTEE:
			continue
		var pos: Vector3 = a.global_position
		var der = a.get_meta("trace", null)
		if der == null:
			a.set_meta("trace", pos)
			continue
		var dep: Vector3 = pos - der
		dep.y = 0.0
		if dep.length() < float(FOULEE.get(a.kind, 2.6)):
			continue
		a.set_meta("trace", pos)
		poser_trace(pos, atan2(-dep.x, -dep.z), a.kind)


func poser_trace(pos: Vector3, yaw: float, kind: String) -> void:
	var patte: bool = kind in PATTES
	if not pistes.has(patte):
		_creer_piste(patte)
	var p: Dictionary = pistes[patte]
	var i: int = p.i
	p.i = (i + 1) % TRACES_MAX
	var k := 0.6 if kind == "lapin" else (0.85 if kind in ["loup", "chien", "sanglier"] else 1.0)
	var sol := Vector3(pos.x, Game.hauteur(pos.x, pos.z) + 0.04, pos.z)
	if absf(sol.y - pos.y) > 0.6:
		sol.y = pos.y + 0.04   # (pont, sol construit : la position de l'animal fait foi)
	p.mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(0.75 * k, 1.0, 1.0 * k)), sol))
	p.mm.set_instance_color(i, Color(1, 1, 1, clampf(Game.enneige * 2.0, 0.0, 1.0)))
	p.t[i] = 0.0


## Un MultiMesh de carrés couchés (avant de l'animal = -Z = haut de la texture), instances écrasées au départ.
func _creer_piste(patte: bool) -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _texture_foulee(patte)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = TRACES_MAX
	var ages: Array = []
	for i in TRACES_MAX:
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		ages.append(-1.0)
	var mi := MultiMeshInstance3D.new()
	mi.name = "Traces_" + ("pattes" if patte else "sabots")
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-3000, -200, -3000), Vector3(6000, 600, 6000))   # instances partout sur la carte
	add_child(mi)
	pistes[patte] = {"mm": mm, "i": 0, "t": ages}


func _texture_foulee(patte: bool) -> ImageTexture:
	# creux bleu-gris bien marqués (empreintes stylisées, plus grosses que nature pour se suivre de loin)
	var col := Color(0.16, 0.19, 0.27)
	var img := Image.create(48, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 48:
			var a := 0.0
			for c in [Vector2(14.0, 16.0), Vector2(34.0, 48.0)]:   # gauche devant, droite derrière
				var px: float = (x - c.x) / 13.0
				var py: float = (y - c.y) / 15.0
				if patte:
					# coussinet et quatre doigts
					a = maxf(a, 1.0 - (px * px + pow((py - 0.35) / 0.6, 2)) * 1.6)
					for o in [Vector2(-0.75, -0.35), Vector2(-0.28, -0.85), Vector2(0.28, -0.85), Vector2(0.75, -0.35)]:
						a = maxf(a, 1.0 - (pow(px - o.x, 2) + pow(py - o.y, 2)) * 9.0)
				else:
					# sabot fendu : goutte pointue vers l'avant, fente au milieu
					var b := 1.0 - (px * px * (1.0 + maxf(0.0, -py) * 1.5) + py * py)
					if absf(x - c.x) < 1.0 and py < 0.6:
						b = minf(b, 0.15)
					a = maxf(a, b)
			img.set_pixel(x, y, Color(col, clampf(a * 2.5, 0.0, 0.9)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
