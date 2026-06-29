// Chamas finas lambendo a BORDA da carta (pista de raridade no booster).
// Mede a distância à borda por um SDF de retângulo arredondado e desenha línguas
// de fogo só num anel fino para fora — nada de bloco retangular.
//   mode      → 0 azul (rara/foil), 1 misturado (lendária), 2 prismático (mística/lend.-foil)
//   intensity → força geral
//   overlay_px/card_px → tamanhos em pixels (a cena passa) p/ trabalhar isotrópico
shader_type canvas_item;
render_mode blend_add;

uniform int mode = 0;
uniform float intensity = 1.0;
uniform float speed = 1.0;
uniform vec2 overlay_px = vec2(340.0, 478.0);
uniform vec2 card_px = vec2(220.0, 330.0);
uniform float reach_px = 50.0;
uniform float corner_px = 16.0;

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

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

vec3 fire_palette(int m, float heat, vec2 uv, float t) {
	if (m == 0) {
		// azul: base -> ciano -> branco quente na base da chama
		vec3 c1 = vec3(0.02, 0.10, 0.45);
		vec3 c2 = vec3(0.10, 0.55, 1.00);
		vec3 c3 = vec3(0.80, 0.97, 1.00);
		return mix(mix(c1, c2, smoothstep(0.0, 0.55, heat)), c3, smoothstep(0.6, 1.0, heat));
	} else if (m == 1) {
		// misturado (lendária): vermelho -> laranja -> ouro
		vec3 c1 = vec3(0.55, 0.02, 0.02);
		vec3 c2 = vec3(1.00, 0.40, 0.02);
		vec3 c3 = vec3(1.00, 0.92, 0.55);
		return mix(mix(c1, c2, smoothstep(0.0, 0.55, heat)), c3, smoothstep(0.6, 1.0, heat));
	}
	// prismático (mística / lendária-foil): arco-íris com pontas claras
	float hue = fract(uv.x * 0.7 + uv.y * 0.35 + t * 0.18 + heat * 0.3);
	vec3 rb = hsv2rgb(vec3(hue, 0.85, 1.0));
	return mix(rb, vec3(1.0), smoothstep(0.75, 1.0, heat));
}

void fragment() {
	float t = TIME * speed;
	vec2 P = (UV - vec2(0.5)) * overlay_px;             // espaço em pixels (isotrópico)
	float d = sd_round_box(P, card_px * 0.5, corner_px); // <0 dentro, 0 borda, >0 fora

	// ruído de chamas: warp + fluxo p/ cima, octaves rotacionadas
	vec2 np = P / 58.0;
	np.y += t * 1.6;
	float w = fbm(np * 1.2 + vec2(3.1, t * 0.7));
	float n = fbm(np + vec2(w * 0.6, w * 0.6 - t * 0.4));

	// língua de fogo: o alcance varia com o ruído -> pontas irregulares
	float reach = reach_px * smoothstep(0.15, 0.95, n);
	float flame = 1.0 - smoothstep(0.0, reach + 2.0, d);  // 1 na borda, some na ponta
	flame *= smoothstep(-10.0, 1.0, d);                   // só borda/fora (não no miolo)
	flame = clamp(flame, 0.0, 1.0);

	float heat = clamp(flame * (0.7 + 0.5 * n), 0.0, 1.0);
	vec3 col = fire_palette(mode, heat, UV, t);

	float a = flame * (0.55 + 0.45 * n) * intensity;
	COLOR = vec4(col, a);
}
