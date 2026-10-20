extends SceneTree
## Captures de comparaison du rendu : rue (jour), intérieur, coucher de soleil, nuit au camp.
## godot --path . -s res://outils/godot/captures_rendu.gd -- <dossier> <préfixe> [qualité]


func _initialize():
	_go.call_deferred()


func _cap(nom: String, sortie: String) -> void:
	var img := root.get_texture().get_image()
	img.resize(800, 450)
	img.save_png(sortie.path_join(nom + ".png"))
	print(nom, " : ", Engine.get_frames_per_second(), " FPS")


func _attendre(n: int) -> void:
	for i in n:
		await process_frame


func _go():
	var args := OS.get_cmdline_user_args()
	var sortie: String = args[0]
	var pre: String = args[1]
	var g = root.get_node("Game")
	if args.size() > 2 and g.get("qualite") != null:
		g.qualite = int(args[2])
		g.apply_settings()
	g.partie_a_charger = {}
	var main = load("res://scenes/main.tscn").instantiate()
	main.world_seed = 12345
	root.add_child(main)
	await _attendre(60)
	g.admin = true
	g.admin_invisible = true
	g.admin_invincible = true
	var p = g.player
	var w = main.world
	# 1. rue, jour (devant la maison de départ)
	g.time_hours = 10.5
	var dehors: Vector3 = (w.spawn_point - w.spawn_zone.center)
	dehors.y = 0
	dehors = dehors.normalized()
	p.global_position = w.spawn_point + dehors * 2.0 + Vector3.UP * 0.1
	p.rotation.y = atan2(-dehors.cross(Vector3.UP).x, -dehors.cross(Vector3.UP).z)
	p.head.rotation.x = -0.05
	await _attendre(120)
	_cap(pre + "_1_rue", sortie)
	# 2. intérieur de la maison de départ
	p.global_position = w.spawn_zone.center + Vector3(0, 0.1, 0)
	p.global_position.y = w.spawn_zone.aabb.position.y + 0.1
	p.rotation.y = atan2(dehors.x, dehors.z)
	await _attendre(120)
	_cap(pre + "_2_interieur", sortie)
	# 3. coucher de soleil dans la rue
	g.time_hours = 19.9
	p.global_position = w.spawn_point + dehors * 3.0 + Vector3.UP * 0.1
	p.rotation.y = atan2(-dehors.x, -dehors.z) + PI
	await _attendre(120)
	_cap(pre + "_3_coucher", sortie)
	# 4. nuit, au marché (projecteurs absents : lumière des stands et du ciel)
	g.time_hours = 23.0
	var c: Vector3 = main.camps[0].global_position
	p.global_position = c + Vector3(9, 0, 9)
	p.global_position.y = g.hauteur(p.global_position.x, p.global_position.z) + 0.3
	p.look_at(c + Vector3.UP, Vector3.UP)
	p.rotation.x = 0
	p.rotation.z = 0
	await _attendre(120)
	_cap(pre + "_4_nuit_camp", sortie)
	quit()
