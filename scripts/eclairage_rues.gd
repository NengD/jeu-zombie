extends Node3D
## Éclairage des rues la nuit : lampadaires allumés (lumière orangée au sodium), quelques-uns
## qui clignotent, d'autres en panne. La lanterne s'illumine, avec un halo dans la brume.

const HAUT := 4.25          # hauteur de la lanterne du modèle de lampadaire

var lampes: Array = []      # {lumiere, verre, mat, etat (0 marche, 1 clignote, 2 panne), t}
var allume := -1.0
var tri_t := 0.0


func installer(lampadaires: Array, graine: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine + 777
	for l in lampadaires:
		if not is_instance_valid(l):
			continue
		var r := rng.randf()
		var etat := 0 if r < 0.72 else (1 if r < 0.84 else 2)
		# lanternes du modèle (méta « tetes » posée par world_gen._lampadaire), au repère du monde
		var n3: Node3D = l
		var tetes: Array = n3.get_meta("tetes", [Vector3(0, HAUT, 0)])
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.6)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.72, 0.4)
		mat.emission_energy_multiplier = 0.0
		var centre := Vector3.ZERO
		for t in tetes:
			var pos: Vector3 = n3.position + n3.basis * (t as Vector3)
			centre += pos / tetes.size()
			var verre := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.2 if tetes.size() == 1 else 0.16
			sm.height = 0.14
			verre.mesh = sm
			verre.material_override = mat
			verre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			verre.position = pos - Vector3(0, 0.1, 0)   # sous la lanterne, visible
			add_child(verre)
		# une seule lumière par lampadaire (au milieu des lanternes), portée selon la hauteur
		var lum := SpotLight3D.new()
		lum.position = centre - Vector3(0, 0.15, 0)
		lum.rotation.x = -PI / 2.0          # cône vers le sol
		lum.spot_angle = 50.0 if tetes.size() == 1 else 62.0
		lum.spot_angle_attenuation = 0.8
		lum.light_color = Color(1.0, 0.72, 0.42)
		lum.spot_range = maxf(9.0, centre.y - n3.position.y + 5.0)
		lum.spot_attenuation = 0.7
		lum.light_energy = 0.0
		lum.light_volumetric_fog_energy = 1.6     # halo dans la brume
		lum.shadow_enabled = false
		lum.distance_fade_enabled = true
		lum.distance_fade_begin = 90.0
		lum.distance_fade_length = 30.0
		lum.visible = false
		add_child(lum)
		lampes.append({"lumiere": lum, "mat": mat, "etat": etat, "t": rng.randf() * 10.0, "rang": 99})


## Allumés de 20 h à 6 h 30.
func _process(delta: float) -> void:
	var h: float = Game.time_hours
	var cible := 1.0 if (h >= 20.0 or h < 6.5) else 0.0
	allume = move_toward(maxf(allume, 0.0), cible, delta * 0.5) if allume >= 0.0 else cible
	var p = Game.player
	# seules les lampes les plus proches éclairent vraiment (les autres : lanterne lumineuse seule)
	tri_t -= delta
	if tri_t <= 0.0 and p:
		tri_t = 0.5
		var pp: Vector3 = p.global_position
		var tries := lampes.duplicate()
		tries.sort_custom(func(a, b): return a.lumiere.global_position.distance_squared_to(pp) < b.lumiere.global_position.distance_squared_to(pp))
		for i in tries.size():
			tries[i].rang = i
	var nb_lumieres: int = [4, 8, 12, 16][Game.qualite]
	for l in lampes:
		var k := allume
		if l.etat == 2:
			k = 0.0
		elif l.etat == 1 and k > 0.0:
			# néon fatigué : coupures aléatoires
			l.t += delta
			var s := sin(l.t * 23.0) + sin(l.t * 7.1) + sin(l.t * 1.3) * 1.5
			k *= 0.0 if s < -0.6 else (0.4 if s < 0.2 else 1.0)
		var lum: SpotLight3D = l.lumiere
		lum.visible = k > 0.01 and int(l.get("rang", 99)) < nb_lumieres
		lum.light_volumetric_fog_energy = 1.6 if int(l.get("rang", 99)) < 6 else 0.0
		lum.light_energy = 10.0 * k
		lum.shadow_enabled = int(l.get("rang", 99)) < [0, 0, 2, 4][Game.qualite]   # ombres des lampes les plus proches (murs opaques)
		l.mat.emission_energy_multiplier = 6.0 * k
