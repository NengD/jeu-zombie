extends CanvasLayer
## Écran « État du survivant » (touche J, action « etat ») : chaque état du joueur avec sa valeur, sa cause,
## ce qu'il fait au personnage et le soin conseillé ; silhouette avec les zones touchées ; effets actifs
## (vêtements chauds, feu, abri). Mis à jour 4 fois par seconde tant qu'il est ouvert. Créé par hud.gd.

const COUL_OK := Color(0.55, 0.85, 0.5)
const COUL_ALERTE := Color(1.0, 0.72, 0.3)
const COUL_GRAVE := Color(1.0, 0.38, 0.32)
const COUL_FROID := Color(0.55, 0.78, 1.0)
const COUL_DOUX := Color(0.66, 0.68, 0.64)

var fond: ColorRect
var silhouette: Silhouette
var texte: RichTextLabel
var conseil: RichTextLabel
var _t := 0.0


func _ready() -> void:
	layer = 7
	visible = false
	process_mode = Node.PROCESS_MODE_PAUSABLE   # le HUD (parent) tourne même en pause
	add_to_group("etat_ui")
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
	titre.text = "ÉTAT DU SURVIVANT"
	titre.add_theme_font_size_override("font_size", 28)
	titre.add_theme_color_override("font_color", Color(0.92, 0.9, 0.8))
	col.add_child(titre)
	conseil = RichTextLabel.new()
	conseil.bbcode_enabled = true
	conseil.fit_content = true
	conseil.add_theme_font_size_override("normal_font_size", 18)
	conseil.add_theme_font_size_override("bold_font_size", 18)
	col.add_child(conseil)
	var ligne := HBoxContainer.new()
	ligne.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ligne.add_theme_constant_override("separation", 30)
	col.add_child(ligne)
	silhouette = Silhouette.new()
	silhouette.custom_minimum_size = Vector2(220, 420)
	silhouette.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ligne.add_child(silhouette)
	texte = RichTextLabel.new()
	texte.bbcode_enabled = true
	texte.scroll_active = true
	texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texte.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texte.add_theme_font_size_override("normal_font_size", 16)
	texte.add_theme_font_size_override("bold_font_size", 17)
	ligne.add_child(texte)
	var aide := Label.new()
	aide.text = "[J] ou Échap : fermer    [H] : appliquer le soin conseillé"
	aide.add_theme_font_size_override("font_size", 14)
	aide.add_theme_color_override("font_color", COUL_DOUX)
	col.add_child(aide)


func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("etat") or event.is_action_pressed("pause"):
			fermer()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("soigner") and Game.player:
			var s: String = Game.player._soin_conseille()
			if s != "":
				Game.player.use_item(s)
			else:
				Game.msg("Aucun soin utile dans ton sac.")
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("etat") and not Game.ui_open and Game.player and Game.player.alive:
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
	if not visible:
		return
	_t -= delta
	if _t <= 0.0:
		_t = 0.25
		maj()


# ====================================================================== contenu
static func _c(col: Color, t: String) -> String:
	return "[color=#%s]%s[/color]" % [col.to_html(false), t]


## Objet de soin : nom et quantité dans le sac (rouge s'il manque).
static func _soin(p, id: String) -> String:
	var n: int = p.count(id) if Items.DB.has(id) else 0
	return _c(COUL_OK if n > 0 else COUL_GRAVE, "%s (%s)" % [Items.nom(id), ("tu en as %d" % n) if n > 0 else "tu n'en as pas"])


static func _soins(p, ids: Array) -> String:
	var t: Array = []
	for id in ids:
		t.append(_soin(p, id))
	return " ou ".join(t)


## Un bloc : titre + valeur, puis cause / effet / soin (lignes vides omises).
static func _bloc(titre: String, valeur: String, col: Color, cause: String, effet: String, soin: String) -> String:
	var t := "[b]%s[/b]  %s\n" % [_c(col, titre), _c(col, valeur)]
	if cause != "":
		t += "    Cause : %s\n" % cause
	if effet != "":
		t += "    Effet : %s\n" % effet
	if soin != "":
		t += "    Soin : %s\n" % soin
	return t + "\n"


func maj() -> void:
	var p = Game.player
	if p == null:
		return
	var pr = p.prog
	var sm: float = pr.sante_max()
	var em: float = pr.endurance_max()
	# --- soin conseillé en haut
	var s: String = p._soin_conseille()
	conseil.text = ("[H] utiliserait : [b]%s[/b]" % _soin(p, s)) if s != "" else _c(COUL_OK, "Rien à soigner pour l'instant (ou aucun soin utile dans ton sac).")
	var t := ""
	# --- santé
	var regen := "remonte doucement"
	if p.hunger <= 0.0 or p.thirst <= 0.0:
		regen = _c(COUL_GRAVE, "baisse : tu meurs de faim ou de soif")
	elif p.health >= sm - 0.5:
		regen = "au maximum"
	elif p.saignement > 0.0:
		regen = "ne remonte pas (saignement)"
	elif p.infection >= 30.0:
		regen = "ne remonte pas (fièvre)"
	elif p.froid > 50.0:
		regen = "ne remonte pas (froid)"
	elif p.hunger <= 50.0 or p.thirst <= 50.0:
		regen = "ne remonte que si faim et soif sont au-dessus de 50"
	var k_sante: float = p.health / sm
	t += _bloc("Santé", "%d / %d" % [ceili(p.health), roundi(sm)], COUL_OK if k_sante > 0.6 else (COUL_ALERTE if k_sante > 0.3 else COUL_GRAVE),
		"", regen + (" ; sous 35 %, tu boites et te tiens le flanc" if k_sante < 0.35 else ""),
		_soins(p, ["bandage", "trousse", "antidouleur"]) if p.health < sm - 0.5 else "")
	# --- faim, soif
	for b in [["Faim", p.hunger, "manger (conserves, viande cuite, fruits…)"], ["Soif", p.thirst, "boire (eau, soda ; eau du lac à faire bouillir)"]]:
		var v: float = b[1]
		var eff := "aucun"
		if v <= 0.0:
			eff = _c(COUL_GRAVE, "tu perds de la santé")
		elif v <= 50.0:
			eff = "la santé ne remonte plus"
		t += _bloc(b[0], "%d %%" % roundi(v), COUL_OK if v > 50.0 else (COUL_ALERTE if v > 20.0 else COUL_GRAVE), "", eff, b[2] if v < 70.0 else "")
	# --- endurance : plafonds actifs
	var plafonds: Array = []
	var plafond := 1.0
	if p.maladie > 0.0:
		plafond = minf(plafond, 0.6)
		plafonds.append("intoxication 60 %")
	if p.froid > 50.0:
		var f := 0.7 if p.froid < 80.0 else 0.5
		plafond = minf(plafond, f)
		plafonds.append("froid %d %%" % roundi(f * 100.0))
	if p.infection > 0.0:
		var fi: float = 1.0 - 0.5 * p.infection / 100.0
		plafond = minf(plafond, fi)
		plafonds.append("fièvre %d %%" % roundi(fi * 100.0))
	t += _bloc("Endurance", "%d / %d" % [roundi(p.stamina), roundi(em * plafond)], COUL_OK if plafond >= 1.0 else COUL_ALERTE,
		"", ("plafonnée : " + ", ".join(plafonds)) if not plafonds.is_empty() else "normale", "")
	# --- blessures
	if p.saignement > 0.0:
		t += _bloc("Saignement", "encore %d s" % ceili(p.saignement), COUL_GRAVE, p.causes.get("saignement", "blessure"),
			"-%s santé par seconde, la santé ne remonte plus" % ("%.1f" % p.SAIGNE_PV).replace(".", ","), _soins(p, ["bandage", "trousse"]))
	if p.morsure_t > 0.0:
		var r: float = p.morsure_risque * (0.3 if p.plaie_desinfectee else 1.0)
		t += _bloc("Morsure", "%d s avant de savoir si elle s'infecte" % ceili(p.morsure_t), COUL_ALERTE, "morsure de zombie",
			"risque d'infection %d %%%s" % [roundi(r * 100.0), " (plaie désinfectée)" if p.plaie_desinfectee else ""],
			(("désinfecter : " + _soin(p, "alcool") + ", ou ") if not p.plaie_desinfectee else "") + "prévenir : " + _soin(p, "antibiotiques"))
	if p.infection > 0.0:
		var eff := "soif plus rapide, endurance réduite"
		if p.infection > 60.0:
			eff += _c(COUL_GRAVE, ", la santé baisse")
		t += _bloc("Infection", "fièvre %d %%" % roundi(p.infection), COUL_GRAVE, p.causes.get("infection", "plaie infectée"),
			eff + " ; la fièvre monte (%s)" % ("lentement : Guérison" if pr.a("medecin") else "~18 min jusqu'au maximum"), _soin(p, "antibiotiques"))
	if p.fracture:
		t += _bloc("Fracture", "jambe cassée", COUL_GRAVE, p.causes.get("fracture", "chute ou gros coup"),
			"tu boites, pas de sprint, saut réduit", _soin(p, "attelle") + "  — attelle : 1 planche + 2 tissus, à la main")
	if p.maladie > 0.0:
		t += _bloc("Intoxication", "encore %d min" % ceili(p.maladie / 60.0), COUL_ALERTE, p.causes.get("maladie", "nourriture crue ou eau sale"),
			"faim et soif plus rapides, endurance plafonnée à 60 %, nausées", _soin(p, "medicament"))
	# --- température
	var bilan: float = p.bilan_temperature()
	var etat_froid := "bien"
	var col_froid := COUL_OK
	if p.froid > 80.0:
		etat_froid = "transi de froid"
		col_froid = COUL_GRAVE
	elif p.froid > 50.0:
		etat_froid = "froid"
		col_froid = COUL_FROID
	elif p.froid > 25.0:
		etat_froid = "frais"
		col_froid = COUL_FROID
	var causes_froid: Array = []
	if Game.is_night():
		causes_froid.append("nuit")
	if Game.pluie > 0.1 and p.in_zone.is_empty():
		causes_froid.append("pluie")
	if Game.dans_eau(p.global_position):
		causes_froid.append("dans l'eau")
	var eff_froid := "aucun"
	if p.froid > 80.0:
		eff_froid = _c(COUL_GRAVE, "endurance au plus 50 %, la santé baisse")
	elif p.froid > 50.0:
		eff_froid = "endurance au plus 70 %, la santé ne remonte plus"
	var tendance := "stable"
	if bilan > 0.005:
		tendance = "tu te refroidis (+%d par minute)" % roundi(bilan * 60.0)
	elif bilan < -0.005 and p.froid > 0.0:
		tendance = "tu te réchauffes (%d par minute)" % roundi(bilan * 60.0)
	t += _bloc("Température", "%s (froid %d / 100) — %s" % [etat_froid, roundi(p.froid), tendance], col_froid,
		", ".join(causes_froid) if not causes_froid.is_empty() else "", eff_froid,
		"feu de camp, abri, vêtements chauds" if p.froid > 25.0 else "")
	# --- effets actifs
	var actifs: Array = []
	var vet: Array = []
	for sl in p.equipped:
		var e: Dictionary = p.equipped[sl]
		if not e.is_empty() and float(Items.info(e.id).get("chaleur", 0.0)) > 0.0:
			vet.append("%s +%d %%" % [Items.nom(e.id), roundi(float(Items.info(e.id).chaleur) * 100.0)])
	if not vet.is_empty():
		actifs.append("Vêtements chauds : " + ", ".join(vet))
	actifs.append("Protection contre le froid : %d %%" % roundi((1.0 - p.protection_froid()) * 100.0))
	if p.pres_feu:
		actifs.append(_c(COUL_OK, "Près d'un feu : tu te réchauffes vite"))
	if not p.in_zone.is_empty():
		actifs.append(_c(COUL_OK, "À l'abri : %s" % (p.in_zone.name if p.in_zone.name != "" else "intérieur")))
	if p.armor_total() > 0.0:
		actifs.append("Armure : -%d %% de dégâts, moins de morsures et de saignements" % roundi(p.armor_total() * 100.0))
	t += "[b]%s[/b]\n    %s\n" % [_c(Color(0.92, 0.9, 0.8), "Effets actifs"), "\n    ".join(actifs)]
	texte.text = t
	silhouette.p = p
	silhouette.queue_redraw()


# ====================================================================== silhouette
## Personnage stylisé : zones colorées selon les blessures (jambe cassée, torse qui saigne, bras mordu,
## ventre intoxiqué), contour bleu quand on a froid, rouge selon la santé perdue.
class Silhouette extends Control:
	var p = null

	func _zone(r: Rect2, col: Color) -> void:
		draw_rect(r, col)
		draw_rect(r, col.darkened(0.45), false, 2.0)

	func _draw() -> void:
		if p == null:
			return
		var w := size.x
		var cx := w * 0.5
		var k := minf(w / 220.0, size.y / 420.0)
		var base := Color(0.42, 0.44, 0.42)
		var perdu: float = clampf(1.0 - p.health / p.prog.sante_max(), 0.0, 1.0)
		base = base.lerp(Color(0.6, 0.25, 0.22), perdu * 0.6)
		var rouge := Color(0.85, 0.2, 0.16)
		var torse := base
		if p.saignement > 0.0:
			torse = rouge
		var bras_g := base
		if p.infection > 0.0:
			bras_g = Color(0.55, 0.7, 0.25)
		elif p.morsure_t > 0.0:
			bras_g = Color(0.8, 0.45, 0.2)
		var jambe_g := Color(0.95, 0.55, 0.15) if p.fracture else base
		# contour de froid
		if p.froid > 25.0:
			var a: float = clampf((p.froid - 25.0) / 75.0, 0.15, 0.9)
			draw_circle(Vector2(cx, 48 * k), 40 * k, Color(0.5, 0.75, 1.0, a * 0.35))
			draw_rect(Rect2(cx - 78 * k, 80 * k, 156 * k, 330 * k), Color(0.5, 0.75, 1.0, a * 0.25))
		# tête
		draw_circle(Vector2(cx, 48 * k), 30 * k, base.lerp(Color(0.85, 0.35, 0.25), clampf(p.infection / 100.0, 0.0, 1.0) * 0.7))
		# torse, bras, jambes
		_zone(Rect2(cx - 42 * k, 86 * k, 84 * k, 130 * k), torse)
		_zone(Rect2(cx - 70 * k, 90 * k, 24 * k, 120 * k), bras_g)     # bras gauche (à gauche de l'écran : vu de dos)
		_zone(Rect2(cx + 46 * k, 90 * k, 24 * k, 120 * k), base)
		_zone(Rect2(cx - 40 * k, 222 * k, 36 * k, 180 * k), jambe_g)
		_zone(Rect2(cx + 4 * k, 222 * k, 36 * k, 180 * k), base)
		if p.maladie > 0.0:
			draw_circle(Vector2(cx, 180 * k), 16 * k, Color(0.5, 0.75, 0.25, 0.85))
		if p.fracture:
			draw_line(Vector2(cx - 40 * k, 300 * k), Vector2(cx - 4 * k, 318 * k), Color(0.1, 0.05, 0.0), 3.0)
		if p.saignement > 0.0:
			for i in 3:
				draw_circle(Vector2(cx - 12 * k + i * 12 * k, (226 + i * 9) * k), 4 * k, rouge)
