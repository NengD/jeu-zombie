extends StaticBody3D
## Marchand d'un campement gardé (scripts/camp_marchand.gd) : un stand (table, auvent, marchandises) et son vendeur.
## [F] ouvre la boutique : acheter son stock, revendre ses objets à 40 % du prix.

const Perso = preload("res://scripts/perso.gd")
const ModeleUtil = preload("res://scripts/modele_util.gd")

const METIERS := {
	"armurier": {"titre": "Armurier", "toile": Color(0.55, 0.16, 0.12), "stock": [
		"batte", "matraque", "machette", "couteau_km2000", "hache", "pioche",
		"glock19", "m45a1", "mr920", "toz34", "marlin", "mp5k",
		"mun_9mm", "mun_45", "mun_12", "mun_4570", "mun_762r", "mun_556",
		"rgd5", "point_rouge", "silencieux_9mm", "chargeur_etendu", "laser"]},
	"quincaillier": {"titre": "Quincaillier", "toile": Color(0.2, 0.35, 0.6), "stock": [
		"planche", "clous", "ferraille", "ruban", "tissu", "ciment", "marteau",
		"piques", "barbeles", "projecteur", "barricade", "etabli", "caisse_stockage", "sac_toile", "sac_a_dos"]},
	"medecin": {"titre": "Médecin", "toile": Color(0.85, 0.85, 0.82), "stock": [
		"bandage", "antidouleur", "trousse", "alcool", "eau", "soda", "barre", "conserve", "ration",
		"veste_cuir", "casque_moto"]},
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
	for k in 6:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.from_hsv(rng.randf(), 0.4, rng.randf_range(0.35, 0.8))
		_boite(Vector3(rng.randf_range(0.12, 0.3), rng.randf_range(0.08, 0.25), rng.randf_range(0.12, 0.25)), Vector3(-0.85 + k * 0.34, 0.98, rng.randf_range(-0.2, 0.2)), m, false)
	# le vendeur, derrière la table, tourné vers le client
	if Perso.disponible():
		var p: Node3D = Perso.creer(Perso.apparence("vendeur"))
		p.position = Vector3(0, 0, 0.85)
		add_child(p)
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
	return "[F] Commercer — %s, %s" % [nom, titre().to_lower()]


func interact(_player: Node) -> void:
	var ui := get_tree().get_first_node_in_group("boutique_ui")
	if ui:
		ui.ouvrir(self)
