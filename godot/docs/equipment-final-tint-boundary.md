# 最终顶点与材质乘色迁移边界

## 锁定对象与真相源

- 迁移起点：`73452d9440bb82a24662afb2844f815115617657`。
- Unity 原码：`31629d53a110dd4c87d4c85e6ad5a387fbafb931` 的 `EquipmentUV.shader`。顶点阶段执行 `o.color = v.color * _Color`；片元完成本体、装备、武器、轮廓、阴影后执行 `return finalColor * i.color`。
- 本轮入口是两个既有 Godot 装备材质变体的显式乘色，不自动改场景、正式 Actor、纹理、顶点数据或默认视觉结果。
- 本轮验证合同是绑定、阶段顺序与数值输出；不等于 Unity/GameView 与 Godot 正式场景完整截图验收。

## 同职责映射

| 原版 | Godot 迁移 |
| --- | --- |
| 顶点输入 `v.color` | vertex 阶段的 `COLOR` 复制到 `final_vertex_color` varying |
| 材质 `_Color` | `final_material_tint` 原始 RGBA 数值 |
| 插值后的顶点色 × 材质常量 | varying 插值后与材质常量相乘。常量乘法与插值可交换，不提前作用到本体覆盖/轮廓门限 |
| 片元末尾整 RGBA 相乘 | 填充、描边、阴影全部完成后执行 `value *= final_vertex_color * final_material_tint` |
| 默认白色材质 tint | 显式绑定时可传白色；未启用本迁移阶段则保持以前未乘色的路径 |

Godot 的 fragment 输入 `COLOR` 已包含绑定的默认纹理采样，不能将其作为原版 `i.color`。否则本体纹理被重复乘一次，且透明本体上的武器、描边、阴影会消失。因此只从 vertex 阶段捕获未乘纹理的颜色。

Godot vertex `COLOR` 包含几何顶点色以及 CanvasItem 的调制颜色。正式接线时，调用方必须把原版 Sprite 顶点色映射到同等乘积，并避免父级调制或 self_modulate 重复施加。此处不推断正式 Actor 的映射已经完成。

## 显式绑定

`apply_final_tint(material, tint: Color, color_domain: int)`：

- 只接受这两个已知装备 shader。
- `color_domain = 1` 表示调用方已证明为既有非 HDR Compatibility 原始 sRGB 数值域。未知域拒绝，不自动做 Gamma/Linear 转换。
- 锁定 Unity 的 ProjectSettings 明确为 `m_ActiveColorSpace: 1`（Linear）。这里的原始数值合同不证明该 Unity 运行态的导入、颜色转换和输出色域已经对应；不得把 raw-sRGB 子集的等式验证说成已匹配原场景 Linear 管线。
- 四通道必须有限。保留零 alpha、分数值和超出 0..1 的有限输入，不在绑定层自行截断；目标附件格式的截断或精度仍属于渲染验证。
- 成功才启用 `final_tint_enabled`。失败关闭该阶段并恢复白色，防止复用旧 tint。
- `reset_final_tint` 显式关闭。逐帧填充、描边、阴影刷新不清除此独立材质值；本轮不改 Unity 刷新缓存生命周期。
- 默认创建关闭。仍是默认 13、双武器 15 个 sampler；数量不代表最低设备可用性已验证。

## 混合阶段仍需单独验证

本轮只迁移源片元 RGBA。原 Unity shader 声明 `Blend SrcAlpha OneMinusSrcAlpha`，未指定独立 alpha 因子；Godot GLES3 在透明渲染目标上使用的标准混合 alpha 因子不同。不能把独立片元 RGBA 一致直接推成透明帧缓冲 alpha 一致。

后续对照须分别核验：
1. 混合前片元 RGBA。
2. 不透明背景上的合成 RGB。
3. 透明目标上的最终 alpha，以及后续合成方式。

本轮不通过修改混合模式伪造上述差异消失，也不声称原生 GPU 帧缓冲一致。

## 验证与待验收

新增测试覆盖默认关闭、两个变体、原始 RGBA 绑定、颜色域、非有限输入、刷新独立性、失效清理、13/15 个采样器以及末尾阶段顺序。源码顺序断言只能补充合同测试，不能代替实际像素验证。

正式 Actor 顶点颜色与调制映射、持续材质生命周期、原生 Godot GPU、目标混合差异与 Unity/Godot 同帧完整场景截图仍待完成。阶段通过不等于整个迁移交付。

独立改编 GLES 数值夹具通过：透明底图上的武器和描边、非白半透明本体和阴影均只乘一次。复现误用片元 COLOR 时，本体颜色与 alpha 断言失败；关闭阶段保留此前原始帧阴影对照。混合因子模拟分别记录透明与不透明背景，RGB 一致不代表透明 alpha 一致。
