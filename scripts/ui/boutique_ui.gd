extends CanvasLayer
## Boutique d'un marchand : acheter son stock (à gauche), revendre ses objets à 40 % (à droite).

const LOTS := {"clous": 10, "planche": 5}   # vendus par lots ; les munitions par 20

var fond: ColorRect
var contenu: VBoxContainer
var vendeur: Node = null


func _ready() -> void:
	layer = 7
	add_to_group("boutique_ui")
	fond = ColorRect.new()
	fond.color = Color(0.03, 0.035, 0.04, 0.95)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for c in ["left", "right"]:
		marge.add_theme_constant_override("margin_" + c, 60)
	for c in ["top", "bottom"]:
		marge.add_theme_constant_override("margin_" + c, 36)
	fond.add_child(marge)
	contenu = VBoxContainer.new()
	contenu.add_theme_constant_override("separation", 12)
	marge.add_child(contenu)
	visible = false


func ouvrir(v: Node) -> void:
	if Game.player == null or not Game.player.alive:
		return
	vendeur = v
	visible = true
	Game.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.play_ui("fouille", -8.0, 0.1, 1.2)
	_maj()


func fermer() -> void:
	visible = false
	vendeur = null
	Game.ui_open = false
	if Game.player and Game.player.alive:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("interagir")):
		fermer()
		get_viewport().set_input_as_handled()


static func lot(id: String) -> int:
	if LOTS.has(id):
		return LOTS[id]
	return 20 if Items.info(id).get("type", "") == "ammo" else 1


func _maj() -> void:
	for c in contenu.get_children():
		contenu.remove_child(c)
		c.queue_free()
	var p = Game.player
	var tete := HBoxContainer.new()
	contenu.add_child(tete)
	var t := _label(tete, "%s — %s" % [vendeur.nom.to_upper(), vendeur.titre().to_upper()], 30, Color(0.95, 0.85, 0.5))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(tete, "Ton argent : %d €    " % p.argent, 24, Color(0.6, 1.0, 0.6))
	_bouton(tete, "Fermer  (F / Échap)", fermer)
	_primes(p)
	var colonnes := HBoxContainer.new()
	colonnes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonnes.add_theme_constant_override("separation", 40)
	contenu.add_child(colonnes)
	# ------------------------------------------------ achat
	var achat := _colonne(colonnes, "ACHETER")
	for id in vendeur.stock():
		if not Items.DB.has(id):
			continue
		var n := lot(id)
		var prix: int = Items.prix(id) * n
		var ligne := _ligne(achat, id, ("%d× " % n if n > 1 else "") + Items.nom(id), "%d €" % prix)
		var b := _bouton(ligne, "Acheter", _acheter.bind(id, n, prix))
		b.disabled = p.argent < prix
	# ------------------------------------------------ vente
	var vente := _colonne(colonnes, "VENDRE (40 % du prix)")
	var objets := {}
	for g in p.grilles():
		for e in g.entrees:
			if e.get("contenu") != null and not e.contenu.vide():
				continue   # sac encore rempli : à vider d'abord
			objets[e.id] = int(objets.get(e.id, 0)) + int(e.n)
	var ids: Array = objets.keys()
	ids.sort_custom(func(a, b): return Items.nom(a) < Items.nom(b))
	if ids.is_empty():
		_label(vente, "Rien à vendre.", 16, Color(0.7, 0.7, 0.68))
	for id in ids:
		var pv: int = Items.prix_vente(id)
		if pv <= 0:
			continue
		var nb: int = objets[id]
		var ligne := _ligne(vente, id, "%s  (×%d)" % [Items.nom(id), nb], "%d € / u" % pv)
		var n1 := mini(lot(id), nb)
		_bouton(ligne, "Vendre %d" % n1, _vendre.bind(id, n1))
		if nb > n1:
			_bouton(ligne, "Tout (%d €)" % (pv * nb), _vendre.bind(id, nb))


## Primes sur les camps de bandits : où ils sont, combien il en reste, et paiement une fois nettoyés.
func _primes(p: Node) -> void:
	var main: Node = p.get_parent()
	if not main.has_method("infos_primes"):
		return
	var infos: Array = main.infos_primes(vendeur.global_position)
	if infos.is_empty():
		return
	_label(contenu, "PRIMES — camps de bandits (carte M, en rouge)", 20, Color(1.0, 0.45, 0.35))
	var grille := GridContainer.new()
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", 40)
	contenu.add_child(grille)
	for e in infos:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		grille.add_child(h)
		var texte := "Camp au %s (%d m) — " % [e.dir, e.dist]
		if e.payee:
			_label(h, texte + "prime payée", 15, Color(0.55, 0.55, 0.52))
		elif e.restants > 0:
			_label(h, texte + "%d bandit(s) — prime %d €" % [e.restants, e.prime], 15, Color(0.9, 0.9, 0.88))
		else:
			_label(h, texte + "nettoyé !", 15, Color(0.6, 1.0, 0.6))
			_bouton(h, "Toucher %d €" % e.prime, func():
				if main.reclamer_prime(e.i):
					_maj())


func _acheter(id: String, n: int, prix: int) -> void:
	var p = Game.player
	if p.argent < prix:
		return
	p.argent -= prix
	p.add_item(id, n)
	Game.play_ui("fouille", -6.0, 0.1, 1.4)
	Game.msg("Acheté : %s%s (-%d €)" % ["%d× " % n if n > 1 else "", Items.nom(id), prix])
	_maj()


func _vendre(id: String, n: int) -> void:
	var p = Game.player
	if p.count(id) < n:
		return
	var gain: int = Items.prix_vente(id) * n
	if not p.remove_item(id, n):
		return
	if id == p.current_weapon():
		p._refresh_weapon_model()
	p.gagner_argent(gain, true)
	Game.play_ui("fouille", -6.0, 0.1, 1.1)
	Game.msg("Vendu : %d× %s (+%d €)" % [n, Items.nom(id), gain])
	_maj()


# ------------------------------------------------ petits outils d'interface
func _colonne(parent: Node, titre: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	_label(v, titre, 22, Color(0.9, 0.8, 0.5))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var liste := VBoxContainer.new()
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste.add_theme_constant_override("separation", 4)
	sc.add_child(liste)
	return liste


func _ligne(parent: Node, id: String, texte: String, prix: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	var ic := TextureRect.new()
	ic.texture = Items.icon(id)
	ic.custom_minimum_size = Vector2(34, 34)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ic.texture and String(ic.texture.resource_path).ends_with(".svg"):
		ic.modulate = Items.category_color(id)
	h.add_child(ic)
	var n := _label(h, texte, 16, Color(0.9, 0.9, 0.88))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pl := _label(h, prix, 16, Color(0.6, 1.0, 0.6))
	pl.custom_minimum_size = Vector2(90, 0)
	return h


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
