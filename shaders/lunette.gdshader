shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Oculaire de la lunette : affiche l'image grossie (caméra de la lunette),
// avec un réticule fin, un léger vignettage et un bord noir.

uniform sampler2D vue : source_color, filter_linear;
uniform float actif = 1.0;

void fragment() {
	vec2 c = UV - 0.5;
	float d = length(c) * 2.0;
	vec3 col = vec3(0.0);
	if (actif > 0.5) {
		// petite aberration au bord
		col = texture(vue, UV).rgb;
		col *= smoothstep(1.0, 0.78, d);
		// réticule : fines lignes au centre, épaisses vers l'extérieur
		float fin = 0.0025;
		float epais = 0.012;
		float lx = abs(c.x);
		float ly = abs(c.y);
		bool ligne_h = ly < (abs(c.x) > 0.2 ? epais : fin);
		bool ligne_v = lx < (abs(c.y) > 0.2 ? epais : fin);
		if ((ligne_h || ligne_v) && d < 0.97) {
			col = vec3(0.02);
		}
		if (d < 0.012) {
			col = vec3(0.9, 0.08, 0.05);
		}
	} else {
		col = vec3(0.04, 0.06, 0.08) + vec3(0.1) * (1.0 - d);
	}
	if (d > 1.0) {
		discard;
	}
	// bord de l'oculaire : anneau sombre
	col *= smoothstep(1.0, 0.93, d) * 0.85 + 0.15 * step(d, 0.93);
	ALBEDO = col;
}
