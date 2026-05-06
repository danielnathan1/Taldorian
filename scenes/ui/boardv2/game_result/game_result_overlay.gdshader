shader_type canvas_item;
// Overlay background for game result screen.
// Dim + colored radial glow behind the result card.
// Pass is_victory = true for gold glow, false for crimson.

uniform bool  is_victory   = true;
uniform float glow_strength = 0.08;

void fragment() {
	vec2  uv  = UV;
	vec2  d   = uv - vec2(0.5, 0.5);
	float dist = length(d * vec2(1.0, 0.9));

	// Base dim
	float alpha = 0.94;
	vec3  base  = vec3(0.025, 0.028, 0.055);

	// Radial accent glow
	vec3  glow_col = is_victory
		? vec3(0.72, 0.60, 0.26)   // gold
		: vec3(0.55, 0.10, 0.10);  // crimson
	float glow = (1.0 - smoothstep(0.0, 0.70, dist)) * glow_strength;

	vec3 col = base + glow_col * glow;
	COLOR = vec4(col, alpha);
}
