extends Node3D
## Événements aléatoires (nœud « Evenements » créé par main.gd) : environ un tous les 1 à 2 jours de jeu,
## annoncé par un message et un son radio, repéré sur la carte et la boussole (`reperes`).
##  - largage : un hélicoptère passe et lâche une caisse en parachute (bon butin, fumée rouge qui attire les zombies) ;
##  - convoi : convoi militaire accidenté (camions, soldats zombies, caisses militaires) ;
##  - horde : 20 à 40 zombies qui traversent la carte d'un bord à l'autre et dévient vers les gros bruits ;
##  - bandits : bande de bandits en maraude (scripts/bandit.gd) qui traverse la région.
## Horde et bandits sont simulés (position du groupe seulement) loin du joueur et n'existent en nœuds qu'à moins de
## DIST_REEL. Chaque événement disparaît après sa durée ou une fois fouillé. État sauvegardé (`etat` / `appliquer`).

const Decor = preload("res://scripts/decor.gd")
const LootContainer = preload("res://scripts/loot_container.gd")
const Bandit = preload("res://scripts/bandit.gd")

const TYPES := ["largage", "convoi", "horde", "bandits"]
const POIDS := {"largage": 35.0, "convoi": 25.0, "horde": 25.0, "bandits": 15.0}
const NOMS := {"largage": "Largage", "convoi": "Convoi militaire", "horde": "Horde migrante", "bandits": "Bandits en maraude"}
const COULEURS := {"largage": Color(1.0, 0.3, 0.25), "convoi": Color(0.6, 0.8, 0.3), "horde": Color(0.85, 0.2, 0.6), "bandits": Color(1.0, 0.85, 0.2)}
const MAX_ACTIFS := 3
const DIST_REEL := 160.0        # horde, bandits : nœuds créés à moins de cette distance du joueur
const DIST_VIRTUEL := 200.0     # … et rendus virtuels au-delà (avant le sommeil des zombies de main.gd, 215 m)
const VIT_HORDE := 2.0          # m/s (simulée)
const VIT_BANDITS := 1.1

## Repères pour la carte (map_ui.gd) et la boussole (hud.gd) : {nom, x, z, couleur}.
static var reperes: Array = []

var prochain := -1.0            # secondes de jeu avant le prochain tirage
var seq := 0
var actifs: Array = []          # données sauvegardées de chaque événement (dictionnaires simples)
var _r := {}                    # id -> nœuds de l'événement (non sauvegardés)
var _tick := 0.0
static var _son_radio: AudioStreamWAV = null
static var _son_rotor: AudioStreamWAV = null


func _ready() -> void:
	add_to_group("passe_temps")
	reperes = []
	if prochain < 0.0:
		prochain = randf_range(0.8, 1.5) * Game.DAY_SECONDS
	Game.noise_made.connect(_bruit)


# ================================================================ sauvegarde
func etat() -> Dictionary:
	var liste := []
	for e in actifs:
		var d: Dictionary = e.duplicate(true)
		var r: Dictionary = _r.get(e.id, {})
		var cs := []
		for c in r.get("caisses", []):
			if is_instance_valid(c):
				cs.append({"f": c.searched, "g": Sauvegarde.grille_vers(c.grille) if c.grille else null})
			else:
				cs.append({"f": true, "g": null})
		d["caisses"] = cs
		if e.type in ["horde", "bandits"]:
			d["n"] = _vivants(e)
			var c := _centre(e)
			d["x"] = c.x
			d["z"] = c.z
		liste.append(d)
	return {"prochain": prochain, "seq": seq, "actifs": liste}


func appliquer(d: Dictionary) -> void:
	if d.is_empty():
		return
	prochain = float(d.get("prochain", prochain))
	seq = int(d.get("seq", 0))
	for e in d.get("actifs", []):
		if not e is Dictionary or not str(e.get("type", "")) in TYPES:
			continue
		var ev: Dictionary = e
		ev.id = int(ev.get("id", 0))
		if ev.type == "largage":
			ev.phase = "sol"   # en vol à la sauvegarde : déjà posé au chargement
		actifs.append(ev)
		_construire(ev, ev.get("caisses", []))
		ev.erase("caisses")
	_maj_reperes()


# ================================================================ boucle
func _process(delta: float) -> void:
	var p = Game.player
	if p == null or not p.alive:
		return
	prochain -= delta
	if prochain <= 0.0:
		prochain = randf_range(1.0, 2.0) * Game.DAY_SECONDS
		if actifs.size() < MAX_ACTIFS:
			declencher(_tirer_type())
	for e in actifs:
		if e.type == "largage":
			_anim_largage(e, delta)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	for e in actifs.duplicate():
		_maj(e, 0.5)
	_maj_reperes()


## Sommeil (player.dormir) : le temps passe pour les événements aussi.
func passer_temps(s: float) -> void:
	prochain -= s
	for e in actifs.duplicate():
		if e.type == "largage" and e.phase == "vol":
			_poser_caisse(e)
		var pas := 10.0
		var t := 0.0
		while t < s and e in actifs:
			_maj(e, pas)
			t += pas
	if prochain <= 0.0:
		prochain = randf_range(0.5, 1.0) * Game.DAY_SECONDS
	_maj_reperes()


func _tirer_type() -> String:
	var tot := 0.0
	for t in POIDS:
		tot += float(POIDS[t])
	var x := randf() * tot
	for t in POIDS:
		x -= float(POIDS[t])
		if x <= 0.0:
			return t
	return "largage"


## Lance un événement (tirage aléatoire ou panneau admin). `pres` : à côté du joueur (admin).
func declencher(type: String, pres := false) -> bool:
	var pp: Vector3 = Game.player.global_position
	seq += 1
	var e := {"type": type, "id": seq, "age": 0.0, "fini": false, "reste": -1.0}
	var pos := Vector3.INF
	match type:
		"largage":
			pos = _point_libre(pp, 50.0 if pres else 250.0, 90.0 if pres else 650.0, false)
			e.duree = Game.DAY_SECONDS
			e.phase = "vol"
			e.ang = randf() * TAU
			e.vol_t = 0.0
		"convoi":
			pos = _point_route(pp, 70.0 if pres else 300.0, 140.0 if pres else 800.0)
			if pos == Vector3.INF:
				pos = _point_libre(pp, 70.0 if pres else 300.0, 140.0 if pres else 800.0, false)
			e.duree = 2.0 * Game.DAY_SECONDS
			e.ang = float(get_meta("ang_route", randf() * TAU))
			e.graine = randi()
		"horde", "bandits":
			# d'un bord de la carte à l'autre, en passant près du joueur (admin : départ à 230 m, déjà en route)
			var lim: float = Game.map_half - 30.0
			var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
			var cote := dir.cross(Vector3.UP) * randf_range(-150.0, 150.0)
			var a := pp + cote - dir * (230.0 if pres else 6000.0)
			var b := pp + cote + dir * 6000.0
			a = _vers_bord(a, pp + cote, lim)
			b = _vers_bord(b, pp + cote, lim)
			pos = a
			e.bx = b.x
			e.bz = b.z
			e.n = randi_range(20, 40) if type == "horde" else randi_range(3, 5)
			e.duree = a.distance_to(b) / (VIT_HORDE if type == "horde" else VIT_BANDITS) + 600.0
			e.dx = 0.0
			e.dz = 0.0
			e.dt = 0.0
	if pos == Vector3.INF:
		Game.msg("Événement impossible ici (%s)." % NOMS[type])
		return false
	e.x = pos.x
	e.z = pos.z
	actifs.append(e)
	_construire(e, [])
	_annoncer(e)
	_maj_reperes()
	return true


func _annoncer(e: Dictionary) -> void:
	var pp: Vector3 = Game.player.global_position
	var v := Vector2(e.x - pp.x, e.z - pp.z)
	var ou := "%s, à %s" % [Game.cardinal(v), ("%d m" % int(v.length())) if v.length() < 1000.0 else ("%.1f km" % (v.length() / 1000.0))]
	match e.type:
		"largage":
			Game.msg("RADIO : un hélicoptère va larguer du ravitaillement (%s). Suis la fumée rouge !" % ou)
		"convoi":
			Game.msg("RADIO : un convoi militaire s'est renversé (%s). Des caisses, mais l'escorte est contaminée." % ou)
		"horde":
			Game.msg("RADIO : une horde de %d zombies traverse la région (%s, vers le %s). Évite le bruit !" % [e.n, ou, Game.cardinal(Vector2(e.bx - e.x, e.bz - e.z))])
		"bandits":
			Game.msg("RADIO : une bande de %d bandits armés rôde dans la région (%s)." % [e.n, ou])
	_jouer_radio()


func _jouer_radio() -> void:
	if _son_radio == null:
		_son_radio = _generer_radio()
	var a := AudioStreamPlayer.new()
	a.stream = _son_radio
	a.bus = "Effets"
	a.volume_db = -6.0
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)


## Fin d'un événement : nœuds retirés (hors de vue si possible : `reste` = délai minimal).
func _terminer(e: Dictionary) -> void:
	actifs.erase(e)
	var r: Dictionary = _r.get(e.id, {})
	for z in r.get("membres", []):
		if is_instance_valid(z) and e.type == "horde":
			z.assaut = false   # la horde se disperse : ce sont de simples zombies maintenant
			z.remove_from_group("evenement")
			z.persistent = false
	if r.has("racine") and is_instance_valid(r.racine):
		r.racine.queue_free()
	_r.erase(e.id)


# ================================================================ construction des nœuds
func _construire(e: Dictionary, caisses: Array) -> void:
	var racine := Node3D.new()
	racine.name = "Ev%d" % e.id
	add_child(racine)
	var pos := Vector3(e.x, Game.hauteur(e.x, e.z), e.z)
	racine.global_position = pos
	var r := {"racine": racine, "caisses": [], "membres": []}
	_r[e.id] = r
	match e.type:
		"largage":
			if e.phase == "vol":
				var h := Decor.instance("helico")
				var hel := Node3D.new()
				racine.add_child(hel)
				if h:
					hel.add_child(h)
				var son := AudioStreamPlayer3D.new()
				if _son_rotor == null:
					_son_rotor = _generer_rotor()
				son.stream = _son_rotor
				son.bus = "Effets"
				son.unit_size = 40.0
				son.max_distance = 1500.0
				son.volume_db = 6.0
				son.autoplay = true
				hel.add_child(son)
				r.helico = hel
			else:
				_poser_caisse(e, caisses)
		"convoi":
			_construire_convoi(e, r, caisses)


func _caisse(r: Dictionary, parent: Node3D, label: String, tables: Array, taille: Vector3, sauve) -> LootContainer:
	var c := LootContainer.new()
	c.setup(label, str(tables[0][0]), taille, Color(0.3, 0.34, 0.2), 3)
	parent.add_child(c)
	c.set_modele("caisse_mil", 0.0)
	if sauve is Dictionary and not sauve.is_empty():
		c.searched = bool(sauve.get("f", false))
		c.grille = Sauvegarde.grille_depuis(sauve.get("g"))
	else:
		_remplir(c, tables)
	r.caisses.append(c)
	return c


## Contenu tiré tout de suite (jamais vide) : [[table, tirages], …].
func _remplir(c: LootContainer, tables: Array) -> void:
	var gs: Vector2i = c._grid_size()
	c.grille = Grille.creer(c.label, gs.x, gs.y)
	for t in tables:
		var found: Dictionary = Items.roll_loot(str(t[0]), int(t[1]), 0.0)
		for id in found:
			if Items.grid(id).x > 0:
				for i in int(found[id]):
					c.grille.ajouter_entree(Game.player.nouvelle_entree(id) if Game.player else {"id": id, "n": 1, "x": 0, "y": 0, "r": false, "contenu": null})
			else:
				c.grille.ajouter(id, int(found[id]))
	if Game.player:
		for en in c.grille.entrees:
			var w := Items.info(en.id)
			if w.get("type", "") == "gun" and not Game.player.mags.has(en.id):
				Game.player.mags[en.id] = int(int(w.mag) * randf_range(0.3, 1.0))


# ---------------------------------------------------------------- largage
const ALT_VOL := 95.0
const VIT_HELICO := 38.0
const DIST_VOL := 700.0      # l'hélicoptère arrive de 700 m et repart aussi loin
const VIT_PARACHUTE := 4.5


func _anim_largage(e: Dictionary, delta: float) -> void:
	var r: Dictionary = _r.get(e.id, {})
	var racine: Node3D = r.get("racine")
	if racine == null:
		return
	var hel: Node3D = r.get("helico")
	if hel and is_instance_valid(hel):
		e.vol_t += delta
		var d := Vector3(cos(e.ang), 0, sin(e.ang))
		var s: float = -DIST_VOL + e.vol_t * VIT_HELICO
		hel.position = d * s + Vector3.UP * ALT_VOL
		hel.rotation.y = atan2(-d.x, -d.z)   # modèle tourné vers -Z
		if e.phase == "vol" and s >= 0.0:
			_poser_caisse(e, [], true)
		if s > DIST_VOL:
			hel.queue_free()
			r.erase("helico")
	var para: Node3D = r.get("para")
	if para and is_instance_valid(para):
		var sol := 0.0
		para.position.y = maxf(sol, para.position.y - VIT_PARACHUTE * delta)
		para.rotation.y += delta * 0.4
		var voile: Node3D = para.get_node_or_null("Voile")
		if para.position.y <= sol + 0.01:
			if voile:
				voile.queue_free()
			r.erase("para")
			_fumee(r, racine)
			Game.play_3d("atterrissage", racine.global_position, 4.0, 0.05, 120.0, 0.7)
			Game.make_noise(racine.global_position, 60.0)


## Caisse posée (ou larguée de haut si `chute`).
func _poser_caisse(e: Dictionary, caisses := [], chute := false) -> void:
	var r: Dictionary = _r[e.id]
	e.phase = "sol"
	var para := Node3D.new()
	para.name = "Colis"
	r.racine.add_child(para)
	var c := _caisse(r, para, "Caisse de ravitaillement", [["armurerie_mil", 3], ["militaire", 3], ["pharmacie", 2]],
			Vector3(1.3, 0.8, 0.9), caisses[0] if not caisses.is_empty() else null)
	c.rotation.y = randf() * TAU
	if chute:
		para.position.y = ALT_VOL - 4.0
		var voile := MeshInstance3D.new()
		voile.name = "Voile"
		var sm := SphereMesh.new()
		sm.radius = 3.0
		sm.height = 3.0
		sm.is_hemisphere = true
		voile.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.82, 0.7)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		voile.material_override = m
		voile.position.y = 5.5
		para.add_child(voile)
		for k in 4:
			var fil := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.015
			cm.bottom_radius = 0.015
			cm.height = 5.2
			fil.mesh = cm
			fil.material_override = m
			var a := k * TAU / 4.0 + PI / 4.0
			fil.position = Vector3(cos(a) * 1.4, 3.1, sin(a) * 1.4)
			fil.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
			voile.add_child(fil)
			fil.position -= voile.position
		r.para = para
		Game.msg("Le ravitaillement est largué ! Une fumée rouge marque la caisse.")
	elif not c.searched:
		_fumee(r, r.racine)


func _fumee(r: Dictionary, racine: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.name = "Fumee"
	p.amount = 48
	p.lifetime = 9.0
	p.preprocess = 6.0
	var qm := QuadMesh.new()
	qm.size = Vector2(1.2, 1.2)
	p.mesh = qm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _tache()
	p.material_override = m
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 1.6
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0.35, 0.25, 0.15)
	p.damping_min = 0.1
	p.damping_max = 0.3
	var courbe := Curve.new()
	courbe.add_point(Vector2(0, 0.5))
	courbe.add_point(Vector2(1, 4.0))
	p.scale_amount_curve = courbe
	var g := Gradient.new()
	g.set_color(0, Color(0.95, 0.15, 0.1, 0.85))
	g.set_color(1, Color(0.8, 0.35, 0.3, 0.0))
	p.color_ramp = g
	p.position = Vector3(0, 0.9, 0)
	p.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 60, 40))
	racine.add_child(p)
	r.fumee = p


static var _tex_tache: Texture2D = null


static func _tache() -> Texture2D:
	if _tex_tache == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_tex_tache = t
	return _tex_tache


# ---------------------------------------------------------------- convoi
const VEHICULES_CONVOI := ["camion_mil", "camion_mil", "voiture_camionnette"]


func _construire_convoi(e: Dictionary, r: Dictionary, caisses: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(e.graine)
	var racine: Node3D = r.racine
	var d := Vector3(cos(e.ang), 0, sin(e.ang))
	var cote := d.cross(Vector3.UP)
	var corps := StaticBody3D.new()
	corps.collision_layer = Game.LAYER_WORLD
	corps.collision_mask = 0
	racine.add_child(corps)
	for k in VEHICULES_CONVOI.size():
		var id: String = VEHICULES_CONVOI[k]
		var n := Decor.instance(id)
		if n == null:
			continue
		var off := d * (k - 1) * 11.0 + cote * rng.randf_range(-2.5, 2.5)
		var w := racine.global_position + off
		var hp := Vector3(off.x, Game.hauteur(w.x, w.z) - racine.global_position.y, off.z)
		var ang := atan2(-d.x, -d.z) + rng.randf_range(-0.6, 0.6) + (PI / 2.0 if k == 1 else 0.0)
		n.position = hp
		n.rotation.y = ang
		if k == 1:
			n.rotation.z = 0.25   # camion couché sur le flanc… presque
		Decor.vieillir(n, Color(0.25, 0.22, 0.18), 0.45)
		racine.add_child(n)
		var t := Decor.taille(id)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = t * Vector3(0.9, 0.9, 0.95)
		cs.shape = bs
		cs.position = hp + Vector3(0, t.y * 0.45, 0)
		cs.rotation.y = ang
		corps.add_child(cs)
		if k == 0:
			# moteur qui fume encore
			var f := CPUParticles3D.new()
			f.amount = 24
			f.lifetime = 5.0
			var qm := QuadMesh.new()
			qm.size = Vector2(0.9, 0.9)
			f.mesh = qm
			var m := StandardMaterial3D.new()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.vertex_color_use_as_albedo = true
			m.albedo_texture = _tache()
			f.material_override = m
			f.direction = Vector3.UP
			f.spread = 15.0
			f.initial_velocity_min = 1.0
			f.initial_velocity_max = 1.8
			f.gravity = Vector3(0.2, 0.2, 0.0)
			var courbe := Curve.new()
			courbe.add_point(Vector2(0, 0.6))
			courbe.add_point(Vector2(1, 3.0))
			f.scale_amount_curve = courbe
			var g := Gradient.new()
			g.set_color(0, Color(0.2, 0.2, 0.2, 0.7))
			g.set_color(1, Color(0.4, 0.4, 0.4, 0.0))
			f.color_ramp = g
			f.position = hp + Vector3(0, t.y * 0.8, 0) - d * t.z * 0.35
			racine.add_child(f)
	# caisses militaires éparpillées
	for k in 3:
		var a := rng.randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(4.0, 8.0) + d * rng.randf_range(-8.0, 8.0)
		var tables := [["militaire", 3]] if k > 0 else [["armurerie_mil", 3], ["militaire", 1]]
		var c := _caisse(r, racine, "Caisse militaire", tables, Vector3(1.2, 0.7, 0.7), caisses[k] if k < caisses.size() else null)
		var w := racine.global_position + off
		c.position = Vector3(off.x, Game.hauteur(w.x, w.z) - racine.global_position.y, off.z)
		c.rotation.y = rng.randf() * TAU
	# escorte transformée (seulement à la création : ensuite ce sont des zombies ordinaires, sauvegardés par main)
	if caisses.is_empty():
		var main := get_parent()
		var nb := rng.randi_range(4, 7)
		for k in nb:
			var a := rng.randf() * TAU
			var p: Vector3 = racine.global_position + Vector3(cos(a), 0, sin(a)) * rng.randf_range(3.0, 12.0)
			if Game.relief and Game.relief.dans_eau(p.x, p.z):
				continue
			p.y = Game.hauteur(p.x, p.z) + 0.15
			main.placer_zombie(p, "militaire", 14.0, -1.0, racine.global_position, Game.player.global_position)


# ================================================================ mise à jour (toutes les 0,5 s)
func _maj(e: Dictionary, dt: float) -> void:
	e.age += dt
	var r: Dictionary = _r.get(e.id, {})
	var pp: Vector3 = Game.player.global_position
	match e.type:
		"largage", "convoi":
			var tout: bool = not r.get("caisses", []).is_empty()
			for c in r.get("caisses", []):
				if is_instance_valid(c) and not c.searched:
					tout = false
			if tout and not e.fini:
				e.fini = true
				e.reste = 240.0
				if r.has("fumee") and is_instance_valid(r.fumee):
					r.fumee.emitting = false
			if e.type == "largage" and e.phase == "sol" and not e.fini and not r.has("para"):
				# la fumée attire les zombies du coin
				e["bruit_t"] = float(e.get("bruit_t", 0.0)) - dt
				if e.bruit_t <= 0.0:
					e.bruit_t = 6.0
					Game.make_noise(Vector3(e.x, Game.hauteur(e.x, e.z), e.z), 70.0)
				if not e.get("appel", false) and pp.distance_to(Vector3(e.x, pp.y, e.z)) < 130.0:
					e.appel = true
					_attirer_zombies(Vector3(e.x, Game.hauteur(e.x, e.z), e.z), randi_range(5, 9))
			var d := Vector2(pp.x - e.x, pp.z - e.z).length()
			if e.fini:
				e.reste -= dt
				if e.reste <= 0.0 and d > 60.0:
					_terminer(e)
			elif e.age > e.duree and d > 80.0:
				_terminer(e)
		"horde", "bandits":
			_maj_groupe(e, r, dt)


## Quelques zombies de passage arrivent vers la fumée.
func _attirer_zombies(cible: Vector3, nb: int) -> void:
	var main := get_parent()
	for k in nb * 3:
		if nb <= 0:
			break
		var a := randf() * TAU
		var p := cible + Vector3(cos(a), 0, sin(a)) * randf_range(35.0, 60.0)
		if not _sol_libre(p):
			continue
		p.y = Game.hauteur(p.x, p.z) + 0.15
		var z = main.spawn_zombie(p, "coureur" if randf() < 0.2 else "civil", false, 15.0)
		z.state = z.State.INVESTIGATE
		z.target = cible + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		nb -= 1


func _centre(e: Dictionary) -> Vector3:
	return Vector3(e.x, 0, e.z)


func _vivants(e: Dictionary) -> int:
	var r: Dictionary = _r.get(e.id, {})
	if not r.get("reel", false):
		return int(e.n)
	var n := 0
	for m in r.get("membres", []):
		if _vivant(m, e.type):
			n += 1
	return n


func _vivant(m, type: String) -> bool:
	if not is_instance_valid(m):
		return false
	return m.state != (m.State.DEAD if type == "horde" else 3)


## Horde, bandits : le groupe avance vers son but (ou vers un gros bruit) ; nœuds réels près du joueur.
func _maj_groupe(e: Dictionary, r: Dictionary, dt: float) -> void:
	var pp: Vector3 = Game.player.global_position
	var c := Vector3(e.x, 0, e.z)
	var reel: bool = r.get("reel", false)
	if reel:
		e.n = _vivants(e)
		var vivants := []
		for m in r.membres:
			if _vivant(m, e.type):
				vivants.append(m)
		r.membres = vivants
	if int(e.n) <= 0:
		if e.type == "bandits":
			Game.msg("La bande de bandits en maraude a été éliminée.")
		_terminer(e)
		return
	# but : détour vers un bruit, sinon le bord d'en face
	e.dt = maxf(0.0, float(e.dt) - dt)
	var but := Vector3(e.bx, 0, e.bz)
	if e.dt > 0.0:
		but = Vector3(e.dx, 0, e.dz)
		if Vector2(but.x - c.x, but.z - c.z).length() < 8.0:
			e.dt = 0.0
	var vers := Vector3(but.x - c.x, 0, but.z - c.z)
	var vit := VIT_HORDE if e.type == "horde" else VIT_BANDITS
	var avance := true
	if reel:
		# le groupe réel n'avance que si ses membres suivent
		var moy := Vector3.ZERO
		for m in r.membres:
			moy += m.global_position
		moy /= maxf(1.0, r.membres.size())
		avance = Vector2(moy.x - c.x, moy.z - c.z).length() < 14.0
	if avance and vers.length() > 0.5:
		c += vers.normalized() * minf(vers.length(), vit * dt)
		e.x = c.x
		e.z = c.z
	if e.dt <= 0.0 and Vector2(e.bx - c.x, e.bz - c.z).length() < 25.0 or e.age > e.duree:
		if not reel or c.distance_to(Vector3(pp.x, 0, pp.z)) > DIST_VIRTUEL:
			_terminer(e)   # sortie de la carte
			return
	var dj := Vector2(pp.x - c.x, pp.z - c.z).length()
	if not reel and dj < DIST_REEL:
		_materialiser(e, r)
	elif reel and dj > DIST_VIRTUEL:
		_virtualiser(e, r)
	elif reel:
		_guider(e, r)


func _materialiser(e: Dictionary, r: Dictionary) -> void:
	var main := get_parent()
	var c := Vector3(e.x, 0, e.z)
	var membres := []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rayon := 4.0 + sqrt(float(e.n)) * 1.6
	for k in int(e.n) * 4:
		if membres.size() >= int(e.n):
			break
		var a := rng.randf() * TAU
		var p := c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, rayon)
		if not _sol_libre(p):
			continue
		p.y = Game.hauteur(p.x, p.z) + 0.15
		if e.type == "horde":
			var x := rng.randf()
			var z = main.spawn_zombie(p, "coureur" if x < 0.15 else ("gros" if x < 0.25 else "civil"), true, 15.0)
			z.add_to_group("evenement")
			z.assaut = true
			z.assaut_pos = p
			z.state = z.State.CHASE
			z.target = p
			z.set_meta("ecart", p - c)
			membres.append(z)
		else:
			var b = Bandit.new()
			b.setup(1000 + int(e.id), c, rng)
			r.racine.add_child(b)
			b.global_position = p + Vector3.UP * 0.1
			b.rotation.y = rng.randf() * TAU
			b.set_meta("ecart", p - c)
			membres.append(b)
	if membres.is_empty():
		return
	e.n = membres.size()
	r.membres = membres
	r.reel = true
	_guider(e, r)


func _virtualiser(e: Dictionary, r: Dictionary) -> void:
	var n := 0
	for m in r.membres:
		if _vivant(m, e.type):
			n += 1
		if is_instance_valid(m):
			if e.type == "horde":
				m.remove_from_group("zombies")
				m.remove_from_group("evenement")
			else:
				m.remove_from_group("bandits")
			m.queue_free()
	e.n = n
	r.membres = []
	r.reel = false


## Membres réels : chacun suit sa place autour du centre du groupe.
func _guider(e: Dictionary, r: Dictionary) -> void:
	var c := Vector3(e.x, 0, e.z)
	var vers := Vector3(e.bx - e.x, 0, e.bz - e.z).normalized() * 6.0
	for m in r.membres:
		var ec: Vector3 = m.get_meta("ecart", Vector3.ZERO)
		var p := c + vers + Vector3(ec.x, 0, ec.z)
		p.y = Game.hauteur(p.x, p.z)
		if e.type == "horde":
			m.assaut_pos = p
		else:
			m.maison = c
			if m.state == 0:   # PATROUILLE : marche avec la bande
				m.cible_pos = p


## Gros bruit près de la horde (tirs, explosions) : elle dévie pour aller voir.
func _bruit(pos: Vector3, rayon: float) -> void:
	if rayon < 15.0:
		return
	for e in actifs:
		if e.type != "horde":
			continue
		var d := Vector2(pos.x - e.x, pos.z - e.z).length()
		if d < rayon * 2.5 + 60.0:
			e.dx = pos.x
			e.dz = pos.z
			e.dt = 90.0


# ================================================================ repères, positions
func _maj_reperes() -> void:
	var liste := []
	for e in actifs:
		if e.fini or (e.type == "largage" and e.phase == "vol"):
			continue
		var nom: String = NOMS[e.type]
		if e.type == "horde":
			nom += " (%d)" % _vivants(e)
		liste.append({"nom": nom, "x": float(e.x), "z": float(e.z), "couleur": COULEURS[e.type]})
	reperes = liste


func _sol_libre(p: Vector3) -> bool:
	if absf(p.x) > Game.map_half - 15.0 or absf(p.z) > Game.map_half - 15.0:
		return false
	if Game.relief and Game.relief.dans_eau(p.x, p.z):
		return false
	var y := Game.hauteur(p.x, p.z)
	return Game.find_zone(Vector3(p.x, y + 1.0, p.z)).is_empty()


## Terrain dégagé, sec et plat, hors des villes et des camps de marchands.
func _point_libre(centre: Vector3, rmin: float, rmax: float, ville_ok: bool) -> Vector3:
	var main := get_parent()
	for k in 80:
		var a := randf() * TAU
		var p := centre + Vector3(cos(a), 0, sin(a)) * randf_range(rmin, rmax)
		if not _sol_libre(p) or (not ville_ok and Game.in_city(p)):
			continue
		if main.has_method("pres_camp_marchand") and main.pres_camp_marchand(p, 40.0):
			continue
		var h0 := Game.hauteur(p.x, p.z)
		var plat := true
		for j in 4:
			var q := p + Vector3(cos(j * PI / 2.0), 0, sin(j * PI / 2.0)) * 6.0
			if absf(Game.hauteur(q.x, q.z) - h0) > 1.6 or not _sol_libre(q):
				plat = false
		if plat:
			return Vector3(p.x, h0, p.z)
	return Vector3.INF


## Point sur une route de campagne (convoi), orienté le long de la route (méta « ang_route »).
func _point_route(centre: Vector3, rmin: float, rmax: float) -> Vector3:
	var w = get_parent().world
	var routes: Array = w.routes if w and w.get("routes") != null else []
	var cand := []
	for rt in routes:
		var re: Rect2 = rt.r
		var m := re.get_center()
		var d := Vector2(m.x - centre.x, m.y - centre.z).length()
		if d > rmax + maxf(re.size.x, re.size.y) / 2.0:
			continue
		cand.append(rt)
	cand.shuffle()
	for rt in cand:
		var re: Rect2 = rt.r
		for k in 10:
			var p := Vector3(randf_range(re.position.x, re.end.x), 0, randf_range(re.position.y, re.end.y))
			if bool(rt.x):
				p.z = re.get_center().y
			else:
				p.x = re.get_center().x
			var d := Vector2(p.x - centre.x, p.z - centre.z).length()
			if d < rmin or d > rmax or Game.in_city(p) or not _sol_libre(p):
				continue
			set_meta("ang_route", 0.0 if bool(rt.x) else PI / 2.0)
			p.y = Game.hauteur(p.x, p.z)
			return p
	if has_meta("ang_route"):
		remove_meta("ang_route")
	return Vector3.INF


## Ramène un point sur le bord de la carte (le long du segment depuis `dedans`).
func _vers_bord(p: Vector3, dedans: Vector3, lim: float) -> Vector3:
	var d := p - dedans
	var k := 1.0
	if absf(d.x) > 0.001:
		k = minf(k, (lim - signf(d.x) * dedans.x) / absf(d.x))
	if absf(d.z) > 0.001:
		k = minf(k, (lim - signf(d.z) * dedans.z) / absf(d.z))
	return dedans + d * clampf(k, 0.0, 1.0)


# ================================================================ sons générés
static func _wav(data: PackedByteArray, rate: int, boucle: bool) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	if boucle:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = data.size() / 2
	return s


## Bip radio : grésillement, deux notes, grésillement.
static func _generer_radio() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 1.1)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		if t < 0.18 or t > 0.85:
			v = randf_range(-0.25, 0.25)
		elif t < 0.4:
			v = sin(TAU * 880.0 * t) * 0.45 + randf_range(-0.05, 0.05)
		elif t < 0.45:
			v = 0.0
		elif t < 0.75:
			v = sin(TAU * 660.0 * t) * 0.45 + randf_range(-0.05, 0.05)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	return _wav(data, rate, false)


## Rotor d'hélicoptère : battements sourds (11 par seconde) sur un ronronnement, en boucle.
static func _generer_rotor() -> AudioStreamWAV:
	var rate := 22050
	var n := rate   # 1 s
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var ph := fmod(t * 11.0, 1.0)
		var env := exp(-ph * 9.0)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.08)
		var v := lp * (0.25 + env * 1.4) + sin(TAU * 66.0 * t) * 0.18
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	return _wav(data, rate, true)
