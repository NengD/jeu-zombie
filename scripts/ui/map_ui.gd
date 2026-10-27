extends CanvasLayer
## Carte (touche M) : relief, routes, bâtiments, points d'intérêt et position du joueur.
## Molette : zoom ; clic gauche maintenu : déplacer ; [Espace] : recentrer sur le joueur.
## Les petits lieux ne sont nommés qu'en zoomant (villes, villages et base toujours nommés).

class Cadre extends Control:
	var ui
	var zoom := 3.0
	var centre := Vector2.ZERO        # point du monde (x, z) au centre du cadre
	var glisse := false

	func _echelle() -> float:
		return size.x / (2.0 * Game.map_half) * zoom

	func vers_ecran(p: Vector2) -> Vector2:
		return size / 2.0 + (p - centre) * _echelle()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				_zoomer(1.25, mb.position)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				_zoomer(0.8, mb.position)
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				glisse = mb.pressed
			elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				ui.clic_droit(centre + (mb.position - size / 2.0) / _echelle(), mb.position)
			accept_event()
		elif event is InputEventMouseMotion and glisse:
			centre -= (event as InputEventMouseMotion).relative / _echelle()
			_borner()
			accept_event()

	func _zoomer(f: float, souris: Vector2) -> void:
		var avant := centre + (souris - size / 2.0) / _echelle()
		zoom = clampf(zoom * f, 1.0, 12.0)
		var apres := centre + (souris - size / 2.0) / _echelle()
		centre += avant - apres   # le point sous la souris reste en place
		_borner()

	func _borner() -> void:
		var m := Game.map_half
		centre = centre.clamp(Vector2(-m, -m), Vector2(m, m))

	func _draw() -> void:
		var m := Game.map_half
		var k := _echelle()
		var coin := vers_ecran(Vector2(-m, -m))
		if Game.carte_relief:
			draw_texture_rect(Game.carte_relief, Rect2(coin, Vector2(2.0 * m, 2.0 * m) * k), false)
		else:
			draw_rect(Rect2(coin, Vector2(2.0 * m, 2.0 * m) * k), Color(0.2, 0.24, 0.15))
		var vue := Rect2(Vector2.ZERO, size)
		for r in Game.map_rects:
			var rr: Rect2 = r.rect
			var re := Rect2(vers_ecran(rr.position), rr.size * k)
			if re.intersects(vue):
				draw_rect(re, r.color)
		var font := ThemeDB.fallback_font
		for poi in Game.pois:
			var pp := vers_ecran(Vector2(poi.pos.x, poi.pos.z))
			if not vue.grow(40.0).has_point(pp):
				continue
			var nom: String = poi.name
			var grand := nom in ["Bellerive", "Valmont"]
			var moyen := grand or nom.begins_with("Village") or nom.begins_with("Hameau") or nom.begins_with("Forêt") or nom.begins_with("Bois ") or nom == "Base militaire"
			# lieux dans une ville (boutiques, église…) : petit point, nommés seulement de près
			var en_ville: bool = not moyen and Game.in_city(poi.pos)
			# lieu déjà fouillé : grisé
			var fouille := Game.lieux_fouilles.has(Game.cle_lieu(poi))
			draw_circle(pp, 9.0 if grand else (4.5 if en_ville else 6.0), Color(0.45, 0.45, 0.45, 0.8) if fouille else poi.color)
			if fouille:
				nom += " (fouillé)"
			# noms : villes et villages toujours, le reste en zoomant (camps de bandits et lieux de ville encore plus près)
			var montrer := moyen or zoom >= (4.5 if nom == "Camp de bandits" else (5.0 if en_ville else 2.6))
			# campements de marchands : leur métier dès le zoom 1,2, leur nom complet de plus près
			if poi.get("marchand", false) and not montrer and zoom >= 1.2:
				montrer = true
				nom = poi.get("metiers", nom)
			if montrer:
				var taille := 24 if grand else (18 if moyen else 15)
				draw_string_outline(font, pp + Vector2(11, 6), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 4, Color.BLACK)
				draw_string(font, pp + Vector2(11, 6), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(0.7, 0.7, 0.7) if fouille else Color.WHITE)
		# marqueurs personnels (losanges orange)
		for mq in Game.marqueurs:
			var mp := vers_ecran(Vector2(mq.x, mq.z))
			if not vue.grow(40.0).has_point(mp):
				continue
			var losange := PackedVector2Array([mp + Vector2(0, -10), mp + Vector2(8, 0), mp + Vector2(0, 10), mp + Vector2(-8, 0)])
			draw_colored_polygon(losange, Color(1.0, 0.55, 0.1))
			losange.append(losange[0])
			draw_polyline(losange, Color.BLACK, 1.5)
			draw_string_outline(font, mp + Vector2(11, 6), mq.nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
			draw_string(font, mp + Vector2(11, 6), mq.nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.75, 0.4))
		# événements aléatoires en cours (evenements.gd) : triangle de couleur
		for ev in preload("res://scripts/evenements.gd").reperes:
			var ep := vers_ecran(Vector2(ev.x, ev.z))
			if not vue.grow(40.0).has_point(ep):
				continue
			var tri := PackedVector2Array([ep + Vector2(0, -11), ep + Vector2(10, 8), ep + Vector2(-10, 8)])
			draw_colored_polygon(tri, ev.couleur)
			tri.append(tri[0])
			draw_polyline(tri, Color.BLACK, 1.5)
			draw_string_outline(font, ep + Vector2(12, 6), ev.nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
			draw_string(font, ep + Vector2(12, 6), ev.nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ev.couleur.lightened(0.3))
		# ma base : petite maison bleue
		var base := Game.position_base()
		if base != Vector3.INF:
			var bp := vers_ecran(Vector2(base.x, base.z))
			if vue.grow(40.0).has_point(bp):
				draw_rect(Rect2(bp + Vector2(-7, -3), Vector2(14, 10)), Color(0.45, 0.7, 1.0))
				draw_colored_polygon(PackedVector2Array([bp + Vector2(-10, -3), bp + Vector2(0, -12), bp + Vector2(10, -3)]), Color(0.3, 0.5, 0.9))
				draw_rect(Rect2(bp + Vector2(-7, -3), Vector2(14, 10)), Color.BLACK, false, 1.5)
				draw_string_outline(font, bp + Vector2(13, 6), "Ma base", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color.BLACK)
				draw_string(font, bp + Vector2(13, 6), "Ma base", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.6, 0.8, 1.0))
		# ma voiture (dernière conduite, vehicule.gd) : petite voiture rose
		var vp3: Vector3 = preload("res://scripts/vehicule.gd").position_derniere()
		if vp3 != Vector3.INF:
			var vp := vers_ecran(Vector2(vp3.x, vp3.z))
			if vue.grow(40.0).has_point(vp):
				_voiture(vp, Color(0.95, 0.45, 0.9))
				draw_string_outline(font, vp + Vector2(13, 6), "Ma voiture", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color.BLACK)
				draw_string(font, vp + Vector2(13, 6), "Ma voiture", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.7, 0.95))
		var p = Game.player
		if p:
			var pp2 := vers_ecran(Vector2(p.global_position.x, p.global_position.z))
			var fwd: Vector3 = -p.global_basis.z
			var dir := Vector2(fwd.x, fwd.z).normalized()
			var perp := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([pp2 + dir * 13.0, pp2 - dir * 8.0 + perp * 8.0, pp2 - dir * 8.0 - perp * 8.0]), Color(1, 0.95, 0.3))
		# échelle : barre de 500 m
		var lg := 500.0 * k
		var b0 := Vector2(16.0, size.y - 20.0)
		draw_line(b0, b0 + Vector2(lg, 0), Color.WHITE, 3.0)
		draw_string_outline(font, b0 + Vector2(0, -8), "500 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.BLACK)
		draw_string(font, b0 + Vector2(0, -8), "500 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

	## Petite voiture de profil (caisse, toit, deux roues) : « Ma voiture ».
	func _voiture(c: Vector2, col: Color) -> void:
		draw_rect(Rect2(c + Vector2(-9, -3), Vector2(18, 7)), col)
		draw_rect(Rect2(c + Vector2(-5, -8), Vector2(10, 6)), col.darkened(0.15))
		draw_rect(Rect2(c + Vector2(-9, -3), Vector2(18, 7)), Color.BLACK, false, 1.5)
		draw_circle(c + Vector2(-5, 5), 2.6, Color.BLACK)
		draw_circle(c + Vector2(5, 5), 2.6, Color.BLACK)


class MapView extends Control:
	var legende := true   # [L] : afficher / masquer la légende
	const LEGENDE := [
		["rond", Color(0.95, 0.95, 0.95), "Ville"],
		["rond", Color(0.9, 0.7, 0.45), "Village, ferme, campagne"],
		["rond", Color(0.4, 0.9, 0.5), "Campement de marchands (sûr)"],
		["rond", Color(0.95, 0.2, 0.15), "Bandits, zone infestée"],
		["rond", Color(0.6, 0.8, 0.3), "Militaire"],
		["rond", Color(0.35, 0.55, 1.0), "Police"],
		["rond", Color(1.0, 0.35, 0.35), "Hôpital"],
		["rond", Color(1.0, 0.9, 0.3), "Station-service"],
		["rond", Color(1.0, 0.75, 0.3), "Commerce"],
		["rond", Color(0.4, 0.65, 0.95), "Eau"],
		["rond", Color(0.45, 0.45, 0.45), "Lieu déjà fouillé"],
		["losange", Color(1.0, 0.55, 0.1), "Mon marqueur (clic droit)"],
		["maison", Color(0.45, 0.7, 1.0), "Ma base"],
		["voiture", Color(0.95, 0.45, 0.9), "Ma voiture"],
		["fleche", Color(1, 0.95, 0.3), "Toi"],
	]

	func _dessiner_legende(cadre: Control, font: Font) -> void:
		var lg := 250.0
		var h := 34.0 + LEGENDE.size() * 22.0
		# à droite de la carte s'il y a la place, sinon dans son coin haut droit
		var o := cadre.position + Vector2(cadre.size.x + 18.0, 0)
		if o.x + lg > size.x - 8.0:
			o = cadre.position + Vector2(cadre.size.x - lg - 8.0, 8.0)
		draw_rect(Rect2(o, Vector2(lg, h)), Color(0, 0, 0, 0.6))
		draw_string(font, o + Vector2(10, 22), "LÉGENDE  [L]", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.9, 0.7))
		for i in LEGENDE.size():
			var e: Array = LEGENDE[i]
			var c := o + Vector2(20, 44 + i * 22.0)
			var col: Color = e[1]
			match e[0]:
				"rond":
					draw_circle(c, 6.0, col)
				"losange":
					draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 0), c + Vector2(0, 8), c + Vector2(-6, 0)]), col)
				"maison":
					draw_rect(Rect2(c + Vector2(-6, -2), Vector2(12, 8)), col)
					draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -2), c + Vector2(0, -9), c + Vector2(8, -2)]), Color(0.3, 0.5, 0.9))
				"fleche":
					draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 6), c + Vector2(-6, 6)]), col)
				"voiture":
					_voiture(c, col)
			draw_string(font, c + Vector2(16, 5), e[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

	## Même symbole que dans Cadre, pour la légende.
	func _voiture(c: Vector2, col: Color) -> void:
		draw_rect(Rect2(c + Vector2(-9, -3), Vector2(18, 7)), col)
		draw_rect(Rect2(c + Vector2(-5, -8), Vector2(10, 6)), col.darkened(0.15))
		draw_rect(Rect2(c + Vector2(-9, -3), Vector2(18, 7)), Color.BLACK, false, 1.5)
		draw_circle(c + Vector2(-5, 5), 2.6, Color.BLACK)
		draw_circle(c + Vector2(5, 5), 2.6, Color.BLACK)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.8))
		var font := ThemeDB.fallback_font
		if legende and get_child_count() > 0:
			_dessiner_legende(get_child(0), font)
		var titre := "CARTE  —  [M] fermer   molette : zoom   clic maintenu : déplacer   clic droit : poser / retirer un marqueur   [Espace] : recentrer   [L] : légende"
		var cadre: Control = get_child(0)
		draw_string_outline(font, cadre.position + Vector2(0, -12), titre, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color.BLACK)
		draw_string(font, cadre.position + Vector2(0, -12), titre, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.9, 0.7))
		# campement de marchands le plus proche : distance et direction
		var p = Game.player
		if p:
			var mc := Game.marchand_proche(p.global_position)
			if not mc.is_empty():
				var v := Vector2(mc.pos.x - p.global_position.x, mc.pos.z - p.global_position.z)
				var t := "Marchands les plus proches : %s — %d m au %s" % [mc.name, int(v.length()), Game.cardinal(v)]
				var bas := cadre.position + Vector2(0, cadre.size.y + 26)
				draw_string_outline(font, bas, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color.BLACK)
				draw_string(font, bas, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.55, 1.0, 0.6))


var view: MapView
var cadre: Cadre


func _ready() -> void:
	layer = 7
	view = MapView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.visible = false
	add_child(view)
	cadre = Cadre.new()
	cadre.clip_contents = true
	cadre.mouse_filter = Control.MOUSE_FILTER_STOP
	cadre.ui = self
	view.add_child(cadre)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("carte"):
		if view.visible:
			_fermer()
		elif not Game.ui_open and Game.player and Game.player.alive:
			view.visible = true
			Game.ui_open = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_recentrer()
		get_viewport().set_input_as_handled()
	elif view.visible and event.is_action_pressed("pause"):
		_fermer()
		get_viewport().set_input_as_handled()
	elif view.visible and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_SPACE:
		_recentrer()
		get_viewport().set_input_as_handled()
	elif view.visible and event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_L:
		view.legende = not view.legende
		get_viewport().set_input_as_handled()


## Clic droit : retire le marqueur sous la souris, sinon demande un nom pour en poser un.
var saisie: LineEdit = null
var saisie_pos := Vector2.ZERO


func clic_droit(monde: Vector2, ecran: Vector2) -> void:
	for mq in Game.marqueurs:
		if cadre.vers_ecran(Vector2(mq.x, mq.z)).distance_to(ecran) < 12.0:
			Game.marqueurs.erase(mq)
			Game.msg("Marqueur retiré : %s" % mq.nom)
			return
	if Game.marqueurs.size() >= 40:
		Game.msg("Trop de marqueurs (40 au plus).")
		return
	_fermer_saisie()
	saisie_pos = monde
	saisie = LineEdit.new()
	saisie.placeholder_text = "Nom du marqueur (Entrée)"
	saisie.max_length = 28
	saisie.add_theme_font_size_override("font_size", 16)
	saisie.custom_minimum_size = Vector2(240, 0)
	saisie.position = (cadre.position + ecran + Vector2(12, -14)).min(view.size - Vector2(250, 40))
	view.add_child(saisie)
	saisie.text_submitted.connect(func(t: String):
		var nom := t.strip_edges()
		Game.marqueurs.append({"nom": nom if nom != "" else "Marqueur %d" % (Game.marqueurs.size() + 1), "x": saisie_pos.x, "z": saisie_pos.y})
		_fermer_saisie())
	saisie.focus_exited.connect(_fermer_saisie)
	saisie.grab_focus()


func _fermer_saisie() -> void:
	if saisie and is_instance_valid(saisie):
		var s := saisie
		saisie = null
		s.queue_free()


func _fermer() -> void:
	_fermer_saisie()
	view.visible = false
	Game.ui_open = false
	Game.capturer_souris()


func _recentrer() -> void:
	var p = Game.player
	if p:
		cadre.centre = Vector2(p.global_position.x, p.global_position.z)
		cadre._borner()


func _process(_delta: float) -> void:
	if view.visible:
		var vs := view.size
		var side := minf(vs.x, vs.y) - 80.0
		cadre.position = (vs - Vector2(side, side)) / 2.0 + Vector2(0, 10)
		cadre.size = Vector2(side, side)
		view.queue_redraw()
		cadre.queue_redraw()
