extends Node3D
## Arc de chasse (tenu par la main gauche) : modèle Quaternius (modeles/armes/arc_corps.res), corde tendue par le code.
## Repère : X = vers les doigts de la main d'arc, Y = vers l'avant (sens de la flèche), Z = vers le haut (branches).
## La corde passe par l'encoche (repère de l'arc) : au repos juste derrière la poignée, tirée jusqu'à la joue.

const MAILLAGE_ARC: ArrayMesh = preload("res://modeles/armes/arc_corps.res")
const MAILLAGE_FLECHE: ArrayMesh = preload("res://modeles/armes/fleche.res")
const ALLONGE := 0.64              # allonge à pleine tension
const LONGUEUR_FLECHE := 0.72

var corde_h: MeshInstance3D
var corde_b: MeshInstance3D
var fleche: Node3D                 # flèche encochée (visible pendant la tension)
var _pointe_h := Vector3.ZERO
var _pointe_b := Vector3.ZERO
var band := -0.2                   # corde au repos (distance poignée-corde, Y)

func _ready() -> void:
	# arc recourbé « Wooden Bow » de Quaternius (CC0), converti par outils/godot/normaliser_arc.gd (sans sa corde)
	var corps := MeshInstance3D.new()
	corps.mesh = MAILLAGE_ARC
	add_child(corps)
	_pointe_h = MAILLAGE_ARC.get_meta("pointe_h")
	_pointe_b = MAILLAGE_ARC.get_meta("pointe_b")
	band = MAILLAGE_ARC.get_meta("band")
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.85, 0.82, 0.72)
	corde_h = _cylindre(0.0028, mc)
	corde_b = _cylindre(0.0028, mc)
	# flèche encochée (« Arrow » de Quaternius, CC0) : encoche à l'origine, pointe vers +Y
	fleche = MeshInstance3D.new()
	(fleche as MeshInstance3D).mesh = MAILLAGE_FLECHE
	fleche.scale = Vector3.ONE * (LONGUEUR_FLECHE + 0.04) / float(MAILLAGE_FLECHE.get_meta("longueur"))
	add_child(fleche)
	fleche.visible = false
	maj(0.0, false)

## Corde et flèche pour une tension donnée (0 = au repos, 1 = pleine allonge).
func maj(tension: float, avec_fleche: bool, allonge := ALLONGE) -> void:
	var enc := Vector3(0, lerpf(band, -allonge, clampf(tension, 0.0, 1.0)), 0)
	_tendre(corde_h, _pointe_h, enc)
	_tendre(corde_b, enc, _pointe_b)
	fleche.visible = avec_fleche
	fleche.position = enc

func _tendre(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := maxf(d.length(), 0.001)
	var y := d / l
	var x := y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).normalized()
	var z := x.cross(y)
	m.transform = Transform3D(Basis(x, y * l, z), (a + b) * 0.5)

func _cylindre(r: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 1.0
	cm.radial_segments = 4
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
