using UnityEngine;
using UnityEngine.Events;
using Unity.Mathematics;
using GAS.Runtime;

namespace FantasyWord.GameCore
{
    public abstract partial class CharacterBase
    {
        /// <summary>
        /// 设置受击后是否播放临时无敌表现。
        /// 这里只改表现开关，不改变伤害结算或受击保护时长。
        /// </summary>
        public void SetInvincibleOnHit(bool invincibleOnHit) => m_invincibleOnHit = invincibleOnHit;

        /// <summary>
        /// 通用当前属性改动只保留给非资源属性使用。
        /// 若传入生命或法力，则自动转到专用资源写入口，避免外部继续把资源修改当普通属性增减来用。
        /// </summary>
        public void ModifyCurrentStat(EStat stat, int delta)
        {
            switch (stat)
            {
                case EStat.Health:
                    ModifyCurrentHealth(delta);
                    return;
                case EStat.Mana:
                    ModifyCurrentMana(delta);
                    return;
                default:
                    int newValue = GetCurrentStatValue(stat) + delta;
                    SetFormalCurrentStatOrReportFailure(stat, newValue);

                    return;
            }
        }

        /// <summary>
        /// 生命和法力不是普通属性，它们带有“当前值 / 上限 / 缺口 / 能否恢复 / 能否支付”的资源语义。
        /// 后续若由 GAS 接管，这一层是优先替换入口，外部不应继续自己拼 Health/Mana 规则。
        /// </summary>
        public int GetMaxHealth() => GetFormalBaseStatOrBootstrapBuffer(EStat.Health);
        public int GetCurrentHealth() => GetFormalCurrentStatOrBootstrapBuffer(EStat.Health);
        public int GetMissingHealth() => math.max(0, GetMaxHealth() - GetCurrentHealth());
        public bool CanRecoverHealth() => GetMissingHealth() > 0;
        public int GetMaxMana() => GetFormalBaseStatOrBootstrapBuffer(EStat.Mana);
        public int GetCurrentMana() => GetFormalCurrentStatOrBootstrapBuffer(EStat.Mana);
        public int GetMissingMana() => math.max(0, GetMaxMana() - GetCurrentMana());
        public bool CanRecoverMana() => GetMissingMana() > 0;
        public bool HasEnoughMana(int amount) => GetCurrentMana() >= math.max(0, amount);

        /// <summary>
        /// 资源合法性判断由角色拥有者统一回答，外部不再自己拼“是否会死 / 是否会负蓝”的规则。
        /// </summary>
        public bool CanModifyCurrentHealth(int delta, int minimumValue = 0) => GetCurrentHealth() + delta >= minimumValue;
        public bool CanModifyCurrentMana(int delta, int minimumValue = 0) => GetCurrentMana() + delta >= minimumValue;

        /// <summary>
        /// 当前资源变更是否合法，由角色拥有者统一给出分类结果。
        /// 先判生命，再判法力，避免外部调用方自己拆 Health/Mana 条件后再映射业务结果。
        /// </summary>
        public EResourceValidationResult ValidateCurrentResourceDelta(int healthDelta, int manaDelta, int minimumHealth = 0, int minimumMana = 0)
        {
            if (!CanModifyCurrentHealth(healthDelta, minimumHealth))
            {
                return EResourceValidationResult.HealthBelowMinimum;
            }

            if (!CanModifyCurrentMana(manaDelta, minimumMana))
            {
                return EResourceValidationResult.ManaBelowMinimum;
            }

            return EResourceValidationResult.Valid;
        }

        /// <summary>
        /// 使用 Stats 形式验证资源变更。
        /// 只读取 Health/Mana 两个资源字段，其它属性不参与支付合法性判断。
        /// </summary>
        public EResourceValidationResult ValidateCurrentResourceDelta(Stats statDelta, int minimumHealth = 0, int minimumMana = 0)
        {
            if (statDelta == null)
            {
                return ValidateCurrentResourceDelta(0, 0, minimumHealth, minimumMana);
            }

            return ValidateCurrentResourceDelta(statDelta[EStat.Health], statDelta[EStat.Mana], minimumHealth, minimumMana);
        }

        /// <summary>
        /// 将资源改变量裁到当前角色允许的范围内。
        /// 这主要服务持续效果和装备预演，避免外部再去读当前值后手工写最小值裁剪。
        /// </summary>
        public int ClampCurrentHealthDelta(int delta, int minimumValue = 0)
        {
            int minimumAllowedDelta = minimumValue - GetCurrentHealth();
            return math.max(delta, minimumAllowedDelta);
        }

        /// <summary>
        /// 将法力改变量裁到当前角色允许的范围内。
        /// </summary>
        public int ClampCurrentManaDelta(int delta, int minimumValue = 0)
        {
            int minimumAllowedDelta = minimumValue - GetCurrentMana();
            return math.max(delta, minimumAllowedDelta);
        }

        /// <summary>
        /// 当前生命值改动保留在拥有者内部完成，调用方只描述资源变化量和最低保底值。
        /// 正值会裁到生命上限，负值会按最低保底值截断；底层变化交给 GAS Instant Modifier。
        /// </summary>
        public void ModifyCurrentHealth(int delta, int minimumValue = 0)
        {
            int appliedDelta = ClampCurrentHealthDelta(delta, minimumValue);
            if (appliedDelta == 0)
            {
                return;
            }

            ApplyCurrentResourceDeltaViaFormalModifier(EStat.Health, appliedDelta, this);
        }

        /// <summary>
        /// 当前法力值改动保留在拥有者内部完成，负值不会低于最低保底值。
        /// </summary>
        public void ModifyCurrentMana(int delta, int minimumValue = 0)
        {
            int appliedDelta = ClampCurrentManaDelta(delta, minimumValue);
            if (appliedDelta == 0)
            {
                return;
            }

            ApplyCurrentResourceDeltaViaFormalModifier(EStat.Mana, appliedDelta, this);
        }

        /// <summary>
        /// 读取角色当前生效的正式属性值。
        /// 调用方只想知道某一个数值时，应走这个标量入口，而不是先拿整份属性快照。
        /// </summary>
        public int GetStatValue(EStat stat) => GetFormalBaseStatOrBootstrapBuffer(stat);

        /// <summary>
        /// 使用正式属性定义读取基础属性。
        /// </summary>
        public int GetStatValue(FormalAttributeDefinition definition) => GetStatValue(definition.Stat);

        /// <summary>
        /// 计算攻击速度倍率。
        /// baseline 是配置基准值，当前攻击速度小于等于 0 时按 1.0 处理，避免动画或冷却链被除零拖垮。
        /// </summary>
        public float GetAttackSpeedMultiplier(float baseline = 100.0f)
        {
            if (baseline <= 0.0f)
            {
                return 1.0f;
            }

            float currentAttackSpeed = math.max(0.0f, GetCurrentStatValue(EStat.AttackSpeed));
            if (currentAttackSpeed <= 0.0f)
            {
                return 1.0f;
            }

            return math.max(0.05f, currentAttackSpeed / baseline);
        }

        /// <summary>
        /// 读取角色当前运行时属性值。
        /// 这里的“当前”包含生命、法力以及临时效果改动后的实时结果，后续若切 GAS，优先在这里收查询真相。
        /// </summary>
        public int GetCurrentStatValue(EStat stat) => GetFormalCurrentStatOrBootstrapBuffer(stat);

        /// <summary>
        /// 使用正式属性定义读取当前属性。
        /// </summary>
        public int GetCurrentStatValue(FormalAttributeDefinition definition) => GetCurrentStatValue(definition.Stat);

        /// <summary>
        /// 只有确实需要整份属性快照做批量计算或存档时，才暴露完整快照。
        /// 外部 UI 和简单规则读取优先使用标量查询入口，避免把整份属性真相到处外借。
        /// </summary>
        public Stats CreateStatsSnapshot() => TryGetInitializedFormalAttributes(out _)
            ? CreateFormalBaseStatsSnapshot()
            : CreateBootstrapBaseStatsSnapshotOrReportFailure();

        /// <summary>
        /// 创建当前运行时属性快照。
        /// 这个入口主要服务存档、批量计算或需要复制整组状态的调用点，不作为日常单值读取路径。
        /// </summary>
        public Stats CreateCurrentStatsSnapshot() => TryGetInitializedFormalAttributes(out _)
            ? CreateFormalCurrentStatsSnapshot()
            : CreateBootstrapCurrentStatsSnapshotOrReportFailure();

        /// <summary>
        /// 创建存档用当前资源快照。
        /// 只保存会被消耗或恢复的生命/法力，不保存整份 CurrentValue。
        /// </summary>
        private CharacterResourceStateData CreateCurrentResourceStateData() => new()
        {
            health = GetCurrentHealth(),
            mana = GetCurrentMana()
        };

        /// <summary>
        /// 战斗层只取当前结算真正需要的最小属性快照。
        /// 后续若切 GAS，优先在这里切掉伤害系统对整份 Stats 的依赖。
        /// </summary>
        public CombatStatSnapshot CreateCombatStatSnapshot() => TryGetInitializedFormalAttributes(out _)
            ? CreateFormalCombatStatSnapshot()
            : CreateCombatStatSnapshotFromCurrentStats(CreateBootstrapCurrentStatsSnapshotOrReportFailure());

        /// <summary>
        /// 订阅基础属性变化。
        /// listener 会收到变化前的属性快照，方便 UI 或派生系统比较差异。
        /// </summary>
        public void AddStatsChangedListener(UnityAction<Stats> listener)
        {
            m_statsChanged.AddListener(listener);
        }

        /// <summary>
        /// 取消订阅基础属性变化。
        /// </summary>
        public void RemoveStatsChangedListener(UnityAction<Stats> listener)
        {
            m_statsChanged.RemoveListener(listener);
        }

        /// <summary>
        /// 订阅当前属性变化。
        /// 生命归零的死亡请求也从当前属性变化链路触发。
        /// </summary>
        public void AddCurrentStatsChangedListener(UnityAction<Stats> listener)
        {
            m_currentStatsChanged.AddListener(listener);
        }

        /// <summary>
        /// 取消订阅当前属性变化。
        /// </summary>
        public void RemoveCurrentStatsChangedListener(UnityAction<Stats> listener)
        {
            m_currentStatsChanged.RemoveListener(listener);
        }

        /// <summary>
        /// GAS 伤害执行器解析完目标侧伤害后，把击退交给角色移动层。
        /// 这里只处理表现和位移副作用，不做伤害数值结算。
        /// </summary>
        internal void ApplyFormalDamageImpact(DamageInputDescriptor damageInput, Vector2 velocity, DamageImpactSettings damageImpact)
        {
            TryPush(damageInput, velocity, damageImpact);
        }

        /// <summary>
        /// GAS 伤害执行器命中后通知仇恨和 AI 订阅者。
        /// </summary>
        internal void NotifyFormalDamageProvoked(CharacterBase sourceCharacter)
        {
            if (sourceCharacter != null)
            {
                m_provoked.Invoke(sourceCharacter);
            }
        }

        /// <summary>
        /// GAS 伤害扣血前准备目标侧表现状态。
        /// 真正的生命扣减由 FormalDamageExecutor 通过 Instant Modifier 完成。
        /// </summary>
        internal void PrepareFormalDamageHit(CharacterBase sourceCharacter, DamageInputDescriptor damageInput)
        {
            SetLastEffectiveDamageSource(sourceCharacter);

            if (damageInput.silent)
            {
                return;
            }

            RequestActionInterruptAfterFormalDamage();
            TryPlayHitAnimation();
        }

        /// <summary>
        /// GAS 伤害扣血后收尾受击反馈、音频和临时无敌。
        /// </summary>
        internal void CompleteFormalDamageHit(
            CharacterBase sourceCharacter,
            DamageInputDescriptor damageInput,
            EEffectVisualFlags visualFlags,
            DamageImpactSettings damageImpact,
            int previousHealthBeforeDamage,
            int appliedDamage)
        {
            characterSheet.feedbacks.PlayDamageTaken(transform.position, this, damageInput, visualFlags);
            GameRuntimeEvents.RequestAudioPlayback(characterSheet.hitAudio);

            bool isSelfTargeted = sourceCharacter == this;
            bool willReachZeroHealth = appliedDamage >= previousHealthBeforeDamage;
            if (!willReachZeroHealth && !dead && !damageInput.silent && invincibleOnHit && !isSelfTargeted)
            {
                m_animationStrategy?.PlayInvincibleAnimation();
            }

            if (!isSelfTargeted && !damageInput.silent && damageImpact.sanitizedInvincibilityDuration > 0.0f)
            {
                // TopDown 的 DamageOnTouch 会把受击保护时间作为命中区参数；这里仅吸收保护时长，不接管 RPG 生命值真相。
                ExtendTemporaryInvincibility(damageImpact.sanitizedInvincibilityDuration);
            }
        }

        /// <summary>
        /// 恢复生命并发送恢复展示事件。
        /// 恢复值会被裁到当前缺口内，避免 UI 展示超过真实恢复量。
        /// </summary>
        public void Heal(int value, EEffectVisualFlags visualFlags = EEffectVisualFlags.None)
        {
            int appliedValue = math.min(math.max(0, value), GetMissingHealth());
            ModifyCurrentHealth(appliedValue);
            GameRuntimeEvents.NotifyHealthRecoveredPresentation(new CharacterValuePresentationContext(transform.position, this, appliedValue, visualFlags));
        }

        /// <summary>
        /// 恢复法力并发送恢复展示事件。
        /// </summary>
        public void RecoverMana(int value, EEffectVisualFlags visualFlags = EEffectVisualFlags.None)
        {
            int appliedValue = math.min(math.max(0, value), GetMissingMana());
            ModifyCurrentMana(appliedValue);
            GameRuntimeEvents.NotifyManaRecoveredPresentation(new CharacterValuePresentationContext(transform.position, this, appliedValue, visualFlags));
        }

        /// <summary>
        /// 消耗法力并发送消耗展示事件。
        /// 消耗值会被裁到当前法力内，避免写出负数当前值。
        /// </summary>
        public void ConsumeMana(int value, EEffectVisualFlags visualFlags = EEffectVisualFlags.None)
        {
            int appliedValue = math.min(math.max(0, value), GetCurrentMana());
            ModifyCurrentMana(-appliedValue);
            GameRuntimeEvents.NotifyManaConsumedPresentation(new CharacterValuePresentationContext(transform.position, this, appliedValue, visualFlags));
        }

        /// <summary>
        /// 提升基础等级。
        /// 角色升级时可以按配置恢复生命/法力，并解锁该等级新增的正式能力。
        /// </summary>
        public virtual void LevelUp(bool silentMode = false)
        {
            ++m_level;

            if (!silentMode)
            {
                if (m_restoreHealthOnLevelUp)
                {
                    Heal(GetMissingHealth());
                }

                if (m_restoreManaOnLevelUp)
                {
                    RecoverMana(GetMissingMana());
                }
            }

            UnlockFormalGasAbilitiesForLevel(characterSheet.GetFormalGasAbilitiesUnlockedAtLevel(m_level));
            m_levelUpped.Invoke(m_level);
        }

        /// <summary>
        /// 延长临时受击保护时间。
        /// 只取更长值，避免短时命中覆盖正在生效的长保护。
        /// </summary>
        private void ExtendTemporaryInvincibility(float duration)
        {
            m_temporaryInvincibilityTimer = Mathf.Max(m_temporaryInvincibilityTimer, duration);
        }

        /// <summary>
        /// 正式角色 prefab 现已强制挂 ASC，运行时当前值写入口不再允许退回启动缓冲。
        /// 若这里失败，说明正式属性宿主或字段接线已经回归损坏，应直接报错而不是默默双轨。
        /// </summary>
        private void SetFormalCurrentStatOrReportFailure(EStat stat, int value)
        {
            if (TrySetFormalCurrentStat(stat, value))
            {
                return;
            }

            Debug.LogError($"[{nameof(CharacterBase)}] 运行时当前属性写入必须命中正式 ASC，无法为 {name} 写入 {stat}={value}。", this);
        }

        /// <summary>
        /// 通过正式 GAS Modifier 应用当前资源变化。
        /// 调用方传入变化量，这里只做资源上下限裁剪，底层交给 EX-GAS 重算 CurrentValue。
        /// </summary>
        private bool ApplyCurrentResourceDeltaViaFormalModifier(
            EStat stat,
            int delta,
            CharacterBase sourceCharacter)
        {
            if (delta == 0)
            {
                return true;
            }

            int? maxValue = delta > 0
                ? stat switch
                {
                    EStat.Health => GetMaxHealth(),
                    EStat.Mana => GetMaxMana(),
                    _ => null
                }
                : null;

            bool applied = FormalGameplayEffectResourceModifier.TryApplyCurrentStatDelta(
                this,
                stat,
                delta,
                minValue: 0,
                maxValue: maxValue,
                sourceCharacter,
                out _,
                out _);

            if (!applied)
            {
                Debug.LogError($"[{nameof(CharacterBase)}] 正式资源变化必须命中 ASC，无法为 {name} 应用 {stat} delta={delta}。", this);
            }

            return applied;
        }

        /// <summary>
        /// 标量属性读取默认只认正式 ASC。
        /// 仅当角色正式属性系统尚未完成启动初始化时，才允许退回启动快照缓冲。
        /// </summary>
        private int GetFormalBaseStatOrBootstrapBuffer(EStat stat)
        {
            if (TryGetFormalBaseStat(stat, out int value))
            {
                return value;
            }

            return ReadBootstrapBaseStatOrReportFailure(stat);
        }

        /// <summary>
        /// 读取正式当前属性，初始化窗口内允许从 bootstrap buffer 回退。
        /// </summary>
        private int GetFormalCurrentStatOrBootstrapBuffer(EStat stat)
        {
            if (TryGetFormalCurrentStat(stat, out int value))
            {
                return value;
            }

            return ReadBootstrapCurrentStatOrReportFailure(stat);
        }

        /// <summary>
        /// 从启动期基础属性缓冲读取字段。
        /// 窗口关闭后再访问就是接线或初始化顺序错误，必须报错。
        /// </summary>
        private int ReadBootstrapBaseStatOrReportFailure(EStat stat)
        {
            if (IsAttributeBootstrapReadWindowOpen())
            {
                return m_attributeBootstrapBuffer.GetBaseStat(stat);
            }

            Debug.LogError($"[{nameof(CharacterBase)}] 运行时基础属性读取必须命中正式 ASC，无法为 {name} 读取 {stat}。", this);
            return 0;
        }

        /// <summary>
        /// 从启动期当前属性缓冲读取字段。
        /// 窗口关闭后再访问就是正式 ASC 未正确接管。
        /// </summary>
        private int ReadBootstrapCurrentStatOrReportFailure(EStat stat)
        {
            if (IsAttributeBootstrapReadWindowOpen())
            {
                return m_attributeBootstrapBuffer.GetCurrentStat(stat);
            }

            Debug.LogError($"[{nameof(CharacterBase)}] 运行时当前属性读取必须命中正式 ASC，无法为 {name} 读取 {stat}。", this);
            return 0;
        }

        /// <summary>
        /// 创建启动期基础属性快照。
        /// 只服务 Awake 初始化过程，运行时失败后返回空 Stats 并报错。
        /// </summary>
        private Stats CreateBootstrapBaseStatsSnapshotOrReportFailure()
        {
            if (IsAttributeBootstrapReadWindowOpen())
            {
                return m_attributeBootstrapBuffer.CreateBaseStatsSnapshot();
            }

            Debug.LogError($"[{nameof(CharacterBase)}] 基础属性快照必须命中正式 ASC，当前角色无法继续依赖启动期基础快照。", this);
            return new Stats();
        }

        /// <summary>
        /// 创建启动期当前属性快照。
        /// 只服务 Awake 初始化过程，运行时失败后返回空 Stats 并报错。
        /// </summary>
        private Stats CreateBootstrapCurrentStatsSnapshotOrReportFailure()
        {
            if (IsAttributeBootstrapReadWindowOpen())
            {
                return m_attributeBootstrapBuffer.CreateCurrentStatsSnapshot();
            }

            Debug.LogError($"[{nameof(CharacterBase)}] 当前属性快照必须命中正式 ASC，当前角色无法继续依赖启动期当前快照。", this);
            return new Stats();
        }

        /// <summary>
        /// 当前是否仍处在允许读取启动属性缓冲的窗口。
        /// </summary>
        private bool IsAttributeBootstrapReadWindowOpen() => m_isAttributeBootstrapReadWindowOpen;

        /// <summary>
        /// 从当前属性快照提取战斗最小属性集。
        /// </summary>
        private static CombatStatSnapshot CreateCombatStatSnapshotFromCurrentStats(Stats currentStats)
        {
            Stats safeCurrentStats = currentStats ?? new Stats();
            return new CombatStatSnapshot(
                safeCurrentStats[EStat.PhysicalAttack],
                safeCurrentStats[EStat.MagicalAttack],
                safeCurrentStats[EStat.PhysicalDefense],
                safeCurrentStats[EStat.MagicalDefense],
                safeCurrentStats[EStat.Agility],
                safeCurrentStats[EStat.Luck]);
        }
    }
}
