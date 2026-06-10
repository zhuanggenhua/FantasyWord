using System.Linq;
using GAS.General;
using NaughtyAttributes;
using UnityEngine;

namespace GAS.Runtime
{
    [CreateAssetMenu(fileName = "AbilitySystemComponentPreset", menuName = "GAS/AbilitySystemComponentPreset")]
    public class AbilitySystemComponentPreset : ScriptableObject
    {
        private const int WIDTH_LABEL = 70;
        private const string ERROR_ABILITY = "Ability can't be NONE!!";

                                                public string Description;


                [Label(GASTextDefine.ASC_AttributeSet)]
        public string[] AttributeSets;

        private void DrawAttributeSetsButtons()
        {
#if UNITY_EDITOR
            if (GUILayout.Button("SortAlphaDown"))
            {
                AttributeSets = AttributeSets.OrderBy(x => x).ToArray();
            }
#endif
        }

                [Label(GASTextDefine.ASC_BASE_TAG)]
        public GameplayTag[] BaseTags;

        private void DrawBaseTagsButtons()
        {
#if UNITY_EDITOR
            if (GUILayout.Button("SortAlphaDown"))
            {
                BaseTags = BaseTags.OrderBy(x => x.Name).ToArray();
            }
#endif
        }

                        [Label(GASTextDefine.ASC_BASE_ABILITY)]
                        [InfoBox(ERROR_ABILITY, EInfoBoxType.Error)]
        public AbilityAsset[] BaseAbilities;

        private void DrawBaseAbilitiesButtons()
        {
#if UNITY_EDITOR
            if (GUILayout.Button("SortAlphaDown"))
            {
                BaseAbilities = BaseAbilities.OrderBy(x => x.name).ToArray();
            }
#endif
        }

        bool IsAbilityNone()
        {
            return BaseAbilities != null && BaseAbilities.Any(ability => ability == null);
        }
    }
}
