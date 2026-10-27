extends CharacterBody3D
## Zombie : erre, entend les bruits, voit le joueur (moins bien la nuit),
## poursuit, attaque, passe par les portes des bâtiments, frappe les barricades.
## Une fois mort, le corps peut être fouillé.

enum State { WANDER, INVESTIGATE, CHASE, DEAD }

const LodAnim = preload("res://scripts/lod_anim.gd")
const GRAVITY := 14.0

var kind := "civil"
var health := 100.0
var armor := 0.0
var walk_speed := 1.1
var run_speed := 3.6
var damage := 10.0
var persistent := false     # gardiens / habitants : ne disparaissent pas
var home := Vector3.ZERO
var home_radius := 10.0

var state := State.WANDER
var target := Vector3.ZERO
var think_t := 0.0
var attack_t := 0.0
var lost_t := 0.0
var wander_t := 0.0
var stuck_t := 0.0
var detour_t := 0.0
var detour_dir := Vector3.ZERO
var lunge := 0.0
var dormant := false
var dormant_t := 0.0
var lod_loin := false         # loin du joueur et calme : logique allégée
var lod_n := randi() % 6        # loin et calme : compteur d'images physiques (une sur lod_pas)
var lod_pas := 1
var steer_t := 0.0
var steer_cache := Vector3.ZERO
var anim_acc := 0.0           # temps d'animation en attente (animation allégée au loin)
var anim_image := 0
var dead_t := 0.0
var searched := false
var groan_t := randf_range(1.0, 14.0)   # (décalé : pas tous les zombies à la fois au chargement)
var voix := 1.0          # hauteur de la voix de ce zombie (selon le type, un peu au hasard)
var douleur_cd := 0.0
var etait_chasse := false
var echelle := 1.0          # taille du modèle (le boss est un géant)
var est_boss := false
var charge_t := 0.0         # boss : temps de charge restant
var charge_cd := 6.0        # boss : délai avant la prochaine charge
var charge_dir := Vector3.ZERO
var charge_touche := false
var slam_cd := 4.0          # boss : délai avant le prochain coup au sol
var slam_t := -1.0          # boss : temps avant l'impact du coup au sol
var rampant := false        # rampe au sol (jambes arrachées ou zombie rampant)
var corps := Vector3.ONE    # proportions du modèle (gros zombie plus large)
var membres := {}           # dégâts reçus par membre (démembrement)
var coupes: Array = []      # os coupés
var demembre: Node = null
var aspect := {}            # apparence (couleurs des morceaux arrachés)
var squelette: Skeleton3D = null
var pieds_ik = null                 # pieds posés sur le sol (scripts/pieds_ik.gd)
var corps_v = null                  # regard, boiterie, coups selon le côté, bras levés avant l'attaque (scripts/corps_vivant.gd)
var prep_t := -1.0                  # préparation de l'attaque (bras levés) : temps écoulé, -1 = aucune
var prep_cible: Node3D = null
var relev_t := -1.0                 # relevé maladroit après avoir été renversé : temps écoulé
var allure := randf_range(0.82, 1.18)   # cadence propre à chaque zombie (démarches variées)
var a_terre := 0.0          # renversé : reste au sol, peut être achevé
var etourdi := 0.0          # repoussé par une parade ou un coup lourd : ne peut plus attaquer un instant
var ralenti_t := 0.0        # empêtré dans des barbelés / des piques
var ralenti_k := 1.0
var assaut := false         # membre d'une horde lancée contre la base du joueur
var assaut_pos := Vector3.ZERO
var voit_joueur := false
var proie: Node3D = null      # bandit pris en chasse (quand le joueur n'est pas en vue)

@onready var modele: Node3D = $Modele
var ap: AnimationPlayer = null      # animations du modèle Blender (si présent)
var anim_lock := 0.0                # durée pendant laquelle une animation ponctuelle joue
var cur_anim := ""
var anim_noms := {}                 # nom générique -> nom dans le modèle
const ANIMS_UAL := {"idle": "z_idle", "marche": "z_marche", "course": "course", "attaque": "z_attaque",
		"touche": "touche", "mort": "mort"}

const ModeleUtil = preload("res://scripts/modele_util.gd")
const Effets = preload("res://scripts/effets.gd")
const LootContainer = preload("res://scripts/loot_container.gd")
## Armes portées par certains zombies (visibles sur eux, elles tombent au sol à leur mort) : [id, poids]
const ARMES_ZOMBIES := {
	"militaire": [["m4a1", 4.0], ["ak74", 3.0], ["urgi", 2.0], ["lr300", 2.0], ["mcx", 2.0], ["m5_scw", 2.0], ["ak74m", 1.0], ["uar10", 1.0], ["mcx_spear", 1.0], ["mg5", 0.4]],
	"police": [["glock19", 5.0], ["mr920", 2.0], ["m45a1", 2.0], ["mp5k", 1.5], ["benelli_m4", 1.5]],
}
const CHANCE_ARME := {"militaire": 0.45, "police": 0.4}
var arme_portee := ""
var arme_noeud: Node3D = null
const MODELES := {"civil": "zombie_civil", "police": "zombie_policier", "militaire": "zombie_militaire", "patient": "zombie_patient"}
const TEINTES_CIVIL := [Color(0.45, 0.38, 0.3), Color(0.32, 0.36, 0.42), Color(0.5, 0.2, 0.18), Color(0.3, 0.38, 0.28), Color(0.55, 0.52, 0.45), Color(0.25, 0.25, 0.28)]


func setup(p_kind: String, p_persistent: bool, radius: float) -> void:
	kind = p_kind
	persistent = p_persistent
	home_radius = radius if radius > 0.0 else 12.0
	match kind:
		"police":
			health = 140.0
			armor = 0.25
			damage = 14.0
		"militaire":
			health = 190.0
			armor = 0.4
			damage = 16.0
			run_speed = 3.9
		"patient":
			health = 90.0
			run_speed = 3.3
		"coureur":
			health = 75.0
			damage = 8.0
			run_speed = 5.4
			corps = Vector3(0.92, 1.02, 0.92)
		"gros":
			health = 420.0
			armor = 0.15
			damage = 24.0
			run_speed = 2.5
			corps = Vector3(1.3, 1.07, 1.3)
		"rampant":
			health = 55.0
			damage = 9.0
			run_speed = 1.3
			rampant = true
		"boss":
			est_boss = true
			health = 2500.0
			armor = 0.3
			damage = 35.0
			run_speed = 3.4
			echelle = 1.8
	health *= Game.mult_pv()        # réglage de difficulté (game.gd)
	damage *= Game.mult_degats()
	voix = randf_range(0.92, 1.08) * float({"coureur": 1.16, "gros": 0.8, "rampant": 1.05, "patient": 1.04, "boss": 0.68}.get(kind, 1.0))
	if est_boss:
		walk_speed = 1.0
		return
	if Game.is_night() and randf() < 0.3 and kind != "gros" and not rampant:
		run_speed += 1.3  # coureurs nocturnes
	walk_speed = randf_range(0.8, 1.3)
	if kind == "gros":
		walk_speed = 0.6
	elif rampant:
		walk_speed = 0.45


func _ready() -> void:
	add_to_group("zombies")
	collision_layer = Game.LAYER_ZOMBIE
	collision_mask = Game.LAYER_WORLD | Game.LAYER_ZOMBIE | Game.LAYER_PLAYER
	home = global_position
	target = global_position
	rotation.y = randf() * TAU
	think_t = randf() * 0.3
	Game.noise_made.connect(_on_noise)
	_apply_look()
	_posture_zombie()
	if corps != Vector3.ONE:
		modele.scale = corps
		var cs0: CollisionShape3D = $Collision
		var cap0 := CapsuleShape3D.new()
		cap0.radius = 0.33 * corps.x
		cap0.height = 1.8 * corps.y
		cs0.shape = cap0
		cs0.position.y = 0.9 * corps.y
	if rampant:
		_mettre_au_sol()
	if est_boss:
		add_to_group("boss")
		modele.scale = Vector3.ONE * echelle
		var cs: CollisionShape3D = $Collision
		var cap := CapsuleShape3D.new()
		cap.radius = 0.33 * echelle
		cap.height = 1.8 * echelle
		cs.shape = cap
		cs.position.y = 0.9 * echelle


## Lieux dont les zombies portent la tenue du métier : nom du lieu -> [tenue, rayon (m), part des zombies].
const TENUES_LIEUX := {
	"Caserne de pompiers": ["pompier", 30.0, 0.8], "Hôpital": ["soignant", 45.0, 0.6], "Infirmerie de campagne": ["soignant", 25.0, 0.6],
	"Zone industrielle": ["ouvrier", 75.0, 0.75], "Prison": ["prisonnier", 70.0, 0.7], "Base militaire": ["soldat", 90.0, 0.9],
}


## Tenue imposée par le lieu où le zombie apparaît (pompier, soignant, ouvrier, prisonnier, soldat), sinon "".
func _tenue_du_lieu() -> String:
	if not kind in ["civil", "coureur", "patient", "militaire", "police"]:
		return ""
	var p := global_position
	for poi in Game.pois:
		var t: Array = TENUES_LIEUX.get(poi.name, [])
		if t.is_empty():
			continue
		var d := Vector2(p.x - poi.pos.x, p.z - poi.pos.z).length()
		if d < float(t[1]):
			# même tirage pour un même emplacement de départ
			var h := absi(hash(Vector2i(roundi(home.x / 3.0), roundi(home.z / 3.0)))) % 1000
			if t[0] == "soldat" and kind == "militaire" or h < int(float(t[2]) * 1000.0):
				return t[0]
	return ""


func _apply_look() -> void:
	var m: Node3D = null
	if Perso.disponible():
		# personnage réaliste (mannequin UAL habillé par perso.gdshader)
		aspect = Perso.apparence(kind)
		var metier := _tenue_du_lieu()
		if metier != "":
			Perso.tenue_metier(aspect, metier, RandomNumberGenerator.new())
		m = Perso.creer(aspect)
		anim_noms = ANIMS_UAL
	else:
		m = ModeleUtil.charger("res://modeles/%s.glb" % MODELES.get(kind, "zombie_civil"))
	if m:
		for c in modele.get_children():
			c.queue_free()
		modele.add_child(m)
		ModeleUtil.distance_visible(m, 160.0)
		if kind == "civil" and anim_noms.is_empty():
			ModeleUtil.teinter(m, "Haut", TEINTES_CIVIL[randi() % TEINTES_CIVIL.size()])
			ModeleUtil.teinter(m, "Manche", TEINTES_CIVIL[randi() % TEINTES_CIVIL.size()])
		ap = ModeleUtil.anim_player(m)
		squelette = ModeleUtil.squelette(m)
		if squelette and squelette.find_bone("foot_l") >= 0:
			# pieds posés sur le sol (seulement près du joueur : voir _physics_process)
			pieds_ik = preload("res://scripts/pieds_ik.gd").new()
			pieds_ik.corps = self
			pieds_ik.masque = Game.LAYER_WORLD
			pieds_ik.active = false
			squelette.add_child(pieds_ik)
			# chaque zombie a sa démarche : buste penché d'un côté, plus ou moins voûté
			pieds_ik.penche = randf_range(-0.22, 0.22)
			# corps vivant (avant les pieds) : tête vers le joueur, réactions aux coups, bras levés avant
			# de frapper ; un zombie sur trois boite (jambe raide, dos voûté), certains penchent d'un côté
			corps_v = preload("res://scripts/corps_vivant.gd").new()
			corps_v.corps = self
			corps_v.pieds = pieds_ik
			corps_v.active = false
			corps_v.pivot_actif = false
			corps_v.regard_max = 0.9
			if randf() < 0.33:
				corps_v.blessure = randf_range(0.5, 1.0)
			corps_v.inclinaison_cible = randf_range(-0.08, 0.08)
			squelette.add_child(corps_v)
			squelette.move_child(corps_v, pieds_ik.get_index())
		_armer()
		if ap:
			ModeleUtil.boucler(ap, ["idle", "marche", "course", "rampe"])
			ap.playback_default_blend_time = 0.2
			ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL   # avancée par _process (niveau de détail)
			if squelette:
				squelette.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL   # idem pour pieds, corps, posture
			_anim("idle")
			ap.seek(randf() * 2.0)
		return
	var clothes := Color(0.3, 0.32, 0.28).lerp(Color(0.45, 0.35, 0.3), randf())
	var skin := Color(0.45, 0.55, 0.4).lerp(Color(0.55, 0.55, 0.45), randf())
	match kind:
		"police":
			clothes = Color(0.12, 0.15, 0.3)
		"militaire":
			clothes = Color(0.25, 0.3, 0.18)
		"patient":
			clothes = Color(0.75, 0.8, 0.82)
	var mc := StandardMaterial3D.new()
	mc.albedo_color = clothes
	mc.roughness = 0.95
	var ms := StandardMaterial3D.new()
	ms.albedo_color = skin
	ms.roughness = 0.8
	$Modele/Corps.material_override = mc
	$Modele/Tete.material_override = ms
	$Modele/BrasG.material_override = ms
	$Modele/BrasD.material_override = ms
	if kind == "militaire" or kind == "police":
		var helmet := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.22
		sm.is_hemisphere = true
		helmet.mesh = sm
		var hm := StandardMaterial3D.new()
		hm.albedo_color = clothes.darkened(0.2)
		helmet.material_override = hm
		helmet.position = Vector3(0, 1.68, 0)
		modele.add_child(helmet)


## Arme en bandoulière dans le dos (fusils) ou dans l'étui à la hanche (pistolets).
func _armer() -> void:
	if squelette == null or est_boss or not CHANCE_ARME.has(kind) or randf() > float(CHANCE_ARME[kind]):
		return
	var liste: Array = ARMES_ZOMBIES[kind]
	var total := 0.0
	for e in liste:
		total += float(e[1])
	var tirage := randf() * total
	for e in liste:
		tirage -= float(e[1])
		if tirage <= 0.0:
			arme_portee = e[0]
			break
	var m := ModeleUtil.arme(arme_portee)
	if m == null:
		arme_portee = ""
		return
	var longue: bool = float(Items.info(arme_portee).get("len", 0.3)) >= 0.4
	var ba := BoneAttachment3D.new()
	ba.bone_name = "spine_03" if longue else "pelvis"
	squelette.add_child(ba)
	ba.add_child(m)
	if longue:
		# en travers du dos, canon vers le haut, dessus de l'arme tourné vers l'extérieur
		m.transform = Transform3D(_base_arme(Vector3(0.45, 0.89, 0.0), Vector3(0, 0, -1)), Vector3(-0.1, -0.3, -0.17))
	else:
		# dans l'étui à la hanche droite, canon vers le bas
		m.transform = Transform3D(_base_arme(Vector3(0, -1, 0.15), Vector3(0, 0, 1)), Vector3(-0.19, 0.0, 0.02))
	ModeleUtil.distance_visible(m, 70.0)
	arme_noeud = m


static func _base_arme(canon: Vector3, dessus: Vector3) -> Basis:
	var z := -canon.normalized()
	var y := (dessus - z * dessus.dot(z)).normalized()
	return Basis(y.cross(z), y, z)


## À la mort : l'arme portée tombe au sol à côté du corps (on peut la ramasser avec quelques munitions).
func _lacher_arme() -> void:
	if arme_noeud == null or not is_instance_valid(arme_noeud) or arme_portee == "":
		return
	var pile = LootContainer.new()
	pile.setup("Arme au sol", "", Vector3(0.7, 0.12, 0.7), Color(0.3, 0.3, 0.3))
	pile.make_storage(6, 4)
	pile.add_to_group("tas_sol")
	get_parent().add_child(pile)
	pile.global_position = global_position + global_basis.x * 0.7
	pile.rotation.y = randf() * TAU
	pile.grille.ajouter_entree({"id": arme_portee, "n": 1, "x": 0, "y": 0, "r": false, "contenu": null})
	var mun := str(Items.info(arme_portee).get("ammo", ""))
	if mun != "" and randf() < 0.7:
		pile.grille.ajouter(mun, randi_range(4, int(Items.info(arme_portee).get("mag", 10))))
	pile.mesh_i.visible = false
	arme_noeud.queue_free()   # l'arme est montrée au sol par le tas (LootContainer.maj_visuel_tas)
	arme_noeud = null
	arme_portee = ""
	Game.play_3d("chargeur_sol", pile.global_position, -4.0, 0.15, 15.0)


# ================================================================ boucle
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_dead_process(delta)
		return
	var p = Game.player
	# renversé : immobile au sol jusqu'à ce qu'il se relève
	if a_terre > 0.0:
		a_terre -= delta
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		if ap:
			ap.active = true
			anim_lock = maxf(anim_lock - delta, 0.0)
		if a_terre <= 0.0:
			_se_relever()
		return
	# endormi si loin du joueur (économise le processeur)
	if dormant:
		dormant_t -= delta
		if dormant_t > 0.0:
			return
		dormant_t = 1.0
	var dist := 9999.0
	if p:
		dist = global_position.distance_to(p.global_position)
	dormant = dist > 90.0 and state == State.WANDER   # (un bruit lointain — pétards, explosion — réveille aussi les zombies loin du joueur)
	LodAnim.ombres(modele, dist < LodAnim.OMBRE_DIST)
	if pieds_ik:
		pieds_ik.active = dist < 22.0 and state != State.DEAD and not rampant
	if corps_v:
		corps_v.active = pieds_ik.active
		corps_v.vitesse = Vector2(velocity.x, velocity.z).length()
		var regarde: bool = state == State.CHASE and p != null and dist < 15.0
		corps_v.regard = (p.global_position + Vector3.UP * 1.6) if regarde else Vector3.INF
	if ap:
		ap.active = not dormant
	if dormant:
		return
	# niveau de détail : au-delà de 35 m et sans poursuite, logique allégée
	lod_loin = dist > 35.0 and state != State.CHASE
	# loin et calme : une image physique sur 2 (sur 3 au-delà de 60 m), pas de temps multiplié d'autant
	lod_pas = 1
	if lod_loin:
		lod_n += 1
		var pas := 3 if dist > 60.0 else 2
		if lod_n % pas != 0:
			return
		lod_pas = pas
		delta *= pas
	steer_t -= delta
	# immobile, posé au sol, rien à faire : pas de calcul de déplacement cette image
	if lod_loin and is_on_floor() and Vector2(velocity.x, velocity.z).length() < 0.05 and _flat_dist(target, global_position) < 0.7:
		think_t -= delta
		if think_t <= 0.0:
			think_t = 0.25
			_think()
		return
	think_t -= delta
	if think_t <= 0.0:
		think_t = 0.25
		_think()
	var raw := _raw_target()
	var goal := _route(raw)
	var routed := not goal.is_equal_approx(raw)
	var speed := run_speed if state == State.CHASE else walk_speed
	if etourdi > 0.0:
		speed *= 0.15
	if ralenti_t > 0.0:
		ralenti_t -= delta
		speed *= ralenti_k
	if charge_t > 0.0 or slam_t >= 0.0:
		goal = global_position + charge_dir * 3.0
		routed = false
		speed = 9.0 if charge_t > 0.0 else 0.0
	var desired := Vector3.ZERO
	var to_goal := goal - global_position
	to_goal.y = 0.0
	var stop_dist := 1.1 if state == State.CHASE else 0.6
	if routed:
		stop_dist = 0.05
	if to_goal.length() > stop_dist:
		# loin et calme : la direction (rayons contre les obstacles) est recalculée moins souvent
		if lod_loin and steer_t > 0.0:
			desired = steer_cache
		else:
			desired = _steer(to_goal.normalized(), delta)
			steer_cache = desired
			steer_t = 0.2
	if Game.dans_eau(global_position):
		speed *= 0.6
	var accel := 30.0 if charge_t > 0.0 else 10.0
	velocity.x = move_toward(velocity.x, desired.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, desired.z * speed, accel * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var face := desired if desired.length() > 0.1 else to_goal
	if face.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 7.0 * delta)
	if lod_pas > 1:
		velocity *= lod_pas   # move_and_slide avance d'un pas physique : vitesse multipliée pour les images sautées
		move_and_slide()
		velocity /= lod_pas
	else:
		move_and_slide()
	# coincé ?
	if desired.length() > 0.1 and Vector2(velocity.x, velocity.z).length() < 0.25:
		stuck_t += delta
		if stuck_t > 0.8:
			stuck_t = 0.0
			detour_dir = desired.rotated(Vector3.UP, randf_range(1.2, 2.0) * (1.0 if randf() < 0.5 else -1.0))
			detour_t = 1.0
	else:
		stuck_t = 0.0
	# attaque
	attack_t -= delta
	lunge = move_toward(lunge, 0.0, delta * 3.0)
	if ap:
		_update_anim(delta)
	else:
		modele.rotation.x = -lunge * 0.5
	if etourdi > 0.0:
		etourdi -= delta
		attack_t = maxf(attack_t, 0.3)
	if est_boss:
		_boss_update(delta, p)
	# attaque en deux temps : bras levés (préparation visible, PREP_ATTAQUE), puis la frappe, qui ne
	# touche que si la cible est encore à portée (on peut reculer ou rouler pour l'éviter)
	if prep_t >= 0.0:
		prep_t += delta
		if corps_v:
			corps_v.bras_leves = 0.0 if rampant else smoothstep(0.0, _duree_prep() * 0.8, prep_t)
		if etourdi > 0.0 or state != State.CHASE:
			_finir_prep()
		elif prep_t >= _duree_prep():
			_frapper()
	elif state == State.CHASE and p and p.alive:
		var flat := _distance_cible(p)
		if flat < 1.5 * (1.6 if est_boss else 1.0) and absf(p.global_position.y - global_position.y) < 1.5 * echelle and attack_t <= 0.0 and charge_t <= 0.0 and slam_t < 0.0:
			_preparer(p)
	# attaque d'un bandit
	if prep_t < 0.0 and state == State.CHASE and proie and is_instance_valid(proie) and proie.state != 3:
		var fb := Vector2(proie.global_position.x - global_position.x, proie.global_position.z - global_position.z).length()
		if fb < 1.5 * (1.6 if est_boss else 1.0) and attack_t <= 0.0 and charge_t <= 0.0 and slam_t < 0.0:
			_preparer(proie)
	# bruit de grognement (attire les autres de près)
	groan_t -= delta
	douleur_cd -= delta
	var chasse := state == State.CHASE
	if chasse and not etait_chasse and dist < 60.0:
		# cri en se lançant à la poursuite
		_voix("cri", 0.0, 60.0)
		groan_t = maxf(groan_t, randf_range(1.5, 3.0))
	etait_chasse = chasse
	if groan_t <= 0.0:
		groan_t = randf_range(6.0, 14.0) if not chasse else (randf_range(1.6, 3.2) if kind == "coureur" else randf_range(2.5, 5.0))
		if dist < 45.0:
			if not chasse:
				_voix("grogne", -8.0, 40.0)
			elif kind == "coureur" and randf() < 0.6:
				_voix("coureur", -3.0, 45.0)   # râle haletant
			else:
				_voix("cri" if randf() < 0.35 else "grogne", -3.0, 45.0)
		if state == State.CHASE:
			Game.make_noise(global_position, 10.0)


func _think() -> void:
	var p = Game.player
	if p == null or not p.alive or (Game.admin and Game.admin_invisible):
		if _chercher_proie(20.0):
			state = State.CHASE
			return
		if assaut:
			# horde : la base est attaquée même sans joueur à voir (mort, admin invisible)
			voit_joueur = false
			state = State.CHASE
			target = assaut_pos
			return
		if state == State.CHASE:
			state = State.WANDER
		_wander_update()
		return
	var to_p: Vector3 = p.global_position - global_position
	var dist := to_p.length()
	# vue : réduite la nuit (sauf lampe allumée), accroupi, caché dans un buisson
	var sight := 24.0
	if Game.is_night():
		sight = 8.0 + (12.0 if p.flashlight_on else 0.0)
	if p.crouching:
		sight *= 0.3 if p.prog.a("ombre") else 0.5
	if p.get("cache_buisson"):
		sight *= 0.45
	if p.prog.a("discret"):
		sight *= 0.7
	if not p.in_zone.is_empty() and not is_same(p.in_zone, Game.find_zone(global_position + Vector3.UP)):
		sight *= 0.6
	var sees := false
	# déguisé de tripes (player.tripes_t) : pris pour un des leurs, pas vu (la course et les coups rompent le déguisement)
	if dist < sight and not p.deguise():
		var fwd := -global_basis.z
		# accroupi : il faut être bien devant le zombie, et plus près, pour qu'il le remarque
		var facing := fwd.dot(to_p.normalized()) > (0.45 if p.crouching else 0.1)
		if dist < (1.8 if p.crouching else 3.0) or facing or state == State.CHASE:
			sees = _line_of_sight(p)
	voit_joueur = sees
	if sees:
		proie = null
	elif _chercher_proie(sight):
		# pas de joueur en vue : un bandit fera l'affaire
		state = State.CHASE
		lost_t = 0.0
		return
	if assaut and not sees:
		# horde : marche sur la base du joueur et tape dans ce qui bloque le passage
		state = State.CHASE
		target = assaut_pos
		lost_t = 0.0
		return
	if sees:
		state = State.CHASE
		target = p.global_position
		lost_t = 0.0
	elif state == State.CHASE:
		lost_t += 0.25
		if lost_t > 4.0 or (p.deguise() and proie == null):
			state = State.INVESTIGATE
	elif state == State.INVESTIGATE:
		if _frapper_leurre():
			return
		if Vector2(target.x - global_position.x, target.z - global_position.z).length() < 1.5 and absf(target.y - global_position.y) < 1.5:
			state = State.WANDER
			wander_t = randf_range(3.0, 8.0)
	else:
		_wander_update()


func _wander_update() -> void:
	wander_t -= 0.25
	if wander_t <= 0.0:
		wander_t = randf_range(4.0, 12.0)
		if randf() < 0.4:
			target = global_position  # reste sur place
		else:
			var r := home_radius
			target = home + Vector3(randf_range(-r, r), 0, randf_range(-r, r))
			# les habitants restent dans leur bâtiment
			var hz := Game.find_zone(home + Vector3.UP * 0.5)
			if not hz.is_empty():
				var ab: AABB = hz.aabb
				target.x = clampf(target.x, ab.position.x + 0.6, ab.end.x - 0.6)
				target.z = clampf(target.z, ab.position.z + 0.6, ab.end.z - 0.6)


func _line_of_sight(p: Node3D) -> bool:
	var from := global_position + Vector3.UP * 1.6
	var to := p.global_position + Vector3.UP * 1.3
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.LAYER_WORLD, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


var leurre_vise: Node3D = null   # leurre qu'il est en train de frapper (_frapper_leurre)


## Leurre qui sonne (réveil, radio : grenade.gd, groupe « leurres ») à moins de 6 m : le zombie va dessus et s'acharne.
func _frapper_leurre() -> bool:
	for l in get_tree().get_nodes_in_group("leurres"):
		var d := Vector2(l.global_position.x - global_position.x, l.global_position.z - global_position.z).length()
		if d > 6.0 or absf(l.global_position.y - global_position.y) > 1.6 or not l.sonne():
			continue
		leurre_vise = l
		target = l.global_position
		if d < 1.8:
			# à portée de bras : s'arrête face au leurre et frappe (les autres zombies l'entourent)
			target = global_position
			rotation.y = atan2(-(l.global_position.x - global_position.x), -(l.global_position.z - global_position.z))
			if attack_t <= 0.0 and etourdi <= 0.0:
				attack_t = randf_range(1.2, 1.8)
				lunge = 1.0
				_anim("attaque", 1.0, 0.6)
				l.frapper_leurre(global_position)
		return true
	leurre_vise = null
	return false


func _on_noise(pos: Vector3, radius: float) -> void:
	if state == State.DEAD or state == State.CHASE:
		return
	if state == State.INVESTIGATE and leurre_vise and is_instance_valid(leurre_vise) and leurre_vise.sonne():
		return   # va déjà droit sur la source (leurre qui sonne : _frapper_leurre)
	if global_position.distance_to(pos) <= radius:
		state = State.INVESTIGATE
		target = pos + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		dormant = false


# ================================================================ déplacement
## Bandit vivant à portée de vue (le plus proche), gardé tant qu'il reste proche.
func _chercher_proie(portee: float) -> bool:
	if proie and is_instance_valid(proie) and proie.state != 3 and global_position.distance_to(proie.global_position) < portee * 1.5:
		return true
	proie = null
	var meilleur := portee
	var fwd := -global_basis.z
	for b in get_tree().get_nodes_in_group("bandits"):
		var d: float = global_position.distance_to(b.global_position)
		if d >= meilleur:
			continue
		if d > 6.0 and fwd.dot((b.global_position - global_position).normalized()) < 0.1:
			continue
		if _line_of_sight(b):
			meilleur = d
			proie = b
	return proie != null


func _raw_target() -> Vector3:
	if state == State.CHASE and proie and is_instance_valid(proie):
		return proie.global_position
	if state == State.CHASE and Game.player and not (assaut and not voit_joueur):
		return Game.player.global_position
	return target


## Piques, barbelés : le zombie avance au ralenti pendant un moment.
func ralentir(duree: float, facteur: float) -> void:
	ralenti_t = maxf(ralenti_t, duree)
	ralenti_k = facteur


## Passe par les portes quand la cible est dans un autre bâtiment.
func _route(to: Vector3) -> Vector3:
	var zt := Game.find_zone(to + Vector3.UP * 0.5)
	var zs := Game.find_zone(global_position + Vector3.UP * 0.5)
	# escalier en cours : on suit le chemin jusqu'au bout, même si on change d'étage en route
	if not chaine.is_empty():
		return _contourner(zs, _suivre_chaine())
	if is_same(zs, zt):
		return _contourner(zs, to)
	var l := Game.prochain_lien(zs, zt)
	if l.is_empty():
		return to
	if l.type == "escalier":
		chaine = l.chemin
		chaine_i = 0
		chaine_t = 0.0
		return _contourner(zs, _suivre_chaine())
	var etape := _route_lien(l)
	return _contourner(zs, etape)


## Dans un bâtiment cloisonné : passe par l'ouverture de la cloison si le mur barre la route.
func _contourner(zone: Dictionary, cible: Vector3) -> Vector3:
	var ps: Array = zone.get("passages", [])
	if ps.is_empty() or absf(global_position.y - zone.aabb.position.y) > 0.3 or absf(cible.y - zone.aabb.position.y) > 0.5:
		return cible
	var from := global_position + Vector3.UP * 0.9
	var q := PhysicsRayQueryParameters3D.create(from, Vector3(cible.x, from.y, cible.z), Game.LAYER_WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit.collider.get_script() != null:
		return cible   # rien, ou seulement un meuble / une porte : pas besoin de contourner
	var best: Vector3 = cible
	var bd := INF
	for g in ps:
		var gp: Vector3 = g
		if _flat_dist(global_position, gp) < 0.7:
			return cible
		var dd := _flat_dist(global_position, gp) + _flat_dist(gp, cible)
		if dd < bd:
			bd = dd
			best = Vector3(gp.x, global_position.y, gp.z)
	return best


var chaine: Array = []
var chaine_i := 0
var chaine_t := 0.0


func _suivre_chaine() -> Vector3:
	chaine_t += get_physics_process_delta_time()
	var pt: Vector3 = chaine[chaine_i]
	# reprise en cours de volée : déjà plus haut / plus bas que le premier point
	if chaine_i == 0 and absf(global_position.y - pt.y) > 0.35:
		chaine_i = 1
		pt = chaine[1]
	if _flat_dist(global_position, pt) < 0.6 and absf(global_position.y - pt.y) < 0.9:
		chaine_i += 1
		if chaine_i >= chaine.size():
			chaine = []
			return pt
		pt = chaine[chaine_i]
	if chaine_t > 15.0:
		chaine = []   # bloqué : on abandonne et on recalcule
	return pt


func _route_lien(l: Dictionary) -> Vector3:
	if l.type == "escalier":
		# déjà engagé dans la volée (plus haut ou plus bas que le départ) : on continue
		var a: Vector3 = l.a
		if absf(global_position.y - a.y) > 0.25 or _flat_dist(global_position, a) < 0.8:
			return l.b
		return a
	# porte : on passe de a (de ce côté) à b (de l'autre côté)
	if _flat_dist(global_position, l.pos) < _flat_dist(l.a, l.pos) + 0.4:
		return l.b
	return l.a


func _nearest_door(zone: Dictionary, from: Vector3) -> Dictionary:
	var best := {}
	var bd := INF
	for d in zone.doors:
		var dd := _flat_dist(from, d.pos)
		if dd < bd:
			bd = dd
			best = d
	return best


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _steer(dir: Vector3, delta: float) -> Vector3:
	if detour_t > 0.0:
		detour_t -= delta
		return detour_dir
	var block = _blocked(dir)
	if block == null:
		return dir
	# barricade sur le chemin : on tape dedans
	if block is Node and block.is_in_group("barricade") and state == State.CHASE:
		if attack_t <= 0.0:
			attack_t = 1.2
			lunge = 1.0
			block.take_damage(damage * 1.5, self)
		return Vector3.ZERO
	# porte fermée : on l'enfonce (seulement en poursuite ou en alerte)
	if block is Node and block.get("porte") != null and not block.porte.ouverte:
		if state == State.CHASE or state == State.INVESTIGATE:
			lost_t = 0.0
			if attack_t <= 0.0:
				attack_t = 1.3
				lunge = 1.0
				_anim("attaque", 1.0, 0.8)
				block.porte.frapper(damage * (2.0 if state == State.CHASE else 1.0))
			return Vector3.ZERO
	for a in [0.6, -0.6, 1.2, -1.2, 1.8, -1.8]:
		var d := dir.rotated(Vector3.UP, a)
		if _blocked(d) == null:
			detour_dir = d
			detour_t = 0.5
			return d
	return dir


func _blocked(d: Vector3) -> Variant:
	# deux rayons : à hauteur de torse et à hauteur de genou (meubles bas)
	for hauteur in [0.9, 0.35]:
		var from: Vector3 = global_position + Vector3.UP * hauteur
		var q := PhysicsRayQueryParameters3D.create(from, from + d * 1.2, Game.LAYER_WORLD, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			# une marche ou la rampe d'un escalier n'est pas un obstacle
			if hit.normal.y > 0.5:
				continue
			return hit.collider
	return null


# ================================================================ dégâts / mort
func take_hit(dmg: float, pos: Vector3, from: Vector3) -> void:
	if state == State.DEAD:
		return
	# talent Embuscade : coup au corps à corps du joueur (point touché tout près de lui) sur un zombie qui ne le poursuit pas
	var jp = Game.player
	if jp != null and state != State.CHASE and jp.prog.a("embuscade") and from.distance_to(jp.global_position) < 2.5 and pos.distance_to(jp.global_position) < 3.2:
		dmg *= 2.0
	var headshot := pos.y > global_position.y + 1.45 * echelle
	var tete := _pos_os("Head")
	if tete != Vector3.INF:
		headshot = pos.distance_to(tete + Vector3.UP * 0.07 * echelle) < 0.17 * echelle
	elif rampant:
		headshot = false
	if not headshot and not est_boss:
		_toucher_membre(pos, dmg, from)
	# un gros coup peut renverser le zombie
	if dmg >= 40.0 and not est_boss and a_terre <= 0.0 and randf() < (0.1 if kind == "gros" else 0.3) and health - dmg * (1.0 - armor) > 0.0:
		renverser(randf_range(2.5, 4.0))
	if headshot:
		# talent « Tireur de précision » : ×3 pour les coups du joueur (tir, flèche ou mêlée)
		var du_joueur: bool = Game.player != null and from.distance_to(Game.player.global_position) < 2.5
		dmg *= 3.0 if du_joueur and Game.player.prog.a("tir_tete") else 2.5
	else:
		dmg *= (1.0 - armor)
	Game.signaler_degats(self, dmg, health, pos, from, headshot)
	health -= dmg
	if corps_v:
		corps_v.coup(from, clampf(dmg / 40.0, 0.3, 1.2))   # buste rejeté du côté opposé au coup
	var push := global_position - from
	push.y = 0.0
	velocity += push.normalized() * 2.0
	var killed := health <= 0.0
	dormant = false
	if jp != null and jp.deguise() and global_position.distance_to(jp.global_position) < 6.0:
		jp.rompre_tripes("zombie touché tout près")
	if Game.tir_discret and state != State.CHASE:
		# flèche venue de nulle part : tué, il tombe sans alerter personne ; blessé, il va voir d'où vient
		# le tir (à peu près : l'erreur grandit avec la distance) sans encore savoir où est le tireur
		if not killed:
			var ecart := clampf(global_position.distance_to(from) * 0.15, 1.0, 8.0)
			state = State.INVESTIGATE
			target = from + Vector3(randf_range(-ecart, ecart), 0.0, randf_range(-ecart, ecart))
	else:
		state = State.CHASE
		lost_t = 0.0
	if not killed and douleur_cd <= 0.0:
		douleur_cd = 0.7
		_voix("douleur", -3.0, 35.0)
	if not killed and anim_lock <= 0.0:
		_anim("touche", 1.0, 0.35)
	Game.hit_confirmed.emit(headshot, killed)
	if killed:
		_die()


## Voix du zombie : une variante au hasard de zv_<type> (sons/), à la hauteur propre à ce zombie.
func _voix(type: String, vol_db: float, portee: float, haut := 1.6) -> void:
	var n := Game.variantes("zv_" + type)
	if n > 0:
		Game.play_3d("zv_%s%d" % [type, randi_range(1, n)], global_position + Vector3.UP * haut * echelle, vol_db, 0.04, portee, voix)


func take_damage(amount: float, _from: Node = null) -> void:
	take_hit(amount, global_position, global_position)


const XP_TYPE := {"civil": 20, "patient": 25, "police": 35, "militaire": 50, "boss": 600, "coureur": 30, "gros": 60, "rampant": 15}


func _die() -> void:
	if Game.player and state != State.DEAD:
		var p = Game.player
		if p.prog.a("furie"):   # talent Furie : chaque zombie tué redonne un peu de souffle et de santé
			p.stamina = minf(p.prog.endurance_max(), p.stamina + 8.0)
			p.health = minf(p.prog.sante_max(), p.health + 3.0)
		Game.player.prog.gagner("combat", XP_TYPE.get(kind, 20))
		var journal = preload("res://scripts/journal.gd")   # journal du survivant
		journal.compter("zombies")
		journal.compter("zombies_type:" + ("boss" if est_boss else kind))
		journal.compter("zombies_arme:" + p.current_weapon())
		# quelques billets sur le corps
		if randf() < 0.45:
			Game.player.gagner_argent(randi_range(1, 6) * (4 if est_boss else 1))
		if est_boss:
			Game.player.prog.gagner("exploration", 200)
			Game.msg("Le Colosse est tombé ! Fouille son corps et la cache au fond de la grotte.")
			_voix("mort", 6.0, 120.0, 1.4)
			remove_from_group("boss")
	charge_t = 0.0
	slam_t = -1.0
	get_tree().create_timer(0.9).timeout.connect(func(): if is_instance_valid(self): Effets.flaque(get_parent(), global_position))
	get_tree().create_timer(0.5).timeout.connect(func(): if is_instance_valid(self): _lacher_arme())
	if state != State.DEAD and not est_boss:
		_voix("mort", -2.0, 40.0)
	state = State.DEAD
	if pieds_ik:
		pieds_ik.active = false
	_finir_prep()
	relev_t = -1.0
	if corps_v:
		corps_v.active = false
	remove_from_group("zombies")
	add_to_group("corpses")
	collision_layer = Game.LAYER_INTERACT
	collision_mask = Game.LAYER_WORLD
	velocity = Vector3.ZERO
	if ap:
		ap.active = true
		# déjà au sol (renversé ou rampant) : reste couché, sans rejouer la chute depuis la pose debout
		if a_terre > 0.0:
			pass
		elif rampant:
			ap.pause()
		else:
			_mort_variee()
		return
	var tw := create_tween()
	tw.tween_property(modele, "rotation:x", -PI / 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(modele, "position:y", 0.25, 0.45)


func _dead_process(delta: float) -> void:
	dead_t += delta
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		move_and_slide()
	var p = Game.player
	if dead_t > 240.0 or (dead_t > 20.0 and p and global_position.distance_to(p.global_position) > 120.0):
		queue_free()


var label := "Corps"
var grille: Grille = null


func get_prompt() -> String:
	if state != State.DEAD:
		return "[F] Achever" if achevable() else ""
	# déguisement (player.se_couvrir_de_tripes) : une fois par corps, avec une lame
	var tripes := ""
	if not has_meta("tripes") and not est_boss and Game.player and Game.player.lame_tripes() != "":
		tripes = "   [%s] Se couvrir de tripes" % Game.texte_touche("ameliorer")
	if searched and grille and grille.vide():
		return "Corps (vide)" + tripes
	return "[F] Fouiller le corps" + tripes


func interact(player: Node) -> void:
	if state != State.DEAD:
		if achevable() and player.has_method("achever"):
			player.achever(self)
		return
	if grille == null:
		searched = true
		grille = Grille.creer("Corps", 6 if est_boss else 4, 6 if est_boss else 4)
		player.prog.gagner("exploration", 4)
		var table := "zombie_" + kind if Items.LOOT.has("zombie_" + kind) else "zombie_civil"
		var found := Items.roll_loot(table, 6 if est_boss else (3 if kind == "gros" else 2), 0.0 if est_boss else 0.35)
		for id in found:
			if Items.grid(id).x > 0:
				grille.ajouter_entree(player.nouvelle_entree(id))
			else:
				grille.ajouter(id, int(found[id]))
	if int(get_meta("fleches", 0)) > 0:   # flèches restées plantées dans le corps
		grille.ajouter("fleche", int(get_meta("fleches", 0)))
		remove_meta("fleches")
	player.open_storage(self)


func on_closed() -> void:
	pass


# ================================================================ animations
func _anim(nom: String, vitesse := 1.0, verrou := 0.0) -> void:
	nom = anim_noms.get(nom, nom)
	if ap == null or not ap.has_animation(nom):
		return
	if verrou > 0.0:
		anim_lock = verrou
		ap.play(nom, 0.1)
		ap.seek(0.0)
		cur_anim = nom
	elif cur_anim != nom:
		ap.play(nom)
		cur_anim = nom
	ap.speed_scale = vitesse


func _update_anim(delta: float) -> void:
	if relev_t >= 0.0:
		relev_t += delta
		ap.speed_scale = _vitesse_relever(relev_t)
		if relev_t > 1.95:
			relev_t = -1.0
			if corps_v:
				corps_v.coup(global_position + global_basis.x * (1.0 if randf() < 0.5 else -1.0), 0.7)   # titube
	if anim_lock > 0.0:
		anim_lock -= delta
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	hs /= echelle
	if rampant:
		_anim("rampe", clampf(hs / 0.55, 0.25, 2.0) if hs > 0.05 else 0.25)
		return
	if hs > 2.0 / echelle:
		_anim("course", clampf(hs / (3.1 if anim_noms else 3.0), 0.6, 1.8) * allure)
	elif hs > 0.15:
		_anim("marche", clampf(hs / (0.95 if anim_noms else 0.65), 0.5, 2.2) * allure)
	else:
		_anim("idle", allure)



# ================================================================ boss
## Le Colosse : charge le joueur de loin, frappe le sol de près (onde de choc).
func _boss_update(delta: float, p) -> void:
	charge_cd -= delta
	slam_cd -= delta
	if p == null or not p.alive:
		charge_t = 0.0
		slam_t = -1.0
		return
	var to_p: Vector3 = p.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	# charge en cours
	if charge_t > 0.0:
		charge_t -= delta
		if not charge_touche and dist < 2.9 and absf(p.global_position.y - global_position.y) < 2.5:
			charge_touche = true
			p.take_damage(30.0, self)
			if p is CharacterBody3D:
				p.velocity += charge_dir * 9.0 + Vector3.UP * 4.0
			Game.play_3d("coup", global_position + Vector3.UP * 2.0, 4.0, 0.1, 60.0)
			charge_t = minf(charge_t, 0.15)
		if charge_t < 1.1:
			for i in get_slide_collision_count():
				var n := get_slide_collision(i).get_normal()
				if n.y < 0.5 and n.dot(charge_dir) < -0.6:
					charge_t = 0.0   # percute un mur : s'arrête net
		if charge_t <= 0.0:
			attack_t = 1.2
		return
	# coup au sol en préparation
	if slam_t >= 0.0:
		slam_t -= delta
		if slam_t < 0.0:
			Game.play_3d("construire", global_position + Vector3.UP, 6.0, 0.1, 80.0)
			Game.make_noise(global_position, 30.0)
			if dist < 4.8 and absf(p.global_position.y - global_position.y) < 2.0:
				p.take_damage(25.0 * (1.0 - dist / 9.0), self)
				if p is CharacterBody3D:
					p.velocity += to_p.normalized() * 6.0 + Vector3.UP * 5.0
			attack_t = 1.0
		return
	if state != State.CHASE or attack_t > 0.0:
		return
	if dist > 6.0 and dist < 16.0 and charge_cd <= 0.0 and _line_of_sight(p):
		charge_cd = randf_range(6.0, 9.0)
		charge_t = clampf(dist / 7.0 + 0.5, 1.2, 2.6)
		charge_touche = false
		charge_dir = to_p.normalized()
		rotation.y = atan2(-charge_dir.x, -charge_dir.z)
		_voix("cri", 6.0, 90.0, 1.4)
		_anim("course", 1.6)
	elif dist < 3.6 and slam_cd <= 0.0:
		slam_cd = randf_range(5.0, 8.0)
		slam_t = 0.7
		charge_dir = Vector3.ZERO
		_anim("attaque", 0.7, 1.1)
		_voix("attaque", 6.0, 90.0, 1.4)



## Repoussé (parade du joueur, coup de masse…) : recule et reste étourdi un instant.
func repousser(dir: Vector3, force: float, duree: float) -> void:
	if state == State.DEAD:
		return
	var f := force * (0.25 if est_boss else 1.0)
	velocity += Vector3(dir.x, 0.0, dir.z).normalized() * f
	etourdi = maxf(etourdi, duree * (0.3 if est_boss else 1.0))
	if duree >= 0.85 and randf() < (0.12 if kind == "gros" else 0.35):
		renverser(randf_range(3.0, 4.5))
		return
	if anim_lock <= 0.0:
		_anim("touche", 1.0, 0.35)


# ================================================================ rampants et démembrement
## Position (monde) d'un os du modèle, ou INF si indisponible.
func _pos_os(nom: String) -> Vector3:
	if squelette == null or not is_instance_valid(squelette):
		return Vector3.INF
	var i := squelette.find_bone(nom)
	if i < 0:
		i = squelette.find_bone(nom.to_lower())   # squelette Quaternius : noms UAL en minuscules
	if i < 0:
		return Vector3.INF
	return squelette.global_transform * squelette.get_bone_global_pose(i).origin


## Le zombie rampe : corps couché, collision basse.
func _mettre_au_sol() -> void:
	rampant = true
	run_speed = minf(run_speed, 1.3)
	walk_speed = 0.45
	var cs: CollisionShape3D = $Collision
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 0.64
	cs.shape = cap
	cs.position.y = 0.32
	if ap:
		_anim("rampe", 0.3)


## Accumule les dégâts sur le membre touché ; au-delà d'un seuil, le membre est arraché.
func _toucher_membre(pos: Vector3, dmg: float, from: Vector3) -> void:
	if squelette == null:
		return
	var os_membres := ["lowerarm_l", "lowerarm_r", "upperarm_l", "upperarm_r", "calf_l", "calf_r", "thigh_l", "thigh_r"]
	var meilleur := ""
	var dmin := 0.2
	for b in os_membres:
		if b in coupes:
			continue
		var p := _pos_os(b)
		if p == Vector3.INF:
			continue
		var d := p.distance_to(pos)
		if d < dmin:
			dmin = d
			meilleur = b
	if meilleur == "":
		return
	var cote := meilleur.substr(meilleur.length() - 2)
	var cle := ("bras" if meilleur.contains("arm") else "jambe") + cote
	membres[cle] = float(membres.get(cle, 0.0)) + dmg
	var seuil := 35.0 if cle.begins_with("bras") else 40.0
	if float(membres[cle]) >= seuil and health - dmg * (1.0 - armor) > 0.0:
		_arracher(meilleur, from)


func _arracher(os_nom: String, from: Vector3) -> void:
	var p_os := _pos_os(os_nom)
	coupes.append(os_nom)
	_modificateur().coupes = coupes
	Game.spawn_blood(p_os, get_parent())
	Game.spawn_blood(p_os + Vector3.UP * 0.1, get_parent())
	Game.play_3d("impact", p_os, 2.0, 0.2, 30.0)
	# morceau arraché
	var jambe := os_nom.begins_with("calf") or os_nom.begins_with("thigh")
	var rb := RigidBody3D.new()
	rb.collision_layer = 0
	rb.collision_mask = Game.LAYER_WORLD
	var lg := 0.45 if jambe else 0.33
	var r := 0.065 if jambe else 0.045
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = lg
	cs.shape = cap
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = lg
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	var peau: Color = aspect.get("peau", Color(0.55, 0.5, 0.45))
	m.albedo_color = (aspect.get("bas", Color(0.3, 0.3, 0.3)) if jambe else peau.lerp(Color(0.45, 0.5, 0.4), 0.4))
	m.roughness = 0.8
	mi.material_override = m
	rb.add_child(mi)
	var bout := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r * 1.05
	sm.height = r * 2.1
	bout.mesh = sm
	var mb := StandardMaterial3D.new()
	mb.albedo_color = Color(0.4, 0.02, 0.02)
	mb.roughness = 0.4
	bout.material_override = mb
	bout.position = Vector3(0, lg * 0.5 - r * 0.5, 0)
	rb.add_child(bout)
	get_parent().add_child(rb)
	rb.global_position = p_os
	var dir := (p_os - from)
	dir.y = 0.0
	rb.linear_velocity = dir.normalized() * 2.5 + Vector3.UP * 2.0
	rb.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	get_tree().create_timer(60.0).timeout.connect(func(): if is_instance_valid(rb): rb.queue_free())
	if jambe:
		if not rampant:
			kind = "rampant"
			_mettre_au_sol()
	else:
		# sans ses deux bras, il ne peut plus que mordre
		var bras := 0
		for c in coupes:
			if c.contains("arm"):
				bras += 1
		if bras >= 2:
			damage *= 0.5



# ================================================================ à terre / coup de grâce
func achevable() -> bool:
	return state != State.DEAD and not est_boss and (a_terre > 0.0 or rampant)


## Renversé : tombe au sol quelques secondes (peut être achevé), puis se relève.
func renverser(duree: float) -> void:
	if est_boss or state == State.DEAD or rampant:
		return
	a_terre = duree
	_finir_prep()
	relev_t = -1.0
	dormant = false
	var cs: CollisionShape3D = $Collision
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 0.64
	cs.shape = cap
	cs.position.y = 0.32
	if ap:
		_anim("mort_miroir" if randf() < 0.5 and ap.has_animation("mort_miroir") else "mort", 1.5, duree)
	Game.play_3d("coup", global_position + Vector3.UP * 0.5, -2.0, 0.2, 25.0)


func _se_relever() -> void:
	var cs: CollisionShape3D = $Collision
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33 * corps.x
	cap.height = 1.8 * corps.y
	cs.shape = cap
	cs.position.y = 0.9 * corps.y
	if ap:
		if ap.has_animation("relever"):
			_anim("relever", 1.0, 2.0)
			relev_t = 0.0
			etourdi = maxf(etourdi, 1.9)   # ne bouge presque pas tant qu'il n'est pas debout
		else:
			_anim("idle", 1.0, 0.3)
	state = State.CHASE if Game.player and Game.player.alive else State.WANDER


## Animation selon la distance et la visibilité : chaque image de près, de moins en moins souvent
## au loin ou hors du champ de vision (le squelette coûte cher à recalculer).
func _process(delta: float) -> void:
	if ap == null or not ap.active or ap.callback_mode_process != AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		anim_acc = 0.0
		return
	anim_acc += delta
	anim_image += 1
	var palier := 1
	var p = Game.player
	if p and state != State.CHASE:
		var d := global_position.distance_to(p.global_position)
		if not p.camera.is_position_in_frustum(global_position + Vector3.UP):
			palier = 8
		elif d > 45.0:
			palier = 4
		elif d > 20.0:
			palier = 2
	if anim_image % palier == 0:
		ap.advance(anim_acc)
		if squelette:
			squelette.advance(anim_acc)
		anim_acc = 0.0


## Modificateur d'après-animation du squelette (membres coupés, posture), créé au besoin.
func _modificateur() -> Node:
	if demembre == null:
		demembre = preload("res://scripts/demembrement.gd").new()
		squelette.add_child(demembre)
	return demembre


## Zombie « dédié » : tête penchée sur le côté, dos voûté, parfois un avant-bras ou un bras déjà arraché.
## Rotations données dans le repère du squelette (avant = +Z) et ramenées dans celui de chaque os.
func _posture_zombie() -> void:
	if squelette == null:
		return
	var voute := 0.0 if rampant else (0.06 if kind == "coureur" else randf_range(0.1, 0.2))
	var cote := -1.0 if randf() < 0.5 else 1.0
	var penche := randf_range(0.15, 0.45) * cote
	var p: Array = []
	for r in [["spine_02", voute * 0.5, 0.0], ["spine_03", voute * 0.4, penche * 0.15], ["neck_01", 0.05 + voute * 0.3, penche * 0.6],
			["Head", randf_range(0.0, 0.08), penche * 0.5]]:
		var i := squelette.find_bone(r[0])
		if i < 0:
			continue
		var g := squelette.get_bone_global_rest(i).basis.orthonormalized()
		var b := Basis(Vector3.RIGHT, r[1]) * Basis(Vector3.BACK, r[2])
		p.append([r[0], Quaternion(g.inverse() * b * g)])
	_modificateur().posture = p
	# membres arrachés dès l'apparition (sans effet de sang : blessure ancienne)
	if not est_boss and not rampant and randf() < 0.2:
		var os_nom: String = ["lowerarm_l", "lowerarm_r", "lowerarm_l", "lowerarm_r", "upperarm_l", "upperarm_r"].pick_random()
		if squelette.find_bone(os_nom) >= 0:
			coupes.append(os_nom)
			demembre.coupes = coupes


# ================================================================ attaque en deux temps
func _duree_prep() -> float:
	return 0.6 if est_boss else (0.3 if kind == "coureur" else 0.42)


func _preparer(c: Node3D) -> void:
	prep_t = 0.0
	prep_cible = c
	attack_t = (1.7 if est_boss else 1.1) + _duree_prep()
	_voix("attaque", -2.0, 30.0)


func _finir_prep() -> void:
	prep_t = -1.0
	prep_cible = null
	if corps_v:
		corps_v.bras_leves = 0.0


## Distance à plat jusqu'à la cible ; joueur dans une voiture arrêtée (vehicule.gd) : jusqu'à la carrosserie,
## qu'il frappe (le coup passe par `vehicule.encaisser`). Voiture qui roule : hors d'atteinte.
func _distance_cible(c: Node3D) -> float:
	var v = c.get("vehicule") if c == Game.player else null
	if v != null and is_instance_valid(v):
		return v.distance_coque(global_position) + 0.4 if v.linear_velocity.length() < 3.0 else INF
	return Vector2(c.global_position.x - global_position.x, c.global_position.z - global_position.z).length()


func _frapper() -> void:
	var c := prep_cible
	_finir_prep()
	lunge = 1.0
	if not rampant:
		_anim("attaque", 1.3, 0.6)
	if c == null or not is_instance_valid(c):
		return
	var portee := 1.9 * (1.6 if est_boss else 1.0)
	var flat := _distance_cible(c)
	if flat > portee or absf(c.global_position.y - global_position.y) > 1.5 * echelle:
		return   # la cible a reculé à temps
	if c == Game.player:
		if c.alive:
			c.take_damage(damage, self)
	elif c.get("state") != 3:
		c.take_hit(damage, c.global_position + Vector3.UP * 1.2, global_position)


## Vitesse de lecture du relevé maladroit (après avoir été renversé) : il se redresse, glisse en
## arrière, peine un instant, puis se relève d'un coup et titube.
func _vitesse_relever(t: float) -> float:
	if t < 0.45:
		return 1.0
	if t < 0.75:
		return -0.7
	if t < 1.05:
		return 0.2
	return 1.3


## Mort : chute sur un côté ou sur l'autre, ou effondrement sur place (« se relever » joué à l'envers).
func _mort_variee() -> void:
	var r := randf()
	if r < 0.3 and ap.has_animation("relever"):
		anim_lock = 99.0
		ap.speed_scale = 1.0
		ap.play("relever", 0.15, -1.15, true)
		cur_anim = "relever"
	elif r < 0.65 and ap.has_animation("mort_miroir"):
		_anim("mort_miroir", 1.0, 99.0)
	else:
		_anim("mort", 1.0, 99.0)
