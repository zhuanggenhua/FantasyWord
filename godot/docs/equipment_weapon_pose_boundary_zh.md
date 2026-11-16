# 武器序列与静态绑定迁移边界

## 对象、来源、入口和验收

- 对象：武器槽在已有躯干方向、当前帧和作者锚点确定后的参数绑定；不是完整换装渲染交付。
- 锁定 Unity 提交：31629d53a110dd4c87d4c85e6ad5a387fbafb931。
- 对照位置：EquipmentSystem/Runtime/EquipmentRenderer.cs 的 RenderWeaponSlot、WeaponConfigByRow、GetWeaponSortOffset、PixelToFrameUV；Data/CharacterFrameData.cs 的 AnchorPoint.GetRotationAngle、AnchorFacingConfig；EquipmentRenderData.GetSpriteByRow。
- Godot 入口：gameplay/presentation/equipment_weapon_pose.gd 的 resolve。无节点搜索、素材自动填补或新设计。
- 验收：tests/test_equipment_weapon_pose.gd。仅绑定合同单测，不是原场景或完整画面验收。

## 输入责任

调用方显式传入躯干朝向（不是头部朝向）、主副手、当前动画帧尺寸（无动画数据时先用角色 Sprite.rect 尺寸）、锚点或 null、装备和本动画是否配置序列。原 Shader 材质、缓存帧和角色 Sprite 存在性由调用方在进入本函数前检查。

装备的 sprites 使用 se/sw/ne/nw，值为描述对象：texture 是整张纹理，rect 是原 Sprite 的像素区域。源非法素材识别结果显式传 ui_icon / whole_character_action；序列的 invalid_layer 是原 IsInvalidEquipmentLayerSprite 判定结果。本阶段不以纹理名称或尺寸猜测这些分类。

sequence_configured 来自源 HasSequenceForKey，不能用“这一帧有没有图”代替。sequence_sample 的 sprite 和 depth_back 来自已解析的本帧序列与作者深度。此函数不重做动画键、大小写匹配、序列帧索引或帧回退，不冒称已接入整个序列资源加载链。

anchor.position 为原帧像素整数位置，direction 保留源 AnchorDirection 的 0..7 枚举值。方向表不是简单的枚举乘角度。

## 输出与清槽语义

- enabled / write_slot / disable_generated_renderer 明确区分“原函数直接返回”和“明确关闭武器槽”。
- 配置了序列但本帧无图、无纹理或被原非法层规则拒绝时，清槽且禁用生成子渲染器；不能使用静态图兜底。
- 静态缺图/非法图沿用原直接返回。调用方必须保留源 Refresh 先清槽再绑定的顺序，不能把 write_slot=false 解读为保留上一帧。
- 有效序列绑定作者深度、禁旋转与镜像；缺锚点用帧中心。有锚点仍使用作者位置。
- 静态缺锚点清槽。西向是否镜像只看 SW 是否配置，即使 NW 配置了也不能改用 NW 存在性判定。
- anchor_frame_uv 保留 PixelToFrameUV 的实际 Y 反向实现；hand_local_uv 用所选武器 rect 大小。四方向偏移以源表实际 (-0.5,-0.5) 为准，不沿用过时注释。
- rot_cos_sin 是原角度的 cos/sin，西向镜像时仅将静态角度取反。不根据 Godot 屏幕坐标再次反转。
- slot_is_front 保留实际左右手表和排序增量计算；主手 SE/SW 后、NE/NW 前。注释不覆盖运行代码。
- hand_in_front 对盾牌南向为 false，北向为 true；其他武器均为 true。hide_outline_on_body 原样传递。
- sprite 引用与像素 rect 保持原样，不把整 atlas 当成裁剪图。

## 未完成与证据限制

此阶段没有改写正式材质/主场景，没有新增源素材、作者表或原截图，没有完成武器 UV 采样、两槽合成、武器描边及完整视觉对照。测试包含非零 atlas 原点、非方形 rect、非中心锚点、全部角度和四朝向主副手；测试纹理是明确标注的合成合同夹具，不能当作原素材视觉证据。
