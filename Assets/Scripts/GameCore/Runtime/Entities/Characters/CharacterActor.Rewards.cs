namespace FantasyWord.GameCore
{
    public partial class CharacterActor
    {
        public override void Kill()
        {
            if (IsMarkedAsDestroyed())
            {
                return;
            }

            CharacterBase rewardReceiver = ResolveRewardReceiver();
            base.Kill();

            if (m_isSummoned)
            {
                return;
            }

            GameRuntimeEvents.NotifyCharacterKilled(m_sheet);
            if (rewardReceiver != null)
            {
                GrantKillRewards(rewardReceiver, GameManager.InventorySystem);
            }

            m_sheet.ExecuteOnDeath(
                rewardReceiver != null
                    ? ResolveRewardCommandContext(rewardReceiver)
                    : GameCommandContext.Script(this, nameof(CharacterActor)));
        }

        private CharacterBase ResolveRewardReceiver()
        {
            if (TryGetLastEffectiveDamageSource(out CharacterBase damageSource))
            {
                return damageSource;
            }

            return GameManager.PlayerSystem.GetPrimaryPlayerCharacter();
        }

        private void GrantKillRewards(CharacterBase receiver, InventorySystem inventorySystem)
        {
            if (receiver == null)
            {
                return;
            }

            bool rewardGranted = GrantLoot(receiver, inventorySystem);
            int experienceReward = m_sheet.GetExperienceRewardAtLevel(m_level);
            int moneyReward = m_sheet.GetMoneyRewardAtLevel(m_level);

            if (receiver is CharacterActor actor && experienceReward > 0)
            {
                actor.AddExperience(experienceReward);
            }

            if (moneyReward > 0)
            {
                inventorySystem.AddMoney(moneyReward);
            }

            if (rewardGranted || moneyReward > 0)
            {
                PlayRewardPresentation(receiver, rewardGranted, moneyReward);
            }

        }

        private bool GrantLoot(CharacterBase receiver, InventorySystem inventorySystem)
        {
            bool rewardGranted = false;
            InventoryOwnerHandle receiverOwner = inventorySystem.GetOwner(receiver);

            foreach (Loot loot in m_sheet.GetPotentialLoot())
            {
                if (!CanGrantLoot(loot, receiver))
                {
                    continue;
                }

                inventorySystem.AddToBag(receiverOwner, loot.item, loot.quantity, EItemTransferType.CharacterDrop);
                rewardGranted = true;
            }

            return rewardGranted;
        }

        private bool CanGrantLoot(Loot loot, CharacterBase receiver)
        {
            return receiver.level >= loot.minimumReceiverLevel
                && m_level >= loot.minimumDefeatedCharacterLevel
                && loot.IsAvailable()
                && loot.ResolveDrop();
        }

        private void PlayRewardPresentation(CharacterBase receiver, bool rewardGranted, int moneyReward)
        {
            UnityEngine.Vector3 rewardPosition = transform.position;
            m_sheet.feedbacks.PlayLoot(rewardPosition);
            GameRuntimeEvents.NotifyLootPresentation(new LootPresentationContext(
                rewardPosition,
                this,
                receiver,
                rewardGranted,
                moneyReward));
        }

        private static GameCommandContext ResolveRewardCommandContext(CharacterBase receiver)
        {
            return GameCommandContext.ResolveForActor(receiver);
        }
    }
}
