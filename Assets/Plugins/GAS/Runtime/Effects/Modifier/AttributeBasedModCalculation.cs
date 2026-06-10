using NaughtyAttributes;
using UnityEngine;

namespace GAS.Runtime
{
    [CreateAssetMenu(fileName = "AttributeBasedModCalculation", menuName = "GAS/MMC/AttributeBasedModCalculation")]
    public class AttributeBasedModCalculation : ModifierMagnitudeCalculation
    {
        public enum AttributeFrom
        {
            [Label("来源(Source)")]
            Source,

            [Label("目标(Target)")]
            Target
        }

        public enum GEAttributeCaptureType
        {
            [Label("快照(SnapShot)")]
            SnapShot,

            [Label("实时(Track)")]
            Track
        }

                [InfoBox(" 以什么方式(Capture Type)从谁身上(Attribute From)捕获哪个属性的值(Attribute Name)。")]
                [Label("捕获方式(Capture Type)")]
        public GEAttributeCaptureType captureType;

                        [Label("捕获目标(Attribute From)")]
        public AttributeFrom attributeFromType;
        [Label("属性的名称(Attribute Name)")]
        [OnValueChanged("@OnAttributeNameChanged()")]
        [InfoBox("未指定属性名称", EInfoBoxType.Error)]
        public string attributeName;

                [ReadOnly]
        public string attributeSetName;

                [ReadOnly]
        public string attributeShortName;

        [InfoBox("计算逻辑与ScalableFloatModCalculation一致, 公式：AttributeValue * k + b")]
                [Label("系数(k)")]
        public float k = 1;

                [Label("常量(b)")]
        public float b = 0;

        public override float CalculateMagnitude(GameplayEffectSpec spec, float modifierMagnitude)
        {
            if (attributeFromType == AttributeFrom.Source)
            {
                if (captureType == GEAttributeCaptureType.SnapShot)
                {
                    var snapShot = spec.SnapshotSourceAttributes;
                    var attribute = snapShot[attributeName];
                    return attribute * k + b;
                }
                else
                {
                    var attribute = spec.Source.GetAttributeCurrentValue(attributeSetName, attributeShortName);
                    return (attribute ?? 1) * k + b;
                }
            }

            if (captureType == GEAttributeCaptureType.SnapShot)
            {
                var snapShot = spec.SnapshotTargetAttributes;
                var attribute = snapShot[attributeName];
                return attribute * k + b;
            }
            else
            {
                var attribute = spec.Owner.GetAttributeCurrentValue(attributeSetName, attributeShortName);
                return (attribute ?? 1) * k + b;
            }
        }

        private void OnAttributeNameChanged()
        {
            if (!string.IsNullOrWhiteSpace(attributeName))
            {
                var split = attributeName.Split('.');
                attributeSetName = split[0];
                attributeShortName = split[1];
            }
            else
            {
                attributeSetName = null;
                attributeShortName = null;
            }
        }
    }
}