## Saisons (fonctions statiques sans état, calculées à partir de Game.day ; jour 1 = printemps).
## Cycle printemps → été → automne → hiver de JOURS_SAISON jours chacun.
extends RefCounted

const JOURS_SAISON := 7
const ORDRE := ["printemps", "ete", "automne", "hiver"]
const NOMS := {"printemps": "Printemps", "ete": "Été", "automne": "Automne", "hiver": "Hiver"}


static func saison(jour: int = -1) -> String:
	if jour < 1:
		jour = Game.day
	return ORDRE[((jour - 1) / JOURS_SAISON) % 4]


static func nom(jour: int = -1) -> String:
	return NOMS[saison(jour)]


## 1..JOURS_SAISON
static func jour_de_saison(jour: int = -1) -> int:
	if jour < 1:
		jour = Game.day
	return (jour - 1) % JOURS_SAISON + 1


static func _fin_de_saison() -> bool:
	return jour_de_saison() > JOURS_SAISON / 2


## Facteur de pousse des plantes dehors.
static func pousse() -> float:
	return {"printemps": 1.0, "ete": 1.2, "automne": 0.7, "hiver": 0.2}[saison()]


## Facteur de vitesse de péremption de la nourriture.
static func peremption() -> float:
	return {"ete": 1.5, "hiver": 0.6}.get(saison(), 1.0)


## Ajout au refroidissement par seconde (player.bilan_temperature) : + = refroidit, - = réchauffe.
static func froid() -> float:
	return {"printemps": 0.0, "ete": -0.05, "automne": 0.06, "hiver": 0.22}[saison()]


## Facteur de fréquence des averses.
static func pluie() -> float:
	return {"printemps": 1.2, "ete": 0.6, "automne": 1.5, "hiver": 1.0}[saison()]


## En hiver, les averses tombent en neige.
static func neige() -> bool:
	return saison() == "hiver"


## Cueillette possible ? type : "pomme", "raisin", "mais".
static func fruits(type: String) -> bool:
	match saison():
		"ete":
			return type in ["pomme", "mais"] and _fin_de_saison()
		"automne":
			return type in ["pomme", "raisin", "mais"]
	return false


## Heures de jour (été plus long, hiver plus court).
static func duree_jour() -> float:
	return {"printemps": 13.0, "ete": 15.0, "automne": 11.0, "hiver": 9.0}[saison()]


## Effets de la saison en une ligne (écran d'état).
static func effets() -> String:
	match saison():
		"ete":
			return "Chaleur : on se réchauffe vite, mais la nourriture se gâte 1,5 fois plus vite. Plantes ×1,2."
		"automne":
			return "Fraîcheur : un peu plus froid, averses fréquentes. Récolte des pommes, du raisin et du maïs. Plantes ×0,7."
		"hiver":
			return "Grand froid, neige : vêtements chauds et feu indispensables, la nuit surtout. Nourriture conservée plus longtemps (×0,6), plantes presque à l'arrêt."
	return "Doux : averses assez fréquentes, les plantes poussent normalement."
