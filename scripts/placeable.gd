extends StaticBody3D
## Objets de base posés par le joueur : établi et barricade.
## (La caisse de stockage utilise loot_container.gd.)

const Effets = preload("res://scripts/effets.gd")

var kind := "etabli"
var health := 250.0
var health_max := 250.0


func setup(p_kind: String) -> void:
	kind = p_kind
	add_to_group("placeables")
	if kind in ["collet", "canne_peche", "sechoir", "recuperateur_eau", "bac_culture", "groupe_electrogene"]:
		add_to_group("passe_temps")   # minuteurs avancés par le sommeil (passer_temps)
	collision_layer = Game.LAYER_WORLD | Game.LAYER_INTERACT
	collision_mask = 0
	var wood := Color(0.5, 0.36, 0.2)
	match kind:
		"etabli":
			add_to_group("workbench")
			_modele("etabli", Vector3.ZERO, Vector3.ONE * 1.1)   # établi à outils (Kenney, CC0)
			_shape(Vector3(0, 0.52, 0), Vector3(1.2, 1.05, 1.1))
		"feu_camp":
			# cercle de pierres, bûches croisées, braises, flammes et lumière vacillante
			add_to_group("feu_camp")
			health = 100.0
			collision_layer = Game.LAYER_INTERACT
			var pierre := Color(0.42, 0.41, 0.4)
			for k in 9:
				var a := k * TAU / 9.0
				var pi := _part(Vector3(cos(a) * 0.48, 0.07, sin(a) * 0.48), Vector3(0.2, 0.14, 0.16), pierre.lightened(randf() * 0.15))
				pi.rotation.y = -a
			_modele("feu_bois", Vector3.ZERO, Vector3.ONE * 0.45)   # bûches (Quaternius, CC0)
			_part(Vector3(0, 0.03, 0), Vector3(0.5, 0.04, 0.5), Color(0.15, 0.08, 0.04))
			var mf := StandardMaterial3D.new()
			mf.albedo_texture = Effets._texture("flamme")
			mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mf.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mf.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mf.albedo_color = Color(1.0, 0.6, 0.25)
			for k in 3:
				var f := MeshInstance3D.new()
				var q := QuadMesh.new()
				q.size = Vector2(0.45, 0.6)
				f.mesh = q
				f.material_override = mf
				f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				f.position = Vector3(randf_range(-0.08, 0.08), 0.32 + k * 0.07, randf_range(-0.08, 0.08))
				add_child(f)
				flammes.append(f)
			lumiere_feu = OmniLight3D.new()
			lumiere_feu.light_color = Color(1.0, 0.6, 0.3)
			lumiere_feu.light_energy = 2.2
			lumiere_feu.omni_range = 9.0
			lumiere_feu.position = Vector3(0, 0.6, 0)
			add_child(lumiere_feu)
			_shape(Vector3(0, 0.2, 0), Vector3(1.1, 0.4, 1.1))
		"torche":
			# bâton planté, tête de tissu enflammée, lumière vacillante (pas une station de cuisson)
			health = 40.0
			collision_layer = Game.LAYER_INTERACT
			_part(Vector3(0, 0.6, 0), Vector3(0.06, 1.2, 0.06), wood.darkened(0.3))
			_part(Vector3(0, 1.22, 0), Vector3(0.12, 0.16, 0.12), Color(0.2, 0.15, 0.1))
			var mt := StandardMaterial3D.new()
			mt.albedo_texture = Effets._texture("flamme")
			mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mt.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mt.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mt.albedo_color = Color(1.0, 0.62, 0.25)
			for k in 2:
				var ft := MeshInstance3D.new()
				var qt := QuadMesh.new()
				qt.size = Vector2(0.22, 0.34)
				ft.mesh = qt
				ft.material_override = mt
				ft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				ft.position = Vector3(0, 1.4 + k * 0.05, 0)
				add_child(ft)
				flammes.append(ft)
			lumiere_feu = OmniLight3D.new()
			lumiere_feu.light_color = Color(1.0, 0.62, 0.3)
			lumiere_feu.omni_range = 7.0
			lumiere_feu.position = Vector3(0, 1.45, 0)
			add_child(lumiere_feu)
			_shape(Vector3(0, 0.6, 0), Vector3(0.2, 1.2, 0.2))
		"lit":
			# lit de camp : cadre en bois, matelas, oreiller, couverture
			add_to_group("lits")
			health = 120.0
			_modele("lit_camp", Vector3.ZERO, Vector3(1.75, 1.1, 1.7))   # lit de camp et sac de couchage (Steve B, CC BY)
			_shape(Vector3(0, 0.25, 0), Vector3(1.0, 0.5, 2.0))
		"plan_couture":
			# table, rouleau de tissu, peau tendue sur un cadre, ciseaux
			add_to_group("plan_couture")
			_part(Vector3(0, 0.85, 0), Vector3(1.6, 0.08, 0.8), wood.lightened(0.1))
			for x in [-0.72, 0.72]:
				for z in [-0.32, 0.32]:
					_part(Vector3(x, 0.41, z), Vector3(0.08, 0.82, 0.08), wood.darkened(0.2))
			var rouleau := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.09
			cm.bottom_radius = 0.09
			cm.height = 0.7
			rouleau.mesh = cm
			var mt := StandardMaterial3D.new()
			mt.albedo_color = Color(0.55, 0.25, 0.22)
			rouleau.material_override = mt
			rouleau.position = Vector3(-0.35, 0.98, -0.15)
			rouleau.rotation.z = PI / 2.0
			add_child(rouleau)
			_part(Vector3(0.3, 0.9, 0.05), Vector3(0.6, 0.02, 0.45), Color(0.62, 0.45, 0.3))   # cuir étalé
			_part(Vector3(0.45, 0.92, -0.25), Vector3(0.18, 0.015, 0.04), Color(0.7, 0.7, 0.72))   # ciseaux
			_part(Vector3(-0.1, 0.9, 0.22), Vector3(0.12, 0.05, 0.12), Color(0.3, 0.3, 0.6))   # bobine
			_shape(Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 0.8))
		"collet":
			# piquet et boucle de fil de fer au ras du sol ; un lapin s'y prend avec le temps
			health = 50.0
			collision_layer = Game.LAYER_INTERACT
			_part(Vector3(0, 0.15, 0.15), Vector3(0.03, 0.3, 0.03), wood.darkened(0.2))
			var boucle := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.09
			tm.outer_radius = 0.1
			boucle.mesh = tm
			boucle.material_override = _mat_acier()
			boucle.position = Vector3(0, 0.1, 0)
			boucle.rotation.x = PI / 2.0
			add_child(boucle)
			lapin_pris = Node3D.new()
			lapin_pris.visible = false
			add_child(lapin_pris)
			if ResourceLoader.exists("res://modeles/animaux/lapin.scn"):
				# lapin pris au collet, couché sur le flanc
				var la: Node3D = load("res://modeles/animaux/lapin.scn").instantiate()
				la.position = Vector3(0, 0.08, -0.05)
				la.rotation = Vector3(0, 0.4, PI / 2.0)
				lapin_pris.add_child(la)
			collet_t = randf_range(150.0, 400.0) * (0.5 if Game.player and Game.player.prog.a("piegeur") else 1.0)
			_shape(Vector3(0, 0.15, 0), Vector3(0.5, 0.3, 0.5))
		"canne_peche":
			# ligne de pêche : canne plantée en biais vers l'eau (-Z), fil, bouchon, seau où tombent les poissons
			health = 50.0
			collision_layer = Game.LAYER_INTERACT
			var canne := _part(Vector3(0, 0.55, -0.35), Vector3(0.035, 0.035, 1.6), wood.darkened(0.15))
			canne.rotation.x = 0.6
			_part(Vector3(0, 0.08, 0.25), Vector3(0.12, 0.16, 0.12), wood.darkened(0.3))   # fourche qui la tient
			var fil := _part(Vector3(0, 0.6, -1.05), Vector3(0.006, 1.15, 0.006), Color(0.85, 0.85, 0.85))
			fil.rotation.x = -0.25
			_part(Vector3(0, 0.06, -1.2), Vector3(0.07, 0.07, 0.07), Color(0.85, 0.15, 0.1))   # bouchon
			var seau := MeshInstance3D.new()
			var cs := CylinderMesh.new()
			cs.top_radius = 0.17
			cs.bottom_radius = 0.13
			cs.height = 0.3
			cs.cap_top = false
			seau.mesh = cs
			seau.material_override = _mat_acier()
			seau.position = Vector3(0.4, 0.15, 0.25)
			add_child(seau)
			for k in PECHE_MAX + 2:   # (+2 : talent Pêcheur)
				var po := _part(Vector3(0.4 + (k - 1) * 0.06, 0.24 + k * 0.025, 0.25), Vector3(0.05, 0.03, 0.2), Color(0.55, 0.6, 0.62))
				po.rotation.y = k * 0.9
				poissons.append(po)
			minuteur = randf_range(0.0, 60.0)
			_maj_visuel_stock()
			_shape(Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.9))
		"piege_machoires":
			# piège à mâchoires (Quaternius, CC0) : blesse et immobilise le premier zombie qui marche dessus ; [F] pour le réarmer
			health = 80.0
			collision_layer = Game.LAYER_INTERACT
			machoires = _modele("piege_machoires", Vector3.ZERO, Vector3.ONE * 1.1)
			_shape(Vector3(0, 0.08, 0), Vector3(0.7, 0.16, 0.8))
			_zone_piege(Vector3(0.8, 1.0, 0.8))
		"recuperateur_eau":
			# fût bleu sous un entonnoir de bâche tendu sur quatre piquets : se remplit sous la pluie
			health = 120.0
			_modele("baril_bleu", Vector3.ZERO, Vector3.ONE * 0.95)
			for x in [-0.55, 0.55]:
				for z in [-0.55, 0.55]:
					_part(Vector3(x, 0.75, z), Vector3(0.05, 1.5, 0.05), wood.darkened(0.25))
			var bache := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.8
			cone.bottom_radius = 0.12
			cone.height = 0.45
			cone.radial_segments = 4
			cone.cap_top = false
			bache.mesh = cone
			var mb := StandardMaterial3D.new()
			mb.albedo_color = Color(0.25, 0.38, 0.3)
			mb.roughness = 0.8
			mb.cull_mode = BaseMaterial3D.CULL_DISABLED
			bache.material_override = mb
			bache.position = Vector3(0, 1.32, 0)
			bache.rotation.y = PI / 4.0
			add_child(bache)
			niveau_eau = _part(Vector3(0, 0.0, 0), Vector3(0.48, 0.02, 0.48), Color(0.3, 0.42, 0.5))
			_maj_visuel_stock()
			_shape(Vector3(0, 0.6, 0), Vector3(0.75, 1.2, 0.75))
		"sechoir":
			# séchoir à viande : chevalet en bois, perche, lanières de viande suspendues (selon le stock)
			health = 100.0
			for sx in [-0.7, 0.7]:
				for sz in [-1.0, 1.0]:
					var pied := _part(Vector3(sx, 0.75, sz * 0.22), Vector3(0.06, 1.6, 0.06), wood.darkened(0.2))
					pied.rotation.x = sz * 0.28
			_part(Vector3(0, 1.48, 0), Vector3(1.6, 0.05, 0.05), wood.darkened(0.1))
			_part(Vector3(0, 0.03, 0), Vector3(1.2, 0.04, 0.5), Color(0.2, 0.12, 0.06))   # cendres du fumage
			for k in 6:
				var la := _part(Vector3(-0.55 + k * 0.22, 1.24, 0), Vector3(0.1, 0.45, 0.03), Color(0.45, 0.13, 0.1))
				la.rotation.z = randf_range(-0.1, 0.1)
				lanieres.append(la)
			_maj_visuel_stock()
			_shape(Vector3(0, 0.8, 0), Vector3(1.6, 1.6, 0.6))
		"barricade":
			add_to_group("barricade")
			for y in [0.4, 1.15, 1.9]:
				_part(Vector3(0, y, 0), Vector3(2.1, 0.28, 0.08), wood.lightened(randf() * 0.15))
			for x in [-0.8, 0.8]:
				_part(Vector3(x, 1.2, 0.07), Vector3(0.12, 2.4, 0.06), wood.darkened(0.25))
			_shape(Vector3(0, 1.2, 0), Vector3(2.1, 2.4, 0.2))
		"piques":
			# rondin couché et pieux taillés en pointe, tournés vers l'avant (-Z)
			health = 200.0
			collision_layer = Game.LAYER_INTERACT
			_part(Vector3(0, 0.12, 0.15), Vector3(2.0, 0.22, 0.22), wood.darkened(0.3))
			for k in 7:
				var x := -0.9 + k * 0.3
				var pieu := _part(Vector3(x, 0.45, -0.1), Vector3(0.09, 1.1, 0.09), wood.lightened(randf() * 0.2))
				pieu.rotation.x = -0.75
				var pointe := _part(Vector3(x, 0.86, -0.53), Vector3(0.05, 0.18, 0.05), wood.lightened(0.35))
				pointe.rotation.x = -0.75
			_shape(Vector3(0, 0.25, 0), Vector3(2.0, 0.5, 0.6))
			_zone_piege(Vector3(2.2, 1.2, 1.4))
		"barbeles":
			health = 160.0
			collision_layer = Game.LAYER_INTERACT
			var acier := Color(0.45, 0.45, 0.47)
			for x in [-1.1, 0.0, 1.1]:
				_part(Vector3(x, 0.45, 0), Vector3(0.06, 0.9, 0.06), wood.darkened(0.35))
			for k in 6:
				var spire := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.36
				tm.outer_radius = 0.4
				spire.mesh = tm
				var m := StandardMaterial3D.new()
				m.albedo_color = acier
				m.metallic = 0.8
				m.roughness = 0.4
				spire.material_override = m
				spire.position = Vector3(-1.0 + k * 0.4, 0.42, 0)
				spire.rotation = Vector3(0, 0, PI / 2.0 + randf_range(-0.2, 0.2))
				add_child(spire)
			_shape(Vector3(0, 0.25, 0), Vector3(2.4, 0.5, 0.5))
			_zone_piege(Vector3(2.6, 1.2, 1.1))
		"projecteur":
			# trépied, mât, phare orienté vers l'avant (-Z) et un peu vers le sol
			health = 120.0
			var noir := Color(0.12, 0.12, 0.13)
			for a in 3:
				var pied := _part(Vector3(sin(a * TAU / 3.0) * 0.22, 0.35, cos(a * TAU / 3.0) * 0.22), Vector3(0.04, 0.8, 0.04), noir)
				pied.rotation = Vector3(cos(a * TAU / 3.0) * 0.45, 0, -sin(a * TAU / 3.0) * 0.45)
			_part(Vector3(0, 1.2, 0), Vector3(0.05, 1.0, 0.05), noir)
			var tete := Node3D.new()
			tete.position = Vector3(0, 1.75, 0)
			tete.rotation.x = -0.28
			add_child(tete)
			var boitier := _part(Vector3.ZERO, Vector3(0.45, 0.32, 0.22), noir)
			remove_child(boitier)
			tete.add_child(boitier)
			verre = MeshInstance3D.new()
			var vm := BoxMesh.new()
			vm.size = Vector3(0.4, 0.27, 0.02)
			verre.mesh = vm
			verre.position = Vector3(0, 0, -0.115)
			mat_verre = StandardMaterial3D.new()
			mat_verre.albedo_color = Color(0.9, 0.9, 0.85)
			mat_verre.emission_enabled = true
			mat_verre.emission = Color(1.0, 0.95, 0.8)
			verre.material_override = mat_verre
			tete.add_child(verre)
			lumiere = SpotLight3D.new()
			lumiere.spot_range = 38.0
			lumiere.spot_angle = 32.0
			lumiere.light_energy = 7.0
			lumiere.light_color = Color(1.0, 0.95, 0.82)
			lumiere.shadow_enabled = false
			lumiere.position = Vector3(0, 0, -0.15)
			tete.add_child(lumiere)
			_shape(Vector3(0, 0.95, 0), Vector3(0.6, 1.9, 0.6))
			_maj_projecteur()
		"bac_culture":
			_creer_bac()
		"groupe_electrogene", "panneau_solaire", "lampe", "cloture_electrique":
			_creer_electrique()
	health_max = health


## Réparation au marteau (mode construction, touche G).
const COUT_REPARATION := {"piques": {"planche": 1, "clous": 1}, "barbeles": {"ferraille": 1, "clous": 1}, "barricade": {"planche": 1, "clous": 1}}


func nom_piege() -> String:
	return {"piques": "Piques en bois", "barbeles": "Barbelés", "barricade": "Barricade"}.get(kind, kind)


func _part(pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


func _shape(pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	add_child(cs)


func get_prompt() -> String:
	match kind:
		"etabli":
			return "[F] Utiliser l'établi"
		"feu_camp":
			return "[F] Feu de camp (cuisiner)"
		"plan_couture":
			return "[F] Plan de couture"
		"collet":
			return "[F] Relever le collet : un lapin s'est fait prendre" if lapin_pris.visible else "Collet à lapin (vide)"
		"piques":
			return "Piques en bois (%d PV)" % int(health)
		"barbeles":
			return "Barbelés (%d PV)" % int(health)
		"projecteur":
			return "[F] Projecteur : %s" % ("automatique (s'allume la nuit)" if mode == 0 else MODES[mode])
		"torche":
			return "Torche"
		"recuperateur_eau":
			return "[F] Récupérateur d'eau : remplir tes bouteilles vides (%d / %d d'eau de pluie%s)" % [stock, EAU_MAX, ", il pleut" if Game.pluie > 0.3 else ""]
		"sechoir":
			return "[F] Séchoir à viande : %d / %d sèche(s)" % [secs, stock] if stock > 0 else "[F] Séchoir à viande : mettre de la viande crue à sécher"
		"canne_peche":
			return "[F] Ligne de pêche : %d / %d poisson(s)" % [stock, peche_max()] if stock > 0 else "Ligne de pêche (rien pour l'instant : les poissons mordent quand personne ne rôde)"
		"piege_machoires":
			return "Piège à mâchoires (armé)" if armee else "[F] Réarmer le piège à mâchoires"
		"lit":
			return "[F] Dormir jusqu'au matin" if Game.is_night() else "Lit de camp (on n'y dort que la nuit, après 20 h 30)"
		"bac_culture":
			return _prompt_bac()
		"groupe_electrogene", "panneau_solaire", "lampe", "cloture_electrique":
			return _prompt_elec()
	return "Barricade (%d PV)" % int(health)


const Decor = preload("res://scripts/decor.gd")
const Saisons = preload("res://scripts/saisons.gd")


## Modèle de décor (modeles/props) posé dans l'objet.
func _modele(id: String, pos: Vector3, k: Vector3, rot_y := 0.0) -> Node3D:
	var n := Decor.instance(id)
	if n == null:
		return null
	n.position = pos
	n.rotation.y = rot_y
	n.scale = k
	add_child(n)
	return n


# ---------------------------------------------------------------- récupérateur d'eau, séchoir, piège à mâchoires
const EAU_MAX := 6                  # bouteilles d'eau de pluie en réserve au plus (puisées dans des bouteilles vides)
const PLUIE_PAR_BOUTEILLE := 90.0   # secondes de pluie franche par bouteille
const SECHAGE := 240.0              # secondes pour sécher une lanière de viande
const SECHOIR_MAX := 6
var stock := 0                       # bouteilles (récupérateur) ou viandes mises à sécher (séchoir)
var minuteur := 0.0
var secs := 0                        # séchoir : viandes déjà sèches
var armee := true                    # piège à mâchoires armé
var machoires: Node3D = null
var niveau_eau: MeshInstance3D = null
var lanieres: Array = []
const PECHE_MAX := 3                # poissons gardés dans le seau
const PECHE_DUREE := 240.0          # secondes (au calme) par poisson
var poissons: Array = []


## Refus de pose propre à certains objets ("" = accepté) ; appelé par player._update_placement.
static func refus_pose(k: String, pt: Vector3) -> String:
	if k != "canne_peche" or Game.relief == null:
		return ""
	var r = Game.relief
	if r.dans_eau(pt.x, pt.z) and r.hauteur(pt.x, pt.z) < r.NIVEAU_EAU - 0.5:
		return "Trop profond : plante la ligne sur la rive."
	for d in [1.5, 3.5, 6.0]:
		for a in 12:
			var ang := a * TAU / 12.0
			if r.dans_eau(pt.x + cos(ang) * d, pt.z + sin(ang) * d):
				return ""
	return "Il faut de l'eau à moins de 6 m (rivière, lac, mare)."


func _maj_visuel_stock() -> void:
	if niveau_eau:
		niveau_eau.visible = stock > 0
		niveau_eau.position.y = 0.15 + 0.7 * float(stock) / EAU_MAX
	for k in lanieres.size():
		var la: MeshInstance3D = lanieres[k]
		la.visible = k < stock
		if la.visible:
			(la.material_override as StandardMaterial3D).albedo_color = Color(0.32, 0.17, 0.1) if k < secs else Color(0.6, 0.16, 0.13)
	for k in poissons.size():
		poissons[k].visible = k < stock
	if machoires:
		machoires.scale.y = 1.1 if armee else 0.5
	if kind == "bac_culture":
		_maj_visuel_bac()


## Poissons gardés dans le seau (talent Pêcheur : +2).
func peche_max() -> int:
	return PECHE_MAX + (2 if Game.player and Game.player.prog.a("pecheur") else 0)


## Temps sauté par le sommeil (player.dormir -> groupe « passe_temps ») : même progression, plafonnée par le stock.
func passer_temps(s: float) -> void:
	if kind == "collet":
		if not lapin_pris.visible and not Game.in_city(global_position):
			collet_t -= s
			lapin_pris.visible = collet_t <= 0.0
		return
	if kind == "groupe_electrogene":
		if armee:
			minuteur = maxf(0.0, minuteur - s * conso_essence())
		return
	_maj_lent(s, true)


## Le temps passe pour les objets « lents » (pluie récoltée, poissons, viande qui sèche) ;
## `dort` = temps sauté par le sommeil (personne ne rôde : la pêche avance même près du joueur).
func _maj_lent(delta: float, dort := false) -> void:
	if kind == "bac_culture":
		_maj_bac(delta)
		return
	var avant := stock + secs
	if kind == "recuperateur_eau" and stock < EAU_MAX and Game.pluie > 0.3:
		minuteur += delta * Game.pluie
		while minuteur >= PLUIE_PAR_BOUTEILLE and stock < EAU_MAX:
			minuteur -= PLUIE_PAR_BOUTEILLE
			stock += 1
	elif kind == "canne_peche" and stock < peche_max():
		# comme le collet : ça ne mord que si personne ne rôde (joueur à plus de 20 m)
		var p = Game.player
		if not dort and p and global_position.distance_squared_to(p.global_position) < 400.0:
			return
		minuteur += delta * (2.0 if p and p.prog.a("piegeur") else 1.0) * (1.6 if p and p.prog.a("pecheur") else 1.0) * (1.3 if Game.pluie > 0.3 else 1.0)
		while minuteur >= PECHE_DUREE and stock < peche_max():
			minuteur -= PECHE_DUREE + randf_range(-30.0, 60.0)
			stock += 1
	elif kind == "sechoir" and secs < stock:
		minuteur += delta * (1.5 if Game.pluie < 0.2 else 0.5)   # sèche mal sous la pluie
		while minuteur >= SECHAGE and secs < stock:
			minuteur -= SECHAGE
			secs += 1
	else:
		return
	if (kind == "recuperateur_eau" and stock >= EAU_MAX) or (kind == "canne_peche" and stock >= peche_max()) or (kind == "sechoir" and secs >= stock):
		minuteur = 0.0   # plein : rien ne s'accumule d'avance
	if stock + secs != avant:
		_maj_visuel_stock()


func _interagir_stock(player: Node) -> void:
	match kind:
		"recuperateur_eau":
			# l'eau de pluie reste dans le fût : [F] en remplit les bouteilles vides du joueur
			if stock <= 0:
				Game.msg("Le fût est vide : il se remplit quand il pleut.")
				return
			var n := mini(stock, player.count("bouteille_vide"))
			if n <= 0:
				Game.msg("Il faut des bouteilles vides pour puiser l'eau de pluie (%d dans le fût)." % stock)
				return
			player.remove_item("bouteille_vide", n)
			player.add_item("eau", n)
			stock -= n
			Game.play_ui("fouille", -6.0, 0.1, 1.2)
		"sechoir":
			if secs > 0:
				player.add_item("viande_sechee", secs)
				stock -= secs
				secs = 0
			elif stock < SECHOIR_MAX and player.count("viande_crue") > 0:
				var n := mini(SECHOIR_MAX - stock, player.count("viande_crue"))
				player.remove_item("viande_crue", n)
				stock += n
				Game.msg("%d viande(s) crue(s) mise(s) à sécher." % n)
			elif stock > 0:
				Game.msg("La viande sèche encore (%d / %d prête)." % [secs, stock])
				return
			else:
				Game.msg("Il faut de la viande crue à faire sécher.")
				return
			Game.play_ui("fouille", -6.0, 0.1, 0.9)
		"canne_peche":
			if stock <= 0:
				Game.msg("Rien n'a mordu : les poissons viennent quand personne ne rôde autour.")
				return
			player.add_item("poisson_cru", stock)
			player.prog.gagner("chasse", 6 * stock)
			stock = 0
			Game.play_ui("fouille", -6.0, 0.1, 1.1)
		"piege_machoires":
			if not armee:
				armee = true
				health = maxf(health, 30.0)
				Game.play_3d("impact_metal", global_position, -8.0, 0.1, 20.0)
				Game.msg("Piège réarmé.")
	_maj_visuel_stock()


# ---------------------------------------------------------------- pièges
var zone: Area3D = null
var piege_t := 0.0


## Zone où les zombies se blessent (piques) ou s'empêtrent (barbelés).
func _zone_piege(taille: Vector3) -> void:
	add_to_group("piege")
	zone = Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = Game.LAYER_ZOMBIE
	zone.monitorable = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = taille
	cs.shape = bs
	cs.position = Vector3(0, taille.y / 2.0, 0)
	zone.add_child(cs)
	add_child(zone)


# ---------------------------------------------------------------- projecteur
const MODES := ["auto", "allumé", "éteint"]
var mode := 0                     # auto = s'allume à la nuit tombée
var lumiere: SpotLight3D = null
var verre: MeshInstance3D = null
var mat_verre: StandardMaterial3D = null
var flammes: Array = []             # feu de camp
var lumiere_feu: OmniLight3D = null
var lapin_pris: Node3D = null         # collet : lapin attrapé (visible)
var collet_t := 0.0
var projecteur_t := 0.0


func _maj_projecteur() -> void:
	if lumiere == null:
		return
	var on := mode == 1 or (mode == 0 and Game.is_night())
	lumiere.visible = on
	mat_verre.emission_energy_multiplier = 4.0 if on else 0.0


func _physics_process(delta: float) -> void:
	if kind == "recuperateur_eau" or kind == "sechoir" or kind == "canne_peche" or kind == "bac_culture":
		_maj_lent(delta)
		return
	if kind in ELEC:
		_maj_elec(delta)
		return
	if lapin_pris:
		_maj_collet(delta)
		return
	if lumiere_feu:
		_animer_feu()
		return
	if lumiere:
		projecteur_t -= delta
		if projecteur_t <= 0.0:
			projecteur_t = 1.0
			_maj_projecteur()
		return
	if zone == null:
		return
	piege_t -= delta
	if piege_t > 0.0:
		return
	piege_t = 0.5 if kind != "piege_machoires" else 0.15
	if kind == "piege_machoires":
		if not armee:
			return
		for z in zone.get_overlapping_bodies():
			if z.has_method("take_hit") and z.get("state") != 3:
				# les mâchoires se referment : grosse blessure, zombie cloué sur place
				armee = false
				z.take_hit(45.0 * (1.6 if Game.player and Game.player.prog.a("ingenieur") else 1.0), z.global_position + Vector3.UP * 0.3, global_position)
				if z.has_method("ralentir"):
					z.ralentir(7.0, 0.0)
				health -= 15.0
				Game.play_3d("impact_metal", global_position, 0.0, 0.1, 35.0, 0.7)
				_maj_visuel_stock()
				break
		if health <= 0.0:
			queue_free()
		return
	var touche := false
	for z in zone.get_overlapping_bodies():
		if not z.has_method("take_hit") or z.get("state") == 3:   # 3 = mort
			continue
		touche = true
		if kind == "piques":
			z.take_hit(14.0, z.global_position + Vector3.UP * 0.8, global_position)
			z.ralentir(0.6, 0.5)
			health -= 7.0
		else:
			z.take_hit(3.0, z.global_position + Vector3.UP * 0.6, global_position)
			z.ralentir(1.2, 0.25)
			health -= 2.5
	if touche:
		Game.play_3d("impact" if kind == "piques" else "impact_metal", global_position + Vector3.UP * 0.5, -10.0, 0.2, 25.0)
	if health <= 0.0:
		Game.msg("%s détruits par les zombies." % ("Les piques sont" if kind == "piques" else "Les barbelés sont"))
		queue_free()


func interact(player: Node) -> void:
	if kind in ["etabli", "feu_camp", "plan_couture"]:
		player.open_inventory()
	elif kind == "lit":
		player.dormir(self)
	elif kind in ["recuperateur_eau", "sechoir", "piege_machoires", "canne_peche"]:
		_interagir_stock(player)
	elif kind == "bac_culture":
		_interagir_bac(player)
	elif kind in ELEC:
		_interagir_elec(player)
	elif kind == "collet" and lapin_pris.visible:
		lapin_pris.visible = false
		collet_t = randf_range(200.0, 450.0) * (0.5 if Game.player and Game.player.prog.a("piegeur") else 1.0)
		player.add_item("viande_crue", 1)
		player.add_item("peau", 1)
		if randf() < 0.5:
			player.add_item("os", 1)
		player.prog.gagner("chasse", 8)
		Game.play_ui("fouille", -6.0, 0.1, 0.9)
	elif kind == "projecteur":
		mode = (mode + 1) % MODES.size()
		_maj_projecteur()
		Game.play_ui("clic_vide", -6.0, 0.05, 1.4)


## Les zombies frappent les barricades qui leur bloquent le passage.
func take_damage(amount: float, _from: Node = null) -> void:
	if kind != "barricade":
		return
	health -= amount
	if health <= 0.0:
		Game.msg("Une barricade a cédé !")
		queue_free()


func _animer_feu() -> void:
	var p = Game.player
	if p == null or global_position.distance_squared_to(p.global_position) > 3600.0:
		return
	var t := Time.get_ticks_msec() / 1000.0 + get_instance_id() % 7
	lumiere_feu.light_energy = 2.0 + sin(t * 13.0) * 0.3 + sin(t * 7.3) * 0.25
	for k in flammes.size():
		flammes[k].scale = Vector3.ONE * (0.85 + 0.2 * sin(t * (9.0 + k * 2.3) + k))


## Collet : le temps ne passe que si personne ne rôde autour (joueur à plus de 20 m), hors des villes.
func _maj_collet(delta: float) -> void:
	if lapin_pris.visible:
		return
	var p = Game.player
	if p and global_position.distance_squared_to(p.global_position) < 400.0:
		return
	if Game.in_city(global_position):
		return
	collet_t -= delta
	if collet_t <= 0.0:
		lapin_pris.visible = true


func _mat_acier() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.5, 0.52)
	m.metallic = 0.8
	m.roughness = 0.4
	return m


func _mat(col: Color, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	return m


## Boîte ou sphère accrochée à un nœud parent (plantes, appareils).
func _boite(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _boule(parent: Node3D, pos: Vector3, r: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	mi.material_override = _mat(col)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- potager (bac de culture)
## stock = culture (0 = vide, sinon rang dans CULTURES + 1), minuteur = secondes de pousse arrosée,
## secs = eau dans la terre (0..100). Une plante ne pousse que si la terre est humide.
const CULTURES := ["tomate", "carotte", "pomme_de_terre", "mais"]
const NOMS_CULTURES := {"tomate": "Tomates", "carotte": "Carottes", "pomme_de_terre": "Pommes de terre", "mais": "Maïs"}
const POUSSE := {"tomate": 900.0, "carotte": 720.0, "pomme_de_terre": 840.0, "mais": 1080.0}   # secondes (une journée = 1440 s)
const RECOLTE_CULTURE := {"tomate": ["tomate", 3, 5], "carotte": ["carotte", 3, 5], "pomme_de_terre": ["pomme_de_terre", 3, 6], "mais": ["epi_mais", 2, 4]}
const EAU_PAR_S := 100.0 / 480.0    # un bac plein d'eau tient 8 minutes de pousse
const EAU_BOUTEILLE := 60
const EAU_PLUIE := 1.5              # eau gagnée par seconde sous une pluie franche (× intensité)
var eau_frac := 0.0
var plantes: Node3D = null
var terre_mat: StandardMaterial3D = null
var _etape := -1


func _creer_bac() -> void:
	health = 100.0
	var bois := Color(0.45, 0.32, 0.18)
	for z in [-0.42, 0.42]:
		_part(Vector3(0, 0.18, z), Vector3(1.4, 0.36, 0.06), bois.lightened(randf() * 0.1))
	for x in [-0.67, 0.67]:
		_part(Vector3(x, 0.18, 0), Vector3(0.06, 0.36, 0.8), bois.darkened(0.1))
	var terre := _part(Vector3(0, 0.3, 0), Vector3(1.28, 0.04, 0.8), Color(0.3, 0.2, 0.12))
	terre_mat = terre.material_override as StandardMaterial3D
	plantes = Node3D.new()
	plantes.position.y = 0.32
	add_child(plantes)
	_maj_visuel_bac()
	_shape(Vector3(0, 0.2, 0), Vector3(1.4, 0.4, 0.9))


func culture() -> String:
	return CULTURES[stock - 1] if stock >= 1 and stock <= CULTURES.size() else ""


## 0 = pousse, 1 = plant, 2 = plant mûr (-1 = vide).
func etape() -> int:
	var c := culture()
	if c == "":
		return -1
	var t: float = minuteur / POUSSE[c]
	return 2 if t >= 1.0 else (1 if t >= 0.3 else 0)


## Bac sous un toit (bâtiment) : pas de pluie, mais à l'abri du gros froid.
var _abrite := -1


func abrite() -> bool:
	if _abrite < 0 and is_inside_tree():
		_abrite = 0 if Game.find_zone(global_position + Vector3.UP * 0.5).is_empty() else 1
	return _abrite == 1


## Facteur de pousse de la saison (Saisons.pousse) ; à l'abri, jamais moins de ABRI_POUSSE.
const ABRI_POUSSE := 0.6


func pousse_saison() -> float:
	var k: float = Saisons.pousse()
	return maxf(k, ABRI_POUSSE) if abrite() else k


func _maj_bac(delta: float) -> void:
	var e := secs + eau_frac
	if Game.pluie > 0.3 and not abrite():
		e += delta * Game.pluie * EAU_PLUIE
	var c := culture()
	if c != "" and minuteur < POUSSE[c]:
		var t := minf(delta, e / EAU_PAR_S)
		minuteur = minf(minuteur + t * pousse_saison() * (1.4 if _talent("jardinier") else 1.0), POUSSE[c])
		e -= t * EAU_PAR_S
	e = clampf(e, 0.0, 100.0)
	var avant := secs
	secs = int(e)
	eau_frac = e - secs
	if etape() != _etape or absi(secs - avant) >= 1:
		_maj_visuel_bac()


func _maj_visuel_bac() -> void:
	if terre_mat:
		terre_mat.albedo_color = Color(0.32, 0.22, 0.13).lerp(Color(0.16, 0.1, 0.06), secs / 100.0)
	var et := etape()
	if et == _etape or plantes == null:
		return
	_etape = et
	for n in plantes.get_children():
		n.queue_free()
	if et < 0:
		return
	var c := culture()
	var vert := Color(0.25, 0.55, 0.2)
	for i in 6:
		var p := Node3D.new()
		p.position = Vector3(-0.42 + (i % 3) * 0.42, 0, -0.2 + floori(i / 3.0) * 0.4)
		p.rotation.y = randf() * TAU
		plantes.add_child(p)
		if et == 0:
			# pousse : deux petites feuilles
			for s in [-1.0, 1.0]:
				var f := _boite(p, Vector3(s * 0.03, 0.05, 0), Vector3(0.05, 0.01, 0.03), vert.lightened(0.25))
				f.rotation.z = s * 0.5
			_boite(p, Vector3(0, 0.025, 0), Vector3(0.01, 0.05, 0.01), vert.lightened(0.2))
			continue
		var mur := et == 2
		match c:
			"tomate":
				_boite(p, Vector3(0.06, 0.3, 0), Vector3(0.02, 0.6, 0.02), Color(0.5, 0.38, 0.22))   # tuteur
				var h := 0.45
				_boite(p, Vector3(0, h / 2.0, 0), Vector3(0.025, h, 0.025), vert)
				for k in 4:
					var f := _boite(p, Vector3(0, 0.1 + k * 0.1, 0), Vector3(0.22 - k * 0.03, 0.02, 0.08), vert.darkened(0.1))
					f.rotation.y = k * 1.3
				if mur:
					for k in 4:
						_boule(p, Vector3(cos(k * 1.7) * 0.08, 0.15 + k * 0.07, sin(k * 1.7) * 0.08), 0.035, Color(0.8, 0.12, 0.08))
			"carotte":
				for k in 5:
					var f := _boite(p, Vector3(0, 0.1, 0), Vector3(0.015, 0.2, 0.015), vert.lightened(0.1))
					f.rotation = Vector3(0.35, k * TAU / 5.0, 0)
				if mur:
					var col := MeshInstance3D.new()
					var cm := CylinderMesh.new()
					cm.top_radius = 0.035
					cm.bottom_radius = 0.01
					cm.height = 0.08
					col.mesh = cm
					col.material_override = _mat(Color(0.95, 0.5, 0.1))
					col.position = Vector3(0, 0.0, 0)
					p.add_child(col)
			"pomme_de_terre":
				for k in 6:
					var f := _boite(p, Vector3(cos(k) * 0.06, 0.12 + (k % 2) * 0.06, sin(k) * 0.06), Vector3(0.12, 0.02, 0.07), vert.darkened(0.05))
					f.rotation.y = k * 1.1
				if mur:
					for k in 3:
						_boule(p, Vector3(cos(k * 2.0) * 0.05, 0.25, sin(k * 2.0) * 0.05), 0.018, Color(0.95, 0.95, 0.9))   # fleurs blanches
						_boule(p, Vector3(cos(k * 2.0 + 1.0) * 0.12, 0.01, sin(k * 2.0 + 1.0) * 0.12), 0.035, Color(0.7, 0.55, 0.35))   # tubercules
			"mais":
				var h := 1.5 if mur else 0.7
				_boite(p, Vector3(0, h / 2.0, 0), Vector3(0.03, h, 0.03), vert.lightened(0.1))
				for k in 4:
					var f := _boite(p, Vector3(0, h * (0.25 + k * 0.18), 0), Vector3(0.35, 0.01, 0.05), vert)
					f.rotation = Vector3(0, k * 1.6, -0.25)
				if mur:
					var epi := _boite(p, Vector3(0.04, h * 0.6, 0), Vector3(0.05, 0.16, 0.05), Color(0.95, 0.8, 0.25))
					epi.rotation.z = -0.3


func _graine_dispo(player: Node) -> String:
	for c in CULTURES:
		if player.count("graines_" + c) > 0:
			return c
	return ""


func _prompt_bac() -> String:
	var c := culture()
	if c == "":
		var g := _graine_dispo(Game.player) if Game.player else ""
		return "[F] Bac de culture : semer des %s" % NOMS_CULTURES[g].to_lower() if g != "" else "Bac de culture vide (il faut des graines : fermes, granges, quincailleries)"
	var nom: String = NOMS_CULTURES[c]
	if etape() == 2:
		return "[F] Récolter : %s (mûr)" % nom.to_lower()
	var p := int(100.0 * minuteur / POUSSE[c])
	var eau := "eau %d %%" % secs if secs > 0 else "terre sèche : ne pousse plus"
	var arroser := "[F] Arroser — " if secs < 100 - EAU_BOUTEILLE / 2 else ""
	var k := pousse_saison()
	var saison := "" if is_equal_approx(k, 1.0) else ", %s : pousse ×%s" % [Saisons.nom().to_lower(), str(snappedf(k, 0.1)).replace(".", ",")]
	return "%s%s : %s, %d %% (%s%s%s)" % [arroser, nom, ["pousse", "plant"][etape()], p, eau, ", il pleut" if Game.pluie > 0.3 and not abrite() else "", saison]


func _interagir_bac(player: Node) -> void:
	var c := culture()
	if c == "":
		var g := _graine_dispo(player)
		if g == "":
			Game.msg("Il faut des graines (tomate, carotte, pomme de terre, maïs).")
			return
		player.remove_item("graines_" + g, 1)
		stock = CULTURES.find(g) + 1
		minuteur = 0.0
		player.geste("planter")
		player.prog.gagner("survie", 3)
		Game.play_ui("fouille", -8.0, 0.1, 0.8)
		Game.msg("%s semé(e)s. Garde la terre humide (eau ou pluie)." % NOMS_CULTURES[g])
	elif etape() == 2:
		var r: Array = RECOLTE_CULTURE[c]
		player.add_item(r[0], randi_range(r[1], r[2]) + (1 if _talent("jardinier") else 0))
		if randf() < 0.6:
			player.add_item("graines_" + c, randi_range(1, 2))
		player.prog.gagner("survie", 8)
		player.geste("ramasser")
		Game.play_ui("fouille", -6.0, 0.1, 1.0)
		stock = 0
		minuteur = 0.0
	else:
		if secs >= 100 - EAU_BOUTEILLE / 2:
			Game.msg("La terre est encore humide.")
			return
		var bouteille := "eau_sale" if player.count("eau_sale") > 0 else ("eau" if player.count("eau") > 0 else "")
		if bouteille == "":
			Game.msg("Il faut une bouteille d'eau (même sale) pour arroser.")
			return
		player.remove_item(bouteille, 1)
		player.add_item("bouteille_vide", 1)
		secs = mini(100, secs + EAU_BOUTEILLE)
		player.geste("planter")
		Game.play_3d("eau", global_position, -6.0, 0.1, 15.0)
	_maj_visuel_bac()


# ---------------------------------------------------------------- électricité
## Sources (groupe électrogène : minuteur = secondes d'essence, armee = en marche ; panneau solaire le jour)
## et appareils (lampe, clôture électrique, frigo = conteneur loot_container.gd) reliés à moins de RAYON_ELEC.
## Réseau recalculé toutes les secondes (maj_reseau) : métas « alimente » et « reseau » = (production, demande).
const LootContainer = preload("res://scripts/loot_container.gd")
const ELEC := ["groupe_electrogene", "panneau_solaire", "lampe", "cloture_electrique"]
const RAYON_ELEC := 15.0
const PRODUCTION := {"groupe_electrogene": 1500.0, "panneau_solaire": 400.0}
const CONSO := {"lampe": 60.0, "cloture_electrique": 250.0, "frigo": 150.0}
const ESSENCE_DUREE := 720.0        # secondes de marche par jerrican (une demi-journée)
const RESERVOIR := 3                # jerricans au plus dans le réservoir
static var _reseau_ms := -100000
static var _son_moteur: AudioStreamWAV = null
var son: AudioStreamPlayer3D = null
var corps_moteur: Node3D = null
var bruit_t := 0.0
var etincelle: OmniLight3D = null
var lampe_mat: StandardMaterial3D = null


func _creer_electrique() -> void:
	match kind:
		"groupe_electrogene":
			# châssis tubulaire, moteur, réservoir rouge, pot d'échappement
			health = 150.0
			var noir := Color(0.12, 0.12, 0.13)
			for x in [-0.45, 0.45]:
				for z in [-0.3, 0.3]:
					_part(Vector3(x, 0.38, z), Vector3(0.04, 0.76, 0.04), noir)
				_part(Vector3(x, 0.02, 0), Vector3(0.04, 0.04, 0.64), noir)
				_part(Vector3(x, 0.76, 0), Vector3(0.04, 0.04, 0.64), noir)
			corps_moteur = Node3D.new()
			add_child(corps_moteur)
			_boite(corps_moteur, Vector3(-0.1, 0.3, 0), Vector3(0.5, 0.4, 0.42), Color(0.35, 0.35, 0.37))
			_boite(corps_moteur, Vector3(0.0, 0.62, 0), Vector3(0.7, 0.2, 0.46), Color(0.75, 0.12, 0.08))   # réservoir
			_boite(corps_moteur, Vector3(0.0, 0.74, 0.1), Vector3(0.08, 0.05, 0.08), noir)   # bouchon
			_boite(corps_moteur, Vector3(0.28, 0.28, 0), Vector3(0.2, 0.3, 0.36), Color(0.2, 0.2, 0.22))   # alternateur
			var pot := _boite(corps_moteur, Vector3(-0.38, 0.25, 0.2), Vector3(0.12, 0.12, 0.2), Color(0.3, 0.28, 0.25))
			(pot.material_override as StandardMaterial3D).metallic = 0.6
			_boite(corps_moteur, Vector3(0.36, 0.45, 0.22), Vector3(0.12, 0.1, 0.02), Color(0.9, 0.85, 0.2))   # prises
			_shape(Vector3(0, 0.4, 0), Vector3(1.0, 0.8, 0.7))
			son = AudioStreamPlayer3D.new()
			son.stream = _moteur()
			son.volume_db = -4.0
			son.unit_size = 5.0
			son.max_distance = 45.0
			son.bus = "Effets"
			add_child(son)
			armee = false
		"panneau_solaire":
			# panneau incliné vers le soleil sur deux tréteaux
			health = 80.0
			var gris := Color(0.55, 0.56, 0.58)
			for x in [-0.65, 0.65]:
				_part(Vector3(x, 0.35, 0.3), Vector3(0.05, 0.7, 0.05), gris)
				_part(Vector3(x, 0.75, -0.3), Vector3(0.05, 1.5, 0.05), gris)
			var cadre := Node3D.new()
			cadre.position = Vector3(0, 1.05, 0)
			cadre.rotation.x = 0.6
			add_child(cadre)
			_boite(cadre, Vector3.ZERO, Vector3(1.6, 0.04, 1.05), gris)
			var cellules := _boite(cadre, Vector3(0, 0.022, 0), Vector3(1.52, 0.01, 0.97), Color(0.08, 0.12, 0.3))
			(cellules.material_override as StandardMaterial3D).metallic = 0.5
			(cellules.material_override as StandardMaterial3D).roughness = 0.25
			for k in 3:
				_boite(cadre, Vector3(-0.38 + k * 0.38, 0.03, 0), Vector3(0.012, 0.01, 0.97), gris)
			_shape(Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 1.1))
		"lampe":
			# mât, potence et globe ; s'allume la nuit si le réseau l'alimente ([F] : auto / allumée / éteinte)
			health = 40.0
			collision_layer = Game.LAYER_INTERACT
			var noir := Color(0.15, 0.15, 0.16)
			_part(Vector3(0, 0.04, 0), Vector3(0.28, 0.08, 0.28), noir)
			_part(Vector3(0, 0.9, 0), Vector3(0.05, 1.8, 0.05), noir)
			_part(Vector3(0, 1.8, -0.12), Vector3(0.04, 0.04, 0.28), noir)
			var globe := _boule(self, Vector3(0, 1.72, -0.24), 0.1, Color(1.0, 0.92, 0.7))
			lampe_mat = globe.material_override as StandardMaterial3D
			lampe_mat.emission_enabled = true
			lampe_mat.emission = Color(1.0, 0.85, 0.55)
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.85, 0.6)
			l.light_energy = 1.8
			l.omni_range = 11.0
			l.position = Vector3(0, 1.6, -0.24)
			l.visible = false
			add_child(l)
			etincelle = l
			_shape(Vector3(0, 0.9, 0), Vector3(0.3, 1.8, 0.3))
		"cloture_electrique":
			# poteaux, isolateurs jaunes, quatre fils ; alimentée : électrocute et ralentit
			health = 160.0
			collision_layer = Game.LAYER_INTERACT
			for x in [-1.15, 0.0, 1.15]:
				_part(Vector3(x, 0.65, 0), Vector3(0.07, 1.3, 0.07), Color(0.4, 0.3, 0.2))
				for k in 4:
					_part(Vector3(x, 0.3 + k * 0.28, -0.05), Vector3(0.05, 0.05, 0.05), Color(0.95, 0.8, 0.1))
			for k in 4:
				var fil := _part(Vector3(0, 0.3 + k * 0.28, -0.07), Vector3(2.35, 0.008, 0.008), Color(0.7, 0.7, 0.72))
				(fil.material_override as StandardMaterial3D).metallic = 0.8
			etincelle = OmniLight3D.new()
			etincelle.light_color = Color(0.55, 0.7, 1.0)
			etincelle.light_energy = 3.0
			etincelle.omni_range = 4.0
			etincelle.position = Vector3(0, 0.8, 0)
			etincelle.visible = false
			add_child(etincelle)
			_shape(Vector3(0, 0.65, 0), Vector3(2.4, 1.3, 0.2))
			_zone_piege(Vector3(2.6, 1.4, 1.0))
	if kind in PRODUCTION:
		add_to_group("elec_source")
	else:
		add_to_group("elec_conso")
	set_meta("alimente", false)
	set_meta("reseau", Vector2.ZERO)


## Frigo : caisse de rangement (loot_container.gd) branchée sur le réseau ; posé par player._confirm_placement,
## recréé par sauvegarde.gd (« k » = "frigo").
static func creer_frigo() -> Node3D:
	var f = LootContainer.new()
	f.setup("Frigo", "", Vector3(0.8, 1.8, 0.75), Color(0.88, 0.89, 0.9))
	f.make_storage(6, 6)
	f.add_to_group("elec_conso")
	f.add_to_group("frigo")
	f.set_meta("kind", "frigo")
	f.set_meta("alimente", false)
	f.set_meta("reseau", Vector2.ZERO)
	var gris := StandardMaterial3D.new()
	gris.albedo_color = Color(0.3, 0.3, 0.32)
	for y in [1.15]:
		var joint := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.8, 0.02, 0.01)
		joint.mesh = bm
		joint.material_override = gris
		joint.position = Vector3(0, y, -0.38)
		f.add_child(joint)
	for y in [0.75, 1.45]:
		var poignee := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.03, 0.25, 0.03)
		poignee.mesh = pm
		poignee.material_override = gris
		poignee.position = Vector3(0.3, y, -0.39)
		f.add_child(poignee)
	var led := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.03, 0.03, 0.01)
	led.mesh = lm
	var mled := StandardMaterial3D.new()
	mled.albedo_color = Color(0.3, 0.05, 0.05)
	mled.emission_enabled = true
	led.material_override = mled
	led.position = Vector3(-0.3, 1.7, -0.38)
	f.add_child(led)
	f.set_meta("led", mled)
	return f


## Nourriture rangée dans ce conteneur gardée au frais (frigo alimenté) : à utiliser par une future péremption.
## Réseau recalculé au besoin (au plus une fois par seconde) : juste même si aucun appareil ne tourne.
static func au_frais(conteneur: Node) -> bool:
	if conteneur == null or not is_instance_valid(conteneur) or not conteneur.is_in_group("frigo"):
		return false
	if conteneur.is_inside_tree():
		maj_reseau(conteneur.get_tree())
	return bool(conteneur.get_meta("alimente", false))


static func _talent(t: String) -> bool:
	return Game.player != null and Game.player.prog.a(t)


## Talent Électricien : portée du réseau +5 m, groupe électrogène ×0,6 d'essence.
static func rayon_elec() -> float:
	return RAYON_ELEC + (5.0 if _talent("electricien") else 0.0)


static func conso_essence() -> float:
	return 0.6 if _talent("electricien") else 1.0


func produit() -> float:
	match kind:
		"groupe_electrogene":
			return PRODUCTION[kind] if armee and minuteur > 0.0 else 0.0
		"panneau_solaire":
			if Game.is_night():
				return 0.0
			var soleil := clampf(sin(PI * (Game.time_hours - 6.0) / 14.5), 0.25, 1.0)
			return roundf(PRODUCTION[kind] * soleil * (1.0 - 0.6 * Game.pluie))
	return 0.0


static func demande(n: Node) -> float:
	var k: String = str(n.get_meta("kind")) if n.has_meta("kind") else str(n.get("kind"))
	if k == "lampe":
		return CONSO.lampe if n.lampe_voulue() else 0.0
	return CONSO.get(k, 0.0)


## Réseau électrique : chaque appareil est relié aux sources à moins de RAYON_ELEC ; un réseau = sources et appareils
## reliés de proche en proche. Les appareils les plus proches d'une source sont servis d'abord, tant qu'il reste du courant.
static func maj_reseau(tree: SceneTree, forcer := false) -> void:
	var ms := Time.get_ticks_msec()
	if not forcer and ms - _reseau_ms < 1000:
		return
	_reseau_ms = ms
	var sources := []
	for s in tree.get_nodes_in_group("elec_source"):
		if not s.is_queued_for_deletion():
			sources.append(s)
	var appareils := []
	for a in tree.get_nodes_in_group("elec_conso"):
		if not a.is_queued_for_deletion():
			appareils.append(a)
	var r2 := rayon_elec() * rayon_elec()
	var vu := {}
	for depart in sources:
		if vu.has(depart):
			continue
		# parcours en largeur : sources <-> appareils à portée
		var res_s := []
		var res_a := []
		var file := [depart]
		vu[depart] = true
		while not file.is_empty():
			var n = file.pop_back()
			var est_source: bool = n.is_in_group("elec_source")
			if est_source:
				res_s.append(n)
			else:
				res_a.append(n)
			for m in (appareils if est_source else sources):
				if not vu.has(m) and n.global_position.distance_squared_to(m.global_position) <= r2:
					vu[m] = true
					file.append(m)
		var prod := 0.0
		for s in res_s:
			prod += s.produit()
		var dem := 0.0
		var tries := []
		for a in res_a:
			var d := demande(a)
			dem += d
			var proche := INF
			for s in res_s:
				proche = minf(proche, a.global_position.distance_squared_to(s.global_position))
			tries.append([proche, a, d])
		tries.sort_custom(func(x, y): return x[0] < y[0])
		var reste := prod
		for t in tries:
			var ok: bool = prod > 0.0 and reste >= t[2]
			if ok:
				reste -= t[2]
			_alimenter(t[1], ok, Vector2(prod, dem))
		for s in res_s:
			s.set_meta("reseau", Vector2(prod, dem))
	for a in appareils:
		if not vu.has(a):
			_alimenter(a, false, Vector2.ZERO)


static func _alimenter(a: Node, ok: bool, reseau: Vector2) -> void:
	a.set_meta("alimente", ok)
	a.set_meta("reseau", reseau)
	if a.is_in_group("frigo"):
		a.label = "Frigo (alimenté : la nourriture se gâte 3 fois moins vite)" if ok else "Frigo (sans courant)"
		var led: StandardMaterial3D = a.get_meta("led", null)
		if led:
			led.emission = Color(0.2, 1.0, 0.3) if ok else Color(0.0, 0.0, 0.0)
			led.albedo_color = Color(0.2, 0.9, 0.3) if ok else Color(0.3, 0.05, 0.05)


func alimente() -> bool:
	return bool(get_meta("alimente", false))


func lampe_voulue() -> bool:
	return mode == 1 or (mode == 0 and Game.is_night())


func _maj_elec(delta: float) -> void:
	maj_reseau(get_tree())
	match kind:
		"groupe_electrogene":
			var marche := armee and minuteur > 0.0
			if marche:
				minuteur = maxf(0.0, minuteur - delta * conso_essence())
				bruit_t -= delta
				if bruit_t <= 0.0:
					bruit_t = 2.0
					Game.make_noise(global_position, 35.0)   # le moteur attire les zombies
				corps_moteur.position = Vector3(randf_range(-0.004, 0.004), randf_range(-0.003, 0.003), 0)
				if minuteur <= 0.0:
					armee = false
					maj_reseau(get_tree(), true)
			if son and son.playing != marche and is_inside_tree():
				if marche:
					son.play()
				else:
					son.stop()
		"lampe":
			var on := alimente() and lampe_voulue()
			if etincelle.visible != on:
				etincelle.visible = on
				lampe_mat.emission_energy_multiplier = 3.0 if on else 0.0
		"cloture_electrique":
			piege_t -= delta
			if etincelle.visible and piege_t < 0.35:
				etincelle.visible = false
			if piege_t > 0.0:
				return
			piege_t = 0.5
			if not alimente():
				return
			var touche := false
			for z in zone.get_overlapping_bodies():
				if not z.has_method("take_hit") or z.get("state") == 3:
					continue
				touche = true
				z.take_hit(10.0 * (1.4 if Game.player and Game.player.prog.a("ingenieur") else 1.0), z.global_position + Vector3.UP * 0.8, global_position)
				if z.has_method("ralentir"):
					z.ralentir(1.5, 0.3)
				health -= 1.0
			if touche:
				etincelle.visible = true
				Game.play_3d("impact_metal", global_position + Vector3.UP * 0.7, -6.0, 0.3, 25.0, 1.6)
			if health <= 0.0:
				Game.msg("La clôture électrique est détruite.")
				queue_free()


func _prompt_elec() -> String:
	var r: Vector2 = get_meta("reseau", Vector2.ZERO)
	var bilan := "production %d W, consommation %d W" % [int(r.x), int(r.y)]
	match kind:
		"groupe_electrogene":
			var essence := "essence %d min" % ceili(minuteur / 60.0 / conso_essence()) if minuteur > 0.0 else "réservoir vide"
			var action := "[F] Éteindre" if armee and minuteur > 0.0 else "[F] Démarrer (verse un jerrican si le réservoir n'est pas plein)"
			return "%s — groupe électrogène : %s ; %s" % [action, essence, bilan]
		"panneau_solaire":
			return "Panneau solaire : %s%s" % [bilan, " (nuit : ne produit rien)" if Game.is_night() else ""]
		"lampe":
			var etat := "alimentée" if alimente() else "sans courant (source à moins de %d m)" % int(rayon_elec())
			return "[F] Lampe : %s, %s (%d W)" % ["automatique (la nuit)" if mode == 0 else MODES[mode], etat, int(CONSO.lampe)]
		"cloture_electrique":
			if alimente():
				return "Clôture électrique sous tension (%d W ; réseau : %s)" % [int(CONSO.cloture_electrique), bilan]
			return "Clôture électrique sans courant : pose un groupe électrogène ou un panneau solaire à moins de %d m" % int(rayon_elec())
	return ""


func _interagir_elec(player: Node) -> void:
	match kind:
		"groupe_electrogene":
			if armee and minuteur > 0.0:
				armee = false
				Game.msg("Groupe électrogène arrêté.")
			else:
				if minuteur <= (RESERVOIR - 1) * ESSENCE_DUREE and player.count("essence") > 0:
					player.remove_item("essence", 1)
					minuteur += ESSENCE_DUREE
				if minuteur <= 0.0:
					Game.msg("Il faut un jerrican d'essence.")
					return
				armee = true
				Game.play_3d("construire", global_position, -8.0, 0.1, 20.0, 0.7)
				Game.msg("Groupe électrogène en marche : %d min d'essence. Il fait du bruit !" % ceili(minuteur / 60.0 / conso_essence()))
			maj_reseau(get_tree(), true)
		"lampe":
			mode = (mode + 1) % MODES.size()
			Game.play_ui("clic_vide", -6.0, 0.05, 1.4)
			maj_reseau(get_tree(), true)
		_:
			Game.msg(_prompt_elec())


## Ronronnement du moteur (son généré une fois : 50 Hz et harmoniques, bouclé sans coupure).
static func _moteur() -> AudioStreamWAV:
	if _son_moteur:
		return _son_moteur
	var rate := 22050
	var n := rate / 2   # 0,5 s = 25 périodes de 50 Hz
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / rate
		var v := 0.45 * sin(TAU * 50.0 * t) + 0.3 * sin(TAU * 100.0 * t + 0.5) + 0.18 * sin(TAU * 150.0 * t) + 0.12 * signf(sin(TAU * 25.0 * t)) * absf(sin(TAU * 200.0 * t))
		v += rng.randf_range(-0.08, 0.08)
		data.encode_s16(i * 2, int(clampf(v * 0.6, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	_son_moteur = w
	return w
