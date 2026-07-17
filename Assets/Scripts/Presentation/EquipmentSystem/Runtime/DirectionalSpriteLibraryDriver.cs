using FantasyWord.GameCore;
using UnityEngine;
using UnityEngine.U2D.Animation;

/// <summary>
/// 将角色朝向映射到四向 SpriteLibraryAsset，不参与 Animator 动作状态切换。
/// </summary>
[DisallowMultipleComponent]
[RequireComponent(typeof(SpriteResolver))]
public sealed class DirectionalSpriteLibraryDriver : MonoBehaviour
{
    [SerializeField]
    [Tooltip("承载当前方向 SpriteLibraryAsset 的 SpriteLibrary。必须显式绑定，通常在角色根节点。")]
    SpriteLibrary spriteLibrary;

    [SerializeField]
    [Tooltip("当前动画 SpriteResolver。必须显式绑定，通常与本组件同对象。")]
    SpriteResolver spriteResolver;

    [SerializeField]
    [Tooltip("可选：换装渲染器。存在时同步预览方向。")]
    EquipmentRenderer equipmentRenderer;

    [SerializeField]
    [Tooltip("可选：角色移动/朝向 owner。存在时跟随目标朝向；工作台可不绑定并手动切方向。")]
    Movable movable;

    [SerializeField]
    DirectionalSpriteLibrarySet defaultAnimationLibraries = new DirectionalSpriteLibrarySet();

    DirectionalSpriteLibrarySet _libraries;
    int _currentDirectionIndex;

    public int CurrentDirectionIndex => _currentDirectionIndex;

    void Reset()
    {
        spriteResolver = GetComponent<SpriteResolver>();
        equipmentRenderer = GetComponent<EquipmentRenderer>();
    }

    void Awake()
    {
        ValidateRequiredReferences();
    }

    void OnEnable()
    {
        if (!ValidateRequiredReferences())
            return;

        if (_libraries == null && defaultAnimationLibraries != null && defaultAnimationLibraries.IsComplete)
            SetAnimationLibraries(defaultAnimationLibraries, false);

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
        return CharacterAnimationDirections.CopyNames();
    }

    public static Vector2 GetDirectionValue(int index)
    {
        return CharacterAnimationDirections.GetVector(index);
    }

    public bool SetAnimationLibraries(DirectionalSpriteLibrarySet libraries, bool resetDirection)
    {
        if (libraries == null)
        {
            Debug.LogError("[DirectionalSpriteLibraryDriver] 缺少四向动画精灵库配置，无法选择方向精灵库。", this);
            return false;
        }

        if (!libraries.IsComplete)
        {
            Debug.LogError(
                "[DirectionalSpriteLibraryDriver] 缺少完整的 SE/SW/NE/NW 动画精灵库。",
                this);
            return false;
        }

        _libraries = libraries;
        if (resetDirection)
            _currentDirectionIndex = 0;

        return ApplyDirectionVariant();
    }

    public bool SetDirection(int index)
    {
        if (!CharacterAnimationDirections.IsValidIndex(index))
            return false;

        _currentDirectionIndex = index;
        return ApplyDirectionVariant();
    }

    public void SetFacingDirection(Vector2 direction)
    {
        if (direction.sqrMagnitude <= 0.0001f)
            return;

        SetDirection(CharacterAnimationDirections.ResolveIndex(direction, _currentDirectionIndex));
    }

    bool ApplyDirectionVariant()
    {
        if (!ValidateRequiredReferences())
            return false;

        if (_libraries == null)
        {
            Debug.LogError("[DirectionalSpriteLibraryDriver] 缺少当前四向动画精灵库集合。", this);
            return false;
        }

        SpriteLibraryAsset asset = _libraries.Get(_currentDirectionIndex);
        if (asset == null)
        {
            Debug.LogError(
                $"[DirectionalSpriteLibraryDriver] 方向 {CharacterAnimationDirections.GetName(_currentDirectionIndex)} 缺少 SpriteLibraryAsset。",
                this);
            return false;
        }

        spriteLibrary.spriteLibraryAsset = asset;
        spriteResolver.ResolveSpriteToSpriteRenderer();

        if (equipmentRenderer != null)
            equipmentRenderer.SetPreviewDirection(_currentDirectionIndex);

        return true;
    }

    bool ValidateRequiredReferences()
    {
        if (spriteLibrary == null)
        {
            Debug.LogError("[DirectionalSpriteLibraryDriver] 缺少显式绑定的 SpriteLibrary，不能运行时向父级查找。", this);
            return false;
        }

        if (spriteResolver == null)
        {
            Debug.LogError("[DirectionalSpriteLibraryDriver] 缺少显式绑定的 SpriteResolver。", this);
            return false;
        }

        return true;
    }
}
