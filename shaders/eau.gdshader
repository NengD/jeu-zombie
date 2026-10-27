shader_type spatial;
render_mode cull_disabled, depth_draw_always, specular_schlick_ggx;
// Surface d'eau des lacs et de la rivière : vaguelettes animées, reflets, transparence.
// Lacs en hiver (meteo.gd) : « gel » 0..1 = glace mate et opaque, « neige » = neige posée dessus par taches.

uniform vec3 couleur_fond : source_color = vec3(0.1, 0.2, 0.2);
uniform vec3 couleur_surface : source_color = vec3(0.38, 0.5, 0.52);
uniform sampler2D vagues1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D vagues2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 courant = vec2(0.0, 0.0);
uniform float gel = 0.0;
uniform float neige = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz;
	// glace : normale vers le ciel (les maillages des lacs sont vus par leur face arrière)
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, gel));
	float t = TIME * (1.0 - gel);
	vec3 n1 = texture(vagues1, uv / 9.0 + vec2(t * 0.012, t * 0.008) + courant * t).rgb;
	vec3 n2 = texture(vagues2, uv / 5.0 - vec2(t * 0.01, -t * 0.014) + courant * t * 1.3).rgb;
	vec3 nm = normalize(n1 + n2 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP = mix(nm, vec3(0.5, 0.5, 1.0), gel * 0.8);
	NORMAL_MAP_DEPTH = 0.6;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 eau = mix(couleur_fond, couleur_surface, fres);
	// glace : bleu-gris laiteux, fissures et voile blanc tirés des textures de vagues
	float voile = n1.r * 0.6 + n2.g * 0.4;
	vec3 glace = mix(vec3(0.5, 0.62, 0.68), vec3(0.78, 0.85, 0.88), smoothstep(0.35, 0.75, voile));
	float nv = neige * 0.85 * smoothstep(0.35, 0.65, texture(vagues1, uv / 31.0).g + neige * 0.35);
	glace = mix(glace, vec3(0.86, 0.88, 0.93), nv);
	ALBEDO = mix(eau, glace, gel);
	ROUGHNESS = mix(0.06, mix(0.25, 0.75, nv), gel);
	METALLIC = 0.0;
	SPECULAR = 0.7;
	ALPHA = mix(mix(0.72, 0.95, fres), 1.0, gel);
}
