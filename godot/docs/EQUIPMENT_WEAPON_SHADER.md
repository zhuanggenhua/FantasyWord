# 双武器填充的显式着色器接入

## 范围和原始依据

锁定 Unity 31629d53a110dd4c87d4c85e6ad5a387fbafb931 的 EquipmentUV.shader：
TrySampleWeaponGeneric 和身体/头部/肤色之后的武器填充、末次北向背包覆盖。
这是已有本体子集的可选后续阶段，不是整套角色着色器，不接入正式场景，也不改变正式玩家装备。

| 源行为 | Godot 对应 |
|---|---|
| 整图映射当前角色帧，再相对锚点旋转、镜像 | sample_weapon；顶原点仅在入口和采样出口转换 |
| 角色帧与武器局部边界包含端点，帧宽高大于 0.0001 | 保留原公式，不做裁切重排或缩放补偿 |
| alpha 严格大于 0.5 才命中 | 命中后保留分数 alpha |
| 后景主手再副手；原人物覆盖挡 RGB，但不阻止武器贡献 alpha | 保存原 char_alpha，不以刚写的武器判遮挡 |
| 前景副手再主手；各槽 HandInFront 阻挡手部 | 不把过时注释里的“脚始终挡武器”补成新功能 |
| DepthMode 恰为 0.5 不绘制 | 两侧都严格比较 |
| 北向背包再次覆盖所有武器 | 除身体朝向、启用、采样 alpha 外，不增加部位条件 |

## 绑定与默认行为

equipment_subset_material.gd 的 create 新末参 using_weapon_stage 默认 false。
旧调用继续使用 equipment_character_subset.gdshader，不编译任何武器函数或武器 sampler。
显式 true 使用 equipment_weapon_subset.gdshader；两者共享 equipment_character_shared.gdshaderinc，
武器代码由预处理条件隔离，避免只用运行时开关却增加旧路径的纹理单元占用。

只有武器变体可调用 apply_weapon_fill(material, frame_rect, slots)。
frame_rect 为当前帧在角色整图中的底原点归一化 Rect2，必须与当前几何/动画帧同步。
slots 为主手、副手两个字典，空槽用空字典或 enabled=false。
启用槽必须提供：
- enabled：布尔。
- texture：有效整张 Texture2D，不接受 AtlasTexture。
- rect：作者精灵在该整图中的底原点归一化 Rect2。
- anchor_frame_uv、hand_local_uv、rot_cos_sin：原姿态计算的 Vector2。
- flip_x：原布尔镜像。
- depth_mode、hand_in_front：原数值，不把 0.5 舍入到前后侧。

姿态模块的 sprite.rect 为像素区域，不能直接当归一化区域；调用方根据实际整图尺寸和原点换算。
本层不重算朝向、不选择装备、不推进序列。错误配置先清除上次武器并返回明确失败。
空双槽显式启用仍执行北向背包末次覆盖。reset_weapon_fill 释放双槽引用并关闭该阶段。
肤色绑定同时支持原变体与武器变体，始终发生在武器合成之前。

## 验证与边界

- test_equipment_weapon_material.gd 检验真实 ShaderMaterial 参数、清槽、原子失败和默认变体隔离；原生无头 uniform 列表分别是13和15个 sampler。
- 独立私有原图实验：88个有盾牌锚点的原作者帧，901120次像素比较无差异；96个原作者动画帧原生材质绑定（88有锚、8无锚）通过。这里显式把盾牌配置作为测试输入，并非声称正式玩家原本已装备盾牌。
- 旧本体786432像素回归、肤色门槛和合成双槽2304案例算式检查通过。上述像素是 EGL 改写算式实验，不是真实 Godot framebuffer 或最终场景。
- 私有 EGL llvmpipe 32 单元环境只验证改写后的 GLSL 算式，不等于 Godot CanvasItem 后台或 Unity GameView。
- 默认本体13、武器变体15个显式 sampler。Godot GLES3 另有预留纹理单元；不得以15小于16宣称最低16单元的Web/移动设备可用。目标设备编译、绑定、完整输出仍需实测。
- 未迁移程序描边、阴影、后续来源优先级；未验收正式 Actor 接入、完整同场景截图。
- 不发布原始素材、私有参数表或截图，合成测试数据不是正式素材。
