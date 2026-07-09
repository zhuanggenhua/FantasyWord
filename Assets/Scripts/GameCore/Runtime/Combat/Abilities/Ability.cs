namespace FantasyWord.GameCore
{
    public abstract class Ability : AbilityBase
    {
        protected override void InitFormalGasAbilityCore()
        {
            InitRuntime(m_character);
            ConfigureFormalGasContext(formalGasAbilityCode);
        }
    }
}

