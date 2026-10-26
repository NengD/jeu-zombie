extends SceneTree
## Ce que coûte chaque famille de nœuds : coupe-la un instant et compare au temps d'image juste avant.
## JZ_TEST=1 godot --path . --screen <écran de Claude> --resolution 1600x900 -s res://outils/godot/profil_fps.gd -- [depart|bellerive|valmont] (HEURE=22 : de nuit)

var g
var main
var vp: RID


func _initialize():
	_go.call_deferred()


func _attendre(n: int) -> void:
	for i in n:
		await process_frame


## [image, process, physique, rendu CPU, GPU] en ms, médianes sur n images (process et physique : Godot donne le maximum de la dernière seconde, seule « image » est fiable)
func _mesure(n: int) -> Array:
	var cols := [[], [], [], [], []]
	var t := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var t2 := Time.get_ticks_usec()
		cols[0].append((t2 - t) / 1000.0)
		t = t2
		cols[1].append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		cols[2].append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		cols[3].append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
		cols[4].append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	var res := []
	for c in cols:
		c.sort()
		res.append(c[c.size() / 2])
	return res


func _tous(n: Node, res: Array) -> void:
	for c in n.get_children():
		res.append(c)
		_tous(c, res)


func _couper(ns: Array, mode: String) -> Array:
	var etats := []
	for n in ns:
		match mode:
			"process":
				etats.append([n.is_processing(), n.is_physics_processing(), n.is_processing_internal(), n.is_physics_processing_internal()])
				n.set_process(false)
				n.set_physics_process(false)
				n.set_process_internal(false)
				n.set_physics_process_internal(false)
			"visible":
				etats.append(n.visible)
				n.visible = false
			"ombre":
				etats.append(n.shadow_enabled)
				n.shadow_enabled = false
			"anim":
				etats.append(n.active)
				n.active = false
	return etats


func _rendre(ns: Array, mode: String, etats: Array) -> void:
	for i in ns.size():
		var n = ns[i]
		if not is_instance_valid(n):
			continue
		match mode:
			"process":
				n.set_process(etats[i][0])
				n.set_physics_process(etats[i][1])
				n.set_process_internal(etats[i][2])
				n.set_physics_process_internal(etats[i][3])
			"visible":
				n.visible = etats[i]
			"ombre":
				n.shadow_enabled = etats[i]
			"anim":
				n.active = etats[i]


func _go():
	var args := OS.get_cmdline_user_args()
	var lieu: String = args[0] if args.size() > 0 else "depart"
	g = root.get_node("Game")
	g.partie_a_charger = {}
	main = load("res://scenes/main.tscn").instantiate()
	main.world_seed = 12345
	root.add_child(main)
	await _attendre(60)
	g.admin = true
	g.admin_invisible = true
	g.admin_invincible = true
	g.time_hours = float(OS.get_environment("HEURE")) if OS.get_environment("HEURE") != "" else 11.0
	var w = main.world
	vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var c: Vector3 = w.spawn_point
	if lieu == "bellerive":
		c = g.villes[0]["c"]
	elif lieu == "valmont":
		c = g.villes[1]["c"]
	g.player.global_position = c + Vector3(0, 0.5, 0)
	await _attendre(240)
	var cam := Camera3D.new()
	root.add_child(cam)
	var oeil: Vector3 = g.player.global_position + Vector3(0, 1.7, 0)
	cam.look_at_from_position(oeil, oeil + Vector3(1, -0.08, 1))
	cam.current = true
	await _attendre(90)
	var tous: Array = []
	_tous(root, tous)
	var par_script := {}
	for n in tous:
		var s = n.get_script()
		# jamais les autoloads (Game relâche la souris en mode test)
		if s and not s.resource_path.contains("/autoload/") and (n.is_processing() or n.is_physics_processing()):
			var cle: String = s.resource_path.get_file()
			if not par_script.has(cle):
				par_script[cle] = []
			par_script[cle].append(n)
	var familles := {}
	for cle in par_script:
		if par_script[cle].size() >= 1:
			familles["script " + cle] = [par_script[cle], "process"]
	var de_classe := func(cl: String) -> Array:
		return tous.filter(func(n): return n.is_class(cl))
	familles["anim AnimationMixer"] = [de_classe.call("AnimationMixer"), "anim"]
	familles["process Skeleton3D"] = [de_classe.call("Skeleton3D"), "process"]
	familles["vis Label3D"] = [de_classe.call("Label3D"), "visible"]
	familles["vis OmniLight3D"] = [de_classe.call("OmniLight3D"), "visible"]
	familles["vis SpotLight3D"] = [de_classe.call("SpotLight3D"), "visible"]
	familles["ombre Omni+Spot"] = [de_classe.call("OmniLight3D") + de_classe.call("SpotLight3D"), "ombre"]
	familles["ombre soleil"] = [de_classe.call("DirectionalLight3D"), "ombre"]
	familles["vis Decal"] = [de_classe.call("Decal"), "visible"]
	familles["vis GPUParticles3D"] = [de_classe.call("GPUParticles3D") + de_classe.call("CPUParticles3D"), "visible"]
	familles["vis MultiMeshInstance3D"] = [de_classe.call("MultiMeshInstance3D"), "visible"]
	familles["vis MeshInstance3D"] = [de_classe.call("MeshInstance3D"), "visible"]
	familles["vis CanvasLayer (HUD)"] = [de_classe.call("CanvasLayer"), "visible"]
	var nb := {}
	for cl in ["MeshInstance3D", "MultiMeshInstance3D", "Label3D", "OmniLight3D", "SpotLight3D", "Decal", "Skeleton3D", "AnimationMixer", "CollisionShape3D", "StaticBody3D", "CharacterBody3D", "Area3D", "RayCast3D", "AudioStreamPlayer3D"]:
		nb[cl] = de_classe.call(cl).size()
	print("nœuds ", tous.size(), " ", nb)
	var ombres := 0
	for n in de_classe.call("OmniLight3D") + de_classe.call("SpotLight3D"):
		if n.shadow_enabled and n.visible:
			ombres += 1
	print("lumières avec ombre visibles : ", ombres)
	var base: Array = await _mesure(120)
	print("base %s : image %.1f, process %.1f, physique %.1f, rendu CPU %.1f, GPU %.1f ms" % [lieu, base[0], base[1], base[2], base[3], base[4]])
	var lignes := []
	for nom in familles:
		var ns: Array = familles[nom][0]
		if ns.is_empty():
			continue
		var avant: Array = await _mesure(60)
		var etats := _couper(ns, familles[nom][1])
		await _attendre(5)
		var m: Array = await _mesure(60)
		_rendre(ns, familles[nom][1], etats)
		await _attendre(10)
		lignes.append([avant[0] - m[0], "%-34s %5d : image -%.1f  process -%.1f  physique -%.1f  rendu CPU -%.1f  GPU -%.1f" % [nom, ns.size(), avant[0] - m[0], avant[1] - m[1], avant[2] - m[2], avant[3] - m[3], avant[4] - m[4]]])
	lignes.sort_custom(func(a, b): return a[0] > b[0])
	for l in lignes:
		print(l[1])
	quit()
