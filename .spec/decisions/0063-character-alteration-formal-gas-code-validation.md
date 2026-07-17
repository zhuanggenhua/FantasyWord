# 0063-变形感染规则 Formal GAS 编号校验边界

- 日期：2026-07-17
- 状态：已采纳
- 背景：
  - 2DRPGEngine 没有独立的变形/感染规则资产；相近职责是装备、命令或持续效果改变角色能力集合。
  - 参考工程的作者数据直接保存 `AbilitySheet` 资产引用。空数组表示“不改变能力”，但数组里的能力项应当是真实能力资产。
  - FantasyWord 将能力身份迁移为 Formal GAS 技能编号后，`CharacterAlterationRule` 的授予/压制数组承担了原资产引用的作者配置职责。
- 决策：
  - `CharacterAlterationRule` 允许授予/压制能力数组为空，表示该规则只改变动作锁、玩家控制、AI 接管、装备压制或阵营等非能力状态。
  - 授予/压制数组中出现小于等于 0 的 Formal GAS 技能编号时，视为作者配置错误；不得通过过滤把坏编号静默当成未配置。
  - 正式应用变形/感染规则前必须先校验能力编号配置，再移除互斥规则、授予/压制能力或应用非能力状态。
- 影响：
  - `CharacterAlterationRule.EnsureFormalGasAbilityCodeConfiguration()` 是变形/感染规则应用前的配置门禁。
  - `CharacterBase.ApplyCharacterAlterationRule(...)` 在任何状态变化前调用该门禁。
  - 测试覆盖坏编号不改变角色状态，空能力数组仍允许纯非能力状态规则生效。
  - Foundation 静态门禁检查该合同，防止回退成静默过滤。
- 替代关系：
  - 补充 0050 的“参考流程优先”审计口径。
  - 不取代 0062；旧规则型持续效果边界仍按 0062 执行。
