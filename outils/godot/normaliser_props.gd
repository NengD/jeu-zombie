extends SceneTree
## Convertit les modèles de décor téléchargés (Poly Haven, The Base Mesh, Quaternius — CC0)
## en scènes légères pour le jeu : res://modeles/props/<id>.scn
##  - origine au centre de la base, face avant vers +Z, taille réelle (ou hauteur imposée)
##  - maillages simplifiés (niveaux de détail générés par Godot) et textures réduites
##  - matériaux « triplanaires » pour les modèles fournis sans texture
## Lancer : godot --headless --path . -s res://outils/godot/normaliser_props.gd

const SRC := "res://modeles/sources/props/"
const OUT := "res://modeles/props/"

# id : [source, filtre de noms (inclure si contient), exclure si contient, hauteur visée (0 = réelle),
#       rotation (degrés), triangles max, matériau imposé ("" = garder), teinte, taille texture]
const CFG := {
	# --- meubles fouillables
	"placard_peint": ["painted_wooden_cabinet", "", "", 0.0, Vector3.ZERO, 6000, "", Color.WHITE, 512],
	"placard_peint2": ["painted_wooden_cabinet_02", "", "", 0.0, Vector3.ZERO, 6000, "", Color.WHITE, 512],
	"commode": ["vintage_wooden_drawer_01", "", "", 0.0, Vector3.ZERO, 5000, "", Color.WHITE, 512],
	"chevet": ["painted_wooden_nightstand", "", "", 0.0, Vector3.ZERO, 3000, "", Color.WHITE, 256],
	"armoire_bois": ["modern_wooden_cabinet", "", "", 0.0, Vector3.ZERO, 6000, "", Color.WHITE, 512],
	"meuble_tiroirs": ["drawer_cabinet", "", "", 0.0, Vector3.ZERO, 6000, "", Color.WHITE, 512],
	"etagere_metal": ["steel_frame_shelves_03", "", "", 0.0, Vector3.ZERO, 8000, "", Color.WHITE, 512],
	"etagere_bois": ["wooden_display_shelves_01", "", "", 0.0, Vector3.ZERO, 4000, "", Color.WHITE, 512],
	"etagere_murale": ["shelf_01", "", "", 0.0, Vector3.ZERO, 2000, "", Color.WHITE, 512],
	"console": ["classicconsole_01", "", "", 0.0, Vector3.ZERO, 5000, "", Color.WHITE, 512],
	"table_bois": ["wooden_table_02", "", "", 0.0, Vector3.ZERO, 2000, "", Color.WHITE, 512],
	"bureau_ecole": ["schooldesk_01", "", "", 0.0, Vector3.ZERO, 4000, "", Color.WHITE, 512],
	"canape": ["sofa_01", "", "", 0.0, Vector3.ZERO, 5000, "", Color.WHITE, 512],
	"casier": ["locker", "", "", 1.9, Vector3.ZERO, 6000, "metal_peint", Color(0.42, 0.48, 0.55), 0],
	"casier_mil": ["locker", "", "", 1.9, Vector3.ZERO, 6000, "metal_peint", Color(0.36, 0.40, 0.26), 0],
	"classeur": ["filing_cabinet", "", "", 1.35, Vector3.ZERO, 2000, "metal_peint", Color(0.55, 0.56, 0.55), 0],
	"bureau": ["office_desk", "", "", 0.76, Vector3.ZERO, 2000, "parquet", Color(0.75, 0.6, 0.45), 0],
	"caisse_bois": ["wooden_crate_01", "", "", 0.0, Vector3.ZERO, 2000, "planches", Color(0.8, 0.66, 0.48), 0],
	"caisse_mil": ["military_crate_01", "", "", 0.0, Vector3.ZERO, 3000, "metal_peint", Color(0.33, 0.38, 0.22), 0],
	# --- rue
	"lampadaire": ["street_lamp_01", "", "", 4.6, Vector3.ZERO, 5000, "", Color.WHITE, 512],
	"borne_incendie": ["fire_hydrant", "aged", "", 0.0, Vector3.ZERO, 5000, "", Color.WHITE, 512],
	"poubelle": ["metal_trash_can", "rust", "", 0.0, Vector3.ZERO, 4000, "", Color.WHITE, 512],
	"poubelle_rue": ["outdoor_bin", "", "", 0.95, Vector3.ZERO, 2000, "metal_peint", Color(0.18, 0.28, 0.2), 0],
	"barriere_beton": ["concrete_road_barrier", "", "", 0.0, Vector3.ZERO, 3000, "", Color.WHITE, 512],
	"glissiere": ["jersey_barrier", "", "", 0.81, Vector3.ZERO, 500, "beton", Color(0.85, 0.85, 0.82), 0],
	"cone": ["traffic_cone_01", "", "", 0.7, Vector3.ZERO, 1000, "uni", Color(0.95, 0.35, 0.05), 0],
	"pneu": ["old_tyre", "", "", 0.0, Vector3.ZERO, 3000, "", Color.WHITE, 256],
	"baril_rouge": ["barrel_01", "", "", 0.0, Vector3.ZERO, 3000, "", Color.WHITE, 512],
	"baril_bleu": ["barrel_03", "", "", 0.0, Vector3.ZERO, 3000, "", Color.WHITE, 512],
	"armoire_electrique": ["utility_box_01", "", "", 0.0, Vector3.ZERO, 4000, "", Color.WHITE, 512],
	"clim": ["exterior_aircon_unit", "rusted", "", 0.0, Vector3.ZERO, 3000, "", Color.WHITE, 512],
	"plaque_egout": ["water_manhole_cover", "", "", 0.0, Vector3.ZERO, 2000, "", Color.WHITE, 512],
	"rideau_fer": ["rollershutter_door", "graffiti", "", 0.0, Vector3.ZERO, 2000, "", Color.WHITE, 512],
	"banc": ["park_bench", "", "", 0.85, Vector3.ZERO, 2000, "planches", Color(0.75, 0.55, 0.38), 0],
	"palette": ["pallet", "", "", 0.144, Vector3.ZERO, 500, "planches", Color(0.95, 0.85, 0.7), 0],
	"carton": ["cardboard_box_01", "", "", 0.45, Vector3.ZERO, 500, "uni", Color(0.62, 0.47, 0.32), 0],
	# --- nature
	"rocher": ["boulder_01", "", "", 0.0, Vector3.ZERO, 3000, "", Color.WHITE, 512],
	"souche": ["tree_stump_01", "", "", 0.0, Vector3.ZERO, 2000, "", Color.WHITE, 512],
	"tronc_mort": ["dead_tree_trunk", "", "", 0.0, Vector3.ZERO, 4000, "", Color.WHITE, 512],
	"buisson": ["shrub_02", "shrub_02_a", "", 0.0, Vector3.ZERO, 6000, "", Color.WHITE, 512],
	"buisson2": ["shrub_02", "shrub_02_c", "", 0.0, Vector3.ZERO, 6000, "", Color.WHITE, 512],
	# --- voitures (Quaternius)
	"voiture1": ["normal_car1", "", "", 0.0, Vector3.ZERO, 6000, "", Color.WHITE, 0],
	"voiture2": ["normal_car2", "", "", 0.0, Vector3.ZERO, 6000, "", Color.WHITE, 0],
	"voiture_suv": ["suv", "", "", 0.0, Vector3.ZERO, 6000, "", Color.WHITE, 0],
	"voiture_taxi": ["taxi", "", "", 0.0, Vector3.ZERO, 6000, "", Color.WHITE, 0],
	"voiture_sport": ["sports_car", "", "", 0.0, Vector3.ZERO, 6000, "", Color.WHITE, 0],
	"voiture_police": ["cop", "", "", 0.0, Vector3.ZERO, 6000, "", Color.WHITE, 0],
	# --- camps de bandits (Poly Haven, sources gltf dans outils/sources_props)
	"brasero": ["barrel_stove", "", "", 0.0, Vector3.ZERO, 3000, "", Color.WHITE, 512],
	"caisse_munitions": ["ammo_box", "", "", 0.0, Vector3.ZERO, 2000, "", Color.WHITE, 512],
	"jerrican": ["metal_jerrycan", "", "", 0.0, Vector3.ZERO, 2000, "", Color.WHITE, 512],
	"lanterne": ["Lantern_01", "", "", 0.0, Vector3.ZERO, 2000, "", Color.WHITE, 256],
	# --- véhicules des lieux (Poly Pizza : Quaternius CC0, Vojtěch Balák / Zsky / Poly by Google CC BY ; glb dans outils/sources_props)
	"train_loco": ["train_loco", "", "", 4.3, Vector3.ZERO, 8000, "", Color.WHITE, 0],
	"train_wagon": ["train_wagon", "", "", 4.0, Vector3.ZERO, 6000, "", Color.WHITE, 0],
	"train_conteneur": ["train_conteneur", "", "", 4.0, Vector3.ZERO, 6000, "", Color.WHITE, 0],
	"train_charbon": ["train_charbon", "", "", 3.2, Vector3.ZERO, 6000, "", Color.WHITE, 0],
	"avion_leger": ["avion_leger", "", "", 4.0, Vector3.ZERO, 6000, "", Color.WHITE, 0],
	"helico": ["helico", "", "", 4.4, Vector3.ZERO, 6000, "", Color.WHITE, 0],
	"bulldozer": ["bulldozer", "", "", 3.3, Vector3.ZERO, 6000, "", Color.WHITE, 0],
	"tente_mil": ["tente_mil", "", "", 2.4, Vector3.ZERO, 3000, "", Color.WHITE, 0],
	"tour_garde": ["tour_garde", "", "", 7.5, Vector3.ZERO, 3000, "", Color.WHITE, 0],
	"bus_scolaire": ["bus_scolaire", "", "", 3.2, Vector3.ZERO, 6000, "", Color.WHITE, 0],
	"camion_mil": ["camion_mil", "", "", 3.4, Vector3.ZERO, 6000, "", Color.WHITE, 0],
	# --- intérieurs (Ultimate Home Interior / Furniture, Quaternius CC0)
	"lit_simple": ["lit_simple", "", "", 0.65, Vector3.ZERO, 3000, "", Color.WHITE, 0],
	"lit_double": ["lit_double", "", "", 0.7, Vector3.ZERO, 3000, "", Color.WHITE, 0],
	"baignoire": ["baignoire", "", "", 0.6, Vector3.ZERO, 3000, "", Color.WHITE, 0],
	"wc": ["wc", "", "", 0.8, Vector3.ZERO, 3000, "", Color.WHITE, 0],
	"lave_linge": ["lave_linge", "", "", 0.85, Vector3.ZERO, 3000, "", Color.WHITE, 0],
	"lavabo": ["lavabo", "", "", 0.9, Vector3.ZERO, 3000, "", Color.WHITE, 0],
	# --- véhicules en plus (Quaternius CC0 : pick-up, ambulance ; Poly by Google CC BY : camionnette, tracteur, moto)
	"voiture_pickup": ["pickup", "", "", 1.75, Vector3.ZERO, 5000, "", Color.WHITE, 0],
	"voiture_ambulance": ["ambulance", "", "", 2.5, Vector3.ZERO, 5000, "", Color.WHITE, 0],
	"voiture_camionnette": ["camionnette", "", "", 2.1, Vector3.ZERO, 5000, "", Color.WHITE, 0],
	"voiture_tracteur": ["tracteur", "", "", 2.8, Vector3.ZERO, 5000, "", Color.WHITE, 0],
	"voiture_moto": ["moto", "", "", 1.15, Vector3.ZERO, 5000, "", Color.WHITE, 0],
	# --- bateaux (« Ships », Quaternius CC0)
	"barque": ["barque", "", "", 0.75, Vector3.ZERO, 3000, "", Color.WHITE, 0],
	"canot": ["canot", "", "", 0.85, Vector3.ZERO, 3000, "", Color.WHITE, 0],
}
const TUILES := {"metal_peint": 1.0, "parquet": 2.0, "planches": 1.0, "beton": 3.0, "uni": 1.0}
const MATS_VOITURE := ["Black", "Grey", "Windows", "Headlights", "TailLights", "WhiteLights", "BlueLights"]

var tex_cache := {}
var infos := {}
var manque := false   # des textures viennent d'être écrites : relancer après import


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var seul := OS.get_environment("PROP")
	for id in CFG:
		if seul != "" and id != seul:
			continue
		_convertir(id, CFG[id])
	if manque:
		print("TEXTURES ECRITES : importer (godot --editor --quit) puis relancer cet outil")
	# tailles des modèles (pour placer meubles et décors)
	if FileAccess.file_exists(OUT + "tailles.json"):
		var ancien = JSON.parse_string(FileAccess.get_file_as_string(OUT + "tailles.json"))
		if ancien is Dictionary:
			for k in ancien:
				if not infos.has(k):
					infos[k] = ancien[k]
	var f := FileAccess.open(OUT + "tailles.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(infos, "\t"))
	quit()


func _convertir(id: String, c: Array) -> void:
	var chemin: String = SRC + c[0] + ".glb"
	if not ResourceLoader.exists(chemin):
		chemin = "res://outils/sources_props/%s.glb" % c[0]
	if not ResourceLoader.exists(chemin):
		chemin = "res://outils/sources_props/%s/%s_1k.gltf" % [c[0], c[0]]
	var src: Node3D = load(chemin).instantiate()
	root.add_child(src)
	var garder: String = c[1]
	var exclure: String = c[2]
	var morceaux := []
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if garder != "" and not nm.contains(garder):
			continue
		if exclure != "" and nm.contains(exclure):
			continue
		morceaux.append(mi)
	if morceaux.is_empty():
		push_error("aucun maillage pour " + id)
		return
	var rot := Basis.from_euler(Vector3(deg_to_rad(c[4].x), deg_to_rad(c[4].y), deg_to_rad(c[4].z)))
	# boîte englobante dans le repère final (avant mise à l'échelle)
	var ab := AABB()
	var premier := true
	for mi in morceaux:
		var xf: Transform3D = Transform3D(rot, Vector3.ZERO) * _rel(mi, src)
		var a: AABB = xf * mi.mesh.get_aabb()
		ab = a if premier else ab.merge(a)
		premier = false
	var k := 1.0
	if c[3] > 0.0:
		k = c[3] / ab.size.y
	var decal := Vector3(-ab.get_center().x, -ab.position.y, -ab.get_center().z)
	var racine := Node3D.new()
	racine.name = id
	var tris_tot := 0
	for mi in morceaux:
		tris_tot += mi.mesh.get_faces().size() / 3
	var ratio := minf(1.0, float(c[5]) / maxf(1.0, tris_tot))
	var n := 0
	for mi in morceaux:
		var m := MeshInstance3D.new()
		m.name = "m%d" % n
		n += 1
		m.mesh = _simplifier(mi, ratio, c)
		var xf: Transform3D = Transform3D(rot, Vector3.ZERO) * _rel(mi, src)
		m.transform = Transform3D(Basis().scaled(Vector3(k, k, k)), decal * k) * xf
		racine.add_child(m)
		m.owner = racine
	var taille := ab.size * k
	infos[id] = [snappedf(taille.x, 0.001), snappedf(taille.y, 0.001), snappedf(taille.z, 0.001)]
	var ps := PackedScene.new()
	ps.pack(racine)
	var err := ResourceSaver.save(ps, OUT + id + ".scn", ResourceSaver.FLAG_COMPRESS)
	print("%s : %s tris %d -> ~%d, taille %s (err %d)" % [id, c[0], tris_tot, int(tris_tot * ratio), taille, err])
	src.queue_free()


func _simplifier(mi: MeshInstance3D, ratio: float, c: Array) -> ArrayMesh:
	var src: Mesh = mi.mesh
	var im := ImporterMesh.new()
	for s in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(s)
		for ci in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arr[ci] = null
		var mat := _materiau(mi.get_active_material(s), c)
		if ratio < 0.95 and arr[Mesh.ARRAY_INDEX] != null:
			# niveau de détail réduit : on prend les indices d'un LOD généré
			var tmp := ImporterMesh.new()
			tmp.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
			tmp.generate_lods(25.0, 60.0, [])
			var cible := int(arr[Mesh.ARRAY_INDEX].size() * ratio)
			for l in tmp.get_surface_lod_count(0):
				var idx: PackedInt32Array = tmp.get_surface_lod_indices(0, l)
				arr[Mesh.ARRAY_INDEX] = idx
				if idx.size() <= cible:
					break
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, mat)
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


func _materiau(m: Material, c: Array) -> Material:
	var impose: String = c[6]
	if impose != "":
		var sm := StandardMaterial3D.new()
		sm.albedo_color = c[7]
		sm.roughness = 0.8
		if impose != "uni":
			sm.albedo_texture = load("res://textures/%s_albedo.jpg" % impose)
			sm.normal_enabled = true
			sm.normal_texture = load("res://textures/%s_normal.png" % impose)
			if ResourceLoader.exists("res://textures/%s_rough.jpg" % impose):
				sm.roughness_texture = load("res://textures/%s_rough.jpg" % impose)
				sm.roughness = 1.0
			sm.uv1_triplanar = true
			var t := 1.0 / float(TUILES.get(impose, 1.0))
			sm.uv1_scale = Vector3(t, t, t)
		if impose == "metal_peint":
			sm.metallic = 0.3
		return sm
	if m == null or not (m is BaseMaterial3D):
		return m
	var bm: BaseMaterial3D = m.duplicate()
	var taille: int = c[8]
	if String(c[0]) in ["normal_car1", "normal_car2", "suv", "taxi", "sports_car", "cop"]:
		# voitures : carrosserie métallisée usée, vitres sombres
		if bm.resource_name == "Windows":
			bm.albedo_color = Color(0.08, 0.1, 0.12)
			bm.metallic = 0.6
			bm.roughness = 0.08
		elif bm.resource_name in ["Black"]:
			bm.roughness = 0.9
		elif not bm.resource_name in MATS_VOITURE or bm.resource_name == "White":
			if c[0] != "cop":
				bm.resource_name = "Carrosserie"
			bm.albedo_texture = load("res://textures/metal_peint_albedo.jpg")
			bm.roughness_texture = load("res://textures/metal_peint_rough.jpg")
			bm.normal_enabled = true
			bm.normal_texture = load("res://textures/metal_peint_normal.png")
			bm.uv1_triplanar = true
			bm.uv1_scale = Vector3(0.7, 0.7, 0.7)
			bm.metallic = 0.45
			bm.roughness = 1.0
		return bm
	for prop in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "ao_texture", "emission_texture"]:
		var t = bm.get(prop)
		if t is Texture2D and taille > 0:
			var nom := "%s_%s_%s" % [c[0], bm.resource_name, prop.replace("_texture", "")]
			bm.set(prop, _reduire(t, taille, prop == "normal_texture", nom.validate_filename()))
	return bm


func _reduire(t: Texture2D, taille: int, normale: bool, nom: String) -> Texture2D:
	# 1er passage : la texture réduite est écrite dans modeles/props/tex/ ;
	# après import par l'éditeur, le 2e passage l'utilise (compression VRAM, mipmaps).
	var chemin := OUT + "tex/" + nom + (".png" if normale else ".jpg")
	if ResourceLoader.exists(chemin):
		return load(chemin)
	if tex_cache.has(chemin):
		return null
	var img := t.get_image()
	if img == null:
		return t
	if img.is_compressed():
		img.decompress()
	if img.get_width() > taille:
		img.resize(taille, taille, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(OUT + "tex")
	if normale:
		img.save_png(chemin)
	else:
		if img.detect_alpha() != Image.ALPHA_NONE:
			chemin = chemin.replace(".jpg", ".png")
			img.save_png(chemin)
		else:
			img.convert(Image.FORMAT_RGB8)
			img.save_jpg(chemin, 0.88)
	tex_cache[chemin] = true
	manque = true
	return null


## Transformation d'un nœud relative à la racine du modèle (sans passer par l'arbre de scène).
func _rel(n: Node3D, racine: Node) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p != null and p != racine:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
