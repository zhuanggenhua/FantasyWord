using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditor.Build;
public static class EditorTool
{
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
}
