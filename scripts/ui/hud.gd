extends CanvasLayer
const Textes = preload("res://scripts/ui/textes.gd")
## Interface en jeu : réticule, jauges, arme, barre rapide, messages,
## heure, aide (F1), pause (Échap), écran de mort.

class Crosshair extends Control:
	var spread := 6.0
	var hit := 0.0
	var head := false

	func _draw() -> void:
		var c := size / 2.0
		var col := Color(1, 1, 1, 0.85)
		var g := spread
		draw_line(c + Vector2(-g - 8, 0), c + Vector2(-g, 0), col, 2.0)
		draw_line(c + Vector2(g, 0), c + Vector2(g + 8, 0), col, 2.0)
		draw_line(c + Vector2(0, -g - 8), c + Vector2(0, -g), col, 2.0)
		draw_line(c + Vector2(0, g), c + Vector2(0, g + 8), col, 2.0)
		draw_circle(c, 1.5, col)
		if hit > 0.0:
			var hc := Color(1, 0.25, 0.2, hit) if head else Color(1, 1, 1, hit)
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * 6.0, c + d * 13.0, hc, 2.5)


var root: Control
var cross: Crosshair
var bars := {}
var lbl_weapon: Label
var lbl_ammo: Label
var lbl_prompt: Label
var lbl_info: Label
var hot_panels: Array = []
var hot_labels: Array = []
var hot_icons: Array = []
var msg_box: VBoxContainer
var messages: Array = []
var flash: ColorRect
var help_panel: PanelContainer
var pause_panel: PanelContainer
var death_panel: PanelContainer
var paused := false


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	flash = ColorRect.new()
	flash.color = Color(0.6, 0, 0, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	cross = Crosshair.new()
	cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)
	# jauges
	var bar_box := VBoxContainer.new()
	bar_box.name = "Jauges"
	bar_box.position = Vector2(24, 0)
	bar_box.add_theme_constant_override("separation", 6)
	root.add_child(bar_box)
	for b in [["sante", "Santé", Color(0.8, 0.2, 0.2)], ["faim", "Faim", Color(0.85, 0.6, 0.2)], ["soif", "Soif", Color(0.25, 0.55, 0.9)], ["endurance", "Endurance", Color(0.4, 0.8, 0.35)]]:
		var row := HBoxContainer.new()
		var l := _label(b[1], 16)
		l.custom_minimum_size = Vector2(100, 0)
		row.add_child(l)
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(220, 16)
		pb.show_percentage = false
		pb.max_value = 100
		var fill := StyleBoxFlat.new()
		fill.bg_color = b[2]
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.55)
		pb.add_theme_stylebox_override("fill", fill)
		pb.add_theme_stylebox_override("background", bg)
		row.add_child(pb)
		bar_box.add_child(row)
		bars[b[0]] = pb
	# arme
	lbl_weapon = _label("", 22)
	lbl_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(lbl_weapon)
	lbl_ammo = _label("", 30)
	lbl_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(lbl_ammo)
	# barre rapide
	for i in 5:
		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(150, 48)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		pc.add_child(hb)
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(40, 40)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(tr)
		hot_icons.append(tr)
		var l2 := _label("", 13)
		l2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l2)
		root.add_child(pc)
		hot_panels.append(pc)
		hot_labels.append(l2)
	lbl_prompt = _label("", 20)
	lbl_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(lbl_prompt)
	lbl_info = _label("", 17)
	lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(lbl_info)
	msg_box = VBoxContainer.new()
	msg_box.position = Vector2(24, 24)
	root.add_child(msg_box)
	help_panel = _panel(_help_text(), Vector2(620, 0))
	help_panel.visible = false
	pause_panel = _menu_panel("PAUSE", [["Reprendre", _resume], ["Commandes (F1)", _toggle_help], ["Menu principal", Game.go_to_menu], ["Quitter le jeu", _quit]])
	death_panel = _menu_panel("TU ES MORT", [["Recommencer", _restart], ["Menu principal", Game.go_to_menu], ["Quitter le jeu", _quit]])
	Game.notify.connect(_on_msg)
	Game.hit_confirmed.connect(_on_hit)
	Game.player_died.connect(_on_death)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.outline_size = 5
	ls.outline_color = Color(0, 0, 0, 0.9)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(text: String, min_size: Vector2) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.05, 0.9)
	sb.set_content_margin_all(18)
	sb.set_corner_radius_all(6)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = min_size
	var l := _label(text, 17)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pc.add_child(l)
	root.add_child(pc)
	return pc


func _menu_panel(title: String, buttons: Array) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.05, 0.92)
	sb.set_content_margin_all(28)
	sb.set_corner_radius_all(8)
	pc.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	var t := _label(title, 36)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(320, 48)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(b[1])
		vb.add_child(btn)
	pc.add_child(vb)
	pc.visible = false
	root.add_child(pc)
	return pc


func _help_text() -> String:
	return "COMMANDES\n" + Textes.touches_texte() + "\n\nLe guide complet est dans le menu principal (bouton Guide)."


# ================================================================ boucle
func _process(delta: float) -> void:
	var vs := root.get_viewport_rect().size
	var p = Game.player
	_layout(vs)
	# messages
	for m in messages.duplicate():
		m.t -= delta
		if m.t < 1.0:
			m.label.modulate.a = maxf(0.0, m.t)
		if m.t <= 0.0:
			m.label.queue_free()
			messages.erase(m)
	cross.hit = maxf(0.0, cross.hit - delta * 4.0)
	if p == null:
		return
	bars.sante.value = p.health
	bars.faim.value = p.hunger
	bars.soif.value = p.thirst
	bars.endurance.value = p.stamina
	flash.color.a = maxf(p.hurt_flash * 0.35, (1.0 - p.health / 100.0) * 0.18 if p.health < 35.0 else 0.0)
	var wid: String = p.current_weapon()
	var w := Items.info(wid)
	lbl_weapon.text = Items.nom(wid)
	if w.get("type", "") == "gun":
		if p.reload_t > 0.0:
			lbl_ammo.text = "Rechargement…"
		else:
			lbl_ammo.text = "%d / %d" % [int(p.mags.get(wid, 0)), p.count(w.ammo)]
	else:
		lbl_ammo.text = ""
	for i in 5:
		var id: String = p.hotbar[i]
		var txt := "—"
		if id != "":
			txt = Items.nom(id)
			if not Items.is_weapon(id):
				txt += " ×%d" % p.count(id)
		hot_labels[i].text = "%d  %s" % [i + 1, txt]
		var tex: Texture2D = Items.icon(id) if id != "" else null
		hot_icons[i].texture = tex
		hot_icons[i].modulate = Items.category_color(id) if tex and String(tex.resource_path).ends_with(".svg") else Color.WHITE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.85, 0.75, 0.3, 0.55) if i == p.slot else Color(0, 0, 0, 0.45)
		sb.set_corner_radius_all(4)
		hot_panels[i].add_theme_stylebox_override("panel", sb)
	lbl_prompt.text = p.prompt
	var view := "3e personne" if p.tps_blend > 0.5 else "1re personne"
	if p.want_tps and not p.in_zone.is_empty():
		view = "1re personne (intérieur)"
	var zone_name := ""
	if not p.in_zone.is_empty():
		zone_name = p.in_zone.name if p.in_zone.name != "" else "Intérieur"
		var nz := Game.zombies_in_zone(p.in_zone)
		zone_name += "  —  bâtiment sûr" if nz == 0 else "  —  %d zombie(s) à l'intérieur" % nz
	var hh := int(Game.time_hours)
	var mm := int((Game.time_hours - hh) * 60.0)
	lbl_info.text = "Jour %d — %02d:%02d%s\nVue : %s\n%s" % [
		Game.day, hh, mm, "  (nuit)" if Game.is_night() else "", view, zone_name]
	var moving: float = Vector2(p.velocity.x, p.velocity.z).length()
	var target_spread := 4.0 + moving * 1.5 + (0.0 if p.aiming else 4.0)
	cross.spread = lerpf(cross.spread, target_spread, delta * 10.0)
	cross.visible = p.alive and not Game.ui_open
	cross.queue_redraw()


func _layout(vs: Vector2) -> void:
	root.get_node("Jauges").position = Vector2(24, vs.y - 140)
	lbl_weapon.position = Vector2(vs.x - 424, vs.y - 110)
	lbl_weapon.size = Vector2(400, 30)
	lbl_ammo.position = Vector2(vs.x - 424, vs.y - 76)
	lbl_ammo.size = Vector2(400, 40)
	var total := 5 * 158.0
	for i in 5:
		hot_panels[i].position = Vector2(vs.x / 2.0 - total / 2.0 + i * 158.0, vs.y - 64)
	lbl_prompt.position = Vector2(vs.x / 2.0 - 400, vs.y / 2.0 + 40)
	lbl_prompt.size = Vector2(800, 30)
	lbl_info.position = Vector2(vs.x - 624, 20)
	lbl_info.size = Vector2(600, 100)
	help_panel.position = Vector2(vs.x / 2.0 - help_panel.size.x / 2.0, vs.y / 2.0 - help_panel.size.y / 2.0)
	pause_panel.position = (vs - pause_panel.size) / 2.0
	death_panel.position = (vs - death_panel.size) / 2.0


# ================================================================ événements
func _on_msg(text: String) -> void:
	var l := _label(text, 17)
	msg_box.add_child(l)
	messages.append({"label": l, "t": 6.0})
	while messages.size() > 7:
		var m = messages.pop_front()
		m.label.queue_free()


func _on_hit(headshot: bool, kill: bool) -> void:
	cross.hit = 1.0
	cross.head = headshot
	if kill and headshot:
		_on_msg("Tir à la tête mortel !")


func _on_death() -> void:
	death_panel.visible = true
	help_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("aide"):
		_toggle_help()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if paused:
			_resume()
		elif not Game.ui_open and Game.player and Game.player.alive:
			paused = true
			get_tree().paused = true
			Game.ui_open = true
			pause_panel.visible = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()


func _toggle_help() -> void:
	help_panel.visible = not help_panel.visible


func _resume() -> void:
	paused = false
	get_tree().paused = false
	Game.ui_open = false
	pause_panel.visible = false
	help_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _restart() -> void:
	get_tree().paused = false
	Game.ui_open = false
	get_tree().reload_current_scene()


func _quit() -> void:
	get_tree().quit()
