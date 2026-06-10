# PlayerSystem 恢复记录（2026-03-12）

## 本轮原则

- 旧工程 `PlayerSystem.cs` 已损坏，不能直接复用
- 参考文件虽完整，但 persistence / database / notification 依赖明显超出当前工程宿主
- 因此本轮采用：
  - 保留参考职责
  - 去掉当前工程不存在的 persistence 依赖
  - 接到现有 `Hero` / `GameManager.Player` / `PlayerEvents` / `UISystem` 体系

## 本轮完成

- 新增 `Assets/Scripts/Game/Systems/PlayerSystem.cs`
  - 负责发现当前场景 Hero
  - 可选地使用 dummy prefab 实例化玩家
  - 维护 `PlayerInstance`
  - 在玩家死亡时清理对话和菜单栈
- 扩展 `Assets/Scripts/Game/GameManager.cs`
  - 增加 `PlayerSystem` 静态入口

## 编译验证

- `RecoveryNotes/unity-batch-compile-20260312-22.log`
- 结果：通过

## 差集更新

- 本轮前剩余：`16`
- 本轮后剩余：`15`

## 下一步建议

1. 优先处理 `Spawners/*`
2. 或转向 `InputSystemGenerator.cs` / `MultiTrack.cs`
3. `UISave*` / `UIMainMenu` 继续后置
