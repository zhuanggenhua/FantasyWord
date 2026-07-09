using UnityEngine;
using UnityEngine.Serialization;

namespace FantasyWord.GameCore
{
    public abstract class Character<CharacterSheetDerivation> : CharacterBase where CharacterSheetDerivation : CharacterSheet
    {
        [Header("Character Settings")]
        [FormerlySerializedAs("m_characterSheet")]
        [SerializeField] protected CharacterSheetDerivation m_sheet = null;

        public override CharacterSheet characterSheet => m_sheet;
    }
}
