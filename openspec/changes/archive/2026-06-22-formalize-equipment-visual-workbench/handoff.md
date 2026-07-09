# Handoff: formalize-equipment-visual-workbench

## 当前状态快照

- `npx openspec validate formalize-equipment-visual-workbench --strict` 已通过。
- `editor-application-get-state` 曾返回 `isPlaying=false`、`isCompiling=false`、`isUpdating=false`。
- `assets-refresh '{"options":"ForceSynchronousImport"}'` 已成功。
- `scene-open '{"sceneRef":{"assetPath":"Assets/Scenes/EquipmentSystemDemo.unity"},"loadSceneMode":"Single","bridgeSceneDirtyPolicy":"discard-generated"}'` 已成功，并打开 `EquipmentSystemDemo`。
- 独立 `script-execute` 已回读 active scene：
  - `activeScenePath = Assets/Scenes/EquipmentSystemDemo.unity`
  - `activeSceneName = EquipmentSystemDemo`
  - `sceneCount = 1`
- 最近窗口内 Console `Error = []`、`Exception = []`。
- 已修复阻止 PlayMode 的 3 处编译错误：
  - [DamageDescriptor.cs](/C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Combat/DamageDescriptor.cs)
  - [UICharacter.cs](/C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/UI/Menus/Character/UICharacter.cs)
  - [UIInventoryStats.cs](/C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/UIInventoryStats.cs)
- 已继续修复 AIBridge `editor-application-set-state` 收敛问题：
  - [bridge.py](/C:/Gamedev/Unity/Project/FantasyWord/.codex/skills/aibridge/bridge.py)
  - `set-state` 现在会在 CLI 侧继续轮询 `editor-application-get-state`，等最终状态收敛后再回包，不再把切换前旧状态直接返回给调用方。
  - `editor-application-set-state` 保留执行前脏场景守卫，但跳过执行后/失败后那类易与 PlayMode 切换窗口期打架的 generic dirty-summary `script-execute` 探针。
- 已新增正式 `TMP_FontAsset`：
  - [Silver SDF.asset](/C:/Gamedev/Unity/Project/FantasyWord/Assets/Resources/Fonts/Silver%20SDF.asset)
- PlayMode 运行态实证已确认：
  - 角色数为 5：人类、精灵、矮人、兽人、地精。
  - 左侧是角色 / 动作 / 方向网格，中央无遮挡，右侧是类型 / 装备网格。
  - 当前分类下装备格子带 icon，高亮当前已装备项。
  - 当前字体资源走 `Silver SDF`，底层 `sourceFont = Silver`。
- 运行态探针文件：
  - `Temp/workbench-font-probe.txt`
  - `Temp/workbench-runtime-summary.txt`
- 中文命名复核现态：
  - 正式项目侧目录和资产名已中文化，例如 `换装工作台目录`、`人类帧数据`、`矮人帧数据`、`布衣`、`旅行披风`、`角饰头盔`。
  - 保留 ASCII 的项目前提已明确：动作键和方向缩写仍作为稳定兼容键存在，例如 [EquipmentWorkbenchRuntimeUI.cs](/C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/Presentation/EquipmentSystem/Runtime/UI/EquipmentWorkbenchRuntimeUI.cs:527) 的 `Idle` 查询、[EquipmentWorkbenchRuntimeUI.cs](/C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/Presentation/EquipmentSystem/Runtime/UI/EquipmentWorkbenchRuntimeUI.cs:772) 起的动作键映射、[EquipmentWorkbenchRuntimeUI.cs](/C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/Presentation/EquipmentSystem/Runtime/UI/EquipmentWorkbenchRuntimeUI.cs:799) 起的 `SE/SW/NE/NW` 方向缩写，以及 [EquipmentRenderData.cs](/C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/Presentation/EquipmentSystem/Data/Appearance/EquipmentRenderData.cs:10) 的 `EquipmentType` 代码枚举；这些是代码符号/兼容键，不是面向内容制作的正式中文命名入口。
- 当前 Bridge 核心阻塞已从“scene-open 假失败/残锁导致无法继续”进一步收口到“PlayMode 往返和最终状态回包已稳定，剩余工作应回到换装生产模块本身，而不是桥层”。

## 新会话第一步

先不要继续改 UI 或数据。先确认 Bridge 和 Unity 当前状态：

```powershell
if (Test-Path Temp/UnityBridge/.cli.lock) { Get-Content Temp/UnityBridge/.cli.lock -Raw } else { 'no-cli-lock' }
if (Test-Path Temp/UnityBridge/.scene.lock) { Get-Content Temp/UnityBridge/.scene.lock -Raw } else { 'no-scene-lock' }
if (Test-Path Temp/UnityBridge/heartbeat) { Get-Content Temp/UnityBridge/heartbeat -Raw } else { 'no-heartbeat' }
Get-ChildItem Temp/UnityBridge/commands -Force -ErrorAction SilentlyContinue
Get-ChildItem Temp/UnityBridge/results -Force -ErrorAction SilentlyContinue
python .codex/skills/aibridge/bridge.py editor-application-get-state
```

如果 `heartbeat` 指向的 pid 不存在，或 Unity 窗口处于 `Recovering Scene Backups` / `Opening project` / `Hold on`，不要继续跑场景端到端；先等 Unity 完成加载。

确认 Bridge 状态干净后，下一步不要立刻大改 UI，先看这 3 类已知证据：

1. `Temp/workbench-runtime-summary.txt`：确认 5 个角色和各装备类型选项数。
2. `Temp/workbench-font-probe.txt`：确认运行态字体已走 `Silver SDF / Silver`。
3. `tasks.md` 已全部勾完；若继续做，重点应回到工作台/数据本体是否还要进一步重构，而不是重复验证已通过的桥层烟雾项。
4. 只有在这些现态证据与用户新要求冲突时，才继续改 UI、数据或 bootstrap 逻辑。

## 当前已改文件

- `.codex/skills/aibridge/bridge.py`
  - 新增结果文件读取重试。
  - 新增超时边界结果文件复查。
  - 新增 pid 存活检测，用于清理持锁进程已退出的 stale lock。
- `Packages/com.aibridge.unity/Editor/Tools/Scene.Open.cs`
  - `scene-open` 打开场景后尝试设为 active。
  - 由于 Unity 可能在 `OpenScene(Single)` 后已经激活目标场景，但 `SetActiveScene` 仍返回 false，当前已把这种情况从 hard error 降为 warning。

## 当前已知事实

- `editor-application-get-state` 曾恢复成功，返回 `isCompiling=false`、`isUpdating=false`。
- `scene-open` 曾能实际打开 `Assets/Scenes/EquipmentSystemDemo.unity`。
- 独立 `script-execute` 曾回读到 active scene：
  - `activeScenePath = Assets/Scenes/EquipmentSystemDemo.unity`
  - `activeSceneName = EquipmentSystemDemo`
  - `sceneCount = 1`
- 但 `scene-open` 外层仍曾返回 error，原因是包侧旧程序集或旧判断仍把 `SetActiveScene` false 当失败。最新代码已改为 warning，但尚未完成重新验证。

## 下一步命令

先刷新并确认错误为空：

```powershell
python .codex/skills/aibridge/bridge.py assets-refresh '{"options":"ForceSynchronousImport"}'
python .codex/skills/aibridge/bridge.py console-get-logs '{"maxEntries":20,"logTypeFilter":"Error","includeStackTrace":true,"lastMinutes":10}'
python .codex/skills/aibridge/bridge.py console-get-logs '{"maxEntries":20,"logTypeFilter":"Exception","includeStackTrace":true,"lastMinutes":10}'
```

再验证 `scene-open`：

```powershell
python .codex/skills/aibridge/bridge.py scene-open '{"sceneRef":{"assetPath":"Assets/Scenes/EquipmentSystemDemo.unity"},"loadSceneMode":"Single","bridgeSceneDirtyPolicy":"discard-generated"}'
```

再用 `script-execute` 独立确认 active scene：

```powershell
$code = @'
using System.Collections.Generic;
using UnityEngine.SceneManagement;
public class Script
{
    public static object Main()
    {
        return new Dictionary<string, object>
        {
            ["activeScenePath"] = SceneManager.GetActiveScene().path,
            ["activeSceneName"] = SceneManager.GetActiveScene().name,
            ["sceneCount"] = SceneManager.sceneCount
        };
    }
}
'@; python .codex/skills/aibridge/bridge.py script-execute (@{ csharpCode = $code; bridgeSceneDirtyPolicy = 'discard-generated' } | ConvertTo-Json -Compress)
```

## 不要做的事

- 不要删除或回滚第三方素材、参考工程、`.meta` 或用户未授权的脏工作区变动。
- 不要为换装工作台机械新增 `Assets/Tests`。
- 不要再新增并行测试控制器、并行测试场景或同职责测试 UI。
- 不要把 GAS 字符串、测试字符串或 UI 枚举当正式装备定义。
- 不要把 Bridge 截图失败直接等同于换装模块失败；先用对象和字段回读验证运行态。
