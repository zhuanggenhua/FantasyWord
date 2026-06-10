using System;
using System.IO;
using GAS.General;
using NaughtyAttributes;
using UnityEditor;
using UnityEngine;

namespace GAS.Editor
{
    [FilePath(GasDefine.GAS_BASE_SETTING_PATH)]
    public class GASSettingAsset : ScriptableSingleton<GASSettingAsset>
    {
        private const int LABEL_WIDTH = 200;
        private const int SHORT_LABEL_WIDTH = 200;
        private static GASSettingAsset _setting;
                        [OnValueChanged("SaveAsset")]
        public string CodeGeneratePath = "Assets/Scripts/Gen";
                        [OnValueChanged("SaveAsset")]
        public string GASConfigAssetPath = "Assets/GAS/Config";

        public static GASSettingAsset Setting
        {
            get
            {
                if (_setting == null) _setting = LoadOrCreate();
                return _setting;
            }
        }
                        private static string Version =>
            $"<size=15><b><color=white>EX-GAS Version: {GasDefine.GAS_VERSION}</color></b></size>";

        public static string CodeGenPath => Setting.CodeGeneratePath;
                        public static string ASCLibPath => $"{Setting.GASConfigAssetPath}/{GasDefine.GAS_ASC_LIBRARY_FOLDER}";
                        public static string GameplayEffectLibPath =>
            $"{Setting.GASConfigAssetPath}/{GasDefine.GAS_EFFECT_LIBRARY_FOLDER}";
                        public static string GameplayAbilityLibPath =>
            $"{Setting.GASConfigAssetPath}/{GasDefine.GAS_ABILITY_LIBRARY_FOLDER}";
                        public static string GameplayCueLibPath => $"{Setting.GASConfigAssetPath}/{GasDefine.GAS_CUE_LIBRARY_FOLDER}";
                        public static string MMCLibPath => $"{Setting.GASConfigAssetPath}/{GasDefine.GAS_MMC_LIBRARY_FOLDER}";
                        public static string AbilityTaskLib =>
            $"{Setting.GASConfigAssetPath}/{GasDefine.GAS_ABILITY_TASK_LIBRARY_FOLDER}";
        public static string GAS_TAG_ASSET_PATH => GasDefine.GAS_TAGS_MANAGER_ASSET_PATH;
        public static string GAS_ATTRIBUTE_ASSET_PATH => GasDefine.GAS_ATTRIBUTE_ASSET_PATH;
        public static string GAS_ATTRIBUTESET_ASSET_PATH => GasDefine.GAS_ATTRIBUTE_SET_ASSET_PATH;

        void CheckPathFolderExist(string folderPath)
        {
            var folders = folderPath.Split('/');
            if (folders[0] != "Assets")
            {
                EditorUtility.DisplayDialog("Error!", "'Config Asset Path/Code Gen Path' must start with Assets!",
                    "OK");
                return;
            }

            string parentFolderPath = folders[0];
            for (var i = 1; i < folders.Length; i++)
            {
                string newFolderName = folders[i];
                if (newFolderName == "") continue;

                string newFolderPath = parentFolderPath + "/" + newFolderName;
                if (!AssetDatabase.IsValidFolder(newFolderPath))
                {
                    AssetDatabase.CreateFolder(parentFolderPath, newFolderName);
                    Debug.Log("[EX] Folder created at path: " + newFolderPath);
                }

                parentFolderPath += "/" + newFolderName;
            }
        }
        [Button(GASTextDefine.BUTTON_CheckAllPathFolderExist)]
        void CheckAllPathFolderExist()
        {
            CheckPathFolderExist(GASConfigAssetPath);
            CheckPathFolderExist(CodeGeneratePath);
            CheckPathFolderExist(ASCLibPath);
            CheckPathFolderExist(GameplayAbilityLibPath);
            CheckPathFolderExist(GameplayEffectLibPath);
            CheckPathFolderExist(GameplayCueLibPath);
            CheckPathFolderExist(MMCLibPath);
            CheckPathFolderExist(AbilityTaskLib);
            AssetDatabase.Refresh();
        }
        [Button(GASTextDefine.BUTTON_GenerateAscExtensionCode)]
        void GenerateAscExtensionCode()
        {
            string pathWithoutAssets = Application.dataPath.Substring(0, Application.dataPath.Length - 6);
            var filePath =
                $"{pathWithoutAssets}/{CodeGenPath}/{GasDefine.GAS_ATTRIBUTESET_LIB_CSHARP_SCRIPT_NAME}";

            if (!File.Exists(filePath))
            {
                EditorUtility.DisplayDialog("Error!", "Please generate AttributeSetAsset first!", "OK");
                return;
            }

            AbilitySystemComponentUtilGenerator.Gen();
            AssetDatabase.Refresh();
        }

        private void SaveAsset()
        {
            if (Instance == this) return;
            UpdateAsset(this);
            Save();
        }

        private const string EX_GAS_ENABLE_HOT_KEYS = "EX_GAS_ENABLE_HOT_KEYS";

#if EX_GAS_ENABLE_HOT_KEYS
        public const bool EnableHotKeys = true;
#else
        public const bool EnableHotKeys = false;
#endif

                [InfoBox(
            "@\"当前快捷键状态: \" + (EnableHotKeys ? \"启用\":\"禁用\") + \", 冲突时可禁用快捷键\"")]
#if EX_GAS_ENABLE_HOT_KEYS
        [Button("禁用快捷键")]
#else
        [Button("开启快捷键")]
#endif
        private void ToggleScriptDefineSymbol_EX_GAS_ENABLE_HOT_KEYS()
        {
            if (EditorUtility.DisplayDialog("Ex-GAS",
                    "切换快捷键状态\n将在你的项目中切换\"EX_GAS_ENABLE_HOT_KEYS\"宏定义\n\n这会重新编译你的代码, 之后你可能需要手动保存你的项目(请留意ProjectSettings.asset的变化).",
                    "确定", "取消"))
            {
#pragma warning disable 162
                if (EnableHotKeys)
                    ScriptingDefineSymbolsHelper.Remove(EX_GAS_ENABLE_HOT_KEYS);
                else
                    ScriptingDefineSymbolsHelper.Add(EX_GAS_ENABLE_HOT_KEYS);
#pragma warning restore 162
            }
        }
    }
}