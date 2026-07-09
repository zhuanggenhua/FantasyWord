using UnityEngine;

namespace FantasyWord.GameCore
{
    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Characters + nameof(NPCSheet))]
    public class NPCSheet : CharacterSheet
    {
        public NPCSheet() : base(EAlignment.Neutral) { }
    }
}

