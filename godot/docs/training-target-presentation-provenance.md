# 训练假人表现来源与复用边界

来源锁定 `31629d53a110dd4c87d4c85e6ad5a387fbafb931`，对象为 `ClickMoveTest` 的活动训练假人，而非玩家替身或停用的转向测试对象。

## 为什么可以复用 Human 表现

- 训练假人预制体继承 `0_CharacterActor_Base`，再继承 `0_Character_Base`。
- 训练假人静态覆盖的旧玩家 SpriteLibrary 只有 `Idle/Run/Hit/Death/Parts`。不能看到 Human 图集就推断该旧库支持正式 `Dmg`。
- 继承且启用的 `DirectionalSpriteLibraryDriver.OnEnable` 会采用原本配置完整的 Human SE/SW/NE/NW 四向库；`ApplyDirectionVariant` 将当前方向库写回同一个 SpriteLibrary，覆盖旧静态库。
- 继承动作驱动原配置就是 `Idle/Walk/Dmg`，Actor 基类将 Body Animator 改为原共享状态机。不存在需要额外编造的“训练假人受伤动画”。
- 继承 EquipmentRenderer 使用同一份 Human frameData、appearance，初始装备为空。Body 局部位置为零、缩放为一；不能把碰撞胶囊中心的偏移当成模型偏移。

`tools/extract_training_target_animation.py` 重新从锁定 Git 对象验证上述继承和 GUID 映射，再复用现有提取器核实三个动作每个方向的标签、原 PNG 的 LFS SHA256、尺寸与 PPU。输出是私有合同，不能提交输出文件或原图集。

## 原生接入

复用 `gameplay/clickmovetest/human_presentation.gd`，无需新增第二套动画 owner：

1. 在已配置的训练假人 `body` 下添加表现节点，保持局部位置零。
2. `configure(animation, texture_directory)` 接受提取器输出的 Idle/Walk/Dmg 合同。配置失败释放该节点，不保留半成品。
3. `bind_base_material(material_contract, uv_directory, appearance_directory)` 加载已核实的原 UV 和外观。
4. 命中语义由伤害 owner 裁决，在原先非静默的 prepare 时机调用 `try_play_damage_animation()`，不得用表现节点倒推命中或扣血。
5. 接受实际运动量和权威身体朝向通知。已有 `HumanMotionBinding` 可复用，但要求实际 owner 提供 `get_look_at_direction` 与 `look_at_direction_changed`。不可用移动意图自行代替身体朝向。

## 验收范围

已在真实训练假人 Body 下加载原始三动作 PNG、原 UV/外观，逐一比较 Dmg 四个方向四帧的实际 Sprite2D 纹理像素，核对 PPU、局部位置以及 0.5 秒回 Idle/收到运动通知后回 Walk。证明的是原生表现节点与原始素材对应，不是 Unity 实机截图一致，也不是完整 AI、追击、移动攻击或整项目完成。生产 Entry 的接线由集成阶段独立验收。
