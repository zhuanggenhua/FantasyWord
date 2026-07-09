using UnityEngine;

namespace FantasyWord.GameCore
{
    public enum EPlayerCommandKind
    {
        Interact,
        OpenGameMenu,
        Move,
        StopMove,
        ClickMove,
        ToggleMovementControlMode,
        FireAbility,
        StopFireAbility
    }

    public enum EPlayerCommandFailureReason
    {
        None,
        InvalidCommand,
        MissingInputTarget,
        InvalidControlledCharacter,
        InvalidTarget,
        ActorMismatch,
        NotRunning,
        ControlLocked,
        InteractionLocked,
        BlockedByState,
        MissingAbility,
        AbilityRejected
    }

    public readonly struct PlayerCommandRequest
    {
        public PlayerCommandRequest(
            GameCommandContext commandContext,
            EPlayerCommandKind kind,
            Vector2 direction = default,
            Vector2? worldPosition = null,
            int abilityIndex = -1,
            CharacterBase targetCharacter = null,
            GameObject interactionTarget = null)
        {
            CommandContext = commandContext;
            Kind = kind;
            Direction = direction;
            WorldPosition = worldPosition;
            AbilityIndex = abilityIndex;
            TargetCharacter = targetCharacter;
            InteractionTarget = interactionTarget;
        }

        public GameCommandContext CommandContext { get; }
        public CharacterBase Actor => CommandContext.Actor;
        public EPlayerCommandKind Kind { get; }
        public Vector2 Direction { get; }
        public bool HasWorldPosition => WorldPosition.HasValue;
        public Vector2? WorldPosition { get; }
        public int AbilityIndex { get; }
        public CharacterBase TargetCharacter { get; }
        public GameObject InteractionTarget { get; }
    }

    public readonly struct PlayerCommandResult
    {
        private PlayerCommandResult(
            PlayerCommandRequest request,
            bool succeeded,
            EPlayerCommandFailureReason failureReason)
        {
            Request = request;
            Succeeded = succeeded;
            FailureReason = failureReason;
        }

        public PlayerCommandRequest Request { get; }
        public bool Succeeded { get; }
        public EPlayerCommandFailureReason FailureReason { get; }

        public static PlayerCommandResult Success(PlayerCommandRequest request)
        {
            return new PlayerCommandResult(request, true, EPlayerCommandFailureReason.None);
        }

        public static PlayerCommandResult Failed(
            PlayerCommandRequest request,
            EPlayerCommandFailureReason failureReason)
        {
            return new PlayerCommandResult(request, false, failureReason);
        }
    }
}
