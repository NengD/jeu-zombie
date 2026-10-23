extends CanvasLayer
## Carte (touche M) : relief, routes, bâtiments, points d'intérêt et position du joueur.
## Molette : zoom ; clic gauche maintenu : déplacer ; [Espace] : recentrer sur le joueur.
## Les petits lieux ne sont nommés qu'en zoomant (villes, villages et base toujours nommés).

class Cadre extends Control:
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
			draw_circle(pp, 9.0 if grand else (4.5 if en_ville else 6.0), poi.color)
			# noms : villes et villages toujours, le reste en zoomant (camps de bandits et lieux de ville encore plus près)
			var montrer := moyen or zoom >= (4.5 if nom == "Camp de bandits" else (5.0 if en_ville else 2.6))
			if montrer:
				var taille := 24 if grand else (18 if moyen else 15)
				draw_string_outline(font, pp + Vector2(11, 6), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 4, Color.BLACK)
				draw_string(font, pp + Vector2(11, 6), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color.WHITE)
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


class MapView extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.8))
		var font := ThemeDB.fallback_font
		var titre := "CARTE  —  [M] fermer   molette : zoom   clic maintenu : déplacer   [Espace] : recentrer   (nord en haut)"
		var cadre: Control = get_child(0)
		draw_string_outline(font, cadre.position + Vector2(0, -12), titre, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color.BLACK)
		draw_string(font, cadre.position + Vector2(0, -12), titre, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.9, 0.7))


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


func _fermer() -> void:
	view.visible = false
	Game.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
