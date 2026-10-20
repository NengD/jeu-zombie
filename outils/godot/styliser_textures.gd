extends SceneTree
## Textures du monde en style low-poly (pour aller avec les personnages Quaternius) :
## à partir des photos Poly Haven (outils/sources_textures/<id>/), on garde les couleurs en grandes
## plages douces et seulement un soupçon du détail photo ; relief adouci.
## Retour aux photos : outils/godot/installer_textures.gd.
## Lancer : godot --headless --path . -s res://outils/godot/styliser_textures.gd   puis   --import

const Installer = preload("res://outils/godot/installer_textures.gd")
const DETAIL := 0.22        # part du détail photo conservée
const RELIEF := 0.3         # force du relief conservée
const TAILLE := 1024


func _initialize() -> void:
	var src := ProjectSettings.globalize_path("res://outils/sources_textures/")
	var dst := ProjectSettings.globalize_path("res://textures/")
	for nom in Installer.TEXTURES:
		var d: String = src + Installer.TEXTURES[nom] + "/"
		var photo := Image.load_from_file(d + "Diffuse.jpg")
		photo.resize(TAILLE, TAILLE, Image.INTERPOLATE_LANCZOS)
		# grandes plages de couleur : image réduite à quelques pixels puis agrandie en douceur
		var doux := photo.duplicate()
		doux.resize(12, 12, Image.INTERPOLATE_LANCZOS)
		doux.resize(TAILLE, TAILLE, Image.INTERPOLATE_CUBIC)
		var moyen := photo.duplicate()
		moyen.resize(48, 48, Image.INTERPOLATE_LANCZOS)
		moyen.resize(TAILLE, TAILLE, Image.INTERPOLATE_CUBIC)
		for y in TAILLE:
			for x in TAILLE:
				var c: Color = doux.get_pixel(x, y).lerp(moyen.get_pixel(x, y), 0.45)
				c = c.lerp(photo.get_pixel(x, y), DETAIL)
				# couleurs un peu plus franches, comme les personnages
				c = Color.from_hsv(c.h, minf(1.0, c.s * 1.15), c.v)
				if nom == "herbe":
					c = Color.from_hsv(lerpf(c.h, 0.27, 0.6), minf(1.0, c.s * 1.5), c.v * 1.05)   # prairie bien verte
				doux.set_pixel(x, y, c)
		doux.save_jpg(dst + nom + "_albedo.jpg", 0.9)
		var n := Image.load_from_file(d + "nor_gl.jpg")
		n.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		var plat := Color(0.5, 0.5, 1.0)
		for y in 512:
			for x in 512:
				n.set_pixel(x, y, plat.lerp(n.get_pixel(x, y), RELIEF))
		n.save_png(dst + nom + "_normal.png")
		print(nom, " stylisée")
	quit()
