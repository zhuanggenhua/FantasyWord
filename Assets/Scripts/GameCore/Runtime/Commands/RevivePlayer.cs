using System;
using System.Threading.Tasks;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class RevivePlayer : IContextualCommand
    {
        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            CharacterBase target = context.ResolveActorOrCurrentControlledCharacter();

            target?.Revive();
            return Task.CompletedTask;
        }
    }
}

