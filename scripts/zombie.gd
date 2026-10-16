extends CharacterBody3D
## Zombie : erre, entend les bruits, voit le joueur (moins bien la nuit),
## poursuit, attaque, passe par les portes des bâtiments, frappe les barricades.
## Une fois mort, le corps peut être fouillé.

enum State { WANDER, INVESTIGATE, CHASE, DEAD }

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
var dead_t := 0.0
var searched := false
var groan_t := 0.0
var echelle := 1.0          # taille du modèle (le boss est un géant)
var est_boss := false
var charge_t := 0.0         # boss : temps de charge restant
var charge_cd := 6.0        # boss : délai avant la prochaine charge
var charge_dir := Vector3.ZERO
var charge_touche := false
var slam_cd := 4.0          # boss : délai avant le prochain coup au sol
var slam_t := -1.0          # boss : temps avant l'impact du coup au sol

@onready var modele: Node3D = $Modele
var ap: AnimationPlayer = null      # animations du modèle Blender (si présent)
var anim_lock := 0.0                # durée pendant laquelle une animation ponctuelle joue
var cur_anim := ""
var anim_noms := {}                 # nom générique -> nom dans le modèle
const ANIMS_UAL := {"idle": "z_idle", "marche": "z_marche", "course": "course", "attaque": "z_attaque",
		"touche": "touche", "mort": "mort"}

const ModeleUtil = preload("res://scripts/modele_util.gd")
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
		"boss":
			est_boss = true
			health = 2500.0
			armor = 0.3
			damage = 35.0
			run_speed = 3.4
			echelle = 1.8
	if est_boss:
		walk_speed = 1.0
		return
	if Game.is_night() and randf() < 0.3:
		run_speed += 1.3  # coureurs nocturnes
	walk_speed = randf_range(0.8, 1.3)


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
	if est_boss:
		add_to_group("boss")
		modele.scale = Vector3.ONE * echelle
		var cs: CollisionShape3D = $Collision
		var cap := CapsuleShape3D.new()
		cap.radius = 0.33 * echelle
		cap.height = 1.8 * echelle
		cs.shape = cap
		cs.position.y = 0.9 * echelle


func _apply_look() -> void:
	var m: Node3D = null
	if Perso.disponible():
		# personnage réaliste (mannequin UAL habillé par perso.gdshader)
		m = Perso.creer(Perso.apparence(kind))
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
		if ap:
			ModeleUtil.boucler(ap, ["idle", "marche", "course"])
			ap.playback_default_blend_time = 0.2
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


# ================================================================ boucle
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_dead_process(delta)
		return
	var p = Game.player
	# endormi si loin du joueur (économise le processeur)
	if dormant:
		dormant_t -= delta
		if dormant_t > 0.0:
			return
		dormant_t = 1.0
	var dist := 9999.0
	if p:
		dist = global_position.distance_to(p.global_position)
	dormant = dist > 90.0 and state != State.CHASE
	if ap:
		ap.active = not dormant
	if dormant:
		return
	think_t -= delta
	if think_t <= 0.0:
		think_t = 0.25
		_think()
	var raw := _raw_target()
	var goal := _route(raw)
	var routed := not goal.is_equal_approx(raw)
	var speed := run_speed if state == State.CHASE else walk_speed
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
		desired = _steer(to_goal.normalized(), delta)
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
	if est_boss:
		_boss_update(delta, p)
	if state == State.CHASE and p and p.alive:
		var flat := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if flat < 1.5 * (1.6 if est_boss else 1.0) and absf(p.global_position.y - global_position.y) < 1.5 * echelle and attack_t <= 0.0 and charge_t <= 0.0 and slam_t < 0.0:
			attack_t = 1.7 if est_boss else 1.1
			lunge = 1.0
			_anim("attaque", 1.0, 0.8)
			Game.play_3d("attaque_zombie", global_position + Vector3.UP * 1.5, 0.0, 0.15, 30.0)
			p.take_damage(damage, self)
	# bruit de grognement (attire les autres de près)
	groan_t -= delta
	if groan_t <= 0.0:
		groan_t = randf_range(6.0, 14.0) if state != State.CHASE else randf_range(2.5, 5.0)
		if dist < 45.0:
			Game.play_3d("grogne%d" % randi_range(1, 3), global_position + Vector3.UP * 1.6, -6.0 if state != State.CHASE else -1.0, 0.2, 45.0)
		if state == State.CHASE:
			Game.make_noise(global_position, 10.0)


func _think() -> void:
	var p = Game.player
	if p == null or not p.alive:
		if state == State.CHASE:
			state = State.WANDER
		_wander_update()
		return
	var to_p: Vector3 = p.global_position - global_position
	var dist := to_p.length()
	var sight := 24.0
	if Game.is_night():
		sight = 10.0 + (10.0 if p.flashlight_on else 0.0)
	if p.crouching:
		sight *= 0.55
	if p.prog.a("discret"):
		sight *= 0.7
	if not p.in_zone.is_empty() and not is_same(p.in_zone, Game.find_zone(global_position + Vector3.UP)):
		sight *= 0.6
	var sees := false
	if dist < sight:
		var fwd := -global_basis.z
		var facing := fwd.dot(to_p.normalized()) > 0.1
		if dist < 3.0 or facing or state == State.CHASE:
			sees = _line_of_sight(p)
	if sees:
		state = State.CHASE
		target = p.global_position
		lost_t = 0.0
	elif state == State.CHASE:
		lost_t += 0.25
		if lost_t > 4.0:
			state = State.INVESTIGATE
	elif state == State.INVESTIGATE:
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


func _on_noise(pos: Vector3, radius: float) -> void:
	if state == State.DEAD or state == State.CHASE:
		return
	if global_position.distance_to(pos) <= radius:
		state = State.INVESTIGATE
		target = pos + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		dormant = false


# ================================================================ déplacement
func _raw_target() -> Vector3:
	if state == State.CHASE and Game.player:
		return Game.player.global_position
	return target


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
	var headshot := pos.y > global_position.y + 1.45 * echelle
	if headshot:
		dmg *= 2.5
	else:
		dmg *= (1.0 - armor)
	health -= dmg
	var push := global_position - from
	push.y = 0.0
	velocity += push.normalized() * 2.0
	state = State.CHASE
	lost_t = 0.0
	dormant = false
	var killed := health <= 0.0
	if not killed and anim_lock <= 0.0:
		_anim("touche", 1.0, 0.35)
	Game.hit_confirmed.emit(headshot, killed)
	if killed:
		_die()


func take_damage(amount: float, _from: Node = null) -> void:
	take_hit(amount, global_position, global_position)


const XP_TYPE := {"civil": 20, "patient": 25, "police": 35, "militaire": 50, "boss": 600}


func _die() -> void:
	if Game.player and state != State.DEAD:
		Game.player.prog.gagner("combat", XP_TYPE.get(kind, 20))
		if est_boss:
			Game.player.prog.gagner("exploration", 200)
			Game.msg("Le Colosse est tombé ! Fouille son corps et la cache au fond de la grotte.")
			Game.play_3d("grogne1", global_position + Vector3.UP * 2.5, 6.0, 0.0, 120.0)
			remove_from_group("boss")
	charge_t = 0.0
	slam_t = -1.0
	state = State.DEAD
	remove_from_group("zombies")
	add_to_group("corpses")
	collision_layer = Game.LAYER_INTERACT
	collision_mask = Game.LAYER_WORLD
	velocity = Vector3.ZERO
	if ap:
		ap.active = true
		_anim("mort", 1.0, 99.0)
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
		return ""
	if searched and grille and grille.vide():
		return "Corps (vide)"
	return "[F] Fouiller le corps"


func interact(player: Node) -> void:
	if state != State.DEAD:
		return
	if grille == null:
		searched = true
		grille = Grille.creer("Corps", 6 if est_boss else 4, 6 if est_boss else 4)
		player.prog.gagner("exploration", 4)
		var found := Items.roll_loot("zombie_" + kind, 6 if est_boss else 2, 0.0 if est_boss else 0.35)
		for id in found:
			if Items.grid(id).x > 0:
				grille.ajouter_entree(player.nouvelle_entree(id))
			else:
				grille.ajouter(id, int(found[id]))
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
	if anim_lock > 0.0:
		anim_lock -= delta
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	hs /= echelle
	if hs > 2.0 / echelle:
		_anim("course", clampf(hs / (3.1 if anim_noms else 3.0), 0.6, 1.8))
	elif hs > 0.15:
		_anim("marche", clampf(hs / (0.95 if anim_noms else 0.65), 0.5, 2.2))
	else:
		_anim("idle")



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
		Game.play_3d("grogne2", global_position + Vector3.UP * 2.5, 6.0, 0.0, 90.0)
		_anim("course", 1.6)
	elif dist < 3.6 and slam_cd <= 0.0:
		slam_cd = randf_range(5.0, 8.0)
		slam_t = 0.7
		charge_dir = Vector3.ZERO
		_anim("attaque", 0.7, 1.1)
		Game.play_3d("grogne3", global_position + Vector3.UP * 2.5, 6.0, 0.0, 90.0)
