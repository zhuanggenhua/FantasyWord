using System.Linq;
using GAS.General;
using NaughtyAttributes;
using UnityEngine;

namespace GAS.Runtime
{
    public abstract class ModifierMagnitudeCalculation : ScriptableObject
    {
        protected const int WIDTH_LABEL = 70;

                                                public string Description;

#if UNITY_EDITOR
                                public string TypeName => GetType().Name;

                                public string TypeFullName => GetType().FullName;

                                public string[] InheritanceChain => GetType().GetInheritanceChain().Reverse().ToArray();
#endif

        public abstract float CalculateMagnitude(GameplayEffectSpec spec, float modifierMagnitude);

#if UNITY_EDITOR
        private void OnValidate()
        {
            // if(Application.isPlaying) return;
            // EditorUtility.SetDirty(this);
            // AssetDatabase.SaveAssets();
            // AssetDatabase.Refresh();
        }
#endif
    }
}
