using GAS.Runtime;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// GameCore 对 EX-GAS 2.0 属性初始化的项目侧适配。
    /// 初始化和快照覆盖只设置 BaseValue，然后交给 EX-GAS 重算 CurrentValue。
    /// </summary>
    internal static class FormalAbilitySystemAttributeExtensions
    {
        public static void SetAttrBaseValueAndRecalculate(
            this AbilitySystemComponent abilitySystemComponent,
            int attrSetCode,
            int attributeCode,
            float baseValue)
        {
            if (abilitySystemComponent == null)
            {
                return;
            }

            abilitySystemComponent.SetAttrBaseValue(attrSetCode, attributeCode, baseValue);
            AttributeHelper.RecalculateCurrentValue(
                abilitySystemComponent.Cell.Entity,
                attrSetCode,
                attributeCode);
        }
    }
}
