# Tasks: define-skill-authoring-workbench

## 0. Current Status

本 change 当前只能成立三类结果：

1. 提案 / 问题清单 / 边界文档已经形成闭环
2. 旧“工作台 / 准备链路 / 修复接线 / 测试角色保活器”已经从正式方案和正式入口中撤回
3. 执行资产层、统一技能实现路径和审计入口已经部分落地；基础攻击样例仍只作为 smoke 目标，不再包装成作者流程

本 change 当前**不能**成立的结果：

- 不能宣称项目侧正式技能编辑器已完成
- 不能宣称项目侧自造窗口优于参考
- 不能宣称基础攻击规则层已经完全收口
- 不能宣称执行真相已经裁死单一赢家

## 1. Proposal Closure

- [x] 新建 `define-skill-authoring-workbench` OpenSpec change
- [x] 提案、设计、规格、开放问题和门禁文档已经收口
- [x] 记录未确认职业 / 技能树 / 正式技能内容前，不直接实现正式构筑内容

## 2. Still Valid Work

- [x] 锁定第一小阶段为：基础攻击 + 动画驱动 + 碰撞盒命中 + 最小属性扣血
- [x] 保留 `FireAbility1` 作为当前基础攻击样例验证入口
- [x] 基础攻击伤害已收口到 `GameplayEffectAsset.Executions -> FormalInstantDamageExecution -> CharacterBase.Damage(...)`
- [x] 建立 `2DRPGEngine` 当前真实技能族源码矩阵：`Melee / Projectile / Dash / SelfCast / Summoning / ContactDamage / Ticking`
- [x] 已删除 `BasicAttackAuthoringWorkbench`、相关脚本、菜单和错误作者流入口
- [x] 已删除 `BasicAttackTestSceneRuntimeBootstrap` 及 `ClickMoveTest` 中对应场景挂件
- [x] 已移除 `玩家角色.prefab` 中越界的 `测试-蓄力攻击 / 测试-背刺` 正式接线
- [x] 已移除 `DatabaseRegistry.asset` 中越界的测试技能登记
- [x] 已删除超出当前合法范围的测试技能资产与 prefab：`投射物 / 召唤 / 自施法 / 持续触发 / 冲刺 / 接触伤害 / 蓄力攻击 / 背刺`
- [x] 已将残留基础攻击样例目录从 `SkillWorkbench` 更名为中性 `AbilitySamples`
- [x] 已新增 `AbilityExecutionAsset / MeleeAbilityExecutionAsset` 代码与基础命中框静态迁移预览
- [x] 已把 `测试-基础攻击` 样例迁到正式执行资产引用：`AbilitySheet.executionAsset + m_meleeExecutionAsset`
- [x] 已把 `MeleeAttackAbility` 显式接到正式近战执行资产门禁，缺失时会报错
- [x] 已新增 `FormalAbilityExecutionAudit`，用于审计近战技能是否绑定了匹配的正式执行资产
- [x] 已把 `Projectile / Dash / Summoning / SelfCast` 也纳入正式执行资产体系与审计口径
- [x] `AbilitySheetEditor` 已支持为主要主动技能族创建并绑定对应执行资产，不再只支持近战
- [x] 已修正 `AbilitySheet -> AbilityExecutionAsset` 旧字段迁移复制逻辑，避免嵌套字段、数组和 `SerializeReference` 数据在创建正式执行资产时静默丢失
- [x] 已为 `Projectile / Dash / Summoning / SelfCast` 补执行资产 Inspector 与基础防误提示，不再只有近战有迁移期数据入口
- [x] `FormalAbilityExecutionAudit` 已扩展检查主要主动技能族兼容字段与 `AbilitySheet.executionAsset` 是否一致
- [x] 已新增并收口正式技能实现流程说明：`formal-skill-implementation-flow.md`
- [x] 已新增提案完成性审计：`completion-audit.md`

## 3. Explicit Rollbacks

以下方向已被判定为偏离用户要求，必须视为撤回，不再当成完成项：

- [x] 撤回把项目侧“基础攻击工作台”当成正式作者流方向
- [x] 撤回把项目侧“能力对比工作台”当成正式作者流方向
- [x] 撤回把项目侧命中盒预览 / SceneView 手柄当成正式判定框编辑器方向
- [x] 撤回把项目侧截图桥产物当成“参考流程截图对比完成”的证据
- [x] 撤回 proposal / design / spec / parity matrix / basic-attack-authoring 里把工作台写成正式方向的口径
- [x] 撤回“准备链路 / 修复接线 / 打开测试场景”这类人类可点击修补入口
- [x] 撤回 `SkillWorkbench` 作为正式能力目录语义
- [x] 撤回通过运行时保活器强行启用基础攻击测试角色的旧场景补丁逻辑

## 4. Recorded Future Decision Gates

- [x] 已记录蓄力攻击 / 背刺的冷却细节仍待后续阶段确认
- [x] 已记录后续角色构筑阶段的职业结构仍待用户确认
- [x] 已记录后续角色构筑阶段的技能树归属仍待用户确认
- [x] 已记录后续角色构筑阶段是否允许 respec 仍待用户确认
- [x] 已记录后续角色构筑阶段的技能获取方式仍待用户确认
- [x] 已记录玩家炼金式法术配置第一版 UI 形态仍待用户确认

## 5. Verification That Still Holds

- [x] `npx openspec validate define-skill-authoring-workbench --strict`
- [x] 清理完成后重新做一次残留扫描，确认没有再把旧作者流写成正式入口
- [x] Unity Editor AIBridge 已恢复可消费命令，已取到真实 Editor 状态：`isCompiling=false`
- [x] 已取到当前场景状态证据：`ClickMoveTest` 已从内存脏状态重开回磁盘版本，当前 `isDirty=false`
- [x] 已有正式执行资产审计真实取证入口：`FormalAbilityExecutionAudit.Inspect()`
- [x] 已按当前无旧保活器现态重新补跑 `ClickMoveTest` / composite PlayMode smoke，结果通过：`控制组 / RTS 订单链 / GAS formal 恢复 smoke 通过`

## 6. Remaining Blocking Work

- [x] 已将后续角色构筑与玩家配方的数据模型问题收口为“后续阶段决策门”，不再混算为当前 change 的未完成实现
- [ ] 基础攻击规则残留仍未收干净：基础 `effects` 仍在 `AbilitySheet`，背刺额外效果仍在执行资产
- [ ] 近战命中框正式作者面仍未完成：当前只有静态迁移预览，不是动画帧可视化编辑
- [ ] 执行真相仍未完成最终职责裁决：当前只能确认“项目执行壳 + GAS 规则层”的收口方向
