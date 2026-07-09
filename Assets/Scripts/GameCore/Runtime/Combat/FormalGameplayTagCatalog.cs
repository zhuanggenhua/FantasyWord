using System;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 当前项目对 EX-GAS 2.0 的最小正式标签码占位。
    /// 现阶段只保留角色动作锁读取需要的控制标签编码；
    /// 未接入真实标签生成表前，默认返回 false，避免继续依赖错误的旧 GameplayTag 对象模型。
    /// </summary>
    public static class FormalGameplayTagCatalog
    {
        public const int EventAttackingTagCode = 3003;

        public static readonly FormalGameplayTagDefinition AttackingEvent =
            new("event.attacking", "正在攻击", EventAttackingTagCode);

        public static readonly FormalGameplayTagDefinition TemporalBuffEffect =
            new("effect.buff", "增益效果", 0);

        public static readonly FormalGameplayTagDefinition TemporalDebuffEffect =
            new("effect.debuff", "减益效果", 0);

        public static readonly FormalGameplayTagDefinition ControlEffect =
            new("effect.debuff.control", "控制效果", 0);

        public static readonly FormalGameplayTagDefinition StunControlEffect =
            new("effect.debuff.control.stun", "眩晕", 0);

        public static readonly FormalGameplayTagDefinition SilenceControlEffect =
            new("effect.debuff.control.silence", "沉默", 0);

        public static readonly FormalGameplayTagDefinition RootControlEffect =
            new("effect.debuff.control.root", "定身", 0);

        public static bool HasRegisteredControlTags =>
            StunControlEffect.TagCode > 0 ||
            SilenceControlEffect.TagCode > 0 ||
            RootControlEffect.TagCode > 0;

        public static bool TryGetTemporalEffectTagCode(EEffectType effectType, out int tagCode)
        {
            tagCode = effectType switch
            {
                EEffectType.Buff => TemporalBuffEffect.TagCode,
                EEffectType.Debuff => TemporalDebuffEffect.TagCode,
                _ => 0
            };

            return tagCode > 0;
        }

        public static bool TryGetControlEffectTagCode(EControlType controlType, out int tagCode)
        {
            tagCode = controlType switch
            {
                EControlType.Stun => StunControlEffect.TagCode,
                EControlType.Silence => SilenceControlEffect.TagCode,
                EControlType.Root => RootControlEffect.TagCode,
                _ => 0
            };

            return tagCode > 0;
        }

        public static FormalGameplayTagDefinition GetTemporalEffectDefinition(EEffectType effectType)
        {
            return effectType switch
            {
                EEffectType.Buff => TemporalBuffEffect,
                EEffectType.Debuff => TemporalDebuffEffect,
                _ => throw new ArgumentOutOfRangeException(nameof(effectType), effectType, "未知的持续效果分类。")
            };
        }

        public static FormalGameplayTagDefinition GetControlEffectDefinition(EControlType controlType)
        {
            return controlType switch
            {
                EControlType.Stun => StunControlEffect,
                EControlType.Silence => SilenceControlEffect,
                EControlType.Root => RootControlEffect,
                _ => throw new ArgumentOutOfRangeException(nameof(controlType), controlType, "未知的控制效果分类。")
            };
        }
    }

    public readonly struct FormalGameplayTagDefinition
    {
        public FormalGameplayTagDefinition(string stableId, string displayName, int tagCode)
        {
            StableId = stableId ?? throw new ArgumentNullException(nameof(stableId));
            DisplayName = displayName ?? throw new ArgumentNullException(nameof(displayName));
            TagCode = tagCode;
        }

        public string StableId { get; }
        public string DisplayName { get; }
        public int TagCode { get; }
    }
}
