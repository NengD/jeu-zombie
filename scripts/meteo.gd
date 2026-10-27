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
## Saisons : averses plus ou moins fréquentes (Saisons.pluie), neige en hiver (Saisons.neige) ;
## la neige tient au sol (enneige 0..1 → uniforme « neige » du sol, terrain.gdshader) et fond hors de l'hiver.
const Saisons = preload("res://scripts/saisons.gd")
var neige := false              # l'averse en cours tombe en neige
var enneige := 0.0
var mat_sol: ShaderMaterial = null
var _neige_sol := -1.0
var _style_neige := false
var mat_goutte: StandardMaterial3D
var quad_goutte: QuadMesh
## Neige sur les routes, trottoirs, toits, pelouses : couche de détail (blanc) des matériaux partagés du monde,
## dosée par une texture 1×1 (masque) mise à jour ; aucune ShaderMaterial, aucun nœud en plus.
const MATS_NEIGE := ["asphalte", "trottoir", "toit", "tuiles", "herbe", "terre"]
var _img_masque: Image
var tex_masque: ImageTexture
var tex_blanc: ImageTexture
var _neige_mats := -1.0
## Lacs gelés (Saisons.gel) : glace dans le shader de l'eau des lacs, sol solide (cylindres de collision).
var mat_lacs: ShaderMaterial = null
var gel := 0.0
var _gel_mat := -1.0
var glace: StaticBody3D = null
var _debut := true
## Traces de pas dans la neige : décalques recyclés (TRACES_MAX), effacés en TRACE_DUREE secondes.
const TRACES_MAX := 40
const TRACE_DUREE := 75.0
var traces: Array = []          # Decal
var _trace_i := 0
var _pied_g := false
var tex_trace: ImageTexture


func installer(p_world: Node, graine: int) -> void:
	world = p_world
	add_to_group("meteo")
	mat_lacs = world.get("mat_lacs")
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
	mat_goutte = m
	quad_goutte = q
	add_child(gouttes)


## Gouttes ou flocons : mêmes particules, réglées autrement (flocons lents, blancs, qui dérivent).
func _style(flocons: bool) -> void:
	if flocons == _style_neige:
		return
	_style_neige = flocons
	var pm: ParticleProcessMaterial = gouttes.process_material
	if flocons:
		gouttes.lifetime = 7.0
		pm.direction = Vector3(0.2, -1, 0.1)
		pm.spread = 25.0
		pm.initial_velocity_min = 1.4
		pm.initial_velocity_max = 2.4
		pm.gravity = Vector3(0, -0.6, 0)
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.6
		pm.particle_flag_align_y = false
		quad_goutte.size = Vector2(0.06, 0.06)
		mat_goutte.albedo_color = Color(0.95, 0.96, 1.0, 0.85)
	else:
		gouttes.lifetime = 1.1
		pm.direction = Vector3(0.15, -1, 0.05)
		pm.spread = 3.0
		pm.initial_velocity_min = 16.0
		pm.initial_velocity_max = 20.0
		pm.gravity = Vector3(0, -9.8, 0)
		pm.turbulence_enabled = false
		pm.particle_flag_align_y = true
		quad_goutte.size = Vector2(0.012, 0.45)
		mat_goutte.albedo_color = Color(0.75, 0.8, 0.85, 0.28)


## Matériau du sol (partagé par toutes les tuiles du relief, construites à l'approche du joueur).
func _materiau_sol() -> ShaderMaterial:
	var sol: Node = world.get_node_or_null("Sol") if world else null
	if sol == null:
		return null
	for t in sol.get_children():
		if t is MeshInstance3D and t.mesh:
			var m = t.material_override if t.material_override else t.mesh.surface_get_material(0)
			if m is ShaderMaterial:
				return m
	return null


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
	son.bus = "Ambiance"
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
			prochain = randf_range(300.0, 900.0) / Saisons.pluie()   # temps sec plus court en automne, plus long en été
		else:
			cible = randf_range(0.45, 1.0)
			prochain = randf_range(120.0, 360.0)
			neige = randf() < Saisons.part_neige()
			Game.msg("Il commence à neiger." if neige else "Il commence à pleuvoir.")
	Game.pluie = move_toward(Game.pluie, cible, delta / 25.0)
	if Game.pluie <= 0.0 and neige and not Saisons.neige():
		neige = false
	Game.neige = neige and Game.pluie > 0.05
	if _debut:
		# partie chargée en plein hiver : déjà de la neige au sol et des lacs gelés (état non sauvegardé)
		_debut = false
		if Saisons.neige() and Saisons.jour_de_saison() >= 2:
			enneige = 0.7
		gel = 1.0 if Saisons.gel() else 0.0
	var tombe := Game.pluie > 0.15
	# la neige ne mouille pas (pas de flaques) : elle tient au sol, puis fond (vite hors de l'hiver)
	mouille = move_toward(mouille, 1.0 if tombe and not neige else 0.0, delta / (20.0 if tombe and not neige else 120.0))
	if tombe and neige:
		enneige = move_toward(enneige, 1.0, delta * Game.pluie / 90.0)
	elif tombe:
		enneige = move_toward(enneige, 0.0, delta / 180.0)   # redoux : la pluie fait fondre la neige
	else:
		enneige = move_toward(enneige, 0.0, delta / (900.0 if Saisons.neige() else 120.0))
	Game.enneige = enneige
	_maj_sol_enneige()
	_maj_mats_enneiges()
	_maj_gel(delta)
	_maj_traces(delta)
	var p = Game.player
	if p == null:
		return
	var dedans: bool = not p.in_zone.is_empty()
	# gouttes au-dessus du joueur (pas à l'intérieur)
	_style(neige)
	gouttes.global_position = p.global_position + Vector3(0, 12 if not neige else 9, 0) + p.velocity * (0.6 if not neige else 3.0)
	gouttes.emitting = Game.pluie > 0.05 and not dedans and Game.qualite >= 1
	gouttes.amount_ratio = clampf(Game.pluie * (0.5 if neige else 1.0), 0.1, 1.0)
	# son : étouffé à l'intérieur ; la neige tombe presque sans bruit
	var vol := Game.pluie * (0.35 if dedans else 1.0) * (0.12 if neige else 1.0)
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


## Neige au sol : une seule valeur passée au matériau partagé du relief (aucun coût de rendu en plus).
func _maj_sol_enneige() -> void:
	if mat_sol == null:
		if enneige <= 0.0:
			return
		mat_sol = _materiau_sol()
		if mat_sol == null:
			return
	if absf(enneige - _neige_sol) < 0.01 and not (enneige == 0.0 and _neige_sol != 0.0):
		return
	_neige_sol = enneige
	mat_sol.set_shader_parameter("neige", enneige)
	var details := get_parent().get_node_or_null("DetailsMonde") if get_parent() else null
	if details and details.get("herbe_mat"):
		details.herbe_mat.set_shader_parameter("neige", enneige)


## Neige sur les matériaux partagés du monde (routes, trottoirs, toits, pelouses) : couche de détail blanche
## dosée par un masque 1×1. La couche n'est active que tant qu'il y a de la neige (rien à payer le reste de l'année).
func _maj_mats_enneiges() -> void:
	var v := snappedf(enneige * 0.8, 0.01)
	if v == _neige_mats:
		return
	_neige_mats = v
	if tex_masque == null:
		_img_masque = Image.create(1, 1, false, Image.FORMAT_L8)
		_img_masque.fill(Color.BLACK)
		tex_masque = ImageTexture.create_from_image(_img_masque)
		var blanc := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		blanc.fill(Color(0.86, 0.88, 0.93))
		tex_blanc = ImageTexture.create_from_image(blanc)
	_img_masque.fill(Color(v, v, v))
	tex_masque.update(_img_masque)
	var actif := v > 0.0
	for nom in MATS_NEIGE:
		var m = world.mats.get(nom) if world else null
		if m is StandardMaterial3D and m.detail_enabled != actif:
			m.detail_enabled = actif
			m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			m.detail_albedo = tex_blanc
			m.detail_mask = tex_masque


## Lacs gelés : glace qui prend en une minute (shader « gel » des lacs), sol solide une fois prise ;
## dégel au printemps (la glace cède : on retombe à l'eau).
func _maj_gel(delta: float) -> void:
	gel = move_toward(gel, 1.0 if Saisons.gel() else 0.0, delta / 60.0)
	var pris := gel >= 0.9
	if pris != Game.lacs_geles:
		Game.lacs_geles = pris
		_poser_glace(pris)
		if Game.player and Game.relief and Game.relief.dans_lac(Game.player.global_position.x, Game.player.global_position.z):
			Game.msg("Le lac est gelé : on peut marcher dessus." if pris else "La glace cède : le lac dégèle.")
	if mat_lacs:
		var g := snappedf(gel, 0.01) + snappedf(enneige if pris else 0.0, 0.01) * 10.0
		if g != _gel_mat:
			_gel_mat = g
			mat_lacs.set_shader_parameter("gel", snappedf(gel, 0.01))
			mat_lacs.set_shader_parameter("neige", snappedf(enneige, 0.01) if pris else 0.0)


func _poser_glace(pris: bool) -> void:
	if not pris:
		if glace:
			glace.queue_free()
			glace = null
		return
	if glace or Game.relief == null:
		return
	glace = StaticBody3D.new()
	glace.name = "Glace"
	glace.collision_layer = Game.LAYER_WORLD
	glace.collision_mask = 0
	add_child(glace)
	var niv: float = Game.relief.NIVEAU_EAU
	for l in Game.relief.lacs:
		var cy := CylinderShape3D.new()
		cy.radius = float(l.r) * 1.35 * 1.15
		cy.height = 0.4
		var cs := CollisionShape3D.new()
		cs.shape = cy
		var c: Vector2 = l.c
		cs.position = Vector3(c.x, niv - 0.2, c.y)
		glace.add_child(cs)
	# joueur en train de nager : remonté sur la glace (sinon pris dessous)
	var p = Game.player
	if p and Game.relief.dans_lac(p.global_position.x, p.global_position.z) and p.global_position.y < niv + 0.05:
		p.global_position.y = niv + 0.1
		p.velocity.y = 0.0


## Trace de pas dans la neige (appelée par player.gd à chaque pas dehors) ; yaw = direction de la marche.
func trace_pas(pos: Vector3, yaw: float) -> void:
	if enneige < 0.25:
		return
	if traces.is_empty():
		_creer_traces()
	_pied_g = not _pied_g
	var d: Decal = traces[_trace_i]
	_trace_i = (_trace_i + 1) % TRACES_MAX
	var droite := Vector3(cos(yaw), 0.0, -sin(yaw))
	d.global_position = pos + droite * (-0.12 if _pied_g else 0.12)
	d.rotation = Vector3(0.0, yaw, 0.0)
	d.set_meta("t", 0.0)
	d.visible = true


func _creer_traces() -> void:
	# empreinte de semelle (bout arrondi, talon séparé) : creux bleu-gris dans la neige
	var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 32:
			var u := (x - 15.5) / 16.0
			var a := 0.0
			if y < 40:
				var v := (y - 21.0) / 20.0
				a = 1.0 - (u * u * 1.15 + v * v)
			else:
				var v2 := (y - 51.0) / 11.0
				a = 1.0 - (u * u * 1.6 + v2 * v2)
			img.set_pixel(x, y, Color(0.42, 0.47, 0.56, clampf(a * 3.0, 0.0, 0.85)))
	img.generate_mipmaps()
	tex_trace = ImageTexture.create_from_image(img)
	for i in TRACES_MAX:
		var d := Decal.new()
		d.texture_albedo = tex_trace
		d.size = Vector3(0.13, 0.5, 0.3)
		d.upper_fade = 0.2
		d.lower_fade = 0.2
		d.distance_fade_enabled = true
		d.distance_fade_begin = 30.0
		d.distance_fade_length = 10.0
		d.visible = false
		add_child(d)
		traces.append(d)


func _maj_traces(delta: float) -> void:
	for d in traces:
		if not d.visible:
			continue
		var t: float = d.get_meta("t") + delta
		d.set_meta("t", t)
		d.albedo_mix = clampf(1.0 - t / TRACE_DUREE, 0.0, 1.0) * clampf(enneige * 2.0, 0.0, 1.0)
		if t >= TRACE_DUREE or enneige < 0.1:
			d.visible = false


## Admin / tests : neige qui tombe tout de suite (et tient au sol si « au_sol »).
func forcer_neige(au_sol := false) -> void:
	neige = true
	cible = 1.0
	prochain = randf_range(240.0, 480.0)
	if au_sol:
		enneige = maxf(enneige, 0.8)
	Game.msg("Il commence à neiger.")
