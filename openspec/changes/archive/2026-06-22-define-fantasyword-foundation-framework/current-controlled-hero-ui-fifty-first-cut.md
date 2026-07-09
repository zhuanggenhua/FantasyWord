# 第五十一刀：当前受控 Hero UI 语义收口

## 背景

控制组和未来多角色控制进入正式闭包后，`PlayerSystem` 同时承载两个不同语义：

- 长期玩家实例：用于存档、主角长期成长，以及当前仍保留的世界穿越等旧全局玩家语义。
- 当前受控 Hero：用于当前前台能力栏、能力菜单和角色面板。

此前 `m_currentControlledHeroChanged` 事件发布的是 `GetCurrentControlledHeroOrPlayerInstance()`。这会在当前控制对象不是 `Hero`，或当前没有受控 Hero 时，把能力 UI 和角色面板回退到玩家主角。对 Kenshi / 博德之门式多角色控制来说，这会让 UI 看起来像当前角色仍拥有玩家主角的能力和属性。

## 实施

- `PlayerSystem.cs`
  - 将 `GetCurrentControlledHero()` 改为公开查询口。
  - `NotifyCurrentControlledTargetChanged()` 现在发布真实当前受控 Hero；没有受控 Hero 时发布 `null`。
  - 保留 `GetCurrentControlledHeroOrPlayerInstance()`，继续服务长期玩家实例兜底语义。
- `UIHUDAbilityBar.cs`
  - 初始绑定改读 `GetCurrentControlledHero()`。
- `UIHUDAbilityBarEntry.cs`
  - 冷却刷新改读 `GetCurrentControlledHero()`，不再在控制非 Hero 角色时读取玩家主角冷却。
- `UIAbilityBar.cs`
  - 能力菜单内快捷栏初始绑定改读 `GetCurrentControlledHero()`。
- `UIAbilities.cs`
  - 能力菜单初始化和显示时绑定真实当前受控 Hero。
- `UICharacter.cs`
  - 角色面板初始化和显示时绑定真实当前受控 Hero。
- `Invoke-FoundationStaticGate.ps1`
  - 新增 `CurrentControlledHeroUiMissingPatternCount / CurrentControlledHeroUiDisallowedPatternCount`，防止能力/角色 UI 回退到玩家主角兜底。

## 边界

- 不实现完整控制组能力栏合并显示。
- 不实现非 Hero 角色的能力菜单。
- 不改变 `GetCurrentControlledHeroOrPlayerInstance()` 对存档和旧全局玩家语义的用途。
- 不改背包 UI、装备 UI 或商店/制作 UI 的 owner 模型。
- 不接入远程访客、FishNet、网络 ownership 或 ECS。

## 当前结论

本刀只把“当前受控 Hero”事件和能力/角色 UI 从“真实当前 Hero 或玩家主角兜底”改成“真实当前 Hero”。当玩家控制非 Hero 或未来控制组不以 Hero 为前台时，这些 UI 会清空，而不是误显示玩家主角能力。完整控制组技能栏、非 Hero 能力 UI、队伍级技能栏和远程访客 UI 仍未完成。

## 验证

- 本轮触碰文件尾随空格搜索无命中。
- `git diff --check` 通过。
- `powershell -ExecutionPolicy Bypass -File .\scripts\Invoke-FoundationStaticGate.ps1 -AsJson` 通过，关键结果包括 `PlayerSystemPlayerControlMissingPatternCount = 0`、`CurrentControlledHeroUiMissingPatternCount = 0`、`CurrentControlledHeroUiDisallowedPatternCount = 0`。
- `npx openspec validate define-fantasyword-foundation-framework --strict` 通过。
- AIBridge `assets-refresh {"options":"ForceSynchronousImport"}` 成功；Editor 状态为 `isPlaying = false`、`isCompiling = false`、`isUpdating = false`；最近 1 分钟 Console 的 `Error = []`、`Exception = []`。
