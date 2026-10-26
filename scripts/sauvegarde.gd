class_name Sauvegarde
extends RefCounted
## Sauvegarde / chargement de la partie (fichier user://sauvegarde.json).
## Le monde est regénéré à l'identique à partir de sa graine ; on enregistre seulement
## ce qui a changé : joueur, meubles fouillés, objets posés, tas au sol, zombies, heure.

const FICHIER := "user://sauvegarde.json"
const LootContainer = preload("res://scripts/loot_container.gd")
const Placeable = preload("res://scripts/placeable.gd")
const Construction = preload("res://scripts/construction.gd")


static func existe() -> bool:
	return not lire().is_empty()


## Résumé affiché dans le menu : « Jour 3 — 14:20 (sauvegardé le …) ».
static func resume() -> String:
	var d := lire()
	if d.is_empty():
		return ""
	var h := float(d.get("heure", 8.0))
	return "Jour %d — %02d:%02d   (sauvegardée le %s)" % [int(d.get("jour", 1)), int(h), int(fmod(h, 1.0) * 60.0), d.get("date", "?")]


static func lire() -> Dictionary:
	if not FileAccess.file_exists(FICHIER):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	# les sauvegardes d'avant le relief (collines, lacs) ne correspondent plus à la carte
	return d if d is Dictionary and int(d.get("version", 1)) >= 3 else {}


static func supprimer() -> void:
	if existe():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))


# ================================================================ conversion grilles
static func entree_vers(e: Dictionary) -> Dictionary:
	var c = e.get("contenu")
	var d := {"id": e.id, "n": int(e.n), "x": int(e.x), "y": int(e.y), "r": bool(e.get("r", false)),
			"contenu": grille_vers(c) if c is Grille else null}
	if float(e.get("us", 0.0)) > 0.0:
		d["us"] = float(e.us)   # usure d'une arme ou d'un outil
	return d


static func entree_depuis(d) -> Dictionary:
	if not (d is Dictionary) or not d.has("id"):
		return {}
	var e := {"id": str(d.id), "n": int(d.get("n", 1)), "x": int(d.get("x", 0)), "y": int(d.get("y", 0)),
			"r": bool(d.get("r", false)), "contenu": grille_depuis(d.get("contenu"))}
	if float(d.get("us", 0.0)) > 0.0:
		e["us"] = float(d.us)
	return e


static func grille_vers(g: Grille) -> Dictionary:
	var es := []
	for e in g.entrees:
		es.append(entree_vers(e))
	return {"nom": g.nom, "w": g.w, "h": g.h, "e": es}


static func grille_depuis(d) -> Grille:
	if not (d is Dictionary):
		return null
	var g := Grille.creer(str(d.get("nom", "")), int(d.get("w", 4)), int(d.get("h", 4)))
	for ed in d.get("e", []):
		var e := entree_depuis(ed)
		if not e.is_empty() and Items.DB.has(e.id):
			g.entrees.append(e)
	return g


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


static func _vd(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array and a.size() == 3 else Vector3.ZERO


# ================================================================ sauvegarde
static func sauver(main: Node) -> bool:
	var p = Game.player
	if p == null or not p.alive:
		return false
	var d := {"version": 3, "monde": main.world.VERSION_MONDE, "graine": Game.graine_monde, "jour": Game.day, "heure": Game.time_hours,
			"date": Time.get_datetime_string_from_system(false, true)}
	# joueur
	var eq := {}
	for s in p.equipped:
		var e: Dictionary = p.equipped[s]
		eq[s] = entree_vers(e) if not e.is_empty() else null
	d["joueur"] = {
		"pos": _v(p.global_position), "rot": p.rotation.y, "tete": p.head.rotation.x,
		"sante": p.health, "faim": p.hunger, "soif": p.thirst, "endurance": p.stamina,
		"poches": grille_vers(p.poches), "equipe": eq, "barre": p.hotbar, "barre_verrou": p.hotbar_verrou, "slot": p.slot,
		"chargeurs": p.mags, "accessoires": p.accessoires, "argent": p.argent, "progression": p.prog.vers_dict(), "lampe": p.flashlight_on, "maladie": p.maladie, "fav": p.recettes_fav,
		"saignement": p.saignement, "morsure": p.morsure_t, "morsure_risque": p.morsure_risque, "desinfectee": p.plaie_desinfectee,
		"infection": p.infection, "fracture": p.fracture, "froid": p.froid,
	}
	# meubles du monde (identifiés par leur numéro de génération)
	var cont := {}
	for c in main.world.conteneurs:
		if is_instance_valid(c) and (c.searched or c.grille != null):
			cont[str(c.uid)] = {"f": c.searched, "g": grille_vers(c.grille) if c.grille else null}
	d["conteneurs"] = cont
	if Game.recolte and is_instance_valid(Game.recolte):
		d["recolte"] = Game.recolte.etat()
	if main.has_method("etat_camps"):
		d["camps"] = main.etat_camps()
		d["primes"] = main.primes_payees
	# objets posés par le joueur, tas au sol
	var tas := []
	var caisses := []
	var objets := []
	for n in main.get_children():
		if n is LootContainer and n.uid < 0 and n.grille:
			var item := {"pos": _v(n.global_position), "rot": n.rotation.y, "g": grille_vers(n.grille)}
			if n.is_in_group("tas_sol"):
				if not n.grille.vide():
					tas.append(item)
			else:
				caisses.append(item)
		elif n is Placeable:
			objets.append({"type": n.kind, "pos": _v(n.global_position), "rot": n.rotation.y, "pv": n.health, "s": n.stock, "m": n.minuteur, "sec": n.secs, "arm": n.armee})
	d["tas"] = tas
	d["caisses"] = caisses
	d["objets"] = objets
	var bases := []
	for b in main.get_tree().get_nodes_in_group("base_construction"):
		if not b.is_queued_for_deletion():
			bases.append(b.vers_dict())
	d["constructions"] = bases
	# zombies vivants
	var zs := []
	for z in main.get_tree().get_nodes_in_group("zombies"):
		zs.append({"pos": _v(z.global_position), "type": z.kind, "garde": z.persistent, "rayon": z.home_radius,
				"pv": z.health, "maison": _v(z.home)})
	for v in main.zombies_virtuels:
		zs.append({"pos": _v(v.pos), "type": v.kind, "garde": true, "rayon": v.rayon, "pv": v.pv, "maison": _v(v.maison)})
	d["zombies"] = zs
	var ouvertes := []
	for pt in main.world.portes:
		if is_instance_valid(pt) and pt.ouverte:
			ouvertes.append(pt.idx)
	d["portes"] = ouvertes
	d["marqueurs"] = Game.marqueurs
	d["lieux_fouilles"] = Game.lieux_fouilles.keys()
	var f := FileAccess.open(FICHIER, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	return true


# ================================================================ chargement
## Après la génération du monde : état des meubles.
static func appliquer_monde(main: Node, d: Dictionary) -> void:
	var cont: Dictionary = d.get("conteneurs", {})
	if main.has_method("appliquer_camps") and d.has("camps"):
		main.appliquer_camps(d.camps)
		main.primes_payees = Array(d.get("primes", []))
	# sauvegarde d'une version plus ancienne de la génération : les numéros des meubles et des portes
	# ne désignent plus les mêmes objets, on garde alors la carte telle que générée
	if int(d.get("monde", 1)) != main.world.VERSION_MONDE:
		cont = {}
		d.erase("portes")
		d.erase("recolte")
	if d.has("recolte") and Game.recolte:
		Game.recolte.appliquer(d.recolte)
	for c in main.world.conteneurs:
		var k := str(c.uid)
		if cont.has(k):
			var cd: Dictionary = cont[k]
			c.searched = bool(cd.get("f", false))
			c.grille = grille_depuis(cd.get("g"))
			if c.searched and c.modele == null and c.mat:
				c.mat.albedo_color = c.mat.albedo_color.darkened(0.35)
	if d.has("portes"):
		var ouv := {}
		for i in d.portes:
			ouv[int(i)] = true
		for pt in main.world.portes:
			pt.basculer(ouv.has(pt.idx), true)
	Game.day = int(d.get("jour", 1))
	Game.time_hours = float(d.get("heure", 8.0))
	Game.marqueurs.clear()
	for mq in d.get("marqueurs", []):
		Game.marqueurs.append({"nom": str(mq.get("nom", "")), "x": float(mq.get("x", 0.0)), "z": float(mq.get("z", 0.0))})
	Game.lieux_fouilles.clear()
	for k in d.get("lieux_fouilles", []):
		Game.lieux_fouilles[str(k)] = true


static func appliquer_zombies(main: Node, d: Dictionary) -> void:
	var ref := _vd(d.get("joueur", {}).get("pos", [0, 0, 0]))
	for zd in d.get("zombies", []):
		var pos := _vd(zd.pos)
		if bool(zd.get("garde", false)):
			main.placer_zombie(pos, str(zd.get("type", "civil")), float(zd.get("rayon", 12.0)), float(zd.get("pv", -1.0)), _vd(zd.get("maison", zd.pos)), ref)
		else:
			var z = main.spawn_zombie(pos, str(zd.get("type", "civil")), false, float(zd.get("rayon", 12.0)))
			z.health = float(zd.get("pv", z.health))
			z.home = _vd(zd.get("maison", zd.pos))


static func appliquer_joueur(main: Node, d: Dictionary) -> void:
	var p = main.player
	var j: Dictionary = d.get("joueur", {})
	if j.is_empty():
		return
	p.global_position = _vd(j.pos)
	p.rotation.y = float(j.get("rot", 0.0))
	p.head.rotation.x = float(j.get("tete", 0.0))
	p.health = float(j.get("sante", 100.0))
	p.hunger = float(j.get("faim", 100.0))
	p.thirst = float(j.get("soif", 100.0))
	p.stamina = float(j.get("endurance", 100.0))
	if j.get("progression") is Dictionary:
		p.prog.depuis_dict(j.progression)
	var g := grille_depuis(j.get("poches"))
	if g:
		p.poches = g
		p.poches.nom = "Sur toi"
	p.maj_poches()
	for s in p.equipped:
		p.equipped[s] = entree_depuis(j.get("equipe", {}).get(s))
	var barre: Array = j.get("barre", [])
	for i in mini(5, barre.size()):
		p.hotbar[i] = str(barre[i]) if Items.DB.has(str(barre[i])) else ""
	var verrou: Array = j.get("barre_verrou", [])
	for i in 5:
		p.hotbar_verrou[i] = i < verrou.size() and bool(verrou[i]) and p.hotbar[i] != ""
	p.mags = {}
	for k in j.get("chargeurs", {}):
		p.mags[k] = int(j.chargeurs[k])
	p.accessoires = {}
	var acc: Dictionary = j.get("accessoires", {})
	for a in acc:
		if not Items.DB.has(str(a)):
			continue
		p.accessoires[a] = {}
		for emp in acc[a]:
			if Items.DB.has(str(acc[a][emp])):
				p.accessoires[a][emp] = str(acc[a][emp])
	p.flashlight_on = bool(j.get("lampe", false))
	p.argent = int(j.get("argent", 40))
	p.maladie = float(j.get("maladie", 0.0))
	p.saignement = float(j.get("saignement", 0.0))
	p.morsure_t = float(j.get("morsure", 0.0))
	p.morsure_risque = float(j.get("morsure_risque", 0.0))
	p.plaie_desinfectee = bool(j.get("desinfectee", false))
	p.infection = float(j.get("infection", 0.0))
	p._palier_fievre = int(p.infection / 30.0)
	p.fracture = bool(j.get("fracture", false))
	p.froid = float(j.get("froid", 0.0))
	p.recettes_fav.clear()
	for k in j.get("fav", []):
		p.recettes_fav.append(str(k))
	p.slot = -1
	p._select_slot(clampi(int(j.get("slot", 0)), 0, 4))
	p._refresh_weapon_model()
	# objets posés
	# constructions (bases du joueur)
	for bd in d.get("constructions", []):
		var base = Construction.Base.new()
		main.add_child(base)
		base.global_position = Vector3(bd.o[0], bd.o[1], bd.o[2])
		base.rotation.y = float(bd.get("r", 0.0))
		for pd in bd.get("p", []):
			if not Construction.PIECES.has(str(pd.get("t", ""))):
				continue
			var pc = Construction.new()
			pc.setup(str(pd.t), int(pd.get("n", 0)), Array(pd.get("c", [])), float(pd.get("r", 0.0)))
			pc.pv = float(pd.get("pv", pc.pv))
			pc.ouverte = bool(pd.get("o", false))
			base.ajouter(pc)
	for o in d.get("objets", []):
		var pl = Placeable.new()
		pl.setup(str(o.get("type", "etabli")))
		main.add_child(pl)
		pl.global_position = _vd(o.pos)
		pl.rotation.y = float(o.get("rot", 0.0))
		pl.health = float(o.get("pv", pl.health))
		pl.health_max = maxf(pl.health_max, pl.health)
		pl.stock = int(o.get("s", 0))
		pl.minuteur = float(o.get("m", 0.0))
		pl.secs = int(o.get("sec", 0))
		pl.armee = bool(o.get("arm", true))
		pl._maj_visuel_stock()
	for c in d.get("caisses", []):
		var crate = LootContainer.new()
		crate.setup("Caisse de stockage", "", Vector3(1.2, 0.8, 0.8), Color(0.45, 0.32, 0.18))
		crate.make_storage(8, 6)
		crate.grille = grille_depuis(c.get("g"))
		main.add_child(crate)
		crate.global_position = _vd(c.pos)
		crate.rotation.y = float(c.get("rot", 0.0))
	for t in d.get("tas", []):
		var pile = LootContainer.new()
		pile.setup("Objets au sol", "", Vector3(0.5, 0.25, 0.5), Color(0.35, 0.3, 0.25))
		pile.make_storage(6, 6)
		pile.grille = grille_depuis(t.get("g"))
		pile.add_to_group("tas_sol")
		main.add_child(pile)
		pile.global_position = _vd(t.pos)
