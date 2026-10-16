extends SkeletonModifier3D
## Membres coupés d'un zombie : l'os (et tout ce qui en dépend) est réduit à rien,
## après l'animation. Ajouté au squelette du zombie lors de la première coupure.

var coupes: Array = []


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for b in coupes:
		var i := sk.find_bone(b)
		if i >= 0:
			sk.set_bone_pose_scale(i, Vector3(0.001, 0.001, 0.001))
