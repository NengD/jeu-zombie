extends Node3D
## Scène principale : génère le monde, place le joueur, gère l'apparition des zombies.

const WorldGen = preload("res://scripts/world_gen.gd")
const DayNight = preload("res://scripts/day_night.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const InventoryUI = preload("res://scripts/ui/inventory_ui.gd")
const InspectionUI = preload("res://scripts/ui/inspection_ui.gd")
const CompetencesUI = preload("res://scripts/ui/competences_ui.gd")
const MapUI = preload("res://scripts/ui/map_ui.gd")
const PLAYER_SCENE = preload("res://scenes/player.tscn")
const ZOMBIE_SCENE = preload("res://scenes/zombie.tscn")

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
	add_child(world)
	var spawn: Vector3 = world.build(s)
	var dn = DayNight.new()
	dn.name = "Cycle"
	add_child(dn)
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
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = spawn + Vector3.UP * 0.1
	var door_dir: Vector3 = world.spawn_point - world.spawn_zone.center
	player.rotation.y = atan2(-door_dir.x, -door_dir.z)  # dos au bâtiment
	add_child(Hud.new())
	add_child(InventoryUI.new())
	add_child(InspectionUI.new())
	add_child(CompetencesUI.new())
	add_child(MapUI.new())
	if Game.admin:
		add_child(preload("res://scripts/ui/admin_ui.gd").new())
	_ambience()
	if charge.is_empty():
		Game.msg("Bienvenue. Trouve de quoi survivre. [F1] pour l'aide.")
	else:
		Sauvegarde.appliquer_joueur(self, charge)
		Game.msg("Partie chargée — jour %d." % Game.day)


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


func spawn_zombie(pos: Vector3, kind: String, persistent: bool, radius: float) -> Node:
	var z = ZOMBIE_SCENE.instantiate()
	z.setup(kind, persistent, radius)
	z.position = pos
	zombies_root.add_child(z)
	return z


var auto_t := 300.0


func _process(delta: float) -> void:
	_maj_ambiance(delta)
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
		var s = Game.sfx(nom)
		if s == null:
			continue
		if s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
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
