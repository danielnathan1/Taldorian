// Borda brilhante pulsante — indica que uma carta/token pode ser ativada.
// Aplicado a um ColorRect cobrindo a carta inteira (full-rect): o brilho se
// concentra nas bordas e some no centro, pulsando com o tempo.
shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(1.0, 0.82, 0.28, 1.0);
uniform float speed : hint_range(0.5, 8.0) = 3.0;
uniform float thickness : hint_range(0.01, 0.5) = 0.12;
uniform float sharpness : hint_range(0.5, 4.0) = 1.6;

void fragment() {
	vec2 uv = UV;
	// distância até a borda mais próxima (0 na borda → 0.5 no centro)
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	// banda de brilho colada na borda, decaindo para dentro
	float band = 1.0 - smoothstep(0.0, thickness, edge);
	band = pow(band, sharpness);
	float pulse = 0.45 + 0.55 * sin(TIME * speed);
	COLOR = vec4(glow_color.rgb, glow_color.a * band * pulse);
}
