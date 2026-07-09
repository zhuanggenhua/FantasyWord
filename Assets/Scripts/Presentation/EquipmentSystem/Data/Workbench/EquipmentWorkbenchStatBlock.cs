using System;
using System.Collections.Generic;
using UnityEngine;

public enum WorkbenchStatType
{
    Constitution = 0,
    Health = 1,
    Strength = 2,
    Intelligence = 3,
    Mana = 4
}

[Serializable]
public struct WorkbenchStatValue
{
    public WorkbenchStatType stat;
    public int value;
}

[Serializable]
public sealed class WorkbenchStatBlock
{
    [SerializeField]
    List<WorkbenchStatValue> values = new List<WorkbenchStatValue>();

    public IReadOnlyList<WorkbenchStatValue> Values => values;

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
