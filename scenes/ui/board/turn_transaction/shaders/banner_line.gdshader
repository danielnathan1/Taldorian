shader_type canvas_item;
// Thin accent border line — glows at center, fades at both edges.
uniform vec4 line_color : source_color = vec4(0.91, 0.76, 0.337, 1.0);

void fragment() {
	float fade = smoothstep(0.0, 0.30, UV.x) * smoothstep(1.0, 0.70, UV.x);
	COLOR = vec4(line_color.rgb, line_color.a * fade);
}
