extends VBoxContainer
## Fil des objets reçus, à gauche de l'écran : « +12 Balles 9 mm », « +2 Bandages », « +40 € »…
## Chaque ligne reste quelques secondes puis s'efface ; les ajouts identiques rapprochés se regroupent.
## Alimenté par le signal Game.objet_recu (Game.recu : ramassage, fouille, dépeçage, récolte, achat, fabrication).

const DUREE := 4.0          # secondes d'affichage (le fondu commence 1 s avant la fin)
const REGROUPE := 3.0       # un même objet reçu moins de 3 s après sa ligne s'y ajoute
const MAX_LIGNES := 7

var lignes: Array = []      # {id, n, t, ligne: HBoxContainer, texte: Label}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	Game.objet_recu.connect(_recu)


func _recu(id: String, n: int) -> void:
	for l in lignes:
		if l.id == id and l.t < REGROUPE and signi(l.n) == signi(n):
			l.n += n
			l.t = 0.0
			_ecrire(l)
			move_child(l.ligne, get_child_count() - 1)
			return
	var ligne := HBoxContainer.new()
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_theme_constant_override("separation", 6)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(22, 22)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = Items.icon(id) if id != "argent" else null
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(ic)
	var lb := Label.new()
	lb.add_theme_font_size_override("font_size", 16)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lb.add_theme_constant_override("outline_size", 5)
	ligne.add_child(lb)
	add_child(ligne)
	var l := {"id": id, "n": n, "t": 0.0, "ligne": ligne, "texte": lb}
	lignes.append(l)
	_ecrire(l)
	while lignes.size() > MAX_LIGNES:
		lignes[0].ligne.queue_free()
		lignes.remove_at(0)


func _ecrire(l: Dictionary) -> void:
	var n: int = l.n
	var signe := "+" if n > 0 else "−"
	if l.id == "argent":
		l.texte.text = "%s%d €" % [signe, absi(n)]
		l.texte.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35) if n > 0 else Color(1.0, 0.55, 0.45))
	else:
		l.texte.text = "%s%d %s" % [signe, absi(n), Items.nom(l.id)]
		l.texte.add_theme_color_override("font_color", Color(0.92, 0.95, 0.88) if n > 0 else Color(1.0, 0.6, 0.5))


func _process(delta: float) -> void:
	for i in range(lignes.size() - 1, -1, -1):
		var l: Dictionary = lignes[i]
		l.t += delta
		l.ligne.modulate.a = clampf(DUREE - l.t, 0.0, 1.0)
		if l.t >= DUREE:
			l.ligne.queue_free()
			lignes.remove_at(i)
