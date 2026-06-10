using System.Linq;
using GAS.General;
using NaughtyAttributes;
using UnityEngine;

namespace GAS.Runtime
{
    [CreateAssetMenu(fileName = "GameplayEffect", menuName = "GAS/GameplayEffect")]
    public class GameplayEffectAsset : ScriptableObject, IGameplayEffectData
    {
        private const string GRP_BASE = "Base";
        private const string GRP_BASE_H = "Base/H";
        private const string GRP_BASE_H_LEFT = "Base/H/Left";
        private const string GRP_BASE_H_RIGHT = "Base/H/Right";

        private const string GRP_DATA = "Data";
        private const string GRP_DATA_H = "Data/H";
        private const string GRP_DATA_TAG = "Data/H/Tags";
        private const string GRP_DATA_MOD = "Data/H/Modifiers";
        private const string GRP_DATA_CUE = "Data/H/Cues";
        private const string GRP_DATA_H2 = "Data/H2";
        private const string GRP_DATA_STACK = "Data/H2/Stack";
        private const string GRP_DATA_GRANTED_ABILITIES = "Data/H2/GrantedAbilities";

        private const int WIDTH_LABEL = 70;

        private const string ERROR_NONE_CUE = "Cue CAN NOT be NONE!";
        private const string ERROR_DURATION = "Duration must be > 0.";
        private const string ERROR_PERIOD_GE_NONE = "Period GameplayEffect CAN NOT be NONE!";
        private const string ERROR_GRANTED_ABILITY_INVALID = "存在无效的Ability!";

        #region Base Info

                                                public string Description;

        #endregion Base Info

        #region Policy

                        [Label(GASTextDefine.LABLE_GE_POLICY)]
                                public EffectsDurationPolicy DurationPolicy = EffectsDurationPolicy.Instant;

                        [EnableIf("CanEditDuration")]
                [ValidateInput("IsDurationConfigurationValid", ERROR_DURATION)]
        [Label(GASTextDefine.LABLE_GE_DURATION)]
                public float Duration;

                [Label(GASTextDefine.LABLE_GE_INTERVAL)]
                [ShowIf("ShouldShowPeriod")]
        [EnableIf("IsDurationalPolicy")]
                        public float Period;

                [Label(GASTextDefine.LABLE_GE_EXEC)]
                [EnableIf("IsPeriodic")]
                [InfoBox(ERROR_PERIOD_GE_NONE, EInfoBoxType.Error)]
        [InfoBox("必须为Instant类型", EInfoBoxType.Error)]
                public GameplayEffectAsset PeriodExecution;

        #endregion Policy

        #region Stack

                                        [EnableIf("IsDurationalPolicy")]
        [InfoBox("瞬时效果无法叠加", EInfoBoxType.Normal)]
        public GameplayEffectStackingConfig Stacking;

#if UNITY_EDITOR
                [ShowIf("CanShowSetStackingCodeButton")]
        [Button("使用资产名称作为堆叠识别码")]
        private void SetStackingCodeNameAsAssetName()
        {
            var stacking = Stacking;
            stacking.stackingCodeName = name;
            Stacking = stacking;
        }
#endif

        #endregion Stack

        #region Granted Abilities

                [EnableIf("IsDurationalPolicy")]
        [InfoBox("瞬时效果无法赋予能力", EInfoBoxType.Normal)]
                [InfoBox(ERROR_GRANTED_ABILITY_INVALID, EInfoBoxType.Error)]
        public GrantedAbilityConfig[] GrantedAbilities;

        #endregion Granted Abilities

        #region Modifiers

                                [InfoBox("依次执行多个修改器, 请注意执行顺序", EInfoBoxType.Normal)]
        [InfoBox("瞬时效果不能修改非Stacking属性", EInfoBoxType.Error)]
        [Label(@"@IsInstantPolicy() ? ""仅在成功应用时执行"":""每次激活时都会执行""")]
        public GameplayEffectModifier[] Modifiers;

        bool IsModifiersHasInvalid()
        {
            if (IsInstantPolicy())
            {
                return Modifiers != null && Modifiers.Any(modifier =>
                {
                    var attributeBase = ReflectionHelper.GetAttribute(modifier.AttributeName);
                    if (attributeBase != null)
                    {
                        return attributeBase.CalculateMode != CalculateMode.Stacking;
                    }

                    return false;
                });
            }

            return false;
        }

        #endregion Modifiers

        #region Tags
        [Label(GASTextDefine.TITLE_GE_TAG_AssetTags)]
        [Tooltip(GASTextDefine.TIP_GE_TAG_AssetTags)]
        [ShowIf("IsDurationalPolicy")]
        public GameplayTag[] AssetTags;

        [Space()]
        [Label(GASTextDefine.TITLE_GE_TAG_GrantedTags)]
        [Tooltip(GASTextDefine.TIP_GE_TAG_GrantedTags)]
        [ShowIf("IsDurationalPolicy")]
        public GameplayTag[] GrantedTags;

        [Space()]
        [Label(GASTextDefine.TITLE_GE_TAG_ApplicationRequiredTags)]
        [Tooltip(GASTextDefine.TIP_GE_TAG_ApplicationRequiredTags)]
        public GameplayTag[] ApplicationRequiredTags;

        [Space()]
        [Label(GASTextDefine.TITLE_GE_TAG_OngoingRequiredTags)]
        [Tooltip(GASTextDefine.TIP_GE_TAG_OngoingRequiredTags)]
        [ShowIf("IsDurationalPolicy")]
        public GameplayTag[] OngoingRequiredTags;

        [Space()]
        [Label(GASTextDefine.TITLE_GE_TAG_RemoveGameplayEffectsWithTags)]
        [Tooltip(GASTextDefine.TIP_GE_TAG_RemoveGameplayEffectsWithTags)]
        public GameplayTag[] RemoveGameplayEffectsWithTags;

        [Space()]
        [Label(GASTextDefine.TITLE_GE_TAG_ApplicationImmunityTags)]
        [Tooltip(GASTextDefine.TIP_GE_TAG_ApplicationImmunityTags)]
        public GameplayTag[] ApplicationImmunityTags;

        #endregion Tags

        #region Cues

                        [ShowIf("IsInstantPolicy")]
        [InfoBox(ERROR_NONE_CUE, EInfoBoxType.Error)]
                [Label(GASTextDefine.TITLE_GE_CUE_CueOnExecute)]
        public GameplayCueInstant[] CueOnExecute;

        [Space()]
                        [ShowIf("IsDurationalPolicy")]
        [InfoBox(ERROR_NONE_CUE, EInfoBoxType.Error)]
                [Label(GASTextDefine.TITLE_GE_CUE_CueDurational)]
        [Tooltip("生命周期完全和GameplayEffect同步")]
        public GameplayCueDurational[] CueDurational;

        [Space()]
                        [ShowIf("IsDurationalPolicy")]
                [Label(GASTextDefine.TITLE_GE_CUE_CueOnAdd)]
        public GameplayCueInstant[] CueOnAdd;

        [Space()]
                        [ShowIf("IsDurationalPolicy")]
                [Label(GASTextDefine.TITLE_GE_CUE_CueOnRemove)]
        public GameplayCueInstant[] CueOnRemove;

        [Space()]
                        [ShowIf("IsDurationalPolicy")]
                [Label(GASTextDefine.TITLE_GE_CUE_CueOnActivate)]
        public GameplayCueInstant[] CueOnActivate;

        [Space()]
                        [ShowIf("IsDurationalPolicy")]
                [Label(GASTextDefine.TITLE_GE_CUE_CueOnDeactivate)]
        public GameplayCueInstant[] CueOnDeactivate;

        #endregion Cues

        // TODO
        [HideInInspector]
        public ExecutionCalculation[] Executions;

        bool IsPeriodic()
        {
            return IsDurationalPolicy() && Period > 0;
        }

        bool CanEditDuration()
        {
            return DurationPolicy == EffectsDurationPolicy.Duration;
        }

        bool ShouldShowPeriod()
        {
            return DurationPolicy != EffectsDurationPolicy.Duration;
        }

        bool IsDurationalPolicy()
        {
            return DurationPolicy == EffectsDurationPolicy.Duration || DurationPolicy == EffectsDurationPolicy.Infinite;
        }

        bool IsInstantPolicy() => DurationPolicy == EffectsDurationPolicy.Instant;

        bool CanShowSetStackingCodeButton()
        {
            return IsDurationalPolicy() && Stacking != null && Stacking.stackingType != StackingType.None;
        }

        bool IsCueExecuteNone() => CueOnExecute != null && CueOnExecute.Any(cue => cue == null);

        bool IsCueDurationalNone()
        {
            return (CueDurational != null && CueDurational.Any(cue => cue == null)) ||
                   (CueOnAdd != null && CueOnAdd.Any(cue => cue == null)) ||
                   (CueOnRemove != null && CueOnRemove.Any(cue => cue == null)) ||
                   (CueOnActivate != null && CueOnActivate.Any(cue => cue == null)) ||
                   (CueOnDeactivate != null && CueOnDeactivate.Any(cue => cue == null));
        }

        bool IsPeriodGameplayEffectNone()
        {
            return IsPeriodic() && PeriodExecution == null;
        }

        bool IsDurationConfigurationValid()
        {
            return DurationPolicy != EffectsDurationPolicy.Duration || Duration > 0f;
        }

        bool IsDurationInvalid() => DurationPolicy == EffectsDurationPolicy.Duration && Duration <= 0;
        bool IsPeriodInvalid() => IsDurationalPolicy() && Period < 0;

        bool IsGrantedAbilitiesInvalid()
        {
            return IsDurationalPolicy() &&
                   GrantedAbilities != null &&
                   GrantedAbilities.Any(abilityConfig => abilityConfig.AbilityAsset == null);
        }

        #region IGameplayEffectData

        public string GetDisplayName() => name;

        public EffectsDurationPolicy GetDurationPolicy() => DurationPolicy;

        public float GetDuration() => Duration;

        public float GetPeriod() => Period;

        public IGameplayEffectData GetPeriodExecution() => PeriodExecution;

        public GameplayTag[] GetAssetTags() => AssetTags;

        public GameplayTag[] GetGrantedTags() => GrantedTags;

        public GameplayTag[] GetApplicationRequiredTags() => ApplicationRequiredTags;

        public GameplayTag[] GetOngoingRequiredTags() => OngoingRequiredTags;

        public GameplayTag[] GetRemoveGameplayEffectsWithTags() => RemoveGameplayEffectsWithTags;

        public GameplayTag[] GetApplicationImmunityTags() => ApplicationImmunityTags;

        public GameplayCueInstant[] GetCueOnExecute() => CueOnExecute;

        public GameplayCueInstant[] GetCueOnRemove() => CueOnRemove;

        public GameplayCueInstant[] GetCueOnAdd() => CueOnAdd;

        public GameplayCueInstant[] GetCueOnActivate() => CueOnActivate;

        public GameplayCueInstant[] GetCueOnDeactivate() => CueOnDeactivate;

        public GameplayCueDurational[] GetCueDurational() => CueDurational;

        public GameplayEffectModifier[] GetModifiers() => Modifiers ?? System.Array.Empty<GameplayEffectModifier>();

        public ExecutionCalculation[] GetExecutions() => Executions ?? System.Array.Empty<ExecutionCalculation>();

        public GrantedAbilityConfig[] GetGrantedAbilities() => GrantedAbilities ?? System.Array.Empty<GrantedAbilityConfig>();

        public GameplayEffectStacking GetStacking() => Stacking == null ? GameplayEffectStacking.None : Stacking.ToRuntimeData();

        #endregion IGameplayEffectData
    }
}
