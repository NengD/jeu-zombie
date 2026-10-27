shader_type spatial;
// Herbe haute : brins verts dégradés (pied sombre, pointe claire et sèche), qui ondulent au vent.
// La couleur d'instance module la teinte (rgb) et décale la phase du vent (a).
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 couleur_pied : source_color = vec3(0.10, 0.16, 0.05);
uniform vec3 couleur_milieu : source_color = vec3(0.30, 0.40, 0.14);
uniform vec3 couleur_pointe : source_color = vec3(0.62, 0.62, 0.32);
uniform float force_vent = 0.18;
uniform float vitesse_vent = 1.6;
uniform vec2 direction_vent = vec2(1.0, 0.35);
uniform float distance_max = 70.0;
// neige au sol (meteo.gd) : brins à demi enfouis, pied blanc
uniform float neige = 0.0;

varying float hauteur;
varying vec3 teinte;

void vertex() {
	hauteur = UV.y;
	teinte = COLOR.rgb;
	vec3 monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 base = MODEL_MATRIX[3].xyz;
	// rafales : grosses ondes qui traversent le champ + petit frémissement par touffe
	float rafale = sin(dot(base.xz, direction_vent) * 0.08 - TIME * vitesse_vent) * 0.5 + 0.5;
	float tremble = sin(TIME * 4.0 + COLOR.a * 40.0 + base.x * 0.7) * 0.25;
	float k = UV.y * UV.y * force_vent * (0.4 + rafale + tremble);
	vec3 decal = vec3(direction_vent.x, 0.0, direction_vent.y) * k;
	// s'efface en douceur au loin (évite la coupure nette au bord des parcelles)
	float d = distance(base, INV_VIEW_MATRIX[3].xyz);
	float fond = 1.0 - smoothstep(distance_max * 0.7, distance_max, d);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(monde + decal, 1.0)).xyz;
	VERTEX.y *= fond * (1.0 - 0.55 * neige);
	VERTEX.xz *= mix(0.2, 1.0, fond);
}

void fragment() {
	vec3 c = mix(couleur_pied, couleur_milieu, smoothstep(0.0, 0.5, hauteur));
	c = mix(c, couleur_pointe, smoothstep(0.55, 1.0, hauteur));
	ALBEDO = mix(c * teinte, vec3(0.86, 0.88, 0.93), neige * (1.0 - smoothstep(0.15, 0.75, hauteur)));
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	// lumière qui traverse les brins
	BACKLIGHT = vec3(0.25, 0.3, 0.1) * hauteur;
	AO = mix(0.35, 1.0, hauteur);
	AO_LIGHT_AFFECT = 0.6;
	NORMAL = mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.6);
}
