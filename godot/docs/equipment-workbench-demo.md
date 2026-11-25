# 原换装工作台：人类装备预览
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

### 可选武器与盾牌合同
私有目录需要原 `长矛1.png`、`shield2.png` 至 `shield5.png`（MiniFantasyUV ImportedSource）与原人类目录的 `Slash_sword_f.png`、`Slash_sword_b.png`。
后一对是「长矛」实际序列 GUID 引用，不以同名或相似的突刺资源替换。
完整四件配置还需要 ImportedSource 中的 `axe.png`、`shield.png`、`shield0.png`，以及原 `Assets/Art/武器/迷你幻想_武器_v3.0/迷你幻想_武器_素材/劈砍_攻击/斧` 中的 `劈砍_斧_f.png` 和 `劈砍_斧_b.png`。仅拥有前七张时，已有双件合同仍可用；提取时加 `--legacy-pair` 可重建同一合同。
```sh
python godot/tools/extract_workbench_weapons.py /path/to/Unity-repository /path/to/private-weapon-source
export FANTASYWORD_WORKBENCH_WEAPONS=/path/to/private-weapon-source
```
提取器核对原图、图集 Sprite ID、作者方向和每帧锚点，生成的私有合同不入库。只有原工作台给齐合同才使用武器填充材质，正式 ClickMoveTest 默认不受影响。

### 独立战马无装备骑手验收
原普通工作台角色没有正式 `CharacterEquipment`，不能穿戴坐骑；Unity 的 `MountRuntimeGameViewValidator` 会改用正式玩家，再经工作台按钮写入 `Mount` 槽。Godot 对应的独立验收配置不改变普通工作台、默认 F5 或正式玩法库存。将锁定源目录 `Assets/Art/坐骑/迷你幻想_坐骑_v1.0/迷你幻想_坐骑_素材/新 坐骑/War 马` 下的四张原图复制到私有目录并按下表命名：

| 原图 | 私有文件名 |
| --- | --- |
| `待机_stallion.png` | `mount_stand.png` |
| `行走_stallion.png` | `mount_move.png` |
| `War马待机袭击者_人类.png` | `rider_stand.png` |
| `War马行走袭击者_人类.png` | `rider_move.png` |

```sh
python godot/tools/extract_workbench_mount.py /path/to/Unity-repository /path/to/private-mount-source
export FANTASYWORD_WORKBENCH_MOUNT_VALIDATION=/path/to/private-mount-source
godot --path godot res://gameplay/equipment_workbench/equipment_system_demo.tscn
```

此入口还需要工作台基础私有资源合同。先卸下普通装备（默认布衣也要卸下），再用「坐骑 → 战马」穿戴；卸下恢复步行层。仅这一验收配置限制带普通装备上马、骑乘时换装或重选角色，以免把未迁移的骑手换装称作原版行为。马和骑手使用原同画布 Sprite，按四向共享帧索引，待机与行走各自按 2.4 和 0.8 秒循环。动作或朝向变化从第 0 帧开始；不支持的动作按原资产回退到 Stand，已经播放 Stand 时不重置。合同和原图不提交。

`godot --path godot --script res://tests/test_workbench_mount_validation.gd` 验证按钮、真实槽写入/卸下、四向连续两帧、循环与回退；原生窗口另外核对马身和骑手两个实际图层的颜色。独立验收不代表正式玩法骑乘、骑手专用 Body/Head UV、其他坐骑或 Unity GameView 同场对照通过。

### 战马骑手基础布衣绑定

若同时提供锁定 `GeneratedUV/Mounts/HumanWarHorse/` 的四张 `HumanWarHorse_{Idle,Walk}_{Body,Head}UV.png`，可在同一独立入口验证原版普通装备叠加分支。把它们放在战马四张图同一个私有目录，再执行：

```sh
python godot/tools/extract_workbench_mounted_cloth.py /path/to/Unity-repository /path/to/private-mount-source
export FANTASYWORD_WORKBENCH_MOUNT_CLOTH=/path/to/private-mount-source
```

启用后可穿默认基础布衣上马；也可在骑乘中点「服装 → 布衣／卸下」。马身始终使用原图；布衣更新的是当前骑手材质、原骑乘帧对应的 Body/Head UV 和基础外观，不重新计时或重设坐骑槽。卸下布衣回到原图直显，保留布衣下马则恢复站立换装。

原作者给这套骑乘 Body UV 的布衣采样区与原布衣非透明区不重合。四方向、两动作共 64 帧均验证没有布衣颜色贡献；不修改作者 UV 或补画布衣。原生像素探针验证实际骑手右眼的着色结果，且开关布衣层没有凭空染色。这里仅迁移基础布衣的材质与装备流程，不宣称布衣可见、正式玩法骑乘、未列入的骑乘装备或 Unity 同屏差分已通过。合同和原资源不提交。

### 战马骑手默认轮廓与地面阴影

在上面的骑手布衣合同提取命令末尾加 `--include-outline-shadow`，同目录生成私有的 `outline-shadow-frames.json`。保留原先无此文件的布衣验收方式；有文件但合同不匹配会拒绝加载。骑乘带布衣时，按同一个实际骑手帧的作者脚标记和 `groundPixelY=8` 写入原版共用基线与 Mode 0 阴影，复用原地面探针和普通黑色轮廓规则。原 64 帧没有受击轮廓旗标；马身、无装备直显和站立材质不受影响。原生 Godot 窗口核对东南待机、东南/西北行走的纯黑轮廓、0.6 黑色阴影和阴影外不变点，含第二行地面阴影；不等同 Unity 同屏验收或其他骑乘装备已迁移。

### 战马骑乘主副手

同时提供上述 64 帧轮廓／阴影合同和原武器目录 `FANTASYWORD_WORKBENCH_WEAPONS` 后，独立战马验收开放对应主副手类别。长矛、战斧、重盾、圆盾可以先装备再上马，也可以骑乘中穿脱，装备状态与徽章保留。任一主副手武器单独装备也启用骑手换装材质；卸下最后一件普通装备回到原图直显，不动坐骑、马身和播放进度。

原版骑乘动画上下文为实际的 Idle / Walk，攻击请求回退后仍是 Idle；这四件装备没有该上下文的序列，作者 64 帧也没有主副手锚点。原静态武器分支因此不绘制武器，而非借站立锚点或补一个中心位置。原生窗口用同帧画面验证装备时轮廓、阴影及眼色有效而没有武器像素，卸下时原直显恢复，下马可继续播放保留装备的站立武器序列。这不是正式场景背包骑乘、可显示武器的骑乘动作或 Unity 同屏验收。

## 迁移及验收范围
人类进场默认东南待机、穿布衣。通过实际按钮卸下及重穿，驱动渲染器的布衣层，详情和状态徽章同步。卸下显示「当前为空」，重穿显示「已装备」与预览目录的「生命 +6」，不写玩家库存、生命数值、装备栏或存档。支持选择原待机、行走、攻击与四向动画；重选人类恢复初始外观。披风类别迁移来源目录中的旅行披风（体质 +1、魔力 +2）和厚斗篷（体质 +2、生命 +4）。二者虽同 numeric ID，仍按各自原视觉资源替换同一个披风槽，不改布衣。厚斗篷跟随原 Dmg 前两帧的 Torso Left 变体，末两帧回 Base；后向缺帧及 Right 无 SE 按原回退。工作台受伤预览停留末帧，不触发玩法伤害或自动回待机。重选人类恢复原默认布衣和空披风。装备按钮预览图取该披风原有效图；未迁移完整原图标合成与全量界面。

小背包沿用原独立装备槽和详情「生命 +2、魔力 +3」。默认无背包；穿脱不改布衣和披风。南向仅在原躯干透明底图时走早绘制；北向根据原躯干朝向在武器之后再画一次，不要求启用武器。工作台图标取原 SE 裁片，按原 alpha 裁切后缩放居中。Godot 原生窗口附加验证四向穿脱、同帧像素复原和北向背包实际盖过披风；两个着色器版本另有无武器合成回归。

头部工作台保留源三列分类网格和独立头盔、帽子、面罩页。角饰头盔、铁盔 I/II、轻帽和护目镜依原类型互相替换，空分类的卸下不移除其它分类。头盔/帽子共用 Helmet 层，面罩独立；原人类头发、胡须按选项分别保留或隐藏，并在每次原头部帧采样时重新求值。四向护目镜贴图、铁盔的不同 atlas 列、行动后发须保留和移除后复原已纳入 Godot 原生测试；不改变正式场景的默认外观或装备逻辑。

长矛与重盾按原主手/副手分开穿脱，显示原属性。原行走标签 1、3 缺副手锚点时只隐藏盾牌，标签 0、2 恢复，主手不消失且并未卸下装备。原东北攻击标签 1 到 2 的长矛从前层原图切到后层原图，副手保留。测试同时覆盖静态待机四向、武器组合后的原生帧像素与卸下复原。战斧和长矛在主手互换，圆盾和重盾在副手互换，不影响另一手。同项再次点击保留穿戴；卸下只清所在槽。战斧东北攻击标签 0、1 的原切片 x 顺序是 32、0，按确切 fileID 绑定。圆盾没有后向图，东北回退东南、西北回退西南，已经配置西南所以不镜像。原生测试区分了实际战斧两帧和圆盾两个后向的图像颜色。独立的挥砍路径见下文；武器/盾牌未接正式库存和战斗。

等待、其他动作、其他角色/形象及装备、其他骑乘换装、正式玩法坐骑、工作台完整轮廓与整屏布局、Unity 同场画面逐项对比仍未验收。

`godot --path godot --script res://tests/test_equipment_workbench_demo.gd`：给齐私有输入时驱动真实 Godot Viewport 鼠标按钮；非 headless 额外比较同一实际显示帧的穿脱衣服和披风像素差分及复原。披风覆盖两种选项替换、独立穿脱、四向 Dmg 的 16 个采样、末帧维持及 Right 回退。干净环境验证没有私有素材时不放置假角色，默认入口仍为 ClickMoveTest。局部像素差分仅验证工作台真实改变渲染，不代表整屏布局与 Unity 像素一致。


### 原人类挥砍（可选工作台合同）

从锁定版本准备原 `Slash_Character_human.png` 及其 .meta 到人类图集目录，
同名的 `_BodyUV.png`、`_HeadUV.png` 及 .meta 放到 `uv/`。用上文的
动画、材质提取命令（保留 `--include-attack`），各加 `--include-slash-attack`。
若同时验证武器，在完整战斧、长矛、重盾、圆盾合同（非 legacy/formal）提取命令
也加 `--include-slash-attack`，并与新的动画合同一起加载。旧合同与正式 F5 不变。
可与原受伤、披风和小背包一起载入：源动画、材质提取命令同时指定
`--include-damage`；披风合同提取也需加 `--include-slash-attack`，小背包合同不变。
原挥砍的 16 条躯干记录对应当前四向、基础变体；厚斗篷东北/西北分别按原规则
回退到东南/西南，小背包按对应的原切片和身体深度绘制。旧披风合同若没有挥砍
躯干记录则拒绝组合，不借用待机帧。本组合仍不接骑乘。

经原共享状态机、四个精灵库、实际人类 FrameData 及战斧序列 GUID 验证，工作台
显示「挥砍」，使用原 8 Hz 的 0.5 秒非循环序列，16 个四向帧并保留首尾帧。
战斧在此动作有独立登记的前后深度序列，无原手锚则按源渲染器规则使用帧中心；
没有序列亦没有手锚的长矛和重盾在挥砍期间不画，并不代表卸下。回待机恢复原装备。
`FORMAL_WORKBENCH_SLASH_TEST=1` 下运行 `tests/test_workbench_slash_attack.gd`
经过真实工作台按钮、16 个帧区域、原武器贴图与深度绑定验证；未做双引擎像素对照，
不是新增正式主角技能或改变玩法装备。

### 原人类旋转死亡（独立工作台预览）

在已有私有人类图和 UV 目录加入原 `Minifantasy_CreaturesHumanSpinDie.png`、
对应的 `_BodyUV.png`、`_HeadUV.png` 及各自的原 `.meta`。动画、材质提取命令
各加 `--workbench-spin`（不要同时传正式主角的 `--include-death`）。
同时启用披风或背包时，披风提取也加 `--workbench-spin`；原武器、背包合同不变。
提取会核实原 EquipmentSystemDemo、其人类工作台目录条目、四个精灵库、帧数据和
动作数据库登记。普通工作台可与受伤、挥砍组合，不混用骑乘或正式玩法死亡合同。

点击「旋转死亡」按原 8 Hz 播放 12 个不同精灵，1.5 秒非循环后保持末帧。
四向原精灵库引用同一行，换方向不切图或改动原躯干朝向。末两帧没有躯干区域时
按原 EquipmentRenderer 的行 0 和 Base 回退，披风与背包仍使用该行贴图规则。
在没有原武器锚点及序列的 SpinDie 中不绘主副手，保留已装备状态，回到待机即恢复。
只在独立界面选动作，不扣血、不锁主角、不触发死亡、掉落或读档。

`FORMAL_WORKBENCH_SPIN_TEST=1` 下的 `tests/test_workbench_spin.gd` 驱动真实
工作台按钮，逐一复核四向 48 次原精灵引用、材质参数、末帧与回待机后的已装备武器，
并检查该合同不能被正式场景当作死亡所有权。无头验证不代表最终像素、阴影、完整界面
或 Unity 同机位对照已经验收。

### 原动作列表与没有身体帧的条目

工作台按锁定 `AnimationTypeDatabase._items` 的 28 条顺序显示，不再把已迁移
动作排成另一套顺序。原 `EquipmentWorkbenchRuntimeUI` 区分真实身体图、
「·缺帧」和农务「·无真人帧」。其中 Wait 与 Die 的身体回退仅用于可选性；
原 `TrySetPreviewAnimation` 仍需要独立身体图，所以点这两条不换动作或装备。
已有独立原图但当前 Godot 未接入的动作保留原按钮名并禁用，提示明确区分
迁移缺口与作者缺帧。不会为了让按钮可点就播放别的动作。

原按钮为 88×32、11–16 单行字号和省略。Godot 用已核实字体测量并在同一尺寸
内限制字号；不宣称 TMP 字形、亚像素或完整工作台窗口已比对。验收包含 28 项
顺序、缺帧标签、真实点击无副作用，以及原有可用动画与装备回归。

### 原人类蓄力（独立工作台预览）

在私有目录加入原 `Minifantasy_CreaturesHumanChargedAttack.png` 及同名
`_BodyUV.png`、`_HeadUV.png` 与原 .meta。动画、材质和披风提取各加
`--include-charged`；仍需原其余动作及装备合同。原图与两张数据图均为
192×96，Body/Head UV 按原 point/Repeat 采样，切回其他动作不会残留 Repeat。
东南、西南、东北、西北分别读原图 0、1、2、0 行，西北复用东南原 Sprite；
8 Hz 播放六帧，0.75 秒非循环并保留末帧。披风和小背包按同一帧的躯干行及
Base 变体，不按按钮方向另编造第四行。原帧无手锚且当前四件武器/盾无
此动作序列，预览期间不绘，切回待机恢复已装备状态。现有武器合同不变。

`FORMAL_WORKBENCH_CHARGED_TEST=1` 下的 `tests/test_workbench_charged.gd`
走真实工作台按钮、四向全帧、原主图和两张 UV、装备层、末帧和回待机。
这不接入骑乘或正式技能，也不是原生像素、完整面板或 Unity 截图验收。

### 原人类 Dmg2 与跳跃（独立工作台预览）

把原 `Minifantasy_CreaturesHumanDmg2.png`、`Minifantasy_CreaturesHumanJump.png`
及各自的生成 BodyUV、HeadUV 和原 .meta 放入私有资源目录。动画、材质和披风
提取命令各加 `--workbench-moves`。两动作分别沿东南、西南、东北、西北
原 0、1、2、3 行，在 8 Hz 播四帧，0.5 秒非循环，停在末帧。Dmg2 保留原
动作名和 clamp 双 UV，跳跃使用原 repeat 双 UV；不修改角色本体颜色图采样。
披风和小背包按原躯干行/Base，当前四件武器和盾均无此动作序列，原帧无手锚，
暂不绘制但不卸下，回待机恢复。与受击、挥砍、旋转死亡和蓄力可同载，
不改变主场景玩家受击、跳跃逻辑或骑乘。

`FORMAL_WORKBENCH_MOVES_TEST=1` 下 `tests/test_workbench_moves.gd` 走实际
按钮与原四方向，检查连续切换的 UV、装备、末帧及回待机，并验证默认玩法入口
不接受这两个工作台专用动作。无头结果不等于原生像素对照。

同一 `--workbench-moves` 也需要原 `Minifantasy_CreaturesHumanSoulDie.png`、
两张生成 UV 和 .meta，提供「灵魂消散」。原 384×32 图四向共用同一行的
12 个精灵，8 Hz、1.5 秒不循环，仍保留末帧；两张 UV 用 Repeat。躯干均取
行 0/Base，武器和盾在本动作无锚点与序列，回待机恢复显示。预览不进入
角色死亡、掉落或读档流程。旧版公开不含 `--workbench-moves` 的合同仍可用。

### 原人类采集、砍伐、挖矿（独立工作台预览）

私有图集加入原 `Human_Harvest.png`、`Human_Chopping.png`、
`Human_Mining.png`、各自的生成 BodyUV / HeadUV 与原 .meta。动画、材质、
披风提取各加 `--workbench-gather`。提取同时核实直接 Git PNG 与 LFS PNG，
不会按素材名替换更像的动作。这三项均按原四向 24 帧、6 帧每向、8 Hz、
0.75 秒循环播放。显示原动作名「采集」「砍伐」「挖矿」；数据库里的
`Harvesting` 仍是独立的「收获·无真人帧」，不能借用 Harvest 伪造。
两张数据图按原 Repeat，披风与小背包随原四向躯干/Base。现有四项
武器、盾牌无此序列或原挂点，预览时不画，原装备不卸下。

原三个主图为 Unity Tight 网格导入，没有手写轮廓；当前 Godot
预览仍用 32×32 区域。原网格几何、边缘像素和完整窗口需另行双引擎对照，
无头运行不能验证这些。`FORMAL_WORKBENCH_GATHER_TEST=1` 的实际按钮测试
仅核实工作台材质、装备、帧、循环重入和回到待机，不接入正式采集玩法。

### 原人类制作台预览

三个提取器均可选 `--workbench-craft`。私有输入须提供原铁砧、珠宝、炼金、木工台主图及各自的 Body/Head UV 和 meta。该选项不启用实际制作、交互或非人类角色动作。

- 铁砧、木工台是 6 帧 / 0.75 秒；珠宝、炼金是 11 帧 / 1.375 秒。四个动作都是 8 Hz 循环，四向按钮选中状态独立，原精灵库各向共用同一行，不重播。
- 当前已接入的武器与盾在这些动作没有原挂点或独立序列。动作使用共用躯干行的披风、背包和原 Repeat UV，回待机恢复原装备显示。
- 通过 `FORMAL_WORKBENCH_CRAFT_TEST=1` 验证实际工作台。原 Unity 主图为 Tight，Godot 当前按矩形区域采样；不据此宣称原生画面或轮廓已逐像素对齐。

### 可选：原地精／兽人工作台预览

`FANTASYWORD_WORKBENCH_NONHUMAN` 指向锁定源的私有合同目录；不设置时保留原人类预览入口。安装项目提取工具所用的 PyYAML 和 Pillow，在 Unity 原仓库备齐已授权的 Git/LFS 对象后，运行 `python godot/tools/extract_workbench_nonhuman.py --unity /path/to/unity --out /path/to/private-fixture`。可选 `--lfs-dir` 只读按 SHA-256 命名的原始 LFS 对象。合同与原始素材都只留在私有目录，不提交。

两种角色各接入原四向库中具备专属精灵的 14 个动作，包括源待机、移动、受击、攻击、死亡、采集和制作台。切换人物回到待机、东南方向及该角色的默认布衣；按原 sprite 文件 ID 保留共享帧身份。源动作的 28 对 BodyUV／HeadUV 都是零数据，默认布衣的装备状态不表示会覆盖身体。矮人、精灵、非布衣装备、无独立帧的回退按钮、原图缩略图与 Tight 网格仍未验收；无头检查不代表实机像素对照或整个工作台交付。
