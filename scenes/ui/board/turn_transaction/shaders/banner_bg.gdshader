shader_type canvas_item;
// Banner background stripe — fades horizontally at both edges.
uniform vec4 stripe_color : source_color = vec4(0.063, 0.082, 0.188, 0.92);

void fragment() {
	float fade = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	COLOR = vec4(stripe_color.rgb, stripe_color.a * fade);
}
