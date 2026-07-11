using System;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class MovePlayer : MoveCharacterBase
    {
        protected override CharacterBase targetCharacter => GameManager.PlayerSystem.GetPrimaryPlayerCharacter();

        protected override CharacterBase ResolveTargetCharacter(GameCommandContext context)
        {
            return context.ResolveActorOrCurrentControlledCharacter();
        }
    }
}

