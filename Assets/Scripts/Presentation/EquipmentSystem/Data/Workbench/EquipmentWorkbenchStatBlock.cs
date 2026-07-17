using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 换装工作台展示用属性类型，只服务于工作台 UI，不直接替代 GameCore 正式属性定义。
/// </summary>
public enum WorkbenchStatType
{
    Constitution = 0,
    Health = 1,
    Strength = 2,
    Intelligence = 3,
    Mana = 4
}

/// <summary>
/// 工作台中的单条属性数值，用于基础属性和装备加成的轻量展示。
/// </summary>
[Serializable]
public struct WorkbenchStatValue
{
    [InspectorName("属性")]
    [Tooltip("工作台 UI 中展示的属性类型。")]
    public WorkbenchStatType stat;

    [InspectorName("数值")]
    [Tooltip("该属性对应的数值，可为正数或负数。")]
    public int value;
}

/// <summary>
/// 工作台属性块，可把多条属性加到汇总字典中，供 UI 展示装备前后变化。
/// </summary>
[Serializable]
public sealed class WorkbenchStatBlock
{
    [InspectorName("属性列表")]
    [Tooltip("工作台展示用的属性条目列表。相同属性会在汇总时累加。")]
    [SerializeField]
    List<WorkbenchStatValue> values = new List<WorkbenchStatValue>();

    public IReadOnlyList<WorkbenchStatValue> Values => values;

    /// <summary>
    /// 把本属性块累加到外部汇总表；空目标表会被忽略。
    /// </summary>
    public void AddTo(Dictionary<WorkbenchStatType, int> totals)
    {
        if (totals == null)
            return;

        for (int i = 0; i < values.Count; i++)
        {
            WorkbenchStatValue entry = values[i];
            totals[entry.stat] = totals.TryGetValue(entry.stat, out int current)
                ? current + entry.value
                : entry.value;
        }
    }
}
