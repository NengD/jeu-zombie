extends CanvasLayer
## Carte (touche M) : routes, bâtiments, points stratégiques et position du joueur.

class MapView extends Control:
	func _draw() -> void:
		var vs := size
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.75))
		var side := minf(vs.x, vs.y) - 80.0
		var origin := (vs - Vector2(side, side)) / 2.0
		var m := Game.map_half
		var k := side / (2.0 * m)
		if Game.carte_relief:
			draw_texture_rect(Game.carte_relief, Rect2(origin, Vector2(side, side)), false)
		else:
			draw_rect(Rect2(origin, Vector2(side, side)), Color(0.2, 0.24, 0.15))
		for r in Game.map_rects:
			var rr: Rect2 = r.rect
			draw_rect(Rect2(origin + (rr.position + Vector2(m, m)) * k, rr.size * k), r.color)
		var font := ThemeDB.fallback_font
		for poi in Game.pois:
			var pp: Vector2 = origin + (Vector2(poi.pos.x, poi.pos.z) + Vector2(m, m)) * k
			draw_circle(pp, 6.0, poi.color)
			draw_string_outline(font, pp + Vector2(10, 5), poi.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
			draw_string(font, pp + Vector2(10, 5), poi.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		var p = Game.player
		if p:
			var pp2: Vector2 = origin + (Vector2(p.global_position.x, p.global_position.z) + Vector2(m, m)) * k
			var fwd: Vector3 = -p.global_basis.z
			var dir := Vector2(fwd.x, fwd.z).normalized()
			var perp := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([pp2 + dir * 12.0, pp2 - dir * 7.0 + perp * 7.0, pp2 - dir * 7.0 - perp * 7.0]), Color(1, 0.95, 0.3))
		draw_string_outline(font, origin + Vector2(0, -12), "CARTE  —  [M] pour fermer   (le nord est en haut)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color.BLACK)
		draw_string(font, origin + Vector2(0, -12), "CARTE  —  [M] pour fermer   (le nord est en haut)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.9, 0.7))


var view: MapView


func _ready() -> void:
	layer = 7
	view = MapView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.visible = false
	add_child(view)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("carte"):
		if view.visible:
			view.visible = false
			Game.ui_open = false
		elif not Game.ui_open and Game.player and Game.player.alive:
			view.visible = true
			Game.ui_open = true
		get_viewport().set_input_as_handled()
	elif view.visible and event.is_action_pressed("pause"):
		view.visible = false
		Game.ui_open = false
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if view.visible:
		view.queue_redraw()
