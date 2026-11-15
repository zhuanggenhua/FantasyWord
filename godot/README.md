# FantasyWord 的 Godot 迁移

在 `godot/` 中逐段接通原有游戏。Unity 基线为提交
`31629d53a110dd4c87d4c85e6ad5a387fbafb931`；主分支、Unity 工程和原文档不改动。
原设计继续以[项目知识库](../.spec/knowledge/README.md)为准，不复制出第二套设计规范。
现阶段优先核对[小体量幸存者动作测试场](../.spec/knowledge/features/project/用户故事_小体量幸存者动作测试场_2026-07-09.md)，不先补开放世界、联机或未来框架。

## 运行和验证

Godot 项目入口是 `godot/project.godot`，目前以 Godot 4.7.2 验证模块，尚无正式主场景。
在仓库根目录执行：

```sh
GODOT=/path/to/godot bash godot/tests/run.sh
node .spec/tools/spec-lint.mjs
```

测试使用独立临时用户目录，不会碰玩家存档。用 Godot 编辑器导入时请选择
`godot/project.godot`，不要选择 Unity 仓库根目录。

## 当前迁移范围

- **角色侧移动命令**：移植了方向/点击模式门禁、切换清理、动作锁定、有图路径成功或失败、无图时由角色修正合法落点再提交直线路径。按
  [CharacterMovement.cs](../Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterMovement.cs)
  的调用顺序验证。
- [基础角色预制体](../Assets/Prefabs/Entities/Characters/0_CharacterActor_Base.prefab)默认为方向模式、停止距离为
  0.05 世界单位；[ClickMoveTest](../Assets/Scenes/ClickMoveTest.unity) 的测试面板另外把启动模式设为点击。
  前者是角色默认，后者是场景行为，不混为一谈。
- **战斗规则**：移植了阵营、无敌及死亡门禁，以及伤害缩放、防御、暴击和闪避计算；尚未接到原版 GAS 的扣血和技能执行链。见[战斗迁移边界](combat-port.md)。
- **已解析的移动事件到单角色命令**：迁移了方向动作屏蔽、释放直接停止、点 UI 不发移动命令、
  真正投影后再下达点击命令，以及角色控制锁、执行器停用、错误角色、缺坐标等各自的拒绝原因。
  对应[输入系统](../Assets/Scripts/GameCore/Runtime/Game/Systems/InputSystem.cs)和
  [角色命令执行器](../Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterCommandExecutor.cs)。
  回归从已解析的事件跑到角色移动组件；原始设备、真实相机和 UI 命中仍是替身。
- **有序键盘与角色移动意图**：WASD 和方向键保持独立，不混合为额外的斜向；松开活跃按键组时，
  向仍按住的一组交接，最后归零才发独立停止命令。Godot Viewport 测试贯通键盘事件、角色命令及原版
  动作意图的加减速和停止清理。见[键盘输入](keyboard-input-port.md)与[移动计算](movement-port.md)。
- **航点和位移请求**：按 `Movable.MotionRuntime` 的原顺序执行航点，区分到达、失败和被新命令取消；
  探测整向受阻后尝试 X、Y，并保留失败探测的碰撞对象。宿主只接收位移请求，到点仍以宿主实际观察的位置为准。
  半径、场景地形和坐标转换未接入；这不是可游玩的主场景。见[移动计算和执行](movement-port.md)。
- **场景运行仍待验收**：真实设备、地图、角色、相机和表现尚未连通，手柄、设备切换、重绑和焦点未验收。
  [场景验收表](runtime-acceptance.md)保留了原仓库的点击移动、转角和 GAS 验证判据；
  独立地形查询探针只验证 Godot 物理 API，不代替正式场景。
- [Unity 构建列表](../ProjectSettings/EditorBuildSettings.asset)把 ClickMoveTest 的路径写在第一项，
  但它、EquipmentSystemDemo、SampleScene 的列表 GUID 都和各自的实际 `.meta` 不符，
  不能据此确定实际运行顺序。按[运行时入口文档](../.spec/knowledge/features/project/框架与运行时入口.md)，
  SampleScene 是正式场景候选；ClickMoveTest 只用作点击移动参照。
  后续原主分支提交 `1b9498e` 将 Unity 版本升至 6000.6.0f1、Input System 升至 1.20.0，
  本轮锁定基线仍为 6000.3.10f1 / Input System 1.18.0。两个提交的这三份场景、输入绑定与所用业务代码未变，
  不据此等同原生输入和物理行为。

本分支只新增 Godot 迁移代码、测试和说明。不重发项目原始第三方素材，也不将测试替身当成最终玩法。
