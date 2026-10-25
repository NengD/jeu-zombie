extends SceneTree
## Personnages low-poly de Quaternius (« Ultimate Modular Men / Women », CC0), rangés dans
## outils/sources_persos_modulaires/ (h_*.glb, f_*.glb) -> res://modeles/persos_mod/<id>.scn
##  - les os sont renommés comme ceux du squelette UAL (pelvis, spine_01, hand_r…) : le reste du jeu
##    (démembrement, armes à la ceinture, animations) fonctionne sans changement ;
##  - les animations UAL du jeu (modeles/persos/homme.scn, femme.scn) sont transférées sur ce
##    squelette (rotations en repère monde, avec correction de la pose de repos bras le long du corps) ;
##  - point d'attache de l'arme « Prise » dans la main droite, calé comme pour l'ancien mannequin.
## Lancer : godot --headless --path . -s res://outils/godot/generer_persos_modulaires.gd

const SRC := "res://outils/sources_persos_modulaires/"
const OUT := "res://modeles/persos_mod/"
const FPS := 30.0

const OS_UAL := {
	"Root": "root", "Hips": "pelvis", "Abdomen": "spine_01", "Torso": "spine_02", "Chest": "spine_03",
	"Neck": "neck_01", "Head": "Head",
	"UpperLeg.L": "thigh_l", "LowerLeg.L": "calf_l", "Foot.L": "foot_l",
	"UpperLeg.R": "thigh_r", "LowerLeg.R": "calf_r", "Foot.R": "foot_r",
}
## os dont le parent réel n'est pas le bon (pieds de contrôle rattachés à la racine) : parent « virtuel »
const PARENT_VIRTUEL := {"foot_l": "calf_l", "foot_r": "calf_r"}
## enfant servant à mesurer la direction de chaque os (pour corriger la pose de repos)
const ENFANT := {
	"spine_01": "spine_02", "spine_02": "spine_03", "spine_03": "neck_01", "neck_01": "Head",
	"clavicle_l": "upperarm_l", "upperarm_l": "lowerarm_l", "lowerarm_l": "hand_l", "hand_l": "middle_01_l",
	"clavicle_r": "upperarm_r", "upperarm_r": "lowerarm_r", "lowerarm_r": "hand_r", "hand_r": "middle_01_r",
	"thigh_l": "calf_l", "calf_l": "foot_l", "thigh_r": "calf_r", "calf_r": "foot_r",
	"index_01_l": "index_02_l", "index_02_l": "index_03_l", "middle_01_l": "middle_02_l", "middle_02_l": "middle_03_l",
	"ring_01_l": "ring_02_l", "ring_02_l": "ring_03_l", "pinky_01_l": "pinky_02_l", "pinky_02_l": "pinky_03_l",
	"thumb_01_l": "thumb_02_l", "thumb_02_l": "thumb_03_l",
	"index_01_r": "index_02_r", "index_02_r": "index_03_r", "middle_01_r": "middle_02_r", "middle_02_r": "middle_03_r",
	"ring_01_r": "ring_02_r", "ring_02_r": "ring_03_r", "pinky_01_r": "pinky_02_r", "pinky_02_r": "pinky_03_r",
	"thumb_01_r": "thumb_02_r", "thumb_02_r": "thumb_03_r",
}


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var libs := {}
	var fichiers := DirAccess.get_files_at(SRC)
	for f in fichiers:
		if not f.ends_with(".glb") or not (f.begins_with("h_") or f.begins_with("f_")):
			continue
		var sexe := "homme" if f.begins_with("h_") else "femme"
		var id := f.get_basename()
		var inst := _charger(SRC + f)
		root.add_child(inst)
		await process_frame
		var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
		_renommer(inst, sk)
		# le modèle regarde vers +Z : demi-tour pour regarder vers -Z (l'avant dans Godot, comme le squelette UAL)
		(sk.get_parent() as Node3D).rotation.y += PI
		# une bibliothèque d'animations par sexe (tous les personnages d'un même sexe ont le même squelette)
		if not libs.has(sexe):
			libs[sexe] = _transferer(sexe, inst, sk)
			ResourceSaver.save(libs[sexe], OUT + "anims_%s.res" % sexe, ResourceSaver.FLAG_COMPRESS)
			libs[sexe] = load(OUT + "anims_%s.res" % sexe)
		# ANIMS_SEULES=1 : seulement les bibliothèques d'animations (après outils/godot/ajouter_anims_ual.gd)
		if OS.get_environment("ANIMS_SEULES") == "":
			_assembler(id, inst, sk, libs[sexe])
		else:
			inst.queue_free()
	quit()


func _charger(p: String) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path(p), st)
	return doc.generate_scene(st)


func _nom_ual(n: String) -> String:
	if OS_UAL.has(n):
		return OS_UAL[n]
	var cote := "_l" if n.ends_with(".L") else ("_r" if n.ends_with(".R") else "")
	if cote == "":
		return n
	var base := n.substr(0, n.length() - 2)
	match base:
		"Shoulder":
			return "clavicle" + cote
		"UpperArm":
			return "upperarm" + cote
		"LowerArm":
			return "lowerarm" + cote
		"Wrist":
			return "hand" + cote
	# doigts : ici l'os 1 est l'os de la paume (métacarpe), les phalanges sont 2, 3, 4 ;
	# sur le squelette UAL, index_01 est déjà la première phalange (le métacarpe fait partie de hand)
	for doigt in ["Index", "Middle", "Ring", "Pinky"]:
		if base.begins_with(doigt):
			var k := int(base.substr(doigt.length()))
			return "%s_meta%s" % [doigt.to_lower(), cote] if k == 1 else "%s_0%d%s" % [doigt.to_lower(), k - 1, cote]
	if base.begins_with("Thumb"):
		return "thumb_0%d%s" % [int(base.substr(5)), cote]
	return n


## Os renommés comme sur le squelette UAL (et liaisons des maillages mises à jour).
func _renommer(inst: Node3D, sk: Skeleton3D) -> void:
	var noms := {}
	for b in sk.get_bone_count():
		var ancien := sk.get_bone_name(b)
		noms[ancien] = _nom_ual(ancien)
	for b in sk.get_bone_count():
		sk.set_bone_name(b, noms[sk.get_bone_name(b)])
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var skin: Skin = (mi as MeshInstance3D).skin
		if skin == null:
			continue
		skin = skin.duplicate()
		for i in skin.get_bind_count():
			var bn := skin.get_bind_name(i)
			if noms.has(bn):
				skin.set_bind_name(i, noms[bn])
		(mi as MeshInstance3D).skin = skin


func _monde_repos(sk: Skeleton3D, b: int) -> Transform3D:
	return sk.global_transform * sk.get_bone_global_rest(b)


func _monde_pose(sk: Skeleton3D, b: int) -> Transform3D:
	return sk.global_transform * sk.get_bone_global_pose(b)


## Rotation (monde) qui aligne la direction de repos de l'os cible sur celle de l'os source.
## Rotation (monde) qui fait correspondre le repère de repos de l'os cible à celui de l'os source :
## direction de l'os ET torsion autour de lui (sinon mains et genoux tournent sur eux-mêmes).
func _correction(ss: Skeleton3D, st: Skeleton3D, nom: String) -> Basis:
	var fs = _repere(ss, nom)
	var ft = _repere(st, nom)
	if fs == null or ft == null:
		return Basis.IDENTITY
	return (fs as Basis) * (ft as Basis).inverse()


## Repère d'un os au repos, construit de la même façon sur les deux squelettes :
## axe 1 = vers l'os enfant ; axe 2 = largeur de la paume (mains) ou l'avant du personnage (-Z).
## Os sans repère propre (doigts, tête, pieds) : celui de l'os parent le plus proche.
func _repere(sk: Skeleton3D, nom: String):
	var b := sk.find_bone(nom)
	while b >= 0 and not ENFANT.has(sk.get_bone_name(b)):
		b = sk.get_bone_parent(b)
	if b < 0:
		return null
	var n := sk.get_bone_name(b)
	var o := _monde_repos(sk, b).origin
	var x := (_monde_repos(sk, sk.find_bone(ENFANT[n])).origin - o).normalized()
	var sec := Vector3(0, 0, -1)
	var doigt := n.begins_with("index") or n.begins_with("middle") or n.begins_with("ring") or n.begins_with("pinky") or n.begins_with("thumb")
	if n.begins_with("hand") or doigt:
		var cote := n.substr(n.length() - 2)
		sec = _monde_repos(sk, sk.find_bone("index_01" + cote)).origin - _monde_repos(sk, sk.find_bone("pinky_01" + cote)).origin   # jointures (écartées sur les deux squelettes)
	var z := (sec - x * sec.dot(x)).normalized()
	if z.length() < 0.5:
		z = (Vector3.UP - x * x.y).normalized()
	return Basis(x, z.cross(x), z)


func _transferer(sexe: String, inst: Node3D, st: Skeleton3D) -> AnimationLibrary:
	var src: Node3D = load("res://modeles/persos/%s.scn" % sexe).instantiate()
	root.add_child(src)
	var ss: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var ap_s: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	ap_s.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# os communs, du parent vers l'enfant
	var os_communs := []
	for b in st.get_bone_count():
		if ss.find_bone(st.get_bone_name(b)) >= 0:
			os_communs.append(b)
	var corr := {}
	for b in os_communs:
		var nom := st.get_bone_name(b)
		var bs := ss.find_bone(nom)
		# repos source^-1 puis repos cible « réaligné » sur la source
		corr[b] = _monde_repos(ss, bs).basis.orthonormalized().inverse() * (_correction(ss, st, nom) * _monde_repos(st, b).basis.orthonormalized())
	var h_s := _monde_repos(ss, ss.find_bone("pelvis")).origin.y
	var h_t := _monde_repos(st, st.find_bone("pelvis")).origin.y
	var chemin := str(inst.get_path_to(st))
	var lib := AnimationLibrary.new()
	for nom_anim in ap_s.get_animation_list():
		var a_src: Animation = ap_s.get_animation(nom_anim)
		var an := Animation.new()
		an.length = a_src.length
		an.loop_mode = a_src.loop_mode
		var pistes := {}
		for b in os_communs:
			var t := an.add_track(Animation.TYPE_ROTATION_3D)
			an.track_set_path(t, NodePath("%s:%s" % [chemin, st.get_bone_name(b)]))
			pistes[b] = t
		# positions animées : bassin, et pieds (dans ce squelette, les pieds ne sont pas rattachés aux genoux)
		var pistes_pos := {}
		for nom_p in ["pelvis", "foot_l", "foot_r"]:
			var bpp := st.find_bone(nom_p)
			if bpp >= 0:
				var tp := an.add_track(Animation.TYPE_POSITION_3D)
				an.track_set_path(tp, NodePath("%s:%s" % [chemin, nom_p]))
				pistes_pos[bpp] = tp
		var bp_s := ss.find_bone("pelvis")
		var bp_t := st.find_bone("pelvis")
		var b_corps := st.find_bone("Body")
		var piste_corps_r := -1
		var piste_corps_p := -1
		if b_corps >= 0:
			piste_corps_r = an.add_track(Animation.TYPE_ROTATION_3D)
			an.track_set_path(piste_corps_r, NodePath("%s:Body" % chemin))
			piste_corps_p = an.add_track(Animation.TYPE_POSITION_3D)
			an.track_set_path(piste_corps_p, NodePath("%s:Body" % chemin))
		var nb := maxi(2, int(ceil(a_src.length * FPS)) + 1)
		ap_s.play(nom_anim)
		for i in nb:
			var temps := minf(a_src.length, i / FPS)
			ap_s.seek(temps, true)
			# transforms monde de tous les os cibles, du parent vers l'enfant
			var mondes := {}
			# bassin calculé d'abord : l'os « Body » (son parent, sans équivalent UAL) le suit
			var w_bassin := Transform3D(_monde_pose(ss, bp_s).basis.orthonormalized() * corr[bp_t],
					_monde_repos(st, bp_t).origin + (_monde_pose(ss, bp_s).origin - _monde_repos(ss, bp_s).origin) * (h_t / h_s))
			for b in st.get_bone_count():
				var p := st.get_bone_parent(b)
				var nom_b := st.get_bone_name(b)
				if b == b_corps:
					mondes[b] = w_bassin * (_monde_repos(st, bp_t).affine_inverse() * _monde_repos(st, b))
					var lc: Transform3D = (mondes[p] if p >= 0 else st.global_transform).affine_inverse() * mondes[b]
					an.rotation_track_insert_key(piste_corps_r, temps, lc.basis.get_rotation_quaternion())
					an.position_track_insert_key(piste_corps_p, temps, lc.origin)
					continue
				var ref: int = st.find_bone(PARENT_VIRTUEL[nom_b]) if PARENT_VIRTUEL.has(nom_b) else p
				var ref_xf: Transform3D = mondes[ref] if ref >= 0 else st.global_transform
				var ref_repos: Transform3D = _monde_repos(st, ref) if ref >= 0 else st.global_transform
				var decal := ref_repos.affine_inverse() * _monde_repos(st, b)   # position de repos relative à la référence
				if not corr.has(b):
					mondes[b] = ref_xf * decal
					continue
				var w_s := _monde_pose(ss, ss.find_bone(nom_b))
				var base_t: Basis = w_s.basis.orthonormalized() * corr[b]
				var origine: Vector3 = ref_xf * decal.origin
				if b == bp_t:
					mondes[b] = w_bassin
					var lp: Transform3D = (mondes[p] if p >= 0 else st.global_transform).affine_inverse() * w_bassin
					an.rotation_track_insert_key(pistes[b], temps, lp.basis.get_rotation_quaternion())
					an.position_track_insert_key(pistes_pos[b], temps, lp.origin)
					continue
				if false:
					# bassin : déplacement depuis le repos, à l'échelle de la taille du personnage
					origine = _monde_repos(st, bp_t).origin + (_monde_pose(ss, bp_s).origin - _monde_repos(ss, bp_s).origin) * (h_t / h_s)
				mondes[b] = Transform3D(base_t, origine)
				var parent_xf: Transform3D = mondes[p] if p >= 0 else st.global_transform
				var local: Transform3D = parent_xf.affine_inverse() * mondes[b]
				an.rotation_track_insert_key(pistes[b], temps, local.basis.get_rotation_quaternion())
				if pistes_pos.has(b):
					an.position_track_insert_key(pistes_pos[b], temps, local.origin)
		lib.add_animation(nom_anim, an)
	print(sexe, " : ", lib.get_animation_list().size(), " animations transférées")
	src.queue_free()
	return lib


func _pose_globale_repos_parent(st: Skeleton3D, p: int) -> Transform3D:
	return st.get_bone_global_rest(p)


# ---------------------------------------------------------------- mains simples
const OS_MAIN := ["hand", "index", "middle", "ring", "pinky", "thumb"]


func _os_de_main(nom: String) -> bool:
	for p in OS_MAIN:
		if nom.begins_with(p + "_"):
			return true
	return false


## Mains détaillées (doigts) remplacées par des mains low-poly : un poing arrondi et un pouce,
## rigides et attachés à l'os de la main. Plus propres dans ce style et faciles à animer.
func _mains_simples(inst: Node3D, sk: Skeleton3D) -> void:
	var mat_peau: Material = null
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		if m3.skin == null:
			continue
		var noms := []
		for i in m3.skin.get_bind_count():
			var bn := m3.skin.get_bind_name(i)
			noms.append(bn if bn != "" else sk.get_bone_name(m3.skin.get_bind_bone(i)))
		var nouveau := ArrayMesh.new()
		var modifie := false
		for s in m3.mesh.get_surface_count():
			var arr: Array = m3.mesh.surface_get_arrays(s)
			var mat: Material = m3.mesh.surface_get_material(s)
			if mat and String(mat.resource_name).begins_with("Skin") and mat_peau == null:
				mat_peau = mat
			var os_v: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var nv: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var per := os_v.size() / maxi(nv, 1)
			# sommets « de la main » : os dominant = main ou doigt
			var de_main := PackedByteArray()
			de_main.resize(nv)
			for v in nv:
				var best := -1.0
				var bb := 0
				for k in per:
					if w[v * per + k] > best:
						best = w[v * per + k]
						bb = os_v[v * per + k]
				de_main[v] = 1 if bb < noms.size() and _os_de_main(noms[bb]) else 0
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				idx.resize(nv)
				for v in nv:
					idx[v] = v
			var garde := PackedInt32Array()
			for t in range(0, idx.size(), 3):
				if de_main[idx[t]] and de_main[idx[t + 1]] and de_main[idx[t + 2]]:
					modifie = true
					continue
				garde.append_array([idx[t], idx[t + 1], idx[t + 2]])
			if garde.is_empty():
				continue
			arr[Mesh.ARRAY_INDEX] = garde
			nouveau.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			nouveau.surface_set_material(nouveau.get_surface_count() - 1, mat)
		if modifie:
			m3.mesh = nouveau
	if mat_peau == null:
		mat_peau = StandardMaterial3D.new()
		mat_peau.resource_name = "Skin"
	for cote in ["_l", "_r"]:
		_moufle(sk, cote, mat_peau)


func _moufle(sk: Skeleton3D, cote: String, mat: Material) -> void:
	var h := sk.find_bone("hand" + cote)
	var g_h := sk.get_bone_global_rest(h)
	var o := g_h.origin
	var mid := sk.get_bone_global_rest(sk.find_bone("middle_01" + cote)).origin
	var idx := sk.get_bone_global_rest(sk.find_bone("index_01" + cote)).origin
	var pky := sk.get_bone_global_rest(sk.find_bone("pinky_01" + cote)).origin
	var pouce := sk.get_bone_global_rest(sk.find_bone("thumb_01" + cote)).origin
	# repère de la main : x vers les doigts, z largeur (index -> auriculaire inversé), y dos/paume
	var x := (mid - o).normalized()
	var lat := idx - pky
	var z := (lat - x * lat.dot(x)).normalized()
	var y := z.cross(x).normalized()
	var paume := o.distance_to(mid)
	var larg := paume * 0.56
	var long := paume * 0.78          # poing fermé
	var ep := paume * 0.42
	# le dos de la main est du côté opposé au pouce
	var cote_pouce := (pouce - o).dot(y)
	var repere := Basis(x, y, z)
	var ba := BoneAttachment3D.new()
	ba.name = "MainSimple" + cote
	ba.bone_name = "hand" + cote
	sk.add_child(ba)
	var poing := MeshInstance3D.new()
	poing.name = "Poing"
	# poing arrondi à facettes (sphère basse définition étirée), dans le style low-poly
	var bm := SphereMesh.new()
	bm.radius = 0.5
	bm.height = 1.0
	bm.radial_segments = 8
	bm.rings = 4
	bm.material = mat
	poing.mesh = bm
	var xf_poing := Transform3D(repere, o + x * long * 0.55)
	poing.transform = g_h.affine_inverse() * Transform3D(xf_poing.basis.scaled_local(Vector3(long, ep, larg)), xf_poing.origin)
	ba.add_child(poing)
	var p := MeshInstance3D.new()
	p.name = "Pouce"
	var bp := SphereMesh.new()
	bp.radius = 0.5
	bp.height = 1.0
	bp.radial_segments = 6
	bp.rings = 3
	bp.material = mat
	p.mesh = bp
	var taille_pouce := Vector3(long * 0.6, ep * 0.5, larg * 0.36)
	var dir_pouce := (pouce - o)
	dir_pouce = (dir_pouce - x * dir_pouce.dot(x) * 0.5).normalized()
	var xf_p := Transform3D(Basis(Vector3.UP if absf(dir_pouce.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT, 0.0), Vector3.ZERO)
	var px := (x * 0.6 + dir_pouce * 0.4).normalized()
	var pz := z
	var py := pz.cross(px).normalized()
	pz = px.cross(py).normalized()
	xf_p = Transform3D(Basis(px, py, pz), o + dir_pouce * larg * 0.5 + x * long * 0.35)
	p.transform = g_h.affine_inverse() * Transform3D(xf_p.basis.scaled_local(taille_pouce), xf_p.origin)
	ba.add_child(p)


func _assembler(id: String, inst: Node3D, sk: Skeleton3D, lib: AnimationLibrary) -> void:
	inst.name = "Perso"
	# l'arme d'exemple du pack (pistolet du SWAT) et l'ancien lecteur d'animations sont retirés
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		if mi.name in ["Pistol", "Rifle", "Sword", "Knife"]:
			mi.get_parent().remove_child(mi)
			mi.free()
	for ap_old in inst.find_children("*", "AnimationPlayer", true, false):
		ap_old.get_parent().remove_child(ap_old)
		ap_old.free()
	_mains_simples(inst, sk)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	inst.add_child(ap)
	ap.add_animation_library("", lib)
	# point d'attache de l'arme (main droite) calé pendant la visée, comme pour l'ancien mannequin
	var main := BoneAttachment3D.new()
	main.name = "MainD"
	main.bone_name = "hand_r"
	sk.add_child(main)
	var prise := Node3D.new()
	prise.name = "Prise"
	main.add_child(prise)
	# pose de visée appliquée à la main (pistes de rotation et de position lues à 0,2 s)
	var visee: Animation = lib.get_animation("visee")
	for t in visee.get_track_count():
		var os_nom := String(visee.track_get_path(t).get_concatenated_subnames())
		var bi := sk.find_bone(os_nom)
		if bi < 0:
			continue
		if visee.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			sk.set_bone_pose_rotation(bi, visee.rotation_track_interpolate(t, 0.2))
		elif visee.track_get_type(t) == Animation.TYPE_POSITION_3D:
			sk.set_bone_pose_position(bi, visee.position_track_interpolate(t, 0.2))
	var hb := sk.find_bone("hand_r")
	var gh := sk.get_bone_global_pose(hb)
	var mid := sk.get_bone_global_pose(sk.find_bone("middle_01_r")).origin
	var arme_b := Basis(Vector3.UP, PI)
	var paume := gh.origin.lerp(mid, 0.55) + Vector3(0, -0.03, 0)
	prise.transform = gh.affine_inverse() * Transform3D(arme_b, paume)
	sk.reset_bone_poses()
	_proprio(inst, inst)
	var ps := PackedScene.new()
	ps.pack(inst)
	var err := ResourceSaver.save(ps, OUT + id + ".scn", ResourceSaver.FLAG_COMPRESS)
	print(id, " -> ", err)
	inst.queue_free()


func _proprio(n: Node, owner_: Node) -> void:
	for c in n.get_children():
		c.owner = owner_
		_proprio(c, owner_)
