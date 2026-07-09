namespace FantasyWord.GameCore
{
    public readonly struct FormalGasAbilityIdentity
    {
        public FormalGasAbilityIdentity(string displayName, string description)
        {
            DisplayName = displayName ?? string.Empty;
            Description = description ?? string.Empty;
        }

        public string DisplayName { get; }
        public string Description { get; }
    }

    public static class FormalGasAbilityIdentityResolver
    {
        public delegate bool TryResolveAbilityIdentityHandler(
            int abilityCode,
            out FormalGasAbilityIdentity identity);

        private static TryResolveAbilityIdentityHandler s_handler;

        public static void RegisterTryResolveAbilityIdentityHandler(TryResolveAbilityIdentityHandler handler)
        {
            s_handler = handler;
        }

        public static bool TryResolveAbilityIdentity(
            int abilityCode,
            out FormalGasAbilityIdentity identity)
        {
            if (abilityCode <= 0 || s_handler == null)
            {
                identity = default;
                return false;
            }

            return s_handler(abilityCode, out identity);
        }
    }
}
