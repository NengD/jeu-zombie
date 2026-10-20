shader_type spatial;
// Taches de sang et de crasse sur un personnage (passe supplémentaire au-dessus de ses couleurs).
// Les taches sont fixées au corps (coordonnées du modèle) et plus nombreuses sur le haut du corps.
render_mode blend_mix, depth_draw_never, depth_test_default, cull_back, diffuse_burley;

instance uniform float sang = 0.0;     // 0..1
instance uniform float graine = 0.0;

varying vec3 p_modele;

float bruit(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n = dot(i, vec3(1.0, 57.0, 113.0));
	vec4 a = fract(sin(vec4(n, n + 1.0, n + 57.0, n + 58.0)) * 43758.5453);
	vec4 b = fract(sin(vec4(n + 113.0, n + 114.0, n + 170.0, n + 171.0)) * 43758.5453);
	vec4 c = mix(a, b, f.z);
	vec2 d = mix(c.xy, c.zw, f.y);
	return mix(d.x, d.y, f.x);
}

void vertex() {
	p_modele = VERTEX;
}

void fragment() {
	vec3 p = p_modele * 7.0 + vec3(graine);
	float n = bruit(p) * 0.6 + bruit(p * 2.3) * 0.3 + bruit(p * 5.1) * 0.1;
	float haut = smoothstep(0.6, 1.5, p_modele.y);          // torse, bras, visage
	float seuil = 1.0 - sang * (0.45 + 0.25 * haut);
	float tache = smoothstep(seuil, seuil + 0.04, n);
	ALBEDO = mix(vec3(0.20, 0.015, 0.01), vec3(0.32, 0.03, 0.02), bruit(p * 9.0));
	ROUGHNESS = 0.35;
	ALPHA = tache * 0.92;
}
