# 0061-编辑器验证工具与一次性迁移边界

- 日期：2026-07-17
- 状态：已采纳
- 背景：
  - 参考工程 `2DRPGEngine` 的 Editor 层主要提供数据库、文档、属性绘制、Playtest 和持久化辅助工具。
  - FantasyWord 当前增加了 ClickMoveTest 验证桥、ContextSteering 调试/基准、EX-GAS 命中框 SceneView 辅助、统一 `CharacterSheet` 编辑器和多组 EditMode 合同测试。
  - 这些文件不是运行时 owner，也不能作为“业务已完成”的证据，但它们是当前项目验证链和作者工具链的一部分。
- 决策：
  - 允许把只读审计、验证桥、EditMode 测试、调试窗口、SceneView 作者辅助和当前项目必要编辑器适配登记为参考一致性脚本的 Editor 工具层差异。
  - 这些工具不得拥有正式运行时状态，不得替代 GameCore owner，也不得让场景/资产迁移在无明确目标时自动执行。
  - 会加载、修改或保存场景/资产的一次性迁移入口不得长期留在正式 Editor 菜单；若仍需要，必须作为明确任务脚本或专项流程重新登记目标、真相源和验收口径。
  - 本轮删除已过期的 `ClickMoveTestTerrainLayerMigration` 菜单工具，不把它白名单成长期框架能力。
- 影响：
  - `Test-FoundationReferenceParity.ps1` 允许已审过的 Editor 验证/测试/工具层差异。
  - `ClickMoveTest` 相关验证器仍只能证明测试场景的验证链，不证明正式玩法内容接入。
  - 后续新增 Editor extra 时，仍必须先按参考流程对照表说明工具职责和是否会写场景/资产。
- 替代关系：
  - 补充 `0050` 的参考流程审计纠偏：不能因为参考没有某个 Editor 工具就判错，也不能因为工具有用就放任一次性迁移入口常驻。
