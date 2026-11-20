shader_type canvas_item;
render_mode unshaded;

// RPGSystem 原材质没有轮廓、柔化、发光或阴影关键字；只移植面覆盖率。
uniform float screen_distance_scale;
uniform float face_weight;
varying vec4 glyph_tint;

void vertex() {
	glyph_tint = COLOR;
}

void fragment() {
	float distance_sample = texture(TEXTURE, UV).r;
	float coverage = clamp((distance_sample - (0.5 - face_weight)) * screen_distance_scale + 0.5, 0.0, 1.0);
	COLOR = vec4(glyph_tint.rgb, glyph_tint.a * coverage);
}
