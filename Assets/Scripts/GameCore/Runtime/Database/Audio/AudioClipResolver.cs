using Ami.BroAudio;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public enum EAudioClipResolvingAlgorithm
    {
        First,
        Random,
        Loop,
        PingPong
    }

    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Audio + nameof(AudioClipResolver))]
    public class AudioClipResolver : DatabaseEntry
    {
        [SerializeField] private AudioClip[] m_audioClips = null;
        [SerializeField] private SoundID m_soundId;
        [SerializeField] private EAudioChannel m_targetChannel;
        [SerializeField] private EAudioClipResolvingAlgorithm m_resolvingAlgorithm;

        private int m_currentIndex = 0;
        private int m_increment = 1;

        public EAudioChannel targetChannel => m_targetChannel;
        public SoundID soundId => m_soundId;

        public bool TryGetSoundId(out SoundID soundId)
        {
            soundId = m_soundId;
            return soundId.IsValid();
        }

        public AudioClip GetClip()
        {
            if (HasClips())
            {
                switch (m_resolvingAlgorithm)
                {
                    case EAudioClipResolvingAlgorithm.First: return GetClipFirst();
                    case EAudioClipResolvingAlgorithm.Random: return GetClipRandom();
                    case EAudioClipResolvingAlgorithm.Loop: return GetClipLoop();
                    case EAudioClipResolvingAlgorithm.PingPong: return GetClipPingPong();
                }
            }

            return null;
        }

        private bool HasClips() => m_audioClips != null && m_audioClips.Length > 0;

        private AudioClip GetClipFirst()
        {
            return m_audioClips[0];
        }

        private AudioClip GetClipRandom()
        {
            return m_audioClips[Random.Range(0, m_audioClips.Length)];
        }

        private AudioClip GetClipLoop()
        {
            AudioClip output = m_audioClips[m_currentIndex];

            ++m_currentIndex;

            if (m_currentIndex == m_audioClips.Length)
            {
                m_currentIndex = 0;
            }

            return output;
        }

        private AudioClip GetClipPingPong()
        {
            AudioClip output = m_audioClips[m_currentIndex];

            m_currentIndex += m_increment;

            if (m_currentIndex == m_audioClips.Length)
            {
                m_currentIndex -= m_increment;
                m_increment *= -1;
            }

            return output;
        }
    }
}


