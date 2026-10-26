extends OmniLight3D
## Néon d'intérieur alimenté par un groupe électrogène de secours : lumière faible,
## parfois clignotante. S'éteint quand le joueur est loin (économie).

var clignote := false
var base := 0.9
var t := 0.0
var tube: MeshInstance3D = null
var mat_tube: StandardMaterial3D = null
var verif := randf() * 0.3   # distance au joueur revue toutes les 0,3 s


func _process(delta: float) -> void:
	var p = Game.player
	if p == null:
		return
	verif -= delta
	if verif <= 0.0:
		verif = 0.3
		visible = global_position.distance_squared_to(p.global_position) < 45.0 * 45.0
	if not visible or not clignote:
		return
	t -= delta
	if t <= 0.0:
		var eteint := randf() < 0.35
		t = randf_range(0.03, 0.12) if eteint else randf_range(0.2, 2.5)
		light_energy = base * (0.05 if eteint else randf_range(0.85, 1.0))
		if mat_tube:
			mat_tube.emission_energy_multiplier = 0.1 if eteint else 2.5
