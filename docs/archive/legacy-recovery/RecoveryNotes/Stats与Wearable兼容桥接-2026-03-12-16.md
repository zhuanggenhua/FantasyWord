# Stats 与 Wearable 兼容桥接记录（2026-03-12）

## 本轮原则

- 这批不属于“损坏文件直接迁参考”的情况，而属于“当前工程已有更优同职责实现”的情况
- 因此按用户要求走“完好文件先择优”的分支：
  - 不复制第二套并行主实现
  - 直接桥接到当前已在项目中稳定工作的 `Stats` / `Equipment`

## 本轮完成

### Stats

- 将 `Assets/Scripts/Entities/Stats.cs` 改为 `partial`
- 新增 `Assets/Scripts/Combat/Stats.cs`
  - 仅作为缺失路径的桥接文件
  - 真实实现继续以当前 `Entities/Stats.cs` 为准
- 新增 `Assets/Scripts/Combat/ObservableStats.cs`
  - 保留参考工程里的职责：封装 `Stats`，并在变化时发出 `UnityEvent<Stats>`

### Wearable

- 新增 `Assets/Scripts/Game/Wearable.cs`
- 直接桥接到当前 `Equipment` 体系

## 编译验证

- `RecoveryNotes/unity-batch-compile-20260312-21.log`
- 结果：通过

## 差集更新

- 本轮前剩余：`19`
- 本轮后剩余：`16`

## 下一步建议

1. 继续处理 `PlayerSystem.cs`
2. 或进入 `Spawners/*`
3. `UISave*` / `UIMainMenu` 继续后置
