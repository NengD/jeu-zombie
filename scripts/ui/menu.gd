extends Control
## Menu principal : Jouer, Paramètres (touches + réglages), Guide, Quitter.

const Textes = preload("res://scripts/ui/textes.gd")

var main_box: VBoxContainer
var settings_panel: PanelContainer
var guide_panel: PanelContainer
var sens_label: Label
var vol_label: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# fond
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float t = 0.0;
void fragment() {
	vec2 uv = UV;
	float v = 1.0 - length(uv - vec2(0.5, 0.45)) * 1.1;
	float n = fract(sin(dot(floor(uv * 300.0) + floor(TIME * 12.0), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 col = mix(vec3(0.02, 0.02, 0.02), vec3(0.16, 0.05, 0.04), clamp(v, 0.0, 1.0));
	col += (n - 0.5) * 0.025;
	COLOR = vec4(col, 1.0);
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	bg.material = sm
	add_child(bg)
	# colonne principale
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 16)
	center.add_child(main_box)
	var title := Label.new()
	title.text = "JEU ZOMBIE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ts := LabelSettings.new()
	ts.font_size = 96
	ts.font_color = Color(0.75, 0.12, 0.08)
	ts.outline_size = 10
	ts.outline_color = Color(0, 0, 0)
	ts.shadow_size = 12
	ts.shadow_color = Color(0, 0, 0, 0.6)
	title.label_settings = ts
	main_box.add_child(title)
	var sub := Label.new()
	sub.text = "Fouille. Fabrique. Survis."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	main_box.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	main_box.add_child(spacer)
	var play: Button
	if Sauvegarde.existe():
		play = _big_button("Continuer", func(): Game.admin = false; Game.partie_a_charger = Sauvegarde.lire(); _play())
		var info := Label.new()
		info.text = Sauvegarde.resume()
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_theme_font_size_override("font_size", 16)
		info.add_theme_color_override("font_color", Color(0.65, 0.65, 0.6))
		main_box.add_child(info)
		_big_button("Nouvelle partie", func(): Game.admin = false; Game.partie_a_charger = {}; _play())
	else:
		play = _big_button("Jouer", func(): Game.admin = false; Game.partie_a_charger = {}; _play())
	var adm := _big_button("Mode admin (test)", func(): _lancer_admin())
	adm.tooltip_text = "Partie de test : vol, invincible, tous les objets, téléportation… (rien n'est sauvegardé)"
	_big_button("Paramètres", func(): _show(settings_panel))
	_big_button("Guide", func(): _show(guide_panel))
	_big_button("Quitter", func(): get_tree().quit())
	play.grab_focus()
	var ver := Label.new()
	ver.text = "Prototype 1"
	ver.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(20, -40)
	add_child(ver)
	settings_panel = _build_settings()
	guide_panel = _build_guide()


func _big_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 62)
	b.add_theme_font_size_override("font_size", 26)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	n.border_color = Color(0.45, 0.15, 0.1)
	n.set_border_width_all(2)
	n.set_corner_radius_all(6)
	var h := n.duplicate()
	h.bg_color = Color(0.35, 0.08, 0.05, 0.95)
	h.border_color = Color(0.85, 0.25, 0.15)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("pressed", h)
	b.pressed.connect(cb)
	main_box.add_child(b)
	return b


func _panel_base(title: String) -> Array:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.05, 0.96)
	sb.border_color = Color(0.45, 0.15, 0.1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(26)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(900, 700)
	pc.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 36)
	t.add_theme_color_override("font_color", Color(0.85, 0.25, 0.15))
	vb.add_child(t)
	add_child(pc)
	return [pc, vb]


func _build_settings() -> PanelContainer:
	var r := _panel_base("PARAMÈTRES")
	var vb: VBoxContainer = r[1]
	# réglages
	sens_label = _small_label(vb, "")
	var s1 := HSlider.new()
	s1.min_value = 0.2
	s1.max_value = 3.0
	s1.step = 0.05
	s1.value = Game.mouse_sens
	s1.custom_minimum_size = Vector2(500, 24)
	s1.value_changed.connect(func(v): Game.mouse_sens = v; _update_setting_labels())
	vb.add_child(s1)
	vol_label = _small_label(vb, "")
	var s2 := HSlider.new()
	s2.min_value = 0.0
	s2.max_value = 1.0
	s2.step = 0.05
	s2.value = Game.volume
	s2.custom_minimum_size = Vector2(500, 24)
	s2.value_changed.connect(func(v): Game.volume = v; Game.apply_settings(); _update_setting_labels())
	vb.add_child(s2)
	_small_label(vb, "Qualité graphique (Élevé et Ultra : brume volumétrique, reflets, ombres douces) :")
	var qg := OptionButton.new()
	for nom in Game.NOMS_QUALITE:
		qg.add_item(nom)
	qg.selected = Game.qualite
	qg.custom_minimum_size = Vector2(240, 30)
	qg.item_selected.connect(func(i): Game.qualite = i; Game.save_settings())
	vb.add_child(qg)
	_update_setting_labels()
	# touches
	var kt := Label.new()
	kt.text = "TOUCHES"
	kt.add_theme_font_size_override("font_size", 24)
	kt.add_theme_color_override("font_color", Color(0.9, 0.8, 0.45))
	vb.add_child(kt)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for t in Textes.TOUCHES:
		var k := Label.new()
		k.text = t[1]
		k.custom_minimum_size = Vector2(220, 0)
		k.add_theme_font_size_override("font_size", 19)
		k.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		grid.add_child(k)
		var a := Label.new()
		a.text = t[0]
		a.add_theme_font_size_override("font_size", 19)
		grid.add_child(a)
	_back_button(vb, func():
		Game.save_settings()
		_show(null))
	return r[0]


func _update_setting_labels() -> void:
	sens_label.text = "Sensibilité de la souris : %.2f" % Game.mouse_sens
	vol_label.text = "Volume général : %d %%" % int(Game.volume * 100)


func _build_guide() -> PanelContainer:
	var r := _panel_base("GUIDE DE SURVIE")
	var vb: VBoxContainer = r[1]
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = Textes.GUIDE
	rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 18)
	rt.add_theme_font_size_override("bold_font_size", 19)
	rt.add_theme_color_override("default_color", Color(0.88, 0.86, 0.8))
	vb.add_child(rt)
	_back_button(vb, func(): _show(null))
	return r[0]


func _small_label(parent: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	parent.add_child(l)
	return l


func _back_button(parent: Control, cb: Callable) -> void:
	var b := Button.new()
	b.text = "Retour"
	b.custom_minimum_size = Vector2(200, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(cb)
	parent.add_child(b)


func _show(panel: Control) -> void:
	settings_panel.visible = panel == settings_panel
	guide_panel.visible = panel == guide_panel
	main_box.visible = panel == null


func _process(_delta: float) -> void:
	var vs := get_viewport_rect().size
	for p in [settings_panel, guide_panel]:
		if p and p.visible:
			p.position = (vs - p.size) / 2.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not main_box.visible:
		Game.save_settings()
		_show(null)


func _play() -> void:
	var l := Label.new()
	l.text = "Chargement…"
	l.add_theme_font_size_override("font_size", 32)
	l.set_anchors_preset(Control.PRESET_CENTER)
	main_box.visible = false
	add_child(l)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/main.tscn")



## Lance une partie de test en mode admin (rien n'est sauvegardé).
func _lancer_admin() -> void:
	Game.admin = true
	Game.admin_invincible = true
	Game.admin_munitions = true
	Game.admin_besoins = true
	Game.admin_vol = false
	Game.admin_murs = false
	Game.admin_invisible = false
	Game.partie_a_charger = {}
	_play()
