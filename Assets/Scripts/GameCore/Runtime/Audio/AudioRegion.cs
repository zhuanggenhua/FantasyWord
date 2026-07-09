using UnityEngine;

namespace FantasyWord.GameCore
{
    public class AudioRegion : MonoBehaviour
    {
        [Header("Settings")]
        [SerializeField] protected AudioClipResolver m_audioClipResolver = null;

        private AudioClipResolver m_previousAudio = null;

        public bool IsPlayer(Collider2D collision)
        {
            CharacterBase currentControlledCharacter = GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
            if (currentControlledCharacter && currentControlledCharacter.gameObject)
            {
                return collision.gameObject == currentControlledCharacter.gameObject;
            }

            return false;
        }

        private void OnTriggerEnter2D(Collider2D collision)
        {
            if (IsPlayer(collision))
            {
                m_previousAudio = GameManager.AudioSystem.GetLastPlayedAudioClipResolver(m_audioClipResolver.targetChannel);
                GameRuntimeEvents.RequestAudioPlayback(m_audioClipResolver);
            }
        }

        private void OnTriggerExit2D(Collider2D collision)
        {
            if (IsPlayer(collision))
            {
                GameRuntimeEvents.RequestAudioPlayback(m_previousAudio);
            }
        }
    }
}
