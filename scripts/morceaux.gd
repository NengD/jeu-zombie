extends Node
## Chargement de la carte par morceaux : seules les cases de 128 m proches du joueur restent dans l'arbre
## (rendu, physique, nœuds) ; les autres sont détachées, puis rattachées quand il s'approche.
## Un nœud détaché garde tout son état (meuble fouillé, porte ouverte) : il est seulement hors de l'arbre.
## Une case peut aussi avoir des constructions différées (maillage du relief, géométrie des chunks),
## faites la première fois qu'elle s'approche : le monde reste identique pour une même graine.

const CASE := 128.0
const RAYON := 840.0        # cases rattachées jusqu'à cette distance (la caméra voit à 700 m)
const MARGE := 160.0        # détachées au-delà de RAYON + MARGE (pas de va-et-vient en bord de case)
const RAYON_IMMEDIAT := 220.0   # rattachées tout de suite (téléportation, réveil des zombies à 175 m)
const TAILLE_MAX := 300.0   # un nœud plus grand (rivière, limites de la carte, relief) reste toujours là
const BUDGET_US := 2500     # temps de rattachement par image au plus

var cases := {}             # Vector2i -> Array de [nœud, parent]
var differes := {}          # Vector2i -> Array de [Callable (renvoie un Node3D), parent]
var actives := {}           # Vector2i -> true : cases dans l'arbre
var case_joueur := Vector2i(999999, 999999)
var file: Array = []        # cases actives encore à rattacher, les plus proches d'abord
var reste := {}             # case -> entrées [nœud ou Callable, parent] encore à rattacher


static func case_de(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CASE), floori(p.z / CASE))


## Range tous les enfants de « parent » (dont le repère est celui du monde) dans leur case et les détache.
func ranger(parent: Node) -> void:
	for n in parent.get_children():
		var c = _centre(n)
		if c == null:
			continue
		var k := case_de(c)
		if not cases.has(k):
			cases[k] = []
		cases[k].append([n, parent])
		parent.remove_child(n)


## Construction différée : « fabrique » renvoie le nœud à ajouter sous « parent » la première fois que la case approche.
func differer(pos: Vector3, fabrique: Callable, parent: Node) -> void:
	var k := case_de(pos)
	if not differes.has(k):
		differes[k] = []
	differes[k].append([fabrique, parent])


## Nœuds rangés sous « parent » et actuellement détachés (pour degager()).
## (Les constructions différées pas encore faites n'en font pas partie.)
func detaches(parent: Node) -> Array:
	var res: Array = []
	for k in cases:
		for e in cases[k]:
			if e[1] == parent and is_instance_valid(e[0]) and e[0].get_parent() == null:
				res.append(e[0])
	return res


func _centre(n: Node):
	if not (n is Node3D):
		return null
	var ab := AABB()
	if n is MeshInstance3D and n.mesh:
		ab = n.transform * n.mesh.get_aabb()
	elif n is MultiMeshInstance3D and n.multimesh:
		ab = n.transform * n.multimesh.get_aabb()
	elif n is StaticBody3D and n.position == Vector3.ZERO:
		# corps d'un chunk : formes placées en coordonnées du monde
		var premier := true
		for cs in n.get_children():
			if not (cs is CollisionShape3D):
				continue
			if cs.shape is HeightMapShape3D or cs.shape is WorldBoundaryShape3D:
				return null
			var b := AABB(cs.position - Vector3.ONE, Vector3.ONE * 2.0)
			ab = b if premier else ab.merge(b)
			premier = false
		if premier:
			return null
	elif n.get_class() == "Node3D" and n.position == Vector3.ZERO:
		return null   # conteneur (Sol, Decor…) dont les enfants sont en coordonnées du monde
	else:
		return (n as Node3D).position
	if ab.size.x > TAILLE_MAX or ab.size.z > TAILLE_MAX:
		return null
	return ab.get_center()


func _distance(k: Vector2i, p: Vector3) -> float:
	var dx := maxf(maxf(k.x * CASE - p.x, p.x - (k.x + 1) * CASE), 0.0)
	var dz := maxf(maxf(k.y * CASE - p.z, p.z - (k.y + 1) * CASE), 0.0)
	return sqrt(dx * dx + dz * dz)



## Met à jour les cases autour de « p ». « tout » : rattache tout le rayon d'un coup (chargement de la partie).
func maj(p: Vector3, tout := false) -> void:
	var c := case_de(p)
	if c != case_joueur:
		case_joueur = c
		for k in actives.keys():
			if _distance(k, p) > RAYON + MARGE:
				_detacher(k)
		var r := ceili(RAYON / CASE) + 1
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var k := c + Vector2i(dx, dz)
				if actives.has(k) or _distance(k, p) > RAYON or not (cases.has(k) or differes.has(k)):
					continue
				actives[k] = true
				var l: Array = cases.get(k, []).duplicate()
				l.append_array(differes.get(k, []))
				differes.erase(k)
				reste[k] = l
		file = reste.keys()
		file.sort_custom(func(a, b): return _distance(a, p) < _distance(b, p))
	# les cases tout près d'abord et sans attendre, le reste quelques millisecondes par image
	var t0 := Time.get_ticks_usec()
	while not file.is_empty():
		var k: Vector2i = file[0]
		var l: Array = reste[k]
		if l.is_empty():
			reste.erase(k)
			file.pop_front()
			continue
		if not tout and _distance(k, p) > RAYON_IMMEDIAT and Time.get_ticks_usec() - t0 > BUDGET_US:
			break
		_rattacher(l.pop_back(), k)


func _rattacher(e: Array, k: Vector2i) -> void:
	var n = e[0]
	var parent: Node = e[1]
	if n is Callable:
		n = n.call()
		if n == null:
			return
		cases[k] = cases.get(k, [])
		cases[k].append([n, parent])
	if is_instance_valid(n) and n.get_parent() == null:
		parent.add_child(n)


func _detacher(k: Vector2i) -> void:
	actives.erase(k)
	# constructions différées pas encore faites : remises pour la prochaine fois
	for e in reste.get(k, []):
		if e[0] is Callable:
			differes[k] = differes.get(k, [])
			differes[k].append(e)
	reste.erase(k)
	file.erase(k)
	for e in cases.get(k, []):
		var n = e[0]
		if is_instance_valid(n) and n.get_parent() == e[1]:
			e[1].remove_child(n)


func _process(_delta: float) -> void:
	var pl = Game.player
	if pl != null and is_instance_valid(pl) and pl.is_inside_tree():
		maj(pl.global_position)


## Libère les nœuds détachés à la fin de la partie (sinon ils resteraient en mémoire).
func _exit_tree() -> void:
	for k in cases:
		for e in cases[k]:
			if is_instance_valid(e[0]) and e[0].get_parent() == null:
				e[0].free()
	cases.clear()
	differes.clear()
