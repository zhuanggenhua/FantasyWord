# 原换装工作台：人类服装预览
锁定源为 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931` 的 `Assets/Scenes/EquipmentSystemDemo.unity`、`UIEquipmentWorkbench.prefab`、`换装工作台目录.asset`、`布衣.asset` 和 `EquipmentWorkbenchController/RuntimeUI`。这是原有的独立场景，不改变默认 F5 的 ClickMoveTest，也没有入口混入正式游戏菜单。

## 运行
从 Godot 工程显式打开 `res://gameplay/equipment_workbench/equipment_system_demo.tscn` 并运行当前场景，或运行 `godot --path godot res://gameplay/equipment_workbench/equipment_system_demo.tscn`。需要持有原授权资源：
- `FANTASYWORD_WORKBENCH_SOURCE`：放有原场景/源版本标识的 `workbench.json`（`scene: Assets/Scenes/EquipmentSystemDemo.unity`，`source_commit` 为上述完整提交），以及原动画合同 `animation.json` 和材质合同 `material.json`。使用 `godot/tools/extract_formal_human_animation.py` 和 `extract_formal_human_material.py`，二者均带 `--include-attack`，生成恰好 Idle/Walk/Attack 三项。工作台目录与这套动画共用同一人类帧数据、基础外观、共享状态机和四向精灵库。
- `FANTASYWORD_WORKBENCH_HUMAN_ART`：对应原始人类图集；同目录下的 `uv/` 与 `appearance/` 按材质提取器定义提供原图。 `FANTASYWORD_WORKBENCH_CLOTH`：源装备 `布衣.asset` 指向的 `精灵-0001.png`。
- `FORMAL_PANEL_SILVER` 和 `FORMAL_PANEL_CJK`：已经用于原界面验证的两种私有字体。本场景校验两者哈希及服装哈希。不提交素材，也不以占位资产替代缺失的原件。

## 迁移及验收范围
人类进场默认东南待机、穿布衣。通过实际按钮卸下及重穿，驱动渲染器的布衣层，详情和状态徽章同步。卸下显示「当前为空」，重穿显示「已装备」与预览目录的「生命 +6」，不写玩家库存、生命数值、装备栏或存档。支持选择原待机、行走、攻击与四向动画；重选人类恢复初始外观。当前只迁移这一组，不启用等待和形象切换；其他角色/形象、动作、装备、坐骑、完整原图标合成和 Unity 同场画面比对仍未验收。

`godot --path godot --script res://tests/test_equipment_workbench_demo.gd`：给齐私有输入时驱动真实 Godot Viewport 鼠标按钮；非 headless 额外比较同一实际显示帧的脱衣像素差分和重穿复原。干净环境验证没有私有素材时不放置假角色，默认入口仍为 ClickMoveTest。局部像素差分仅验证工作台真实改变渲染，不代表整屏布局与 Unity 像素一致。
