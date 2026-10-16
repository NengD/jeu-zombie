extends CharacterBody3D
## Joueur : déplacements, vue 1re / 3e personne (1re forcée en intérieur),
## se pencher, combat (armes blanches + armes à feu), survie, inventaire,
## craft et pose d'objets de base.

const LootContainer = preload("res://scripts/loot_container.gd")
const Placeable = preload("res://scripts/placeable.gd")
const ModeleUtil = preload("res://scripts/modele_util.gd")
const FpsArms = preload("res://scripts/fps_arms.gd")

const WALK := 4.2
const SPRINT := 7.2
const CROUCH_SPEED := 2.2
const AIM_SPEED := 2.8
const JUMP := 4.8
const GRAVITY := 14.0
const MOUSE_SENS := 0.0022
const EYE_STAND := 1.62
const EYE_CROUCH := 1.05
const TPS_DIST := 2.9
const SHOULDER := 0.75
const FOV := 75.0
const FOV_AIM := 50.0
const VM_SCALE := 1.45                  # taille des armes 3D en vue 1re personne
const HAND_ROT := Vector3(90, 0, 0)      # orientation de l'arme dans la main (vue 3e personne)
const PLACE_SIZES := {"etabli": Vector3(2.0, 1.0, 0.9), "barricade": Vector3(2.1, 2.4, 0.2), "caisse_stockage": Vector3(1.2, 0.8, 0.8)}

# --- état de survie
var health := 100.0
var hunger := 100.0
var thirst := 100.0
var stamina := 100.0
var alive := true
var hurt_flash := 0.0

# --- inventaire
var poches: Grille = Grille.creer("Sur toi", 8, 5)   # inventaire de base ; sacs et gilets ajoutent de la place
var mags: Dictionary = {}
var equipped := {"tete": {}, "torse": {}, "dos": {}}
var hotbar: Array = ["", "", "", "", ""]
var slot := 0

# --- caméra / mouvement
var want_tps := false
var tps_blend := 0.0
var shoulder_side := 1.0
var lean := 0.0
var crouching := false
var aiming := false
var sprinting := false
var step_t := 0.0
var bob_t := 0.0
var flashlight_on := false
var in_zone: Dictionary = {}

# --- combat
var cooldown := 0.0
var reload_t := 0.0
var fire_queued := 0.0
var swing_t := 0.0
var vm_kick := 0.0
var muzzle_t := 0.0

# --- interaction / construction
var prompt := ""
var interact_target: Node = null
var placing := ""
var ghost: MeshInstance3D
var ghost_mat: StandardMaterial3D
var ghost_rot := 0.0
var ghost_valid := false
var ghost_reason := ""
var ghost_pos := Vector3.ZERO

@onready var modele: Node3D = $Modele
@onready var collision: CollisionShape3D = $Collision
var head: Node3D
var lean_pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D
var flashlight: SpotLight3D
var viewmodel: Node3D
var vm_holder: Node3D
var muzzle_light: OmniLight3D
var fps_arms: Node3D
var vm_weapon: Node3D = null
var reload_total := 1.0
# --- tenue de l'arme en vue 1re personne
var sway := Vector2.ZERO          # inertie de l'arme quand on tourne la tête
var sway_v := Vector2.ZERO
var rec_pos := Vector3.ZERO       # recul (ressort amorti)
var rec_vel := Vector3.ZERO
var rec_rot := Vector3.ZERO
var rec_rvel := Vector3.ZERO
var draw_t := 0.0                 # sortie de l'arme (1 → 0)
var ads := 0.0                    # 0 = à la hanche, 1 = en visée
var sprint_k := 0.0
var air_vy := 0.0
var doigt_tir := 0.0               # index sur la détente (0..1)
var coup_gauche := false           # alternance des coups de poing
var reload_vide := false          # rechargement à vide (chargeur éjecté, armement)
var reload_cart := 3              # cartouches insérées une à une
var reload_ev: Array = []         # évènements sonores restants
var scope_vp: SubViewport         # image grossie de la lunette
var scope_cam: Camera3D
var oculaire_mat: ShaderMaterial
var hand: Node3D
var pap: AnimationPlayer = null   # animations du survivant (modèle Blender)
var accessoires := {}              # arme -> {emplacement: accessoire}
var prog := Progression.new()
var dernier_lieu := ""      # niveaux, attributs, compétences, talents
var hand_weapon: Node3D = null     # modèle de l'arme dans la main (vue 3e personne)
var perso_ual := false             # modèle réaliste (animations UAL)
var p_anim := ""
var p_lock := 0.0
var shoot_pose_t := 0.0


func _ready() -> void:
	add_to_group("player")
	Game.player = self
	prog.niveau_global.connect(func(n): Game.msg("NIVEAU %d ! +1 point d'attribut — touche K" % n); Game.play_ui("construire", -2.0, 0.0, 1.3))
	prog.niveau_competence.connect(func(c, n): Game.msg("%s niveau %d : nouveau talent à débloquer — touche K" % [Progression.NOMS[c], n]); Game.play_ui("construire", -2.0, 0.0, 1.5))
	collision_layer = Game.LAYER_PLAYER
	collision_mask = Game.LAYER_WORLD | Game.LAYER_ZOMBIE
	collision.shape = collision.shape.duplicate()
	floor_snap_length = 0.3
	_build_rig()
	# équipement de départ
	equipped.dos = nouvelle_entree("sac_toile")
	add_item("couteau", 1)
	add_item("conserve", 2)
	add_item("eau", 2)
	add_item("bandage", 2)
	add_item("tissu", 2)
	slot = 0
	_refresh_weapon_model()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_rig() -> void:
	head = Node3D.new()
	head.name = "Tete"
	head.position.y = EYE_STAND
	add_child(head)
	lean_pivot = Node3D.new()
	head.add_child(lean_pivot)
	spring = SpringArm3D.new()
	spring.collision_mask = Game.LAYER_WORLD
	spring.margin = 0.15
	var sph := SphereShape3D.new()
	sph.radius = 0.2
	spring.shape = sph
	spring.spring_length = 0.0
	spring.add_excluded_object(get_rid())
	lean_pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.05
	camera.far = 700.0
	spring.add_child(camera)
	camera.current = true
	flashlight = SpotLight3D.new()
	flashlight.spot_range = 32.0
	flashlight.spot_angle = 26.0
	flashlight.light_energy = 3.0
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.shadow_enabled = true
	flashlight.visible = false
	flashlight.position = Vector3(0.15, -0.1, 0)
	camera.add_child(flashlight)
	vm_holder = Node3D.new()
	vm_holder.position = Vector3(0.24, -0.2, -0.42)
	vm_holder.scale = Vector3.ONE * 0.6
	camera.add_child(vm_holder)
	fps_arms = FpsArms.new()
	camera.add_child(fps_arms)
	# lunette : une seconde caméra au champ étroit rend l'image affichée dans l'oculaire
	scope_vp = SubViewport.new()
	scope_vp.size = Vector2i(512, 512)
	scope_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(scope_vp)
	scope_cam = Camera3D.new()
	scope_cam.cull_mask = 0xFFFFF & ~2    # sans l'arme ni les bras
	scope_cam.near = 0.3
	scope_cam.far = 900.0
	scope_vp.add_child(scope_cam)
	scope_cam.current = true
	oculaire_mat = ShaderMaterial.new()
	oculaire_mat.shader = preload("res://shaders/lunette.gdshader")
	oculaire_mat.set_shader_parameter("vue", scope_vp.get_texture())
	viewmodel = Node3D.new()
	vm_holder.add_child(viewmodel)
	muzzle_light = OmniLight3D.new()
	muzzle_light.omni_range = 7.0
	muzzle_light.light_color = Color(1.0, 0.8, 0.45)
	muzzle_light.light_energy = 0.0
	vm_holder.add_child(muzzle_light)
	hand = Node3D.new()
	hand.position = Vector3(0.3, 1.15, -0.35)
	modele.add_child(hand)
	# modèle du survivant : personnage réaliste (mannequin UAL) sinon modèle Blender
	var m: Node3D = null
	if Perso.disponible():
		m = Perso.creer(Perso.apparence("survivant"))
		perso_ual = true
	else:
		m = ModeleUtil.charger("res://modeles/survivant.glb")
	if m:
		for c in modele.get_children():
			if c != hand:
				c.queue_free()
		modele.add_child(m)
		pap = ModeleUtil.anim_player(m)
		if pap:
			ModeleUtil.boucler(pap, ["idle", "marche", "course", "accroupi", "accroupi_marche", "visee"])
			pap.playback_default_blend_time = 0.15
		var sk := ModeleUtil.squelette(m)
		var prise: Node3D = m.find_child("Prise", true, false)
		if perso_ual and prise:
			modele.remove_child(hand)
			prise.add_child(hand)
			hand.transform = Transform3D.IDENTITY
		elif sk and sk.find_bone("main.R") >= 0:
			var ba := BoneAttachment3D.new()
			ba.bone_name = "main.R"
			sk.add_child(ba)
			modele.remove_child(hand)
			ba.add_child(hand)
			hand.position = Vector3(0, 0.07, 0.0)
			hand.rotation_degrees = HAND_ROT


# ================================================================ entrées
func _unhandled_input(event: InputEvent) -> void:
	if not alive or Game.ui_open:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENS * Game.mouse_sens * (0.6 * camera.fov / FOV_AIM if aiming else 1.0)
		if aiming and scope_vp.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			sens *= 0.3
		sway_v += Vector2(event.relative.x, event.relative.y) * 0.0012
		rotate_y(-event.relative.x * sens)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sens, -1.45, 1.45)
		return
	if placing != "":
		if event.is_action_pressed("tirer"):
			_confirm_placement()
		elif event.is_action_pressed("viser") or event.is_action_pressed("pause"):
			cancel_placement()
		elif event.is_action_pressed("arme_suiv"):
			ghost_rot += deg_to_rad(15)
		elif event.is_action_pressed("arme_prec"):
			ghost_rot -= deg_to_rad(15)
		elif event.is_action_pressed("recharger"):
			ghost_rot += PI / 2.0
		get_viewport().set_input_as_handled()
		return
	if Game.admin and event.is_action_pressed("admin_vol"):
		Game.admin_vol = not Game.admin_vol
		if not Game.admin_vol:
			collision_mask = Game.LAYER_WORLD | Game.LAYER_ZOMBIE
		Game.msg("Vol : " + ("activé (Espace / Ctrl, Maj = rapide)" if Game.admin_vol else "désactivé"))
		return
	if event.is_action_pressed("tirer"):
		fire_queued = 0.2
	elif event.is_action_pressed("arme_suiv"):
		_cycle_weapon(1)
	elif event.is_action_pressed("arme_prec"):
		_cycle_weapon(-1)
	elif event.is_action_pressed("vue"):
		want_tps = not want_tps
		if want_tps and not in_zone.is_empty():
			Game.msg("Vue 3e personne indisponible à l'intérieur.")
	elif event.is_action_pressed("lampe"):
		flashlight_on = not flashlight_on
		flashlight.visible = flashlight_on
	elif event.is_action_pressed("interagir"):
		if interact_target and is_instance_valid(interact_target):
			interact_target.interact(self)
	elif event.is_action_pressed("recharger"):
		_start_reload()
	elif event.is_action_pressed("soigner"):
		if count("bandage") > 0:
			use_item("bandage")
		elif count("trousse") > 0:
			use_item("trousse")
		else:
			Game.msg("Aucun bandage ni trousse de soin.")
	elif event.is_action_pressed("accroupir"):
		_set_crouch(not crouching)
	else:
		for i in 5:
			if event.is_action_pressed("arme_%d" % (i + 1)):
				_select_slot(i)


# ================================================================ boucle
func _physics_process(delta: float) -> void:
	if not alive:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	var can_act := not Game.ui_open
	_update_stats(delta)
	_update_zone()
	_move(delta, can_act)
	_update_camera(delta)
	_update_combat(delta, can_act)
	_update_interact()
	if placing != "":
		_update_placement()
	hurt_flash = maxf(0.0, hurt_flash - delta * 1.5)


func _update_stats(delta: float) -> void:
	if Game.admin and Game.admin_besoins:
		hunger = 100.0
		thirst = 100.0
		stamina = prog.endurance_max()
		return
	hunger = maxf(0.0, hunger - delta * 0.055 * prog.faim_mult())
	thirst = maxf(0.0, thirst - delta * 0.085 * prog.soif_mult())
	if sprinting:
		stamina = maxf(0.0, stamina - delta * 16.0 * (0.65 if prog.a("marathonien") else 1.0))
	else:
		stamina = minf(prog.endurance_max(), stamina + delta * (14.0 if velocity.length() < 0.5 else 9.0) * prog.recup_endurance())
	if hunger <= 0.0 or thirst <= 0.0:
		_hurt(0.6 * delta)
	elif hunger > 50.0 and thirst > 50.0 and health < prog.sante_max():
		health = minf(prog.sante_max(), health + 0.25 * delta)


func _update_zone() -> void:
	var z := Game.find_zone(global_position + Vector3.UP * 0.9)
	if not is_same(z, in_zone):
		in_zone = z
		if not z.is_empty() and z.name != "" and z.name != dernier_lieu:
			Game.msg("Lieu : " + z.name)
		if not z.is_empty():
			dernier_lieu = z.name
		if not z.is_empty():
			# découverte d'un bâtiment : XP d'exploration (plus pour les lieux importants)
			var cle := "%d_%d" % [int(z.center.x), int(z.center.z)]
			if not prog.lieux_vus.has(cle):
				prog.lieux_vus[cle] = true
				prog.gagner("exploration", 40 if z.name != "" else 8)


func _move(delta: float, can_act: bool) -> void:
	var input := Vector2.ZERO
	if can_act:
		input = Input.get_vector("gauche", "droite", "avancer", "reculer")
	if Game.admin and Game.admin_vol:
		_voler(delta, input, can_act)
		return
	var dir := (global_basis * Vector3(input.x, 0, input.y))
	dir.y = 0.0
	dir = dir.normalized()
	aiming = can_act and Input.is_action_pressed("viser") and placing == ""
	sprinting = can_act and Input.is_action_pressed("sprint") and input.y < -0.2 and not crouching and not aiming and stamina > 1.0
	var speed := WALK
	if sprinting:
		speed = SPRINT * (1.12 if prog.a("coureur") else 1.0)
	elif crouching:
		speed = CROUCH_SPEED
	elif aiming:
		speed = AIM_SPEED
	# dans l'eau : on avance lentement, sans sprinter
	var mouille := Game.dans_eau(global_position)
	if mouille:
		speed = minf(speed, WALK * 0.55)
		sprinting = false
	var accel := 40.0 if is_on_floor() else 6.0
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)
	if is_on_floor():
		if can_act and Input.is_action_just_pressed("sauter") and stamina > 8.0:
			if crouching:
				_set_crouch(false)
			else:
				velocity.y = JUMP
				stamina -= 8.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	# bruit des pas
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.5:
		bob_t += delta * hspeed * 1.6
		step_t -= delta
		if step_t <= 0.0:
			step_t = 0.4 if sprinting else 0.6
			if mouille:
				Game.make_noise(global_position, 10.0)
				Game.play_ui("eau", -8.0, 0.2)
			elif sprinting:
				Game.make_noise(global_position, 16.0)
				Game.play_ui("pas", -10.0, 0.15)
			elif not crouching:
				Game.make_noise(global_position, 6.0)
				Game.play_ui("pas", -16.0, 0.15)


## Mode admin : vol libre (Espace monte, Ctrl/C descend, Maj accélère), murs traversables en option.
func _voler(delta: float, input: Vector2, can_act: bool) -> void:
	aiming = can_act and Input.is_action_pressed("viser") and placing == ""
	sprinting = false
	var dir := (camera.global_basis * Vector3(input.x, 0, input.y))
	if can_act:
		if Input.is_action_pressed("sauter"):
			dir += Vector3.UP
		if Input.is_action_pressed("accroupir"):
			dir += Vector3.DOWN
	var vitesse := 14.0
	if can_act and Input.is_action_pressed("sprint"):
		vitesse = 45.0
	velocity = velocity.lerp(dir.limit_length(1.0) * vitesse, minf(1.0, delta * 8.0))
	collision_mask = 0 if Game.admin_murs else (Game.LAYER_WORLD | Game.LAYER_ZOMBIE)
	move_and_slide()


func _set_crouch(on: bool) -> void:
	if not on:
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, global_position + Vector3.UP * 1.95, Game.LAYER_WORLD, [get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			return
	crouching = on
	var cap: CapsuleShape3D = collision.shape
	cap.height = 1.2 if on else 1.8
	collision.position.y = cap.height / 2.0


func _update_camera(delta: float) -> void:
	# 3e personne seulement à l'extérieur
	var tps_now := want_tps and in_zone.is_empty()
	tps_blend = move_toward(tps_blend, 1.0 if tps_now else 0.0, delta * 4.0)
	# se pencher
	var lean_target := 0.0
	if not Game.ui_open:
		if Input.is_action_pressed("pencher_gauche"):
			lean_target -= 1.0
		if Input.is_action_pressed("pencher_droite"):
			lean_target += 1.0
	lean = move_toward(lean, lean_target, delta * 5.0)
	if absf(lean) > 0.05:
		shoulder_side = signf(lean)
	var allowed := 0.55
	if absf(lean) > 0.01:
		var from := head.global_position
		var side := global_basis.x * signf(lean)
		var q := PhysicsRayQueryParameters3D.create(from, from + side * 0.85, Game.LAYER_WORLD, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			allowed = maxf(0.0, from.distance_to(hit.position) - 0.3)
	lean_pivot.position.x = signf(lean) * minf(absf(lean) * 0.55, allowed)
	lean_pivot.rotation.z = -lean * 0.22
	modele.rotation.z = -lean * 0.25
	head.position.y = move_toward(head.position.y, EYE_CROUCH if crouching else EYE_STAND, delta * 4.0)
	if pap == null:
		modele.scale.y = move_toward(modele.scale.y, 0.7 if crouching else 1.0, delta * 3.0)
	else:
		_update_player_anim(delta)
	spring.spring_length = TPS_DIST * tps_blend
	spring.position = Vector3(SHOULDER * shoulder_side * tps_blend, 0.2 * tps_blend, 0)
	var fps := tps_blend < 0.5
	_set_model_shadow_only(fps)
	vm_holder.visible = fps
	hand.visible = not fps
	var cw := current_weapon()
	var cwi := Items.info(cw)
	var is_gun: bool = cwi.get("type", "") == "gun"
	var optique := str(accessoires.get(cw, {}).get("viseur", "")) if is_gun else ""
	var vise := aiming and is_gun and reload_t <= 0.0 and placing == ""
	ads = move_toward(ads, 1.0 if vise else 0.0, delta * (5.5 if vise else 7.0))
	var k_ads := smoothstep(0.0, 1.0, ads)
	var fov_vise := FOV_AIM * float(arme_stats(cw).get("fov_visee", 1.0)) if is_gun else FOV_AIM
	camera.fov = lerpf(FOV, fov_vise, k_ads)
	# --- lunette : image grossie rendue seulement quand on vise
	var lunette := optique == "lunette" and fps and ads > 0.6
	scope_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if lunette else SubViewport.UPDATE_DISABLED
	oculaire_mat.set_shader_parameter("actif", 1.0 if lunette else 0.0)
	if lunette:
		scope_cam.global_transform = camera.global_transform
		scope_cam.fov = camera.fov / 4.5
	camera.near = 0.012 if (optique == "lunette" and ads > 0.2) else 0.05
	# --- position de l'arme : hanche, sprint, visée alignée sur le viseur
	var hs := Vector2(velocity.x, velocity.z).length()
	sprint_k = move_toward(sprint_k, 1.0 if (sprinting and hs > 3.0 and is_on_floor() and reload_t <= 0.0) else 0.0, delta * 5.0)
	var hanche := Vector3(0.24, -0.2, -0.42)
	var visee := Vector3(0.0, -0.1, -0.32)
	if is_gun and vm_weapon and is_instance_valid(vm_weapon):
		var pv := _point_visee(cw, optique)
		var base_xf := Transform3D(Basis.from_scale(vm_holder.scale)) * vm_weapon.transform
		visee = Vector3(0, 0, -float(pv.dist)) - base_xf * Vector3(pv.pt)
	var cible := hanche.lerp(visee, k_ads)
	cible += Vector3(-0.04, -0.05, 0.05) * sprint_k
	# balancement de marche (en huit), respiration, inertie
	var t := Time.get_ticks_msec() / 1000.0
	var amp := clampf(hs / WALK, 0.0, 1.7) * (1.0 - 0.85 * k_ads) if is_on_floor() else 0.0
	var bob := Vector3(sin(bob_t) * 0.014, -absf(cos(bob_t)) * 0.012, 0.0) * amp
	var souffle := Vector3(sin(t * 1.3) * 0.0016, sin(t * 2.6) * 0.0022, 0.0) * (1.0 - 0.55 * k_ads)
	sway_v = sway_v.lerp(Vector2.ZERO, minf(1.0, delta * 12.0))
	var sway_cible := sway_v.clamp(Vector2(-0.12, -0.12), Vector2(0.12, 0.12))
	sway = sway.lerp(sway_cible, minf(1.0, delta * 9.0))
	var k_sway := 1.0 - 0.8 * k_ads
	# atterrissage
	if is_on_floor() and air_vy < -3.0:
		rec_vel += Vector3(0, clampf(air_vy * 0.06, -0.9, 0.0), 0)
		rec_rvel += Vector3(clampf(air_vy * 0.25, -3.0, 0.0), 0, 0)
	air_vy = velocity.y if not is_on_floor() else 0.0
	# ressorts du recul (petits pas de temps : stable même à faible nombre d'images par seconde)
	var raideur := 170.0
	var amort := 17.0
	var reste := minf(delta, 0.25)
	while reste > 0.0:
		var dt := minf(reste, 1.0 / 240.0)
		reste -= dt
		rec_vel += (-rec_pos * raideur - rec_vel * amort) * dt
		rec_pos += rec_vel * dt
		rec_rvel += (-rec_rot * raideur - rec_rvel * amort) * dt
		rec_rot += rec_rvel * dt
	# sortie de l'arme
	draw_t = move_toward(draw_t, 0.0, delta * 2.6)
	var sortie := smoothstep(0.0, 1.0, draw_t)
	vm_holder.position = vm_holder.position.lerp(cible, minf(1.0, delta * 16.0)) if ads < 0.999 else cible
	swing_t = move_toward(swing_t, 0.0, delta * 3.5)
	var rot := Vector3(-sin(swing_t * PI) * 1.1, sin(swing_t * PI) * 0.5, 0)
	rot += Vector3(sway.y * 0.9, sway.x * 0.9, -sway.x * 0.7) * k_sway
	rot += Vector3(0.0, 0.0, sin(bob_t) * 0.02 * amp)
	rot += rec_rot
	rot += Vector3(-0.28, 0.55, 0.2) * sprint_k * (1.0 if is_gun else 0.3)
	rot += Vector3(-1.0, 0.25, 0.3) * sortie
	var pos := bob + souffle + rec_pos + Vector3(-sway.x * 0.02, sway.y * 0.015, 0.0) * k_sway
	pos += Vector3(0.0, -0.18, 0.06) * sortie
	vm_kick = move_toward(vm_kick, 0.0, delta * 6.0)
	# rechargement + bras en vue 1re personne
	var p_rel := -1.0
	if reload_t > 0.0 and reload_total > 0.0:
		p_rel = 1.0 - reload_t / reload_total
		_reload_evenements(p_rel)
	if p_rel >= 0.0 and vm_weapon:
		var pose: Dictionary = FpsArms.reload_pose(cw, cwi, p_rel, FpsArms.hand_points(cw, cwi, fps_arms.geo), reload_vide, reload_cart)
		rot += pose.rot
		pos += pose.off
	viewmodel.rotation = rot
	viewmodel.position = pos
	fps_arms.visible = fps
	_update_lampes(fps)
	if fps:
		var wxf = null
		if vm_weapon and is_instance_valid(vm_weapon):
			wxf = camera.global_transform.affine_inverse() * vm_weapon.global_transform
		var appuie := is_gun and not Game.ui_open and Input.is_action_pressed("tirer") and reload_t <= 0.0
		doigt_tir = move_toward(doigt_tir, 1.0 if appuie else 0.0, delta * 9.0)
		fps_arms.update(cw, cwi, wxf, p_rel, swing_t, reload_vide, reload_cart, doigt_tir, coup_gauche)
	if pap == null:
		hand.rotation.x = -sin(swing_t * PI) * 1.4
	muzzle_t = maxf(0.0, muzzle_t - delta)
	muzzle_light.light_energy = 6.0 if muzzle_t > 0.0 else 0.0


## Point de visée sur le modèle de l'arme (repère du modèle) et distance à l'œil.
## Point rouge : centre du verre ; lunette : oculaire ; sinon : hausse (dessus de la carcasse).
func _point_visee(id: String, optique: String) -> Dictionary:
	var pts := Accessoires.points(id, vm_weapon)
	var v: Vector3 = pts.get("viseur", Vector3(0, 0.05, 0))
	var longue: bool = float(Items.info(id).get("len", 0.3)) >= 0.4
	match optique:
		"point_rouge":
			return {"pt": v + Vector3(0, 0.03, -0.021), "dist": 0.17 if longue else 0.24}
		"lunette":
			return {"pt": v + Vector3(0, 0.04, 0.1365), "dist": 0.042}
	return {"pt": v + Vector3(0, 0.006, 0.0), "dist": 0.2 if longue else 0.3}


## Sons et effets du rechargement au fil de l'animation.
func _reload_evenements(p: float) -> void:
	while not reload_ev.is_empty() and p >= float(reload_ev[0][0]):
		var e: String = reload_ev.pop_front()[1]
		match e:
			"lacher":
				_lacher_chargeur()
			"chargeur_sort":
				Game.play_ui("chargeur_sort", -6.0, 0.08)
			"chargeur_in":
				Game.play_ui("chargeur_in", -4.0, 0.08)
			"culasse":
				Game.play_ui("culasse", -4.0, 0.06)
			"cartouche":
				Game.play_ui("cartouche", -7.0, 0.12)
			"pompe":
				Game.play_ui("pompe", -3.0, 0.05)
			"barillet":
				Game.play_ui("culasse", -8.0, 0.1, 1.3)


## Le chargeur vide tombe au sol (objet physique qui disparaît après un moment).
func _lacher_chargeur() -> void:
	if vm_weapon == null or not is_instance_valid(vm_weapon):
		return
	var pts := FpsArms.hand_points(current_weapon(), Items.info(current_weapon()), fps_arms.geo)
	var depart: Vector3 = vm_weapon.global_transform * Vector3(pts.get("well", Vector3(0, -0.08, -0.04)))
	var rb := RigidBody3D.new()
	rb.collision_layer = 0
	rb.collision_mask = Game.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.03, 0.12, 0.06)
	cs.shape = bs
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.1, 0.1)
	m.metallic = 0.5
	m.roughness = 0.5
	mi.material_override = m
	rb.add_child(mi)
	get_parent().add_child(rb)
	rb.global_position = depart
	rb.global_basis = camera.global_basis
	rb.linear_velocity = velocity * 0.8 + Vector3(0, -1.0, 0)
	rb.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	get_tree().create_timer(25.0).timeout.connect(rb.queue_free)
	get_tree().create_timer(0.45).timeout.connect(func(): if is_instance_valid(rb): Game.play_3d("chargeur_sol", rb.global_position, -8.0, 0.15, 12.0))


## Lampe : celle montée sur l'arme si elle en a une, sinon la lampe torche.
func _update_lampes(fps: bool) -> void:
	var sur_arme: bool = arme_stats(current_weapon()).get("lampe", false)
	flashlight.visible = flashlight_on and not sur_arme
	for m in [vm_weapon, hand_weapon]:
		if m and is_instance_valid(m):
			var l: Node3D = m.find_child("Lumiere", true, false)
			if l:
				l.visible = flashlight_on and sur_arme and ((m == vm_weapon) == fps)


## Statistiques de l'arme avec ses accessoires.
func arme_stats(id: String) -> Dictionary:
	var w := Accessoires.stats(id, Items.info(id), accessoires.get(id, {}))
	if w.get("type", "") == "gun":
		if prog.a("main_sure"):
			w.spread = float(w.spread) * 0.75
		if prog.a("recharge_rapide"):
			w.reload = float(w.reload) * 0.75
		if prog.a("tireur"):
			w.damage = float(w.damage) * 1.2
		if prog.a("sang_froid"):
			w.recoil = float(w.recoil) * 0.65
	return w


## Pose un accessoire (pris dans l'inventaire) sur une arme. L'ancien retourne dans l'inventaire.
func poser_accessoire(arme: String, emplacement: String, acc: String) -> bool:
	if not acc in Accessoires.compatibles(arme, emplacement) or count(acc) <= 0:
		return false
	remove_item(acc)
	var a: Dictionary = accessoires.get(arme, {})
	var ancien: String = a.get(emplacement, "")
	a[emplacement] = acc
	accessoires[arme] = a
	if ancien != "":
		add_item(ancien)
	_apres_accessoire(arme)
	Game.play_ui("recharge", -8.0, 0.1)
	return true


func retirer_accessoire(arme: String, emplacement: String) -> void:
	var a: Dictionary = accessoires.get(arme, {})
	if not a.has(emplacement):
		return
	var acc: String = a[emplacement]
	a.erase(emplacement)
	accessoires[arme] = a
	add_item(acc)
	_apres_accessoire(arme)
	Game.play_ui("recharge", -8.0, 0.1)


func _apres_accessoire(arme: String) -> void:
	# chargeur plus petit : les cartouches en trop retournent dans l'inventaire
	var w := arme_stats(arme)
	if w.get("type", "") == "gun" and int(mags.get(arme, 0)) > int(w.mag):
		add_item(w.ammo, int(mags[arme]) - int(w.mag))
		mags[arme] = int(w.mag)
	if arme == current_weapon():
		_refresh_weapon_model()


var _shadow_only_state := -1
func _set_model_shadow_only(on: bool) -> void:
	var s := 1 if on else 0
	if s == _shadow_only_state:
		return
	_shadow_only_state = s
	ModeleUtil.ombres(modele, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON)


# ================================================================ combat
func current_weapon() -> String:
	var id: String = hotbar[slot]
	if id != "" and count(id) > 0 and Items.is_weapon(id):
		return id
	return "poings"


## Place un objet dans un emplacement de la barre rapide (0 à 4). "" = vider.
func assign_hotbar(i: int, id: String) -> void:
	if i < 0 or i > 4:
		return
	if id != "":
		var old := hotbar.find(id)
		if old >= 0:
			hotbar[old] = ""
	hotbar[i] = id
	_refresh_weapon_model()


func _select_slot(i: int) -> void:
	# un consommable dans la barre rapide est utilisé directement
	var id: String = hotbar[i]
	if id != "" and not Items.is_weapon(id):
		use_item(id)
		return
	if i == slot:
		return
	slot = i
	reload_t = 0.0
	cooldown = maxf(cooldown, 0.25)
	_refresh_weapon_model()
	Game.msg("Arme : " + Items.nom(current_weapon()))


func _cycle_weapon(d: int) -> void:
	for k in 5:
		var i := posmod(slot + d * (k + 1), 5)
		if (hotbar[i] != "" and Items.is_weapon(hotbar[i])) or k == 4:
			_select_slot(i)
			return


func _update_combat(delta: float, can_act: bool) -> void:
	cooldown -= delta
	fire_queued = maxf(0.0, fire_queued - delta)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			_finish_reload()
		return
	if not can_act or placing != "" or cooldown > 0.0:
		return
	var id := current_weapon()
	var w := arme_stats(id)
	var held := Input.is_action_pressed("tirer")
	var wants: bool = fire_queued > 0.0 or (held and (w.get("auto", false) or w.type == "melee"))
	if not wants:
		return
	fire_queued = 0.0
	if w.type == "gun":
		_fire_gun(id, w)
	else:
		_melee(w)


func _aim_point(max_range: float) -> Vector3:
	var from := camera.global_position
	var fwd := -camera.global_basis.z
	var to := from + fwd * (max_range + spring.spring_length + 0.5)
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.LAYER_WORLD | Game.LAYER_ZOMBIE, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return to
	return hit.position


func _fire_gun(id: String, w: Dictionary) -> void:
	if int(mags.get(id, 0)) <= 0:
		cooldown = 0.3
		Game.play_ui("clic_vide", -4.0)
		if count(w.ammo) > 0:
			_start_reload()
		else:
			Game.msg("Plus de munitions (%s)." % Items.nom(w.ammo))
		return
	if not (Game.admin and Game.admin_munitions):
		mags[id] = int(mags[id]) - 1
	doigt_tir = 1.0
	cooldown = w.rate
	var origin := lean_pivot.global_position
	var aim := _aim_point(w.range)
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	var spread_deg: float = w.spread * (float(w.get("dispersion_visee", 0.45)) if aiming else 1.0) * (1.6 if moving else 1.0) * (0.8 if crouching else 1.0)
	var spread := deg_to_rad(spread_deg)
	var right := camera.global_basis.x.normalized()
	var up := camera.global_basis.y.normalized()
	var touche := false
	for i in int(w.pellets):
		var dir := (aim - origin).normalized()
		dir = dir.rotated(right, randf_range(-spread, spread)).rotated(up, randf_range(-spread, spread))
		if _shoot_ray(origin, origin + dir * float(w.range), float(w.damage)):
			touche = true
	if touche:
		prog.gagner("combat", 2)   # XP de combat aussi avec les armes à feu
	head.rotation.x = clampf(head.rotation.x + float(w.recoil), -1.45, 1.45)
	rotate_y(randf_range(-1.0, 1.0) * float(w.recoil) * 0.3)
	vm_kick = 1.0
	# recul visible de l'arme (moins fort en visée, l'épaule encaisse)
	var force := clampf(float(w.recoil) * 14.0, 0.35, 1.6) * (0.55 if aiming else 1.0)
	rec_vel += Vector3(randf_range(-0.12, 0.12), 0.18, 1.5) * force
	rec_rvel += Vector3(2.6, randf_range(-0.5, 0.5), randf_range(-0.9, 0.9)) * force
	muzzle_t = 0.05
	shoot_pose_t = 1.5
	if w.get("silencieux", false):
		Game.play_ui(w.get("sound", "tir_pistolet"), -16.0, 0.05, 1.6)
	else:
		Game.play_ui(w.get("sound", "tir_pistolet"), -3.0, 0.05)
	Game.make_noise(global_position, float(w.noise))


func _melee(w: Dictionary) -> void:
	var cost: float = w.stamina * (0.7 if prog.a("souffle") else 1.0)
	var dmg: float = w.damage * (1.25 if prog.a("coup_puissant") else 1.0)
	if prog.a("critique") and randf() < 0.2:
		dmg *= 2.0
	if stamina < cost:
		dmg *= 0.5
	stamina = maxf(0.0, stamina - cost)
	cooldown = w.rate
	swing_t = 1.0
	if current_weapon() == "poings":
		coup_gauche = not coup_gauche
	if perso_ual:
		if current_weapon() == "poings":
			_p_anim("coup_poing" if randf() < 0.5 else "coup_poing2", 1.5, 0.4)
		else:
			_p_anim("frappe", 1.6, 0.5)
	else:
		_p_anim("frappe", 1.3, 0.45)
	Game.play_ui("coup", -6.0, 0.15)
	var origin := lean_pivot.global_position
	var aim := _aim_point(float(w.range) + 1.0)
	var dir := (aim - origin).normalized()
	if _shoot_ray(origin, origin + dir * float(w.range), dmg):
		Game.make_noise(global_position, 7.0)
		prog.gagner("combat", 2)


func _shoot_ray(from: Vector3, to: Vector3, dmg: float) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.LAYER_WORLD | Game.LAYER_ZOMBIE, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false
	var col: Object = hit.collider
	if col.has_method("take_hit"):
		col.take_hit(dmg, hit.position, global_position)
		Game.spawn_blood(hit.position, get_parent())
		Game.play_3d("impact", hit.position, -4.0, 0.2, 30.0)
		return true
	return false


func _start_reload() -> void:
	var id := current_weapon()
	var w := arme_stats(id)
	if w.get("type", "") != "gun" or reload_t > 0.0:
		return
	if int(mags.get(id, 0)) >= int(w.mag):
		return
	if count(w.ammo) <= 0:
		Game.msg("Pas de munitions : " + Items.nom(w.ammo))
		return
	var facteur: float = float(w.reload) / maxf(float(Items.info(id).get("reload", w.reload)), 0.01)
	reload_vide = int(mags.get(id, 0)) == 0
	if FpsArms.arme_a_cartouches(id):
		# une cartouche à la fois
		reload_cart = mini(int(w.mag) - int(mags.get(id, 0)), count(w.ammo))
		reload_total = (0.55 + 0.42 * reload_cart + 0.5) * facteur
		reload_vide = false
	else:
		reload_cart = 0
		reload_total = float(w.reload) * (1.3 if reload_vide else 1.0)
	reload_t = reload_total
	reload_ev = FpsArms.evenements(id, reload_vide, reload_cart)
	Game.make_noise(global_position, 4.0)


func _finish_reload() -> void:
	var id := current_weapon()
	var w := arme_stats(id)
	if w.get("type", "") != "gun":
		return
	var need := int(w.mag) - int(mags.get(id, 0))
	var take := mini(need, count(w.ammo))
	remove_item(w.ammo, take)
	mags[id] = int(mags.get(id, 0)) + take


func take_damage(amount: float, _from: Node = null) -> void:
	if not alive:
		return
	if Game.admin and Game.admin_invincible:
		hurt_flash = 0.3
		return
	_hurt(amount * (1.0 - armor_total()) * (0.85 if prog.a("robuste") else 1.0))
	hurt_flash = 1.0
	Game.play_ui("douleur", -2.0, 0.15)


func _hurt(amount: float) -> void:
	health -= amount
	if health <= 0.0 and alive:
		health = 0.0
		_die()


func _die() -> void:
	alive = false
	cancel_placement()
	want_tps = false
	var tw := create_tween()
	tw.tween_property(head, "position:y", 0.35, 0.8)
	tw.parallel().tween_property(lean_pivot, "rotation:z", 1.2, 0.8)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.player_died.emit()


# ================================================================ modèle d'arme
func _refresh_weapon_model() -> void:
	for c in viewmodel.get_children():
		c.queue_free()
	for c in hand.get_children():
		c.queue_free()
	vm_weapon = null
	hand_weapon = null
	draw_t = 1.0
	reload_t = 0.0
	var id := current_weapon()
	var w := Items.info(id)
	var col: Color = w.get("color", Color.GRAY)
	var length: float = w.get("len", 0.0)
	if w.get("type", "") == "gun":
		muzzle_light.position = Vector3(0, 0.05, -length - 0.1)
	if id == "poings":
		return  # les poings sont dessinés par les bras
	# modèle 3D de l'arme (Blender) si disponible
	var vm := ModeleUtil.arme(id)
	if vm:
		var tilt_m := 0.0 if w.type == "gun" else 0.9
		var longue: bool = w.type == "gun" and length > 0.5
		vm.scale = Vector3.ONE * (VM_SCALE * 0.72 if longue else VM_SCALE)
		vm.position = Vector3(0.02, 0.02, 0.18) if longue else Vector3.ZERO
		vm.rotation.x = tilt_m
		viewmodel.add_child(vm)
		vm_weapon = vm
		ModeleUtil.ombres(vm, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var hm := ModeleUtil.arme(id)
		hand.add_child(hm)
		var accs: Dictionary = accessoires.get(id, {})
		Accessoires.habiller(vm, id, accs, true)
		Accessoires.habiller(hm, id, accs, true)
		# arme et accessoires de la vue 1re personne : invisibles pour la caméra de la lunette
		for g in vm.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).layers = 2
		fps_arms.geo = Accessoires.points(id, vm) if w.type == "gun" else {}
		var oc := vm.find_child("Oculaire", true, false)
		if oc:
			(oc as MeshInstance3D).material_override = oculaire_mat
		hand_weapon = hm
		if perso_ual and w.type != "gun":
			hm.rotation.x = deg_to_rad(80)   # manche dans le poing, tête de l'arme vers le haut
		return
	var parts: Array = []
	if id == "poings":
		parts = [[Vector3(-0.05, 0, 0), Vector3(0.09, 0.09, 0.2), Color(0.8, 0.62, 0.5)]]
	elif w.type == "gun":
		parts = [
			[Vector3(0, 0, -length / 2.0), Vector3(0.06, 0.1, length), col],
			[Vector3(0, -0.1, -0.02), Vector3(0.05, 0.14, 0.07), col.darkened(0.3)],
			[Vector3(0, 0.02, -length - 0.04), Vector3(0.03, 0.03, 0.1), Color(0.08, 0.08, 0.08)],
		]
		if length > 0.5:
			parts.append([Vector3(0, -0.02, 0.15), Vector3(0.06, 0.12, 0.3), col.darkened(0.2)])
		muzzle_light.position = Vector3(0, 0.03, -length - 0.1)
	else:
		parts = [
			[Vector3(0, 0, 0), Vector3(0.04, 0.04, 0.22), Color(0.2, 0.15, 0.1)],
			[Vector3(0, 0.0, -0.11 - length / 2.0), Vector3(0.025, 0.07, length), col],
		]
	var tilt := 0.0 if (id == "poings" or w.type == "gun") else 0.9
	for p in parts:
		var pos: Vector3 = Vector3(p[0]).rotated(Vector3.RIGHT, tilt)
		_vm_box(viewmodel, pos, p[1], p[2], false, tilt)
		_vm_box(hand, pos, p[1], p[2], true, tilt)


func _vm_box(parent: Node3D, pos: Vector3, size: Vector3, col: Color, shadows: bool, tilt := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.6
	m.metallic = 0.3
	mi.material_override = m
	mi.position = pos
	mi.rotation.x = tilt
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# ================================================================ interaction
func _update_interact() -> void:
	prompt = ""
	interact_target = null
	if placing != "" or Game.ui_open:
		return
	var from := camera.global_position
	var fwd := -camera.global_basis.z
	var to := from + fwd * (2.8 + spring.spring_length)
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.LAYER_WORLD | Game.LAYER_INTERACT | Game.LAYER_ZOMBIE, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	if global_position.distance_to(hit.position) > 3.2:
		return
	var col: Object = hit.collider
	if col and col.has_method("get_prompt"):
		var p: String = col.get_prompt()
		if p != "":
			prompt = p
			if col.has_method("interact"):
				interact_target = col


func open_inventory() -> void:
	var ui := get_tree().get_first_node_in_group("inventory_ui")
	if ui:
		ui.open(null)


func open_storage(crate: Node) -> void:
	var ui := get_tree().get_first_node_in_group("inventory_ui")
	if ui:
		ui.open(crate)


# ================================================================ inventaire (grilles)
## Grilles actives : poches + gilet/veste + sac à dos.
func grilles() -> Array:
	var g: Array = [poches]
	for s in ["torse", "dos"]:
		var e: Dictionary = equipped[s]
		if not e.is_empty() and e.get("contenu") != null:
			g.append(e.contenu)
	return g


func count(id: String) -> int:
	var c := 0
	for g in grilles():
		c += g.compter(id)
	return c


static func nouvelle_entree(id: String, n: int = 1) -> Dictionary:
	var gs: Vector2i = Items.grid(id)
	var contenu = Grille.creer(Items.nom(id), gs.x, gs.y) if gs.x > 0 else null
	return {"id": id, "n": n, "x": 0, "y": 0, "r": false, "contenu": contenu}


## Ajoute des objets dans l'inventaire. Ce qui ne rentre pas est posé au sol.
func add_item(id: String, n: int = 1) -> int:
	if n <= 0:
		return 0
	var w := Items.info(id)
	if w.get("type", "") == "gun" and not mags.has(id):
		mags[id] = int(int(w.mag) * randf_range(0.2, 1.0))
	var reste := n
	if Items.grid(id).x > 0:
		# objets avec rangement (sacs, gilets) : une entrée par objet
		while reste > 0:
			var e := nouvelle_entree(id)
			var ok := false
			for g in grilles():
				if g.ajouter_entree(e):
					ok = true
					break
			if not ok:
				break
			reste -= 1
	else:
		for g in grilles():
			reste = g.ajouter(id, reste)
			if reste == 0:
				break
	if Items.is_weapon(id) and not hotbar.has(id) and count(id) > 0:
		var empty := hotbar.find("")
		if empty >= 0:
			hotbar[empty] = id
			if empty == slot:
				_refresh_weapon_model()
	if reste > 0:
		var e2 := nouvelle_entree(id, reste)
		drop_entry(e2)
		Game.msg("Inventaire plein : %d× %s posé(s) au sol." % [reste, Items.nom(id)])
	return reste


func remove_item(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	var gs := grilles()
	gs.reverse()  # vider le sac avant les poches
	for g in gs:
		n -= g.enlever(id, n)
		if n <= 0:
			break
	_check_hotbar()
	return true


func _check_hotbar() -> void:
	for i in 5:
		if hotbar[i] != "" and count(hotbar[i]) <= 0:
			hotbar[i] = ""
			if i == slot:
				_refresh_weapon_model()


func armor_total() -> float:
	var a := 0.0
	for s in equipped:
		var e: Dictionary = equipped[s]
		if not e.is_empty():
			a += float(Items.info(e.id).get("armor", 0.0))
	return minf(a, 0.75)


func _find_entry(id: String) -> Array:
	for g in grilles():
		for e in g.entrees:
			if e.id == id:
				return [g, e]
	return []


func use_item(id: String) -> void:
	if count(id) <= 0:
		return
	var it := Items.info(id)
	match it.get("type", ""):
		"food", "drink":
			hunger = minf(100.0, hunger + float(it.get("food", 0.0)) * (1.25 if prog.a("cuisinier") else 1.0))
			thirst = minf(100.0, thirst + float(it.get("water", 0.0)) * (1.25 if prog.a("cuisinier") else 1.0))
			remove_item(id)
			Game.msg("Consommé : " + Items.nom(id))
		"heal":
			if health >= prog.sante_max() - 0.5:
				Game.msg("Ta santé est déjà au maximum.")
				return
			health = minf(prog.sante_max(), health + float(it.heal) * (1.3 if prog.a("soigneur") else 1.0))
			remove_item(id)
			Game.msg("Soigné avec : " + Items.nom(id))
		"armor":
			var f := _find_entry(id)
			if not f.is_empty():
				equip_entry(f[1], f[0])
		"melee", "gun":
			var i := hotbar.find(id)
			if i < 0:
				i = hotbar.find("")
				if i < 0:
					i = slot
				hotbar[i] = id
			slot = -1
			_select_slot(i)
		"placeable":
			start_placement(id)
		_:
			Game.msg("Cet objet sert à la fabrication.")


## Consomme une unité d'une entrée précise (nourriture, boisson, soin).
func consume_entry(e: Dictionary, g: Grille) -> bool:
	var it := Items.info(e.id)
	var t: String = it.get("type", "")
	if t == "heal" and health >= 99.5:
		Game.msg("Ta santé est déjà au maximum.")
		return false
	if t == "food" or t == "drink":
		hunger = minf(100.0, hunger + float(it.get("food", 0.0)) * (1.25 if prog.a("cuisinier") else 1.0))
		thirst = minf(100.0, thirst + float(it.get("water", 0.0)) * (1.25 if prog.a("cuisinier") else 1.0))
		Game.msg("Consommé : " + Items.nom(e.id))
	elif t == "heal":
		health = minf(prog.sante_max(), health + float(it.heal) * (1.3 if prog.a("soigneur") else 1.0))
		Game.msg("Soigné avec : " + Items.nom(e.id))
	else:
		return false
	e.n -= 1
	if e.n <= 0:
		g.retirer_entree(e)
	_check_hotbar()
	return true


## Équipe une entrée venant d'une grille. L'ancien équipement retourne dans l'inventaire.
func equip_entry(e: Dictionary, from: Grille) -> bool:
	var s: String = Items.info(e.id).get("slot", "")
	if s == "":
		return false
	if from:
		from.retirer_entree(e)
	var old: Dictionary = equipped[s]
	equipped[s] = e
	if not old.is_empty():
		_stow_entry(old)
	Game.msg("Équipé : " + Items.nom(e.id))
	return true


## Range une entrée dans l'inventaire (ou au sol si plein).
func _stow_entry(e: Dictionary) -> void:
	for g in grilles():
		if g == e.get("contenu"):
			continue
		if g.ajouter_entree(e):
			return
	drop_entry(e)
	Game.msg("Plus de place : %s posé au sol." % Items.nom(e.id))


func unequip(s: String) -> void:
	var e: Dictionary = equipped.get(s, {})
	if e.is_empty():
		return
	equipped[s] = {}
	_stow_entry(e)
	_check_hotbar()


## Pose une entrée au sol, dans un tas d'objets fouillable.
func drop_entry(e: Dictionary) -> void:
	var pile = null
	for c in get_tree().get_nodes_in_group("tas_sol"):
		if c.global_position.distance_to(global_position) < 2.0:
			pile = c
			break
	if pile == null:
		pile = LootContainer.new()
		pile.setup("Objets au sol", "", Vector3(0.5, 0.25, 0.5), Color(0.35, 0.3, 0.25))
		pile.make_storage(6, 6)
		pile.add_to_group("tas_sol")
		get_parent().add_child(pile)
		pile.global_position = global_position - global_basis.z * 0.8
	if not pile.grille.ajouter_entree(e):
		var g2 := Grille.creer("Objets au sol", 6, 6)
		g2.ajouter_entree(e)
	_check_hotbar()


func drop_item(id: String, n: int = 1) -> void:
	n = mini(n, count(id))
	if n <= 0:
		return
	remove_item(id, n)
	drop_entry(nouvelle_entree(id, n))


func near_bench() -> bool:
	if prog.a("atelier"):
		return true
	for b in get_tree().get_nodes_in_group("workbench"):
		if b.global_position.distance_to(global_position) < 3.5:
			return true
	return false


func can_craft(r: Dictionary) -> bool:
	if r.bench and not near_bench():
		return false
	for id in r.needs:
		if count(id) < int(r.needs[id]):
			return false
	return true


func craft(r: Dictionary) -> bool:
	if not can_craft(r):
		return false
	var total := 0
	for id in r.needs:
		remove_item(id, int(r.needs[id]))
		total += int(r.needs[id])
	var qty := int(r.qty)
	var munition: bool = Items.info(r.out).get("type", "") == "ammo"
	if munition and prog.a("cartoucherie"):
		qty = int(ceil(qty * 1.5))
	if not munition and prog.a("maitre_artisan") and randf() < 0.5:
		qty *= 2
	add_item(r.out, qty)
	if prog.a("econome") and randf() < 0.3:
		var ids: Array = r.needs.keys()
		var rendu: String = ids[randi() % ids.size()]
		add_item(rendu, 1)
		Game.msg("Économe : 1× %s récupéré." % Items.nom(rendu))
	Game.make_noise(global_position, 6.0)
	Game.msg("Fabriqué : %d× %s" % [qty, Items.nom(r.out)])
	prog.gagner("fabrication", 12 + total * 3)
	return true


## Taille de l'inventaire de base selon les talents.
func maj_poches() -> void:
	poches.h = maxi(poches.h, prog.lignes_inventaire())


# ================================================================ construction
func start_placement(id: String) -> void:
	if count(id) <= 0 or not PLACE_SIZES.has(id):
		return
	cancel_placement()
	placing = id
	ghost_rot = rotation.y
	ghost = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = PLACE_SIZES[id]
	ghost.mesh = bm
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.albedo_color = Color(0.2, 1.0, 0.3, 0.35)
	ghost.material_override = ghost_mat
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(ghost)
	Game.msg("Pose : clic gauche = poser, molette / R = tourner, clic droit = annuler.")


func cancel_placement() -> void:
	placing = ""
	if ghost and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null


func _update_placement() -> void:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var fwd := -camera.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * (4.5 + spring.spring_length), Game.LAYER_WORLD, [get_rid()])
	var hit := space.intersect_ray(q)
	var pt: Vector3 = from + fwd * (3.0 + spring.spring_length) if hit.is_empty() else hit.position
	# redescendre jusqu'au sol
	var dq := PhysicsRayQueryParameters3D.create(pt + Vector3.UP * 0.4, pt + Vector3.DOWN * 4.0, Game.LAYER_WORLD, [get_rid()])
	var down := space.intersect_ray(dq)
	if not down.is_empty():
		pt = down.position
	var size: Vector3 = PLACE_SIZES[placing]
	ghost_pos = pt
	ghost.global_position = pt + Vector3(0, size.y / 2.0, 0)
	ghost.rotation = Vector3(0, ghost_rot, 0)
	ghost_valid = true
	ghost_reason = ""
	if Vector2(pt.x - global_position.x, pt.z - global_position.z).length() > 5.0:
		ghost_valid = false
		ghost_reason = "Trop loin."
	if placing != "barricade":
		var zone := Game.find_zone(pt + Vector3.UP * 0.5)
		if zone.is_empty():
			ghost_valid = false
			ghost_reason = "À placer à l'intérieur d'un bâtiment."
		elif Game.zombies_in_zone(zone) > 0:
			ghost_valid = false
			ghost_reason = "Il reste %d zombie(s) dans ce bâtiment. Nettoie-le d'abord !" % Game.zombies_in_zone(zone)
	if ghost_valid:
		var sq := PhysicsShapeQueryParameters3D.new()
		var bs := BoxShape3D.new()
		bs.size = size - Vector3(0.1, 0.1, 0.1)
		sq.shape = bs
		sq.transform = Transform3D(Basis(Vector3.UP, ghost_rot), pt + Vector3(0, size.y / 2.0 + 0.04, 0))
		sq.collision_mask = Game.LAYER_PLAYER | Game.LAYER_ZOMBIE | (0 if placing == "barricade" else Game.LAYER_WORLD)
		if not space.intersect_shape(sq, 1).is_empty():
			ghost_valid = false
			ghost_reason = "Pas assez de place."
	ghost_mat.albedo_color = Color(0.2, 1.0, 0.3, 0.35) if ghost_valid else Color(1.0, 0.2, 0.2, 0.35)


func _confirm_placement() -> void:
	if not ghost_valid:
		Game.msg(ghost_reason)
		return
	var obj: Node3D
	if placing == "caisse_stockage":
		var crate = LootContainer.new()
		crate.setup("Caisse de stockage", "", PLACE_SIZES[placing], Color(0.45, 0.32, 0.18))
		crate.make_storage(8, 6)
		obj = crate
	else:
		var p = Placeable.new()
		p.setup(placing)
		if prog.a("charpentier"):
			p.health *= 1.6
		obj = p
	get_parent().add_child(obj)
	obj.global_position = ghost_pos
	obj.rotation.y = ghost_rot
	remove_item(placing)
	prog.gagner("fabrication", 10)
	Game.play_ui("construire", -3.0)
	Game.msg("Posé : " + Items.nom(placing))
	Game.make_noise(global_position, 8.0)
	cancel_placement()


# ================================================================ animations du survivant
func _p_anim(nom: String, vitesse := 1.0, verrou := 0.0) -> void:
	if pap == null or not pap.has_animation(nom):
		return
	if verrou > 0.0:
		p_lock = verrou
		pap.play(nom, 0.08)
		pap.seek(0.0)
		p_anim = nom
	elif p_anim != nom:
		pap.play(nom)
		p_anim = nom
	pap.speed_scale = vitesse


func _update_player_anim(delta: float) -> void:
	shoot_pose_t = maxf(0.0, shoot_pose_t - delta)
	if p_lock > 0.0:
		p_lock -= delta
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	var is_gun: bool = Items.info(current_weapon()).get("type", "") == "gun"
	if perso_ual:
		# vitesses naturelles des animations UAL : marche 0,94 m/s, jogging 2,4, sprint 3,1, accroupi 0,77
		if crouching:
			if hs > 0.3:
				_p_anim("accroupi_marche", clampf(hs / 0.77, 0.6, 2.2))
			else:
				_p_anim("accroupi")
		elif hs > 4.6:
			_p_anim("course", clampf(hs / 3.1, 0.8, 2.2))
		elif hs > 1.9:
			_p_anim("jogging", clampf(hs / 2.4, 0.7, 1.8))
		elif hs > 0.3:
			_p_anim("marche", clampf(hs / 0.94, 0.6, 2.2))
		elif is_gun and reload_t > 0.0 and reload_total > 0.0:
			_p_anim("recharge", pap.get_animation("recharge").length / reload_total if pap.has_animation("recharge") else 1.0)
		elif is_gun and (aiming or shoot_pose_t > 0.0):
			_p_anim("visee")
		elif is_gun:
			_p_anim("arme_idle")
		else:
			_p_anim("idle")
		return
	if crouching:
		if hs > 0.3:
			_p_anim("accroupi_marche", clampf(hs / 1.6, 0.6, 1.6))
		else:
			_p_anim("accroupi")
	elif hs > 5.0:
		_p_anim("course", clampf(hs / 6.5, 0.7, 1.5))
	elif hs > 0.3:
		_p_anim("marche", clampf(hs / 2.2, 0.6, 2.0))
	elif is_gun and (aiming or shoot_pose_t > 0.0):
		_p_anim("visee")
	else:
		_p_anim("idle")
