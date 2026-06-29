// Aura de tensão (estilo gacha) exibida atrás do pacote durante o build-up.
// A COR sugere o melhor item do pacote; o fake-out "evolui" a cor via uniforms.
//   aura_color  → cor base do tier (azul/roxo/dourado)
//   rainbow_mix → 0..1, varre a cor por ângulo (tier arco-íris: místico/foil alto)
//   intensity   → 0..1, controla o quanto a aura aparece (tweened pela cena)
shader_type canvas_item;
render_mode blend_add;

uniform vec4 aura_color : source_color = vec4(0.30, 0.55, 1.00, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float rainbow_mix : hint_range(0.0, 1.0) = 0.0;
uniform float ray_count = 14.0;
uniform float swirl_speed = 1.0;

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv) * 2.0;          // 0 no centro -> 1 na borda
	float angle = atan(uv.y, uv.x);
	float t = TIME * swirl_speed;

	// brilho radial suave
	float radial = smoothstep(1.0, 0.0, dist);
	radial = pow(radial, 1.5);

	// raios de luz girando
	float rays = 0.5 + 0.5 * sin(angle * ray_count + t * 2.0);
	rays = pow(rays, 3.0);

	// núcleo brilhante
	float core = smoothstep(0.60, 0.0, dist);

	// pulso
	float pulse = 0.80 + 0.20 * sin(t * 5.0);

	float glow = (radial * (1.05 + 1.35 * rays) + core * 2.6) * pulse * intensity;
	glow = min(glow, 3.5);   // headroom pro blend aditivo estourar mais

	// cor base do tier, opcionalmente varrida em arco-íris pelo ângulo
	vec3 rb = hsv2rgb(vec3(fract(angle / 6.28318 + t * 0.15), 0.75, 1.0));
	vec3 col = mix(aura_color.rgb, rb, rainbow_mix);

	COLOR = vec4(col, glow);
}
