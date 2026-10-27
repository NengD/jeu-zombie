shader_type spatial;
// Sol de la campagne : mélange herbe / terre / roche selon les couleurs de sommet
// (rouge = roche des pentes, vert = terre et vase près de l'eau, bleu = herbe sèche des hauteurs).

uniform sampler2D herbe : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D herbe_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D terre : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D terre_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roche : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roche_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// neige tombée en hiver (0..1, meteo.gd) : couvre d'abord le plat, par taches, jamais l'eau
uniform float neige = 0.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// projection sur les trois axes pour la roche (pas d'étirement sur les pentes)
vec3 triplan(sampler2D t, vec3 p, vec3 n, float k) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(t, p.zy / k).rgb * w.x + texture(t, p.xz / k).rgb * w.y + texture(t, p.xy / k).rgb * w.z;
}

void fragment() {
	vec2 uv = wpos.xz;
	// grandes taches de couleur pour casser la répétition
	float tache = texture(herbe, uv / 61.0).g * 0.6 + texture(terre, uv / 137.0).r * 0.4;
	vec3 h = texture(herbe, uv / 3.0).rgb;
	h *= mix(vec3(0.82, 0.9, 0.75), vec3(1.12, 1.05, 0.88), tache);
	vec3 sec = h * vec3(1.15, 1.02, 0.72);
	h = mix(h, sec, COLOR.b);
	vec3 t = texture(terre, uv / 3.0).rgb * vec3(0.85, 0.82, 0.78);
	vec3 r = triplan(roche, wpos, wnorm, 4.0);
	float wr = smoothstep(0.15, 0.85, COLOR.r + (tache - 0.5) * 0.3);
	float wt = smoothstep(0.1, 0.9, COLOR.g);
	vec3 col = mix(mix(h, t, wt), r, wr);
	// rive mouillée, plus sombre
	col *= mix(1.0, 0.6, smoothstep(0.0, -0.6, wpos.y));
	float nv = 0.0;
	if (neige > 0.0) {
		nv = neige * smoothstep(0.55, 0.85, wnorm.y) * (1.0 - 0.6 * wr) * smoothstep(-0.3, 0.2, wpos.y);
		nv *= smoothstep(0.35, 0.7, tache + neige * 0.6);
		col = mix(col, vec3(0.86, 0.88, 0.93), nv);
	}
	ALBEDO = col;
	vec3 nh = texture(herbe_n, uv / 3.0).rgb;
	vec3 nt = texture(terre_n, uv / 3.0).rgb;
	vec3 nr = texture(roche_n, uv / 4.0).rgb;
	NORMAL_MAP = mix(mix(mix(nh, nt, wt), nr, wr), vec3(0.5, 0.5, 1.0), nv * 0.7);
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(mix(0.95, 0.55, smoothstep(-0.1, -0.5, wpos.y)), 0.75, nv);
}
