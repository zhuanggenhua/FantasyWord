using System.Threading.Tasks;
using UnityEngine;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Utils + nameof(CommandHandler))]
    public class CommandHandler : DatabaseEntry
    {
        [SerializeReference, SubclassSelector]
        private ICommand m_command = null;

        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            return m_command.Execute(context);
        }
    }
}

