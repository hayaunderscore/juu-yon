shader_type canvas_item;

uniform vec4 mix_color : source_color = vec4(1.0);

vec3 rgb_to_hsv(vec3 rgb) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(rgb.bg, K.wz), vec4(rgb.gb, K.xy), step(rgb.b, rgb.g));
	vec4 q = mix(vec4(p.xyw, rgb.r), vec4(rgb.r, p.yzx), step(p.x, rgb.r));
	
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 hsv) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(hsv.xxx + K.xyz) * 6.0 - K.www);
	return hsv.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), hsv.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 hsv = rgb_to_hsv(c.rgb);
	hsv = hsv * rgb_to_hsv(mix_color.rgb);
	COLOR.rgb = hsv_to_rgb(hsv);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
