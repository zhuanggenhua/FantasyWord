namespace FantasyWord.GameCore
{
    public enum EEffectInterruptionPolicy
    {
        AfterFail,
        AfterSuccess,
        Never
    }

    public struct EffectDescription
    {
        public string name;
        public string details;
    }

    public interface IEffect
    {
        public bool initialized { get; }
        public EEffectInterruptionPolicy interruptionPolicy { get; }
        public EEffectVisualFlags visualFlags { get; }

        public void Init(CharacterBase source);
        public bool IsApplicable(CharacterBase target);
        public bool Apply(CharacterBase target, EffectImpactSettings? impactSettings = null);
        public void Deinit();

        public EffectDescription GenerateDescription();
    }
}

