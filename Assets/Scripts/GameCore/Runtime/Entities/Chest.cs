using System;
using System.Collections;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class ChestDataBlock : EntityDataBlock
    {
        public bool opened;
    }

    public class Chest : Entity
    {
        [Header("References")]
        [SerializeField] private Animator m_chestAnimator = null;
        [SerializeField] private Animator m_contentAnimator = null;
        [SerializeField] private SpriteRenderer m_contentSpriteRenderer = null;

        [Header("Chest Settings")]
        [SerializeField] private ChestLoot m_loot;
        [SerializeField] private string m_openedAnimationParameter = "opened";
        [SerializeField] private string m_contentRevealAnimationParameter = "reveal";
        [SerializeField] private float m_contentRevealIconCycleDuration = 1.0f;
        [SerializeField] private DialogueSequence m_noItemDialogue = null;
        [SerializeField] private DialogueSequence m_hasItemDialogue = null;

        [Header("Audio")]
        [SerializeField] private AudioClipResolver m_openingSound;

        private bool m_hasOpeningAnimation = false;
        private bool m_hasRevealAnimation = false;
        private bool m_opened = false;

        protected void Awake()
        {
            Debug.Assert(m_chestAnimator, ErrorMessages.InspectorMissingComponentReference<Animator>());
            Debug.Assert(m_contentAnimator, ErrorMessages.InspectorMissingComponentReference<Animator>());
            Debug.Assert(m_contentSpriteRenderer, ErrorMessages.InspectorMissingComponentReference<SpriteRenderer>());

            if (m_chestAnimator)
            {
                m_hasOpeningAnimation = AnimationUtils.HasParameter(m_chestAnimator, m_openedAnimationParameter);
            }

            if (m_contentAnimator)
            {
                m_hasRevealAnimation = AnimationUtils.HasParameter(m_contentAnimator, m_contentRevealAnimationParameter);
            }
        }

        protected virtual void Start()
        {
            if (m_opened)
            {
                TryPlayOpeningAnimation(true);
            }
        }

        public bool TryPlayOpeningAnimation(bool open)
        {
            if (m_chestAnimator && m_hasOpeningAnimation)
            {
                m_chestAnimator.SetBool(m_openedAnimationParameter, open);
                return true;
            }

            return false;
        }

        public bool TryPlayContentRevealAnimation()
        {
            if (m_contentSpriteRenderer && m_contentAnimator && m_hasRevealAnimation)
            {
                Sprite[] sprites = m_loot.GetLootSprites();

                if (sprites.Length > 0)
                {
                    StartCoroutine(UpdateContentSprite(sprites, m_contentRevealIconCycleDuration));
                    m_contentAnimator.SetTrigger(m_contentRevealAnimationParameter);
                    return true;
                }

                return false;
            }

            return false;
        }

        private IEnumerator UpdateContentSprite(Sprite[] sprites, float duration)
        {
            if (sprites.Length == 0) yield break;

            float interval = duration / sprites.Length;

            for (int index = 0; index < sprites.Length; ++index)
            {
                m_contentSpriteRenderer.sprite = sprites[index];
                yield return new WaitForSeconds(interval);
            }
        }

        public async Task<bool> TryOpen()
        {
            return await TryOpen(GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance());
        }

        public async Task<bool> TryOpen(CharacterBase opener)
        {
            bool firstOpen = !m_opened;
            GameCommandContext commandContext = ResolveCommandContext(opener);

            if (!m_opened)
            {
                TryPlayOpeningAnimation(true);
                TryPlayContentRevealAnimation();

                if (!m_loot.IsEmpty())
                {
                    GameRuntimeEvents.RequestAudioPlayback(m_openingSound);

                    InitializeContainerLoot(commandContext);

                    if (m_loot.HasMoney())
                    {
                        GameManager.DialogueSystem.AddToQueue(
                            m_hasItemDialogue.ToDialogueTree(
                                string.Empty, commandContext, $"{m_loot.money} <currency.fullName>"
                            )
                        );

                        GameManager.InventorySystem.AddMoney(m_loot.money);
                    }
                }
                else
                {
                    GameManager.DialogueSystem.AddToQueue(
                        m_noItemDialogue.ToDialogueTree(string.Empty, commandContext)
                    );
                }

                await GameManager.DialogueSystem.PlayQueue();

                m_opened = true;
            }

            if (firstOpen && m_loot.IsEmpty())
            {
                return true;
            }

            return await TryOpenContainerInventory(opener, commandContext);
        }

        public InventoryOwnerHandle GetInventoryOwner()
        {
            return InventoryOwnerHandle.ForPersistable(EInventoryOwnerKind.Container, this);
        }

        private void InitializeContainerLoot(GameCommandContext commandContext)
        {
            InventorySystem inventorySystem = GameManager.InventorySystem;
            InventoryOwnerHandle containerOwner = GetInventoryOwner();

            foreach (var entry in m_loot.GetEntries())
            {
                if (!entry.item || entry.quantity <= 0)
                {
                    continue;
                }

                GameManager.DialogueSystem.AddToQueue(
                    m_hasItemDialogue.ToDialogueTree(
                        string.Empty, commandContext, $"{entry.item.displayName} x{entry.quantity}"
                    )
                );

                inventorySystem.AddToBag(containerOwner, entry.item, entry.quantity, EItemTransferType.Chest);
            }
        }

        private async Task<bool> TryOpenContainerInventory(CharacterBase opener, GameCommandContext commandContext)
        {
            InventoryOwnerHandle containerOwner = GetInventoryOwner();
            if (GameManager.InventorySystem.GetBagEntries(containerOwner).Length == 0)
            {
                return !m_loot.IsEmpty();
            }

            TaskCompletionSource<bool> menuClosedTask = new();
            GameRuntimeEvents.RequestInventory(
                InventoryMenuContext.TransferToCharacter(
                    commandContext,
                    opener,
                    containerOwner,
                    EItemTransferType.Chest),
                menuClosedTask);
            return await menuClosedTask.Task;
        }

        private static GameCommandContext ResolveCommandContext(CharacterBase opener)
        {
            return GameCommandContext.ResolveForActor(opener);
        }

        protected override Type GetDataBlockType() => typeof(ChestDataBlock);

        protected override void OnSave(PersistableDataBlock block)
        {
            base.OnSave(block);
            block.As<ChestDataBlock>().opened = m_opened;
        }

        protected override void OnLoad(PersistableDataBlock block)
        {
            base.OnLoad(block);
            m_opened = block.As<ChestDataBlock>().opened;
        }
    }
}

