class_name Grille
extends RefCounted
## Grille d'inventaire (poches, sac, gilet, meuble, caisse…).
## Chaque objet occupe une zone de cases (taille définie dans items.gd) et peut être tourné.
## Entrée = {"id": String, "n": int, "x": int, "y": int, "r": bool, "contenu": Grille ou null}

var nom := ""
var w := 5
var h := 2
var entrees: Array = []


static func creer(p_nom: String, p_w: int, p_h: int) -> Grille:
	var g := Grille.new()
	g.nom = p_nom
	g.w = p_w
	g.h = p_h
	return g


static func taille(e: Dictionary) -> Vector2i:
	var s: Vector2i = Items.size(e.id)
	return Vector2i(s.y, s.x) if e.get("r", false) else s


func rect(e: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(e.x, e.y), taille(e))


func entree_a(x: int, y: int) -> Dictionary:
	for e in entrees:
		if rect(e).has_point(Vector2i(x, y)):
			return e
	return {}


func peut_placer(id: String, x: int, y: int, r: bool, ignorer: Dictionary = {}) -> bool:
	var s: Vector2i = Items.size(id)
	if r:
		s = Vector2i(s.y, s.x)
	if x < 0 or y < 0 or x + s.x > w or y + s.y > h:
		return false
	var zone := Rect2i(Vector2i(x, y), s)
	for e in entrees:
		if is_same(e, ignorer):
			continue
		if rect(e).intersects(zone):
			return false
	return true


func trouver_place(id: String) -> Array:
	for r in [false, true]:
		for y in h:
			for x in w:
				if peut_placer(id, x, y, r):
					return [x, y, r]
	return []


func placer(e: Dictionary, x: int, y: int, r: bool) -> bool:
	if not peut_placer(e.id, x, y, r, e):
		return false
	e.x = x
	e.y = y
	e.r = r
	if not entrees.has(e):
		entrees.append(e)
	return true


func retirer_entree(e: Dictionary) -> void:
	entrees.erase(e)


## Ajoute n objets (empile d'abord). Renvoie le nombre qui n'a pas pu entrer.
func ajouter(id: String, n: int, contenu = null) -> int:
	var pile: int = Items.stack(id)
	if pile > 1:
		for e in entrees:
			if e.id == id and e.n < pile:
				var k := mini(pile - int(e.n), n)
				e.n += k
				n -= k
				if n <= 0:
					return 0
	while n > 0:
		var pos := trouver_place(id)
		if pos.is_empty():
			return n
		var k := mini(pile, n)
		entrees.append({"id": id, "n": k, "x": pos[0], "y": pos[1], "r": pos[2], "contenu": contenu})
		n -= k
	return 0


## Ajoute une entrée existante (avec son contenu) n'importe où. Renvoie true si réussi.
func ajouter_entree(e: Dictionary) -> bool:
	if Items.stack(e.id) > 1:
		var reste := ajouter(e.id, e.n)
		e.n = reste
		return reste == 0
	var pos := trouver_place(e.id)
	if pos.is_empty():
		return false
	e.x = pos[0]
	e.y = pos[1]
	e.r = pos[2]
	entrees.append(e)
	return true


func compter(id: String) -> int:
	var c := 0
	for e in entrees:
		if e.id == id:
			c += int(e.n)
	return c


## Retire jusqu'à n objets ; renvoie le nombre retiré.
func enlever(id: String, n: int) -> int:
	var retire := 0
	for e in entrees.duplicate():
		if n <= 0:
			break
		if e.id != id:
			continue
		var k := mini(int(e.n), n)
		e.n -= k
		n -= k
		retire += k
		if e.n <= 0:
			entrees.erase(e)
	return retire


func vide() -> bool:
	return entrees.is_empty()


func cases_utilisees() -> int:
	var c := 0
	for e in entrees:
		var s := taille(e)
		c += s.x * s.y
	return c
