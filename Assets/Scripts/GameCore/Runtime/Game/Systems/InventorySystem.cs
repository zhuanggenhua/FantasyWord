using System;
using System.Collections.Generic;
using System.Linq;
using Unity.Mathematics;
using UnityEngine;
using azixMcAze.SerializableDictionary;

namespace FantasyWord.GameCore
{
    public enum EInventoryOwnerKind
    {
        Party,
        Character,
        Container,
        GroundPile,
        Corpse,
        Shop,
        CraftingStation
    }

    public enum EInventoryQueryScope
    {
        Party,
        CurrentControlledCharacter
    }

    [Serializable]
    public readonly struct InventoryOwnerHandle : IEquatable<InventoryOwnerHandle>
    {
        public static readonly InventoryOwnerHandle DefaultParty = new(EInventoryOwnerKind.Party, "default");

        public InventoryOwnerHandle(EInventoryOwnerKind kind, string id)
        {
            Kind = kind;
            Id = string.IsNullOrWhiteSpace(id) ? "default" : id;
        }

        public EInventoryOwnerKind Kind { get; }
        public string Id { get; }
        public bool IsValid => !string.IsNullOrWhiteSpace(Id);

        public static InventoryOwnerHandle ForCharacter(CharacterBase character)
        {
            if (!character)
            {
                return DefaultParty;
            }

            string persistentIdentifier = character.GetPersistentIdentifier();
            string ownerId = !string.IsNullOrWhiteSpace(persistentIdentifier)
                ? persistentIdentifier
                : $"scene:{character.gameObject.scene.handle}:{character.GetInstanceID()}";

            return new InventoryOwnerHandle(EInventoryOwnerKind.Character, ownerId);
        }

        public static InventoryOwnerHandle ForPersistable(EInventoryOwnerKind kind, Persistable persistable)
        {
            if (!persistable)
            {
                return new InventoryOwnerHandle(kind, "default");
            }

            string persistentIdentifier = persistable.GetPersistentIdentifier();
            string ownerId = !string.IsNullOrWhiteSpace(persistentIdentifier)
                ? persistentIdentifier
                : $"scene:{persistable.gameObject.scene.handle}:{persistable.GetInstanceID()}";

            return new InventoryOwnerHandle(kind, ownerId);
        }

        public bool Equals(InventoryOwnerHandle other) => Kind == other.Kind && string.Equals(Id, other.Id, StringComparison.Ordinal);
        public override bool Equals(object obj) => obj is InventoryOwnerHandle other && Equals(other);
        public override int GetHashCode() => HashCode.Combine((int)Kind, Id);
        public override string ToString() => $"{Kind}:{Id}";
    }

    [Serializable]
    public class InventoryOwnerDataBlock
    {
        public EInventoryOwnerKind ownerKind;
        public string ownerId;
        public int money;
        public SerializableDictionary<DatabaseEntryReference<Item>, int> items;
    }

    [Serializable]
    public class InventoryDataBlock : DataBlock
    {
        public InventoryOwnerDataBlock[] inventories;
    }

    public class InventorySystem : AGameSystem, IDataBlockHandler<InventoryDataBlock>
    {
        private sealed class InventoryRuntime
        {
            public int money;
            public readonly Dictionary<Item, int> items = new();
        }

        private readonly Dictionary<InventoryOwnerHandle, InventoryRuntime> m_inventories = new();

        public int money => GetMoney(InventoryOwnerHandle.DefaultParty);

        public InventoryOwnerHandle GetOwner(CharacterBase character)
        {
            if (character == null)
            {
                return InventoryOwnerHandle.DefaultParty;
            }

            if (character.TryGetComponent(out CharacterInventory inventory) && inventory != null)
            {
                return inventory.ResolveMainInventoryOwner();
            }

            throw new InvalidOperationException(
                $"[{nameof(InventorySystem)}] Character inventory owner requires {nameof(CharacterInventory)} on [{character.name}].");
        }

        public InventoryOwnerHandle GetCorpseOwner(CharacterBase character) =>
            InventoryOwnerHandle.ForPersistable(EInventoryOwnerKind.Corpse, character);

        public InventoryOwnerHandle GetOwner(EInventoryQueryScope queryScope)
        {
            switch (queryScope)
            {
                case EInventoryQueryScope.CurrentControlledCharacter:
                    return GetOwner(GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance());
                case EInventoryQueryScope.Party:
                default:
                    return InventoryOwnerHandle.DefaultParty;
            }
        }

        public KeyValuePair<Item, int>[] GetBagEntries(InventoryOwnerHandle owner)
        {
            return GetInventory(owner).items.ToArray();
        }

        public int GetItemCount(InventoryOwnerHandle owner, Item item)
        {
            if (GetInventory(owner).items.TryGetValue(item, out int count))
            {
                return count;
            }

            return 0;
        }

        public void AddMoney(int value)
        {
            AddMoney(InventoryOwnerHandle.DefaultParty, value);
        }

        private void AddMoney(InventoryOwnerHandle owner, int value)
        {
            if (value > 0)
            {
                GetInventory(owner).money += value;
                GameRuntimeEvents.NotifyInventoryMoneyAdded(owner, value);
            }
        }

        public void RemoveMoney(int value)
        {
            RemoveMoney(InventoryOwnerHandle.DefaultParty, value);
        }

        private void RemoveMoney(InventoryOwnerHandle owner, int value)
        {
            if (value > 0)
            {
                InventoryRuntime inventory = GetInventory(owner);
                inventory.money = math.max(inventory.money - value, 0);
                GameRuntimeEvents.NotifyInventoryMoneyRemoved(owner, value);
            }
        }

        public bool HasSufficientFunds(int value) => value <= money;
        private bool HasSufficientFunds(InventoryOwnerHandle owner, int value) => value <= GetMoney(owner);

        private int GetMoney(InventoryOwnerHandle owner)
        {
            return GetInventory(owner).money;
        }

        public bool IsOwnerInScope(EInventoryQueryScope queryScope, InventoryOwnerHandle owner)
        {
            switch (queryScope)
            {
                case EInventoryQueryScope.CurrentControlledCharacter:
                    return owner.Equals(GetOwner(EInventoryQueryScope.CurrentControlledCharacter));
                case EInventoryQueryScope.Party:
                default:
                    return owner.Equals(InventoryOwnerHandle.DefaultParty);
            }
        }

        public bool HasItemInBag(InventoryOwnerHandle owner, Item item, int quantity = 1)
        {
            return GetInventory(owner).items.TryGetValue(item, out int count) && count >= quantity;
        }

        public Equipment GetEquipment(CharacterEquipment equipmentTarget, EEquipmentType type)
        {
            if (equipmentTarget == null)
            {
                return null;
            }

            if (equipmentTarget.TryGetEquipment(type, out Equipment equipment))
            {
                return equipment;
            }

            return null;
        }

        public EEquipmentOperationResult TryEquip(InventoryOwnerHandle sourceOwner, CharacterEquipment equipmentTarget, Equipment equipment)
        {
            Debug.Assert(equipment, "Cannot equip a null equipment");

            if (equipmentTarget == null || equipmentTarget.Character == null)
            {
                return EEquipmentOperationResult.InvalidTarget;
            }

            if (!equipmentTarget.Character.Can(EActionFlags.ChangeEquipment))
            {
                return EEquipmentOperationResult.ActionLocked;
            }

            if (!HasItemInBag(sourceOwner, equipment, 1))
            {
                return EEquipmentOperationResult.MissingItem;
            }

            EEquipmentOperationResult result = equipmentTarget.TryEquip(equipment, out Equipment previousEquipment);

            if (result == EEquipmentOperationResult.Valid)
            {
                RemoveFromBag(sourceOwner, equipment, 1, EItemTransferType.Equipment);

                if (previousEquipment)
                {
                    AddToBag(sourceOwner, previousEquipment, 1, EItemTransferType.Equipment);
                }
            }

            return result;
        }

        public EEquipmentOperationResult TryUnequip(InventoryOwnerHandle destinationOwner, CharacterEquipment equipmentTarget, EEquipmentType type)
        {
            if (equipmentTarget == null || equipmentTarget.Character == null)
            {
                return EEquipmentOperationResult.InvalidTarget;
            }

            if (!equipmentTarget.Character.Can(EActionFlags.ChangeEquipment))
            {
                return EEquipmentOperationResult.ActionLocked;
            }

            EEquipmentOperationResult result = equipmentTarget.TryUnequip(type, out Equipment previousEquipment);

            if (result == EEquipmentOperationResult.Valid && previousEquipment != null)
            {
                AddToBag(destinationOwner, previousEquipment, 1, EItemTransferType.Equipment);
            }

            return result;
        }

        public void AddToBag(Item item, int quantity = 1, EItemTransferType source = EItemTransferType.Unknown)
        {
            AddToBag(InventoryOwnerHandle.DefaultParty, item, quantity, source);
        }

        public void AddToBag(InventoryOwnerHandle owner, Item item, int quantity = 1, EItemTransferType source = EItemTransferType.Unknown)
        {
            if (!item || quantity <= 0)
            {
                return;
            }

            Dictionary<Item, int> items = GetInventory(owner).items;
            if (!items.ContainsKey(item))
            {
                items.Add(item, quantity);
            }
            else
            {
                items[item] += quantity;
            }

            GameRuntimeEvents.NotifyInventoryItemAdded(owner, item, quantity, source);
        }

        public bool RemoveFromBag(Item item, int quantity = 1, EItemTransferType transferType = EItemTransferType.Unknown)
        {
            return RemoveFromBag(InventoryOwnerHandle.DefaultParty, item, quantity, transferType);
        }

        public bool RemoveFromBag(InventoryOwnerHandle owner, Item item, int quantity = 1, EItemTransferType transferType = EItemTransferType.Unknown)
        {
            if (!item || quantity <= 0)
            {
                return false;
            }

            Dictionary<Item, int> items = GetInventory(owner).items;

            if (!items.TryGetValue(item, out int currentQuantity))
            {
                return false;
            }

            int removedQuantity = math.min(quantity, currentQuantity);

            if (removedQuantity >= currentQuantity)
            {
                items.Remove(item);
            }
            else
            {
                items[item] -= removedQuantity;
            }

            GameRuntimeEvents.NotifyInventoryItemRemoved(owner, item, removedQuantity, transferType);

            return true;
        }

        public bool TransferItem(
            InventoryOwnerHandle sourceOwner,
            InventoryOwnerHandle destinationOwner,
            Item item,
            int quantity = 1,
            EItemTransferType transferType = EItemTransferType.Unknown)
        {
            InventoryTransferResult result = ExecuteTransfer(new InventoryTransferRequest(
                null,
                sourceOwner,
                destinationOwner,
                item,
                quantity,
                transferType));
            return result.Succeeded;
        }

        public InventoryTransferResult ExecuteTransfer(InventoryTransferRequest request)
        {
            EInventoryTransferFailureReason failureReason = ValidateTransferRequest(request);
            if (failureReason != EInventoryTransferFailureReason.None)
            {
                return InventoryTransferResult.Failed(request, failureReason);
            }

            if (request.SourceOwner.Equals(request.DestinationOwner))
            {
                return InventoryTransferResult.Success(request, 0);
            }

            RemoveFromBag(request.SourceOwner, request.Item, request.Quantity, request.TransferType);
            AddToBag(request.DestinationOwner, request.Item, request.Quantity, request.TransferType);
            return InventoryTransferResult.Success(request, request.Quantity);
        }

        private EInventoryTransferFailureReason ValidateTransferRequest(InventoryTransferRequest request)
        {
            if (!request.Item)
            {
                return EInventoryTransferFailureReason.InvalidItem;
            }

            if (request.Quantity <= 0)
            {
                return EInventoryTransferFailureReason.InvalidQuantity;
            }

            if (!request.SourceOwner.IsValid)
            {
                return EInventoryTransferFailureReason.InvalidSourceOwner;
            }

            if (!request.DestinationOwner.IsValid)
            {
                return EInventoryTransferFailureReason.InvalidDestinationOwner;
            }

            if (!CanActorParticipateInTransfer(request))
            {
                return EInventoryTransferFailureReason.ActorNotParticipant;
            }

            if (!CanActorManageInventory(request))
            {
                return EInventoryTransferFailureReason.ActorActionLocked;
            }

            if (!HasItemInBag(request.SourceOwner, request.Item, request.Quantity))
            {
                return EInventoryTransferFailureReason.InsufficientQuantity;
            }

            return EInventoryTransferFailureReason.None;
        }

        private bool CanActorParticipateInTransfer(InventoryTransferRequest request)
        {
            if (!request.Actor)
            {
                return true;
            }

            InventoryOwnerHandle actorOwner = GetOwner(request.Actor);
            return actorOwner.Equals(request.SourceOwner) || actorOwner.Equals(request.DestinationOwner);
        }

        private static bool CanActorManageInventory(InventoryTransferRequest request)
        {
            return !request.Actor || request.Actor.Can(EActionFlags.ManageInventory);
        }

        private bool TransferAllItems(
            InventoryOwnerHandle sourceOwner,
            InventoryOwnerHandle destinationOwner,
            EItemTransferType transferType = EItemTransferType.Unknown)
        {
            bool transferredAny = false;

            foreach (KeyValuePair<Item, int> entry in GetBagEntries(sourceOwner))
            {
                transferredAny |= TransferItem(sourceOwner, destinationOwner, entry.Key, entry.Value, transferType);
            }

            return transferredAny;
        }

        public bool TransferCharacterInventoryToCorpse(CharacterBase character)
        {
            if (!character)
            {
                return false;
            }

            return TransferAllItems(
                GetOwner(character),
                GetCorpseOwner(character),
                EItemTransferType.Corpse);
        }

        public bool TransferCharacterEquipmentToCorpse(CharacterBase character)
        {
            if (character == null ||
                !character.TryGetComponent(out CharacterEquipment equipmentComponent) ||
                equipmentComponent == null)
            {
                return false;
            }

            bool transferredAny = false;
            InventoryOwnerHandle corpseOwner = GetCorpseOwner(character);
            foreach (Equipment equipment in equipmentComponent.ForceUnequipAllEquipmentForLifecycle())
            {
                AddToBag(corpseOwner, equipment, 1, EItemTransferType.Corpse);
                transferredAny = true;
            }

            return transferredAny;
        }

        public bool TransferCorpseInventoryToCharacter(CharacterBase character)
        {
            if (!character)
            {
                return false;
            }

            return TransferAllItems(
                GetCorpseOwner(character),
                GetOwner(character),
                EItemTransferType.Corpse);
        }

        public void LoadDataBlock(InventoryDataBlock block)
        {
            m_inventories.Clear();

            if (block == null)
            {
                return;
            }

            LoadOwnerDataBlocks(block.inventories);
        }

        public InventoryDataBlock CreateDataBlock()
        {
            return new InventoryDataBlock
            {
                inventories = CreateOwnerDataBlocks()
            };
        }

        private InventoryRuntime GetInventory(InventoryOwnerHandle owner)
        {
            if (!owner.IsValid)
            {
                owner = InventoryOwnerHandle.DefaultParty;
            }

            if (!m_inventories.TryGetValue(owner, out InventoryRuntime inventory))
            {
                inventory = new InventoryRuntime();
                m_inventories.Add(owner, inventory);
            }

            return inventory;
        }

        private void LoadOwnerDataBlocks(InventoryOwnerDataBlock[] ownerDataBlocks)
        {
            if (ownerDataBlocks == null)
            {
                return;
            }

            foreach (InventoryOwnerDataBlock ownerDataBlock in ownerDataBlocks)
            {
                if (ownerDataBlock == null)
                {
                    continue;
                }

                InventoryOwnerHandle owner = new(ownerDataBlock.ownerKind, ownerDataBlock.ownerId);
                InventoryRuntime inventory = GetInventory(owner);
                inventory.money = ownerDataBlock.money;
                inventory.items.Clear();

                if (ownerDataBlock.items == null)
                {
                    continue;
                }

                foreach ((DatabaseEntryReference<Item> itemReference, int quantity) in ownerDataBlock.items)
                {
                    inventory.items[GameManager.Database.LoadFromReference(itemReference)] = quantity;
                }
            }
        }

        private InventoryOwnerDataBlock[] CreateOwnerDataBlocks()
        {
            return m_inventories
                .Select(kvp => new InventoryOwnerDataBlock
                {
                    ownerKind = kvp.Key.Kind,
                    ownerId = kvp.Key.Id,
                    money = kvp.Value.money,
                    items = new SerializableDictionary<DatabaseEntryReference<Item>, int>(
                        kvp.Value.items.ToDictionary(itemKvp => GameManager.Database.CreateReference(itemKvp.Key), itemKvp => itemKvp.Value))
                })
                .ToArray();
        }
    }
}
