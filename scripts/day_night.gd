extends Node
## Cycle jour / nuit : soleil, lune, ciel, brouillard.

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var monde_env: WorldEnvironment
var interieur_k := 0.0     # 1 quand le joueur est dans un bâtiment (moins de brume)

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
	monde_env = WorldEnvironment.new()
	var we := monde_env
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)
	appliquer_qualite()
	Game.graphismes_changes.connect(appliquer_qualite)
	_apply()


## Effets d'éclairage selon la qualité choisie (Bas, Moyen, Élevé, Ultra).
## Élevé et Ultra : brouillard volumétrique, reflets, occlusion indirecte (SSIL), ombres douces, adaptation de l'œil.
func appliquer_qualite() -> void:
	var q: int = Game.qualite
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	# lumière ambiante minimale : les intérieurs fermés ne deviennent jamais tout noirs
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_color = Color(0.55, 0.58, 0.62)
	# adaptation de l'œil : l'image s'éclaircit peu à peu dans le noir, s'assombrit au soleil
	var cam_attr := CameraAttributesPractical.new()
	cam_attr.auto_exposure_enabled = q >= 1
	cam_attr.auto_exposure_scale = 0.4
	cam_attr.auto_exposure_speed = 0.8
	cam_attr.auto_exposure_min_sensitivity = 60.0
	cam_attr.auto_exposure_max_sensitivity = 1000.0
	monde_env.camera_attributes = cam_attr
	env.ssao_enabled = q >= 1
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssil_enabled = q >= 2
	env.ssil_radius = 4.0
	env.ssr_enabled = q >= 2
	env.ssr_max_steps = 64 if q >= 3 else 32
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.sdfgi_enabled = false   # SDFGI : intérieurs fermés délavés et flous, remplacé par SSIL + adaptation de l'œil
	env.volumetric_fog_enabled = q >= 2
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 96.0 if q >= 3 else 64.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.0
	env.fog_density = 0.0025 if q >= 2 else 0.006
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q == 0 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = [60.0, 90.0, 110.0, 140.0][q]   # au-delà, coût élevé (millions de triangles dans les ombres)
	sun.light_angular_distance = 0.6 if q >= 3 else 0.0   # ombres douces réalistes (pénombre)
	sun.shadow_blur = 1.0
	sun.light_volumetric_fog_energy = 1.0
	RenderingServer.environment_set_ssao_quality([RenderingServer.ENV_SSAO_QUALITY_LOW, RenderingServer.ENV_SSAO_QUALITY_MEDIUM,
			RenderingServer.ENV_SSAO_QUALITY_HIGH, RenderingServer.ENV_SSAO_QUALITY_ULTRA][q], q < 3, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality([RenderingServer.ENV_SSIL_QUALITY_LOW, RenderingServer.ENV_SSIL_QUALITY_LOW,
			RenderingServer.ENV_SSIL_QUALITY_HIGH, RenderingServer.ENV_SSIL_QUALITY_ULTRA][q], q < 3, 0.5, 4, 50.0, 300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(160 if q >= 3 else 96, 96 if q >= 3 else 64)
	RenderingServer.environment_set_volumetric_fog_filter_active(q >= 2)


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
	# temps de pluie : ciel gris et bas, soleil voilé
	var gris := Color(0.42, 0.44, 0.46).lerp(Color(0.03, 0.035, 0.04), 1.0 - daylight)
	top = top.lerp(gris, Game.pluie * 0.85)
	hor = hor.lerp(gris.lightened(0.1), Game.pluie * 0.85)
	sun.light_energy *= 1.0 - 0.7 * Game.pluie
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor.darkened(0.3)
	sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.02).lerp(Color(0.1, 0.1, 0.09), daylight)
	env.ambient_light_energy = lerpf(0.4, 1.0, daylight) * (1.0 - 0.45 * interieur_k)   # pièces plus sombres que dehors
	env.fog_light_color = hor.darkened(0.1)
	env.fog_light_energy = lerpf(0.3, 1.0, daylight)
	# brouillard volumétrique : brume légère le jour, plus épaisse à l'aube, au crépuscule et la nuit
	env.volumetric_fog_density = lerpf(0.016, 0.0025, daylight) + dusk * 0.008
	var dedans: bool = Game.player != null and is_instance_valid(Game.player) and not Game.player.in_zone.is_empty()
	interieur_k = move_toward(interieur_k, 1.0 if dedans else 0.0, get_process_delta_time() * 1.5)
	env.volumetric_fog_density += Game.pluie * 0.012   # averse : brume épaisse
	env.volumetric_fog_density *= 1.0 - 0.9 * interieur_k   # pas de brume dans les pièces
	env.volumetric_fog_albedo = Color(0.9, 0.9, 0.92).lerp(hor, 0.3)
