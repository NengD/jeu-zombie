extends CanvasLayer
## Journal du survivant (touche O, action « journal ») : onglets Statistiques, Objectifs et Succès.
## Données dans scripts/journal.gd ; ce nœud fait aussi avancer le journal (`Journal.maj`) à chaque image.
## Créé par hud.gd (sur le modèle de etat_ui.gd).

const Journal = preload("res://scripts/journal.gd")
const COUL_OK := Color(0.55, 0.85, 0.5)
const COUL_TITRE := Color(1.0, 0.82, 0.45)
const COUL_DOUX := Color(0.66, 0.68, 0.64)
const NOMS_ZOMBIES := {"civil": "Civils", "patient": "Patients", "police": "Policiers", "militaire": "Militaires",
	"boss": "Colosse", "coureur": "Coureurs", "gros": "Gros", "rampant": "Rampants"}

var fond: ColorRect
var onglets: TabContainer
var textes: Array = []      # un RichTextLabel par onglet
var _t := 0.0


func _ready() -> void:
	layer = 7
	visible = false
	process_mode = Node.PROCESS_MODE_PAUSABLE   # le HUD (parent) tourne même en pause
	add_to_group("journal_ui")
	fond = ColorRect.new()
	fond.color = Color(0.03, 0.035, 0.04, 0.94)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for c in ["left", "right", "top", "bottom"]:
		marge.add_theme_constant_override("margin_" + c, 40)
	fond.add_child(marge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	marge.add_child(col)
	var titre := Label.new()
	titre.text = "JOURNAL DU SURVIVANT"
	titre.add_theme_font_size_override("font_size", 28)
	titre.add_theme_color_override("font_color", Color(0.92, 0.9, 0.8))
	col.add_child(titre)
	onglets = TabContainer.new()
	onglets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	onglets.add_theme_font_size_override("font_size", 18)
	col.add_child(onglets)
	for nom in ["Statistiques", "Objectifs", "Succès"]:
		var t := RichTextLabel.new()
		t.name = nom
		t.bbcode_enabled = true
		t.scroll_active = true
		t.add_theme_font_size_override("normal_font_size", 16)
		t.add_theme_font_size_override("bold_font_size", 17)
		onglets.add_child(t)
		textes.append(t)
	var aide := Label.new()
	aide.text = "[%s] ou Échap : fermer    Tab / Q / E : changer d'onglet" % Game.texte_touche("journal")
	aide.add_theme_font_size_override("font_size", 14)
	aide.add_theme_color_override("font_color", COUL_DOUX)
	col.add_child(aide)


func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("journal") or event.is_action_pressed("pause"):
			fermer()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("inventaire") or event.is_action_pressed("pencher_droite"):
			onglets.current_tab = (onglets.current_tab + 1) % onglets.get_tab_count()
			maj()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pencher_gauche"):
			onglets.current_tab = (onglets.current_tab + onglets.get_tab_count() - 1) % onglets.get_tab_count()
			maj()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal") and not Game.ui_open and Game.player and Game.player.alive:
		ouvrir()
		get_viewport().set_input_as_handled()


func ouvrir() -> void:
	visible = true
	Game.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	maj()


func fermer() -> void:
	visible = false
	Game.ui_open = false
	if Game.player and Game.player.alive and not Game.mode_test:
		Game.capturer_souris()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	Journal.maj(delta)
	if not visible:
		return
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		maj()


# ====================================================================== contenu
static func _c(col: Color, t: String) -> String:
	return "[color=#%s]%s[/color]" % [col.to_html(false), t]


static func _km(m: float) -> String:
	return ("%.2f km" % (m / 1000.0)) if m >= 1000.0 else ("%d m" % int(m))


static func _duree(s: float) -> String:
	var mn := int(s / 60.0)
	return ("%d h %02d min" % [mn / 60, mn % 60]) if mn >= 60 else ("%d min %02d s" % [mn, int(s) % 60])


## Sous-compteurs « préfixe:x » triés du plus grand au plus petit : [[x, n], …].
static func _detail(prefixe: String) -> Array:
	var l: Array = []
	for k in Journal.compteurs:
		if str(k).begins_with(prefixe):
			l.append([str(k).substr(prefixe.length()), int(Journal.compteurs[k])])
	l.sort_custom(func(a, b): return a[1] > b[1])
	return l


static func _nom_objet(id: String) -> String:
	if id == "poings":
		return "Mains nues"
	return Items.nom(id) if Items.DB.has(id) else id.capitalize()


func maj() -> void:
	match onglets.current_tab:
		0: textes[0].text = _stats()
		1: textes[1].text = _objectifs()
		2: textes[2].text = _succes()


func _stats() -> String:
	var v := func(k): return int(Journal.valeur(k))
	var t := "[b]%s[/b]\n" % _c(COUL_TITRE, "SURVIE")
	t += "    Jours survécus : %d\n" % v.call("jours")
	t += "    Plus longue série sans dégâts : %s\n" % _duree(Journal.valeur("serie_max"))
	t += "    Série en cours : %s\n" % _duree(Journal.serie)
	t += "    Morsures soignées : %d\n" % v.call("morsures_soignees")
	t += "    Attaques de la base : %d (repoussées %d, pièces perdues %d)\n\n" % [v.call("attaques_base"), v.call("attaques_repoussees"), v.call("pieces_perdues")]
	t += "[b]%s[/b]  %d\n" % [_c(COUL_TITRE, "ZOMBIES TUÉS"), v.call("zombies")]
	var types: Array = []
	for e in _detail("zombies_type:"):
		types.append("%s %d" % [NOMS_ZOMBIES.get(e[0], e[0].capitalize()), e[1]])
	if not types.is_empty():
		t += "    Par type : %s\n" % ", ".join(types)
	var armes: Array = []
	for e in _detail("zombies_arme:"):
		armes.append("%s %d" % [_nom_objet(e[0]), e[1]])
	if not armes.is_empty():
		t += "    Par arme : %s\n" % ", ".join(armes.slice(0, 10))
	t += "    Bandits tués : %d\n\n" % v.call("bandits")
	t += "[b]%s[/b]  %d\n" % [_c(COUL_TITRE, "ANIMAUX CHASSÉS"), v.call("animaux")]
	var an: Array = []
	for e in _detail("animaux:"):
		an.append("%s %d" % [e[0].capitalize().replace("_", " "), e[1]])
	if not an.is_empty():
		t += "    %s\n" % ", ".join(an)
	t += "\n[b]%s[/b]\n" % _c(COUL_TITRE, "EXPLORATION")
	t += "    Distance à pied : %s\n" % _km(Journal.valeur("dist_pied"))
	t += "    Distance en véhicule : %s\n" % _km(Journal.valeur("dist_vehicule"))
	t += "    Lieux découverts : %d / %d\n" % [v.call("decouverts"), Journal.total_lieux()]
	t += "    Lieux entièrement fouillés : %d\n" % v.call("lieux_fouilles")
	t += "    Meubles fouillés : %d\n\n" % v.call("fouilles")
	t += "[b]%s[/b]  %d\n" % [_c(COUL_TITRE, "OBJETS FABRIQUÉS"), v.call("fabriques")]
	var fab: Array = []
	for e in _detail("fab:"):
		fab.append("%s %d" % [_nom_objet(e[0]), e[1]])
	if not fab.is_empty():
		t += "    %s\n" % ", ".join(fab.slice(0, 12))
	return t


func _objectifs() -> String:
	var faits := 0
	var t := ""
	var courant: Dictionary = Journal.objectif_courant()
	for o in Journal.OBJECTIFS:
		var fait: bool = Journal.objectifs_faits.has(o.id)
		var rec: Dictionary = o.rec
		var gain: String = ("%d €" % int(rec.argent)) if rec.has("argent") else ("%d XP %s" % [int(rec.xp[1]), rec.xp[0]])
		if fait:
			faits += 1
			t += "%s  %s  %s\n" % [_c(COUL_OK, "☑"), _c(COUL_OK, o.nom), _c(COUL_DOUX, "(jour %d, +%s)" % [int(Journal.objectifs_faits[o.id]), gain])]
		else:
			var n: float = minf(Journal.valeur(o.cle), o.n)
			var prog := ("  %d / %d" % [int(n), int(o.n)]) if o.n > 1 else ""
			var nom: String = ("[b]%s[/b]" % o.nom) if o.id == courant.get("id", "") else o.nom
			t += "☐  %s%s  %s\n" % [nom, prog, _c(COUL_DOUX, "(+%s)" % gain)]
			if o.id == courant.get("id", "") and o.aide != "":
				t += "        %s\n" % _c(COUL_TITRE, o.aide)
	return "[b]%s[/b]  %d / %d\n\n" % [_c(COUL_TITRE, "OBJECTIFS"), faits, Journal.OBJECTIFS.size()] + t


func _succes() -> String:
	var t := ""
	for s in Journal.SUCCES:
		if Journal.succes.has(s.id):
			t += "%s  [b]%s[/b] — %s  %s\n" % [_c(COUL_TITRE, "★"), _c(COUL_TITRE, s.nom), s.desc, _c(COUL_DOUX, "(jour %d)" % int(Journal.succes[s.id]))]
		else:
			var n: float = minf(Journal.valeur(s.cle), s.n)
			var prog := ("  %d %%" % int(100.0 * n / s.n)) if s.n > 1 else ""
			t += "%s  %s — %s%s\n" % [_c(COUL_DOUX, "☆"), s.nom, s.desc, _c(COUL_DOUX, prog)]
	return "[b]%s[/b]  %d / %d\n\n" % [_c(COUL_TITRE, "SUCCÈS"), Journal.succes.size(), Journal.SUCCES.size()] + t
