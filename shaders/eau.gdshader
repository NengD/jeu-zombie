shader_type spatial;
render_mode cull_disabled, depth_draw_always, specular_schlick_ggx;
// Surface d'eau des lacs et de la rivière : vaguelettes animées, reflets, transparence.

uniform vec3 couleur_fond : source_color = vec3(0.1, 0.2, 0.2);
uniform vec3 couleur_surface : source_color = vec3(0.38, 0.5, 0.52);
uniform sampler2D vagues1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D vagues2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 courant = vec2(0.0, 0.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz;
	float t = TIME;
	vec3 n1 = texture(vagues1, uv / 9.0 + vec2(t * 0.012, t * 0.008) + courant * t).rgb;
	vec3 n2 = texture(vagues2, uv / 5.0 - vec2(t * 0.01, -t * 0.014) + courant * t * 1.3).rgb;
	NORMAL_MAP = normalize(n1 + n2 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	ALBEDO = mix(couleur_fond, couleur_surface, fres);
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	ALPHA = mix(0.72, 0.95, fres);
}
