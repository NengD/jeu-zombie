extends SceneTree
## Planche des décors : godot --path . --screen 1 -s res://outils/godot/captures_props.gd -- <image.png> id1 id2…
## (id = modeles/props/<id>.scn, ou chemin res:// d'une scène) ; vue de trois quarts avant (+Z), étiquettes.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var sortie: String = args[0]
	var ids := args.slice(1)
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	w.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-50, 30, 0)
	soleil.shadow_enabled = true
	w.add_child(soleil)
	var col := ceili(sqrt(ids.size()))
	var pas := 0.0
	var scenes := []
	for id in ids:
		var ch: String = id if id.begins_with("res://") else "res://modeles/props/%s.scn" % id
		var n: Node3D = load(ch).instantiate()
		var ab := AABB()
		var prem := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = mi.transform * mi.mesh.get_aabb()
			ab = a if prem else ab.merge(a)
			prem = false
		pas = maxf(pas, maxf(ab.size.x, maxf(ab.size.y, ab.size.z)) * 1.3)
		scenes.append([id, n, ab])
	for i in scenes.size():
		var n: Node3D = scenes[i][1]
		var ab: AABB = scenes[i][2]
		var k := pas / 1.3 / maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
		n.scale = Vector3.ONE * k
		n.position = Vector3((i % col) * pas, -(i / col) * pas, 0) - ab.get_center() * k + Vector3(0, ab.size.y * k * 0.5, 0) * 0.0
		w.add_child(n)
		var l := Label3D.new()
		l.text = "%s %.2fx%.2fx%.2f" % [scenes[i][0], ab.size.x, ab.size.y, ab.size.z]
		l.pixel_size = pas * 0.0012
		l.position = Vector3((i % col) * pas, -(i / col) * pas - pas * 0.45, pas * 0.5)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		w.add_child(l)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var lignes := ceili(float(ids.size()) / col)
	cam.size = pas * maxf(lignes, col * 0.6) * 1.05
	var centre := Vector3((col - 1) * pas * 0.5, -(lignes - 1) * pas * 0.5, 0)
	cam.position = centre + Vector3(0.5, 0.35, 1).normalized() * 100.0
	w.add_child(cam)
	cam.look_at_from_position(centre + Vector3(0.5, 0.35, 1).normalized() * 100.0, centre)
	root.size = Vector2i(1400, 900)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(sortie)
	quit()
