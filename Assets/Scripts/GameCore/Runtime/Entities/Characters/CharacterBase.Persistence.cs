using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public abstract partial class CharacterBase
    {
        protected override Type GetDataBlockType() => typeof(CharacterBaseDataBlock);

        protected override void OnSave(PersistableDataBlock block)
        {
            base.OnSave(block);
            CharacterBaseDataBlock characterBlock = block.As<CharacterBaseDataBlock>();
            characterBlock.currentStats = CreateCurrentStatsSnapshot();
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
            ApplySavedCurrentStatsToOwnedAttributeTruth(characterBlock.currentStats);
        }

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

        private void LoadOwnedTemporalEffects(CharacterBaseDataBlock block)
        {
            FinalizeOwnedTemporalEffects(
                RemoveOwnedTemporalEffectsByRuntimeKeySnapshot(
                    GetOwnedTemporalEffectRuntimeKeySnapshot()));

            RestoreLoadedTemporalEffects(block?.temporalEffectRuntimeStates);
        }

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
                currentStats = CreateCurrentStatsSnapshot(),
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
            ApplySavedCurrentStatsToOwnedAttributeTruth(runtimeState.currentStats);
        }
    }
}

