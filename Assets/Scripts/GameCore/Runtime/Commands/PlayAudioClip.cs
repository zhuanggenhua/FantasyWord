using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class PlayAudioClip : IContextualCommand
    {
        [SerializeField] private AudioClipResolver m_audioClip = null;

        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            GameRuntimeEvents.RequestAudioPlayback(m_audioClip);
            return Task.CompletedTask;
        }
    }
}

