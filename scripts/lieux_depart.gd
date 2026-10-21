extends RefCounted
## Lieux de départ d'une nouvelle partie (choisis dans le menu après « Jouer »), classés par difficulté.
## Le choix ne change pas la carte générée : on cherche, après la génération, un bâtiment du lieu
## (rez-de-chaussée avec porte, loin des camps de bandits et des campements de marchands), on le vide
## de ses zombies, on ouvre ses portes et le joueur apparaît devant, dos au bâtiment.

const DIFFICULTES := ["Facile", "Moyen", "Difficile", "Extrême"]
const COULEURS := [Color(0.45, 0.85, 0.4), Color(0.95, 0.8, 0.3), Color(1.0, 0.5, 0.2), Color(0.95, 0.2, 0.15)]

## poi : point d'intérêt de la carte qui sert d'ancre (sinon « ancre ») ; kinds : bâtiments acceptés ;
## rayon : distance maximale à l'ancre ; calme : rayon (m) vidé de ses zombies autour du départ ;
## bonus : objets ajoutés à l'équipement de départ.
const LIEUX := [
	{"id": "hameau", "nom": "Hameau des Sources", "diff": 0, "poi": "Hameau des Sources", "ancre": Vector3(-470, 0, -93),
		"kinds": ["maison"], "rayon": 90.0, "calme": 60.0, "bonus": {"conserve": 2, "eau": 2, "bandage": 1},
		"desc": "Quelques maisons au calme à l'ouest de Bellerive. Peu de zombies, butin modeste, campements de marchands à quelques centaines de mètres."},
	{"id": "saint_aubin", "nom": "Village de Saint-Aubin", "diff": 0, "poi": "Village de Saint-Aubin", "ancre": Vector3(118, 0, 520),
		"kinds": ["maison"], "rayon": 90.0, "calme": 60.0, "bonus": {"conserve": 1, "eau": 1, "barre": 2},
		"desc": "Village tranquille au sud de Bellerive, le long de l'autoroute. Peu de zombies, maisons à fouiller, ville et marchands accessibles."},
	{"id": "ferme", "nom": "Ferme de la Plaine", "diff": 1, "poi": "Ferme de la Plaine", "ancre": Vector3(-1100, 0, 97),
		"kinds": ["ferme"], "rayon": 60.0, "calme": 40.0, "bonus": {"conserve": 3, "eau": 3, "tissu": 2},
		"desc": "Ferme isolée loin à l'ouest. Presque aucun zombie autour, mais le butin est rare et les marchands sont à près d'un kilomètre : provisions en plus au départ."},
	{"id": "bellerive", "nom": "Maison de Bellerive", "diff": 1,
		"desc": "Le départ habituel : une maison d'un quartier pavillonnaire de Bellerive. Zombies dans les rues, beaucoup à fouiller, marchands à la sortie de la ville."},
	{"id": "lotissement", "nom": "Lotissement des Tilleuls", "diff": 2, "poi": "Lotissement des Tilleuls", "ancre": Vector3(0, 0, 0), "carte": Vector3(90, 0, -200),
		"kinds": ["maison"], "rayon": 120.0, "calme": 0.0, "renfort": [12, "civil"], "bonus": {},
		"desc": "Lotissement neuf en bordure de Bellerive : 28 maisons identiques pleines de butin… et de leurs anciens habitants."},
	{"id": "valmont", "nom": "Centre de Valmont", "diff": 2, "poi": "Valmont", "ancre": Vector3(1450, 0, -1350),
		"kinds": ["maison", "magasin", "bureau"], "rayon": 90.0, "calme": 0.0, "bonus": {"bandage": 1},
		"desc": "Seconde ville de la carte, au nord-est. Rues infestées, police, hôpital et armurerie à proximité, marchands de l'autre côté de la ville."},
	{"id": "centre", "nom": "Centre-ville de Bellerive", "diff": 3, "poi": "Bellerive", "ancre": Vector3(0, 0, 0),
		"kinds": ["maison", "magasin", "bureau"], "rayon": 70.0, "calme": 0.0, "bonus": {"bandage": 2, "antidouleur": 1},
		"desc": "En plein centre dense : immeubles, bureaux, foule de zombies dès la première minute. Le meilleur butin de la ville, si tu tiens."},
	{"id": "base", "nom": "Base militaire", "diff": 3, "poi": "Base militaire", "ancre": Vector3(-255, 0, -250),
		"kinds": ["militaire", "maison", "ferme", "magasin", "bureau"], "rayon": 140.0, "calme": 0.0, "renfort": [8, "militaire"], "bonus": {"bandage": 2, "antidouleur": 1},
		"desc": "Aux portes de la base militaire : soldats zombies coriaces, mais armes et équipement militaires à portée de main."},
]

## Lieu choisi pour la prochaine nouvelle partie (menu -> main) ; « hasard » = tiré au sort.
static var choix := "bellerive"


static func lieu(id: String) -> Dictionary:
	for l in LIEUX:
		if l.id == id:
			return l
	return LIEUX[3]


## Applique le lieu choisi : renvoie {pos, dir (vers l'extérieur), zone, lieu, infos}.
## Appelé par main.gd après la génération (marchands et camps déjà placés), avant le rangement par morceaux.
static func appliquer(main: Node, id: String) -> Dictionary:
	var world = main.world
	if id == "hasard":
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		id = LIEUX[rng.randi() % LIEUX.size()].id
	var l := lieu(id)
	var res := {"pos": world.spawn_point, "dir": world.spawn_point - world.spawn_zone.center, "zone": world.spawn_zone, "lieu": l}
	if id != "bellerive":
		var z := _chercher_batiment(main, l)
		if not z.is_empty():
			var dr: Dictionary = z.doors[0]
			var pos: Vector3 = dr.out + (dr.out - dr.pos).normalized() * 1.0
			pos.y = maxf(pos.y, Game.hauteur(pos.x, pos.z))
			res.pos = pos
			res.dir = dr.out - dr.pos
			res.zone = z
			for pp in z.get("portes", []):
				pp.basculer(true, true)
			_vider_zombies(world, z, pos, float(l.get("calme", 0.0)))
			if l.has("renfort"):
				_renfort(world, pos, int(l.renfort[0]), l.renfort[1])
	res["infos"] = mesurer(main, res.pos)
	return res


## Bâtiment du lieu : rez-de-chaussée avec porte, du bon type, le plus proche de l'ancre,
## à plus de 150 m d'un camp de bandits et hors des campements de marchands.
static func _chercher_batiment(main: Node, l: Dictionary) -> Dictionary:
	var ancre: Vector3 = l.ancre
	for p in Game.pois:
		if p.name == l.poi:
			ancre = p.pos
			break
	var r: float = l.rayon
	var meilleur := {}
	var dmin := INF
	for z in Game.zones:
		if int(z.get("etage", 0)) != 0 or z.doors.is_empty() or not (z.kind in l.kinds) or not z.has("portes"):
			continue
		var c: Vector3 = z.center
		var d := Vector2(c.x - ancre.x, c.z - ancre.z).length()
		if d > r or d >= dmin:
			continue
		if main.pres_camp_marchand(c, 25.0) or _pres_bandits(main, c, 150.0):
			continue
		dmin = d
		meilleur = z
	return meilleur


static func _pres_bandits(main: Node, c: Vector3, r: float) -> bool:
	for cb in main.camps:
		if Vector2(c.x - cb.global_position.x, c.z - cb.global_position.z).length() < r:
			return true
	return false


## Retire les zombies prévus dans le bâtiment de départ (tous les étages) et, selon le lieu, dans un rayon autour.
static func _vider_zombies(world, z: Dictionary, pos: Vector3, calme: float) -> void:
	var etages: Array = z.get("etages", [z])
	for i in range(world.guards.size() - 1, -1, -1):
		var g: Vector3 = world.guards[i].pos
		var dedans := false
		for e in etages:
			if e.aabb.grow(1.5).has_point(g + Vector3.UP * 0.5):
				dedans = true
		if dedans or Vector2(g.x - pos.x, g.z - pos.z).length() < maxf(calme, 15.0):
			world.guards.remove_at(i)


## Zombies de plus dehors, entre 18 et 70 m du départ (lieux difficiles), tirés de la graine du monde.
static func _renfort(world, pos: Vector3, n: int, kind: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.graine_monde + 9191
	var places := 0
	for essai in n * 10:
		if places >= n:
			break
		var a := rng.randf() * TAU
		var p := pos + Vector3(cos(a), 0, sin(a)) * rng.randf_range(18.0, 70.0)
		if not Game.find_zone(p + Vector3.UP).is_empty() or (Game.relief and Game.relief.dans_eau(p.x, p.z)):
			continue
		p.y = Game.hauteur(p.x, p.z) + 0.1
		world.guards.append({"pos": p, "kind": kind, "radius": 12.0})
		places += 1


## Ce qui entoure un point : zombies prévus à moins de 120 m, meubles à fouiller à moins de 80 m,
## camps de bandits à moins de 600 m, distance du campement de marchands le plus proche.
static func mesurer(main: Node, pos: Vector3) -> Dictionary:
	var p2 := Vector2(pos.x, pos.z)
	var nz := 0
	for g in main.world.guards:
		if Vector2(g.pos.x, g.pos.z).distance_to(p2) < 120.0:
			nz += 1
	var nb := 0
	for c in main.world.conteneurs:
		if is_instance_valid(c) and Vector2(c.position.x, c.position.z).distance_to(p2) < 80.0:
			nb += 1
	var nbandits := 0
	for cb in main.camps:
		if Vector2(cb.global_position.x, cb.global_position.z).distance_to(p2) < 600.0:
			nbandits += 1
	var dm := INF
	for cm in main.camps_marchands:
		dm = minf(dm, Vector2(cm.global_position.x, cm.global_position.z).distance_to(p2))
	return {"zombies": nz, "butin": nb, "bandits": nbandits, "marchand": dm}
