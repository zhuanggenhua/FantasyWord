# 原换装工作台：人类服装、披风、背包与头部装备预览
锁定源为 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931` 的 `Assets/Scenes/EquipmentSystemDemo.unity`、`UIEquipmentWorkbench.prefab`、`换装工作台目录.asset`、`布衣.asset` 和 `EquipmentWorkbenchController/RuntimeUI`。这是原有的独立场景，不改变默认 F5 的 ClickMoveTest，也没有入口混入正式游戏菜单。

## 运行
从 Godot 工程显式打开 `res://gameplay/equipment_workbench/equipment_system_demo.tscn` 并运行当前场景，或运行 `godot --path godot res://gameplay/equipment_workbench/equipment_system_demo.tscn`。需要持有原授权资源：
- `FANTASYWORD_WORKBENCH_SOURCE`：放有原场景/源版本标识的 `workbench.json`（`scene: Assets/Scenes/EquipmentSystemDemo.unity`，`source_commit` 为上述完整提交），以及原动画合同 `animation.json` 和材质合同 `material.json`。使用 `godot/tools/extract_formal_human_animation.py` 和 `extract_formal_human_material.py`，二者均带 `--include-attack`；保留旧版 Idle/Walk/Attack 三项合同只打开布衣预览。要验收披风，二者额外带 `--include-damage`，并在同一目录额外提供下面的披风合同和原图。工作台目录与这套动画共用同一人类帧数据、基础外观、共享状态机和四向精灵库。
- `FANTASYWORD_WORKBENCH_HUMAN_ART`：对应原始人类图集；同目录下的 `uv/` 与 `appearance/` 按材质提取器定义提供原图。 `FANTASYWORD_WORKBENCH_CLOTH`：源装备 `布衣.asset` 指向的 `精灵-0001.png`。
- `FORMAL_PANEL_SILVER` 和 `FORMAL_PANEL_CJK`：已经用于原界面验证的两种私有字体。本场景校验两者哈希及服装哈希。不提交素材，也不以占位资产替代缺失的原件。

### 披风原图与合同
在私有目录放置授权的 `clock1.png` 到 `clock8.png`、`斗篷.png`、`斗篷1.png`。它们来自锁定提交的 `Assets/ThirdParty/MiniFantasyUV/ImportedSource/Art/equip`（不要用近似的同名 Art/equip）。运行：

```sh
python godot/tools/extract_workbench_cloaks.py /path/to/Unity-repository /path/to/private-workbench-source
```

提取器按原 Git LFS 指针核对每张图片哈希与长度，读取原目录及两件装备的序列化数据、每帧人类躯干朝向及变体，生成本地 `cloak.json`；合同和原图不入库。指定了四动作合同却缺配套披风时拒绝进入，不以假图补齐。

### 可选小背包合同
若要启用原小背包选项，把锁定提交 `Assets/ThirdParty/MiniFantasyUV/ImportedSource/Art/equip` 的两张授权原图
`YellowBackpacks_facingfront.png` 和 `YellowBackpacks_facingback.png` 单独放在私有目录：
```sh
python godot/tools/extract_workbench_bag.py /path/to/Unity-repository /path/to/private-bag-source
export FANTASYWORD_WORKBENCH_BAG=/path/to/private-bag-source
```
合同核对 LFS 哈希、长度、两张实际 160×128 图集，以及原四个 Sprite fileID 的 32×32 矩形；UV 只翻一次 Y。需要同时提供四动作披风合同以复用躯干采样。未设置背包路径保持原先布衣/披风模式，指定无效合同不会用替代素材。

### 可选头盔、帽子与面罩合同
将锁定提交的 `Assets/ThirdParty/MiniFantasyUV/ImportedSource/Art/equip` 中 `HelmetDesigns.png`、
`鹿头盔.png`、`鹿头盔2.png` 至 `鹿头盔4.png`、`hat_yellow1.png` 至 `hat_yellow4.png`、`glasses1.png` 至 `glasses3.png`
放入授权使用的私有目录，再运行：
```sh
python godot/tools/extract_workbench_headwear.py /path/to/Unity-repository /path/to/private-headwear-source
export FANTASYWORD_WORKBENCH_HEADWEAR=/path/to/private-headwear-source
```
提取器只生成精确材质合同，不复制素材。图集大小按原实际 PNG 高宽，逐字校验材质引用的文件、SHA 和 Unity Sprite ID；两个铁盔共享 512×608 原图集，使用不同列。

## 迁移及验收范围
人类进场默认东南待机、穿布衣。通过实际按钮卸下及重穿，驱动渲染器的布衣层，详情和状态徽章同步。卸下显示「当前为空」，重穿显示「已装备」与预览目录的「生命 +6」，不写玩家库存、生命数值、装备栏或存档。支持选择原待机、行走、攻击与四向动画；重选人类恢复初始外观。披风类别迁移来源目录中的旅行披风（体质 +1、魔力 +2）和厚斗篷（体质 +2、生命 +4）。二者虽同 numeric ID，仍按各自原视觉资源替换同一个披风槽，不改布衣。厚斗篷跟随原 Dmg 前两帧的 Torso Left 变体，末两帧回 Base；后向缺帧及 Right 无 SE 按原回退。工作台受伤预览停留末帧，不触发玩法伤害或自动回待机。重选人类恢复原默认布衣和空披风。装备按钮预览图取该披风原有效图；未迁移完整原图标合成与全量界面。

小背包沿用原独立装备槽和详情「生命 +2、魔力 +3」。默认无背包；穿脱不改布衣和披风。南向仅在原躯干透明底图时走早绘制；北向根据原躯干朝向在武器之后再画一次，不要求启用武器。工作台图标取原 SE 裁片，按原 alpha 裁切后缩放居中。Godot 原生窗口附加验证四向穿脱、同帧像素复原和北向背包实际盖过披风；两个着色器版本另有无武器合成回归。

头部工作台保留源三列分类网格和独立头盔、帽子、面罩页。角饰头盔、铁盔 I/II、轻帽和护目镜依原类型互相替换，空分类的卸下不移除其它分类。头盔/帽子共用 Helmet 层，面罩独立；原人类头发、胡须按选项分别保留或隐藏，并在每次原头部帧采样时重新求值。四向护目镜贴图、铁盔的不同 atlas 列、行动后发须保留和移除后复原已纳入 Godot 原生测试；不改变正式场景的默认外观或装备逻辑。

等待、其他动作、其他角色/形象及装备、坐骑、工作台完整轮廓与整屏布局、Unity 同场画面逐项对比仍未验收。

`godot --path godot --script res://tests/test_equipment_workbench_demo.gd`：给齐私有输入时驱动真实 Godot Viewport 鼠标按钮；非 headless 额外比较同一实际显示帧的穿脱衣服和披风像素差分及复原。披风覆盖两种选项替换、独立穿脱、四向 Dmg 的 16 个采样、末帧维持及 Right 回退。干净环境验证没有私有素材时不放置假角色，默认入口仍为 ClickMoveTest。局部像素差分仅验证工作台真实改变渲染，不代表整屏布局与 Unity 像素一致。
