#if UNITY_EDITOR
namespace GAS.Editor
{
    using System.Collections.Generic;
    using Runtime;
    using NaughtyAttributes;
    using UnityEditor;
    using UnityEngine;
    using GAS.General;

    public class GASWatcher : NaughtyEditorWindow
    {
        private const string BOXGROUP_TIPS = "Tips";
        private const string BOXGROUP_TIPS_RUNNINGTIP = "Tips/Running tip";
        private const string BOXGROUP_ASC = "Ability System Components";
        private const string BOXGROUP_ASC_H = "Ability System Components/H";
        private const string BOXGROUP_ASC_H_L = "Ability System Components/H/L";
        private const string BOXGROUP_ASC_H_R = "Ability System Components/H/R";
        private const string BOXGROUP_ASC_H_R_A = "Ability System Components/H/R/A";
        private const string BOXGROUP_ASC_H_R_A_V = "Ability System Components/H/R/A/V1";
        private const string BOXGROUP_ASC_H_R_A_VB = "Ability System Components/H/R/A/VB";
        private const string BOXGROUP_ASC_H_R_A_VC = "Ability System Components/H/R/A/VC";

        private AbilitySystemComponent _selected;

                        public string windowTitle = "<size=18><b>EX Gameplay Ability System Watcher</b></size>";
                        public string tips = GASTextDefine.TIP_WATCHER;
                        [HideIf("IsPlaying")]
        public string onlyForGameRunning = GASTextDefine.TIP_WATCHER_OnlyForGameRunning;
                                [ShowIf("IsPlaying")]
        public string Navis = "NAVI";
                [ShowIf("IsPlaying")]
        public int IID;

                [ReadOnly]
                [ShowIf("IsPlaying")]
        public GameObject instance;
                [ShowIf("IsPlaying")]
        public int Level;

        [Space]
        [ShowIf("IsPlaying")]
                public List<string> Abilities = new List<string>();
        [ShowIf("IsPlaying")]
                public List<string> Attributes = new List<string>();
        [InfoBox("format: [ActiveState][DurationInfo]GeName", EInfoBoxType.Normal)]
        [ShowIf("IsPlaying")]
                public List<string> Effects = new List<string>();
        [ShowIf("IsPlaying")]
                public List<string> FixedTag = new List<string>();
        [ShowIf("IsPlaying")]
                public List<string> DynamicTag = new List<string>();


        private Vector2 menuScrollPos;

        private bool IsPlaying => Application.isPlaying;

        private void Update()
        {
            if (IsPlaying)
            {
                if (_selected == null || _selected.gameObject == null)
                {
                    _selected = GAS.GameplayAbilitySystem.GAS.AbilitySystemComponents.Count > 0
                        ? GAS.GameplayAbilitySystem.GAS.AbilitySystemComponents[0] as AbilitySystemComponent
                        : null;
                }

                RefreshAscInfo();
                Repaint();
            }
        }

        private const string OpenWindow_MenuItemName = "EX-GAS/Runtime Watcher";
#if EX_GAS_ENABLE_HOT_KEYS
        private const string OpenWindow_MenuItemNameEnh = OpenWindow_MenuItemName + " %F11";
#else
        private const string OpenWindow_MenuItemNameEnh = OpenWindow_MenuItemName;
#endif
        [MenuItem(OpenWindow_MenuItemNameEnh, priority = 3)]
        private static void OpenWindow()
        {
            var window = GetWindow<GASWatcher>();
            window.titleContent = new GUIContent("EX Gameplay Ability System Watcher");
            window.Show();
        }

        void OnDrawNavi()
        {
            if (!IsPlaying) return;

            menuScrollPos = EditorGUILayout.BeginScrollView(menuScrollPos, GUI.skin.box);
            foreach (var iasc in GAS.GameplayAbilitySystem.GAS.AbilitySystemComponents)
            {
                var asc = (AbilitySystemComponent)iasc;
                var presetName = asc.Preset != null ? asc.Preset.name : "NoPreset";
                if (GUILayout.Button($"{presetName}#{asc.GetInstanceID()}"))
                {
                    _selected = asc;
                    RefreshAscInfo();
                }
            }

            EditorGUILayout.EndScrollView();
        }

        private void RefreshAscInfo()
        {
            if (_selected == null)
            {
                IID = 0;
                instance = null;
                Level = 0;
                Abilities.Clear();
                Attributes.Clear();
                Effects.Clear();
                FixedTag.Clear();
                DynamicTag.Clear();
                return;
            }

            IID = _selected.GetInstanceID();
            instance = _selected.gameObject;
            Level = _selected.Level;

            RefreshAbilityInfo();
            RefreshAttributesInfo();
            RefreshGameplayEffectsInfo();
            RefreshTagsInfo();
        }


        private void RefreshGameplayEffectsInfo()
        {
            Effects.Clear();
            foreach (var ge in _selected.GameplayEffectContainer.GameplayEffects())
            {
                string isActive = ge.IsActive ? "√" : "×";
                string durationStr = ge.DurationPolicy switch
                {
                    EffectsDurationPolicy.Duration => $"{ge.DurationRemaining():N2}/{ge.Duration:N2}(s)",
                    EffectsDurationPolicy.Infinite => "∞",
                    EffectsDurationPolicy.Instant => "N/A",
                    _ => "Unknown"
                };
                var stackCountText = ge.Stacking.stackingType != StackingType.None ? $"[S:{ge.StackCount}]" : "";
                Effects.Add($"[{isActive}][{durationStr}]{stackCountText}{ge.GameplayEffect.GameplayEffectName}");
            }
        }

        private void RefreshAbilityInfo()
        {
            Abilities.Clear();
            foreach (var ability in _selected.AbilityContainer.AbilitySpecs())
            {
                string isActive = ability.Value.IsActive ? "(Active)" : "";
                Abilities.Add($"{ability.Key} | Lv.{ability.Value.Level} {isActive}");
            }
        }

        private void RefreshAttributesInfo()
        {
            Attributes.Clear();
            foreach (var (attributeSetName, attributeSet) in _selected.AttributeSetContainer.Sets)
            {
                Attributes.Add($"AttributeSet: {attributeSetName} ↓");
                foreach (var attributeName in attributeSet.AttributeNames)
                {
                    var attr = attributeSet[attributeName];
                    Attributes.Add(
                        $"  - {attributeName} = {attr.CurrentValue:N2}({attr.BaseValue:N2} + {attr.CurrentValue - attr.BaseValue:N2})");
                }
            }
        }

        private void RefreshTagsInfo()
        {
            RefreshFixedTagsInfo();
            RefreshDynamicTagsInfo();
        }

        void RefreshFixedTagsInfo()
        {
            FixedTag.Clear();
            foreach (var tag in _selected.GameplayTagAggregator.FixedTags)
            {
                FixedTag.Add(tag.Name);
            }
        }

        void RefreshDynamicTagsInfo()
        {
            DynamicTag.Clear();
            foreach (var kv in _selected.GameplayTagAggregator.DynamicAddedTags)
            {
                var tagName = kv.Key.Name;
                DynamicTag.Add($"{tagName} ↓ ");

                foreach (var obj in kv.Value)
                {
                    switch (obj)
                    {
                        case GameplayEffectSpec spec:
                        {
                            DynamicTag.Add(
                                $"  - From: {spec.Owner.GetInstanceID()}'s GE: {spec.GameplayEffect.GameplayEffectName}");
                            break;
                        }
                        case AbilitySpec ability:
                        {
                            DynamicTag.Add(
                                $"  - From: {ability.Owner.GetInstanceID()}'s Ability: {ability.Ability.Name}");
                            break;
                        }
                    }
                }
            }
        }
    }
}
#endif