extends SceneTree
## Rend les icônes des accessoires d'armes (res://icones/<id>.png) à partir de leurs modèles 3D.
## Lancer avec un affichage : godot --path . -s res://outils/godot/generer_icones_accessoires.gd

const IDS := ["point_rouge", "lunette", "silencieux", "silencieux_artisanal", "chargeur_etendu", "lampe_tactique", "poignee"]
var sv: SubViewport
var cam: Camera3D
var pivot: Node3D
var i := -1
var attente := 0


func _initialize() -> void:
	sv = SubViewport.new()
	sv.size = Vector2i(256, 256)
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.75)
	e.ambient_light_energy = 0.9
	env.environment = e
	sv.add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-40, 30, 0)
	l.light_energy = 1.8
	sv.add_child(l)
	pivot = Node3D.new()
	sv.add_child(pivot)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	sv.add_child(cam)


func _process(_d: float) -> bool:
	attente -= 1
	if attente > 0:
		return false
	if i >= 0:
		var img := sv.get_texture().get_image()
		img.save_png("res://icones/%s.png" % IDS[i])
		print("icône ", IDS[i])
	i += 1
	if i >= IDS.size():
		return true
	for c in pivot.get_children():
		c.queue_free()
	var m := Accessoires.modele_accessoire(IDS[i])
	pivot.add_child(m)
	# cadrage sur la boîte englobante
	var ab := AABB()
	var premier := true
	for g in m.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (g as MeshInstance3D).transform * (g as MeshInstance3D).get_aabb()
		ab = a if premier else ab.merge(a)
		premier = false
	m.position = -ab.get_center()
	pivot.rotation = Vector3(deg_to_rad(15), deg_to_rad(-60), 0)
	cam.size = maxf(ab.size.length() * 1.05, 0.05)
	cam.position = Vector3(0, 0, 2)
	attente = 4
	return false
