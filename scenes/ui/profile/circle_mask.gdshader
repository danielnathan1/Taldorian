// Máscara circular para a foto do avatar (recorta o TextureRect num círculo).
shader_type canvas_item;

void fragment() {
	vec2 c = UV - vec2(0.5);
	float d = length(c);
	COLOR = texture(TEXTURE, UV);
	// Suaviza a borda do círculo (anti-alias barato).
	COLOR.a *= smoothstep(0.5, 0.485, d);
}
