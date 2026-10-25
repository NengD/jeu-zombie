extends CanvasLayer
const Textes = preload("res://scripts/ui/textes.gd")
const Fleche = preload("res://scripts/fleche.gd")
## Interface en jeu : réticule, jauges, arme, barre rapide, messages,
## heure, aide (F1), pause (Échap), écran de mort.

## Boussole en haut de l'écran : directions (N, NE, E…) sur ±90° autour du regard, marqueurs personnels,
## campement de marchands le plus proche et lieux à moins de 300 m (avec la distance).
class Boussole extends Control:
	const LARGEUR := 640.0
	const CHAMP := 180.0     # degrés visibles

	func _draw() -> void:
		var p = Game.player
		if p == null or p.camera == null:
			return
		var fwd: Vector3 = -p.camera.global_basis.z
		var cap := rad_to_deg(atan2(fwd.x, -fwd.z))
		var font := ThemeDB.fallback_font
		var x0 := (size.x - LARGEUR) / 2.0
		draw_rect(Rect2(x0, 6, LARGEUR, 28), Color(0, 0, 0, 0.4))
		var noms := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SO", 270: "O", 315: "NO"}
		for deg in range(0, 360, 15):
			var dx := wrapf(deg - cap, -180.0, 180.0)
			if absf(dx) > CHAMP / 2.0:
				continue
			var x := size.x / 2.0 + dx / CHAMP * LARGEUR
			if noms.has(deg):
				var t: String = noms[deg]
				var fs := 20 if t.length() == 1 else 15
				var col := Color(1.0, 0.45, 0.35) if t == "N" else Color.WHITE
				draw_string_outline(font, Vector2(x - 6.0 * t.length(), 28), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color.BLACK)
				draw_string(font, Vector2(x - 6.0 * t.length(), 28), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			else:
				draw_line(Vector2(x, 10), Vector2(x, 16), Color(1, 1, 1, 0.6), 1.5)
		draw_line(Vector2(size.x / 2.0, 4), Vector2(size.x / 2.0, 36), Color(1.0, 0.85, 0.3), 2.0)
		# repères : marqueurs, marchands, lieux proches
		var pos: Vector3 = p.global_position
		var reperes: Array = []
		for mq in Game.marqueurs:
			reperes.append([Vector2(mq.x, mq.z), mq.nom, Color(1.0, 0.6, 0.15)])
		var mc := Game.marchand_proche(pos)
		if not mc.is_empty():
			reperes.append([Vector2(mc.pos.x, mc.pos.z), "Marchands", Color(0.45, 1.0, 0.55)])
		var base := Game.position_base()
		if base != Vector3.INF:
			reperes.append([Vector2(base.x, base.z), "Ma base", Color(0.45, 0.7, 1.0)])
		for poi in Game.pois:
			if poi.get("marchand", false):
				continue
			var d2 := Vector2(poi.pos.x - pos.x, poi.pos.z - pos.z).length()
			if d2 < 300.0 and d2 > 15.0 and not Game.in_city(poi.pos):
				reperes.append([Vector2(poi.pos.x, poi.pos.z), poi.name, Color(0.85, 0.85, 0.85, 0.85)])
		var occupes: Array = []   # étiquettes déjà écrites (Rect2) : on décale les suivantes d'une ligne
		for r in reperes:
			var v: Vector2 = r[0] - Vector2(pos.x, pos.z)
			var dist := v.length()
			if dist < 4.0:
				continue
			var dx := wrapf(rad_to_deg(atan2(v.x, -v.y)) - cap, -180.0, 180.0)
			var hors := absf(dx) > CHAMP / 2.0
			var x := size.x / 2.0 + clampf(dx, -CHAMP / 2.0, CHAMP / 2.0) / CHAMP * LARGEUR
			var col: Color = r[2]
			if hors:
				col.a *= 0.45
			draw_colored_polygon(PackedVector2Array([Vector2(x, 36), Vector2(x - 6, 44), Vector2(x + 6, 44)]), col)
			if not hors:
				var t := "%s %s" % [r[1], ("%d m" % int(dist)) if dist < 1000.0 else ("%.1f km" % (dist / 1000.0))]
				var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
				var y := 58.0
				for essai in 4:
					var libre := true
					for o in occupes:
						if (o as Rect2).intersects(Rect2(x - w / 2.0 - 4.0, y - 12.0, w + 8.0, 14.0)):
							libre = false
					if libre:
						break
					y += 15.0
				occupes.append(Rect2(x - w / 2.0 - 4.0, y - 12.0, w + 8.0, 14.0))
				draw_string_outline(font, Vector2(x - w / 2.0, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
				draw_string(font, Vector2(x - w / 2.0, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)


class Crosshair extends Control:
	var spread := 6.0
	var hit := 0.0
	var head := false
	var vise := false   # en visée : on utilise le viseur de l'arme, pas de réticule
	var melee := false  # arme de mêlée / mains nues : simple point
	var ennemi := false # le réticule passe sur un zombie ou un bandit
	var bloque := Vector2(-1, -1)   # point d'impact réel quand un obstacle coupe la ligne de tir
	var impacts: Array = []         # [angle (0 = devant, sens horaire), opacité] des coups reçus
	var arc := -1.0                 # arc tenu : tension (0..1), sinon -1
	var chute: Array = []            # arc : écart à l'écran du point d'impact à 20, 40 et 60 m

	func _draw() -> void:
		var c := size / 2.0
		var col := Color(1, 0.35, 0.3, 0.9) if ennemi else Color(1, 1, 1, 0.85)
		var g := spread
		if arc >= 0.0:
			# viseur d'arc : cercle qui se resserre avec la tension, repères de chute en dessous (20, 40, 60 m)
			var r := lerpf(30.0, 7.0, arc)
			draw_arc(c, r, 0.0, TAU, 32, Color(0, 0, 0, 0.35), 3.0)
			draw_arc(c, r, 0.0, TAU, 32, col, 1.5)
			draw_circle(c, 1.8, col)
			for k in 3:
				var y := c.y + (float(chute[k]) if k < chute.size() else 14.0 + k * 13.0)
				draw_line(Vector2(c.x - 6 + k * 1.5, y), Vector2(c.x + 6 - k * 1.5, y), Color(col, 0.6), 1.5)
		elif melee:
			draw_circle(c, 3.0, Color(0, 0, 0, 0.35))
			draw_circle(c, 2.0, col)
		elif not vise:
			draw_line(c + Vector2(-g - 8, 0), c + Vector2(-g, 0), col, 2.0)
			draw_line(c + Vector2(g, 0), c + Vector2(g + 8, 0), col, 2.0)
			draw_line(c + Vector2(0, -g - 8), c + Vector2(0, -g), col, 2.0)
			draw_line(c + Vector2(0, g), c + Vector2(0, g + 8), col, 2.0)
			draw_circle(c, 1.5, col)
		# arcs rouges autour du centre, du côté d'où viennent les coups
		var r_imp := minf(size.x, size.y) * 0.17
		for imp in impacts:
			var a: float = imp[0]
			var ic := Color(0.95, 0.12, 0.08, 0.9 * float(imp[1]))
			draw_arc(c, r_imp, a - PI / 2.0 - 0.32, a - PI / 2.0 + 0.32, 14, ic, 7.0, true)
			var pointe := c + Vector2(sin(a), -cos(a)) * (r_imp + 16.0)
			var g2 := Vector2(cos(a), sin(a)) * 9.0
			var base := c + Vector2(sin(a), -cos(a)) * (r_imp + 5.0)
			draw_colored_polygon(PackedVector2Array([pointe, base + g2, base - g2]), ic)
		if bloque.x >= 0.0:
			# croix orange : la balle s'arrêtera là (mur, rebord, voiture…)
			var oc := Color(1.0, 0.6, 0.15, 0.9)
			draw_arc(bloque, 6.0, 0.0, TAU, 16, oc, 1.5)
			draw_line(bloque + Vector2(-4, -4), bloque + Vector2(4, 4), oc, 1.5)
			draw_line(bloque + Vector2(-4, 4), bloque + Vector2(4, -4), oc, 1.5)
		if hit > 0.0:
			var hc := Color(1, 0.25, 0.2, hit) if head else Color(1, 1, 1, hit)
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * 6.0, c + d * 13.0, hc, 2.5)


var root: Control
var cible_reticule: Node = null    # zombie, bandit ou animal sous le réticule (barre de vie)
var lbl_niveau: Label
var barre_xp: ProgressBar
var lbl_gain: Label
var gain_t := 0.0
var gain_xp := 0
var gain_comp := ""
var prog_connecte := false
var cross: Crosshair
var boussole: Boussole
var bars := {}
var lbl_weapon: Label
var lbl_ammo: Label
var lbl_prompt: Label
var lbl_info: Label
var lbl_alerte: Label        # alerte de horde (haut de l'écran)
var lbl_cache: Label         # « Caché » sous le réticule quand on est dans un buisson
var lbl_charge: Label        # poids porté / seuil de ralentissement (sous les jauges)
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
	flash.color = Color.WHITE
	var mat_vignette := ShaderMaterial.new()
	mat_vignette.shader = preload("res://shaders/vignette_degats.gdshader")
	flash.material = mat_vignette
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	cross = Crosshair.new()
	cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)
	boussole = Boussole.new()
	boussole.set_anchors_preset(Control.PRESET_FULL_RECT)
	boussole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boussole)
	# fil des objets reçus (« +12 Balles 9 mm »), à gauche, au tiers de la hauteur
	var fil: VBoxContainer = preload("res://scripts/ui/fil_objets.gd").new()
	fil.anchor_top = 0.36
	fil.anchor_bottom = 0.36
	fil.offset_left = 24.0
	root.add_child(fil)
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
	lbl_charge = _label("", 15)
	bar_box.add_child(lbl_charge)
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
	lbl_cache = _label("", 20)
	lbl_cache.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_cache.label_settings.font_color = Color(0.65, 0.95, 0.6)
	lbl_cache.visible = false
	root.add_child(lbl_cache)
	lbl_alerte = _label("", 34)
	lbl_alerte.label_settings.outline_size = 10
	lbl_alerte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_alerte.label_settings.font_color = Color(1.0, 0.25, 0.2)
	root.add_child(lbl_alerte)
	lbl_info = _label("", 17)
	lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(lbl_info)
	msg_box = VBoxContainer.new()
	msg_box.position = Vector2(24, 24)
	root.add_child(msg_box)
	help_panel = _panel(_help_text(), Vector2(620, 0))
	help_panel.visible = false
	pause_panel = _menu_panel("PAUSE", [["Reprendre", _resume], ["Sauvegarder (F5)", _sauver], ["Charger la sauvegarde (F9)", _charger], ["Commandes (F1)", _toggle_help], ["Paramètres", _ouvrir_parametres], ["Sauvegarder et menu principal", _sauver_menu], ["Quitter le jeu", _quit]])
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
	var degats = preload("res://scripts/ui/degats_ui.gd").new()
	degats.hud = self
	root.add_child(degats)
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
	# caché dans un buisson : les zombies te voient beaucoup moins
	# (ou soin en cours : objet et temps restant)
	lbl_cache.visible = p.alive and not Game.ui_open and (p.cache_buisson or p.soin_t > 0.0 or p.fab_n > 0)
	if lbl_cache.visible:
		if p.fab_n > 0 and p.soin_t <= 0.0:
			lbl_cache.text = "Fabrication : %s %d / %d — %d %%" % [Items.nom(p.fab_r.out), p.fab_total - p.fab_n + 1, p.fab_total, int(p.progression_fabrication() * 100.0)]
			lbl_cache.label_settings.font_color = Color(0.85, 0.9, 1.0)
		elif p.soin_t > 0.0:
			lbl_cache.text = "Soin : %s — %.1f s" % [Items.nom(p.soin_id), p.soin_t]
			lbl_cache.label_settings.font_color = Color(1.0, 0.85, 0.5)
		else:
			lbl_cache.text = "Caché (accroupi)" if p.crouching else "Caché"
			lbl_cache.label_settings.font_color = Color(0.65, 0.95, 0.6)
		lbl_cache.size = Vector2(440, 30)
		lbl_cache.position = vs / 2.0 + Vector2(-220, 42)
	_maj_alerte(vs, p)
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
	var kg: float = p.charge()
	var seuil: float = p.charge_max()
	lbl_charge.text = "Charge  %.1f / %.0f kg%s" % [kg, seuil, ("   — ralenti -%d %%" % int((1.0 - p.facteur_charge()) * 100.0)) if kg > seuil else ""]
	lbl_charge.label_settings.font_color = Color(1.0, 0.5, 0.35) if kg > seuil else (Color(1.0, 0.85, 0.45) if kg > seuil * 0.85 else Color(0.85, 0.85, 0.8))
	# bords rouges : montent sous 60 % de santé, battent sous 25 % ; éclair à chaque coup reçu
	var k_sante: float = p.health / p.prog.sante_max()
	var force := clampf((0.6 - k_sante) / 0.6, 0.0, 1.0) * 0.75
	if k_sante < 0.25 and p.alive:
		force += 0.12 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006))
	var mv := flash.material as ShaderMaterial
	mv.set_shader_parameter("force", force)
	mv.set_shader_parameter("eclair", clampf(p.hurt_flash, 0.0, 1.0))
	# flèches de dégâts : direction de chaque attaquant récent, vue depuis la caméra (haut de l'écran = devant)
	cross.impacts.clear()
	if p.camera:
		var cb: Basis = p.camera.global_basis
		for imp in p.impacts_recus:
			var v: Vector3 = (imp[0] as Vector3) - p.camera.global_position
			var dx := v.dot(cb.x)
			var dz := v.dot(-cb.z)
			cross.impacts.append([atan2(dx, dz), clampf(float(imp[1]) / 0.6, 0.0, 1.0)])
	var wid: String = p.current_weapon()
	var w := Items.info(wid)
	lbl_weapon.text = Items.nom(wid)
	if w.get("type", "") == "gun":
		if p.reload_t > 0.0:
			lbl_ammo.text = "Rechargement…"
		else:
			lbl_ammo.text = ("PRÊT  " if p.arme_prete_t > 0.0 else "") + "%d / %d" % [int(p.mags.get(wid, 0)), p.count(w.ammo)]
	elif w.get("type", "") == "arc":
		lbl_ammo.text = "%d flèche%s" % [p.count("fleche"), "s" if p.count("fleche") > 1 else ""]
	elif w.get("type", "") == "lancer":
		lbl_ammo.text = "× %d" % p.count(wid)
	else:
		lbl_ammo.text = ""
	# munitions en vert juste après le rechargement, en orange quand le chargeur est presque vide
	var col_mun := Color.WHITE
	if w.get("type", "") == "gun" and p.reload_t <= 0.0:
		if p.arme_prete_t > 0.0:
			col_mun = Color(0.45, 1.0, 0.45)
		elif int(p.mags.get(wid, 0)) <= maxi(1, int(int(w.get("mag", 10)) * 0.2)):
			col_mun = Color(1.0, 0.6, 0.2)
	lbl_ammo.label_settings.font_color = col_mun
	for i in 5:
		var id: String = p.hotbar[i]
		var txt := "—"
		if id != "":
			txt = Items.nom(id)
			if not Items.is_weapon(id) or Items.info(id).get("type", "") == "lancer":
				txt += " ×%d" % p.count(id)
		hot_labels[i].text = ("[%d] %s" if p.hotbar_verrou[i] else "%d  %s") % [i + 1, txt]
		var tex: Texture2D = Items.icon(id) if id != "" else null
		hot_icons[i].texture = tex
		hot_icons[i].modulate = Items.category_color(id) if tex and String(tex.resource_path).ends_with(".svg") else Color.WHITE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.85, 0.75, 0.3, 0.55) if i == p.slot else Color(0, 0, 0, 0.45)
		sb.set_corner_radius_all(4)
		hot_panels[i].add_theme_stylebox_override("panel", sb)
	lbl_prompt.text = p.prompt
	var zone_name := ""
	if not p.in_zone.is_empty():
		zone_name = p.in_zone.name if p.in_zone.name != "" else "Intérieur"
		var nz := Game.zombies_in_zone(p.in_zone)
		zone_name += "  —  bâtiment sûr" if nz == 0 else "  —  %d zombie(s) à l'intérieur" % nz
	var hh := int(Game.time_hours)
	var mm := int((Game.time_hours - hh) * 60.0)
	if p.maladie > 0.0:
		zone_name += "\nMALADE (intoxication) : %d min" % ceili(p.maladie / 60.0)
	lbl_info.text = "Jour %d — %02d:%02d%s\nArgent : %d €\n%s" % [
		Game.day, hh, mm, "  (nuit)" if Game.is_night() else "", p.argent, zone_name]
	# réticule dynamique : écart = vraie dispersion du tir projetée à l'écran (+ recul en cours)
	var cw: String = p.current_weapon()
	var ws: Dictionary = p.arme_stats(cw)
	cross.melee = not ws.get("type", "") in ["gun", "arc"]
	cross.arc = p.arc_tension if cw == "arc" else -1.0
	if cw == "arc" and p.camera:
		cross.chute.clear()
		var v := lerpf(20.0, 62.0, maxf(p.arc_tension, 0.35))
		var demi_fov := tan(deg_to_rad(p.camera.fov) * 0.5)
		for d in [20.0, 40.0, 60.0]:
			var t: float = d / v
			cross.chute.append(clampf(0.5 * Fleche.GRAVITE * t * t / d / demi_fov * cross.size.y * 0.5, 4.0, 300.0))
	var target_spread := 4.0
	if not cross.melee and p.camera:
		var demi := deg_to_rad(p.camera.fov) * 0.5
		var px := tan(deg_to_rad(p.dispersion(ws))) / tan(demi) * cross.size.y * 0.5
		target_spread = clampf(3.0 + px + absf(p.rec_rot.x) * 40.0, 3.0, 120.0)
	cross.spread = lerpf(cross.spread, target_spread, minf(1.0, delta * 14.0))
	cross.ennemi = _vise_ennemi(p, float(ws.get("range", 3.0)) if not cross.melee else 3.5)
	cross.bloque = Vector2(-1, -1) if cross.melee else _point_bloque(p, float(ws.get("range", 80.0)))
	cross.visible = p.alive and not Game.ui_open
	boussole.visible = p.alive and not Game.ui_open
	if boussole.visible:
		boussole.queue_redraw()
	cross.vise = false   # 3e personne : réticule toujours affiché
	cross.queue_redraw()


## Le tir part de la tête du personnage, pas de la caméra (décalée sur l'épaule) : si un obstacle
## coupe la ligne de tir avant le point visé, renvoie sa position à l'écran (sinon (-1, -1)).
func _point_bloque(p: Node, portee: float) -> Vector2:
	if p.camera == null:
		return Vector2(-1, -1)
	var vise: Vector3 = p._aim_point(portee)
	var depart: Vector3 = p.lean_pivot.global_position
	var q := PhysicsRayQueryParameters3D.create(depart, vise, Game.LAYER_WORLD | Game.LAYER_ZOMBIE, [p.get_rid()])
	var hit: Dictionary = (p.get_world_3d() as World3D).direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit.position as Vector3).distance_to(vise) < 0.3:
		return Vector2(-1, -1)
	if p.camera.is_position_behind(hit.position):
		return Vector2(-1, -1)
	return p.camera.unproject_position(hit.position)


## Le rayon du réticule touche-t-il un zombie ou un bandit (à portée de l'arme) ?
func _vise_ennemi(p: Node, portee: float) -> bool:
	if p.camera == null:
		return false
	var from: Vector3 = p.camera.global_position
	var to: Vector3 = from - p.camera.global_basis.z * (portee + p.recul_camera())
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.LAYER_WORLD | Game.LAYER_ZOMBIE, [p.get_rid()])
	var hit: Dictionary = (p.get_world_3d() as World3D).direct_space_state.intersect_ray(q)
	var n: Node = hit.get("collider")
	cible_reticule = null
	for i in 4:
		if n == null:
			return false
		if n.is_in_group("animaux"):
			cible_reticule = n
			return false
		if n.is_in_group("zombies") or n.is_in_group("bandits"):
			cible_reticule = n
			# dead_t / mort_t ne comptent qu'après la mort
			return float(n.get("dead_t") if n.get("dead_t") != null else 0.0) <= 0.0 and float(n.get("mort_t") if n.get("mort_t") != null else 0.0) <= 0.0
		n = n.get_parent()
	return false


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
	root.get_node("Jauges").position = Vector2(24, vs.y - 164)
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
		if parametres and parametres.visible:
			pass   # l'écran Paramètres gère lui-même Échap
		elif paused:
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
		boss_box.position = Vector2(-260, 60)
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
	boss_box.position.y = 60.0
	boss_barre.value = boss.health


## Alerte de horde : gros texte rouge clignotant en haut de l'écran.
func _maj_alerte(vs: Vector2, p: Node) -> void:
	var main: Node = p.get_parent() if p else null
	var t: String = main.texte_alerte() if main and main.has_method("texte_alerte") else ""
	lbl_alerte.text = t
	lbl_alerte.visible = t != ""
	if t == "":
		return
	lbl_alerte.position = Vector2(0, vs.y * 0.1)
	lbl_alerte.size = Vector2(vs.x, 40)
	lbl_alerte.modulate.a = 0.8 + 0.2 * sin(Time.get_ticks_msec() / 160.0)


## Menu pause : passe au niveau de qualité graphique suivant (Bas → Moyen → Élevé → Ultra).
## Paramètres depuis le menu pause (même écran que le menu principal, appliqués tout de suite).
var parametres: PanelContainer = null


func _ouvrir_parametres() -> void:
	if parametres == null:
		parametres = preload("res://scripts/ui/parametres_ui.gd").new()
		parametres.ferme.connect(func(): pause_panel.visible = paused)
		root.add_child(parametres)
	pause_panel.visible = false
	parametres.visible = true
	parametres.reset_size()
	var vs := root.get_viewport_rect().size
	parametres.position = ((vs - parametres.size) / 2.0).max(Vector2.ZERO)


func _qualite_suivante() -> void:
	Game.qualite = (Game.qualite + 1) % Game.NOMS_QUALITE.size()
	Game.save_settings()
	for b in pause_panel.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Qualité graphique"):
			(b as Button).text = "Qualité graphique : " + Game.NOMS_QUALITE[Game.qualite]
	Game.msg("Qualité graphique : " + Game.NOMS_QUALITE[Game.qualite])
