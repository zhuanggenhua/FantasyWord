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
            case CharacterAnimationDirections.SouthEast: return southEast;
            case CharacterAnimationDirections.SouthWest: return southWest;
            case CharacterAnimationDirections.NorthEast: return northEast;
            case CharacterAnimationDirections.NorthWest: return northWest;
            default: return null;
        }
    }

    public void Set(int directionIndex, SpriteLibraryAsset asset)
    {
        switch (directionIndex)
        {
            case CharacterAnimationDirections.SouthEast: southEast = asset; break;
            case CharacterAnimationDirections.SouthWest: southWest = asset; break;
            case CharacterAnimationDirections.NorthEast: northEast = asset; break;
            case CharacterAnimationDirections.NorthWest: northWest = asset; break;
        }
    }
}
