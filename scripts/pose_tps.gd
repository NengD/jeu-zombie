extends SkeletonModifier3D
## Personnage en 3e personne : recul du buste et des bras à chaque tir,
## doigts refermés sur l'arme (poignée pour la main droite, garde-main pour la gauche).
## Placé avant la cinématique inverse du bras gauche (la main reste sur l'arme).

var recul := 0.0            # 0..1, remis à 1 à chaque tir puis amorti par le joueur
var serre_d := 0.0          # 0..1 : main droite serrée
var serre_g := 0.0          # 0..1 : main gauche serrée
var droite := Vector3.RIGHT # axe droit du personnage, dans le repère du squelette
var axe_doigts := Vector3(1, 0, 0)   # axe de flexion des phalanges du mannequin UAL
var signe_doigts := 1.0

const DOIGTS := ["index", "middle", "ring", "pinky"]
const ANGLES := [0.95, 1.2, 0.85]         # flexion par phalange (rad) quand la main est serrée
const POUCE := [0.35, 0.45, 0.3]


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if recul > 0.001:
		# le buste part en arrière, l'arme se relève légèrement
		_tourner_global(sk, "spine_03", droite, 0.05 * recul)
		_tourner_global(sk, "clavicle_r", droite, 0.025 * recul)
		_tourner_global(sk, "upperarm_r", droite, 0.045 * recul)
	for cote in ["r", "l"]:
		var k := serre_d if cote == "r" else serre_g
		if k <= 0.001:
			continue
		for d in DOIGTS:
			for j in 3:
				_plier(sk, "%s_0%d_%s" % [d, j + 1, cote], ANGLES[j] * k)
		for j in 3:
			_plier(sk, "thumb_0%d_%s" % [j + 1, cote], POUCE[j] * k)


func _plier(sk: Skeleton3D, nom: String, angle: float) -> void:
	var i := sk.find_bone(nom)
	if i < 0:
		return
	sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(axe_doigts, angle * signe_doigts))


func _tourner_global(sk: Skeleton3D, nom: String, axe: Vector3, angle: float) -> void:
	var i := sk.find_bone(nom)
	if i < 0:
		return
	var g := sk.get_bone_global_pose(i)
	sk.set_bone_global_pose(i, Transform3D(Basis(axe.normalized(), angle) * g.basis, g.origin))
