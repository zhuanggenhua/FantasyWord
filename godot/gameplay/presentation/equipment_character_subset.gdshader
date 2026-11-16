shader_type canvas_item;
render_mode unshaded;
// 原 EquipmentUV 的本体合成阶段；不替代后续肤色、武器、阴影、描边。
// UV 必须是整张角色图的左上原点坐标；数据贴图禁止颜色空间转换。
uniform sampler2D main_map : filter_nearest, repeat_disable;
uniform sampler2D body_map : filter_nearest, repeat_disable;
uniform sampler2D head_map : filter_nearest, repeat_disable;
uniform bool body_in_front = false;
uniform bool enabled_gloves = false;
uniform bool enabled_shoes = false;
uniform bool enabled_left_eye = false;
uniform bool enabled_right_eye = false;
uniform vec4 left_hand_color;
uniform vec4 right_hand_color;
uniform vec4 left_foot_color;
uniform vec4 right_foot_color;
uniform vec4 left_eye_color;
uniform vec4 right_eye_color;
uniform bool enabled_bag = false;
uniform sampler2D bag_map : filter_nearest, repeat_disable;
uniform vec4 bag_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool enabled_pants = false;
uniform sampler2D pants_map : filter_nearest, repeat_disable;
uniform vec4 pants_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool enabled_cloth = false;
uniform sampler2D cloth_map : filter_nearest, repeat_disable;
uniform vec4 cloth_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool enabled_cloak = false;
uniform sampler2D cloak_map : filter_nearest, repeat_disable;
uniform vec4 cloak_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool enabled_helmet = false;
uniform sampler2D helmet_map : filter_nearest, repeat_disable;
uniform vec4 helmet_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool enabled_beard = false;
uniform sampler2D beard_map : filter_nearest, repeat_disable;
uniform vec4 beard_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool enabled_face_accessory = false;
uniform sampler2D face_accessory_map : filter_nearest, repeat_disable;
uniform vec4 face_accessory_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool enabled_hair = false;
uniform sampler2D hair_map : filter_nearest, repeat_disable;
uniform vec4 hair_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool enabled_eye_decoration = false;
uniform sampler2D eye_decoration_map : filter_nearest, repeat_disable;
uniform vec4 eye_decoration_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool enabled_mask = false;
uniform sampler2D mask_map : filter_nearest, repeat_disable;
uniform vec4 mask_rect = vec4(0.0, 0.0, 1.0, 1.0);

bool part(float value, float target) { return abs(value - target) < 0.025; }
// 装备编码 RG 以左下为原点，先映射作者 rect，再转换一次到 Godot 左上坐标。
vec2 equip_uv(vec2 encoded, vec4 rect) {
 vec2 bottom = mix(rect.xy, rect.zw, encoded);
 return vec2(bottom.x, 1.0-bottom.y);
}
bool write_bag(vec2 uv, inout vec4 value, inout float coverage) {
 if (!enabled_bag) { return false; }
 vec4 pixel = texture(bag_map, equip_uv(uv, bag_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; return true;
}
bool write_pants(vec2 uv, inout vec4 value, inout float coverage) {
 if (!enabled_pants) { return false; }
 vec4 pixel = texture(pants_map, equip_uv(uv, pants_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; return true;
}
bool write_cloth(vec2 uv, inout vec4 value, inout float coverage) {
 if (!enabled_cloth) { return false; }
 vec4 pixel = texture(cloth_map, equip_uv(uv, cloth_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; return true;
}
bool write_cloak(vec2 uv, inout vec4 value, inout float coverage) {
 if (!enabled_cloak) { return false; }
 vec4 pixel = texture(cloak_map, equip_uv(uv, cloak_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; return true;
}
bool write_helmet(vec2 uv, inout vec4 value, inout float coverage) {
 if (!enabled_helmet) { return false; }
 vec4 pixel = texture(helmet_map, equip_uv(uv, helmet_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; return true;
}
bool write_beard(vec2 uv, inout vec4 value, inout float coverage) {
 if (!enabled_beard) { return false; }
 vec4 pixel = texture(beard_map, equip_uv(uv, beard_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; return true;
}
bool write_face_accessory(vec2 uv, inout vec4 value, inout float coverage) {
 if (!enabled_face_accessory) { return false; }
 vec4 pixel = texture(face_accessory_map, equip_uv(uv, face_accessory_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; return true;
}
bool write_hair(vec2 uv, inout vec4 value, inout float coverage) {
 if (!enabled_hair) { return false; }
 vec4 pixel = texture(hair_map, equip_uv(uv, hair_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; return true;
}
bool write_eye_decoration(vec2 uv, inout vec4 value, inout float coverage) {
 if (!enabled_eye_decoration) { return false; }
 vec4 pixel = texture(eye_decoration_map, equip_uv(uv, eye_decoration_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; return true;
}
bool write_mask(vec2 uv, inout vec4 value, inout float coverage) {
 if (!enabled_mask) { return false; }
 vec4 pixel = texture(mask_map, equip_uv(uv, mask_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; return true;
}

void apply_head(vec4 body, vec4 head, inout vec4 value, inout float coverage) {
 if (!part(head.b,0.1) || part(body.b,0.4) || part(body.b,0.5)) { return; }
 if (write_helmet(head.rg,value,coverage)) { return; }
 bool wrote = write_beard(head.rg,value,coverage);
 if (!wrote) { wrote = write_face_accessory(head.rg,value,coverage); }
 if (!wrote) { wrote = write_hair(head.rg,value,coverage); }
 wrote = write_eye_decoration(head.rg,value,coverage);
 wrote = write_mask(head.rg,value,coverage);
}
void apply_body(vec4 body, vec4 head, float base_alpha, inout vec4 value, inout float coverage) {
 bool left_hand = part(body.b,0.4);
 bool right_hand = part(body.b,0.5);
 bool left_foot = part(body.b,0.6);
 bool right_foot = part(body.b,0.7);
 bool hand = left_hand || right_hand;
 bool foot = left_foot || right_foot;
 bool torso = part(body.b,0.2) || (body_in_front && (hand || foot));
 if (torso) {
  if (!body_in_front && part(head.b,0.1) && head.a > 0.5) { return; }
  bool wrote = false;
  if (!body_in_front && base_alpha <= 0.5) { wrote = write_bag(body.rg,value,coverage); }
  wrote = write_pants(body.rg,value,coverage);
  wrote = write_cloth(body.rg,value,coverage);
  wrote = write_cloak(body.rg,value,coverage);
 } else if (hand && enabled_gloves) {
  value.rgb = left_hand ? left_hand_color.rgb : right_hand_color.rgb; coverage = 1.0;
 } else if (foot && enabled_shoes) {
  value.rgb = left_foot ? left_foot_color.rgb : right_foot_color.rgb; coverage = 1.0;
 } else if (part(body.b,0.3) && enabled_left_eye) {
  value.rgb = left_eye_color.rgb; coverage = 1.0;
 } else if (part(body.b,0.35) && enabled_right_eye) {
  value.rgb = right_eye_color.rgb; coverage = 1.0;
 }
}
void fragment() {
 vec4 base = texture(main_map,UV);
 vec4 body = texture(body_map,UV);
 vec4 head = texture(head_map,UV);
 vec4 value = base;
 float body_coverage = 0.0;
 float head_coverage = 0.0;
 if (body_in_front) {
  apply_head(body,head,value,head_coverage);
  apply_body(body,head,base.a,value,body_coverage);
 } else {
  apply_body(body,head,base.a,value,body_coverage);
  apply_head(body,head,value,head_coverage);
 }
 // 输出原本体合成阶段 charAlpha；后续完整着色流程尚未接入。
 value.a = max(value.a,max(body_coverage,head_coverage));
 COLOR = value;
}
