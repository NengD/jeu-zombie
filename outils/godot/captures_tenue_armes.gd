extends SceneTree
## Tenue des armes en 3e personne : pour chaque arme, une planche (repos / en joue, côté droit / côté gauche).
## godot --path . --resolution 1600x900 -s res://outils/godot/captures_tenue_armes.gd -- <dossier> arme1 arme2…

var p
var cam: Camera3D


func _initialize():
	_go.call_deferred()


func _att(n):
	for i in n:
		await process_frame


func _vue(gauche: bool) -> Image:
	var s := -1.0 if gauche else 1.0
	cam.global_position = p.global_position + p.global_basis.x * 1.9 * s + Vector3.UP * 1.45 - p.global_basis.z * 0.45
	cam.look_at(p.global_position + Vector3.UP * 1.25 - p.global_basis.z * 0.35)
	cam.current = true
	await _att(3)
	var img := root.get_texture().get_image()
	img.resize(640, 360)
	img.convert(Image.FORMAT_RGBA8)
	return img


func _go():
	var args := OS.get_cmdline_user_args()
	var sortie: String = args[0]
	var armes: Array = args.slice(1)
	var g = root.get_node("Game")
	g.partie_a_charger = {}
	var main = load("res://scenes/main.tscn").instantiate()
	main.world_seed = 12345
	root.add_child(main)
	await _att(60)
	g.admin = true
	g.admin_invisible = true
	g.admin_invincible = true
	p = g.player
	cam = Camera3D.new()
	cam.fov = 50
	main.add_child(cam)
	var w = main.world
	g.time_hours = 11.0
	var dehors: Vector3 = (w.spawn_point - w.spawn_zone.center)
	dehors.y = 0
	dehors = dehors.normalized()
	p.global_position = w.spawn_point + dehors * 3.0 + Vector3.UP * 0.1
	p.rotation.y = atan2(-dehors.x, -dehors.z)
	for i in armes.size():
		var id: String = armes[i]
		if i > 0:
			p.remove_item(armes[i - 1], 1)
		p.add_item(id)
		p.hotbar[1] = id
		p.slot = -1
		p._select_slot(1)
		p.head.rotation.x = 0.0
		await _att(60)
		var planche := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
		var k := 0
		for vise in [false, true]:
			if vise:
				Input.action_press("viser")
			await _att(45)
			for gauche in [false, true]:
				var img: Image = await _vue(gauche)
				planche.blit_rect(img, Rect2i(0, 0, 640, 360), Vector2i((k % 2) * 640, (k / 2) * 360))
				k += 1
			p.camera.current = true
			Input.action_release("viser")
		planche.save_png(sortie.path_join("tenue_%s.png" % id))
		print(id, " ok")
	quit()
