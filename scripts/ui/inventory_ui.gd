extends CanvasLayer
## Inventaire en grille (style SurrounDead) : poches, gilet et sac à dos,
## équipement, barre rapide, conteneurs (meubles, caisses, corps, sol) et fabrication.
##
## Souris :
##   glisser-déposer un objet entre les grilles, vers l'équipement ou la barre rapide
##   R pendant le glissement : tourner l'objet
##   double-clic : utiliser / équiper        Ctrl + clic : transfert rapide
##   clic droit : menu (utiliser, équiper, démonter, diviser, jeter…)
##   déposer hors de la fenêtre : jeter au sol

const Peremption = preload("res://scripts/peremption.gd")
const CELL := 52.0

# ------------------------------------------------------------------ vues
class GridView extends Control:
	const CELL := 52.0
	var grille: Grille
	var ui
	var hover := Vector2i(-1, -1)

	func setup(p_ui, g: Grille) -> void:
		ui = p_ui
		grille = g
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(g.w, g.h) * CELL

	func cell_at(local: Vector2) -> Vector2i:
		return Vector2i(floori(local.x / CELL), floori(local.y / CELL))

	func _draw() -> void:
		for y in grille.h:
			for x in grille.w:
				var r := Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL)).grow(-1)
				draw_rect(r, Color(0.1, 0.11, 0.1, 0.9))
				draw_rect(r, Color(0.25, 0.26, 0.22), false, 1.0)
		for e in grille.entrees:
			var s := Grille.taille(e)
			var r := Rect2(Vector2(e.x, e.y) * CELL, Vector2(s) * CELL).grow(-2)
			ui.draw_entry(self, r, e)
		if ui.held and hover.x >= 0:
			var e: Dictionary = ui.held.e
			var tl: Vector2i = hover - ui.held.grab
			var s2 := Grille.taille(e)
			var ok: bool = ui.can_drop_in(grille, tl, e)
			draw_rect(Rect2(Vector2(tl) * CELL, Vector2(s2) * CELL).grow(-2), Color(0.3, 1.0, 0.4, 0.25) if ok else Color(1.0, 0.3, 0.3, 0.25))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			var c := cell_at(ev.position)
			if c != hover:
				hover = c
				queue_redraw()
				ui.on_hover(self, grille.entree_a(c.x, c.y))
		elif ev is InputEventMouseButton and ev.pressed:
			ui.on_grid_press(self, cell_at(ev.position), ev)
			accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			hover = Vector2i(-1, -1)
			queue_redraw()
			ui.on_hover(self, {})


class SlotView extends Control:
	const CELL := 52.0
	## Emplacement d'équipement (tete/torse/dos) ou de barre rapide (0..4)
	var ui
	var kind := "equip"     # "equip" ou "hot"
	var key = ""            # nom de l'emplacement ou index
	var title := ""

	func setup(p_ui, p_kind: String, p_key, p_title: String, size: Vector2) -> void:
		ui = p_ui
		kind = p_kind
		key = p_key
		title = p_title
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.1, 0.11, 0.1, 0.92))
		var hl: bool = ui.held != null and ui.slot_accepts(self, ui.held.e)
		draw_rect(r, Color(0.9, 0.8, 0.4) if hl else Color(0.35, 0.33, 0.25), false, 2.0 if hl else 1.0)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(6, 15), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.68, 0.6))
		var e: Dictionary = ui.slot_entry(self)
		if not e.is_empty():
			ui.draw_entry(self, Rect2(Vector2(4, 18), size - Vector2(8, 22)), e, kind == "hot")
			if kind == "hot" and int(e.n) <= 0:
				draw_rect(Rect2(Vector2(4, 18), size - Vector2(8, 22)), Color(0, 0, 0, 0.55))
		if kind == "hot" and Game.player and Game.player.hotbar_verrou[key]:
			# petit cadenas en haut à droite
			var c := Vector2(size.x - 11, 9)
			draw_arc(c + Vector2(0, -1), 3.0, PI, TAU, 8, Color(1, 0.85, 0.4), 1.5)
			draw_rect(Rect2(c + Vector2(-4.5, -1), Vector2(9, 7)), Color(1, 0.85, 0.4))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			ui.on_slot_press(self, ev)
			accept_event()
		elif ev is InputEventMouseMotion:
			ui.on_hover(self, ui.slot_entry(self))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			ui.on_hover(self, {})


class DragLayer extends Control:
	const CELL := 52.0
	var ui

	func _draw() -> void:
		if ui.held == null:
			return
		var e: Dictionary = ui.held.e
		var s := Vector2(Grille.taille(e)) * CELL
		var pos := get_local_mouse_position() - (Vector2(ui.held.grab) + Vector2(0.5, 0.5)) * CELL
		ui.draw_entry(self, Rect2(pos, s).grow(-2), e)


# ------------------------------------------------------------------ état
var panel: PanelContainer
var player_box: VBoxContainer
var right_box: VBoxContainer
var cont_box: VBoxContainer
var craft_box: VBoxContainer
var equip_slots: Array = []
var hot_slots: Array = []
var stats_label: Label
var tooltip: PanelContainer
var tooltip_label: Label
var menu: PopupMenu
var drag_layer: DragLayer
var rec_tree: Tree
var rec_items: Array = []          # [TreeItem, indice de recette]
var rec_desc: RichTextLabel
var fab_bar: ProgressBar
var fab_label: Label
var craft_btn5: Button
var craft_btn_max: Button
var stop_btn: Button
var craft_btn: Button
var demonter_btn: Button
var fav_btn: Button
var bench_label: Label
var tab_cont: Button
var tab_craft: Button
var storage: Node = null
var held = null           # {e, from (Grille | "equip:slot"), orig: [x,y,r], grab: Vector2i}
var menu_ctx := {}
var grid_views: Array = []
var refresh_t := 0.0
var show_craft := false
var fab_vu := 0


func _ready() -> void:
	layer = 6
	add_to_group("inventory_ui")
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.05, 0.95)
	sb.set_content_margin_all(16)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.4, 0.36, 0.22)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	panel.add_child(hb)

	# --- colonne équipement
	var c1 := _column(hb, "ÉQUIPEMENT")
	c1.custom_minimum_size.x = 260
	var eg := GridContainer.new()
	eg.columns = 2
	eg.add_theme_constant_override("h_separation", 8)
	eg.add_theme_constant_override("v_separation", 8)
	c1.add_child(eg)
	for s in [["tete", "Tête"], ["visage", "Visage"], ["torse", "Torse"], ["dos", "Sac à dos"]]:
		var sv := SlotView.new()
		sv.setup(self, "equip", s[0], s[1], Vector2(124, 124))
		eg.add_child(sv)
		equip_slots.append(sv)
	_label(c1, "BARRE RAPIDE", 16, Color(0.9, 0.8, 0.45))
	var hg := HBoxContainer.new()
	hg.add_theme_constant_override("separation", 4)
	c1.add_child(hg)
	for i in 5:
		var hv := SlotView.new()
		hv.setup(self, "hot", i, str(i + 1), Vector2(48, 60))
		hg.add_child(hv)
		hot_slots.append(hv)
	stats_label = _label(c1, "", 14, Color(0.85, 0.85, 0.8))
	var help := _label(c1, "Glisser-déposer pour ranger\nR : tourner l'objet tenu\nDouble-clic : utiliser / équiper\nCtrl + clic : transfert rapide\nClic droit : options\nLâcher hors de la fenêtre : jeter", 12, Color(0.6, 0.6, 0.55))
	help.autowrap_mode = TextServer.AUTOWRAP_OFF

	# --- colonne inventaire du joueur
	var c2 := _column(hb, "INVENTAIRE")
	var tri := HBoxContainer.new()
	tri.add_theme_constant_override("separation", 6)
	c2.add_child(tri)
	_button(tri, "Trier par type", func(): _trier("type"))
	_button(tri, "Trier par taille", func(): _trier("taille"))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(CELL * 8 + 24, 680)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c2.add_child(sc)
	player_box = VBoxContainer.new()
	player_box.add_theme_constant_override("separation", 10)
	sc.add_child(player_box)

	# --- colonne de droite : conteneur ou fabrication
	right_box = VBoxContainer.new()
	right_box.custom_minimum_size = Vector2(CELL * 8 + 24, 0)
	hb.add_child(right_box)
	var tabs := HBoxContainer.new()
	right_box.add_child(tabs)
	tab_cont = _button(tabs, "Conteneur", func(): _set_tab(false))
	tab_craft = _button(tabs, "Fabrication", func(): _set_tab(true))
	cont_box = VBoxContainer.new()
	right_box.add_child(cont_box)
	craft_box = VBoxContainer.new()
	craft_box.add_theme_constant_override("separation", 8)
	right_box.add_child(craft_box)
	bench_label = _label(craft_box, "", 14, Color.WHITE)
	rec_tree = Tree.new()
	rec_tree.custom_minimum_size = Vector2(CELL * 8, 380)
	rec_tree.hide_root = true
	rec_tree.add_theme_font_size_override("font_size", 15)
	rec_tree.add_theme_constant_override("icon_max_width", 26)
	rec_tree.item_selected.connect(_update_recipe)
	rec_tree.item_activated.connect(func(): _craft(1))
	craft_box.add_child(rec_tree)
	rec_desc = RichTextLabel.new()
	rec_desc.bbcode_enabled = true
	rec_desc.fit_content = true
	rec_desc.scroll_active = false
	rec_desc.custom_minimum_size = Vector2(CELL * 8, 150)
	rec_desc.add_theme_font_size_override("normal_font_size", 15)
	rec_desc.add_theme_font_size_override("bold_font_size", 16)
	craft_box.add_child(rec_desc)
	fab_bar = ProgressBar.new()
	fab_bar.custom_minimum_size = Vector2(CELL * 8, 22)
	fab_bar.max_value = 1.0
	fab_bar.show_percentage = false
	craft_box.add_child(fab_bar)
	fab_label = _label(fab_bar, "", 13, Color.WHITE)
	fab_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.15, 0.15, 0.13)
	fab_bar.add_theme_stylebox_override("background", fond)
	var plein := StyleBoxFlat.new()
	plein.bg_color = Color(0.35, 0.55, 0.25)
	fab_bar.add_theme_stylebox_override("fill", plein)
	fab_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fab_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bb := HBoxContainer.new()
	bb.add_theme_constant_override("separation", 6)
	craft_box.add_child(bb)
	craft_btn = _button(bb, "Fabriquer ×1", func(): _craft(1))
	craft_btn5 = _button(bb, "×5", func(): _craft(5))
	craft_btn_max = _button(bb, "Maximum", func(): _craft(-1))
	stop_btn = _button(bb, "Arrêter", func(): Game.player.arreter_fabrication("Fabrication arrêtée."))
	var bb2 := HBoxContainer.new()
	bb2.add_theme_constant_override("separation", 6)
	craft_box.add_child(bb2)
	fav_btn = _button(bb2, "Épingler en favori", func(): _basculer_favori())
	demonter_btn = _button(bb2, "Démonter", func(): _demonter_choisi())

	# --- infobulle, menu contextuel, objet tenu
	tooltip = PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.02, 0.02, 0.02, 0.95)
	tsb.border_color = Color(0.5, 0.45, 0.3)
	tsb.set_border_width_all(1)
	tsb.set_content_margin_all(8)
	tooltip.add_theme_stylebox_override("panel", tsb)
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label = Label.new()
	tooltip_label.add_theme_font_size_override("font_size", 14)
	tooltip_label.custom_minimum_size.x = 260
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tooltip.clip_contents = true
	tooltip.add_child(tooltip_label)
	tooltip.visible = false
	add_child(tooltip)
	menu = PopupMenu.new()
	menu.add_theme_font_size_override("font_size", 15)
	menu.id_pressed.connect(_on_menu)
	add_child(menu)
	drag_layer = DragLayer.new()
	drag_layer.ui = self
	drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(drag_layer)
	panel.visible = false


func _column(parent: Control, title: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_label(vb, title, 20, Color(0.9, 0.8, 0.45))
	parent.add_child(vb)
	return vb


func _label(parent: Control, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# ------------------------------------------------------------------ dessin d'un objet
func draw_entry(ci: CanvasItem, r: Rect2, e: Dictionary, small := false) -> void:
	var col: Color = Items.category_color(e.id)
	var bg := Color(0.36, 0.37, 0.34).lerp(col, 0.12)
	ci.draw_rect(r, bg.darkened(0.25))
	ci.draw_rect(r, col.darkened(0.3), false, 1.0)
	var tex: Texture2D = Items.icon(e.id)
	var rot: bool = e.get("r", false)
	if tex:
		var ts := tex.get_size()
		var box := r.grow(-4)
		var bs := Vector2(box.size.y, box.size.x) if rot else box.size
		var k := minf(bs.x / ts.x, bs.y / ts.y)
		var ds := ts * k
		var center := box.get_center()
		var modulate := icon_modulate(e.id)
		if rot:
			ci.draw_set_transform(center, PI / 2.0, Vector2.ONE)
			ci.draw_texture_rect(tex, Rect2(-ds / 2.0, ds), false, modulate)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			ci.draw_texture_rect(tex, Rect2(center - ds / 2.0, ds), false, modulate)
	else:
		var font := ThemeDB.fallback_font
		ci.draw_string(font, r.position + Vector2(4, 16), Items.nom(e.id), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 11, Color.WHITE)
	var font2 := ThemeDB.fallback_font
	var n := int(e.get("n", 1))
	if small and Game.player:
		n = Game.player.count(e.id)
	if n > 1 or (small and not Items.is_weapon(e.id)):
		var t := str(n)
		ci.draw_string_outline(font2, r.position + Vector2(r.size.x - 6 - 8 * t.length(), r.size.y - 4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color.BLACK)
		ci.draw_string(font2, r.position + Vector2(r.size.x - 6 - 8 * t.length(), r.size.y - 4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	var w := Items.info(e.id)
	# barre d'usure (armes et outils) : verte → rouge, croix rouge si cassé
	if not small and int(w.get("durab", 0)) > 0 and Game.player:
		var k: float = Game.player.etat_usure(e)
		var bar := Rect2(r.position + Vector2(3, r.size.y - 6), Vector2(r.size.x - 6, 3))
		ci.draw_rect(bar, Color(0, 0, 0, 0.6))
		ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), Color(0.9, 0.2, 0.15).lerp(Color(0.35, 0.85, 0.3), k))
		if k <= 0.0:
			ci.draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 8), Color(0.9, 0.15, 0.1, 0.8), 2.0)
	# pastille de péremption : orange = se gâte, brun = avarié
	if not small and float(w.get("frais", 0)) > 0.0 and Peremption.etat(e) > 0:
		ci.draw_circle(r.position + Vector2(9, 9), 5.0, Color(0.95, 0.6, 0.15) if Peremption.etat(e) == 1 else Color(0.45, 0.3, 0.1))
		ci.draw_arc(r.position + Vector2(9, 9), 5.0, 0.0, TAU, 12, Color.BLACK, 1.0)
	if not small and w.get("type", "") == "gun" and Game.player:
		var am := "%d/%d" % [int(Game.player.mags.get(e.id, 0)), int(Game.player.arme_stats(e.id).mag)]
		ci.draw_string_outline(font2, r.position + Vector2(4, 14), am, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
		ci.draw_string(font2, r.position + Vector2(4, 14), am, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.9, 0.6))


func icon_modulate(id: String) -> Color:
	var tex: Texture2D = Items.icon(id)
	if tex and String(tex.resource_path).ends_with(".svg"):
		return Items.category_color(id)
	return Color.WHITE


# ------------------------------------------------------------------ ouverture
func open(crate: Node) -> void:
	var p = Game.player
	if p == null or not p.alive:
		return
	storage = crate
	show_craft = crate == null
	panel.visible = true
	drag_layer.visible = true
	tooltip.visible = false
	panel.size = Vector2.ZERO
	panel.scale = Vector2.ONE
	Game.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.regrouper_piles()
	refresh()


func close() -> void:
	if held:
		_revert_held()
	panel.visible = false
	tooltip.visible = false
	held = null
	drag_layer.visible = false
	drag_layer.queue_redraw()
	Game.ui_open = false
	get_viewport().gui_release_focus()
	if storage and is_instance_valid(storage) and storage.has_method("on_closed"):
		storage.on_closed()
	storage = null
	if Game.player and Game.player.alive:
		Game.capturer_souris()


func _set_tab(craft: bool) -> void:
	show_craft = craft
	refresh()


func refresh() -> void:
	var p = Game.player
	if p == null:
		return
	# grilles du joueur
	for c in player_box.get_children():
		c.queue_free()
	grid_views.clear()
	for g in p.grilles():
		_add_grid(player_box, g)
	# colonne de droite
	for c in cont_box.get_children():
		c.queue_free()
	var has_cont := storage != null and is_instance_valid(storage) and storage.grille != null
	tab_cont.visible = has_cont
	tab_cont.disabled = not show_craft
	tab_craft.disabled = show_craft or not has_cont
	cont_box.visible = has_cont and not show_craft
	craft_box.visible = show_craft or not has_cont
	if has_cont:
		var sc := ScrollContainer.new()
		sc.custom_minimum_size = Vector2(CELL * 8 + 24, 680)
		cont_box.add_child(sc)
		var vb := VBoxContainer.new()
		sc.add_child(vb)
		_add_grid(vb, storage.grille, storage.label.to_upper())
		var bb := HBoxContainer.new()
		bb.add_theme_constant_override("separation", 6)
		cont_box.add_child(bb)
		_button(bb, "Tout prendre", _take_all)
		_button(bb, "Déposer les matériaux", _deposer_materiaux)
	_refresh_recipes()
	_update_side()


func _add_grid(parent: Control, g: Grille, title := "") -> void:
	var t := title if title != "" else g.nom.to_upper()
	_label(parent, "%s   (%d×%d)" % [t, g.w, g.h], 14, Color(0.8, 0.75, 0.55))
	var gv := GridView.new()
	gv.setup(self, g)
	parent.add_child(gv)
	grid_views.append(gv)


func _update_side() -> void:
	var p = Game.player
	for sv in equip_slots + hot_slots:
		sv.queue_redraw()
	stats_label.text = "Santé %d   Faim %d   Soif %d\nProtection : %d %%" % [int(p.health), int(p.hunger), int(p.thirst), int(p.armor_total() * 100)]


func _redraw_all() -> void:
	for gv in grid_views:
		if is_instance_valid(gv):
			gv.queue_redraw()
	_update_side()
	drag_layer.queue_redraw()


func _input(event: InputEvent) -> void:
	if panel.visible:
		if event.is_action_pressed("inventaire") or event.is_action_pressed("pause"):
			close()
			get_viewport().set_input_as_handled()
		elif held and event is InputEventKey and event.pressed and event.keycode == KEY_R:
			held.e.r = not held.e.r
			held.grab = Vector2i.ZERO
			_redraw_all()
			get_viewport().set_input_as_handled()
		elif held and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and (not event.pressed or held.get("lache", false)):
			# lâcher (ou nouveau clic si le relâchement n'a pas été reçu)
			_drop_held()
			get_viewport().set_input_as_handled()
		elif held and event is InputEventMouseButton and not event.pressed:
			held["lache"] = true
		elif held and event is InputEventMouseMotion:
			drag_layer.queue_redraw()
	elif event.is_action_pressed("inventaire") and not Game.ui_open and Game.player and Game.player.alive:
		open(null)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not panel.visible:
		return
	# l'objet tenu suit la souris ; une fois lâché, il ne doit plus être dessiné
	drag_layer.queue_redraw()
	var vs := get_viewport().get_visible_rect().size
	# sécurité : la fenêtre doit toujours tenir à l'écran
	if panel.size.x > vs.x or panel.size.y > vs.y:
		panel.size = Vector2.ZERO
		panel.reset_size()
	var k := minf(1.0, minf((vs.x - 16.0) / maxf(panel.size.x, 1.0), (vs.y - 16.0) / maxf(panel.size.y, 1.0)))
	panel.scale = Vector2(k, k)
	panel.position = ((vs - panel.size * k) / 2.0).floor()
	if tooltip.visible:
		# l'infobulle ne doit jamais grandir au point de cacher l'inventaire
		if tooltip.size.x > 340.0 or tooltip.size.y > 500.0:
			tooltip.size = Vector2.ZERO
			tooltip.reset_size()
		var mp := get_viewport().get_mouse_position()
		tooltip.position = (mp + Vector2(18, 18)).min(vs - tooltip.size - Vector2(4, 4))
	if craft_box.visible:
		_maj_barre_fabrication()
	# un objet fabriqué vient d'arriver dans le sac : redessiner les grilles
	if Game.player.fab_n != fab_vu and held == null:
		fab_vu = Game.player.fab_n
		refresh()
	refresh_t -= delta
	if refresh_t <= 0.0:
		refresh_t = 0.5
		_update_side()
		_refresh_recipe_marks()
	if storage and not is_instance_valid(storage):
		storage = null
		refresh()
	elif storage and Game.player.global_position.distance_to(storage.global_position) > 4.0:
		close()


# ------------------------------------------------------------------ infobulle
func on_hover(_src, e: Dictionary) -> void:
	if held or e.is_empty():
		tooltip.visible = false
		return
	tooltip_label.text = Items.nom(e.id) + ("  ×%d" % e.n if int(e.get("n", 1)) > 1 else "") + "\n" + _desc(e.id) + _texte_usure(e) + _texte_frais(e)
	tooltip.visible = true
	tooltip.size = Vector2.ZERO
	tooltip.reset_size()
	tooltip.call_deferred("reset_size")


func _texte_usure(e: Dictionary) -> String:
	var m := int(Items.info(e.id).get("durab", 0))
	if m <= 0 or Game.player == null:
		return ""
	var k: float = Game.player.etat_usure(e)
	if k <= 0.0:
		return "\nÉtat : CASSÉ — clic droit > Réparer (kit de réparation%s)" % (" + clé à molette" if Items.info(e.id).get("type", "") == "gun" else "")
	return "\nÉtat : %d %% (%d / %d)" % [roundi(k * 100.0), roundi(k * m), m]


func _texte_frais(e: Dictionary) -> String:
	var t := Peremption.texte(e)
	return "" if t == "" else "\n" + t


func _desc(id: String) -> String:
	var it := Items.info(id)
	var d := ""
	match it.get("type", ""):
		"food", "drink":
			d = "+%d faim, +%d soif." % [it.get("food", 0), it.get("water", 0)]
		"heal":
			d = "Soin : +%d santé." % it.heal
		"melee":
			d = "Arme blanche — dégâts %d, portée %.1f m. Silencieuse." % [it.damage, it.range]
		"gun":
			d = "Arme à feu — dégâts %d%s, chargeur %d.\nMunitions : %s. Bruyante !" % [it.damage, " ×%d plombs" % it.pellets if it.pellets > 1 else "", it.mag, Items.nom(it.ammo)]
		"armor":
			var gs: Vector2i = Items.grid(id)
			d = "Équipement (%s) — protection %d %%." % [it.slot, int(it.armor * 100)]
			if gs.x > 0:
				d += "\nRangement : %d×%d cases." % [gs.x, gs.y]
		"placeable":
			d = "Objet de base à poser (clic droit → Placer)."
		"outil":
			d = "Construction de base : touche B (garde-le dans ton inventaire)."
		"accessoire":
			var armes := []
			for a in Accessoires.table():
				for emp in Accessoires.table()[a]:
					if id in Accessoires.table()[a][emp]:
						armes.append(Items.nom(a))
			d = "%s\nCompatible : %s.\nÀ poser dans la vue d'inspection (touche T)." % [it.get("desc", ""), ", ".join(armes)]
		"ammo":
			d = "Munitions."
		_:
			d = "Matériau de fabrication."
	var s: Vector2i = Items.size(id)
	d += "\nTaille : %d×%d" % [s.x, s.y]
	if Items.stack(id) > 1:
		d += "   ·   pile de %d max" % Items.stack(id)
	var pv := Items.prix_vente(id) if Items.prix(id) > 0 else 0
	if pv > 0:
		d += "\nRevente chez un marchand : %d €%s" % [pv, " pièce" if Items.stack(id) > 1 else ""]
	return d + _comparaison(id)


## Comparaison avec l'arme en main (armes) ou la pièce portée au même endroit (vêtements, sacs).
func _comparaison(id: String) -> String:
	var p = Game.player
	if p == null:
		return ""
	var it := Items.info(id)
	var t: String = it.get("type", "")
	var lignes: Array = []
	var ligne := func(nom: String, a: float, b: float, fmt: String, plus_bas_mieux: bool) -> void:
		if is_equal_approx(a, b):
			lignes.append("%s : %s (=)" % [nom, fmt % b])
		else:
			var mieux := (b < a) if plus_bas_mieux else (b > a)
			lignes.append("%s : %s → %s  %s" % [nom, fmt % a, fmt % b, "▲ mieux" if mieux else "▼ moins bien"])
	if t in ["gun", "melee", "arc"]:
		var cur: String = p.current_weapon()
		if cur == id:
			return "\n— Arme en main —"
		var a: Dictionary = p.arme_stats(cur)
		var b: Dictionary = p.arme_stats(id)
		var ta: String = a.get("type", "")
		ligne.call("Dégâts", float(a.get("damage", 0)) * int(a.get("pellets", 1)), float(b.get("damage", 0)) * int(b.get("pellets", 1)), "%.0f", false)
		if ta == t and t != "arc":
			ligne.call("Coups / s" if t == "melee" else "Cadence (tirs / s)", 1.0 / maxf(0.05, float(a.get("rate", 1.0))), 1.0 / maxf(0.05, float(b.get("rate", 1.0))), "%.1f", false)
		if ta == "gun" and t == "gun":
			ligne.call("Dispersion", float(a.spread), float(b.spread), "%.2f°", true)
			ligne.call("Recul", float(a.get("recoil", 0.0)) * 100.0, float(b.get("recoil", 0.0)) * 100.0, "%.1f", true)
			ligne.call("Chargeur", float(a.mag), float(b.mag), "%.0f", false)
			ligne.call("Rechargement", float(a.reload), float(b.reload), "%.1f s", true)
		ligne.call("Portée", float(a.get("range", 0)), float(b.get("range", 0)), "%.1f m", false)
		return "\n\nFace à %s (en main) :\n%s" % [Items.nom(cur), "\n".join(lignes)]
	if t == "armor":
		var slot: String = it.get("slot", "")
		var e: Dictionary = p.equipped.get(slot, {})
		if not e.is_empty() and e.id == id:
			return ""
		var ia := Items.info(e.id) if not e.is_empty() else {}
		ligne.call("Protection", float(ia.get("armor", 0.0)) * 100.0, float(it.get("armor", 0.0)) * 100.0, "%.0f %%", false)
		var ga := Items.grid(e.id) if not e.is_empty() else Vector2i.ZERO
		var gb := Items.grid(id)
		if ga.x > 0 or gb.x > 0:
			ligne.call("Rangement (cases)", float(ga.x * ga.y), float(gb.x * gb.y), "%.0f", false)
		return "\n\nFace à %s :\n%s" % [Items.nom(e.id) if not e.is_empty() else "rien de porté", "\n".join(lignes)]
	return ""


# ------------------------------------------------------------------ clics
func on_grid_press(gv: GridView, cell: Vector2i, ev: InputEventMouseButton) -> void:
	if held:
		return
	var e: Dictionary = gv.grille.entree_a(cell.x, cell.y)
	if e.is_empty():
		return
	if ev.button_index == MOUSE_BUTTON_RIGHT:
		_open_menu(e, gv.grille)
		return
	if ev.button_index != MOUSE_BUTTON_LEFT:
		return
	if ev.double_click:
		_use(e, gv.grille)
		return
	if ev.ctrl_pressed or ev.shift_pressed:
		_quick_transfer(e, gv.grille)
		return
	held = {"e": e, "from": gv.grille, "orig": [e.x, e.y, e.r], "grab": cell - Vector2i(e.x, e.y)}
	gv.grille.retirer_entree(e)
	tooltip.visible = false
	_redraw_all()


func on_slot_press(sv: SlotView, ev: InputEventMouseButton) -> void:
	var p = Game.player
	if held:
		return
	if sv.kind == "hot":
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			menu_ctx = {"hot": sv.key}
			menu.clear()
			menu.add_item("Déverrouiller la case" if p.hotbar_verrou[sv.key] else "Verrouiller la case (l'objet garde sa place)", 10)
			menu.set_item_disabled(0, p.hotbar[sv.key] == "" and not p.hotbar_verrou[sv.key])
			menu.add_item("Vider la case", 11)
			menu.position = Vector2i(get_viewport().get_mouse_position())
			menu.reset_size()
			menu.popup()
		return
	var e: Dictionary = p.equipped[sv.key]
	if e.is_empty():
		return
	if ev.button_index == MOUSE_BUTTON_RIGHT or ev.double_click:
		p.unequip(sv.key)
		refresh()
		return
	if ev.button_index == MOUSE_BUTTON_LEFT:
		p.equipped[sv.key] = {}
		held = {"e": e, "from": "equip:" + String(sv.key), "orig": [0, 0, false], "grab": Vector2i.ZERO}
		refresh()


func slot_entry(sv: SlotView) -> Dictionary:
	var p = Game.player
	if p == null:
		return {}
	if sv.kind == "equip":
		return p.equipped[sv.key]
	var id: String = p.hotbar[sv.key]
	if id == "":
		return {}
	return {"id": id, "n": p.count(id), "r": false}


func slot_accepts(sv: SlotView, e: Dictionary) -> bool:
	if sv.kind == "hot":
		return true
	return Items.info(e.id).get("slot", "") == sv.key


func can_drop_in(g: Grille, tl: Vector2i, e: Dictionary) -> bool:
	if e.get("contenu") == g:
		return false
	var target: Dictionary = g.entree_a(tl.x + Grille.taille(e).x / 2, tl.y + Grille.taille(e).y / 2)
	if not target.is_empty() and target.id == e.id and Items.stack(e.id) > 1 and int(target.n) < Items.stack(e.id):
		return true
	return g.peut_placer(e.id, tl.x, tl.y, e.r)


# ------------------------------------------------------------------ dépôt
func _control_under_mouse(list: Array) -> Control:
	var mp := get_viewport().get_mouse_position()
	for c in list:
		if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(mp):
			return c
	return null


func _drop_held() -> void:
	var p = Game.player
	var e: Dictionary = held.e
	var mp := get_viewport().get_mouse_position()
	# 1) grille
	var gv := _control_under_mouse(grid_views) as GridView
	if gv:
		var cell := gv.cell_at(gv.get_local_mouse_position())
		var tl: Vector2i = cell - held.grab
		if e.get("contenu") != gv.grille:
			var s := Grille.taille(e)
			var target: Dictionary = gv.grille.entree_a(tl.x + s.x / 2, tl.y + s.y / 2)
			if not target.is_empty() and target.id == e.id and Items.stack(e.id) > 1:
				var room := Items.stack(e.id) - int(target.n)
				var k := mini(room, int(e.n))
				Peremption.fusionner(target, e, k)
				target.n += k
				e.n -= k
				if e.n <= 0:
					_finish_drop()
					return
			elif gv.grille.placer(e, tl.x, tl.y, e.r):
				_finish_drop()
				return
		_revert_held()
		return
	# 2) emplacement d'équipement / barre rapide
	var sv := _control_under_mouse(equip_slots + hot_slots) as SlotView
	if sv:
		if sv.kind == "hot":
			_revert_held()
			if p.count(e.id) > 0:
				p.assign_hotbar(sv.key, e.id)
			else:
				Game.msg("Range d'abord l'objet dans ton inventaire.")
			_redraw_all()
			return
		if slot_accepts(sv, e):
			var from_grid = held.from if held.from is Grille else null
			held = null
			if from_grid == null:
				p.equipped[sv.key] = e
			else:
				p.equip_entry(e, null)
			refresh()
			return
		_revert_held()
		return
	# 3) hors de la fenêtre : jeter au sol
	if not panel.get_global_rect().has_point(mp):
		held = null
		p.drop_entry(e)
		Game.msg("Jeté : %s" % Items.nom(e.id))
		refresh()
		return
	_revert_held()


func _finish_drop() -> void:
	held = null
	Game.player._check_hotbar()
	refresh()


func _revert_held() -> void:
	if held == null:
		return
	var p = Game.player
	var e: Dictionary = held.e
	var from = held.from
	var o: Array = held.orig
	held = null
	if from is Grille:
		if not from.placer(e, o[0], o[1], o[2]):
			if not from.ajouter_entree(e):
				p.drop_entry(e)
	elif String(from).begins_with("equip:"):
		var s := String(from).substr(6)
		if p.equipped[s].is_empty():
			p.equipped[s] = e
		else:
			p._stow_entry(e)
	refresh()


# ------------------------------------------------------------------ actions
func _use(e: Dictionary, g: Grille) -> void:
	var p = Game.player
	var t: String = Items.info(e.id).get("type", "")
	if Items.info(e.id).get("desinfecte", false) and _is_player_grid(g) and p.morsure_t > 0.0:
		t = "heal"   # alcool : désinfecter la morsure (double-clic), sinon il se range comme un matériau
	match t:
		"food", "drink", "heal":
			p.consume_entry(e, g)
		"armor":
			p.equip_entry(e, g)
		"melee", "gun", "arc":
			if _is_player_grid(g):
				p.use_item(e.id)
			else:
				_quick_transfer(e, g)
		"placeable":
			if _is_player_grid(g):
				close()
				p.use_item(e.id)
				return
			_quick_transfer(e, g)
		_:
			_quick_transfer(e, g)
	refresh()


func _is_player_grid(g: Grille) -> bool:
	return Game.player.grilles().has(g)


func _quick_transfer(e: Dictionary, g: Grille) -> void:
	var p = Game.player
	var targets: Array = []
	if _is_player_grid(g):
		if storage and is_instance_valid(storage) and storage.grille:
			targets = [storage.grille]
	else:
		targets = p.grilles()
	if targets.is_empty():
		return
	var o := [e.x, e.y, e.r]
	var n0 := int(e.n)
	g.retirer_entree(e)
	var done := false
	for t in targets:
		if t == e.get("contenu"):
			continue
		if t.ajouter_entree(e):
			done = true
			if not _is_player_grid(g):
				Game.recu(e.id, n0)   # fouille : fil des objets
			break
	if not done and int(e.n) > 0:
		if not g.placer(e, o[0], o[1], o[2]) and not g.ajouter_entree(e):
			p.drop_entry(e)
		Game.msg("Pas assez de place.")
	p._check_hotbar()
	refresh()


func _take_all() -> void:
	if storage == null or not is_instance_valid(storage) or storage.grille == null:
		return
	for e in storage.grille.entrees.duplicate():
		_quick_transfer(e, storage.grille)
	refresh()


## Vide d'un coup les matériaux de fabrication (type « material ») du joueur dans le conteneur ouvert.
func _deposer_materiaux() -> void:
	if storage == null or not is_instance_valid(storage) or storage.grille == null:
		return
	var n := 0
	var reste := 0
	for g in Game.player.grilles():
		for e in g.entrees.duplicate():
			if Items.info(e.id).get("type", "") != "material":
				continue
			var avant := int(e.n)
			_quick_transfer(e, g)
			if g.entrees.has(e) and int(e.n) > 0:
				reste += 1
			n += avant - (int(e.n) if g.entrees.has(e) else 0)
	Game.msg("%d matériau(x) déposé(s)%s." % [n, " — plus de place pour le reste" if reste > 0 else ""])
	refresh()


func _trier(mode: String) -> void:
	if held:
		return
	if not Game.player.trier_inventaire(mode):
		Game.msg("Tri impossible : tout ne rentrerait plus.")
	refresh()


func _open_menu(e: Dictionary, g: Grille) -> void:
	menu_ctx = {"e": e, "g": g}
	menu.clear()
	var t: String = Items.info(e.id).get("type", "")
	var mine := _is_player_grid(g)
	match t:
		"food":
			menu.add_item("Manger", 0)
		"drink":
			menu.add_item("Boire", 0)
		"heal":
			menu.add_item("Se soigner", 0)
		"armor":
			menu.add_item("Équiper", 0)
		"melee", "gun", "arc":
			if mine:
				menu.add_item("Prendre en main", 0)
			if t == "gun" and mine and Accessoires.table().has(e.id):
				menu.add_item("Inspecter / accessoires", 5)
		"accessoire":
			if mine:
				menu.add_item("Poser sur une arme…", 5)
		"placeable":
			if mine:
				menu.add_item("Placer", 0)
	if storage and is_instance_valid(storage) and storage.grille:
		menu.add_item("Déposer dans le conteneur" if mine else "Prendre", 1)
	if mine and int(Items.info(e.id).get("durab", 0)) > 0 and float(e.get("us", 0.0)) > 0.0:
		menu.add_item("Réparer (kit de réparation%s)" % (" + clé à molette" if t == "gun" else ""), 7)
	if mine and Items.info(e.id).get("desinfecte", false):
		menu.add_item("Désinfecter une plaie", 0)
	if mine and not Items.recette_demontage(e.id).is_empty():
		menu.add_item("Démonter (%s)" % Items.texte_demontage(Items.recette_demontage(e.id)), 6)
	if int(e.n) > 1:
		menu.add_item("Diviser la pile", 2)
	if mine:
		menu.add_item("Mettre dans la barre rapide", 4)
	menu.add_item("Jeter au sol", 3)
	menu.position = Vector2i(get_viewport().get_mouse_position())
	menu.reset_size()
	menu.popup()


func _on_menu(id: int) -> void:
	var p = Game.player
	if menu_ctx.has("hot"):
		var i: int = menu_ctx.hot
		if id == 10:
			p.basculer_verrou(i)
		elif id == 11:
			p.hotbar_verrou[i] = false
			p.assign_hotbar(i, "")
		_redraw_all()
		return
	var e: Dictionary = menu_ctx.get("e", {})
	var g: Grille = menu_ctx.get("g")
	if e.is_empty() or g == null:
		return
	match id:
		0:
			_use(e, g)
		1:
			_quick_transfer(e, g)
		2:
			var k := int(e.n) / 2
			var pos := g.trouver_place(e.id)
			if pos.is_empty():
				Game.msg("Pas de place pour diviser la pile.")
			else:
				e.n -= k
				g.entrees.append({"id": e.id, "n": k, "x": pos[0], "y": pos[1], "r": pos[2], "contenu": null, "p": e.get("p", 0.0)})
		3:
			g.retirer_entree(e)
			p.drop_entry(e)
			Game.msg("Jeté : %s" % Items.nom(e.id))
		4:
			var i: int = p.hotbar.find("")
			p.assign_hotbar(i if i >= 0 else 4, e.id)
		5:
			var insp := get_tree().get_first_node_in_group("inspection_ui")
			if insp:
				var cible: String = e.id
				if Items.info(e.id).get("type", "") == "accessoire":
					cible = ""
					for a in Accessoires.table():
						for emp in Accessoires.table()[a]:
							if e.id in Accessoires.table()[a][emp] and p.count(a) > 0 and cible == "":
								cible = a
					if cible == "":
						Game.msg("Aucune arme compatible dans ton inventaire.")
						return
				close()
				insp.ouvrir(cible)
			return
		6:
			p.demonter(e.id, e, g)
		7:
			p.reparer(e)
	refresh()


# ------------------------------------------------------------------ fabrication
## Arbre des recettes par catégorie (reconstruit à l'ouverture ; les couleurs suivent toutes les 0,5 s).
func _refresh_recipes() -> void:
	var garde := _recette_choisie()
	rec_tree.clear()
	rec_items.clear()
	var racine := rec_tree.create_item()
	# recettes épinglées en haut, avec ce qu'il manque
	var favs: Array = Game.player.recettes_fav if Game.player else []
	if not favs.is_empty():
		var cf := rec_tree.create_item(racine)
		cf.set_text(0, "FAVORIS")
		cf.set_selectable(0, false)
		cf.set_custom_color(0, Color(1.0, 0.85, 0.35))
		for i in Items.RECIPES.size():
			var r: Dictionary = Items.RECIPES[i]
			if not Items.cle_recette(r) in favs:
				continue
			var it := rec_tree.create_item(cf)
			it.set_icon(0, _icone_carree(r.out))
			it.set_icon_max_width(0, 26)
			it.set_icon_modulate(0, icon_modulate(r.out))
			it.set_metadata(0, i)
			rec_items.append([it, i, true])
			if i == garde and rec_tree.get_selected() == null:
				it.select(0)
	for c in Items.CATEGORIES_FAB:
		var cat: TreeItem = null
		for i in Items.RECIPES.size():
			var r: Dictionary = Items.RECIPES[i]
			if r.cat != c[0]:
				continue
			if cat == null:
				cat = rec_tree.create_item(racine)
				cat.set_text(0, c[1].to_upper())
				cat.set_selectable(0, false)
				cat.set_custom_color(0, Color(0.9, 0.8, 0.45))
			var it := rec_tree.create_item(cat)
			it.set_text(0, "%s%s" % [Items.nom(r.out), (" ×%d" % r.qty) if r.qty > 1 else ""])
			it.set_icon(0, _icone_carree(r.out))
			it.set_icon_max_width(0, 26)
			it.set_icon_modulate(0, icon_modulate(r.out))
			it.set_metadata(0, i)
			rec_items.append([it, i, false])
			if i == garde and rec_tree.get_selected() == null:
				it.select(0)
	_refresh_recipe_marks()
	_update_recipe()


func _recette_choisie() -> int:
	var it := rec_tree.get_selected() if rec_tree else null
	return int(it.get_metadata(0)) if it and it.get_metadata(0) != null else -1


func _refresh_recipe_marks() -> void:
	var p = Game.player
	if p == null:
		return
	var proches: PackedStringArray = []
	for st in ["etabli", "feu", "couture"]:
		if p.near_station(st):
			proches.append(Items.STATIONS[st])
	var nc: int = p.caisses_proches().size()
	bench_label.text = "Stations à proximité : %s\nNiveau de fabrication : %d%s" %[", ".join(proches) if not proches.is_empty() else "aucune", p.niveau_fabrication(),
			("   ·   %d caisse%s de la base utilisée%s" % [nc, "s" if nc > 1 else "", "s" if nc > 1 else ""]) if nc > 0 else ""]
	bench_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5) if not proches.is_empty() else Color(1.0, 0.75, 0.5))
	# vert : fabricable ; blanc cassé : il manque des ingrédients ; gris : station ou niveau manquant
	for ri in rec_items:
		var r: Dictionary = Items.RECIPES[ri[1]]
		var col := Color(0.55, 1.0, 0.55)
		if p.niveau_fabrication() < int(r.niv) or not p.near_station(r.station):
			col = Color(0.5, 0.5, 0.5)
		elif not p.a_ingredients(r):
			col = Color(0.85, 0.8, 0.72)
		ri[0].set_custom_color(0, col)
		if ri[2]:
			var manque := _manque(r)
			ri[0].set_text(0, "%s%s%s" % [Items.nom(r.out), (" ×%d" % r.qty) if r.qty > 1 else "", ("  — manque : " + manque) if manque != "" else ""])
	_update_recipe()


## Ce qui manque pour fabriquer la recette une fois (ingrédients, station, niveau), "" si rien.
func _manque(r: Dictionary) -> String:
	var p = Game.player
	var l: PackedStringArray = []
	for id in r.needs:
		var k: int = int(r.needs[id]) - p.compte_fab(id)
		if k > 0:
			l.append("%d× %s" % [k, Items.nom(id)])
	if not p.near_station(r.station):
		l.append(Items.STATIONS[r.station])
	if p.niveau_fabrication() < int(r.niv):
		l.append("niveau %d" % r.niv)
	return ", ".join(l)


func _basculer_favori() -> void:
	var i := _recette_choisie()
	if i < 0:
		return
	var cle := Items.cle_recette(Items.RECIPES[i])
	var favs: Array = Game.player.recettes_fav
	if cle in favs:
		favs.erase(cle)
	else:
		favs.append(cle)
	_refresh_recipes()


func _update_recipe() -> void:
	var p = Game.player
	var i := _recette_choisie()
	if i < 0 or p == null:
		rec_desc.text = "Sélectionne une recette."
		for b in [craft_btn, craft_btn5, craft_btn_max, demonter_btn, fav_btn]:
			b.disabled = true
		return
	var r: Dictionary = Items.RECIPES[i]
	var vert := "[color=#7cf07c]"
	var rouge := "[color=#ff6a5a]"
	var t := "[b]%s%s[/b]\n" % [Items.nom(r.out), (" ×%d" % r.qty) if r.qty > 1 else ""]
	for id in r.needs:
		var ok: bool = p.compte_fab(id) >= int(r.needs[id])
		var nc: int = p.compte_caisses(id)
		t += "%s%s %d× %s (tu as %d%s)[/color]\n" % [vert if ok else rouge, "✔" if ok else "✘", r.needs[id], Items.nom(id), p.count(id), (" + %d dans les caisses" % nc) if nc > 0 else ""]
	if r.station != "":
		t += "%sStation : %s[/color]\n" % [vert if p.near_station(r.station) else rouge, Items.STATIONS[r.station]]
	if int(r.niv) > 0:
		t += "%sFabrication niveau %d requis[/color]\n" % [vert if p.niveau_fabrication() >= int(r.niv) else rouge, r.niv]
	var manque := _manque(r)
	if manque != "":
		t += "%sIl manque : %s[/color]\n" % [rouge, manque]
	t += "[color=#bbbbaa]Durée : %.1f s par objet[/color]" % p.duree_fabrication(r)
	fav_btn.text = "Retirer des favoris" if Items.cle_recette(r) in p.recettes_fav else "Épingler en favori"
	fav_btn.disabled = false
	var rd := Items.recette_demontage(r.out)
	if not rd.is_empty():
		t += "\n[color=#bbbbaa]Démontage%s : %s%s[/color]" % [(" (lot de %d)" % rd.qty) if rd.qty > 1 else "", Items.texte_demontage(rd), (" — " + Items.STATIONS[rd.station]) if rd.station != "" else ""]
	rec_desc.text = t
	demonter_btn.disabled = rd.is_empty() or p.count(r.out) < int(rd.get("qty", 1)) or p.fab_n > 0
	demonter_btn.text = "Démonter %s (tu en as %d)" % [Items.nom(r.out), p.count(r.out)] if not rd.is_empty() else "Ne se démonte pas"
	var occupe: bool = p.fab_n > 0
	var n: int = p.max_craft(r) if p.can_craft(r) else 0
	craft_btn.disabled = occupe or n < 1
	craft_btn5.disabled = occupe or n < 5
	craft_btn_max.disabled = occupe or n < 2
	craft_btn_max.text = "Maximum (%d)" % n if n >= 2 else "Maximum"


func _maj_barre_fabrication() -> void:
	var p = Game.player
	var k: float = p.progression_fabrication()
	stop_btn.disabled = k < 0.0
	if k < 0.0:
		fab_bar.value = 0.0
		fab_label.text = ""
		return
	fab_bar.value = k
	fab_label.text = "%s : %d / %d" % [Items.nom(p.fab_r.out), p.fab_total - p.fab_n + 1, p.fab_total]


## Démonte un lot de l'objet que fabrique la recette choisie.
func _demonter_choisi() -> void:
	var i := _recette_choisie()
	if i >= 0 and Game.player.demonter(Items.RECIPES[i].out):
		refresh()


## n = -1 : autant que les ingrédients le permettent.
func _craft(n: int) -> void:
	var i := _recette_choisie()
	if i < 0:
		return
	var r: Dictionary = Items.RECIPES[i]
	if n < 0:
		n = Game.player.max_craft(r)
	if Game.player.lancer_fabrication(r, n):
		_update_recipe()


# ------------------------------------------------------------------ compatibilité
## Utilisé par les tests / anciens appels.
func _assign_slot(i: int, id: String) -> void:
	Game.player.assign_hotbar(i, id)
	_redraw_all()


## Icône ramenée dans un carré de 28 px (les objets longs, comme la batte, restent petits dans l'arbre).
var _icones_carrees := {}


func _icone_carree(id: String) -> Texture2D:
	if _icones_carrees.has(id):
		return _icones_carrees[id]
	var tex := Items.icon(id)
	var out: Texture2D = tex
	if tex:
		var img := tex.get_image()
		if img:
			img = img.duplicate()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			var k := 28.0 / maxf(img.get_width(), img.get_height())
			img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_BILINEAR)
			var carre := Image.create(28, 28, false, Image.FORMAT_RGBA8)
			carre.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), (Vector2i(28, 28) - img.get_size()) / 2)
			out = ImageTexture.create_from_image(carre)
	_icones_carrees[id] = out
	return out
