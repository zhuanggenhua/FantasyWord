using System;
using System.Diagnostics;

namespace FantasyWord.GameCore
{
    public abstract class ABaseCondition : ICondition
    {
        public abstract bool Evaluate();

        public virtual void StartListening(Action onStateChanged)
        {
            m_stateChangedCallback = onStateChanged;
            OnStartListening();
        }

        public virtual void StopListening()
        {
            Debug.Assert(m_stateChangedCallback != null, "Trying to stop listening when no callback is set.");
            m_stateChangedCallback = null;
            OnStopListening();
        }

        protected void NotifyStateChange()
        {
            m_stateChangedCallback();
        }

        protected virtual void OnStartListening() { }
        protected virtual void OnStopListening() { }

        private Action m_stateChangedCallback = null;
    }
}

