using NaughtyAttributes;
using UnityEngine;

namespace GAS.Runtime
{
    /// <summary>
    ///  基于属性混合GE堆栈的MMC
    /// </summary>
    [CreateAssetMenu(fileName = "AttrBasedWithStackModCalculation", menuName = "GAS/MMC/AttrBasedWithStackModCalculation")]
    public class AttrBasedWithStackModCalculation:AttributeBasedModCalculation
    {
        public enum StackMagnitudeOperation
        {
            Add,
            Multiply
        }
        
        [InfoBox(" 公式：StackCount * sK + sB")]
                        [Label("系数(sK)")]
        public float sK = 1;

                [Label("常量(sB)")]
        public float sB = 0;

                        [InfoBox(" 最终公式： \n" +
                 "Add:(AttributeValue * k + b)+(StackCount * sK + sB); \n" +
                 "Multiply:(AttributeValue * k + b)*(StackCount * sK + sB)")]
        [Label("Stack幅值与Attr幅值计算方式")]
        public StackMagnitudeOperation stackMagnitudeOperation;

                        public string FinalFormulae
        {
            get
            {
                var formulae = stackMagnitudeOperation switch
                {
                    StackMagnitudeOperation.Add => $"({attributeName} * {k} + {b}) + (StackCount * {sK} + {sB})",
                    StackMagnitudeOperation.Multiply => $"({attributeName} * {k} + {b}) * (StackCount * {sK} + {sB})",
                    _ => ""
                };

                return $"<size=15><b><color=green>{formulae}</color></b></size>";
            }
        }
        
        public override float CalculateMagnitude(GameplayEffectSpec spec, float modifierMagnitude)
        {
            var attrMagnitude = base.CalculateMagnitude(spec, modifierMagnitude);
            
            if (spec.Stacking.stackingType == StackingType.None) return attrMagnitude;
            
            var stackMagnitude = spec.StackCount * sK + sB;

            return stackMagnitudeOperation switch
            {
                StackMagnitudeOperation.Add => attrMagnitude + stackMagnitude,
                StackMagnitudeOperation.Multiply => attrMagnitude * stackMagnitude,
                _ => attrMagnitude + stackMagnitude
            };
        }
        
    }
}
