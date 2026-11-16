# 装备主体的世界脚底查询边界

## 锁定对象与证据

- 迁移基线：`d7c240d19625bcfbca437b3d38f8ff7853c13f5a`。
- Unity 真相源：`31629d53a110dd4c87d4c85e6ad5a387fbafb931` 中 `EquipmentRenderer.TryGetGroundAnchorWorldPosition`。
- 当前入口：已采样实际 `AtlasTexture` 的 `EquipmentFrameGeometry`。本轮新增只读表现查询，不改移动、碰撞、脚底阴影、动作选择或生成资源。
- 证据是源码与原生 Godot 节点合同测试，不是 Unity 运行时或完整画面对照。

## 原语义与适配

| Unity 原语义 | 当前 Godot 合同 |
| --- | --- |
| 缺少 `frameData` 或当前 Sprite 返回失败 | `ground_pixel_y = null` 或没有有效实际采样返回失败 |
| 动作配置存在时使用配置帧高，否则用 Sprite 实际矩形高 | `configured_frame_height` 明确给正数或 `null` |
| `groundPixelY + 0.5` 夹到配置高度 | 保留像素中心和上下限，不把留白底边当脚底 |
| 归一化地面比例乘实际 Sprite 高度，再减底起轴点并除以 PPU | 保留配置高和实际高的区别，复用当前采样的作者几何 |
| FlipY 对局部脚底 Y 取反 | 同样取反，然后转换为 Godot 向下的局部 Y |
| Body.TransformPoint((0,localY,0)).y | 通过当前几何节点的实时 `global_transform * Vector2(0,-localY)` 求纵坐标 |
| SpriteRenderer.bounds.center.x | 必须由调用方明确提供 `bounds_center_x`；不使用节点原点，不从未经核实的完整矩形推断紧网格/覆盖后的 Bounds |

公开方法：

```gdscript
query_ground_anchor(
    ground_pixel_y: Variant,
    configured_frame_height: Variant,
    bounds_center_x: float
) -> Dictionary
```

成功返回 `{"ok": true, "position": Vector2}`；失败返回 `{"ok": false, "reason": ...}`。地面行为整数，因为对应原作者整数像素配置。有限数值与真实节点等验证是桥接安全边界，不声称原 Unity 会对 NaN 做相同检查。

调用者必须确认几何节点对应原 Body 的二维变换映射；返回坐标是 Godot 世界坐标，Y 向下。这里不接受把任意 Unity 三维倾斜投影直接当成同一二维变换。未接入正式 Actor 的帧数据/Bounds 提供方。

## 当前 Sprite 与材质失败分离

原查询并不要求 Body/Head UV 或材质成功。本轮在真实采样通过几何验证后、调用材质提供者之前保留 Sprite 身份和作者几何快照。因此材质失败时仍按原有规则清除绘制，但已采样 Sprite 的脚底查询仍可成立。

无 Sprite、未知 Sprite、无效 region/margin/几何时拒绝使用旧脚底。调用方更改配置的 flip/pivot 等后，必须通过下一次真实采样更新几何，不能把外部元数据变化说成已改变当前画面；这是既有采样桥接合同，不等于完整 Unity LateUpdate/Refresh 生命周期。

## 验证与仍未验收

- 原生节点覆盖非中心轴点、配置高不同于实际高、正负越界像素行夹取、双镜像、旋转/缩放/平移父子节点及其组合。
- 分别验证 X 取显式世界 Bounds 中心，Y 取局部 X=0 的世界变换结果；旋转下不可把 Bounds 局部中心的 X 混入 Y。
- 验证只读、无采样、缺作者数据、无效配置、非有限变换、离树节点、材质失败保留脚底、缺帧清除和后续恢复。
- 完整矩形测试纹理仅作合同夹具，不冒充正式素材。锁定人形 Idle/Walk/Dmg 三张图的导入元数据为 FullRect、PPU 8，实际 96 帧为中心轴点，配置高 32、地面像素行 18。独立用原数据在原生节点检查 193 次，包括缺材质时仍可查。这不证明紧网格或运行时自定义 Bounds，也不需要公开原始图。
- 正式 Actor 调用、实际倒影接线、SpriteRenderer Bounds 与 Godot Bounds 的真实运行态配对，以及 Unity/Godot 同帧完整截图仍待验收。
