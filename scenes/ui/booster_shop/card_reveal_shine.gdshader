// Brilho de revelação: uma banda diagonal de luz varre a carta no momento em que
// ela vira, na cor da raridade, com a moldura acendendo junto. Aditivo, some sozinho.
//   progress   → posição da banda (-0.25 a 1.25), tweened pela cena
//   shine_color→ cor da raridade da carta
//   intensity  → força do efeito (raras > comuns; foil soma)
shader_type canvas_item;
render_mode blend_add;

uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float progress = -0.25;
uniform float band_width = 0.22;
uniform float intensity = 1.0;

void fragment() {
	// diagonal: canto superior-esquerdo -> inferior-direito
	float d = (UV.x + UV.y) * 0.5;
	float band = smoothstep(band_width, 0.0, abs(d - progress));
	band = pow(band, 1.5);

	// moldura acendendo (borda da carta)
	vec2 e = min(UV, vec2(1.0) - UV);
	float edge = smoothstep(0.05, 0.0, min(e.x, e.y));

	float a = (band * 1.0 + edge * 0.6) * intensity;
	COLOR = vec4(shine_color.rgb, a);
}
