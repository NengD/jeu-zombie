extends CanvasLayer
## Panneau du mode admin (touche F2) : tout ce qu'il faut pour tester le jeu rapidement.
## Vol (N), invincibilité, munitions infinies, objets, coffres de tous les objets, téléportation,
## heure, zombies, boss, progression. Rien n'est sauvegardé en mode admin.

const LootContainer = preload("res://scripts/loot_container.gd")

var fond: PanelContainer
var contenu: VBoxContainer
var liste: ItemList
var ids: Array = []
var bandeau: Label
var case_vol: CheckBox


func _process(_delta: float) -> void:
	# la touche N change aussi le vol : la case suit
	if case_vol and fond.visible:
		case_vol.set_pressed_no_signal(Game.admin_vol)


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	# bandeau permanent en haut de l'écran
	bandeau = Label.new()
	bandeau.text = "MODE ADMIN — F2 : panneau   N : voler"
	bandeau.add_theme_font_size_override("font_size", 15)
	bandeau.add_theme_color_override("font_color", Color(1.0, 0.45, 0.3))
	bandeau.add_theme_color_override("font_outline_color", Color.BLACK)
	bandeau.add_theme_constant_override("outline_size", 4)
	bandeau.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bandeau.position = Vector2(-150, 52)
	add_child(bandeau)
	fond = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.05, 0.95)
	sb.border_color = Color(0.85, 0.35, 0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	fond.add_theme_stylebox_override("panel", sb)
	fond.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fond.offset_left = 20
	fond.offset_top = 20
	fond.offset_bottom = -20
	fond.custom_minimum_size = Vector2(860, 0)
	add_child(fond)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fond.add_child(sc)
	contenu = VBoxContainer.new()
	contenu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenu.add_theme_constant_override("separation", 10)
	sc.add_child(contenu)
	fond.visible = false
	_construire()


func _construire() -> void:
	var tete := HBoxContainer.new()
	contenu.add_child(tete)
	var t := _label(tete, "MODE ADMIN", 26, Color(1.0, 0.5, 0.3))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bouton(tete, "Fermer (F2 / Échap)", fermer)
	_label(contenu, "Rien n'est sauvegardé dans ce mode : ta vraie partie reste intacte.", 14, Color(0.7, 0.7, 0.68))

	# ------------------------------------------------ options
	_titre("Options")
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 18)
	contenu.add_child(g)
	_case(g, "Invincible", "admin_invincible")
	_case(g, "Munitions infinies", "admin_munitions")
	_case(g, "Ni faim ni soif, endurance infinie", "admin_besoins")
	_case(g, "Voler (touche N)", "admin_vol")
	_case(g, "Traverser les murs en volant", "admin_murs")
	_case(g, "Invisible pour les zombies", "admin_invisible")

	# ------------------------------------------------ objets
	_titre("Objets")
	var h := HBoxContainer.new()
	contenu.add_child(h)
	_bouton(h, "Équipement complet", _equipement)
	_bouton(h, "Coffres de tous les objets", _coffres)
	_bouton(h, "Munitions ×200", func():
		for m in ["mun_9mm", "mun_12", "mun_556"]:
			Game.player.add_item(m, 200)
		Game.msg("Munitions ajoutées."))
	_bouton(h, "Lancer une horde sur ma base", func():
		var m = Game.player.get_parent()
		var b = m._base_principale()
		if b == null:
			Game.msg("Il faut une base d'au moins 4 pièces.")
		else:
			m.annoncer_horde(b))
	_bouton(h, "Pluie / beau temps", func():
		var mt = Game.player.get_parent().get_node_or_null("Meteo")
		if mt:
			mt.cible = 0.0 if mt.cible > 0.0 else 1.0
			mt.prochain = 600.0
			Game.msg("Météo : " + ("pluie" if mt.cible > 0.0 else "beau temps")))
	_bouton(h, "Vider l'inventaire", func():
		Game.player.poches.entrees.clear()
		Game.player._check_hotbar()
		Game.msg("Inventaire vidé."))
	_label(contenu, "Double-clic sur un objet pour le recevoir (une pile complète) :", 14, Color(0.75, 0.75, 0.72))
	liste = ItemList.new()
	liste.custom_minimum_size = Vector2(0, 230)
	liste.max_columns = 3
	liste.same_column_width = true
	liste.fixed_column_width = 260
	liste.fixed_icon_size = Vector2i(28, 28)
	contenu.add_child(liste)
	var tous: Array = Items.DB.keys()
	tous.sort_custom(func(a, b): return str(Items.info(a).get("type", "")) + Items.nom(a) < str(Items.info(b).get("type", "")) + Items.nom(b))
	for id in tous:
		ids.append(id)
		liste.add_item(Items.nom(id), Items.icon(id))
	liste.item_activated.connect(func(i: int): _donner(ids[i]))

	# ------------------------------------------------ téléportation
	_titre("Téléportation")
	var gt := GridContainer.new()
	gt.columns = 4
	contenu.add_child(gt)
	_bouton(gt, "Point de départ", func(): _teleporter(Game.player.get_parent().world.spawn_point))
	for poi in Game.pois:
		var pos: Vector3 = poi.pos
		_bouton(gt, str(poi.name), func(): _teleporter(pos))

	# ------------------------------------------------ temps
	_titre("Heure")
	var ht := HBoxContainer.new()
	contenu.add_child(ht)
	for hh in [[6.0, "Aube"], [9.0, "Matin"], [13.0, "Midi"], [19.0, "Soir"], [23.0, "Nuit"]]:
		var v: float = hh[0]
		_bouton(ht, hh[1], func(): Game.time_hours = v; Game.msg("Heure : %02d:00" % int(v)))
	_bouton(ht, "Jour suivant", func(): Game.day += 1; Game.msg("Jour %d" % Game.day))

	# ------------------------------------------------ zombies
	_titre("Zombies")
	var hz := HBoxContainer.new()
	contenu.add_child(hz)
	_bouton(hz, "1 zombie", func(): _zombies("civil", 1))
	_bouton(hz, "Horde ×10", func(): _zombies("civil", 10))
	_bouton(hz, "Policier", func(): _zombies("police", 1))
	_bouton(hz, "Militaire", func(): _zombies("militaire", 1))
	_bouton(hz, "Coureur", func(): _zombies("coureur", 1))
	_bouton(hz, "Gros", func(): _zombies("gros", 1))
	_bouton(hz, "Rampant", func(): _zombies("rampant", 1))
	_bouton(hz, "Le Colosse (boss)", func(): _zombies("boss", 1))
	_bouton(hz, "Tuer les zombies proches", _tuer)

	# ------------------------------------------------ joueur
	_titre("Joueur")
	var hj := HBoxContainer.new()
	contenu.add_child(hj)
	_bouton(hj, "Soigner", func():
		var p = Game.player
		p.health = p.prog.sante_max()
		p.hunger = 100.0
		p.thirst = 100.0
		p.stamina = p.prog.endurance_max()
		Game.msg("Soigné."))
	_bouton(hj, "+1 niveau", func():
		var pr = Game.player.prog
		pr.gagner("", Progression.xp_niveau(pr.niveau) - pr.xp))
	_bouton(hj, "+1 niveau dans chaque compétence", func():
		var pr = Game.player.prog
		for c in Progression.COMPETENCES:
			var d: Dictionary = pr.comp[c]
			if d.niv < Progression.NIVEAU_MAX_COMP:
				pr.gagner(c, Progression.xp_comp(d.niv) - int(d.xp)))
	_bouton(hj, "Tous les talents", func():
		var pr = Game.player.prog
		for c in Progression.COMPETENCES:
			pr.comp[c].niv = Progression.NIVEAU_MAX_COMP
		for tid in Progression.TALENTS:
			if not pr.a(tid):
				pr.talents.append(tid)
		Game.player.maj_poches()
		Game.msg("Tous les talents débloqués."))


# ================================================================ actions
func _donner(id: String) -> void:
	var p = Game.player
	var n: int = Items.stack(id) if Items.stack(id) > 1 else 1
	if Items.info(id).get("type", "") == "ammo":
		n = 100
	var reste: int = p.add_item(id, n)
	if reste >= n:
		Game.msg("Plus de place dans l'inventaire pour : " + Items.nom(id))
	else:
		Game.msg("Reçu : %s" % Items.nom(id))


func _equipement() -> void:
	var p = Game.player
	p.equipped.dos = p.nouvelle_entree("sac_militaire")
	for s in ["gilet_militaire", "casque_militaire"]:
		var info: Dictionary = Items.info(s)
		if info.has("slot"):
			p.equipped[info.slot] = p.nouvelle_entree(s)
	p.maj_poches()
	var armes := ["m4a1", "glock19", "benelli_m4", "rgd5", "machette"]
	for id in armes:
		p.add_item(id, 4 if id == "rgd5" else 1)
	p.accessoires["m4a1"] = {"viseur": "viseur_holo", "bouche": "silencieux", "chargeur": "chargeur_etendu", "rail": "laser", "poignee": "poignee"}
	p.accessoires["glock19"] = {"viseur": "point_rouge", "bouche": "silencieux_9mm"}
	for m in [["mun_556", 240], ["mun_9mm", 120], ["mun_12", 48], ["trousse", 3], ["bandage", 6], ["eau", 3], ["ration", 3]]:
		p.add_item(m[0], m[1])
	for i in 5:
		p.hotbar[i] = armes[i]
	for id in ["m4a1", "glock19", "benelli_m4"]:
		p.mags[id] = int(p.arme_stats(id).mag)
	p.slot = -1
	p._select_slot(0)
	Game.msg("Équipement complet : M4A1 équipé (holographique, silencieux, laser, poignée), Glock 19, Benelli M4, grenades, gilet, casque, sac militaire.")


## Cinq coffres posés devant le joueur, un par catégorie, avec un exemplaire de chaque objet.
func _coffres() -> void:
	var p = Game.player
	var cats := [["Coffre : armes", ["gun", "melee", "lancer"]], ["Coffre : munitions et accessoires", ["ammo", "accessoire"]],
		["Coffre : équipement", ["armor"]], ["Coffre : soins et nourriture", ["heal", "food", "drink"]],
		["Coffre : matériaux et constructions", ["material", "placeable"]]]
	var fwd: Vector3 = -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var cote := Vector3(-fwd.z, 0, fwd.x)
	for k in cats.size():
		var c = LootContainer.new()
		c.setup(cats[k][0], "", Vector3(1.2, 0.8, 0.8), Color(0.7, 0.3, 0.15))
		c.make_storage(16, 16)
		for id in Items.DB:
			if not (str(Items.info(id).get("type", "")) in cats[k][1]):
				continue
			if Items.grid(id).x > 0:
				c.grille.ajouter_entree(p.nouvelle_entree(id))
			else:
				var n: int = 100 if Items.info(id).get("type", "") == "ammo" else maxi(1, Items.stack(id))
				c.grille.ajouter(id, n)
		p.get_parent().add_child(c)
		var pos: Vector3 = p.global_position + fwd * 3.0 + cote * (k - 2) * 1.6
		pos.y = p.global_position.y if not Game.admin_vol else Game.hauteur(pos.x, pos.z)
		c.global_position = pos
		c.rotation.y = p.rotation.y
	fermer()
	Game.msg("5 coffres posés devant toi (F pour les ouvrir).")


func _teleporter(pos: Vector3) -> void:
	var p = Game.player
	var y := Game.hauteur(pos.x, pos.z) + 1.0
	p.global_position = Vector3(pos.x + 4.0, maxf(y, pos.y + 1.0), pos.z + 4.0)
	p.velocity = Vector3.ZERO
	fermer()
	Game.msg("Téléporté.")


func _zombies(kind: String, n: int) -> void:
	var p = Game.player
	var m = p.get_parent()
	var fwd: Vector3 = -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for i in n:
		var pos: Vector3 = p.global_position + fwd * (8.0 + i * 0.8) + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		pos.y = maxf(Game.hauteur(pos.x, pos.z), p.global_position.y if p.is_on_floor() else Game.hauteur(pos.x, pos.z)) + 0.2
		m.spawn_zombie(pos, kind, kind == "boss", 10.0)
	fermer()
	Game.msg("%d zombie(s) ajouté(s)." % n)


func _tuer() -> void:
	var p = Game.player
	var n := 0
	for z in get_tree().get_nodes_in_group("zombies"):
		if z.global_position.distance_to(p.global_position) < 80.0:
			z.take_hit(99999.0, z.global_position + Vector3.UP, p.global_position)
			n += 1
	Game.msg("%d zombie(s) éliminé(s)." % n)


# ================================================================ affichage
func ouvrir() -> void:
	fond.visible = true
	Game.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func fermer() -> void:
	fond.visible = false
	Game.ui_open = false
	if Game.player and Game.player.alive:
		Game.capturer_souris()


func _input(event: InputEvent) -> void:
	if fond.visible:
		if event.is_action_pressed("admin_panneau") or event.is_action_pressed("pause"):
			fermer()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("admin_panneau") and not Game.ui_open and Game.player and Game.player.alive:
		ouvrir()
		get_viewport().set_input_as_handled()


func _titre(t: String) -> void:
	var sep := HSeparator.new()
	contenu.add_child(sep)
	_label(contenu, t.to_upper(), 18, Color(0.95, 0.8, 0.5))


func _case(parent: Node, texte: String, prop: String) -> void:
	var c := CheckBox.new()
	c.text = texte
	c.button_pressed = bool(Game.get(prop))
	c.add_theme_font_size_override("font_size", 15)
	c.toggled.connect(func(on: bool):
		Game.set(prop, on)
		if prop == "admin_vol" and not on and Game.player:
			Game.player.collision_mask = Game.LAYER_WORLD | Game.LAYER_ZOMBIE)
	parent.add_child(c)
	if prop == "admin_vol":
		case_vol = c


func _label(parent: Node, t: String, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	parent.add_child(l)
	return l


func _bouton(parent: Node, t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
