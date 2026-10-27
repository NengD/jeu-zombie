## Péremption de la nourriture : champ `frais` d'items.gd = jours avant d'être avariée (absent = ne se périme pas).
## Progression `p` (0..1) rangée dans l'entrée d'inventaire comme l'usure `us` ; chaque grille retient
## l'heure de sa dernière mise à jour (méta `tf`), le retard est rattrapé (sommeil, conteneur détaché).
extends RefCounted

const SE_GATE := 0.6
const FRIGO := 1.0 / 3.0
const Placeable = preload("res://scripts/placeable.gd")
const Saisons = preload("res://scripts/saisons.gd")


## Heures de jeu écoulées depuis le début de la partie.
static func heures() -> float:
	return (Game.day - 1) * 24.0 + Game.time_hours


static func perissable(id: String) -> bool:
	return float(Items.info(id).get("frais", 0)) > 0.0


## Avance la péremption d'une grille (et des sacs qu'elle contient) jusqu'à maintenant ; k = vitesse (frigo 1/3).
static func avancer(g: Grille, k := 1.0) -> void:
	if g == null:
		return
	var h := heures()
	var t0: float = g.get_meta("tf", h)
	g.set_meta("tf", h)
	var jours := (h - t0) / 24.0 * k * Saisons.peremption()   # été ×1,5, hiver ×0,6
	if jours <= 0.0 or jours > 400.0:
		return
	for e in g.entrees:
		var f := float(Items.info(e.id).get("frais", 0))
		if f > 0.0:
			e["p"] = minf(1.0, float(e.get("p", 0.0)) + jours / f)
		if e.get("contenu") is Grille:
			avancer(e.contenu, k)


## Avance les grilles du joueur et celles des conteneurs dans l'arbre (frigo alimenté : ×1/3).
static func avancer_tout(player: Node) -> void:
	for g in player.grilles():
		avancer(g)
	for c in player.get_tree().get_nodes_in_group("conteneurs"):
		if c.grille != null:
			avancer(c.grille, FRIGO if Placeable.au_frais(c) else 1.0)


## Avant de verser k objets de b dans la pile a : moyenne pondérée de la progression.
static func fusionner(a: Dictionary, b: Dictionary, k: int) -> void:
	var pa := float(a.get("p", 0.0))
	var pb := float(b.get("p", 0.0))
	if pa > 0.0 or pb > 0.0:
		a["p"] = (pa * int(a.n) + pb * k) / maxf(1.0, int(a.n) + k)


static func etat(e: Dictionary) -> int:   # 0 frais, 1 se gâte, 2 avarié
	var p := float(e.get("p", 0.0))
	return 2 if p >= 1.0 else (1 if p >= SE_GATE else 0)


static func texte(e: Dictionary) -> String:
	var f := float(Items.info(e.id).get("frais", 0))
	if f <= 0.0:
		return ""
	var p := float(e.get("p", 0.0))
	match etat(e):
		2:
			return "Avarié : nourrit moitié moins, risque d'intoxication doublé."
		1:
			return "Se gâte : avarié dans %s." % _duree((1.0 - p) * f)
	return "Frais : se gâte dans %s." % _duree((SE_GATE - p) * f)


static func _duree(jours: float) -> String:
	if jours >= 1.0:
		return "%d jour%s" % [roundi(jours), "s" if roundi(jours) > 1 else ""]
	return "%d h" % maxi(1, roundi(jours * 24.0))
