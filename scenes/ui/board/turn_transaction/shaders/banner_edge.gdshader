shader_type canvas_item;
// Edge vignette — fades the banner into the background on left or right side.
// Set flip = true for the right-side instance.
uniform bool flip = false;
uniform vec4 bg_color : source_color = vec4(0.027, 0.031, 0.059, 1.0);

void fragment() {
	float x = flip ? UV.x : 1.0 - UV.x;
	float fade = 1.0 - smoothstep(0.0, 1.0, x);
	COLOR = vec4(bg_color.rgb, fade * bg_color.a);
}
