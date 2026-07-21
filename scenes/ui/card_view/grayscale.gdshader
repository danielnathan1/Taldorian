// Dessaturação para cartas — usado no fichário do Catálogo (cartas que o jogador
// nunca teve aparecem em preto-e-branco). Cosmético puro.
// COLOR já vem como (textura × modulate) no início do fragment; então só calculamos
// a luminância de COLOR.rgb e misturamos para o cinza — sem re-multiplicar a textura
// (o bug anterior fazia textura² e resultava num tom sépia em vez de P&B).
shader_type canvas_item;

uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, vec3(luma), amount);
}
