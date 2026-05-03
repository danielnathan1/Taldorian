shader_type canvas_item;

// Atmospheric background for Taldorian TCG Lobby — no runes, clean gradient.
// Assign to a full-screen ColorRect as a ShaderMaterial.

void fragment() {
	vec2 uv = UV;

	// ── Base gradient ─────────────────────────────────────────────────────────
	vec3 bg_top    = vec3(0.031, 0.043, 0.094); // deep navy
	vec3 bg_bottom = vec3(0.024, 0.020, 0.039); // dark crimson-purple
	vec3 col = mix(bg_top, bg_bottom, uv.y);

	// Radial glow from bottom-center (dramatic uplight — crimson)
	float bottom_glow = 1.0 - smoothstep(0.0, 1.4, length(uv - vec2(0.5, 1.3)));
	col += vec3(0.20, 0.04, 0.04) * bottom_glow * 0.28;

	// Radial glow from top-left (cool blue accent)
	float top_glow = 1.0 - smoothstep(0.0, 1.1, length(uv - vec2(0.0, 0.0)));
	col += vec3(0.04, 0.06, 0.22) * top_glow * 0.22;

	// Soft center glow
	float center_glow = 1.0 - smoothstep(0.0, 0.7, length(uv - vec2(0.5, 0.5)));
	col += vec3(0.05, 0.04, 0.14) * center_glow * 0.20;

	// ── Vignette ──────────────────────────────────────────────────────────────
	vec2 d = uv - vec2(0.5, 0.5);
	float vignette = smoothstep(0.45, 1.1, length(d * vec2(1.0, 0.75)));
	col *= 1.0 - vignette * 0.65;

	// ── Subtle noise grain ────────────────────────────────────────────────────
	float grain = fract(sin(dot(UV * 800.0 + TIME * 0.5, vec2(12.9898, 78.233))) * 43758.5453);
	col += (grain - 0.5) * 0.018;

	COLOR = vec4(col, 1.0);
}
