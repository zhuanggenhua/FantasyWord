# 动作可空 UV 的独立写入

## 四项前提

- 对象：已有换装材质的 Body/Head 两个采样器，以及动作选择与完整 Refresh 的调用顺序。
- 真相：Unity 锁定提交 31629d53a110dd4c87d4c85e6ad5a387fbafb931 的 EquipmentRenderer.cs（ApplyAnimationKey、UpdateUVMapTexture、Refresh）及 EquipmentUV.shader 声明。
- 入口：Godot 4.7.2 的显式 apply_nullable_action_uv_maps，供已有 EquipmentFrameRuntime.hooks.bind_uv_maps 接入；不修改正式角色场景。
- 验收：真实 ShaderMaterial 引用/参数及 ImageTexture 的 CPU RGBA，运行既有帧游标、动作与 Refresh 分支。不是 Unity 原生采样或最终画面证据。

## 为什么不能一起清除

动作改变时，源 UpdateUVMapTexture 分别写两张图。有效 Body 加缺失 Head 会立即得到新 Body 与空 Head；如果 Sprite 没变，LateUpdate 不执行整套 Refresh，之前装备层可以仍然启用。

显式刷新或下次 Sprite 变化后，Refresh 若缺任一图、动作或帧，先重置装备层，再同时清两张图，然后尝试独立武器及匹配动作的序列装备。完全没有 frameData 是更早的警告、重置、返回，不清 UV。现有 Runtime/Refresh 已保留这些顺序，本轮连接可空参数，不重写这些分支。

## 显式黑纹理合同

源 Shader 声明两个 UV 默认都是 black。[Unity 6 ShaderLab 文档](https://docs.unity.com/en-us/engine/6000.0/manual/materials-and-shaders/shaders/reference/sl-reference/sl-shader-object/sl-properties) 将该默认定义为 RGBA（0,0,0,1）。

新入口将每个显式 null 映射为同一内部一像素不透明黑 ImageTexture；不是透明图，不依赖 Godot 未绑定采样器的未知默认。非空图分别校验为有效完整 Texture2D；非法非空值、AtlasTexture、空尺寸拒绝且不半写。源分别持有两图，因此此新入口不强制两图尺寸一致。原 apply_action_uv_maps 的严格双图契约保持不变。

只改 body_map/head_map，不增 sampler、不改着色器声明、不重建材质、不改主图或装备开关。返回值明确记录各自是否缺失。绑定资源属于内部默认常量，调用方不得修改其像素。

黑 UV 不能推导为装备不可见：零 RG 仍可在已启用装备的作者 rect 角落采样到不透明像素，轮廓和阴影查询同样可能取样。不得借清图顺便关闭装备，否则改变同 Sprite 的中间态。

## 验证和未验收

测试覆盖有效→同 Sprite 半缺失→完整 Refresh 双清→无 frameData 只重置→有图但缺帧双清→恢复，检查顺序、普通层/独立武器/序列筛选，以及黑资源 CPU RGBA、同材质和严格入口不变。

测试中的层重置/武器/序列钩子只对本测试显式字段操作或记录顺序，不是正式完整 ResetEquipmentState、武器渲染、装备图层接线。真实 Unity 将 null 赋给声明默认采样器后的 GPU 结果，以及 Godot 全着色器和角落装备纹理渲染仍需独立运行对比；本轮不声称实现了这些画面验收，也不改变正式角色入口。
