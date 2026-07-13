using FantasyWord.GameCore;
using UnityEngine;

/// <summary>
/// 角色动作控制器。只负责动作状态，不拥有朝向或 SpriteLibrary 变体。
/// </summary>
public class AnimationController : MonoBehaviour, ICharacterAnimationDriver
{
    [Header("动画配置")]
    [Tooltip("动画类型数据库")]
    public AnimationTypeDatabase animDatabase;

    Animator _animator;
    int _currentAnimIndex;
    GameObject _shadowObject;
    bool _shadowEnabled = true;
    string _lockedAnimationKey = string.Empty;

    [SerializeField]
    string _debugCurrentState = "";

    [SerializeField]
    string _debugAnimatorPath = "";

    public int CurrentAnimationIndex => _currentAnimIndex;
    public AnimationTypeDatabase AnimationDatabase => animDatabase;

    public AnimationTypeItem CurrentAnimationType
    {
        get
        {
            if (animDatabase != null
                && animDatabase.TryGetByIndex(_currentAnimIndex, out AnimationTypeItem currentType))
            {
                return currentType;
            }

            return null;
        }
    }

    public string CurrentAnimationKey => CurrentAnimationType != null
        ? CurrentAnimationType.name
        : string.Empty;

    public bool ShadowEnabled => _shadowEnabled;
    public Animator Animator => _animator;
    public string DebugCurrentState => _debugCurrentState;
    public string DebugAnimatorPath => _debugAnimatorPath;

    void Awake()
    {
        _animator = ResolveCharacterAnimator();
        FindShadowObject();
    }

    void OnEnable()
    {
        ApplyAnimation();
    }

    public void SetAnimation(int index)
    {
        if (animDatabase == null || index < 0 || index >= animDatabase.Count)
            return;
        if (!animDatabase.TryGetByIndex(index, out AnimationTypeItem animationType)
            || IsBlockedByAnimationLock(animationType?.name))
        {
            return;
        }

        _currentAnimIndex = index;
        ApplyAnimation();
    }

    public void SetAnimation(AnimationTypeItem animType)
    {
        if (animDatabase == null || animType == null || IsBlockedByAnimationLock(animType.name))
            return;

        int index = animDatabase.IndexOf(animType);
        if (index < 0)
            return;

        _currentAnimIndex = index;
        ApplyAnimation();
    }

    public bool TryPlayAnimation(string animationKey)
    {
        string normalizedKey = animationKey?.Trim();
        if (!string.IsNullOrEmpty(_lockedAnimationKey)
            && !string.Equals(normalizedKey, _lockedAnimationKey, System.StringComparison.Ordinal))
        {
            return true;
        }

        return TryApplyAnimation(normalizedKey);
    }

    public bool TryLockAnimation(string animationKey)
    {
        string normalizedKey = animationKey?.Trim();
        if (!TryApplyAnimation(normalizedKey))
            return false;

        _lockedAnimationKey = normalizedKey;
        return true;
    }

    public void ClearAnimationLock()
    {
        _lockedAnimationKey = string.Empty;
    }

    public bool TryRestoreAnimation(string expectedAnimationKey, string fallbackAnimationKey)
    {
        if (!string.IsNullOrEmpty(_lockedAnimationKey))
            return true;

        string normalizedExpectedKey = expectedAnimationKey?.Trim();
        if (!string.Equals(
                CurrentAnimationKey,
                normalizedExpectedKey,
                System.StringComparison.Ordinal))
        {
            return true;
        }

        return TryApplyAnimation(fallbackAnimationKey?.Trim());
    }

    public bool TryPreviewAnimation(string animationKey, float normalizedTime)
    {
        if (!TryPlayAnimation(animationKey) || _animator == null)
            return false;

        string stateName = ResolvePlayableStateName(CurrentAnimationType);
        if (string.IsNullOrWhiteSpace(stateName))
            return false;

        _animator.Play(Animator.StringToHash(stateName), 0, Mathf.Clamp01(normalizedTime));
        _animator.Update(0f);

        EquipmentRenderer[] renderers = GetComponentsInChildren<EquipmentRenderer>(true);
        for (int i = 0; i < renderers.Length; i++)
            renderers[i].Refresh();

        return true;
    }

    public void SetAnimationDatabase(AnimationTypeDatabase database, bool resetSelection)
    {
        animDatabase = database;

        if (animDatabase == null || animDatabase.Count <= 0)
        {
            _currentAnimIndex = 0;
            return;
        }

        if (resetSelection || _currentAnimIndex >= animDatabase.Count)
            _currentAnimIndex = GetDefaultAnimationIndex();

        ApplyAnimation();
    }

    public void SetShadowEnabled(bool enabled)
    {
        _shadowEnabled = enabled;
        if (_shadowObject != null)
            _shadowObject.SetActive(enabled);
    }

    public bool SupportsAnimation(AnimationTypeItem animType)
    {
        return !string.IsNullOrWhiteSpace(ResolvePlayableStateName(animType));
    }

    public string ResolvePlayableStateName(AnimationTypeItem animType)
    {
        if (animType == null || string.IsNullOrWhiteSpace(animType.name))
            return string.Empty;

        if (_animator == null)
            _animator = ResolveCharacterAnimator();
        if (_animator == null)
            return string.Empty;

        string actionName = animType.name;
        if (_animator.HasState(0, Animator.StringToHash(actionName)))
            return actionName;

        string fullPath = "Base Layer." + actionName;
        return _animator.HasState(0, Animator.StringToHash(fullPath))
            ? fullPath
            : string.Empty;
    }

    bool IsBlockedByAnimationLock(string animationKey)
    {
        return !string.IsNullOrEmpty(_lockedAnimationKey)
            && !string.Equals(
                animationKey?.Trim(),
                _lockedAnimationKey,
                System.StringComparison.Ordinal);
    }

    bool TryApplyAnimation(string animationKey)
    {
        if (animDatabase == null || string.IsNullOrWhiteSpace(animationKey))
            return false;

        AnimationTypeItem animationType = animDatabase.GetByKey(animationKey);
        if (animationType == null || !SupportsAnimation(animationType))
            return false;

        SetAnimation(animationType);
        return true;
    }

    void ApplyAnimation()
    {
        if (_animator == null || animDatabase == null)
            return;

        if (!animDatabase.TryGetByIndex(_currentAnimIndex, out AnimationTypeItem currentType)
            || currentType == null)
        {
            return;
        }

        PlayAnimatorState(currentType);
    }

    bool PlayAnimatorState(AnimationTypeItem animType)
    {
        string stateName = ResolvePlayableStateName(animType);
        if (string.IsNullOrWhiteSpace(stateName))
        {
            _debugCurrentState = $"Missing action state: {animType?.name}";
            return false;
        }

        _animator.Play(Animator.StringToHash(stateName), 0, 0f);
        _animator.Update(0f);
        _debugCurrentState = animType.name;
        return true;
    }

    Animator ResolveCharacterAnimator()
    {
        Animator selfAnimator = GetComponent<Animator>();
        if (IsCharacterAnimator(selfAnimator))
        {
            _debugAnimatorPath = GetTransformPath(selfAnimator.transform);
            return selfAnimator;
        }

        Animator[] animators = GetComponentsInChildren<Animator>(true);
        for (int i = 0; i < animators.Length; i++)
        {
            Animator candidate = animators[i];
            if (!IsCharacterAnimator(candidate))
                continue;

            _debugAnimatorPath = GetTransformPath(candidate.transform);
            return candidate;
        }

        _debugAnimatorPath = "(未找到角色 Animator)";
        return null;
    }

    static bool IsCharacterAnimator(Animator animator)
    {
        if (animator == null)
            return false;
        if (animator.GetComponentInParent<Canvas>() != null
            || animator.GetComponentInParent<RectTransform>() != null)
        {
            return false;
        }

        Transform current = animator.transform;
        while (current != null)
        {
            string objectName = current.name;
            if (ContainsIgnoreCase(objectName, "Canvas")
                || ContainsIgnoreCase(objectName, "Dialogue")
                || ContainsIgnoreCase(objectName, "Dialog")
                || ContainsIgnoreCase(objectName, "Bubble")
                || ContainsIgnoreCase(objectName, "Speech")
                || ContainsIgnoreCase(objectName, "Floating"))
            {
                return false;
            }

            current = current.parent;
        }

        return animator.GetComponent<SpriteRenderer>() != null
            || animator.GetComponent<EquipmentRenderer>() != null
            || animator.GetComponentInChildren<SpriteRenderer>(true) != null
            || animator.GetComponentInChildren<EquipmentRenderer>(true) != null;
    }

    static bool ContainsIgnoreCase(string source, string value)
    {
        return !string.IsNullOrEmpty(source)
            && source.IndexOf(value, System.StringComparison.OrdinalIgnoreCase) >= 0;
    }

    static string GetTransformPath(Transform target)
    {
        if (target == null)
            return string.Empty;

        string path = target.name;
        Transform current = target.parent;
        while (current != null)
        {
            path = current.name + "/" + path;
            current = current.parent;
        }

        return path;
    }

    void FindShadowObject()
    {
        _shadowObject = null;
        Transform shadow = transform.Find("Shadow");
        if (shadow == null)
            return;

        _shadowObject = shadow.gameObject;
        _shadowEnabled = _shadowObject.activeSelf;
    }

    int GetDefaultAnimationIndex()
    {
        if (animDatabase == null)
            return 0;

        AnimationTypeItem idle = animDatabase.GetByKey("Idle");
        int idleIndex = animDatabase.IndexOf(idle);
        return idleIndex >= 0 ? idleIndex : 0;
    }
}
