extends AnimatableBody3D
## Battant d'une porte : renvoie l'interaction et les coups à la porte.

var porte: Node = null


func get_prompt() -> String:
	return porte.get_prompt() if porte else ""


func interact(player: Node) -> void:
	if porte:
		porte.interact(player)
