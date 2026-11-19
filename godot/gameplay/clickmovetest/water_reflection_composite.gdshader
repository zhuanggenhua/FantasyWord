// FantasyWord's locked WaterReflectionTilemap shader, in Godot's y-down world.
// The source tree uses Sprites-Default; retain its premultiplied capture
// RGB and original source-over alpha, with no unpremultiply in the compositor.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D water_mask : filter_nearest, repeat_disable;
uniform sampler2D capture_color : filter_nearest, repeat_disable;
uniform vec3 world_to_capture_u;
uniform vec3 world_to_capture_v;
uniform float unity_elapsed;
varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float mask_at(vec2 uv) {
	return texture(water_mask, uv).r;
}

void fragment() {
	// Godot SpriteFrames AtlasTexture exposes the underlying atlas UV to
	// both samples; the mask is authored for those same atlas coordinates.
	vec4 base = COLOR;
	vec2 mask_texel = 1.0 / vec2(textureSize(water_mask, 0));
	float mask = mask_at(UV);
	mask *= min(min(mask_at(UV + vec2(mask_texel.x, 0.0)),
	                mask_at(UV - vec2(mask_texel.x, 0.0))),
	            min(mask_at(UV + vec2(0.0, mask_texel.y)),
	                mask_at(UV - vec2(0.0, mask_texel.y))));

	vec3 point = vec3(world_pos, 1.0);
	vec2 uv = vec2(dot(world_to_capture_u, point), dot(world_to_capture_v, point));
	float wave = sin((-world_pos.y * 7.0 + unity_elapsed * 2.0) * 1.5707963);
	uv.x += floor(wave + 0.5) / float(textureSize(capture_color, 0).x);

	vec4 reflection = texture(capture_color, uv);
	base.rgb = mix(base.rgb, reflection.rgb * vec3(0.72, 0.86, 0.9),
	               clamp(reflection.a * mask * 0.55, 0.0, 1.0));
	COLOR = base;
}
