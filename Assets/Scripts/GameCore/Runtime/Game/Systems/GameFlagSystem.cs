using System;
using System.Collections.Generic;
using System.Linq;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class GameFlagsDataBlock : DataBlock
    {
        public string[] flags;
    }

    public class GameFlagSystem : AGameSystem, IDataBlockHandler<GameFlagsDataBlock>
    {
        private HashSet<string> m_flags = new();

        public bool Get(string variableName)
        {
            return m_flags.Contains(variableName);
        }

        public void Set(string variableName, bool value)
        {
            if (value)
            {
                m_flags.Add(variableName);
            }
            else
            {
                m_flags.Remove(variableName);
            }

            GameRuntimeEvents.NotifyGameFlagChanged(variableName, value);
        }

        public void LoadDataBlock(GameFlagsDataBlock block)
        {
            m_flags = block.flags.ToHashSet();
        }

        public GameFlagsDataBlock CreateDataBlock()
        {
            return new GameFlagsDataBlock
            {
                flags = m_flags.ToArray(),
            };
        }
    }
}

