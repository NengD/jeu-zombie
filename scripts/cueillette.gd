extends Node3D
## Cueillette ([F]) : pommiers des vergers, rangs de vigne (tronçons de 21 m) et champs de maïs (carrés de 5 m).
## Une parcelle = un seul StaticBody3D (couche LAYER_INTERACT seule : ne bloque ni le joueur, ni les zombies,
## ni les tirs) avec une forme par plant ; le plant visé est retrouvé par l'indice de forme du rayon.
## Chaque plant se cueille une fois par jour (`cueilli` : n° -> jour), état sauvegardé avec la récolte
## (`Recolte.etat()["c"]`). Fruits visibles : un MultiMesh par parcelle (instances écrasées une fois cueillies).

const Recolte = preload("res://scripts/recolte.gd")
const Saisons = preload("res://scripts/saisons.gd")
## saison : type de Saisons.fruits ; quand : phrase affichée hors saison.
const GENRES := {
	"pomme": {"nom": "pommier", "q": [2, 4], "verbe": "Cueillir des pommes", "saison": "pomme", "fruit": "pas de pommes", "quand": "à la fin de l'été et en automne"},
	"raisin": {"nom": "vigne", "q": [2, 3], "verbe": "Cueillir du raisin", "saison": "raisin", "fruit": "pas de raisin", "quand": "en automne"},
	"epi_mais": {"nom": "maïs", "q": [1, 3], "verbe": "Cueillir des épis de maïs", "saison": "mais", "fruit": "pas d'épis mûrs", "quand": "à la fin de l'été et en automne"},
}
var en_saison := {}         # id -> fruits montrés (vrai à l'installation : fruits posés)

var plants: Array = []      # [{p: Vector3, id: String, arbre: n° dans world.arbres_ref (pommiers) ou -1, fruits: [mm, debut, nb]}]
var cueilli := {}           # n° du plant -> jour de la dernière cueillette


class Parcelle extends StaticBody3D:
	var cueillette: Node = null
	var debut := 0          # n° du premier plant de la parcelle (forme 0)

	func get_prompt() -> String:
		return cueillette.prompt(self)

	func interact(joueur: Node) -> void:
		cueillette.cueillir(self, joueur)


func installer(w: Node) -> void:
	# pommiers : les arbres réellement posés dans les vergers
	for r in w.vergers:
		var rr: Rect2 = (r as Rect2).grow(1.0)
		var pts: Array = []
		for i in w.arbres_ref.size():
			var o: Vector3 = (w.arbres_ref[i][3] as Transform3D).origin
			if rr.has_point(Vector2(o.x, o.z)):
				pts.append([o, i])
		_parcelle("pomme", pts, Vector3(1.4, 3.0, 1.4), 1.5)
	# vigne : 3 tronçons de 21 m par rang (mêmes rangs que world_gen._vignoble)
	for c in w.vignobles:
		var pts: Array = []
		var z: float = c.z - 12.0
		while z < c.z + 23.0:
			for s in 3:
				var x: float = c.x - 33.0 + s * 22.0 + 11.0
				pts.append([Vector3(x, Game.hauteur(x, z), z), -1])
			z += 2.6
		_parcelle("raisin", pts, Vector3(21.0, 1.1, 0.7), 0.3)
	# maïs : un carré de 5 m = un plant (forme étroite au centre pour ne pas masquer les objets au sol)
	for r in w.champs_mais:
		var pts: Array = []
		var x: float = r.position.x + 2.5
		while x < r.end.x:
			var z: float = r.position.y + 2.5
			while z < r.end.y:
				pts.append([Vector3(x, Game.hauteur(x, z), z), -1])
				z += 5.0
			x += 5.0
		_parcelle("epi_mais", pts, Vector3(1.4, 1.4, 1.4), 0.9)


## Une parcelle : corps + formes + fruits visibles.
func _parcelle(id: String, pts: Array, taille: Vector3, bas: float) -> void:
	if pts.is_empty():
		return
	var corps := Parcelle.new()
	corps.cueillette = self
	corps.debut = plants.size()
	corps.collision_layer = Game.LAYER_INTERACT
	corps.collision_mask = 0
	var bs := BoxShape3D.new()
	bs.size = taille
	var mm := _fruits(id, pts.size())
	var par_plant := mm.instance_count / pts.size() if mm else 0
	for k in pts.size():
		var p: Vector3 = pts[k][0]
		var cs := CollisionShape3D.new()
		cs.shape = bs
		cs.position = p + Vector3(0, bas + taille.y / 2.0, 0)
		corps.add_child(cs)
		plants.append({"p": p, "id": id, "arbre": pts[k][1], "fruits": [mm, k * par_plant, par_plant]})
		if mm:
			_poser_fruits(id, mm, k * par_plant, par_plant, p)
	add_child(corps)


## MultiMesh des fruits (pommes rouges, grappes violettes ; le maïs n'en montre pas).
func _fruits(id: String, n: int) -> MultiMesh:
	if id == "epi_mais":
		return null
	var sm := SphereMesh.new()
	sm.radius = 0.09 if id == "pomme" else 0.07
	sm.height = sm.radius * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.12, 0.08) if id == "pomme" else Color(0.32, 0.12, 0.35)
	mat.roughness = 0.6
	sm.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = n * (10 if id == "pomme" else 16)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 70.0
	add_child(mi)
	return mm


func _poser_fruits(id: String, mm: MultiMesh, debut: int, nb: int, p: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.x * 13.0) ^ int(p.z * 7.0)
	for k in nb:
		var o: Vector3
		if id == "pomme":
			var a := rng.randf() * TAU
			var r := rng.randf_range(1.0, 1.7)
			o = p + Vector3(cos(a) * r, rng.randf_range(1.9, 2.8), sin(a) * r)
		else:
			# grappes pendues des deux côtés du rang, sous le feuillage
			o = p + Vector3(rng.randf_range(-10.2, 10.2), rng.randf_range(0.45, 0.65), 0.3 * (1.0 if k % 2 == 0 else -1.0))
		mm.set_instance_transform(debut + k, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.4 if id == "raisin" else 1.0, 1.0)), o))


func _fruits_visibles(n: int, vis: bool) -> void:
	var f: Array = plants[n].fruits
	var mm: MultiMesh = f[0]
	if mm == null:
		return
	if vis:
		_poser_fruits(plants[n].id, mm, f[1], f[2], plants[n].p)
	else:
		for k in f[2]:
			mm.set_instance_transform(f[1] + k, Transform3D(Basis.from_scale(Vector3.ZERO), plants[n].p))


## Plant visé par le joueur : forme touchée par le rayon de la caméra (sinon le plus proche du joueur).
func _plant_vise(corps: Parcelle) -> int:
	var j = Game.player
	if j == null:
		return -1
	var cam: Camera3D = j.camera
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * 8.0, Game.LAYER_INTERACT, [j.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider == corps:
		return corps.debut + int(hit.shape)
	return -1


func _pret(n: int) -> bool:
	return int(cueilli.get(n, -1)) != Game.day


func prompt(corps: Parcelle) -> String:
	var n := _plant_vise(corps)
	if n < 0:
		return ""
	var pl: Dictionary = plants[n]
	if pl.arbre >= 0 and Game.recolte and Game.recolte.faits.a.has(int(pl.arbre)):
		return ""
	var g: Dictionary = GENRES[pl.id]
	if not _de_saison(pl.id):
		return _hors_saison(g)
	if _pret(n):
		return "[F] " + g.verbe
	return "%s : déjà cueilli aujourd'hui (revenir demain)" % String(g.nom).capitalize()


func _de_saison(id: String) -> bool:
	return Saisons.fruits(GENRES[id].saison)


func _hors_saison(g: Dictionary) -> String:
	return "%s : %s en cette saison (%s, jour %d) — ça se cueille %s" % [String(g.nom).capitalize(), g.fruit, Saisons.nom(), Saisons.jour_de_saison(), g.quand]


## Un nouveau jour : tout repousse (s'il est de saison).
var jour := -1


func _process(_delta: float) -> void:
	if Game.day == jour:
		return
	jour = Game.day
	for n in cueilli.keys():
		if int(cueilli[n]) != jour:
			cueilli.erase(n)
			_fruits_visibles(n, _de_saison(plants[n].id))
	# fruits montrés ou retirés quand la saison change (une fois par changement)
	for id in GENRES:
		var ok := _de_saison(id)
		if ok == bool(en_saison.get(id, true)):
			continue
		en_saison[id] = ok
		for n in plants.size():
			if plants[n].id == id and _pret(n):
				_fruits_visibles(n, ok)


func cueillir(corps: Parcelle, joueur: Node) -> void:
	var n := _plant_vise(corps)
	if n >= 0 and not _de_saison(plants[n].id):
		Game.msg(_hors_saison(GENRES[plants[n].id]))
		return
	if n < 0 or not _pret(n):
		return
	var pl: Dictionary = plants[n]
	if pl.arbre >= 0 and Game.recolte and Game.recolte.faits.a.has(int(pl.arbre)):
		return
	var g: Dictionary = GENRES[pl.id]
	var niv := int(joueur.prog.comp["survie"].niv) if joueur.get("prog") else 0
	var x := randi_range(g.q[0], g.q[1]) * Recolte.plus_de_ressources(niv) * (1.5 if joueur.get("prog") and joueur.prog.a("cueilleur") else 1.0)   # talent Cueilleur : +50 %
	var qte := int(floor(x)) + (1 if randf() < x - floor(x) else 0)
	joueur.add_item(pl.id, maxi(1, qte))
	if joueur.get("prog"):
		joueur.prog.gagner("survie", 3)
	if joueur.has_method("geste"):
		joueur.geste("fouille")
	cueilli[n] = Game.day
	_fruits_visibles(n, false)
	Game.play_ui("fouille", -8.0, 0.1, 1.3)


# ================================================================ sauvegarde (avec la récolte)
func etat() -> Dictionary:
	var d := {}
	for n in cueilli:
		d[str(n)] = cueilli[n]
	return d


func appliquer(d: Dictionary) -> void:
	for k in d:
		var n := int(k)
		if n >= 0 and n < plants.size() and int(d[k]) == Game.day:
			cueilli[n] = Game.day
			_fruits_visibles(n, false)
