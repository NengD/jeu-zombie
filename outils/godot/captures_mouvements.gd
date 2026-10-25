extends SceneTree
## Planche des mouvements du joueur en jeu (graine 12345, 11 h, admin invisible) :
## JZ_TEST=1 godot --path . --screen <écran de Claude, voir CLAUDE.md> --resolution 1600x900 -s res://outils/godot/captures_mouvements.gd -- <image.png> scénario…
## scénarios : repos, cote (pas de côté à droite), recul, pivot, virage, atterrissage, chute, coup_gauche,
## coup_face, blesse, souffle, regard_haut, nage, echelle, mort, fouille, depecage, bandage, lit, ramasser,
## zombies (zombies proches qui regardent le joueur), arme (sortie d'arme), flanc, roulade, combo, lever,
## genou ; suffixes « @t » = attendre t s,
## « !a » = caméra à l'angle a (rad, 0 = de face, 1,57 = à sa droite).

var g
var main
var p
var cam: Camera3D
var etiquette: Label
var depart := Vector3.ZERO
var suivre := false                 # la caméra de capture reste active


func _initialize():
	_go.call_deferred()


func _attendre(s: float) -> void:
	var fin := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fin:
		_sans_pause()
		await process_frame


## la fenêtre de capture perd parfois le focus et le jeu se met en pause : on reprend aussitôt
func _sans_pause() -> void:
	if paused:
		for hud in main.get_children():
			if hud.has_method("_resume"):
				hud._resume()
		paused = false
	if cam and cam.current == false and suivre:
		cam.make_current()


func _relacher() -> void:
	for a in ["avancer", "reculer", "gauche", "droite", "sprint", "viser", "sauter"]:
		Input.action_release(a)


func _go():
	var args := OS.get_cmdline_user_args()
	var sortie: String = args[0]
	g = root.get_node("Game")
	g.partie_a_charger = {}
	main = load("res://scenes/main.tscn").instantiate()
	main.world_seed = 12345
	root.add_child(main)
	await _attendre(3.0)
	g.admin = true
	g.admin_invisible = true
	g.admin_invincible = true
	g.time_hours = 11.0
	p = g.player
	depart = _lieu_degage(p.global_position)
	cam = Camera3D.new()
	root.add_child(cam)
	var calque := CanvasLayer.new()
	root.add_child(calque)
	etiquette = Label.new()
	etiquette.position = Vector2(20, 14)
	etiquette.add_theme_font_size_override("font_size", 40)
	etiquette.add_theme_color_override("font_outline_color", Color.BLACK)
	etiquette.add_theme_constant_override("outline_size", 8)
	calque.add_child(etiquette)
	var images: Array[Image] = []
	for sc in args.slice(1):
		images.append(await _scenario(sc))
	# planche : 3 colonnes, images réduites de moitié
	var cols := mini(3, images.size())
	var w := images[0].get_width() / 2
	var h := images[0].get_height() / 2
	var planche := Image.create(w * cols, h * int(ceil(images.size() / float(cols))), false, Image.FORMAT_RGB8)
	for i in images.size():
		var im := images[i]
		im.convert(Image.FORMAT_RGB8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		planche.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	planche.save_png(sortie)
	print("planche : ", sortie, " (", images.size(), " vues)")
	quit()


func _remettre() -> void:
	_relacher()
	g.admin_invincible = true
	p.alive = true
	p.health = p.prog.sante_max()
	p.stamina = p.prog.endurance_max()
	p.soin_t = 0.0
	p.velocity = Vector3.ZERO
	p.global_position = depart
	p.rotation.y = 0.0
	p.p_lock = 0.0
	for m in [p.corps_vivant, p.pieds_ik, p.bras_ik]:
		if m:
			m.active = true
	if p.crouching:
		p._set_crouch(false)
	await _attendre(0.4)


## Caméra à `dist` m du joueur, du côté `angle` (0 = de face, PI/2 = sa droite), regard sur le buste.
func _viser(angle := 0.6, dist := 3.6, haut := 1.4) -> void:
	var av: Vector3 = -p.global_basis.z
	var dir := av.rotated(Vector3.UP, -angle)
	cam.global_position = p.global_position + dir * dist + Vector3.UP * haut
	cam.look_at(p.global_position + Vector3.UP * 1.0)
	cam.fov = 50.0
	suivre = true
	cam.make_current()


func _scenario(sc: String) -> Image:
	var vue := float(sc.get_slice("!", 1)) if sc.contains("!") else INF   # « !angle » : angle de la caméra imposé
	sc = sc.get_slice("!", 0)
	var nom := sc.get_slice("@", 0)
	var attente := float(sc.get_slice("@", 1)) if sc.contains("@") else -1.0
	await _remettre()
	etiquette.text = nom
	var angle := 0.6
	match nom:
		"cote":
			Input.action_press("droite")
			await _attendre(attente if attente > 0 else 1.0)
			angle = 0.2
		"recul":
			Input.action_press("reculer")
			await _attendre(attente if attente > 0 else 1.0)
			angle = PI / 2
		"pivot":
			await _attendre(0.3)
			for i in 10:
				p.rotation.y += 0.09
				await process_frame
			await _attendre(attente if attente > 0 else 0.05)
		"virage":
			Input.action_press("avancer")
			Input.action_press("sprint")
			await _attendre(0.8)
			var fin := Time.get_ticks_msec() + int((attente if attente > 0 else 0.5) * 1000.0)
			while Time.get_ticks_msec() < fin:
				p.rotation.y += 0.035
				await process_frame
			angle = 0.0
		"atterrissage", "chute":
			p.global_position = depart + Vector3.UP * (1.2 if nom == "atterrissage" else 5.0)
			await process_frame
			while not p.is_on_floor():
				await process_frame
			await _attendre(attente if attente > 0 else 0.12)
			angle = PI / 2
		"coup_gauche":
			p.take_damage(15.0, null, p.global_position - p.global_basis.x * 2.0 + Vector3.UP)
			await _attendre(attente if attente > 0 else 0.1)
			angle = 0.0
		"coup_face":
			p.take_damage(15.0, null, p.global_position - p.global_basis.z * 2.0 + Vector3.UP)
			await _attendre(attente if attente > 0 else 0.1)
			angle = PI / 2
		"blesse":
			p.health = p.prog.sante_max() * 0.08
			Input.action_press("avancer")
			await _attendre(attente if attente > 0 else 1.0)
			angle = PI / 2
		"souffle":
			p.stamina = 0.0
			p.pause_endurance = 30.0
			await _attendre(attente if attente > 0 else 1.0)
			angle = PI / 2
		"regard_haut":
			p.head.rotation.x = 0.6
			await _attendre(attente if attente > 0 else 0.6)
			angle = PI / 2
		"nage":
			var l: Dictionary = g.relief.lacs[0]
			p.global_position = Vector3(l.c.x, -2.0, l.c.y)
			Input.action_press("avancer")
			await _attendre(attente if attente > 0 else 1.5)
			angle = 1.2
		"echelle":
			var e: Dictionary = g.echelles[0]
			var n: Vector3 = e.n
			p.global_position = e.pos + n * 0.7
			p.look_at(p.global_position - n, Vector3.UP)
			p.rotation.x = 0.0
			Input.action_press("avancer")
			await _attendre(attente if attente > 0 else 1.6)
			angle = 2.4
		"mort":
			g.admin_invincible = false
			p.take_damage(9999.0, null, p.global_position - p.global_basis.z * 2.0)
			await _attendre(attente if attente > 0 else 2.0)
			angle = PI / 2
		"zombies":
			var z := load("res://scripts/zombie.gd")
			for i in 3:
				var zo = z.new()
				main.world.add_child(zo)
				zo.global_position = p.global_position + p.global_basis.x * (2.0 + i) - p.global_basis.z * (3.0 + i * 1.5)
			g.admin_invisible = false
			await _attendre(attente if attente > 0 else 1.5)
			g.admin_invisible = true
			angle = 0.4
		"bandage":
			p.soin_t = 4.0
			p.soin_id = "bandage"
			await _attendre(attente if attente > 0 else 0.7)
			angle = 0.5
		"flanc":
			p.health = p.prog.sante_max() * 0.1
			await _attendre(attente if attente > 0 else 1.0)
			angle = 0.3
		"lit", "lever":
			var lit = load("res://scripts/placeable.gd").new()
			main.world.add_child(lit)
			lit.setup("lit")
			lit.global_position = p.global_position + p.global_basis.x * 1.2
			p.geste("lit", lit)
			await _attendre(attente if attente > 0 else (0.8 if nom == "lit" else 2.6))
			angle = 1.0
			_viser(angle, 3.6, 2.2)
			await _attendre(0.05)
			var im0 := root.get_viewport().get_texture().get_image()
			lit.queue_free()
			p.geste("")
			suivre = false
			cam.clear_current()
			return im0
		"roulade":
			Input.action_press("avancer")
			Input.action_press("sprint")
			await _attendre(0.7)
			p._roulade()
			await _attendre(attente if attente > 0 else 0.3)
			angle = PI / 2
		"combo":
			for i in 3:
				p.cooldown = 0.0
				p._melee(p.arme_stats(p.current_weapon()))
				await _attendre(p._duree_coup(p.arme_stats(p.current_weapon())) + 0.12 if i < 2 else (attente if attente > 0 else 0.2))
			angle = 0.8
		"arme":
			p._select_slot(1 if p.slot == 0 else 0)
			await _attendre(attente if attente > 0 else 0.15)
			angle = 2.6
		_:
			if p.has_method("geste"):
				p.geste(nom)
			await _attendre(attente if attente > 0 else 0.8)
			angle = 1.0
	var cv = p.corps_vivant
	print(nom, " : anim ", p.p_anim, " vitesse ", p.pap.speed_scale, " v=", p.velocity, " hanches ", cv._hanches if cv else -99.0, " cible ", cv.hanches_cible if cv else -99.0, " incl ", cv._inclinaison if cv else 0.0, " coup ", cv._coup if cv else Vector3.ZERO, " actif ", cv.active if cv else false, " tete ", cv._tete if cv else Vector2.ZERO, " flex ", p.pieds_ik.flexion if p.pieds_ik else -1.0, " amp ", p.flex_amp, " t ", p.flex_t)
	_viser(angle if vue == INF else vue, 3.6, 2.6 if nom == "nage" else 1.4)
	await _attendre(0.05)
	var im := root.get_viewport().get_texture().get_image()
	if p.has_method("geste"):
		p.geste("")
	suivre = false
	cam.clear_current()
	p.head.rotation.x = 0.0
	return im


## Endroit dégagé (aucun décor à 4,5 m) près du départ, posé au sol.
func _lieu_degage(c: Vector3) -> Vector3:
	var espace: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var forme := SphereShape3D.new()
	forme.radius = 4.5
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forme
	q.collision_mask = g.LAYER_WORLD
	for r in range(0, 120, 6):
		for i in 16:
			var pt := c + Vector3(cos(i * TAU / 16.0), 0.0, sin(i * TAU / 16.0)) * float(r)
			var sol := espace.intersect_ray(PhysicsRayQueryParameters3D.create(pt + Vector3.UP * 30.0, pt + Vector3.DOWN * 30.0, g.LAYER_WORLD))
			if sol.is_empty() or absf(sol.position.y - c.y) > 1.5:   # pas sur un toit
				continue
			q.transform = Transform3D(Basis(), sol.position + Vector3.UP * 5.0)
			if espace.intersect_shape(q, 1).is_empty():
				return sol.position + Vector3.UP * 0.1
	return c
