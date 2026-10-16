extends Node3D
## Scène principale : génère le monde, place le joueur, gère l'apparition des zombies.

const WorldGen = preload("res://scripts/world_gen.gd")
const DayNight = preload("res://scripts/day_night.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const InventoryUI = preload("res://scripts/ui/inventory_ui.gd")
const InspectionUI = preload("res://scripts/ui/inspection_ui.gd")
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
			spawn_zombie(g.pos, g.kind, true, g.radius)
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
	add_child(MapUI.new())
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
	if Sauvegarde.sauver(self):
		Game.msg("Sauvegarde automatique." if auto else "Partie sauvegardée.")
	else:
		Game.msg("Impossible de sauvegarder.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sauvegarde_rapide"):
		sauvegarder()
	elif event.is_action_pressed("chargement_rapide"):
		if Sauvegarde.existe():
			Game.charger_partie()
		else:
			Game.msg("Aucune sauvegarde.")


func spawn_zombie(pos: Vector3, kind: String, persistent: bool, radius: float) -> Node:
	var z = ZOMBIE_SCENE.instantiate()
	z.setup(kind, persistent, radius)
	z.position = pos
	zombies_root.add_child(z)
	return z


var auto_t := 300.0


func _process(delta: float) -> void:
	auto_t -= delta
	if auto_t <= 0.0:
		auto_t = 300.0
		if not Game.ui_open:
			sauvegarder(true)
	spawn_t -= delta
	if spawn_t > 0.0 or player == null or not player.alive:
		return
	spawn_t = 1.0
	var roamers := 0
	for z in get_tree().get_nodes_in_group("zombies"):
		if z.persistent:
			continue
		if z.global_position.distance_to(player.global_position) > 140.0:
			z.queue_free()
			continue
		roamers += 1
	var max_z := 60 if Game.is_night() else 35
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
		p.y = 0.1
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
		spawn_zombie(p, "civil", false, 15.0)
		return true
	return false


func _ambience() -> void:
	var s = Game.sfx("vent")
	if s == null:
		return
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	var a := AudioStreamPlayer.new()
	a.stream = s
	a.volume_db = -14.0
	a.autoplay = true
	add_child(a)
