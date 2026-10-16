class_name Decor
extends RefCounted
## Modèles de décor (res://modeles/props/*.scn, créés par outils/godot/normaliser_props.gd).
## Chaque modèle a son origine au centre de sa base et sa face avant vers +Z.

static var _scenes := {}
static var _tailles := {}
static var _peintures := {}


static func tailles() -> Dictionary:
	if _tailles.is_empty() and FileAccess.file_exists("res://modeles/props/tailles.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://modeles/props/tailles.json"))
		if d is Dictionary:
			_tailles = d
	return _tailles


static func existe(id: String) -> bool:
	return ResourceLoader.exists("res://modeles/props/%s.scn" % id)


## Taille réelle du modèle (largeur x hauteur x profondeur).
static func taille(id: String) -> Vector3:
	var t = tailles().get(id, null)
	if t is Array and t.size() == 3:
		return Vector3(t[0], t[1], t[2])
	return Vector3.ONE


static func instance(id: String) -> Node3D:
	if not _scenes.has(id):
		var p := "res://modeles/props/%s.scn" % id
		_scenes[id] = load(p) if ResourceLoader.exists(p) else null
	var ps: PackedScene = _scenes[id]
	return ps.instantiate() if ps else null


## Modèle mis à l'échelle (uniforme) pour tenir dans la boîte « boite » (x = largeur, z = profondeur).
static func ajuste(id: String, boite: Vector3) -> Node3D:
	var n := instance(id)
	if n == null:
		return null
	var t := taille(id)
	var k := minf(boite.x / maxf(t.x, 0.01), minf(boite.y / maxf(t.y, 0.01), boite.z / maxf(t.z, 0.01)))
	# on accepte un modèle un peu plus haut que prévu plutôt que trop petit
	k = clampf(maxf(k, boite.y / maxf(t.y, 0.01) * 0.85), 0.3, 3.0)
	k = minf(k, minf(boite.x / maxf(t.x, 0.01), boite.z / maxf(t.z, 0.01)) * 1.08)
	n.scale = Vector3.ONE * k
	return n


## Repeint la carrosserie d'une voiture (matériau « Carrosserie »).
static func peindre(n: Node, couleur: Color) -> void:
	for g in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = g
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m and m.resource_name == "Carrosserie":
				var cle := couleur.to_html()
				if not _peintures.has(cle):
					var c: StandardMaterial3D = m.duplicate()
					c.albedo_color = couleur
					_peintures[cle] = c
				mi.set_surface_override_material(s, _peintures[cle])


static func distance(n: Node, d: float) -> void:
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		g.visibility_range_end = d
		g.visibility_range_end_margin = d * 0.1
