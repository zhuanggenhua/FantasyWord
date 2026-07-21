using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public abstract partial class CharacterBase
    {
        /// <summary>
        /// 返回 CharacterBase 基础存档块类型。
        /// 派生类可以扩展自己的 DataBlock，但基础角色状态统一从这里开始保存。
        /// </summary>
        protected override Type GetDataBlockType() => typeof(CharacterBaseDataBlock);

        /// <summary>
        /// 保存角色基础运行时状态。
        /// 这里保存等级、当前属性、来源化能力、能力压制、动作/阵营规则和持续效果运行时状态。
        /// </summary>
        protected override void OnSave(PersistableDataBlock block)
        {
            base.OnSave(block);
            CharacterBaseDataBlock characterBlock = block.As<CharacterBaseDataBlock>();
            characterBlock.currentResources = CreateCurrentResourceStateData();
            characterBlock.level = m_level;
            characterBlock.activeAlterationRules = CreateActiveAlterationRuleSnapshots();
            characterBlock.abilityRuntimeStates =
                TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet)
                    ? abilitySet.CreateAbilityRuntimeStates()
                    : System.Array.Empty<CharacterAbilityRuntimeStateData>();
            characterBlock.abilitySources = CreateAbilitySourceDataBlocks();
            characterBlock.abilitySuppressions = CreateAbilitySuppressionDataBlocks();
            characterBlock.temporalEffectRuntimeStates = CreateTemporalEffectRuntimeStates();
        }

        /// <summary>
        /// 加载角色基础运行时状态。
        /// 恢复顺序很关键：先清旧来源，再恢复能力来源和压制，再恢复等级/能力运行时，最后恢复持续效果与当前属性。
        /// </summary>
        protected override void OnLoad(PersistableDataBlock block)
        {
            base.OnLoad(block);
            CharacterBaseDataBlock characterBlock = block.As<CharacterBaseDataBlock>();
            ClearOwnedAbilitySourceRuntimeState();

            // 角色存档只认来源化能力桶，能力来源恢复统一走正式来源记录。
            RestoreAbilitySources(
                characterBlock.abilitySources,
                AddBonusFormalGasAbility);

            RestoreAbilitySuppressions(
                characterBlock.abilitySuppressions,
                AddSourcedFormalGasAbilitySuppression);
            RestoreActiveAlterationRules(characterBlock.activeAlterationRules);

            RestoreLevel(characterBlock.level, () => m_level, () => LevelUp(silentMode: true));
            if (TryGetOwnedAbilitySet(out CharacterAbilitySet loadedAbilitySet))
            {
                loadedAbilitySet.LoadAbilityRuntimeStates(
                    characterBlock.abilityRuntimeStates);
            }

            LoadOwnedTemporalEffects(characterBlock);
            ApplySavedCurrentResourcesToOwnedAttributeTruth(characterBlock.currentResources);
        }

        /// <summary>
        /// 创建来源化能力存档块。
        /// 只保存正式能力编号、来源类型、来源 ID 和叠层数，不保存运行时实例引用。
        /// </summary>
        private CharacterAbilitySourceData[] CreateAbilitySourceDataBlocks()
        {
            return AbilityRuntime.CreateBonusAbilitySourceEntrySnapshot()
                .Select(entry => new CharacterAbilitySourceData
                {
                    formalGasAbilityCode = entry.FormalGasAbilityCode,
                    sourceKind = entry.Source.Kind,
                    sourceId = entry.Source.SourceId,
                    stackCount = entry.StackCount
                })
                .ToArray();
        }

        /// <summary>
        /// 创建来源化能力压制存档块。
        /// 压制和授予分开保存，读档时才能分别重建“拥有能力”和“暂时禁用能力”两类状态。
        /// </summary>
        private CharacterAbilitySourceData[] CreateAbilitySuppressionDataBlocks()
        {
            return AbilityRuntime.CreateSuppressedAbilitySourceEntrySnapshot()
                .Select(entry => new CharacterAbilitySourceData
                {
                    formalGasAbilityCode = entry.FormalGasAbilityCode,
                    sourceKind = entry.Source.Kind,
                    sourceId = entry.Source.SourceId,
                    stackCount = entry.StackCount
                })
                .ToArray();
        }

        /// <summary>
        /// 从存档恢复来源化能力。
        /// addFormalGasAbility 由调用方传入，方便基础存档和运行时快照共用同一恢复逻辑。
        /// </summary>
        private static void RestoreAbilitySources(
            CharacterAbilitySourceData[] abilitySources,
            Func<int, CharacterAbilitySourceKey, int, bool> addFormalGasAbility)
        {
            if (abilitySources == null || abilitySources.Length == 0)
            {
                return;
            }

            foreach (CharacterAbilitySourceData sourceData in abilitySources)
            {
                if (sourceData == null || sourceData.stackCount <= 0)
                {
                    continue;
                }

                CharacterAbilitySourceKey source = new(sourceData.sourceKind, sourceData.sourceId);
                if (sourceData.formalGasAbilityCode > 0)
                {
                    addFormalGasAbility?.Invoke(
                        sourceData.formalGasAbilityCode,
                        source,
                        sourceData.stackCount);
                }
            }
        }

        /// <summary>
        /// 从存档恢复来源化能力压制。
        /// 无效条目会被跳过，避免旧存档或空槽位制造无意义压制状态。
        /// </summary>
        private static void RestoreAbilitySuppressions(
            CharacterAbilitySourceData[] abilitySuppressions,
            Func<int, CharacterAbilitySourceKey, int, bool> addFormalGasAbilitySuppression)
        {
            if (abilitySuppressions == null || abilitySuppressions.Length == 0)
            {
                return;
            }

            foreach (CharacterAbilitySourceData suppressionData in abilitySuppressions)
            {
                if (suppressionData == null || suppressionData.stackCount <= 0)
                {
                    continue;
                }

                CharacterAbilitySourceKey source = new(suppressionData.sourceKind, suppressionData.sourceId);
                if (suppressionData.formalGasAbilityCode > 0)
                {
                    addFormalGasAbilitySuppression?.Invoke(
                        suppressionData.formalGasAbilityCode,
                        source,
                        suppressionData.stackCount);
                }
            }
        }

        /// <summary>
        /// 静默恢复等级。
        /// 只支持向上补级，避免降级时重复触发升级解锁或破坏派生类的降级处理策略。
        /// </summary>
        private static void RestoreLevel(int savedLevel, Func<int> getCurrentLevel, Action levelUpSilently)
        {
            while (getCurrentLevel() < savedLevel)
            {
                levelUpSilently();
            }
        }

        /// <summary>
        /// 持续效果写盘现在由角色正式拥有者自己编排：
        /// 角色只按 runtimeKey 枚举当前 effect，再交给每个 effect 自己回答最小 formal runtime state。
        /// </summary>
        private CharacterTemporalEffectRuntimeStateData[] CreateTemporalEffectRuntimeStates()
        {
            List<CharacterTemporalEffectRuntimeStateData> runtimeStates = new();
            foreach (int runtimeKey in GetOwnedTemporalEffectRuntimeKeySnapshot())
            {
                if (!TryGetOwnedTemporalEffect(runtimeKey, out ITemporalEffect effect) ||
                    effect == null)
                {
                    continue;
                }

                CharacterTemporalEffectRuntimeStateData runtimeState = CreateOwnedTemporalEffectRuntimeState(effect);
                if (runtimeState != null)
                {
                    runtimeStates.Add(runtimeState);
                }
            }

            return runtimeStates.ToArray();
        }

        /// <summary>
        /// 清空并恢复角色拥有的持续效果。
        /// 读档前必须先完成旧 effect，避免对象复用时旧副作用残留。
        /// </summary>
        private void LoadOwnedTemporalEffects(CharacterBaseDataBlock block)
        {
            FinalizeOwnedTemporalEffects(
                RemoveOwnedTemporalEffectsByRuntimeKeySnapshot(
                    GetOwnedTemporalEffectRuntimeKeySnapshot()));

            RestoreLoadedTemporalEffects(block?.temporalEffectRuntimeStates);
        }

        /// <summary>
        /// 注册从存档重建出来的持续效果。
        /// 注册完成后再调用 RestoreRuntimeState，让 effect 能拿到当前角色 owner。
        /// </summary>
        private void RestoreLoadedTemporalEffects(
            CharacterTemporalEffectRuntimeStateData[] runtimeStates)
        {
            ITemporalEffect[] restoredEffects =
                CreateTemporalEffectsReadyForRuntimeRegistration(
                    CreateTemporalEffectsFromRuntimeStates(runtimeStates));

            foreach (ITemporalEffect effect in restoredEffects)
            {
                ITemporalEffect replacedEffect = RegisterOwnedTemporalEffect(effect);
                if (replacedEffect != null)
                {
                    FinalizeOwnedTemporalEffects(replacedEffect);
                }

                effect.RestoreRuntimeState(this);
            }
        }

        /// <summary>
        /// 当前持续效果读档只恢复本地 effect runtime。
        /// 已完成或无法创建的 runtime state 会被跳过，不进入正式注册表。
        /// </summary>
        private static ITemporalEffect[] CreateTemporalEffectsFromRuntimeStates(
            CharacterTemporalEffectRuntimeStateData[] runtimeStates)
        {
            List<ITemporalEffect> effects = new();
            if (runtimeStates == null)
            {
                return Array.Empty<ITemporalEffect>();
            }

            foreach (CharacterTemporalEffectRuntimeStateData runtimeState in runtimeStates)
            {
                if (runtimeState == null)
                {
                    continue;
                }

                if (runtimeState.TryCreateRuntimeEffect(out ITemporalEffect effect) &&
                    effect != null &&
                    !effect.completed)
                {
                    effects.Add(effect);
                }
            }

            return effects.ToArray();
        }

        /// <summary>
        /// 读档恢复由角色拥有者决定最终注册哪些 effect。
        /// 当前运行时只接受按 runtimeKey 的正式注册入口。
        /// 使用 SortedDictionary 保证恢复顺序稳定，避免同一存档在不同运行时得到不同遍历顺序。
        /// </summary>
        private static ITemporalEffect[] CreateTemporalEffectsReadyForRuntimeRegistration(
            ITemporalEffect[] loadedEffectSnapshot)
        {
            if (loadedEffectSnapshot == null)
            {
                return Array.Empty<ITemporalEffect>();
            }

            SortedDictionary<int, ITemporalEffect> effectsByRuntimeKey = new();
            foreach (ITemporalEffect effect in loadedEffectSnapshot)
            {
                if (effect == null || effect.completed || effect.runtimeKey <= 0)
                {
                    continue;
                }

                effectsByRuntimeKey[effect.runtimeKey] = effect;
            }

            return effectsByRuntimeKey.Values.ToArray();
        }

        /// <summary>
        /// 创建轻量运行时快照。
        /// 用于场景切换、队伍成员迁移等不一定落盘的状态转移，字段语义和正式存档块保持一致。
        /// </summary>
        internal CharacterRuntimeStateData CreateRuntimeState()
        {
            return new CharacterRuntimeStateData
            {
                identifier = GetPersistentIdentifier(),
                state = CapturePersistableState(),
                position = transform.position,
                rotation = transform.rotation,
                scale = transform.localScale,
                lookAtDirection = m_lookAtDirection,
                controllerData = m_controller?.CreateDataBlock(),
                level = m_level,
                currentResources = CreateCurrentResourceStateData(),
                activeAlterationRules = CreateActiveAlterationRuleSnapshots(),
                abilityRuntimeStates =
                    TryGetOwnedAbilitySet(out CharacterAbilitySet abilitySet)
                        ? abilitySet.CreateAbilityRuntimeStates()
                        : System.Array.Empty<CharacterAbilityRuntimeStateData>(),
                abilitySources = CreateAbilitySourceDataBlocks(),
                abilitySuppressions = CreateAbilitySuppressionDataBlocks(),
                temporalEffectRuntimeStates = CreateTemporalEffectRuntimeStates()
            };
        }

        /// <summary>
        /// 加载轻量运行时快照。
        /// 和 OnLoad 保持同一恢复顺序，确保能力来源、等级、槽位运行时、持续效果和当前资源不会互相覆盖。
        /// </summary>
        internal void LoadRuntimeState(CharacterRuntimeStateData runtimeState)
        {
            if (runtimeState == null || !ApplyPersistableState(runtimeState.state))
            {
                return;
            }

            transform.position = runtimeState.position;
            transform.rotation = runtimeState.rotation;
            transform.localScale = runtimeState.scale;
            SetLookAtDirection(runtimeState.lookAtDirection);
            m_controller?.LoadDataBlock(runtimeState.controllerData);
            ClearOwnedAbilitySourceRuntimeState();

            RestoreAbilitySources(
                runtimeState.abilitySources,
                AddBonusFormalGasAbility);

            RestoreAbilitySuppressions(
                runtimeState.abilitySuppressions,
                AddSourcedFormalGasAbilitySuppression);
            RestoreActiveAlterationRules(runtimeState.activeAlterationRules);

            RestoreLevel(runtimeState.level, () => m_level, () => LevelUp(silentMode: true));
            if (TryGetOwnedAbilitySet(out CharacterAbilitySet loadedAbilitySet))
            {
                loadedAbilitySet.LoadAbilityRuntimeStates(
                    runtimeState.abilityRuntimeStates);
            }

            RestoreLoadedTemporalEffects(runtimeState.temporalEffectRuntimeStates);
            ApplySavedCurrentResourcesToOwnedAttributeTruth(runtimeState.currentResources);
        }
    }
}
