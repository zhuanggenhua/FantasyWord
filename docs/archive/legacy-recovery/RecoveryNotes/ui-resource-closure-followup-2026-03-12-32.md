# UI Resource Closure Follow-up - 2026-03-12

## 本轮目标
- 收口 `User Interface.prefab` 整条 UI 资源闭包的尾部缺口
- 把参考宿主扫描压到只剩内置占位或外部孤儿 GUID

## 关键动作
- 对齐剩余 10 个 UI 脚本 meta GUID：
  - `UIHUDAbilityBarEntry.cs.meta`
  - `UIStatBar.cs.meta`
  - `UIAbilityBarEntry.cs.meta`
  - `UINavigationCursorTarget.cs.meta`
  - `UIAbilityListEntry.cs.meta`
  - `UIIngredientEntry.cs.meta`
  - `UIRecipeEntry.cs.meta`
  - `UIJournalQuestEntry.cs.meta`
  - `UIShopEntry.cs.meta`
  - `UIEffectListEntry.cs.meta`
- 迁入尾部资源闭包：
  - `Ability.prefab`
  - `Effect List Entry.prefab`
  - `EffectIcon.prefab`
  - `Bag item Slot.prefab`
  - `Category Entry.prefab`
  - `Equipment Slot.prefab`
  - `ItemNavigationCursorStyle.asset`
  - `SPS_Armors.png`
  - `SPS_Effects.png`
- 将 `Dialogue.prefab` 两处 `Button.SpriteState.m_HighlightedSprite` 的孤儿引用清零
- 把当前 `Library/PackageCache` 纳入 GUID 扫描，消除 `UGUI` / `TMP` / `InputSystem` 的假阳性缺口
- 重新运行 Unity Roslyn：`Assembly-CSharp.codex-validate.rsp` + 11 个显式追加源码，退出码 `0`

## 结果
- 参考宿主缺口收口为：
  - `M2DEngine.unity`: `1`，仅剩 `0000000000000000e000000000000000`
  - `Main Menu.unity`: `3`，剩余 `0000000000000000e000000000000000`、`357186adf88f47441beed107c9dbbe69`、`6a160d838ff8b4b4693ac20007e008c7`
  - `User Interface.prefab`: `1`，仅剩 `0000000000000000f000000000000000`
- 当前 `Assets/Prefabs/UI/**/*.prefab` 内部扫描只剩 6 个 `0000000000000000f000000000000000` 占位 GUID，分布在：
  - `Abilities Menu.prefab`
  - `Craft Menu.prefab`
  - `Game Menu.prefab`
  - `Journal Menu.prefab`
  - `Shop Menu.prefab`
  - `User Interface.prefab`

## 关键判断
- `UIEffectListEntry.cs.meta` 如果不对齐到 reference GUID，`Effect List Entry.prefab` 会持续残留 `Missing Script`
- `d1c8e0eaf60c6b84bb4a7d47f400c8d1` 对应 `Mythril2D/Demo/Sprites/SPS_Effects.png`
- `7a7a06017d45ec84f9010d833ee328cb` 只出现在 `Dialogue.prefab` 的两个 `Button` 的 `SpriteState.m_HighlightedSprite`
- reference 与旧项目都找不到 `7a7a...` 的 `.meta`；这不是当前仓可恢复的真实资产
- 这两个 `Button` 的 `m_Transition = 1`，运行时走 `ColorTint` 而不是 `SpriteSwap`，因此清零 `m_HighlightedSprite` 不改变行为
- GUID 扫描如果不包含当前 `Library/PackageCache`，会把 `CanvasScaler`、`Image`、`Button`、`TextMeshProUGUI`、`InputSystemUIInputModule`、`PlayerInput` 等包内宿主误判为缺口
