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
- **尚未接入移动运行时**：测试替身只验证命令与回调，不证明角色已经在地图里移动。原
  [输入系统](../Assets/Scripts/GameCore/Runtime/Game/Systems/InputSystem.cs) 与
  [Input Actions](../Assets/InputSystem_Actions.inputactions) 的按键、释放、UI 挡点和世界坐标转换，
  实际角色物理、合法落点、场景地图导航、镜头及动画是独立待验收项。
- 原 [Unity 构建场景列表](../ProjectSettings/EditorBuildSettings.asset) 把 ClickMoveTest 排第一，表示适合做首个输入闭环对照；
  不把它认定为完整游戏，也不把局部测试当作角色美术、地图或整局验证。

本分支只新增 Godot 迁移代码、测试和说明。不重发项目原始第三方素材，也不将测试替身当成最终玩法。
