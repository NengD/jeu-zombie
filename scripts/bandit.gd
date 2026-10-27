extends CharacterBody3D
## Bandit armé : patrouille autour de son camp, entend les bruits, voit moins bien la nuit,
## tire sur le joueur (et sur les zombies trop proches), alerte ses camarades,
## garde ses distances et recharge. À sa mort : son arme et des munitions au sol, de l'argent.

const LodAnim = preload("res://scripts/lod_anim.gd")
const Perso = preload("res://scripts/perso.gd")
const ModeleUtil = preload("res://scripts/modele_util.gd")
const Effets = preload("res://scripts/effets.gd")
const LootContainer = preload("res://scripts/loot_container.gd")
const Accessoires = preload("res://scripts/accessoires.gd")

enum { PATROUILLE, ALERTE, COMBAT, MORT = 3, REPLI = 4 }
const ARMES := [["glock19", 4.0], ["m45a1", 2.0], ["mr920", 2.0], ["toz34", 1.5], ["mp5k", 1.5], ["ak74", 1.5], ["draco", 1.0], ["marlin", 1.0]]
const GRAVITE := 14.0

var state := PATROUILLE
var health := 100.0
var pv_max := 100.0
var abri := Vector3.ZERO      # point à couvert (repli quand il est blessé)
var a_couvert := false
var repli_t := 0.0
var deja_replie := false
var camp := -1                 # numéro du camp (sauvegarde)
var maison := Vector3.ZERO     # centre du camp
var cible_pos := Vector3.ZERO  # point de patrouille / bruit entendu
var cible: Node3D = null       # joueur ou zombie visé
var arme := "glock19"
var chargeur := 0
var tir_t := 0.0
var rafale := 0
var recharge_t := 0.0
var pense_t := 0.0
var attente_t := 0.0
var perdu_t := 0.0
var lateral := 1.0
var bloque_t := 0.0
var detour := Vector3.ZERO
var detour_t := 0.0
var etourdi := 0.0
var ralenti_t := 0.0
var ralenti_k := 1.0
var mort_t := 0.0
var modele: Node3D = null
var pap: AnimationPlayer = null
var lod = null                # animation à niveau de détail (lod_anim.gd)
var arme_noeud: Node3D = null
var bras_ik: Node = null
var pieds_ik = null                 # pieds posés sur le sol (scripts/pieds_ik.gd)
var corps_v = null                  # hanches vers la marche (pas de côté en combat), regard, coups (scripts/corps_vivant.gd)
var recule := false                 # recule en combat : la marche est jouée à l'envers
var anim := ""
var anim_lock := 0.0


func setup(p_camp: int, centre: Vector3, rng: RandomNumberGenerator) -> void:
	camp = p_camp
	maison = centre
	cible_pos = centre
	add_to_group("bandits")
	collision_layer = Game.LAYER_ZOMBIE
	collision_mask = Game.LAYER_WORLD | Game.LAYER_PLAYER
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	# arme tirée au sort
	var total := 0.0
	for e in ARMES:
		total += float(e[1])
	var t := rng.randf() * total
	for e in ARMES:
		t -= float(e[1])
		if t <= 0.0:
			arme = e[0]
			break
	chargeur = int(Items.info(arme).get("mag", 8))
	health = rng.randf_range(90.0, 130.0)
	pv_max = health
	lateral = 1.0 if rng.randf() < 0.5 else -1.0
	if Perso.disponible():
		modele = Perso.creer(Perso.apparence("bandit", rng))
		add_child(modele)
		pap = ModeleUtil.anim_player(modele)
		if pap:
			ModeleUtil.boucler(pap, ["idle", "marche", "jogging", "course", "arme_idle", "visee", "accroupi"])
			pap.playback_default_blend_time = 0.2
		var prise: Node3D = modele.find_child("Prise", true, false)
		var m := ModeleUtil.arme(arme)
		if prise and m:
			prise.add_child(m)
			arme_noeud = m
			# bras calculés : arme au torse, en joue au combat
			bras_ik = preload("res://scripts/bras_ik.gd").new()
			bras_ik.corps = self
			bras_ik.arme = m
			bras_ik.pistolet = float(Items.info(arme).get("len", 0.3)) < 0.4
			bras_ik.point_main_g = preload("res://scripts/fps_arms.gd").hand_points(arme, Items.info(arme), Accessoires.points(arme, m)).L
			var sk_b := ModeleUtil.squelette(modele)
			# pieds posés sur le sol (près du joueur), avant les bras
			pieds_ik = preload("res://scripts/pieds_ik.gd").new()
			pieds_ik.corps = self
			pieds_ik.masque = Game.LAYER_WORLD
			pieds_ik.active = false
			corps_v = preload("res://scripts/corps_vivant.gd").new()
			corps_v.corps = self
			corps_v.pieds = pieds_ik
			corps_v.active = false
			corps_v.pivot_actif = false
			sk_b.add_child(corps_v)
			sk_b.add_child(pieds_ik)
			sk_b.add_child(bras_ik)
		ModeleUtil.distance_visible(modele, 160.0)
		lod = LodAnim.new(pap, ModeleUtil.squelette(modele))


func _ready() -> void:
	Game.noise_made.connect(_bruit)


# ---------------------------------------------------------------- boucle
func _process(delta: float) -> void:
	if lod:
		lod.maj(delta, global_position, state == COMBAT or state == REPLI or state == MORT)


func _physics_process(delta: float) -> void:
	if state == MORT:
		_mort_process(delta)
		return
	var p = Game.player
	var dj := 9999.0
	if p:
		dj = global_position.distance_to(p.global_position)
	LodAnim.ombres(modele, dj < LodAnim.OMBRE_DIST)
	if pieds_ik:
		pieds_ik.active = dj < 22.0
	if corps_v:
		corps_v.active = pieds_ik.active
		# en combat : jambes vers la marche, buste vers la cible ; tête vers la cible
		var vl := global_basis.inverse() * velocity
		vl.y = 0.0
		corps_v.vitesse = vl.length()
		var h := 0.0
		recule = false
		if state == COMBAT and vl.length() > 0.4:
			var ang := atan2(-vl.x, -vl.z)
			if absf(ang) > 1.95:
				recule = true
				ang = wrapf(ang + PI, -PI, PI)
			h = clampf(ang, -1.1, 1.1)
		corps_v.hanches_cible = h
		var vise: bool = cible != null and is_instance_valid(cible) and global_position.distance_to(cible.global_position) < 25.0
		corps_v.regard = (cible.global_position + Vector3.UP * 1.5) if vise else Vector3.INF
	# loin du joueur : en sommeil
	if dj > 120.0 and state != COMBAT and state != REPLI:
		if modele:
			modele.visible = dj < 160.0
		if pap:
			pap.active = false
		return
	if pap:
		pap.active = true
	if modele:
		modele.visible = true
	pense_t -= delta
	if pense_t <= 0.0:
		pense_t = 0.3
		_penser()
	anim_lock = maxf(0.0, anim_lock - delta)
	etourdi = maxf(0.0, etourdi - delta)
	var vitesse := 0.0
	var dir := Vector3.ZERO
	var regard := Vector3.ZERO
	match state:
		PATROUILLE:
			attente_t -= delta
			var d := _plat(cible_pos - global_position)
			if d.length() > 0.8:
				dir = d.normalized()
				vitesse = 1.2
			elif attente_t <= 0.0:
				attente_t = randf_range(3.0, 8.0)
				cible_pos = maison + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9))
		ALERTE:
			var d := _plat(cible_pos - global_position)
			if d.length() > 1.5:
				dir = d.normalized()
				vitesse = 2.6
			else:
				perdu_t += delta
				if perdu_t > 6.0:
					state = PATROUILLE
					cible_pos = maison
		COMBAT:
			if cible == null or not is_instance_valid(cible):
				state = ALERTE
			else:
				var vers := _plat(cible.global_position - global_position)
				var dist := vers.length()
				regard = vers.normalized()
				# distance de combat : 8 à 18 m (pompe : plus près), décalage latéral
				var loin := 12.0 if Items.info(arme).get("famille", "") == "pompe" else 18.0
				var pres := 5.0 if Items.info(arme).get("famille", "") == "pompe" else 8.0
				if dist > loin:
					dir = regard
					vitesse = 3.2
				elif dist < pres:
					dir = -regard
					vitesse = 2.2
				else:
					dir = regard.cross(Vector3.UP) * lateral
					vitesse = 1.0
					if randf() < delta * 0.25:
						lateral = -lateral
				_tirer(delta)
		REPLI:
			# blessé : court se mettre à l'abri, s'accroupit et tire de temps en temps
			repli_t -= delta
			if cible and is_instance_valid(cible):
				regard = _plat(cible.global_position - global_position).normalized()
				# la menace contourne l'abri : on en cherche un autre
				if fmod(repli_t, 3.0) < delta:
					_choisir_abri(cible.global_position)
			var d := _plat(abri - global_position)
			a_couvert = d.length() < 0.8
			if not a_couvert:
				dir = d.normalized()
				vitesse = 3.6
				regard = Vector3.ZERO
			elif cible and is_instance_valid(cible):
				tir_t += delta * 0.5   # tire moins souvent, à l'abri
				_tirer(delta)
			var proche: bool = cible != null and is_instance_valid(cible) and global_position.distance_to(cible.global_position) < 5.0
			if repli_t <= 0.0 or proche:
				state = COMBAT
				a_couvert = false
	if recharge_t > 0.0:
		recharge_t -= delta
		vitesse *= 0.5
		if recharge_t <= 0.0:
			chargeur = int(Items.info(arme).get("mag", 8))
	if etourdi > 0.0:
		vitesse *= 0.2
	if ralenti_t > 0.0:
		ralenti_t -= delta
		vitesse *= ralenti_k
	if Game.dans_eau(global_position):
		vitesse *= 0.6
	dir = _eviter(dir, delta)
	velocity.x = move_toward(velocity.x, dir.x * vitesse, 10.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * vitesse, 10.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITE * delta
	move_and_slide()
	var face := regard if regard.length() > 0.1 else dir
	if face.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 8.0 * delta)
	_animer(vitesse)
	if bras_ik:
		var en_combat: bool = (state == COMBAT or state == REPLI) and cible != null and is_instance_valid(cible)
		bras_ik.poids = move_toward(bras_ik.poids, 0.0 if recharge_t > 0.0 else 1.0, delta * 5.0)
		bras_ik.visee = move_toward(bras_ik.visee, 1.0 if en_combat else 0.0, delta * 4.0)
		if en_combat:
			bras_ik.cible_visee = cible.global_position + Vector3.UP * 1.2


func _plat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v


## Contourne un obstacle droit devant (mur, voiture) ; détour si coincé.
func _eviter(dir: Vector3, delta: float) -> Vector3:
	if dir.length() < 0.1:
		return dir
	if detour_t > 0.0:
		detour_t -= delta
		return detour
	if Vector2(velocity.x, velocity.z).length() < 0.2:
		bloque_t += delta
		if bloque_t > 0.7:
			bloque_t = 0.0
			detour = dir.rotated(Vector3.UP, randf_range(1.0, 2.0) * (1.0 if randf() < 0.5 else -1.0))
			detour_t = 1.0
	else:
		bloque_t = 0.0
	return dir


# ---------------------------------------------------------------- perception
func _penser() -> void:
	var p = Game.player
	if state == REPLI:
		if p and p.alive and _voit(p):
			cible = p
		return
	if p and p.alive and not (Game.admin and Game.admin_invisible) and _voit(p):
		if state != COMBAT:
			_alerter_camp(p.global_position)
			tir_t = randf_range(0.8, 1.6)   # temps de réaction avant le premier tir
		state = COMBAT
		cible = p
		perdu_t = 0.0
		return
	if state == COMBAT and cible == p:
		perdu_t += 0.3
		if perdu_t > 5.0:
			# cible perdue de vue : on va voir où elle était
			state = ALERTE
			cible_pos = p.global_position
			perdu_t = 0.0
		return
	# zombies trop proches : on se défend
	var proche: Node3D = null
	var dmin := 14.0
	for z in get_tree().get_nodes_in_group("zombies"):
		if z.state == 3:
			continue
		var d: float = global_position.distance_to(z.global_position)
		if d < dmin and _ligne_libre(z.global_position + Vector3.UP * 1.2):
			dmin = d
			proche = z
	if proche:
		state = COMBAT
		cible = proche
	elif state == COMBAT and (cible == null or not is_instance_valid(cible) or cible.get("state") == 3):
		state = ALERTE
		cible = null
		perdu_t = 0.0


func _voit(p: Node3D) -> bool:
	var d := global_position.distance_to(p.global_position)
	var portee := 35.0
	if Game.is_night():
		portee = 14.0 + (16.0 if p.flashlight_on else 0.0)
		var v = _voiture_joueur() if p == Game.player else null
		if v and v.phares_on:
			portee += 26.0   # phares allumés : vus de loin
	if p.crouching:
		portee *= 0.6
	if p.prog.a("discret"):
		portee *= 0.75
	if d > portee:
		return false
	var vers := _plat(p.global_position - global_position).normalized()
	if state != COMBAT and d > 4.0 and (-global_basis.z).dot(vers) < -0.2:
		return false   # dans son dos
	return _ligne_libre(p.global_position + Vector3.UP * 1.4)


func _ligne_libre(vers: Vector3) -> bool:
	var exclus := [get_rid()]
	var v = _voiture_joueur()
	if v:
		exclus.append(v.get_rid())   # le conducteur se voit (et se vise) à travers les vitres
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.6, vers, Game.LAYER_WORLD, exclus)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Voiture conduite par le joueur (vehicule.gd), ou null.
func _voiture_joueur():
	var v = Game.player.get("vehicule") if Game.player else null
	return v if v != null and is_instance_valid(v) else null


func _bruit(pos: Vector3, rayon: float) -> void:
	if state == MORT or state == COMBAT or state == REPLI:
		return
	if global_position.distance_to(pos) <= rayon * 1.3:
		state = ALERTE
		cible_pos = pos + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		perdu_t = 0.0


## Les autres bandits du camp se mettent en alerte.
func _alerter_camp(pos: Vector3) -> void:
	for b in get_tree().get_nodes_in_group("bandits"):
		if b != self and b.camp == camp and b.state != MORT and b.state != COMBAT and b.state != REPLI:
			b.state = ALERTE
			b.cible_pos = pos
			b.perdu_t = 0.0


# ---------------------------------------------------------------- tir
func _tirer(delta: float) -> void:
	tir_t -= delta
	if tir_t > 0.0 or recharge_t > 0.0 or etourdi > 0.0 or cible == null:
		return
	var w := Items.info(arme)
	if chargeur <= 0:
		recharge_t = 2.2
		_anim("recharge", 1.0, 1.2)
		Game.play_3d("recharge", global_position + Vector3.UP * 1.2, -4.0, 0.1, 25.0)
		return
	var vise := cible.global_position + Vector3.UP * 1.2
	if not _ligne_libre(vise):
		return
	var auto: bool = w.get("auto", false)
	if rafale <= 0:
		rafale = randi_range(2, 4) if auto else 1
	rafale -= 1
	tir_t = (float(w.get("rate", 0.3)) * 1.8) if rafale > 0 else randf_range(1.3, 2.6)
	chargeur -= 1
	# précision : forte de près, chute vite avec la distance (mieux vaut les contourner que les combattre de loin) ;
	# baisse aussi la nuit, quand la cible court ou se tient accroupie
	var dist := global_position.distance_to(cible.global_position)
	var chance := 0.66 - dist * 0.027
	if Game.is_night():
		chance -= 0.12
	if cible.velocity.length() > 4.0:
		chance -= 0.15
	if cible.get("crouching"):
		chance -= 0.08
	chance = clampf(chance, 0.04, 0.65)
	var famille: String = w.get("famille", "")
	var son := "tir_pompe" if famille == "pompe" else ("tir_pistolet" if famille in ["pistolet", "smg"] else "tir_fusil")
	var bouche := global_position + Vector3.UP * 1.45 - global_basis.z * 0.6
	Game.play_tir(son, bouche, 2.0)
	Game.make_noise(global_position, 45.0)
	if arme_noeud and is_instance_valid(arme_noeud):
		var pts := Accessoires.points(arme, arme_noeud)
		Effets.flamme(arme_noeud, pts.get("bouche", Vector3(0, 0.03, -0.4)), 0.22, 1)
	_anim("tir", 1.0, 0.25)
	var plombs := int(w.get("pellets", 1))
	var degats := float(w.get("damage", 20.0)) * (0.22 if plombs > 1 else 0.35) * plombs
	# dégâts : +30 % à bout portant (< 6 m), -20 % au loin (> 22 m)
	degats *= remap(clampf(dist, 6.0, 22.0), 6.0, 22.0, 1.3, 0.8)
	if cible == Game.player:
		degats *= Game.mult_degats()   # réglage de difficulté (game.gd)
	if randf() < chance:
		if cible == Game.player:
			var v = _voiture_joueur()
			if v:
				v.balle_t = true   # balle à travers la vitre : vehicule.encaisser
			cible.take_damage(degats, null, global_position)
			if v:
				v.balle_t = false
		elif cible.has_method("take_hit"):
			cible.take_hit(degats * 1.5, vise, global_position)
	else:
		# balle perdue : impact dans le décor près de la cible
		var rate := vise + Vector3(randf_range(-1.2, 1.2), randf_range(-0.6, 0.8), randf_range(-1.2, 1.2))
		var q := PhysicsRayQueryParameters3D.create(bouche, bouche + (rate - bouche).normalized() * (dist + 6.0), Game.LAYER_WORLD, [get_rid()])
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		if not h.is_empty():
			Effets.impact(get_parent(), h.position, h.normal, false)


# ---------------------------------------------------------------- dégâts
func take_hit(dmg: float, pos: Vector3, from: Vector3) -> void:
	if state == MORT:
		return
	var tete := pos.y > global_position.y + 1.5
	Game.signaler_degats(self, dmg * (2.5 if tete else 1.0), health, pos, from, tete)
	health -= dmg * (2.5 if tete else 1.0)
	if corps_v:
		corps_v.coup(from, clampf(dmg / 30.0, 0.3, 1.2))
	var p = Game.player
	var par_joueur: bool = p != null and from.distance_to(p.global_position) < 3.0
	if par_joueur:
		Game.hit_confirmed.emit(tete, health <= 0.0)
	if health <= 0.0:
		_mourir(par_joueur)
		return
	if anim_lock <= 0.0:
		_anim("touche", 1.2, 0.3)
	if par_joueur and p.alive:
		cible = p
		perdu_t = 0.0
		_alerter_camp(p.global_position)
		if state != REPLI:
			state = COMBAT
	# gravement blessé : repli à couvert (une fois)
	if not deja_replie and health < pv_max * 0.4:
		deja_replie = true
		state = REPLI
		repli_t = randf_range(9.0, 14.0)
		_choisir_abri(from)


## Point derrière le muret (ou l'épave) le plus proche, du côté opposé à la menace.
## Sans abri : on s'éloigne de la menace.
func _choisir_abri(menace: Vector3) -> void:
	var camp_n := get_parent()
	var meilleur := 9999.0
	abri = global_position + _plat(global_position - menace).normalized() * 10.0
	var liste: Array = camp_n.get("abris") if camp_n and camp_n.get("abris") != null else []
	for c in liste:
		var cv: Vector3 = c
		var derriere: Vector3 = cv + _plat(cv - menace).normalized() * 0.9
		var d := global_position.distance_to(derriere)
		if d < meilleur and d < 25.0:
			meilleur = d
			abri = derriere


func take_damage(amount: float, _from: Node = null) -> void:
	take_hit(amount, global_position + Vector3.UP, global_position)


func repousser(dir: Vector3, force: float, duree: float) -> void:
	velocity += _plat(dir).normalized() * force
	etourdi = maxf(etourdi, duree)


func ralentir(duree: float, facteur: float) -> void:
	ralenti_t = maxf(ralenti_t, duree)
	ralenti_k = facteur


func _mourir(par_joueur: bool) -> void:
	state = MORT
	if pieds_ik:
		pieds_ik.active = false
	if bras_ik:
		bras_ik.poids = 0.0
		bras_ik.arme = null
	remove_from_group("bandits")
	collision_layer = 0
	velocity = Vector3.ZERO
	if corps_v:
		corps_v.active = false
	# chute sur un côté ou sur l'autre, ou effondrement sur place (« se relever » joué à l'envers)
	var r := randf()
	if r < 0.3 and pap and pap.has_animation("relever"):
		anim_lock = 99.0
		pap.speed_scale = 1.0
		pap.play("relever", 0.15, -1.15, true)
		anim = "relever"
	else:
		_anim("mort_miroir" if r < 0.65 else "mort", 1.0, 99.0)
	if par_joueur and Game.player:
		Game.player.prog.gagner("combat", 70)
		Game.player.gagner_argent(randi_range(10, 40))
		preload("res://scripts/journal.gd").compter("bandits")   # journal du survivant
	_lacher_butin()


## Arme, munitions et un petit quelque chose au sol, à côté du corps.
func _lacher_butin() -> void:
	var pile = LootContainer.new()
	pile.setup("Affaires du bandit", "", Vector3(0.7, 0.12, 0.7), Color(0.3, 0.3, 0.3))
	pile.make_storage(6, 4)
	pile.add_to_group("tas_sol")
	var monde: Node = Game.player.get_parent() if Game.player else get_parent()
	monde.add_child(pile)   # dans la scène principale : sauvegardé avec les tas au sol
	pile.global_position = global_position + global_basis.x * 0.7
	pile.grille.ajouter_entree({"id": arme, "n": 1, "x": 0, "y": 0, "r": false, "contenu": null})
	var mun := str(Items.info(arme).get("ammo", ""))
	if mun != "":
		pile.grille.ajouter(mun, randi_range(6, 24))
	var bonus: String = ["bandage", "conserve", "eau", "alcool", "antidouleur", "ferraille"].pick_random()
	pile.grille.ajouter(bonus, 1)
	pile.mesh_i.visible = false
	if arme_noeud and is_instance_valid(arme_noeud):
		arme_noeud.get_parent().remove_child(arme_noeud)
		pile.add_child(arme_noeud)
		arme_noeud.transform = Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), Vector3(0, 0.035, 0))
		arme_noeud = null


func _mort_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITE * delta
		move_and_slide()
	mort_t += delta
	if mort_t > 120.0 and Game.player and global_position.distance_to(Game.player.global_position) > 60.0:
		queue_free()


# ---------------------------------------------------------------- animations
func _anim(nom: String, vitesse := 1.0, verrou := 0.0) -> void:
	if pap == null or not pap.has_animation(nom):
		return
	if verrou > 0.0:
		anim_lock = verrou
		pap.play(nom, 0.1)
		pap.seek(0.0)
	elif anim != nom:
		pap.play(nom)
	anim = nom
	pap.speed_scale = vitesse


func _animer(vitesse: float) -> void:
	if anim_lock > 0.0:
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	if state == REPLI:
		_anim("course" if hs > 2.0 else "accroupi", clampf(hs / 3.1, 0.8, 1.6) if hs > 2.0 else 1.0)
		return
	if state == COMBAT:
		if hs > 2.5:
			_anim("jogging", clampf(hs / 2.4, 0.7, 1.6) * (-1.0 if recule else 1.0))
		elif hs > 0.4:
			_anim("marche", clampf(hs / 0.94, 0.6, 1.8) * (-1.0 if recule else 1.0))
		else:
			_anim("visee")
	elif hs > 2.0:
		_anim("jogging", clampf(hs / 2.4, 0.7, 1.6))
	elif hs > 0.3:
		_anim("marche", clampf(hs / 0.94, 0.6, 1.8))
	else:
		_anim("arme_idle" if state == ALERTE else "idle")
