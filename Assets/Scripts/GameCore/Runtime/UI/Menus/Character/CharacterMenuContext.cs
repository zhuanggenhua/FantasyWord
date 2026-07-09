namespace FantasyWord.GameCore
{
    public readonly struct CharacterMenuContext
    {
        private CharacterMenuContext(CharacterBase actor)
        {
            Actor = actor;
        }

        public CharacterBase Actor { get; }
        public bool FollowsCurrentControlledCharacter => Actor == null;

        public static CharacterMenuContext CurrentControlledCharacter()
        {
            return new CharacterMenuContext(null);
        }

        public static CharacterMenuContext ViewCharacter(CharacterBase actor)
        {
            return actor == null
                ? CurrentControlledCharacter()
                : new CharacterMenuContext(actor);
        }

        public CharacterBase ResolveActor()
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
