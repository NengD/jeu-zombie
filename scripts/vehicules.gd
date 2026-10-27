extends Node3D
## Voitures réparables et véhicules conduisibles (nœud `Vehicules` de main.gd ; véhicule : scripts/vehicule.gd).
## Une voiture garée sur six environ (`world_gen._car`, méta « garee ») peut être réparée : pas les épaves brûlées
## (méta « brulee »), ni les motos, ni les voitures déjà vidées par la récolte. Tirage fixe par n° d'épave et graine.
## [F] devant elle : ce qui manque (3 pièces auto, 1 batterie, 1 jerrican), ou la réparation quand tout y est.
## La voiture réparée devient un VehicleBody3D enfant de ce nœud : hors des morceaux de la carte (toujours dans
## l'arbre), l'épave d'origine est cachée et sa collision coupée. Sauvegarde : `etat()` / `appliquer()` (clé « vehicules » :
## un élément par véhicule + un élément {"siphon": {n°: jerricans restants}}).
## Siphonnage : toutes les voitures garées non brûlées ont un fond de réservoir (`fond` : 0, 1 ou 2 jerricans, 60 %
## en ont) ; accroupi [F] avec un `tuyau` = un jerrican (« essence »). Voiture réparée : son fond s'ajoute au plein.

const Decor = preload("res://scripts/decor.gd")
const Vehicule = preload("res://scripts/vehicule.gd")
const BESOINS := {"piece_auto": 3, "batterie": 1, "essence": 1}
const PART := 0.17

var world: Node = null
var pannes := {}             # n° d'épave -> Panne (StaticBody3D d'interaction) : voitures garées non brûlées
var reparables := {}         # n° d'épave -> true : celles qui se réparent
var siphon := {}             # n° d'épave -> jerricans restants (si déjà siphonnée)


class Panne extends StaticBody3D:
	var gestion: Node = null
	var i := -1

	func get_prompt() -> String:
		return gestion.prompt(i)

	func interact(joueur: Node) -> void:
		gestion.interagir(i, joueur)


func installer(w: Node) -> void:
	world = w
	Vehicule.derniere = null   # nouvelle partie : pas encore de voiture conduite
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
		if _tirage(i) < PART:
			reparables[i] = true
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
		pannes[i] = b


func _tirage(i: int, sel := 17) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash(i * 7919 + Game.graine_monde * 31 + sel)
	return r.randf()


## Jerricans encore dans le réservoir de l'épave n° i.
func fond(i: int) -> int:
	if siphon.has(i):
		return int(siphon[i])
	var r := _tirage(i, 53)
	return 0 if r < 0.4 else (1 if r < 0.88 else 2)


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
	var p = Game.player
	if _videe(i) or p == null:
		return ""
	var s := ""
	if reparables.has(i):
		var m := manque(p)
		s = "[F] Réparer la voiture (3 pièces auto, 1 batterie, 1 jerrican)" if m.is_empty() else "Voiture réparable — il manque : " + ", ".join(m)
	if p.count("tuyau") > 0:
		var f := fond(i)
		var l := "accroupi : [F] siphonner l'essence (%s)" % ("reste de quoi remplir %d jerrican%s" % [f, "s" if f > 1 else ""]) if f > 0 else "Réservoir vide"
		s = l if s == "" else s + "\n" + l
	return s


func interagir(i: int, joueur: Node) -> void:
	if _videe(i):
		return
	if joueur.crouching and joueur.count("tuyau") > 0:
		siphonner(i, joueur)
	elif reparables.has(i):
		reparer(i, joueur)


func siphonner(i: int, joueur: Node) -> void:
	var f := fond(i)
	if f <= 0:
		Game.msg("Le réservoir est vide.")
		return
	siphon[i] = f - 1
	joueur.add_item("essence", 1)
	joueur.geste("genou")
	Game.make_noise((world.epaves[i].n as Node3D).position, 6.0)
	Game.msg("Essence siphonnée (1 jerrican)." + (" Le réservoir est vide." if f - 1 <= 0 else ""))


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
	var plein := minf(Vehicule.ESSENCE_MAX, Vehicule.JERRICAN * (1 + fond(i)))   # le fond du réservoir s'ajoute
	siphon[i] = 0
	creer(i, String(n.get_meta("garee")), Transform3D(Basis(Vector3.UP, n.rotation.y), n.position + Vector3.UP * 0.05),
			plein, Vehicule.PV_MAX)
	Game.msg("Voiture réparée ! [F] pour monter (essence %d L)." % int(plein))


## Crée le véhicule (modèle copié de l'épave, peinture comprise) et retire l'épave du décor.
func creer(i: int, id: String, xf: Transform3D, essence: float, pv: float, coffre = null) -> Node:
	var v = Vehicule.new()
	v.coffre_donnees = coffre
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
	if pannes.has(i):
		pannes[i].queue_free()
		pannes.erase(i)
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
	if not siphon.is_empty():
		var s := {}
		for k in siphon:
			s[str(k)] = siphon[k]
		res.append({"siphon": s})
	return res


## `meme_monde` : sauvegarde de la même version de la carte (les n° d'épaves désignent les mêmes voitures).
func appliquer(liste: Array, meme_monde: bool) -> void:
	for d in liste:
		if not (d is Dictionary):
			continue
		if d.has("siphon"):
			if meme_monde and d.siphon is Dictionary:
				for k in d.siphon:
					siphon[int(k)] = int(d.siphon[k])
			continue
		var i := int(d.get("e", -1)) if meme_monde else -1
		if i >= world.epaves.size():
			i = -1
		var id := String(d.get("id", "voiture1"))
		var pos: Array = d.get("pos", [0, 0, 0])
		var o := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		o.y = maxf(o.y, Game.hauteur(o.x, o.z)) + 0.05
		var v := creer(i, id, Transform3D(Basis(Vector3.UP, float(d.get("rot", 0.0))), o), float(d.get("essence", 0.0)),
				float(d.get("pv", Vehicule.PV_MAX)), d.get("coffre"))
		if d.get("derniere", false):
			Vehicule.derniere = v
