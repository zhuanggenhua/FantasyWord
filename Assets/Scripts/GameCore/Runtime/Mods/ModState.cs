using System;

namespace FantasyWord.GameCore
{
    public enum ModStatus
    {
        Enabled,
        Disabled,
        Delete
    }

    [Serializable]
    public class ModState
    {
        public string fullName;
        public ModStatus status;
    }
}
