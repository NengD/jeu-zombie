extends Node3D
## Météo : averses qui vont et viennent. Pendant la pluie : gouttes autour du joueur, bruit de pluie,
## ciel plus sombre et brumeux (day_night.gd lit Game.pluie), sols et murs mouillés qui brillent,
## flaques qui reflètent le décor, et la pluie couvre le bruit (les zombies entendent moins loin).

var world: Node
var gouttes: GPUParticles3D
var son: AudioStreamPlayer
var flaques: Array = []         # MeshInstance3D
var mat_flaque: StandardMaterial3D
var rugosites := {}             # matériau -> rugosité d'origine
var cible := 0.0                # intensité visée (0 = sec, 1 = averse)
var prochain := 0.0             # secondes avant le prochain changement de temps
var mouille := 0.0              # sols mouillés (sèchent lentement après la pluie)


func installer(p_world: Node, graine: int) -> void:
	world = p_world
	var rng := RandomNumberGenerator.new()
	rng.seed = graine + 3131
	prochain = rng.randf_range(240.0, 600.0)
	_creer_gouttes()
	_creer_son()
	_creer_flaques(rng)
	for m in world.mats.values():
		if m is StandardMaterial3D:
			rugosites[m] = m.roughness


func _creer_gouttes() -> void:
	gouttes = GPUParticles3D.new()
	gouttes.amount = 9000
	gouttes.lifetime = 1.1
	gouttes.preprocess = 1.0
	gouttes.visibility_aabb = AABB(Vector3(-25, -25, -25), Vector3(50, 50, 50))
	gouttes.local_coords = false
	gouttes.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 1, 22)
	pm.direction = Vector3(0.15, -1, 0.05)
	pm.spread = 3.0
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 20.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	gouttes.process_material = pm
	# trait de pluie : quad étiré, orienté selon la vitesse
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.45)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 0.8, 0.85, 0.28)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	pm.particle_flag_align_y = true
	gouttes.draw_pass_1 = q
	gouttes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gouttes)


## Bruit de pluie généré (bruit rose filtré, en boucle).
func _creer_son() -> void:
	var rate := 22050
	var n := rate * 3
	var data := PackedByteArray()
	data.resize(n * 2)
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	for i in n:
		var w := r.randf_range(-1.0, 1.0)
		b0 = 0.99765 * b0 + w * 0.099
		b1 = 0.963 * b1 + w * 0.2965
		b2 = 0.57 * b2 + w * 1.0527
		var s := (b0 + b1 + b2 + w * 0.1848) * 0.11
		# crépitement des gouttes
		if r.randf() < 0.004:
			s += r.randf_range(-0.5, 0.5)
		# fondu aux extrémités pour une boucle sans clic
		var f := minf(1.0, minf(i, n - i) / 2000.0)
		data.encode_s16(i * 2, int(clampf(s * f, -1.0, 1.0) * 30000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.data = data
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = n
	son = AudioStreamPlayer.new()
	son.stream = st
	son.volume_db = -60.0
	add_child(son)


## Flaques sur les routes de la ville et de la campagne : surfaces sombres et lisses (reflets SSR).
func _creer_flaques(rng: RandomNumberGenerator) -> void:
	mat_flaque = StandardMaterial3D.new()
	mat_flaque.albedo_color = Color(0.02, 0.025, 0.03, 0.0)
	mat_flaque.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_flaque.roughness = 0.02
	mat_flaque.metallic = 0.0
	mat_flaque.metallic_specular = 0.9
	var forme := CylinderMesh.new()
	forme.top_radius = 1.0
	forme.bottom_radius = 1.0
	forme.height = 0.01
	forme.radial_segments = 20
	forme.material = mat_flaque
	var demi: float = Game.city_half
	var poses := 0
	for k in 900:
		if poses >= 220:
			break
		var p := Vector3(rng.randf_range(-demi, demi), 0, rng.randf_range(-demi, demi))
		if not Game.find_zone(p + Vector3.UP).is_empty():
			continue
		# sur la chaussée : près des axes de routes (tous les BLOCK mètres)
		var bloc: float = world.BLOCK
		var dx := absf(fposmod(p.x + demi, bloc) - 0.0)
		var dz := absf(fposmod(p.z + demi, bloc) - 0.0)
		if minf(minf(dx, bloc - dx), minf(dz, bloc - dz)) > world.ROAD / 2.0 - 0.6:
			continue
		var f := MeshInstance3D.new()
		f.mesh = forme
		f.position = Vector3(p.x, 0.022, p.z)
		f.rotation.y = rng.randf() * TAU
		f.scale = Vector3(rng.randf_range(0.6, 2.4), 1.0, rng.randf_range(0.4, 1.4))
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.visibility_range_end = 90.0
		f.visible = false
		add_child(f)
		flaques.append(f)
		poses += 1


func _process(delta: float) -> void:
	# changement de temps
	prochain -= delta
	if prochain <= 0.0:
		if cible > 0.0:
			cible = 0.0
			prochain = randf_range(300.0, 900.0)
		else:
			cible = randf_range(0.45, 1.0)
			prochain = randf_range(120.0, 360.0)
			Game.msg("Il commence à pleuvoir.")
	Game.pluie = move_toward(Game.pluie, cible, delta / 25.0)
	mouille = move_toward(mouille, 1.0 if Game.pluie > 0.15 else 0.0, delta / (20.0 if Game.pluie > 0.15 else 120.0))
	var p = Game.player
	if p == null:
		return
	var dedans: bool = not p.in_zone.is_empty()
	# gouttes au-dessus du joueur (pas à l'intérieur)
	gouttes.global_position = p.global_position + Vector3(0, 12, 0) + p.velocity * 0.6
	gouttes.emitting = Game.pluie > 0.05 and not dedans and Game.qualite >= 1
	gouttes.amount_ratio = clampf(Game.pluie, 0.1, 1.0)
	# son : étouffé à l'intérieur
	var vol := Game.pluie * (0.35 if dedans else 1.0)
	if vol > 0.01:
		if not son.playing:
			son.play()
		son.volume_db = linear_to_db(vol) - 8.0
	elif son.playing:
		son.stop()
	# sols mouillés : les matériaux deviennent brillants, les flaques apparaissent
	for m in rugosites:
		m.roughness = lerpf(rugosites[m], rugosites[m] * 0.35, mouille)
	mat_flaque.albedo_color.a = 0.85 * mouille
	var montre := mouille > 0.02
	for f in flaques:
		f.visible = montre
