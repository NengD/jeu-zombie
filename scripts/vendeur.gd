extends StaticBody3D
## Marchand d'un campement gardé (scripts/camp_marchand.gd) : un stand (table, auvent, marchandises) et son vendeur.
## [F] ouvre la boutique : acheter son stock, revendre ses objets à 40 % du prix.

const Perso = preload("res://scripts/perso.gd")
const ModeleUtil = preload("res://scripts/modele_util.gd")
const Commandes = preload("res://scripts/commandes.gd")

const METIERS := {
	"armurier": {"titre": "Armurier", "toile": Color(0.55, 0.16, 0.12), "stock": [
		"batte", "matraque", "machette", "couteau_km2000", "hache", "pioche",
		"glock19", "m45a1", "mr920", "toz34", "marlin", "mp5k",
		"mun_9mm", "mun_45", "mun_12", "mun_4570", "mun_762r", "mun_556",
		"mun_545", "mun_762x39", "rgd5", "molotov", "kit_reparation", "point_rouge", "silencieux_9mm", "chargeur_etendu", "laser"],
		"rachat": ["type:gun", "type:ammo", "type:accessoire", "type:lancer", "kit_reparation"]},
	"quincaillier": {"titre": "Quincaillier", "toile": Color(0.2, 0.35, 0.6), "stock": [
		"planche", "clous", "ferraille", "ruban", "tissu", "ciment", "marteau",
		"piques", "barbeles", "projecteur", "barricade", "etabli", "caisse_stockage", "sac_toile", "sac_a_dos",
		"sac_sport", "sac_randonnee", "casque_chantier", "lunettes", "bonnet", "casquette", "kit_reparation", "canne_peche"],
		"rachat": ["planche", "clous", "ferraille", "ruban", "tissu", "ciment", "buche", "pierre", "minerai", "cuir", "bouteille_vide"]},
	"medecin": {"titre": "Médecin", "toile": Color(0.85, 0.85, 0.82), "stock": [
		"bandage", "antidouleur", "trousse", "medicament", "antibiotiques", "attelle", "alcool", "eau", "soda", "barre", "conserve", "ration",
		"veste_cuir", "casque_moto", "masque_gaz"],
		"rachat": ["type:heal", "alcool"]},
	"boucher": {"titre": "Boucher-chasseur", "toile": Color(0.5, 0.32, 0.2), "stock": [
		"arc", "fleche", "couteau_km2000", "hache", "collet", "piege_machoires", "sechoir", "feu_camp",
		"viande_cuite", "viande_sechee", "bouillon", "ragout", "cuir", "sac_chasse", "capuche_cuir", "veste_cuir"],
		"rachat": ["viande_crue", "viande_cuite", "viande_sechee", "peau", "cuir", "graisse", "os", "plume", "poisson_cru", "poisson_cuit"]},
	"epicier": {"titre": "Épicier", "toile": Color(0.3, 0.55, 0.25), "stock": [
		"eau", "soda", "barre", "conserve", "ration", "viande_sechee", "bouillon", "alcool", "medicament",
		"torche", "feu_camp", "lit", "recuperateur_eau", "sac_toile", "sac_sport", "casquette", "bonnet"],
		"rachat": ["eau", "soda", "barre", "conserve", "ration", "viande_sechee", "viande_cuite", "ragout", "bouillon", "alcool", "pomme", "raisin", "epi_mais", "mais_grille", "poisson_cuit"]},
	"mecanicien": {"titre": "Mécanicien", "toile": Color(0.75, 0.55, 0.12), "stock": [
		"cle_molette", "marteau", "pioche", "batte_cloutee", "piece_auto", "essence", "batterie", "pneu", "ferraille",
		"ruban", "clous", "projecteur", "barbeles", "casque_chantier", "lunettes", "masque_gaz", "veste_renforcee"],
		"rachat": ["piece_auto", "essence", "batterie", "pneu", "ferraille", "minerai", "cle_molette"]},
}
## Les marchands rachètent à 40 % ; un métier rachète ses spécialités (« rachat ») plus cher.
const BONUS_RACHAT := 1.75

# objets posés sur l'étal (les cases restantes : boîtes colorées)
const ETAL := {
	"medecin": ["res://modeles/objets/trousse.scn", "res://modeles/objets/bandage.scn", "res://modeles/objets/eau.scn",
		"res://modeles/objets/bandage.scn", "res://modeles/objets/conserve.scn", "res://modeles/objets/barre.scn"],
	"quincaillier": ["res://modeles/props/seau.scn", "res://modeles/objets/essence.scn", "res://modeles/armes/hache.scn"],
	"armurier": ["res://modeles/armes/glock19.scn", "res://modeles/armes/m45a1.scn", "res://modeles/props/caisse_munitions.scn",
		"res://modeles/armes/machette.scn", "res://modeles/objets/molotov.scn"],
	"boucher": ["res://modeles/armes/couteau_km2000.scn", "res://modeles/armes/hache.scn", "res://modeles/objets/conserve_ouverte.scn"],
	"epicier": ["res://modeles/objets/conserve.scn", "res://modeles/objets/eau.scn", "res://modeles/objets/barre.scn",
		"res://modeles/objets/bouteille2.scn", "res://modeles/objets/conserve.scn", "res://modeles/objets/eau.scn"],
	"mecanicien": ["res://modeles/objets/essence.scn", "res://modeles/props/seau.scn", "res://modeles/objets/essence.scn"],
}

var metier := "armurier"
var nom := "Marc"


func setup(p_metier: String, p_nom: String) -> void:
	metier = p_metier
	nom = p_nom
	add_to_group("vendeur")
	collision_layer = Game.LAYER_WORLD | Game.LAYER_INTERACT
	collision_mask = 0
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color(0.7, 0.52, 0.35)
	if ResourceLoader.exists("res://textures/planches_albedo.jpg"):
		bois.albedo_texture = load("res://textures/planches_albedo.jpg")
		bois.uv1_triplanar = true
		bois.uv1_scale = Vector3.ONE * 0.7
	var toile := StandardMaterial3D.new()
	toile.albedo_color = METIERS[metier].toile
	toile.roughness = 1.0
	toile.cull_mode = BaseMaterial3D.CULL_DISABLED
	# table et auvent (le client se tient côté -Z)
	_boite(Vector3(2.2, 0.08, 0.8), Vector3(0, 0.9, 0), bois, true)
	_boite(Vector3(2.2, 0.8, 0.05), Vector3(0, 0.45, -0.37), bois, false)
	for x in [-1.05, 1.05]:
		for z in [-0.4, 1.2]:
			_boite(Vector3(0.08, 2.5, 0.08), Vector3(x, 1.25, z), bois, false)
	var auvent := _boite(Vector3(2.5, 0.05, 1.9), Vector3(0, 2.45, 0.4), toile, false)
	auvent.rotation.x = 0.12
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.2, 0.95, 0.8)
	cs.shape = bs
	cs.position = Vector3(0, 0.47, 0)
	add_child(cs)
	# marchandises sur la table
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(nom + metier)
	var etal: Array = ETAL.get(metier, [])
	for k in 6:
		if k < etal.size():
			# vrai objet du métier, couché sur la table
			var ch: String = etal[k]
			if ResourceLoader.exists(ch):
				var o: Node3D = load(ch).instantiate()
				o.position = Vector3(-0.85 + k * 0.34, 0.95, rng.randf_range(-0.15, 0.15))
				o.rotation.y = rng.randf_range(-0.6, 0.6)
				if ch.contains("/armes/"):
					o.rotation = Vector3(0, PI / 2.0 + rng.randf_range(-0.3, 0.3), PI / 2.0)
					o.position.y += 0.03
				add_child(o)
				continue
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.from_hsv(rng.randf(), 0.4, rng.randf_range(0.35, 0.8))
		_boite(Vector3(rng.randf_range(0.12, 0.3), rng.randf_range(0.08, 0.25), rng.randf_range(0.12, 0.25)), Vector3(-0.85 + k * 0.34, 0.98, rng.randf_range(-0.2, 0.2)), m, false)
	# le vendeur, derrière la table, tourné vers le client
	if Perso.disponible():
		var a := Perso.apparence("vendeur", rng)
		Perso.tenue_metier(a, metier, rng)
		var p: Node3D = Perso.creer(a)
		p.position = Vector3(0, 0, 0.85)
		add_child(p)
		_habit_metier(p)
		var pap := ModeleUtil.anim_player(p)
		if pap and pap.has_animation("idle"):
			ModeleUtil.boucler(pap, ["idle"])
			pap.play("idle")
		var cv := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.3
		cap.height = 1.8
		cv.shape = cap
		cv.position = Vector3(0, 0.9, 0.85)
		add_child(cv)


## Pièces de vêtement en plus, suivant le bassin : bas de blouse du médecin, tablier du quincaillier, du boucher, de l'épicier.
func _habit_metier(p: Node3D) -> void:
	var sk: Skeleton3D = ModeleUtil.squelette(p)
	if sk == null or sk.find_bone("pelvis") < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = "pelvis"
	sk.add_child(ba)
	# repère du bassin ramené à celui du modèle (avant -Z, haut +Y) : les pièces restent droites
	var piv := Node3D.new()
	ba.add_child(piv)
	var rel := Transform3D()
	var n: Node = sk
	while n != null and n != p:
		if n is Node3D:
			rel = (n as Node3D).transform * rel
		n = n.get_parent()
	var os := rel * sk.get_bone_global_rest(sk.find_bone("pelvis"))
	piv.transform = os.affine_inverse() * Transform3D(Basis(), os.origin)
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	match metier:
		"medecin":
			# bas de la blouse blanche, ouverte devant (cylindre sans fond, fendu)
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.19
			cyl.bottom_radius = 0.25
			cyl.height = 0.5
			cyl.radial_segments = 10
			cyl.cap_top = false
			cyl.cap_bottom = false
			mi.mesh = cyl
			mi.position = Vector3(0, -0.2, -0.01)
			mi.scale = Vector3(1.0, 1.0, 0.8)
			m.albedo_color = Color(0.86, 0.87, 0.85)
		"quincaillier", "boucher", "epicier":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.36, 0.55, 0.015)
			mi.mesh = bm
			mi.position = Vector3(0, -0.16, -0.15)   # avant du personnage = -Z
			mi.rotation.x = -0.08
			m.albedo_color = {"quincaillier": Color(0.2, 0.27, 0.36), "boucher": Color(0.78, 0.74, 0.7), "epicier": Color(0.24, 0.42, 0.22)}[metier]
			# poche du tablier
			var po := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.26, 0.12, 0.02)
			po.mesh = pm
			po.position = Vector3(0, 0.0, -0.01)
			po.material_override = m
			mi.add_child(po)
		_:
			piv.queue_free()
			return
	mi.material_override = m
	piv.add_child(mi)


func _boite(taille: Vector3, pos: Vector3, m: Material, ombre: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	if not ombre:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi


func titre() -> String:
	return METIERS[metier].titre


func stock() -> Array:
	return METIERS[metier].stock


func get_prompt() -> String:
	var n := 0
	if Game.player:
		for c in Commandes.liste(self):
			if not c.fait:
				n += 1
	return "[F] Commercer — %s, %s%s" % [nom, titre().to_lower(), "" if n == 0 else " (%d commande%s)" % [n, "s" if n > 1 else ""]]


func interact(_player: Node) -> void:
	var ui := get_tree().get_first_node_in_group("boutique_ui")
	if ui:
		ui.ouvrir(self)


## Prix de rachat d'une unité : 40 %, plus pour les spécialités du métier.
func prix_rachat(id: String) -> int:
	var k := 1.15 if Game.player and Game.player.prog.a("marchandage") else 1.0   # talent Marchandage
	return roundi(Items.prix_vente(id, BONUS_RACHAT if est_specialite(id) else 1.0) * k)


## Spécialités rachetées plus cher (affichées dans la boutique).
func specialites() -> Array:
	return METIERS[metier].get("rachat", [])


## Spécialité de ce marchand : id listé dans « rachat », ou « type:<type> » (armurier : toutes les armes à feu…).
func est_specialite(id: String) -> bool:
	var r: Array = METIERS[metier].get("rachat", [])
	return id in r or ("type:" + str(Items.info(id).get("type", ""))) in r
