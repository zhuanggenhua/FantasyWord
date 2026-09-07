using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 单个角色的玩家输入目标。
    /// 这个组件挂在角色 Prefab 上，负责把 <see cref="PlayerSystem"/> 选中的“当前控制角色”接到命令执行器、
    /// 移动模式和交互目标刷新上。它不自己拥有玩家身份，也不直接改写世界状态；正式输入仍先进入
    /// <see cref="PlayerSystem"/>，再以 <see cref="PlayerOrderRequest"/> 的形式提交给角色命令链。
    /// </summary>
    /// <remarks>
    /// 这里同时维护一个很轻的本地控制状态：当角色从可控状态切出、被禁用或不再接受玩家输入时，
    /// 会主动清掉移动和朝向残留，避免上一个控制对象的输入意图继续影响角色。
    /// </remarks>
    [DisallowMultipleComponent]
    [RequireComponent(typeof(CharacterBase))]
    [RequireComponent(typeof(CharacterCommandExecutor))]
    public sealed class CharacterPlayerControl : MonoBehaviour, IPlayerInputTarget
    {
        [Header("控制组合")]
        [SerializeField]
        [LabelText("角色引用"), Tooltip("接收玩家控制的角色本体；通常自动取同物体上的 CharacterBase。")]
        private CharacterBase m_character = null;

        [SerializeField]
        [LabelText("命令执行器"), Tooltip("把玩家订单提交到正式角色命令链，缺失时会自动取同物体组件。")]
        private CharacterCommandExecutor m_commandExecutor = null;

        [SerializeField]
        [LabelText("接受玩家输入"), Tooltip("关闭后会立刻清理本地移动、朝向和交互缓存。")]
        private bool m_acceptsPlayerInput = true;

        // 交互和移动是可选能力组件，缓存后只在角色同物体上解析，不做运行时全局查找。
        private CharacterButtonActivation m_buttonActivation = null;
        private CharacterMovement m_movement = null;

        // 记录上一帧是否真的由本地玩家控制，用来在失去控制权时只清一次残留状态。
        private bool m_wasLocallyControlled;

        /// <summary>当前控制目标角色。</summary>
        public CharacterBase Character => m_character;

        /// <summary>该角色是否允许接收玩家输入。</summary>
        public bool AcceptsPlayerInput => m_acceptsPlayerInput;

        /// <summary>
        /// 设置玩家输入开关。
        /// 被关闭时会立即清理移动、朝向和交互缓存，避免角色继续沿用上一帧输入。
        /// </summary>
        public void SetAcceptsPlayerInput(bool acceptsPlayerInput)
        {
            m_acceptsPlayerInput = acceptsPlayerInput;
            if (!m_acceptsPlayerInput)
            {
                ResetLocalControlState();
            }
        }

        /// <summary>
        /// 尝试取得当前受控角色。
        /// 控制组后续也应实现同一接口返回自己的角色集合，而不是复制玩家输入订阅逻辑。
        /// </summary>
        public bool TryGetControlledCharacter(out CharacterBase character)
        {
            character = m_character;
            return character != null;
        }

        /// <summary>
        /// 创建受控角色快照。
        /// 单角色控制只返回自己；使用数组快照是为了给后续队伍/编队控制保留统一读取形状。
        /// </summary>
        public CharacterBase[] CreateControlledCharacterSnapshot()
        {
            return m_character ? new[] { m_character } : System.Array.Empty<CharacterBase>();
        }

        /// <summary>
        /// 提交玩家订单。
        /// 这里先做玩家输入、角色存活和控制状态门禁，真正的命令执行交给 <see cref="CharacterCommandExecutor"/>。
        /// </summary>
        public PlayerOrderResult SubmitPlayerOrder(PlayerOrderRequest orderRequest)
        {
            if (!m_acceptsPlayerInput || !m_character || !m_character.CanBePlayerControlled())
            {
                PlayerCommandResult failed = PlayerCommandResult.Failed(
                    orderRequest.CommandRequest,
                    EPlayerCommandFailureReason.ControlLocked);
                return PlayerOrderResult.Failed(orderRequest, 1, failed);
            }

            return ResolveCommandExecutor().Submit(orderRequest);
        }

        /// <summary>
        /// 查询当前移动控制模式。
        /// 缺少移动组件时回退为方向移动，方便 UI 和调试面板显示一个稳定默认值。
        /// </summary>
        public EPlayerMovementControlMode GetMovementControlMode()
        {
            CharacterMovement movement = ResolveMovement();
            return movement != null ? movement.MovementControlMode : EPlayerMovementControlMode.Directional;
        }

        /// <summary>
        /// 设置移动控制模式。
        /// 实际切换逻辑由 <see cref="CharacterMovement"/> 负责，这里只作为玩家输入目标的外部入口。
        /// </summary>
        public void SetMovementControlMode(EPlayerMovementControlMode mode)
        {
            ResolveMovement()?.SetMovementControlMode(mode);
        }

        /// <summary>
        /// 查询当前交互目标的位置，用于 UI 提示或控制反馈。
        /// 没有交互组件、当前没有目标或角色不能交互时返回 false。
        /// </summary>
        public bool TryGetCurrentInteractionTargetPosition(out Vector3 position)
        {
            CharacterButtonActivation buttonActivation = ResolveButtonActivation();
            if (buttonActivation != null)
            {
                return buttonActivation.TryGetCurrentTargetPosition(out position);
            }

            position = default;
            return false;
        }

        /// <summary>
        /// 初始化同物体引用缓存。
        /// </summary>
        private void Awake()
        {
            EnsureReferences();
        }

        /// <summary>
        /// 每帧只在“本角色就是当前玩家控制角色”时刷新交互目标和闲置朝向。
        /// 输入对象切换、角色死亡、动作锁定或组件禁用时，会清理本地残留状态。
        /// </summary>
        private void Update()
        {
            if (!m_character || !m_acceptsPlayerInput)
            {
                return;
            }

            if (!GameManager.PlayerSystem.TryGetCurrentControlledCharacter(out CharacterBase currentControlledCharacter) ||
                currentControlledCharacter != m_character ||
                !m_character.CanBePlayerControlled())
            {
                ResetLocalControlStateIfPreviouslyControlled();
                return;
            }

            m_wasLocallyControlled = true;

            // 交互目标只在当前控制角色上刷新，避免非当前角色因为玩家指针移动而更新提示目标。
            ResolveButtonActivation()?.RefreshCurrentTarget();
            CharacterMovement movement = ResolveMovement();
            if (movement == null)
            {
                m_character.ResetTargetDirection();
                return;
            }

            if (!m_character.CanUpdateTargetDirection())
            {
                return;
            }

            if (!movement.TryUpdateIdlePointerTargetDirection())
            {
                m_character.ResetTargetDirection();
            }
        }

        /// <summary>
        /// 角色或组件被禁用时清理输入残留。
        /// Unity 禁用可能来自死亡、场景卸载、对象池回收或切换 Prefab 状态。
        /// </summary>
        private void OnDisable()
        {
            ResetLocalControlState();
        }

        /// <summary>
        /// 新挂组件或重置 Inspector 时自动补齐同物体引用。
        /// </summary>
        private void Reset()
        {
            EnsureReferences();
        }

        /// <summary>
        /// Inspector 修改后刷新引用，降低 Prefab 作者手动漏绑的概率。
        /// </summary>
        private void OnValidate()
        {
            EnsureReferences();
        }

        /// <summary>
        /// 清理本地控制状态。
        /// 这里同时清移动和目标方向，因为两者都可能来自上一帧玩家输入。
        /// </summary>
        private void ResetLocalControlState()
        {
            if (m_character)
            {
                m_character.ResetTargetDirection();
                m_character.ResetMovement();
            }

            ResolveButtonActivation()?.ResetState();
            m_wasLocallyControlled = false;
        }

        /// <summary>
        /// 只在角色刚刚失去本地控制权时清理一次状态，避免非控制角色每帧重复重置。
        /// </summary>
        private void ResetLocalControlStateIfPreviouslyControlled()
        {
            if (!m_wasLocallyControlled)
            {
                return;
            }

            ResetLocalControlState();
        }

        /// <summary>
        /// 解析同物体依赖。
        /// 正式运行路径只允许通过显式组件关系取依赖，不做按名称、Tag 或场景搜索。
        /// </summary>
        private void EnsureReferences()
        {
            if (m_character == null)
            {
                TryGetComponent(out m_character);
            }

            if (m_commandExecutor == null)
            {
                TryGetComponent(out m_commandExecutor);
            }

            ResolveButtonActivation();
            ResolveMovement();
        }

        /// <summary>
        /// 懒解析命令执行器，兼容编辑期未手动绑定但同物体存在组件的 Prefab。
        /// </summary>
        private CharacterCommandExecutor ResolveCommandExecutor()
        {
            if (m_commandExecutor == null)
            {
                TryGetComponent(out m_commandExecutor);
            }

            return m_commandExecutor;
        }

        /// <summary>
        /// 懒解析交互能力组件。
        /// </summary>
        private CharacterButtonActivation ResolveButtonActivation()
        {
            if (m_buttonActivation == null && m_character != null)
            {
                m_character.TryGetComponent(out m_buttonActivation);
            }

            return m_buttonActivation;
        }

        /// <summary>
        /// 懒解析移动能力组件。
        /// </summary>
        private CharacterMovement ResolveMovement()
        {
            if (m_movement == null && m_character != null)
            {
                m_character.TryGetComponent(out m_movement);
            }

            return m_movement;
        }
    }
}
