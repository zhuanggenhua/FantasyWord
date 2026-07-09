using UnityEngine;

/// <summary>
/// 将装备换装示例里的方向行索引同步到 Animator 参数。
/// </summary>
[DisallowMultipleComponent]
[RequireComponent(typeof(Animator))]
public class AnimatorEquipmentSync : MonoBehaviour
{
    [Header("Animator 参数")]
    [Tooltip("方向行索引参数，0=SE，1=SW，2=NE，3=NW。")]
    [SerializeField]
    string rowParameterName = "Direction";

    [Tooltip("方向横轴参数名。")]
    [SerializeField]
    string xParameterName = "X";

    [Tooltip("方向纵轴参数名。")]
    [SerializeField]
    string yParameterName = "Y";

    [Header("同步来源")]
    [Tooltip("可选动画控制器；为空时会从当前物体查找。")]
    [SerializeField]
    AnimationController animationController;

    Animator _animator;
    int _rowHash;
    int _xHash;
    int _yHash;
    bool _hasRowParameter;
    bool _hasXParameter;
    bool _hasYParameter;
    int _lastDirectionIndex = -1;

    void Awake()
    {
        _animator = GetComponent<Animator>();
        if (animationController == null)
            animationController = GetComponent<AnimationController>();

        _rowHash = Animator.StringToHash(rowParameterName);
        _xHash = Animator.StringToHash(xParameterName);
        _yHash = Animator.StringToHash(yParameterName);
        CacheAnimatorParameters();
    }

    void OnEnable()
    {
        _lastDirectionIndex = -1;
        SyncDirection();
    }

    void LateUpdate()
    {
        SyncDirection();
    }

    void SyncDirection()
    {
        if (_animator == null)
            return;

        int directionIndex = animationController != null
            ? animationController.CurrentDirectionIndex
            : 0;

        if (directionIndex == _lastDirectionIndex)
            return;

        _lastDirectionIndex = directionIndex;
        var direction = AnimationController.GetDirectionValue(directionIndex);

        if (_hasRowParameter)
            _animator.SetInteger(_rowHash, directionIndex);
        if (_hasXParameter)
            _animator.SetFloat(_xHash, direction.x);
        if (_hasYParameter)
            _animator.SetFloat(_yHash, direction.y);
    }

    void CacheAnimatorParameters()
    {
        foreach (var parameter in _animator.parameters)
        {
            if (parameter.nameHash == _rowHash && parameter.type == AnimatorControllerParameterType.Int)
                _hasRowParameter = true;
            if (parameter.nameHash == _xHash && parameter.type == AnimatorControllerParameterType.Float)
                _hasXParameter = true;
            if (parameter.nameHash == _yHash && parameter.type == AnimatorControllerParameterType.Float)
                _hasYParameter = true;
        }
    }
}
