extends SceneTree
## Convertit les petits objets téléchargés (outils/sources_objets/<id d'objet>.glb : « Survival Pack » et
## « Ultimate Food » de Quaternius, CC0) en scènes res://modeles/objets/<id>.scn, montrées dans les tas au sol
## (loot_container.gd, maj_visuel_tas) : plus grande dimension imposée, centré, posé à y = 0.
## Lancer : godot --headless --path . -s res://outils/godot/normaliser_objets.gd

const SRC := "res://outils/sources_objets/"
const OUT := "res://modeles/objets/"
# id : plus grande dimension (m)
const TAILLE := {"conserve": 0.11, "bandage": 0.09, "trousse": 0.3, "essence": 0.42,
	"eau": 0.28, "barre": 0.14}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for id in TAILLE:
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(SRC + id + ".glb", st) != OK:
			push_error("lecture impossible : " + id)
			continue
		var modele: Node3D = doc.generate_scene(st)
		var racine := Node3D.new()
		racine.name = id
		racine.add_child(modele)
		var b := _boite(modele, Transform3D.IDENTITY)
		var k: float = TAILLE[id] / maxf(b.size.x, maxf(b.size.y, b.size.z))
		modele.scale = Vector3.ONE * k
		b = _boite(modele, Transform3D.IDENTITY)
		modele.position = Vector3(-b.get_center().x, -b.position.y, -b.get_center().z)
		for m in modele.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_proprietaire(modele, racine)
		var ps := PackedScene.new()
		ps.pack(racine)
		print(id, " : ", b.size, " -> ", ResourceSaver.save(ps, OUT + id + ".scn", ResourceSaver.FLAG_COMPRESS))
	quit()


func _boite(n: Node, xf: Transform3D) -> AABB:
	var b := AABB()
	var premier := true
	if n is Node3D:
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		b = xf * (n as MeshInstance3D).get_aabb()
		premier = false
	for c in n.get_children():
		var bc := _boite(c, xf)
		if bc.size != Vector3.ZERO:
			b = bc if premier else b.merge(bc)
			premier = false
	return b


func _proprietaire(n: Node, racine: Node) -> void:
	for c in n.get_children():
		c.owner = racine
		_proprietaire(c, racine)
	if n != racine:
		n.owner = racine
