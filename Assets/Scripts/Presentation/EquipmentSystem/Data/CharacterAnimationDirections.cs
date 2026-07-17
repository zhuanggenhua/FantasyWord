using UnityEngine;

/// <summary>
/// MiniFantasy 换装系统的四向素材约定。
/// 行索引、方向缩写和方向向量只能从这里取，避免运行时、生成器和 UI 各自维护一份。
/// </summary>
public static class CharacterAnimationDirections
{
    public const int SouthEast = 0;
    public const int SouthWest = 1;
    public const int NorthEast = 2;
    public const int NorthWest = 3;
    public const int Count = 4;

    static readonly string[] Names =
    {
        "SE",
        "SW",
        "NE",
        "NW"
    };

    static readonly Vector2[] Vectors =
    {
        new Vector2(1f, -1f),
        new Vector2(-1f, -1f),
        new Vector2(1f, 1f),
        new Vector2(-1f, 1f)
    };

    public static bool IsValidIndex(int index)
    {
        return index >= 0 && index < Count;
    }

    public static string GetName(int index)
    {
        return IsValidIndex(index) ? Names[index] : Names[SouthEast];
    }

    public static string[] CopyNames()
    {
        return (string[])Names.Clone();
    }

    public static Vector2 GetVector(int index)
    {
        return IsValidIndex(index) ? Vectors[index] : Vectors[SouthEast];
    }

    public static int ResolveIndex(Vector2 direction, int currentIndex)
    {
        if (direction.sqrMagnitude <= 0.0001f)
            return IsValidIndex(currentIndex) ? currentIndex : SouthEast;

        bool currentlyEast = currentIndex == SouthEast || currentIndex == NorthEast;
        bool currentlyNorth = currentIndex == NorthEast || currentIndex == NorthWest;
        bool east = Mathf.Abs(direction.x) > 0.0001f ? direction.x >= 0f : currentlyEast;
        bool north = Mathf.Abs(direction.y) > 0.0001f ? direction.y > 0f : currentlyNorth;

        if (north)
            return east ? NorthEast : NorthWest;
        return east ? SouthEast : SouthWest;
    }
}
