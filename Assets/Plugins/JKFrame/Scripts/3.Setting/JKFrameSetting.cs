using UnityEngine;
using NaughtyAttributes;
using System.Collections.Generic;
using System;
using System.Reflection;
#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.Build;
#endif
namespace JKFrame
{
    /// <summary>
    /// 资源系统类型
    /// </summary>
    public enum ResourcesSystemType
    {
        Resources,
        Addressables
    }

    /// <summary>
    /// 存档系统类型
    /// </summary>
    public enum SaveSystemType
    {
        Binary,
        Json
    }

    /// <summary>
    /// 框架的设置
    /// </summary>
    [CreateAssetMenu(fileName = "JKFrameSetting", menuName = "JKFrame/JKFrameSetting")]
    public class JKFrameSetting : ScriptableObject
    {
        [Label("资源管理方式")]
#if UNITY_EDITOR 
        [OnValueChanged(nameof(SetResourcesSystemType))]
#endif
        public ResourcesSystemType ResourcesSystemType = ResourcesSystemType.Resources;

#if UNITY_EDITOR
        [Label("存档方式"), Tooltip("修改类型会导致之前的存档丢失"), OnValueChanged(nameof(SetSaveSystemType))]
#endif
        public SaveSystemType SaveSystemType = SaveSystemType.Binary;

        [SerializeReference, Label("二进制序列化器，仅用于二进制方式存档")]
        public IBinarySerializer binarySerializer;

        [Label("日志设置")] public LogSetting LogConfig = new LogSetting();

        [NonSerialized]
        public Dictionary<string, UIWindowData> UIWindowDataDic = new Dictionary<string, UIWindowData>();

        [SerializeField, Label("UI窗口数据(无需手动填写)")]
        private List<UIWindowDataEntry> uiWindowDataEntries = new List<UIWindowDataEntry>();

        /// <summary>
        /// Unity 不能直接序列化字典，这里用列表保存窗口注册数据，加载时重建运行时字典。
        /// </summary>
        [Serializable]
        private class UIWindowDataEntry
        {
            [Label("窗口键")]
            public string windowKey;

            [Label("窗口数据")]
            public UIWindowData windowData;
        }

        private void OnEnable()
        {
            RebuildUIWindowDataDictionary();
        }

        /// <summary>
        /// 日志设置
        /// </summary>
        public class LogSetting
        {
            [Label("启用日志"), OnValueChanged("EnableLogValueChaged")] public bool enableLog = true;
            [Label("写入时间"), OnValueChanged("EnableLogValueChaged")] public bool writeTime = true;
            [Label("写入线程ID"), OnValueChanged("EnableLogValueChaged")] public bool writeThreadID = false;
            [Label("写入堆栈"), OnValueChanged("EnableLogValueChaged")] public bool writeTrace = true;
            [Label("保存日志文件"), OnValueChanged("EnableLogValueChaged")] public bool enableSave = false;
            [Label("需要保存的日志类型"), HideIf("CheckSaveState"), OnValueChanged("EnableLogValueChaged")] public JK.Log.LogType saveLogTypes;
            [Label("保存路径,相对persistentDataPath的路径"), HideIf("CheckSaveState"), OnValueChanged("EnableLogValueChaged")] public string savePath = "/Log";
            [Label("自定义的文件名"), HideIf("CheckSaveState"), OnValueChanged("EnableLogValueChaged")]
            [InfoBox("如果填写，则会导致每次保存都是覆盖式的；如果不填写，则每次自动保存为时间命名的文件")]
            public string customSaveFileName = string.Empty;
#if UNITY_EDITOR
            public void InitOnEidtor()
            {
                EnableLogValueChaged();
            }

            [Button("打开日志")]
            private void OpenLog()
            {
                string path = Application.persistentDataPath + savePath;
                path = path.Replace("/", "\\");
                System.Diagnostics.Process.Start("explorer.exe", path);
            }

            private bool CheckSaveState()
            {
                return !enableSave;
            }

            private void EnableLogValueChaged()
            {
                if (enableLog)
                {
                    AddScriptCompilationSymbol("ENABLE_LOG");
                }
                else
                {
                    RemoveScriptCompilationSymbol("ENABLE_LOG");
                }
            }
#endif
        }

#if UNITY_EDITOR
        [Button("重置")]
        public void Reset()
        {
            LogConfig = new LogSetting();
            LogConfig.InitOnEidtor();
            SetResourcesSystemType();
            SetSaveSystemType();
            InitUIWindowDataDicOnEditor();
        }

        public void InitOnEditor()
        {
            if (LogConfig != null) LogConfig.InitOnEidtor();
            SetResourcesSystemType();
            InitUIWindowDataDicOnEditor();
        }

        /// <summary>
        /// 修改资源管理系统的类型
        /// </summary>
        public void SetResourcesSystemType()
        {
            switch (ResourcesSystemType)
            {
                case ResourcesSystemType.Resources:
                    RemoveScriptCompilationSymbol("ENABLE_ADDRESSABLES");
                    // 查找资源R.cs，如果有需要删除
                    string path = Application.dataPath + "/JKFrame//Scripts/2.System/3.Res/R.cs";
                    if (System.IO.File.Exists(path)) AssetDatabase.DeleteAsset("Assets/JKFrame//Scripts/2.System/3.Res/R.cs");
                    break;
                case ResourcesSystemType.Addressables:
                    AddScriptCompilationSymbol("ENABLE_ADDRESSABLES");
                    break;
            }
        }

        /// <summary>
        /// 修改存档系统的类型
        /// </summary>
        private void SetSaveSystemType()
        {
            // 清空存档
            SaveSystem.DeleteAll();
        }

        /// <summary>
        /// 增加预处理指令
        /// </summary>
        public static void AddScriptCompilationSymbol(string name)
        {
            NamedBuildTarget buildTarget = NamedBuildTarget.FromBuildTargetGroup(EditorUserBuildSettings.selectedBuildTargetGroup);
            string group = PlayerSettings.GetScriptingDefineSymbols(buildTarget);
            if (!group.Contains(name))
            {
                PlayerSettings.SetScriptingDefineSymbols(buildTarget, group + ";" + name);
            }
        }

        /// <summary>
        /// 移除预处理指令
        /// </summary>
        public static void RemoveScriptCompilationSymbol(string name)
        {
            NamedBuildTarget buildTarget = NamedBuildTarget.FromBuildTargetGroup(EditorUserBuildSettings.selectedBuildTargetGroup);
            string group = PlayerSettings.GetScriptingDefineSymbols(buildTarget);
            if (group.Contains(name))
            {
                PlayerSettings.SetScriptingDefineSymbols(buildTarget, group.Replace(";" + name, string.Empty));
            }
        }

        private void InitUIWindowDataDicOnEditor()
        {
            UIWindowDataDic.Clear();
            uiWindowDataEntries.Clear();
            // 获取所有程序集
            System.Reflection.Assembly[] asms = AppDomain.CurrentDomain.GetAssemblies();
            Type baseType = typeof(UI_WindowBase);
            // 遍历程序集
            foreach (System.Reflection.Assembly assembly in asms)
            {

                // 遍历程序集下的每一个类型
                try
                {
                    Type[] types = assembly.GetTypes();
                    foreach (Type type in types)
                    {
                        if (baseType.IsAssignableFrom(type)
                            && !type.IsAbstract)
                        {
                            var attributes = type.GetCustomAttributes<UIWindowDataAttribute>();
                            foreach (var attribute in attributes)
                            {
                                var windowData = new UIWindowData(attribute.isCache, attribute.assetPath, attribute.layerNum);
                                UIWindowDataDic.Add(attribute.windowKey, windowData);
                                uiWindowDataEntries.Add(new UIWindowDataEntry
                                {
                                    windowKey = attribute.windowKey,
                                    windowData = windowData
                                });
                            }

                        }
                    }
                }
                catch (Exception)
                {
                    continue;
                }
            }

            EditorUtility.SetDirty(this);
            AssetDatabase.SaveAssetIfDirty(this);
        }
#endif

        private void RebuildUIWindowDataDictionary()
        {
            UIWindowDataDic.Clear();
            foreach (var entry in uiWindowDataEntries)
            {
                if (entry == null || string.IsNullOrEmpty(entry.windowKey) || entry.windowData == null)
                {
                    continue;
                }

                UIWindowDataDic[entry.windowKey] = entry.windowData;
            }
        }

    }

}
