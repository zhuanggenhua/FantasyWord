# Sample Scene Dressing Test Host - 2026-03-12

## 本轮目标
- 不再继续推进多场景恢复
- 只保留一张可用于测试换装/背包/UI 链的场景

## 执行动作
- 将 `Assets/Scenes/SampleScene.unity` 的内容替换为 `Mythril2D/Demo/Scenes/M2DEngine.unity` 的宿主骨架
- 保留原 `SampleScene.unity.meta`，不改场景 GUID 与工程内路径
- 重新扫描 `SampleScene.unity` 的直连 GUID 缺口
- 核对 `ProjectSettings/EditorBuildSettings.asset` 当前启用场景
- 核对场景内关键宿主：
  - `Inventory System`
  - `Player System`
  - `UI System`
  - `Journal System`
  - `Game Manager`
  - `Map System`
  - `Save System`
  - `Input System`

## 结果
- `SampleScene.unity` 当前已经是测试换装宿主场景
- `EditorBuildSettings.asset` 中唯一启用场景仍为 `Assets/Scenes/SampleScene.unity`
- `SampleScene.unity` 直连缺口为 `1`：
  - `0000000000000000e000000000000000`
- `Player System` 已配置：
  - `m_dummyPlayerPrefab -> Devon.prefab`
- `UI System` 已配置：
  - `m_uiPrefab -> User Interface.prefab`

## 结论
- 当前工程已经具备一张单独的换装测试场景，不再需要继续恢复 `Main Menu` 或其它地图场景
- 后续如果继续做场景层工作，只应在 `Assets/Scenes/SampleScene.unity` 上做定点装配与实测
