shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float alpha: hint_range(0.0, 1.0);

void fragment() {
	vec4 screen_sample = texture(screen_texture, SCREEN_UV);
	
	COLOR.rgb += screen_sample.rgb;
	COLOR.a = alpha;
}