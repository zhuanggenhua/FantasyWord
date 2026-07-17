using FantasyWord.GameCore;
using UnityEngine;

/// <summary>
/// 角色动作 Animator 驱动。只负责动作状态，不拥有朝向或 SpriteLibrary 变体。
/// </summary>
public class CharacterActionAnimatorDriver : MonoBehaviour, ICharacterAnimationDriver
{
    const float FallbackDamageRestoreDelay = 0.35f;
    const float MinimumAutoRestoreDelay = 0.05f;

    [Header("动画配置")]
    [Tooltip("动画类型数据库")]
    public AnimationTypeDatabase animDatabase;

    [SerializeField]
    [Tooltip("没有其它动作覆盖时恢复到的默认动作键。该键必须存在于动画类型数据库和 Animator 状态中。")]
    string defaultAnimationKey = "Idle";

    [SerializeField]
    [Tooltip("受击动作键。播放该动作后会按当前动作时长自动恢复默认动作。")]
    string damageAnimationKey = "Dmg";

    [SerializeField]
    [Tooltip("死亡动作键。角色死亡逻辑只请求锁定死亡表现，具体动作键由这里配置。")]
    string deathAnimationKey = "SpinDie";

    [Header("运行时依赖")]
    [SerializeField]
    [Tooltip("驱动角色动作片段的 Animator。正式 Prefab 应显式绑定；未绑定时只允许使用同对象 Animator。")]
    Animator characterAnimator;

    [SerializeField]
    [Tooltip("角色脚底阴影对象。为空表示该角色没有由动作控制器管理的独立阴影。")]
    GameObject shadowObject;

    Animator _animator;
    int _currentAnimIndex;
    bool _shadowEnabled = true;
    string _lockedAnimationKey = string.Empty;
    string _pendingAutoRestoreAnimationKey = string.Empty;
    string _pendingAutoRestoreFallbackKey = string.Empty;
    float _pendingAutoRestoreTime;

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
        CacheAnimatorReference(true);
        InitializeShadowState();
    }

    void OnEnable()
    {
        ApplyAnimation();
    }

    void Update()
    {
        TryApplyPendingAutoRestore();
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
        CancelPendingAutoRestore();
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
        CancelPendingAutoRestore();
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

        if (!TryApplyAnimation(normalizedKey))
            return false;

        ScheduleAutoRestoreIfNeeded(normalizedKey);
        return true;
    }

    public bool TryLockAnimation(string animationKey)
    {
        string normalizedKey = animationKey?.Trim();
        if (!TryApplyAnimation(normalizedKey))
            return false;

        CancelPendingAutoRestore();
        _lockedAnimationKey = normalizedKey;
        return true;
    }

    public void ClearAnimationLock()
    {
        _lockedAnimationKey = string.Empty;
    }

    public bool TryPlayDefaultAnimation()
    {
        return TryPlayAnimation(DefaultAnimationKey);
    }

    public bool TryPlayDamageAnimation()
    {
        return TryPlayAnimation(DamageAnimationKey);
    }

    public bool TryLockDeathAnimation()
    {
        return TryLockAnimation(DeathAnimationKey);
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

    public bool TryRestoreDefaultAnimation(string expectedAnimationKey)
    {
        return TryRestoreAnimation(expectedAnimationKey, DefaultAnimationKey);
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
        if (shadowObject != null)
            shadowObject.SetActive(enabled);
    }

    public bool SupportsAnimation(AnimationTypeItem animType)
    {
        return !string.IsNullOrWhiteSpace(ResolvePlayableStateName(animType));
    }

    public string ResolvePlayableStateName(AnimationTypeItem animType)
    {
        if (animType == null || string.IsNullOrWhiteSpace(animType.name))
            return string.Empty;

        if (!EnsureAnimatorReference())
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

    void ScheduleAutoRestoreIfNeeded(string animationKey)
    {
        string damageKey = DamageAnimationKey;
        if (!Application.isPlaying ||
            string.IsNullOrWhiteSpace(damageKey) ||
            !string.Equals(animationKey, damageKey, System.StringComparison.Ordinal))
        {
            return;
        }

        _pendingAutoRestoreAnimationKey = damageKey;
        _pendingAutoRestoreFallbackKey = DefaultAnimationKey;
        _pendingAutoRestoreTime = Time.time + ResolveCurrentAnimationDurationSeconds();
    }

    void TryApplyPendingAutoRestore()
    {
        if (string.IsNullOrEmpty(_pendingAutoRestoreAnimationKey) ||
            Time.time < _pendingAutoRestoreTime)
        {
            return;
        }

        if (!string.Equals(
                CurrentAnimationKey,
                _pendingAutoRestoreAnimationKey,
                System.StringComparison.Ordinal))
        {
            CancelPendingAutoRestore();
            return;
        }

        TryRestoreAnimation(_pendingAutoRestoreAnimationKey, _pendingAutoRestoreFallbackKey);
        CancelPendingAutoRestore();
    }

    void CancelPendingAutoRestore()
    {
        _pendingAutoRestoreAnimationKey = string.Empty;
        _pendingAutoRestoreFallbackKey = string.Empty;
        _pendingAutoRestoreTime = 0.0f;
    }

    float ResolveCurrentAnimationDurationSeconds()
    {
        if (_animator == null)
        {
            return FallbackDamageRestoreDelay;
        }

        AnimatorStateInfo stateInfo = _animator.GetCurrentAnimatorStateInfo(0);
        if (float.IsNaN(stateInfo.length) ||
            float.IsInfinity(stateInfo.length) ||
            stateInfo.length < MinimumAutoRestoreDelay)
        {
            return FallbackDamageRestoreDelay;
        }

        return stateInfo.length;
    }

    bool EnsureAnimatorReference()
    {
        if (_animator != null)
            return true;

        CacheAnimatorReference(false);
        return _animator != null;
    }

    void CacheAnimatorReference(bool reportMissing)
    {
        _animator = characterAnimator != null ? characterAnimator : GetComponent<Animator>();
        if (_animator != null)
        {
            _debugAnimatorPath = GetTransformPath(_animator.transform);
            return;
        }

        _debugAnimatorPath = "(未配置角色 Animator)";
        if (reportMissing)
        {
            Debug.LogError(
                "[CharacterActionAnimatorDriver] 缺少角色 Animator。请在 Prefab 上显式绑定 characterAnimator，或把 Animator 放在同一对象。",
                this);
        }
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

    void InitializeShadowState()
    {
        if (shadowObject == null)
            return;

        _shadowEnabled = shadowObject.activeSelf;
    }

    int GetDefaultAnimationIndex()
    {
        if (animDatabase == null)
            return 0;

        AnimationTypeItem defaultAnimation = animDatabase.GetByKey(DefaultAnimationKey);
        int defaultIndex = animDatabase.IndexOf(defaultAnimation);
        return defaultIndex >= 0 ? defaultIndex : 0;
    }

    string DefaultAnimationKey => NormalizeAnimationKey(defaultAnimationKey);
    string DamageAnimationKey => NormalizeAnimationKey(damageAnimationKey);
    string DeathAnimationKey => NormalizeAnimationKey(deathAnimationKey);

    static string NormalizeAnimationKey(string animationKey)
    {
        return animationKey?.Trim() ?? string.Empty;
    }
}
