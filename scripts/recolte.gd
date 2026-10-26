extends Node3D
## Récolte des ressources du décor avec un outil de mêlée (le coup porté sur le décor) :
##  - hache : arbres (plusieurs coups, l'arbre tombe puis disparaît, il reste une souche) -> bûches ;
##  - pioche : rochers (ils se brisent) -> pierres, parfois du minerai de fer ou de la ferraille ;
##  - hache ou pioche : épaves de voitures (démontées puis vidées) -> ferraille, pièces auto, pneus, batterie…
## Rien ne repousse : la carte compte des milliers d'arbres et de rochers et des centaines d'épaves, et ce qui
## a été coupé / cassé / vidé reste ainsi cohérent d'une partie à l'autre. L'état est mémorisé par numéro
## (ordre de génération : même graine = mêmes numéros) et sauvegardé (`etat()` / `appliquer()`).

const Decor = preload("res://scripts/decor.gd")
const OUTILS := ["hache", "pioche"]
const CASE := 8.0
const DUREE_CHUTE := 1.6

var world: Node = null
var index := {}                 # Vector2i -> [[genre, n°], …]  (genre : "a" arbre, "r" rocher, "e" épave)
var coups := {}                 # "a12" -> coups déjà portés
var faits := {"a": {}, "r": {}, "e": {}}   # n° -> true (coupé, cassé, vidé)
var chutes: Array = []          # arbres en train de tomber {i, t, axe}


func installer(w: Node) -> void:
	world = w
	for i in w.arbres_ref.size():
		_indexer("a", i, (w.arbres_ref[i][3] as Transform3D).origin)
	for i in w.rochers.size():
		_indexer("r", i, (w.rochers[i].n as Node3D).position)
	for i in w.epaves.size():
		_indexer("e", i, (w.epaves[i].n as Node3D).position)


func _indexer(genre: String, i: int, p: Vector3) -> void:
	var c := Vector2i(floori(p.x / CASE), floori(p.z / CASE))
	if not index.has(c):
		index[c] = []
	index[c].append([genre, i])


## Position (base) et rayon de prise d'une ressource.
func _lieu(genre: String, i: int) -> Array:
	match genre:
		"a":
			var xf: Transform3D = world.arbres_ref[i][3]
			return [xf.origin, 0.9 * xf.basis.get_scale().x]
		"r":
			var r: Dictionary = world.rochers[i]
			var t := Decor.taille("rocher") * float(r.k)
			return [(r.n as Node3D).position, maxf(t.x, t.z) * 0.6 + 0.5]
		_:
			return [(world.epaves[i].n as Node3D).position, 2.8]


## Ressource la plus proche du point touché (repère du monde = repère global, le monde est à l'origine).
func _trouver(pos: Vector3) -> Array:
	var c0 := Vector2i(floori(pos.x / CASE), floori(pos.z / CASE))
	var best := []
	var dmin := INF
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for e in index.get(c0 + Vector2i(dx, dz), []):
				if faits[e[0]].has(e[1]):
					continue
				var l := _lieu(e[0], e[1])
				var p: Vector3 = l[0]
				var d := Vector2(p.x - pos.x, p.z - pos.z).length()
				if d < float(l[1]) and d < dmin:
					dmin = d
					best = e
	return best


## Compétence qui règle le rendement : survie pour les arbres et les rochers, fabrication pour les épaves.
static func competence(genre: String) -> String:
	return "fabrication" if genre == "e" else "survie"


## Bonus de compétence (niveau 0 à 10) : -4 % de coups par niveau (au moins 2), +6 % de ressources par niveau.
static func moins_de_coups(niv: int) -> float:
	return 1.0 - 0.04 * niv


static func plus_de_ressources(niv: int) -> float:
	return 1.0 + 0.06 * niv


func _niv(joueur: Node, genre: String) -> int:
	if joueur == null or joueur.get("prog") == null:
		return 0
	var c := competence(genre)
	return int(joueur.prog.comp[c].niv) + (2 if c == "survie" and joueur.prog.a("bucheron") else 0)


func _coups_requis(genre: String, i: int, outil: String, niv := 0) -> int:
	return maxi(2, int(round(_coups_base(genre, i, outil) * moins_de_coups(niv))))


func _coups_base(genre: String, i: int, outil: String) -> int:
	match genre:
		"a":
			var s: float = (world.arbres_ref[i][3] as Transform3D).basis.get_scale().x
			return int(round(4.0 + 3.0 * s))                     # 6 à 8 coups de hache
		"r":
			return int(round(3.0 + 2.5 * float(world.rochers[i].k)))   # 5 à 13 coups de pioche
		_:
			return 7 if outil == "pioche" else 9


## Coup d'outil porté sur le décor au point `pos` : renvoie true si une ressource a été frappée.
func frapper(pos: Vector3, dir: Vector3, outil: String, joueur: Node) -> bool:
	if not outil in OUTILS:
		return false
	var e := _trouver(pos)
	if e.is_empty():
		return false
	var genre: String = e[0]
	var i: int = e[1]
	if genre == "a" and outil != "hache":
		Game.msg("Il faut une hache pour couper un arbre.")
		Game.play_ui("coup", -4.0, 0.1, 0.8)
		return true
	if genre == "r" and outil != "pioche":
		Game.msg("La hache rebondit sur la pierre : il faut une pioche.")
		Game.play_ui("impact_metal", -6.0, 0.1, 0.7)
		return true
	var cle := genre + str(i)
	var n := int(coups.get(cle, 0)) + 1
	var niv := _niv(joueur, genre)
	var requis := _coups_requis(genre, i, outil, niv)
	var bonus := plus_de_ressources(niv)
	coups[cle] = n
	Game.make_noise(pos, 14.0)
	match genre:
		"a":
			Game.play_ui("impact_mur", -1.0, 0.1, 0.62)
			Game.play_ui("coup", -6.0, 0.1, 0.7)
			_eclats(pos, dir, Color(0.72, 0.58, 0.38), 5)
		"r":
			Game.play_ui("impact_metal", -3.0, 0.1, 0.55)
			Game.play_ui("impact_mur", -6.0, 0.1, 1.2)
			_eclats(pos, dir, Color(0.55, 0.55, 0.53), 6)
		_:
			Game.play_ui("impact_metal", -2.0, 0.12, 0.85)
			_eclats(pos, dir, Color(0.4, 0.33, 0.28), 4)
	var nom: String = {"a": "Arbre", "r": "Rocher", "e": "Épave"}[genre]
	Game.texte_flottant.emit(pos + Vector3.UP * 0.3, "%s %d / %d" % [nom, n, requis], Color(0.85, 0.78, 0.6))
	if n < requis:
		return true
	coups.erase(cle)
	faits[genre][i] = true
	match genre:
		"a":
			_abattre(i, dir, true)
			_donner(joueur, "buche", _qte((2.0 + round(2.0 * (world.arbres_ref[i][3] as Transform3D).basis.get_scale().x)) * bonus))
			if randf() < 0.3 * bonus:
				_donner(joueur, "planche", 1)
			joueur.prog.gagner("survie", 6)
		"r":
			_briser(i, true)
			var k: float = world.rochers[i].k
			_donner(joueur, "pierre", _qte((2.0 + round(1.5 * k)) * bonus))
			if randf() < 0.3 * bonus:
				_donner(joueur, "minerai", _qte(randi_range(1, 1 + int(k)) * bonus))
			if randf() < 0.12:
				_donner(joueur, "ferraille", 1)
			joueur.prog.gagner("survie", 6)
		_:
			_vider(i, true)
			_donner(joueur, "ferraille", _qte(randi_range(2, 4) * bonus))
			_donner(joueur, "piece_auto", _qte(randi_range(1, 2) * bonus))
			if randf() < 0.5 * bonus:
				_donner(joueur, "pneu", 1)
			if randf() < 0.35:
				_donner(joueur, "batterie", 1)
			if randf() < 0.25:
				_donner(joueur, "essence", 1)
			if randf() < 0.4:
				_donner(joueur, "tissu", _qte(randi_range(1, 2) * bonus))
			joueur.prog.gagner("fabrication", 8)
	return true


## Quantité arrondie au hasard (2,4 -> 2 ou 3, 3 fois sur 5 deux) : le bonus compte même sur de petites quantités.
func _qte(x: float) -> int:
	return int(floor(x)) + (1 if randf() < x - floor(x) else 0)


func _donner(joueur: Node, id: String, n: int) -> void:
	joueur.add_item(id, n)   # (le fil des objets du HUD affiche « +n »)


## Arbre coupé : la collision disparaît, le tronc tombe (animé) puis s'efface ; une souche reste.
func _abattre(i: int, dir: Vector3, anime: bool) -> void:
	var ref: Array = world.arbres_ref[i]
	(ref[2] as CollisionShape3D).disabled = true
	var xf: Transform3D = ref[3]
	var souche := Decor.instance("souche")
	if souche:
		souche.position = xf.origin
		souche.rotation.y = randf() * TAU
		souche.scale = Vector3.ONE * 0.8 * xf.basis.get_scale().x
		add_child(souche)
		Decor.distance(souche, 160.0)
	if anime and world.arbres_mm.has(ref[0]):
		var d := Vector3(dir.x, 0, dir.z).normalized()
		if d == Vector3.ZERO:
			d = Vector3.FORWARD
		chutes.append({"i": i, "t": 0.0, "d": d, "axe": Vector3.UP.cross(d).normalized()})   # le haut bascule vers d
		Game.play_3d("vent_lourd", xf.origin + Vector3.UP * 3.0, 0.0, 0.1, 60.0)
	else:
		_arbre_xf(i, Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin))


func _arbre_xf(i: int, t: Transform3D) -> void:
	var ref: Array = world.arbres_ref[i]
	var mm: MultiMesh = world.arbres_mm.get(ref[0])
	if mm:
		mm.set_instance_transform(int(ref[1]), t)


func _process(delta: float) -> void:
	for c in chutes:
		c.t += delta
		var xf: Transform3D = world.arbres_ref[c.i][3]
		var k := clampf(c.t / DUREE_CHUTE, 0.0, 1.0)
		var ang := k * k * 1.5                       # chute de plus en plus rapide jusqu'au sol (~86°)
		if c.t < DUREE_CHUTE + 2.5:
			_arbre_xf(c.i, Transform3D(Basis(c.axe, ang) * xf.basis, xf.origin))
			if c.t >= DUREE_CHUTE and not c.has("sol"):
				c["sol"] = true
				Game.play_3d("atterrissage", xf.origin + c.d * 4.0, 6.0, 0.1, 70.0)
				Game.play_3d("coup", xf.origin + Vector3.UP, 2.0, 0.1, 60.0)
		else:
			# le tronc couché s'enfonce et disparaît (le bois est dans le sac)
			var s := clampf(1.0 - (c.t - DUREE_CHUTE - 2.5) / 1.0, 0.0, 1.0)
			_arbre_xf(c.i, Transform3D(Basis(c.axe, ang) * xf.basis.scaled(Vector3.ONE * maxf(s, 0.0001)), xf.origin))
	chutes = chutes.filter(func(c): return c.t < DUREE_CHUTE + 3.5)


## Rocher brisé : il disparaît en éclats.
func _briser(i: int, anime: bool) -> void:
	var r: Dictionary = world.rochers[i]
	var n: Node3D = r.n
	(r.cs as CollisionShape3D).disabled = true
	n.visible = false
	if anime:
		var t := Decor.taille("rocher") * float(r.k)
		for k in 6:
			_eclats(n.position + Vector3(randf_range(-0.5, 0.5) * t.x, t.y * 0.5, randf_range(-0.5, 0.5) * t.z), Vector3.UP, Color(0.5, 0.5, 0.48), 4, 0.12)
		Game.play_3d("explosion", n.position, -14.0, 0.1, 40.0)
		Game.play_3d("impact_mur", n.position, 2.0, 0.1, 40.0)


## Épave vidée : assombrie (rouillée, démontée), on ne peut plus rien en tirer.
func _vider(i: int, anime: bool) -> void:
	var n: Node3D = world.epaves[i].n
	Decor.peindre(n, Color(0.28, 0.2, 0.15))
	if anime:
		Game.play_3d("impact_metal", n.position + Vector3.UP, 2.0, 0.1, 40.0)


## Petits éclats (bois, pierre, métal) projetés au point d'impact.
func _eclats(pos: Vector3, dir: Vector3, col: Color, nb: int, taille := 0.05) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * taille
	for k in nb:
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = pos
		var v := (-dir * 2.0 + Vector3(randf_range(-1.5, 1.5), randf_range(1.0, 3.0), randf_range(-1.5, 1.5)))
		var fin := pos + v * 0.35 + Vector3.DOWN * 0.5
		var tw := mi.create_tween()
		tw.tween_property(mi, "global_position", fin, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mi, "rotation", Vector3(randf() * 6.0, randf() * 6.0, 0), 0.45)
		tw.tween_callback(mi.queue_free)


# ================================================================ sauvegarde
func etat() -> Dictionary:
	return {"a": faits.a.keys(), "r": faits.r.keys(), "e": faits.e.keys()}


func appliquer(d: Dictionary) -> void:
	for genre in ["a", "r", "e"]:
		for v in d.get(genre, []):
			var i := int(v)
			var liste: Array = world.arbres_ref if genre == "a" else (world.rochers if genre == "r" else world.epaves)
			if i < 0 or i >= liste.size() or faits[genre].has(i):
				continue
			faits[genre][i] = true
			match genre:
				"a":
					_abattre(i, Vector3.FORWARD, false)
				"r":
					_briser(i, false)
				_:
					_vider(i, false)
