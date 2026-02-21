shader_type canvas_item;

uniform vec4 color : source_color;
uniform float mixture : hint_range(0.0, 1.0);
uniform float lerp_to_add : hint_range(0.0, 1.0);
uniform float alpha = 1.0;

uniform vec2 offset;

void vertex()
{
	VERTEX += offset;
}

void fragment() 
{
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= alpha;
	COLOR.rgb += color.rgb * mixture * (lerp_to_add);
	COLOR.rgb = mix(COLOR.rgb, color.rgb, mixture * (1.0 - lerp_to_add));
}