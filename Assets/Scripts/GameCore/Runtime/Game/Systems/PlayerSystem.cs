using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;
using YokiFrame;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class PlayerDataBlock : DataBlock
    {
        public HeroRuntimeStateData heroData;
        public PersistableReference<CharacterBase>[] currentControlledCharacters;
    }

    /// <summary>
    /// 玩家实体与当前控制目标的正式真相源。
    /// 玩家 Hero 仍是 RPG 数据和存档入口，但“谁接玩家输入”不再默认等于唯一 Hero。
    /// </summary>
    public class PlayerSystem : AGameSystem, IDataBlockHandler<PlayerDataBlock>
    {
        [Header("Scene References")]
        [SerializeField] private Hero m_playerInstance = null;

        private readonly UnityEvent<CharacterBase> m_currentControlledCharacterChanged = new();
        private IPlayerInputTarget m_currentInputTarget;
        private PlayerControlGroup m_currentControlGroup;
        private CharacterBase m_boundControlledCharacter;
        private readonly List<CharacterBase> m_boundControlledCharacters = new();
        private PersistableReference<CharacterBase>[] m_pendingControlledCharacterReferences = Array.Empty<PersistableReference<CharacterBase>>();
        private bool m_hasPendingControlledCharacterRestore = false;
        private bool m_pendingPlayerControlRestore = false;

        public override void OnSystemStart()
        {
            EnsurePlayerInstance();
            ResetCurrentControlToPlayerInstance();
            m_pendingPlayerControlRestore = m_currentInputTarget == null;
            GameManager.PersistenceSystem.RegisterCustomInstancedPersistable(m_playerInstance, Constants.UniquePlayerIdentifier);
        }

        public override void OnSystemStop()
        {
            BindControlledCharacters(Array.Empty<CharacterBase>());
            ClearPendingControlledCharacterRestore();
            m_pendingPlayerControlRestore = false;
        }

        public override void OnMapLoaded()
        {
            TryRestorePendingControlledCharacters();
            TryRestorePendingPlayerControl();
        }

        public override void OnSaveFileLoaded()
        {
            TryRestorePendingControlledCharacters();
            TryRestorePendingPlayerControl();
        }

        internal void NotifyHeroKilled(Hero hero)
        {
            if (hero == m_playerInstance)
            {
                GameManager.DialogueSystem.Interrupt();
                GameRuntimeEvents.RequestCloseAllMenus();
                Debug.Assert(GameManager.Config.hasPlayerDeathAction, "No action specified to execute on player death! Specify an action in the GameConfig.");
                GameManager.Config.ExecutePlayerDeathAction(GameCommandContext.LocalPlayer(hero));
                GameManager.DialogueSystem.Interrupt();
            }
        }

        internal void NotifyCharacterDied(CharacterBase character)
        {
            if (character != null && IsCurrentControlledMember(character))
            {
                RevalidateCurrentControlledCharacter();
            }
        }

        internal void NotifyCharacterRevived(CharacterBase character)
        {
            if (m_currentInputTarget == null &&
                character == m_playerInstance &&
                TryResolveControllableInputTarget(character, out IPlayerInputTarget _))
            {
                SetCurrentControlledCharacter(character);
            }
        }

        /// <summary>
        /// 切换当前消费玩家输入的正式目标。
        /// 当前默认是角色 prefab 上的 CharacterPlayerControl；控制组或编队应继续实现同一接口，而不是另造输入入口。
        /// </summary>
        public void SetCurrentInputTarget(IPlayerInputTarget inputTarget)
        {
            if (ReferenceEquals(m_currentInputTarget, inputTarget))
            {
                if (m_currentInputTarget != null)
                {
                    BindControlledCharacters(CreateCurrentControlledCharacterSnapshot());
                    NotifyCurrentControlledTargetChanged();
                }

                return;
            }

            m_currentInputTarget = inputTarget;
            m_currentControlGroup = inputTarget as PlayerControlGroup;
            if (m_currentInputTarget != null)
            {
                m_pendingPlayerControlRestore = false;
            }
            BindControlledCharacters(CreateCurrentControlledCharacterSnapshot());
            NotifyCurrentControlledTargetChanged();
        }

        /// <summary>
        /// 以角色实体切换当前控制对象。
        /// 角色必须挂有实现 <see cref="IPlayerInputTarget"/> 的玩家控制组件，否则它只能继续作为世界实体存在，不能直接接玩家输入。
        /// </summary>
        public void SetCurrentControlledCharacter(CharacterBase character)
        {
            IPlayerInputTarget inputTarget = null;
            if (character != null && !TryResolveControllableInputTarget(character, out inputTarget))
            {
                RevalidateCurrentControlledCharacter();
                return;
            }

            Debug.Assert(character == null || inputTarget != null, "The selected controlled character must expose an IPlayerInputTarget controller.");
            SetCurrentInputTarget(inputTarget);
        }

        public void SetCurrentControlGroup(params CharacterBase[] characters)
        {
            CharacterBase[] controllableCharacters = CreateControllableCharacterSnapshot(characters);
            if (controllableCharacters.Length == 0)
            {
                m_currentControlGroup = null;
                SetCurrentInputTarget(null);
                return;
            }

            if (controllableCharacters.Length == 1)
            {
                m_currentControlGroup = null;
                SetCurrentControlledCharacter(controllableCharacters[0]);
                return;
            }

            CharacterBase primaryMember = ResolvePreferredControlGroupPrimary(controllableCharacters);
            if (m_currentControlGroup == null)
            {
                m_currentControlGroup = new PlayerControlGroup(primaryMember, controllableCharacters);
            }
            else
            {
                m_currentControlGroup.ReplaceMembers(primaryMember, controllableCharacters);
            }

            SetCurrentInputTarget(m_currentControlGroup);
        }

        public bool TryAddCurrentControlGroupMember(CharacterBase character, bool makePrimary = false)
        {
            if (!TryResolveControllableInputTarget(character, out IPlayerInputTarget _))
            {
                return false;
            }

            if (m_currentControlGroup == null)
            {
                CharacterBase currentControlledCharacter = GetCurrentControlledCharacter();
                if (currentControlledCharacter == null || currentControlledCharacter == character)
                {
                    return false;
                }

                SetCurrentControlGroup(currentControlledCharacter, character);
                if (makePrimary)
                {
                    TrySetCurrentControlGroupPrimaryMember(character);
                }

                return true;
            }

            if (!m_currentControlGroup.TryAddMember(character, makePrimary))
            {
                return false;
            }

            RefreshCurrentInputTargetFromControlGroup();
            return true;
        }

        public bool TryRemoveCurrentControlGroupMember(CharacterBase character)
        {
            if (m_currentControlGroup == null)
            {
                return false;
            }

            if (!m_currentControlGroup.RemoveMember(character))
            {
                return false;
            }

            if (m_currentControlGroup.MemberCount == 0)
            {
                m_currentControlGroup = null;
                SetCurrentInputTarget(null);
                return true;
            }

            if (m_currentControlGroup.MemberCount == 1)
            {
                CharacterBase[] remainingMembers = m_currentControlGroup.CreateControlledCharacterSnapshot();
                m_currentControlGroup = null;
                SetCurrentControlledCharacter(remainingMembers.Length > 0 ? remainingMembers[0] : null);
                return true;
            }

            RefreshCurrentInputTargetFromControlGroup();
            return true;
        }

        public bool TrySetCurrentControlGroupPrimaryMember(CharacterBase character)
        {
            if (m_currentControlGroup == null || !m_currentControlGroup.TrySetPrimaryMember(character))
            {
                return false;
            }

            RefreshCurrentInputTargetFromControlGroup();
            return true;
        }

        /// <summary>
        /// 当前玩家命令的正式提交入口。
        /// InputSystem、后续本地 RTS 选择器或脚本命令都应先过 PlayerSystem，再由它决定命中单角色还是控制组订单链。
        /// </summary>
        public PlayerCommandResult SubmitPlayerCommand(PlayerCommandRequest commandRequest)
        {
            return SubmitPlayerOrder(PlayerOrderRequest.FromCommandRequest(commandRequest)).LastCommandResult;
        }

        /// <summary>
        /// 当前玩家订单的正式提交入口。
        /// 控制组会走正式订单链；单角色目标则由 CharacterPlayerControl 执行。
        /// 订单入口不再由 InputSystem 直接抓住输入目标后自行分发。
        /// </summary>
        public PlayerOrderResult SubmitPlayerOrder(PlayerOrderRequest orderRequest)
        {
            if (m_currentInputTarget == null)
            {
                PlayerCommandResult missingTargetResult = PlayerCommandResult.Failed(
                    orderRequest.CommandRequest,
                    EPlayerCommandFailureReason.MissingInputTarget);
                return PlayerOrderResult.Failed(orderRequest, 0, missingTargetResult);
            }

            return m_currentInputTarget.SubmitPlayerOrder(orderRequest);
        }

        private void Update()
        {
            TryRestorePendingPlayerControl();
            TryRestorePendingControlledCharacters();
            m_currentControlGroup?.Tick();
        }

        private void StageControlledCharacterRestore(PlayerDataBlock block)
        {
            m_pendingControlledCharacterReferences = block?.currentControlledCharacters ?? Array.Empty<PersistableReference<CharacterBase>>();
            m_hasPendingControlledCharacterRestore = HasResolvableControlledCharacterReferences(m_pendingControlledCharacterReferences);
        }

        private bool TryRestorePendingControlledCharacters()
        {
            if (!m_hasPendingControlledCharacterRestore)
            {
                return false;
            }

            CharacterBase[] resolvedCharacters = ResolvePendingControlledCharacters();
            if (resolvedCharacters.Length == 0)
            {
                return false;
            }

            if (resolvedCharacters.Length == 1)
            {
                SetCurrentControlledCharacter(resolvedCharacters[0]);
                ClearPendingControlledCharacterRestore();
                return true;
            }

            SetCurrentControlGroup(resolvedCharacters);
            ClearPendingControlledCharacterRestore();
            return true;
        }

        private CharacterBase[] ResolvePendingControlledCharacters()
        {
            List<CharacterBase> resolvedCharacters = new();
            foreach (PersistableReference<CharacterBase> characterReference in m_pendingControlledCharacterReferences)
            {
                if (!TryResolvePendingControlledCharacterReference(characterReference, out CharacterBase character))
                {
                    continue;
                }

                if (!resolvedCharacters.Contains(character))
                {
                    resolvedCharacters.Add(character);
                }
            }

            return resolvedCharacters.ToArray();
        }

        private static bool TryResolvePendingControlledCharacterReference(
            PersistableReference<CharacterBase> characterReference,
            out CharacterBase character)
        {
            if (characterReference.TryResolve(out character) &&
                TryResolveControllableInputTarget(character, out IPlayerInputTarget _))
            {
                return true;
            }

            character = null;
            return false;
        }

        private static bool HasResolvableControlledCharacterReferences(PersistableReference<CharacterBase>[] references)
        {
            if (references == null || references.Length == 0)
            {
                return false;
            }

            foreach (PersistableReference<CharacterBase> reference in references)
            {
                if (!string.IsNullOrWhiteSpace(reference.identifier))
                {
                    return true;
                }
            }

            return false;
        }

        private void ClearPendingControlledCharacterRestore()
        {
            m_pendingControlledCharacterReferences = Array.Empty<PersistableReference<CharacterBase>>();
            m_hasPendingControlledCharacterRestore = false;
        }

        public bool IsCurrentControlledMember(CharacterBase character)
        {
            if (!character)
            {
                return false;
            }

            CharacterBase[] controlledCharacters = CreateCurrentControlledCharacterSnapshot();
            foreach (CharacterBase controlledCharacter in controlledCharacters)
            {
                if (controlledCharacter == character)
                {
                    return true;
                }
            }

            return false;
        }

        public bool TryGetCurrentInputTarget(out IPlayerInputTarget inputTarget)
        {
            inputTarget = m_currentInputTarget;
            return inputTarget != null;
        }

        public void RevalidateCurrentControlledCharacter()
        {
            CharacterBase currentControlledCharacter = GetCurrentControlledCharacter();
            if (m_currentInputTarget == null)
            {
                return;
            }

            if (m_currentInputTarget is PlayerControlGroup controlGroup)
            {
                CharacterBase[] validMembers = controlGroup.CreateControlledCharacterSnapshot();
                if (validMembers.Length > 1)
                {
                    CharacterBase preferredPrimary = ResolvePreferredControlGroupPrimary(validMembers);
                    controlGroup.ReplaceMembers(preferredPrimary, validMembers);
                    BindControlledCharacters(validMembers);
                    NotifyCurrentControlledTargetChanged();
                    return;
                }

                if (validMembers.Length == 1)
                {
                    m_currentControlGroup = null;
                    SetCurrentControlledCharacter(validMembers[0]);
                    return;
                }
            }

            if (TryResolveControllableInputTarget(currentControlledCharacter, out IPlayerInputTarget _))
            {
                CharacterBase[] currentSnapshot = CreateCurrentControlledCharacterSnapshot();
                if (!ReferenceEquals(m_boundControlledCharacter, currentControlledCharacter) ||
                    !AreSameControlledCharacters(m_boundControlledCharacters, currentSnapshot))
                {
                    BindControlledCharacters(currentSnapshot);
                    NotifyCurrentControlledTargetChanged();
                }

                return;
            }

            if (m_playerInstance != null &&
                m_playerInstance != currentControlledCharacter &&
                TryResolveControllableInputTarget(m_playerInstance, out IPlayerInputTarget _))
            {
                SetCurrentControlledCharacter(m_playerInstance);
                return;
            }

            SetCurrentInputTarget(null);
        }

        /// <summary>
        /// 长期玩家 Hero 的正式查询口。
        /// 这里表达的是“存档与长期成长归属的玩家实例”，不是“当前前台受控对象”。
        /// </summary>
        public Hero GetPlayerInstance()
        {
            return m_playerInstance;
        }

        public CharacterBase GetCurrentControlledCharacterOrPlayerInstance()
        {
            return GetCurrentControlledCharacter() ?? m_playerInstance;
        }

        public bool TryGetCurrentControlledCharacter(out CharacterBase character)
        {
            character = GetCurrentControlledCharacter();
            return character != null;
        }

        private CharacterBase[] CreateCurrentControlledCharacterSnapshot()
        {
            return m_currentInputTarget != null
                ? m_currentInputTarget.CreateControlledCharacterSnapshot()
                : Array.Empty<CharacterBase>();
        }

        /// <summary>
        /// 当前控制角色切换的正式订阅入口。
        /// 外部只允许挂监听，不允许直接持有事件对象本体。
        /// </summary>
        public void AddCurrentControlledCharacterChangedListener(UnityAction<CharacterBase> listener)
        {
            m_currentControlledCharacterChanged.AddListener(listener);
        }

        public void RemoveCurrentControlledCharacterChangedListener(UnityAction<CharacterBase> listener)
        {
            m_currentControlledCharacterChanged.RemoveListener(listener);
        }

        private void ResolvePlayerInstance()
        {
            if (TryResolveNamedScenePlayer(out Hero namedScenePlayer) &&
                (!IsLoadedSceneHero(m_playerInstance) || IsLikelyTrainingDummy(m_playerInstance)))
            {
                m_playerInstance = namedScenePlayer;
                return;
            }

            if (IsLoadedSceneHero(m_playerInstance))
            {
                return;
            }

            Hero[] sceneHeroes = FindObjectsByType<Hero>(FindObjectsInactive.Exclude, FindObjectsSortMode.InstanceID);
            if (sceneHeroes.Length <= 0)
            {
                m_playerInstance = null;
                return;
            }

            if (sceneHeroes.Length > 1)
            {
                Debug.LogWarning(
                    $"[{nameof(PlayerSystem)}] Scene contains {sceneHeroes.Length} loaded Hero instances but no valid explicit player instance binding was available. " +
                    $"Falling back to the first loaded Hero ({sceneHeroes[0].name}). Assign m_playerInstance explicitly to avoid ambiguity.",
                    sceneHeroes[0]);
            }

            m_playerInstance = sceneHeroes[0];
        }

        private static bool TryResolveNamedScenePlayer(out Hero player)
        {
            Hero[] sceneHeroes = FindObjectsByType<Hero>(FindObjectsInactive.Exclude, FindObjectsSortMode.InstanceID);
            foreach (Hero hero in sceneHeroes)
            {
                if (hero != null && string.Equals(hero.name, "玩家角色", StringComparison.Ordinal))
                {
                    player = hero;
                    return true;
                }
            }

            player = null;
            return false;
        }

        private static bool IsLikelyTrainingDummy(Hero hero)
        {
            return hero != null && hero.name.Contains("训练假人", StringComparison.Ordinal);
        }

        private static bool IsLoadedSceneHero(Hero hero)
        {
            if (!hero)
            {
                return false;
            }

            UnityEngine.SceneManagement.Scene scene = hero.gameObject.scene;
            return scene.IsValid() && scene.isLoaded;
        }

        private void EnsurePlayerInstance()
        {
            ResolvePlayerInstance();

            if (!m_playerInstance)
            {
                throw new InvalidOperationException(
                    "PlayerSystem requires a valid player instance. Assign m_playerInstance explicitly or ensure at least one loaded Hero is available.");
            }
        }

        public void LoadDataBlock(PlayerDataBlock block)
        {
            EnsurePlayerInstance();
            StageControlledCharacterRestore(block);

            if (block?.heroData != null)
            {
                m_playerInstance.LoadHeroRuntimeState(block.heroData);
            }

            ResetCurrentControlToPlayerInstance();
            TryRestorePendingControlledCharacters();
        }

        public PlayerDataBlock CreateDataBlock()
        {
            EnsurePlayerInstance();

            CharacterBase[] controlledCharacters = CreateCurrentControlledCharacterSnapshot();
            return new PlayerDataBlock
            {
                heroData = m_playerInstance.CreateHeroRuntimeState(),
                currentControlledCharacters = CreateControlledCharacterReferenceSnapshot(controlledCharacters)
            };
        }

        /// <summary>
        /// 当前控制对象一旦被销毁，正式回退规则必须只留在 PlayerSystem 闭包内。
        /// 这样未来改成控制组、多 Hero 或世界角色接管时，不需要再去 UI、表现或交互层逐处补兜底。
        /// </summary>
        private void OnCurrentControlledCharacterDestroyed()
        {
            RevalidateCurrentControlledCharacter();
        }

        private void ResetCurrentControlToPlayerInstance()
        {
            SetCurrentControlledCharacter(m_playerInstance);
        }

        private bool TryRestorePendingPlayerControl()
        {
            if (!m_pendingPlayerControlRestore)
            {
                return false;
            }

            if (m_currentInputTarget != null)
            {
                m_pendingPlayerControlRestore = false;
                return true;
            }

            if (!TryResolveControllableInputTarget(m_playerInstance, out IPlayerInputTarget inputTarget))
            {
                return false;
            }

            SetCurrentInputTarget(inputTarget);
            m_pendingPlayerControlRestore = m_currentInputTarget == null;
            return m_currentInputTarget != null;
        }

        private void BindControlledCharacters(CharacterBase[] characters)
        {
            CharacterBase[] controlledCharacters = CreateControllableCharacterSnapshot(characters);
            if (AreSameControlledCharacters(m_boundControlledCharacters, controlledCharacters))
            {
                return;
            }

            foreach (CharacterBase boundCharacter in m_boundControlledCharacters)
            {
                if (boundCharacter != null)
                {
                    boundCharacter.RemoveDestroyedListener(OnCurrentControlledCharacterDestroyed);
                }
            }

            m_boundControlledCharacters.Clear();
            m_boundControlledCharacters.AddRange(controlledCharacters);
            m_boundControlledCharacter = controlledCharacters.Length > 0 ? controlledCharacters[0] : null;

            foreach (CharacterBase boundCharacter in m_boundControlledCharacters)
            {
                boundCharacter.AddDestroyedListener(OnCurrentControlledCharacterDestroyed);
            }
        }

        private void NotifyCurrentControlledTargetChanged()
        {
            CharacterBase currentControlledCharacter = GetCurrentControlledCharacter();
            m_currentControlledCharacterChanged.Invoke(currentControlledCharacter);
        }

        private void RefreshCurrentInputTargetFromControlGroup()
        {
            if (m_currentControlGroup == null)
            {
                return;
            }

            BindControlledCharacters(m_currentControlGroup.CreateControlledCharacterSnapshot());
            NotifyCurrentControlledTargetChanged();
        }

        private static PersistableReference<CharacterBase>[] CreateControlledCharacterReferenceSnapshot(CharacterBase[] characters)
        {
            if (characters == null || characters.Length == 0)
            {
                return Array.Empty<PersistableReference<CharacterBase>>();
            }

            List<PersistableReference<CharacterBase>> references = new();
            foreach (CharacterBase character in characters)
            {
                if (character == null)
                {
                    continue;
                }

                PersistableReference<CharacterBase> reference = character;
                if (string.IsNullOrWhiteSpace(reference.identifier))
                {
                    continue;
                }

                references.Add(reference);
            }

            return references.ToArray();
        }

        private CharacterBase GetCurrentControlledCharacter()
        {
            return m_currentInputTarget != null && m_currentInputTarget.TryGetControlledCharacter(out CharacterBase character)
                ? character
                : null;
        }

        private static CharacterBase[] CreateControllableCharacterSnapshot(CharacterBase[] characters)
        {
            if (characters == null || characters.Length == 0)
            {
                return Array.Empty<CharacterBase>();
            }

            List<CharacterBase> snapshot = new();
            foreach (CharacterBase character in characters)
            {
                if (!TryResolveControllableInputTarget(character, out IPlayerInputTarget _))
                {
                    continue;
                }

                if (!snapshot.Contains(character))
                {
                    snapshot.Add(character);
                }
            }

            return snapshot.ToArray();
        }

        private static bool TryResolveControllableInputTarget(CharacterBase character, out IPlayerInputTarget inputTarget)
        {
            inputTarget = null;
            return character != null &&
                character.TryResolvePlayerInputTarget(out inputTarget);
        }

        private CharacterBase ResolvePreferredControlGroupPrimary(CharacterBase[] controllableCharacters)
        {
            if (controllableCharacters == null || controllableCharacters.Length == 0)
            {
                return null;
            }

            CharacterBase currentControlledCharacter = GetCurrentControlledCharacter();
            if (currentControlledCharacter != null &&
                Array.IndexOf(controllableCharacters, currentControlledCharacter) >= 0)
            {
                return currentControlledCharacter;
            }

            return controllableCharacters[0];
        }

        private static bool AreSameControlledCharacters(
            IReadOnlyList<CharacterBase> currentCharacters,
            CharacterBase[] nextCharacters)
        {
            int currentCount = currentCharacters?.Count ?? 0;
            int nextCount = nextCharacters?.Length ?? 0;
            if (currentCount != nextCount)
            {
                return false;
            }

            for (int i = 0; i < currentCount; i++)
            {
                if (currentCharacters[i] != nextCharacters[i])
                {
                    return false;
                }
            }

            return true;
        }
    }
}
