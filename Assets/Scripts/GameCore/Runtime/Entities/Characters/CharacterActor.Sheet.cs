using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.Serialization;

namespace FantasyWord.GameCore
{
    public partial class CharacterActor
    {
        [FormerlySerializedAs("m_characterSheet")]
        [SerializeField]
        [LabelText("角色配置表")]
        [Tooltip("角色等级成长、基础属性、经验曲线和初始能力来源。保留旧字段名兼容，避免已保存 Prefab 丢引用。")]
        private CharacterSheet m_sheet = null;

        /// <summary>角色配置表正式入口。</summary>
        public override CharacterSheet characterSheet => m_sheet;

        /// <summary>兼容旧调用点的配置表入口。</summary>
        public CharacterSheet sheet => m_sheet;
    }
}
