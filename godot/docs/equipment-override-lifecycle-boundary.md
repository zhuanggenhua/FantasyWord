# 换装动作覆盖设置与清除：阶段边界

## 对象与来源

仅增量迁移锁定 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931` 的 `EquipmentRenderer.SetAnimationContextOverride` / `ClearAnimationContextOverride`。Godot 基线为 `d72870e25f62c5076925ad7c1b1cf7d8fc7777c3`，执行入口是 `equipment_frame_runtime.gd`，验证环境是官方 Godot 4.7.2 无头测试。

源入口位于 `Assets/Scripts/Gameplay/Runtime/Presentation/EquipmentSystem/Runtime/EquipmentRenderer.cs`。调用时序参考同目录 `MountedCharacterPresentation.cs`：覆盖键可先以 `autoRefresh=false` 设置，之后当前骑手 Sprite 即使引用相同，也由调用方选择显式刷新。这不是坐骑动作推进的移植。

## 对应规则

- `set_animation_context_override(animation_key, code_key, sprite, auto_refresh=true)` 接受 String 或 null。null 变空；字符串按 .NET `Char.IsWhiteSpace` 集合裁剪两端，保留内部空白、大小写以及 Godot 字符串可表达的非空白控制字符。覆盖、代码动作键和实际动作应用的空白判定共用此集合，但非空代码动作键不做裁剪。Godot 不接受内嵌 NUL，故不声称跨语言 NUL 字符串互操作。
- 规范化结果与已存键精确相等就立即退出，既不重新解析动作，也不刷新。未知动作不擅自映射到已有动作。
- 值变化后先存键、调用已有 owner 解析，再在自动刷新启用时调用已有显式当前 Sprite 同步。不能把这个先后顺序简化为只有 Sprite 改变才刷新。
- `clear_animation_context_override(code_key, sprite, auto_refresh=true)` 在已空时直接退出；否则清空后沿用同一解析与可选刷新顺序。
- 调用方显式提供当前代码动作键、Sprite，适配源组件持有的依赖。接口不修改 Animator、代码动作状态或能力动作真相。
- 空 Sprite 时，setter 仍先解析动作，随后显式同步仅执行 Refresh；不同于单独调用空 Sprite 同步时不解析动作。直显模式的 setter 也先解析，随后 Refresh 才执行直显分支，不等同直显 LateUpdate。

## 验证与未覆盖

`tests/test_equipment_override_lifecycle.gd` 使用实际 Godot AtlasTexture 引用和现有刷新钩子核对：同 Sprite 设置、不自动刷新、显式刷新；规范化重复调用无副作用；清除与 null；大小写及完整 .NET 空白边界；直显及缺帧数据/空 Sprite 分支。人工小纹理只用于隔离合同测试，不是正式素材或视觉交付。

本阶段不接入真实 MountedCharacterPresentation 驱动、坐骑时钟、装备工作台按钮，不移植完整 SetFrameData 生命周期，不宣称真实素材、四向连续帧、Shader 最终合成、完整角色或 Unity/GameView 对照验收通过。原 Unity 主分支与素材不变。
