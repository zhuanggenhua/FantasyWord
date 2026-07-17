using System;
using System.Collections.Generic;
using UnityEngine;

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

        public static bool HasConfiguredFormalGasAbilityCodes(params int[][] formalGasAbilityCodeGroups)
        {
            if (formalGasAbilityCodeGroups == null)
            {
                return false;
            }

            foreach (int[] formalGasAbilityCodes in formalGasAbilityCodeGroups)
            {
                if (formalGasAbilityCodes != null && formalGasAbilityCodes.Length > 0)
                {
                    return true;
                }
            }

            return false;
        }

        public static void EnsureFormalGasAbilityCodeConfiguration(
            string ownerName,
            string fieldName,
            int[] formalGasAbilityCodes)
        {
            if (!TryValidateFormalGasAbilityCodeConfiguration(
                    ownerName,
                    fieldName,
                    formalGasAbilityCodes,
                    out string errorMessage))
            {
                throw new InvalidOperationException(errorMessage);
            }
        }

        public static bool TryValidateFormalGasAbilityCodeConfiguration(
            string ownerName,
            string fieldName,
            int[] formalGasAbilityCodes,
            out string errorMessage)
        {
            errorMessage = string.Empty;
            if (formalGasAbilityCodes == null)
            {
                return true;
            }

            for (int index = 0; index < formalGasAbilityCodes.Length; index++)
            {
                if (formalGasAbilityCodes[index] > 0)
                {
                    continue;
                }

                errorMessage =
                    $"[{ownerName}] {fieldName}[{index}] 必须大于 0，不能把坏 Formal GAS 技能编号过滤成成功状态效果。";
                return false;
            }

            return true;
        }

        public static bool TryValidateRestoredFormalGasAbilityCodeConfiguration(
            string ownerName,
            string fieldName,
            int[] formalGasAbilityCodes)
        {
            if (TryValidateFormalGasAbilityCodeConfiguration(
                    ownerName,
                    fieldName,
                    formalGasAbilityCodes,
                    out string errorMessage))
            {
                return true;
            }

            Debug.LogWarning(errorMessage);
            return false;
        }

        public static bool TryHasRestoredFormalGasAbilityCodes(
            string ownerName,
            params int[][] formalGasAbilityCodeGroups)
        {
            if (HasConfiguredFormalGasAbilityCodes(formalGasAbilityCodeGroups))
            {
                return true;
            }

            Debug.LogWarning(
                $"[{ownerName}] 存档中的 Formal GAS 能力型持续效果没有任何技能编号，已跳过恢复，避免登记成功 no-op 状态效果。");
            return false;
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
