extends SceneTree
## Génère les personnages du jeu à partir du mannequin « Universal Animation Library »
## de Quaternius (CC0) : res://modeles/persos/homme.scn et femme.scn.
##  - le maillage reçoit, dans CUSTOM0, sa position au repos et la zone du corps
##    (utilisées par perso.gdshader pour dessiner peau, visage, vêtements…)
##  - les animations utiles des deux bibliothèques UAL sont copiées sous des noms français
##  - coiffures (Universal Base Characters, CC0), casque, casquette et point d'attache de l'arme
## Lancer : godot --headless --path . -s res://outils/godot/generer_persos.gd

const SRC := "res://modeles/sources/ual/"
const OUT := "res://modeles/persos/"

const ANIMS := {
	"idle": ["ual1", "Idle"], "marche": ["ual1", "Walk"], "jogging": ["ual1", "Jog_Fwd"],
	"course": ["ual1", "Sprint"], "accroupi": ["ual1", "Crouch_Idle"], "accroupi_marche": ["ual1", "Crouch_Fwd"],
	"arme_idle": ["ual1", "Pistol_Idle"], "visee": ["ual1", "Pistol_Aim_Neutral"],
	"recharge": ["ual1", "Pistol_Reload"], "tir": ["ual1", "Pistol_Shoot"],
	"coup_poing": ["ual1", "Punch_Jab"], "coup_poing2": ["ual1", "Punch_Cross"],
	"frappe": ["ual1", "Sword_Attack"], "mort": ["ual1", "Death01"], "touche": ["ual1", "Hit_Chest"],
	"touche_tete": ["ual1", "Hit_Head"], "interagir": ["ual1", "Interact"], "ramasser": ["ual1", "PickUp_Table"],
	"saut": ["ual1", "Jump"],
	"z_idle": ["ual2", "Zombie_Idle"], "z_marche": ["ual2", "Zombie_Walk_Fwd"], "z_attaque": ["ual2", "Zombie_Scratch"],
	"recul": ["ual2", "Hit_Knockback"], "crochet": ["ual2", "Melee_Hook"], "manger": ["ual2", "Consume"],
	"frappe2": ["ual2", "Sword_Regular_A"], "fouiller": ["ual2", "Chest_Open"],
	"frappe3": ["ual2", "Sword_Regular_B"], "estoc": ["ual2", "Sword_Regular_C"], "hache": ["ual2", "TreeChopping"],
	"parade": ["ual2", "Sword_Block"], "pousser": ["ual1", "Push"], "rampe": ["ual1", "Swim_Fwd"],
	"visee_haut": ["ual1", "Pistol_Aim_Up"], "visee_bas": ["ual1", "Pistol_Aim_Down"],
}
const BOUCLES := ["idle", "marche", "jogging", "course", "accroupi", "accroupi_marche", "arme_idle", "visee", "z_idle", "z_marche", "rampe", "parade", "visee_haut", "visee_bas"]

const COIFFURES := ["hair_simple_parted", "hair_buzzed", "hair_long", "hair_buns", "hair_beard", "hair_buzzed_female"]

const ECHELLE_CHEVEUX := {"hair_beard": 1.03, "eyebrows_regular": 1.0, "eyebrows_female": 1.0}
var libs := {}


func _initialize() -> void:
	for k in ["ual1", "ual2"]:
		var inst: Node = load(SRC + "%s_standard.glb" % k).instantiate()
		libs[k] = inst.find_child("AnimationPlayer", true, false)
	var tex_cheveux := _texture_cheveux()
	for nom in ["homme", "femme"]:
		var src := "ual1_standard.glb" if nom == "homme" else "mannequin_f.glb"
		_construire(nom, load(SRC + src).instantiate(), tex_cheveux)
	quit()


func _texture_cheveux() -> Texture2D:
	var inst: Node = load(SRC + "hair_simple_parted.glb").instantiate()
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var m: BaseMaterial3D = mi.mesh.surface_get_material(0)
	var img: Image = m.albedo_texture.get_image()
	if img.is_compressed():
		img.decompress()
	img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


func _zone(nom_os: String) -> int:
	if nom_os in ["Head", "neck_01"]:
		return 0
	if nom_os.begins_with("spine") or nom_os.begins_with("clavicle"):
		return 1
	if nom_os.begins_with("upperarm") or nom_os.begins_with("lowerarm"):
		return 2
	if nom_os.begins_with("hand") or nom_os.begins_with("index") or nom_os.begins_with("middle") \
			or nom_os.begins_with("ring") or nom_os.begins_with("pinky") or nom_os.begins_with("thumb"):
		return 3
	if nom_os.begins_with("foot") or nom_os.begins_with("ball"):
		return 5
	return 4   # pelvis, thigh, calf, root


func _construire(nom: String, inst: Node3D, tex_cheveux: Texture2D) -> void:
	root.add_child(inst)
	inst.name = "Perso"
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var skin: Skin = mi.skin
	# transformation de chaque liaison (os) : repos * pose de liaison
	var xf_bind := []
	var nom_bind := []
	for i in skin.get_bind_count():
		var bn := skin.get_bind_name(i)
		var bi := sk.find_bone(bn) if bn != "" else skin.get_bind_bone(i)
		nom_bind.append(sk.get_bone_name(bi))
		xf_bind.append(sk.get_bone_global_rest(bi) * skin.get_bind_pose(i))
	var mesh := ArrayMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = load(OUT + "perso.gdshader")
	for s in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / v.size()
		var custom := PackedFloat32Array()
		custom.resize(v.size() * 4)
		for i in v.size():
			var pr := Vector3.ZERO
			var best := -1.0
			var best_b := 0
			for k in per:
				var wk := w[i * per + k]
				if wk <= 0.0:
					continue
				var b := bones[i * per + k]
				pr += (xf_bind[b] * v[i]) * wk
				if wk > best:
					best = wk
					best_b = b
			custom[i * 4] = pr.x
			custom[i * 4 + 1] = pr.y
			custom[i * 4 + 2] = pr.z
			custom[i * 4 + 3] = _zone(nom_bind[best_b])
		arr[Mesh.ARRAY_CUSTOM0] = custom
		var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		mesh.surface_set_material(s, mat)
	mi.mesh = mesh
	mi.name = "Corps"

	# coiffures (maillages animés par le même squelette)
	var mat_ch := StandardMaterial3D.new()
	mat_ch.albedo_texture = tex_cheveux
	mat_ch.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat_ch.alpha_scissor_threshold = 0.4
	mat_ch.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_ch.roughness = 0.75
	mat_ch.albedo_color = Color.WHITE
	for c in COIFFURES:
		var hi: Node = load(SRC + c + ".glb").instantiate()
		var hm: MeshInstance3D = hi.find_children("*", "MeshInstance3D", true, false)[0]
		var copie := MeshInstance3D.new()
		copie.name = c.replace("hair_", "cheveux_")
		copie.mesh = _gonfler(hm.mesh, hm.skin, sk, ECHELLE_CHEVEUX.get(c, 1.05))
		copie.skin = hm.skin
		copie.material_override = mat_ch
		copie.visible = false
		sk.add_child(copie)
		copie.skeleton = NodePath("..")
	for c in ["eyebrows_regular", "eyebrows_female"]:
		var hi: Node = load(SRC + c + ".glb").instantiate()
		var hm: MeshInstance3D = hi.find_children("*", "MeshInstance3D", true, false)[0]
		var copie := MeshInstance3D.new()
		copie.name = "sourcils" if c == "eyebrows_regular" else "sourcils_f"
		copie.mesh = _gonfler(hm.mesh, hm.skin, sk, ECHELLE_CHEVEUX.get(c, 1.05))
		copie.skin = hm.skin
		copie.material_override = mat_ch
		copie.visible = false
		sk.add_child(copie)
		copie.skeleton = NodePath("..")

	# accessoires de tête
	var tete := BoneAttachment3D.new()
	tete.name = "Tete"
	tete.bone_name = "Head"
	sk.add_child(tete)
	var rest_tete := sk.get_bone_global_rest(sk.find_bone("Head"))
	tete.add_child(_casque(rest_tete))
	tete.add_child(_casquette(rest_tete))

	# point d'attache de l'arme (main droite)
	var main := BoneAttachment3D.new()
	main.name = "MainD"
	main.bone_name = "hand_r"
	sk.add_child(main)
	var prise := Node3D.new()
	prise.name = "Prise"
	main.add_child(prise)

	# animations
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "AnimationPlayer"
		inst.add_child(ap)
	for l in ap.get_animation_library_list():
		ap.remove_animation_library(l)
	var lib := AnimationLibrary.new()
	for a in ANIMS:
		var src_ap: AnimationPlayer = libs[ANIMS[a][0]]
		var an: Animation = src_ap.get_animation("Armature|Armature|" + ANIMS[a][1]).duplicate(true)
		# on ne garde que les rotations (+ position du bassin) : les proportions du modèle sont respectées
		for t in range(an.get_track_count() - 1, -1, -1):
			var pth := str(an.track_get_path(t))
			if an.track_get_type(t) == Animation.TYPE_POSITION_3D and not pth.ends_with(":pelvis"):
				an.remove_track(t)
			elif an.track_get_type(t) == Animation.TYPE_SCALE_3D:
				an.remove_track(t)
		an.loop_mode = Animation.LOOP_LINEAR if a in BOUCLES else Animation.LOOP_NONE
		lib.add_animation(a, an)
	ap.add_animation_library("", lib)

	# calage de l'arme : pendant la visée, le canon pointe vers l'avant du personnage
	_poser(sk, lib.get_animation("visee"), 0.2)
	var hb := sk.find_bone("hand_r")
	var gh: Transform3D = _glob(sk, hb)
	var mid: Vector3 = _glob(sk, sk.find_bone("middle_01_r")).origin
	var idx: Vector3 = _glob(sk, sk.find_bone("index_01_r")).origin
	var pinky: Vector3 = _glob(sk, sk.find_bone("pinky_01_r")).origin
	# l'avant du squelette est +Z ; une arme a son canon vers -Z → rotation de 180° autour de Y
	var arme_b := Basis(Vector3.UP, PI)
	var paume := gh.origin.lerp(mid, 0.55) + Vector3(0, -0.035, 0)
	prise.transform = gh.affine_inverse() * Transform3D(arme_b, paume)
	print(nom, " prise ", prise.transform, " idx-pinky ", idx - pinky)
	sk.reset_bone_poses()

	_proprio(inst, inst)
	var ps := PackedScene.new()
	ps.pack(inst)
	var err := ResourceSaver.save(ps, OUT + nom + ".scn", ResourceSaver.FLAG_COMPRESS)
	print(nom, " -> ", err)
	inst.queue_free()


func _proprio(n: Node, owner_: Node) -> void:
	for c in n.get_children():
		c.owner = owner_
		_proprio(c, owner_)


func _mat(c: Color, r := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = r
	m.metallic = metal
	return m


## Casque militaire (calotte + rebord) placé sur la tête au repos.
func _casque(rest_tete: Transform3D) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anneaux := 10
	var segs := 24
	for j in anneaux:
		for i in segs:
			for q in [[0, 0], [1, 0], [1, 1], [0, 0], [1, 1], [0, 1]]:
				var a := TAU * float(i + q[0]) / segs
				var e := (PI * 0.5) * float(j + q[1]) / anneaux
				var bord := 1.0 if j + q[1] > 0 else 1.08
				var pnt := Vector3(cos(a) * cos(e) * 0.118 * bord, sin(e) * 0.115, sin(a) * cos(e) * 0.128 * bord)
				st.set_normal(pnt.normalized())
				st.add_vertex(pnt)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Casque"
	mi.mesh = st.commit()
	var m := _mat(Color(0.26, 0.28, 0.2), 0.85)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.transform = rest_tete.affine_inverse() * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-6)), Vector3(0, 1.735, -0.005))
	mi.visible = false
	return mi


## Casquette de police : calotte + visière.
func _casquette(rest_tete: Transform3D) -> Node3D:
	var n := Node3D.new()
	n.name = "Casquette"
	var cal := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.118
	cm.bottom_radius = 0.104
	cm.height = 0.07
	cal.mesh = cm
	cal.material_override = _mat(Color(0.08, 0.1, 0.18), 0.7)
	cal.scale = Vector3(1, 1, 1.12)
	n.add_child(cal)
	var vis := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.008, 0.07)
	vis.mesh = bm
	vis.material_override = _mat(Color(0.03, 0.03, 0.03), 0.25)
	vis.position = Vector3(0, -0.03, 0.125)
	vis.rotation_degrees.x = 12
	n.add_child(vis)
	var ins := MeshInstance3D.new()
	var im := BoxMesh.new()
	im.size = Vector3(0.035, 0.03, 0.004)
	ins.mesh = im
	ins.material_override = _mat(Color(0.85, 0.72, 0.3), 0.3, 0.8)
	ins.position = Vector3(0, 0.0, 0.122)
	n.add_child(ins)
	n.transform = rest_tete.affine_inverse() * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-5)), Vector3(0, 1.79, 0.0))
	n.visible = false
	return n


## Applique une image d'animation au squelette (sans passer par l'AnimationPlayer).
func _poser(sk: Skeleton3D, an: Animation, t: float) -> void:
	for i in an.get_track_count():
		var pth := str(an.track_get_path(i))
		var b := sk.find_bone(pth.get_slice(":", 1))
		if b < 0:
			continue
		if an.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			sk.set_bone_pose_rotation(b, an.rotation_track_interpolate(i, t))
		elif an.track_get_type(i) == Animation.TYPE_POSITION_3D:
			sk.set_bone_pose_position(b, an.position_track_interpolate(i, t))
	sk.force_update_all_bone_transforms()


## Pose globale d'un os calculée à partir des poses locales (indépendant du cache du squelette).
func _glob(sk: Skeleton3D, b: int) -> Transform3D:
	var t := sk.get_bone_pose(b)
	var p := sk.get_bone_parent(b)
	while p >= 0:
		t = sk.get_bone_pose(p) * t
		p = sk.get_bone_parent(p)
	return t


## Les coiffures sont faites pour une tête un peu plus petite que celle du mannequin :
## on les écarte légèrement du centre de la tête (en pose de repos) pour éviter qu'elles s'y enfoncent.
func _gonfler(m: Mesh, skin: Skin, sk: Skeleton3D, k: float) -> ArrayMesh:
	var centre := Vector3(0, 1.69, -0.005)
	var out := ArrayMesh.new()
	for s in m.get_surface_count():
		var arr: Array = m.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		# les sommets sont exprimés dans l'espace de liaison : on passe par la tête au repos
		var bi := 0
		for i in skin.get_bind_count():
			if skin.get_bind_name(i) == "Head":
				bi = i
		var xf := sk.get_bone_global_rest(sk.find_bone("Head")) * skin.get_bind_pose(bi)
		var inv := xf.affine_inverse()
		for i in v.size():
			var p := xf * v[i]
			p = centre + (p - centre) * k
			v[i] = inv * p
		arr[Mesh.ARRAY_VERTEX] = v
		for c in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arr[c] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(s, m.surface_get_material(s))
	return out
