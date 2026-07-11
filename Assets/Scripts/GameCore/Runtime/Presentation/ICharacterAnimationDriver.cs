using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色玩法层向表现层提交动作键和朝向的最小合同。
    /// GAS、移动和受击逻辑只依赖该合同，不依赖具体 Animator 或换装实现。
    /// </summary>
    public interface ICharacterAnimationDriver
    {
        bool TryPlayAnimation(string animationKey);
        bool TryLockAnimation(string animationKey);
        void ClearAnimationLock();
        bool TryRestoreAnimation(string expectedAnimationKey, string fallbackAnimationKey);
        bool TryPreviewAnimation(string animationKey, float normalizedTime);
        void SetFacingDirection(Vector2 direction);
    }
}
