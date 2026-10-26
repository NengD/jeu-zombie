extends StaticBody3D
## Garde d'un campement de marchand : survivant armé, posté (il ne quitte pas sa place).
## Il scrute les alentours et abat les zombies qui approchent ; il ne tire jamais sur le joueur.
## [F] : quelques mots avec lui.

const LodAnim = preload("res://scripts/lod_anim.gd")
const Perso = preload("res://scripts/perso.gd")
const ModeleUtil = preload("res://scripts/modele_util.gd")
const Effets = preload("res://scripts/effets.gd")
const ARMES := ["ak74", "m4a1", "ak74m", "benelli_m4", "mosin"]
const PHRASES := [
	"On veille jour et nuit. Tant qu'on est là, rien n'entre.",
	"Les zombies viennent toujours par l'entrée. On les attend.",
	"Fais tes affaires tranquille, on surveille.",
	"La nuit, ils sont plus nombreux. Garde ta lampe allumée près du camp.",
	"Pas de bagarre dans le camp, compris ?",
	"Les bandits ne s'approchent pas d'ici. Ils savent ce qui les attend.",
]

var arme := "ak74"
var portee := 30.0
var regard_base := 0.0          # direction surveillée (rotation.y globale)
var modele: Node3D
var pap: AnimationPlayer
var lod = null                # animation à niveau de détail (lod_anim.gd)
var arme_noeud: Node3D
var bras_ik: Node
var cible: Node3D = null
var _cherche_t := 0.0
var _tir_t := 0.0
var _chargeur := 30
var _recharge_t := 0.0
var _balayage := 0.0
var _phrase := 0


func setup(rng: RandomNumberGenerator) -> void:
	add_to_group("gardes")
	collision_layer = Game.LAYER_WORLD | Game.LAYER_INTERACT
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	arme = ARMES[rng.randi() % ARMES.size()]
	if not Items.DB.has(arme):
		arme = "ak74"
	_chargeur = int(Items.info(arme).get("mag", 30))
	_balayage = rng.randf() * TAU
	_phrase = rng.randi() % PHRASES.size()
	if not Perso.disponible():
		return
	modele = Perso.creer(Perso.apparence("garde", rng))
	add_child(modele)
	pap = ModeleUtil.anim_player(modele)
	if pap:
		ModeleUtil.boucler(pap, ["idle", "arme_idle", "visee"])
		pap.playback_default_blend_time = 0.25
		pap.play("arme_idle" if pap.has_animation("arme_idle") else "idle")
	var prise: Node3D = modele.find_child("Prise", true, false)
	var m := ModeleUtil.arme(arme)
	if prise and m:
		prise.add_child(m)
		arme_noeud = m
		bras_ik = preload("res://scripts/bras_ik.gd").new()
		bras_ik.corps = self
		bras_ik.arme = m
		bras_ik.poids = 1.0
		bras_ik.pistolet = float(Items.info(arme).get("len", 0.3)) < 0.4
		bras_ik.point_main_g = preload("res://scripts/fps_arms.gd").hand_points(arme, Items.info(arme), Accessoires.points(arme, m)).L
		ModeleUtil.squelette(modele).add_child(bras_ik)
	ModeleUtil.distance_visible(modele, 160.0)
	lod = LodAnim.new(pap, ModeleUtil.squelette(modele))


func _process(delta: float) -> void:
	if lod:
		lod.maj(delta, global_position, cible != null)


func _physics_process(delta: float) -> void:
	var p = Game.player
	if p:
		LodAnim.ombres(modele, global_position.distance_to(p.global_position) < LodAnim.OMBRE_DIST)
	if p == null or global_position.distance_to(p.global_position) > 140.0:
		if pap:
			pap.active = false
		return
	if pap:
		pap.active = true
	_tir_t -= delta
	_cherche_t -= delta
	if _cherche_t <= 0.0:
		_cherche_t = 0.3
		cible = _chercher()
	if _recharge_t > 0.0:
		_recharge_t -= delta
		if _recharge_t <= 0.0:
			_chargeur = int(Items.info(arme).get("mag", 30))
	var vise: bool = cible != null and is_instance_valid(cible) and cible.state != 3
	if vise:
		var d: Vector3 = cible.global_position - global_position
		var voulu := atan2(-d.x, -d.z)
		global_rotation.y = lerp_angle(global_rotation.y, voulu, minf(1.0, delta * 6.0))
		if bras_ik:
			bras_ik.cible_visee = cible.global_position + Vector3.UP * 1.3
		if _tir_t <= 0.0 and _recharge_t <= 0.0 and absf(angle_difference(global_rotation.y, voulu)) < 0.2:
			_tirer()
	else:
		# surveillance : balaye lentement son secteur
		_balayage += delta * 0.35
		global_rotation.y = lerp_angle(global_rotation.y, regard_base + sin(_balayage) * 0.8, minf(1.0, delta * 1.5))
		if bras_ik:
			bras_ik.cible_visee = global_position + Vector3.UP * 1.4 - global_basis.z * 20.0
	if bras_ik:
		bras_ik.visee = move_toward(bras_ik.visee, 1.0 if vise and _recharge_t <= 0.0 else 0.0, delta * 4.0)
		bras_ik.poids = move_toward(bras_ik.poids, 0.0 if _recharge_t > 0.0 else 1.0, delta * 5.0)
	if pap:
		var nom := "visee" if vise and _recharge_t <= 0.0 else "arme_idle"
		if pap.current_animation != nom and pap.has_animation(nom):
			pap.play(nom)


## Zombie vivant le plus proche, à portée et à découvert.
func _chercher() -> Node3D:
	var oeil := global_position + Vector3.UP * 1.6
	var meilleur: Node3D = null
	var dmin := portee
	for z in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(z) or z.state == 3:
			continue
		var dist: float = oeil.distance_to(z.global_position)
		if dist >= dmin:
			continue
		var q := PhysicsRayQueryParameters3D.create(oeil, z.global_position + Vector3.UP * 1.2, Game.LAYER_WORLD, [get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			meilleur = z
			dmin = dist
	return meilleur


func _tirer() -> void:
	var w := Items.info(arme)
	_chargeur -= 1
	if _chargeur <= 0:
		_recharge_t = float(w.get("reload", 2.4)) + 0.4
		Game.play_3d("recharge", global_position + Vector3.UP * 1.2, -4.0, 0.1, 25.0)
	_tir_t = randf_range(0.9, 1.4) if int(w.get("pellets", 1)) > 1 else randf_range(0.45, 0.9)
	var famille: String = w.get("famille", "")
	var son := "tir_pompe" if famille == "pompe" else ("tir_pistolet" if famille in ["pistolet", "smg"] else "tir_fusil")
	var bouche := global_position + Vector3.UP * 1.45 - global_basis.z * 0.6
	Game.play_tir(son, bouche, 2.0)
	if arme_noeud and is_instance_valid(arme_noeud):
		var pts := Accessoires.points(arme, arme_noeud)
		Effets.flamme(arme_noeud, pts.get("bouche", Vector3(0, 0.03, -0.4)), 0.22, 1)
	var vise: Vector3 = cible.global_position + Vector3.UP * 1.3
	var dist := global_position.distance_to(cible.global_position)
	var plombs := int(w.get("pellets", 1))
	var degats := float(w.get("damage", 30.0)) * (0.6 * plombs if plombs > 1 else 1.3)
	if randf() < clampf(0.85 - dist * 0.012, 0.4, 0.85):
		cible.take_hit(degats, vise, global_position)
	else:
		var rate := vise + Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6), randf_range(-1.0, 1.0))
		var q := PhysicsRayQueryParameters3D.create(bouche, bouche + (rate - bouche).normalized() * (dist + 6.0), Game.LAYER_WORLD, [get_rid()])
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		if not h.is_empty():
			Effets.impact(get_parent(), h.position, h.normal, false)


func get_prompt() -> String:
	return "[F] Parler au garde"


func interact(_player: Node) -> void:
	Game.msg("Garde : « %s »" % PHRASES[_phrase])
	_phrase = (_phrase + 1) % PHRASES.size()
