using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using azixMcAze.SerializableDictionary;

namespace FantasyWord.GameCore
{
    public abstract class CharacterSheet : DatabaseEntry, INameable
    {
        [Header("General")]
        [SerializeField] private EAlignment m_alignment = EAlignment.Default;
        [SerializeField] private string m_displayName = string.Empty;
        [SerializeField] private SerializableDictionary<int, int> m_formalGasAbilitiesPerLevel;

        [Header("Audio")]
        [SerializeField] private AudioClipResolver m_hitAudio;
        [SerializeField] private AudioClipResolver m_deathAudio;

        [Header("Feedbacks")]
        [SerializeField]
        [Tooltip("角色受击、死亡和奖励发放的表现反馈。只承接表现触发点，不改变 RPG 属性、掉落或存档真相。")]
        private GameplayFeedbackSet m_feedbacks = new();

        public EAlignment alignment => m_alignment;
        public string displayName => DisplayNameUtils.GetNameOrDefault(this, m_displayName);
        public AudioClipResolver hitAudio => m_hitAudio;
        public AudioClipResolver deathAudio => m_deathAudio;
        public GameplayFeedbackSet feedbacks
        {
            get
            {
                m_feedbacks ??= new GameplayFeedbackSet();
                return m_feedbacks;
            }
        }

        public CharacterSheet(EAlignment alignment)
        {
            m_alignment = alignment;
        }

        public int[] GetAvailableFormalGasAbilitiesAtLevel(int level)
        {
            return CreateDistinctFormalGasAbilityCodes(
                m_formalGasAbilitiesPerLevel != null
                    ? m_formalGasAbilitiesPerLevel
                    .Where(keyValuePair => keyValuePair.Key > 0 && keyValuePair.Value <= level)
                    .Select(keyValuePair => keyValuePair.Key)
                    : System.Array.Empty<int>());
        }

        public int[] GetFormalGasAbilitiesUnlockedAtLevel(int level)
        {
            return CreateDistinctFormalGasAbilityCodes(
                m_formalGasAbilitiesPerLevel != null
                    ? m_formalGasAbilitiesPerLevel
                    .Where(keyValuePair => keyValuePair.Key > 0 && keyValuePair.Value == level)
                    .Select(keyValuePair => keyValuePair.Key)
                    : System.Array.Empty<int>());
        }

        private static int[] CreateDistinctFormalGasAbilityCodes(params IEnumerable<int>[] sources)
        {
            List<int> result = new();
            foreach (IEnumerable<int> source in sources)
            {
                if (source == null)
                {
                    continue;
                }

                foreach (int formalGasAbilityCode in source)
                {
                    if (formalGasAbilityCode > 0 && !result.Contains(formalGasAbilityCode))
                    {
                        result.Add(formalGasAbilityCode);
                    }
                }
            }

            return result.ToArray();
        }
    }
}

