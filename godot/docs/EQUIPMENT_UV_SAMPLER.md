# 换装 UV 坐标与点采样合同

## 锁定与边界

基于 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`，Godot 基线 `e173d233`。目标为换装链路的纯 CPU 坐标合同；不接入最终画面，不声称 Shader、装备合成或截图验收完成。

- `EquipmentUV.shader:167` 的 `TransformUV`：编码 RG 在装备 Sprite 矩形内线性映射。
- `EquipmentUV.shader:996–1013`：Main、Body、Head 使用同一整张角色图 UV；帧局部 UV 单独计算，原点为左下。
- `EquipmentRenderer.cs:2220–2238`：当前帧矩形来自实际 Sprite 的 rect 与整张纹理尺寸。
- `SpriteUtils.GetUVRect`：装备矩形采用左下原点的 min/max 边界。
- 原人类 Idle BodyUV 导入设置：Point、Clamp、无 mip、非 sRGB。CPU Image 不执行颜色空间转换，零 alpha 的 RGB 仍可读取。

## 显式 API

`equipment_uv_sampler.gd` 接收顶原点整图 UV，`frame_local_uv` 返回左下原点帧局部 UV。`equipment_uv` 接收保持原值的编码 RG 和底原点装备 `Rect2`，返回顶原点装备纹理 UV。`rect_from_unity_bounds` 才负责把 Unity xyzw 最小/最大值转换成 Godot 的 position/size。不得把顶原点装备矩形混入此 API。

`sample_sheet` 同坐标读取三个 Image；`sample_point` 对应最近点、边缘夹取。不裁剪到 Sprite 内，不对编码 RG 做翻转后再映射，不跳过透明像素。

## 验证及未完成

原生 GDScript 对非对称 12×8 人工诊断图逐像素覆盖三张图，验证非零行列、V 翻转、装备非全图矩形、边界点采样和零 alpha RGB。这些人工图仅是测试输入，不是替代原素材或最终画面。

本合同不计算部位掩码、装备颜色层、身体深度、武器、阴影与描边。尚未完成 GPU Shader 接入和同场景完整画面验收；无图形显示的 headless 通过仅证明 CPU 行为。
