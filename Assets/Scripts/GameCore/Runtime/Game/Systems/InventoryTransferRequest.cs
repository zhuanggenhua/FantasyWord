namespace FantasyWord.GameCore
{
    public enum EInventoryTransferFailureReason
    {
        None,
        InvalidItem,
        InvalidQuantity,
        InvalidSourceOwner,
        InvalidDestinationOwner,
        ActorNotParticipant,
        ActorActionLocked,
        InsufficientQuantity
    }

    public readonly struct InventoryTransferRequest
    {
        public InventoryTransferRequest(
            CharacterBase actor,
            InventoryOwnerHandle sourceOwner,
            InventoryOwnerHandle destinationOwner,
            Item item,
            int quantity,
            EItemTransferType transferType)
            : this(
                GameCommandContext.Unknown(actor),
                sourceOwner,
                destinationOwner,
                item,
                quantity,
                transferType)
        {
        }

        public InventoryTransferRequest(
            GameCommandContext commandContext,
            InventoryOwnerHandle sourceOwner,
            InventoryOwnerHandle destinationOwner,
            Item item,
            int quantity,
            EItemTransferType transferType)
        {
            CommandContext = commandContext;
            SourceOwner = sourceOwner;
            DestinationOwner = destinationOwner;
            Item = item;
            Quantity = quantity;
            TransferType = transferType;
        }

        public GameCommandContext CommandContext { get; }
        public CharacterBase Actor => CommandContext.Actor;
        public InventoryOwnerHandle SourceOwner { get; }
        public InventoryOwnerHandle DestinationOwner { get; }
        public Item Item { get; }
        public int Quantity { get; }
        public EItemTransferType TransferType { get; }
    }

    public readonly struct InventoryTransferResult
    {
        private InventoryTransferResult(
            InventoryTransferRequest request,
            bool succeeded,
            int transferredQuantity,
            EInventoryTransferFailureReason failureReason)
        {
            Request = request;
            Succeeded = succeeded;
            TransferredQuantity = transferredQuantity;
            FailureReason = failureReason;
        }

        public InventoryTransferRequest Request { get; }
        public bool Succeeded { get; }
        public int TransferredQuantity { get; }
        public EInventoryTransferFailureReason FailureReason { get; }

        public static InventoryTransferResult Success(InventoryTransferRequest request, int transferredQuantity)
        {
            return new InventoryTransferResult(
                request,
                true,
                transferredQuantity,
                EInventoryTransferFailureReason.None);
        }

        public static InventoryTransferResult Failed(
            InventoryTransferRequest request,
            EInventoryTransferFailureReason failureReason)
        {
            return new InventoryTransferResult(request, false, 0, failureReason);
        }
    }
}
