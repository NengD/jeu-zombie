extends Node3D
## Camp de bandits : tentes autour d'un brasero, murets de sacs de sable, caisses et barils,
## deux caisses à fouiller (bon butin) et une bande de bandits armés qui le gardent.

const Decor = preload("res://scripts/decor.gd")
const Effets = preload("res://scripts/effets.gd")
const LootContainer = preload("res://scripts/loot_container.gd")
const Bandit = preload("res://scripts/bandit.gd")

var numero := 0
var effectif := 0               # nombre de bandits au départ (fixe la prime)
var corps: StaticBody3D          # collisions du décor du camp
var flammes: Array = []
var feu: OmniLight3D
var abris: Array = []            # centres des murets et épaves (couverts pour les bandits blessés)


## Construit le camp (le nœud doit déjà être dans l'arbre, placé au centre du camp).
## Renvoie les caisses à fouiller (à enregistrer dans les meubles du monde pour la sauvegarde).
func construire(n: int, rng: RandomNumberGenerator, nb_bandits: int) -> Array:
	numero = n
	effectif = nb_bandits
	add_to_group("camp_bandits")
	corps = StaticBody3D.new()
	corps.collision_layer = Game.LAYER_WORLD
	corps.collision_mask = 0
	add_child(corps)
	_brasero()
	# tentes en cercle, ouvertes vers le feu
	var toiles := [Color(0.33, 0.36, 0.22), Color(0.45, 0.4, 0.3), Color(0.2, 0.3, 0.45), Color(0.4, 0.22, 0.15)]
	var a0 := rng.randf() * TAU
	for k in 3:
		var a := a0 + k * TAU / 3.0 + rng.randf_range(-0.3, 0.3)
		_tente(Vector2(cos(a), sin(a)) * rng.randf_range(6.0, 7.5), toiles[rng.randi() % toiles.size()])
	# murets de sacs de sable entre les tentes
	for k in 3:
		var a := a0 + (k + 0.5) * TAU / 3.0
		_sacs(Vector2(cos(a), sin(a)) * 11.0, a + PI / 2.0)
	# bric-à-brac
	var props := ["caisse_mil", "caisse_mil", "caisse_bois", "baril_rouge", "baril_bleu", "palette", "pneu", "pneu", "jerrican", "jerrican"]
	for id in props:
		var a := rng.randf() * TAU
		_prop(id, Vector2(cos(a), sin(a)) * rng.randf_range(3.0, 9.5), rng.randf() * TAU)
	# table avec caisse de munitions et lanterne allumée
	var at := a0 + PI / 3.0
	var pt := Vector2(cos(at), sin(at)) * 3.2
	var table := _prop("table_bois", pt, at)
	if table:
		var h := Decor.taille("table_bois").y
		_prop("caisse_munitions", pt, at + 0.3, false, h)
		var lan := _prop("lanterne", pt + Vector2(0.35, 0.2), 0.0, false, h)
		if lan:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.8, 0.5)
			l.light_energy = 1.2
			l.omni_range = 5.0
			l.position = Vector3(0, 0.2, 0)
			lan.add_child(l)
	# épave de voiture en bordure (couvert)
	if rng.randf() < 0.7:
		var av := rng.randf() * TAU
		var epave := _prop(["voiture1", "voiture2", "voiture_suv"][rng.randi() % 3], Vector2(cos(av), sin(av)) * 14.0, av + PI / 2.0)
		if epave:
			abris.append(epave.global_position)
	# caisses à fouiller
	var caisses := []
	for k in 2:
		var a := a0 + k * TAU / 3.0 + 0.6
		var c = LootContainer.new()
		c.setup("Caisse des bandits", "camp_bandit", Vector3(1.0, 0.7, 0.6), Color(0.3, 0.33, 0.2), 3)
		add_child(c)
		c.position = _sol(Vector2(cos(a), sin(a)) * 4.6)
		c.rotation.y = -a
		c.set_modele("caisse_mil", 0.0)
		caisses.append(c)
	# bandits
	for k in nb_bandits:
		var b = Bandit.new()
		var a := rng.randf() * TAU
		var pos: Vector3 = to_global(_sol(Vector2(cos(a), sin(a)) * rng.randf_range(2.0, 8.0))) + Vector3.UP * 0.1
		b.setup(numero, global_position, rng)
		add_child(b)
		b.global_position = pos
		b.rotation.y = rng.randf() * TAU
	return caisses


## Point au sol (repère du camp) pour une position horizontale locale.
func _sol(p: Vector2) -> Vector3:
	var w := to_global(Vector3(p.x, 0, p.y))
	return Vector3(p.x, Game.hauteur(w.x, w.z) - global_position.y, p.y)


func _boite_collision(taille: Vector3, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = taille
	cs.shape = bs
	cs.transform = xf
	corps.add_child(cs)


func _prop(id: String, p: Vector2, ang: float, solide := true, dessus := 0.0) -> Node3D:
	var n := Decor.instance(id)
	if n == null:
		return null
	var pos := _sol(p) + Vector3(0, dessus, 0)
	n.position = pos
	n.rotation.y = ang
	add_child(n)
	Decor.distance(n, 120.0)
	if solide:
		var t := Decor.taille(id)
		_boite_collision(t, Transform3D(Basis(Vector3.UP, ang), pos + Vector3(0, t.y / 2.0, 0)))
	return n


func _materiau(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _boite(parent: Node3D, taille: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Tente canadienne : deux pans de toile sur une arête, ouverte côté feu.
func _tente(p: Vector2, toile: Color) -> void:
	var t := Node3D.new()
	t.position = _sol(p)
	t.rotation.y = atan2(p.x, p.y)   # entrée (+Z local) tournée vers le centre
	add_child(t)
	var m := _materiau(toile)
	var l := 2.2
	var h := 1.5
	var long := 2.6
	var pente := sqrt((l / 2.0) * (l / 2.0) + h * h)
	var ang := atan2(h, l / 2.0)
	_boite(t, Vector3(pente, 0.03, long), Vector3(l / 4.0, h / 2.0, 0), m, Vector3(0, 0, PI - ang))
	_boite(t, Vector3(pente, 0.03, long), Vector3(-l / 4.0, h / 2.0, 0), m, Vector3(0, 0, ang))
	# fond triangulaire (approché par un panneau) et tapis de sol
	_boite(t, Vector3(l * 0.55, h * 0.95, 0.03), Vector3(0, h * 0.47, -long / 2.0), m)
	_boite(t, Vector3(l * 0.9, 0.02, long), Vector3(0, 0.01, 0), _materiau(toile.darkened(0.4)))
	# mât et piquets
	var bois := _materiau(Color(0.35, 0.25, 0.15))
	for z in [-long / 2.0, long / 2.0]:
		_boite(t, Vector3(0.04, h, 0.04), Vector3(0, h / 2.0, z), bois)
	_boite_collision(Vector3(l * 0.8, h, long), Transform3D(Basis(Vector3.UP, t.rotation.y), t.position + Vector3(0, h / 2.0, 0)))


## Muret de sacs de sable (deux rangs de six sacs), le long de l'angle donné.
func _sacs(p: Vector2, ang: float) -> void:
	var s := Node3D.new()
	s.position = _sol(p)
	s.rotation.y = ang
	add_child(s)
	var m := _materiau(Color(0.6, 0.53, 0.38))
	for r in 2:
		for k in 6:
			var sac := MeshInstance3D.new()
			var cm := CapsuleMesh.new()
			cm.radius = 0.15
			cm.height = 0.55
			sac.mesh = cm
			sac.material_override = m
			sac.rotation.z = PI / 2.0
			sac.scale = Vector3(1.0, 1.0, 0.75)
			sac.position = Vector3(-1.37 + k * 0.55 + (0.27 if r == 1 else 0.0), 0.14 + r * 0.24, 0)
			s.add_child(sac)
	_boite_collision(Vector3(3.3, 0.55, 0.4), Transform3D(Basis(Vector3.UP, ang), s.position + Vector3(0, 0.27, 0)))
	abris.append(to_global(s.position))


## Bidon-brasero avec des flammes et une lumière vacillante (au centre du camp par défaut).
func _brasero(p := Vector2.ZERO) -> void:
	var b := _prop("brasero", p, 0.0)
	var haut := Decor.taille("brasero").y
	var m := StandardMaterial3D.new()
	m.albedo_texture = Effets._texture("flamme")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1.0, 0.6, 0.25)
	var base := _sol(p) + Vector3(0, haut, 0)
	for k in 3:
		var f := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.55, 0.7)
		f.mesh = q
		f.material_override = m
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.position = base + Vector3(randf_range(-0.1, 0.1), 0.25 + k * 0.08, randf_range(-0.1, 0.1))
		add_child(f)
		flammes.append(f)
	feu = OmniLight3D.new()
	feu.light_color = Color(1.0, 0.6, 0.3)
	feu.light_energy = 2.5
	feu.omni_range = 10.0
	feu.position = base + Vector3(0, 0.6, 0)
	add_child(feu)
	if b == null:
		feu.position.y = _sol(p).y + 1.0


func _process(_delta: float) -> void:
	var p = Game.player
	if p == null or global_position.distance_to(p.global_position) > 150.0:
		return
	var t := Time.get_ticks_msec() / 1000.0
	if feu:
		feu.light_energy = 2.2 + sin(t * 13.0) * 0.3 + sin(t * 7.3) * 0.25
	for k in flammes.size():
		var f: MeshInstance3D = flammes[k]
		f.scale = Vector3.ONE * (0.85 + 0.2 * sin(t * (9.0 + k * 2.3) + k))


## Bandits encore en vie (pour la sauvegarde).
func vivants() -> int:
	var n := 0
	for c in get_children():
		if c.is_in_group("bandits"):
			n += 1
	return n


## Après chargement : ne garder que les bandits encore en vie.
func garder(n: int) -> void:
	for c in get_children():
		if c.is_in_group("bandits"):
			if n > 0:
				n -= 1
			else:
				c.remove_from_group("bandits")
				c.queue_free()
