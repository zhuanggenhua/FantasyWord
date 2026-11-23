# ClickMoveTest 初始装备详情

从正常 F5 进入 ClickMoveTest，在暂停菜单打开 Items，鼠标进入或方向键聚焦原版初始武器、躯干装备槽时显示共享 Item Details。移到空白或点击非选择区域不关闭；聚焦空槽、主动指针移到分类按钮或退出菜单关闭。只在可见详情图形范围拦截下层命中。

使用锁定 Unity 提交 `31629d53a110dd4c87d4c85e6ad5a387fbafb931` 的 `User Interface.prefab` 中 Overlay 下的 Item Details 实例。图标、描述、图集和锚点从实际 Prefab/装备资产复现，不含重新制作的底图或补写内容。布局契约由 `tools/extract_clickmovetest_item_details.py` 生成到私有来源目录；不将原始素材和契约数据提交。缺少合格契约时保留已有背包路径，不提供替代详情。

标题仍取原版装备名称，但原始名框高 50、字体 48、Ellipsis、无自动调字号；Silver 后备字体在该字号的首行高度约 53.05。按 [Unity uGUI 的 TMP 垂直溢出逻辑](https://github.com/Unity-Technologies/uGUI/blob/6000.3/com.unity.ugui/Runtime/TMP/TextMeshProUGUI.cs#L3063-L3142)，第一字在任何可插省略号的候选之前已触发溢出，因此这里预测画面不绘标题，没有自行放宽框或改变字号。实际 Unity 截图尚未验收。描述的原始框高 96，两个初始描述分别能在一行放下；不声称迁移了任意长描述换行或 Unity SDF 像素一致。非空背包、其他物品类型、物品使用、换装、对话遮盖与存读档未纳入本次。

定向验证：`tests/test_source_inventory_entry.gd` 走正常主场景输入，验证从背包空态、聚焦实际初始装备、详情覆盖范围、键盘切换、窗口纵向匹配和返回，非 headless 验证原图标、字体和覆盖渲染。无私有契约时明确跳过详情验收。
