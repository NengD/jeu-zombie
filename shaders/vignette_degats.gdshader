shader_type canvas_item;
// Bords de l'écran rougis : blessure (force) + éclair bref à chaque coup reçu (eclair, tout l'écran légèrement).
uniform float force : hint_range(0.0, 1.0) = 0.0;
uniform float eclair : hint_range(0.0, 1.0) = 0.0;
uniform vec4 couleur : source_color = vec4(0.55, 0.0, 0.0, 1.0);

void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 0.85);
	float bord = smoothstep(0.28, 0.72, length(d));
	float a = clamp(bord * force + eclair * (0.12 + 0.5 * bord), 0.0, 0.85);
	COLOR = vec4(couleur.rgb, a);
}
