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
var lbl_niveau: Label
var barre_xp: ProgressBar
var lbl_gain: Label
var gain_t := 0.0
var gain_xp := 0
var gain_comp := ""
var prog_connecte := false
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
var boss_box: VBoxContainer
var boss_barre: ProgressBar


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
	pause_panel = _menu_panel("PAUSE", [["Reprendre", _resume], ["Sauvegarder (F5)", _sauver], ["Charger la sauvegarde (F9)", _charger], ["Commandes (F1)", _toggle_help], ["Sauvegarder et menu principal", _sauver_menu], ["Quitter le jeu", _quit]])
	death_panel = _menu_panel("TU ES MORT", [["Charger la dernière sauvegarde", _charger], ["Nouvelle partie", _restart], ["Menu principal", Game.go_to_menu], ["Quitter le jeu", _quit]])
	# niveau et XP (au-dessus de la barre rapide)
	lbl_niveau = _label("", 15)
	lbl_niveau.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(lbl_niveau)
	barre_xp = ProgressBar.new()
	barre_xp.show_percentage = false
	barre_xp.custom_minimum_size = Vector2(0, 6)
	var fx := StyleBoxFlat.new()
	fx.bg_color = Color(0.95, 0.8, 0.35)
	var bx := StyleBoxFlat.new()
	bx.bg_color = Color(0, 0, 0, 0.5)
	barre_xp.add_theme_stylebox_override("fill", fx)
	barre_xp.add_theme_stylebox_override("background", bx)
	root.add_child(barre_xp)
	lbl_gain = _label("", 18)
	lbl_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_gain.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	root.add_child(lbl_gain)
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
	_maj_boss(p)
	bars.sante.max_value = p.prog.sante_max()
	bars.endurance.max_value = p.prog.endurance_max()
	bars.sante.value = p.health
	bars.faim.value = p.hunger
	bars.soif.value = p.thirst
	bars.endurance.value = p.stamina
	flash.color.a = maxf(p.hurt_flash * 0.35, (1.0 - p.health / p.prog.sante_max()) * 0.18 if p.health < 35.0 else 0.0)
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


func _on_xp(c: String, q: int) -> void:
	if c != gain_comp or gain_t <= 0.0:
		gain_xp = 0
	gain_comp = c
	gain_xp += q
	gain_t = 2.0


func _maj_xp(delta: float, vs: Vector2) -> void:
	var p = Game.player
	if p == null:
		return
	if not prog_connecte:
		p.prog.xp_gagnee.connect(_on_xp)
		prog_connecte = true
	var pr = p.prog
	var alerte := ""
	var pts_talents := 0
	for c in pr.comp:
		pts_talents += int(pr.comp[c].points)
	if pr.points > 0 or pts_talents > 0:
		alerte = "   •   points à dépenser : touche K"
	lbl_niveau.text = "Niveau %d   (%d / %d XP)%s" % [pr.niveau, pr.xp, Progression.xp_niveau(pr.niveau), alerte]
	barre_xp.max_value = Progression.xp_niveau(pr.niveau)
	barre_xp.value = pr.xp
	var w := 5 * 158.0
	barre_xp.position = Vector2(vs.x / 2.0 - w / 2.0, vs.y - 74)
	barre_xp.size = Vector2(w - 8, 6)
	lbl_niveau.position = Vector2(vs.x / 2.0 - 400, vs.y - 100)
	lbl_niveau.size = Vector2(800, 24)
	gain_t -= delta
	lbl_gain.visible = gain_t > 0.0
	if gain_t > 0.0:
		lbl_gain.text = "+%d XP  %s" % [gain_xp, Progression.NOMS.get(gain_comp, "")]
		lbl_gain.modulate.a = clampf(gain_t, 0.0, 1.0)
		lbl_gain.position = Vector2(vs.x / 2.0 - 200, vs.y - 128 - (2.0 - gain_t) * 10.0)
		lbl_gain.size = Vector2(400, 24)


func _layout(vs: Vector2) -> void:
	_maj_xp(get_process_delta_time(), vs)
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


func _sauver() -> void:
	var m := get_tree().current_scene
	if m and m.has_method("sauvegarder"):
		m.sauvegarder()


func _sauver_menu() -> void:
	_sauver()
	Game.go_to_menu()


func _charger() -> void:
	if Sauvegarde.existe():
		Game.charger_partie()
	else:
		Game.msg("Aucune sauvegarde.")


func _restart() -> void:
	get_tree().paused = false
	Game.ui_open = false
	get_tree().reload_current_scene()


func _quit() -> void:
	get_tree().quit()



# ================================================================ barre de vie du boss
func _maj_boss(p) -> void:
	var boss: Node = null
	for b in get_tree().get_nodes_in_group("boss"):
		if b.state != b.State.DEAD and (b.state == b.State.CHASE or b.global_position.distance_to(p.global_position) < 22.0):
			boss = b
			break
	if boss == null:
		if boss_box:
			boss_box.visible = false
		return
	if boss_box == null:
		boss_box = VBoxContainer.new()
		boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boss_box.alignment = BoxContainer.ALIGNMENT_CENTER
		boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
		boss_box.position = Vector2(-260, 18)
		boss_box.custom_minimum_size = Vector2(520, 0)
		root.add_child(boss_box)
		var l := Label.new()
		l.text = "LE COLOSSE"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(0.95, 0.75, 0.45))
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 5)
		boss_box.add_child(l)
		boss_barre = ProgressBar.new()
		boss_barre.show_percentage = false
		boss_barre.custom_minimum_size = Vector2(520, 16)
		boss_barre.max_value = 2500.0
		var f := StyleBoxFlat.new()
		f.bg_color = Color(0.7, 0.12, 0.1)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.6)
		bg.border_color = Color(0.9, 0.75, 0.45, 0.8)
		bg.set_border_width_all(1)
		boss_barre.add_theme_stylebox_override("fill", f)
		boss_barre.add_theme_stylebox_override("background", bg)
		boss_box.add_child(boss_barre)
	boss_box.visible = true
	boss_box.position.x = root.get_viewport_rect().size.x / 2.0 - 260.0
	boss_box.position.y = 18.0
	boss_barre.value = boss.health
