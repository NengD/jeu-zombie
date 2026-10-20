extends SceneTree
## Installe les textures photo Poly Haven (CC0, 2k) téléchargées dans outils/sources_textures/<id>/
## (Diffuse.jpg, nor_gl.jpg, Rough.jpg) sous les noms du jeu : textures/<nom>_albedo.jpg,
## <nom>_normal.png, <nom>_rough.jpg. Les anciennes textures générées sont dans outils/textures_generees/.
## Lancer : godot --headless --path . -s res://outils/godot/installer_textures.gd   puis   --import

const TEXTURES := {
	"asphalte": "asphalt_02", "beton": "concrete_wall_008", "brique": "red_brick_03", "carrelage": "floor_tiles_06",
	"ecorce": "bark_brown_02", "enduit": "plastered_wall_04", "herbe": "leafy_grass", "metal_peint": "metal_plate",
	"parpaing": "concrete_block_wall", "parquet": "wood_floor_worn", "planches": "weathered_planks", "roche": "rock_face",
	"terre": "brown_mud_02", "toit": "roof_09", "tole": "corrugated_iron_02", "trottoir": "concrete_pavers",
	"tuiles": "clay_roof_tiles",
}


func _initialize() -> void:
	var src := ProjectSettings.globalize_path("res://outils/sources_textures/")
	var dst := ProjectSettings.globalize_path("res://textures/")
	for nom in TEXTURES:
		var d: String = src + TEXTURES[nom] + "/"
		var ok := DirAccess.copy_absolute(d + "Diffuse.jpg", dst + nom + "_albedo.jpg") == OK
		ok = ok and DirAccess.copy_absolute(d + "Rough.jpg", dst + nom + "_rough.jpg") == OK
		var img := Image.load_from_file(d + "nor_gl.jpg")
		ok = ok and img != null and img.save_png(dst + nom + "_normal.png") == OK
		print(nom, " <- ", TEXTURES[nom], " : ", "ok" if ok else "ERREUR")
	quit()
