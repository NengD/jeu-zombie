extends CanvasLayer
## Écran « Personnage » (touche K) : niveau global et points d'attribut,
## compétences Combat / Fabrication / Exploration et leurs talents.

var fond: ColorRect
var contenu: VBoxContainer


func _ready() -> void:
	layer = 7
	add_to_group("competences_ui")
	fond = ColorRect.new()
	fond.color = Color(0.03, 0.035, 0.04, 0.96)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for c in ["left", "right"]:
		marge.add_theme_constant_override("margin_" + c, 60)
	for c in ["top", "bottom"]:
		marge.add_theme_constant_override("margin_" + c, 36)
	fond.add_child(marge)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	marge.add_child(sc)
	contenu = VBoxContainer.new()
	contenu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenu.add_theme_constant_override("separation", 14)
	sc.add_child(contenu)
	visible = false


func ouvrir() -> void:
	if Game.player == null or not Game.player.alive:
		return
	visible = true
	Game.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_maj()


func fermer() -> void:
	visible = false
	Game.ui_open = false
	if Game.player and Game.player.alive:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _maj() -> void:
	for c in contenu.get_children():
		c.queue_free()
	var p = Game.player
	var pr = p.prog
	# ---------------------------------------------------------- en-tête : niveau global
	var tete := HBoxContainer.new()
	contenu.add_child(tete)
	var t := _label(tete, "PERSONNAGE — NIVEAU %d" % pr.niveau, 30, Color(0.95, 0.85, 0.5))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bouton(tete, "Fermer  (K / Échap)", fermer)
	_barre(contenu, pr.xp, Progression.xp_niveau(pr.niveau), Color(0.95, 0.8, 0.35), "%d / %d XP avant le niveau %d" % [pr.xp, Progression.xp_niveau(pr.niveau), pr.niveau + 1], 600)

	# ---------------------------------------------------------- attributs
	var bloc_a := _bloc(contenu)
	var ta := _label(bloc_a, "ATTRIBUTS — %d point(s) à dépenser" % pr.points, 20, Color(0.9, 0.8, 0.45) if pr.points > 0 else Color(0.75, 0.75, 0.72))
	ta.tooltip_text = "Tu gagnes 1 point d'attribut à chaque niveau global."
	var grille := GridContainer.new()
	grille.columns = 4
	grille.add_theme_constant_override("h_separation", 18)
	grille.add_theme_constant_override("v_separation", 6)
	bloc_a.add_child(grille)
	var valeurs := {
		"endurance": "Endurance max : %d" % int(pr.endurance_max()),
		"sante": "Santé max : %d" % int(pr.sante_max()),
		"soif": "Soif : -%d %% plus lente" % int(round((1.0 - pr.soif_mult()) * 100.0)),
		"faim": "Faim : -%d %% plus lente" % int(round((1.0 - pr.faim_mult()) * 100.0)),
	}
	for a in Progression.ATTRIBUTS:
		var info: Dictionary = Progression.ATTRIBUTS[a]
		_label(grille, "%s  (%d)" % [info.nom, pr.attributs[a]], 18, Color.WHITE).custom_minimum_size.x = 170
		_label(grille, valeurs[a], 15, Color(0.75, 0.8, 0.75)).custom_minimum_size.x = 230
		_label(grille, info.desc + " par point", 13, Color(0.55, 0.58, 0.55)).custom_minimum_size.x = 330
		var a2: String = a
		var b := _bouton(grille, "+1", func(): if pr.ameliorer(a2): _maj())
		b.disabled = pr.points <= 0
		b.custom_minimum_size.x = 60

	# ---------------------------------------------------------- compétences
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	contenu.add_child(cols)
	for c in Progression.COMPETENCES:
		var d: Dictionary = pr.comp[c]
		var bloc := _bloc(cols)
		bloc.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(bloc, "%s — niveau %d" % [Progression.NOMS[c].to_upper(), d.niv], 20, Color(0.95, 0.85, 0.5))
		if d.niv < Progression.NIVEAU_MAX_COMP:
			_barre(bloc, d.xp, Progression.xp_comp(d.niv), Color(0.45, 0.75, 0.95), "%d / %d XP" % [d.xp, Progression.xp_comp(d.niv)], 0)
		else:
			_label(bloc, "Niveau maximum atteint", 14, Color(0.6, 0.9, 0.6))
		_label(bloc, _gains(c), 13, Color(0.55, 0.58, 0.55))
		_label(bloc, "Points de talent : %d" % d.points, 16, Color(0.9, 0.8, 0.45) if d.points > 0 else Color(0.7, 0.7, 0.68))
		for tid in Progression.TALENTS:
			var ti: Dictionary = Progression.TALENTS[tid]
			if ti.comp != c:
				continue
			var ligne := PanelContainer.new()
			var sb := StyleBoxFlat.new()
			sb.set_content_margin_all(8)
			sb.set_corner_radius_all(4)
			if pr.a(tid):
				sb.bg_color = Color(0.12, 0.25, 0.12)
			elif pr.peut_debloquer(tid):
				sb.bg_color = Color(0.22, 0.2, 0.1)
			else:
				sb.bg_color = Color(0.1, 0.1, 0.1)
			ligne.add_theme_stylebox_override("panel", sb)
			bloc.add_child(ligne)
			var hb := HBoxContainer.new()
			ligne.add_child(hb)
			var vb := VBoxContainer.new()
			vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(vb)
			_label(vb, "%s   (niveau %d)" % [ti.nom, ti.niv], 16, Color.WHITE if d.niv >= ti.niv else Color(0.5, 0.5, 0.5))
			var dl := _label(vb, ti.desc, 13, Color(0.7, 0.72, 0.7))
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dl.custom_minimum_size.x = 300
			if pr.a(tid):
				_label(hb, "✔ Acquis", 15, Color(0.5, 1.0, 0.5))
			else:
				var t2: String = tid
				var b := _bouton(hb, "Débloquer", func(): if pr.debloquer(t2): _apres_talent(t2))
				b.disabled = not pr.peut_debloquer(tid)


func _apres_talent(t: String) -> void:
	var p = Game.player
	if t in ["poches", "poches2"]:
		p.maj_poches()
	Game.play_ui("construire", -3.0, 0.0, 1.4)
	Game.msg("Talent débloqué : " + Progression.TALENTS[t].nom)
	_maj()


func _gains(c: String) -> String:
	match c:
		"combat":
			return "XP : tuer des zombies (plus pour policiers et militaires), frapper au corps à corps."
		"fabrication":
			return "XP : fabriquer des objets, poser des établis, caisses, barricades."
		_:
			return "XP : fouiller meubles et corps, découvrir bâtiments et lieux importants."


func _bloc(parent: Node) -> VBoxContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.07)
	sb.set_content_margin_all(14)
	sb.set_corner_radius_all(6)
	pc.add_theme_stylebox_override("panel", sb)
	parent.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pc.add_child(vb)
	return vb


func _barre(parent: Node, v: float, mx: float, col: Color, texte: String, largeur: float) -> void:
	var hb := HBoxContainer.new()
	parent.add_child(hb)
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.max_value = maxf(mx, 1.0)
	pb.value = v
	pb.custom_minimum_size = Vector2(largeur if largeur > 0 else 200, 12)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if largeur <= 0:
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var f := StyleBoxFlat.new()
	f.bg_color = col
	var b := StyleBoxFlat.new()
	b.bg_color = Color(0, 0, 0, 0.5)
	pb.add_theme_stylebox_override("fill", f)
	pb.add_theme_stylebox_override("background", b)
	hb.add_child(pb)
	_label(hb, "  " + texte, 14, Color(0.8, 0.8, 0.78))


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


func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("competences") or event.is_action_pressed("pause"):
			fermer()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("competences") and not Game.ui_open and Game.player and Game.player.alive:
		ouvrir()
		get_viewport().set_input_as_handled()
