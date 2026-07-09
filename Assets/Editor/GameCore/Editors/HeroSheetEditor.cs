using UnityEditor;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [CustomEditor(typeof(HeroSheet))]
    public class HeroSheetEditor : DatabaseEntryEditor
    {
        private int m_previewLevel = 1;

        public int GetTotalExperienceRequired(HeroSheet sheet, int level)
        {
            return level > 0 ? sheet.GetExperienceRequiredAtLevel(level) + GetTotalExperienceRequired(sheet, level - 1) : 0;
        }

        public override void OnInspectorGUI()
        {
            base.OnInspectorGUI();

            HeroSheet sheet = target as HeroSheet;
            CharacterSheetFeedbackEditorUtility.DrawFeedbackWarnings(sheet);

            EditorGUILayout.Separator();

            EditorGUILayout.LabelField("Evolution Preview", EditorStyles.boldLabel);

            m_previewLevel = EditorGUILayout.IntSlider("Level", m_previewLevel, Constants.MinLevel, Constants.MaxLevel);

            int experienceRequired = sheet.GetExperienceRequiredAtLevel(m_previewLevel);
            int experienceRequiredTotal = GetTotalExperienceRequired(sheet, m_previewLevel);

            GUI.enabled = false;
            EditorGUILayout.IntField("Experience Required", experienceRequired);
            EditorGUILayout.IntField("Experience Required Total", experienceRequiredTotal);
            GUI.enabled = true;
        }
    }
}

