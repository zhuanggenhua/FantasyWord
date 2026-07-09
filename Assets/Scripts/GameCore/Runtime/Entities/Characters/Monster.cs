namespace FantasyWord.GameCore
{
    public class Monster : Character<MonsterSheet>
    {
        protected override void InitializeStats()
        {
            UpdateStats();
        }

        internal void SetLevel(int level)
        {
            m_level = level;
            UpdateStats();
        }

        public override void LevelUp(bool silentMode = false)
        {
            base.LevelUp(silentMode);
            UpdateStats();
        }

        private void UpdateStats()
        {
            SetResolvedBaseStats(m_sheet.GetStatsAtLevel(m_level) + CreateEquipmentStatContributionSnapshot());
        }

        internal override void RefreshResolvedStatsForEquipmentRuntime()
        {
            UpdateStats();
        }

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

            GrantKillRewards(rewardReceiver, GameManager.InventorySystem);
        }

        protected override void OnStuckInAWall()
        {
            // If the monster is stuck in a wall, kill it.
            Kill();
        }

        private CharacterBase ResolveRewardReceiver()
        {
            if (TryGetLastEffectiveDamageSource(out CharacterBase damageSource))
            {
                return damageSource;
            }

            return GameManager.PlayerSystem.GetPlayerInstance();
        }

        private void GrantKillRewards(CharacterBase receiver, InventorySystem inventorySystem)
        {
            if (receiver == null)
            {
                throw new System.InvalidOperationException("Monster rewards require a valid receiver.");
            }

            GameRuntimeEvents.NotifyMonsterKilled(m_sheet);

            bool rewardGranted = GrantLoot(receiver, inventorySystem);
            int experienceReward = m_sheet.GetExperienceRewardAtLevel(m_level);
            int moneyReward = m_sheet.GetMoneyRewardAtLevel(m_level);

            if (receiver is Hero hero)
            {
                hero.AddExperience(experienceReward);
            }

            inventorySystem.AddMoney(moneyReward);

            if (rewardGranted || moneyReward > 0)
            {
                PlayRewardPresentation(receiver, rewardGranted, moneyReward);
            }

            m_sheet.ExecuteOnDeath(ResolveRewardCommandContext(receiver));
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

                inventorySystem.AddToBag(receiverOwner, loot.item, loot.quantity, EItemTransferType.MonsterDrop);
                rewardGranted = true;
            }

            return rewardGranted;
        }

        private bool CanGrantLoot(Loot loot, CharacterBase receiver)
        {
            return receiver.level >= loot.minimumPlayerLevel
                && m_level >= loot.minimumMonsterLevel
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
