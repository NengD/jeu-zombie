extends SceneTree
## Cocktail Molotov : bouteille d'alcool « Bottle 2 » (Quaternius, CC0 : res://modeles/objets/bouteille2.scn)
## bouchée d'un chiffon noué au goulot, dont un pan pend sur le côté.
## Deux scènes avec les mêmes maillages :
##  - res://modeles/objets/molotov.scn : debout, posée à y = 0 (tas au sol, étal de l'armurier) ;
##  - res://modeles/armes/molotov.scn : goulot vers -Z, origine dans la main (prise sur le corps de la bouteille),
##    comme les armes de mêlée (player.gd la relève de 80°) ; méta `goulot` = haut du chiffon (flamme de grenade.gd).
## Lancer : godot --headless --path . -s res://outils/godot/creer_molotov.gd

const ECHELLE := 0.85          # bouteille de 0,3 m → 0,255 m
const PRISE := 0.09            # hauteur de la main sur la bouteille (m, après échelle)


func _initialize() -> void:
	var objet := _bouteille()
	var haut: float = objet.get_meta("haut")
	_sauver(objet, "res://modeles/objets/molotov.scn")
	var arme := Node3D.new()
	arme.name = "molotov"
	var b := _bouteille()
	b.rotation.x = -PI / 2.0                     # +Y (goulot) → -Z
	b.position = Vector3(0, 0, PRISE)
	arme.add_child(b)
	_posseder(arme, arme)
	arme.set_meta("goulot", Vector3(0, 0, PRISE - haut))
	_sauver(arme, "res://modeles/armes/molotov.scn")
	quit()


func _bouteille() -> Node3D:
	var racine := Node3D.new()
	racine.name = "molotov"
	var src: Node3D = load("res://modeles/objets/bouteille2.scn").instantiate()
	src.scale = Vector3.ONE * ECHELLE
	racine.add_child(src)
	var h := 0.3 * ECHELLE                       # haut du goulot
	var tissu := StandardMaterial3D.new()
	tissu.albedo_color = Color(0.72, 0.64, 0.5)
	tissu.roughness = 1.0
	# chiffon enfoncé dans le goulot, noué autour
	var noeud := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.011
	cm.bottom_radius = 0.016
	cm.height = 0.045
	cm.radial_segments = 8
	noeud.mesh = cm
	noeud.material_override = tissu
	noeud.position.y = h - 0.004
	racine.add_child(noeud)
	var bout := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.02, 0.035, 0.012)
	bout.mesh = bm
	bout.material_override = tissu
	bout.position.y = h + 0.03
	bout.rotation.z = 0.25
	racine.add_child(bout)
	# pan qui pend le long du goulot
	var pan := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.026, 0.08, 0.004)
	pan.mesh = pm
	pan.material_override = tissu
	pan.position = Vector3(0.019, h - 0.045, 0.0)
	pan.rotation.z = 0.18
	racine.add_child(pan)
	racine.set_meta("haut", h + 0.045)
	_posseder(racine, racine)
	return racine


func _posseder(n: Node, proprio: Node) -> void:
	for c in n.get_children():
		c.owner = proprio
		if c.scene_file_path == "":              # la bouteille reste une instance de bouteille2.scn
			_posseder(c, proprio)


func _sauver(n: Node3D, chemin: String) -> void:
	var ps := PackedScene.new()
	ps.pack(n)
	var err := ResourceSaver.save(ps, chemin)
	print(chemin, " -> ", err)
	n.free()
