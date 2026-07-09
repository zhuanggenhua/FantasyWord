using UnityEngine;

namespace FantasyWord.GameCore
{
    [System.Flags]
    public enum EOptionalCharacterStatistics
    {
        None = 0,
        Mana = 1 << 0,
        MagicalAttack = 1 << 1,
        MagicalDefense = 1 << 2,
        Agility = 1 << 3,
        Luck = 1 << 4,
    }

    [System.Flags]
    public enum ECameraShakeSources
    {
        None = 0,
        PlayerReceiveDamage = 1 << 0,
        AnyCharacterReceiveDamageFromPlayer = 1 << 1
    }

    public enum EGameTerm
    {
        Currency,
        Level,
        Experience
    }

    [System.Serializable]
    public struct StatSettings
    {
        public string name;
        public string shortened;
        public string description;
        public Sprite icon;
        public bool hide;
    }

    [System.Serializable]
    public struct TermDefinition
    {
        public string fullName;
        public string shortName;
        public string description;
        public Sprite icon;
    }
}
