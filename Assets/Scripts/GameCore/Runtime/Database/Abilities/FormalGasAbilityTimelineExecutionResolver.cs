using System;

namespace FantasyWord.GameCore
{
    public readonly struct FormalGasTimelineExecutionSettings
    {
        public FormalGasTimelineExecutionSettings(float delayBeforeUse, float timeBetweenUses)
        {
            this.delayBeforeUse = Math.Max(0.0f, delayBeforeUse);
            this.timeBetweenUses = Math.Max(0.0f, timeBetweenUses);
        }

        public readonly float delayBeforeUse;
        public readonly float timeBetweenUses;
    }

    public static class FormalGasAbilityTimelineExecutionResolver
    {
        public delegate bool TryResolveTimelineExecutionSettingsHandler(
            int abilityCode,
            out FormalGasTimelineExecutionSettings settings);

        private static TryResolveTimelineExecutionSettingsHandler s_tryResolveTimelineExecutionSettings;

        public static void RegisterTryResolveTimelineExecutionSettingsHandler(
            TryResolveTimelineExecutionSettingsHandler handler)
        {
            s_tryResolveTimelineExecutionSettings = handler ?? throw new ArgumentNullException(nameof(handler));
        }

        public static bool TryResolveTimelineExecutionSettings(
            int abilityCode,
            out FormalGasTimelineExecutionSettings settings)
        {
            settings = default;
            if (abilityCode <= 0)
            {
                return false;
            }

            return s_tryResolveTimelineExecutionSettings != null &&
                s_tryResolveTimelineExecutionSettings.Invoke(abilityCode, out settings);
        }
    }
}
