extends SkeletonModifier3D
## Après l'animation, sur le squelette d'un zombie :
##  - membres coupés : l'os (et tout ce qui en dépend) est réduit à rien ;
##  - posture du zombie (tête penchée, dos voûté…) : rotations locales ajoutées à la pose animée.
## Ajouté au squelette du zombie à son apparition (zombie._posture_zombie) ou à la première coupure.

var coupes: Array = []
var posture: Array = []      # [nom d'os, Quaternion]
var _idx := {}


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for p in posture:
		var i := _os(sk, p[0])
		if i >= 0:
			sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * (p[1] as Quaternion))
	for b in coupes:
		var i := _os(sk, b)
		if i >= 0:
			sk.set_bone_pose_scale(i, Vector3(0.001, 0.001, 0.001))


func _os(sk: Skeleton3D, nom: String) -> int:
	if not _idx.has(nom):
		_idx[nom] = sk.find_bone(nom)
	return _idx[nom]
