# 正式 Human 主图集 Idle/Walk 切片

来源锁定 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`。这不是完整换装或视觉验收，也不更改旧的合成测试注入接口。

## 已接入

- 从共享控制器核实 Idle/Walk 引用，读取共享片段 m_SpriteHash 常量曲线；float32 位解释后关联 `category_label` 30 位 CRC32 哈希，逐键核对四向精灵库。
- Sprite GUID/FileID 与原 PNG.meta 内部 ID 联接，不从截图猜行列。提取器验证原 Git LFS SHA256 和逐字节 meta；原文件只在私有目录。
- Idle 16 标签、2 秒；Walk 4 标签、0.5 秒，均间隔 0.125 秒，末关键帧重复最后标签、循环。源控制器速度为 1。
- Godot AtlasTexture 采用原 32×32 区域、中心 pivot、PPU 8、最近邻采样，转换 Unity 左下原点；四向按 SE/SW/NE/NW，方向切换不重置动画。
- `entry.start_human_presentation(manifest, private_directory)` 显式附着于原 Body 偏移，不移动物理根。无合同或缺图就拒绝，不生成替代角色。
- 返回节点的 `set_movement` 必须接原 owner 实际动画位移通知；`set_facing` 必须接 owner 已裁决身体朝向，不能把移动意图当作权威朝向。入口不偷偷接管 GAS/角色 owner。

## 私有重现

```sh
python3 godot/tools/extract_formal_human_animation.py --repo ORIGINAL_GIT --textures PRIVATE_PNG_META_DIRECTORY --output PRIVATE_DIRECTORY/animation.json
GODOT --headless --path godot --script res://tools/check_formal_human_animation.gd -- PRIVATE_DIRECTORY/animation.json PRIVATE_PNG_META_DIRECTORY
```

提取器需要 Python PyYAML。第二条运行真实原图 80 个裁片像素、全部关键帧时间、循环、方向保时、入口偏移检查，不是 GPU 截图比对。JSON/PNG/meta 不应加入仓库。一般无素材测试另检查非法嵌套合同无副作用失败。

## 尚未验收

完整共享控制器状态、动态换装与阴影，以及正式 PlayerSystem/GAS owner 到完整角色表现生命周期均不由本切片宣称完成。基础外观接入记录见既有材质文档；Dmg 增量见下节。此入口只供明确选择的源图样本，默认场景不会展示一个缺层角色冒充完整迁移。Unity/Godot 实机相同状态截图、渲染混合/排序等仍需另行对照。

## 增量：显式 Dmg 表现与基础材质

提取器默认保持原两动作合同；动画和材质提取命令同时增加 `--include-damage` 后，会额外逐字核对原 Dmg 控制器引用、四向库、PNG/meta、FrameData 和 GeneratedUV/Human 的 Body/Head 图。源 Dmg 是 4 帧、8Hz、0.5 秒、非循环；末尾 0.5 秒关键帧重复标签 3，控制器速度 1、无转换。不得用同名 Art UV 代替帧数据引用。

返回的 `HumanPresentation.try_play_damage_animation()` 接受显式表现请求；不产生按键、碰撞伤害、生命值或 GAS 事件。缺少 Dmg 的旧合同返回失败而不生成占位。三动作展示必须绑定覆盖全部三动作的基础材质合同；不能沿用两动作 UV。

恢复仍由既有 CharacterActionAnimatorDriver 独占：请求时默认恢复 Idle；之后原移动 owner 的 SetMovement 可以更新为 Walk/Idle，但不抢占受击。再次受击重播首帧并延期；转向只换方向库；显式新动作取消旧期限；动作锁保持原“请求成功但不切换”语义；非运行预览不自动恢复。未另建计时器。

`tests/test_formal_human_damage.gd` 使用真实 ClickMoveTest 展示入口验证这些分支、四向 16 帧、材质持续复用与 Dmg 独有 UV。默认是合成合同测试；传入五个参数（动画 JSON、材质 JSON、原 PNG 目录、生成 UV 目录、外观目录）可运行私有原图逐像素裁片检查。测试不代表 GPU 或 Unity/Godot 截图一致。

本节只新增原 Dmg 图集/时序/基础外观的显式展示请求，不宣称正式伤害 owner 到表现已接通。完整死亡、打断/GAS、装备/坐骑、阴影和跨引擎画面验收仍未完成。

### 正式主角轮廓与地面程序阴影

用 `python godot/tools/extract_formal_human_effects.py <锁定 Unity 仓库> <私有角色图目录> <私有输出.json>` 核对正常主角实际精灵帧，在正式入口将产物设为 `FORMAL_PLAYER_EFFECTS_SOURCE`。不要求同时提供私有长矛图；已提供的合同不符时，不使用推断数据。合同、原素材和取证截图均不入库。

运行时沿用本体、装备合成后的原轮廓及阴影片元规则。按实际精灵图集坐标读取 Idle、Walk、Dmg、Attack、SpinDie 共 124 帧；地面基线使用原第 18 行像素中心。保留 Walk 离地、Dmg 帧旗标切换、攻击序列不参与轮廓探针，以及 SpinDie 无脚时只覆盖模式并保留先前参数的行为。卸矛不清除轮廓或阴影。此处不包含独立的 Blob Shadow 节点、训练假人轮廓或 Unity/Godot 同视口截图验收。

### 正常关卡活动假人的装备表现和死亡转移

在原素材工作区配齐 `FORMAL_PLAYER_CLOTH_PNG` 和 `FORMAL_PLAYER_SPEAR_SOURCE` 后，可给正常入口设置 `FORMAL_TRAINER_EFFECTS_SOURCE`，指向上一节生成的同一人类帧合同。锁定的活动假人通过原角色基类继承布衣、长矛和同一人类五组原动作；不是工作台角色。两角色共享物品数据库身份，但不共享装备槽、材质或阴影状态。假人用原非致命受击和攻击动作更新材质；死亡先移普通背包，再锁定 SpinDie，随后经装备事件将原装备转入对应的尸体背包，不影响主角。这里仅接通当前假人的运行时归属；尚未接入尸体交互、拾取 UI、主角死亡装备转移或存档恢复。

另有一个独立的原 Blob Shadow 对象。原图、根节点局部位置和透明度已核对，但原渲染器引用的排序层 ID 不存在于锁定版的 TagManager。实际遮挡顺序尚缺同版本 Unity 运行画面证据，此批不接入该对象，也不以程序阴影冒充。
