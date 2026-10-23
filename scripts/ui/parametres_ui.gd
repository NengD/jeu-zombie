extends PanelContainer
## Écran Paramètres, partagé par le menu principal et le menu pause : sensibilités, champ de vision,
## taille du texte, ramassage auto, volumes par catégorie, qualité graphique et touches modifiables.
## Tout s'applique tout de suite ; « Retour » (ou Échap) enregistre dans user://parametres.cfg.

signal ferme

var lbls := {}
var boutons_touches := {}
var attente := ""          # action dont on attend la nouvelle touche


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.05, 0.96)
	sb.border_color = Color(0.45, 0.15, 0.1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(24)
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(900, 700)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	var t := Label.new()
	t.text = "PARAMÈTRES"
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", Color(0.85, 0.25, 0.15))
	vb.add_child(t)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(850, 540)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 6)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(c)

	_titre(c, "JEU")
	_curseur(c, "sens", 0.2, 3.0, 0.05, Game.mouse_sens, func(v): Game.mouse_sens = v)
	_curseur(c, "visee", 0.3, 1.5, 0.05, Game.sens_visee, func(v): Game.sens_visee = v)
	_curseur(c, "fov", 55.0, 100.0, 1.0, Game.fov, func(v): Game.fov = v)
	_curseur(c, "texte", 0.75, 1.5, 0.05, Game.taille_texte, func(v): Game.taille_texte = v, true)
	var cb := CheckBox.new()
	cb.text = "Ramasser automatiquement les munitions et les flèches en passant dessus"
	cb.add_theme_font_size_override("font_size", 17)
	cb.button_pressed = Game.ramassage_auto
	cb.toggled.connect(func(on): Game.ramassage_auto = on)
	c.add_child(cb)

	_titre(c, "SON")
	_curseur(c, "volume", 0.0, 1.0, 0.05, Game.volume, func(v): Game.volume = v)
	_curseur(c, "effets", 0.0, 1.0, 0.05, Game.vol_effets, func(v): Game.vol_effets = v)
	_curseur(c, "voix", 0.0, 1.0, 0.05, Game.vol_voix, func(v): Game.vol_voix = v)
	_curseur(c, "ambiance", 0.0, 1.0, 0.05, Game.vol_ambiance, func(v): Game.vol_ambiance = v)

	_titre(c, "GRAPHISMES")
	var hq := HBoxContainer.new()
	c.add_child(hq)
	_texte(hq, "Qualité (Élevé et Ultra : brume volumétrique, reflets, ombres douces) :")
	var qg := OptionButton.new()
	for nom in Game.NOMS_QUALITE:
		qg.add_item(nom)
	qg.selected = Game.qualite
	qg.item_selected.connect(func(i): Game.qualite = i; Game.save_settings())
	hq.add_child(qg)

	_titre(c, "TOUCHES  (clic sur une touche, puis appuie sur la nouvelle ; Échap annule)")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 4)
	c.add_child(grid)
	for a in Game.TOUCHES_MODIFIABLES:
		var l := _texte(grid, a[1])
		l.custom_minimum_size.x = 300
		var b := Button.new()
		b.custom_minimum_size = Vector2(260, 30)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_attendre.bind(a[0]))
		grid.add_child(b)
		boutons_touches[a[0]] = b
	var defaut := Button.new()
	defaut.text = "Touches par défaut"
	defaut.add_theme_font_size_override("font_size", 16)
	defaut.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	defaut.pressed.connect(func(): Game.touches_par_defaut(); _maj_touches())
	c.add_child(defaut)
	_texte(c, "Autres touches : 1 à 5 et molette (barre rapide), Échap (pause), F1 (aide), F5 / F9 (sauvegarde rapide).")
	_maj_touches()

	var retour := Button.new()
	retour.text = "Retour"
	retour.custom_minimum_size = Vector2(200, 46)
	retour.add_theme_font_size_override("font_size", 20)
	retour.size_flags_horizontal = Control.SIZE_SHRINK_END
	retour.pressed.connect(fermer)
	vb.add_child(retour)
	_maj_libelles()


func _titre(parent: Control, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.9, 0.8, 0.45))
	parent.add_child(l)


func _texte(parent: Control, t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 17)
	parent.add_child(l)
	return l


## Curseur avec son libellé ; `fin_glisse` : la valeur ne s'applique qu'en lâchant (taille du texte,
## qui redimensionne le curseur lui-même).
func _curseur(parent: Control, cle: String, mini: float, maxi: float, pas: float, val: float, cb: Callable, fin_glisse := false) -> void:
	lbls[cle] = _texte(parent, "")
	var s := HSlider.new()
	s.min_value = mini
	s.max_value = maxi
	s.step = pas
	s.value = val
	s.custom_minimum_size = Vector2(520, 22)
	s.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var glisse := [false]
	s.drag_started.connect(func(): glisse[0] = true)
	s.drag_ended.connect(func(_c):
		glisse[0] = false
		if fin_glisse:
			Game.appliquer_son_et_texte())
	s.value_changed.connect(func(v):
		cb.call(v)
		_maj_libelles()
		if not fin_glisse or not glisse[0]:
			Game.appliquer_son_et_texte())
	parent.add_child(s)


func _maj_libelles() -> void:
	lbls.sens.text = "Sensibilité de la souris : %.2f" % Game.mouse_sens
	lbls.visee.text = "Sensibilité en visée : ×%.2f" % Game.sens_visee
	lbls.fov.text = "Champ de vision : %d°" % int(Game.fov)
	lbls.texte.text = "Taille du texte et de l'interface : %d %%" % int(round(Game.taille_texte * 100.0))
	lbls.volume.text = "Volume général : %d %%" % int(Game.volume * 100)
	lbls.effets.text = "Effets (armes, pas, actions) : %d %%" % int(Game.vol_effets * 100)
	lbls.voix.text = "Voix des zombies : %d %%" % int(Game.vol_voix * 100)
	lbls.ambiance.text = "Ambiance (vent, pluie, nuit, musique) : %d %%" % int(Game.vol_ambiance * 100)


func _maj_touches() -> void:
	for a in boutons_touches:
		boutons_touches[a].text = Game.texte_touche(a) if a != attente else "Appuie sur une touche…"


func _attendre(action: String) -> void:
	attente = action
	_maj_touches()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if attente != "":
		var ev: InputEvent = null
		if event is InputEventKey and event.pressed and not event.echo:
			if (event as InputEventKey).keycode == KEY_ESCAPE:
				attente = ""
				_maj_touches()
				get_viewport().set_input_as_handled()
				return
			ev = InputEventKey.new()
			(ev as InputEventKey).physical_keycode = (event as InputEventKey).physical_keycode
		elif event is InputEventMouseButton and event.pressed:
			ev = InputEventMouseButton.new()
			(ev as InputEventMouseButton).button_index = (event as InputEventMouseButton).button_index
		if ev:
			Game.changer_touche(attente, ev)
			attente = ""
			_maj_touches()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		fermer()
		get_viewport().set_input_as_handled()


func fermer() -> void:
	attente = ""
	Game.save_settings()
	visible = false
	ferme.emit()
