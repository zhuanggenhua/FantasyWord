using UnityEngine;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    public enum EVerticalDirection { None, Up, Down }
    public enum EHorizontalDirection { None, Left, Right }

    public class Teleporter : Checkpoint
    {
        [Header("Destination Settings")]
        [SerializeReference, SubclassSelector] private ICheckpoint m_destination;
        [SerializeField] private bool m_saveCheckpointOnArrival = false;

        [Header("Activation Settings")]
        [SerializeField] private EVerticalDirection m_requiredVerticalMovement = EVerticalDirection.None;
        [SerializeField] private EHorizontalDirection m_requiredHorizontalMovement = EHorizontalDirection.None;

        [Header("Audio")]
        [SerializeField] private AudioClipResolver m_activationAudio;

        // Used to prevent a teleporter from triggering multiple teleportations before the previous one is fully completed
        private static bool _teleportationInProgress = false;

        private void OnTriggerStay2D(Collider2D collision)
        {
            CharacterActor traversalCharacter = GameManager.MapSystem.GetTraversalCharacter();
            CharacterActor collisionCharacter = collision != null
                ? collision.GetComponentInParent<CharacterActor>()
                : null;

            if (!_teleportationInProgress &&
                traversalCharacter != null &&
                collisionCharacter == traversalCharacter)
            {
                if (traversalCharacter.dead) return;

                if (m_requiredVerticalMovement == EVerticalDirection.Up && !traversalCharacter.IsMovingUp()) return;
                if (m_requiredVerticalMovement == EVerticalDirection.Down && !traversalCharacter.IsMovingDown()) return;
                if (m_requiredHorizontalMovement == EHorizontalDirection.Left && !traversalCharacter.IsMovingLeft()) return;
                if (m_requiredHorizontalMovement == EHorizontalDirection.Right && !traversalCharacter.IsMovingRight()) return;

                traversalCharacter.InterruptPush();

                GameRuntimeEvents.RequestAudioPlayback(m_activationAudio);

                _teleportationInProgress = true;

                GameManager.MapSystem.TeleportTo(m_destination, null, () =>
                {
                    if (m_saveCheckpointOnArrival)
                    {
                        GameManager.MapSystem.SaveCheckpoint(m_destination);
                    }
                    _teleportationInProgress = false;
                });
            }
        }
    }
}

