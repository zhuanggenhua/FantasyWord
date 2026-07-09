using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class MoveCharacter : MoveCharacterBase
    {
        [SerializeField] private CharacterBase m_toMove = null;

        protected override CharacterBase targetCharacter => m_toMove;
    }
}

