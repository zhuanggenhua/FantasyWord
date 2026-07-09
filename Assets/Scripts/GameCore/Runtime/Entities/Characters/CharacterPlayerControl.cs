using UnityEngine;

namespace FantasyWord.GameCore
{
    [DisallowMultipleComponent]
    [RequireComponent(typeof(CharacterBase))]
    public sealed class CharacterPlayerControl : MonoBehaviour, IPlayerInputTarget
    {
        [Header("Control Composition")]
        [SerializeField] private CharacterBase m_character = null;
        [SerializeField] private bool m_acceptsPlayerInput = true;

        private CharacterButtonActivation m_buttonActivation = null;
        private CharacterMovement m_movement = null;

        public CharacterBase Character => m_character;
        public bool AcceptsPlayerInput => m_acceptsPlayerInput;

        public bool TryGetControlledCharacter(out CharacterBase character)
        {
            character = m_character;
            return character != null;
        }

        public CharacterBase[] CreateControlledCharacterSnapshot()
        {
            return m_character ? new[] { m_character } : System.Array.Empty<CharacterBase>();
        }

        public PlayerOrderResult SubmitPlayerOrder(PlayerOrderRequest orderRequest)
        {
            PlayerCommandResult commandResult = ExecutePlayerCommand(orderRequest.CommandRequest);
            return commandResult.Succeeded
                ? PlayerOrderResult.Success(orderRequest, 1, commandResult)
                : PlayerOrderResult.Failed(orderRequest, 1, commandResult);
        }

        public PlayerCommandResult ExecutePlayerCommand(PlayerCommandRequest request)
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
                return PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.ActorMismatch);
            }

            if (!m_acceptsPlayerInput || !m_character.CanBePlayerControlled())
            {
                return PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.ControlLocked);
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

        public EPlayerMovementControlMode GetMovementControlMode()
        {
            CharacterMovement movement = ResolveMovement();
            return movement != null ? movement.MovementControlMode : EPlayerMovementControlMode.Directional;
        }

        public void SetMovementControlMode(EPlayerMovementControlMode mode)
        {
            ResolveMovement()?.SetMovementControlMode(mode);
        }

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

        private void Awake()
        {
            EnsureCharacterReference();
            ResolveButtonActivation();
            ResolveMovement();
        }

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
                ResolveButtonActivation()?.ResetState();
                m_character.ResetTargetDirection();
                return;
            }

            ResolveButtonActivation()?.RefreshCurrentTarget();
            if (ResolveMovement() == null || !m_movement.TryUpdatePointerTargetDirection())
            {
                m_character.ResetTargetDirection();
            }
        }

        private void OnDisable()
        {
            if (m_character)
            {
                m_character.ResetTargetDirection();
                m_character.ResetMovement();
            }

            ResolveButtonActivation()?.ResetState();
        }

        private void Reset()
        {
            EnsureCharacterReference();
        }

        private void OnValidate()
        {
            EnsureCharacterReference();
        }

        private void EnsureCharacterReference()
        {
            if (m_character == null)
            {
                TryGetComponent(out m_character);
            }
        }

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

        private PlayerCommandResult ExecuteOpenGameMenuCommand(PlayerCommandRequest request)
        {
            if (!m_character.Can(EActionFlags.Interact))
            {
                return PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.BlockedByState);
            }

            GameRuntimeEvents.RequestMenu(EMenu.Pause);
            return PlayerCommandResult.Success(request);
        }

        private PlayerCommandResult ExecuteMoveCommand(PlayerCommandRequest request)
        {
            CharacterMovement movement = ResolveMovement();
            return movement != null && movement.HandleDirectionalMove(request.Direction)
                ? PlayerCommandResult.Success(request)
                : PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.BlockedByState);
        }

        private PlayerCommandResult ExecuteStopMoveCommand(PlayerCommandRequest request)
        {
            CharacterMovement movement = ResolveMovement();
            return movement != null && movement.StopMovement()
                ? PlayerCommandResult.Success(request)
                : PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.BlockedByState);
        }

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

        private PlayerCommandResult ExecuteToggleMovementControlModeCommand(PlayerCommandRequest request)
        {
            CharacterMovement movement = ResolveMovement();
            return movement != null && movement.ToggleMovementControlMode()
                ? PlayerCommandResult.Success(request)
                : PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.BlockedByState);
        }

        private PlayerCommandResult ExecuteFireAbilityCommand(PlayerCommandRequest request)
        {
            if (ResolveButtonActivation()?.HasInteractedThisFrame() == true)
            {
                return PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.BlockedByState);
            }

            CharacterAbilityFireResult fireResult = m_character.FireEquippedAbilityAtIndex(
                request.AbilityIndex,
                request.CommandContext);

            if (fireResult.HasAbilitySource)
            {
                if (fireResult.Result != EAbilityFireCheckResult.Valid)
                {
                    GameRuntimeEvents.NotifyPlayerAbilityFireFailed(fireResult.FormalGasAbilityCode, fireResult.Result);
                    return PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.AbilityRejected);
                }

                return PlayerCommandResult.Success(request);
            }

            return PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.MissingAbility);
        }

        private PlayerCommandResult ExecuteStopFireAbilityCommand(PlayerCommandRequest request)
        {
            return m_character.StopFireEquippedAbilityAtIndex(request.AbilityIndex)
                ? PlayerCommandResult.Success(request)
                : PlayerCommandResult.Failed(request, EPlayerCommandFailureReason.MissingAbility);
        }

        private CharacterButtonActivation ResolveButtonActivation()
        {
            if (m_buttonActivation == null && m_character != null)
            {
                m_character.TryGetComponent(out m_buttonActivation);
            }

            return m_buttonActivation;
        }

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
