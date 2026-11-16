shader_type canvas_item;
render_mode unshaded;
// 显式武器变体：需要独立验证目标设备的纹理单元预算。
#define EQUIPMENT_WEAPON_STAGE
#include "equipment_character_shared.gdshaderinc"
