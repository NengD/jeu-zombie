extends Node3D
## Voitures réparables et véhicules conduisibles (nœud `Vehicules` de main.gd ; véhicule : scripts/vehicule.gd).
## Une voiture garée sur six environ (`world_gen._car`, méta « garee ») peut être réparée : pas les épaves brûlées
## (méta « brulee »), ni les motos, ni les voitures déjà vidées par la récolte. Tirage fixe par n° d'épave et graine.
## [F] devant elle : ce qui manque (3 pièces auto, 1 batterie, 1 jerrican), ou la réparation quand tout y est.
## La voiture réparée devient un VehicleBody3D enfant de ce nœud : hors des morceaux de la carte (toujours dans
## l'arbre), l'épave d'origine est cachée et sa collision coupée. Sauvegarde : `etat()` / `appliquer()` (clé « vehicules »).

const Decor = preload("res://scripts/decor.gd")
const Vehicule = preload("res://scripts/vehicule.gd")
const BESOINS := {"piece_auto": 3, "batterie": 1, "essence": 1}
const PART := 0.17

var world: Node = null
var reparables := {}         # n° d'épave -> Panne (StaticBody3D d'interaction)


class Panne extends StaticBody3D:
	var gestion: Node = null
	var i := -1

	func get_prompt() -> String:
		return gestion.prompt(i)

	func interact(joueur: Node) -> void:
		gestion.reparer(i, joueur)


func installer(w: Node) -> void:
	world = w
	for i in w.epaves.size():
		var n: Node3D = w.epaves[i].n
		if not n.has_meta("garee") or n.has_meta("brulee"):
			continue
		var id := String(n.get_meta("garee"))
		if id == "voiture_moto" or not Decor.existe(id):
			continue
		if absf(n.rotation.x) + absf(n.rotation.z) > 0.05 or absf(n.scale.x - 1.0) > 0.01:
			continue
		if absf(n.position.y - Game.hauteur(n.position.x, n.position.z)) > 0.8:
			continue   # sur un pont ou un plancher : laissée en décor
		if _tirage(i) >= PART:
			continue
		var t := Decor.taille(id)
		var b := Panne.new()
		b.gestion = self
		b.i = i
		b.collision_layer = Game.LAYER_INTERACT
		b.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = t + Vector3(0.2, 0.1, 0.2)   # un peu plus grande que la collision de l'épave : visée en premier
		cs.shape = bs
		b.add_child(cs)
		b.position = n.position + Vector3(0, t.y / 2.0, 0)
		b.rotation.y = n.rotation.y
		add_child(b)
		reparables[i] = b


func _tirage(i: int) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash(i * 7919 + Game.graine_monde * 31 + 17)
	return r.randf()


func _videe(i: int) -> bool:
	return Game.recolte != null and Game.recolte.faits.e.has(i)


func manque(joueur: Node) -> Array:
	var res: Array = []
	for id in BESOINS:
		var n: int = BESOINS[id] - joueur.count(id)
		if n > 0:
			res.append("%d × %s" % [n, Items.nom(id)])
	return res


func prompt(i: int) -> String:
	if _videe(i) or Game.player == null:
		return ""
	var m := manque(Game.player)
	if m.is_empty():
		return "[F] Réparer la voiture (3 pièces auto, 1 batterie, 1 jerrican)"
	return "Voiture réparable — il manque : " + ", ".join(m)


func reparer(i: int, joueur: Node) -> void:
	if _videe(i) or not reparables.has(i):
		return
	var m := manque(joueur)
	if not m.is_empty():
		Game.msg("Pour réparer cette voiture, il manque : " + ", ".join(m) + ".")
		Game.play_ui("impact_metal", -10.0, 0.1, 0.8)
		return
	for id in BESOINS:
		joueur.remove_item(id, BESOINS[id])
	var n: Node3D = world.epaves[i].n
	joueur.geste("fouille")
	Game.play_3d("impact_metal", n.position + Vector3.UP, 2.0, 0.1, 40.0)
	Game.make_noise(n.position, 20.0)
	joueur.prog.gagner("fabrication", 25)
	creer(i, String(n.get_meta("garee")), Transform3D(Basis(Vector3.UP, n.rotation.y), n.position + Vector3.UP * 0.05),
			Vehicule.JERRICAN, Vehicule.PV_MAX)
	Game.msg("Voiture réparée ! [F] pour monter (essence %d L)." % int(Vehicule.JERRICAN))


## Crée le véhicule (modèle copié de l'épave, peinture comprise) et retire l'épave du décor.
func creer(i: int, id: String, xf: Transform3D, essence: float, pv: float) -> Node:
	var v = Vehicule.new()
	v.id = id
	v.epave = i
	v.essence = essence
	v.pv = pv
	if i >= 0 and i < world.epaves.size():
		var e: Dictionary = world.epaves[i]
		v.modele = (e.n as Node3D).duplicate()
		(e.n as Node3D).visible = false
		(e.cs as CollisionShape3D).disabled = true
		if Game.recolte:
			Game.recolte.faits.e[i] = true    # plus démontable à la hache
	if reparables.has(i):
		reparables[i].queue_free()
		reparables.erase(i)
	add_child(v)
	v.global_transform = xf
	return v


func vehicules() -> Array:
	return get_children().filter(func(c): return c is VehicleBody3D)


# ================================================================ sauvegarde
func etat() -> Array:
	var res: Array = []
	for v in vehicules():
		res.append(v.vers_dict())
	return res


## `meme_monde` : sauvegarde de la même version de la carte (les n° d'épaves désignent les mêmes voitures).
func appliquer(liste: Array, meme_monde: bool) -> void:
	for d in liste:
		if not (d is Dictionary):
			continue
		var i := int(d.get("e", -1)) if meme_monde else -1
		if i >= world.epaves.size():
			i = -1
		var id := String(d.get("id", "voiture1"))
		var pos: Array = d.get("pos", [0, 0, 0])
		var o := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		o.y = maxf(o.y, Game.hauteur(o.x, o.z)) + 0.05
		creer(i, id, Transform3D(Basis(Vector3.UP, float(d.get("rot", 0.0))), o), float(d.get("essence", 0.0)), float(d.get("pv", Vehicule.PV_MAX)))
