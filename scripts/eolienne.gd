extends Node3D
## Rotor d'éolienne (trois pales) qui tourne lentement ; créé par world_gen.gd.

var vitesse := 0.5
static var _pale: BoxMesh
static var _moyeu: BoxMesh


func _init() -> void:
	if _pale == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.92, 0.9)
		m.roughness = 0.6
		_pale = BoxMesh.new()
		_pale.size = Vector3(1.3, 21.0, 0.3)
		_pale.material = m
		_moyeu = BoxMesh.new()
		_moyeu.size = Vector3(1.6, 1.6, 1.4)
		_moyeu.material = m
	var moyeu := MeshInstance3D.new()
	moyeu.mesh = _moyeu
	add_child(moyeu)
	for k in 3:
		var pale := MeshInstance3D.new()
		pale.mesh = _pale
		pale.rotation.z = TAU * k / 3.0
		pale.position = Vector3(0, 11.0, 0).rotated(Vector3(0, 0, 1), pale.rotation.z)
		pale.visibility_range_end = 900.0
		add_child(pale)


func _process(delta: float) -> void:
	rotate_object_local(Vector3(0, 0, 1), vitesse * delta)
