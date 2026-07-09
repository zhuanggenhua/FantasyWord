using System;
using System.Collections.Generic;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 能力型持续效果的共享最小帮助器。
    /// 这里只收三类效果都在重复做的能力引用/反解/展示拼接，
    /// 不承接生命周期或规则判断，避免再长出第二套玩法真相。
    /// </summary>
    internal static class TemporalAbilityEffectSupport
    {
        public static int[] CloneFormalGasAbilityCodes(int[] formalGasAbilityCodes)
        {
            return formalGasAbilityCodes != null
                ? (int[])formalGasAbilityCodes.Clone()
                : Array.Empty<int>();
        }

        public static int[] CreateFormalGasAbilityCodes(int[] formalGasAbilityCodes)
        {
            List<int> codes = new();
            AddFormalGasAbilityCodes(codes, formalGasAbilityCodes);
            return codes.ToArray();
        }

        public static string CreateAbilityListDetails(int[] formalGasAbilityCodes)
        {
            if (formalGasAbilityCodes == null || formalGasAbilityCodes.Length == 0)
            {
                return string.Empty;
            }

            List<string> abilityNames = new();
            if (formalGasAbilityCodes != null)
            {
                foreach (int formalGasAbilityCode in formalGasAbilityCodes)
                {
                    if (formalGasAbilityCode <= 0)
                    {
                        continue;
                    }

                    if (FormalGasAbilityIdentityResolver.TryResolveAbilityIdentity(
                        formalGasAbilityCode,
                        out FormalGasAbilityIdentity identity) &&
                        !string.IsNullOrWhiteSpace(identity.DisplayName))
                    {
                        abilityNames.Add(identity.DisplayName);
                        continue;
                    }

                    abilityNames.Add($"EX-GAS Ability {formalGasAbilityCode}");
                }
            }

            return string.Join(", ", abilityNames);
        }

        private static void AddFormalGasAbilityCodes(List<int> codes, int[] formalGasAbilityCodes)
        {
            if (formalGasAbilityCodes == null)
            {
                return;
            }

            foreach (int formalGasAbilityCode in formalGasAbilityCodes)
            {
                AddFormalGasAbilityCode(codes, formalGasAbilityCode);
            }
        }

        private static void AddFormalGasAbilityCode(List<int> codes, int formalGasAbilityCode)
        {
            if (formalGasAbilityCode <= 0 || codes.Contains(formalGasAbilityCode))
            {
                return;
            }

            codes.Add(formalGasAbilityCode);
        }

    }
}
