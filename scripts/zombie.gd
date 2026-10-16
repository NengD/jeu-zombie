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

@onready var modele: Node3D = $Modele
var ap: AnimationPlayer = null      # animations du modèle Blender (si présent)
var anim_lock := 0.0                # durée pendant laquelle une animation ponctuelle joue
var cur_anim := ""

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


func _apply_look() -> void:
	var m := ModeleUtil.charger("res://modeles/%s.glb" % MODELES.get(kind, "zombie_civil"))
	if m:
		for c in modele.get_children():
			c.queue_free()
		modele.add_child(m)
		ModeleUtil.distance_visible(m, 160.0)
		if kind == "civil":
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
	var desired := Vector3.ZERO
	var to_goal := goal - global_position
	to_goal.y = 0.0
	var stop_dist := 1.1 if state == State.CHASE else 0.6
	if routed:
		stop_dist = 0.05
	if to_goal.length() > stop_dist:
		desired = _steer(to_goal.normalized(), delta)
	velocity.x = move_toward(velocity.x, desired.x * speed, 10.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z * speed, 10.0 * delta)
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
	if state == State.CHASE and p and p.alive:
		var flat := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if flat < 1.5 and absf(p.global_position.y - global_position.y) < 1.5 and attack_t <= 0.0:
			attack_t = 1.1
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
		if Vector2(target.x - global_position.x, target.z - global_position.z).length() < 1.5:
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
	if is_same(zs, zt):
		return to
	if not zs.is_empty():
		var d := _nearest_door(zs, to)
		if d.is_empty():
			return to
		if _flat_dist(global_position, d.pos) < 1.9:
			return d.out
		return d.inn
	if not zt.is_empty():
		var d2 := _nearest_door(zt, global_position)
		if d2.is_empty():
			return to
		if _flat_dist(global_position, d2.pos) < 1.9:
			return d2.inn
		return d2.out
	return to


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
	for a in [0.6, -0.6, 1.2, -1.2, 1.8, -1.8]:
		var d := dir.rotated(Vector3.UP, a)
		if _blocked(d) == null:
			detour_dir = d
			detour_t = 0.5
			return d
	return dir


func _blocked(d: Vector3) -> Variant:
	var from := global_position + Vector3.UP * 0.9
	var q := PhysicsRayQueryParameters3D.create(from, from + d * 1.2, Game.LAYER_WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	return hit.collider


# ================================================================ dégâts / mort
func take_hit(dmg: float, pos: Vector3, from: Vector3) -> void:
	if state == State.DEAD:
		return
	var headshot := pos.y > global_position.y + 1.45
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


func _die() -> void:
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


func get_prompt() -> String:
	if state != State.DEAD:
		return ""
	return "Corps (déjà fouillé)" if searched else "[F] Fouiller le corps"


func interact(player: Node) -> void:
	if state != State.DEAD:
		return
	if searched:
		Game.msg("Ce corps a déjà été fouillé.")
		return
	searched = true
	var found := Items.roll_loot("zombie_" + kind, 2, 0.35)
	if found.is_empty():
		Game.msg("Rien sur ce corps.")
		return
	for id in found:
		player.add_item(id, found[id])
	Game.msg("Sur le corps : " + Items.describe(found))


# ================================================================ animations
func _anim(nom: String, vitesse := 1.0, verrou := 0.0) -> void:
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
	if hs > 2.0:
		_anim("course", clampf(hs / 3.0, 0.6, 1.8))
	elif hs > 0.15:
		_anim("marche", clampf(hs / 0.65, 0.5, 2.2))
	else:
		_anim("idle")
