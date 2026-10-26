extends CharacterBody3D
## Joueur : déplacements, vue 1re personne,
## se pencher, combat (armes blanches + armes à feu), survie, inventaire,
## craft et pose d'objets de base.

const LootContainer = preload("res://scripts/loot_container.gd")
const Placeable = preload("res://scripts/placeable.gd")
const ModeleUtil = preload("res://scripts/modele_util.gd")
const EquipVisuel = preload("res://scripts/equipement_visuel.gd")
const FpsArms = preload("res://scripts/fps_arms.gd")
const Effets = preload("res://scripts/effets.gd")
const Grenade = preload("res://scripts/grenade.gd")
const Peremption = preload("res://scripts/peremption.gd")

const WALK := 4.2
const SPRINT := 7.2
const CROUCH_SPEED := 2.9
const AIM_SPEED := 2.8
const JUMP := 4.8
const GRAVITY := 14.0
const MOUSE_SENS := 0.0022
const EYE_STAND := 1.62
const EYE_CROUCH := 1.05
const FOV := 70.0
const CAM_DIST := 2.7                  # recul de la caméra 3e personne
const CAM_DIST_VISEE := 1.6          # recul en visant (zoom sur l'épaule)
const CAM_EPAULE := Vector3(0.5, 0.15, 0.0)
const CAM_EPAULE_VISEE := Vector3(0.75, 0.1, 0.0)
const FOV_AIM := 50.0
const HAND_ROT := Vector3(90, 0, 0)      # orientation de l'arme dans la main du modèle (ombre)
const PLACE_SIZES := {"etabli": Vector3(1.2, 1.05, 1.1), "barricade": Vector3(2.1, 2.4, 0.2), "caisse_stockage": Vector3(1.2, 0.8, 0.8), "piques": Vector3(2.0, 1.0, 1.0), "barbeles": Vector3(2.4, 1.0, 1.0), "projecteur": Vector3(0.7, 1.9, 0.7), "feu_camp": Vector3(1.2, 0.6, 1.2), "plan_couture": Vector3(1.6, 1.0, 0.8), "collet": Vector3(0.5, 0.3, 0.5), "torche": Vector3(0.25, 1.5, 0.25), "lit": Vector3(1.0, 0.5, 2.0), "piege_machoires": Vector3(0.7, 0.2, 0.8), "recuperateur_eau": Vector3(1.2, 1.6, 1.2), "sechoir": Vector3(1.6, 1.6, 0.8), "canne_peche": Vector3(0.6, 1.0, 0.9), "bac_culture": Vector3(1.4, 0.4, 0.9), "groupe_electrogene": Vector3(1.0, 0.8, 0.7), "panneau_solaire": Vector3(1.6, 1.2, 1.1), "lampe": Vector3(0.3, 1.8, 0.3), "cloture_electrique": Vector3(2.4, 1.3, 0.3), "frigo": Vector3(0.8, 1.8, 0.75)}
const POSE_DEHORS := ["barricade", "piques", "barbeles", "projecteur", "feu_camp", "collet", "torche", "piege_machoires", "recuperateur_eau", "sechoir", "canne_peche", "bac_culture", "groupe_electrogene", "panneau_solaire", "lampe", "cloture_electrique"]   # se posent n'importe où

# --- état de survie
var health := 100.0
var hunger := 100.0
var thirst := 100.0
var argent := 40                  # porte-monnaie (€), dépensé chez les marchands
var stamina := 100.0
var pause_endurance := 0.0          # délai avant que l'endurance remonte (après un effort)
var cache_buisson := false           # le joueur est dans un buisson (les zombies le voient moins)
var buisson_t := 0.0
var alive := true
var hurt_flash := 0.0
var impacts_recus: Array = []         # [position de l'attaquant, temps restant] pour les flèches de dégâts du HUD

# --- inventaire
var poches: Grille = Grille.creer("Sur toi", 8, 5)   # inventaire de base ; sacs et gilets ajoutent de la place
var mags: Dictionary = {}
var equipped := {"tete": {}, "visage": {}, "torse": {}, "dos": {}}
var _sig_equip := "-"                # équipement affiché sur le personnage (equipement_visuel.gd)
var hotbar: Array = ["", "", "", "", ""]
var hotbar_verrou: Array = [false, false, false, false, false]   # cases verrouillées : l'objet garde sa place
var recettes_fav: Array = []     # recettes épinglées (Items.cle_recette)
var slot := 0

# --- caméra / mouvement
var lean := 0.0
var crouching := false
var aiming := false
var sprinting := false
var step_t := 0.0
var flashlight_on := false
var in_zone: Dictionary = {}

# --- combat
var cooldown := 0.0
var reload_t := 0.0
var fire_queued := 0.0
# --- mêlée : un coup simple vers l'avant (armé, frappe, retour), parade
const ARME_COUP := 0.3            # progression où l'arme est ramenée en arrière (tenue pendant la charge)
const IMPACT_COUP := 0.45         # progression où le coup porte
const LAMES := ["hache", "machette", "couteau_km2000"]
const CONTONDANTES := ["batte", "batte_cloutee", "matraque", "pioche"]
const BALAYAGE := ["batte", "batte_cloutee", "machette"]   # alternent coup vers l'avant et balayage latéral
var coup_lateral := false         # le coup en cours est un balayage (de droite à gauche)
var increvable_jour := -1         # jour où le talent Increvable a servi
var melee_p := 1.0                # progression du coup (0 → 1)
var melee_degats := 0.0
var coup_crit := false              # coup de mêlée en cours : critique (chiffre de dégâts doré)
var melee_frappe := true          # le coup a déjà porté
var bloque := false               # parade (clic droit avec une arme de mêlée)
var secousse := 0.0               # secousse de la caméra à l'impact
# coup puissant : maintenir le clic garde l'arme armée, relâcher frappe plus fort
const CHARGE_MIN := 0.2           # durée de maintien (s) au-delà de laquelle le coup est chargé
const CHARGE_MAX := 1.0           # charge complète
var charge_actif := false
var charge_t := 0.0
var melee_charge := 0.0           # charge du coup en cours (0..1)
var vitesse_coup := 1.0           # vitesse de l'animation du corps pendant le coup
var bloque_k := 0.0
var muzzle_t := 0.0

# --- interaction / construction
var prompt := ""
var vehicule: Node = null           # voiture conduite (vehicule.gd), null à pied
var interact_target: Node = null
var placing := ""
var constructeur: Node            # mode construction (touche B)
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
var camera: Camera3D
var bras_camera: SpringArm3D       # porte la caméra 3e personne
var bras_ik: Node = null           # bras calculés pour tenir l'arme (scripts/bras_ik.gd)
var flashlight: SpotLight3D
var muzzle_light: OmniLight3D
var reload_total := 1.0
# --- tenue de l'arme en vue 1re personne
var rec_vel := Vector3.ZERO
var rec_rot := Vector3.ZERO
var recul_profil: Dictionary = {}   # Items.RECUL_FAMILLE de la dernière arme tirée
var recul_a_venir := 0.0            # tangage du recul pas encore appliqué à la visée (rad)
var recul_cumul := 0.0              # tangage du recul appliqué, rendu peu à peu (rad)
var recul_depuis := 9.0             # secondes depuis le dernier tir
var arme_rec := Vector3.ZERO        # coup de l'arme tenue : x = relevée (rad), y = vers l'arrière (m), z = roulis
var arme_rec_v := Vector3.ZERO
var rec_rvel := Vector3.ZERO
var ads := 0.0                    # 0 = à la hanche, 1 = en visée
var sprint_k := 0.0
var air_vy := 0.0
var coup_gauche := false           # alternance des coups de poing
var reload_vide := false          # rechargement à vide (chargeur éjecté, armement)
var reload_cart := 3              # cartouches insérées une à une
var reload_ev: Array = []         # évènements sonores restants
var hand: Node3D
var pap: AnimationPlayer = null   # animations du survivant (modèle Blender)
var accessoires := {}              # arme -> {emplacement: accessoire}
var prog := Progression.new()
var dernier_lieu := ""      # niveaux, attributs, compétences, talents
var hand_weapon: Node3D = null     # arme dans la main du modèle (ombre ; sert aussi à suivre les coups de mêlée)
var perso_ual := false             # modèle réaliste (animations UAL)
var p_anim := ""
var p_lock := 0.0
var shoot_pose_t := 0.0
var bloom := 0.0                  # dispersion en plus après des tirs rapprochés (retombe vite)
var arme_prete_t := 0.0             # vient de finir de recharger (HUD : munitions en vert)
var chargeur_main: Node3D = null  # chargeur porté par la main gauche pendant le rechargement
var pts_bras := {}                 # points de prise de l'arme tenue (FpsArms.hand_points)
var pieds_ik: Node = null           # pieds posés au sol + coup de talon (scripts/pieds_ik.gd)
var corps_vivant: Node = null       # hanches, penché, regard, souffle, coups reçus (scripts/corps_vivant.gd)
var marche_arriere := false         # on recule : la marche est jouée à l'envers
var yaw_prec := 0.0
var flex_amp := 0.0                 # flexion des jambes à l'atterrissage (m)
var flex_t := 9.0
var nage := false                   # en eau profonde : on nage
var air_t := 0.0                    # temps passé en l'air
const SURFACE_EAU := -0.9           # relief.NIVEAU_EAU
var geste_nom := ""                 # geste en cours : fouille, genou, depecage, ramasser, lit, lever (geste())
var geste_t := 0.0
var lit_geste: Node3D = null        # lit sur lequel on est couché (geste « lit »)
var sortie_t := -1.0                # sortie de l'arme choisie : temps écoulé (-1 = aucune)
var sortie_lieu := "dos"
const SORTIE_DUREE := 0.42
var combo_n := 0                    # rang du coup dans l'enchaînement de mêlée (0, 1, 2)
var combo_fin := 0.0                # instant (s) où le dernier coup s'est terminé
var roulade_t := 0.0                # roulade d'esquive en cours (s restantes)
const ROULADE_DUREE := 0.75


func _ready() -> void:
	add_to_group("player")
	Game.player = self
	prog.niveau_global.connect(func(n): Game.msg("NIVEAU %d ! +1 point d'attribut — touche K" % n); Game.play_ui("construire", -2.0, 0.0, 1.3))
	prog.niveau_competence.connect(func(c, n): Game.msg("%s niveau %d : nouveau talent à débloquer — touche K" % [Progression.NOMS[c], n]); Game.play_ui("construire", -2.0, 0.0, 1.5))
	collision_layer = Game.LAYER_PLAYER
	collision_mask = Game.LAYER_WORLD | Game.LAYER_ZOMBIE
	floor_max_angle = deg_to_rad(50.0)   # escaliers construits (pente de 45°)
	constructeur = preload("res://scripts/constructeur.gd").new()
	constructeur.player = self
	add_child(constructeur)
	collision.shape = collision.shape.duplicate()
	floor_snap_length = 0.3
	_build_rig()
	# équipement de départ
	equipped.dos = nouvelle_entree("sac_toile")
	add_item("couteau_km2000", 1)
	add_item("batte", 1)
	add_item("marteau", 1)
	add_item("planche", 8)
	add_item("clous", 12)
	add_item("conserve", 2)
	add_item("eau", 2)
	add_item("bandage", 2)
	add_item("tissu", 2)
	slot = 0
	_refresh_weapon_model()
	Game.capturer_souris()


func _build_rig() -> void:
	head = Node3D.new()
	head.name = "Tete"
	head.position.y = EYE_STAND
	add_child(head)
	lean_pivot = Node3D.new()
	head.add_child(lean_pivot)
	# caméra 3e personne : bras à ressort au-dessus de l'épaule droite (se raccourcit contre les murs)
	bras_camera = SpringArm3D.new()
	bras_camera.collision_mask = Game.LAYER_WORLD
	bras_camera.margin = 0.12
	var sph := SphereShape3D.new()
	sph.radius = 0.18
	bras_camera.shape = sph
	bras_camera.spring_length = CAM_DIST
	bras_camera.position = CAM_EPAULE
	bras_camera.add_excluded_object(get_rid())
	lean_pivot.add_child(bras_camera)
	camera = Camera3D.new()
	camera.fov = Game.fov
	camera.near = 0.05
	camera.far = 700.0
	bras_camera.add_child(camera)
	camera.current = true
	flashlight = SpotLight3D.new()
	flashlight.spot_range = 32.0
	flashlight.spot_angle = 26.0
	flashlight.light_energy = 3.0
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.shadow_enabled = true
	flashlight.visible = false
	flashlight.position = Vector3(0.3, -0.25, -0.35)   # à l'épaule du personnage (pas derrière lui)
	lean_pivot.add_child(flashlight)
	muzzle_light = OmniLight3D.new()
	muzzle_light.omni_range = 7.0
	muzzle_light.light_color = Color(1.0, 0.8, 0.45)
	muzzle_light.light_energy = 0.0
	add_child(muzzle_light)   # placée au bout du canon de l'arme tenue (_refresh_weapon_model)
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
			# corps vivant d'abord (hanches, buste, tête), puis les pieds (le bassin peut descendre), puis les bras
			corps_vivant = preload("res://scripts/corps_vivant.gd").new()
			corps_vivant.corps = self
			sk.add_child(corps_vivant)
			# pieds posés sur le sol (avant les bras : le bassin peut descendre)
			pieds_ik = preload("res://scripts/pieds_ik.gd").new()
			var pieds = pieds_ik
			pieds.corps = self
			pieds.masque = Game.LAYER_WORLD
			sk.add_child(pieds)
			corps_vivant.pieds = pieds
			bras_ik =preload("res://scripts/bras_ik.gd").new()
			bras_ik.corps = self
			sk.add_child(bras_ik)
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
		Game.capturer_souris()
		return
	if vehicule:   # au volant (vehicule.gd : souris = caméra de poursuite)
		if event.is_action_pressed("interagir"):
			vehicule.descendre()
		elif event.is_action_pressed("lampe"):
			vehicule.basculer_phares()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENS * Game.mouse_sens * (0.6 * camera.fov / FOV_AIM * Game.sens_visee if aiming else 1.0)
		rotate_y(-event.relative.x * sens)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sens, -1.45, 1.45)
		if event.relative.y > 0.0:   # le joueur compense le recul lui-même : rien à rendre
			recul_cumul = maxf(0.0, recul_cumul - event.relative.y * sens)
		return
	if placing == "construction":
		if constructeur.entree(event):
			get_viewport().set_input_as_handled()
			return
	if placing != "" and placing != "construction":
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
	elif event.is_action_pressed("construire"):
		constructeur.basculer()
	elif event.is_action_pressed("lampe"):
		flashlight_on = not flashlight_on
		flashlight.visible = flashlight_on
	elif event.is_action_pressed("interagir"):
		if interact_target and is_instance_valid(interact_target):
			interact_target.interact(self)
		elif face_eau:
			_puiser_eau()
	elif event.is_action_pressed("ameliorer") and interact_target and is_instance_valid(interact_target) and interact_target.is_in_group("corpses"):
		se_couvrir_de_tripes(interact_target)
	elif event.is_action_pressed("recharger"):
		_start_reload()
	elif event.is_action_pressed("soigner"):
		var choisi := _soin_conseille()
		if choisi == "":
			Game.msg("Aucun soin utile (bandage, trousse, attelle, antibiotiques, antidouleurs).")
		else:
			use_item(choisi)
	elif event.is_action_pressed("accroupir"):
		if sprinting and is_on_floor() and stamina >= 12.0 and perso_ual and roulade_t <= 0.0:
			_roulade()   # accroupi en plein sprint : roulade d'esquive
		else:
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
	if vehicule:   # au volant : la voiture place le joueur ; seuls les besoins et le lieu avancent
		_update_stats(delta)
		_update_zone()
		interact_target = null
		prompt = vehicule.prompt_conduite()
		return
	var can_act := not Game.ui_open
	_maj_souffle(delta)
	_update_stats(delta)
	_update_zone()
	_move(delta, can_act)
	_update_camera(delta)
	_update_combat(delta, can_act)
	_update_interact()
	_maj_face_eau()
	_maj_fabrication(delta)
	_maj_tripes(delta)
	_ramassage_auto(delta)
	_maj_equipement_visible()
	if placing != "":
		_update_placement()
	hurt_flash = maxf(0.0, hurt_flash - delta * 1.5)
	for imp in impacts_recus:
		imp[1] -= delta
	while not impacts_recus.is_empty() and impacts_recus[0][1] <= 0.0:
		impacts_recus.pop_front()


func _update_stats(delta: float) -> void:
	# caché dans un buisson ? (vue des zombies réduite) — vérifié 5 fois par seconde
	buisson_t -= delta
	if buisson_t <= 0.0:
		buisson_t = 0.2
		cache_buisson = Game.dans_buisson(global_position)
	# contenants proches qui ont encore quelque chose : liseré doré (4 fois par seconde, 6 m)
	surbrillance_t -= delta
	if surbrillance_t <= 0.0:
		surbrillance_t = 0.25
		_maj_surbrillance()
	_maj_maladie(delta)
	_maj_blessures(delta)
	_maj_temperature(delta)
	_frais_t -= delta
	if _frais_t <= 0.0:
		_frais_t = 5.0
		Peremption.avancer_tout(self)
	if Game.admin and Game.admin_besoins:
		hunger = 100.0
		thirst = 100.0
		stamina = prog.endurance_max()
		return
	hunger = maxf(0.0, hunger - delta * 0.045 * prog.faim_mult())
	thirst = maxf(0.0, thirst - delta * 0.07 * prog.soif_mult())
	# endurance : après un effort, courte pause (0,7 s) puis récupération rapide (à l'arrêt surtout)
	pause_endurance = maxf(0.0, pause_endurance - delta)
	if sprinting:
		stamina = maxf(0.0, stamina - delta * 16.0 * (0.65 if prog.a("marathonien") else 1.0))
		pause_endurance = maxf(pause_endurance, 0.5)
	elif pause_endurance <= 0.0:
		stamina = minf(prog.endurance_max(), stamina + delta * (24.0 if velocity.length() < 0.5 else 14.0) * prog.recup_endurance())
	if hunger <= 0.0 or thirst <= 0.0:
		_hurt(0.6 * delta)
	elif hunger > 50.0 and thirst > 50.0 and health < prog.sante_max() and saignement <= 0.0 and infection < 30.0 and froid <= 50.0:
		health = minf(prog.sante_max(), health + 0.25 * delta * (2.0 if prog.a("regeneration") else 1.0) * (1.5 if prog.a("survivant_ne") else 1.0))


var surbrillance_t := 0.0
var surlignes: Array = []           # contenants actuellement en surbrillance
const RAYON_SURBRILLANCE := 6.0


func _maj_surbrillance() -> void:
	var proches: Array = []
	if alive:
		for c in get_tree().get_nodes_in_group("conteneurs"):
			if is_instance_valid(c) and c.global_position.distance_squared_to(global_position) < RAYON_SURBRILLANCE * RAYON_SURBRILLANCE:
				if c.a_donner():
					proches.append(c)
	for c in surlignes:
		if is_instance_valid(c) and not proches.has(c):
			c.surligner(false)
	for c in proches:
		c.surligner(true)
	surlignes = proches


## Dépense d'endurance (coup, saut, parade) : la récupération attend un court instant.
func _depenser_endurance(n: float) -> void:
	stamina = maxf(0.0, stamina - n)
	pause_endurance = 0.7


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
	if _grimper(input, can_act):
		return
	var dir := (global_basis * Vector3(input.x, 0, input.y))
	dir.y = 0.0
	dir = dir.normalized()
	aiming = can_act and Input.is_action_pressed("viser") and placing == ""
	sprinting = can_act and Input.is_action_pressed("sprint") and input.y < -0.2 and not crouching and not aiming and stamina > 1.0
	var speed := WALK
	if sprinting:
		speed = SPRINT * (1.12 if prog.a("coureur") else 1.0) * (1.0 + 0.03 * prog.rang("pied_leger"))
	elif crouching:
		speed = CROUCH_SPEED * (1.3 if prog.a("rodeur") else 1.0)
	elif aiming:
		speed = AIM_SPEED
	# dans l'eau : on avance lentement, sans sprinter
	var mouille := Game.dans_eau(global_position)
	if mouille:
		speed = minf(speed, WALK * 0.55)
	# eau profonde (plus de 1,3 m) : on nage, le buste à la surface
	nage = mouille and _profondeur_eau() > 1.3
	if nage:
		speed = minf(speed, WALK * 0.5)
		sprinting = false
		if crouching:
			_set_crouch(false)
	if arc_tension > 0.0:
		speed = minf(speed, AIM_SPEED)
		sprinting = false
	if soin_t > 0.0:
		speed = minf(speed, WALK * 0.5)   # on se soigne en marchant lentement
		sprinting = false
	if fracture:
		speed = minf(speed, WALK * 0.6)   # jambe cassée : on boite, sans courir
		sprinting = false
		if float(sang_armes.get(current_weapon(), 0.0)) > 0.0:
			sang_armes[current_weapon()] = maxf(0.0, float(sang_armes[current_weapon()]) - delta * 0.25)
			_appliquer_sang()
	if _adrenaline():
		speed *= 1.2
	if roulade_t > 0.0:
		# roulade : élan droit devant, qui faiblit en fin de roulade
		roulade_t -= delta
		var elan := -global_basis.z * lerpf(3.0, 7.5, clampf(roulade_t / ROULADE_DUREE, 0.0, 1.0))
		velocity.x = elan.x
		velocity.z = elan.z
		sprinting = false
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	var accel := 40.0 if is_on_floor() else 6.0
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)
	if nage:
		velocity.y = clampf((SURFACE_EAU - 0.95 - global_position.y) * 5.0, -3.0, 2.0)
	elif is_on_floor():
		if can_act and Input.is_action_just_pressed("sauter") and stamina > 4.0:
			if crouching:
				_set_crouch(false)
			else:
				velocity.y = JUMP * (0.6 if fracture else 1.0)
				_depenser_endurance(4.0)
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	air_t = 0.0 if (is_on_floor() or nage) else air_t + delta
	# bruit des pas
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.5:
		step_t -= delta
		if step_t <= 0.0:
			step_t = 0.36 if sprinting else (0.7 if crouching else 0.55)
			var sol := _sol_sous_pieds()
			if mouille or sol == "eau":
				Game.make_noise(global_position, 10.0)
				Game.play_ui("eau", -8.0, 0.2)
			else:
				var vol := -7.0 if sprinting else (-19.0 if crouching else -13.0)
				Game.play_ui("pas_%s%d" % [sol, randi_range(1, 3)], vol, 0.12)
				if sprinting:
					Game.make_noise(global_position, 16.0)
				elif not crouching:
					Game.make_noise(global_position, 6.0)


## Échelles (Game.echelles) : face à l'échelle, avancer fait monter et reculer descendre ;
## en haut, avancer fait passer sur la plateforme ; Espace lâche l'échelle. Renvoie vrai si on grimpe.
var sur_echelle := false


func _grimper(input: Vector2, can_act: bool) -> bool:
	var avant := -global_basis.z
	avant.y = 0.0
	avant = avant.normalized()
	for e in Game.echelles:
		var pied: Vector3 = e.pos
		var n: Vector3 = e.n
		var haut: float = pied.y + float(e.haut)
		var axe := pied + n * 0.45
		var ecart := Vector2(global_position.x - axe.x, global_position.z - axe.z).length()
		var y := global_position.y
		if ecart > 0.9 or y < pied.y - 0.5 or y > haut + 0.4:
			continue
		var face := avant.dot(-n) > 0.4
		if not sur_echelle:
			# on s'accroche : en bas en avançant, en haut en reculant vers le vide
			var bas := y < haut - 0.3 and input.y < -0.3 and face and ecart < 0.7
			var depuis_haut := y >= haut - 0.3 and input.y > 0.3 and face
			if not (can_act and (bas or depuis_haut)):
				continue
			sur_echelle = true
		if can_act and Input.is_action_just_pressed("sauter"):
			sur_echelle = false
			velocity = n * 3.0 + Vector3.UP * 1.0
			move_and_slide()
			return true
		sprinting = false
		aiming = false
		if y >= haut + 0.1 and input.y < -0.3:
			# en haut : on passe sur la plateforme
			velocity = -n * 2.5 + Vector3.UP * 0.5
			move_and_slide()
			if Vector2(global_position.x - axe.x, global_position.z - axe.z).length() > 0.75:
				sur_echelle = false
			return true
		if is_on_floor() and input.y > 0.3 and y < pied.y + 0.3:
			sur_echelle = false   # arrivé en bas
			return false
		var vy := -input.y * 2.4 if can_act else 0.0
		var rappel := (axe - global_position) * 8.0
		velocity = Vector3(rappel.x, vy, rappel.z)
		move_and_slide()
		step_t -= get_physics_process_delta_time() * absf(vy)
		if step_t <= 0.0:
			step_t = 0.45
			Game.play_ui("pas_metal1", -14.0, 0.12)
		return true
	sur_echelle = false
	return false


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


## Sol sous les pieds : intérieur (bois dans les maisons, béton ailleurs), objets (bois / métal), extérieur.
func _sol_sous_pieds() -> String:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 0.5, Game.LAYER_WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var c: Object = hit.collider
		if c is Placeable:
			return "bois"
		if c is LootContainer:
			return "metal"
	if not in_zone.is_empty():
		return "bois" if str(in_zone.get("kind", "")) in ["maison", "ferme", "grange"] else "beton"
	return Game.sol_exterieur(global_position)


## Souffle quand l'endurance est basse.
var souffle_lecteur: AudioStreamPlayer
var air_avant := 0.0


func _maj_souffle(delta: float) -> void:
	if souffle_lecteur == null:
		var s = Game.sfx_boucle("souffle")
		if s == null:
			return
		souffle_lecteur = AudioStreamPlayer.new()
		souffle_lecteur.stream = s
		souffle_lecteur.volume_db = -60.0
		add_child(souffle_lecteur)
		souffle_lecteur.play()
	var essouffle := clampf((0.45 - stamina / prog.endurance_max()) / 0.45, 0.0, 1.0)
	var cible := essouffle * 0.55 if alive else 0.0
	var lin := move_toward(db_to_linear(souffle_lecteur.volume_db), cible, delta * 0.4)
	souffle_lecteur.volume_db = linear_to_db(maxf(lin, 0.0005))
	souffle_lecteur.pitch_scale = 0.9 + essouffle * 0.35
	# atterrissage
	if is_on_floor() and air_avant < -5.0:
		Game.play_ui("atterrissage", -6.0 + clampf(-air_avant - 5.0, 0.0, 6.0), 0.1)
	air_avant = velocity.y if not is_on_floor() else 0.0


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
	# se pencher
	var lean_target := 0.0
	if not Game.ui_open:
		if Input.is_action_pressed("pencher_gauche"):
			lean_target -= 1.0
		if Input.is_action_pressed("pencher_droite"):
			lean_target += 1.0
	lean = move_toward(lean, lean_target, delta * 5.0)
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
	# le buste se penche (pieds au sol) ; ancien modèle sans squelette : tout le corps bascule
	if pieds_ik:
		pieds_ik.penche = lean * 0.45
		modele.rotation.z = 0.0
	else:
		modele.rotation.z = -lean * 0.25
	head.position.y = move_toward(head.position.y, EYE_CROUCH if crouching else EYE_STAND, delta * 4.0)
	if pap == null:
		modele.scale.y = move_toward(modele.scale.y, 0.7 if crouching else 1.0, delta * 3.0)
	else:
		_maj_corps(delta)
		_update_player_anim(delta)
	_set_model_shadow_only(false)
	hand.visible = true
	var cw := current_weapon()
	var cwi := Items.info(cw)
	var is_gun: bool = cwi.get("type", "") == "gun"
	var avec_arc := cw == "arc" and placing == ""
	arc_vise = move_toward(arc_vise, 1.0 if avec_arc and (aiming or arc_tension > 0.0 or cooldown > 0.0) else 0.0, delta * 6.0)   # (arc gardé levé un instant après le tir)
	var vise := (aiming and is_gun and reload_t <= 0.0 and placing == "") or (avec_arc and arc_vise > 0.5)
	ads = move_toward(ads, 1.0 if vise else 0.0, delta * (5.5 if vise else 7.0))
	var k_ads := smoothstep(0.0, 1.0, ads)
	var fov_vise := FOV_AIM * float(arme_stats(cw).get("fov_visee", 1.0)) if is_gun else FOV_AIM
	if avec_arc:
		fov_vise = lerpf(FOV_AIM + 8.0, FOV_AIM - 4.0, arc_tension)   # le regard se resserre en bandant
	camera.fov = lerpf(Game.fov, lerpf(Game.fov, fov_vise, 0.6), k_ads)
	# --- caméra 3e personne : se rapproche de l'épaule en visant (aussi avec une arme de mêlée en parade)
	var k_cam := maxf(k_ads, smoothstep(0.0, 1.0, bloque_k) * 0.4)
	bras_camera.spring_length = lerpf(CAM_DIST, CAM_DIST_VISEE, k_cam) * (0.85 if crouching else 1.0) + maxf(arme_rec.y, 0.0) * 1.5
	bras_camera.position = CAM_EPAULE.lerp(CAM_EPAULE_VISEE, k_cam)
	var hs := Vector2(velocity.x, velocity.z).length()
	sprint_k = move_toward(sprint_k, 1.0 if (sprinting and hs > 3.0 and is_on_floor() and reload_t <= 0.0) else 0.0, delta * 5.0)
	# atterrissage : petite secousse
	if is_on_floor() and air_vy < -3.0:
		flex_amp = clampf(0.08 + (-air_vy - 3.0) * 0.035, 0.08, 0.36)
		flex_t = 0.0
		if air_vy < -9.0 and perso_ual:
			_p_anim("reception", 1.3, 0.45)   # grosse chute : réception accroupie, mains au sol
		if air_vy < CHUTE_DEGATS and not nage and not (Game.admin and Game.admin_vol):
			_chute(-air_vy)
		rec_rvel += Vector3(clampf(air_vy * 0.25, -3.0, 0.0), 0, 0)
	air_vy = velocity.y if not is_on_floor() else 0.0
	# ressort du recul (petits pas de temps : stable même à faible nombre d'images par seconde)
	var reste := minf(delta, 0.25)
	while reste > 0.0:
		var dt := minf(reste, 1.0 / 240.0)
		reste -= dt
		rec_rvel += (-rec_rot * 170.0 - rec_rvel * 17.0) * dt
		rec_rot += rec_rvel * dt
		if not recul_profil.is_empty():
			arme_rec_v += (-arme_rec * float(recul_profil.raideur) - arme_rec_v * float(recul_profil.amort)) * dt
			arme_rec += arme_rec_v * dt
	_maj_recul_visee(delta)
	# léger recul de la caméra à chaque tir
	camera.rotation = Vector3(rec_rot.x * 0.25, 0.0, 0.0)
	_maj_melee(delta)
	_maj_achevement(delta)
	lancer_t = maxf(0.0, lancer_t - delta)
	goupille_t = maxf(0.0, goupille_t - delta)
	if hand_weapon and is_instance_valid(hand_weapon) and cwi.get("type", "") == "lancer":
		hand_weapon.visible = not (lancer_t > 0.0 and lancer_t < LANCER_DUREE * 0.45)
		# Molotov (méta « goulot ») : tenu comme une bouteille, goulot vers le ciel, sauf pendant l'élan du lancer
		if hand_weapon.has_meta("goulot"):
			if lancer_t <= 0.0 and goupille_t <= 0.0:
				var avant := -global_basis.z
				var b := Basis.looking_at(Vector3.UP, avant)   # -Z (goulot) vers le haut
				hand_weapon.global_basis = b.scaled(hand_weapon.global_basis.get_scale())
			else:
				hand_weapon.rotation = Vector3(deg_to_rad(80), 0, 0)
	# parade (clic droit avec une arme de mêlée)
	var est_melee: bool = cwi.get("type", "") == "melee" or cw == "poings"
	bloque = est_melee and aiming and melee_p >= 1.0 and placing == ""
	bloque_k = move_toward(bloque_k, 1.0 if bloque else 0.0, delta * 8.0)
	# réarmement manuel après le tir (culasse à verrou, levier) : éjection de la douille à mi-course
	if pompe_t > 0.0:
		pompe_t = maxf(0.0, pompe_t - delta)
		if not cycle_ejecte and 1.0 - pompe_t / CYCLE_DUREE > 0.5:
			cycle_ejecte = true
			_ejecter(cw, false)
	# rechargement : sons au bon moment
	if reload_t > 0.0 and reload_total > 0.0:
		_reload_evenements(1.0 - reload_t / reload_total)
	_update_lampes()
	_maj_laser(cw)
	_maj_bras(delta, cw, cwi, is_gun, k_ads)
	bloom = move_toward(bloom, 0.0, delta * 2.2)
	arme_prete_t = maxf(0.0, arme_prete_t - delta)
	muzzle_t = maxf(0.0, muzzle_t - delta)
	muzzle_light.light_energy = 6.0 if muzzle_t > 0.0 else 0.0
	# secousse de la caméra à l'impact
	secousse = move_toward(secousse, 0.0, delta * 4.0)
	camera.rotation += Vector3(randf_range(-1.0, 1.0) * 0.02, randf_range(-1.0, 1.0) * 0.02, randf_range(-1.0, 1.0) * 0.012) * secousse * secousse


## Bras du personnage : arme à feu au torse, en joue vers le réticule ou en rechargement
## (main gauche au chargeur, à la poche, à la culasse) ; arme de mêlée à deux mains : main gauche sur le manche.
## Désactivé pendant les coups à mains nues, le lancer et les animations verrouillées.
func _maj_bras(delta: float, cw: String, cwi: Dictionary, is_gun: bool, k_ads: float) -> void:
	if bras_ik == null:
		if arc_modele and is_instance_valid(arc_modele):
			arc_modele.maj(arc_tension, arc_tension > 0.0 or arc_vise > 0.6)
		return
	if cw == "arc" and arc_modele and is_instance_valid(arc_modele):
		arc_modele.maj(arc_tension, (arc_tension > 0.0 or arc_vise > 0.6) and count("fleche") > 0 and cooldown <= 0.0, bras_ik.allonge)
		bras_ik.arme = arc_modele
		bras_ik.arc = true
		bras_ik.arc_vise = arc_vise
		bras_ik.tension = arc_tension
		bras_ik.main_g_tendue = false
		bras_ik.achevement = -1.0
		bras_ik.poids = move_toward(bras_ik.poids, 1.0 if alive and p_lock <= 0.0 and sortie_t < 0.0 else 0.0, delta * 6.0)
		bras_ik.cible_visee = _aim_point(80.0)
		return
	bras_ik.arc = false
	var arme_ok := alive and hand_weapon != null and is_instance_valid(hand_weapon)
	var deux_mains: bool = cwi.get("type", "") == "melee" and cw in FpsArms.TWO_HANDED_MELEE
	# à deux mains seulement pendant le coup, la charge et la parade (au repos : arme portée d'une main)
	# lancer : bras gauche tendu vers la cible pendant l'élan (jusqu'au lâcher)
	var bras_tendu: bool = cwi.get("type", "") == "lancer" and lancer_t > LANCER_DUREE - 0.4
	if achevement_t <= 0.0 and bras_ik.poids <= 0.0:
		bras_ik.achevement = -1.0
	var rapide: bool = deux_mains or goupille_t > 0.0 or bras_tendu or bras_ik.achevement >= 0.0
	var actif: bool = sortie_t < 0.0 and arme_ok and ((is_gun and p_lock <= 0.0) or (deux_mains and (melee_p < 1.0 or charge_actif or bloque)) or goupille_t > 0.0 or bras_tendu or (achevement_t > 0.0 and bras_ik.achevement >= 0.0))
	bras_ik.main_g_tendue = cwi.get("type", "") == "lancer" and goupille_t <= 0.0   # (garde ce mode pendant le retour)
	bras_ik.poids = move_toward(bras_ik.poids, 1.0 if actif else 0.0, delta * (12.0 if rapide else 6.0))
	if bras_ik.arme != hand_weapon:
		bras_ik.arme = hand_weapon
		pts_bras = FpsArms.hand_points(cw, cwi, _geo_prise(cw, hand_weapon)) if arme_ok else {"L": null}
		bras_ik.point_main_g = pts_bras.L
		bras_ik.pistolet = float(cwi.get("len", 0.3)) < 0.4
		bras_ik.main_g_seule = deux_mains
		_preparer_chargeur_main()
	if not actif and bras_ik.poids <= 0.0:
		bras_ik.recharge = false
		return
	# grenade : tenue devant la poitrine, la main gauche vient arracher la goupille avant le lancer
	if goupille_t > 0.0:
		var kg := smoothstep(0.45, 1.0, 1.0 - goupille_t / GOUPILLE_DUREE)
		bras_ik.recharge = true
		bras_ik.recharge_rot = Vector3.ZERO
		bras_ik.recharge_off = Vector3(-0.05, 0.16, -0.05)
		bras_ik.point_l_recharge = Vector3(0.0, 0.05, 0.0) + Vector3(-0.16, 0.04, 0.03) * kg
		bras_ik.visee = 0.0
		bras_ik.sprint = 0.0
		bras_ik.cible_visee = _aim_point(80.0)
		return
	# rechargement : pose de l'ancienne vue 1re personne, appliquée à l'arme tenue en 3e personne
	var p_rel := 1.0 - reload_t / reload_total if is_gun and reload_t > 0.0 and reload_total > 0.0 else -1.0
	bras_ik.recharge = p_rel >= 0.0
	var mag_arme := true
	var mag_main := false
	if bras_ik.recharge:
		var pose: Dictionary = FpsArms.reload_pose(cw, cwi, p_rel, pts_bras, reload_vide, reload_cart)
		bras_ik.recharge_rot = pose.rot
		bras_ik.recharge_off = pose.off
		bras_ik.point_l_recharge = pose.L
		mag_arme = pose.get("mag_arme", true)
		mag_main = pose.get("mag", false)
	var ch: Node3D = hand_weapon.get_node_or_null("Chargeur") if arme_ok else null
	if ch:
		if ch.visible != mag_arme:
			ch.visible = mag_arme
	if chargeur_main and is_instance_valid(chargeur_main):
		chargeur_main.visible = mag_main
		if mag_main and arme_ok:
			var poing: Node3D = chargeur_main.get_parent().get_node_or_null("Poing")
			chargeur_main.global_basis = hand_weapon.global_basis * (ch.basis if ch else Basis.IDENTITY)
			if poing:
				chargeur_main.global_position = poing.global_position - hand_weapon.global_basis.y.normalized() * 0.03
	# en joue en visant, et aussi un instant après chaque tir
	var en_joue := 0.0 if bras_ik.recharge else maxf(k_ads, clampf(shoot_pose_t / 0.4, 0.0, 1.0))
	bras_ik.visee = move_toward(bras_ik.visee, en_joue, delta * 8.0)
	bras_ik.sprint = 0.0 if bras_ik.recharge else smoothstep(0.0, 1.0, sprint_k)
	bras_ik.cible_visee = _aim_point(80.0)
	bras_ik.recul_arme = arme_rec


## Copie du chargeur de l'arme tenue, portée par la main gauche pendant le rechargement.
func _preparer_chargeur_main() -> void:
	if chargeur_main and is_instance_valid(chargeur_main):
		chargeur_main.queue_free()
	chargeur_main = null
	if hand_weapon == null or not is_instance_valid(hand_weapon) or bras_ik == null:
		return
	var ch: Node3D = hand_weapon.get_node_or_null("Chargeur")
	var main_g: Node = bras_ik.get_skeleton().get_node_or_null("MainSimple_l") if bras_ik.get_skeleton() else null
	if ch == null or main_g == null:
		return
	chargeur_main = ch.duplicate() as Node3D
	chargeur_main.visible = false
	main_g.add_child(chargeur_main)
	# centré sur son milieu (le poing le tient par le corps)
	var a := AABB()
	var premier := true
	for mi in chargeur_main.find_children("*", "MeshInstance3D", true, false):
		var b2: AABB = (mi as MeshInstance3D).transform * (mi as MeshInstance3D).get_aabb()
		a = b2 if premier else a.merge(b2)
		premier = false
	for e in chargeur_main.get_children():
		if e is Node3D:
			(e as Node3D).position -= a.get_center()


## Zombie à terre ou rampant juste devant soi (même si le regard passe au-dessus).
func _chercher_a_achever() -> void:
	if achevement_t > 0.0:
		return
	var fwd := -global_basis.z
	for z in get_tree().get_nodes_in_group("zombies"):
		if not z.achevable():
			continue
		var d: Vector3 = z.global_position - global_position
		if d.length() < 2.2 and absf(d.y) < 1.2 and fwd.dot(Vector3(d.x, 0, d.z).normalized()) > 0.5:
			prompt = "[F] Achever"
			interact_target = z
			return


## Coup de grâce : coup de talon sur la tête (pieds_ik), ou balle à bout portant avec une arme à feu chargée.
var achevement_t := 0.0
const ACHEV_DUREE := 0.5            # durée du geste (impact aux 3/5)
var achevement_cible: Node = null
var achev_mode := ""                # "talon", "deux_mains", "lame" (geste du coup de grâce)
var achev_point := Vector3.ZERO     # tête visée


func achever(z: Node) -> void:
	if achevement_t > 0.0 or reload_t > 0.0:
		return
	var id := current_weapon()
	var w := arme_stats(id)
	if w.get("type", "") == "gun" and int(mags.get(id, 0)) > 0:
		# balle dans la tête à bout portant
		head.rotation.x = clampf(head.rotation.x - 0.35, -1.45, 1.45)
		var t: Vector3 = z._pos_os("Head")
		if t == Vector3.INF:
			t = z.global_position + Vector3.UP * 0.3
		_fire_gun(id, w)
		z.take_hit(99999.0, t, global_position)
		Effets.gerbe_sang(get_parent(), t, Vector3.DOWN, 1.4)
		prog.gagner("combat", 10)
		return
	achevement_t = ACHEV_DUREE
	achevement_cible = z
	cooldown = ACHEV_DUREE + 0.05
	melee_p = 1.0
	# point frappé : la tête si elle est à portée, sinon la poitrine (zombie tombé la tête loin de soi)
	achev_point = z.global_position + Vector3.UP * 0.15
	var meilleur := 9999.0
	for os_nom in ["Head", "spine_03", "spine_02"]:
		var pt: Vector3 = z._pos_os(os_nom)
		if pt == Vector3.INF:
			continue
		var d := Vector2(pt.x - global_position.x, pt.z - global_position.z).length() + (0.0 if os_nom == "Head" else 0.6)
		if d < meilleur:
			meilleur = d
			achev_point = pt
	# mains nues : coup de talon (pieds_ik) ; arme à deux mains : levée puis abattue, debout ;
	# lame ou matraque : accroupi, plantée vers le bas (bras calculés par bras_ik)
	achev_mode = ""
	if id == "poings" and pieds_ik:
		achev_mode = "talon"
		pieds_ik.cible_pied = achev_point
		pieds_ik.coup_pied = 0.0
		_p_anim("idle", 1.0, ACHEV_DUREE)
	elif bras_ik and hand_weapon and is_instance_valid(hand_weapon):
		achev_mode = "deux_mains" if id in FpsArms.TWO_HANDED_MELEE else "lame"
		bras_ik.cible_achev = achev_point
		bras_ik.longueur_arme = float(Items.info(id).get("len", 0.5))
		bras_ik.achevement = 0.0
		_p_anim("idle" if achev_mode == "deux_mains" else "accroupi", 1.0, ACHEV_DUREE)
	elif perso_ual:
		_p_anim("estoc", 2.1, ACHEV_DUREE)
	Game.play_ui("vent_lourd", -6.0, 0.1)


func _maj_achevement(delta: float) -> void:
	if achevement_t <= 0.0:
		return
	var avant := achevement_t
	achevement_t = maxf(0.0, achevement_t - delta)
	var p_achev := 1.0 - achevement_t / ACHEV_DUREE if achevement_t > 0.0 else -1.0
	if pieds_ik:
		pieds_ik.coup_pied = p_achev if achev_mode == "talon" else -1.0
	if bras_ik:
		if achev_mode in ["deux_mains", "lame"]:
			bras_ik.achevement = p_achev if p_achev >= 0.0 else 1.0   # pose finale gardée le temps du retour
	# petit pas vers la tête pour qu'elle soit à bonne distance (talon, lame, ou bout d'une arme longue)
	if achev_mode != "" and achevement_t > ACHEV_DUREE * 0.53 and is_instance_valid(achevement_cible):
		var vers := Vector3(achev_point.x - global_position.x, 0.0, achev_point.z - global_position.z)
		var reste: float = vers.length() - {"talon": 0.5, "lame": 0.55, "deux_mains": 0.9}[achev_mode]
		if reste > 0.02:
			move_and_collide(vers.normalized() * minf(reste, delta * 3.6))
	if avant > ACHEV_DUREE * 0.4 and achevement_t <= ACHEV_DUREE * 0.4 and is_instance_valid(achevement_cible) and achevement_cible.state != achevement_cible.State.DEAD:
		var z = achevement_cible
		var t: Vector3 = z._pos_os("Head")
		if t == Vector3.INF:
			t = z.global_position + Vector3.UP * 0.3
		z.take_hit(99999.0, t, global_position)
		Effets.gerbe_sang(get_parent(), t, Vector3.DOWN, 1.3)
		Game.play_ui("coup", 0.0, 0.1)
		Game.play_ui("impact", -2.0, 0.1)
		prog.gagner("combat", 10)
		if current_weapon() != "poings" and Items.info(current_weapon()).get("type", "") == "melee":
			_salir_arme(current_weapon(), 0.3)


## Sang sur les armes de mêlée : s'accumule à chaque coup, part dans l'eau.
var sang_armes := {}
var mat_sang: StandardMaterial3D = null


func _salir_arme(id: String, quantite: float) -> void:
	sang_armes[id] = clampf(float(sang_armes.get(id, 0.0)) + quantite, 0.0, 1.0)
	_appliquer_sang()


func _appliquer_sang() -> void:
	var niveau := float(sang_armes.get(current_weapon(), 0.0))
	if mat_sang == null:
		mat_sang = StandardMaterial3D.new()
		mat_sang.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_sang.albedo_texture = Effets._texture("sang")
		mat_sang.uv1_triplanar = true
		mat_sang.uv1_scale = Vector3(6, 6, 6)
		mat_sang.roughness = 0.3
	mat_sang.albedo_color = Color(0.55, 0.05, 0.04, clampf(niveau * 1.1, 0.0, 0.95))
	for modele in [hand_weapon]:
		if modele == null or not is_instance_valid(modele):
			continue
		for g in modele.find_children("*", "MeshInstance3D", true, false):
			if not g.has_meta("accessoire") and g.get_parent() and not g.get_parent().has_meta("accessoire"):
				(g as MeshInstance3D).material_overlay = mat_sang if niveau > 0.01 else null


## Flamme de bouche, fumée, douille éjectée (ou cartouche du fusil à pompe au coup de pompe).
var pompe_t := 0.0


const CYCLE_DUREE := 0.62
var cycle_ejecte := true


func _effets_tir(id: String, w: Dictionary) -> void:
	var modele: Node3D = hand_weapon
	if modele == null or not is_instance_valid(modele):
		return
	var pts := Accessoires.points(id, modele)
	var bouche: Vector3 = pts.get("bouche", Vector3(0, 0.03, -0.3))
	var silencieux: bool = w.get("silencieux", false)
	var acc_bouche: String = accessoires.get(id, {}).get("bouche", "")
	if acc_bouche != "":
		bouche = Vector3(pts.get("canon", bouche)) + Vector3(0, 0, -float(Accessoires.infos(acc_bouche).get("longueur", 0.15)))
	var info := Items.info(id)
	var taille := 0.26 if float(w.get("len", 0.3)) >= 0.4 else 0.18
	if info.get("famille", "") == "pompe":
		taille = 0.36
	elif info.get("famille", "") in ["sniper", "mitrailleuse"]:
		taille = 0.32
	if not silencieux:
		Effets.flamme(modele, bouche, taille, 1)
		Effets.eclair(get_parent(), modele.global_transform * bouche, Game.is_night() or not in_zone.is_empty())
	var g_bouche: Vector3 = modele.global_transform * bouche
	var avant := -modele.global_basis.z.normalized()
	Effets.fumee(get_parent(), g_bouche + avant * 0.05, avant, 3 if silencieux else 6)
	# douille / cartouche : tout de suite (semi-automatiques), au réarmement (verrou, levier), au rechargement (cassant)
	if info.get("cassant", false):
		return
	if info.get("verrou", false) or info.get("levier", false):
		pompe_t = CYCLE_DUREE
		cycle_ejecte = false
		get_tree().create_timer(0.12).timeout.connect(func(): if is_instance_valid(self): Game.play_ui("culasse", -5.0, 0.06, 0.9))
		return
	_ejecter(id, info.get("famille", "") == "pompe")


func _ejecter(id: String, cartouche: bool) -> void:
	var modele: Node3D = hand_weapon
	if modele == null or not is_instance_valid(modele):
		return
	var pts := Accessoires.points(id, modele)
	var v: Vector3 = pts.get("viseur", Vector3(0, 0.05, 0))
	var fenetre := Vector3(0.02, v.y - 0.03, v.z + 0.03)
	if pts.has("chargeur"):
		fenetre.z = pts.chargeur.z + 0.02
	elif pts.has("culasse"):
		fenetre = Vector3(0.02, pts.culasse.y - 0.01, pts.culasse.z)
	var b := modele.global_basis.orthonormalized()
	var pos: Vector3 = modele.global_transform * fenetre
	var vit := b.x * randf_range(2.0, 3.0) + b.y * randf_range(1.2, 2.0) + b.z * randf_range(0.2, 0.8) + velocity
	Effets.douille(get_parent(), pos, vit, cartouche)


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
			"ouvrir":
				Game.play_ui("culasse", -6.0, 0.1, 0.8)
				# fusil cassant : les étuis vides sont éjectés à l'ouverture
				var id := current_weapon()
				for i in maxi(1, int(arme_stats(id).mag) - int(mags.get(id, 0))):
					_ejecter(id, true)


## Le chargeur vide tombe au sol (objet physique qui disparaît après un moment).
func _lacher_chargeur() -> void:
	if hand_weapon == null or not is_instance_valid(hand_weapon):
		return
	var pts := FpsArms.hand_points(current_weapon(), Items.info(current_weapon()), _geo_prise(current_weapon(), hand_weapon))
	var depart: Vector3 = hand_weapon.global_transform * Vector3(pts.get("well", Vector3(0, -0.08, -0.04)))
	var rb := RigidBody3D.new()
	rb.collision_layer = 0
	rb.collision_mask = Game.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.03, 0.12, 0.06)
	cs.shape = bs
	rb.add_child(cs)
	# vrai chargeur de l'arme (taille réelle)
	var source := ModeleUtil.arme(current_weapon())
	var ch: Node3D = source.get_node_or_null("Chargeur") if source else null
	if ch:
		source.remove_child(ch)
		var a := AABB()
		var premier := true
		for mi in ch.find_children("*", "MeshInstance3D", true, false):
			var b2: AABB = (mi as MeshInstance3D).transform * (mi as MeshInstance3D).get_aabb()
			a = b2 if premier else a.merge(b2)
			premier = false
		ch.position = -a.get_center()
		bs.size = a.size.max(Vector3.ONE * 0.02)
		rb.add_child(ch)
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = bs.size
		mi.mesh = bm
		rb.add_child(mi)
	if source:
		source.queue_free()
	get_parent().add_child(rb)
	rb.global_position = depart
	rb.global_basis = hand_weapon.global_basis.orthonormalized()
	rb.linear_velocity = velocity * 0.8 + Vector3(0, -1.0, 0)
	rb.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	get_tree().create_timer(25.0).timeout.connect(rb.queue_free)
	get_tree().create_timer(0.45).timeout.connect(func(): if is_instance_valid(rb): Game.play_3d("chargeur_sol", rb.global_position, -8.0, 0.15, 12.0))


## Point du laser (module PEQ-15) projeté là où pointe le canon.
var point_laser: MeshInstance3D = null


func _maj_laser(cw: String) -> void:
	var actif: bool = arme_stats(cw).get("laser", false) and reload_t <= 0.0 and alive
	var modele: Node3D = hand_weapon
	var em: Node3D = null
	if actif and modele and is_instance_valid(modele):
		em = modele.find_child("Emetteur", true, false)
	if em == null:
		if point_laser:
			point_laser.visible = false
		return
	if point_laser == null:
		point_laser = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.012
		sm.height = 0.024
		point_laser.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1, 0.05, 0.02)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = Color(1, 0.05, 0.02)
		point_laser.material_override = m
		point_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		point_laser.top_level = true
		add_child(point_laser)
	# depuis la vue 1re personne, le laser part de l'œil dans l'axe du canon (l'arme est réduite à l'écran)
	var from: Vector3 = em.global_position
	var dir: Vector3 = -modele.global_basis.z.normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 80.0, Game.LAYER_WORLD | Game.LAYER_ZOMBIE, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	point_laser.visible = not hit.is_empty()
	if not hit.is_empty():
		point_laser.global_position = hit.position + hit.normal * 0.01
		var d := from.distance_to(hit.position)
		point_laser.scale = Vector3.ONE * clampf(d * 0.06, 0.4, 3.0)


## Lampe : celle montée sur l'arme si elle en a une, sinon la lampe torche.
func _update_lampes() -> void:
	var sur_arme: bool = arme_stats(current_weapon()).get("lampe", false)
	flashlight.visible = flashlight_on and not sur_arme
	for m in [hand_weapon]:
		if m and is_instance_valid(m):
			var l: Node3D = m.find_child("Lumiere", true, false)
			if l:
				l.visible = flashlight_on and sur_arme and m == hand_weapon


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
		w.damage = float(w.damage) * (1.0 + 0.05 * prog.rang("calibre")) * (1.1 if prog.a("combattant") else 1.0)
		if prog.a("sang_froid"):
			w.recoil = float(w.recoil) * 0.65
		if prog.a("tir_hanche"):
			w.dispersion_hanche = float(w.get("dispersion_hanche", 1.0)) * 0.7
		if prog.a("visee_stable"):
			w.dispersion_visee = float(w.get("dispersion_visee", 0.45)) * 0.75
		if prog.a("gachette"):
			w.rate = float(w.rate) * 0.87
		if prog.a("balistique"):
			w.range = float(w.range) * 1.25
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
	if hotbar_verrou[i] and hotbar[i] != "" and hotbar[i] != id:
		Game.msg("Case %d verrouillée (clic droit dessus dans l'inventaire pour la déverrouiller)." % (i + 1))
		return
	if id != "":
		var old := hotbar.find(id)
		if old >= 0:
			hotbar[old] = ""
			hotbar_verrou[old] = false
	elif hotbar_verrou[i]:
		hotbar_verrou[i] = false
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
	# la main droite va chercher l'arme là où elle était rangée (dos, cuisse, hanche)
	sortie_lieu = _lieu_arme(current_weapon())
	sortie_t = 0.0 if sortie_lieu != "" else -1.0
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
	if soin_t > 0.0:
		_maj_soin(delta)
		return
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			_finish_reload()
		return
	if current_weapon() == "arc":
		_maj_arc(delta, can_act)
		return
	if not can_act or placing != "" or cooldown > 0.0:
		return
	var id := current_weapon()
	var w := arme_stats(id)
	var held := Input.is_action_pressed("tirer")
	var wants: bool = fire_queued > 0.0 or (held and w.get("auto", false))
	if not wants:
		return
	fire_queued = 0.0
	if est_cassee(id):
		cooldown = 0.6
		Game.play_ui("clic_vide", -4.0)
		Game.msg("%s est cassé : répare-le (kit de réparation, clic droit dans l'inventaire)." % Items.nom(id))
		return
	if not (w.type == "lancer" and (w.has("leurre") or w.has("petards"))):
		rompre_tripes("attaque")   # lancer un leurre ne trahit pas le déguisement, frapper ou tirer si
	if w.type == "gun":
		_fire_gun(id, w)
	elif w.type == "lancer":
		_lancer(id, w)
	else:
		_melee(w)


## Distance entre la caméra (derrière l'épaule) et la tête : ajoutée aux portées des rayons de visée.
func recul_camera() -> float:
	return camera.global_position.distance_to(head.global_position)


## Dispersion du tir (degrés) : visée / hanche, déplacement, accroupi, tirs rapprochés (bloom).
func dispersion(w: Dictionary) -> float:
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	return float(w.get("spread", 0.0)) * (float(w.get("dispersion_visee", 0.45)) if aiming else float(w.get("dispersion_hanche", 1.0))) \
		* (1.6 if moving else 1.0) * (0.8 if crouching else 1.0) * (1.0 + bloom)


func _aim_point(max_range: float) -> Vector3:
	var from := camera.global_position
	var fwd := -camera.global_basis.z
	var to := from + fwd * (max_range + 0.5 + recul_camera())
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.LAYER_WORLD | Game.LAYER_ZOMBIE, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return to
	return hit.position


## Recul de la visée : le tangage du tir monte selon la famille (sec pour un pistolet, en douceur pour un
## fusil de précision), puis revient doucement au centre ; ce que le joueur a déjà compensé à la souris n'est pas rendu.
func _maj_recul_visee(delta: float) -> void:
	if recul_profil.is_empty():
		return
	recul_depuis += delta
	var avant := head.rotation.x
	if recul_a_venir > 0.0:
		var part := recul_a_venir * (1.0 - exp(-float(recul_profil.montee) * delta))
		if recul_a_venir < 0.0005:
			part = recul_a_venir
		recul_a_venir -= part
		head.rotation.x = clampf(head.rotation.x + part, -1.45, 1.45)
		recul_cumul += head.rotation.x - avant
	# retour au centre, aussi entre deux balles d'une rafale (la montée se stabilise : rafale contrôlable)
	if recul_cumul > 0.0 and recul_depuis > float(recul_profil.delai):
		var ret := minf(recul_cumul, maxf(recul_cumul * (1.0 - exp(-float(recul_profil.retour) * delta)), 0.01 * delta))
		recul_cumul -= ret
		head.rotation.x = clampf(head.rotation.x - ret, -1.45, 1.45)


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
		if not (prog.a("econome_balles") and randf() < 0.15):
			mags[id] = int(mags[id]) - 1
	user(id)
	cooldown = w.rate
	var origin := lean_pivot.global_position
	var aim := _aim_point(w.range)
	var spread := deg_to_rad(dispersion(w))
	bloom = minf(bloom + 0.3 * (0.6 if prog.a("maitrise_rafale") else 1.0), 1.2)
	var right := camera.global_basis.x.normalized()
	var up := camera.global_basis.y.normalized()
	var touche := false
	for i in int(w.pellets):
		var dir := (aim - origin).normalized()
		dir = dir.rotated(right, randf_range(-spread, spread)).rotated(up, randf_range(-spread, spread))
		if _shoot_ray(origin, origin + dir * float(w.range), float(w.damage), int(w.get("perforant", 0))):
			touche = true
	if touche:
		prog.gagner("combat", 2)   # XP de combat aussi avec les armes à feu
	# recul propre à la famille de l'arme : la visée monte (vite ou en douceur), puis revient au centre
	recul_profil = Items.RECUL_FAMILLE.get(w.get("famille", ""), Items.RECUL_FAMILLE.fusil)
	var rp: Dictionary = recul_profil
	recul_a_venir += float(w.recoil) * float(rp.haut)
	recul_depuis = 0.0
	rotate_y(randf_range(-1.0, 1.0) * float(w.recoil) * float(rp.lat))
	# recul visible de l'arme (moins fort en visée, l'épaule encaisse)
	var force := clampf(float(w.recoil) * 14.0, 0.3, 2.2) * (0.7 if aiming else 1.0)
	var omega := sqrt(float(rp.raideur)) * 1.5
	arme_rec_v += Vector3(float(rp.arme_rot), float(rp.arme_recul), randf_range(-0.3, 0.3) * float(rp.arme_rot)) * force * omega
	var sec := force * float(rp.secousse) * (0.55 if aiming else 1.0)
	rec_rvel += Vector3(2.6, randf_range(-0.5, 0.5), randf_range(-0.9, 0.9)) * sec
	muzzle_t = 0.05
	shoot_pose_t = 1.5
	_effets_tir(id, w)
	var hauteur: float = float(w.get("pitch", 1.0))
	if w.get("silencieux", false):
		Game.play_ui(w.get("sound", "tir_pistolet"), -16.0, 0.05, 1.6 * hauteur)
	else:
		Game.play_ui(w.get("sound", "tir_pistolet"), -3.0 + (3.0 if hauteur < 0.8 else 0.0), 0.05, hauteur)
	Game.make_noise(global_position, float(w.noise))


## Grenade : on la dégoupille, le bras part en arrière puis la lance.
var lancer_t := 0.0
const LANCER_DUREE := 0.55
const GOUPILLE_DUREE := 0.35        # main gauche qui arrache la goupille avant le lancer
var goupille_t := 0.0


func _lancer(id: String, _w: Dictionary) -> void:
	if count(id) <= 0:
		return
	var leurre: bool = _w.has("leurre")
	if leurre and crouching:
		# réveil / radio posé à ses pieds, à genoux (sans bruit de lancer)
		cooldown = 1.0
		geste("genou")
		get_tree().create_timer(0.5).timeout.connect(_relacher_grenade.bind(id, true))
		return
	cooldown = 1.0 + GOUPILLE_DUREE
	# 1) goupille arrachée de la main gauche (grenade), réveil remonté, mèche allumée… 2) lancer
	goupille_t = GOUPILLE_DUREE
	if not leurre and not _w.has("petards"):
		get_tree().create_timer(GOUPILLE_DUREE * 0.6).timeout.connect(func(): Game.play_ui("goupille", -4.0, 0.05))
	get_tree().create_timer(GOUPILLE_DUREE).timeout.connect(_jeter_grenade.bind(id))


func _jeter_grenade(id: String) -> void:
	goupille_t = 0.0
	if not alive or current_weapon() != id:
		return
	lancer_t = LANCER_DUREE
	if perso_ual:
		_p_anim("frappe2", 1.3, 0.6)
	get_tree().create_timer(0.3).timeout.connect(_relacher_grenade.bind(id))


func _relacher_grenade(id: String, pose := false) -> void:
	if not alive or count(id) <= 0 or current_weapon() != id:
		return
	if pose:
		remove_item(id, 1)
		var gp: RigidBody3D = Grenade.new()
		gp.preparer(id)
		gp.minuterie = 0.3
		get_parent().add_child(gp)
		gp.global_position = global_position - global_basis.z * 0.6 + Vector3.UP * 0.2
		if count(id) <= 0:
			_refresh_weapon_model()
		return
	remove_item(id, 1)
	var g: RigidBody3D = Grenade.new()
	g.preparer(id)
	if prog.a("grenadier"):
		g.degats *= 1.3
		g.rayon *= 1.3
	get_parent().add_child(g)
	var dir := -camera.global_basis.z
	g.global_position = head.global_position + dir * 0.6 + global_basis.x * 0.3
	g.linear_velocity = dir * (15.0 if not crouching else 10.0) + Vector3.UP * 2.5 + velocity
	g.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	Game.play_ui("vent_leger", -8.0, 0.1)
	Game.make_noise(global_position, 5.0)
	if count(id) <= 0:
		_refresh_weapon_model()


## Multiplicateur des dégâts au corps à corps donné par les talents (hors critique, enchaînement, adrénaline).
func mult_melee() -> float:
	return (1.25 if prog.a("coup_puissant") else 1.0) * (1.2 if prog.a("maitre_armes") else 1.0) \
		* (1.0 + 0.05 * prog.rang("force")) * (1.1 if prog.a("combattant") else 1.0)


## Multiplicateur du coût en endurance d'un coup au corps à corps.
func cout_melee() -> float:
	return (0.7 if prog.a("souffle") else 1.0) * (0.85 if prog.a("maitre_armes") else 1.0)


## Multiplicateur des dégâts d'une flèche bandée à k (0..1).
func mult_fleche(k: float) -> float:
	return (1.2 if prog.a("archer") else 1.0) * (1.5 if k >= 0.98 and prog.a("tir_mortel") else 1.0) * (1.0 + 0.06 * prog.rang("oeil_faucon"))


func _melee(w: Dictionary) -> void:
	var cost: float = w.stamina * cout_melee()
	var dmg: float = w.damage * mult_melee()
	coup_crit = prog.a("critique") and randf() < 0.2
	if coup_crit:
		dmg *= 2.0
	# à bout de souffle : coup moins fort, de façon progressive (60 % des dégâts à endurance nulle)
	if stamina < cost:
		dmg *= lerpf(0.6, 1.0, clampf(stamina / cost, 0.0, 1.0))
	_depenser_endurance(cost)
	var id := current_weapon()
	var maintenant := Time.get_ticks_msec() / 1000.0
	# enchaînement : un coup donné moins de 0,5 s après la fin du précédent passe au coup suivant (3 au plus)
	combo_n = (combo_n + 1) % 3 if maintenant - combo_fin < 0.5 else 0
	if combo_n == 2 and prog.a("enchainement"):
		dmg *= 1.4
	if id == "poings":
		cooldown = w.rate
		coup_gauche = not coup_gauche
		combo_fin = maintenant + float(w.rate)
		if combo_n == 2:
			_anim_corps("crochet", 0.5, 0.14, 0.45)   # 3e coup : crochet
		else:
			_anim_corps("coup_poing" if coup_gauche else "coup_poing2", 0.27, 0.12, 0.45)
		Game.play_ui("vent_leger", -10.0, 0.15)
		_porter_coup(w, dmg)
		return
	if id in LAMES and prog.a("lame_aiguisee"):
		dmg *= 1.2
	if _adrenaline():
		dmg *= 1.2
	# coup vers l'avant : léger recul de l'arme, frappe (dégâts à l'impact), retour ;
	# batte et machette alternent avec un balayage latéral
	coup_lateral = id in BALAYAGE and not coup_lateral
	var duree := _duree_coup(w)
	cooldown = maxf(float(w.rate), duree)
	melee_p = 0.0
	melee_frappe = false
	melee_degats = dmg
	charge_actif = Input.is_action_pressed("tirer")
	charge_t = 0.0
	melee_charge = 0.0
	# corps du personnage : coup de hache (armes lourdes), sinon frappes d'épée en alternance
	if float(w.get("weight", 1.0)) >= 1.5:
		combo_fin = maintenant + duree
		_anim_corps("hache", 0.17, IMPACT_COUP * duree, duree + 0.1)
	else:
		combo_fin = maintenant + duree
		if combo_n == 2:
			_anim_corps("estoc", 0.3, IMPACT_COUP * duree, duree + 0.1)   # 3e coup de l'enchaînement : estoc
		else:
			_anim_corps("frappe3" if (coup_lateral or combo_n == 1) else "frappe2", 0.5 if (coup_lateral or combo_n == 1) else 0.55, IMPACT_COUP * duree, duree + 0.1)


## Animation du corps calée sur le coup : la vitesse est choisie pour que le moment de l'impact
## de l'animation (impact_norm, en part de sa durée) tombe à t_impact secondes.
func _anim_corps(nom: String, impact_norm: float, t_impact: float, verrou: float) -> void:
	if pap == null or not pap.has_animation(nom):
		return
	var duree_anim := pap.get_animation(nom).length
	vitesse_coup = clampf(impact_norm * duree_anim / maxf(t_impact, 0.05), 0.3, 3.0)
	_p_anim(nom, vitesse_coup, verrou)


## Durée du coup de mêlée : les armes lourdes frappent plus lentement.
func _duree_coup(w: Dictionary) -> float:
	return 0.36 + 0.08 * float(w.get("weight", 1.0))


## Giclées de sang selon l'arme : les lames tranchent (gerbe projetée sur le côté du geste),
## les armes contondantes éclaboussent moins, sauf coup puissant ou batte cloutée.
func _sang_coup(id: String, pos: Vector3, dir: Vector3) -> void:
	if id in LAMES:
		var cote := global_basis.x * (-1.0 if coup_lateral else 1.0)
		var force := 1.3 * (1.4 if prog.a("lame_aiguisee") else 1.0)
		Effets.gerbe_sang(get_parent(), pos, (dir + cote * 0.8).normalized(), force)
		Effets.gerbe_sang(get_parent(), pos, dir, force * 0.6)
	elif id in CONTONDANTES:
		var force := 0.5 + 0.6 * melee_charge + (0.3 if id == "batte_cloutee" else 0.0)
		Effets.gerbe_sang(get_parent(), pos, (dir + Vector3.UP * 0.4).normalized(), force)


## Argent trouvé (corps, meubles) ou gagné en vendant.
func gagner_argent(n: int, silencieux := false) -> void:
	if n <= 0:
		return
	argent += n
	if not silencieux:
		Game.recu("argent", n)


## Talent Adrénaline : actif sous 25 % de santé.
func _adrenaline() -> bool:
	return prog.a("adrenaline") and health < prog.sante_max() * 0.25


## Le coup touche (rayon devant soi) ; les coups lourds repoussent le zombie.
func _porter_coup(w: Dictionary, dmg: float) -> void:
	var id := current_weapon()
	var origin := lean_pivot.global_position
	var aim := _aim_point(float(w.range) + 1.0)
	var dir := (aim - origin).normalized()
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * float(w.range), Game.LAYER_WORLD | Game.LAYER_ZOMBIE, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	# Grand balayage : le coup latéral traverse jusqu'à deux zombies
	var perforant := 1 if coup_lateral and prog.a("balayage") else 0
	Game.coup_critique = coup_crit
	var touche_coup := _shoot_ray(origin, origin + dir * float(w.range), dmg, perforant)
	Game.coup_critique = false
	if touche_coup:
		Game.make_noise(global_position, 7.0)
		prog.gagner("combat", 2)
		user(id)
		var lame: bool = id in LAMES
		# son d'impact : tranchant et aigu pour les lames, sourd et grave pour les armes contondantes
		if lame:
			Game.play_ui("coup", -6.0, 0.1, 1.35)
			Game.play_ui("impact", -9.0, 0.15, 1.2)
		elif id == "poings":
			Game.play_ui("coup", -4.0, 0.15)
		else:
			Game.play_ui("coup", -2.0, 0.1, 0.75)
			Game.play_ui("atterrissage", -8.0, 0.1, 0.8)
			if id == "batte_cloutee":
				Game.play_ui("impact_metal", -12.0, 0.15, 1.3)
		# secousse de la caméra : plus forte pour les armes lourdes
		secousse = maxf(secousse, clampf(0.35 + float(w.get("weight", 0.3)) * 0.35 + melee_charge * 0.5, 0.35, 1.3))
		if not hit.is_empty():
			_sang_coup(id, hit.position, dir)
		if not hit.is_empty() and hit.collider.has_method("repousser"):
			if melee_charge >= 0.95 and prog.a("brute") and hit.collider.has_method("renverser"):
				# Brute : coup puissant chargé à fond = zombie au sol
				hit.collider.repousser(dir, 7.0, 0.6)
				hit.collider.renverser(randf_range(3.0, 4.5))
			elif melee_charge > 0.4:
				# coup puissant : le zombie est projeté (et peut tomber)
				hit.collider.repousser(dir, 3.0 + 4.0 * melee_charge, 0.6 + 0.5 * melee_charge)
			elif float(w.get("weight", 0.0)) >= 1.5 or (id in CONTONDANTES and prog.a("frappeur")):
				hit.collider.repousser(dir, 3.0, 0.6)
	elif not hit.is_empty():
		# hache, pioche : coup porté à un arbre, un rocher ou une épave (récolte)
		if Game.recolte and Game.recolte.frapper(hit.position, dir, id, self):
			secousse = maxf(secousse, 0.45)
			user(id)
		else:
			Game.play_3d("impact_mur", hit.position, -6.0, 0.2, 20.0)


func _maj_melee(delta: float) -> void:
	if melee_p >= 1.0:
		return
	var id := current_weapon()
	var w := arme_stats(id)
	var duree := _duree_coup(w)
	var avant := melee_p
	var impact := IMPACT_COUP
	var avance := delta / duree * (1.0 + 0.4 * melee_charge)
	if charge_actif:
		var arme := ARME_COUP    # arme ramenée en arrière, tenue tant que le clic est maintenu
		if not Input.is_action_pressed("tirer") or Game.ui_open or not alive:
			charge_actif = false
			if charge_t >= CHARGE_MIN:
				_lacher_charge(w, duree)
			if pap:
				pap.speed_scale = vitesse_coup * (1.0 + 0.4 * melee_charge)   # le corps repart
				p_lock = (1.0 - melee_p) * duree + 0.1
		elif melee_p >= arme:
			melee_p = arme
			avance = 0.0
			charge_t += delta * (1.4 if prog.a("charge_rapide") else 1.0)
			cooldown = maxf(cooldown, 0.1)
			if pap:
				pap.speed_scale = 0.0   # le corps reste armé tant que le clic est maintenu
				p_lock = maxf(p_lock, 0.2)
	melee_p = minf(1.0, melee_p + avance)
	if avant < impact - 0.12 and melee_p >= impact - 0.12:
		Game.play_ui("vent_lourd" if float(w.get("weight", 0.0)) >= 1.5 else "vent_leger", -6.0, 0.12)
	if not melee_frappe and melee_p >= impact:
		melee_frappe = true
		if w.get("type", "") == "melee":
			_porter_coup(w, melee_degats)


## Coup puissant relâché : plus de dégâts, frappe plus rapide, plus d'endurance.
func _lacher_charge(w: Dictionary, duree: float) -> void:
	melee_charge = clampf((charge_t - CHARGE_MIN) / (CHARGE_MAX - CHARGE_MIN), 0.0, 1.0)
	melee_degats *= 1.0 + 1.2 * melee_charge
	_depenser_endurance(float(w.stamina) * 0.6 * melee_charge)
	cooldown = (1.0 - melee_p) * duree
	Game.play_ui("vent_lourd", -4.0, 0.1)


## Tir d'une balle (ou coup de mêlée). perforant : nombre de zombies supplémentaires traversés.
func _shoot_ray(from: Vector3, to: Vector3, dmg: float, perforant := 0) -> bool:
	var exclus: Array[RID] = [get_rid()]
	var depart := from
	var touche := false
	var arme_feu: bool = Items.info(current_weapon()).get("type", "") == "gun"
	for i in perforant + 1:
		var q := PhysicsRayQueryParameters3D.create(depart, to, Game.LAYER_WORLD | Game.LAYER_ZOMBIE, exclus)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return touche
		var col: Object = hit.collider
		if col.has_method("take_hit"):
			col.take_hit(dmg * pow(0.75, i), hit.position, global_position)
			Game.spawn_blood(hit.position, get_parent())
			Effets.gerbe_sang(get_parent(), hit.position, (to - from).normalized(), 1.0 if arme_feu else 0.6)
			if not arme_feu and current_weapon() != "poings":
				_salir_arme(current_weapon(), 0.17)
			Game.play_3d("impact", hit.position, -4.0, 0.2, 30.0)
			touche = true
			if not arme_feu:
				return true
			exclus.append(hit.rid)
			depart = hit.position
			continue
		# impact dans le décor (balles seulement, pas les coups de mêlée)
		if arme_feu:
			Effets.impact(get_parent(), hit.position, hit.normal, col is LootContainer)
		return touche
	return touche


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
	# arme prête : clic net (aigu) et compteur de munitions en vert un instant (HUD)
	Game.play_ui("culasse", -2.0, 0.03, 1.45)
	arme_prete_t = 0.8


## origine : point d'où vient le coup (balle d'un bandit, explosion) quand il n'y a pas d'attaquant au corps à corps.
func take_damage(amount: float, _from: Node = null, origine := Vector3.INF) -> void:
	if not alive:
		return
	if vehicule:   # au volant : la carrosserie prend l'essentiel des coups
		amount = vehicule.encaisser(amount)
	# roulade : les coups au corps à corps passent à côté pendant le milieu de la roulade
	if roulade_t > 0.15 and roulade_t < ROULADE_DUREE - 0.1 and _from is Node3D:
		return
	if amount > 0.0:
		preload("res://scripts/journal.gd").touche()   # journal : fin de la série sans dégâts
	# indicateur de direction des dégâts (HUD)
	var src: Vector3 = (_from as Node3D).global_position if _from is Node3D else origine
	if src != Vector3.INF:
		impacts_recus.append([src, 1.2])
		if impacts_recus.size() > 6:
			impacts_recus.pop_front()
		if corps_vivant:
			corps_vivant.coup(src, clampf(amount / 20.0, 0.3, 1.2))
	# parade réussie si l'attaquant est devant soi
	if bloque and _from is Node3D:
		var vers: Vector3 = (_from as Node3D).global_position - global_position
		vers.y = 0.0
		if vers.normalized().dot(-global_basis.z) > 0.25:
			if stamina >= 10.0:
				_depenser_endurance(6.0 if prog.a("parade_experte") else 12.0)
				amount *= 0.1 if prog.a("parade_experte") else 0.2
				Game.play_ui("parade", -2.0, 0.1)
				rec_rvel += Vector3(-2.0, 0.0, 1.0)
				if _from.has_method("repousser"):
					_from.repousser(vers.normalized(), 4.5, 0.9)
			else:
				amount *= 0.6
				Game.msg("Trop épuisé pour parer !")
	if Game.admin and Game.admin_invincible:
		hurt_flash = 0.3
		return
	var subi := amount * (1.0 - armor_total()) * (0.85 if prog.a("robuste") else 1.0) * (0.9 if prog.a("seconde_peau") else 1.0)
	_hurt(subi)
	_blessures_coup(subi, _from)
	if soin_t > 0.0 and soin_id in ["trousse", "attelle"]:
		soin_t = 0.0
		soin_entree = null
		Game.msg("Soin interrompu : tu as été touché !")
	arreter_fabrication("Fabrication interrompue : tu as été touché !")
	hurt_flash = 1.0
	Game.play_ui("douleur", -2.0, 0.15)


func _hurt(amount: float) -> void:
	health -= amount
	if amount >= 2.0 and alive:
		prog.gagner("survie", 1)
	if health <= 0.0 and alive and prog.a("increvable") and increvable_jour != Game.day:
		# Increvable : une fois par jour, on reste debout
		increvable_jour = Game.day
		health = 15.0
		Game.msg("Increvable : tu refuses de tomber !")
		return
	if health <= 0.0 and alive:
		health = 0.0
		_die()


func _die() -> void:
	alive = false
	# chute (deux variantes : côté gauche ou droit), les bras ne tiennent plus l'arme
	if perso_ual and pap:
		p_lock = 0.0
		_p_anim(["mort", "mort_miroir"].pick_random(), 1.0, 99.0)
		if bras_ik:
			bras_ik.active = false
		if corps_vivant:
			corps_vivant.active = false
		if pieds_ik:
			pieds_ik.active = false
	cancel_placement()
	var tw := create_tween()
	tw.tween_property(head, "position:y", 0.35, 0.8)
	tw.parallel().tween_property(lean_pivot, "rotation:z", 1.2, 0.8)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.player_died.emit()


# ================================================================ modèle d'arme
func _refresh_weapon_model() -> void:
	for c in hand.get_children():
		c.queue_free()
	hand_weapon = null
	if arc_modele and is_instance_valid(arc_modele):
		arc_modele.queue_free()
	arc_modele = null
	arc_tension = 0.0
	reload_t = 0.0
	var id := current_weapon()
	var w := Items.info(id)
	var col: Color = w.get("color", Color.GRAY)
	var length: float = w.get("len", 0.0)
	if muzzle_light.get_parent() != self:
		muzzle_light.get_parent().remove_child(muzzle_light)
		add_child(muzzle_light)
	if id == "arc":
		# arc construit par le code, dans la main gauche (le poing gauche du personnage)
		arc_modele = preload("res://scripts/arc.gd").new()
		var main_g: Node3D = modele.find_child("MainSimple_l", true, false)
		if main_g and bras_ik:
			main_g.add_child(arc_modele)
			arc_modele.transform = Transform3D(bras_ik._repere_main.get("_l", Basis.IDENTITY), bras_ik._centre_poing_g)
		else:
			hand.add_child(arc_modele)
			arc_modele.rotation = Vector3(0, PI / 2.0, 0)
		hand_weapon = arc_modele
		return
	if id == "poings":
		return
	# modèle 3D de l'arme, dans la main du personnage
	var hm := ModeleUtil.arme(id)
	if hm:
		hand.add_child(hm)
		Accessoires.habiller(hm, id, accessoires.get(id, {}), true)
		ModeleUtil.ombres(hm, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		_appliquer_sang.call_deferred()
		hand_weapon = hm
		if perso_ual and w.type != "gun":
			hm.rotation.x = deg_to_rad(80)   # manche dans le poing, tête de l'arme vers le haut
		if w.type == "gun":
			# lumière du tir au bout du canon
			remove_child(muzzle_light)
			hm.add_child(muzzle_light)
			muzzle_light.position = Vector3(Accessoires.points(id, hm).get("bouche", Vector3(0, 0.03, -length - 0.1)))
		return
	# pas de modèle : arme faite de boîtes
	var parts: Array = []
	if w.type == "gun":
		parts = [
			[Vector3(0, 0, -length / 2.0), Vector3(0.06, 0.1, length), col],
			[Vector3(0, -0.1, -0.02), Vector3(0.05, 0.14, 0.07), col.darkened(0.3)],
			[Vector3(0, 0.02, -length - 0.04), Vector3(0.03, 0.03, 0.1), Color(0.08, 0.08, 0.08)],
		]
		if length > 0.5:
			parts.append([Vector3(0, -0.02, 0.15), Vector3(0.06, 0.12, 0.3), col.darkened(0.2)])
	else:
		parts = [
			[Vector3(0, 0, 0), Vector3(0.04, 0.04, 0.22), Color(0.2, 0.15, 0.1)],
			[Vector3(0, 0.0, -0.11 - length / 2.0), Vector3(0.025, 0.07, length), col],
		]
	var tilt := 0.0 if w.type == "gun" else 0.9
	for p in parts:
		var pos: Vector3 = Vector3(p[0]).rotated(Vector3.RIGHT, tilt)
		_vm_box(hand, pos, p[1], p[2], true, tilt)


## Points de prise pour les bras : ceux du modèle, avec la poignée verticale si elle est montée.
func _geo_prise(id: String, modele: Node3D) -> Dictionary:
	var g := Accessoires.points(id, modele).duplicate()
	if accessoires.get(id, {}).has("poignee") and g.has("poignee"):
		g["L"] = Vector3(g.poignee) + Vector3(0, -0.035, 0.0)
		g["prise_l"] = "verticale"
	return g


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
	var to := from + fwd * (2.8 + recul_camera())
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.LAYER_WORLD | Game.LAYER_INTERACT | Game.LAYER_ZOMBIE, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_chercher_a_achever()
		return
	if global_position.distance_to(hit.position) > 3.2:
		_chercher_a_achever()
		return
	var col: Object = hit.collider
	if col and col.has_method("get_prompt"):
		var p: String = col.get_prompt()
		if p == "[F] Achever" and achevement_t > 0.0:
			p = ""
		if p != "":
			prompt = p
			if col.has_method("interact"):
				interact_target = col


func open_inventory() -> void:
	var ui := get_tree().get_first_node_in_group("inventory_ui")
	if ui:
		ui.open(null)


func open_storage(crate: Node) -> void:
	# geste : à genoux devant un tas au sol, un cadavre ou un meuble bas ; penché sur un meuble haut
	var bas: bool = crate.is_in_group("corpses") or crate.is_in_group("zombies") or crate.is_in_group("tas_sol") or float((crate.get("box_size") if crate.get("box_size") != null else Vector3.ONE).y) < 0.9
	geste("genou" if bas else "fouille")
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
		var empty := -1
		for i in 5:
			if hotbar[i] == "" and not hotbar_verrou[i]:
				empty = i
				break
		if empty >= 0:
			hotbar[empty] = id
			if empty == slot:
				_refresh_weapon_model()
	Game.recu(id, n - reste)
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
		if hotbar[i] != "" and count(hotbar[i]) <= 0 and not hotbar_verrou[i]:
			hotbar[i] = ""
			if i == slot:
				_refresh_weapon_model()


## Regroupe les piles incomplètes du même objet (les premières se remplissent, les vides disparaissent).
func regrouper_piles() -> void:
	var tout: Array = []
	for g in grilles():
		for e in g.entrees:
			if Items.stack(e.id) > 1:
				tout.append([g, e])
	for i in tout.size():
		var a: Dictionary = tout[i][1]
		var pile := Items.stack(a.id)
		for j in range(i + 1, tout.size()):
			if int(a.n) >= pile:
				break
			var b: Dictionary = tout[j][1]
			if b.id != a.id or int(b.n) <= 0:
				continue
			var k := mini(pile - int(a.n), int(b.n))
			Peremption.fusionner(a, b, k)
			a.n += k
			b.n -= k
	for t in tout:
		if int(t[1].n) <= 0:
			t[0].retirer_entree(t[1])


const ORDRE_TYPES := ["gun", "arc", "melee", "lancer", "ammo", "heal", "food", "drink", "armor", "accessoire", "outil", "placeable", "material"]


## Range tout l'inventaire (poches, gilet, sac) : mode "type" (armes, munitions, soins, nourriture…)
## ou "taille" (le plus encombrant d'abord). Les piles sont regroupées. Si tout ne rentre plus, rien ne bouge.
func trier_inventaire(mode: String) -> bool:
	regrouper_piles()
	var gs := grilles()
	var sauve: Array = []
	var tout: Array = []
	for g in gs:
		var l: Array = []
		for e in g.entrees:
			l.append([e, e.x, e.y, e.r, e.n])
			tout.append(e)
		sauve.append([g, g.entrees.duplicate(), l])
	var cle := func(e: Dictionary) -> Array:
		var rang := ORDRE_TYPES.find(Items.info(e.id).get("type", ""))
		if mode == "taille":
			var s := Items.size(e.id)
			return [-s.x * s.y, e.id]
		return [rang if rang >= 0 else 99, e.id, -int(e.n)]
	var aire := func(e: Dictionary) -> int:
		var s := Items.size(e.id)
		return s.x * s.y
	# d'abord l'ordre demandé, puis (si ça ne rentre pas) les plus gros objets d'abord
	for essai in 2:
		var liste := tout.duplicate()
		liste.sort_custom(func(a, b):
			if essai == 1 and aire.call(a) != aire.call(b):
				return aire.call(a) > aire.call(b)
			var ka: Array = cle.call(a)
			var kb: Array = cle.call(b)
			for i in ka.size():
				if ka[i] != kb[i]:
					return ka[i] < kb[i]
			return false)
		for g in gs:
			g.entrees.clear()
		var ok := true
		for e in liste:
			var place := false
			for g in gs:
				if g.ajouter_entree(e):
					place = true
					break
			if not place:
				ok = false
				break
		if ok:
			_check_hotbar()
			return true
	# échec : tout remettre comme avant
	for s in sauve:
		s[0].entrees = s[1]
		for l in s[2]:
			l[0].x = l[1]
			l[0].y = l[2]
			l[0].r = l[3]
			l[0].n = l[4]
	return false


## Dormir dans un lit (la nuit) jusqu'à 7 h : refusé si un zombie ou un bandit vivant est à moins de 30 m,
## ou si l'on a trop faim / soif. Faim et soif baissent deux fois moins vite qu'éveillé ; santé et endurance
## remontent.
const SOMMEIL_RAYON := 30.0


func dormir(lit: Node3D = null) -> void:
	if not Game.is_night():
		Game.msg("Tu n'as pas sommeil : on ne dort que la nuit (après 20 h 30).")
		return
	for g in ["zombies", "bandits"]:
		for z in get_tree().get_nodes_in_group(g):
			var mort := float(z.get("dead_t") if z.get("dead_t") != null else 0.0) > 0.0 or float(z.get("mort_t") if z.get("mort_t") != null else 0.0) > 0.0
			if not mort and (z as Node3D).global_position.distance_to(global_position) < SOMMEIL_RAYON:
				Game.msg("Impossible de dormir : il y a du danger tout près.")
				return
	if saignement > 0.0:
		Game.msg("Impossible de dormir en saignant : arrête d'abord le saignement (bandage) [H].")
		return
	if infection >= 60.0:
		Game.msg("Trop de fièvre pour dormir : prends des antibiotiques.")
		return
	var heures := fposmod(7.0 - Game.time_hours, 24.0)
	var faim_h := 0.045 * Game.DAY_SECONDS / 24.0 * 0.5 * prog.faim_mult()
	var soif_h := 0.07 * Game.DAY_SECONDS / 24.0 * 0.5 * prog.soif_mult()
	if hunger - faim_h * heures < 5.0 or thirst - soif_h * heures < 5.0:
		Game.msg("Tu as trop faim ou trop soif pour dormir : mange et bois d'abord.")
		return
	hunger -= faim_h * heures
	thirst -= soif_h * heures
	var s := heures * Game.DAY_SECONDS / 24.0     # secondes de jeu sautées
	var froid_avant := froid
	_passer_etats(s)
	# le froid gâche le repos : moitié moins de santé au-dessus de 50, rien au-dessus de 80
	var f := maxf(froid_avant, froid)
	var k_repos := 0.0 if (f > 80.0 or infection >= 30.0) else (0.5 if f > 50.0 else 1.0)
	health = minf(prog.sante_max(), health + (10.0 if prog.a("sommeil") else 5.0) * heures * k_repos)
	if k_repos < 1.0:
		Game.msg("Nuit agitée (%s) : tu récupères mal." % ("fièvre" if infection >= 30.0 else "froid"))
	if prog.a("sommeil"):
		stamina = prog.endurance_max()
	stamina = prog.endurance_max()
	if Game.time_hours >= 12.0:
		Game.day += 1      # couché avant minuit
	Game.time_hours = 7.0
	Peremption.avancer_tout(self)   # la nourriture se gâte aussi pendant la nuit
	if fab_n > 0:
		arreter_fabrication()
	hurt_flash = 0.0
	Game.play_ui("fouille", -10.0, 0.05, 0.7)
	Game.msg("Tu as dormi %d h. Jour %d, 07:00." % [roundi(heures), Game.day])
	if lit:
		geste("lit", lit)   # allongé un instant sur le lit, puis on se relève
	# pièges, lignes de pêche, séchoirs… avancent du temps dormi ; puis sauvegarde automatique
	get_tree().call_group("passe_temps", "passer_temps", s)
	get_tree().call_group("sauvegarde_auto", "sauvegarde_auto", "réveil")


## Temps sauté (sommeil) : morsure tirée, fièvre qui monte, intoxication qui passe, froid de la nuit.
func _passer_etats(s: float) -> void:
	var pas := 10.0
	var t := 0.0
	while t < s and alive:
		var d := minf(pas, s - t)
		_maj_blessures(d)
		if maladie > 0.0:
			maladie = maxf(0.0, maladie - d * (2.0 if prog.a("medecin") else 1.0))
		froid = clampf(froid + bilan_temperature() * d, 0.0, 100.0)
		t += d


## Verrouille / déverrouille une case de la barre rapide : verrouillée, elle garde son objet même
## quand on n'en a plus (il y revient quand on le reprend) et les nouvelles armes ne s'y rangent pas.
func basculer_verrou(i: int) -> void:
	hotbar_verrou[i] = not hotbar_verrou[i]
	Game.msg("Case %d %s." % [i + 1, "verrouillée" if hotbar_verrou[i] else "déverrouillée"])
	_check_hotbar()


# ---------------------------------------------------------------- ramassage automatique
var _ramasse_t := 0.0


## Munitions et flèches ramassées en passant dessus (option Game.ramassage_auto) :
## flèches plantées dans le décor et munitions des tas d'objets au sol, à moins de 1,6 m.
func _ramassage_auto(delta: float) -> void:
	_ramasse_t -= delta
	if _ramasse_t > 0.0 or not Game.ramassage_auto:
		return
	_ramasse_t = 0.25
	var pieds := global_position + Vector3(0, 0.5, 0)
	for f in get_tree().get_nodes_in_group("fleches_plantees"):
		if f.has_node("Ramassage") and (f as Node3D).global_position.distance_to(pieds) < 1.6:
			if add_item("fleche", 1) == 0:
				Game.play_ui("fouille", -12.0, 0.1, 1.5)
				f.queue_free()
	for c in get_tree().get_nodes_in_group("tas_sol"):
		if c.grille == null or c.has_meta("jete") or (c as Node3D).global_position.distance_to(global_position) > 1.6:
			continue
		var pris := false
		for e in c.grille.entrees.duplicate():
			if Items.info(e.id).get("type", "") != "ammo" and e.id != "fleche":
				continue
			var n := int(e.n)
			var reste := n
			for g in grilles():
				reste = g.ajouter(e.id, reste)
				if reste == 0:
					break
			if reste < n:
				pris = true
				Game.recu(e.id, n - reste)
			e.n = reste
			if reste <= 0:
				c.grille.retirer_entree(e)
		if pris:
			Game.play_ui("fouille", -10.0, 0.1, 1.4)
			if c.grille.vide():
				c.queue_free()


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
	if it.get("desinfecte", false):
		_commencer_soin(id)
		return
	match it.get("type", ""):
		"food", "drink":
			var p := _p_de(id)
			remove_item(id)
			_manger(id, p)
		"heal":
			_commencer_soin(id)
		"armor":
			var f := _find_entry(id)
			if not f.is_empty():
				equip_entry(f[1], f[0])
		"melee", "gun", "arc":
			var i := hotbar.find(id)
			if i < 0:
				i = hotbar.find("")
				if i < 0:
					i = slot
				hotbar[i] = id
			slot = -1
			_select_slot(i)
		"outil":
			constructeur.basculer()
		"placeable":
			start_placement(id)
		_:
			Game.msg("Cet objet sert à la fabrication.")


## Soins : [durée (s), santé rendue (-1 = au maximum)]. Rapide mais peu efficace, ou lent mais complet.
const SOINS := {"antidouleur": [0.5, 10.0], "bandage": [0.9, 15.0], "trousse": [3.5, -1.0], "medicament": [1.0, 5.0],
		"attelle": [4.0, 0.0], "antibiotiques": [1.0, 0.0], "alcool": [1.5, 0.0]}
var soin_t := 0.0                    # soin en cours (temps restant)
var soin_total := 1.0
var soin_id := ""
var soin_entree = null               # entrée d'inventaire utilisée (double-clic), sinon on prend dans le sac
var soin_grille = null


## Commence un soin (l'objet n'est consommé qu'à la fin ; la trousse est interrompue si on est touché).
func _commencer_soin(id: String, entree = null, grille = null) -> bool:
	if soin_t > 0.0:
		return false
	if health >= prog.sante_max() - 0.5 and not _soin_utile(id):
		Game.msg("Ta santé est déjà au maximum." if Items.info(id).get("type", "") == "heal" else "Pas de plaie à désinfecter.")
		return false
	var s: Array = SOINS.get(id, [0.8, float(Items.info(id).get("heal", 10.0))])
	soin_total = float(s[0]) * (0.75 if prog.a("soigneur") else 1.0) * (0.7 if prog.a("premiers_secours") else 1.0)
	soin_t = soin_total
	soin_id = id
	soin_entree = entree
	soin_grille = grille
	Game.play_ui("fouille", -10.0, 0.1, 1.3)
	return true


func _maj_soin(delta: float) -> void:
	soin_t -= delta
	if soin_t > 0.0:
		return
	soin_t = 0.0
	var s: Array = SOINS.get(soin_id, [0.8, float(Items.info(soin_id).get("heal", 10.0))])
	# consommer : l'entrée choisie dans l'inventaire si elle existe encore, sinon une unité du sac
	if soin_entree != null and soin_grille != null and int(soin_entree.get("n", 0)) > 0:
		soin_entree.n -= 1
		if soin_entree.n <= 0:
			soin_grille.retirer_entree(soin_entree)
		_check_hotbar()
	elif not remove_item(soin_id):
		return
	var gain: float = prog.sante_max() if float(s[1]) < 0.0 else float(s[1]) * (1.3 if prog.a("soigneur") else 1.0) * (1.2 if prog.a("herboriste") else 1.0)
	health = minf(prog.sante_max(), health + gain)
	prog.gagner("survie", 8)
	if not _soigner_etat(soin_id):
		Game.msg("Soigné avec : " + Items.nom(soin_id))
	if soin_id == "medicament" and maladie > 0.0:
		maladie = 0.0
		Game.msg("Les médicaments font effet : tu n'es plus malade.")
	soin_entree = null
	soin_grille = null


## Consomme une unité d'une entrée précise (nourriture, boisson, soin).
func consume_entry(e: Dictionary, g: Grille) -> bool:
	var it := Items.info(e.id)
	var t: String = it.get("type", "")
	if t == "heal" or it.get("desinfecte", false):
		return _commencer_soin(e.id, e, g)
	if t == "food" or t == "drink":
		_manger(e.id, float(e.get("p", 0.0)))
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
	pile.set_meta("jete", true)   # pas de ramassage automatique de ce qu'on vient de jeter
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
	return _station_proche("workbench")


func _station_proche(groupe: String) -> bool:
	for b in get_tree().get_nodes_in_group(groupe):
		var d: Vector3 = b.global_position - global_position
		if Vector2(d.x, d.z).length() < 3.5 and absf(d.y) < 3.0:
			return true
	return false


## Station de fabrication à portée : "" (à la main), "etabli", "feu" (feu de camp, brasero), "couture".
func near_station(st: String) -> bool:
	match st:
		"etabli":
			return near_bench()
		"feu":
			return _station_proche("feu_camp")
		"couture":
			return _station_proche("plan_couture")
	return true


func niveau_fabrication() -> int:
	return int(prog.comp["fabrication"].niv)


## Caisses de stockage posées par le joueur à moins de 12 m (et 6 m de hauteur) : la fabrication y puise
## les ingrédients qui manquent dans le sac. Liste gardée 0,5 s.
const RAYON_CAISSES := 12.0
var _caisses: Array = []
var _caisses_t := -1.0


func caisses_proches() -> Array:
	var t := Time.get_ticks_msec() / 1000.0
	if _caisses_t >= 0.0 and t - _caisses_t < 0.5:
		return _caisses
	_caisses_t = t
	_caisses = []
	for c in get_tree().get_nodes_in_group("conteneurs"):
		if not c.is_storage or c.is_in_group("tas_sol") or c.grille == null:
			continue
		var d: Vector3 = c.global_position - global_position
		if Vector2(d.x, d.z).length() < RAYON_CAISSES and absf(d.y) < 6.0:
			_caisses.append(c.grille)
	return _caisses


## Quantité disponible pour fabriquer : inventaire + caisses proches.
func compte_fab(id: String) -> int:
	var n := count(id)
	for g in caisses_proches():
		n += g.compter(id)
	return n


func compte_caisses(id: String) -> int:
	return compte_fab(id) - count(id)


## Retire n objets pour une fabrication : d'abord du sac, puis des caisses proches.
func _retirer_fab(id: String, n: int) -> void:
	var k := mini(n, count(id))
	if k > 0:
		remove_item(id, k)
	n -= k
	for g in caisses_proches():
		if n <= 0:
			break
		n -= g.enlever(id, n)


func a_ingredients(r: Dictionary, n := 1) -> bool:
	for id in r.needs:
		if compte_fab(id) < int(r.needs[id]) * n:
			return false
	return true


func can_craft(r: Dictionary) -> bool:
	return niveau_fabrication() >= int(r.get("niv", 0)) and near_station(str(r.get("station", ""))) and a_ingredients(r)


## Nombre d'exemplaires fabricables avec les ingrédients portés.
func max_craft(r: Dictionary) -> int:
	var n := 999
	for id in r.needs:
		n = mini(n, compte_fab(id) / maxi(1, int(r.needs[id])))
	return n


## Durée de fabrication d'un exemplaire : -5 % par niveau de fabrication.
func duree_fabrication(r: Dictionary) -> float:
	return float(r.get("duree", 3.0)) * maxf(0.5, 1.0 - 0.05 * niveau_fabrication()) * (0.75 if prog.a("artisan_rapide") else 1.0) * (1.0 - 0.08 * prog.rang("rendement")) \
		* (0.5 if prog.a("poudre_maison") and Items.info(r.out).get("type", "") == "ammo" else 1.0)


# fabrication en cours (en série) : un objet à la fois, ingrédients pris à la fin de chacun
var fab_r := {}
var fab_n := 0                      # exemplaires restants
var fab_total := 0
var fab_t := 0.0


## Démonte un lot de l'objet (qty de sa recette) : rend environ la moitié des ingrédients (Items.recette_demontage).
## `e` / `g` : entrée précise de l'inventaire (clic droit) ; sinon la première qui convient.
func demonter(id: String, e: Dictionary = {}, g: Grille = null) -> bool:
	var r := Items.recette_demontage(id)
	if r.is_empty():
		Game.msg("%s ne se démonte pas." % Items.nom(id))
		return false
	if not near_station(r.station):
		Game.msg("Pour démonter : %s à proximité." % Items.STATIONS[r.station])
		return false
	if fab_n > 0:
		Game.msg("Fabrication en cours.")
		return false
	var q := int(r.qty)
	var vide := func(x: Dictionary) -> bool: return x.contenu == null or (x.contenu as Grille).entrees.is_empty()
	if Items.grid(id).x > 0:
		# sac, gilet : une entrée par objet, qui doit être vide
		if e.is_empty():
			for gg in grilles():
				for x in gg.entrees:
					if x.id == id and vide.call(x):
						e = x
						g = gg
						break
				if not e.is_empty():
					break
		if e.is_empty() or g == null:
			Game.msg("Aucun %s vide à démonter." % Items.nom(id))
			return false
		if not vide.call(e):
			Game.msg("Vide d'abord %s." % Items.nom(id))
			return false
		g.retirer_entree(e)
	elif count(id) < q:
		Game.msg("Il en faut %d pour démonter (lot de fabrication)." % q)
		return false
	elif not e.is_empty() and g != null and int(e.n) >= q:
		if int(e.n) > q:
			e.n = int(e.n) - q
		else:
			g.retirer_entree(e)
	else:
		remove_item(id, q)
	_check_hotbar()
	var rendu: PackedStringArray = []
	for ing in r.needs:
		var x := minf(float(r.needs[ing]), float(r.needs[ing]) * Items.PART_DEMONTAGE * (1.5 if prog.a("recuperateur") else 1.0))
		var k := int(floor(x)) + (1 if randf() < x - floor(x) else 0)
		if k > 0:
			add_item(ing, k)
			rendu.append("%d× %s" % [k, Items.nom(ing)])
	Game.msg("Démonté : %s%s → %s" % [Items.nom(id), (" ×%d" % q) if q > 1 else "", ", ".join(rendu) if not rendu.is_empty() else "rien de récupérable"])
	Game.play_ui("fouille", -6.0, 0.1, 0.75)
	Game.play_ui("impact_metal", -14.0, 0.1, 1.2)
	return true


func lancer_fabrication(r: Dictionary, n: int) -> bool:
	if fab_n > 0 or n <= 0 or not can_craft(r):
		return false
	fab_r = r
	fab_n = n
	fab_total = n
	fab_t = 0.0
	Game.play_ui("fouille", -8.0, 0.1, 0.9)
	return true


func arreter_fabrication(raison := "") -> void:
	if fab_n > 0 and raison != "":
		Game.msg(raison)
	fab_n = 0
	fab_r = {}


## Progression de l'objet en cours (0..1), -1 si rien.
func progression_fabrication() -> float:
	return fab_t / duree_fabrication(fab_r) if fab_n > 0 else -1.0


func _maj_fabrication(delta: float) -> void:
	if fab_n <= 0:
		return
	if not can_craft(fab_r):
		arreter_fabrication("Fabrication interrompue : %s." % ("station trop loin" if not near_station(str(fab_r.get("station", ""))) else "il manque des ingrédients"))
		return
	fab_t += delta
	if fab_t < duree_fabrication(fab_r):
		return
	fab_t = 0.0
	craft(fab_r)
	fab_n -= 1
	if fab_n > 0:
		Game.play_ui("fouille", -8.0, 0.1, 0.9)
	else:
		fab_r = {}


func craft(r: Dictionary) -> bool:
	if not can_craft(r):
		return false
	var total := 0
	for id in r.needs:
		_retirer_fab(id, int(r.needs[id]))
		total += int(r.needs[id])
	var qty := int(r.qty)
	var munition: bool = Items.info(r.out).get("type", "") == "ammo"
	if munition and prog.a("cartoucherie"):
		qty = int(ceil(qty * 1.5))
	if munition and prog.a("armurier"):
		qty = int(ceil(qty * 1.25))
	if not munition and prog.a("maitre_artisan") and randf() < 0.5:
		qty *= 2
	var au_feu: bool = r.get("station", "") == "feu"
	if au_feu and not munition and prog.a("chef") and randf() < 0.5:
		qty += 1
	if r.get("cat", "") == "soins" and prog.a("chimiste") and randf() < 0.5:
		qty += 1
	if r.out == "cuir" and prog.a("tanneur"):
		qty += 1
	if r.out == "fleche" and prog.a("empenneur"):
		qty += 2
	add_item(r.out, qty)
	if prog.a("econome") and randf() < (0.5 if prog.a("ingeniosite") else 0.3):
		var ids: Array = r.needs.keys()
		var rendu: String = ids[randi() % ids.size()]
		add_item(rendu, 1)
		Game.msg("Économe : 1× %s récupéré." % Items.nom(rendu))
	Game.make_noise(global_position, 6.0)
	Game.msg("Fabriqué : %d× %s" % [qty, Items.nom(r.out)])
	preload("res://scripts/journal.gd").compter("fabriques", qty)   # journal du survivant
	preload("res://scripts/journal.gd").compter("fab:" + str(r.out), qty)
	prog.gagner("fabrication", 12 + total * 3)
	if au_feu:
		prog.gagner("chasse", 8)   # la cuisine au feu fait partie de la branche Chasse
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
	if placing == "construction":
		constructeur.nettoyer()
	placing = ""
	if ghost and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null


func _update_placement() -> void:
	if placing == "construction":
		constructeur.maj()
		return
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var fwd := -camera.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * (4.5 + recul_camera()), Game.LAYER_WORLD, [get_rid()])
	var hit := space.intersect_ray(q)
	var pt: Vector3 = from + fwd * (3.0 + recul_camera()) if hit.is_empty() else hit.position
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
	var refus: String = Placeable.refus_pose(placing, pt)
	if refus != "":
		ghost_valid = false
		ghost_reason = refus
	var sur_base: bool = not down.is_empty() and down.collider is Node and down.collider.is_in_group("construction")
	if not placing in POSE_DEHORS and not sur_base:
		var zone := Game.find_zone(pt + Vector3.UP * 0.5)
		if zone.is_empty():
			ghost_valid = false
			ghost_reason = "À placer dans un bâtiment ou sur le plancher de ta base."
		elif Game.zombies_in_zone(zone) > 0:
			ghost_valid = false
			ghost_reason = "Il reste %d zombie(s) dans ce bâtiment. Nettoie-le d'abord !" % Game.zombies_in_zone(zone)
	if ghost_valid:
		var sq := PhysicsShapeQueryParameters3D.new()
		var bs := BoxShape3D.new()
		bs.size = size - Vector3(0.1, 0.1, 0.1)
		sq.shape = bs
		sq.transform = Transform3D(Basis(Vector3.UP, ghost_rot), pt + Vector3(0, size.y / 2.0 + 0.04, 0))
		sq.collision_mask = Game.LAYER_PLAYER | Game.LAYER_ZOMBIE | (0 if placing in POSE_DEHORS else Game.LAYER_WORLD)
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
	elif placing == "frigo":
		obj = Placeable.creer_frigo()
	else:
		var p = Placeable.new()
		p.setup(placing)
		if prog.a("charpentier"):
			p.health *= 1.6
			p.health_max = p.health
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


## Vitesse de lecture d'une animation de déplacement : la cadence des pas suit la racine carrée de la vitesse
## (pas plus longs quand on va vite) et reste entre 0,7 et 1,4 fois la vitesse naturelle de l'animation.
func _cadence(hs: float, naturelle: float) -> float:
	return clampf(sqrt(hs / naturelle), 0.7, 1.4)


func _update_player_anim(delta: float) -> void:
	shoot_pose_t = maxf(0.0, shoot_pose_t - delta)
	if p_lock > 0.0:
		p_lock -= delta
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	var is_gun: bool = Items.info(current_weapon()).get("type", "") == "gun"
	if perso_ual:
		# vitesses naturelles des animations UAL : marche 0,94 m/s, jogging 2,4, sprint 3,1, accroupi 0,77
		# à reculons : la même animation jouée à l'envers (les hanches se tournent pour les pas de côté : _maj_corps)
		if _anim_geste(delta, hs):
			return
		var sens := -1.0 if marche_arriere else 1.0
		if sur_echelle:
			_p_anim("escalade", clampf(absf(velocity.y) / 1.6, 0.0, 1.3))
		elif nage:
			_p_anim("nage" if hs > 0.3 else "nage_place", _cadence(maxf(hs, 0.5), 0.9))
		elif not is_on_floor() and air_t > 0.35:
			_p_anim("saut_air")
		elif crouching:
			if hs > 0.3:
				_p_anim("accroupi_marche", _cadence(hs, 0.77) * sens)
			else:
				_p_anim("accroupi")
		elif hs > 4.6:
			_p_anim("course", _cadence(hs, 3.1))
		elif hs > 1.9:
			_p_anim("jogging", _cadence(hs, 2.4) * sens)
		elif hs > 0.3:
			_p_anim("marche", _cadence(hs, 0.94) * sens)
		elif bloque:
			_p_anim("parade")
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


# ================================================================ arc
## Tension tant que le clic gauche est maintenu, tir au relâchement (dégâts et vitesse selon la tension).
const ARC_TENSION_DUREE := 0.9
const Fleche = preload("res://scripts/fleche.gd")
var arc_tension := 0.0
var arc_vise := 0.0                 # 0 = arc baissé, 1 = levé en position de tir
var arc_plein_t := 0.0              # temps à pleine tension : le bras finit par trembler
var arc_modele: Node3D = null


func _maj_arc(delta: float, can_act: bool) -> void:
	if not can_act or placing != "":
		arc_tension = 0.0           # inventaire ouvert pendant la tension : on relâche sans tirer
		return
	var tient := Input.is_action_pressed("tirer") and cooldown <= 0.0
	if tient and arc_tension <= 0.0 and est_cassee("arc"):
		if fire_queued > 0.0:
			Game.msg("L'arc est cassé : répare-le (kit de réparation).")
			Game.play_ui("clic_vide", -8.0, 0.05, 0.6)
		fire_queued = 0.0
		return
	if tient and arc_tension <= 0.0 and count("fleche") <= 0 and not (Game.admin and Game.admin_munitions):
		if fire_queued > 0.0:
			Game.msg("Plus de flèches.")
			Game.play_ui("clic_vide", -8.0, 0.05, 0.6)
		fire_queued = 0.0
		return
	fire_queued = 0.0
	if tient:
		if arc_tension <= 0.0:
			Game.play_ui("fouille", -12.0, 0.05, 0.55)   # la corde grince
		arc_tension = minf(1.0, arc_tension + delta / (ARC_TENSION_DUREE * (0.65 if prog.a("tension_rapide") else 1.0)))
		if arc_tension >= 1.0:
			arc_plein_t += delta
			if arc_plein_t > 2.0:
				_depenser_endurance(6.0 * delta)
	elif arc_tension > 0.0:
		if arc_tension > 0.12:
			_tirer_fleche(arc_tension)
			cooldown = 0.45 * (0.6 if prog.a("fleches_serie") else 1.0)
		arc_tension = 0.0
		arc_plein_t = 0.0


func _tirer_fleche(k: float) -> void:
	rompre_tripes("attaque")
	if not (Game.admin and Game.admin_munitions):
		remove_item("fleche", 1)
	user("arc")
	var w := Items.info("arc")
	var origine := lean_pivot.global_position
	var vise := _aim_point(float(w.range))
	var dir := (vise - origine).normalized()
	# précision : meilleure bandé à fond, moins bonne en marchant ou quand le bras tremble
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	var ecart := deg_to_rad((0.35 + 1.4 * (1.0 - k)) * (1.8 if moving else 1.0) * (1.0 + clampf(arc_plein_t - 2.0, 0.0, 3.0) * 0.5) * (0.75 if prog.a("main_sure") else 1.0))
	dir = dir.rotated(camera.global_basis.x.normalized(), randf_range(-ecart, ecart)).rotated(Vector3.UP, randf_range(-ecart, ecart))
	var f = Fleche.new()
	var degats := float(w.damage) * (0.25 + 0.75 * k * k) * mult_fleche(k)
	f.tirer(self, origine + dir * 0.5, dir * lerpf(20.0, 62.0, k), degats)
	get_parent().add_child(f)
	Game.play_ui("vent_leger", -6.0, 0.1, 1.7)
	Game.play_ui("clic_vide", -10.0, 0.05, 0.45)   # claquement de la corde
	Game.make_noise(global_position, float(w.noise) * (0.25 if prog.a("silence") else 1.0))
	if count("fleche") <= 0 and not (Game.admin and Game.admin_munitions):
		Game.msg("Dernière flèche tirée.")


# ================================================================ maladie
## Intoxication (viande crue) : faim et soif baissent plus vite, endurance plafonnée, nausées
## (on vomit de temps en temps), santé qui s'effrite si on est affamé ou assoiffé. Guérit avec le temps
## ou avec des médicaments anti-nausée.
const MALADIE_DUREE := 300.0       # secondes
var maladie := 0.0                  # temps restant (0 = en bonne santé)
var nausee_t := 30.0


## Effets d'un aliment ou d'une boisson (nourriture crue : risque d'intoxication).
## p = péremption de la portion (1 = avariée : moitié moins nourrissante, risque d'intoxication ×2).
func _manger(id: String, p := 0.0) -> void:
	var it := Items.info(id)
	var k := (1.25 if prog.a("cuisinier") else 1.0) * (1.3 if prog.a("vivre_terre") and id in ["viande_cuite", "viande_sechee", "bouillon", "ragout"] else 1.0)
	var avarie := p >= 1.0
	if avarie:
		k *= 0.5
	hunger = minf(100.0, hunger + float(it.get("food", 0.0)) * k)
	thirst = minf(100.0, thirst + float(it.get("water", 0.0)) * k)
	prog.gagner("survie", 5)
	Game.msg("Consommé : " + Items.nom(id) + (" (avarié)" if avarie else ""))
	if id in BOUTEILLES and Items.DB.has("bouteille_vide"):
		add_item("bouteille_vide")   # la bouteille vide reste : on peut la remplir à un lac ou à la rivière
	if avarie:
		_risque_intoxication("Tu as mangé de la nourriture avariée", 2.0)
	elif it.get("cru", false) or it.get("sale", false):
		_risque_intoxication("Tu as bu de l'eau sale" if it.get("sale", false) else "Tu as mangé de la viande crue")


const BOUTEILLES := ["eau", "eau_sale", "soda"]
var _frais_t := 5.0   # péremption avancée toutes les 5 s (peremption.gd)


## Péremption de la première pile de cet objet dans l'inventaire (0 si aucune).
func _p_de(id: String) -> float:
	var gs := grilles()
	gs.reverse()   # même ordre que remove_item
	for g in gs:
		for e in g.entrees:
			if e.id == id:
				return float(e.get("p", 0.0))
	return 0.0


## Intoxication possible (viande crue, eau sale) : 50 % - 3 %/niveau de survie, moitié avec Estomac de fer.
func _risque_intoxication(cause: String, k := 1.0) -> void:
	var risque := maxf(0.2, 0.5 - 0.03 * int(prog.comp["survie"].niv)) * (0.5 if prog.a("estomac") else 1.0) * k
	if randf() < risque:
		var deja := maladie > 0.0
		maladie = minf(MALADIE_DUREE * 1.6, maladie + (120.0 if deja else MALADIE_DUREE))
		causes["maladie"] = cause
		nausee_t = randf_range(15.0, 30.0)
		Game.msg(cause + " : tu te sens malade (intoxication)." if not deja else "Ton intoxication s'aggrave.")
		Game.play_ui("douleur", -6.0, 0.1, 0.8)


func _maj_maladie(delta: float) -> void:
	if maladie <= 0.0:
		return
	maladie = maxf(0.0, maladie - delta * (2.0 if prog.a("medecin") else 1.0))
	hunger = maxf(0.0, hunger - delta * 0.04)
	thirst = maxf(0.0, thirst - delta * 0.06)
	stamina = minf(stamina, prog.endurance_max() * 0.6)
	if hunger < 25.0 or thirst < 25.0:
		_hurt(0.08 * delta)
	nausee_t -= delta
	if nausee_t <= 0.0:
		nausee_t = randf_range(40.0, 75.0)
		hunger = maxf(0.0, hunger - 10.0)
		thirst = maxf(0.0, thirst - 14.0)
		_depenser_endurance(25.0)
		secousse = maxf(secousse, 0.6)
		Game.play_ui("souffle", -2.0, 0.1, 0.6)
		Game.msg("Tu vomis… (intoxication)")
		Game.make_noise(global_position, 10.0)
	if maladie <= 0.0:
		Game.msg("Tu te sens mieux : l'intoxication est passée.")


## Équipement porté visible sur le personnage (casques, masques, sacs, gilets, vestes) et armes rangées
## (armes de la barre rapide qu'on ne tient pas) : refait quand ils changent.
func _maj_equipement_visible() -> void:
	if not perso_ual:
		return
	var tenue := current_weapon()
	var sig := ""
	for s in equipped:
		sig += str(equipped[s].get("id", "")) + "/"
	var rangees := []
	for id in hotbar:
		if id != "" and id != tenue and not id in rangees and Items.is_weapon(id) and count(id) > 0:
			rangees.append(id)
	sig += ",".join(rangees) + str(accessoires.hash())
	if sig == _sig_equip:
		return
	_sig_equip = sig
	var armes := []
	for id in rangees:
		var n: Node3D = preload("res://scripts/arc.gd").new() if id == "arc" else ModeleUtil.arme(id)
		if n == null:
			continue
		if id != "arc":
			Accessoires.habiller(n, id, accessoires.get(id, {}), false)
		armes.append([id, n])
	for c in modele.get_children():
		if c != hand and c.has_meta("modele"):
			EquipVisuel.appliquer(c, equipped)
			EquipVisuel.armes_rangees(c, armes)


## Profondeur de l'eau sous le joueur (m), 0 hors de l'eau.
func _profondeur_eau() -> float:
	if Game.relief == null or not Game.relief.dans_eau(global_position.x, global_position.z):
		return 0.0
	return maxf(0.0, SURFACE_EAU - Game.relief.hauteur(global_position.x, global_position.z))


## Corps vivant (scripts/corps_vivant.gd) : hanches vers la marche, penché dans les virages, regard,
## souffle, blessure, flexion à l'atterrissage.
func _maj_corps(delta: float) -> void:
	var cv = corps_vivant
	if cv == null:
		return
	var vl := global_basis.inverse() * velocity
	vl.y = 0.0
	var hs := vl.length()
	cv.vitesse = hs if is_on_floor() else 0.0
	var h := 0.0
	marche_arriere = false
	if hs > 0.3 and not sprinting and not sur_echelle and not nage and is_on_floor():
		var ang := atan2(-vl.x, -vl.z)       # 0 = droit devant, + = vers la gauche
		if absf(ang) > 1.95:
			marche_arriere = true
			ang = wrapf(ang + PI, -PI, PI)
		h = clampf(ang, -1.1, 1.1)
	cv.hanches_cible = h
	cv.pivot_actif = is_on_floor() and not sur_echelle and not nage and p_lock <= 0.0
	# virage en courant : le corps penche vers l'intérieur
	var yaw := global_rotation.y
	var vit_yaw := wrapf(yaw - yaw_prec, -PI, PI) / maxf(delta, 0.001)
	yaw_prec = yaw
	cv.inclinaison_cible = clampf(-vit_yaw * hs * 0.03, -0.28, 0.28) if (hs > 2.5 and is_on_floor()) else 0.0
	# regard : vers là où vise la caméra (l'arme tenue en joue s'en charge déjà : bras_ik)
	var en_joue := ads > 0.3 or arc_vise > 0.3
	cv.regard = Vector3.INF if (en_joue or sur_echelle) else camera.global_position - camera.global_basis.z * 25.0
	cv.souffle = clampf((0.45 - stamina / prog.endurance_max()) / 0.45, 0.0, 1.0)
	cv.blessure = maxf(clampf((0.35 - health / prog.sante_max()) / 0.35, 0.0, 1.0), 0.75 if fracture else 0.0)
	# gestes des bras : bandage pendant les soins, main sur le flanc quand on est gravement blessé
	# (sans arme à feu ni coup en cours), sortie de l'arme choisie
	var soin_bandage: bool = soin_t > 0.0 and soin_id in ["bandage", "trousse"]
	cv.bandage = move_toward(cv.bandage, 1.0 if soin_bandage else 0.0, delta * 4.0)
	var mains_libres: bool = Items.info(current_weapon()).get("type", "") != "gun" and p_lock <= 0.0 and cooldown <= 0.0 and not bloque
	cv.main_flanc = move_toward(cv.main_flanc, 1.0 if (cv.blessure > 0.45 and mains_libres and not soin_bandage) else 0.0, delta * 3.0)
	if sortie_t >= 0.0:
		sortie_t += delta
		cv.sortie = sortie_t / SORTIE_DUREE
		cv.sortie_lieu = sortie_lieu
		if hand_weapon and is_instance_valid(hand_weapon):
			hand_weapon.visible = cv.sortie > 0.5   # l'arme apparaît dans la main une fois saisie
		if sortie_t >= SORTIE_DUREE:
			sortie_t = -1.0
			cv.sortie = -1.0
			if hand_weapon and is_instance_valid(hand_weapon):
				hand_weapon.visible = true
	# atterrissage : jambes fléchies, d'autant plus que la chute était haute
	flex_t += delta
	if pieds_ik:
		var p := minf(flex_t / 0.5, 1.0)
		pieds_ik.flexion = flex_amp * sin(minf(p * 3.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.25, 1.0, p))


## Geste du personnage (animation tenue tant que l'action dure) : « fouille » (meuble haut),
## « genou » (fouille au sol, cadavre, meuble bas), « depecage », « ramasser », « lit » (couché, puis
## « lever »), « » = aucun. lit : le lit sur lequel s'allonger (geste « lit »).
func geste(nom: String, lit: Node3D = null) -> void:
	if not perso_ual or pap == null:
		return
	if geste_nom == "lit" or geste_nom == "lever":
		_quitter_lit()
	geste_nom = nom
	geste_t = 0.0
	p_lock = 0.0
	p_anim = ""
	if nom == "lit" and lit:
		lit_geste = lit
		if pieds_ik:
			pieds_ik.active = false
		# allongé sur le lit de camp, dans sa longueur (première image de « se relever » = couché sur le dos)
		modele.global_transform = Transform3D(lit.global_basis.orthonormalized() * Basis(Vector3.UP, PI / 2), lit.global_position + Vector3.UP * 0.38)


func _quitter_lit() -> void:
	lit_geste = null
	modele.transform = Transform3D.IDENTITY
	if pieds_ik and alive:
		pieds_ik.active = true


## Animation du geste en cours ; renvoie vrai s'il occupe le corps.
func _anim_geste(delta: float, hs: float) -> bool:
	if geste_nom == "":
		return false
	geste_t += delta
	var fini := false
	match geste_nom:
		"fouille", "genou":
			fini = geste_t > 0.5 and not Game.ui_open
		"depecage":
			fini = geste_t > 1.6
		"ramasser":
			fini = geste_t > 0.8
		"planter":
			fini = geste_t > 1.3
		"lit":
			fini = geste_t > 2.0
		"lever":
			fini = geste_t > 1.5
	if hs > 0.6 and geste_nom != "lit" and geste_nom != "lever":
		fini = true
	if fini:
		if geste_nom == "lit":
			geste_nom = "lever"
			geste_t = 0.0
		else:
			if geste_nom == "lever":
				_quitter_lit()
			geste_nom = ""
			return false
	match geste_nom:
		"fouille":
			_p_anim("fouiller", 0.9)
		"genou", "depecage":
			_p_anim("genou")
		"ramasser":
			_p_anim("recolter", 2.2)
		"planter":
			_p_anim("planter", 1.2)
		"lit":
			# couché : première image de « se relever », sans fondu (il ne progresserait pas à vitesse nulle)
			if p_anim != "relever":
				pap.play("relever", 0.0)
				p_anim = "relever"
			pap.speed_scale = 0.0
			pap.seek(0.0, true)
		"lever":
			_p_anim("relever", 1.1)
	return true


## Où l'arme est rangée sur le personnage (comme EquipVisuel.armes_rangees) : la main va l'y chercher.
func _lieu_arme(id: String) -> String:
	var it := Items.info(id)
	var t: String = it.get("type", "")
	if t == "gun" and it.get("famille", "") == "pistolet":
		return "cuisse"
	if t == "melee" and float(it.get("len", 0.0)) < 0.58:
		return "hanche"
	if t in ["gun", "melee", "arc"]:
		return "dos"
	return ""


## Roulade d'esquive (s'accroupir en plein sprint) : élan vers l'avant, coups évités pendant la
## partie centrale de la roulade (ROULADE_DUREE), endurance dépensée.
func _roulade() -> void:
	roulade_t = ROULADE_DUREE
	_depenser_endurance(6.0 if prog.a("acrobate") else 12.0)
	var duree_anim := pap.get_animation("roulade").length if pap.has_animation("roulade") else 1.0
	_p_anim("roulade", duree_anim / ROULADE_DUREE, ROULADE_DUREE)
	Game.play_ui("atterrissage", -10.0, 0.1)
	Game.make_noise(global_position, 6.0)


# ================================================================ blessures, eau, usure, température
## Blessures : saignement (secondes restantes, PV perdus peu à peu), morsure (risque d'infection tiré à la fin
## du délai pour désinfecter), infection (fièvre 0..100, antibiotiques), fracture (boiterie, attelle).
const SAIGNE_PV := 0.2               # PV perdus par seconde en saignant
const SAIGNE_MAX := 360.0
const MORSURE_DELAI := 60.0          # temps pour désinfecter la plaie à l'alcool
const CHUTE_DEGATS := -11.5          # vitesse à l'atterrissage au-delà de laquelle on se blesse (≈ 4,7 m)
var saignement := 0.0
var morsure_t := 0.0
var morsure_risque := 0.0
var plaie_desinfectee := false
var infection := 0.0
var fracture := false
var _palier_fievre := 0
var causes := {}                    # cause de chaque état (saignement, fracture, infection, maladie) pour l'écran État (etat_ui.gd)


func risque_saignement() -> float:
	return 0.5 if prog.a("seconde_peau") else 1.0


## Chance d'infection d'une morsure : 12 % - 0,4 %/niveau de survie.
func risque_morsure() -> float:
	return maxf(0.04, 0.12 - 0.004 * int(prog.comp["survie"].niv))


func _blessures_coup(subi: float, from: Node) -> void:
	if not alive or subi < 3.0 or from == null or (Game.admin and Game.admin_invincible):
		return
	var protege := 1.0 - armor_total()
	if from.is_in_group("zombies"):
		if str(from.get("kind")) in ["gros", "boss"] and subi >= 15.0 and randf() < 0.3:
			_casser("Le choc t'a brisé la jambe")
		if randf() < 0.3 * protege:
			_mordu()
			return
	if randf() < (0.25 if from.is_in_group("zombies") else 0.35) * protege * risque_saignement():
		causes["saignement"] = "coup de zombie" if from.is_in_group("zombies") else ("blessure par balle" if from.is_in_group("bandits") else "morsure ou coup d'un animal")
		_saigner(60.0 + subi * 2.0)


func _saigner(duree: float) -> void:
	if saignement <= 0.0:
		Game.msg("Tu saignes ! Un bandage ou une trousse arrête le saignement [H].")
	saignement = minf(SAIGNE_MAX, saignement + duree)


func _mordu() -> void:
	causes["saignement"] = "morsure de zombie"
	_saigner(90.0)
	morsure_risque = minf(0.5, (morsure_risque if morsure_t > 0.0 else 0.0) + risque_morsure())
	morsure_t = MORSURE_DELAI
	plaie_desinfectee = false
	Game.msg("Tu as été mordu ! Désinfecte la plaie à l'alcool dans la minute [H].")


func _casser(cause: String) -> void:
	if fracture:
		return
	fracture = true
	causes["fracture"] = cause
	secousse = maxf(secousse, 1.0)
	Game.play_ui("douleur", 0.0, 0.1, 0.85)
	Game.msg(cause + " : fracture ! Tu boites ; pose une attelle [H].")


func _chute(v: float) -> void:
	if Game.admin and Game.admin_invincible:
		return
	_hurt((v + CHUTE_DEGATS) * 7.0 + 6.0)
	hurt_flash = 1.0
	Game.play_ui("douleur", -2.0, 0.15)
	if v > 13.5 or randf() < (v + CHUTE_DEGATS) * 0.25:
		_casser("Mauvaise réception")


func _maj_blessures(delta: float) -> void:
	var sans_degats := Game.admin and Game.admin_invincible
	if saignement > 0.0:
		saignement = maxf(0.0, saignement - delta * (2.0 if prog.a("premiers_secours") else 1.0))
		if not sans_degats:
			_hurt(SAIGNE_PV * delta)
		if saignement <= 0.0:
			Game.msg("Le saignement s'est arrêté de lui-même.")
	if morsure_t > 0.0:
		morsure_t -= delta
		if morsure_t <= 0.0:
			morsure_t = 0.0
			if randf() < morsure_risque * (0.3 if plaie_desinfectee else 1.0):
				infection = 1.0
				causes["infection"] = "morsure de zombie non soignée"
				_palier_fievre = 0
				Game.msg("La morsure s'infecte : tu as de la fièvre. Il te faut des antibiotiques.")
			else:
				Game.msg("La morsure cicatrise sans s'infecter.")
				preload("res://scripts/journal.gd").compter("morsures_soignees")
			morsure_risque = 0.0
	if infection > 0.0:
		# la fièvre monte en ~18 min (deux fois moins vite avec Guérison)
		infection = minf(100.0, infection + delta * 0.09 * (0.5 if prog.a("medecin") else 1.0))
		var k := infection / 100.0
		thirst = maxf(0.0, thirst - delta * 0.05 * k)
		stamina = minf(stamina, prog.endurance_max() * (1.0 - 0.5 * k))
		if infection > 60.0 and not sans_degats:
			_hurt(delta * (0.05 + 0.2 * (infection - 60.0) / 40.0))
		var palier := int(infection / 30.0)
		if palier > _palier_fievre:
			_palier_fievre = palier
			Game.msg(["", "La fièvre monte…", "Forte fièvre : tu t'affaiblis, prends des antibiotiques !", "L'infection te ronge : antibiotiques, vite !"][mini(palier, 3)])


## Le soin sert-il à quelque chose de plus que la santé (blessure, maladie) ?
func _soin_utile(id: String) -> bool:
	var it := Items.info(id)
	match str(it.get("soigne", "")):
		"saignement":
			if saignement > 0.0:
				return true
		"fracture":
			if fracture:
				return true
		"infection":
			if infection > 0.0 or morsure_t > 0.0:
				return true
	if it.get("desinfecte", false) and morsure_t > 0.0 and not plaie_desinfectee:
		return true
	return id == "medicament" and maladie > 0.0


## Fin d'un soin : blessures soignées par l'objet. Vrai si un message a été donné.
func _soigner_etat(id: String) -> bool:
	var it := Items.info(id)
	var dit := false
	match str(it.get("soigne", "")):
		"saignement":
			if saignement > 0.0:
				saignement = 0.0
				Game.msg("Saignement arrêté (%s)." % Items.nom(id))
				dit = true
		"fracture":
			if fracture:
				fracture = false
				Game.msg("Attelle posée : ta jambe tient, tu marches de nouveau normalement.")
				dit = true
		"infection":
			if infection > 0.0 or morsure_t > 0.0:
				infection = 0.0
				morsure_t = 0.0
				morsure_risque = 0.0
				_palier_fievre = 0
				Game.msg("Les antibiotiques font effet : plus d'infection.")
				preload("res://scripts/journal.gd").compter("morsures_soignees")
				dit = true
	if it.get("desinfecte", false) and morsure_t > 0.0 and not plaie_desinfectee:
		plaie_desinfectee = true
		Game.msg("Plaie désinfectée : bien moins de risque d'infection.")
		dit = true
	return dit


## Soin choisi par [H] : d'abord la blessure la plus grave, puis la santé.
func _soin_conseille() -> String:
	var ordre: Array = []
	if fracture:
		ordre.append("attelle")
	var manque: float = prog.sante_max() - health
	if saignement > 0.0:
		ordre += ["trousse", "bandage"] if manque >= 45.0 else ["bandage", "trousse"]
	if infection > 0.0:
		ordre.append("antibiotiques")
	elif morsure_t > 0.0 and not plaie_desinfectee:
		ordre.append("alcool")
	if maladie > 0.0:
		ordre.append("medicament")
	if manque > 0.5:
		ordre += ["trousse", "bandage", "antidouleur"] if manque >= 45.0 else ["bandage", "antidouleur", "trousse"]
	for s in ordre:
		if Items.DB.has(s) and count(s) > 0:
			return s
	return ""


# --- eau des lacs et de la rivière : [F] pour boire, ou remplir une bouteille vide
var face_eau := false


func _maj_face_eau() -> void:
	face_eau = false
	if prompt != "" or placing != "" or Game.ui_open or not _devant_eau():
		return
	face_eau = true
	prompt = "[F] Remplir une bouteille (eau sale)" if count("bouteille_vide") > 0 and Items.DB.has("eau_sale") else "[F] Boire l'eau (pas potable)"


func _devant_eau() -> bool:
	for d in [0.0, 1.4]:
		var p: Vector3 = global_position - global_basis.z * d
		p.y = Game.hauteur(p.x, p.z)
		if Game.dans_eau(p):
			return true
	return false


func _puiser_eau() -> void:
	if count("bouteille_vide") > 0 and Items.DB.has("eau_sale"):
		remove_item("bouteille_vide")
		if add_item("eau_sale") > 0:
			drop_entry(nouvelle_entree("eau_sale"))
		Game.msg("Bouteille remplie d'eau sale (à faire bouillir au feu).")
	else:
		if thirst >= 99.0:
			Game.msg("Tu n'as pas soif.")
			return
		thirst = minf(100.0, thirst + 20.0)
		Game.msg("Tu bois l'eau à même le lac.")
		_risque_intoxication("L'eau n'était pas potable", 0.7)
	geste("genou")
	Game.play_ui("fouille", -8.0, 0.1, 0.7)


# --- usure : champ "durab" des armes et outils (absent = inusable), usure "us" rangée dans l'entrée d'inventaire
func durab_max(id: String) -> int:
	return int(Items.info(id).get("durab", 0))


## Entrée de l'arme (ou de l'outil) qu'on utilise : la première intacte de ce type, sinon la première.
func entree_usure(id: String) -> Dictionary:
	var m := durab_max(id)
	if m <= 0:
		return {}
	var premiere := {}
	for g in grilles():
		for e in g.entrees:
			if e.id == id:
				if float(e.get("us", 0.0)) < m:
					return e
				if premiere.is_empty():
					premiere = e
	return premiere


## État d'une entrée : 1 = neuve, 0 = cassée.
func etat_usure(e: Dictionary) -> float:
	var m := durab_max(e.get("id", ""))
	return 1.0 if m <= 0 else clampf(1.0 - float(e.get("us", 0.0)) / m, 0.0, 1.0)


func est_cassee(id: String) -> bool:
	var e := entree_usure(id)
	return not e.is_empty() and etat_usure(e) <= 0.0


func user(id: String, n := 1.0) -> void:
	if Game.admin:
		return
	var e := entree_usure(id)
	if e.is_empty() or etat_usure(e) <= 0.0:
		return
	var m := durab_max(id)
	var avant := float(e.get("us", 0.0))
	e["us"] = minf(float(m), avant + n * (0.7 if prog.a("bricoleur") else 1.0))
	if e.us >= m:
		Game.msg("%s : cassé ! Répare-le avec un kit de réparation (clic droit dans l'inventaire)." % Items.nom(id))
		Game.play_ui("impact_metal", -4.0, 0.1, 0.7)
	elif e.us >= m * 0.8 and avant < m * 0.8:
		Game.msg("%s : très usé." % Items.nom(id))


## Part de l'usure effacée par un kit de réparation (50 % + 3 %/niveau de fabrication, ×1,25 avec Bricoleur).
func part_reparation() -> float:
	return minf(1.0, (0.5 + 0.03 * niveau_fabrication()) * (1.25 if prog.a("bricoleur") else 1.0))


func reparer(e: Dictionary) -> bool:
	var m := durab_max(e.id)
	if m <= 0 or float(e.get("us", 0.0)) <= 0.0:
		Game.msg("Cet objet est en parfait état.")
		return false
	if count("kit_reparation") <= 0:
		Game.msg("Il faut un kit de réparation (établi : ruban + ferraille).")
		return false
	if Items.info(e.id).get("type", "") == "gun" and count("cle_molette") <= 0:
		Game.msg("Il faut aussi une clé à molette pour réparer une arme à feu.")
		return false
	remove_item("kit_reparation")
	e["us"] = maxf(0.0, float(e.us) - m * part_reparation())
	prog.gagner("fabrication", 6)
	Game.play_ui("fouille", -6.0, 0.1, 1.2)
	Game.msg("Réparé : %s (%d %%)." % [Items.nom(e.id), roundi(etat_usure(e) * 100.0)])
	return true


# --- température : froid de 0 (au chaud) à 100 (gelé)
var froid := 0.0
var pres_feu := false
var _froid_t := 0.0


func chaleur_portee() -> float:
	var c := 0.0
	for s in equipped:
		var e: Dictionary = equipped[s]
		if not e.is_empty():
			c += float(Items.info(e.id).get("chaleur", 0.0))
	return c


## Protection contre le froid (vêtements, Seconde peau, survie) : multiplie le refroidissement.
func protection_froid() -> float:
	return (1.0 - minf(0.75, chaleur_portee() * 0.5)) * (0.7 if prog.a("endurci") else 1.0) * (1.0 - 0.02 * int(prog.comp["survie"].niv))


## Variation du froid par seconde (+ = on se refroidit).
func bilan_temperature() -> float:
	var dehors := in_zone.is_empty()
	var c := 0.16 if Game.is_night() else 0.0
	if dehors:
		c += 0.2 * Game.pluie
	else:
		c *= 0.3
	if Game.dans_eau(global_position):
		c += 0.35 if nage else 0.15
	c *= protection_froid()
	var r := 0.0
	if dehors and not Game.is_night():
		r += 0.15 * (1.0 - Game.pluie)
	if not dehors:
		r += 0.12
	if pres_feu:
		r += 1.0
	if sprinting:
		r += 0.1
	return c - r


func _maj_temperature(delta: float) -> void:
	_froid_t -= delta
	if _froid_t <= 0.0:
		_froid_t = 0.5
		pres_feu = false
		for f in get_tree().get_nodes_in_group("feu_camp"):
			if f is Node3D and f.global_position.distance_squared_to(global_position) < 36.0:
				pres_feu = true
				break
	var avant := froid
	froid = clampf(froid + bilan_temperature() * delta, 0.0, 100.0)
	if froid > 50.0:
		stamina = minf(stamina, prog.endurance_max() * (0.7 if froid < 80.0 else 0.5))
	if froid > 80.0 and not (Game.admin and Game.admin_invincible):
		_hurt(delta * (0.02 + 0.08 * (froid - 80.0) / 20.0))
	if froid > 50.0 and avant <= 50.0:
		Game.msg("Tu as froid : trouve un abri, un feu ou des vêtements chauds.")
	elif froid > 80.0 and avant <= 80.0:
		Game.msg("Tu es transi de froid : ta santé baisse !")
	elif froid < 30.0 and avant >= 30.0:
		Game.msg("Tu te réchauffes.")


# ================================================================ déguisement de tripes
## Couvert des tripes d'un zombie (cadavre + lame, touche « ameliorer ») : zombie._think ne voit plus le joueur
## pendant TRIPES_DUREE s ; rompu en courant, en attaquant ou quand un zombie est touché tout près
## (zombie.take_hit), lavé plus vite sous la pluie ou dans l'eau. Sang visible : calque sang_perso (perso.gd).
const TRIPES_DUREE := 300.0
const TRIPES_LAMES := ["couteau_km2000", "machette", "hache"]
var tripes_t := 0.0
var _tripes_niveau := -1.0
var _tripes_maj := 0.0


func deguise() -> bool:
	return tripes_t > 0.0


func lame_tripes() -> String:
	for l in TRIPES_LAMES:
		if count(l) > 0:
			return l
	return ""


func se_couvrir_de_tripes(corps: Node) -> void:
	if not alive or not corps.is_in_group("corpses"):
		return
	if corps.has_meta("tripes"):
		Game.msg("Ce corps a déjà été vidé.")
		return
	if lame_tripes() == "":
		Game.msg("Il te faut une lame (couteau, machette, hache) pour ouvrir le corps.")
		return
	corps.set_meta("tripes", true)
	geste("genou")
	tripes_t = TRIPES_DUREE * (1.5 if prog.a("fantome") else 1.0)
	causes["tripes"] = "tripes de zombie"
	Effets.gerbe_sang(get_parent(), (corps as Node3D).global_position + Vector3.UP * 0.3, Vector3.UP, 1.0)
	Game.play_ui("impact", -6.0, 0.1, 0.6)
	# les zombies qui le poursuivaient perdent sa trace (ils cherchent encore là où il était)
	for z in get_tree().get_nodes_in_group("zombies"):
		if z.state == z.State.CHASE and z.proie == null and not z.assaut and global_position.distance_to(z.global_position) < 40.0:
			z.state = z.State.INVESTIGATE
			z.target = global_position
	Game.msg("Couvert de tripes : les zombies te prennent pour l'un des leurs tant que tu marches (ni course, ni attaque).")
	_appliquer_tripes()


func rompre_tripes(raison: String) -> void:
	if tripes_t <= 0.0:
		return
	tripes_t = 0.0
	Game.msg("Déguisement rompu (%s) : les zombies te voient de nouveau." % raison)
	_appliquer_tripes()


func _maj_tripes(delta: float) -> void:
	if tripes_t <= 0.0:
		return
	if sprinting and Vector2(velocity.x, velocity.z).length() > 3.5:
		rompre_tripes("tu as couru")
		return
	var lave := 1.0
	if Game.pluie > 0.1 and in_zone.is_empty():
		lave += 4.0 * Game.pluie   # forte pluie : ~1 min
	if Game.dans_eau(global_position):
		lave += 8.0
	tripes_t = maxf(0.0, tripes_t - delta * lave)
	if tripes_t <= 0.0:
		Game.msg("Les tripes ont séché ou ont été lavées : les zombies te voient de nouveau.")
	_tripes_maj -= delta
	if _tripes_maj <= 0.0 or tripes_t <= 0.0:
		_tripes_maj = 2.0   # (refait aussi après un changement d'équipement visible)
		_appliquer_tripes()


## Calque de sang sur le modèle du joueur (pas sur l'arme en main, qui a son propre sang).
func _appliquer_tripes() -> void:
	var niveau := 0.0 if tripes_t <= 0.0 else clampf(0.5 + 0.5 * tripes_t / TRIPES_DUREE, 0.0, 1.0)
	if niveau == 0.0 and _tripes_niveau == 0.0:
		return
	_tripes_niveau = niveau
	var mat: ShaderMaterial = Perso._materiau_sang()
	for mi in modele.find_children("*", "MeshInstance3D", true, false):
		if hand_weapon and is_instance_valid(hand_weapon) and (mi == hand_weapon or hand_weapon.is_ancestor_of(mi)):
			continue
		var m3: MeshInstance3D = mi
		if m3.material_overlay != null and m3.material_overlay != mat:
			continue
		m3.material_overlay = mat if niveau > 0.0 else null
		if niveau > 0.0:
			m3.set_instance_shader_parameter("sang", niveau)
			m3.set_instance_shader_parameter("graine", 3.7)
