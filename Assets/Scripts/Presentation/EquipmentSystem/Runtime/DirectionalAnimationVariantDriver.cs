using FantasyWord.GameCore;
using UnityEngine;
using UnityEngine.U2D.Animation;

/// <summary>
/// 将角色朝向映射到四向 SpriteLibraryAsset，不参与 Animator 动作状态切换。
/// </summary>
[DisallowMultipleComponent]
[RequireComponent(typeof(SpriteResolver))]
public sealed class DirectionalAnimationVariantDriver : MonoBehaviour
{
    static readonly string[] DirectionNames = { "SE", "SW", "NE", "NW" };

    static readonly Vector2[] DirectionValues =
    {
        new Vector2(1f, -1f),
        new Vector2(-1f, -1f),
        new Vector2(1f, 1f),
        new Vector2(-1f, 1f),
    };

    [SerializeField]
    SpriteLibrary spriteLibrary;

    [SerializeField]
    SpriteResolver spriteResolver;

    [SerializeField]
    EquipmentRenderer equipmentRenderer;

    [SerializeField]
    Movable movable;

    DirectionalSpriteLibrarySet _libraries;
    int _currentDirectionIndex;

    public int CurrentDirectionIndex => _currentDirectionIndex;

    void Awake()
    {
        ResolveDependencies();
    }

    void OnEnable()
    {
        ResolveDependencies();

        if (equipmentRenderer != null && equipmentRenderer.frameData != null)
            SetFrameData(equipmentRenderer.frameData, false);

        if (movable != null)
        {
            movable.AddTargetDirectionChangedListener(SetFacingDirection);
            SetFacingDirection(movable.GetTargetDirection());
        }
        else
        {
            ApplyDirectionVariant();
        }
    }

    void OnDisable()
    {
        if (movable != null)
            movable.RemoveTargetDirectionChangedListener(SetFacingDirection);
    }

    public string[] GetDirectionNames()
    {
        return DirectionNames;
    }

    public static Vector2 GetDirectionValue(int index)
    {
        return index >= 0 && index < DirectionValues.Length
            ? DirectionValues[index]
            : DirectionValues[0];
    }

    public bool SetFrameData(CharacterFrameData frameData, bool resetDirection)
    {
        if (frameData == null)
        {
            Debug.LogError("[DirectionalAnimationVariantDriver] 缺少角色帧数据，无法选择方向精灵库。", this);
            return false;
        }

        DirectionalSpriteLibrarySet libraries = frameData.animationSpriteLibraries;
        if (libraries == null || !libraries.IsComplete)
        {
            Debug.LogError(
                $"[DirectionalAnimationVariantDriver] {frameData.name} 缺少完整的 SE/SW/NE/NW 动画精灵库。",
                frameData);
            return false;
        }

        _libraries = libraries;
        if (resetDirection)
            _currentDirectionIndex = 0;

        return ApplyDirectionVariant();
    }

    public bool SetDirection(int index)
    {
        if (index < 0 || index >= DirectionValues.Length)
            return false;

        _currentDirectionIndex = index;
        return ApplyDirectionVariant();
    }

    public void SetFacingDirection(Vector2 direction)
    {
        if (direction.sqrMagnitude <= 0.0001f)
            return;

        bool currentlyEast = _currentDirectionIndex == 0 || _currentDirectionIndex == 2;
        bool currentlyNorth = _currentDirectionIndex == 2 || _currentDirectionIndex == 3;
        bool east = Mathf.Abs(direction.x) > 0.0001f ? direction.x >= 0f : currentlyEast;
        bool north = Mathf.Abs(direction.y) > 0.0001f ? direction.y > 0f : currentlyNorth;

        SetDirection(north
            ? (east ? 2 : 3)
            : (east ? 0 : 1));
    }

    bool ApplyDirectionVariant()
    {
        ResolveDependencies();
        if (_libraries == null || spriteLibrary == null || spriteResolver == null)
            return false;

        SpriteLibraryAsset asset = _libraries.Get(_currentDirectionIndex);
        if (asset == null)
        {
            Debug.LogError(
                $"[DirectionalAnimationVariantDriver] 方向 {DirectionNames[_currentDirectionIndex]} 缺少 SpriteLibraryAsset。",
                this);
            return false;
        }

        spriteLibrary.spriteLibraryAsset = asset;
        spriteResolver.ResolveSpriteToSpriteRenderer();

        if (equipmentRenderer != null)
            equipmentRenderer.SetPreviewDirection(_currentDirectionIndex);

        return true;
    }

    void ResolveDependencies()
    {
        if (spriteLibrary == null)
            spriteLibrary = GetComponentInParent<SpriteLibrary>();
        if (spriteResolver == null)
            spriteResolver = GetComponent<SpriteResolver>();
        if (equipmentRenderer == null)
            equipmentRenderer = GetComponent<EquipmentRenderer>();
        if (movable == null)
            movable = GetComponentInParent<Movable>();
    }
}
