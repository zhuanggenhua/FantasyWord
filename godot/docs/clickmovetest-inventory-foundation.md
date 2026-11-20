# ClickMoveTest：原角色背包的运行时与布局基线

- 源依据：Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`，`PlayerSystem`、`CharacterInventory`、`InventorySystem`、`UIInventory`、`UIInventoryBag` 与原嵌套预制体。正常 ClickMoveTest 启动建立一份空库存，以实际玩家持久 ID `Character:player` 查询；不是场景 UUID，不读队伍货币，不把初始长矛或布衣放进背包。
- 数据层按实物资源身份计数，增减事件保留原转移类型和实际增减量。用独立快照填格，不按名称排序。条目移除后允许重用已空的枚举位置；尚未在 Unity 编辑器实机逐序重放删插。30 格是当前分类的展示上限，不限制库存。
- 面板数据层打开重置 Consumable，焦点位于首格。切换分类先清除旧详情，再刷新格子；选中不会使用物品，空格没有使用请求。非空格给接收端传原 actor、同一 target 和 Bag 位置；尚未执行真实 Item.Use、使用锁、装备或存档逻辑。
- `tools/extract_clickmovetest_inventory_layout.py --repo <锁定 Unity Git 树> --out <私有输出>` 复算继承布局、图集引用、分类文字、装备栏、摘要行、焦点框。输出不入库。1920×1080 下首格 (968.5,340) 96×96，6×5、间距 8；四个分类按钮各 188×72 且重叠 24，五个装备格区分从背包中取出的物品，八行摘要按内容尺寸运算。
- 运行 `godot --headless --path godot --script res://tests/test_source_inventory_bags.gd`；私有合同齐备时另验证正规 F5 实际玩家归属。**此阶段不是 Pause→Inventory 可玩面板**；原图标和文字的装配、实际选格输入、原物品效果及跨引擎截图仍要完成。
