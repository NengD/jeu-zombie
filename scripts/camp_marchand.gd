extends "res://scripts/camp_bandits.gd"
## Campement d'un marchand : palissade en bois avec une seule entrée (tournée vers la ville, +Z local),
## le stand du marchand au centre, deux tentes, un brasero, un mirador à l'arrière,
## et des gardes armés qui surveillent (deux à l'entrée, un sur le mirador) et abattent les zombies.

const Vendeur = preload("res://scripts/vendeur.gd")
const Garde = preload("res://scripts/garde.gd")
const RAYON := 11.0
const NB_PANS := 18

var vendeur: Node3D
var gardes: Array = []


## Construit le camp (le nœud doit déjà être dans l'arbre, placé et tourné).
func construire_marchand(metier: String, nom_vendeur: String, rng: RandomNumberGenerator) -> void:
	add_to_group("camp_marchand")
	corps = StaticBody3D.new()
	corps.collision_layer = Game.LAYER_WORLD
	corps.collision_mask = 0
	add_child(corps)
	_palissade()
	# entrée : deux murets de sacs de sable en chicane devant l'ouverture
	_sacs(Vector2(-2.6, RAYON + 1.6), 0.0)
	_sacs(Vector2(2.6, RAYON + 1.6), 0.0)
	_mirador(Vector2(0.0, -RAYON + 2.2))
	# le stand au centre, comptoir tourné vers l'entrée (le client se tient côté entrée)
	vendeur = Vendeur.new()
	vendeur.setup(metier, nom_vendeur)
	add_child(vendeur)
	vendeur.position = _sol(Vector2(0.0, -1.0))
	vendeur.rotation.y = PI
	_lumiere(vendeur.position + Vector3(0, 2.2, 0.3), 7.0, 1.4)
	# sol de terre battue, lanternes (allumées la nuit) : quatre poteaux et l'entrée
	_sol_terre()
	for a in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		_lampadaire(Vector2(cos(a), sin(a)) * (RAYON - 1.6))
	var pas_e := TAU / NB_PANS
	for s in [-1.0, 1.0]:
		var ae: float = PI / 2.0 + s * pas_e
		_lumiere(_sol(Vector2(cos(ae), sin(ae)) * (RAYON - 0.4)) + Vector3(0, 2.9, 0), 9.0, 1.6)
	# tentes de part et d'autre, brasero près de l'entrée
	var toiles := [Color(0.33, 0.36, 0.22), Color(0.45, 0.4, 0.3), Color(0.2, 0.3, 0.45)]
	_tente(Vector2(-6.8, -3.0), toiles[rng.randi() % toiles.size()])
	_tente(Vector2(6.8, -3.0), toiles[rng.randi() % toiles.size()])
	_brasero(Vector2(-4.0, 4.0))
	# bric-à-brac le long de la palissade
	var props := ["caisse_bois", "caisse_bois", "caisse_mil", "baril_bleu", "baril_rouge", "palette", "jerrican", "pneu"]
	for id in props:
		var a := rng.randf_range(-PI * 0.95, PI * 0.15) - PI / 2.0
		_prop(id, Vector2(cos(a), sin(a)) * rng.randf_range(RAYON - 2.4, RAYON - 1.3), rng.randf() * TAU)
	# gardes : deux à l'entrée (regard vers l'extérieur), un sur le mirador (regard vers l'arrière)
	var vers_dehors := global_rotation.y + PI
	_garde(Vector3(-2.0, 0.0, RAYON - 0.6), vers_dehors, rng)
	_garde(Vector3(2.0, 0.0, RAYON - 0.6), vers_dehors, rng)
	var g := _garde(Vector3(0.0, 0.0, -RAYON + 2.2), global_rotation.y, rng)
	g.position.y = _sol(Vector2(0.0, -RAYON + 2.2)).y + HAUT_MIRADOR
	g.portee = 40.0


var lampes: Array = []          # lumières allumées seulement la nuit
static var _tex_terre: Texture2D = null


## Sol de terre battue : décalque de terre au bord irrégulier, projeté sur le terrain du camp.
func _sol_terre() -> void:
	if _tex_terre == null:
		_tex_terre = _texture_terre()
	if _tex_terre == null:
		return
	var d := Decal.new()
	d.texture_albedo = _tex_terre
	d.size = Vector3(RAYON * 2.3, 3.0, RAYON * 2.3)
	d.position = _sol(Vector2.ZERO) + Vector3(0, 0.4, 0)
	d.normal_fade = 0.55          # seulement le sol (pas les jambes ni les murs)
	d.upper_fade = 0.15
	d.lower_fade = 0.3
	d.albedo_mix = 0.92
	d.modulate = Color(0.82, 0.74, 0.62)
	d.distance_fade_enabled = true
	d.distance_fade_begin = 140.0
	d.distance_fade_length = 20.0
	add_child(d)


## Texture de terre (textures/terre_albedo.jpg) avec un masque rond au bord irrégulier.
static func _texture_terre() -> Texture2D:
	if not ResourceLoader.exists("res://textures/terre_albedo.jpg"):
		return null
	var src: Image = (load("res://textures/terre_albedo.jpg") as Texture2D).get_image()
	if src == null:
		return null
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var n := 512
	src.resize(n, n)
	var bruit := FastNoiseLite.new()
	bruit.seed = 7
	bruit.frequency = 0.012
	for y in n:
		for x in n:
			var v := Vector2(x - n / 2.0, y - n / 2.0) / (n / 2.0)
			var r := v.length() + bruit.get_noise_2d(x, y) * 0.12
			var c := src.get_pixel(x, y)
			c.a = clampf((0.95 - r) / 0.12, 0.0, 1.0)
			src.set_pixel(x, y, c)
	src.generate_mipmaps()
	return ImageTexture.create_from_image(src)


## Poteau de bois avec une lanterne (et sa lumière, allumée la nuit).
func _lampadaire(p: Vector2, hauteur := 2.4) -> void:
	var base := _sol(p)
	var bois := _materiau(Color(0.35, 0.25, 0.16))
	_boite(self, Vector3(0.12, hauteur, 0.12), base + Vector3(0, hauteur / 2.0, 0), bois)
	_boite_collision(Vector3(0.12, hauteur, 0.12), Transform3D(Basis.IDENTITY, base + Vector3(0, hauteur / 2.0, 0)))
	var lan := Decor.instance("lanterne")
	if lan:
		lan.position = base + Vector3(0, hauteur, 0)
		add_child(lan)
		Decor.distance(lan, 140.0)
	_lumiere(base + Vector3(0, hauteur + 0.15, 0), 8.0, 1.5)


func _lumiere(pos: Vector3, portee_l: float, energie: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.78, 0.48)
	l.light_energy = energie
	l.omni_range = portee_l
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	l.position = pos
	l.visible = false
	add_child(l)
	lampes.append(l)
	return l


func _process(delta: float) -> void:
	super(delta)
	var nuit := Game.is_night()
	if lampes.size() > 0 and (lampes[0] as OmniLight3D).visible != nuit:
		for l in lampes:
			(l as OmniLight3D).visible = nuit


func _garde(p: Vector3, regard: float, rng: RandomNumberGenerator) -> Node3D:
	var g = Garde.new()
	g.setup(rng)
	add_child(g)
	g.position = _sol(Vector2(p.x, p.z))
	g.global_rotation.y = regard
	g.regard_base = regard
	gardes.append(g)
	return g


## Palissade de planches en cercle, ouverte côté +Z (entrée).
func _palissade() -> void:
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color(0.55, 0.42, 0.3)
	bois.roughness = 1.0
	if ResourceLoader.exists("res://textures/planches_albedo.jpg"):
		bois.albedo_texture = load("res://textures/planches_albedo.jpg")
		bois.uv1_triplanar = true
		bois.uv1_scale = Vector3.ONE * 0.6
	var pas := TAU / NB_PANS
	var largeur := 2.0 * RAYON * sin(pas / 2.0) + 0.25
	for k in NB_PANS:
		var a := PI / 2.0 + pas / 2.0 + k * pas   # pans centrés de part et d'autre de +Z
		# ouverture : les deux pans de part et d'autre de +Z (angle PI/2), environ 7,5 m
		if absf(angle_difference(a, PI / 2.0)) < pas * 0.6:
			continue
		var c := Vector2(cos(a), sin(a)) * RAYON
		var h := 2.1 + 0.15 * sin(k * 2.7)
		var pos := _sol(c) + Vector3(0, h / 2.0 - 0.15, 0)
		var ang := -a - PI / 2.0   # pan tangent au cercle (axe X local le long de la tangente)
		var mi := _boite(self, Vector3(largeur, h, 0.16), pos, bois, Vector3(0, ang, 0))
		Decor.distance(mi, 160.0)
		_boite_collision(Vector3(largeur, h, 0.16), Transform3D(Basis(Vector3.UP, ang), pos))
	# deux poteaux plus hauts encadrent l'entrée
	for s in [-1.0, 1.0]:
		var a2: float = PI / 2.0 + s * pas
		var pp := _sol(Vector2(cos(a2), sin(a2)) * RAYON) + Vector3(0, 1.4, 0)
		_boite(self, Vector3(0.28, 2.8, 0.28), pp, bois)
		_boite_collision(Vector3(0.28, 2.8, 0.28), Transform3D(Basis.IDENTITY, pp))


const HAUT_MIRADOR := 2.7


## Mirador : quatre poteaux, plancher et garde-corps ; un garde se tient dessus.
func _mirador(p: Vector2) -> void:
	var t := Node3D.new()
	t.position = _sol(p)
	add_child(t)
	var bois := _materiau(Color(0.42, 0.3, 0.2))
	var h := HAUT_MIRADOR
	for x in [-1.1, 1.1]:
		for z in [-1.1, 1.1]:
			_boite(t, Vector3(0.16, h + 1.1, 0.16), Vector3(x, (h + 1.1) / 2.0, z), bois)
	_boite(t, Vector3(2.6, 0.12, 2.6), Vector3(0, h, 0), bois)
	for s in [-1.0, 1.0]:
		_boite(t, Vector3(2.5, 0.08, 0.08), Vector3(0, h + 1.0, 1.2 * s), bois)
		_boite(t, Vector3(0.08, 0.08, 2.5), Vector3(1.2 * s, h + 1.0, 0), bois)
	# toit de tôle
	var tole := _materiau(Color(0.45, 0.47, 0.5))
	_boite(t, Vector3(2.9, 0.05, 2.9), Vector3(0, h + 2.2, 0), tole, Vector3(0.08, 0, 0))
	for x in [-1.1, 1.1]:
		for z in [-1.1, 1.1]:
			_boite(t, Vector3(0.1, 1.2, 0.1), Vector3(x, h + 1.6, z), bois)
	_boite_collision(Vector3(2.6, 0.12, 2.6), Transform3D(Basis.IDENTITY, t.position + Vector3(0, h, 0)))
	for x in [-1.1, 1.1]:
		for z in [-1.1, 1.1]:
			_boite_collision(Vector3(0.16, h, 0.16), Transform3D(Basis.IDENTITY, t.position + Vector3(x, h / 2.0, z)))



func vivants() -> int:
	return 0


func garder(_n: int) -> void:
	pass
