class_name Progression
extends RefCounted
## Niveaux, attributs et compétences du survivant.
## - Niveau global : chaque niveau donne 1 point d'attribut (endurance, santé, soif, faim).
## - Compétences Combat / Fabrication / Exploration / Survie / Chasse : XP propre, niveaux 1 à 15 ;
##   chaque niveau de compétence donne 1 point de talent à dépenser dans sa branche de l'arbre.
## Les actions rapportent de l'XP de compétence et de l'XP globale.

signal niveau_global(n: int)
signal niveau_competence(comp: String, n: int)
signal xp_gagnee(comp: String, qte: int)

const COMPETENCES := ["combat", "fabrication", "exploration", "survie", "chasse"]
const NOMS := {"combat": "Combat", "fabrication": "Fabrication", "exploration": "Exploration", "survie": "Survie", "chasse": "Chasse"}
const NIVEAU_MAX_COMP := 15

const ATTRIBUTS := {
	"endurance": {"nom": "Endurance", "desc": "+10 d'endurance max et récupération +8 %"},
	"sante": {"nom": "Santé", "desc": "+10 de santé max"},
	"soif": {"nom": "Soif", "desc": "La soif baisse 7 % moins vite"},
	"faim": {"nom": "Faim", "desc": "La faim baisse 7 % moins vite"},
}

## Arbre de compétences : chaque talent est un nœud d'une branche (`br`), relié à son parent
## (`apres`, "" = départ de la branche) ; `niv` = niveau de compétence requis, `d` = distance au
## centre (rang), `l` = décalage sur le côté. Coût : 1 point de talent de la compétence (`comp`).
const BRANCHES := {
	"melee": {"nom": "Corps à corps", "comp": "combat"},
	"tir": {"nom": "Armes à feu", "comp": "combat"},
	"fabrication": {"nom": "Fabrication", "comp": "fabrication"},
	"exploration": {"nom": "Exploration", "comp": "exploration"},
	"survie": {"nom": "Survie", "comp": "survie"},
	"chasse": {"nom": "Chasse et arc", "comp": "chasse"},
}
const TALENTS := {
	# --- combat : corps à corps
	"coup_puissant": {"comp": "combat", "br": "melee", "apres": "", "d": 1, "l": 0, "niv": 1, "nom": "Coup puissant", "desc": "+25 % de dégâts au corps à corps."},
	"lame_aiguisee": {"comp": "combat", "br": "melee", "apres": "coup_puissant", "d": 2, "l": -1, "niv": 2, "nom": "Lame aiguisée", "desc": "Hache, machette et couteau : +20 % de dégâts et plus de sang."},
	"souffle": {"comp": "combat", "br": "melee", "apres": "coup_puissant", "d": 2, "l": 0, "niv": 3, "nom": "Second souffle", "desc": "Les coups au corps à corps coûtent 30 % d'endurance en moins."},
	"frappeur": {"comp": "combat", "br": "melee", "apres": "coup_puissant", "d": 2, "l": 1, "niv": 3, "nom": "Frappeur", "desc": "Battes et matraque repoussent les zombies à chaque coup."},
	"enchainement": {"comp": "combat", "br": "melee", "apres": "lame_aiguisee", "d": 3, "l": -1, "niv": 5, "nom": "Enchaînement", "desc": "Le 3e coup d'un enchaînement fait 40 % de dégâts en plus."},
	"charge_rapide": {"comp": "combat", "br": "melee", "apres": "souffle", "d": 3, "l": 0, "niv": 4, "nom": "Concentration", "desc": "Le coup puissant se charge 40 % plus vite."},
	"acrobate": {"comp": "combat", "br": "melee", "apres": "frappeur", "d": 3, "l": 1, "niv": 4, "nom": "Acrobate", "desc": "La roulade coûte deux fois moins d'endurance."},
	"robuste": {"comp": "combat", "br": "melee", "apres": "enchainement", "d": 4, "l": -1, "niv": 5, "nom": "Peau dure", "desc": "Tu subis 15 % de dégâts en moins."},
	"critique": {"comp": "combat", "br": "melee", "apres": "charge_rapide", "d": 4, "l": 0, "niv": 7, "nom": "Coup critique", "desc": "20 % de chances d'infliger double dégâts au corps à corps."},
	"balayage": {"comp": "combat", "br": "melee", "apres": "acrobate", "d": 4, "l": 1, "niv": 6, "nom": "Grand balayage", "desc": "Le balayage latéral touche jusqu'à deux zombies."},
	"parade_experte": {"comp": "combat", "br": "melee", "apres": "robuste", "d": 5, "l": -1, "niv": 8, "nom": "Parade experte", "desc": "Une parade bloque 90 % des dégâts (au lieu de 80 %) et coûte deux fois moins d'endurance."},
	"brute": {"comp": "combat", "br": "melee", "apres": "critique", "d": 5, "l": 0, "niv": 8, "nom": "Brute", "desc": "Un coup puissant chargé à fond renverse toujours le zombie."},
	"maitre_armes": {"comp": "combat", "br": "melee", "apres": "brute", "d": 6, "l": 0, "niv": 12, "nom": "Maître d'armes", "desc": "+20 % de dégâts au corps à corps et coups 15 % moins fatigants."},
	"furie": {"comp": "combat", "br": "melee", "apres": "maitre_armes", "d": 7, "l": 0, "niv": 14, "nom": "Furie", "desc": "Chaque zombie tué rend 8 d'endurance et 3 de santé."},
	# --- combat : armes à feu
	"main_sure": {"comp": "combat", "br": "tir", "apres": "", "d": 1, "l": 0, "niv": 1, "nom": "Main sûre", "desc": "Tirs 25 % plus précis (armes à feu et arc)."},
	"visee_stable": {"comp": "combat", "br": "tir", "apres": "main_sure", "d": 2, "l": -1, "niv": 4, "nom": "Visée stable", "desc": "En visant, tirs encore 25 % plus précis."},
	"recharge_rapide": {"comp": "combat", "br": "tir", "apres": "main_sure", "d": 2, "l": 0, "niv": 2, "nom": "Recharge rapide", "desc": "Rechargement 25 % plus rapide."},
	"tir_hanche": {"comp": "combat", "br": "tir", "apres": "main_sure", "d": 2, "l": 1, "niv": 3, "nom": "Tir instinctif", "desc": "Tir sans viser 30 % plus précis."},
	"tireur": {"comp": "combat", "br": "tir", "apres": "recharge_rapide", "d": 3, "l": 0, "niv": 4, "nom": "Tireur d'élite", "desc": "+20 % de dégâts avec les armes à feu."},
	"grenadier": {"comp": "combat", "br": "tir", "apres": "tir_hanche", "d": 3, "l": 1, "niv": 7, "nom": "Grenadier", "desc": "Grenades : +30 % de dégâts et d'étendue de l'explosion."},
	"balistique": {"comp": "combat", "br": "tir", "apres": "tireur", "d": 4, "l": -1, "niv": 7, "nom": "Balistique", "desc": "Portée des armes à feu +25 %."},
	"econome_balles": {"comp": "combat", "br": "tir", "apres": "tireur", "d": 4, "l": 0, "niv": 8, "nom": "Tir économe", "desc": "15 % de chances qu'un tir ne consomme pas de cartouche."},
	"gachette": {"comp": "combat", "br": "tir", "apres": "tireur", "d": 4, "l": 1, "niv": 6, "nom": "Doigt léger", "desc": "Cadence de tir 15 % plus rapide."},
	"sang_froid": {"comp": "combat", "br": "tir", "apres": "econome_balles", "d": 5, "l": 0, "niv": 9, "nom": "Sang-froid", "desc": "Recul des armes réduit de 35 %."},
	"maitrise_rafale": {"comp": "combat", "br": "tir", "apres": "gachette", "d": 5, "l": 1, "niv": 10, "nom": "Maîtrise du tir", "desc": "Les tirs rapprochés dispersent 40 % moins."},
	"tir_tete": {"comp": "combat", "br": "tir", "apres": "sang_froid", "d": 6, "l": 0, "niv": 12, "nom": "Tireur de précision", "desc": "Tes coups à la tête des zombies font ×3 dégâts (au lieu de ×2,5)."},
	# --- fabrication
	"econome": {"comp": "fabrication", "br": "fabrication", "apres": "", "d": 1, "l": 0, "niv": 1, "nom": "Économe", "desc": "30 % de chances de récupérer un matériau en fabriquant."},
	"soigneur": {"comp": "fabrication", "br": "fabrication", "apres": "econome", "d": 2, "l": 1, "niv": 1, "nom": "Soigneur", "desc": "Les soins rendent 30 % de santé en plus."},
	"charpentier": {"comp": "fabrication", "br": "fabrication", "apres": "econome", "d": 2, "l": 0, "niv": 3, "nom": "Charpentier", "desc": "Barricades et établis posés ont 60 % de solidité en plus."},
	"cartoucherie": {"comp": "fabrication", "br": "fabrication", "apres": "econome", "d": 2, "l": -1, "niv": 2, "nom": "Cartoucherie", "desc": "Les munitions fabriquées sont 50 % plus nombreuses."},
	"cuisinier": {"comp": "fabrication", "br": "fabrication", "apres": "soigneur", "d": 3, "l": 1, "niv": 4, "nom": "Débrouillard", "desc": "Nourriture et boissons nourrissent 25 % de plus."},
	"artisan_rapide": {"comp": "fabrication", "br": "fabrication", "apres": "charpentier", "d": 3, "l": 0, "niv": 5, "nom": "Mains agiles", "desc": "Fabrication 25 % plus rapide."},
	"mecanicien": {"comp": "fabrication", "br": "fabrication", "apres": "cartoucherie", "d": 3, "l": -1, "niv": 5, "nom": "Mécanicien", "desc": "Épaves : récolte comme avec 2 niveaux de fabrication de plus."},
	"chimiste": {"comp": "fabrication", "br": "fabrication", "apres": "cuisinier", "d": 4, "l": 1, "niv": 9, "nom": "Chimiste", "desc": "Recettes de soins : une chance sur deux d'avoir un objet de plus."},
	"atelier": {"comp": "fabrication", "br": "fabrication", "apres": "artisan_rapide", "d": 4, "l": 0, "niv": 6, "nom": "Atelier portatif", "desc": "Fabrique les recettes d'établi partout."},
	"recuperateur": {"comp": "fabrication", "br": "fabrication", "apres": "mecanicien", "d": 4, "l": -1, "niv": 7, "nom": "Récupérateur", "desc": "Le démontage rend 50 % de matériaux en plus."},
	"maitre_artisan": {"comp": "fabrication", "br": "fabrication", "apres": "atelier", "d": 5, "l": 0, "niv": 8, "nom": "Maître artisan", "desc": "Une chance sur deux d'obtenir un objet fabriqué en double (hors munitions)."},
	"ingenieur": {"comp": "fabrication", "br": "fabrication", "apres": "recuperateur", "d": 5, "l": -1, "niv": 9, "nom": "Ingénieur", "desc": "Les pièges à mâchoires font 60 % de dégâts en plus."},
	"ingeniosite": {"comp": "fabrication", "br": "fabrication", "apres": "maitre_artisan", "d": 6, "l": 0, "niv": 13, "nom": "Ingéniosité", "desc": "Économe : une chance sur deux de récupérer un matériau (au lieu de 30 %)."},
	"armurier": {"comp": "fabrication", "br": "fabrication", "apres": "ingenieur", "d": 6, "l": -1, "niv": 11, "nom": "Armurier", "desc": "Munitions fabriquées : encore 25 % de plus."},
	# --- exploration
	"fouilleur": {"comp": "exploration", "br": "exploration", "apres": "", "d": 1, "l": 0, "niv": 1, "nom": "Fouilleur", "desc": "Les meubles contiennent plus d'objets."},
	"curieux": {"comp": "exploration", "br": "exploration", "apres": "fouilleur", "d": 2, "l": 2, "niv": 2, "nom": "Curieux", "desc": "+25 % d'XP d'exploration."},
	"discret": {"comp": "exploration", "br": "exploration", "apres": "fouilleur", "d": 2, "l": 1, "niv": 1, "nom": "Pas de loup", "desc": "Les zombies te repèrent de 30 % moins loin."},
	"poches": {"comp": "exploration", "br": "exploration", "apres": "fouilleur", "d": 2, "l": 0, "niv": 3, "nom": "Poches profondes", "desc": "+1 rangée à ton inventaire de base (8×6)."},
	"coureur": {"comp": "exploration", "br": "exploration", "apres": "fouilleur", "d": 2, "l": -1, "niv": 2, "nom": "Coureur", "desc": "Sprint 12 % plus rapide."},
	"chanceux": {"comp": "exploration", "br": "exploration", "apres": "curieux", "d": 3, "l": 2, "niv": 4, "nom": "Chanceux", "desc": "Tu trouves de l'argent plus souvent en fouillant, et 30 % de plus."},
	"ombre": {"comp": "exploration", "br": "exploration", "apres": "discret", "d": 3, "l": 1, "niv": 9, "nom": "Ombre", "desc": "Accroupi, les zombies te voient encore 40 % moins loin."},
	"poches2": {"comp": "exploration", "br": "exploration", "apres": "poches", "d": 3, "l": 0, "niv": 6, "nom": "Poches de cargo", "desc": "+1 rangée supplémentaire (8×7)."},
	"marathonien": {"comp": "exploration", "br": "exploration", "apres": "coureur", "d": 3, "l": -1, "niv": 4, "nom": "Marathonien", "desc": "Le sprint consomme 35 % d'endurance en moins."},
	"marchandage": {"comp": "exploration", "br": "exploration", "apres": "chanceux", "d": 4, "l": 2, "niv": 5, "nom": "Marchandage", "desc": "Achats 15 % moins chers et reventes 15 % plus chères chez les marchands."},
	"vue_percante": {"comp": "exploration", "br": "exploration", "apres": "poches2", "d": 4, "l": 0, "niv": 8, "nom": "Œil de lynx", "desc": "Les meubles contiennent encore plus d'objets."},
	"infatigable": {"comp": "exploration", "br": "exploration", "apres": "marathonien", "d": 4, "l": -1, "niv": 12, "nom": "Infatigable", "desc": "+25 d'endurance max."},
	# --- survie (XP : récolte, manger, boire, se soigner, encaisser des coups)
	"regeneration": {"comp": "survie", "br": "survie", "apres": "", "d": 1, "l": 0, "niv": 1, "nom": "Régénération", "desc": "La santé remonte deux fois plus vite quand tu es nourri et hydraté."},
	"bucheron": {"comp": "survie", "br": "survie", "apres": "regeneration", "d": 2, "l": 1, "niv": 2, "nom": "Bûcheron", "desc": "Arbres et rochers : récolte comme avec 2 niveaux de survie de plus."},
	"endurci": {"comp": "survie", "br": "survie", "apres": "regeneration", "d": 2, "l": 0, "niv": 3, "nom": "Endurci", "desc": "L'endurance remonte 25 % plus vite et tu crains moins le froid (-30 %)."},
	"frugal": {"comp": "survie", "br": "survie", "apres": "regeneration", "d": 2, "l": -1, "niv": 2, "nom": "Frugal", "desc": "La faim et la soif baissent 15 % moins vite."},
	"sommeil": {"comp": "survie", "br": "survie", "apres": "bucheron", "d": 3, "l": 1, "niv": 4, "nom": "Sommeil réparateur", "desc": "Dormir rend deux fois plus de santé et toute l'endurance."},
	"adrenaline": {"comp": "survie", "br": "survie", "apres": "endurci", "d": 3, "l": 0, "niv": 5, "nom": "Adrénaline", "desc": "Sous 25 % de santé : +20 % de dégâts et de vitesse."},
	"estomac": {"comp": "survie", "br": "survie", "apres": "frugal", "d": 3, "l": -1, "niv": 4, "nom": "Estomac de fer", "desc": "Risque d'intoxication (viande crue, eau non potable) divisé par deux."},
	"medecin": {"comp": "survie", "br": "survie", "apres": "sommeil", "d": 4, "l": 1, "niv": 7, "nom": "Guérison", "desc": "Les maladies guérissent deux fois plus vite et la fièvre d'une infection monte deux fois moins vite."},
	"vigueur": {"comp": "survie", "br": "survie", "apres": "adrenaline", "d": 4, "l": 0, "niv": 6, "nom": "Vigueur", "desc": "+20 de santé max."},
	"chameau": {"comp": "survie", "br": "survie", "apres": "estomac", "d": 4, "l": -1, "niv": 9, "nom": "Chameau", "desc": "La soif baisse encore 20 % moins vite."},
	"seconde_peau": {"comp": "survie", "br": "survie", "apres": "medecin", "d": 5, "l": 1, "niv": 11, "nom": "Seconde peau", "desc": "Tu subis encore 10 % de dégâts en moins et saignes deux fois moins souvent."},
	"increvable": {"comp": "survie", "br": "survie", "apres": "vigueur", "d": 5, "l": 0, "niv": 8, "nom": "Increvable", "desc": "Une fois par jour, une blessure mortelle te laisse à 15 de santé."},
	"survivant_ne": {"comp": "survie", "br": "survie", "apres": "increvable", "d": 6, "l": 0, "niv": 13, "nom": "Survivant-né", "desc": "Faim et soif 10 % plus lentes, santé qui remonte 50 % plus vite."},
	# --- chasse et arc (XP : flèches qui touchent, animaux tués, dépeçage, collets, cuisine au feu)
	"archer": {"comp": "chasse", "br": "chasse", "apres": "", "d": 1, "l": 0, "niv": 1, "nom": "Archer", "desc": "+20 % de dégâts avec les flèches."},
	"depeceur": {"comp": "chasse", "br": "chasse", "apres": "archer", "d": 2, "l": 1, "niv": 2, "nom": "Dépeceur", "desc": "Le dépeçage rend une viande et une peau de plus."},
	"tension_rapide": {"comp": "chasse", "br": "chasse", "apres": "archer", "d": 2, "l": 0, "niv": 4, "nom": "Bras d'archer", "desc": "L'arc se bande 35 % plus vite."},
	"pisteur": {"comp": "chasse", "br": "chasse", "apres": "archer", "d": 2, "l": -1, "niv": 3, "nom": "Pisteur", "desc": "Les animaux te repèrent de 30 % moins loin."},
	"tanneur": {"comp": "chasse", "br": "chasse", "apres": "depeceur", "d": 3, "l": 1, "niv": 5, "nom": "Tanneur", "desc": "Le tannage donne un cuir de plus."},
	"recup_fleches": {"comp": "chasse", "br": "chasse", "apres": "tension_rapide", "d": 3, "l": 0, "niv": 5, "nom": "Flèches solides", "desc": "Les flèches plantées se récupèrent presque toujours."},
	"piegeur": {"comp": "chasse", "br": "chasse", "apres": "pisteur", "d": 3, "l": -1, "niv": 3, "nom": "Piégeur", "desc": "Les lapins se prennent deux fois plus vite dans les collets."},
	"chef": {"comp": "chasse", "br": "chasse", "apres": "tanneur", "d": 4, "l": 1, "niv": 6, "nom": "Cuisine de camp", "desc": "Recettes au feu : une chance sur deux d'avoir une portion de plus."},
	"fleches_serie": {"comp": "chasse", "br": "chasse", "apres": "recup_fleches", "d": 4, "l": 0, "niv": 7, "nom": "Encochage rapide", "desc": "40 % de délai en moins entre deux flèches."},
	"traqueur": {"comp": "chasse", "br": "chasse", "apres": "piegeur", "d": 4, "l": -1, "niv": 9, "nom": "Traqueur", "desc": "+30 % de dégâts contre les animaux."},
	"tir_mortel": {"comp": "chasse", "br": "chasse", "apres": "fleches_serie", "d": 5, "l": 0, "niv": 8, "nom": "Tir mortel", "desc": "Une flèche bandée à fond fait 50 % de dégâts en plus."},
	"empenneur": {"comp": "chasse", "br": "chasse", "apres": "traqueur", "d": 5, "l": -1, "niv": 10, "nom": "Empenneur", "desc": "Fabriquer des flèches en donne 2 de plus."},
	"silence": {"comp": "chasse", "br": "chasse", "apres": "tir_mortel", "d": 6, "l": 0, "niv": 12, "nom": "Chasseur fantôme", "desc": "Tirer à l'arc ne fait presque plus de bruit."},
	# --- lot 2 : pêche, cueillette, réparation, premiers secours
	"bricoleur": {"comp": "fabrication", "br": "fabrication", "apres": "rendement", "d": 6, "l": 1, "niv": 8, "nom": "Bricoleur", "desc": "Les armes et outils s'usent 30 % moins vite ; un kit de réparation répare 25 % de plus."},
	"premiers_secours": {"comp": "survie", "br": "survie", "apres": "seconde_peau", "d": 6, "l": 1, "niv": 9, "nom": "Premiers secours", "desc": "Les saignements s'arrêtent deux fois plus vite d'eux-mêmes et les soins sont 30 % plus rapides."},
	"cueilleur": {"comp": "survie", "br": "survie", "apres": "constitution", "d": 6, "l": -1, "niv": 8, "nom": "Cueilleur", "desc": "La cueillette (fruits, raisin, maïs) rapporte 50 % de plus."},
	"pecheur": {"comp": "chasse", "br": "chasse", "apres": "empenneur", "d": 6, "l": -1, "niv": 8, "nom": "Pêcheur", "desc": "Les lignes de pêche prennent un poisson 1,6 fois plus vite et en gardent 2 de plus."},
	# --- lot 3 : véhicules, potager, électricité, déguisement
	"pilote": {"comp": "exploration", "br": "exploration", "apres": "ombre", "d": 4, "l": 1, "niv": 6, "nom": "Pilote", "desc": "Les voitures consomment 30 % d'essence en moins et encaissent 30 % de dégâts en moins."},
	"electricien": {"comp": "fabrication", "br": "fabrication", "apres": "armurier", "d": 7, "l": -1, "niv": 8, "nom": "Électricien", "desc": "Le groupe électrogène brûle 40 % d'essence en moins ; le réseau électrique porte 5 m plus loin."},
	"jardinier": {"comp": "survie", "br": "survie", "apres": "cueilleur", "d": 7, "l": -1, "niv": 6, "nom": "Jardinier", "desc": "Les plantes poussent 40 % plus vite et chaque récolte donne 1 légume de plus."},
	"fantome": {"comp": "survie", "br": "survie", "apres": "premiers_secours", "d": 7, "l": 1, "niv": 7, "nom": "Fantôme", "desc": "Le déguisement de tripes dure 50 % plus longtemps."},
	# --- nœuds à plusieurs rangs (`rangs`) : 1 point par rang, +2 niveaux requis à chaque rang
	"force": {"comp": "combat", "br": "melee", "apres": "parade_experte", "d": 6, "l": -1, "niv": 10, "rangs": 3, "nom": "Force", "desc": "+5 % de dégâts au corps à corps par rang."},
	"calibre": {"comp": "combat", "br": "tir", "apres": "maitrise_rafale", "d": 6, "l": 1, "niv": 11, "rangs": 3, "nom": "Main de fer", "desc": "+5 % de dégâts avec les armes à feu par rang."},
	"rendement": {"comp": "fabrication", "br": "fabrication", "apres": "chimiste", "d": 5, "l": 1, "niv": 10, "rangs": 3, "nom": "Productivité", "desc": "Fabrication 8 % plus rapide par rang."},
	"pied_leger": {"comp": "exploration", "br": "exploration", "apres": "vue_percante", "d": 5, "l": 0, "niv": 10, "rangs": 3, "nom": "Pied léger", "desc": "Sprint 3 % plus rapide par rang."},
	"constitution": {"comp": "survie", "br": "survie", "apres": "chameau", "d": 5, "l": -1, "niv": 10, "rangs": 3, "nom": "Constitution", "desc": "+10 de santé max par rang."},
	"oeil_faucon": {"comp": "chasse", "br": "chasse", "apres": "chef", "d": 5, "l": 1, "niv": 9, "rangs": 3, "nom": "Œil de faucon", "desc": "+6 % de dégâts des flèches par rang."},
	# --- ponts entre deux branches voisines (`pont`) : demandent les deux nœuds `apres` et `apres2`
	"combattant": {"comp": "combat", "br": "melee", "pont": true, "apres": "frappeur", "apres2": "visee_stable", "niv": 9, "nom": "Combattant complet", "desc": "+10 % de dégâts au corps à corps et avec les armes à feu."},
	"poudre_maison": {"comp": "fabrication", "br": "fabrication", "pont": true, "apres": "cartoucherie", "apres2": "recharge_rapide", "niv": 6, "nom": "Poudre maison", "desc": "Les munitions se fabriquent deux fois plus vite."},
	"herboriste": {"comp": "survie", "br": "survie", "pont": true, "apres": "frugal", "apres2": "soigneur", "niv": 6, "nom": "Herboriste", "desc": "Les soins rendent encore 20 % de santé en plus."},
	"vivre_terre": {"comp": "chasse", "br": "chasse", "pont": true, "apres": "pisteur", "apres2": "bucheron", "niv": 5, "nom": "Vivre de la terre", "desc": "Viande, bouillon et ragoût nourrissent 30 % de plus."},
	"rodeur": {"comp": "exploration", "br": "exploration", "pont": true, "apres": "coureur", "apres2": "depeceur", "niv": 6, "nom": "Rôdeur", "desc": "Accroupi, tu te déplaces 30 % plus vite."},
	"embuscade": {"comp": "combat", "br": "melee", "pont": true, "apres": "lame_aiguisee", "apres2": "discret", "niv": 6, "nom": "Embuscade", "desc": "Au corps à corps, double dégâts sur un zombie qui ne te poursuit pas."},
}

var niveau := 1
var xp := 0
var points := 0
var attributs := {"endurance": 0, "sante": 0, "soif": 0, "faim": 0}
var comp := {}          # nom -> {"niv": int, "xp": int, "points": int}
var talents: Array = []
var rangs := {}         # talent à plusieurs rangs -> rang atteint (2 ou plus ; absent = 1)
var lieux_vus := {}     # bâtiments/points d'intérêt déjà découverts


func _init() -> void:
	for c in COMPETENCES:
		comp[c] = {"niv": 0, "xp": 0, "points": 0}


static func xp_niveau(n: int) -> int:
	return int(100.0 * pow(n, 1.45))


static func xp_comp(n: int) -> int:
	return int(60.0 * pow(n + 1, 1.5))


func a(talent: String) -> bool:
	return talent in talents


## Rang d'un talent (0 = pas acquis ; 1 pour un talent simple acquis).
func rang(t: String) -> int:
	return int(rangs.get(t, 1)) if a(t) else 0


## Nombre de rangs d'un talent (1 pour un talent simple).
static func rangs_max(t: String) -> int:
	return int(TALENTS[t].get("rangs", 1)) if TALENTS.has(t) else 1


## Niveau de compétence demandé pour le prochain rang (+2 par rang déjà pris).
func niv_requis(t: String) -> int:
	return int(TALENTS[t].niv) + 2 * rang(t)


## Gagne de l'XP dans une compétence (et autant d'XP globale).
func gagner(c: String, qte: int) -> void:
	if qte <= 0:
		return
	if c == "exploration" and a("curieux"):
		qte = roundi(qte * 1.25)
	xp_gagnee.emit(c, qte)
	xp += qte
	while xp >= xp_niveau(niveau):
		xp -= xp_niveau(niveau)
		niveau += 1
		points += 1
		niveau_global.emit(niveau)
	if not comp.has(c):
		return
	var d: Dictionary = comp[c]
	if d.niv >= NIVEAU_MAX_COMP:
		return
	d.xp += qte
	while d.niv < NIVEAU_MAX_COMP and d.xp >= xp_comp(d.niv):
		d.xp -= xp_comp(d.niv)
		d.niv += 1
		d.points += 1
		niveau_competence.emit(c, d.niv)


func peut_debloquer(t: String) -> bool:
	return raison_bloque(t) == ""


## Pourquoi un talent ne peut pas être débloqué ("" = il peut l'être).
func raison_bloque(t: String) -> String:
	if not TALENTS.has(t):
		return "Talent inconnu"
	if rang(t) >= rangs_max(t):
		return "Déjà acquis" if rangs_max(t) == 1 else "Rang maximum atteint"
	var info: Dictionary = TALENTS[t]
	var d: Dictionary = comp[info.comp]
	for par in [info.apres, info.get("apres2", "")]:
		if par != "" and not a(par):
			return "Débloque d'abord « %s »" % TALENTS[par].nom
	if d.niv < niv_requis(t):
		return "Il faut le niveau %d en %s (tu es niveau %d)" % [niv_requis(t), NOMS[info.comp], d.niv]
	if d.points <= 0:
		return "Plus de point de %s" % NOMS[info.comp]
	return ""


func debloquer(t: String) -> bool:
	if not peut_debloquer(t):
		return false
	comp[TALENTS[t].comp].points -= 1
	if a(t):
		rangs[t] = rang(t) + 1
	else:
		talents.append(t)
	return true


func ameliorer(attr: String) -> bool:
	if points <= 0 or not attributs.has(attr):
		return false
	points -= 1
	attributs[attr] += 1
	return true


## Talents gardés à la réinitialisation (les rangées de poches ne se retirent pas).
const GARDES_REINIT := ["poches", "poches2"]


## Prix de la réinitialisation (€) : grandit avec le niveau.
func cout_reinit() -> int:
	return 100 + 40 * niveau


## Points rendus par une réinitialisation (talents et leurs rangs, attributs).
func points_investis() -> int:
	var n := 0
	for t in talents:
		if not t in GARDES_REINIT:
			n += rang(t)
	for k in attributs:
		n += int(attributs[k])
	return n


## Rend tous les points de talent et d'attribut dépensés.
func reinitialiser() -> void:
	var gardes: Array = []
	for t in talents:
		if t in GARDES_REINIT:
			gardes.append(t)
		elif TALENTS.has(t):
			comp[TALENTS[t].comp].points += rang(t)
	talents = gardes
	rangs = {}
	for k in attributs:
		points += int(attributs[k])
		attributs[k] = 0


# ---------------------------------------------------------------- effets
func sante_max() -> float:
	return 100.0 + 10.0 * attributs.sante + (20.0 if a("vigueur") else 0.0) + 10.0 * rang("constitution")


func endurance_max() -> float:
	return 100.0 + 10.0 * attributs.endurance + (25.0 if a("infatigable") else 0.0)


func recup_endurance() -> float:
	return (1.0 + 0.08 * attributs.endurance) * (1.25 if a("endurci") else 1.0)


func faim_mult() -> float:
	return pow(0.93, attributs.faim) * (0.85 if a("frugal") else 1.0) * (0.9 if a("survivant_ne") else 1.0)


func soif_mult() -> float:
	return pow(0.93, attributs.soif) * (0.85 if a("frugal") else 1.0) * (0.8 if a("chameau") else 1.0) * (0.9 if a("survivant_ne") else 1.0)


func lignes_inventaire() -> int:
	return 5 + (1 if a("poches") else 0) + (1 if a("poches2") else 0)


# ---------------------------------------------------------------- sauvegarde
func vers_dict() -> Dictionary:
	return {"niveau": niveau, "xp": xp, "points": points, "attributs": attributs, "comp": comp,
			"talents": talents, "rangs": rangs, "lieux": lieux_vus.keys()}


func depuis_dict(d: Dictionary) -> void:
	niveau = int(d.get("niveau", 1))
	xp = int(d.get("xp", 0))
	points = int(d.get("points", 0))
	var at: Dictionary = d.get("attributs", {})
	for k in attributs:
		attributs[k] = int(at.get(k, 0))
	var cd: Dictionary = d.get("comp", {})
	for c in COMPETENCES:
		var x: Dictionary = cd.get(c, {})
		comp[c] = {"niv": int(x.get("niv", 0)), "xp": int(x.get("xp", 0)), "points": int(x.get("points", 0))}
	talents = []
	for t in d.get("talents", []):
		if TALENTS.has(str(t)):
			talents.append(str(t))
	rangs = {}
	var rd: Dictionary = d.get("rangs", {})
	for t in rd:
		if str(t) in talents:
			rangs[str(t)] = clampi(int(rd[t]), 1, rangs_max(str(t)))
	lieux_vus = {}
	for l in d.get("lieux", []):
		lieux_vus[str(l)] = true
