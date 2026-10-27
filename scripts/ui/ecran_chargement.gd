extends CanvasLayer
## Écran de chargement entre le menu et la partie : image d'ambiance, titre, barre de progression,
## astuce au hasard (changée toutes les 5 s) et infos de la partie (saison et jour, ou lieu de départ).
## `lancer(arbre)` charge scenes/main.tscn dans un fil (barre animée), puis change de scène. La génération
## du monde (main._ready) bloque le fil principal : chaque étape de `world._chrono` appelle `etape(nom, ms)`,
## qui avance la barre et force le rendu d'une image (RenderingServer.force_draw). Pendant ce blocage,
## les nœuds ne se redessinent pas : la barre et les textes qui changent sont dessinés directement dans
## un canvas item à soi (`_dyn`). Poids des étapes = durées mesurées à la partie précédente (user://chargement.cfg).

const Saisons = preload("res://scripts/saisons.gd")
const LieuxDepart = preload("res://scripts/lieux_depart.gd")
const SCENE := "res://scenes/main.tscn"
const FICHIER := "user://chargement.cfg"
const FONDS := ["res://textures/ui/chargement_1.jpg", "res://textures/ui/chargement_2.jpg", "res://textures/ui/chargement_3.jpg"]
const ASTUCE_DUREE := 5.0

## [clé de world.chrono, texte affiché pendant l'étape, durée par défaut en ms (mesurée le 27/10)]
const ETAPES := [
	["ressources", "Chargement des modèles et des sons", 3600],
	["ville", "Construction de Bellerive", 1750],
	["campagne", "Campagne et base militaire", 340],
	["regions", "Valmont, villages, fermes et lieux", 1800],
	["relief", "Relief, lacs et rivière", 1780],
	["arbres", "Forêts et végétation", 540],
	["commit", "Assemblage du monde", 350],
	["marche", "Campements des marchands", 870],
	["camps", "Camps de bandits", 380],
	["ambiance", "Lumières et ambiance", 1000],
	["morceaux", "Préparation des alentours", 330],
	["zombies", "Réveil des morts", 240],
	["joueur_ui", "Arrivée du survivant", 40],
]

const ASTUCES := [
	"Les zombies lèvent les bras avant de frapper : recule ou fais une roulade à ce moment-là.",
	"Accroupis-toi en plein sprint pour faire une roulade : les coups au corps à corps passent au-dessus.",
	"Une flèche tire sans bruit : un zombie qui ne te poursuit pas meurt sans donner l'alerte.",
	"Couvert de tripes de zombie (G sur un cadavre, avec une lame), tu passes au milieu d'eux… tant que tu ne cours pas.",
	"La pluie lave le déguisement de tripes cinq fois plus vite, et l'eau l'efface presque aussitôt.",
	"Un réveil ou une radio posé fait du bruit en boucle : les zombies viennent le frapper au lieu de te chercher.",
	"Les pétards ne blessent personne mais s'entendent à 120 m : parfait pour vider une rue.",
	"Une morsure non désinfectée peut tourner à l'infection : l'alcool réduit fortement le risque.",
	"Un saignement empêche la santé de remonter et le sommeil : bande-le d'abord ([H] applique le soin conseillé).",
	"Une grosse chute peut casser une jambe : une attelle soigne la fracture.",
	"[J] ouvre l'état du survivant : chaque blessure, sa cause et le soin qu'il te faut.",
	"La viande crue et l'eau sale peuvent rendre malade : cuis-les au feu de camp, ou trouve des médicaments.",
	"La nourriture se gâte avec le temps, plus vite en été : un frigo alimenté la garde trois fois plus longtemps.",
	"Toutes les 7 nuits, une nuit de sang : des hordes bien plus grosses. Prépare ta base la veille.",
	"Chaque semaine, les zombies sont plus nombreux et les hordes plus grosses.",
	"En hiver, le froid t'épuise : vêtements chauds, abri et feu de camp à moins de 6 m te réchauffent.",
	"Les saisons durent 7 jours : rien ne pousse en hiver, les pommes et le raisin ont leur saison.",
	"Un bac de culture arrosé (même à l'eau sale) donne des légumes en quelques jours ; la pluie l'arrose dehors.",
	"Un groupe électrogène alimente lampes, frigo et clôture électrique à 15 m de proche en proche… mais il fait du bruit.",
	"Une voiture sur cinq environ peut repartir : il lui faut des pièces auto, une batterie ou un jerrican.",
	"Le coffre de ta voiture sert de rangement : « Ma voiture » est marquée sur la carte et la boussole.",
	"Avec un tuyau, siphonne le réservoir des épaves pour remplir un jerrican.",
	"La hache abat les arbres, la pioche brise les rochers ; les épaves donnent ferraille, pneus et batteries.",
	"Les marchands rachètent leurs spécialités (★) bien plus cher : vends au bon métier.",
	"Les marchands passent des commandes chaque jour, et l'armurier paie une prime pour chaque camp de bandits nettoyé.",
	"Les camps de bandits nettoyés sont réoccupés au bout de 5 à 7 jours.",
	"Un camp de base est sauvegardé automatiquement quand tu y arrives, et toutes les 10 minutes.",
	"Le marteau pose, renforce et répare la base (B) : bois, puis tôle, puis parpaing.",
	"La fabrication puise aussi dans les caisses de stockage à moins de 12 m.",
	"Démonte ce qui ne sert plus (clic droit > Démonter) : on récupère la moitié des matériaux.",
	"[K] ouvre l'arbre de compétences : chaque compétence gagne de l'expérience en la pratiquant.",
	"[O] ouvre le journal : statistiques, objectifs récompensés et succès.",
	"Sur la carte (M), le clic droit pose un marqueur qui apparaît ensuite sur la boussole.",
	"Les armes s'usent : un kit de réparation (et une clé à molette pour les armes à feu) les remet en état.",
	"Les loups et les chiens sauvages chassent en meute ; ils fuient quand ils sont blessés.",
	"Une canne à pêche posée près de l'eau attrape des poissons pendant que tu es ailleurs.",
	"[T] inspecte l'arme en main et y pose les accessoires : viseurs, silencieux, poignées…",
]

signal dessinee(nom: String)   # image forcée pendant la génération (captures de test)

static var actuel = null   # écran affiché (null : pas d'écran, ex. scripts de test qui créent main directement)

var infos := ""
var progres := 0.0          # 0..1 affiché
var cible := 0.0            # 0..1 visé
var etape_n := 0            # n° de l'étape en cours dans ETAPES
var poids := {}             # clé -> ms
var total := 0.0
var t_debut := 0
var t_ressources := 0
var t_dessin := 0
var t_astuce := 0
var astuces: Array = []
var astuce_i := 0
var charge_lancee := false
var fini := false
var dessin_force := true
var racine: Control
var fond: TextureRect
var _dyn: RID
var _police: Font


## Affiche l'écran et charge la partie (Game.partie_a_charger rempli = partie sauvegardée).
static func lancer(arbre: SceneTree) -> void:
	if actuel != null:
		return
	var e = load("res://scripts/ui/ecran_chargement.gd").new()
	arbre.root.add_child(e)
	actuel = e


## Appelé par world._chrono à la fin de chaque étape de la génération (fil principal bloqué).
static func etape(nom: String, ms: int) -> void:
	if actuel != null:
		actuel._etape(nom, ms)


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	t_debut = Time.get_ticks_msec()
	t_astuce = t_debut
	dessin_force = DisplayServer.get_name() != "headless"
	_police = ThemeDB.fallback_font
	_lire_poids()
	astuces = ASTUCES.duplicate()
	astuces.shuffle()
	infos = _texte_infos()
	racine = Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(racine)
	var noir := ColorRect.new()
	noir.color = Color(0.02, 0.02, 0.02)
	noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.add_child(noir)
	fond = TextureRect.new()
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fond.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var dispo := FONDS.filter(func(f): return ResourceLoader.exists(f))
	if not dispo.is_empty():
		fond.texture = load(dispo.pick_random())
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	# capture du jeu stylisée : couleurs passées, teinte rouille, vignette, bas assombri pour les textes
	sm.shader.code = """shader_type canvas_item;
void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 0.35);
	c *= vec3(1.08, 0.86, 0.74);
	c = (c - 0.5) * 1.15 + 0.47;
	float v = 1.0 - smoothstep(0.35, 0.95, length((UV - vec2(0.5, 0.45)) * vec2(1.0, 1.25)));
	c *= mix(0.25, 1.0, v);
	c *= mix(1.0, 0.2, smoothstep(0.55, 1.0, UV.y));
	COLOR = vec4(clamp(c, 0.0, 1.0) * 0.8, 1.0);
}"""
	fond.material = sm
	racine.add_child(fond)
	var titre := Label.new()
	titre.text = "JEU ZOMBIE"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.set_anchors_preset(Control.PRESET_TOP_WIDE)
	titre.offset_top = 70
	var ts := LabelSettings.new()
	ts.font_size = 88
	ts.font_color = Color(0.75, 0.12, 0.08)
	ts.outline_size = 10
	ts.outline_color = Color(0, 0, 0)
	ts.shadow_size = 12
	ts.shadow_color = Color(0, 0, 0, 0.6)
	titre.label_settings = ts
	racine.add_child(titre)
	# textes et barre qui changent : dessinés à la main (voir l'en-tête)
	_dyn = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_dyn, racine.get_canvas_item())
	RenderingServer.canvas_item_set_draw_index(_dyn, 100)
	get_viewport().size_changed.connect(_dessiner)
	_dessiner()


func _exit_tree() -> void:
	if actuel == self:
		actuel = null
	if _dyn.is_valid():
		RenderingServer.free_rid(_dyn)


func _process(delta: float) -> void:
	if fini:
		return
	var sc := get_tree().current_scene
	if etape_n >= 1 and sc and sc.scene_file_path == SCENE and sc.is_node_ready():
		_terminer()   # (sécurité : partie prête sans passer par l'étape « joueur_ui »)
		return
	if not charge_lancee:
		# une image affichée avant de commencer à charger
		charge_lancee = true
		var err := ResourceLoader.load_threaded_request(SCENE, "", true)
		if err != OK:
			_changer_scene(null)
		return
	if etape_n == 0:
		var p := []
		var st := ResourceLoader.load_threaded_get_status(SCENE, p)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			t_ressources = Time.get_ticks_msec() - t_debut
			etape_n = 1
			cible = _cumul(1)
			progres = cible
			_dessiner()
			# image affichée avec « Construction de Bellerive », puis la génération bloque le fil principal
			await get_tree().process_frame
			_changer_scene(ResourceLoader.load_threaded_get(SCENE))
			return
		if st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_changer_scene(null)
			return
		# progression du fil (peu détaillée) ou temps écoulé rapporté à la durée attendue
		var f := maxf(p[0], minf((Time.get_ticks_msec() - t_debut) / poids["ressources"], 0.95))
		cible = _cumul(0) + f * poids["ressources"] / total
	progres = move_toward(progres, cible, delta * 0.6)
	_tourner_astuce()
	_dessiner()


func _changer_scene(paquet) -> void:
	if paquet is PackedScene:
		get_tree().change_scene_to_packed(paquet)
	else:
		t_ressources = Time.get_ticks_msec() - t_debut
		etape_n = 1
		get_tree().change_scene_to_file(SCENE)


func _etape(nom: String, _ms: int) -> void:
	for i in ETAPES.size():
		if ETAPES[i][0] == nom:
			etape_n = i + 1
	cible = _cumul(etape_n)
	progres = cible
	if nom == "joueur_ui":
		_terminer()
		return
	var maintenant := Time.get_ticks_msec()
	if dessin_force and maintenant - t_dessin >= 30:
		_tourner_astuce()
		_dessiner()
		RenderingServer.force_draw(true, (maintenant - t_dessin) / 1000.0 if t_dessin > 0 else 0.0)
		t_dessin = Time.get_ticks_msec()
		dessinee.emit(nom)


## Partie prête : on garde l'écran pendant les premières images (compilation des shaders), puis fondu.
func _terminer() -> void:
	fini = true
	_dessiner()
	var arbre := get_tree()
	var main := arbre.current_scene
	_noter_poids(main.world.chrono if main and "world" in main and main.world else {})
	for i in 3:
		await arbre.process_frame
	var tw := create_tween()
	tw.tween_property(racine, "modulate:a", 0.0, 0.45)
	await tw.finished
	queue_free()


func _tourner_astuce() -> void:
	var maintenant := Time.get_ticks_msec()
	if maintenant - t_astuce >= ASTUCE_DUREE * 1000.0:
		t_astuce = maintenant
		astuce_i = (astuce_i + 1) % astuces.size()


func _cumul(n: int) -> float:
	var s := 0.0
	for i in mini(n, ETAPES.size()):
		s += poids[ETAPES[i][0]]
	return s / total


func _lire_poids() -> void:
	var cf := ConfigFile.new()
	var ok := cf.load(FICHIER) == OK
	total = 0.0
	for e in ETAPES:
		poids[e[0]] = maxf(float(cf.get_value("ms", e[0], e[2]) if ok else e[2]), 10.0)
		total += poids[e[0]]


## Durées de cette partie (moyennées avec les précédentes) pour mieux répartir la barre la prochaine fois.
func _noter_poids(chrono: Dictionary) -> void:
	var cf := ConfigFile.new()
	var mesures := chrono.duplicate()
	mesures["ressources"] = t_ressources
	for e in ETAPES:
		if mesures.has(e[0]):
			cf.set_value("ms", e[0], int(round(poids[e[0]] * 0.5 + float(mesures[e[0]]) * 0.5)))
	cf.save(FICHIER)


func _texte_infos() -> String:
	var d: Dictionary = Game.partie_a_charger
	if not d.is_empty():
		var jour := int(d.get("jour", 1))
		var h := float(d.get("heure", 8.0))
		return "Partie sauvegardée — jour %d, %02d:%02d   ·   %s, jour %d sur %d   ·   %s" % [jour, int(h), int(fmod(h, 1.0) * 60.0),
			Saisons.nom(jour), Saisons.jour_de_saison(jour), Saisons.JOURS_SAISON,
			Game.DIFFICULTES[clampi(int(d.get("difficulte", 1)), 0, Game.DIFFICULTES.size() - 1)]]
	if Game.admin:
		return "Mode admin (test) — Bellerive"
	if LieuxDepart.choix == "hasard":
		return "Nouvelle partie — lieu de départ tiré au sort   ·   %s" % Game.DIFFICULTES[Game.difficulte]
	var l: Dictionary = LieuxDepart.lieu(LieuxDepart.choix)
	if l.is_empty():
		return "Nouvelle partie"
	return "Nouvelle partie — départ : %s (%s)   ·   Printemps, jour 1   ·   %s" % [l.nom, LieuxDepart.DIFFICULTES[l.diff], Game.DIFFICULTES[Game.difficulte]]


## Barre, étape, pourcentage, astuce et infos, dessinés dans _dyn (fonctionne aussi pendant force_draw).
func _dessiner() -> void:
	if not _dyn.is_valid():
		return
	var rs := RenderingServer
	rs.canvas_item_clear(_dyn)
	var vs := get_viewport().get_visible_rect().size
	var k := clampf(vs.y / 1080.0, 0.6, 2.0)
	var larg := minf(vs.x * 0.62, 1200.0 * k)
	var x0 := (vs.x - larg) / 2.0
	var yb := vs.y - 150.0 * k
	var hb := 14.0 * k
	# infos de la partie, sous le titre
	_texte_centre(infos, Vector2(vs.x / 2.0, 205.0 * k), int(22 * k), Color(0.85, 0.82, 0.74), larg)
	# astuce
	var a: String = astuces[astuce_i] if not astuces.is_empty() else ""
	_texte_centre("ASTUCE", Vector2(vs.x / 2.0, yb - 150.0 * k), int(18 * k), Color(0.85, 0.35, 0.25), larg)
	_texte_centre(a, Vector2(vs.x / 2.0, yb - 118.0 * k), int(26 * k), Color(0.93, 0.9, 0.84), larg)
	# barre
	rs.canvas_item_add_rect(_dyn, Rect2(x0 - 2, yb - 2, larg + 4, hb + 4), Color(0, 0, 0, 0.7))
	rs.canvas_item_add_rect(_dyn, Rect2(x0, yb, larg, hb), Color(0.16, 0.13, 0.12, 0.9))
	var p := clampf(progres, 0.0, 1.0)
	rs.canvas_item_add_rect(_dyn, Rect2(x0, yb, larg * p, hb), Color(0.62, 0.11, 0.07))
	rs.canvas_item_add_rect(_dyn, Rect2(x0, yb, larg * p, hb * 0.35), Color(0.85, 0.25, 0.15, 0.6))
	var nom: String = ETAPES[mini(etape_n, ETAPES.size() - 1)][1] + ("" if fini else "…")
	if fini:
		nom = "Prêt"
	var fs := int(20 * k)
	_police.draw_string(_dyn, Vector2(x0, yb + hb + 30.0 * k), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.78, 0.75, 0.7))
	_police.draw_string(_dyn, Vector2(x0, yb + hb + 30.0 * k), "%d %%" % int(p * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, larg, fs, Color(0.78, 0.75, 0.7))


func _texte_centre(texte: String, haut_centre: Vector2, taille: int, coul: Color, larg: float) -> void:
	var par := TextParagraph.new()
	par.width = larg
	par.alignment = HORIZONTAL_ALIGNMENT_CENTER
	par.add_string(texte, _police, taille)
	var pos := Vector2(haut_centre.x - larg / 2.0, haut_centre.y)
	par.draw_outline(_dyn, pos + Vector2(2, 2), 4, Color(0, 0, 0, 0.6))
	par.draw(_dyn, pos, coul)
