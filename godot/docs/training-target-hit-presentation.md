# 训练假人受击表现与效果应用阶段

锁定 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`，从已验证的正式 ClickMoveTest 受击入口继续。对象是原场景活动训练假人，不是玩家、诊断靶或静止替代 AI。

- **命中与作用分段**：`TaskApplyEffects` 在第 12 帧读取实际位置查目标，投递作用于该目标的 2004 请求。`SAbilityTick` 播放命令后，同次 `SGEffect` 实例化并检查。2004 无应用标签、免疫标签或持续时间。Godot 的作用阶段消费新请求，先登记 Cue，再从同一实际 Actor 读取当前属性和根坐标执行伤害。请求只消费一次；离场、无效实体不找替代。现用合并时间轴不宣称全局 FixedStepSimulation 等价。
- **正式 Dmg 在扣血前**：`CharacterBase.PrepareFormalDamageHit` 对非静默伤害请求动作打断和 `TryPlayHitAnimation`。假人视图用[已核实的源四向库及资源](training-target-presentation-provenance.md)，在独立身体原点显式安装现有 Human 表现和运动绑定；无合法原资源不安装。动画与生命拥有者分离，实际 Dmg 在扣血前播放；恢复由真正动画长度与接受的运动量决定。临时程序化夹具只用于公共测试，不进入场景。
- **Cue 20001 不是 Dmg**：原效果表 `CueOnApply=[20001]`，`SPlayCueOnApply` 在 `SGInstantEffect` 前登记；同一应用是否闪避不是 Cue 判断条件。原 cue 表为 `CuePlayGameCoreFeedback`，Kind6 HitDamageable、Target0。目标的 CharacterSheet 反馈槽 `m_hitDamageableFeedbacks` 是空。源瞬时效果完成后销毁；独立的 cue 仍由 `SCueStart` 在显示阶段读取目标，没有凭空的音效或粒子。此空槽分支只记录触发，保持无反馈；不实现任意目标的通用反馈运行器。

组合测试核对原演员、挂点、实时伤害、击退、原 Dmg 帧推进、半秒恢复、Cue 在生命提交后进行显示阶段且只触发一次。公开运行使用独立测试图，私有运行另查原图、原 UV 和外观。没有发布源图、派生私有合同或截图。

仍不含原场景完整图层、完整 GAS、受击数字与全局反馈、死亡形象、正式 20001 敌方攻击/追击与双端截图。无头测试不能替代整体验收。
