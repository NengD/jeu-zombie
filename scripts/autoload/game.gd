extends Node
## État global du jeu : touches, zones intérieures, bruit, messages, heure.

signal noise_made(pos: Vector3, radius: float)
signal notify(text: String)
signal objet_recu(id: String, n: int)   # fil des objets reçus (HUD, scripts/ui/fil_objets.gd) ; id "argent" = euros
signal hit_confirmed(headshot: bool, kill: bool)
signal degats_infliges(cible: Node3D, montant: float, pos: Vector3, genre: int)   # genre : 0 normal, 1 tête, 2 critique
signal texte_flottant(pos: Vector3, texte: String, couleur: Color)   # (récolte : coups portés)
var recolte: Node = null           # scripts/recolte.gd (arbres, rochers, épaves)
var coup_critique := false         # le coup en cours du joueur est un coup critique (talent)
var explosion_joueur := false      # dégâts d'une grenade lancée par le joueur en cours
var tir_discret := false           # coup d'une flèche en cours : la cible qui ne voyait pas le tireur reste discrète
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
var ramassage_auto := true      # munitions et flèches ramassées en passant dessus
var sens_visee := 1.0           # multiplicateur de sensibilité en visée
var fov := 70.0                 # champ de vision (degrés, vertical)
var vol_effets := 1.0           # volumes par catégorie (bus audio Effets / Voix / Ambiance)
var vol_voix := 1.0
var vol_ambiance := 1.0
var taille_texte := 1.0         # échelle de toute l'interface
const BUS := ["Effets", "Voix", "Ambiance"]
# touches modifiables (Paramètres) : [action, libellé]
const TOUCHES_MODIFIABLES := [["avancer", "Avancer"], ["reculer", "Reculer"], ["gauche", "Aller à gauche"], ["droite", "Aller à droite"],
	["sprint", "Sprinter"], ["sauter", "Sauter"], ["accroupir", "S'accroupir"], ["pencher_gauche", "Se pencher à gauche"], ["pencher_droite", "Se pencher à droite"],
	["tirer", "Frapper / tirer"], ["viser", "Viser / parer"], ["recharger", "Recharger"], ["interagir", "Fouiller / utiliser"], ["soigner", "Se soigner"],
	["inventaire", "Inventaire"], ["carte", "Carte"], ["lampe", "Lampe"], ["inspecter", "Inspecter l'arme"], ["construire", "Mode construction"],
	["ameliorer", "Renforcer / réparer"], ["demonter", "Démonter une pièce"], ["competences", "Personnage"]]
const NOMS_QUALITE := ["Bas", "Moyen", "Élevé", "Ultra"]
signal graphismes_changes
const SETTINGS_PATH := "user://parametres.cfg"


## Mode test (variable d'environnement JZ_TEST=1, pour les sessions de développement qui ouvrent le jeu) :
## la fenêtre ne prend jamais le focus et la souris n'est jamais capturée, pour ne pas gêner l'utilisateur.
var mode_test := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mode_test = OS.get_environment("JZ_TEST") != ""
	set_process(mode_test)
	if mode_test and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	_setup_inputs()
	load_settings()


func _process(_delta: float) -> void:
	# mode test : le jeu (joueur, menus) capture la souris à plusieurs endroits ; on la relâche aussitôt
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	marqueurs.clear()
	lieux_fouilles.clear()


# ---------------------------------------------------------------- carte : marqueurs, lieux fouillés, marchands
var marqueurs: Array = []        # marqueurs personnels de la carte : {nom, x, z} (sauvegardés)
var lieux_fouilles := {}         # cle_lieu(poi) -> true : lieux dont presque tout a été fouillé


## Centre de la base du joueur (sa plus grande construction, au moins 3 pièces), Vector3.INF s'il n'en a pas.
## Recalculé au plus toutes les 2 s (carte et boussole l'appellent à chaque image).
var _base_cache := Vector3.INF
var _base_t := -100.0


func position_base() -> Vector3:
	var t := Time.get_ticks_msec() / 1000.0
	if t - _base_t < 2.0:
		return _base_cache
	_base_t = t
	_base_cache = Vector3.INF
	var meilleure: Node = null
	var nb := 2
	for b in get_tree().get_nodes_in_group("base_construction"):
		if is_instance_valid(b) and b.get_child_count() > nb:
			nb = b.get_child_count()
			meilleure = b
	if meilleure:
		var c := Vector3.ZERO
		var n := 0
		for piece in meilleure.get_children():
			if piece is Node3D:
				c += (piece as Node3D).global_position
				n += 1
		if n > 0:
			_base_cache = c / n
	return _base_cache


func cle_lieu(poi: Dictionary) -> String:
	return "%s@%d,%d" % [poi.name, int(poi.pos.x), int(poi.pos.z)]


## Lieux trop vastes pour être « fouillés » (villes, villages, forêts…).
func lieu_vaste(nom: String) -> bool:
	return nom in ["Bellerive", "Valmont"] or nom.begins_with("Village") or nom.begins_with("Hameau") \
			or nom.begins_with("Forêt") or nom.begins_with("Bois ") or nom == "Camp de bandits"


## Après une fouille en `pos` : le lieu le plus proche (60 m) est marqué fouillé quand 80 % de ses meubles
## (à 40 m de son centre) l'ont été.
func maj_lieu_fouille(pos: Vector3) -> void:
	var best: Dictionary = {}
	var dmin := 60.0
	for poi in pois:
		if poi.get("marchand", false) or lieu_vaste(poi.name):
			continue
		var d := Vector2(poi.pos.x - pos.x, poi.pos.z - pos.z).length()
		if d < dmin:
			dmin = d
			best = poi
	if best.is_empty() or lieux_fouilles.has(cle_lieu(best)):
		return
	var total := 0
	var faits := 0
	for c in get_tree().get_nodes_in_group("conteneurs"):
		if c.is_storage or c.is_in_group("tas_sol"):
			continue
		var cp: Vector3 = c.global_position
		if Vector2(cp.x - best.pos.x, cp.z - best.pos.z).length() < 40.0:
			total += 1
			if c.searched:
				faits += 1
	if total >= 2 and faits >= ceili(total * 0.8):
		lieux_fouilles[cle_lieu(best)] = true
		msg("Lieu fouillé : %s" % best.name)


## Campement de marchands le plus proche : {name, pos} (vide s'il n'y en a pas).
func marchand_proche(from: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var dmin := INF
	for poi in pois:
		if poi.get("marchand", false):
			var d := Vector2(poi.pos.x - from.x, poi.pos.z - from.z).length()
			if d < dmin:
				dmin = d
				best = poi
	return best


## Direction cardinale (N, NE, E…) d'un vecteur (x, z) du monde ; le nord est -Z.
static func cardinal(v: Vector2) -> String:
	var a := fposmod(rad_to_deg(atan2(v.x, -v.y)), 360.0)
	return ["N", "NE", "E", "SE", "S", "SO", "O", "NO"][int(round(a / 45.0)) % 8]


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
		ramassage_auto = bool(cf.get_value("jeu", "ramassage_auto", true))
		sens_visee = float(cf.get_value("jeu", "sens_visee", 1.0))
		fov = clampf(float(cf.get_value("jeu", "fov", 70.0)), 55.0, 100.0)
		vol_effets = float(cf.get_value("jeu", "vol_effets", 1.0))
		vol_voix = float(cf.get_value("jeu", "vol_voix", 1.0))
		vol_ambiance = float(cf.get_value("jeu", "vol_ambiance", 1.0))
		taille_texte = clampf(float(cf.get_value("jeu", "taille_texte", 1.0)), 0.75, 1.5)
		for a in TOUCHES_MODIFIABLES:
			if not cf.has_section_key("touches", a[0]):
				continue   # touche jamais modifiée : on garde celle par défaut
			var ev = _evenement_depuis(cf.get_value("touches", a[0]))
			if ev:
				InputMap.action_erase_events(a[0])
				InputMap.action_add_event(a[0], ev)
				_touches_changees[a[0]] = true
	apply_settings()


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("jeu", "sensibilite", mouse_sens)
	cf.set_value("jeu", "volume", volume)
	cf.set_value("jeu", "qualite", qualite)
	cf.set_value("jeu", "ramassage_auto", ramassage_auto)
	cf.set_value("jeu", "sens_visee", sens_visee)
	cf.set_value("jeu", "fov", fov)
	cf.set_value("jeu", "vol_effets", vol_effets)
	cf.set_value("jeu", "vol_voix", vol_voix)
	cf.set_value("jeu", "vol_ambiance", vol_ambiance)
	cf.set_value("jeu", "taille_texte", taille_texte)
	for a in TOUCHES_MODIFIABLES:
		if _touches_changees.has(a[0]):
			cf.set_value("touches", a[0], _evenement_vers(InputMap.action_get_events(a[0])[0]))
	cf.save(SETTINGS_PATH)
	apply_settings()


# ---------------------------------------------------------------- touches modifiables
var _touches_changees := {}


## Remplace les touches d'une action par un seul événement (touche du clavier ou bouton de la souris).
func changer_touche(action: String, ev: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)
	_touches_changees[action] = true


## Remet toutes les touches par défaut.
func touches_par_defaut() -> void:
	for a in InputMap.get_actions():
		if not String(a).begins_with("ui_"):
			InputMap.action_erase_events(a)
	_setup_inputs()
	_touches_changees.clear()
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK and cf.has_section("touches"):
		cf.erase_section("touches")
		cf.save(SETTINGS_PATH)


## Texte d'une action : ses touches, avec la lettre réelle du clavier (Z sur AZERTY pour « avancer »).
func texte_touche(action: String) -> String:
	var l: PackedStringArray = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			if k.physical_keycode != KEY_NONE:
				l.append(OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)))
			else:
				l.append(OS.get_keycode_string(k.keycode))
		elif ev is InputEventMouseButton:
			l.append({MOUSE_BUTTON_LEFT: "Clic gauche", MOUSE_BUTTON_RIGHT: "Clic droit", MOUSE_BUTTON_MIDDLE: "Clic molette",
					MOUSE_BUTTON_WHEEL_UP: "Molette haut", MOUSE_BUTTON_WHEEL_DOWN: "Molette bas"}.get((ev as InputEventMouseButton).button_index,
					"Bouton %d" % (ev as InputEventMouseButton).button_index))
	return " ou ".join(l)


func _evenement_vers(ev: InputEvent) -> Dictionary:
	if ev is InputEventMouseButton:
		return {"m": (ev as InputEventMouseButton).button_index}
	var k := ev as InputEventKey
	return {"p": k.physical_keycode} if k.physical_keycode != KEY_NONE else {"k": k.keycode}


func _evenement_depuis(d) -> InputEvent:
	if not d is Dictionary:
		return null
	if d.has("m"):
		var mb := InputEventMouseButton.new()
		mb.button_index = int(d.m)
		return mb
	var ev := InputEventKey.new()
	if d.has("p"):
		ev.physical_keycode = int(d.p)
	elif d.has("k"):
		ev.keycode = int(d.k)
	else:
		return null
	return ev


func apply_settings() -> void:
	appliquer_son_et_texte()
	_appliquer_rendu()
	graphismes_changes.emit()


## Volumes (général et par bus) et taille de l'interface : légers, appliqués à chaque mouvement de curseur.
func appliquer_son_et_texte() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	for i in BUS.size():
		var idx := AudioServer.get_bus_index(BUS[i])
		if idx < 0:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, BUS[i])
			AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf([vol_effets, vol_voix, vol_ambiance][i], 0.0001)))
	get_tree().root.content_scale_factor = taille_texte


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


## Objets ramassés, fouillés, dépecés, récoltés, achetés, fabriqués : petite ligne « +n objet » dans le fil du HUD.
func recu(id: String, n: int) -> void:
	if n != 0:
		objet_recu.emit(id, n)


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
	var s: AudioStream = null
	for ext in ["wav", "ogg"]:
		var path := "res://sons/%s.%s" % [sound, ext]
		if ResourceLoader.exists(path):
			s = load(path)
			break
	_sfx[sound] = s
	return s


var _nb_variantes := {}


## Nombre de variantes d'un son numéroté (zv_grogne1, zv_grogne2…).
func variantes(prefixe: String) -> int:
	if not _nb_variantes.has(prefixe):
		var n := 0
		while sfx("%s%d" % [prefixe, n + 1]) != null:
			n += 1
		_nb_variantes[prefixe] = n
	return _nb_variantes[prefixe]


## Dégâts infligés par le joueur (ses coups partent de sa position, ou de sa grenade) : chiffres
## et barre de vie affichés par ui/degats_ui.gd. `montant` est ramené à la vie restante (coup de grâce).
func signaler_degats(cible: Node3D, montant: float, vie_avant: float, pos: Vector3, from: Vector3, tete: bool) -> void:
	if player == null or not (explosion_joueur or from.distance_to(player.global_position) < 2.5):
		return
	if not cible.has_meta("pv_max"):
		cible.set_meta("pv_max", vie_avant)
	degats_infliges.emit(cible, minf(montant, maxf(vie_avant, 0.0)), pos, 1 if tete else (2 if coup_critique else 0))


## Copie d'un son jouée en boucle (ambiances, souffle) : le son du cache reste ponctuel
## (sinon chaque play_3d / play_ui de ce son ne s'arrête plus jamais).
func sfx_boucle(sound: String) -> AudioStream:
	var s := sfx(sound)
	if s is AudioStreamWAV:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	return s


## Son spatialisé (zombies, impacts…)
func play_3d(sound: String, pos: Vector3, vol_db := 0.0, pitch_var := 0.1, max_dist := 60.0, pitch := 1.0) -> void:
	var s := sfx(sound)
	var scene := get_tree().current_scene
	if s == null or scene == null:
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = s
	a.bus = "Voix" if sound.begins_with("zv_") else "Effets"
	a.volume_db = vol_db
	a.pitch_scale = pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	a.max_distance = max_dist
	a.unit_size = 8.0
	scene.add_child(a)
	a.global_position = pos
	a.finished.connect(a.queue_free)
	a.play()


## Détonation d'une arme tirée par un PNJ (garde, bandit) : portée bien plus grande qu'un son ordinaire
## et peu étouffée par la distance (un coup de feu bref perdait sinon presque tout son claquement).
func play_tir(sound: String, pos: Vector3, vol_db := 0.0) -> void:
	var s := sfx(sound)
	var scene := get_tree().current_scene
	if s == null or scene == null:
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = s
	a.volume_db = vol_db
	a.pitch_scale = randf_range(0.93, 1.07)
	a.bus = "Effets"
	a.unit_size = 30.0
	a.max_distance = 300.0
	a.max_db = 4.0
	a.attenuation_filter_cutoff_hz = 9000.0
	a.attenuation_filter_db = -8.0
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
	a.bus = "Effets"
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
