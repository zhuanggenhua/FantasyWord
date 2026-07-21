using System;
using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.Events;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 装备操作结果。
    /// 背包、角色动作锁和装备槽规则都通过该结果向 UI 反馈失败原因。
    /// </summary>
    public enum EEquipmentOperationResult
    {
        /// <summary>装备操作通过全部检查。</summary>
        Valid,

        /// <summary>装备或卸装会让生命低于规则允许值。</summary>
        NotEnoughHealth,

        /// <summary>装备或卸装会让法力低于规则允许值。</summary>
        NotEnoughMana,

        /// <summary>目标角色、装备或槽位无效。</summary>
        InvalidTarget,

        /// <summary>背包中缺少对应物品。</summary>
        MissingItem,

        /// <summary>角色当前动作状态不允许装备操作。</summary>
        ActionLocked,
    }

    /// <summary>
    /// 角色 Actor 的持久化数据块。
    /// 在 CharacterBase 基础上追加经验、自由属性点、装备槽和快捷技能槽。
    /// </summary>
    [Serializable]
    public class CharacterActorDataBlock : CharacterBaseDataBlock
    {
        /// <summary>已经消耗的自由属性点。</summary>
        public int usedPoints;

        /// <summary>当前累计经验。</summary>
        public int experience;

        /// <summary>玩家分配的自定义属性点快照。</summary>
        public Stats customStats;

        /// <summary>装备槽存档快照。</summary>
        public CharacterEquipmentSlotData[] equipmentSlots;

        /// <summary>快捷技能槽存档快照。</summary>
        public CharacterAbilitySlotData[] quickAbilitySlots;
    }

    /// <summary>
    /// 角色局部运行时快照。
    /// 玩家队伍、中立角色和敌对角色都使用同一份角色状态结构。
    /// </summary>
    [Serializable]
    public class CharacterActorRuntimeStateData : CharacterRuntimeStateData
    {
        /// <summary>运行时已经消耗的自由属性点。</summary>
        public int usedPoints;

        /// <summary>运行时累计经验。</summary>
        public int experience;

        /// <summary>运行时自定义属性点快照。</summary>
        public Stats customStats;

        /// <summary>运行时装备槽快照。</summary>
        public CharacterEquipmentSlotData[] equipmentSlots;

        /// <summary>运行时快捷技能槽快照。</summary>
        public CharacterAbilitySlotData[] quickAbilitySlots;
    }

    /// <summary>
    /// 装备槽存档条目。
    /// slotType 是槽位真相，equipment 是数据库引用，避免保存运行时装备实例。
    /// </summary>
    [Serializable]
    public class CharacterEquipmentSlotData
    {
        /// <summary>装备所在槽位类型，是恢复时的槽位真相。</summary>
        public EEquipmentType slotType;

        /// <summary>装备数据库引用；为空表示该槽位没有装备。</summary>
        public DatabaseEntryReference<Equipment> equipment;
    }

    /// <summary>
    /// 快捷技能槽存档条目。
    /// 只保存正式 EX-GAS 能力编号，运行时能力实例由 CharacterAbilitySet 重建。
    /// </summary>
    [Serializable]
    public class CharacterAbilitySlotData
    {
        /// <summary>快捷技能槽索引。</summary>
        public int slotIndex;

        /// <summary>正式 EX-GAS 能力编号。</summary>
        public int formalGasAbilityCode;
    }

    /// <summary>
    /// 可成长、可装备、可被队伍/AI 控制的正式角色实体。
    /// 它在 CharacterBase 基础上增加经验等级、自定义属性点、装备与快捷能力槽恢复。
    /// </summary>
    /// <remarks>
    /// 这里是可成长角色的玩法 owner。表现层动画只通过 <see cref="ICharacterAnimationDriver"/> 入口接入；
    /// 背包物品、装备槽和快捷技能槽仍由对应角色组件维护，Actor 只负责存档编排和属性结算。
    /// </remarks>
    public partial class CharacterActor : CharacterBase
    {
        [SerializeField]
        [LabelText("升级音效")]
        [Tooltip("非静默升级时播放的音频配置。")]
        private AudioClipResolver m_levelUpSound;

        [SerializeField]
        [LabelText("动画驱动组件")]
        [Tooltip("正式统一角色 Prefab 上的动画驱动。为空时回退到旧动画策略。")]
        private MonoBehaviour m_animationDriverBehaviour;

        /// <summary>当前累计经验。</summary>
        public int experience => m_experience;

        /// <summary>下一级所需累计经验。</summary>
        public int nextLevelExperience => GetTotalExpRequirement(m_level + 1);

        /// <summary>当前可分配自由属性点。</summary>
        public int availablePoints => GetAvailablePoints(m_level, m_sheet.pointsPerLevel);

        /// <summary>玩家自定义属性点快照。</summary>
        public Stats customStats => CreateCustomStatsSnapshot();

        /// <summary>已经消耗的自由属性点。</summary>
        public int usedPoints => m_usedPoints;

        // 玩家分配的成长属性只保存在 Actor 层，最终属性由 Sheet、自由点和装备贡献合成。
        private Stats m_customStats = new();

        // 已用点数单独记录，避免只靠 Stats 反推时丢失配置版本变化带来的语义。
        private int m_usedPoints = 0;

        // 经验保存为累计值，升级时通过 Sheet 曲线反复结算。
        private int m_experience = 0;

        // 正式动画驱动接管死亡动作后，复活必须先解除动画锁，再回到默认动作。
        private bool m_usesFormalDeathAnimation;

        /// <summary>
        /// 复活角色并恢复动画控制。
        /// 正式死亡动画会锁住表现层，复活时必须显式解锁，否则角色逻辑已活但画面仍停在死亡态。
        /// </summary>
        public override void Revive()
        {
            base.Revive();
            if (m_usesFormalDeathAnimation)
            {
                m_usesFormalDeathAnimation = false;
                if (m_animationDriverBehaviour is ICharacterAnimationDriver animationDriver)
                {
                    animationDriver.ClearAnimationLock();
                    if (animationDriver.TryPlayDefaultAnimation())
                    {
                        return;
                    }
                }

                Debug.LogError(
                    $"角色“{name}”复活时无法通过正式动画驱动播放默认动作。"
                    + "请检查统一角色 Prefab 的动画驱动引用和默认动作配置。",
                    this);
                return;
            }

            m_animationStrategy?.Resume();
        }

        /// <summary>
        /// 计算到指定等级前需要的累计经验。
        /// 等级曲线仍由 CharacterSheet 提供，Actor 不复制成长表。
        /// </summary>
        public int GetTotalExpRequirement(int level)
        {
            int total = 0;

            for (int i = 1; i < level; i++)
            {
                total += m_sheet.GetExperienceRequiredAtLevel(i);
            }

            return total;
        }

        /// <summary>
        /// 增加经验并处理连续升级。
        /// silentMode 用于读档或初始化，避免重复播放升级反馈。
        /// </summary>
        public void AddExperience(int experience, bool silentMode = false)
        {
            Debug.Assert(experience > 0, "Cannot add a negative amount of experience.");
            GameRuntimeEvents.NotifyCharacterExperienceGained(this, experience);
            m_experience += experience;

            while (m_experience >= GetTotalExpRequirement(m_level + 1))
            {
                LevelUp(silentMode);
            }
        }

        /// <summary>
        /// 增加玩家自定义属性点并刷新最终基础属性。
        /// </summary>
        public void AddCustomStats(Stats customStats)
        {
            m_customStats += customStats;
            RefreshResolvedStats();
        }

        /// <summary>
        /// 记录已消耗点数。
        /// 这里只记录消耗账，不直接修改属性；属性增加由 <see cref="AddCustomStats"/> 处理。
        /// </summary>
        public void LogUsedPoints(int points)
        {
            m_usedPoints += points;
        }

        /// <summary>
        /// 初始化 Actor 属性。
        /// Actor 的基础属性由 Sheet、自由属性点和装备贡献共同结算。
        /// </summary>
        protected override void InitializeStats()
        {
            RefreshResolvedStats();
        }

        /// <summary>
        /// 重新结算并写回角色基础属性真相。
        /// </summary>
        internal void RefreshResolvedStats()
        {
            SetResolvedBaseStats(BuildResolvedStats());
        }

        /// <summary>
        /// 装备变化时刷新 Actor 最终属性。
        /// CharacterEquipment 只提供装备贡献，Actor 负责把成长和装备合并成正式基础属性。
        /// </summary>
        internal override void RefreshResolvedStatsForEquipmentRuntime()
        {
            RefreshResolvedStats();
        }

        /// <summary>
        /// 构建最终基础属性：等级 Sheet 属性 + 自由点属性 + 装备属性贡献。
        /// </summary>
        private Stats BuildResolvedStats()
        {
            return m_sheet.GetStatsAtLevel(m_level)
                + CreateCustomStatsSnapshot()
                + CreateEquipmentStatContributionSnapshot();
        }

        /// <summary>
        /// 提升等级并刷新成长属性。
        /// 非静默模式会发送升级事件和音效请求。
        /// </summary>
        public override void LevelUp(bool silentMode = false)
        {
            base.LevelUp(silentMode);
            RefreshResolvedStats();

            if (!silentMode)
            {
                GameRuntimeEvents.NotifyCharacterLevelUp(this, m_level);
                GameRuntimeEvents.RequestAudioPlayback(m_levelUpSound);
            }
        }

        /// <summary>
        /// 设置等级到指定值。
        /// 降级直接写入并刷新；升级仍走 LevelUp，保证解锁能力和成长流程一致。
        /// </summary>
        internal void SetLevel(int level)
        {
            int targetLevel = Mathf.Clamp(level, Constants.MinLevel, Constants.MaxLevel);
            if (targetLevel < m_level)
            {
                m_level = targetLevel;
                RefreshResolvedStats();
                return;
            }

            while (m_level < targetLevel)
            {
                LevelUp(silentMode: true);
            }

            RefreshResolvedStats();
        }

        /// <summary>
        /// Actor 死亡时停止旧动画策略，并通知玩家系统。
        /// 统一动画驱动接管死亡动作时，不再暂停旧策略，避免双重控制。
        /// </summary>
        protected override void OnDeath()
        {
            m_destroyOnDeath = false;
            base.OnDeath();
            if (!m_usesFormalDeathAnimation)
            {
                m_animationStrategy?.Pause();
            }

            GameManager.PlayerSystem.NotifyCharacterKilled(this);
        }

        /// <summary>
        /// 刷新移动动画。
        /// 有正式动画驱动时使用统一驱动，否则回退 CharacterBase 的旧动画策略。
        /// </summary>
        protected override void UpdateMovementAnimation(Vector2 movement)
        {
            if (m_animationDriverBehaviour is ICharacterAnimationDriver animationDriver)
            {
                animationDriver.SetMovement(movement);
                return;
            }

            base.UpdateMovementAnimation(movement);
        }

        /// <summary>
        /// 尝试播放受击动画。
        /// 配置了正式动画驱动但播放失败时直接报错，避免静默回退掩盖 Prefab 接线问题。
        /// </summary>
        protected override bool TryPlayHitAnimation()
        {
            if (m_animationDriverBehaviour == null)
            {
                return base.TryPlayHitAnimation();
            }

            if (m_animationDriverBehaviour is ICharacterAnimationDriver animationDriver &&
                animationDriver.TryPlayDamageAnimation())
            {
                return true;
            }

            Debug.LogError(
                $"角色“{name}”无法通过正式动画驱动播放受击动作。"
                + "请检查统一角色 Prefab 的动画驱动引用、受击动作配置、动画数据库和 Animator 状态。",
                this);
            return false;
        }

        /// <summary>
        /// 尝试播放死亡动画。
        /// 正式动画驱动成功锁定死亡动作时返回 false，让 CharacterBase 不再等待旧动画策略回调。
        /// </summary>
        protected override bool TryPlayDeathAnimation()
        {
            if (m_animationDriverBehaviour == null)
            {
                return base.TryPlayDeathAnimation();
            }

            m_usesFormalDeathAnimation = true;
            if (m_animationDriverBehaviour is ICharacterAnimationDriver animationDriver &&
                animationDriver.TryLockDeathAnimation())
            {
                // 死亡是终止态：立即收口玩法逻辑，同时锁住非循环死亡动作，
                // 防止尚未结束的攻击 Cue 或普通待机同步覆盖尸体表现。
                return false;
            }

            Debug.LogError(
                $"角色“{name}”无法通过正式动画驱动播放死亡动作。"
                + "请检查统一角色 Prefab 的动画驱动引用、死亡动作配置、动画数据库和 Animator 状态。",
                this);
            return false;
        }

        /// <summary>
        /// 返回 Actor 专用存档块类型。
        /// </summary>
        protected override Type GetDataBlockType() => typeof(CharacterActorDataBlock);

        /// <summary>
        /// 保存 Actor 扩展状态。
        /// 基础角色状态由 CharacterBase 保存，这里只追加成长、装备槽和快捷技能槽。
        /// </summary>
        protected override void OnSave(PersistableDataBlock block)
        {
            base.OnSave(block);
            var actorBlock = block.As<CharacterActorDataBlock>();
            actorBlock.usedPoints = m_usedPoints;
            actorBlock.experience = m_experience;
            actorBlock.customStats = CreateCustomStatsSnapshot();
            actorBlock.equipmentSlots = CreateEquipmentSlotDataSnapshot(GameManager.Database);
            actorBlock.quickAbilitySlots = CreateEquippedAbilitySlotDataSnapshot(GameManager.Database);
        }

        /// <summary>
        /// 加载 Actor 扩展状态。
        /// 装备先恢复并刷新基础属性，再交给 CharacterBase 恢复当前属性和正式能力实例，最后恢复快捷技能槽布局。
        /// </summary>
        protected override void OnLoad(PersistableDataBlock block)
        {
            var actorBlock = block.As<CharacterActorDataBlock>();
            m_usedPoints = actorBlock.usedPoints;
            m_customStats = actorBlock.customStats != null ? actorBlock.customStats.Clone() : new Stats();

            if (actorBlock.experience > 0)
            {
                AddExperience(actorBlock.experience, true);
            }

            RestoreEquipmentFromSlotData(
                actorBlock.equipmentSlots,
                reference => GameManager.Database.LoadFromReference(reference));

            RefreshResolvedStats();
            base.OnLoad(block); // CharacterBase 先恢复正式能力实例、等级与当前属性，再由 CharacterAbilitySet 恢复技能槽布局。
            RestoreEquippedAbilitiesFromSlotData(actorBlock.quickAbilitySlots);
        }

        /// <summary>
        /// 创建运行时快照。
        /// 用于队伍/场景切换这类不一定走完整存档文件的角色状态转移。
        /// </summary>
        internal CharacterActorRuntimeStateData CreateActorRuntimeState()
        {
            CharacterRuntimeStateData baseRuntimeState = CreateRuntimeState();
            return new CharacterActorRuntimeStateData
            {
                identifier = baseRuntimeState.identifier,
                state = baseRuntimeState.state,
                position = baseRuntimeState.position,
                rotation = baseRuntimeState.rotation,
                scale = baseRuntimeState.scale,
                lookAtDirection = baseRuntimeState.lookAtDirection,
                controllerData = baseRuntimeState.controllerData,
                level = baseRuntimeState.level,
                currentResources = baseRuntimeState.currentResources,
                activeAlterationRules = baseRuntimeState.activeAlterationRules,
                abilityRuntimeStates = baseRuntimeState.abilityRuntimeStates,
                abilitySources = baseRuntimeState.abilitySources,
                abilitySuppressions = baseRuntimeState.abilitySuppressions,
                temporalEffectRuntimeStates = baseRuntimeState.temporalEffectRuntimeStates,
                usedPoints = m_usedPoints,
                experience = m_experience,
                customStats = CreateCustomStatsSnapshot(),
                equipmentSlots = CreateEquipmentSlotDataSnapshot(GameManager.Database),
                quickAbilitySlots = CreateEquippedAbilitySlotDataSnapshot(GameManager.Database)
            };
        }

        /// <summary>
        /// 从运行时快照恢复 Actor 状态。
        /// 恢复顺序和 OnLoad 保持一致，避免装备、当前属性和快捷技能槽互相覆盖。
        /// </summary>
        internal void LoadActorRuntimeState(CharacterActorRuntimeStateData runtimeState)
        {
            if (runtimeState == null)
            {
                return;
            }

            m_usedPoints = runtimeState.usedPoints;
            m_customStats = runtimeState.customStats != null ? runtimeState.customStats.Clone() : new Stats();

            if (runtimeState.experience > 0)
            {
                AddExperience(runtimeState.experience, true);
            }

            RestoreEquipmentFromSlotData(
                runtimeState.equipmentSlots,
                reference => GameManager.Database.LoadFromReference(reference));

            RefreshResolvedStats();
            LoadRuntimeState(runtimeState);
            RestoreEquippedAbilitiesFromSlotData(runtimeState.quickAbilitySlots);
        }

        /// <summary>
        /// 创建自定义属性快照。
        /// 返回克隆，避免外部直接改写 Actor 内部成长属性。
        /// </summary>
        private Stats CreateCustomStatsSnapshot()
        {
            return m_customStats.Clone();
        }

        /// <summary>
        /// 计算当前还可分配的自由属性点。
        /// </summary>
        private int GetAvailablePoints(int currentLevel, int pointsPerLevel)
        {
            return pointsPerLevel * (currentLevel - Constants.MinLevel) - m_usedPoints;
        }
    }
}
