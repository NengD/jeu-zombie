extends VehicleBody3D
## Véhicule conduisible : voiture garée réparée (scripts/vehicules.gd). Physique VehicleBody3D (avant = +Z, comme
## les modèles de décor) : quatre roues à suspension (VehicleWheel3D, roues du modèle immobiles), propulsion,
## centre de gravité bas, couple qui la garde droite, remise sur ses roues si elle reste renversée.
## [F] monter / descendre ; avancer / reculer / gauche / droite ; Sauter = frein à main ; Lampe = phares (allumés seuls la nuit).
## Moteur : son synthétisé (AudioStreamGenerator, régime selon la vitesse) et `Game.make_noise` (25 à 100 m) qui attire les zombies.
## Zombies, bandits et animaux percutés : dégâts selon la vitesse ; chocs et coups abîment la voiture (à 0 : moteur
## en panne, [F] le réparer avec 2 pièces auto). Essence : 60 L, consommée selon l'accélérateur ; accroupi [F] =
## verser un jerrican (« essence », 20 L). Gardée hors des morceaux de la carte et gelée (freeze) quand personne
## ne conduit et que le joueur est loin : les collisions des morceaux détachés (ponts, parkings) ne manquent jamais sous elle.

const Decor = preload("res://scripts/decor.gd")
const ESSENCE_MAX := 60.0
const JERRICAN := 20.0
const PV_MAX := 100.0
const PIECES_MOTEUR := 2
const FORCE := 6000.0
const FORCE_ARRIERE := 3200.0
const VMAX := 32.0          # m/s (≈ 115 km/h)
const VMAX_ARRIERE := 8.0
const FREIN := 28.0
const RAYON_ROUE := 0.36
const DIST_GEL := 150.0
const MASSE := 1200.0

var id := "voiture1"
var epave := -1              # n° dans world.epaves (-1 : modèle recréé)
var essence := JERRICAN
var pv := PV_MAX
var modele: Node3D = null
var conducteur: Node = null
var taille := Vector3(1.9, 1.5, 4.3)

var camera: Camera3D
var cam_yaw := 0.0           # décalage de la caméra à la souris (rendu peu à peu en roulant)
var cam_pitch := 0.25
var souris_t := 0.0
var phares: Array = []
var phares_on := false
var hud: CanvasLayer
var lbl: Label
var son: AudioStreamPlayer3D
var lecture: AudioStreamGeneratorPlayback
var phase := 0.0
var regime := 0.0
var gaz := 0.0
var bruit_t := 0.0
var choc_t := {}             # instance_id -> délai avant un nouveau choc sur la même créature
var v_avant := 0.0           # vitesse de l'image précédente (chocs contre le décor)
var renverse_t := 0.0
var age := 0.0


func _ready() -> void:
	add_to_group("vehicules")
	taille = Decor.taille(id)
	if taille == Vector3.ONE:
		taille = Vector3(1.9, 1.5, 4.3)
	mass = MASSE
	collision_layer = Game.LAYER_WORLD
	collision_mask = Game.LAYER_WORLD
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.3, 0)
	continuous_cd = true
	angular_damp = 0.8
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true            # dégelée quand le joueur est proche (les cases autour sont alors rattachées)
	if modele == null:
		modele = Decor.instance(id)
	if modele:
		modele.transform = Transform3D.IDENTITY
		modele.visible = true
		add_child(modele)
		Decor.distance(modele, 400.0)
	# coque : boîte au-dessus des roues (garde au sol 0,4 m)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var hc := maxf(0.6, taille.y * 0.62 - 0.4)
	bs.size = Vector3(taille.x * 0.94, hc, taille.z * 0.96)
	cs.shape = bs
	cs.position = Vector3(0, 0.4 + hc / 2.0, 0)
	add_child(cs)
	# roues : avant (+Z) directrices, arrière motrices
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var w := VehicleWheel3D.new()
			w.position = Vector3(sx * (taille.x / 2.0 - 0.32), RAYON_ROUE + 0.2, sz * (taille.z / 2.0 - 0.75))
			w.wheel_radius = RAYON_ROUE
			w.wheel_rest_length = 0.2
			w.suspension_travel = 0.25
			w.suspension_stiffness = 45.0
			w.suspension_max_force = 14000.0
			w.damping_compression = 2.2
			w.damping_relaxation = 2.8
			w.wheel_friction_slip = 2.6
			w.wheel_roll_influence = 0.15
			w.use_as_steering = sz > 0.0
			w.use_as_traction = sz < 0.0
			add_child(w)
	# phares (vers +Z ; une SpotLight éclaire vers -Z)
	for sx in [-1.0, 1.0]:
		var l := SpotLight3D.new()
		l.position = Vector3(sx * taille.x * 0.32, 0.75, taille.z / 2.0 + 0.05)
		l.rotation = Vector3(-0.08, PI, 0)
		l.spot_range = 45.0
		l.spot_angle = 32.0
		l.light_energy = 5.0
		l.light_color = Color(1.0, 0.95, 0.82)
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		phares.append(l)
	camera = Camera3D.new()
	camera.top_level = true
	camera.fov = 75.0
	camera.far = 900.0
	add_child(camera)
	son = AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.12
	son.stream = gen
	son.bus = "Effets"
	son.unit_size = 10.0
	son.max_distance = 120.0
	son.volume_db = -4.0
	son.position = Vector3(0, 0.6, taille.z * 0.35)
	add_child(son)
	hud = CanvasLayer.new()
	hud.layer = 5
	hud.visible = false
	lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl.position = Vector2(-420, -300)   # au-dessus de l'arme en main (HUD)
	lbl.size = Vector2(390, 110)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.add_child(lbl)
	add_child(hud)


# ================================================================ interaction
func get_prompt() -> String:
	if conducteur:
		return ""
	if global_basis.y.y < 0.4:
		return "[F] Remettre la voiture sur ses roues"
	var p = Game.player
	if pv <= 0.0:
		var n: int = p.count("piece_auto") if p else 0
		if n >= PIECES_MOTEUR:
			return "[F] Réparer le moteur (%d pièces auto)" % PIECES_MOTEUR
		return "Moteur en panne — il manque %d pièce(s) auto" % (PIECES_MOTEUR - n)
	var s := "[F] Conduire  (essence %d / %d L, état %d %%)" % [int(ceil(essence)), int(ESSENCE_MAX), int(ceil(pv))]
	if p and p.count("essence") > 0 and essence < ESSENCE_MAX - 1.0:
		s += "\naccroupi : [F] verser un jerrican"
	elif essence <= 0.0:
		s += "\nRéservoir vide : il faut un jerrican d'essence"
	return s


func interact(j: Node) -> void:
	if conducteur:
		return
	if global_basis.y.y < 0.4:
		_redresser()
		return
	if pv <= 0.0:
		if j.count("piece_auto") < PIECES_MOTEUR:
			Game.msg("Il faut %d pièces auto pour réparer le moteur." % PIECES_MOTEUR)
			return
		j.remove_item("piece_auto", PIECES_MOTEUR)
		pv = PV_MAX * 0.6
		j.geste("fouille")
		Game.play_3d("impact_metal", global_position + Vector3.UP, 0.0, 0.1, 40.0)
		Game.msg("Moteur réparé (état 60 %).")
		return
	if j.crouching and j.count("essence") > 0 and essence < ESSENCE_MAX - 1.0:
		j.remove_item("essence", 1)
		essence = minf(ESSENCE_MAX, essence + JERRICAN)
		j.geste("genou")
		Game.msg("Plein : %d / %d L d'essence." % [int(essence), int(ESSENCE_MAX)])
		return
	monter(j)


## Texte affiché sous le réticule pendant la conduite (player.prompt).
func prompt_conduite() -> String:
	if pv <= 0.0:
		return "Moteur en panne — [F] descendre"
	if essence <= 0.0:
		return "Panne d'essence — [F] descendre"
	return ""


func monter(j: Node) -> void:
	conducteur = j
	j.vehicule = self
	j.velocity = Vector3.ZERO
	j.visible = false
	j.collision.disabled = true
	freeze = false
	sleeping = false
	cam_yaw = 0.0
	camera.global_position = global_position - global_basis.z * 7.0 + Vector3.UP * 3.0
	camera.make_current()
	hud.visible = true
	_phares(Game.is_night())
	son.play()
	lecture = son.get_stream_playback()
	Game.play_3d("impact_metal", global_position, -10.0, 0.05, 20.0, 0.6)


func descendre() -> void:
	var j = conducteur
	if j == null:
		return
	var sortie := point_sortie()
	if sortie == Vector3.INF:
		Game.msg("Pas de place pour descendre.")
		return
	conducteur = null
	j.vehicule = null
	j.global_position = sortie
	j.rotation.y = rotation.y
	j.visible = true
	j.collision.disabled = false
	j.velocity = linear_velocity * 0.5
	j.camera.make_current()
	hud.visible = false
	_phares(false)
	son.stop()
	lecture = null
	engine_force = 0.0
	brake = FREIN


## Point libre à côté de la voiture (portière gauche, puis droite, arrière, avant) ; INF si tout est bouché.
func point_sortie() -> Vector3:
	var esp := get_world_3d().direct_space_state
	var demi := taille / 2.0
	for loc in [Vector3(demi.x + 0.7, 0, 0.3), Vector3(-demi.x - 0.7, 0, 0.3), Vector3(0, 0, -demi.z - 0.9), Vector3(0, 0, demi.z + 0.9)]:
		var p: Vector3 = global_transform * loc
		var sol := Game.hauteur(p.x, p.z)
		p.y = maxf(p.y, sol) + 0.15
		var q := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.35
		q.shape = sph
		q.collision_mask = Game.LAYER_WORLD
		q.exclude = [get_rid()]
		q.transform = Transform3D(Basis(), p + Vector3.UP * 0.9)
		if esp.intersect_shape(q, 1).is_empty():
			return p
	return Vector3.INF


func _redresser() -> void:
	freeze = false
	var yaw := atan2(global_basis.z.x, global_basis.z.z)
	global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3.UP * 1.2)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	Game.play_3d("impact_metal", global_position, -2.0, 0.1, 40.0)


func basculer_phares() -> void:
	_phares(not phares_on)


func _phares(on: bool) -> void:
	phares_on = on
	for l in phares:
		l.visible = on


## Coup reçu par le conducteur (player.take_damage) : la carrosserie en prend la plus grande part ; renvoie le reste.
func encaisser(montant: float) -> float:
	abimer(montant * 0.5)
	return montant * 0.25


func abimer(n: float) -> void:
	if n <= 0.0 or pv <= 0.0:
		return
	pv = maxf(0.0, pv - n)
	if pv <= 0.0:
		Game.msg("Le moteur cale : la voiture est hors d'usage (2 pièces auto pour la réparer).")
		Game.play_3d("explosion", global_position, -16.0, 0.1, 60.0)


# ================================================================ conduite
func _unhandled_input(event: InputEvent) -> void:
	if conducteur and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Game.ui_open:
		cam_yaw -= event.relative.x * 0.004 * Game.mouse_sens
		cam_pitch = clampf(cam_pitch + event.relative.y * 0.003 * Game.mouse_sens, -0.1, 0.9)
		souris_t = 1.5


func _physics_process(delta: float) -> void:
	age += delta
	var p = Game.player
	if conducteur == null:
		engine_force = 0.0
		brake = FREIN * 0.5
		steering = 0.0
		# gelée loin du joueur (et la première seconde : les cases proches se rattachent)
		var loin: bool = p == null or age < 1.0 or p.global_position.distance_to(global_position) > DIST_GEL
		if loin != freeze and (loin == false or linear_velocity.length() < 0.5):
			freeze = loin
		v_avant = 0.0
		return
	if not is_instance_valid(conducteur) or not conducteur.alive:
		if is_instance_valid(conducteur):   # mort au volant : le corps tombe à côté de la voiture
			var s := point_sortie()
			conducteur.global_position = s if s != Vector3.INF else global_position + Vector3.UP * 2.0
			conducteur.vehicule = null
			conducteur.visible = true
			conducteur.collision.disabled = false
			conducteur.camera.make_current()
		conducteur = null
		hud.visible = false
		son.stop()
		lecture = null
		return
	var avant := linear_velocity.dot(global_basis.z)
	var vitesse := linear_velocity.length()
	var acc := 0.0
	var dir := 0.0
	var frein_main := false
	if not Game.ui_open:
		acc = Input.get_action_strength("avancer") - Input.get_action_strength("reculer")
		dir = Input.get_action_strength("gauche") - Input.get_action_strength("droite")
		frein_main = Input.is_action_pressed("sauter")
	var marche := pv > 0.0 and essence > 0.0
	if not marche:
		acc = 0.0
	brake = 0.0
	engine_force = 0.0
	if acc > 0.0:
		if avant < -1.0:
			brake = FREIN
		else:
			engine_force = FORCE * acc * clampf(1.0 - avant / VMAX, 0.0, 1.0)
	elif acc < 0.0:
		if avant > 1.0:
			brake = FREIN
		else:
			engine_force = -FORCE_ARRIERE * -acc * clampf(1.0 + avant / VMAX_ARRIERE, 0.0, 1.0)
	else:
		brake = 1.2       # frein moteur
	if frein_main:
		brake = FREIN * 1.4
		engine_force = 0.0
	var braq := lerpf(0.55, 0.16, clampf(absf(avant) / 28.0, 0.0, 1.0))
	steering = move_toward(steering, dir * braq, delta * 2.2)
	gaz = move_toward(gaz, absf(acc), delta * 3.0)
	if marche:
		essence = maxf(0.0, essence - (0.004 + 0.03 * gaz) * delta)
		if essence <= 0.0:
			Game.msg("Panne d'essence !")
	# rester droite : couple vers la verticale (pas sur le lacet), remise sur les roues si elle reste couchée
	var haut := global_basis.y
	apply_torque(haut.cross(Vector3.UP) * MASSE * 6.0)
	if haut.y < 0.4 and vitesse < 2.0:
		renverse_t += delta
		if renverse_t > 2.0:
			renverse_t = 0.0
			_redresser()
	else:
		renverse_t = 0.0
	# chocs contre le décor : forte décélération d'une image à l'autre
	var perte := v_avant - vitesse
	if perte > 6.0:
		abimer((perte - 6.0) * 3.0)
		Game.play_3d("impact_metal", global_position + Vector3.UP, 4.0, 0.1, 60.0)
		Game.make_noise(global_position, 40.0)
		if perte > 14.0 and conducteur:
			conducteur.health = maxf(1.0, conducteur.health - (perte - 14.0) * 2.0)
	v_avant = vitesse
	_percuter(vitesse)
	# bruit du moteur (attire les zombies)
	bruit_t -= delta
	if bruit_t <= 0.0 and marche:
		bruit_t = 0.5
		Game.make_noise(global_position, 25.0 + vitesse * 2.3)
	regime = lerpf(regime, clampf(absf(avant) / VMAX * 0.8 + gaz * 0.35, 0.0, 1.0), delta * 4.0)
	# le joueur suit la voiture (cases de la carte, zombies, faim, sauvegarde)
	conducteur.global_position = global_position + Vector3.UP * 0.3
	conducteur.velocity = linear_velocity


## Zombies, bandits, animaux devant la voiture : dégâts selon la vitesse, la carrosserie s'abîme un peu.
func _percuter(vitesse: float) -> void:
	for k in choc_t.keys():
		choc_t[k] -= get_physics_process_delta_time()
		if choc_t[k] <= 0.0:
			choc_t.erase(k)
	if vitesse < 3.0:
		return
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(taille.x + 0.4, 1.6, taille.z + 0.8)
	q.shape = bs
	q.collision_mask = Game.LAYER_ZOMBIE
	q.transform = Transform3D(global_basis, global_transform * Vector3(0, 1.0, 0))
	for r in get_world_3d().direct_space_state.intersect_shape(q, 12):
		var c = r.collider
		if not (c is Node3D) or not c.has_method("take_hit") or choc_t.has(c.get_instance_id()):
			continue
		var vers: Vector3 = c.global_position - global_position
		if vers.dot(linear_velocity) <= 0.0:
			continue   # derrière la voiture : elle s'en éloigne
		choc_t[c.get_instance_id()] = 0.8
		var dmg := vitesse * vitesse * 0.35
		c.take_hit(dmg, c.global_position + Vector3.UP, global_position)
		if is_instance_valid(c):
			if c.has_method("repousser"):
				c.repousser(linear_velocity.normalized(), vitesse * 0.8, 1.0)
			if c.has_method("renverser") and vitesse > 7.0:
				c.renverser(2.0)
		abimer(0.6 + vitesse * 0.12 * (2.5 if c.get("kind") == "gros" or c.get("est_boss") == true else 1.0))
		linear_velocity *= 0.94
		Game.play_3d("coup", c.global_position + Vector3.UP, 4.0, 0.15, 40.0, 0.7)


func _process(delta: float) -> void:
	if conducteur == null:
		return
	# caméra de poursuite (derrière, un peu haute), rayon contre le décor
	souris_t -= delta
	if souris_t <= 0.0 and linear_velocity.length() > 3.0:
		cam_yaw = lerp_angle(cam_yaw, 0.0, delta * 1.5)
		cam_pitch = lerpf(cam_pitch, 0.25, delta * 1.5)
	var fwd := Vector3(global_basis.z.x, 0, global_basis.z.z).normalized()
	if fwd == Vector3.ZERO:
		fwd = Vector3.FORWARD
	fwd = fwd.rotated(Vector3.UP, cam_yaw)
	var cible := global_position + Vector3.UP * 1.4
	var dist := 6.5 + taille.z * 0.3
	var voulu := cible - fwd * dist * cos(cam_pitch) + Vector3.UP * dist * sin(cam_pitch)
	var q := PhysicsRayQueryParameters3D.create(cible, voulu, Game.LAYER_WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		voulu = hit.position + (cible - voulu).normalized() * 0.3
	camera.global_position = camera.global_position.lerp(voulu, clampf(delta * 8.0, 0.0, 1.0))
	if camera.global_position.distance_to(cible) > 0.5:
		camera.look_at(cible, Vector3.UP)
	# tableau de bord
	var kmh := int(round(linear_velocity.length() * 3.6))
	lbl.text = "%d km/h\nEssence %d / %d L\nÉtat %d %%" % [kmh, int(ceil(essence)), int(ESSENCE_MAX), int(ceil(pv))]
	lbl.modulate = Color(1, 0.5, 0.4) if essence < 6.0 or pv < 25.0 else Color.WHITE
	_remplir_son()


## Moteur synthétisé : dents de scie au régime (avec harmonique et souffle), plus fort à l'accélération.
func _remplir_son() -> void:
	if lecture == null:
		return
	var marche := pv > 0.0 and essence > 0.0
	var f := 32.0 + regime * 95.0
	var amp := (0.16 + 0.14 * gaz) if marche else 0.0
	var pas := f / 22050.0
	for i in lecture.get_frames_available():
		phase = fmod(phase + pas, 1.0)
		var s := (phase * 2.0 - 1.0) * 0.6 + sin(phase * TAU * 2.0) * 0.3 + randf_range(-0.12, 0.12)
		lecture.push_frame(Vector2.ONE * s * amp)


# ================================================================ sauvegarde
func vers_dict() -> Dictionary:
	var o := global_position
	return {"id": id, "e": epave, "pos": [o.x, o.y, o.z], "rot": atan2(global_basis.z.x, global_basis.z.z),
			"essence": essence, "pv": pv}
