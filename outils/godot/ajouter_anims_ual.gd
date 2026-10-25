extends SceneTree
## Ajoute aux mannequins sources (res://modeles/persos/homme.scn, femme.scn) des animations des
## « Universal Animation Library » 1 et 2 de Quaternius (CC0, versions Standard gratuites, OpenGameArt),
## rangées dans outils/sources_ual/ (.gdignore : lues ici sans import Godot) :
##   ual1_standard.glb (version « Godot » du pack 1, os Rigify renommés par _nom_ue)
##   ual2_standard.glb (version « Unreal-Godot » du pack 2)
## Reciblage en espace monde (le pack 1 a d'autres os et une autre pose de repos) :
## les deux packs ont l'animation « A_TPose » ; la correction de chaque os aligne la source en A_TPose
## sur le mannequin en A_TPose (pack 2 = même squelette que nos mannequins) ; déplacement du bassin
## à l'échelle de sa hauteur. Les animations « *_miroir » sont retournées gauche / droite.
## Ensuite : ANIMS_SEULES=1 godot --headless --path . -s res://outils/godot/generer_persos_modulaires.gd
## (refait seulement anims_homme.res / anims_femme.res pour les personnages du jeu).
## Lancer : godot --headless --path . -s res://outils/godot/ajouter_anims_ual.gd

const SRC := "res://outils/sources_ual/"
const FPS := 30.0

## nom dans le jeu : [source, animation, boucle, miroir]
const NOUVELLES := {
	"roulade": ["ual1", "Roll", false, false],
	"assis_debut": ["ual1", "Sitting_Enter", false, false],
	"assis": ["ual1", "Sitting_Idle_Loop", true, false],
	"assis_fin": ["ual1", "Sitting_Exit", false, false],
	"nage": ["ual1", "Swim_Fwd_Loop", true, false],
	"nage_place": ["ual1", "Swim_Idle_Loop", true, false],
	"saut_debut": ["ual1", "Jump_Start", false, false],
	"saut_air": ["ual1", "Jump_Loop", true, false],
	"atterrir": ["ual1", "Jump_Land", false, false],
	"genou": ["ual1", "Fixing_Kneeling", true, false],
	"mort_miroir": ["ual1", "Death01", false, true],
	"touche_miroir": ["ual1", "Hit_Chest", false, true],
	"escalade": ["ual2", "ClimbUp_1m_RM", false, false],
	"frappe2_fin": ["ual2", "Sword_Regular_A_Rec", false, false],
	"frappe3_fin": ["ual2", "Sword_Regular_B_Rec", false, false],
	"combo": ["ual2", "Sword_Regular_Combo", false, false],
	"crochet_fin": ["ual2", "Melee_Hook_Rec", false, false],
	"lancer": ["ual2", "OverhandThrow", false, false],
	"recolter": ["ual2", "Farm_Harvest", false, false],
	"planter": ["ual2", "Farm_PlantSeed", false, false],
	"porter": ["ual2", "Walk_Carry_Loop", true, false],
	"reception": ["ual2", "NinjaJump_Land", false, false],
	"glissade": ["ual2", "Slide_Loop", true, false],
	# contrôle du reciblage : comparé à « idle » (même animation UAL, transférée autrefois)
	"_controle_idle": ["ual1", "Idle_Loop", true, false],
	"_controle_z_idle": ["ual2", "Zombie_Idle_Loop", true, false],
	"_controle_mort": ["ual1", "Death01", false, false],
	"_controle_touche": ["ual1", "Hit_Chest", false, false],
	"_controle_coup_poing": ["ual1", "Punch_Jab", false, false],
	"_controle_arme_idle": ["ual1", "Pistol_Idle_Loop", true, false],
	"_controle_frappe2": ["ual2", "Sword_Regular_A", false, false],
}

var sources := {}   # "ual1" -> [scène, Skeleton3D, AnimationPlayer]
var redresse := {}  # "ual1" -> rotation qui ramène la source dans le repère du pack 2


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	for k in ["ual1", "ual2"]:
		var p := SRC + ("ual1_standard.glb" if k == "ual1" else "ual2_standard.glb")
		var doc = FBXDocument.new() if p.ends_with(".fbx") else GLTFDocument.new()
		var st = FBXState.new() if p.ends_with(".fbx") else GLTFState.new()
		if doc.append_from_file(ProjectSettings.globalize_path(p), st) != OK:
			push_error("lecture impossible : " + p)
			quit(1)
			return
		var sc: Node = doc.generate_scene(st)
		root.add_child(sc)
		sources[k] = [sc, sc.find_children("*", "Skeleton3D", true, false)[0], sc.find_children("*", "AnimationPlayer", true, false)[0]]
	await process_frame
	# orientation d'ensemble de chaque source (le FBX n'a pas les mêmes axes que le pack 2) : repère
	# bassin -> tête / main gauche -> main droite en A_TPose, ramené sur celui du pack 2
	var f2 := _repere("ual2")
	for k in sources:
		redresse[k] = f2 * _repere(k).inverse()
	for nom in ["homme", "femme"]:
		_completer(nom)
	quit()


func _anim_source(k: String, nom: String) -> String:
	var ap: AnimationPlayer = sources[k][2]
	for a in ap.get_animation_list():
		if a == nom or a.ends_with("|" + nom):
			return a
	push_error("animation introuvable : %s %s" % [k, nom])
	return ""


func _completer(nom: String) -> void:
	var chemin := "res://modeles/persos/%s.scn" % nom
	var inst: Node3D = load(chemin).instantiate()
	root.add_child(inst)
	var st: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var lib: AnimationLibrary = ap.get_animation_library("")
	var piste_sk := str(inst.get_path_to(st))
	for n in NOUVELLES:
		var c: Array = NOUVELLES[n]
		var an := _recibler(st, piste_sk, c[0], _anim_source(c[0], c[1]), c[3])
		an.loop_mode = Animation.LOOP_LINEAR if c[2] else Animation.LOOP_NONE
		if n.begins_with("_controle"):
			_comparer(n, an, ap.get_animation(n.trim_prefix("_controle_")))
			if OS.get_environment("GARDER_CONTROLES") == "":
				continue
		if lib.has_animation(n):
			lib.remove_animation(n)
		lib.add_animation(n, an)
	var ps := PackedScene.new()
	_proprietaire(inst, inst)
	ps.pack(inst)
	ResourceSaver.save(ps, chemin)
	print(nom, " : ", lib.get_animation_list().size(), " animations")
	inst.queue_free()


func _proprietaire(n: Node, racine: Node) -> void:
	for e in n.get_children():
		if e.owner == null:
			e.owner = racine
		_proprietaire(e, racine)


static func _miroir_nom(n: String) -> String:
	if n.ends_with("_l"):
		return n.left(-2) + "_r"
	if n.ends_with("_r"):
		return n.left(-2) + "_l"
	return n


func _monde_repos(sk: Skeleton3D, b: int) -> Transform3D:
	return sk.global_transform * sk.get_bone_global_rest(b)


func _monde_pose(sk: Skeleton3D, b: int) -> Transform3D:
	return sk.global_transform * sk.get_bone_global_pose(b)


func _repere(k: String) -> Basis:
	var p := _poses(k, _anim_source(k, "A_TPose"), 0.0, false)
	var haut: Vector3 = ((p["Head"] as Transform3D).origin - (p["pelvis"] as Transform3D).origin).normalized()
	var cote: Vector3 = (p["hand_r"] as Transform3D).origin - (p["hand_l"] as Transform3D).origin
	cote = (cote - haut * cote.dot(haut)).normalized()
	return Basis(cote, haut, cote.cross(haut))


## nom d'os Rigify (version Godot du pack 1 : DEF-upper_arm.L…) -> nom UAL / Unreal (upperarm_l…)
static func _nom_ue(n: String) -> String:
	if not n.begins_with("DEF-"):
		return n
	n = n.trim_prefix("DEF-")
	var cote := ""
	if n.ends_with(".L") or n.ends_with(".R"):
		cote = "_" + n.right(1).to_lower()
		n = n.left(-2)
	const NOMS := {"hips": "pelvis", "spine.001": "spine_01", "spine.002": "spine_02", "spine.003": "spine_03",
		"neck": "neck_01", "head": "Head", "shoulder": "clavicle", "upper_arm": "upperarm", "forearm": "lowerarm",
		"hand": "hand", "thigh": "thigh", "shin": "calf", "foot": "foot", "toe": "ball"}
	if NOMS.has(n):
		return NOMS[n] + cote
	# doigts : f_index.01 -> index_01, thumb.01 -> thumb_01
	return n.trim_prefix("f_").replace(".", "_") + cote


## pose monde de chaque os de la source à l'instant t, par nom (retournée gauche / droite pour un miroir)
func _poses(k: String, nom_src: String, temps: float, miroir: bool) -> Dictionary:
	var ss: Skeleton3D = sources[k][1]
	var aps: AnimationPlayer = sources[k][2]
	ss.reset_bone_poses()
	aps.play(nom_src)
	aps.seek(temps, true)
	var mx := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	var r := {}
	for bs in ss.get_bone_count():
		var w := _monde_pose(ss, bs)
		var nb := _nom_ue(ss.get_bone_name(bs))
		var g: Basis = redresse.get(k, Basis())
		var base := g * w.basis.orthonormalized()
		w.origin = g * w.origin
		if miroir:
			nb = _miroir_nom(nb)
			base = mx * base * mx
			w.origin.x = -w.origin.x
		r[nb] = Transform3D(base, w.origin)
	return r


func _recibler(st: Skeleton3D, piste_sk: String, k: String, nom_src: String, miroir: bool) -> Animation:
	var a_src: Animation = (sources[k][2] as AnimationPlayer).get_animation(nom_src)
	# A_TPose de la source (miroir compris) et du mannequin (écart du pack 2 à son repos, porté sur le repos cible)
	var s_a := _poses(k, _anim_source(k, "A_TPose"), 0.0, miroir)
	var u2_a := _poses("ual2", _anim_source("ual2", "A_TPose"), 0.0, false)
	var u2: Skeleton3D = sources["ual2"][1]
	var corr := {}
	var t_a := {}
	for b in st.get_bone_count():
		var nb := st.get_bone_name(b)
		var bu := u2.find_bone(nb)
		if not s_a.has(nb) or bu < 0:
			continue
		var r_u2 := _monde_repos(u2, bu)
		var ecart2: Basis = (u2_a[nb] as Transform3D).basis * r_u2.basis.orthonormalized().inverse()
		t_a[b] = Transform3D(ecart2 * st.get_bone_global_rest(b).basis.orthonormalized(),
				st.get_bone_global_rest(b).origin + ((u2_a[nb] as Transform3D).origin - r_u2.origin))
		corr[b] = (s_a[nb] as Transform3D).basis.inverse() * (t_a[b] as Transform3D).basis
	var an := Animation.new()
	an.length = a_src.length
	var pistes := {}
	for b in corr:
		pistes[b] = an.add_track(Animation.TYPE_ROTATION_3D)
		an.track_set_path(pistes[b], NodePath("%s:%s" % [piste_sk, st.get_bone_name(b)]))
	var bp_t := st.find_bone("pelvis")
	var piste_pos := an.add_track(Animation.TYPE_POSITION_3D)
	an.track_set_path(piste_pos, NodePath("%s:pelvis" % piste_sk))
	var echelle: float = (t_a[bp_t] as Transform3D).origin.y / (s_a["pelvis"] as Transform3D).origin.y
	var nb_cles := maxi(2, int(ceil(a_src.length * FPS)) + 1)
	for i in nb_cles:
		var temps := minf(a_src.length, i / FPS)
		var ps := _poses(k, nom_src, temps, miroir)
		var mondes := {}
		for b in st.get_bone_count():
			var p := st.get_bone_parent(b)
			var parent_xf: Transform3D = mondes[p] if p >= 0 else Transform3D.IDENTITY
			if not corr.has(b):
				mondes[b] = parent_xf * st.get_bone_rest(b)
				continue
			var nb := st.get_bone_name(b)
			var origine: Vector3 = (parent_xf * st.get_bone_rest(b)).origin
			if b == bp_t:
				origine = (t_a[b] as Transform3D).origin + ((ps[nb] as Transform3D).origin - (s_a[nb] as Transform3D).origin) * echelle
			mondes[b] = Transform3D(((ps[nb] as Transform3D).basis * corr[b]).orthonormalized(), origine)
			var local: Transform3D = parent_xf.affine_inverse() * mondes[b]
			an.rotation_track_insert_key(pistes[b], temps, local.basis.get_rotation_quaternion())
			if b == bp_t:
				an.position_track_insert_key(piste_pos, temps, local.origin)
	return an


## écart moyen (radians) entre l'Idle reciblé et l'ancien « idle » du jeu, au même instant
func _comparer(nom: String, a: Animation, ref: Animation) -> void:
	var total := 0.0
	var n := 0
	var pire := ["", 0.0]
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var tr := ref.find_track(a.track_get_path(t), Animation.TYPE_ROTATION_3D)
		if tr < 0:
			continue
		for temps in [0.0, 0.5, 1.0]:
			var e := 2.0 * acos(minf(1.0, absf((a.rotation_track_interpolate(t, temps) as Quaternion).dot(ref.rotation_track_interpolate(tr, temps)))))
			total += e
			n += 1
			if e > 0.15 and temps == 0.5 and nom.contains("_idle") and not nom.contains("z_"): print("    ", str(a.track_get_path(t)).get_slice(":", 1), " ", snappedf(e, 0.01))
			if e > pire[1]:
				pire = [str(a.track_get_path(t)), e]
	print("contrôle %s : écart moyen %.3f rad, pire %s %.3f" % [nom, total / maxi(n, 1), pire[0], pire[1]])
