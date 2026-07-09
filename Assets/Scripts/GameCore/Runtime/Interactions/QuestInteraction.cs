using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class QuestInteraction : IInteraction
    {
        private async Task<bool> TryProgressingQuest(CharacterBase source, NPC npc)
        {
            TalkToNPCTaskProgress taskProgress = GameManager.JournalSystem.GetTaskToComplete(npc);
            if (taskProgress != null)
            {
                await npc.Say(taskProgress.talkToNPCTask.dialogue, source);
                taskProgress.MarkAsCompleted();
                return true;
            }

            return false;
        }

        private async Task<bool> TryCompletingQuest(CharacterBase source, NPC npc)
        {
            Quest quest = GameManager.JournalSystem.GetQuestToComplete(npc);

            if (quest)
            {
                if (quest.questCompletedDialogue != null)
                {
                    await npc.Say(quest.questCompletedDialogue, source, (actionFeed) =>
                    {
                        GameManager.JournalSystem.CompleteQuest(quest, ResolveQuestCompletionCommandContext(source));
                    });

                    return true;
                }
                else
                {
                    Debug.LogErrorFormat("No quest completed dialogue provided for [{0}]", quest.title);
                }
            }

            return false;
        }

        private static GameCommandContext ResolveQuestCompletionCommandContext(CharacterBase source)
        {
            return GameCommandContext.ResolveForActor(source);
        }

        private DialogueSequence FindQuestHintDialogue(Quest quest)
        {
            // Look for quest hint overrides (some tasks may have specific hints)
            if (quest.questHintDialogueOverrideCount > 0)
            {
                foreach (var activeQuest in GameManager.JournalSystem.GetActiveQuests())
                {
                    foreach (var task in activeQuest.GetCurrentTasks())
                    {
                        if (quest.TryGetQuestHintDialogueOverride(task.task, out DialogueSequence overrideDialogue))
                        {
                            return overrideDialogue;
                        }
                    }
                }
            }

            if (quest.questHintDialogue != null)
            {
                return quest.questHintDialogue;
            }

            return null;
        }

        private async Task<bool> TryGivingHint(CharacterBase source, NPC npc)
        {
            // Try to find a hint for a fullfilled quest (quest with no task, such as "Talk to X")
            Quest quest = GameManager.JournalSystem.GetFullfilledQuest(npc);

            if (!quest)
            {
                // Try to find a hint for a started quest
                quest = GameManager.JournalSystem.GetStartedQuest(npc);
            }

            if (quest != null)
            {
                DialogueSequence dialogue = FindQuestHintDialogue(quest);

                if (dialogue)
                {
                    await npc.Say(dialogue, source);
                    return true;
                }
            }

            return false;
        }

        private async Task<bool> TryOfferingQuest(CharacterBase source, NPC npc)
        {
            Quest quest = GameManager.JournalSystem.GetQuestToStart(npc);

            if (quest)
            {
                if (quest.questOfferDialogue != null)
                {
                    await npc.Say(quest.questOfferDialogue, source, (messages) =>
                    {
                        if (messages.Contains(EDialogueMessageType.Accept))
                        {
                            GameManager.JournalSystem.StartQuest(quest, ResolveQuestStartCommandContext(source));
                        }
                    });

                    return true;
                }
                else
                {
                    Debug.LogErrorFormat("No quest offer dialogue provided for [{0}]", quest.title);
                }
            }

            return false;
        }

        private static GameCommandContext ResolveQuestStartCommandContext(CharacterBase source)
        {
            return GameCommandContext.ResolveForActor(source);
        }

        public async Task<bool> TryExecute(CharacterBase source, IInteractionTarget target)
        {
            if (target is NPC npc)
            {
                if (!await TryCompletingQuest(source, npc))
                {
                    if (!await TryProgressingQuest(source, npc))
                    {
                        if (!await TryOfferingQuest(source, npc))
                        {
                            if (!await TryGivingHint(source, npc))
                            {
                                return false;
                            }
                        }
                    }
                }
            }
            else
            {
                Debug.LogError("QuestInteraction can only be used with NPC targets.");
                return false;
            }

            return true;
        }
    }
}

