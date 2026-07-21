using FantasyWord.GameCore;
using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.U2D.Animation;

/// <summary>
/// 将角色身体朝向映射到四向 SpriteLibraryAsset。
/// 它只切 SE/SW/NE/NW 方向库，不参与 Animator 动作状态切换，也不拥有移动或目标方向真相。
/// </summary>
[DisallowMultipleComponent]
[RequireComponent(typeof(SpriteResolver))]
public sealed class DirectionalSpriteLibraryDriver : MonoBehaviour
{
    [SerializeField]
    [LabelText("SpriteLibrary"), Tooltip("承载当前方向 SpriteLibraryAsset 的 SpriteLibrary。必须显式绑定，通常在角色根节点。")]
    SpriteLibrary spriteLibrary;

    [SerializeField]
    [LabelText("SpriteResolver"), Tooltip("当前动画 SpriteResolver。必须显式绑定，通常与本组件同对象。")]
    SpriteResolver spriteResolver;

    [SerializeField]
    [LabelText("换装渲染器"), Tooltip("可选：换装渲染器。存在时同步预览方向。")]
    EquipmentRenderer equipmentRenderer;

    [SerializeField]
    [LabelText("朝向来源"), Tooltip("可选：角色移动/朝向 owner。存在时跟随实际面朝方向；工作台可不绑定并手动切方向。")]
    Movable movable;

    [SerializeField]
    [LabelText("默认四向库"), Tooltip("启动时可使用的默认 SE/SW/NE/NW SpriteLibraryAsset 集合。留空时等待动作驱动或工作台显式设置。")]
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

    /// <summary>启用时绑定身体朝向监听。没有 Movable 的工作台场景会保留手动方向切换能力。</summary>
    void OnEnable()
    {
        if (!ValidateRequiredReferences())
            return;

        if (_libraries == null && defaultAnimationLibraries != null && defaultAnimationLibraries.IsComplete)
            SetAnimationLibraries(defaultAnimationLibraries, false);

        if (movable != null)
        {
            movable.AddLookAtDirectionChangedListener(SetFacingDirection);
            SetFacingDirection(movable.GetLookAtDirection());
        }
        else
        {
            ApplyDirectionVariant();
        }
    }

    void OnDisable()
    {
        if (movable != null)
            movable.RemoveLookAtDirectionChangedListener(SetFacingDirection);
    }

    public string[] GetDirectionNames()
    {
        return CharacterAnimationDirections.CopyNames();
    }

    public static Vector2 GetDirectionValue(int index)
    {
        return CharacterAnimationDirections.GetVector(index);
    }

    /// <summary>设置当前动作对应的四向库集合。四个方向必须齐全，缺任一方向都直接失败。</summary>
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

    /// <summary>手动切换方向索引，主要供工作台和预览控制使用。</summary>
    public bool SetDirection(int index)
    {
        if (!CharacterAnimationDirections.IsValidIndex(index))
            return false;

        _currentDirectionIndex = index;
        return ApplyDirectionVariant();
    }

    /// <summary>根据角色身体朝向解析四向索引。零向量保持当前方向，避免静止帧随机跳方向。</summary>
    public void SetFacingDirection(Vector2 direction)
    {
        if (direction.sqrMagnitude <= 0.0001f)
            return;

        SetDirection(CharacterAnimationDirections.ResolveIndex(direction, _currentDirectionIndex));
    }

    /// <summary>把当前方向对应的 SpriteLibraryAsset 写入 SpriteLibrary，并同步换装渲染器的预览方向。</summary>
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
