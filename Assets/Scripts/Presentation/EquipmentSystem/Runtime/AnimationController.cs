using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 动画控制器组件
/// 挂在角色上，提供动画切换、方向控制和阴影开关 API
/// </summary>
public class AnimationController : MonoBehaviour
{
    [Header("动画配置")]
    [Tooltip("动画类型数据库")]
    public AnimationTypeDatabase animDatabase;
    
    [Header("方向配置")]
    [Tooltip("方向名称")]
    public string[] directionNames = { "SE", "SW", "NE", "NW" };
    
    // 方向对应的 X/Y 值: SE(1,-1), SW(-1,-1), NE(1,1), NW(-1,1)
    static readonly Vector2[] DirectionValues = {
        new Vector2(1, -1),   // SE
        new Vector2(-1, -1),  // SW
        new Vector2(1, 1),    // NE
        new Vector2(-1, 1)    // NW
    };

    static readonly string[] DirectionStateSuffixes =
    {
        "_SE",
        "_SW",
        "_NE",
        "_NW",
    };
    
    Animator _animator;
    readonly HashSet<string> _animatorParameterNames = new HashSet<string>();
    int _currentAnimIndex = 0;
    int _currentDirIndex = 0;
    GameObject _shadowObject;
    bool _shadowEnabled = true;
    AnimationTypeItem _lastAnimType;
    [SerializeField]
    string _debugCurrentState = "";
    [SerializeField]
    string _debugAnimatorPath = "";
    
    /// <summary>当前动画索引</summary>
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
    
    /// <summary>当前方向索引</summary>
    public int CurrentDirectionIndex => _currentDirIndex;
    
    /// <summary>阴影是否显示</summary>
    public bool ShadowEnabled => _shadowEnabled;
    
    /// <summary>获取 Animator</summary>
    public Animator Animator => _animator;

    public string DebugCurrentState => _debugCurrentState;
    public string DebugAnimatorPath => _debugAnimatorPath;
    
    /// <summary>
    /// 根据方向索引获取方向向量（供其他组件复用）
    /// </summary>
    public static Vector2 GetDirectionValue(int index)
    {
        if (index < 0 || index >= DirectionValues.Length)
            return DirectionValues[0];
        return DirectionValues[index];
    }
    
    void Awake()
    {
        _animator = ResolveCharacterAnimator();
        RefreshAnimatorParameterCache();
        FindShadowObject();
    }
    
    void OnEnable()
    {
        // 激活时应用当前状态
        ApplyAnimation();
        ApplyDirection();
    }
    
    /// <summary>
    /// 设置动画
    /// </summary>
    /// <param name="index">动画索引</param>
    public void SetAnimation(int index)
    {
        if (animDatabase == null || index < 0 || index >= animDatabase.Count) return;
        _currentAnimIndex = index;
        ApplyAnimation();
    }
    
    /// <summary>
    /// 设置动画（按类型）
    /// </summary>
    public void SetAnimation(AnimationTypeItem animType)
    {
        if (animDatabase == null || animType == null) return;
        int index = animDatabase.IndexOf(animType);
        if (index >= 0)
        {
            _currentAnimIndex = index;
            ApplyAnimation();
        }
    }

    public void SetAnimationDatabase(AnimationTypeDatabase database, bool resetSelection)
    {
        animDatabase = database;
        _lastAnimType = null;

        if (animDatabase == null || animDatabase.Count <= 0)
        {
            _currentAnimIndex = 0;
            return;
        }

        if (resetSelection || _currentAnimIndex >= animDatabase.Count)
            _currentAnimIndex = GetDefaultAnimationIndex();

        ApplyAnimation();
    }

    public void SetRuntimeAnimatorController(RuntimeAnimatorController controller, bool resetState)
    {
        if (controller == null)
            return;

        if (_animator == null)
            _animator = ResolveCharacterAnimator();
        if (_animator == null)
            return;

        _animator.runtimeAnimatorController = controller;
        _animator.Rebind();
        _animator.Update(0f);
        RefreshAnimatorParameterCache();
        _lastAnimType = null;

        if (resetState)
        {
            _currentAnimIndex = 0;
            _currentDirIndex = 0;
        }

        ApplyAnimation();
        ApplyDirection();
    }
    
    /// <summary>
    /// 设置方向
    /// </summary>
    /// <param name="index">方向索引 (0=SE, 1=SW, 2=NE, 3=NW)</param>
    public void SetDirection(int index)
    {
        if (index < 0 || index >= DirectionValues.Length) return;
        _currentDirIndex = index;
        ApplyDirection();
    }
    
    /// <summary>
    /// 设置阴影显示
    /// </summary>
    public void SetShadowEnabled(bool enabled)
    {
        _shadowEnabled = enabled;
        if (_shadowObject != null)
            _shadowObject.SetActive(enabled);
    }
    
    /// <summary>
    /// 获取方向名称列表（供 UI 使用）
    /// </summary>
    public string[] GetDirectionNames() => directionNames;

    public bool SupportsAnimation(AnimationTypeItem animType)
    {
        if (animType == null)
            return false;

        if (_animator == null)
            _animator = ResolveCharacterAnimator();

        RefreshAnimatorParameterCache();
        return HasAnimatorState(animType.name);
    }

    public string ResolvePlayableStateName(AnimationTypeItem animType)
    {
        if (animType == null || string.IsNullOrWhiteSpace(animType.name))
            return string.Empty;

        if (_animator == null)
            _animator = ResolveCharacterAnimator();
        if (_animator == null)
            return string.Empty;

        string[] candidateNames = GetStateNameCandidates(animType.name, _currentDirIndex);
        for (int i = 0; i < candidateNames.Length; i++)
        {
            string stateName = candidateNames[i];
            if (!string.IsNullOrWhiteSpace(stateName)
                && _animator.HasState(0, Animator.StringToHash(stateName)))
            {
                return stateName;
            }
        }

        return string.Empty;
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
            if (IsCharacterAnimator(candidate))
            {
                _debugAnimatorPath = GetTransformPath(candidate.transform);
                return candidate;
            }
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

    static string GetTransformPath(Transform transform)
    {
        if (transform == null)
            return string.Empty;

        string path = transform.name;
        Transform current = transform.parent;
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
        
        // 按名称查找 Shadow 子对象
        var shadow = transform.Find("Shadow");
        if (shadow != null)
        {
            _shadowObject = shadow.gameObject;
            _shadowEnabled = _shadowObject.activeSelf;
        }
    }
    
    void ApplyAnimation()
    {
        if (_animator == null || animDatabase == null) return;

        if (animDatabase.TryGetByIndex(_currentAnimIndex, out var currentType) && currentType != null)
        {
            PlayAnimatorState(currentType);
            _lastAnimType = currentType;
        }
    }
    
    void ApplyDirection()
    {
        if (_animator == null) return;
        
        var dir = DirectionValues[_currentDirIndex];
        if (HasAnimatorParameter("X"))
            _animator.SetFloat("X", dir.x);
        if (HasAnimatorParameter("Y"))
            _animator.SetFloat("Y", dir.y);

        if (_lastAnimType != null)
            PlayAnimatorState(_lastAnimType);
    }

    void RefreshAnimatorParameterCache()
    {
        _animatorParameterNames.Clear();
        if (_animator == null)
            return;

        AnimatorControllerParameter[] parameters = _animator.parameters;
        for (int i = 0; i < parameters.Length; i++)
        {
            AnimatorControllerParameter parameter = parameters[i];
            if (!string.IsNullOrWhiteSpace(parameter.name))
                _animatorParameterNames.Add(parameter.name);
        }
    }

    bool HasAnimatorParameter(string parameterName)
    {
        return !string.IsNullOrWhiteSpace(parameterName) && _animatorParameterNames.Contains(parameterName);
    }

    bool PlayAnimatorState(AnimationTypeItem animType)
    {
        if (_animator == null || animType == null || string.IsNullOrWhiteSpace(animType.name))
            return false;

        string[] candidateNames = GetStateNameCandidates(animType.name, _currentDirIndex);
        if (TryPlayAnimatorState(candidateNames))
            return true;

        _animator.Rebind();
        _animator.Update(0f);
        RefreshAnimatorParameterCache();
        if (TryPlayAnimatorState(candidateNames))
            return true;

        _debugCurrentState = $"Missing state: {animType.name}";
        return false;
    }

    bool TryPlayAnimatorState(string[] candidateNames)
    {
        for (int i = 0; i < candidateNames.Length; i++)
        {
            string stateName = candidateNames[i];
            if (string.IsNullOrWhiteSpace(stateName))
                continue;

            int stateHash = Animator.StringToHash(stateName);
            if (!_animator.HasState(0, stateHash))
                continue;

            _animator.Play(stateHash, 0, 0f);
            _animator.Update(0f);
            _debugCurrentState = stateName;
            return true;
        }

        return false;
    }

    bool HasAnimatorState(string animationKey)
    {
        if (_animator == null || string.IsNullOrWhiteSpace(animationKey))
            return false;

        for (int directionIndex = 0; directionIndex < DirectionStateSuffixes.Length; directionIndex++)
        {
            string[] candidateNames = GetStateNameCandidates(animationKey, directionIndex);
            for (int i = 0; i < candidateNames.Length; i++)
            {
                string stateName = candidateNames[i];
                if (string.IsNullOrWhiteSpace(stateName))
                    continue;

                if (_animator.HasState(0, Animator.StringToHash(stateName)))
                    return true;
            }
        }

        return false;
    }

    static string[] GetStateNameCandidates(string animationKey, int directionIndex)
    {
        if (string.IsNullOrWhiteSpace(animationKey))
            return System.Array.Empty<string>();

        string suffix = GetDirectionStateSuffix(directionIndex);
        List<string> candidates = new List<string>();
        foreach (string alias in GetActionStateAliases(animationKey))
        {
            AddStateCandidate(candidates, alias + suffix);
            AddStateCandidate(candidates, "Base Layer." + alias + suffix);
        }

        foreach (string alias in GetActionStateAliases(animationKey))
        {
            AddStateCandidate(candidates, alias);
            AddStateCandidate(candidates, alias + " Blend Tree");
            AddStateCandidate(candidates, "Base Layer." + alias);
            AddStateCandidate(candidates, "Base Layer." + alias + " Blend Tree");
        }

        return candidates.ToArray();
    }

    static IEnumerable<string> GetActionStateAliases(string animationKey)
    {
        yield return animationKey;

        switch (animationKey)
        {
            case "ChargedAttack":
                yield return "ChargedAttack_Human";
                break;
            case "SoulDie":
                yield return "DieSoul";
                break;
            case "SpinDie":
                yield return "DieSpin";
                break;
            case "Die":
                yield return "SoulDie";
                yield return "DieSoul";
                yield return "SpinDie";
                yield return "DieSpin";
                break;
            case "Wait":
                yield return "Idle";
                break;
        }
    }

    static string GetDirectionStateSuffix(int directionIndex)
    {
        if (directionIndex < 0 || directionIndex >= DirectionStateSuffixes.Length)
            return DirectionStateSuffixes[0];

        return DirectionStateSuffixes[directionIndex];
    }

    static void AddStateCandidate(List<string> candidates, string stateName)
    {
        if (string.IsNullOrWhiteSpace(stateName) || candidates.Contains(stateName))
            return;

        candidates.Add(stateName);
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
