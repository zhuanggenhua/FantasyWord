using System.Collections.Generic;
using UnityEngine;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Characters + nameof(MonsterSheet))]
    public class MonsterSheet : CharacterSheet
    {
        [Header("Monster")]
        [SerializeField] private LevelScaledStats m_stats = new();

        [Header("Rewards")]
        [SerializeField] private LevelScaledInteger m_experience = new();
        [SerializeField] private LevelScaledInteger m_money = new();
        [SerializeField] private Loot[] m_potentialLoot;

        [Header("Commands")]
        [SerializeReference, SubclassSelector] private ICommand m_executeOnDeath;

        public int potentialLootCount => m_potentialLoot?.Length ?? 0;
        public Loot[] GetPotentialLoot() => m_potentialLoot != null ? (Loot[])m_potentialLoot.Clone() : System.Array.Empty<Loot>();
        public Stats GetStatsAtLevel(int level) => ((m_stats ??= new LevelScaledStats())[level])?.Clone() ?? new Stats();
        public int GetExperienceRewardAtLevel(int level) => (m_experience ??= new LevelScaledInteger())[level];
        public int GetMoneyRewardAtLevel(int level) => (m_money ??= new LevelScaledInteger())[level];
        public void ExecuteOnDeath(GameCommandContext context) => m_executeOnDeath.Execute(context);

        public MonsterSheet() : base(EAlignment.Evil) { }
    }
}
