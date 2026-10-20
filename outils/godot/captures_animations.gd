extends SceneTree
## Planche de vérification des animations : en haut le mannequin UAL d'origine (référence),
## en bas le personnage low-poly, mêmes poses, vus de profil ; puis gros plans des mains.
## godot --path . --resolution 1800x900 -s res://outils/godot/captures_animations.gd -- <dossier> [id] [anims…]

const POSES_DEFAUT := ["marche:0.0", "marche:0.25", "marche:0.5", "marche:0.75", "course:0.2", "arme_idle:0.5", "visee:0.2", "recharge:0.8"]


func _initialize():
	_go.call_deferred()


func _go():
	var args := OS.get_cmdline_user_args()
	var sortie: String = args[0]
	var id: String = args[1] if args.size() > 1 else "h_adventurer"
	var poses: Array = args.slice(2) if args.size() > 2 else POSES_DEFAUT
	var monde := Node3D.new()
	root.add_child(monde)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	monde.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.9, 0)
	monde.add_child(sun)
	var sexe := "femme" if id.begins_with("f_") else "homme"
	var persos := []
	for ligne in 2:
		for i in poses.size():
			var chemin := "res://modeles/persos/%s.scn" % sexe if ligne == 0 else "res://modeles/persos_mod/%s.scn" % id
			var p: Node3D = load(chemin).instantiate()
			monde.add_child(p)
			p.position = Vector3(0, 0, i * 1.4 - poses.size() * 0.7) + Vector3(-ligne * 1.6, 0, 0)
			var ap: AnimationPlayer = p.find_children("*", "AnimationPlayer", true, false)[0]
			ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var e: PackedStringArray = String(poses[i]).split(":")
			ap.play(e[0])
			ap.seek(float(e[1]) * ap.current_animation_length, true)
			if ligne == 1 and e[0] in ["arme_idle", "visee", "recharge", "tir"]:
				var prise: Node3D = p.find_child("Prise", true, false)
				if prise:
					prise.add_child(load("res://modeles/armes/ak74.scn").instantiate())
			persos.append(p)
	var cam := Camera3D.new()
	monde.add_child(cam)
	cam.fov = 50
	# profil (le personnage regarde vers -Z : la caméra est sur son côté droit, +X)
	cam.position = Vector3(9.0, 1.1, 0.0)
	cam.look_at(Vector3(-0.8, 0.9, 0.0))
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png(sortie.path_join("anim_%s_profil.png" % id))
	# face
	cam.position = Vector3(-0.8, 1.2, -9.0)
	cam.look_at(Vector3(-0.8, 0.9, 0.0))
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(sortie.path_join("anim_%s_face.png" % id))
	# gros plan des mains du personnage low-poly dans la première pose avec arme (ou la première)
	var k := poses.size()
	for i in poses.size():
		if String(poses[i]).begins_with("arme_idle"):
			k = poses.size() + i
	var cible: Node3D = persos[mini(k, persos.size() - 1)]
	var sk: Skeleton3D = cible.find_children("*", "Skeleton3D", true, false)[0]
	var main: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand_r")).origin
	cam.position = main + Vector3(0.9, 0.25, -0.5)
	cam.look_at(main)
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(sortie.path_join("anim_%s_mains.png" % id))
	quit()
