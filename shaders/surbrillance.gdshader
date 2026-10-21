shader_type spatial;
// Liseré doré qui pulse sur les bords d'un objet (contenant à fouiller qui a encore quelque chose).
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 couleur : source_color = vec4(1.0, 0.78, 0.32, 1.0);
uniform float force = 0.8;

void fragment() {
	float bord = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float pulse = 0.7 + 0.3 * sin(TIME * 3.0);
	ALBEDO = couleur.rgb * (bord * 1.3 + 0.06) * force * pulse;
}
