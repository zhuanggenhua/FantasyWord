using System;
using UnityEngine;
using UnityEngine.Serialization;
using YokiFrame;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class ItemTaskProgressDataBlock : QuestTaskProgressDataBlock
    {
        public override IQuestTaskProgress CreateInstance() => new ItemTaskProgress(this);
    }

    public class ItemTaskProgress : QuestTaskProgress<ItemTaskProgressDataBlock>
    {
        public int currentQuantity { get; private set; } = 0;

        private ItemTask m_itemTask => (ItemTask)m_task;

        public ItemTaskProgress(ItemTask task) : base(task) { }

        public ItemTaskProgress(ItemTaskProgressDataBlock block) : base(block) { }

        public override void OnProgressTrackingStarted()
        {
            EventKit.Type.Register<InventoryItemAddedEvent>(OnItemAdded);
            EventKit.Type.Register<InventoryItemRemovedEvent>(OnItemRemoved);

            if (m_itemTask.inventoryScope == EInventoryQueryScope.CurrentControlledCharacter &&
                GameManager.Exists() &&
                GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            }
        }

        public override void OnProgressTrackingStopped()
        {
            EventKit.Type.UnRegister<InventoryItemAddedEvent>(OnItemAdded);
            EventKit.Type.UnRegister<InventoryItemRemovedEvent>(OnItemRemoved);

            if (m_itemTask.inventoryScope == EInventoryQueryScope.CurrentControlledCharacter &&
                GameManager.Exists() &&
                GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.RemoveCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            }
        }

        public override bool IsCompleted()
        {
            return currentQuantity >= m_itemTask.amountToCollect;
        }

        protected override void Update()
        {
            int quantityInInventory = m_itemTask.GetCurrentQuantity();

            if (quantityInInventory != currentQuantity)
            {
                currentQuantity = quantityInInventory;
                UpdateProgression();
            }
        }

        private void OnItemAdded(InventoryItemAddedEvent inventoryItemAddedEvent)
        {
            if (GameManager.InventorySystem.IsOwnerInScope(m_itemTask.inventoryScope, inventoryItemAddedEvent.Owner))
            {
                Update();
            }
        }

        private void OnItemRemoved(InventoryItemRemovedEvent inventoryItemRemovedEvent)
        {
            if (GameManager.InventorySystem.IsOwnerInScope(m_itemTask.inventoryScope, inventoryItemRemovedEvent.Owner))
            {
                Update();
            }
        }

        private void OnCurrentControlledCharacterChanged(CharacterBase character)
        {
            Update();
        }
    }

    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Quests_Tasks + nameof(ItemTask))]
    public class ItemTask : QuestTask
    {
        [SerializeField, FormerlySerializedAs("item")]
        private Item m_item = null;

        [SerializeField, FormerlySerializedAs("amountToCollect")]
        private int m_amountToCollect = 1;

        [SerializeField]
        private EInventoryQueryScope m_inventoryScope = EInventoryQueryScope.Party;

        public Item item => m_item;
        public int amountToCollect => m_amountToCollect;
        public EInventoryQueryScope inventoryScope => m_inventoryScope;

        public ItemTask()
        {
            m_title = "Acquire {0} ({1}/{2})";
        }

        public override IQuestTaskProgress CreateTaskProgress() => new ItemTaskProgress(this);

        public int GetCurrentQuantity()
        {
            return GameManager.InventorySystem.GetItemCount(
                GameManager.InventorySystem.GetOwner(m_inventoryScope),
                m_item);
        }

        public override string GetCompletedTitle()
        {
            return StringFormatter.Format(m_title, item.displayName, amountToCollect, amountToCollect);
        }

        public override string GetInProgressTitle(IQuestTaskProgress progress)
        {
            return StringFormatter.Format(m_title, item.displayName, ((ItemTaskProgress)progress).currentQuantity, amountToCollect);
        }
    }
}
