extends CanvasLayer
## Inventaire, équipement, fabrication, barre rapide et caisse de stockage.

## Liste d'inventaire dont on peut glisser les objets vers la barre rapide.
class DragList extends ItemList:
	var ids_ref: Array = []

	func _get_drag_data(at_position: Vector2) -> Variant:
		var i := get_item_at_position(at_position, true)
		if i < 0 or i >= ids_ref.size():
			return null
		var l := Label.new()
		l.text = get_item_text(i)
		l.add_theme_font_size_override("font_size", 16)
		set_drag_preview(l)
		return {"item_id": ids_ref[i]}


## Emplacement de la barre rapide : accepte un objet glissé, clic droit = vider.
class HotSlot extends Button:
	var index := 0
	var on_drop: Callable
	var on_clear: Callable

	func _can_drop_data(_p: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("item_id")

	func _drop_data(_p: Vector2, data: Variant) -> void:
		on_drop.call(index, data.item_id)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			on_clear.call(index)
			accept_event()

var panel: PanelContainer
var inv_list: DragList
var hot_buttons: Array = []
var inv_desc: Label
var equip_label: Label
var rec_list: ItemList
var rec_desc: Label
var craft_btn: Button
var bench_label: Label
var sto_col: VBoxContainer
var sto_list: ItemList
var sto_title: Label
var inv_ids: Array = []
var sto_ids: Array = []
var storage: Node = null
var refresh_t := 0.0


func _ready() -> void:
	layer = 6
	add_to_group("inventory_ui")
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.06, 0.94)
	sb.set_content_margin_all(18)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(0.45, 0.4, 0.25)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	panel.add_child(hb)

	# --- inventaire
	var c1 := _column(hb, "INVENTAIRE")
	inv_list = DragList.new()
	inv_list.custom_minimum_size = Vector2(400, 470)
	inv_list.add_theme_font_size_override("font_size", 16)
	inv_list.ids_ref = inv_ids
	c1.add_child(inv_list)
	inv_list.item_selected.connect(func(_i): _update_desc())
	inv_list.item_activated.connect(func(_i): _use())
	inv_desc = _text(c1, 90)
	var r1 := HBoxContainer.new()
	c1.add_child(r1)
	_button(r1, "Utiliser / Équiper", _use)
	_button(r1, "Jeter 1", func(): _drop(false))
	_button(r1, "Jeter tout", func(): _drop(true))

	# --- équipement
	var c2 := _column(hb, "ÉQUIPEMENT")
	equip_label = _text(c2, 200)
	equip_label.custom_minimum_size.x = 300
	for s in [["tete", "Retirer tête"], ["torse", "Retirer torse"], ["dos", "Retirer sac"]]:
		var slot_name: String = s[0]
		_button(c2, s[1], func(): _unequip(slot_name))
	var ht := Label.new()
	ht.text = "BARRE RAPIDE"
	ht.add_theme_font_size_override("font_size", 18)
	ht.add_theme_color_override("font_color", Color(0.9, 0.8, 0.45))
	c2.add_child(ht)
	for i in 5:
		var hs := HotSlot.new()
		hs.index = i
		hs.on_drop = _assign_slot
		hs.on_clear = func(idx): _assign_slot(idx, "")
		hs.custom_minimum_size = Vector2(300, 34)
		hs.alignment = HORIZONTAL_ALIGNMENT_LEFT
		hs.add_theme_font_size_override("font_size", 15)
		var sn := StyleBoxFlat.new()
		sn.bg_color = Color(0.12, 0.12, 0.1)
		sn.border_color = Color(0.45, 0.4, 0.25)
		sn.set_border_width_all(1)
		sn.set_corner_radius_all(4)
		sn.content_margin_left = 10
		var sh := sn.duplicate()
		sh.bg_color = Color(0.25, 0.22, 0.12)
		sh.border_color = Color(0.9, 0.8, 0.45)
		hs.add_theme_stylebox_override("normal", sn)
		hs.add_theme_stylebox_override("hover", sh)
		hs.add_theme_stylebox_override("pressed", sh)
		hs.add_theme_stylebox_override("focus", sh)
		hs.pressed.connect(_slot_clicked.bind(i))
		c2.add_child(hs)
		hot_buttons.append(hs)
	var tip := _text(c2, 0)
	tip.text = "Glisse un objet sur un emplacement (ou sélectionne-le puis clique sur l'emplacement). Clic droit = vider.\nDouble-clic sur un objet pour l'utiliser."
	tip.modulate = Color(0.7, 0.7, 0.65)

	# --- fabrication
	var c3 := _column(hb, "FABRICATION")
	bench_label = _text(c3, 0)
	rec_list = _list(c3, Vector2(380, 380))
	rec_list.item_selected.connect(func(_i): _update_recipe())
	rec_list.item_activated.connect(func(_i): _craft())
	rec_desc = _text(c3, 120)
	craft_btn = _button(c3, "Fabriquer", _craft)

	# --- stockage
	sto_col = _column(hb, "STOCKAGE")
	sto_title = sto_col.get_child(0)
	sto_list = _list(sto_col, Vector2(320, 470))
	sto_list.item_activated.connect(func(_i): _take(false))
	var r4 := HBoxContainer.new()
	sto_col.add_child(r4)
	_button(r4, "Prendre", func(): _take(false))
	_button(r4, "Prendre tout", func(): _take(true))
	_button(sto_col, "Déposer l'objet sélectionné →", _deposit)
	panel.visible = false


func _column(parent: Control, title: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color(0.9, 0.8, 0.45))
	vb.add_child(t)
	parent.add_child(vb)
	return vb


func _list(parent: Control, min_size: Vector2) -> ItemList:
	var il := ItemList.new()
	il.custom_minimum_size = min_size
	il.add_theme_font_size_override("font_size", 16)
	parent.add_child(il)
	return il


func _text(parent: Control, min_h: float) -> Label:
	var l := Label.new()
	l.custom_minimum_size = Vector2(0, min_h)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 15)
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# ================================================================ ouverture
func open(crate: Node) -> void:
	var p = Game.player
	if p == null or not p.alive:
		return
	storage = crate
	panel.visible = true
	sto_col.visible = storage != null
	Game.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()


func close() -> void:
	panel.visible = false
	Game.ui_open = false
	get_viewport().gui_release_focus()
	if storage and is_instance_valid(storage) and storage.label == "Objets au sol" and storage.contents.is_empty():
		storage.queue_free()
	storage = null
	if Game.player and Game.player.alive:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if panel.visible:
		if event.is_action_pressed("inventaire") or event.is_action_pressed("pause"):
			close()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventaire") and not Game.ui_open and Game.player and Game.player.alive:
		open(null)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not panel.visible:
		return
	var vs := get_viewport().get_visible_rect().size
	panel.position = (vs - panel.size) / 2.0
	refresh_t -= delta
	if refresh_t <= 0.0:
		refresh_t = 0.5
		_update_equip()
		_update_recipe_marks()
	if storage and not is_instance_valid(storage):
		close()
	elif storage and Game.player.global_position.distance_to(storage.global_position) > 4.0:
		close()


func refresh() -> void:
	var p = Game.player
	var keep := _selected(inv_list)
	inv_list.clear()
	inv_ids.clear()
	var ids: Array = p.items.keys()
	ids.sort_custom(func(a, b): return Items.nom(a) < Items.nom(b))
	for id in ids:
		var tag := ""
		var hi: int = p.hotbar.find(id)
		if hi >= 0:
			tag = "  [%d]" % (hi + 1)
		inv_list.add_item("%s ×%d%s   (%.1f kg)" % [Items.nom(id), p.items[id], tag, Items.weight(id) * p.items[id]])
		inv_ids.append(id)
	if keep >= 0 and keep < inv_list.item_count:
		inv_list.select(keep)
	_update_desc()
	_update_equip()
	# recettes
	var rkeep := _selected(rec_list)
	rec_list.clear()
	for r in Items.RECIPES:
		var label := "%s%s" % [Items.nom(r.out), (" ×%d" % r.qty) if r.qty > 1 else ""]
		if r.bench:
			label += "   [établi]"
		rec_list.add_item(label)
	_update_recipe_marks()
	if rkeep >= 0:
		rec_list.select(rkeep)
	_update_recipe()
	# stockage
	if storage:
		sto_title.text = storage.label.to_upper()
		var skeep := _selected(sto_list)
		sto_list.clear()
		sto_ids.clear()
		for id in storage.contents:
			sto_list.add_item("%s ×%d" % [Items.nom(id), storage.contents[id]])
			sto_ids.append(id)
		if skeep >= 0 and skeep < sto_list.item_count:
			sto_list.select(skeep)


func _selected(il: ItemList) -> int:
	var s := il.get_selected_items()
	return s[0] if s.size() > 0 else -1


func _update_desc() -> void:
	var i := _selected(inv_list)
	if i < 0 or i >= inv_ids.size():
		inv_desc.text = "Sélectionne un objet."
		return
	var id: String = inv_ids[i]
	var it := Items.info(id)
	var d := ""
	match it.get("type", ""):
		"food", "drink":
			d = "Nourriture/boisson : +%d faim, +%d soif." % [it.get("food", 0), it.get("water", 0)]
		"heal":
			d = "Soin : +%d santé." % it.heal
		"melee":
			d = "Arme blanche — dégâts %d, portée %.1f m. Silencieuse." % [it.damage, it.range]
		"gun":
			d = "Arme à feu — dégâts %d%s, chargeur %d, munitions : %s. Bruyante !" % [it.damage, " ×%d plombs" % it.pellets if it.pellets > 1 else "", it.mag, Items.nom(it.ammo)]
		"armor":
			d = "Équipement (%s) — protection %d%%%s." % [it.slot, int(it.armor * 100), ", +%d kg de capacité" % it.capacity if it.has("capacity") else ""]
		"placeable":
			d = "Objet de base. « Utiliser » pour le poser."
		"ammo":
			d = "Munitions."
		_:
			d = "Matériau de fabrication."
	inv_desc.text = d


func _update_equip() -> void:
	var p = Game.player
	var e: Dictionary = p.equipped
	for i in 5:
		var id: String = p.hotbar[i]
		var txt := "%d :  —" % (i + 1)
		if id != "":
			txt = "%d :  %s" % [i + 1, Items.nom(id)]
			if not Items.is_weapon(id):
				txt += " ×%d" % p.count(id)
		hot_buttons[i].text = txt
	equip_label.text = "Tête : %s\nTorse : %s\nDos : %s\n\nProtection totale : %d%%\nPoids : %.1f / %.0f kg\n\nSanté %d  •  Faim %d  •  Soif %d" % [
		Items.nom(e.tete) if e.tete != "" else "—",
		Items.nom(e.torse) if e.torse != "" else "—",
		Items.nom(e.dos) if e.dos != "" else "—",
		int(p.armor_total() * 100), p.carry_weight(), p.max_weight(),
		int(p.health), int(p.hunger), int(p.thirst)]


func _update_recipe_marks() -> void:
	var p = Game.player
	var near: bool = p.near_bench()
	bench_label.text = "Établi à proximité : %s" % ("OUI" if near else "non (recettes [établi] bloquées)")
	bench_label.modulate = Color(0.5, 1.0, 0.5) if near else Color(1.0, 0.7, 0.5)
	for i in Items.RECIPES.size():
		if i < rec_list.item_count:
			var ok: bool = p.can_craft(Items.RECIPES[i])
			rec_list.set_item_custom_fg_color(i, Color(0.6, 1.0, 0.6) if ok else Color(0.6, 0.6, 0.6))


func _update_recipe() -> void:
	var i := _selected(rec_list)
	if i < 0:
		rec_desc.text = "Sélectionne une recette."
		craft_btn.disabled = true
		return
	var p = Game.player
	var r: Dictionary = Items.RECIPES[i]
	var lines: PackedStringArray = []
	for id in r.needs:
		lines.append("%s %d× %s (tu as %d)" % ["✔" if p.count(id) >= r.needs[id] else "✘", r.needs[id], Items.nom(id), p.count(id)])
	if r.bench:
		lines.append(("✔" if p.near_bench() else "✘") + " Nécessite un établi")
	rec_desc.text = "\n".join(lines)
	craft_btn.disabled = not p.can_craft(r)


# ================================================================ actions
func _assign_slot(i: int, id: String) -> void:
	var p = Game.player
	if id != "" and p.count(id) <= 0:
		return
	p.assign_hotbar(i, id)
	refresh()


func _slot_clicked(i: int) -> void:
	var sel := _selected(inv_list)
	if sel < 0 or sel >= inv_ids.size():
		Game.msg("Sélectionne d'abord un objet dans l'inventaire (ou glisse-le sur l'emplacement).")
		return
	_assign_slot(i, inv_ids[sel])


func _use() -> void:
	var i := _selected(inv_list)
	if i < 0 or i >= inv_ids.size():
		return
	var id: String = inv_ids[i]
	if Items.info(id).get("type", "") == "placeable":
		close()
		Game.player.use_item(id)
		return
	Game.player.use_item(id)
	refresh()


func _drop(all: bool) -> void:
	var i := _selected(inv_list)
	if i < 0 or i >= inv_ids.size():
		return
	var id: String = inv_ids[i]
	var p = Game.player
	p.drop_item(id, p.count(id) if all else 1)
	refresh()


func _unequip(s: String) -> void:
	Game.player.unequip(s)
	refresh()


func _craft() -> void:
	var i := _selected(rec_list)
	if i < 0:
		return
	Game.player.craft(Items.RECIPES[i])
	refresh()


func _take(all: bool) -> void:
	if storage == null:
		return
	var p = Game.player
	if all:
		for id in storage.contents.keys():
			p.add_item(id, storage.contents[id])
		storage.contents.clear()
	else:
		var i := _selected(sto_list)
		if i < 0 or i >= sto_ids.size():
			return
		var id: String = sto_ids[i]
		p.add_item(id, 1)
		storage.contents[id] -= 1
		if storage.contents[id] <= 0:
			storage.contents.erase(id)
	refresh()


func _deposit() -> void:
	if storage == null:
		return
	var i := _selected(inv_list)
	if i < 0 or i >= inv_ids.size():
		return
	var id: String = inv_ids[i]
	var p = Game.player
	var n: int = p.count(id)
	if p.remove_item(id, n):
		storage.contents[id] = int(storage.contents.get(id, 0)) + n
	refresh()
