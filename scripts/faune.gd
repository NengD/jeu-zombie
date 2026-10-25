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
