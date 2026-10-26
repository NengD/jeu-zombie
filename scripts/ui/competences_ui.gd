extends CanvasLayer
## Écran « Personnage » (touche K) : arbre de compétences qui part du survivant (au centre).
## Une branche par axe (Combat → corps à corps / armes à feu, Fabrication, Exploration, Survie,
## Chasse et arc) ; un nœud ne se débloque que si le précédent l'est, plus loin = plus puissant.
## Attributs (endurance, santé, soif, faim) : petits nœuds répétables autour du centre.
## Clic-glisser : déplacer ; molette : zoom ; [Espace] : recentrer ; clic sur un nœud : débloquer.

const Recolte = preload("res://scripts/recolte.gd")

## Couleur de chaque compétence (branches, titres).
const COULEURS := {
	"combat": Color(0.9, 0.36, 0.3), "fabrication": Color(0.95, 0.66, 0.25), "exploration": Color(0.38, 0.66, 0.95),
	"survie": Color(0.45, 0.82, 0.42), "chasse": Color(0.78, 0.6, 0.4),
}
const COUL_DISPO := Color(1.0, 0.84, 0.3)
const COUL_VERROU := Color(0.33, 0.34, 0.33)

var fond: ColorRect
var arbre: Arbre
var lbl_titre: Label
var barre_xp: ProgressBar
var lbl_xp: Label
var lbl_points: RichTextLabel
var bt_reinit: Button
var confirm: ConfirmationDialog
var bulle: PanelContainer
var bulle_txt: RichTextLabel
var tailles: Array = []      # [contrôle, propriété, taille à 1080 p de haut] : textes agrandis avec l'écran


func _ready() -> void:
	layer = 7
	add_to_group("competences_ui")
	fond = ColorRect.new()
	fond.color = Color(0.03, 0.035, 0.04, 0.97)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	fond.resized.connect(_redimensionne)
	arbre = Arbre.new()
	arbre.ui = self
	arbre.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.add_child(arbre)
	_bandeau()
	var aide := Label.new()
	aide.text = "Glisser : déplacer    Molette : zoom    Espace : recentrer    Clic : débloquer"
	_taille(aide, "font_size", 14)
	aide.add_theme_color_override("font_color", Color(0.6, 0.62, 0.6))
	aide.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	aide.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	aide.grow_vertical = Control.GROW_DIRECTION_BEGIN
	aide.position += Vector2(-16, -10)
	aide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.add_child(aide)
	var legende := RichTextLabel.new()
	legende.bbcode_enabled = true
	legende.fit_content = true
	legende.autowrap_mode = TextServer.AUTOWRAP_OFF
	legende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_taille(legende, "normal_font_size", 14)
	legende.text = "[color=#%s]●[/color] acquis    [color=#%s]○[/color] disponible    [color=#%s]●[/color] verrouillé" % [COULEURS.survie.to_html(false), COUL_DISPO.to_html(false), Color(0.5, 0.5, 0.5).to_html(false)]
	legende.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	legende.grow_vertical = Control.GROW_DIRECTION_BEGIN
	legende.position += Vector2(16, -10)
	fond.add_child(legende)
	bulle = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.06, 0.97)
	sb.border_color = Color(0.5, 0.5, 0.42)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(10)
	bulle.add_theme_stylebox_override("panel", sb)
	bulle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bulle.visible = false
	fond.add_child(bulle)
	bulle_txt = RichTextLabel.new()
	bulle_txt.bbcode_enabled = true
	bulle_txt.fit_content = true
	bulle_txt.custom_minimum_size.x = 340
	bulle_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_taille(bulle_txt, "normal_font_size", 15)
	_taille(bulle_txt, "bold_font_size", 17)
	bulle.add_child(bulle_txt)
	confirm = ConfirmationDialog.new()
	confirm.title = "Réinitialiser les points"
	confirm.ok_button_text = "Réinitialiser"
	confirm.cancel_button_text = "Annuler"
	confirm.confirmed.connect(_reinitialiser)
	add_child(confirm)
	visible = false


## Bandeau du haut : niveau, XP, points disponibles, réinitialisation, fermer.
func _bandeau() -> void:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.055, 0.05, 0.92)
	sb.set_content_margin_all(10)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	pc.add_theme_stylebox_override("panel", sb)
	pc.set_anchors_preset(Control.PRESET_TOP_WIDE)
	fond.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pc.add_child(vb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	lbl_titre = Label.new()
	_taille(lbl_titre, "font_size", 26)
	lbl_titre.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	hb.add_child(lbl_titre)
	var vx := VBoxContainer.new()
	vx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vx.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(vx)
	barre_xp = ProgressBar.new()
	barre_xp.show_percentage = false
	barre_xp.custom_minimum_size = Vector2(160, 10)
	var f := StyleBoxFlat.new()
	f.bg_color = Color(0.95, 0.8, 0.35)
	var b := StyleBoxFlat.new()
	b.bg_color = Color(0, 0, 0, 0.5)
	barre_xp.add_theme_stylebox_override("fill", f)
	barre_xp.add_theme_stylebox_override("background", b)
	vx.add_child(barre_xp)
	lbl_xp = Label.new()
	_taille(lbl_xp, "font_size", 13)
	lbl_xp.add_theme_color_override("font_color", Color(0.75, 0.75, 0.72))
	vx.add_child(lbl_xp)
	bt_reinit = Button.new()
	_taille(bt_reinit, "font_size", 15)
	bt_reinit.pressed.connect(_demander_reinit)
	hb.add_child(bt_reinit)
	var bf := Button.new()
	bf.text = "Fermer  (K / Échap)"
	_taille(bf, "font_size", 15)
	bf.pressed.connect(fermer)
	hb.add_child(bf)
	lbl_points = RichTextLabel.new()
	lbl_points.bbcode_enabled = true
	lbl_points.fit_content = true
	lbl_points.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_points.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_taille(lbl_points, "normal_font_size", 15)
	vb.add_child(lbl_points)


func _taille(c: Control, prop: String, base: int) -> void:
	tailles.append([c, prop, base])
	c.add_theme_font_size_override(prop, base)


## Textes du bandeau, de l'aide et de la bulle proportionnels à la hauteur de l'écran (1080 p = tailles de base).
func _appliquer_tailles() -> void:
	var k := clampf(fond.size.y / 1080.0, 0.85, 1.5)
	for t in tailles:
		(t[0] as Control).add_theme_font_size_override(t[1], roundi(t[2] * k))
	bulle_txt.custom_minimum_size.x = 340.0 * k


func _redimensionne() -> void:
	if visible and bulle_txt != null:
		_appliquer_tailles()
		arbre.recentrer()


func ouvrir() -> void:
	if Game.player == null or not Game.player.alive:
		return
	visible = true
	Game.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_appliquer_tailles()
	_maj()
	arbre.recentrer()


func fermer() -> void:
	visible = false
	bulle.visible = false
	Game.ui_open = false
	if Game.player and Game.player.alive:
		Game.capturer_souris()


func _maj() -> void:
	var pr = Game.player.prog
	lbl_titre.text = "PERSONNAGE — NIVEAU %d" % pr.niveau
	barre_xp.max_value = maxf(1.0, Progression.xp_niveau(pr.niveau))
	barre_xp.value = pr.xp
	lbl_xp.text = "%d / %d XP avant le niveau %d" % [pr.xp, Progression.xp_niveau(pr.niveau), pr.niveau + 1]
	var morceaux: PackedStringArray = []
	morceaux.append(_pts("Attributs", pr.points, Color(0.95, 0.85, 0.5)))
	for c in Progression.COMPETENCES:
		morceaux.append(_pts("%s niv. %d" % [Progression.NOMS[c], pr.comp[c].niv], int(pr.comp[c].points), COULEURS[c]))
	lbl_points.text = "Points à dépenser :   " + "     ".join(morceaux)
	var cout: int = pr.cout_reinit()
	bt_reinit.text = "Réinitialiser (%d €)" % cout
	bt_reinit.disabled = pr.points_investis() == 0 or Game.player.argent < cout
	bt_reinit.tooltip_text = "Rend tous les points de talent et d'attribut dépensés contre %d € (tu as %d €).\nLes rangées de poches restent acquises." % [cout, Game.player.argent]
	arbre.queue_redraw()


func _pts(nom: String, n: int, c: Color) -> String:
	var col := c if n > 0 else Color(0.55, 0.55, 0.53)
	return "[color=#%s]%s : [b]%d[/b][/color]" % [col.to_html(false), nom, n]


func _demander_reinit() -> void:
	var pr = Game.player.prog
	confirm.dialog_text = "Rendre %d point(s) de talent et d'attribut pour %d € ?\n(Tu as %d €. Les rangées de poches restent acquises.)" % [pr.points_investis(), pr.cout_reinit(), Game.player.argent]
	confirm.popup_centered()


func _reinitialiser() -> void:
	var p = Game.player
	var cout: int = p.prog.cout_reinit()
	if p.argent < cout:
		return
	p.argent -= cout
	Game.recu("argent", -cout)
	p.prog.reinitialiser()
	p.health = minf(p.health, p.prog.sante_max())
	p.stamina = minf(p.stamina, p.prog.endurance_max())
	Game.play_ui("construire", -3.0, 0.0, 0.8)
	Game.msg("Points réinitialisés : tu peux les redistribuer.")
	_maj()


## Clic sur un nœud de l'arbre.
func activer(id: String) -> void:
	var pr = Game.player.prog
	if id.begins_with("attr:"):
		if pr.ameliorer(id.substr(5)):
			Game.play_ui("construire", -6.0, 0.0, 1.6)
			_maj()
		return
	if not Progression.TALENTS.has(id):
		return
	if pr.debloquer(id):
		if id in ["poches", "poches2"]:
			Game.player.maj_poches()
		Game.play_ui("construire", -3.0, 0.0, 1.4)
		if Progression.rangs_max(id) > 1:
			Game.msg("%s : rang %d / %d" % [Progression.TALENTS[id].nom, pr.rang(id), Progression.rangs_max(id)])
		else:
			Game.msg("Talent débloqué : " + Progression.TALENTS[id].nom)
		_maj()
	elif pr.rang(id) < Progression.rangs_max(id):
		Game.play_ui("clic_vide", -8.0, 0.0, 1.0)


## Bulle d'information du nœud survolé ("" = aucune).
func montrer_bulle(id: String, souris: Vector2) -> void:
	if id == "":
		bulle.visible = false
		return
	bulle_txt.text = _texte_bulle(id)
	bulle.visible = true
	bulle.reset_size()
	var vs := fond.size
	var pos := souris + Vector2(22, 18)
	if pos.x + bulle.size.x > vs.x - 8:
		pos.x = souris.x - bulle.size.x - 22
	if pos.y + bulle.size.y > vs.y - 8:
		pos.y = vs.y - bulle.size.y - 8
	bulle.position = pos.max(Vector2(8, 8))


func _texte_bulle(id: String) -> String:
	var pr = Game.player.prog
	var gris := "[color=#9a9c98]"
	if id == "centre":
		return "[b]Le survivant — niveau %d[/b]\n%d / %d XP avant le niveau %d.\n%sChaque niveau donne 1 point d'attribut (nœuds autour du centre). Chaque niveau de compétence donne 1 point de talent dans sa branche.[/color]" % [pr.niveau, pr.xp, Progression.xp_niveau(pr.niveau), pr.niveau + 1, gris]
	if id.begins_with("hub:"):
		var c := id.substr(4)
		var d: Dictionary = pr.comp[c]
		var xp_txt := "Niveau maximum atteint." if d.niv >= Progression.NIVEAU_MAX_COMP else "%d / %d XP avant le niveau %d." % [d.xp, Progression.xp_comp(d.niv), d.niv + 1]
		return "[b][color=#%s]%s — niveau %d[/color][/b]\n%s\nPoints de talent : [b]%d[/b]\n%s%s[/color]" % [COULEURS[c].to_html(false), Progression.NOMS[c].to_upper(), d.niv, xp_txt, d.points, gris, _gains(c, int(d.niv))]
	if id.begins_with("attr:"):
		var at := id.substr(5)
		var info: Dictionary = Progression.ATTRIBUTS[at]
		var valeurs := {
			"endurance": "Endurance max : %d" % int(pr.endurance_max()),
			"sante": "Santé max : %d" % int(pr.sante_max()),
			"soif": "Soif : %d %% plus lente" % int(round((1.0 - pr.soif_mult()) * 100.0)),
			"faim": "Faim : %d %% plus lente" % int(round((1.0 - pr.faim_mult()) * 100.0)),
		}
		var etat := "[color=#ffd84d]Clic : +1 (%d point(s) d'attribut)[/color]" % pr.points if pr.points > 0 else "%sPlus de point d'attribut (1 par niveau global).[/color]" % gris
		return "[b]%s[/b]  (rang %d, répétable)\n%s par point.\n%s\nCoût : 1 point d'attribut\n%s" % [info.nom, pr.attributs[at], info.desc, valeurs[at], etat]
	var t: Dictionary = Progression.TALENTS[id]
	var c2: String = t.comp
	var col: Color = COULEURS[c2]
	var lignes: PackedStringArray = []
	var genre: String = "Pont " + Progression.BRANCHES[t.br].nom if t.get("pont", false) else Progression.BRANCHES[t.br].nom
	lignes.append("[b][color=#%s]%s[/color][/b]   %s%s[/color]" % [col.to_html(false), t.nom, gris, genre])
	lignes.append(t.desc)
	var ok := "[color=#7fe07f]✔[/color]"
	var non := "[color=#e07060]✘[/color]"
	var rmax := Progression.rangs_max(id)
	if rmax > 1:
		lignes.append("Rang : [b]%d / %d[/b]" % [pr.rang(id), rmax])
	lignes.append("Coût : 1 point de %s (tu en as %d)" % [Progression.NOMS[c2], pr.comp[c2].points])
	for par in [t.apres, t.get("apres2", "")]:
		if par != "":
			lignes.append("Prérequis : %s %s" % [Progression.TALENTS[par].nom, ok if pr.a(par) else non])
	var nr: int = pr.niv_requis(id)
	if pr.rang(id) < rmax:
		lignes.append("Niveau requis : %d en %s (actuel %d) %s" % [nr, Progression.NOMS[c2], pr.comp[c2].niv, ok if pr.comp[c2].niv >= nr else non])
	var ap := _apercu(id)
	if ap != "":
		lignes.append(ap)
	if pr.rang(id) >= rmax:
		lignes.append("[color=#7fe07f]✔ Acquis[/color]")
	elif pr.peut_debloquer(id):
		lignes.append("[color=#ffd84d]Disponible — clic pour %s[/color]" % ("monter d'un rang" if pr.a(id) else "débloquer"))
	else:
		lignes.append("[color=#e07060]%s[/color]" % pr.raison_bloque(id))
	return "\n".join(lignes)


## Aperçu chiffré du talent : valeurs actuelles → valeurs avec le talent (ou son rang suivant).
## Calculé en appliquant le talent un instant puis en l'enlevant ; "" si rien de mesurable ne change.
func _apercu(id: String) -> String:
	var pr = Game.player.prog
	if pr.rang(id) >= Progression.rangs_max(id):
		return ""
	var avant := _stats()
	var deja: bool = pr.a(id)
	var ancien_rangs: Dictionary = pr.rangs.duplicate()
	if deja:
		pr.rangs[id] = pr.rang(id) + 1
	else:
		pr.talents.append(id)
	var apres := _stats()
	if deja:
		pr.rangs = ancien_rangs
	else:
		pr.talents.erase(id)
	var lignes: PackedStringArray = []
	for k in avant:
		if apres.has(k) and apres[k] != avant[k]:
			lignes.append("  %s : %s → [color=#7fe07f]%s[/color]" % [k, avant[k], apres[k]])
	if lignes.is_empty():
		return ""
	return "[color=#ffd84d]Avec ce talent :[/color]\n" + "\n".join(lignes)


## Valeurs affichables qui dépendent des talents (arme en main comprise).
func _stats() -> Dictionary:
	var p = Game.player
	var pr = p.prog
	var s := {}
	s["Santé max"] = "%d" % pr.sante_max()
	s["Endurance max"] = "%d" % pr.endurance_max()
	s["Récupération d'endurance"] = "×%.2f" % pr.recup_endurance()
	s["Vitesse de la faim"] = "%d %%" % roundi(pr.faim_mult() * 100.0)
	s["Vitesse de la soif"] = "%d %%" % roundi(pr.soif_mult() * 100.0)
	s["Dégâts au corps à corps"] = "×%.2f" % p.mult_melee()
	s["Endurance par coup"] = "×%.2f" % p.cout_melee()
	s["Dégâts d'une flèche bandée à fond"] = "×%.2f" % p.mult_fleche(1.0)
	s["Durée d'une fabrication de 10 s"] = "%.1f s" % p.duree_fabrication({"duree": 10.0, "out": "planche"})
	var arme: String = p.current_weapon()
	var w: Dictionary = Items.info(arme)
	if w.get("type", "") == "gun":
		var ws: Dictionary = p.arme_stats(arme)
		var n: String = Items.nom(arme)
		s[n + " — dégâts"] = "%.1f" % float(ws.damage)
		s[n + " — dispersion"] = "%.2f" % float(ws.spread)
		s[n + " — dispersion sans viser"] = "×%.2f" % float(ws.get("dispersion_hanche", 1.0))
		s[n + " — dispersion en visant"] = "×%.2f" % float(ws.get("dispersion_visee", 0.45))
		s[n + " — recul"] = "%.2f" % float(ws.recoil)
		s[n + " — rechargement"] = "%.2f s" % float(ws.reload)
		s[n + " — cadence"] = "%.1f tirs/s" % (1.0 / maxf(0.01, float(ws.rate)))
		s[n + " — portée"] = "%d m" % roundi(float(ws.range))
	elif w.get("type", "") == "melee":
		s[Items.nom(arme) + " — dégâts"] = "%.1f" % (float(w.damage) * p.mult_melee())
	if w.get("type", "") != "gun":   # pas d'arme à feu en main : effets des talents en multiplicateurs (arme de référence)
		var base: Dictionary = Items.info("glock19")
		var ws: Dictionary = p.arme_stats("glock19")
		var r := func(k: String, defaut: float) -> String: return "×%.2f" % (float(ws.get(k, defaut)) / maxf(0.001, float(base.get(k, defaut))))
		s["Armes à feu — dégâts"] = r.call("damage", 1.0)
		s["Armes à feu — dispersion"] = r.call("spread", 1.0)
		s["Armes à feu — dispersion sans viser"] = r.call("dispersion_hanche", 1.0)
		s["Armes à feu — dispersion en visant"] = r.call("dispersion_visee", 0.45)
		s["Armes à feu — recul"] = r.call("recoil", 1.0)
		s["Armes à feu — rechargement"] = r.call("reload", 1.0)
		s["Armes à feu — délai entre deux tirs"] = r.call("rate", 1.0)
		s["Armes à feu — portée"] = r.call("range", 1.0)
	_stats_talents(pr, s)
	return s


## Effets de talents qui ne se lisent pas dans une statistique du joueur : chances, prix, détection, récupération…
## Mêmes formules que dans le jeu (player.gd, zombie.gd, animal.gd, fleche.gd, placeable.gd, vendeur.gd…).
func _stats_talents(pr, s: Dictionary) -> void:
	var oui_non := func(t: String, si: String, sinon: String) -> String: return si if pr.a(t) else sinon
	var pc := func(x: float) -> String: return "%d %%" % roundi(x * 100.0)
	# --- combat
	s["Chance de coup critique (×2)"] = pc.call(0.2 if pr.a("critique") else 0.0)
	s["3e coup d'un enchaînement"] = oui_non.call("enchainement", "×1,4", "×1")
	s["Hache, machette, couteau"] = oui_non.call("lame_aiguisee", "×1,2 et plus de sang", "×1")
	s["Battes et matraque"] = oui_non.call("frappeur", "repoussent à chaque coup", "repoussent parfois")
	s["Temps de charge du coup puissant"] = oui_non.call("charge_rapide", "×0,71", "×1")
	s["Coup chargé à fond"] = oui_non.call("brute", "renverse toujours", "renverse parfois")
	s["Zombies touchés par un balayage"] = oui_non.call("balayage", "2", "1")
	s["Dégâts subis"] = pc.call((0.85 if pr.a("robuste") else 1.0) * (0.9 if pr.a("seconde_peau") else 1.0))
	s["Dégâts bloqués par une parade"] = oui_non.call("parade_experte", "90 %", "80 %")
	s["Endurance d'une parade"] = oui_non.call("parade_experte", "6", "12")
	s["Endurance d'une roulade"] = oui_non.call("acrobate", "6", "12")
	s["Zombie tué"] = oui_non.call("furie", "+8 endurance, +3 santé", "rien")
	s["Zombie qui ne te poursuit pas (corps à corps)"] = oui_non.call("embuscade", "×2", "×1")
	s["Sous 25 % de santé"] = oui_non.call("adrenaline", "+20 % de dégâts et de vitesse", "rien")
	s["Coup à la tête"] = oui_non.call("tir_tete", "×3", "×2,5")
	s["Tirs sans consommer de cartouche"] = pc.call(0.15 if pr.a("econome_balles") else 0.0)
	s["Dispersion des tirs rapprochés"] = oui_non.call("maitrise_rafale", "×0,6", "×1")
	s["Grenades : dégâts et étendue"] = oui_non.call("grenadier", "×1,3", "×1")
	# --- fabrication
	s["Récupération d'un matériau en fabriquant"] = oui_non.call("econome", "oui", "non")
	s["Économe : chance par fabrication"] = pc.call(0.5 if pr.a("ingeniosite") else 0.3)
	s["Chance d'un objet en double"] = pc.call(0.5 if pr.a("maitre_artisan") else 0.0)
	s["Munitions fabriquées"] = "×%.2f" % ((1.5 if pr.a("cartoucherie") else 1.0) * (1.25 if pr.a("armurier") else 1.0))
	s["Munitions : durée de fabrication"] = oui_non.call("poudre_maison", "×0,5", "×1")
	s["Solidité des barricades et établis"] = oui_non.call("charpentier", "×1,6", "×1")
	s["Recettes d'établi"] = oui_non.call("atelier", "partout", "à l'établi")
	s["Démontage : matériaux rendus"] = oui_non.call("recuperateur", "75 %", "50 %")
	s["Dégâts des pièges à mâchoires"] = oui_non.call("ingenieur", "72", "45")
	s["Recettes de soins : objet en plus"] = pc.call(0.5 if pr.a("chimiste") else 0.0)
	s["Niveau de récolte des épaves"] = str(int(pr.comp.fabrication.niv) + (2 if pr.a("mecanicien") else 0))
	# --- exploration
	s["Prix d'achat chez les marchands"] = oui_non.call("marchandage", "85 %", "100 %")
	s["Prix de revente"] = oui_non.call("marchandage", "115 %", "100 %")
	s["Argent trouvé en fouillant"] = oui_non.call("chanceux", "chance ×1,5, somme ×1,3", "normal")
	s["Objets dans les meubles"] = "+%d" % ((1 if pr.a("fouilleur") else 0) + (1 if pr.a("vue_percante") else 0))
	s["XP d'exploration"] = oui_non.call("curieux", "×1,25", "×1")
	s["Distance de repérage par les zombies"] = oui_non.call("discret", "70 %", "100 %")
	s["… accroupi"] = pc.call((0.3 if pr.a("ombre") else 0.5) * (0.7 if pr.a("discret") else 1.0))
	s["Vitesse de sprint"] = "×%.2f" % ((1.12 if pr.a("coureur") else 1.0) * (1.0 + 0.03 * pr.rang("pied_leger")))
	s["Endurance du sprint"] = oui_non.call("marathonien", "×0,65", "×1")
	s["Vitesse accroupi"] = oui_non.call("rodeur", "×1,3", "×1")
	s["Rangées d'inventaire de base"] = str(pr.lignes_inventaire())
	# --- survie
	s["Régénération de la santé"] = "×%.1f" % ((2.0 if pr.a("regeneration") else 1.0) * (1.5 if pr.a("survivant_ne") else 1.0))
	s["Soins rendus"] = "×%.2f" % ((1.3 if pr.a("soigneur") else 1.0) * (1.2 if pr.a("herboriste") else 1.0))
	s["Nourriture et boissons"] = oui_non.call("cuisinier", "×1,25", "×1")
	s["Viande et plats de chasse"] = "×%.2f" % ((1.25 if pr.a("cuisinier") else 1.0) * (1.3 if pr.a("vivre_terre") else 1.0))
	s["Risque d'intoxication (viande crue)"] = pc.call(maxf(0.2, 0.5 - 0.03 * int(pr.comp.survie.niv)) * (0.5 if pr.a("estomac") else 1.0))
	s["Guérison des maladies"] = oui_non.call("medecin", "×2", "×1")
	s["Montée de la fièvre (infection)"] = oui_non.call("medecin", "×0,5", "×1")
	s["Risque d'infection d'une morsure"] = pc.call(maxf(0.04, 0.12 - 0.004 * int(pr.comp.survie.niv)))
	s["Risque de saignement"] = oui_non.call("seconde_peau", "×0,5", "×1")
	s["Refroidissement (sans vêtements)"] = pc.call((0.7 if pr.a("endurci") else 1.0) * (1.0 - 0.02 * int(pr.comp.survie.niv)))
	s["Usure effacée par un kit de réparation"] = pc.call(minf(1.0, (0.5 + 0.03 * int(pr.comp.fabrication.niv)) * (1.25 if pr.a("bricoleur") else 1.0)))
	s["Usure des armes et outils"] = oui_non.call("bricoleur", "×0,7", "×1")
	s["Durée des soins"] = "×%.2f" % ((0.75 if pr.a("soigneur") else 1.0) * (0.7 if pr.a("premiers_secours") else 1.0))
	s["Arrêt naturel d'un saignement"] = oui_non.call("premiers_secours", "×2 plus vite", "×1")
	s["Cueillette"] = oui_non.call("cueilleur", "+50 %", "+0 %")
	s["Pêche : temps par poisson"] = oui_non.call("pecheur", "÷1,6", "×1")
	s["Pêche : poissons gardés par ligne"] = oui_non.call("pecheur", "+2", "+0")
	s["Sommeil : santé par heure"] = oui_non.call("sommeil", "10 et toute l'endurance", "5")
	s["Blessure mortelle"] = oui_non.call("increvable", "survie à 15 de santé une fois par jour", "mort")
	s["Niveau de récolte des arbres et rochers"] = str(int(pr.comp.survie.niv) + (2 if pr.a("bucheron") else 0))
	# --- chasse
	s["Temps pour bander l'arc"] = "%.2f s" % (0.9 * (0.65 if pr.a("tension_rapide") else 1.0))
	s["Délai entre deux flèches"] = "%.2f s" % (0.45 * (0.6 if pr.a("fleches_serie") else 1.0))
	s["Flèches récupérées (décor / créature)"] = oui_non.call("recup_fleches", "97 % / 85 %", "75 % / 50 %")
	s["Bruit de l'arc"] = oui_non.call("silence", "25 %", "100 %")
	s["Distance de repérage par les animaux"] = oui_non.call("pisteur", "70 %", "100 %")
	s["Dégâts contre les animaux"] = oui_non.call("traqueur", "×1,3", "×1")
	s["Dépeçage : viande et peau"] = oui_non.call("depeceur", "+1 chacune", "+0")
	s["Tannage"] = oui_non.call("tanneur", "2 cuirs", "1 cuir")
	s["Recettes au feu : portion en plus"] = pc.call(0.5 if pr.a("chef") else 0.0)
	s["Flèches fabriquées"] = oui_non.call("empenneur", "+2 par recette", "+0")
	s["Délai de prise des collets"] = oui_non.call("piegeur", "×0,5", "×1")


func _gains(c: String, niv: int) -> String:
	var recolte := "\nRécolte %s : %d %% de coups en moins, +%d %% de ressources (niveau %d)." % ["des épaves" if c == "fabrication" else "des arbres et rochers", roundi((1.0 - Recolte.moins_de_coups(niv)) * 100.0), roundi((Recolte.plus_de_ressources(niv) - 1.0) * 100.0), niv]
	match c:
		"combat":
			return "XP : tuer des zombies (plus pour policiers et militaires), toucher un zombie au corps à corps ou avec une arme à feu."
		"fabrication":
			return "XP : fabriquer des objets, poser des établis, caisses, barricades." + recolte
		"survie":
			return "XP : couper des arbres, briser des rochers, se soigner, manger, encaisser des coups." + recolte
		"chasse":
			return "XP : toucher avec une flèche, tuer et dépecer des animaux, relever un collet, cuisiner au feu."
		_:
			return "XP : fouiller meubles et corps, découvrir bâtiments et lieux importants."


func _input(event: InputEvent) -> void:
	if visible:
		if confirm.visible:
			return
		if event.is_action_pressed("competences") or event.is_action_pressed("pause"):
			fermer()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_SPACE:
			arbre.recentrer()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("competences") and not Game.ui_open and Game.player and Game.player.alive:
		ouvrir()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		arbre.queue_redraw()   # anneau des nœuds disponibles qui pulse


# ====================================================================== icônes des talents
## Icône de chaque talent : une icône d'objet du jeu (res://icones/<id>) ou, avec « @ », un symbole dessiné.
const ICONES := {
	"coup_puissant": "marteau", "lame_aiguisee": "machette", "souffle": "@eclair", "frappeur": "batte",
	"enchainement": "@poing", "charge_rapide": "@sablier", "acrobate": "@pas", "robuste": "casque_militaire",
	"critique": "@etoile", "balayage": "hache", "parade_experte": "@bouclier", "brute": "batte_cloutee",
	"maitre_armes": "couteau_km2000", "furie": "@crane", "force": "@poing",
	"main_sure": "@cible", "visee_stable": "lunette", "recharge_rapide": "chargeur_etendu", "tir_hanche": "pistolet",
	"tireur": "fusil_assaut", "grenadier": "rgd5", "balistique": "lunette_hawke", "econome_balles": "mun_9mm",
	"gachette": "glock19", "sang_froid": "poignee", "maitrise_rafale": "m4a1", "tir_tete": "point_rouge", "calibre": "mun_762",
	"econome": "ferraille", "soigneur": "bandage", "charpentier": "planche", "cartoucherie": "poudre",
	"cuisinier": "conserve", "artisan_rapide": "@sablier", "mecanicien": "cle_molette", "chimiste": "medicament",
	"atelier": "etabli", "recuperateur": "piece_auto", "maitre_artisan": "@etoile", "ingenieur": "piege_machoires",
	"ingeniosite": "clous", "armurier": "mun_556", "rendement": "marteau",
	"fouilleur": "caisse_stockage", "curieux": "lunettes", "discret": "@pas", "poches": "sac_toile", "coureur": "@eclair",
	"chanceux": "@etoile", "ombre": "@lune", "poches2": "sac_militaire", "marathonien": "eau", "marchandage": "@piece",
	"vue_percante": "@oeil", "infatigable": "sac_randonnee", "pied_leger": "@pas",
	"regeneration": "@coeur", "bucheron": "buche", "endurci": "@eclair", "bricoleur": "kit_reparation", "premiers_secours": "attelle", "cueilleur": "pomme", "pecheur": "canne_peche", "frugal": "ration", "sommeil": "@lune",
	"adrenaline": "@coeur", "estomac": "viande_crue", "medecin": "antidouleur", "vigueur": "@coeur", "chameau": "eau",
	"seconde_peau": "veste_cuir", "increvable": "@crane", "survivant_ne": "@etoile", "constitution": "@bouclier",
	"archer": "arc", "depeceur": "couteau_km2000", "tension_rapide": "arc", "pisteur": "@oeil", "tanneur": "cuir",
	"recup_fleches": "fleche", "piegeur": "collet", "chef": "viande_cuite", "fleches_serie": "plume", "traqueur": "peau",
	"tir_mortel": "@cible", "empenneur": "fleche", "silence": "@lune", "oeil_faucon": "@oeil",
	"combattant": "@etoile", "poudre_maison": "poudre", "herboriste": "trousse", "vivre_terre": "ragout",
	"rodeur": "sac_chasse", "embuscade": "couteau_km2000",
}
var _textures := {}


## Dessine l'icône du talent `id` (carré de côté `taille`, centré sur p) sur `ci` pendant son _draw.
func dessiner_icone(ci: CanvasItem, id: String, p: Vector2, taille: float, teinte: Color) -> void:
	var cle: String = ICONES.get(id, "@etoile")
	if cle.begins_with("@"):
		_glyphe(ci, cle.substr(1), p, taille * 0.42, teinte)
		return
	if not _textures.has(cle):
		_textures[cle] = Items.icon(cle)
	var tex: Texture2D = _textures[cle]
	if tex == null:
		_glyphe(ci, "etoile", p, taille * 0.42, teinte)
		return
	var ts := tex.get_size()
	var k := taille / maxf(ts.x, ts.y)
	draw_rect_tex(ci, tex, Rect2(p - ts * k * 0.5, ts * k), teinte)


func draw_rect_tex(ci: CanvasItem, tex: Texture2D, rect: Rect2, teinte: Color) -> void:
	ci.draw_texture_rect(tex, rect, false, teinte)


## Petits symboles dessinés (s = demi-taille).
func _glyphe(ci: CanvasItem, nom: String, p: Vector2, s: float, teinte: Color) -> void:
	var c := Color(0.95, 0.92, 0.85) * teinte
	var fond := Color(0.12, 0.12, 0.11)
	var w := maxf(1.5, s * 0.16)
	match nom:
		"coeur":
			ci.draw_circle(p + Vector2(-s * 0.42, -s * 0.2), s * 0.48, c)
			ci.draw_circle(p + Vector2(s * 0.42, -s * 0.2), s * 0.48, c)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.88, 0), p + Vector2(s * 0.88, 0), p + Vector2(0, s * 0.95)]), c)
		"bouclier":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.8, -s * 0.8), p + Vector2(s * 0.8, -s * 0.8), p + Vector2(s * 0.75, s * 0.1), p + Vector2(0, s), p + Vector2(-s * 0.75, s * 0.1)]), c)
			ci.draw_line(p + Vector2(0, -s * 0.6), p + Vector2(0, s * 0.7), fond, w, true)
		"oeil":
			var pts := PackedVector2Array()
			for i in 17:
				var a := PI * i / 16.0
				pts.append(p + Vector2(-cos(a) * s, -sin(a) * s * 0.55))
			for i in 17:
				var a := PI * i / 16.0
				pts.append(p + Vector2(cos(a) * s, sin(a) * s * 0.55))
			ci.draw_colored_polygon(pts, c)
			ci.draw_circle(p, s * 0.36, fond)
			ci.draw_circle(p, s * 0.15, c)
		"eclair":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(s * 0.25, -s), p + Vector2(-s * 0.55, s * 0.1), p + Vector2(-s * 0.02, s * 0.1), p + Vector2(-s * 0.25, s), p + Vector2(s * 0.55, -s * 0.15), p + Vector2(s * 0.02, -s * 0.15)]), c)
		"piece":
			ci.draw_circle(p, s * 0.85, c)
			ci.draw_arc(p, s * 0.62, 0, TAU, 24, fond, w, true)
			_texte(ci, p, "€", int(s * 1.0), fond)
		"lune":
			ci.draw_circle(p, s * 0.85, c)
			ci.draw_circle(p + Vector2(s * 0.42, -s * 0.28), s * 0.72, fond)
		"crane":
			ci.draw_circle(p + Vector2(0, -s * 0.15), s * 0.75, c)
			ci.draw_rect(Rect2(p + Vector2(-s * 0.42, s * 0.3), Vector2(s * 0.84, s * 0.55)), c)
			ci.draw_circle(p + Vector2(-s * 0.3, -s * 0.12), s * 0.2, fond)
			ci.draw_circle(p + Vector2(s * 0.3, -s * 0.12), s * 0.2, fond)
			ci.draw_line(p + Vector2(0, s * 0.45), p + Vector2(0, s * 0.85), fond, w * 0.7)
		"pas":
			ci.draw_set_transform(p + Vector2(-s * 0.38, s * 0.2), -0.2, Vector2(0.6, 1.0))
			ci.draw_circle(Vector2.ZERO, s * 0.5, c)
			ci.draw_set_transform(p + Vector2(s * 0.38, -s * 0.35), 0.2, Vector2(0.6, 1.0))
			ci.draw_circle(Vector2.ZERO, s * 0.5, c)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"sablier":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.65, -s * 0.9), p + Vector2(s * 0.65, -s * 0.9), p]), c)
			ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(s * 0.65, s * 0.9), p + Vector2(-s * 0.65, s * 0.9)]), c)
		"cible":
			ci.draw_arc(p, s * 0.85, 0, TAU, 28, c, w, true)
			ci.draw_arc(p, s * 0.5, 0, TAU, 20, c, w, true)
			ci.draw_circle(p, s * 0.18, c)
		"etoile":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + PI * i / 5.0
				pts.append(p + Vector2.from_angle(a) * (s * 0.95 if i % 2 == 0 else s * 0.42))
			ci.draw_colored_polygon(pts, c)
		"poing":
			ci.draw_rect(Rect2(p + Vector2(-s * 0.7, -s * 0.45), Vector2(s * 1.4, s * 1.0)), c)
			ci.draw_rect(Rect2(p + Vector2(-s * 0.55, s * 0.5), Vector2(s * 0.9, s * 0.45)), c)
			for i in 3:
				var x := -s * 0.35 + i * s * 0.35
				ci.draw_line(p + Vector2(x, -s * 0.45), p + Vector2(x, s * 0.1), fond, w * 0.6)
		_:
			ci.draw_circle(p, s * 0.6, c)


func _texte(ci: CanvasItem, p: Vector2, s: String, fs: int, col: Color) -> void:
	var police := ThemeDB.fallback_font
	var l := police.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(police, Vector2(p.x - l * 0.5, p.y + (police.get_ascent(fs) - police.get_descent(fs)) * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# ====================================================================== dessin de l'arbre
class Arbre extends Control:
	## Angle (degrés, 0 = droite, sens horaire à l'écran) de chaque branche et du départ de chaque compétence.
	const ANGLES := {"melee": -120.0, "tir": -60.0, "fabrication": 0.0, "survie": 60.0, "chasse": 120.0, "exploration": 180.0}
	const HUBS := {"combat": -90.0, "fabrication": 0.0, "survie": 60.0, "chasse": 120.0, "exploration": 180.0}
	const ATTR_ANGLES := {"endurance": -150.0, "sante": -30.0, "faim": 30.0, "soif": 150.0}
	const R_HUB := 175.0       # distance du départ de chaque compétence au centre
	const PAS := 108.0         # distance entre deux rangs
	const COTE := 100.0        # écart des nœuds de côté
	const R_NOEUD := 24.0
	const R_HUB_NOEUD := 34.0
	const R_ATTR := 18.0
	const R_CENTRE := 42.0
	var etendue := Vector2(600, 400)        # demi-taille de l'arbre (calculée dans _init)
	const ECRASE := Vector2(1.22, 0.7)    # arbre étiré en largeur : les écrans sont plus larges que hauts

	var ui
	var zoom := 1.0
	var centre := Vector2.ZERO          # position du survivant à l'écran
	var glisse := false
	var appui := Vector2.ZERO
	var deplace := false
	var survol := ""
	var pos := {}                        # id -> position dans l'arbre (zoom 1, centre = 0)
	var parent_de := {}                  # id -> id du nœud parent (traits)
	var parent2_de := {}                 # pont -> son second parent
	var rang_max := {}                   # branche -> rang le plus éloigné
	var titres := {}                     # branche -> position du titre

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		pos["centre"] = Vector2.ZERO
		for c in HUBS:
			pos["hub:" + c] = _dir(HUBS[c]) * R_HUB * ECRASE
			parent_de["hub:" + c] = "centre"
		for a in ATTR_ANGLES:
			pos["attr:" + a] = _dir(ATTR_ANGLES[a]) * 108.0 * ECRASE
		for id in Progression.TALENTS:
			var t: Dictionary = Progression.TALENTS[id]
			if t.get("pont", false):
				continue
			var ang: float = ANGLES[t.br]
			pos[id] = _dir(ang) * (R_HUB + float(t.d) * PAS) * ECRASE + _dir(ang + 90.0) * float(t.l) * COTE
			parent_de[id] = t.apres if t.apres != "" else "hub:" + str(t.comp)
			rang_max[t.br] = maxi(int(rang_max.get(t.br, 0)), int(t.d))
		# ponts entre deux branches : entre leurs deux parents, un peu vers l'extérieur
		for id in Progression.TALENTS:
			var t: Dictionary = Progression.TALENTS[id]
			if t.get("pont", false):
				var m: Vector2 = (pos[t.apres] + pos[t.apres2]) * 0.5
				pos[id] = m + m.normalized() * 60.0
				for essai in 12:   # écarté vers l'extérieur tant qu'il touche un autre nœud
					var libre := true
					for autre in pos:
						if autre != id and pos[autre].distance_to(pos[id]) < 95.0:
							libre = false
							break
					if libre:
						break
					pos[id] += m.normalized() * 22.0
				parent_de[id] = t.apres
				parent2_de[id] = t.apres2
		# titres des branches : au bout du bras (horizontal) ou à côté du dernier nœud, vers l'extérieur (diagonale)
		for br in ANGLES:
			var ang: float = ANGLES[br]
			var n := float(rang_max.get(br, 5))
			var pt := _dir(ang) * (R_HUB + (n + 1.0) * PAS) * ECRASE
			if absf(sin(deg_to_rad(ang))) > 0.5:
				var cote := _dir(ang + 90.0)
				if cote.x * _dir(ang).x < 0.0:
					cote = -cote
				pt = _dir(ang) * (R_HUB + n * PAS) * ECRASE + cote * 2.6 * COTE
			titres[br] = pt
		# demi-taille de l'arbre (noms et titres compris) pour le zoom de départ et les bornes du déplacement
		for p in pos.values() + titres.values():
			etendue = etendue.max(Vector2(absf(p.x) + 90.0, absf(p.y) + 55.0))

	static func _dir(deg: float) -> Vector2:
		return Vector2.from_angle(deg_to_rad(deg))

	## Centre l'arbre et choisit un zoom qui le fait tenir dans l'écran (lisible au moins à 0,5).
	func recentrer() -> void:
		var haut := 110.0
		var dispo := size - Vector2(40, haut + 50)
		zoom = clampf(minf(dispo.x / (2.0 * etendue.x), dispo.y / (2.0 * etendue.y)), 0.5, 1.3)
		centre = Vector2(size.x * 0.5, haut + (size.y - haut - 40) * 0.5)
		queue_redraw()

	func vers_ecran(p: Vector2) -> Vector2:
		return centre + p * zoom

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoomer(1.15, mb.position)
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoomer(1.0 / 1.15, mb.position)
			elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
				if mb.pressed:
					glisse = true
					deplace = false
					appui = mb.position
				else:
					glisse = false
					if not deplace and mb.button_index == MOUSE_BUTTON_LEFT:
						var id := _sous(mb.position)
						if id != "":
							ui.activer(id)
							ui.montrer_bulle(id, mb.position)
			accept_event()
		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if glisse and (deplace or mm.position.distance_to(appui) > 5.0):
				deplace = true
				centre += mm.relative
				_borner()
				ui.montrer_bulle("", mm.position)
			else:
				var id := _sous(mm.position)
				if id != survol:
					survol = id
				ui.montrer_bulle(id, mm.position)

	func _zoomer(f: float, souris: Vector2) -> void:
		var avant := zoom
		zoom = clampf(zoom * f, 0.4, 2.0)
		centre = souris + (centre - souris) * (zoom / avant)
		_borner()
		ui.montrer_bulle(_sous(souris), souris)

	## L'arbre ne sort jamais entièrement de l'écran.
	func _borner() -> void:
		var e := etendue * zoom
		centre.x = clampf(centre.x, 120.0 - e.x, size.x - 120.0 + e.x)
		centre.y = clampf(centre.y, 160.0 - e.y, size.y - 120.0 + e.y)

	func _rayon(id: String) -> float:
		if id == "centre":
			return R_CENTRE
		if id.begins_with("hub:"):
			return R_HUB_NOEUD
		if id.begins_with("attr:"):
			return R_ATTR
		return R_NOEUD

	func _sous(m: Vector2) -> String:
		var meilleur := ""
		var best := INF
		for id in pos:
			var d := vers_ecran(pos[id]).distance_to(m)
			if d < (_rayon(id) + 6.0) * zoom and d < best:
				best = d
				meilleur = id
		return meilleur

	func _comp_de(id: String) -> String:
		if id.begins_with("hub:"):
			return id.substr(4)
		if Progression.TALENTS.has(id):
			return Progression.TALENTS[id].comp
		return ""

	## "acquis", "dispo" ou "verrou" pour un talent.
	func _etat(pr, id: String) -> String:
		if pr.a(id):
			return "acquis"   # au moins un rang (le rang suivant éventuel est signalé à part)
		return "dispo" if pr.peut_debloquer(id) else "verrou"

	func _draw() -> void:
		if Game.player == null:
			return
		var pr = Game.player.prog
		var police := get_theme_default_font()
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		var ep := maxf(1.5, 3.0 * zoom)
		# --- titres des branches, au bout de chaque bras
		var fs_titre := int(clampf(18.0 * sqrt(zoom), 12.0, 28.0))
		for br in ANGLES:
			var c: String = Progression.BRANCHES[br].comp
			var p: Vector2 = vers_ecran(titres[br])
			var col: Color = ui.COULEURS[c]
			col.a = 0.75
			_texte_centre(police, p, Progression.BRANCHES[br].nom.to_upper(), fs_titre, col)
		# --- traits
		var liens: Array = []
		for id in parent_de:
			liens.append([parent_de[id], id])
		for id in parent2_de:
			liens.append([parent2_de[id], id])
		for lien in liens:
			var par: String = lien[0]
			var id: String = lien[1]
			var a: Vector2 = vers_ecran(pos[par])
			var b: Vector2 = vers_ecran(pos[id])
			var c2 := _comp_de(id)
			var col: Color = COUL_VERROU
			var w := ep * 0.7
			if id.begins_with("hub:"):
				col = Color(ui.COULEURS[c2], 0.55)
			else:
				match _etat(pr, id):
					"acquis":
						col = ui.COULEURS[c2]
						w = ep
					"dispo":
						col = COUL_DISPO.lerp(Color(0.5, 0.45, 0.2), 0.5 - 0.5 * pulse)
						w = ep
			var u := (b - a).normalized()
			if parent2_de.has(id):   # pont entre deux branches : trait en pointillés
				draw_dashed_line(a + u * _rayon(par) * zoom, b - u * _rayon(id) * zoom, col, w, 8.0 * zoom, true, true)
			else:
				draw_line(a + u * _rayon(par) * zoom, b - u * _rayon(id) * zoom, col, w, true)
		# --- nœuds
		var fs := int(clampf(15.5 * sqrt(zoom), 11.0, 24.0))
		var noms := zoom >= 0.5
		for id in pos:
			var p: Vector2 = vers_ecran(pos[id])
			var r := _rayon(id) * zoom
			if p.x < -r - 120 or p.y < -r - 60 or p.x > size.x + r + 120 or p.y > size.y + r + 60:
				continue
			var hover: bool = id == survol
			if id == "centre":
				draw_circle(p, r, Color(0.16, 0.15, 0.1))
				draw_arc(p, r, 0, TAU, 48, Color(0.95, 0.85, 0.5), ep, true)
				_texte_centre(police, p + Vector2(0, -fs * 0.15), "Niv. %d" % pr.niveau, int(fs * 1.15), Color(0.95, 0.85, 0.5))
				_texte_centre(police, p + Vector2(0, r + fs * 0.9), "Survivant", fs, Color(0.85, 0.85, 0.8))
			elif id.begins_with("hub:"):
				var c: String = id.substr(4)
				var col: Color = ui.COULEURS[c]
				var d: Dictionary = pr.comp[c]
				draw_circle(p, r, col.darkened(0.6))
				var k := 0.0 if d.niv >= Progression.NIVEAU_MAX_COMP else float(d.xp) / maxf(1.0, Progression.xp_comp(d.niv))
				draw_arc(p, r, 0, TAU, 48, col.darkened(0.3), ep, true)
				if d.niv >= Progression.NIVEAU_MAX_COMP:
					draw_arc(p, r, 0, TAU, 48, col, ep * 1.4, true)
				elif k > 0.0:
					draw_arc(p, r, -PI / 2.0, -PI / 2.0 + TAU * k, 48, col.lightened(0.2), ep * 1.4, true)   # XP du niveau
				_texte_centre(police, p + Vector2(0, -fs * 0.1), str(d.niv), int(fs * 1.4), Color.WHITE)
				if d.points > 0:   # pastille : points de talent à dépenser dans cette compétence
					var pp := p + Vector2(r * 0.75, -r * 0.75)
					draw_circle(pp, fs * 0.75, COUL_DISPO)
					_texte_centre(police, pp, str(d.points), int(fs * 0.9), Color(0.1, 0.08, 0.02))
			elif id.begins_with("attr:"):
				var at: String = id.substr(5)
				var n: int = pr.attributs[at]
				var dispo: bool = pr.points > 0
				draw_circle(p, r, Color(0.2, 0.18, 0.1) if n > 0 else Color(0.11, 0.11, 0.1))
				var bord := COUL_DISPO.lerp(Color(0.5, 0.45, 0.2), 0.5 - 0.5 * pulse) if dispo else (Color(0.8, 0.7, 0.4) if n > 0 else COUL_VERROU)
				draw_arc(p, r, 0, TAU, 32, bord, ep * (1.2 if dispo else 0.8), true)
				_texte_centre(police, p + Vector2(0, -fs * 0.1), "+%d" % n if n > 0 else "+", int(fs * 0.95), Color.WHITE if n > 0 else Color(0.7, 0.7, 0.66))
				if noms:
					_texte_centre(police, p + Vector2(0, r + fs * 0.8), Progression.ATTRIBUTS[at].nom, int(fs * 0.9), Color(0.85, 0.8, 0.6))
			else:
				var t: Dictionary = Progression.TALENTS[id]
				var col: Color = ui.COULEURS[t.comp]
				var etat := _etat(pr, id)
				var encore: bool = etat == "acquis" and pr.peut_debloquer(id)   # rang suivant disponible
				var teinte := Color.WHITE
				match etat:
					"acquis":
						draw_circle(p, r, col.darkened(0.45))
						draw_arc(p, r, 0, TAU, 40, col.lightened(0.3), ep, true)
					"dispo":
						draw_circle(p, r, Color(0.2, 0.18, 0.08))
						teinte = Color(1, 1, 1, 0.85)
					_:
						draw_circle(p, r, Color(0.1, 0.1, 0.1))
						draw_arc(p, r, 0, TAU, 40, col.darkened(0.55) if pr.comp[t.comp].niv >= pr.niv_requis(id) else COUL_VERROU, ep * 0.8, true)
						teinte = Color(0.5, 0.5, 0.5, 0.55)
				if etat == "dispo" or encore:
					draw_arc(p, r + 3.0 * zoom * pulse, 0, TAU, 40, COUL_DISPO, ep * 1.2, true)
				if t.get("pont", false):   # pont : losange autour du nœud
					var q := r * 1.32
					draw_polyline(PackedVector2Array([p + Vector2(0, -q), p + Vector2(q, 0), p + Vector2(0, q), p + Vector2(-q, 0), p + Vector2(0, -q)]), col.lightened(0.2) if etat != "verrou" else COUL_VERROU, maxf(1.0, ep * 0.6), true)
				ui.dessiner_icone(self, id, p, r * 1.25, teinte)
				var pb := fs * 0.62   # rayon des pastilles
				if etat == "acquis":
					var pc := p + Vector2(r * 0.78, -r * 0.78)
					draw_circle(pc, pb, Color(0.3, 0.75, 0.3))
					_texte_centre(police, pc, "✔", int(fs * 0.75), Color.WHITE)
				if etat != "acquis" or encore:   # niveau requis (pour le prochain rang)
					var pn := p + Vector2(r * 0.78, r * 0.78)
					draw_circle(pn, pb, Color(0.12, 0.12, 0.11))
					draw_arc(pn, pb, 0, TAU, 16, COUL_DISPO if etat == "dispo" or encore else Color(0.45, 0.45, 0.43), maxf(1.0, ep * 0.4), true)
					_texte_centre(police, pn, str(pr.niv_requis(id)), int(fs * 0.72), COUL_DISPO if etat == "dispo" or encore else Color(0.7, 0.7, 0.68))
				if Progression.rangs_max(id) > 1:
					var pr2 := p + Vector2(-r * 0.85, r * 0.78)
					var txt := "%d/%d" % [pr.rang(id), Progression.rangs_max(id)]
					draw_rect(Rect2(pr2 - Vector2(fs * 0.85, pb * 0.85), Vector2(fs * 1.7, pb * 1.7)), Color(0.12, 0.12, 0.11))
					_texte_centre(police, pr2, txt, int(fs * 0.68), Color(0.95, 0.9, 0.7))
				if hover:
					draw_arc(p, r + 6.0 * zoom, 0, TAU, 40, Color(1, 1, 1, 0.7), maxf(1.0, ep * 0.6), true)
				if noms:
					var cn := Color(0.92, 0.92, 0.88) if etat != "verrou" else Color(0.55, 0.56, 0.54)
					var lignes := _couper(t.nom)
					for i in lignes.size():
						_texte_centre(police, p + Vector2(0, r + fs * (0.85 + 1.05 * i)), lignes[i], fs, cn)

	## Nom sur deux lignes s'il est long.
	func _couper(s: String) -> PackedStringArray:
		if s.length() <= 11 or not " " in s:
			return PackedStringArray([s])
		var milieu := s.length() / 2
		var best := -1
		for i in s.length():
			if s[i] == " " and (best < 0 or absi(i - milieu) < absi(best - milieu)):
				best = i
		return PackedStringArray([s.substr(0, best), s.substr(best + 1)])

	## Texte centré horizontalement sur p (p.y = milieu de la ligne).
	func _texte_centre(police: Font, p: Vector2, s: String, fs: int, col: Color) -> void:
		var l := police.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y := p.y + (police.get_ascent(fs) - police.get_descent(fs)) * 0.5
		draw_string_outline(police, Vector2(p.x - l * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, fs / 5), Color(0, 0, 0, 0.85))
		draw_string(police, Vector2(p.x - l * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
