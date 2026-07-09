using UnityEngine;
using UnityEngine.Serialization;

namespace FantasyWord.GameCore
{
    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Characters + nameof(HeroSheet))]
    public class HeroSheet : CharacterSheet
    {
        [Header("Hero")]
        [SerializeField, FormerlySerializedAs("baseStats")]
        private Stats m_baseStats = new();

        [SerializeField, FormerlySerializedAs("pointsPerLevel")]
        private int m_pointsPerLevel = 5;

        [SerializeField, FormerlySerializedAs("experience")]
        private LevelScaledInteger m_experience = new();

        public Stats baseStats => m_baseStats?.Clone() ?? new Stats();
        public int pointsPerLevel => m_pointsPerLevel;
        public int GetExperienceRequiredAtLevel(int level) => (m_experience ??= new LevelScaledInteger())[level];

        public HeroSheet() : base(EAlignment.Good) { }
    }
}
