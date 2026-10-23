extends SceneTree
## Planche de l'équipement porté : une ligne par tenue (modèle de personnage + objets), une colonne par pose ;
## images de face, de profil et de dos.
## godot --path . --screen 1 --resolution 1800x1000 -s res://outils/godot/captures_equipement.gd -- <dossier> [poses…]

const Equip = preload("res://scripts/equipement_visuel.gd")
const Perso = preload("res://scripts/perso.gd")
const ModeleUtil = preload("res://scripts/modele_util.gd")
const ARC = preload("res://scripts/arc.gd")

const TENUES := [
	["h_adventurer", ["casque_moto", "veste_cuir", "sac_a_dos"]],
	["h_adventurer", ["casque_militaire", "gilet_militaire", "sac_militaire"]],
	["h_adventurer", ["casque_police", "gilet_police", "sac_toile"]],
	["h_adventurer", ["bonnet", "masque_gaz", "veste_renforcee", "sac_randonnee"]],
	["h_casual_2", ["casquette", "lunettes", "sac_sport"]],
	["f_adventurer", ["casque_militaire", "gilet_militaire", "sac_militaire"]],
	["f_adventurer", ["capuche_cuir", "veste_cuir", "sac_chasse"]],
	["f_casual", ["casque_chantier", "lunettes", "sac_toile"]],
	["h_worker", ["casquette_police", "gilet_police", "sac_a_dos"]],
	["f_adventurer", []],
	["f_soldier", []],
	["h_adventurer", ["casque_militaire", "gilet_militaire", "sac_militaire"], ["m4a1", "benelli_m4", "glock19", "couteau_km2000"]],
	["h_adventurer", ["bonnet", "veste_cuir", "sac_toile"], ["arc", "hache", "m45a1", "matraque"]],
	["f_adventurer", [], ["ak74", "glock19", "machette"]],
]
const POSES_DEFAUT := ["idle:0.3", "marche:0.25", "visee:0.3", "course:0.2"]


func _initialize():
	_go.call_deferred()


func _go():
	var args := OS.get_cmdline_user_args()
	var sortie: String = args[0]
	var poses: Array = args.slice(1) if args.size() > 1 else POSES_DEFAUT
	var monde := Node3D.new()
	root.add_child(monde)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.65, 0.65, 0.65)
	monde.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 2.6, 0)
	monde.add_child(sun)
	var sun2 := DirectionalLight3D.new()
	sun2.rotation = Vector3(-0.5, -0.6, 0)
	sun2.light_energy = 0.5
	monde.add_child(sun2)
	var lignes := range(TENUES.size())
	if OS.get_environment("LIGNES") != "":
		lignes = Array(OS.get_environment("LIGNES").split(",")).map(func(x): return int(x))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for l in lignes:
		for i in poses.size():
			var a := Perso.apparence("survivant", rng)
			a.modele = TENUES[l][0]
			var p: Node3D = Perso.creer(a)
			monde.add_child(p)
			p.position = Vector3(i * 1.3, 0, l * 1.4)
			var ap: AnimationPlayer = p.find_children("*", "AnimationPlayer", true, false)[0]
			ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var e: PackedStringArray = String(poses[i]).split(":")
			ap.play(e[0])
			ap.seek(float(e[1]) * ap.current_animation_length, true)
			var eq := {}
			for id in TENUES[l][1]:
				eq[id] = {"id": id}
			Equip.appliquer(p, eq)
			if TENUES[l].size() > 2:
				var armes := []
				for id in TENUES[l][2]:
					armes.append([id, ARC.new() if id == "arc" else ModeleUtil.arme(id)])
				Equip.armes_rangees(p, armes)
	var cam := Camera3D.new()
	monde.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = poses.size() * 1.3 + 0.2
	var persos: Array = monde.get_children().filter(func(x): return x.has_meta("modele"))
	# le personnage regarde vers -Z : on le tourne pour montrer chaque côté à la caméra (placée en +Z)
	for v in [["face", PI], ["dos", 0.0], ["profil", PI / 2.0]]:
		var imgs := []
		for l in lignes:
			for k in persos.size():
				persos[k].visible = lignes[k / poses.size()] == l
				persos[k].rotation.y = v[1]
			var cl := Vector3((poses.size() - 1) * 0.65, 1.15, l * 1.4)
			cam.position = cl + Vector3(0, 0, 20)
			cam.look_at(cl)
			for k in 3:
				await process_frame
			var img := root.get_texture().get_image()
			var hv := int(img.get_width() * 2.1 / cam.size)
			imgs.append(img.get_region(Rect2i(0, (img.get_height() - hv) / 2, img.get_width(), hv)))
		var w: int = imgs[0].get_width()
		var h: int = imgs[0].get_height()
		var planche := Image.create(w, h * imgs.size(), false, imgs[0].get_format())
		for l in imgs.size():
			planche.blit_rect(imgs[l], Rect2i(0, 0, w, h), Vector2i(0, h * l))
		planche.save_png(sortie.path_join("equip_%s.png" % v[0]))
	quit()
