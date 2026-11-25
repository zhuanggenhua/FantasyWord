# 原角色菜单：明确的角色与预览状态

原暂停动作 5 发出 `RequestCharacterMenu(ViewCharacter(currentControlledOrPrimary))`；
UI 根登记 EMenu 1 的 UICharacter。面板接收的是打开时的明确角色，不是虚构角色、
当前血量面板或另一份可变角色数据。

原面板绑定 Health、Mana、PhysicalAttack、MagicalAttack、PhysicalDefense、
MagicalDefense、Agility、Luck 八行，按这个顺序，没有 AttackSpeed 行。
Health 与 Mana 显示有效基础属性（上限），不是受击后的 HP 或消费后的 MP。
源 ClickMoveTest 同一原角色当前无等级成长、累计经验和已用点数；表上的空
displayName 回退为该资源的 `玩家角色配置`。起始等级 1、到下一级经验差 0、
可分配点 0。实际 Combat 角色的基础属性读入菜单状态，而不是在界面再造一份。

`source_character_panel_state.gd` 迁移打开/隐藏与临时分配：预算从 Actor 读，
加减只改本次预览，Apply 才调用 Actor 的写入端口并刷新。真实当前角色没有
可用点数；未挂通通用成长/自定义属性写入。空绑定清空角色文本而仍显示
InventorySystem 的 DefaultParty 货币。已实现实际宿主的队伍货币字段，
未迁移物品集合、装备加成、奖励或背包存档。

`extract_clickmovetest_character.py` 锁定原 UICharacter 复用预制体的行 ID、
源角色预制体链和角色表，只写到私有合同目录。正常 F5 已通过实际 Pause 动作 5
装配同一角色与队伍钱袋、退出后恢复原 Pause 焦点和 gameplay route。未提供合同
时不生成替代角色面板。

## 布局与原始术语

`extract_clickmovetest_character_layout.py` 解析 Base Menu 根拉伸和安全区，
从原 LayoutGroup、ContentSizeFitter、预制体覆盖、实际子对象顺序逐级计算
参考画布。在 1920×1080 下，左列为 (308.5,317) 的 755×512 八行，
右列为 (1163.5,317) 的 448×496；Apply 外框 (1163.5,701,448,112)，
文字四边各内缩 20。原 Apply Image 使用同一 SPS_GUI 图集中的五态 SpriteSwap，
不是颜色近似，也不是平铺；对应 Godot 切片绘制已按原素材和边框验证。

原 ClickMoveTest 的 GameConfig 术语表为空；UITerm 用 GetTermDefinition 而非
安全回退或 FormalAttributeCatalog。八条属性及四条信息使用原无效简称，
经验行保留原 ` Req.` 格式，货币使用无效全称，属性图标没有指定 sprite。
这不是可擅自用英文行名修复的迁移遗漏。需要继续核实并呈现长词的 TMP
省略规则、Null Sprite 绘制和精确居中。TMP 主字体为 RPGSystem SDF，
TMP Settings 的默认字体为动态 Silver SDF，其次才是 Noto CJK；现有角色名与
Apply 所需汉字都在原 Silver.ttf 中。合同确认来源，不等于中文光栅或面板
原生交互已验收。

首次显示按 UICharacter 原规则选中 Health 的减号；加号、减号和 Apply 即使
没有可用点也保留导航、按下反馈和命中，动作由状态层拒绝。自动导航以 Unity
Selectable 的出边中点到目标中心评分：加号右转可达 Apply，Apply 左转到
Agility 加号、上转到 Health 加号，没有环绕。当前定向测试覆盖面板内所有 68 条方向边与零点不写入；真实 Pause 返回须在
完整入口接线后验证保留原焦点。原 uGUI 在全局活跃 Selectable 中找候选，已装配技能
HUD 的冷却 Slider 可能影响面板底部边界；仅凭面板测试不宣称全局无候选。

同一编辑器版本系列的 Unity uGUI 6000.3 TMP 源码可推导：八条属性窄框中显示
`[INVALID_…`，右列信息标签显示 `[INVALID…`。源角色 Class 字段仍读取
`玩家角色配置`，但其 Silver 行高约 70.74，大于 64 高的 Ellipsis 框，首字前无
可用候选，预测留空，不用缩字号硬塞。Apply 48 点字形混用原 RPGSystem 的
数字与空格、Silver 的汉字，保留两字体合并基线。现为定向布局检查：动态 Silver
暂用经哈希校验的原 TTF，由 Godot 绘制；Unity 序列化 Silver SDF 中的省略号和
「点」有源字形可进一步复用，「应」「用」仍需实际动态 SDF 证据。

## 私有运行与验收

在锁定 Unity Git 树（使用原 Pause/Settings 同一套私有目录）重新生成：

```sh
python godot/tools/extract_clickmovetest_character.py --repo "$SOURCE_REPO" --output "$FORMAL_PAUSE_SOURCE/character-contract.json"
python godot/tools/extract_clickmovetest_character_layout.py --repo "$SOURCE_REPO" --output "$FORMAL_PAUSE_SOURCE/character-layout.json"
```

沿用 `FORMAL_PANEL_SILVER` 的锁定原文件。用正常项目入口选 Pause 的 Character 图标。
Godot 4.7.2 云端原生桌面：角色入口 25/25，包括真实菜单切换、鼠标释放、
健康默认焦点、零点保护、返回、重新打开、可见 title/Apply/箭头像素；既有 Settings
入口同环境回归 25/25。宽画布按高度匹配，背景铺满支持的参考宽 4096 以内，角色列
居中、左右提示贴边；不是 Unity 同帧画面对照。尚未验收正点成长写回、完整全局
HUD/手柄导航、字体精确栅格和原版实机像素。

### 原 Apply 按钮确认反馈

继承的原 `UI/Generic/Button.prefab` 启用 SpriteSwap，确认键先调用 Apply，
再使用 0.1 秒不缩放时间显示按下图。没有可用属性点时，源按钮也仍可交互，
显示反馈但不写入任何属性。鼠标保留按下和同格释放规则，离开焦点或页面
不会保留旧按下图；不添加经验、奖励或属性点来源。
