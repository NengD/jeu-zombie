extends Control
## Menu principal : Jouer (puis choix du lieu de départ), Paramètres (touches + réglages), Guide, Quitter.

const Textes = preload("res://scripts/ui/textes.gd")
const LieuxDepart = preload("res://scripts/lieux_depart.gd")
const ParametresUI = preload("res://scripts/ui/parametres_ui.gd")

var main_box: VBoxContainer
var settings_panel: PanelContainer
var guide_panel: PanelContainer
var depart_panel: PanelContainer


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
		_big_button("Nouvelle partie", func(): Game.admin = false; Game.partie_a_charger = {}; _show(depart_panel))
	else:
		play = _big_button("Jouer", func(): Game.admin = false; Game.partie_a_charger = {}; _show(depart_panel))
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
	depart_panel = _build_depart()


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
	var pc = ParametresUI.new()
	pc.visible = false
	pc.ferme.connect(func(): _show(null))
	add_child(pc)
	return pc


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


## Choix du lieu de départ d'une nouvelle partie : liste classée par difficulté, petite carte, description.
var lieu_choisi := "bellerive"
var depart_desc: RichTextLabel
var depart_carte: Control
var depart_boutons := {}

## Repères fixes de la carte (5 × 5 km, nord en haut) pour la petite carte du choix.
const REPERES_CARTE := [
	["Bellerive", Vector3(0, 0, 0), 161.0], ["Valmont", Vector3(1450, 0, -1350), 115.0],
	["Granges", Vector3(-1500, 0, -1400), 0.0], ["Pont-Rouge", Vector3(1300, 0, 1550), 0.0],
]


func _build_depart() -> PanelContainer:
	var r := _panel_base("LIEU DE DÉPART")
	var vb: VBoxContainer = r[1]
	_small_label(vb, "Choisis où commencer. Plus c'est difficile, plus il y a de zombies… et de butin.").add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(hb)
	var liste := VBoxContainer.new()
	liste.add_theme_constant_override("separation", 6)
	hb.add_child(liste)
	for l in LieuxDepart.LIEUX + [{"id": "hasard", "nom": "Au hasard", "diff": -1}]:
		var b := Button.new()
		b.text = "%s   —   %s" % [l.nom, "?" if l.diff < 0 else LieuxDepart.DIFFICULTES[l.diff]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(390, 44)
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8) if l.diff < 0 else LieuxDepart.COULEURS[l.diff])
		var n := StyleBoxFlat.new()
		n.bg_color = Color(0.1, 0.1, 0.1, 0.85)
		n.set_corner_radius_all(4)
		n.set_content_margin_all(8)
		var p := n.duplicate()
		p.bg_color = Color(0.35, 0.08, 0.05, 0.95)
		p.border_color = Color(0.85, 0.25, 0.15)
		p.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", p)
		b.add_theme_stylebox_override("pressed", p)
		b.add_theme_stylebox_override("focus", p)
		b.pressed.connect(_choisir_lieu.bind(l.id))
		liste.add_child(b)
		depart_boutons[l.id] = b
	var droite := VBoxContainer.new()
	droite.add_theme_constant_override("separation", 10)
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(droite)
	depart_carte = Control.new()
	depart_carte.custom_minimum_size = Vector2(300, 300)
	depart_carte.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	depart_carte.draw.connect(_dessiner_carte_depart)
	droite.add_child(depart_carte)
	depart_desc = RichTextLabel.new()
	depart_desc.bbcode_enabled = true
	depart_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	depart_desc.add_theme_font_size_override("normal_font_size", 18)
	depart_desc.add_theme_font_size_override("bold_font_size", 20)
	depart_desc.add_theme_color_override("default_color", Color(0.88, 0.86, 0.8))
	droite.add_child(depart_desc)
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_END
	bas.add_theme_constant_override("separation", 16)
	vb.add_child(bas)
	# difficulté de la partie (Game.difficulte : nombre de zombies, dégâts reçus, santé des zombies ; sauvegardée)
	var lab := _small_label(bas, "Difficulté :")
	lab.add_theme_font_size_override("font_size", 20)
	var diff := OptionButton.new()
	for k in Game.DIFFICULTES.size():
		diff.add_item(Game.DIFFICULTES[k], k)
	diff.selected = 1
	diff.custom_minimum_size = Vector2(190, 46)
	diff.add_theme_font_size_override("font_size", 20)
	diff.tooltip_text = "Facile : moins de zombies, coups moins forts.\nNormal : le jeu tel qu'il est prévu.\nDifficile : plus de zombies, plus résistants, coups plus forts.\nCauchemar : bien plus de zombies, coups très forts."
	bas.add_child(diff)
	var espace := Control.new()
	espace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bas.add_child(espace)
	_back_button(bas, func(): _show(null))
	var go := Button.new()
	go.text = "Commencer"
	go.custom_minimum_size = Vector2(240, 46)
	go.add_theme_font_size_override("font_size", 22)
	go.pressed.connect(func():
		LieuxDepart.choix = lieu_choisi
		Game.difficulte = diff.selected
		_play())
	bas.add_child(go)
	_choisir_lieu(lieu_choisi)
	return r[0]


func _choisir_lieu(id: String) -> void:
	lieu_choisi = id
	for k in depart_boutons:
		depart_boutons[k].set_pressed_no_signal(k == id)
	if id == "hasard":
		depart_desc.text = "[b]Au hasard[/b]\nUn des lieux de la liste, tiré au sort au chargement. Tu découvriras sa difficulté en arrivant."
	else:
		var l: Dictionary = LieuxDepart.lieu(id)
		depart_desc.text = "[b]%s[/b]   [color=#%s]%s[/color]\n%s" % [l.nom, LieuxDepart.COULEURS[l.diff].to_html(false), LieuxDepart.DIFFICULTES[l.diff], l.desc]
	depart_carte.queue_redraw()


## Petite carte : villes, villages, lieux de départ (point coloré selon la difficulté, cerclé si choisi).
func _dessiner_carte_depart() -> void:
	var s: Vector2 = depart_carte.size
	# échelle en racine carrée de la distance au centre : les lieux proches de Bellerive restent lisibles
	var ech: float = s.x * 0.5 / sqrt(Game.map_half)
	var vers := func(p: Vector3) -> Vector2: return Vector2(p.x, p.z).normalized() * sqrt(Vector2(p.x, p.z).length()) * ech + s / 2.0
	depart_carte.draw_rect(Rect2(Vector2.ZERO, s), Color(0.16, 0.2, 0.13))
	depart_carte.draw_rect(Rect2(Vector2.ZERO, s), Color(0.45, 0.15, 0.1), false, 2.0)
	var police := depart_carte.get_theme_default_font()
	for rp in REPERES_CARTE:
		var c: Vector2 = vers.call(rp[1])
		var d: float = maxf(sqrt(float(rp[2])) * ech * (1.0 if rp[1] == Vector3.ZERO else 0.5), 3.0)
		depart_carte.draw_rect(Rect2(c - Vector2(d, d), Vector2(d, d) * 2.0), Color(0.45, 0.45, 0.45))
		depart_carte.draw_string(police, c + Vector2(-45, -d - 4), rp[0], HORIZONTAL_ALIGNMENT_CENTER, 90, 12, Color(0.85, 0.85, 0.8))
	for l in LieuxDepart.LIEUX:
		var p: Vector3 = l.get("carte", l.get("ancre", Vector3(-110, 0, 125)))   # maison de Bellerive : quartier sud-ouest
		var c: Vector2 = vers.call(p)
		if l.id == lieu_choisi or lieu_choisi == "hasard":
			depart_carte.draw_arc(c, 9.0, 0, TAU, 20, Color(1, 1, 1), 2.0)
		depart_carte.draw_circle(c, 5.0, LieuxDepart.COULEURS[l.diff])


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
	depart_panel.visible = panel == depart_panel
	main_box.visible = panel == null


func _process(_delta: float) -> void:
	var vs := get_viewport_rect().size
	for p in [settings_panel, guide_panel, depart_panel]:
		if p and p.visible:
			p.position = (vs - p.size) / 2.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not main_box.visible:
		Game.save_settings()
		_show(null)


func _play() -> void:
	main_box.visible = false
	depart_panel.visible = false
	preload("res://scripts/ui/ecran_chargement.gd").lancer(get_tree())   # écran de chargement, puis main.tscn



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
	LieuxDepart.choix = "bellerive"
	Game.difficulte = 1
	_play()
