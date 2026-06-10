# Test Dressing Scene Host And Starting Gear - 2026-03-12

## Scope
- 只为当前仓保留一张可用的测试换装场景：`Assets/Scenes/SampleScene.unity`
- 不继续推进 `Main Menu`、村庄或森林场景

## What Changed
- 把 `Assets/Scripts/Game/GameManager.cs` 恢复为可挂载 `MonoBehaviour`，保留 `GameManager.Player` / `GameManager.Config` / 系统快捷入口
- 对齐 `Hero` / `FollowTargetDirection` / `CameraShake` / `UIMovementIndicator` / `UIFloatingIcon` / `UICharacterInfo` 的脚本 GUID
- 迁入并补齐角色宿主链：
  - `Assets/Prefabs/Entities/0_Entity_Base.prefab`
  - `Assets/Prefabs/Entities/Characters/0_Character_Base.prefab`
  - `Assets/Prefabs/Entities/Characters/Heroes/0_Hero_Base.prefab`
  - `Assets/Prefabs/Entities/Characters/Heroes/Devon.prefab`
- 迁入角色相关轻资源：
  - `SLIB_Default.spriteLib`
  - `SLIB_Devon.spriteLib`
  - `SLIB_Floating_Icons.spriteLib`
  - `SPS_Character.png`
  - `SPS_Devon.png`
  - `SPS_Hands.png`
  - `SPS_Floating_Icons.png`
  - `Blob_Shadow.png`
  - `AC_Character.controller`
  - `ANIM_Character_*`
  - `WorldSpaceEffectIcon.prefab`
  - `AUDIO_ISFX_Interact.asset`
  - `AUDIO_ISFX_Level_Up.asset`
- 本地新建最小 `Assets/Database/Characters/Heroes/CS_Devon.asset`
- 将 `Devon.prefab` 的旧字段 `m_sheet` 改为当前字段 `m_characterSheet`
- 新建测试装备：
  - `Assets/Database/Items/Gear/ITEM_Iron_Helmet.asset`
  - `Assets/Database/Items/Gear/ITEM_Iron_Plate.asset`
  - `Assets/Database/Items/Gear/ITEM_Iron_Boots.asset`
- 把三件装备写入 `Assets/Scenes/SampleScene.unity` 的 `Inventory System.startingItems`

## Validation
- GUID 扫描：
  - `Assets/Prefabs/Entities/Characters/Heroes/Devon.prefab`: `1 -> 0`
  - `Assets/Prefabs/Entities/Characters/Heroes/0_Hero_Base.prefab`: 仅剩 Unity 内置材质 GUID `0000000000000000f000000000000000`
  - `Assets/Scenes/SampleScene.unity`: 仅剩 Unity 内置环境 GUID `0000000000000000e000000000000000`
- Unity Roslyn：
  - 直接运行 `Assembly-CSharp.codex-validate.rsp` 仍会复现旧的 rsp 漏源文件问题
  - 显式追加 `AudioChannel.cs` / `GameStateSystem.cs` / `NotificationSystem.cs` / `PersistenceSystem.cs` / `IUIMenu.cs` / `EItemTransferType.cs` / `AudioClipResolver.cs` 后通过

## Remaining Risk
- 还缺一次 Unity Editor 内的真实进场验证
- 当前测试装备先覆盖“有物可穿、可进装备槽、属性可流转”，未继续追整套角色外观替换资源
