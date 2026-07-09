# Character Alteration Alignment Twenty-Sixth Cut

## 目标

第二十六刀只收一个最小合同：变形、感染、丧尸化等 `CharacterAlterationRule` 规则可以在生效期间按来源临时覆盖角色阵营，让敌我判断和 AI 选敌读取同一条角色真相。

这不是完整 AI 接管。角色控制权转移、强制切到 AIController、恢复玩家控制、派系关系系统、犯罪/仇恨记忆和长期感染阵营进程仍是后续裁决。

## 用户故事

- 作为玩家，我的队友可能被感染或丧尸化。规则生效期间，其他 AI 应能把他视为敌对目标，而不是只因为角色原始配置仍是 Good 就继续当队友。
- 作为内容作者，我需要在同一条变形/感染规则上声明“获得/失去哪些能力、锁哪些动作、临时变成什么阵营”，不用再去 AI 控制器或伤害判定里写特殊分支。
- 作为未来主机权威合作的准备，阵营改变应由房主/单机同一套规则入口裁决，AI 只读取角色当前阵营，不直接解释具体感染或变形业务。

## 实现

- `CharacterAlterationRule` 新增 `overrideAlignment` 与 `alignmentOverride`。
- `ApplyNonAbilityChanges(...)` 在规则生效时按 `CharacterAbilitySourceKey` 写入角色的来源化阵营覆盖，并携带规则优先级。
- `RemoveNonAbilityChanges(...)` 和 `RemoveNonAbilityChangeStack(...)` 按同一来源撤回全部或单层阵营覆盖。
- `CharacterBase.currentAlignment` 优先读取来源化阵营覆盖，再回退到脚本临时 `SetAlignmentOverride(...)`，最后回退角色表默认阵营。
- 多条规则同时覆盖阵营时，按规则优先级选最高者；优先级相同则按来源键做稳定裁决，避免结果依赖字典遍历顺序。
- `RestoreActiveAlterationRules(...)` 读档时会从 `activeAlterationRules` 重建阵营覆盖，不新增存档字段。
- `CombatSolver` 和 `AIController` 不需要新增分支，因为它们已经通过 `currentAlignment` 判定敌我和选敌。
- `Invoke-FoundationStaticGate.ps1` 已加入来源化阵营覆盖门禁。

## 存档与边界

没有新增存档字段。阵营覆盖和动作锁一样，由已激活的 `CharacterAlterationRule` 规则资产在读档时重建。

`SetAlignmentOverride(...)` 继续保留给召唤物等脚本临时入口；变形/感染规则来源优先于这类脚本覆盖。后续若进入完整派系系统，应让角色当前阵营继续作为战斗/AI 的即时读口，而不是让 AI 直接依赖感染、变形或派系资产细节。
