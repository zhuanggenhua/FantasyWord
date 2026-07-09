namespace FantasyWord.GameCore
{
    public enum EGameCommandIssuerKind
    {
        Unknown,
        LocalPlayer,
        AI,
        Script,
        RemotePlayer
    }

    public readonly struct GameCommandContext
    {
        private GameCommandContext(EGameCommandIssuerKind issuerKind, string issuerId, CharacterBase actor)
        {
            IssuerKind = issuerKind;
            IssuerId = string.IsNullOrWhiteSpace(issuerId) ? string.Empty : issuerId;
            Actor = actor;
        }

        public EGameCommandIssuerKind IssuerKind { get; }
        public string IssuerId { get; }
        public CharacterBase Actor { get; }
        public bool HasActor => Actor != null;
        public bool IsLocalPlayer => IssuerKind == EGameCommandIssuerKind.LocalPlayer;

        public static GameCommandContext Unknown(CharacterBase actor = null)
        {
            return new GameCommandContext(EGameCommandIssuerKind.Unknown, string.Empty, actor);
        }

        public static GameCommandContext LocalPlayer(CharacterBase actor)
        {
            return new GameCommandContext(EGameCommandIssuerKind.LocalPlayer, "local", actor);
        }

        public static GameCommandContext AI(CharacterBase actor)
        {
            return new GameCommandContext(EGameCommandIssuerKind.AI, "ai", actor);
        }

        public static GameCommandContext Script(CharacterBase actor = null, string issuerId = null)
        {
            return new GameCommandContext(EGameCommandIssuerKind.Script, issuerId, actor);
        }

        public static GameCommandContext RemotePlayer(CharacterBase actor, string issuerId)
        {
            return new GameCommandContext(EGameCommandIssuerKind.RemotePlayer, issuerId, actor);
        }

        public static GameCommandContext Recreate(EGameCommandIssuerKind issuerKind, CharacterBase actor = null, string issuerId = null)
        {
            return issuerKind switch
            {
                EGameCommandIssuerKind.LocalPlayer => LocalPlayer(actor),
                EGameCommandIssuerKind.AI => AI(actor),
                EGameCommandIssuerKind.RemotePlayer => RemotePlayer(actor, issuerId),
                EGameCommandIssuerKind.Script => Script(actor, issuerId),
                EGameCommandIssuerKind.Unknown => Unknown(actor),
                _ => Script(actor, issuerId)
            };
        }

        public static GameCommandContext ResolveForActor(CharacterBase actor)
        {
            if (actor == null)
            {
                return Unknown();
            }

            if (GameManager.Exists() &&
                GameManager.HasSystem<PlayerSystem>() &&
                GameManager.PlayerSystem.IsCurrentControlledMember(actor))
            {
                return LocalPlayer(actor);
            }

            if (actor.IsControllerActive<AIController>())
            {
                return AI(actor);
            }

            return Unknown(actor);
        }

        public CharacterBase ResolveActorOrCurrentControlledCharacter()
        {
            if (Actor != null)
            {
                return Actor;
            }

            return GameManager.Exists() && GameManager.HasSystem<PlayerSystem>()
                ? GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance()
                : null;
        }

    }
}
