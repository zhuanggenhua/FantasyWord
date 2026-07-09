# 2DRPG 技能族与职责参考矩阵

本文件只回答两个问题：`FantasyWord` 的新框架，是否已经覆盖 `2DRPGEngine` 当前真实存在的技能族；`2DRPGEngine` 在本 change 中到底提供了哪些可落地参考。

它不定义职业、技能树、正式数值，也不把后续 DnD 法术体系偷算成当前已完成。

## 1. 2DRPGEngine 当前真实技能族

基于本地源码取证，`2DRPGEngine` 当前技能闭包不是大型节点技能编辑器，而是：

- `AbilitySheet` 资产模型
- `DatabaseWindow` 列表入口
- `AbilitySheetEditor` prefab 与 sheet 类型校验
- 运行时能力类型：
  - `MeleeAttackAbility`
  - `ProjectileAbility`
  - `DashAbility`
  - `SelfCastAbility`
  - `SummoningAbility`
  - `ContactDamageAbility`
  - `TickingAbility`

对应源码证据：

- `C:/Gamedev/Unity/Engine/2DRPGEngine/Assets/Mythril2D/Core/Runtime/Scripts/Database/Abilities/**`
- `C:/Gamedev/Unity/Engine/2DRPGEngine/Assets/Mythril2D/Core/Runtime/Scripts/Combat/Abilities/**`
- `C:/Gamedev/Unity/Engine/2DRPGEngine/Assets/Mythril2D/Core/Editor/Scripts/EditorWindows/DatabaseWindow.cs`
- `C:/Gamedev/Unity/Engine/2DRPGEngine/Assets/Mythril2D/Core/Editor/Scripts/Editors/AbilitySheetEditor.cs`

## 2. FantasyWord 当前覆盖率

`FantasyWord` 当前运行时已经覆盖上述 7 类能力：

| 2DRPG 技能族 | 2DRPG 运行时 | FantasyWord 运行时 | 当前状态 |
| --- | --- | --- | --- |
| 近战 | `MeleeAttackAbility` | `MeleeAttackAbility` | 已覆盖，且已扩展命中窗口、背刺、反馈、GAS 规则执行 |
| 投射物 | `ProjectileAbility` | `ProjectileAbility` | 已覆盖，且已收口到角色武器入口 `CharacterHandleWeapon` |
| 冲刺 | `DashAbility` | `DashAbility` | 已覆盖 |
| 自施法 | `SelfCastAbility` | `SelfCastAbility` | 已覆盖 |
| 召唤 | `SummoningAbility` | `SummoningAbility` | 已覆盖 |
| 接触伤害 | `ContactDamageAbility` | `ContactDamageAbility` | 已覆盖 |
| 持续触发 | `TickingAbility` | `TickingAbility` | 已覆盖 |

对应项目侧源码证据：

- `Assets/Scripts/GameCore/Runtime/Database/Abilities/**`
- `Assets/Scripts/GameCore/Runtime/Combat/Abilities/**`

## 3. 参考职责边界

### 3.1 2DRPGEngine 当前可确认的作者职责

2DRPG 的作者流本质上是：

1. 打开 `DatabaseWindow`
2. 选中某个 `AbilitySheet`
3. 在普通 Inspector 中编辑字段
4. 依赖 `AbilitySheetEditor` 做 prefab 与 sheet 类型匹配校验

它不是可视化技能编辑器，也没有近战判定框可视化预览。因此它在本 change 中只能提供“单技能资产 + 列表入口 + Inspector 校验”的职责参考。

### 3.2 FantasyWord 当前落点

当前 `FantasyWord` 能成立的只有：

1. 基础攻击样例链路已经能跑通
2. 项目侧仍主要依赖现有资产、时间轴入口、测试场景和只读诊断入口

当前不能把任何项目侧自造窗口、预览器或截图桥算成正式作者流证据。

## 4. 当前结论

当前结论不能写成“FantasyWord 已经全面优于 2DRPGEngine 的全部技能作者流”。

当前只能诚实写成：

- **运行时技能族覆盖**：FantasyWord 已经覆盖 2DRPG 当前真实存在的 7 类技能族。
- **参考职责边界**：2DRPG 当前能提供的有效参考是 `AbilitySheet + DatabaseWindow + AbilitySheetEditor + 7 类运行时能力` 这一套源码级结构，而不是可视化技能编辑器或节点图。
- **当前真实现态**：现在只能证明运行时技能族覆盖成立，以及基础攻击样例链路成立。

因此，下一批正式实现方向不是继续空谈“大技能系统”，而是：

1. 先继续按正式单一路径收口 `AbilitySheet -> AbilityExecutionAsset -> 通用运行时壳 -> GAS 规则 -> 表现反馈`
2. 再判断项目侧是否真的需要新的正式作者入口，以及入口形态是否有参考支持
3. 在此之前，不再把项目侧自造窗口当成方向结论

补充现态：

- `FantasyWord` 侧已经补齐正式单一路径流程文档：`formal-skill-implementation-flow.md`
- Unity Bridge 当前已恢复只读取证，可确认当前项目 Editor 在线
- `ClickMoveTest` / composite PlayMode smoke 已真实补跑通过，因此当前项目侧运行时验证不再卡在场景脏状态

## 4.1 当前参考边界

- `FantasyWord` 侧此前曾有项目内截图桥用于拍自造窗口，但该方向已被判定为不合法，不再作为正式取证结论。
- `2DRPGEngine` 在本 change 中只作为源码级参考，不再承担“真实截图对比”或“流程 UI 对齐”的完成性职责。
- 因此，本文件的结论只依赖源码矩阵、运行时技能族和编辑职责边界，不再依赖额外截图试做。

## 5. 素材来源边界

- 动作与角色素材优先使用项目内现有 `MINIFANTASY` 资源，不直接照搬参考项目角色素材。
- 只有投射物允许使用参考或外部现成投射物资源作为过渡样例。
- 当前已发现项目内可直接复用的投射物资源包括：
  - `Assets/Art/MINIFANTASY - Crafting and Professions I/Prefabs/Projectiles/Bomb.prefab`
  - `Assets/Art/MINIFANTASY - Crafting and Professions I/Prefabs/Projectiles/ThunderBlade Projectile.prefab`
  - `Assets/Art/MINIFANTASY - Crafting and Professions I/Prefabs/Projectiles/Root.prefab`
