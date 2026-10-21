extends Node3D
## Scène principale : génère le monde, place le joueur, gère l'apparition des zombies.

const WorldGen = preload("res://scripts/world_gen.gd")
const DayNight = preload("res://scripts/day_night.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const InventoryUI = preload("res://scripts/ui/inventory_ui.gd")
const InspectionUI = preload("res://scripts/ui/inspection_ui.gd")
const CompetencesUI = preload("res://scripts/ui/competences_ui.gd")
const MapUI = preload("res://scripts/ui/map_ui.gd")
const BoutiqueUI = preload("res://scripts/ui/boutique_ui.gd")
const Vendeur = preload("res://scripts/vendeur.gd")
const PLAYER_SCENE = preload("res://scenes/player.tscn")
const ZOMBIE_SCENE = preload("res://scenes/zombie.tscn")
const LieuxDepart = preload("res://scripts/lieux_depart.gd")

## 0 = carte différente à chaque partie. Mets un nombre pour garder toujours la même.
@export var world_seed := 0

var world
var player
var zombies_root: Node3D
var spawn_t := 1.5
var first_fill := true


func _ready() -> void:
	Game.reset()
	var charge: Dictionary = Game.partie_a_charger
	Game.partie_a_charger = {}
	var s := world_seed if world_seed != 0 else randi()
	if not charge.is_empty():
		s = int(charge.get("graine", s))
	Game.graine_monde = s
	world = WorldGen.new()
	world.name = "Monde"
	# le monde est construit hors de l'arbre : seules les cases proches du joueur y entreront (chargement par morceaux)
	var spawn: Vector3 = world.build(s)
	var t := Time.get_ticks_msec()
	_creer_marche()
	t = world._chrono("marche", t)
	_creer_camps()
	t = world._chrono("camps", t)
	if OS.get_environment("SANS_FACADES") == "":   # (test de performance : sans les nouveaux effets)
		_creer_ambiance()
	t = world._chrono("ambiance", t)
	# lieu de départ choisi dans le menu (nouvelle partie) : la carte, les marchands et les camps ne changent pas
	var dir_depart: Vector3 = world.spawn_point - world.spawn_zone.center
	var depart_choisi := {}
	if charge.is_empty():
		depart_choisi = LieuxDepart.appliquer(self, LieuxDepart.choix)
		spawn = depart_choisi.pos
		dir_depart = depart_choisi.dir
	var depart: Vector3 = spawn if charge.is_empty() else Sauvegarde._vd(charge.get("joueur", {}).get("pos", [spawn.x, spawn.y, spawn.z]))
	world.ranger_par_morceaux(depart)
	add_child(world)
	move_child(world, 0)
	t = world._chrono("morceaux", t)
	var dn = DayNight.new()
	dn.name = "Cycle"
	add_child(dn)
	var faune = preload("res://scripts/faune.gd").new()   # animaux sauvages par cases autour du joueur
	faune.name = "Faune"
	add_child(faune)
	faune.installer(world)
	var recolte = preload("res://scripts/recolte.gd").new()   # arbres, rochers, épaves récoltables
	recolte.name = "Recolte"
	add_child(recolte)
	recolte.installer(world)
	Game.recolte = recolte
	zombies_root = Node3D.new()
	zombies_root.name = "Zombies"
	add_child(zombies_root)
	if charge.is_empty():
		for g in world.guards:
			placer_zombie(g.pos, g.kind, g.radius, -1.0, g.pos, spawn)
	else:
		Sauvegarde.appliquer_monde(self, charge)
		Sauvegarde.appliquer_zombies(self, charge)
		first_fill = false
	t = world._chrono("zombies", t)
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = spawn + Vector3.UP * 0.1
	player.rotation.y = atan2(-dir_depart.x, -dir_depart.z)  # dos au bâtiment
	if charge.is_empty():
		var bonus: Dictionary = depart_choisi.lieu.get("bonus", {})   # équipement en plus selon le lieu
		for id in bonus:
			player.add_item(id, int(bonus[id]))
	add_child(Hud.new())
	add_child(InventoryUI.new())
	add_child(InspectionUI.new())
	add_child(CompetencesUI.new())
	add_child(MapUI.new())
	add_child(BoutiqueUI.new())
	if Game.admin:
		add_child(preload("res://scripts/ui/admin_ui.gd").new())
	_ambience()
	t = world._chrono("joueur_ui", t)
	if charge.is_empty():
		var l: Dictionary = depart_choisi.lieu
		var inf: Dictionary = depart_choisi.infos
		Game.msg("Bienvenue : %s (%s). Trouve de quoi survivre. [F1] pour l'aide." % [l.nom, LieuxDepart.DIFFICULTES[l.diff]])
		Game.msg("Autour : %d zombies, %d meubles à fouiller, marchands à %d m." % [inf.zombies, inf.butin, int(inf.marchand)])
	else:
		Sauvegarde.appliquer_joueur(self, charge)
		Game.msg("Partie chargée — jour %d." % Game.day)


## Campements des marchands (médecin, quincaillier, armurier) : chacun dans son propre camp gardé,
## juste à la sortie de la ville, le plus proche du départ en premier (médecin), à au moins 90 m l'un de l'autre.
## Même emplacement et mêmes vendeurs pour une même carte.
const CampMarchand = preload("res://scripts/camp_marchand.gd")
var camps_marchands: Array = []


func _creer_marche() -> void:
	Game.sans_herbe.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.graine_monde + 777
	var depart: Vector3 = world.spawn_point
	# ville de départ : médecin (le plus proche), quincaillier, armurier
	_camps_autour(Vector3.ZERO, Game.city_half, depart, ["medecin", "quincaillier", "armurier"], rng)
	# autres villes : un médecin et un armurier à la sortie de chacune
	for i in range(1, Game.villes.size()):
		var v: Dictionary = Game.villes[i]
		_camps_autour(v.c, float(v.demi), v.c + Vector3(0, 0, float(v.demi) + 200.0), ["medecin", "armurier"], rng)


## Camps de marchands juste à la sortie d'une ville (centre, demi-côté), les plus proches de « vers » d'abord.
func _camps_autour(centre: Vector3, ch: float, vers_pt: Vector3, metiers: Array, rng: RandomNumberGenerator) -> void:
	var lim: float = Game.map_half - 40.0
	var candidats: Array = []
	for i in 1500:
		var c := centre + Vector3(rng.randf_range(-ch - 90.0, ch + 90.0), 0, rng.randf_range(-ch - 90.0, ch + 90.0))
		if maxf(absf(c.x - centre.x), absf(c.z - centre.z)) < ch + 24.0 or absf(c.x) > lim or absf(c.z) > lim:
			continue
		candidats.append(c)
	candidats.sort_custom(func(a, b): return a.distance_to(vers_pt) < b.distance_to(vers_pt))
	var places: Array = []
	for c in candidats:
		if places.size() >= metiers.size():
			break
		var trop_pres := false
		for p in places:
			if Vector2(c.x - p.x, c.z - p.z).length() < 90.0:
				trop_pres = true
		if trop_pres or not _terrain_libre(c, 14.0):
			continue
		c.y = Game.hauteur(c.x, c.z)
		places.append(c)
	var noms := ["Marc", "Sophie", "Karim", "Lucie", "Hugo", "Inès", "Paul", "Nadia", "Yann", "Chloé"]
	var titres := {"medecin": "du médecin", "quincaillier": "du quincaillier", "armurier": "de l'armurier"}
	for k in places.size():
		world.degager(places[k], CampMarchand.RAYON + 1.5)
		Game.sans_herbe.append([places[k], CampMarchand.RAYON + 0.8])
		var n := camps_marchands.size()
		var camp = CampMarchand.new()
		camp.name = "CampMarchand%d" % n
		add_child(camp)
		camp.global_position = places[k]
		var vers: Vector3 = centre - places[k]
		camp.rotation.y = atan2(vers.x, vers.z)   # entrée (+Z) tournée vers la ville
		var nom: String = noms[absi(Game.graine_monde + n * 3) % noms.size()]
		camp.construire_marchand(metiers[k], nom, rng)
		camps_marchands.append(camp)
		Game.pois.append({"name": "Camp %s (%s)" % [titres[metiers[k]], nom], "pos": places[k], "color": Color(0.4, 0.9, 0.5)})


## Terrain sec, plutôt plat et sans bâtiment dans un rayon donné (camps).
func _terrain_libre(c: Vector3, r: float) -> bool:
	# ni route, ni ville, ni ferme (rectangles réservés par la génération du monde)
	if world.has_method("_overlaps") and world._overlaps(Rect2(c.x - r, c.z - r, 2.0 * r, 2.0 * r)):
		return false
	var hmin := 9999.0
	var hmax := -9999.0
	for k in 37:
		var a := k * TAU / (24.0 if k < 24 else 12.0)
		var rr := 0.0 if k == 36 else (r if k < 24 else r * 0.5)
		var pt := c + Vector3(cos(a), 0, sin(a)) * rr
		if Game.relief and Game.relief.dans_eau(pt.x, pt.z):
			return false
		if not Game.find_zone(pt + Vector3.UP).is_empty():
			return false
		var h: float = Game.hauteur(pt.x, pt.z)
		hmin = minf(hmin, h)
		hmax = maxf(hmax, h)
	return hmax - hmin < 2.0


## Le point est-il dans la zone protégée d'un campement de marchand ?
func pres_camp_marchand(pos: Vector3, marge := 0.0) -> bool:
	for c in camps_marchands:
		if is_instance_valid(c) and Vector2(pos.x - c.global_position.x, pos.z - c.global_position.z).length() < c.RAYON + marge:
			return true
	return false


## Camps de bandits répartis sur la carte, hors des villes, loin du départ et entre eux.
## Mêmes camps pour une même carte (tirage à partir de la graine du monde).
const CampBandits = preload("res://scripts/camp_bandits.gd")
const NB_CAMPS := 16
var camps: Array = []


func _creer_camps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.graine_monde + 4242
	var depart: Vector3 = world.spawn_point
	var lim: float = Game.map_half - 40.0
	var places: Array = []
	for essai in 600:
		if places.size() >= NB_CAMPS:
			break
		var c := Vector3(rng.randf_range(-lim, lim), 0, rng.randf_range(-lim, lim))
		if Vector2(c.x - depart.x, c.z - depart.z).length() < 160.0 or Game.in_city(c):
			continue
		if pres_camp_marchand(c, 140.0):
			continue
		var trop_pres := false
		for p in places:
			if Vector2(c.x - p.x, c.z - p.z).length() < 170.0:
				trop_pres = true
		if trop_pres:
			continue
		# terrain sec, plutôt plat, sans bâtiment
		var ok := true
		var hmin := 9999.0
		var hmax := -9999.0
		for k in 9:
			var a := k * TAU / 8.0
			var r := 0.0 if k == 8 else 13.0
			var pt := c + Vector3(cos(a), 0, sin(a)) * r
			if Game.relief and Game.relief.dans_eau(pt.x, pt.z):
				ok = false
			if not Game.find_zone(pt + Vector3.UP).is_empty():
				ok = false
			var h: float = Game.hauteur(pt.x, pt.z)
			hmin = minf(hmin, h)
			hmax = maxf(hmax, h)
		if not ok or hmax - hmin > 2.5:
			continue
		c.y = Game.hauteur(c.x, c.z)
		places.append(c)
	for i in places.size():
		var camp = CampBandits.new()
		camp.name = "CampBandits%d" % i
		add_child(camp)
		camp.global_position = places[i]
		camp.rotation.y = rng.randf() * TAU
		for c in camp.construire(i, rng, 3 + rng.randi_range(0, 3)):
			c.uid = world.conteneurs.size()
			world.conteneurs.append(c)
		camps.append(camp)
		Game.pois.append({"name": "Camp de bandits", "pos": places[i], "color": Color(0.9, 0.15, 0.1)})


## Sauvegarde : nombre de bandits encore en vie dans chaque camp.
func etat_camps() -> Array:
	var res := []
	for c in camps:
		res.append(c.vivants() if is_instance_valid(c) else 0)
	return res


func appliquer_camps(etat: Array) -> void:
	for i in mini(etat.size(), camps.size()):
		camps[i].garder(int(etat[i]))


# ---------------------------------------------------------------- primes
## Les marchands paient pour chaque camp de bandits entièrement nettoyé.
var primes_payees: Array = []
const DIRECTIONS := ["nord", "nord-est", "est", "sud-est", "sud", "sud-ouest", "ouest", "nord-ouest"]


func prime_camp(i: int) -> int:
	return 80 + 30 * int(camps[i].effectif)   # bandits moins précis de loin : camps plus faciles à nettoyer


## Situation des camps vus depuis un point : direction, distance, bandits restants, prime.
func infos_primes(depuis: Vector3) -> Array:
	var res := []
	for i in camps.size():
		var c: Vector3 = camps[i].global_position
		var dx := c.x - depuis.x
		var dz := c.z - depuis.z
		var ang := atan2(dx, -dz)   # 0 = nord (-Z), vers l'est quand x augmente
		var k := posmod(roundi(ang / (PI / 4.0)), 8)
		res.append({"i": i, "dir": DIRECTIONS[k], "dist": int(Vector2(dx, dz).length()), "restants": camps[i].vivants(),
				"prime": prime_camp(i), "payee": i < primes_payees.size() and primes_payees[i]})
	return res


func reclamer_prime(i: int) -> bool:
	if i >= camps.size() or camps[i].vivants() > 0:
		return false
	while primes_payees.size() < camps.size():
		primes_payees.append(false)
	if primes_payees[i]:
		return false
	primes_payees[i] = true
	player.gagner_argent(prime_camp(i), true)
	player.prog.gagner("combat", 150)
	Game.msg("Prime encaissée : %d € pour le camp de bandits nettoyé !" % prime_camp(i))
	Game.play_ui("construire", -2.0, 0.0, 1.4)
	return true


## Sauvegarde la partie (menu pause, F5, et automatiquement toutes les 5 minutes).
func sauvegarder(auto := false) -> void:
	if player == null or not player.alive:
		return
	if Game.admin:
		if not auto:
			Game.msg("Mode admin : la partie n'est pas sauvegardée.")
		return
	if Sauvegarde.sauver(self):
		Game.msg("Sauvegarde automatique." if auto else "Partie sauvegardée.")
	else:
		Game.msg("Impossible de sauvegarder.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sauvegarde_rapide"):
		sauvegarder()
	elif event.is_action_pressed("chargement_rapide"):
		if Game.admin:
			Game.msg("Mode admin : chargement désactivé.")
		elif Sauvegarde.existe():
			Game.charger_partie()
		else:
			Game.msg("Aucune sauvegarde.")


## Zombies « endormis » loin du joueur : gardés en mémoire seulement (pas de nœud), réveillés à son approche.
var zombies_virtuels: Array = []   # {pos, kind, rayon, pv, maison}
const DIST_REVEIL := 175.0
const DIST_SOMMEIL := 215.0


func placer_zombie(pos: Vector3, kind: String, rayon: float, pv: float, maison: Vector3, ref: Vector3) -> void:
	if pres_camp_marchand(pos, 12.0):
		return   # pas de zombie dans un campement gardé
	if pos.distance_to(ref) > DIST_REVEIL:
		zombies_virtuels.append({"pos": pos, "kind": kind, "rayon": rayon, "pv": pv, "maison": maison})
		return
	var z = spawn_zombie(pos, kind, true, rayon)
	if pv > 0.0:
		z.health = pv
	z.home = maison


func _gerer_virtuels() -> void:
	var pp: Vector3 = player.global_position
	for z in get_tree().get_nodes_in_group("zombies"):
		if z.persistent and z.state != z.State.CHASE and z.global_position.distance_to(pp) > DIST_SOMMEIL:
			zombies_virtuels.append({"pos": z.global_position + Vector3(0, 0.05, 0), "kind": z.kind, "rayon": z.home_radius, "pv": z.health, "maison": z.home})
			z.remove_from_group("zombies")
			z.remove_from_group("boss")
			z.queue_free()
	for i in range(zombies_virtuels.size() - 1, -1, -1):
		var v: Dictionary = zombies_virtuels[i]
		if Vector3(v.pos).distance_to(pp) < DIST_REVEIL:
			zombies_virtuels.remove_at(i)
			var z = spawn_zombie(v.pos, v.kind, true, v.rayon)
			if float(v.pv) > 0.0:
				z.health = float(v.pv)
			z.home = v.maison


# ---------------------------------------------------------------- hordes
## À la tombée de la nuit (dès le 2e jour), une horde peut marcher sur la base du joueur.
## Joueur à proximité : vrais zombies qui tapent dans les murs. Joueur au loin : attaque simulée.
var etait_nuit := false
var horde_init := false


func _gerer_hordes() -> void:
	var nuit := Game.is_night()
	if not horde_init:
		# partie chargée de nuit : pas d'attaque immédiate
		horde_init = true
		etait_nuit = nuit
		return
	if nuit and not etait_nuit:
		_nuit_tombe()
	elif not nuit and etait_nuit:
		# le jour se lève : la horde se disperse
		for z in get_tree().get_nodes_in_group("horde"):
			z.assaut = false
	etait_nuit = nuit


## La plus grande base du joueur (au moins 4 pièces).
func _base_principale() -> Node3D:
	var meilleure: Node3D = null
	var n := 3
	for b in get_tree().get_nodes_in_group("base_construction"):
		if b.get_child_count() > n:
			n = b.get_child_count()
			meilleure = b
	return meilleure


func _nuit_tombe() -> void:
	if Game.day < 2:
		return
	var base := _base_principale()
	if base == null or randf() > minf(0.3 + 0.05 * Game.day, 0.6):
		return
	annoncer_horde(base)


## Alerte : la horde arrive dans 60 s (le temps de rentrer et de se préparer), on sait de quel côté elle vient :
## direction annoncée, rappels, distance jusqu'à la base, grognements qui montent de ce côté-là.
const HORDE_DELAI := 60.0
var horde_compte := -1.0
var horde_base: Node3D = null
var horde_angle := NAN          # direction d'arrivée (choisie à l'alerte, gardée pour l'attaque)
var horde_grogne_t := 0.0


func annoncer_horde(base: Node3D) -> void:
	if player.global_position.distance_to(_centre_base(base)) > 90.0:
		Game.msg("!! ALERTE : une horde attaque ta base au loin !")
		Game.play_ui("grogne2", 0.0, 0.05, 0.6)
		declencher_horde(base)
		return
	horde_base = base
	horde_compte = HORDE_DELAI
	horde_angle = randf() * TAU
	horde_grogne_t = 6.0
	Game.msg("!! ALERTE : une horde approche de ta base par %s ! Arrivée dans %d secondes." % [_nom_direction(horde_angle), int(HORDE_DELAI)])
	Game.play_ui("grogne1", 4.0, 0.05, 0.55)
	Game.play_ui("grogne3", 0.0, 0.05, 0.7)


func _compte_horde(delta: float) -> void:
	if horde_compte <= 0.0:
		return
	var avant := horde_compte
	horde_compte -= delta
	for rappel in [45.0, 30.0, 15.0, 5.0]:
		if avant > rappel and horde_compte <= rappel:
			Game.msg("!! La horde arrive par %s dans %d secondes !" % [_nom_direction(horde_angle), int(rappel)])
			Game.play_ui("grogne%d" % randi_range(1, 3), 2.0, 0.1, 0.6)
	# grognements lointains venant du côté où la horde arrivera, de plus en plus souvent
	horde_grogne_t -= delta
	if horde_grogne_t <= 0.0 and horde_base and is_instance_valid(horde_base) and not is_nan(horde_angle):
		horde_grogne_t = lerpf(3.0, 9.0, horde_compte / HORDE_DELAI)
		var c := _centre_base(horde_base)
		var d := Vector3(cos(horde_angle), 0.0, sin(horde_angle))
		var loin := lerpf(22.0, 45.0, horde_compte / HORDE_DELAI)
		Game.play_3d("grogne%d" % randi_range(1, 3), c + d * loin + Vector3.UP, 4.0, 0.15, 90.0)
	if horde_compte <= 0.0:
		horde_compte = -1.0
		if horde_base and is_instance_valid(horde_base):
			declencher_horde(horde_base)
		horde_base = null


## Texte d'alerte affiché en haut de l'écran (vide s'il n'y a rien).
func texte_alerte() -> String:
	if horde_compte > 0.0:
		var t := "!! HORDE EN APPROCHE — %d s — par %s" % [ceili(horde_compte), _nom_direction(horde_angle)]
		if horde_base and is_instance_valid(horde_base):
			var db: float = player.global_position.distance_to(_centre_base(horde_base))
			if db > 15.0:
				t += "\nRentre à ta base : %d m" % int(db)
		return t
	var n := 0
	for z in get_tree().get_nodes_in_group("horde"):
		if is_instance_valid(z) and z.assaut and z.state != 3:
			n += 1
	return "!! HORDE EN COURS — %d zombie(s)" % n if n > 0 else ""


func _centre_base(base: Node3D) -> Vector3:
	var c := Vector3.ZERO
	for p in base.get_children():
		c += (p as Node3D).global_position
	return c / maxf(1.0, base.get_child_count())


func declencher_horde(base: Node3D) -> void:
	var centre := _centre_base(base)
	var nb := clampi(4 + 2 * Game.day, 6, 16)
	if player.global_position.distance_to(centre) > 90.0:
		_horde_simulee(base, centre, nb)
		return
	var ang := horde_angle if not is_nan(horde_angle) else randf() * TAU
	horde_angle = NAN
	var poses := 0
	for k in nb * 4:
		if poses >= nb:
			break
		var a := ang + randf_range(-0.5, 0.5)
		var p := centre + Vector3(cos(a), 0, sin(a)) * randf_range(38.0, 50.0)
		p.y = Game.hauteur(p.x, p.z) + 0.15
		if Game.relief and Game.relief.dans_eau(p.x, p.z):
			continue
		if absf(p.x) > Game.map_half - 10.0 or absf(p.z) > Game.map_half - 10.0:
			continue
		if not Game.find_zone(p + Vector3.UP).is_empty():
			continue
		var r := randf()
		var kind := "coureur" if r < 0.25 else ("gros" if r < 0.4 else "civil")
		var z = spawn_zombie(p, kind, false, 15.0)
		z.add_to_group("horde")
		z.assaut = true
		z.assaut_pos = centre
		z.state = z.State.CHASE
		z.target = centre
		poses += 1
	if poses > 0:
		Game.msg("Une horde de %d zombies marche sur ta base !" % poses)
		Game.play_ui("grogne1", 2.0, 0.1, 0.7)


## Joueur absent : la horde abîme la base ; les pièges autour réduisent les dégâts (et s'usent).
func _horde_simulee(base: Node3D, centre: Vector3, nb: int) -> void:
	var pieces := []
	for p in base.get_children():
		if p.has_method("detruire") and not p.type in ["plancher", "escalier"]:
			pieces.append(p)
	if pieces.is_empty():
		return
	var protection := 0.0
	for t in get_tree().get_nodes_in_group("piege"):
		if t.global_position.distance_to(centre) < 20.0:
			protection = minf(0.5, protection + 0.1)
			t.health -= 40.0
			if t.health <= 0.0:
				t.queue_free()
	var coups := 2 + nb / 3
	var abimees := 0
	var detruites := 0
	for k in coups:
		if pieces.is_empty():
			break
		var p = pieces.pick_random()
		if not is_instance_valid(p) or p.is_queued_for_deletion():
			continue
		p.pv -= 110.0 * nb / coups * randf_range(0.6, 1.4) * (1.0 - protection)
		abimees += 1
		if p.pv <= 0.0:
			detruites += 1
			pieces.erase(p)
			p.detruire()
	Game.msg("Pendant ton absence, une horde a attaqué ta base : %d coups encaissés, %d pièce(s) détruite(s)." % [abimees, detruites])


func spawn_zombie(pos: Vector3, kind: String, persistent: bool, radius: float) -> Node:
	var z = ZOMBIE_SCENE.instantiate()
	z.setup(kind, persistent, radius)
	z.position = pos
	zombies_root.add_child(z)
	return z


var auto_t := 300.0


func _process(delta: float) -> void:
	_maj_ambiance(delta)
	_compte_horde(delta)
	auto_t -= delta
	if auto_t <= 0.0:
		auto_t = 300.0
		if not Game.ui_open:
			sauvegarder(true)
	spawn_t -= delta
	if spawn_t > 0.0 or player == null or not player.alive:
		return
	spawn_t = 1.0
	_gerer_virtuels()
	_gerer_hordes()
	var roamers := 0
	for z in get_tree().get_nodes_in_group("zombies"):
		if z.persistent:
			continue
		if z.global_position.distance_to(player.global_position) > 140.0:
			z.queue_free()
			continue
		roamers += 1
	# début de partie plus doux (pas d'arme à feu au départ) : la pression monte au fil des jours
	var jour := clampi(Game.day, 1, 3)
	var max_z: int = [0, 22, 28, 35][jour] if not Game.is_night() else [0, 38, 48, 60][jour]
	var budget := 12 if first_fill else 3
	first_fill = false
	while roamers < max_z and budget > 0:
		budget -= 1
		if _spawn_roamer():
			roamers += 1


func _spawn_roamer() -> bool:
	var space := get_world_3d().direct_space_state
	for attempt in 8:
		var ang := randf() * TAU
		var dist := randf_range(45.0, 100.0)
		var p: Vector3 = player.global_position + Vector3(cos(ang), 0, sin(ang)) * dist
		p.y = Game.hauteur(p.x, p.z) + 0.15
		if Game.relief and Game.relief.dans_eau(p.x, p.z):
			continue
		if absf(p.x) > Game.map_half - 10.0 or absf(p.z) > Game.map_half - 10.0:
			continue
		if not Game.find_zone(p + Vector3.UP).is_empty():
			continue
		if not Game.in_city(p) and randf() < 0.6:
			continue
		if pres_camp_marchand(p, 35.0):
			continue
		var pq := PhysicsPointQueryParameters3D.new()
		pq.position = p + Vector3.UP * 0.9
		pq.collision_mask = Game.LAYER_WORLD
		if not space.intersect_point(pq, 1).is_empty():
			continue
		# variété : coureurs (surtout la nuit), gros, rampants
		var r := randf()
		var kind := "civil"
		var premier_jour := Game.day <= 1
		if r < (0.22 if Game.is_night() else 0.12) * (0.5 if premier_jour else 1.0):
			kind = "coureur"
		elif r < (0.22 if premier_jour else 0.3) and r >= 0.14:
			kind = "gros"
		elif r < 0.38 and r >= 0.3:
			kind = "rampant"
		spawn_zombie(p, kind, false, 15.0)
		return true
	return false


## Ambiances sonores : vent, campagne (jour), grillons (nuit), ville, grotte, musique du boss.
## Les pistes se fondent les unes dans les autres selon l'endroit et l'heure.
var ambiances := {}
var reverb_idx := -1


func _ambience() -> void:
	for nom in ["vent", "amb_campagne", "amb_nuit", "amb_ville", "amb_grotte", "musique_boss"]:
		var s = Game.sfx_boucle(nom)
		if s == null:
			continue
		var a := AudioStreamPlayer.new()
		a.stream = s
		a.volume_db = -60.0
		a.autoplay = true
		add_child(a)
		ambiances[nom] = a
	# écho dans la grotte
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.85
	rv.damping = 0.3
	rv.wet = 0.35
	rv.dry = 0.9
	AudioServer.add_bus_effect(0, rv)
	reverb_idx = AudioServer.get_bus_effect_count(0) - 1
	AudioServer.set_bus_effect_enabled(0, reverb_idx, false)


func _exit_tree() -> void:
	if reverb_idx >= 0 and reverb_idx < AudioServer.get_bus_effect_count(0):
		AudioServer.remove_bus_effect(0, reverb_idx)
		reverb_idx = -1


func _maj_ambiance(delta: float) -> void:
	if ambiances.is_empty() or player == null:
		return
	var p: Vector3 = player.global_position
	var dans_grotte := Game.grotte_rect.has_point(Vector2(p.x, p.z)) and p.y < 8.0
	var dedans: bool = not player.in_zone.is_empty()
	var ville := Game.in_city(p)
	var nuit := Game.is_night()
	var boss := false
	for b in get_tree().get_nodes_in_group("boss"):
		if b.state == b.State.CHASE or b.global_position.distance_to(p) < 25.0:
			boss = true
	var ext := 0.0 if dans_grotte else (0.45 if dedans else 1.0)
	var cibles := {
		"vent": (0.55 if ville else 0.4) * ext,
		"amb_campagne": (0.0 if (nuit or ville) else 0.75) * ext,
		"amb_nuit": (0.7 if (nuit and not ville) else (0.25 if nuit else 0.0)) * ext,
		"amb_ville": (0.75 if ville else 0.0) * ext,
		"amb_grotte": 0.9 if dans_grotte else 0.0,
		"musique_boss": 0.85 if (boss and player.alive) else 0.0,
	}
	for nom in ambiances:
		var a: AudioStreamPlayer = ambiances[nom]
		var lin := db_to_linear(a.volume_db)
		lin = move_toward(lin, float(cibles.get(nom, 0.0)) * 0.35, delta * 0.25)
		a.volume_db = linear_to_db(maxf(lin, 0.0005))
	if reverb_idx >= 0:
		AudioServer.set_bus_effect_enabled(0, reverb_idx, dans_grotte)


## Éclairage des rues, détails du monde (décalques, herbe) et météo.
func _creer_ambiance() -> void:
	var eclairage = preload("res://scripts/eclairage_rues.gd").new()
	eclairage.name = "EclairageRues"
	add_child(eclairage)
	eclairage.installer(world.lampadaires, Game.graine_monde)
	var details = preload("res://scripts/details_monde.gd").new()
	details.name = "DetailsMonde"
	details.installer(world, Game.graine_monde)
	world.morceaux.ranger(details)   # décalques et déchets fixes : par cases, comme le monde
	add_child(details)
	var meteo = preload("res://scripts/meteo.gd").new()
	meteo.name = "Meteo"
	add_child(meteo)
	meteo.installer(world, Game.graine_monde)


## Nom de la direction (avec l'article) pour un angle d'arrivée autour de la base : x = cos, z = sin, le nord est -Z.
func _nom_direction(ang: float) -> String:
	if is_nan(ang):
		return "un côté inconnu"
	var noms := ["le nord", "le nord-est", "l'est", "le sud-est", "le sud", "le sud-ouest", "l'ouest", "le nord-ouest"]
	var cap := fposmod(atan2(cos(ang), -sin(ang)), TAU)   # 0 = nord, sens horaire
	return noms[int(round(cap / (TAU / 8.0))) % 8]
