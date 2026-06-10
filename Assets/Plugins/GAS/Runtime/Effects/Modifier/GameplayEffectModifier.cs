using System;
using NaughtyAttributes;
using UnityEngine;

namespace GAS.Runtime
{
    public enum GEOperation
    {
        [Label("加")]
        Add = 0,

        [Label("减")]
        Minus = 3,

        [Label("乘")]
        Multiply = 1,

        [Label("除")]
        Divide = 4,

        [Label("替")]
        Override = 2,
    }

    [Flags]
    public enum SupportedOperation : byte
    {
        None = 0,

        [Label("加")]
        Add = 1 << GEOperation.Add,

        [Label("减")]
        Minus = 1 << GEOperation.Minus,

        [Label("乘")]
        Multiply = 1 << GEOperation.Multiply,

        [Label("除")]
        Divide = 1 << GEOperation.Divide,

        [Label("替")]
        Override = 1 << GEOperation.Override,

        All = Add | Minus | Multiply | Divide | Override
    }

    [Serializable]
    public struct GameplayEffectModifier
    {
        private const int LABEL_WIDTH = 70;

        [Label("修改属性")]
                [OnValueChanged("OnAttributeChanged")]
        [Tooltip("指的是GameplayEffect作用对象被修改的属性。")]
        [InfoBox("未选择属性", EInfoBoxType.Error)]
                public string AttributeName;

        [HideInInspector]
        public string AttributeSetName;

        [HideInInspector]
        public string AttributeShortName;

        [Label("运算参数")]
                [Tooltip("修改器的基础数值。这个数值如何使用由MMC的运行逻辑决定。\nMMC未指定时直接使用这个值。")]
        [InfoBox("除数不能为零", EInfoBoxType.Error)]
                public float ModiferMagnitude;

        [Label("运算法则")]
                                [ValidateInput("@ReflectionHelper.GetAttribute(AttributeName).IsSupportOperation($value)", "非法运算: 该属性不支持的此运算法则")]
        public GEOperation Operation;

        [Label("参数修饰")]
                        [Tooltip("ModifierMagnitudeCalculation，修改器，负责GAS中Attribute的数值计算逻辑。\n可以为空(不对\"计算参数\"做任何修改)。")]
                public ModifierMagnitudeCalculation MMC;

        // TODO
        // public readonly GameplayTagSet SourceTag;

        // TODO
        // public readonly GameplayTagSet TargetTag;

        public GameplayEffectModifier(
            string attributeName,
            float modiferMagnitude,
            GEOperation operation,
            ModifierMagnitudeCalculation mmc = null)
        {
            AttributeName = attributeName;
            var splits = attributeName.Split('.');
            AttributeSetName = splits[0];
            AttributeShortName = splits[1];
            ModiferMagnitude = modiferMagnitude;
            Operation = operation;
            MMC = mmc;
        }

        public float CalculateMagnitude(GameplayEffectSpec spec, float modifierMagnitude)
        {
            return MMC == null ? ModiferMagnitude : MMC.CalculateMagnitude(spec, modifierMagnitude);
        }

        public void SetModiferMagnitude(float value)
        {
            ModiferMagnitude = value;
        }

        void OnAttributeChanged()
        {
            var split = AttributeName.Split('.');
            AttributeSetName = split[0];
            AttributeShortName = split[1];

            if (ReflectionHelper.GetAttribute(AttributeName)?.CalculateMode !=
                CalculateMode.Stacking)
            {
                Operation = GEOperation.Override;
            }
        }
    }
}
