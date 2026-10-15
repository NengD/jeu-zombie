extends Node
## Cycle jour / nuit : soleil, lune, ciel, brouillard.

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial

const DAY_TOP := Color(0.38, 0.5, 0.66)
const DAY_HORIZON := Color(0.68, 0.68, 0.64)
const NIGHT_TOP := Color(0.01, 0.015, 0.035)
const NIGHT_HORIZON := Color(0.03, 0.04, 0.06)
const DUSK_HORIZON := Color(0.75, 0.42, 0.25)


func _ready() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.ground_bottom_color = Color(0.1, 0.1, 0.09)
	sky_mat.ground_horizon_color = Color(0.4, 0.4, 0.38)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_sky_affect = 0.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.8
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)
	_apply()


func _process(delta: float) -> void:
	Game.time_hours += delta * 24.0 / Game.DAY_SECONDS
	if Game.time_hours >= 24.0:
		Game.time_hours -= 24.0
		Game.day += 1
		Game.msg("Jour %d" % Game.day)
	_apply()


func _apply() -> void:
	var h := Game.time_hours
	var t := (h - 6.0) / 14.5            # 0 = lever (6 h), 1 = coucher (20 h 30)
	var elev := sin(clampf(t, 0.0, 1.0) * PI) if (t >= 0.0 and t <= 1.0) else -0.3
	var daylight := smoothstep(-0.02, 0.3, elev)
	var dusk := clampf(1.0 - absf(elev) * 5.0, 0.0, 1.0) * (1.0 if t > -0.1 and t < 1.1 else 0.0)
	if daylight > 0.01:
		sun.rotation = Vector3(-asin(maxf(elev, 0.04)), lerpf(-PI * 0.5, PI * 0.5, clampf(t, 0.0, 1.0)), 0)
		sun.light_color = Color(1.0, 0.95, 0.88).lerp(Color(1.0, 0.6, 0.35), dusk)
		sun.light_energy = lerpf(0.0, 1.25, daylight)
	else:
		# clair de lune
		sun.rotation = Vector3(-0.75, 0.6, 0)
		sun.light_color = Color(0.55, 0.65, 0.95)
		sun.light_energy = 0.13
	var top := NIGHT_TOP.lerp(DAY_TOP, daylight)
	var hor := NIGHT_HORIZON.lerp(DAY_HORIZON, daylight).lerp(DUSK_HORIZON, dusk * 0.6)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor.darkened(0.3)
	sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.02).lerp(Color(0.1, 0.1, 0.09), daylight)
	env.ambient_light_energy = lerpf(0.4, 1.0, daylight)
	env.fog_light_color = hor.darkened(0.1)
	env.fog_light_energy = lerpf(0.3, 1.0, daylight)
