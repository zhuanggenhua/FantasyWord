# AI 普攻触发与转向门禁

源锁：Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`。这是供 AI 运行时调用的门禁，未把调试伤害靶替换成原版完整 NPC。

- `AIController.BehaviourRuntime.cs` 的 `TryAttackTarget` 依次检查目标、可见性、零冷却、严格小于触发半径，再向角色查询首个可触发正式技能。方向平方长度须大于 0.0001。写目标方向之后，如需要且尚未对准，只发出身体转向请求，当次不释放。通过后先停止同一技能的既有释放，再以 AI 命令释放；只有正式请求返回 Valid 才重置冷却。
- `AIController.cs` 的默认要求对准，使用小于 5°（配置夹到 0–45°）；`ClickMoveTest` 训练假人对应 AI 的攻击半径 1、冷却 1 秒。
- `Assets/Prefabs/Entities/Characters/Enemies/测试-训练假人.prefab` 的角色能力组件附加正式能力 **20001**；角色表每级技能列表为空并不等于假人不能攻击。项目原文档 `普攻GAS配置复刻流程.md` 对应正式能力 20001 / Timeline 101 / Effect 2003。
- `CharacterAbilitySet.cs` 按运行时正式能力顺序选首个已解析且 `CanFire()==Valid` 者。Godot 门禁要求调用端提供该已解析结果（0 表示找不到）及 AI Fire 的成功回执，不伪造技能解析或伤害。
- `tests/test_ai_attack_gate.gd` 通过显式命令回执验证边界、未对准的一次 Tick 延迟、Stop/Fire 顺序与冷却条件。正式 NPC 当前仍未接上身体转向、AI 释放、地图导航及真实命中；门禁通过不等于实战验收。
