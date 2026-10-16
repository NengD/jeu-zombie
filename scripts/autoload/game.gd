extends Node
## État global du jeu : touches, zones intérieures, bruit, messages, heure.

signal noise_made(pos: Vector3, radius: float)
signal notify(text: String)
signal hit_confirmed(headshot: bool, kill: bool)
signal player_died

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ZOMBIE := 4
const LAYER_INTERACT := 8

const DAY_SECONDS := 1440.0  # une journée complète = 24 minutes réelles

var player: CharacterBody3D = null
var zones: Array = []      # bâtiments : {aabb, doors, kind, name}
var pois: Array = []       # points d'intérêt pour la carte : {name, pos, color}
var map_rects: Array = []  # rectangles de la carte : {rect, color}
var map_half := 420.0
var city_half := 161.0
var ui_open := false
var time_hours := 8.0
var day := 1
var blood_mat: StandardMaterial3D

# --- paramètres (sauvegardés dans user://parametres.cfg)
var mouse_sens := 1.0
var volume := 0.8
const SETTINGS_PATH := "user://parametres.cfg"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	load_settings()
	blood_mat = StandardMaterial3D.new()
	blood_mat.albedo_color = Color(0.35, 0.02, 0.02)
	blood_mat.roughness = 0.4


func reset() -> void:
	zones.clear()
	pois.clear()
	map_rects.clear()
	ui_open = false
	time_hours = 8.0
	day = 1
	player = null


# ---------------------------------------------------------------- touches
# Les déplacements utilisent la POSITION physique des touches (ZQSD sur AZERTY,
# WASD sur QWERTY). Les autres touches utilisent la lettre affichée.
func _setup_inputs() -> void:
	_phys("avancer", KEY_W)
	_phys("reculer", KEY_S)
	_phys("gauche", KEY_A)
	_phys("droite", KEY_D)
	_phys("pencher_gauche", KEY_Q)  # touche A sur AZERTY
	_phys("pencher_droite", KEY_E)
	_phys("sauter", KEY_SPACE)
	_phys("sprint", KEY_SHIFT)
	_key("accroupir", KEY_C)
	_phys("accroupir", KEY_CTRL)
	_key("interagir", KEY_F)
	_key("recharger", KEY_R)
	_key("vue", KEY_V)
	_phys("inventaire", KEY_TAB)
	_key("inventaire", KEY_I)
	_key("carte", KEY_M)
	_key("lampe", KEY_L)
	_key("soigner", KEY_H)
	_key("inspecter", KEY_T)
	_phys("aide", KEY_F1)
	_phys("pause", KEY_ESCAPE)
	_mouse("tirer", MOUSE_BUTTON_LEFT)
	_mouse("viser", MOUSE_BUTTON_RIGHT)
	_mouse("arme_suiv", MOUSE_BUTTON_WHEEL_DOWN)
	_mouse("arme_prec", MOUSE_BUTTON_WHEEL_UP)
	var nums := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
	for i in nums.size():
		_phys("arme_%d" % (i + 1), nums[i])


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _phys(action: String, code: Key) -> void:
	_ensure(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	InputMap.action_add_event(action, ev)


func _key(action: String, code: Key) -> void:
	_ensure(action)
	var ev := InputEventKey.new()
	ev.keycode = code
	InputMap.action_add_event(action, ev)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- paramètres
func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		mouse_sens = float(cf.get_value("jeu", "sensibilite", 1.0))
		volume = float(cf.get_value("jeu", "volume", 0.8))
	apply_settings()


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("jeu", "sensibilite", mouse_sens)
	cf.set_value("jeu", "volume", volume)
	cf.save(SETTINGS_PATH)
	apply_settings()


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


func go_to_menu() -> void:
	get_tree().paused = false
	ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# ---------------------------------------------------------------- helpers
func msg(text: String) -> void:
	notify.emit(text)


func make_noise(pos: Vector3, radius: float) -> void:
	noise_made.emit(pos, radius)


func is_night() -> bool:
	return time_hours < 6.0 or time_hours >= 20.5


func find_zone(pos: Vector3) -> Dictionary:
	for z in zones:
		if z.aabb.has_point(pos):
			return z
	return {}


func zombies_in_zone(zone: Dictionary) -> int:
	if zone.is_empty():
		return 0
	var n := 0
	for zb in get_tree().get_nodes_in_group("zombies"):
		if zone.aabb.has_point(zb.global_position + Vector3.UP * 0.5):
			n += 1
	return n


# ---------------------------------------------------------------- sons
var _sfx := {}


func sfx(sound: String) -> AudioStream:
	if _sfx.has(sound):
		return _sfx[sound]
	var path := "res://sons/%s.wav" % sound
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_sfx[sound] = s
	return s


## Son spatialisé (zombies, impacts…)
func play_3d(sound: String, pos: Vector3, vol_db := 0.0, pitch_var := 0.1, max_dist := 60.0) -> void:
	var s := sfx(sound)
	var scene := get_tree().current_scene
	if s == null or scene == null:
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = s
	a.volume_db = vol_db
	a.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	a.max_distance = max_dist
	a.unit_size = 8.0
	scene.add_child(a)
	a.global_position = pos
	a.finished.connect(a.queue_free)
	a.play()


## Son non spatialisé (actions du joueur)
func play_ui(sound: String, vol_db := 0.0, pitch_var := 0.06, pitch := 1.0) -> void:
	var s := sfx(sound)
	var scene := get_tree().current_scene
	if s == null or scene == null:
		return
	var a := AudioStreamPlayer.new()
	a.stream = s
	a.volume_db = vol_db
	a.pitch_scale = pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	scene.add_child(a)
	a.finished.connect(a.queue_free)
	a.play()


func in_city(pos: Vector3) -> bool:
	return absf(pos.x) < city_half and absf(pos.z) < city_half


func spawn_blood(pos: Vector3, parent: Node) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.07
	s.height = 0.14
	m.mesh = s
	m.material_override = blood_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = pos
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * 0.2, 0.35)
	tw.tween_callback(m.queue_free)
