using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.U2D.Animation;

namespace FantasyWord.GameCore
{
    public enum EEquipmentType
    {
        Weapon,
        Head,
        Torso,
        Hands,
        Feet
    }

    public enum EOperationType
    {
        Equip,
        Unequip
    }

    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Items + nameof(Equipment))]
    public class Equipment : Item
    {
        [Header("Equipment")]
        [SerializeField] private EEquipmentType m_type;
        [SerializeField] private Stats m_bonusStats;
        [SerializeField] private SpriteLibraryAsset m_visualOverride;
        [SerializeField] private int[] m_formalGasAbilityCodes;

        public EEquipmentType type => m_type;
        public SpriteLibraryAsset visualOverride => m_visualOverride;
        public int bonusAbilityCount => GetBonusFormalGasAbilityCodes().Length;

        /// <summary>
        /// 只有需要整份加成快照做聚合运算时才复制整组属性。
        /// 简单 UI 或单值查询优先走标量入口，避免把整份 Stats 真相借出去。
        /// </summary>
        public Stats CreateBonusStatsSnapshot() => m_bonusStats?.Clone() ?? new Stats();

        public int GetBonusStatValue(EStat stat) => m_bonusStats != null ? m_bonusStats[stat] : 0;

        public int GetBonusStatValue(FormalAttributeDefinition definition) => GetBonusStatValue(definition.Stat);

        public int[] GetBonusFormalGasAbilityCodes()
        {
            HashSet<int> codes = new();
            if (m_formalGasAbilityCodes != null)
            {
                foreach (int code in m_formalGasAbilityCodes)
                {
                    if (code > 0)
                    {
                        codes.Add(code);
                    }
                }
            }

            return codes.ToArray();
        }

    }
}
