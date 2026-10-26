extends RefCounted
## Animation à niveau de détail pour les PNJ : animation et modificateurs du squelette (bras, pieds, corps)
## avancés à la main, à chaque image près du joueur, toutes les 2 (20 m) / 4 (45 m) / 8 (hors du champ) images.
## Le propriétaire appelle maj(delta, position, toujours) dans son _process.

var ap: AnimationMixer
var sk: Skeleton3D
var acc := 0.0
var image := randi() % 12


func _init(a: AnimationMixer, s: Skeleton3D) -> void:
	ap = a
	sk = s
	if ap:
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if sk:
		sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL


## 1 = chaque image ; toujours = en combat / poursuite
static func palier(pos: Vector3, toujours: bool) -> int:
	var p = Game.player
	if toujours or p == null:
		return 1
	if not p.camera.is_position_in_frustum(pos + Vector3.UP):
		return 8
	var d := pos.distance_squared_to(p.global_position)
	if d > 2025.0:
		return 4
	if d > 400.0:
		return 2
	return 1


## Ombres portées d'un personnage : seulement près du joueur (OMBRE_DIST), sinon ~16 appels de rendu
## de plus par personnage (4 parts de l'ombre du soleil). Rend celles qui étaient actives.
const OMBRE_DIST := 30.0

static func ombres(modele: Node, oui: bool) -> void:
	if modele == null or bool(modele.get_meta("ombre", true)) == oui:
		return
	modele.set_meta("ombre", oui)
	if oui:
		for m in modele.get_meta("ombre_ms", []):
			if is_instance_valid(m):
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		return
	var ms := []
	for m in modele.find_children("*", "GeometryInstance3D", true, false):
		if m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ms.append(m)
	modele.set_meta("ombre_ms", ms)


func maj(delta: float, pos: Vector3, toujours: bool) -> void:
	if ap == null or not ap.active:
		acc = 0.0
		return
	acc += delta
	image += 1
	if image % palier(pos, toujours) == 0:
		ap.advance(acc)
		if sk:
			sk.advance(acc)
		acc = 0.0
