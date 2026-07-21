// Fumaça preta emanando da BORDA da carta (Selo da Ruína — Lilith).
// Mede a distância à borda por um SDF de retângulo arredondado e desenha "línguas" de
// fumaça só num anel para FORA da carta, com alcance maior PARA CIMA (a fumaça sobe).
// Renderizada atrás do conteúdo do card → o miolo fica coberto pela arte, só os wisps
// ao redor/acima aparecem, como fumaça saindo do card.
//   overlay_px/card_px → tamanhos em pixels (a cena passa) p/ trabalhar isotrópico
//   reach_px           → alcance máx. da fumaça a partir da borda (a cena escala ao card)
shader_type canvas_item;
render_mode blend_mix;

uniform float intensity = 0.9;
uniform float speed = 1.0;
uniform vec2 overlay_px = vec2(360.0, 520.0);
uniform vec2 card_px = vec2(320.0, 480.0);
uniform float reach_px = 44.0;
uniform float corner_px = 16.0;
uniform vec4 smoke_color : source_color = vec4(0.05, 0.03, 0.09, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Octaves rotacionadas: remove o alinhamento aos eixos (sem cara de quadriculado).
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = rot * p * 2.0;
		a *= 0.5;
	}
	return v;
}

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	float t = TIME * speed;
	vec2 P = (UV - vec2(0.5)) * overlay_px;              // espaço em pixels (isotrópico)
	float d = sd_round_box(P, card_px * 0.5, corner_px); // <0 dentro, 0 borda, >0 fora

	// ruído de fumaça: warp + fluxo p/ CIMA, octaves rotacionadas
	vec2 np = P / 68.0;
	float w = fbm(np * 1.25 + vec2(2.3, -t * 0.45));
	np.y += t * 0.8;                                      // sobe
	float n = fbm(np + vec2(w * 0.6, w * 0.6));

	// alcance maior para cima (P.y < 0 = acima do centro) → pluma que sobe
	float upbias = mix(0.35, 1.0, clamp(-P.y / (card_px.y * 0.5 + 1.0), 0.0, 1.0));
	float reach = reach_px * upbias * smoothstep(0.12, 0.92, n);

	// língua de fumaça: 1 na borda, some na ponta; só borda/fora (não no miolo do card)
	float smoke = 1.0 - smoothstep(0.0, reach + 2.0, d);
	smoke *= smoothstep(-8.0, 2.0, d);
	smoke = clamp(smoke, 0.0, 1.0);

	float a = smoke * (0.45 + 0.55 * n) * intensity;
	COLOR = vec4(smoke_color.rgb, a);
}
