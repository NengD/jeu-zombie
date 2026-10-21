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
var echelles: Array = []   # échelles qu'on peut gravir : {pos (pied), n (normale vers l'extérieur), haut}
var map_rects: Array = []  # rectangles de la carte : {rect, color}
var relief = null          # relief de la campagne (scripts/relief.gd)
var buissons := {}         # cases de 8 m -> [[position, rayon], …] : on s'y cache (vue des zombies réduite)
var sans_herbe: Array = []  # [centre, rayon] des campements (sol tassé, pas d'herbe haute)
var carte_relief: Texture2D = null
var grotte_rect := Rect2()   # emprise de la grotte (ambiance, écho)
var sols: Array = []          # [{r: Rect2, s: "beton"/"terre"}] : routes, chemins, dalles (bruits de pas)


## Nature du sol sous un point extérieur (pour les bruits de pas).
func sol_exterieur(pos: Vector3) -> String:
	if dans_eau(pos):
		return "eau"
	if in_city(pos):
		return "beton"
	var p := Vector2(pos.x, pos.z)
	for e in sols:
		if Rect2(e.r).has_point(p):
			return e.s
	if relief and relief.rive.size() > 0:
		var fx := clampi(int(round((pos.x + relief.demi) / relief.PAS)), 0, relief.n - 1)
		var fz := clampi(int(round((pos.z + relief.demi) / relief.PAS)), 0, relief.n - 1)
		if relief.rive[fz * relief.n + fx] > 0.45:
			return "terre"
	return "herbe"


## Hauteur du sol à l'extérieur (0 en ville et sur les routes).
func hauteur(x: float, z: float) -> float:
	return relief.hauteur(x, z) if relief else 0.0


func dans_eau(pos: Vector3) -> bool:
	return relief != null and relief.dans_eau(pos.x, pos.z) and pos.y < -0.8
var map_half := 2500.0     # carte de 5 × 5 km
var city_half := 161.0
var villes: Array = []       # [{c: centre, demi: demi-côté}] : villes de la carte (world_gen)
var ui_open := false
var time_hours := 8.0
var graine_monde := 0
var partie_a_charger: Dictionary = {}   # rempli par « Continuer » : partie à reprendre
# --- mode admin (tests) : rien n'est sauvegardé
var admin := false
var admin_invincible := true
var admin_munitions := true
var admin_vol := false
var admin_murs := false        # traverser les murs en volant
var admin_invisible := false   # les zombies ne voient plus le joueur
var admin_besoins := true      # ni faim, ni soif, endurance infinie
var day := 1
var blood_mat: StandardMaterial3D

# --- paramètres (sauvegardés dans user://parametres.cfg)
var mouse_sens := 1.0
var volume := 0.8
var pluie := 0.0                 # intensité de la pluie (0..1), gérée par meteo.gd
var qualite := 3                # qualité graphique : 0 Bas, 1 Moyen, 2 Élevé, 3 Ultra
const NOMS_QUALITE := ["Bas", "Moyen", "Élevé", "Ultra"]
signal graphismes_changes
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
	_index_zones.clear()
	_nb_zones_indexees = 0
	pois.clear()
	echelles.clear()
	map_rects.clear()
	relief = null
	sols.clear()
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
	_phys("inventaire", KEY_TAB)
	_key("inventaire", KEY_I)
	_key("carte", KEY_M)
	_key("lampe", KEY_L)
	_key("soigner", KEY_H)
	_key("inspecter", KEY_T)
	_key("construire", KEY_B)
	_key("ameliorer", KEY_G)
	_key("demonter", KEY_X)
	_key("competences", KEY_K)
	_phys("admin_panneau", KEY_F2)
	_key("admin_vol", KEY_N)
	_phys("sauvegarde_rapide", KEY_F5)
	_phys("chargement_rapide", KEY_F9)
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
		qualite = clampi(int(cf.get_value("jeu", "qualite", 3)), 0, 3)
	apply_settings()


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("jeu", "sensibilite", mouse_sens)
	cf.set_value("jeu", "volume", volume)
	cf.set_value("jeu", "qualite", qualite)
	cf.save(SETTINGS_PATH)
	apply_settings()


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	_appliquer_rendu()
	graphismes_changes.emit()


## Anticrénelage et qualité des ombres selon le niveau choisi (l'éclairage est réglé par day_night.gd).
func _appliquer_rendu() -> void:
	var vp := get_tree().root
	vp.msaa_3d = Viewport.MSAA_2X if qualite == 1 else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if qualite == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = qualite >= 2
	vp.use_debanding = qualite >= 1
	vp.mesh_lod_threshold = [4.0, 2.0, 1.0, 0.5][qualite]
	var ombres: RenderingServer.ShadowQuality = [RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
			RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][qualite]
	RenderingServer.directional_soft_shadow_filter_set_quality(ombres)
	RenderingServer.positional_soft_shadow_filter_set_quality(ombres)
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 4096, 8192][qualite], true)
	vp.positional_shadow_atlas_size = [2048, 4096, 4096, 8192][qualite]


## Reprend la partie sauvegardée.
func charger_partie() -> void:
	partie_a_charger = Sauvegarde.lire()
	admin = false
	get_tree().paused = false
	ui_open = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func go_to_menu() -> void:
	get_tree().paused = false
	ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# ---------------------------------------------------------------- helpers
func msg(text: String) -> void:
	notify.emit(text)


func make_noise(pos: Vector3, radius: float) -> void:
	noise_made.emit(pos, radius * (1.0 - 0.3 * pluie))   # la pluie couvre les bruits


func ajouter_buisson(pos: Vector3, rayon: float) -> void:
	var c := Vector2i(floori(pos.x / 8.0), floori(pos.z / 8.0))
	if not buissons.has(c):
		buissons[c] = []
	buissons[c].append([pos, rayon])


## Le point est-il à l'intérieur d'un buisson ?
func dans_buisson(pos: Vector3) -> bool:
	var c := Vector2i(floori(pos.x / 8.0), floori(pos.z / 8.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for b in buissons.get(c + Vector2i(dx, dz), []):
				var bp: Vector3 = b[0]
				if Vector2(pos.x - bp.x, pos.z - bp.z).length() < float(b[1]):
					return true
	return false


func is_night() -> bool:
	return time_hours < 6.0 or time_hours >= 20.5


## Prochain passage (porte ou escalier) pour aller de la zone « de » à la zone « vers »
## ({} = dehors). Parcours en largeur du graphe des bâtiments et étages.
func prochain_lien(de: Dictionary, vers: Dictionary) -> Dictionary:
	var id_de: int = de.get("id", -1) if not de.is_empty() else -1
	var id_vers: int = vers.get("id", -1) if not vers.is_empty() else -1
	if id_de == id_vers:
		return {}
	var prec := {id_de: null}
	var file := [id_de]
	while not file.is_empty():
		var cur: int = file.pop_front()
		if cur == id_vers:
			break
		var liens: Array = []
		if cur == -1:
			# dehors : on entre par les portes du bâtiment visé
			if id_vers >= 0:
				var cible: Dictionary = zones[id_vers]
				var rez: Dictionary = zones[cible.get("batiment", id_vers)]
				for l in rez.get("liens", []):
					if l.type == "porte":
						liens.append({"pos": l.pos, "a": l.b, "b": l.a, "vers": rez.id, "type": "porte"})
		else:
			liens = zones[cur].get("liens", [])
		for l in liens:
			var v: int = l.vers
			if not prec.has(v):
				prec[v] = [cur, l]
				file.append(v)
	if not prec.has(id_vers):
		return {}
	var n := id_vers
	var lien: Dictionary = {}
	while prec[n] != null:
		lien = prec[n][1]
		n = prec[n][0]
	return lien


func find_zone(pos: Vector3) -> Dictionary:
	_indexer_zones()
	for i in _index_zones.get(Vector2i(floori(pos.x / 64.0), floori(pos.z / 64.0)), []):
		if zones[i].aabb.has_point(pos):
			return zones[i]
	return {}


## Zones indexées par cases de 64 m (numéros dans l'ordre de « zones » : même résultat qu'un parcours complet).
var _index_zones := {}
var _nb_zones_indexees := 0


func _indexer_zones() -> void:
	if _nb_zones_indexees > zones.size():   # zones vidées (nouvelle partie)
		_index_zones.clear()
		_nb_zones_indexees = 0
	while _nb_zones_indexees < zones.size():
		var ab: AABB = zones[_nb_zones_indexees].aabb
		for cz in range(floori(ab.position.z / 64.0), floori(ab.end.z / 64.0) + 1):
			for cx in range(floori(ab.position.x / 64.0), floori(ab.end.x / 64.0) + 1):
				var k := Vector2i(cx, cz)
				if not _index_zones.has(k):
					_index_zones[k] = []
				_index_zones[k].append(_nb_zones_indexees)
		_nb_zones_indexees += 1


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
	if villes.is_empty():
		return absf(pos.x) < city_half and absf(pos.z) < city_half
	for v in villes:
		if absf(pos.x - v.c.x) < float(v.demi) and absf(pos.z - v.c.z) < float(v.demi):
			return true
	return false


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
