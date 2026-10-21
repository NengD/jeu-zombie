shader_type spatial;
// Fleurs des champs : tige verte (UV.x = 0) et corolle colorée (UV.x = 1, couleur d'instance).
// Ondulent au vent comme l'herbe (mêmes rafales) et s'effacent au loin.
render_mode cull_disabled, diffuse_burley;

uniform vec3 couleur_tige : source_color = vec3(0.22, 0.33, 0.1);
uniform float force_vent = 0.18;
uniform float vitesse_vent = 1.6;
uniform vec2 direction_vent = vec2(1.0, 0.35);
uniform float distance_max = 70.0;

varying float partie;
varying vec3 teinte;

void vertex() {
	partie = UV.x;
	teinte = COLOR.rgb;
	vec3 monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 base = MODEL_MATRIX[3].xyz;
	float rafale = sin(dot(base.xz, direction_vent) * 0.08 - TIME * vitesse_vent) * 0.5 + 0.5;
	float tremble = sin(TIME * 3.3 + COLOR.a * 40.0 + base.z * 0.7) * 0.3;
	float k = UV.y * UV.y * force_vent * (0.4 + rafale + tremble);
	vec3 decal = vec3(direction_vent.x, 0.0, direction_vent.y) * k;
	float d = distance(base, INV_VIEW_MATRIX[3].xyz);
	float fond = 1.0 - smoothstep(distance_max * 0.6, distance_max * 0.9, d);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(monde + decal, 1.0)).xyz;
	VERTEX *= fond;
}

void fragment() {
	ALBEDO = mix(couleur_tige, teinte, step(0.5, partie));
	ROUGHNESS = 0.8;
	BACKLIGHT = vec3(0.2) * partie;
}
