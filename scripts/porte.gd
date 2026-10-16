extends Node3D
## Porte d'entrée de bâtiment (deux battants). [F] pour ouvrir / fermer.
## Les zombies ne savent pas ouvrir : ils tapent dedans jusqu'à l'enfoncer.

var ouverte := false
var pv := 80.0
var largeur := 1.8
var hauteur := 2.4
var sens := 1.0            # côté vers lequel les battants s'ouvrent (vers l'intérieur)
var battants: Array = []   # [pivot, angle_ouvert]
var t_anim := 0.0
var idx := -1              # numéro de la porte (pour la sauvegarde)


func setup(p_largeur: float, p_hauteur: float, p_sens: float, couleur: Color) -> void:
	largeur = p_largeur
	hauteur = p_hauteur
	sens = p_sens
	add_to_group("porte")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = couleur
	mat.roughness = 0.75
	if ResourceLoader.exists("res://textures/planches_albedo.jpg"):
		mat.albedo_texture = load("res://textures/planches_albedo.jpg")
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.8, 0.8, 0.8)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.6, 0.58, 0.52)
	metal.metallic = 0.8
	metal.roughness = 0.35
	var lb := largeur / 2.0
	for cote in [-1.0, 1.0]:
		# pivot sur le bord de l'ouverture (repère local : l'ouverture va de -lb à +lb sur X)
		var pivot := Node3D.new()
		pivot.position = Vector3(cote * lb, 0, 0)
		add_child(pivot)
		var corps := AnimatableBody3D.new()
		corps.sync_to_physics = false
		corps.collision_layer = Game.LAYER_WORLD | Game.LAYER_INTERACT
		corps.collision_mask = 0
		corps.set_script(preload("res://scripts/porte_battant.gd"))
		corps.set("porte", self)
		pivot.add_child(corps)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(lb - 0.02, hauteur - 0.02, 0.05)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(-cote * (lb / 2.0), hauteur / 2.0, 0)
		corps.add_child(mi)
		var poignee := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.12, 0.03, 0.12)
		poignee.mesh = pm
		poignee.material_override = metal
		poignee.position = Vector3(-cote * (lb - 0.12), 1.0, 0)
		corps.add_child(poignee)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(lb + 0.03, hauteur - 0.02, 0.08)   # chevauchement au centre : pas de fente
		cs.shape = bs
		cs.position = mi.position
		corps.add_child(cs)
		battants.append([pivot, cote * sens * deg_to_rad(95.0)])


func get_prompt() -> String:
	return "[F] Fermer la porte" if ouverte else "[F] Ouvrir la porte"


func interact(_player: Node) -> void:
	basculer(not ouverte)


func basculer(o: bool, instantane := false) -> void:
	if o == ouverte and not instantane:
		return
	ouverte = o
	if not instantane:
		Game.play_3d("fouille", global_position + Vector3.UP, -6.0, 0.15, 20.0)
		Game.make_noise(global_position, 4.0)
	for b in battants:
		var cible: float = b[1] if ouverte else 0.0
		if instantane:
			b[0].rotation.y = cible
		else:
			var tw := create_tween()
			tw.tween_property(b[0], "rotation:y", cible, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Un zombie tape dans la porte fermée.
func frapper(degats: float) -> void:
	if ouverte:
		return
	pv -= degats
	Game.play_3d("coup", global_position + Vector3.UP, -2.0, 0.2, 35.0)
	if pv <= 0.0:
		pv = 80.0
		basculer(true)
		Game.play_3d("construire", global_position + Vector3.UP, 0.0, 0.2, 40.0)
