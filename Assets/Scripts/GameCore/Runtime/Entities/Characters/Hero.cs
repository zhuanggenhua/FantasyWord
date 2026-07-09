using System;
using UnityEngine;
using UnityEngine.Events;

namespace FantasyWord.GameCore
{
    public enum EEquipmentOperationResult
    {
        Valid,
        NotEnoughHealth,
        NotEnoughMana,
        InvalidTarget,
        MissingItem,
        ActionLocked,
    }

    [Serializable]
    public class HeroDataBlock : CharacterBaseDataBlock
    {
        public int usedPoints;
        public int experience;
        public Stats customStats;
        public CharacterEquipmentSlotData[] equipmentSlots;
        public CharacterAbilitySlotData[] quickAbilitySlots;
    }

    /// <summary>
    /// 玩家 Hero 的局部运行时快照。
    /// 它只服务 PlayerSystem 的正式玩家状态恢复，不再借 PersistableDataBlock 壳做 DTO。
    /// </summary>
    [Serializable]
    public class HeroRuntimeStateData : CharacterRuntimeStateData
    {
        public int usedPoints;
        public int experience;
        public Stats customStats;
        public CharacterEquipmentSlotData[] equipmentSlots;
        public CharacterAbilitySlotData[] quickAbilitySlots;
    }

    [Serializable]
    public class CharacterEquipmentSlotData
    {
        public EEquipmentType slotType;
        public DatabaseEntryReference<Equipment> equipment;
    }

    [Serializable]
    public class CharacterAbilitySlotData
    {
        public int slotIndex;
        public int formalGasAbilityCode;
    }

    public class Hero : Character<HeroSheet>
    {
        [Header("Audio")]
        [SerializeField] private AudioClipResolver m_levelUpSound;

        public int experience => m_experience;
        public int nextLevelExperience => GetTotalExpRequirement(m_level + 1);
        public int availablePoints => GetAvailablePoints(m_level, m_sheet.pointsPerLevel);
        public Stats customStats => CreateCustomStatsSnapshot();
        public int usedPoints => m_usedPoints;

        private Stats m_customStats = new();
        private int m_usedPoints = 0;
        private int m_experience = 0;

        public override void Revive()
        {
            base.Revive();
            m_animationStrategy?.Resume();
        }

        public int GetTotalExpRequirement(int level)
        {
            int total = 0;

            for (int i = 1; i < level; i++)
            {
                total += m_sheet.GetExperienceRequiredAtLevel(i);
            }

            return total;
        }

        public void AddExperience(int experience, bool silentMode = false)
        {
            Debug.Assert(experience > 0, "Cannot add a negative amount of experience.");
            GameRuntimeEvents.NotifyHeroExperienceGained(experience);
            m_experience += experience;

            while (m_experience >= GetTotalExpRequirement(m_level + 1))
            {
                LevelUp(silentMode);
            }
        }

        public void AddCustomStats(Stats customStats)
        {
            m_customStats += customStats;
            RefreshResolvedStats();
        }

        public void LogUsedPoints(int points)
        {
            m_usedPoints += points;
        }

        protected override void InitializeStats()
        {
            RefreshResolvedStats();
        }

        internal void RefreshResolvedStats()
        {
            SetResolvedBaseStats(BuildResolvedStats());
        }

        internal override void RefreshResolvedStatsForEquipmentRuntime()
        {
            RefreshResolvedStats();
        }

        private Stats BuildResolvedStats()
        {
            return m_sheet.baseStats
                + CreateCustomStatsSnapshot()
                + CreateEquipmentStatContributionSnapshot();
        }

        public override void LevelUp(bool silentMode = false)
        {
            base.LevelUp(silentMode);

            if (!silentMode)
            {
                GameRuntimeEvents.NotifyHeroLevelUp(m_level);
                GameRuntimeEvents.RequestAudioPlayback(m_levelUpSound);
            }
        }

        protected override void OnDeath()
        {
            m_destroyOnDeath = false; // Prevents the Hero GameObject from being destroyed, so it can be used in the death screen.
            base.OnDeath();
            m_animationStrategy?.Pause();
            if (GameManager.Exists() && GameManager.TryGetSystem<PlayerSystem>(out PlayerSystem playerSystem))
            {
                playerSystem.NotifyHeroKilled(this);
            }
        }

        protected override Type GetDataBlockType() => typeof(HeroDataBlock);

        protected override void OnSave(PersistableDataBlock block)
        {
            base.OnSave(block);
            var heroBlock = block.As<HeroDataBlock>();
            heroBlock.usedPoints = m_usedPoints;
            heroBlock.experience = m_experience;
            heroBlock.customStats = CreateCustomStatsSnapshot();
            heroBlock.equipmentSlots = CreateEquipmentSlotDataSnapshot(GameManager.Database);
            heroBlock.quickAbilitySlots = CreateEquippedAbilitySlotDataSnapshot(GameManager.Database);
        }

        protected override void OnLoad(PersistableDataBlock block)
        {
            var heroBlock = block.As<HeroDataBlock>();
            m_usedPoints = heroBlock.usedPoints;
            m_customStats = heroBlock.customStats != null ? heroBlock.customStats.Clone() : new Stats();

            if (heroBlock.experience > 0)
            {
                AddExperience(heroBlock.experience, true);
            }

            RestoreEquipmentFromSlotData(
                heroBlock.equipmentSlots,
                reference => GameManager.Database.LoadFromReference(reference));

            RefreshResolvedStats();
            base.OnLoad(block); // CharacterBase 先恢复正式能力实例、等级与当前属性，再由 CharacterAbilitySet 恢复技能槽布局。
            RestoreEquippedAbilitiesFromSlotData(heroBlock.quickAbilitySlots);
        }

        protected override void OnStuckInAWall()
        {
            Debug.Assert(false, "Oops! The player is stuck in a wall. This should never happen.");
        }

        internal HeroRuntimeStateData CreateHeroRuntimeState()
        {
            CharacterRuntimeStateData baseRuntimeState = CreateRuntimeState();
            return new HeroRuntimeStateData
            {
                identifier = baseRuntimeState.identifier,
                state = baseRuntimeState.state,
                position = baseRuntimeState.position,
                rotation = baseRuntimeState.rotation,
                scale = baseRuntimeState.scale,
                lookAtDirection = baseRuntimeState.lookAtDirection,
                controllerData = baseRuntimeState.controllerData,
                level = baseRuntimeState.level,
                currentStats = baseRuntimeState.currentStats,
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

        internal void LoadHeroRuntimeState(HeroRuntimeStateData runtimeState)
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

        private Stats CreateCustomStatsSnapshot()
        {
            return m_customStats.Clone();
        }

        private int GetAvailablePoints(int currentLevel, int pointsPerLevel)
        {
            return pointsPerLevel * (currentLevel - Constants.MinLevel) - m_usedPoints;
        }
    }
}
