extends CanvasLayer
## Inventaire en grille (style SurrounDead) : poches, gilet et sac à dos,
## équipement, barre rapide, conteneurs (meubles, caisses, corps, sol) et fabrication.
##
## Souris :
##   glisser-déposer un objet entre les grilles, vers l'équipement ou la barre rapide
##   R pendant le glissement : tourner l'objet
##   double-clic : utiliser / équiper        Ctrl + clic : transfert rapide
##   clic droit : menu (utiliser, équiper, diviser, jeter…)
##   déposer hors de la fenêtre : jeter au sol

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
var rec_list: ItemList
var rec_desc: Label
var craft_btn: Button
var bench_label: Label
var tab_cont: Button
var tab_craft: Button
var storage: Node = null
var held = null           # {e, from (Grille | "equip:slot"), orig: [x,y,r], grab: Vector2i}
var menu_ctx := {}
var grid_views: Array = []
var refresh_t := 0.0
var show_craft := false


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
	for s in [["tete", "Tête"], ["torse", "Torse"], ["dos", "Sac à dos"]]:
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
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(CELL * 7 + 24, 720)
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
	bench_label = _label(craft_box, "", 15, Color.WHITE)
	rec_list = ItemList.new()
	rec_list.custom_minimum_size = Vector2(CELL * 8, 420)
	rec_list.add_theme_font_size_override("font_size", 15)
	rec_list.fixed_icon_size = Vector2i(28, 28)
	rec_list.item_selected.connect(func(_i): _update_recipe())
	rec_list.item_activated.connect(func(_i): _craft())
	craft_box.add_child(rec_list)
	rec_desc = _label(craft_box, "", 15, Color.WHITE)
	rec_desc.custom_minimum_size = Vector2(CELL * 8, 120)
	rec_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rec_desc.clip_text = false
	craft_btn = _button(craft_box, "Fabriquer", _craft)

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
	tooltip.visible = false
	panel.size = Vector2.ZERO
	panel.scale = Vector2.ONE
	Game.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()


func close() -> void:
	if held:
		_revert_held()
	panel.visible = false
	tooltip.visible = false
	Game.ui_open = false
	get_viewport().gui_release_focus()
	if storage and is_instance_valid(storage) and storage.has_method("on_closed"):
		storage.on_closed()
	storage = null
	if Game.player and Game.player.alive:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
		_button(cont_box, "Tout prendre", _take_all)
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
		elif held and event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_drop_held()
			get_viewport().set_input_as_handled()
		elif held and event is InputEventMouseMotion:
			drag_layer.queue_redraw()
	elif event.is_action_pressed("inventaire") and not Game.ui_open and Game.player and Game.player.alive:
		open(null)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not panel.visible:
		return
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
	tooltip_label.text = Items.nom(e.id) + ("  ×%d" % e.n if int(e.get("n", 1)) > 1 else "") + "\n" + _desc(e.id)
	tooltip.visible = true
	tooltip.size = Vector2.ZERO
	tooltip.reset_size()
	tooltip.call_deferred("reset_size")


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
		"accessoire":
			var armes := []
			for a in Accessoires.COMPAT:
				for emp in Accessoires.COMPAT[a]:
					if id in Accessoires.COMPAT[a][emp]:
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
	return d


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
			p.assign_hotbar(sv.key, "")
			_redraw_all()
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
	match t:
		"food", "drink", "heal":
			p.consume_entry(e, g)
		"armor":
			p.equip_entry(e, g)
		"melee", "gun":
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
	g.retirer_entree(e)
	var done := false
	for t in targets:
		if t == e.get("contenu"):
			continue
		if t.ajouter_entree(e):
			done = true
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
		"melee", "gun":
			if mine:
				menu.add_item("Prendre en main", 0)
			if t == "gun" and mine and Accessoires.COMPAT.has(e.id):
				menu.add_item("Inspecter / accessoires", 5)
		"accessoire":
			if mine:
				menu.add_item("Poser sur une arme…", 5)
		"placeable":
			if mine:
				menu.add_item("Placer", 0)
	if storage and is_instance_valid(storage) and storage.grille:
		menu.add_item("Déposer dans le conteneur" if mine else "Prendre", 1)
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
				g.entrees.append({"id": e.id, "n": k, "x": pos[0], "y": pos[1], "r": pos[2], "contenu": null})
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
					for a in Accessoires.COMPAT:
						for emp in Accessoires.COMPAT[a]:
							if e.id in Accessoires.COMPAT[a][emp] and p.count(a) > 0 and cible == "":
								cible = a
					if cible == "":
						Game.msg("Aucune arme compatible dans ton inventaire.")
						return
				close()
				insp.ouvrir(cible)
			return
	refresh()


# ------------------------------------------------------------------ fabrication
func _refresh_recipes() -> void:
	var keep := rec_list.get_selected_items()
	rec_list.clear()
	for r in Items.RECIPES:
		var label := "%s%s" % [Items.nom(r.out), (" ×%d" % r.qty) if r.qty > 1 else ""]
		if r.bench:
			label += "   [établi]"
		var idx := rec_list.add_item(label, Items.icon(r.out))
		rec_list.set_item_icon_modulate(idx, icon_modulate(r.out))
	_refresh_recipe_marks()
	if keep.size() > 0 and keep[0] < rec_list.item_count:
		rec_list.select(keep[0])
	_update_recipe()


func _refresh_recipe_marks() -> void:
	var p = Game.player
	if p == null:
		return
	var near: bool = p.near_bench()
	bench_label.text = "Établi à proximité : %s" % ("OUI" if near else "non (recettes [établi] bloquées)")
	bench_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5) if near else Color(1.0, 0.7, 0.5))
	for i in Items.RECIPES.size():
		if i < rec_list.item_count:
			var ok: bool = p.can_craft(Items.RECIPES[i])
			rec_list.set_item_custom_fg_color(i, Color(0.6, 1.0, 0.6) if ok else Color(0.6, 0.6, 0.6))


func _update_recipe() -> void:
	var sel := rec_list.get_selected_items()
	if sel.is_empty():
		rec_desc.text = "Sélectionne une recette."
		craft_btn.disabled = true
		return
	var p = Game.player
	var r: Dictionary = Items.RECIPES[sel[0]]
	var lines: PackedStringArray = []
	for id in r.needs:
		lines.append("%s %d× %s (tu as %d)" % ["✔" if p.count(id) >= r.needs[id] else "✘", r.needs[id], Items.nom(id), p.count(id)])
	if r.bench:
		lines.append(("✔" if p.near_bench() else "✘") + " Nécessite un établi")
	rec_desc.text = "\n".join(lines)
	craft_btn.disabled = not p.can_craft(r)


func _craft() -> void:
	var sel := rec_list.get_selected_items()
	if sel.is_empty():
		return
	Game.player.craft(Items.RECIPES[sel[0]])
	refresh()


# ------------------------------------------------------------------ compatibilité
## Utilisé par les tests / anciens appels.
func _assign_slot(i: int, id: String) -> void:
	Game.player.assign_hotbar(i, id)
	_redraw_all()
