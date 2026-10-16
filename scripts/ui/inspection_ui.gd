extends CanvasLayer
## Vue d'inspection d'une arme (touche T) : l'arme en 3D que l'on fait tourner à la souris,
## ses caractéristiques, et ses emplacements d'accessoires (poser / retirer).

const ModeleUtil = preload("res://scripts/modele_util.gd")

var fond: ColorRect
var vue: SubViewportContainer
var sv: SubViewport
var pivot: Node3D
var cam: Camera3D
var modele: Node3D
var panneau: VBoxContainer
var arme := ""
var armes: Array = []
var rot := Vector2(-0.25, 0.6)
var dist := 1.0
var dist_base := 1.0
var glisse := false
var auto := true


func _ready() -> void:
	layer = 7
	add_to_group("inspection_ui")
	fond = ColorRect.new()
	fond.color = Color(0.03, 0.035, 0.04, 0.97)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 0)
	fond.add_child(hb)
	vue = SubViewportContainer.new()
	vue.stretch = true
	vue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vue.size_flags_stretch_ratio = 1.8
	vue.gui_input.connect(_vue_input)
	hb.add_child(vue)
	sv = SubViewport.new()
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	vue.add_child(sv)
	_scene_3d()
	var marge := MarginContainer.new()
	marge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c in ["left", "right", "top", "bottom"]:
		marge.add_theme_constant_override("margin_" + c, 24)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.06, 1.0)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(pc)
	pc.add_child(marge)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	marge.add_child(sc)
	panneau = VBoxContainer.new()
	panneau.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panneau.add_theme_constant_override("separation", 8)
	sc.add_child(panneau)
	visible = false


func _scene_3d() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.1, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.62)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	sv.add_child(env)
	var cle := DirectionalLight3D.new()
	cle.rotation_degrees = Vector3(-35, 35, 0)
	cle.light_energy = 1.6
	sv.add_child(cle)
	var contre := DirectionalLight3D.new()
	contre.rotation_degrees = Vector3(-20, -150, 0)
	contre.light_energy = 0.8
	contre.light_color = Color(0.8, 0.88, 1.0)
	sv.add_child(contre)
	pivot = Node3D.new()
	sv.add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 35.0
	sv.add_child(cam)


# ------------------------------------------------------------------ ouverture
func ouvrir(id := "") -> void:
	var p = Game.player
	if p == null or not p.alive:
		return
	armes = _armes_possedees()
	if armes.is_empty():
		Game.msg("Tu n'as aucune arme à feu à inspecter.")
		return
	if id == "" or not id in armes:
		id = p.current_weapon() if p.current_weapon() in armes else armes[0]
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	if inv and inv.panel.visible:
		inv.close()
	visible = true
	Game.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_choisir(id)


func fermer() -> void:
	visible = false
	Game.ui_open = false
	if Game.player and Game.player.alive:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _armes_possedees() -> Array:
	var out := []
	for a in Accessoires.table():
		if Game.player.count(a) > 0:
			out.append(a)
	return out


func _choisir(id: String) -> void:
	arme = id
	if modele and is_instance_valid(modele):
		modele.queue_free()
	modele = ModeleUtil.arme(id)
	if modele == null:
		modele = Node3D.new()
	pivot.add_child(modele)
	var pts := Accessoires.points(id, modele)
	var taille: Vector3 = pts.get("taille", Vector3(0.3, 0.2, 0.6))
	var centre: Vector3 = pts.get("centre", Vector3.ZERO)
	var k := modele.scale.x
	modele.position = -centre * k
	dist_base = maxf(taille.z * 1.3, taille.y) * k * 2.4 + 0.15
	dist = dist_base
	auto = true
	_maj()


func _maj() -> void:
	var p = Game.player
	Accessoires.habiller(modele, arme, p.accessoires.get(arme, {}))
	_marqueurs()
	_panneau()


## Étiquettes 3D sur les emplacements de l'arme.
func _marqueurs() -> void:
	for c in modele.get_children():
		if c is Label3D:
			c.queue_free()
	var pts := Accessoires.points(arme, modele)
	var accs: Dictionary = Game.player.accessoires.get(arme, {})
	for emp in Accessoires.emplacements(arme):
		var l := Label3D.new()
		l.text = Items.nom(accs[emp]) if accs.has(emp) else "+ " + Accessoires.NOMS_EMPLACEMENTS[emp]
		l.font_size = 32
		l.pixel_size = 0.00028 * dist_base / maxf(modele.scale.x, 0.01)
		l.outline_size = 10
		l.modulate = Color(0.95, 0.85, 0.45) if accs.has(emp) else Color(0.75, 0.78, 0.8)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		var pos: Vector3 = pts.get("chargeur_bas" if emp == "chargeur" else emp, Vector3.ZERO)
		var dec := Vector3(0, 0.06, 0) if emp in ["viseur", "rail"] else (Vector3(0, -0.08, 0) if emp in ["poignee", "chargeur"] else Vector3(0, 0.04, -0.05))
		l.position = pos + dec * dist_base / maxf(modele.scale.x, 0.01) * 0.6
		modele.add_child(l)


func _panneau() -> void:
	for c in panneau.get_children():
		c.queue_free()
	var p = Game.player
	var nav := HBoxContainer.new()
	panneau.add_child(nav)
	var i := armes.find(arme)
	_bouton(nav, "◀", func(): _choisir(armes[(i - 1 + armes.size()) % armes.size()])).disabled = armes.size() < 2
	var titre := _label(nav, Items.nom(arme), 26, Color(0.95, 0.85, 0.5))
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bouton(nav, "▶", func(): _choisir(armes[(i + 1) % armes.size()])).disabled = armes.size() < 2
	_label(panneau, "Clic gauche + glisser : tourner l'arme  •  molette : zoom", 13, Color(0.55, 0.58, 0.55))

	# caractéristiques (base -> avec accessoires)
	var base := Items.info(arme)
	var w: Dictionary = p.arme_stats(arme)
	_label(panneau, "CARACTÉRISTIQUES", 17, Color(0.9, 0.8, 0.45))
	_barre("Dégâts", float(base.damage) * int(base.pellets), float(w.damage) * int(w.pellets), 150.0, true)
	_barre("Précision", 1.0 / float(base.spread), 1.0 / float(w.spread), 2.2, true)
	_barre("Précision en visée", 1.0 / (float(base.spread) * 0.45), 1.0 / (float(w.spread) * float(w.dispersion_visee)), 12.0, true)
	_barre("Discrétion", 100.0 - float(base.noise), 100.0 - float(w.noise), 100.0, true)
	_barre("Stabilité (recul)", 0.1 - float(base.recoil), 0.1 - float(w.recoil), 0.1, true)
	_barre("Capacité", float(base.mag), float(w.mag), 50.0, true, "%d")
	if float(w.fov_visee) < 0.99:
		_label(panneau, "Zoom en visée : ×%.1f" % (1.0 / float(w.fov_visee)), 14, Color(0.7, 0.85, 0.7))

	# emplacements
	_label(panneau, "ACCESSOIRES", 17, Color(0.9, 0.8, 0.45))
	var accs: Dictionary = p.accessoires.get(arme, {})
	for emp in Accessoires.emplacements(arme):
		var bloc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.11, 0.1)
		sb.set_content_margin_all(8)
		sb.set_corner_radius_all(4)
		bloc.add_theme_stylebox_override("panel", sb)
		panneau.add_child(bloc)
		var vb := VBoxContainer.new()
		bloc.add_child(vb)
		var ligne := HBoxContainer.new()
		vb.add_child(ligne)
		var nom_emp := _label(ligne, Accessoires.NOMS_EMPLACEMENTS[emp], 15, Color(0.8, 0.82, 0.85))
		nom_emp.custom_minimum_size.x = 150
		if accs.has(emp):
			var ic := TextureRect.new()
			ic.texture = Items.icon(accs[emp])
			ic.custom_minimum_size = Vector2(28, 28)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ligne.add_child(ic)
			var l := _label(ligne, Items.nom(accs[emp]), 15, Color(0.95, 0.85, 0.5))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var e2: String = emp
			_bouton(ligne, "Retirer", func(): p.retirer_accessoire(arme, e2); _maj())
		else:
			_label(ligne, "libre", 15, Color(0.5, 0.5, 0.5))
		var dispo := 0
		for acc in Accessoires.compatibles(arme, emp):
			if accs.get(emp, "") == acc:
				continue
			var n: int = p.count(acc)
			var a2: String = acc
			var e3: String = emp
			var b := _bouton(vb, ("Poser : %s  (%d)" % [Items.nom(acc), n]) if n > 0 else ("%s — non possédé" % Items.nom(acc)), func(): p.poser_accessoire(arme, e3, a2); _maj())
			b.icon = Items.icon(acc)
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 24)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.disabled = n <= 0
			b.tooltip_text = Items.info(acc).get("desc", "")
			if n > 0:
				dispo += 1
	_label(panneau, "", 6, Color.WHITE)
	_bouton(panneau, "Fermer  (T / Échap)", fermer)


func _barre(nom: String, base: float, val: float, maxi: float, plus_haut_mieux: bool, fmt := "") -> void:
	var hb := HBoxContainer.new()
	panneau.add_child(hb)
	var l := _label(hb, nom, 14, Color(0.82, 0.82, 0.8))
	l.custom_minimum_size.x = 170
	var barre := Control.new()
	barre.custom_minimum_size = Vector2(220, 14)
	barre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fb := clampf(base / maxi, 0.0, 1.0)
	var fv := clampf(val / maxi, 0.0, 1.0)
	barre.draw.connect(func():
		barre.draw_rect(Rect2(Vector2.ZERO, barre.size), Color(0.15, 0.16, 0.15))
		var mieux := (fv > fb) == plus_haut_mieux
		barre.draw_rect(Rect2(0, 0, barre.size.x * minf(fb, fv), barre.size.y), Color(0.75, 0.75, 0.72))
		if absf(fv - fb) > 0.001:
			var x0 := barre.size.x * minf(fb, fv)
			barre.draw_rect(Rect2(x0, 0, barre.size.x * absf(fv - fb), barre.size.y), Color(0.35, 0.85, 0.35) if mieux else Color(0.9, 0.3, 0.25)))
	hb.add_child(barre)
	if fmt != "":
		_label(hb, ("  " + fmt) % val, 14, Color(0.82, 0.82, 0.8))


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


# ------------------------------------------------------------------ souris / clavier
func _vue_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			glisse = ev.pressed
			auto = false
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			dist = maxf(dist_base * 0.4, dist * 0.9)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			dist = minf(dist_base * 2.0, dist * 1.1)
	elif ev is InputEventMouseMotion and glisse:
		rot.y += ev.relative.x * 0.01
		rot.x = clampf(rot.x + ev.relative.y * 0.01, -1.3, 1.3)


func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("inspecter") or event.is_action_pressed("pause"):
			fermer()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inspecter") and not Game.ui_open and Game.player and Game.player.alive:
		ouvrir()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	if auto:
		rot.y += delta * 0.35
	pivot.rotation = Vector3(rot.x, rot.y, 0)
	cam.position = Vector3(0, 0, dist)
	cam.look_at(Vector3.ZERO)
