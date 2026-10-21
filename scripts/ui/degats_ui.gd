extends Control
## Chiffres de dégâts qui s'envolent au-dessus de la cible touchée par le joueur (plus gros et orangés
## pour un tir à la tête, dorés pour un coup critique) et petite barre de vie au-dessus des ennemis
## touchés ou visés, à portée, qui s'efface après quelques secondes.
## Tout est dessiné par ce seul nœud (aucun nœud par zombie) : quelques projections par image.

const DUREE_NOMBRE := 0.9
const DUREE_BARRE := 4.0          # barre visible après le dernier coup (ou tant qu'on vise, + 1,5 s)
const PORTEE_BARRE := 40.0
const MAX_NOMBRES := 40

var nombres: Array = []           # {pos: Vector3, txt, col: Color, taille, t, dx}
var barres := {}                  # cible -> temps restant
var hud: Node = null              # pour savoir quel ennemi est sous le réticule


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.degats_infliges.connect(_on_degats)
	Game.texte_flottant.connect(func(pos: Vector3, txt: String, col: Color):
		if nombres.size() >= MAX_NOMBRES:
			nombres.pop_front()
		nombres.append({"pos": pos, "txt": txt, "col": col, "taille": 18, "t": 0.0, "dx": 0.0}))


func _on_degats(cible: Node3D, montant: float, pos: Vector3, genre: int) -> void:
	if montant < 0.5:
		return
	var col := Color(1.0, 0.96, 0.85)
	var taille := 20
	var txt := str(int(round(montant)))
	if genre == 1:
		col = Color(1.0, 0.42, 0.18)
		taille = 30
	elif genre == 2:
		col = Color(1.0, 0.84, 0.15)
		taille = 27
		txt += " !"
	if nombres.size() >= MAX_NOMBRES:
		nombres.pop_front()
	nombres.append({"pos": pos + Vector3.UP * 0.25, "txt": txt, "col": col, "taille": taille, "t": 0.0, "dx": randf_range(-18.0, 18.0)})
	if is_instance_valid(cible):
		barres[cible] = DUREE_BARRE


func _process(delta: float) -> void:
	var p = Game.player
	if p == null or p.camera == null:
		return
	for n in nombres:
		n.t += delta
	while not nombres.is_empty() and nombres[0].t >= DUREE_NOMBRE:
		nombres.pop_front()
	# ennemi sous le réticule : sa barre reste affichée
	var vise = hud.get("cible_reticule") if hud else null
	if vise != null and is_instance_valid(vise) and not _mort(vise):
		barres[vise] = maxf(float(barres.get(vise, 0.0)), 1.5)
	for c in barres.keys():
		barres[c] -= delta
		if barres[c] <= 0.0 or not is_instance_valid(c) or _mort(c):
			barres.erase(c)
	visible = not Game.ui_open
	if visible and (not nombres.is_empty() or not barres.is_empty()):
		queue_redraw()


func _mort(n: Node) -> bool:
	if n.get("etat") != null:
		return int(n.etat) == 3
	return n.get("state") != null and int(n.state) == 3


## Vie actuelle et maximale (la maximale est notée au premier coup : `pv_max` en méta).
func _vie(n: Node) -> Vector2:
	var cur: float = float(n.pv) if n.get("pv") != null else float(n.get("health"))
	var mx: float = float(n.pv_max) if n.get("pv_max") != null else float(n.get_meta("pv_max", cur))
	return Vector2(cur, maxf(mx, 1.0))


func _hauteur(n: Node) -> float:
	if n.get("etat") != null:
		return float(n.TYPES[n.kind].get("haut", 1.0)) + 0.45
	return 2.05 * float(n.get("echelle") if n.get("echelle") != null else 1.0)


func _draw() -> void:
	var cam: Camera3D = Game.player.camera
	var police := get_theme_default_font()
	var oeil := cam.global_position
	for c in barres:
		var n: Node3D = c
		var pos := n.global_position + Vector3.UP * _hauteur(n)
		var d := oeil.distance_to(pos)
		if d > PORTEE_BARRE or cam.is_position_behind(pos):
			continue
		var v := _vie(n)
		var k := clampf(v.x / v.y, 0.0, 1.0)
		var a := clampf(float(barres[c]) / 0.6, 0.0, 1.0)
		var larg := clampf(900.0 / maxf(d, 1.0), 34.0, 90.0)
		var ec := cam.unproject_position(pos)
		var r := Rect2(ec - Vector2(larg * 0.5, 0), Vector2(larg, 5.0))
		draw_rect(r.grow(1.0), Color(0, 0, 0, 0.65 * a))
		var col := Color(0.85, 0.15, 0.12).lerp(Color(0.95, 0.8, 0.2), clampf(k * 2.0, 0.0, 1.0)) if k < 0.5 else Color(0.95, 0.8, 0.2).lerp(Color(0.35, 0.85, 0.3), (k - 0.5) * 2.0)
		col.a = 0.9 * a
		draw_rect(Rect2(r.position, Vector2(larg * k, 5.0)), col)
	for n in nombres:
		var k: float = n.t / DUREE_NOMBRE
		var pos: Vector3 = n.pos + Vector3.UP * (1.1 * k - 0.4 * k * k)
		if cam.is_position_behind(pos):
			continue
		var ec := cam.unproject_position(pos) + Vector2(n.dx * k, 0)
		var taille: int = int(n.taille * (1.0 + 0.35 * (1.0 - smoothstep(0.0, 0.18, n.t))))   # petit grossissement au départ
		var col: Color = n.col
		col.a = 1.0 - smoothstep(0.55, 1.0, k)
		var w := police.get_string_size(n.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		var o := ec - Vector2(w * 0.5, 0)
		draw_string_outline(police, o, n.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 5, Color(0, 0, 0, col.a * 0.8))
		draw_string(police, o, n.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, col)
