extends SceneTree
## Captures en jeu devant un lieu ou un décor : godot --path . --screen 1 -s res://outils/godot/captures_lieux.gd -- <dossier> cible…
## cible = "poi:<nom du lieu>[:distance]" ou "prop:<id du décor>[:distance]" (le plus proche du départ, vu de face) ;
## heure 11 h, graine 12345, FPS affichés.

var g
var main


func _initialize():
	_go.call_deferred()


func _attendre(n: int) -> void:
	for i in n:
		await process_frame


func _noeuds(n: Node, res: Array) -> void:
	for c in n.get_children():
		res.append(c)
		_noeuds(c, res)
	var mo = main.world.get_node_or_null("Morceaux")
	if mo:
		for d in mo.detaches(n):
			res.append(d)
			_noeuds(d, res)


func _go():
	var args := OS.get_cmdline_user_args()
	var sortie: String = args[0]
	g = root.get_node("Game")
	g.partie_a_charger = {}
	main = load("res://scenes/main.tscn").instantiate()
	main.world_seed = 12345
	root.add_child(main)
	await _attendre(60)
	g.admin = true
	g.admin_invisible = true
	g.admin_invincible = true
	g.time_hours = 11.0
	var w = main.world
	var tous: Array = []
	_noeuds(w.decor, tous)
	var cam := Camera3D.new()
	root.add_child(cam)
	for ci in range(1, args.size()):
		var morceaux: PackedStringArray = args[ci].split(":")
		var dist := float(morceaux[2]) if morceaux.size() > 2 else 0.0
		var cible := Vector3.INF
		var avant := Vector3(0.6, 0, 1).normalized()
		if morceaux[0] == "groupe":
			# groupe:<nom>:<distance>:<n° du nœud>
			var ns: Array = get_nodes_in_group(morceaux[1])
			var k := int(morceaux[3]) if morceaux.size() > 3 else 0
			if k < ns.size():
				cible = ns[k].global_position
				avant = ns[k].global_basis.z.normalized()
				avant.y = 0
			if dist == 0.0:
				dist = 3.0
		elif morceaux[0] == "poi":
			for p in g.pois:
				if p.name == morceaux[1] and (cible == Vector3.INF or p.pos.distance_to(w.spawn_point) < cible.distance_to(w.spawn_point)):
					cible = p.pos
			if dist == 0.0:
				dist = 14.0
		else:
			var best: Node3D = null
			for n in tous:
				if n is Node3D and String(n.name).begins_with(morceaux[1]):
					var pn: Vector3 = (n as Node3D).position
					if best == null or pn.distance_to(w.spawn_point) < best.position.distance_to(w.spawn_point):
						best = n
			if best:
				cible = best.position
				avant = best.basis.z.normalized()
				avant.y = 0
			if dist == 0.0:
				dist = 4.0
		if cible == Vector3.INF:
			print(args[ci], " : introuvable")
			continue
		g.player.global_position = cible - avant * dist * 2.0 + Vector3(0, 0.5, 0)   # hors du champ
		await _attendre(90)
		if morceaux.size() > 3 and morceaux[3] in ["zombies", "animaux"]:
			# poi:<nom>:<distance>:zombies -> les zombies du lieu, vus de près (le plus proche du lieu)
			var zs: Array = get_nodes_in_group(morceaux[3])
			zs.sort_custom(func(a, b): return a.global_position.distance_to(cible) < b.global_position.distance_to(cible))
			if not zs.is_empty():
				for z in zs:
					z.set_physics_process(false)
				cible = zs[0].global_position
				avant = zs[0].global_basis.z
				avant.y = 0
				avant = avant.normalized()
		var oeil := cible + avant * dist + Vector3(0, absf(dist) * 0.2 + 0.6, 0)
		cam.look_at_from_position(oeil, cible + Vector3(0, 1.0, 0))
		cam.current = true
		await _attendre(60)
		var img := root.get_texture().get_image()
		img.resize(960, 540)
		var nom := args[ci].replace(":", "_").replace(" ", "_").validate_filename()
		img.save_png(sortie.path_join(nom + ".png"))
		print(args[ci], " ", cible, " : ", Engine.get_frames_per_second(), " FPS")
	quit()
