namespace FantasyWord.GameCore
{
    public enum EInventoryMenuMode
    {
        UseOwnerItems,
        TransferToDestination
    }

    public readonly struct InventoryMenuContext
    {
        private InventoryMenuContext(
            GameCommandContext commandContext,
            InventoryOwnerHandle displayOwner,
            InventoryOwnerHandle destinationOwner,
            EInventoryMenuMode mode,
            EItemTransferType transferType)
        {
            CommandContext = commandContext;
            DisplayOwner = displayOwner;
            DestinationOwner = destinationOwner;
            Mode = mode;
            TransferType = transferType;
        }

        public GameCommandContext CommandContext { get; }
        public CharacterBase Actor => CommandContext.Actor;
        public InventoryOwnerHandle DisplayOwner { get; }
        public InventoryOwnerHandle DestinationOwner { get; }
        public EInventoryMenuMode Mode { get; }
        public EItemTransferType TransferType { get; }

        public static InventoryMenuContext CurrentControlledCharacter()
        {
            return new InventoryMenuContext(
                GameCommandContext.Unknown(),
                default,
                default,
                EInventoryMenuMode.UseOwnerItems,
                EItemTransferType.Use);
        }

        public static InventoryMenuContext ViewCharacter(CharacterBase actor)
        {
            if (actor == null)
            {
                return CurrentControlledCharacter();
            }

            InventoryOwnerHandle owner = ResolveInventoryOwner(actor);
            return new InventoryMenuContext(
                ResolveCommandContextForActor(actor),
                owner,
                owner,
                EInventoryMenuMode.UseOwnerItems,
                EItemTransferType.Use);
        }

        public static InventoryMenuContext TransferToCharacter(
            CharacterBase destination,
            InventoryOwnerHandle sourceOwner,
            EItemTransferType transferType)
        {
            return TransferToCharacter(
                ResolveCommandContextForActor(destination),
                destination,
                sourceOwner,
                transferType);
        }

        public static InventoryMenuContext TransferToCharacter(
            GameCommandContext commandContext,
            CharacterBase destination,
            InventoryOwnerHandle sourceOwner,
            EItemTransferType transferType)
        {
            InventoryOwnerHandle destinationOwner = GameManager.InventorySystem.GetOwner(destination);
            return new InventoryMenuContext(
                commandContext,
                sourceOwner,
                destinationOwner,
                EInventoryMenuMode.TransferToDestination,
                transferType);
        }

        public bool FollowsCurrentControlledCharacter =>
            Actor == null && !DisplayOwner.IsValid && !DestinationOwner.IsValid;

        public CharacterBase ResolveActor()
        {
            return Actor ? Actor : GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
        }

        public InventoryOwnerHandle ResolveDisplayOwner()
        {
            if (DisplayOwner.IsValid)
            {
                return DisplayOwner;
            }

            return ResolveInventoryOwner(ResolveActor());
        }

        public InventoryOwnerHandle ResolveDestinationOwner()
        {
            if (DestinationOwner.IsValid)
            {
                return DestinationOwner;
            }

            return ResolveInventoryOwner(ResolveActor());
        }

        public InventoryTransferRequest CreateTransferRequest(Item item, int quantity)
        {
            return new InventoryTransferRequest(
                ResolveCommandContext(),
                ResolveDisplayOwner(),
                ResolveDestinationOwner(),
                item,
                quantity,
                TransferType);
        }

        private GameCommandContext ResolveCommandContext()
        {
            if (CommandContext.HasActor || CommandContext.IssuerKind != EGameCommandIssuerKind.Unknown)
            {
                return CommandContext;
            }

            return ResolveCommandContextForActor(ResolveActor());
        }

        private static GameCommandContext ResolveCommandContextForActor(CharacterBase actor)
        {
            return GameCommandContext.ResolveForActor(actor);
        }

        private static InventoryOwnerHandle ResolveInventoryOwner(CharacterBase actor)
        {
            if (actor == null)
            {
                return default;
            }

            return GameManager.InventorySystem.GetOwner(actor);
        }
    }
}
