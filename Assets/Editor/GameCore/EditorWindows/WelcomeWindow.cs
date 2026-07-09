using UnityEditor;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public class WelcomeWindow : EditorWindow
    {
        private const string kShowOnImportKey = "FantasyWordShowWelcomeWindowOnImport";

        [InitializeOnLoadMethod]
        private static void InitializeOnLoad()
        {
            if (EditorPrefs.GetBool(kShowOnImportKey, true))
            {
                EditorApplication.update += ShowWelcomeWindowOnNextUpdate;
                EditorPrefs.SetBool(kShowOnImportKey, false);
            }
        }

        [MenuItem("Window/FantasyWord/Welcome")]
        public static void ShowWindow()
        {
            EditorWindow window = GetWindow<WelcomeWindow>();
            window.titleContent = new GUIContent("Welcome");
            window.ShowModalUtility();
        }

        void OnGUI()
        {
            minSize = maxSize = new Vector2(400, 140);

            GUILayout.Space(10);
            GUILayout.Label("Thank you for installing Mythril2D!", new GUIStyle(EditorStyles.label)
            {
                fontSize = 20,
                fontStyle = FontStyle.Bold,
                alignment = TextAnchor.MiddleCenter,
            });
            GUILayout.Space(10);
            GUILayout.Label("Get started with Mythril2D by checking out its documentation directly embedded in the Unity Editor", new GUIStyle(EditorStyles.label)
            {
                fontSize = 14,
                alignment = TextAnchor.MiddleCenter,
                wordWrap = true
            });
            GUILayout.Space(10);
            if (GUILayout.Button("Read Documentation", new GUIStyle(GUI.skin.button)
            {
                fontSize = 16,
                fontStyle = FontStyle.Bold
            }, GUILayout.Height(40)))
            {
                DocumentationWindow.ShowWindow("Getting Started");
                Close();
            }
        }

        private static void ShowWelcomeWindowOnNextUpdate()
        {
            EditorApplication.update -= ShowWelcomeWindowOnNextUpdate;
            ShowWindow();
        }
    }
}

