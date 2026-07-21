using System;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色交互目标解析与派发组件。
    /// 负责在交互半径内寻找角色朝向前方的交互对象，并把交互消息派发给目标父级链上的 <see cref="IInteractionReceiver"/>。
    /// </summary>
    /// <remarks>
    /// 它不负责玩家输入订阅，也不执行具体交互规则；输入命令由 <see cref="CharacterCommandExecutor"/> 调用，
    /// 具体交互结果由接收方实现。这样角色侧只承担“当前能不能交互、目标是谁、消息发给谁”。
    /// </remarks>
    [DisallowMultipleComponent]
    [RequireComponent(typeof(CharacterBase))]
    public sealed class CharacterButtonActivation : MonoBehaviour
    {
        // 复用静态列表减少每次交互派发时的临时分配；方法内部会立刻 Clear，不跨帧保存结果。
        private static readonly List<Component> s_interactionReceiverComponents = new();

        [Header("交互配置")]
        [SerializeField]
        [LabelText("角色引用"), Tooltip("发起交互的角色；通常自动取同物体上的 CharacterBase。")]
        private CharacterBase m_character = null;

        [SerializeField]
        [LabelText("交互基准点"), Tooltip("检测交互范围时使用的中心点；为空时使用角色 Transform。")]
        private Transform m_interactionPivot = null;

        [SerializeField]
        [LabelText("交互距离"), Tooltip("角色可检测交互对象的半径，单位为世界坐标。")]
        private float m_interactionDistance = 0.75f;

        [SerializeField]
        [LabelText("交互音效"), Tooltip("成功派发交互后请求播放的音效。为空时只执行交互，不播放音效。")]
        private AudioClipResolver m_interactionSound = null;

        // 当前帧刷新到的目标，只给 UI/控制反馈读取；真实交互时仍会重新解析一次目标。
        private GameObject m_currentTarget = null;

        // 本帧已经交互过时会阻挡 FireAbility，避免同一输入同时触发交互和技能。
        private bool m_interactedThisFrame = false;

        /// <summary>
        /// 交互检测使用的中心点。
        /// </summary>
        private Transform interactionPivot => m_interactionPivot != null ? m_interactionPivot : m_character.transform;

        /// <summary>
        /// 查询当前缓存交互目标的位置。
        /// 主要供 UI 提示、控制反馈或调试面板使用。
        /// </summary>
        public bool TryGetCurrentTargetPosition(out Vector3 position)
        {
            if (m_currentTarget != null)
            {
                position = m_currentTarget.transform.position;
                return true;
            }

            position = default;
            return false;
        }

        /// <summary>
        /// 本帧是否已经成功派发过交互。
        /// </summary>
        public bool HasInteractedThisFrame()
        {
            return m_interactedThisFrame;
        }

        /// <summary>
        /// 当前角色是否允许发起交互。
        /// </summary>
        public bool CanInteractNow()
        {
            return m_character && m_character.Can(EActionFlags.Interact);
        }

        /// <summary>
        /// 清理交互缓存。
        /// 控制目标切换、角色禁用或输入关闭时调用，避免旧目标继续显示。
        /// </summary>
        public void ResetState()
        {
            m_interactedThisFrame = false;
            m_currentTarget = null;
        }

        /// <summary>
        /// 刷新当前可交互目标。
        /// 这里只更新缓存，不执行交互行为。
        /// </summary>
        public void RefreshCurrentTarget()
        {
            m_interactedThisFrame = false;
            m_currentTarget = ResolveInteractibleObject();
        }

        /// <summary>
        /// 尝试执行交互。
        /// 如果外部传入明确目标，会直接使用该目标；否则按半径、层级、距离和朝向筛选当前目标。
        /// </summary>
        public bool TryInteract(GameObject explicitTarget = null)
        {
            GameObject currentTarget = ResolveInteractibleObject(explicitTarget);
            if (!TryDispatchInteraction(currentTarget))
            {
                return false;
            }

            m_interactedThisFrame = true;
            GameRuntimeEvents.RequestAudioPlayback(m_interactionSound);
            return true;
        }

        /// <summary>
        /// 解析当前交互对象。
        /// 筛选规则：显式目标优先；否则从配置层级内找半径范围对象，按距离排序，并只取角色朝向前方目标。
        /// </summary>
        private GameObject ResolveInteractibleObject(GameObject explicitTarget = null)
        {
            if (explicitTarget != null)
            {
                return explicitTarget;
            }

            if (!CanInteractNow())
            {
                return null;
            }

            Collider2D[] colliders = Physics2D.OverlapCircleAll(
                interactionPivot.position,
                m_interactionDistance,
                LayerMask.GetMask(GameManager.Config.interactionLayer));

            Array.Sort(colliders, (x, y) =>
                Vector3.Distance(interactionPivot.position, x.transform.position).CompareTo(
                    Vector3.Distance(interactionPivot.position, y.transform.position)));

            foreach (Collider2D collider in colliders)
            {
                Vector3 targetDirection = m_character.GetTargetDirection();
                Vector3 targetOffset = collider.transform.position + new Vector3(collider.offset.x, collider.offset.y, 0f) - interactionPivot.position;
                if (Vector3.Dot(targetDirection, targetOffset) > 0f)
                {
                    return collider.gameObject;
                }
            }

            return null;
        }

        /// <summary>
        /// 把交互消息派发给目标及其父级上的所有 <see cref="IInteractionReceiver"/>。
        /// 使用父级链是为了支持子碰撞体命中，但真正交互逻辑挂在父对象上的 Prefab 结构。
        /// </summary>
        private bool TryDispatchInteraction(GameObject currentInteractionTarget)
        {
            if (currentInteractionTarget == null)
            {
                return false;
            }

            s_interactionReceiverComponents.Clear();
            currentInteractionTarget.GetComponentsInParent(false, s_interactionReceiverComponents);

            bool dispatched = false;
            for (int i = 0; i < s_interactionReceiverComponents.Count; i++)
            {
                if (s_interactionReceiverComponents[i] is IInteractionReceiver interactionReceiver)
                {
                    interactionReceiver.OnInteract(m_character);
                    dispatched = true;
                }
            }

            return dispatched;
        }

        /// <summary>
        /// 运行时启动时补齐角色引用。
        /// </summary>
        private void Awake()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// 新挂组件或重置 Inspector 时补齐同物体角色引用。
        /// </summary>
        private void Reset()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// Inspector 修改后刷新引用。
        /// </summary>
        private void OnValidate()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// 只从同物体解析角色，保证交互发起者明确。
        /// </summary>
        private void EnsureCharacterReference()
        {
            if (m_character == null)
            {
                TryGetComponent(out m_character);
            }
        }
    }
}
