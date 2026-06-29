// Foil holográfico para cartas — overlay cromático aditivo.
// Aplicado num ColorRect que cobre o CardContent (ver card_view.gd).
// Cosmético puro: não altera regra nenhuma, só o brilho da carta foil.
shader_type canvas_item;
render_mode blend_add;

uniform float intensity     : hint_range(0.0, 1.5) = 0.28;
uniform float sparkle_amount: hint_range(0.0, 1.0) = 0.25;
uniform float band_count    : hint_range(1.0, 8.0) = 2.5;

// HSV hue → RGB (h em voltas, 0..1).
vec3 hue(float h) {
	h = fract(h);
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// Coordenada diagonal — o foil clássico corre na diagonal da carta.
	// Anima só pelo tempo (sem interação com o mouse).
	float diag  = (uv.x + uv.y) * 0.5;
	float sweep = diag + TIME * 0.084;

	// Faixa arco-íris + envelope de bandas suaves (a maior parte fica escura,
	// só as cristas acendem — por isso o blend_add não "lava" a carta inteira).
	vec3  rainbow = hue(sweep * 1.4);

	// Camada base iridescente sempre-ligada (lava a carta de leve com arco-íris).
	float wash    = 0.12;

	// Bandas brilhantes que correm na diagonal por cima da base.
	float band    = 0.5 + 0.5 * sin(sweep * 6.2831853 * band_count);
	band          = pow(band, 3.0);

	// Cintilância: grade de pontos que piscam com o tempo.
	vec2  gp      = floor(uv * 64.0);
	float spk     = hash(gp + floor(TIME * 3.5));
	spk           = step(1.0 - sparkle_amount * 0.12, spk);
	float sparkle = spk * (0.5 + 0.5 * sin(TIME * 25.0 + hash(gp) * 100.0));

	vec3 col = rainbow * (wash + band) * intensity + vec3(sparkle) * sparkle_amount;
	COLOR = vec4(col, 1.0);
}
