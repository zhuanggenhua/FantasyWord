using System.Threading.Tasks;

namespace FantasyWord.GameCore
{
    public interface ICommand
    {
        public Task Execute();
    }

    public interface IContextualCommand : ICommand
    {
        public Task Execute(GameCommandContext context);
    }

    public static class CommandExecutionExtensions
    {
        public static Task Execute(this ICommand command, GameCommandContext context)
        {
            if (command == null)
            {
                return Task.CompletedTask;
            }

            return command is IContextualCommand contextualCommand
                ? contextualCommand.Execute(context)
                : command.Execute();
        }
    }
}
