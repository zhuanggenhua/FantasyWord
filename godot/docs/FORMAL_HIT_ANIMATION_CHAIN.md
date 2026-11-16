# 正式伤害扣血前的受击准备

对应锁定 Unity `31629d5` 的 `CharacterBase.Resources.PrepareFormalDamageHit`、`CharacterBase.SetLastEffectiveDamageSource`、`CharacterActor.TryPlayHitAnimation`。以 `FormalDamageExecutor` 的既有扣血前钩子为接入点，不建立第二套生命值。

先记录非空且非自身的来源，静默伤害也记录。非静默伤害先排队延迟打断，再请求当前角色的正式受击驱动，之后由伤害执行器扣血。正式驱动已绑定但不可调用或播放失败时报告错误，不回退伪造表现，也不阻止扣血；只有未绑定时使用已提供的旧策略。安全阶段消费打断沿用已迁移的 `deferred_damage_lifecycle.gd`。

自动测试使用正式伤害执行器、延迟状态及原生 AnimationPlayer 的合成短片段，验证扣血顺序、静默/真实来源、异常分支与按截止时间恢复 Walk。片段只证明生命周期边界。原版素材、正式属性系统、装备、死亡路径及原场景验收不由这个测试证明。

另有独立私有资源复验：从锁定 Unity 工程的真实四向 Idle、Walk、Dmg 纹理构建原生 AtlasTexture，在受击扣血前进入 Dmg，播放中切向时保留 AnimationPlayer 位置和恢复期限，换成同一标签的原版对应像素；期限后恢复 Walk。该复验没有引入原始贴图到迁移分支。它只证明底层角色精灵链，不是原场景或换装材质验收。
