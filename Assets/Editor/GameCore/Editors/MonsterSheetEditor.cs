using Unity.Mathematics;
using UnityEditor;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [CustomEditor(typeof(MonsterSheet))]
    public class MonsterSheetEditor : DatabaseEntryEditor
    {
        private int m_previewLevel = 1;

        public override void OnInspectorGUI()
        {
            base.OnInspectorGUI();

            MonsterSheet sheet = target as MonsterSheet;
            CharacterSheetFeedbackEditorUtility.DrawFeedbackWarnings(sheet);

            EditorGUILayout.Separator();

            EditorGUILayout.LabelField("Evolution Preview", EditorStyles.boldLabel);

            m_previewLevel = EditorGUILayout.IntSlider("Level", m_previewLevel, 1, Constants.MaxLevel);

            Stats previewStats = sheet.GetStatsAtLevel(m_previewLevel);
            int experience = sheet.GetExperienceRewardAtLevel(m_previewLevel);
            int money = sheet.GetMoneyRewardAtLevel(m_previewLevel);

            int total = previewStats.GetTotal();
            int average = (int)math.round(total / 5.0f);

            GUI.enabled = false;
            foreach (FormalAttributeDefinition attribute in FormalAttributeCatalog.Definitions)
            {
                EditorGUILayout.IntField(attribute.DisplayName, previewStats[attribute.Stat]);
            }
            EditorGUILayout.Space();
            EditorGUILayout.IntField("Total", total);
            EditorGUILayout.IntField("Average", average);
            EditorGUILayout.Space();
            EditorGUILayout.IntField("Experience", experience);
            EditorGUILayout.IntField("Money", money);
            EditorGUILayout.Space();
            GUI.enabled = true;
        }
    }
}

