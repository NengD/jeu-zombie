extends SceneTree
## Relevé des FPS au départ, au centre de Bellerive et de Valmont (graine 12345, 11 h, caméra fixe vers le nord-est).
## JZ_TEST=1 godot --path . --screen <écran de Claude> --resolution 1600x900 -s res://outils/godot/mesure_fps.gd -- [dossier des captures]
## NEIGE=1 : en hiver (jour 23), sous la neige, sol enneigé ; NEIGE=0 : même jour, sans neige.

var g
var main


func _initialize():
	_go.call_deferred()


func _attendre(n: int) -> void:
	for i in n:
		await process_frame


func _go():
	var args := OS.get_cmdline_user_args()
	var sortie: String = args[0] if args.size() > 0 else ""
	for i in DisplayServer.get_screen_count():
		print("écran ", i, " : ", DisplayServer.screen_get_position(i), " ", DisplayServer.screen_get_size(i))
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
	if OS.get_environment("NEIGE") != "":
		# hiver (jour 23) ; NEIGE=1 : neige qui tombe et sol blanc (meteo.gd), NEIGE=0 : temps sec, sol nu
		g.day = 23
		if OS.get_environment("NEIGE") == "1":
			call_group("meteo", "forcer_neige", true)
			main.get_node("Meteo").enneige = 1.0
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var cam := Camera3D.new()
	root.add_child(cam)
	var lieux := {"depart": w.spawn_point, "bellerive": g.villes[0]["c"], "valmont": g.villes[1]["c"]}
	for nom in lieux:
		var c: Vector3 = lieux[nom]
		c.y = w.spawn_point.y if nom == "depart" else 0.0
		g.player.global_position = c + Vector3(0, 0.5, 0)
		await _attendre(240)   # cases du voisinage attachées
		var oeil: Vector3 = g.player.global_position + Vector3(0, 1.7, 0)
		cam.look_at_from_position(oeil, oeil + Vector3(1, -0.08, 1))
		cam.current = true
		await _attendre(90)
		var t0 := Time.get_ticks_usec()
		var proc := 0.0
		var phys := 0.0
		var cpu := 0.0
		var gpu := 0.0
		for i in 240:
			await process_frame
			proc += Performance.get_monitor(Performance.TIME_PROCESS)
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		var fps := 240.0 / ((Time.get_ticks_usec() - t0) / 1000000.0)
		var info := " | pics (max sur 1 s) process %.1f ms, physique %.1f ms | rendu CPU %.1f ms, GPU %.1f ms" % [proc / 0.24, phys / 0.24, cpu / 240.0, gpu / 240.0]
		info += " | objets %d, appels %d, mémoire vidéo %d Mo" % [
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576]
		print("FPS ", nom, " : %.1f" % fps, info)
		if sortie != "":
			var img := root.get_texture().get_image()
			img.resize(800, 450)
			img.save_png(sortie.path_join(nom + ".png"))
	quit()
