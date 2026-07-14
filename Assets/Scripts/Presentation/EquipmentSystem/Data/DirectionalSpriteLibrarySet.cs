using System;
using UnityEngine.U2D.Animation;

[Serializable]
public sealed class DirectionalSpriteLibrarySet
{
    public SpriteLibraryAsset southEast;
    public SpriteLibraryAsset southWest;
    public SpriteLibraryAsset northEast;
    public SpriteLibraryAsset northWest;

    public bool IsComplete => southEast != null
        && southWest != null
        && northEast != null
        && northWest != null;

    public SpriteLibraryAsset Get(int directionIndex)
    {
        switch (directionIndex)
        {
            case 0: return southEast;
            case 1: return southWest;
            case 2: return northEast;
            case 3: return northWest;
            default: return null;
        }
    }

    public void Set(int directionIndex, SpriteLibraryAsset asset)
    {
        switch (directionIndex)
        {
            case 0: southEast = asset; break;
            case 1: southWest = asset; break;
            case 2: northEast = asset; break;
            case 3: northWest = asset; break;
        }
    }
}
