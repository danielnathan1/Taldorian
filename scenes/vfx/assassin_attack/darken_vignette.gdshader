// scenes/vfx/assassin_attack/darken_vignette.gdshader
// Vinheta radial de escurecimento — espelha o overlay do protótipo (Hakai.html).
// O parametro `amount` (0→1) e animado por tween durante o efeito.
shader_type canvas_item;

uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 c = UV - vec2(0.5);
	float d = length(c * vec2(1.1, 1.4));      // elipse ~90%x70%
	float vig = smoothstep(0.30, 0.85, d);     // mais escuro nas bordas
	float a = mix(0.55, 0.92, vig) * amount;   // centro 0.55 → bordas 0.92
	COLOR = vec4(vec3(0.01, 0.012, 0.02), a);  // void azulado profundo
}
