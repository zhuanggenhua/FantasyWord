// 原 EquipmentUV 的本体合成及显式武器、轮廓、阴影子集及显式最终顶点乘色。
// UV 必须是整张角色图的左上原点坐标；数据贴图禁止颜色空间转换。
// 只在显式证明颜色域后启用。vertex COLOR 不含默认纹理，
// fragment 输入 COLOR 则已乘 TEXTURE，不能拿它再乘最终装备合成色。
uniform bool final_tint_enabled = false;
uniform vec4 final_material_tint = vec4(1.0);
varying vec4 final_vertex_color;
void vertex() {
 final_vertex_color = COLOR;
}

uniform sampler2D main_map : filter_nearest, repeat_disable;
uniform sampler2D body_map : filter_nearest, repeat_disable;
uniform sampler2D head_map : filter_nearest, repeat_disable;
uniform bool body_in_front = false;
// 仅非 HDR 兼容模式：可见颜色输入/输出为原始 sRGB，palette 向量已线性化。
// Body/Head 编码数据不参与颜色转换；缺少色域证明时必须保持禁用。
uniform bool skin_palette_enabled = false;
// 0 未证明；1 原始 sRGB。暂不接受其他色域。
uniform int skin_color_domain = 0;
uniform int skin_color_count = 0;
uniform vec4 skin_src_colors[16];
uniform vec4 skin_dst_colors[16];

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


#ifdef EQUIPMENT_WEAPON_STAGE
// 默认保持本体子集；显式启用才执行武器及最后的北向背包覆盖。
uniform bool weapon_fill_enabled = false;
uniform vec4 char_frame_rect = vec4(0.0,0.0,1.0,1.0);
uniform bool weapon0_enabled = false;
uniform sampler2D weapon0_map : filter_nearest, repeat_disable;
uniform vec4 weapon0_rect = vec4(0.0,0.0,1.0,1.0);
uniform vec4 weapon0_anchor_frame_uv = vec4(0.5);
uniform vec2 weapon0_rot_cos_sin = vec2(1.0,0.0);
uniform bool weapon0_flip_x = false;
uniform float weapon0_depth_mode = 0.0;
uniform float weapon0_hand_in_front = 0.0;
uniform bool weapon1_enabled = false;
uniform sampler2D weapon1_map : filter_nearest, repeat_disable;
uniform vec4 weapon1_rect = vec4(0.0,0.0,1.0,1.0);
uniform vec4 weapon1_anchor_frame_uv = vec4(0.5);
uniform vec2 weapon1_rot_cos_sin = vec2(1.0,0.0);
uniform bool weapon1_flip_x = false;
uniform float weapon1_depth_mode = 0.0;
uniform float weapon1_hand_in_front = 0.0;

#endif

bool part(float value, float target) { return abs(value - target) < 0.025; }
// 装备编码 RG 以左下为原点，先映射作者 rect，再转换一次到 Godot 左上坐标。
vec2 equip_uv(vec2 encoded, vec4 rect) {
 vec2 bottom = mix(rect.xy, rect.zw, encoded);
 return vec2(bottom.x, 1.0-bottom.y);
}
bool write_bag(vec2 uv, inout vec4 value, inout float coverage, inout int source_id) {
 if (!enabled_bag) { return false; }
 vec4 pixel = texture(bag_map, equip_uv(uv, bag_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; source_id = 10; return true;
}
bool write_pants(vec2 uv, inout vec4 value, inout float coverage, inout int source_id) {
 if (!enabled_pants) { return false; }
 vec4 pixel = texture(pants_map, equip_uv(uv, pants_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; source_id = 9; return true;
}
bool write_cloth(vec2 uv, inout vec4 value, inout float coverage, inout int source_id) {
 if (!enabled_cloth) { return false; }
 vec4 pixel = texture(cloth_map, equip_uv(uv, cloth_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; source_id = 9; return true;
}
bool write_cloak(vec2 uv, inout vec4 value, inout float coverage, inout int source_id) {
 if (!enabled_cloak) { return false; }
 vec4 pixel = texture(cloak_map, equip_uv(uv, cloak_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; source_id = 2; return true;
}
bool write_helmet(vec2 uv, inout vec4 value, inout float coverage, inout int source_id) {
 if (!enabled_helmet) { return false; }
 vec4 pixel = texture(helmet_map, equip_uv(uv, helmet_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; source_id = 3; return true;
}
bool write_beard(vec2 uv, inout vec4 value, inout float coverage, inout int source_id) {
 if (!enabled_beard) { return false; }
 vec4 pixel = texture(beard_map, equip_uv(uv, beard_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; source_id = 5; return true;
}
bool write_face_accessory(vec2 uv, inout vec4 value, inout float coverage, inout int source_id) {
 if (!enabled_face_accessory) { return false; }
 vec4 pixel = texture(face_accessory_map, equip_uv(uv, face_accessory_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; source_id = 4; return true;
}
bool write_hair(vec2 uv, inout vec4 value, inout float coverage, inout int source_id) {
 if (!enabled_hair) { return false; }
 vec4 pixel = texture(hair_map, equip_uv(uv, hair_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; source_id = 6; return true;
}
bool write_eye_decoration(vec2 uv, inout vec4 value, inout float coverage, inout int source_id) {
 if (!enabled_eye_decoration) { return false; }
 vec4 pixel = texture(eye_decoration_map, equip_uv(uv, eye_decoration_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; source_id = 4; return true;
}
bool write_mask(vec2 uv, inout vec4 value, inout float coverage, inout int source_id) {
 if (!enabled_mask) { return false; }
 vec4 pixel = texture(mask_map, equip_uv(uv, mask_rect));
 if (pixel.a <= 0.5) { return false; }
 value.rgb = pixel.rgb; coverage = 1.0; source_id = 11; return true;
}

void apply_head(vec4 body, vec4 head, inout vec4 value, inout float coverage, inout int source_id) {
 if (!part(head.b,0.1) || part(body.b,0.4) || part(body.b,0.5)) { return; }
 if (write_helmet(head.rg,value,coverage,source_id)) { return; }
 bool wrote = write_beard(head.rg,value,coverage,source_id);
 if (!wrote) { wrote = write_face_accessory(head.rg,value,coverage,source_id); }
 if (!wrote) { wrote = write_hair(head.rg,value,coverage,source_id); }
 wrote = write_eye_decoration(head.rg,value,coverage,source_id);
 wrote = write_mask(head.rg,value,coverage,source_id);
}
void apply_body(vec4 body, vec4 head, float base_alpha, inout vec4 value, inout float coverage, inout int source_id) {
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
  if (!body_in_front && base_alpha <= 0.5) { wrote = write_bag(body.rg,value,coverage,source_id); }
  wrote = write_pants(body.rg,value,coverage,source_id);
  wrote = write_cloth(body.rg,value,coverage,source_id);
  wrote = write_cloak(body.rg,value,coverage,source_id);
 } else if (hand && enabled_gloves) {
  value.rgb = left_hand ? left_hand_color.rgb : right_hand_color.rgb; coverage = 1.0; source_id = 9;
 } else if (foot && enabled_shoes) {
  value.rgb = left_foot ? left_foot_color.rgb : right_foot_color.rgb; coverage = 1.0; source_id = 9;
 } else if (part(body.b,0.3) && enabled_left_eye) {
  value.rgb = left_eye_color.rgb; coverage = 1.0; source_id = 9;
 } else if (part(body.b,0.35) && enabled_right_eye) {
  value.rgb = right_eye_color.rgb; coverage = 1.0; source_id = 9;
 }
}
vec3 skin_srgb_to_linear(vec3 value) {
 return mix(value / 12.92, pow((value + vec3(0.055)) / 1.055, vec3(2.4)), greaterThan(value, vec3(0.04045)));
}
vec3 skin_linear_to_srgb(vec3 value) {
 return mix(value * 12.92, 1.055 * pow(value, vec3(1.0 / 2.4)) - vec3(0.055), greaterThan(value, vec3(0.0031308)));
}
vec3 apply_skin_palette(vec3 raw_srgb, float base_alpha, int source_id) {
 if (!skin_palette_enabled || skin_color_domain != 1 || source_id != 1 || base_alpha <= 0.5) { return raw_srgb; }
 vec3 linear_color = skin_srgb_to_linear(raw_srgb);
 if (dot(linear_color, vec3(0.299,0.587,0.114)) <= 0.15) { return raw_srgb; }
 int count = clamp(skin_color_count,0,16);
 for (int i=0; i<16; i++) {
  if (i >= count) { break; }
  if (all(lessThan(abs(linear_color - skin_src_colors[i].rgb),vec3(1.0/255.0)))) {
   return skin_linear_to_srgb(skin_dst_colors[i].rgb);
  }
 }
 return raw_srgb;
}


#ifdef EQUIPMENT_WEAPON_STAGE
// 保留源底原点角色帧、先旋转再镜像以及严格 alpha 门槛。
bool sample_weapon(vec2 uv_top, sampler2D weapon_map, vec4 rect, vec4 anchor,
 vec2 rotation, bool flip_x, bool enabled, out vec4 value) {
 value = vec4(0.0);
 if (!enabled) { return false; }
 vec2 extent = char_frame_rect.zw - char_frame_rect.xy;
 if (extent.x <= 0.0001 || extent.y <= 0.0001) { return false; }
 vec2 frame_uv = (vec2(uv_top.x,1.0-uv_top.y) - char_frame_rect.xy) / extent;
 if (any(lessThan(frame_uv,vec2(0.0))) || any(greaterThan(frame_uv,vec2(1.0)))) { return false; }
 vec2 offset = frame_uv - anchor.xy;
 vec2 rotated = vec2(offset.x*rotation.x-offset.y*rotation.y,offset.x*rotation.y+offset.y*rotation.x);
 if (flip_x) { rotated.x = -rotated.x; }
 vec2 local_uv = anchor.zw + rotated;
 if (any(lessThan(local_uv,vec2(0.0))) || any(greaterThan(local_uv,vec2(1.0)))) { return false; }
 vec4 pixel = texture(weapon_map,equip_uv(local_uv,rect));
 if (pixel.a <= 0.5) { return false; }
 value = pixel;
 return true;
}
void apply_weapon_fill(vec2 uv, vec4 body, inout vec4 value, inout int source_id) {
 if (!weapon_fill_enabled) { return; }
 vec4 w0;
 vec4 w1;
 bool has0 = sample_weapon(uv,weapon0_map,weapon0_rect,weapon0_anchor_frame_uv,weapon0_rot_cos_sin,weapon0_flip_x,weapon0_enabled,w0);
 bool has1 = sample_weapon(uv,weapon1_map,weapon1_rect,weapon1_anchor_frame_uv,weapon1_rot_cos_sin,weapon1_flip_x,weapon1_enabled,w1);
 float char_alpha = value.a;
 if (has0 && weapon0_depth_mode < 0.5) {
  if (char_alpha <= 0.5) { value.rgb = w0.rgb; source_id = 7; }
  value.a = max(value.a,w0.a);
 }
 if (has1 && weapon1_depth_mode < 0.5) {
  if (char_alpha <= 0.5) { value.rgb = w1.rgb; source_id = 8; }
  value.a = max(value.a,w1.a);
 }
 bool hand = part(body.b,0.4) || part(body.b,0.5);
 if (has1 && weapon1_depth_mode > 0.5 && !(hand && weapon1_hand_in_front > 0.5)) {
  value.rgb = w1.rgb; value.a = max(value.a,w1.a); source_id = 8;
 }
 if (has0 && weapon0_depth_mode > 0.5 && !(hand && weapon0_hand_in_front > 0.5)) {
  value.rgb = w0.rgb; value.a = max(value.a,w0.a); source_id = 7;
 }
 // 源第二次背包采样不检查部位、数据图 alpha 或人物覆盖。
 if (body_in_front) {
  float coverage = value.a;
  bool wrote = write_bag(body.rg,value,coverage,source_id);
  value.a = coverage;
 }
}

// EquipmentUV 812–994、1260–1422：仅程序轮廓，不接阴影或顶点 tint。
uniform bool outline_stage_enabled = false;
uniform vec4 outline_frame_rect = vec4(0.0,0.0,1.0,1.0);
uniform vec2 outline_frame_size = vec2(1.0);
uniform float outline_base_y = 1.0;
uniform float outline_default = 0.0;
uniform float outline_hit = 0.0;
uniform float outline_extra = 0.0;
uniform vec4 outline_hit_color = vec4(0.0);
uniform vec4 outline_extra_color = vec4(0.0);
uniform float weapon0_is_sequence = 0.0;
uniform float weapon1_is_sequence = 0.0;
uniform float weapon0_hide_outline_on_body = 0.0;
uniform float weapon1_hide_outline_on_body = 0.0;
vec2 outline_sheet(vec2 frame_uv) {
 vec2 bottom = mix(outline_frame_rect.xy,outline_frame_rect.zw,frame_uv);
 return vec2(bottom.x,1.0-bottom.y);
}
// 故意不夹到帧内，原源码允许本体/装备查询跨帧相邻像素。
float outline_body(vec2 uv) {
 float a = texture(main_map,uv).a;
 vec2 b = texture(body_map,uv).rg;
 vec2 h = texture(head_map,uv).rg;
 if (enabled_pants && texture(pants_map,equip_uv(b,pants_rect)).a > 0.5) { a = 1.0; }
 if (enabled_cloth && texture(cloth_map,equip_uv(b,cloth_rect)).a > 0.5) { a = 1.0; }
 if (enabled_cloak && texture(cloak_map,equip_uv(b,cloak_rect)).a > 0.5) { a = 1.0; }
 if (enabled_helmet && texture(helmet_map,equip_uv(h,helmet_rect)).a > 0.5) { a = 1.0; }
 if (enabled_hair && texture(hair_map,equip_uv(h,hair_rect)).a > 0.5) { a = 1.0; }
 if (enabled_beard && texture(beard_map,equip_uv(h,beard_rect)).a > 0.5) { a = 1.0; }
 if (enabled_face_accessory && texture(face_accessory_map,equip_uv(h,face_accessory_rect)).a > 0.5) { a = 1.0; }
 if (enabled_mask && texture(mask_map,equip_uv(h,mask_rect)).a > 0.5) { a = 1.0; }
 return a;
}
// x 本体、y 背包、z/w 两武器。武器独立保留 sample_weapon 的帧界限。
vec4 outline_coverage(vec2 f) {
 vec2 uv = outline_sheet(f);
 float body = outline_body(uv);
 float bag = 0.0;
 if (enabled_bag && texture(bag_map,equip_uv(texture(body_map,uv).rg,bag_rect)).a > 0.5) { bag = 1.0; }
 vec4 w0 = vec4(0.0); vec4 w1 = vec4(0.0);
 bool hide = max(weapon0_hide_outline_on_body,weapon1_hide_outline_on_body) > 0.5;
 if (!(hide && body > 0.5)) {
  if (weapon0_is_sequence < 0.5) { bool sampled0 = sample_weapon(uv,weapon0_map,weapon0_rect,weapon0_anchor_frame_uv,weapon0_rot_cos_sin,weapon0_flip_x,weapon0_enabled,w0); }
  if (weapon1_is_sequence < 0.5) { bool sampled1 = sample_weapon(uv,weapon1_map,weapon1_rect,weapon1_anchor_frame_uv,weapon1_rot_cos_sin,weapon1_flip_x,weapon1_enabled,w1); }
 }
 return vec4(body,bag,w0.a,w1.a);
}
float outline_priority(int id) {
 if (id == 10) { return body_in_front ? 100.0 : 0.0; }
 if (id == 7) { return weapon0_depth_mode > 0.5 ? 80.0 : 10.0; }
 if (id == 8) { return weapon1_depth_mode > 0.5 ? 70.0 : 5.0; }
 if (id == 1 || id == 2 || id == 3 || id == 4 || id == 5 || id == 6 || id == 9 || id == 11) { return 50.0; }
 return -1.0;
}
void apply_procedural_outline(vec2 uv, int source_id, inout vec4 value) {
 if (!outline_stage_enabled || !(outline_default > 0.5 || outline_hit > 0.5 || outline_extra > 0.5)) { return; }
 vec2 f = (vec2(uv.x,1.0-uv.y)-outline_frame_rect.xy)/(outline_frame_rect.zw-outline_frame_rect.xy);
 vec2 step_uv = vec2(1.0)/outline_frame_size;
 if (f.y + 0.5*step_uv.y < outline_base_y) { return; }
 vec4 center = outline_coverage(f);
 float current = outline_priority(source_id);
 float bp = outline_priority(1); float bagp = outline_priority(10); float best = -1.0;
 bool hide = max(weapon0_hide_outline_on_body,weapon1_hide_outline_on_body) > 0.5;
 for (int i=0;i<4;i++) {
  vec2 delta = i == 0 ? vec2(step_uv.x,0.0) : (i == 1 ? vec2(-step_uv.x,0.0) : (i == 2 ? vec2(0.0,step_uv.y) : vec2(0.0,-step_uv.y)));
  vec2 n = f+delta; vec4 neighbor = outline_coverage(n);
  if (!(hide && center.x > 0.5) && max(center.z,center.w) <= 0.5) {
   for (int slot=0;slot<2;slot++) {
    float wp = outline_priority(7+slot); float wa = slot == 0 ? neighbor.z : neighbor.w;
    bool blocked = (neighbor.x > 0.5 && bp > wp) || (neighbor.y > 0.5 && bagp > wp);
    if (wa > 0.5 && !blocked && wp >= current && wp > best) { best = wp; }
   }
  }
  if (center.x <= 0.5 && neighbor.x > 0.5) {
   vec2 nuv = outline_sheet(n); vec4 b = texture(body_map,nuv); vec4 h = texture(head_map,nuv);
   bool hand = part(b.b,0.4) || part(b.b,0.5);
   bool core = hand && ((part(h.b,0.1) && h.a > 0.5) || b.a > 0.5);
   bool weapon_blocks = hand && (source_id == 7 || source_id == 8);
   if (!core && !weapon_blocks && bp >= current && bp > best) { best = bp; }
  }
  if (center.y <= 0.5 && neighbor.y > 0.5 && bagp >= current && bagp > best) { best = bagp; }
 }
 if (best >= 0.0) {
  value = vec4(outline_hit > 0.5 ? outline_hit_color.rgb : (outline_extra > 0.5 ? outline_extra_color.rgb : vec3(0.0)),1.0);
 }
}

// 阴影独立取原始投影覆盖，不使用已绘制轮廓、背包、眼饰或隐藏武器轮廓旗标。
uniform bool shadow_stage_enabled = false;
uniform float shadow_enabled = 0.0;
uniform float shadow_mode = 0.0;
uniform float shadow_left_x = 0.0;
uniform float shadow_right_x = 0.0;
uniform float shadow_center_x = 0.0;
uniform vec4 shadow_color = vec4(0.0);
float shadow_caster(vec2 f) {
 vec2 uv = outline_sheet(f);
 float alpha = outline_body(uv);
 vec4 w0 = vec4(0.0); vec4 w1 = vec4(0.0);
 if (weapon0_is_sequence < 0.5) {
  bool sampled0 = sample_weapon(uv,weapon0_map,weapon0_rect,weapon0_anchor_frame_uv,weapon0_rot_cos_sin,weapon0_flip_x,weapon0_enabled,w0);
  alpha = max(alpha,w0.a);
 }
 if (weapon1_is_sequence < 0.5) {
  bool sampled1 = sample_weapon(uv,weapon1_map,weapon1_rect,weapon1_anchor_frame_uv,weapon1_rot_cos_sin,weapon1_flip_x,weapon1_enabled,w1);
  alpha = max(alpha,w1.a);
 }
 return alpha;
}
float shadow_ground_probe(float x) {
 float alpha = 0.0;
 float step_x = 1.0/outline_frame_size.x;
 // 原顺序为中心、右、左；只裁每次 X，不裁 Y，也不提前裁三点中心。
 for (int i=0;i<3;i++) {
  float tap = i == 0 ? x : (i == 1 ? x+step_x : x-step_x);
  if (tap >= 0.0 && tap <= 1.0) { alpha = max(alpha,shadow_caster(vec2(tap,outline_base_y))); }
 }
 return alpha;
}
bool shadow_mask(vec2 f) {
 vec2 pixel = vec2(1.0)/outline_frame_size;
 float dy_uv = f.y-outline_base_y;
 if (shadow_mode < 0.5) {
  if (dy_uv > 0.5*pixel.y || dy_uv < -1.5*pixel.y) { return false; }
  float alpha = 0.0;
  if (dy_uv < -0.5*pixel.y) { alpha = shadow_ground_probe(f.x); }
  else { alpha = max(shadow_ground_probe(f.x-pixel.x),shadow_ground_probe(f.x+pixel.x)); }
  return alpha > 0.001;
 }
 if (shadow_mode < 1.5) {
  return !(f.x < shadow_left_x-pixel.x || f.x > shadow_right_x+pixel.x || f.y < outline_base_y-pixel.y || f.y > outline_base_y+pixel.y);
 }
 float dx = (f.x-shadow_center_x)/pixel.x;
 float dy = dy_uv/pixel.y;
 if (shadow_mode < 2.5) {
  bool in_rect = dx >= -1.0 && dx <= 2.0 && dy >= -1.0 && dy <= 1.0;
  bool in_corner = (dx < -0.5 || dx > 1.5) && (dy < -0.5 || dy > 0.5);
  return in_rect && !in_corner;
 }
 return (abs(dx) <= 0.5 && abs(dy) <= 0.5)
  || (abs(dx) <= 0.5 && (abs(dy-1.0) <= 0.5 || abs(dy+1.0) <= 0.5))
  || (abs(dy) <= 0.5 && (abs(dx-1.0) <= 0.5 || abs(dx+1.0) <= 0.5));
}
void apply_procedural_shadow(vec2 uv, inout vec4 value) {
 if (!shadow_stage_enabled || value.a > 0.5 || shadow_enabled <= 0.5) { return; }
 vec2 f = (vec2(uv.x,1.0-uv.y)-outline_frame_rect.xy)/(outline_frame_rect.zw-outline_frame_rect.xy);
 if (shadow_mask(f) && shadow_color.a > 0.0) { value = shadow_color; }
}

#endif

void fragment() {
 vec4 base = texture(main_map,UV);
 vec4 body = texture(body_map,UV);
 vec4 head = texture(head_map,UV);
 vec4 value = base;
 float body_coverage = 0.0;
 float head_coverage = 0.0;
 int body_source = 0;
 int head_source = 0;
 if (body_in_front) {
  apply_head(body,head,value,head_coverage,head_source);
  apply_body(body,head,base.a,value,body_coverage,body_source);
 } else {
  apply_body(body,head,base.a,value,body_coverage,body_source);
  apply_head(body,head,value,head_coverage,head_source);
 }
 // 来源身份独立于 RGB；同色装备不能落回主体肤色。
 int source_id = 0;
 if (body_in_front) {
  source_id = body_coverage > 0.5 ? body_source : (head_coverage > 0.5 ? head_source : 0);
 } else {
  source_id = head_coverage > 0.5 ? head_source : (body_coverage > 0.5 ? body_source : 0);
 }
 if (source_id == 0 && base.a > 0.5) { source_id = 1; }
 value.rgb = apply_skin_palette(value.rgb,value.a,source_id);
 // 独立 charAlpha 先合成本体覆盖，再按原顺序写武器。
 value.a = max(value.a,max(body_coverage,head_coverage));
#ifdef EQUIPMENT_WEAPON_STAGE
 apply_weapon_fill(UV,body,value,source_id);
 apply_procedural_outline(UV,source_id,value);
 apply_procedural_shadow(UV,value);
#endif
 // 原片元最后乘 v.color * _Color；须在阴影之后，且保留 RGBA。
 if (final_tint_enabled) { value *= final_vertex_color * final_material_tint; }
 COLOR = value;
}
