using GAS.Runtime;
using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色玩家命令执行器。
    /// 负责把 <see cref="PlayerCommandRequest"/> 分发到交互、移动、菜单和技能等角色侧组件。
    /// </summary>
    /// <remarks>
    /// 这里是“命令路由层”，不是玩家输入 owner，也不直接持有移动、交互或能力规则。
    /// <see cref="PlayerSystem"/> 决定当前控制目标，<see cref="CharacterPlayerControl"/> 提交订单，
    /// 本组件只按命令类型调用角色已有能力，并把失败原因统一转成 <see cref="PlayerCommandResult"/>。
    /// </remarks>
    [DisallowMultipleComponent]
    [RequireComponent(typeof(CharacterBase))]
    public sealed class CharacterCommandExecutor : MonoBehaviour
    {
        [SerializeField]
        [LabelText("角色引用"), Tooltip("执行玩家命令的角色；通常自动取同物体上的 CharacterBase。")]
        private CharacterBase m_character = null;

        // 可选组件缓存。命令执行时只从同物体解析，不做场景搜索，保持命令目标明确。
        private CharacterButtonActivation m_buttonActivation = null;
        private CharacterMovement m_movement = null;

        /// <summary>
        /// 提交玩家订单。
        /// 单角色执行时尝试执行一次命令，并把执行结果包装成订单结果；控制组会在自己的入口统计多成员结果。
        /// </summary>
        public PlayerOrderResult Submit(PlayerOrderRequest orderRequest)
        {
            PlayerCommandResult commandResult = Execute(orderRequest.CommandRequest);
            return commandResult.Succeeded
                ? PlayerOrderResult.Success(orderRequest, 1, commandResult)
                : PlayerOrderResult.Failed(orderRequest, 1, commandResult);
        }

        /// <summary>
        /// 执行单条玩家命令。
        /// 先检查角色引用、组件启用状态和命令 actor，再按命令类型进入具体执行函数。
        /// </summary>
        public PlayerCommandResult Execute(PlayerCommandRequest request)
        {
            if (!m_character)
            {
                return PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.InvalidControlledCharacter);
            }

            if (!isActiveAndEnabled)
            {
                return PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.NotRunning);
            }

            if (request.CommandContext.HasActor && request.Actor != m_character)
            {
                // 命令上下文指定了 actor 时，只允许该角色执行，避免控制组转发时串到错误成员。
                return PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.ActorMismatch);
            }

            return request.Kind switch
            {
                EPlayerCommandKind.Interact => ExecuteInteractCommand(request),
                EPlayerCommandKind.OpenGameMenu => ExecuteOpenGameMenuCommand(request),
                EPlayerCommandKind.Move => ExecuteMoveCommand(request),
                EPlayerCommandKind.StopMove => ExecuteStopMoveCommand(request),
                EPlayerCommandKind.ClickMove => ExecuteClickMoveCommand(request),
                EPlayerCommandKind.ToggleMovementControlMode => ExecuteToggleMovementControlModeCommand(request),
                EPlayerCommandKind.FireAbility => ExecuteFireAbilityCommand(request),
                EPlayerCommandKind.StopFireAbility => ExecuteStopFireAbilityCommand(request),
                _ => PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.InvalidCommand)
            };
        }

        /// <summary>
        /// 启动时补齐引用和常用子组件缓存。
        /// </summary>
        private void Awake()
        {
            EnsureCharacterReference();
            ResolveButtonActivation();
            ResolveMovement();
        }

        /// <summary>
        /// 新挂组件或重置 Inspector 时补齐同物体角色引用。
        /// </summary>
        private void Reset()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// Inspector 修改后刷新角色引用。
        /// </summary>
        private void OnValidate()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// 执行交互命令。
        /// 交互组件负责目标解析和派发；命令执行器只把缺少组件或状态锁定映射成失败原因。
        /// </summary>
        private PlayerCommandResult ExecuteInteractCommand(PlayerCommandRequest request)
        {
            CharacterButtonActivation buttonActivation = ResolveButtonActivation();
            if (buttonActivation == null || !buttonActivation.CanInteractNow())
            {
                return PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.InteractionLocked);
            }

            return buttonActivation.TryInteract(request.InteractionTarget)
                ? PlayerCommandResult.Success(request)
                : PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.BlockedByState);
        }

        /// <summary>
        /// 执行打开游戏菜单命令。
        /// 当前复用交互动作门禁，避免死亡、硬直或其它不可操作状态下打开暂停菜单。
        /// </summary>
        private PlayerCommandResult ExecuteOpenGameMenuCommand(PlayerCommandRequest request)
        {
            if (!m_character.Can(EActionFlags.Interact))
            {
                return PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.BlockedByState);
            }

            GameRuntimeEvents.RequestMenu(EMenu.Pause);
            return PlayerCommandResult.Success(request);
        }

        /// <summary>
        /// 执行方向移动命令。
        /// 具体移动模式门禁由 <see cref="CharacterMovement"/> 负责。
        /// </summary>
        private PlayerCommandResult ExecuteMoveCommand(PlayerCommandRequest request)
        {
            CharacterMovement movement = ResolveMovement();
            return movement != null && movement.HandleDirectionalMove(request.Direction)
                ? PlayerCommandResult.Success(request)
                : PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.BlockedByState);
        }

        /// <summary>
        /// 执行停止移动命令。
        /// </summary>
        private PlayerCommandResult ExecuteStopMoveCommand(PlayerCommandRequest request)
        {
            CharacterMovement movement = ResolveMovement();
            return movement != null && movement.StopMovement()
                ? PlayerCommandResult.Success(request)
                : PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.BlockedByState);
        }

        /// <summary>
        /// 执行点击移动命令。
        /// 点击命令必须带世界坐标；路径、导航图和合法目标点仍由 <see cref="CharacterMovement"/> 处理。
        /// </summary>
        private PlayerCommandResult ExecuteClickMoveCommand(PlayerCommandRequest request)
        {
            if (!request.WorldPosition.HasValue)
            {
                return PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.InvalidTarget);
            }

            CharacterMovement movement = ResolveMovement();
            return movement != null && movement.HandleClickMove(request.WorldPosition.Value)
                ? PlayerCommandResult.Success(request)
                : PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.BlockedByState);
        }

        /// <summary>
        /// 执行移动控制模式切换命令。
        /// </summary>
        private PlayerCommandResult ExecuteToggleMovementControlModeCommand(PlayerCommandRequest request)
        {
            CharacterMovement movement = ResolveMovement();
            return movement != null && movement.ToggleMovementControlMode()
                ? PlayerCommandResult.Success(request)
                : PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.BlockedByState);
        }

        /// <summary>
        /// 执行技能开火命令。
        /// 成功路径会把命令上下文转换成 Ability 激活上下文，再交给角色能力槽。
        /// </summary>
        private PlayerCommandResult ExecuteFireAbilityCommand(PlayerCommandRequest request)
        {
            if (ResolveButtonActivation()?.HasInteractedThisFrame() == true)
            {
                // 同一帧已经交互过时，不再触发技能，避免一个输入同时“对话/开箱”和攻击。
                return PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.BlockedByState);
            }

            CharacterAbilityFireResult fireResult = m_character.FireEquippedAbilityAtIndex(
                request.AbilityIndex,
                request.CommandContext,
                CreateAbilityActivationContext(request));

            if (!fireResult.HasAbilitySource)
            {
                return PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.MissingAbility);
            }

            if (fireResult.Result != EAbilityFireCheckResult.Valid)
            {
                GameRuntimeEvents.NotifyPlayerAbilityFireFailed(fireResult.FormalGasAbilityCode, fireResult.Result);
                return PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.AbilityRejected);
            }

            return PlayerCommandResult.Success(request);
        }

        /// <summary>
        /// 创建技能激活上下文。
        /// 这里把目标角色转换成 EX-GAS 的目标 Cell，并把命令方向解析成 Ability 瞄准方向。
        /// </summary>
        private AbilityActivationContext CreateAbilityActivationContext(PlayerCommandRequest request)
        {
            AbilitySystemCell mainTarget = null;
            if (request.TargetCharacter != null &&
                request.TargetCharacter.TryGetFormalAbilitySystem(out AbilitySystemComponent targetAbilitySystem))
            {
                mainTarget = targetAbilitySystem.Cell;
            }

            Vector2 aimDirection = ResolveAbilityAimDirection(request);
            Vector3 aimOrigin = m_character.transform.position;
            return aimDirection.sqrMagnitude > 0.0001f
                ? new AbilityActivationContext(aimOrigin, aimDirection, mainTarget)
                : new AbilityActivationContext(aimOrigin, mainTarget);
        }

        /// <summary>
        /// 解析技能瞄准方向。
        /// 优先级：显式方向输入 → 目标角色方向 → 世界坐标方向 → 角色当前目标方向。
        /// </summary>
        private Vector2 ResolveAbilityAimDirection(PlayerCommandRequest request)
        {
            if (request.Direction.sqrMagnitude > 0.0001f)
            {
                return request.Direction.normalized;
            }

            Vector2 characterPosition = m_character.transform.position;
            if (request.TargetCharacter != null)
            {
                Vector2 targetDirection =
                    (Vector2)request.TargetCharacter.transform.position - characterPosition;
                if (targetDirection.sqrMagnitude > 0.0001f)
                {
                    return targetDirection.normalized;
                }
            }

            if (request.WorldPosition.HasValue)
            {
                Vector2 worldDirection = request.WorldPosition.Value - characterPosition;
                if (worldDirection.sqrMagnitude > 0.0001f)
                {
                    return worldDirection.normalized;
                }
            }

            Vector2 currentDirection = m_character.GetTargetDirection();
            return currentDirection.sqrMagnitude > 0.0001f
                ? currentDirection.normalized
                : Vector2.zero;
        }

        /// <summary>
        /// 执行停止技能开火命令。
        /// </summary>
        private PlayerCommandResult ExecuteStopFireAbilityCommand(PlayerCommandRequest request)
        {
            return m_character.StopFireEquippedAbilityAtIndex(request.AbilityIndex)
                ? PlayerCommandResult.Success(request)
                : PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.MissingAbility);
        }

        /// <summary>
        /// 只从同物体解析角色，保证命令执行目标明确。
        /// </summary>
        private void EnsureCharacterReference()
        {
            if (m_character == null)
            {
                TryGetComponent(out m_character);
            }
        }

        /// <summary>
        /// 懒解析交互组件。
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
        /// 懒解析移动组件。
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
