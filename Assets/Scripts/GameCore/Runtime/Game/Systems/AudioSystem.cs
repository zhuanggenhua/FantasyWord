using System.Collections.Generic;
using System;
using UnityEngine;
using YokiFrame;
using azixMcAze.SerializableDictionary;

namespace FantasyWord.GameCore
{
    public enum EAudioChannel
    {
        BackgroundMusic,
        BackgroundSound,
        InterfaceSoundFX,
        GameplaySoundFX,
        Miscellaneous
    }

    public class AudioSystem : AGameSystem
    {
        [SerializeField] private SerializableDictionary<EAudioChannel, AudioChannel> m_audioChannels;

        const string kVolumePlayerPrefsKey = "M2D_AudioSystem_Volume_";
        const string kChannelVolumePlayerPrefsKey = kVolumePlayerPrefsKey + "Channel_";
        const string kMasterVolumePlayerPrefsKey = kVolumePlayerPrefsKey + "Master";

        private float m_masterVolume = Constants.DefaultMasterVolume;

        public override void OnSystemStart()
        {
            LoadSettings();
            EventKit.Type.Register<AudioPlaybackRequestedEvent>(DispatchAudioPlaybackRequest);
        }

        public override void OnSystemStop()
        {
            EventKit.Type.UnRegister<AudioPlaybackRequestedEvent>(DispatchAudioPlaybackRequest);
            SaveSettings();
        }

        public void SetMasterVolume(float volume)
        {
            m_masterVolume = volume;
            AudioListener.volume = volume;
        }

        public float GetMasterVolume() => m_masterVolume;

        private void LoadSettings()
        {
            SetMasterVolume(PlayerPrefs.GetFloat(kMasterVolumePlayerPrefsKey, m_masterVolume));

            foreach (KeyValuePair<EAudioChannel, AudioChannel> channel in m_audioChannels)
            {
                channel.Value.SetVolumeScale(PlayerPrefs.GetFloat($"{kChannelVolumePlayerPrefsKey}{channel.Key}", channel.Value.GetVolumeScale()));
            }
        }

        private void SaveSettings()
        {
            PlayerPrefs.SetFloat(kMasterVolumePlayerPrefsKey, m_masterVolume);

            foreach (KeyValuePair<EAudioChannel, AudioChannel> channel in m_audioChannels)
            {
                PlayerPrefs.SetFloat($"{kChannelVolumePlayerPrefsKey}{channel.Key}", channel.Value.GetVolumeScale());
            }

            PlayerPrefs.Save();
        }

        private void DispatchAudioPlaybackRequest(AudioPlaybackRequestedEvent audioPlaybackRequestedEvent)
        {
            Play(audioPlaybackRequestedEvent.AudioClipResolver);
        }

        public void Play(AudioClipResolver audioClipResolver, Action onCompleted = null)
        {
            if (TryGetChannel(audioClipResolver, out AudioChannel channel))
            {
                channel.Play(audioClipResolver, onCompleted);
            }
        }

        public void PlayAt(AudioClipResolver audioClipResolver, Vector3 position, Action onCompleted = null)
        {
            if (TryGetChannel(audioClipResolver, out AudioChannel channel))
            {
                channel.PlayAt(audioClipResolver, position, onCompleted);
            }
        }

        public void PlayAttached(AudioClipResolver audioClipResolver, Transform target, Action onCompleted = null)
        {
            if (TryGetChannel(audioClipResolver, out AudioChannel channel))
            {
                channel.PlayAttached(audioClipResolver, target, onCompleted);
            }
        }

        public AudioClipResolver GetLastPlayedAudioClipResolver(EAudioChannel channel)
        {
            if (m_audioChannels.TryGetValue(channel, out AudioChannel channelInstance))
            {
                return channelInstance.GetLastPlayedAudioClipResolver();
            }

            return null;
        }

        public void SetChannelVolumeScale(EAudioChannel channel, float volume)
        {
            if (m_audioChannels.TryGetValue(channel, out AudioChannel channelInstance))
            {
                channelInstance.SetVolumeScale(volume);
            }
        }

        public float GetChannelVolumeScale(EAudioChannel channel)
        {
            if (m_audioChannels.TryGetValue(channel, out AudioChannel channelInstance))
            {
                return channelInstance.GetVolumeScale();
            }

            return 0.0f;
        }

        public void StopChannel(EAudioChannel channel)
        {
            if (m_audioChannels.TryGetValue(channel, out AudioChannel channelInstance))
            {
                channelInstance.Stop();
            }
        }

        public void PauseChannel(EAudioChannel channel)
        {
            if (m_audioChannels.TryGetValue(channel, out AudioChannel channelInstance))
            {
                channelInstance.Pause();
            }
        }

        public void ResumeChannel(EAudioChannel channel)
        {
            if (m_audioChannels.TryGetValue(channel, out AudioChannel channelInstance))
            {
                channelInstance.Resume();
            }
        }

        private bool TryGetChannel(AudioClipResolver audioClipResolver, out AudioChannel channel)
        {
            channel = null;
            return audioClipResolver && m_audioChannels.TryGetValue(audioClipResolver.targetChannel, out channel);
        }
    }
}


