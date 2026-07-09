using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 地图、检查点和传送的运行时真相源。
    /// 它统一负责地图状态、出生点、检查点顺序和重生节奏。
    /// </summary>
    public class MapSystem : AGameSystem, IDataBlockHandler<MapDataBlock>
    {
        private string m_currentMap = string.Empty;
        private Stack<ICheckpoint> m_checkpointStack;
        private MapInfo m_activeMapInfo;
        private readonly List<MapInfo> m_registeredMapInfos = new();
        private bool m_hasOrderedCheckpoint;
        private int m_currentCheckpointOrder = int.MinValue;
        private Coroutine m_respawnCoroutine;

        public override void OnSystemInit()
        {
            m_checkpointStack ??= new Stack<ICheckpoint>();
        }

        public override void OnSystemStart()
        {
            RefreshActiveMapInfoFromRegisteredInfos();
        }

        public override void OnMapLoaded()
        {
            RefreshActiveMapInfoFromRegisteredInfos();
        }

        public override void OnMapUnloaded()
        {
            m_activeMapInfo = null;
        }

        public void SetActiveMap(string map)
        {
            SceneManager.SetActiveScene(
                SceneManager.GetSceneByName(
                    map
                )
            );

            m_currentMap = map ?? string.Empty;
            RefreshActiveMapInfoFromRegisteredInfos();
        }

        /// <summary>
        /// 正式登记当前场景可用的 MapInfo。
        /// 地图配置真相仍然属于场景里的 MapInfo 组件，但“当前活动地图配置是哪一个”必须由 MapSystem 统一缓存。
        /// </summary>
        public void RegisterActiveMapInfo(MapInfo mapInfo)
        {
            if (mapInfo == null)
            {
                return;
            }

            if (!m_registeredMapInfos.Contains(mapInfo))
            {
                m_registeredMapInfos.Add(mapInfo);
            }

            RefreshActiveMapInfoFromRegisteredInfos();
        }

        public void UnregisterActiveMapInfo(MapInfo mapInfo)
        {
            if (mapInfo == null)
            {
                return;
            }

            m_registeredMapInfos.Remove(mapInfo);

            if (ReferenceEquals(m_activeMapInfo, mapInfo))
            {
                m_activeMapInfo = null;
            }

            RefreshActiveMapInfoFromRegisteredInfos();
        }

        public void SaveCheckpoint(ICheckpoint checkpoint)
        {
            SaveCheckpoint(checkpoint, int.MinValue, true);
        }

        /// <summary>
        /// 保存当前重生点。带顺序的入口用于场景触发器，保留 TopDown CheckPoint 的“只向前推进”体验。
        /// </summary>
        public void SaveCheckpoint(ICheckpoint checkpoint, int checkpointOrder, bool forceAssignation = false)
        {
            Debug.Assert(checkpoint != null && checkpoint.IsValid(), "Invalid checkpoint data! The checkpoint will not be saved.");
            if (checkpoint == null || !checkpoint.IsValid())
            {
                return;
            }

            if (!forceAssignation && m_hasOrderedCheckpoint && checkpointOrder < m_currentCheckpointOrder)
            {
                Debug.Log($"Skipping checkpoint order {checkpointOrder}; current checkpoint order is {m_currentCheckpointOrder}.");
                return;
            }

            checkpoint.UpdateMapName();
            Debug.Log($"Saving checkpoint from map '{checkpoint.map}' at position: {checkpoint.position}...");
            m_checkpointStack.Push(checkpoint);
            m_hasOrderedCheckpoint = true;
            m_currentCheckpointOrder = checkpointOrder;
        }

        public string GetCurrentMapName()
        {
            return m_currentMap;
        }

        public bool HasCurrentMap()
        {
            return m_currentMap != string.Empty;
        }

        public void RequestTransition(string map, Action onMapUnloaded = null, Action onMapLoaded = null, Action onCompletion = null)
        {
            GameRuntimeEvents.NotifyMapTransitionStarted();
            Debug.Assert(
                GameManager.TransitionSystem != null && GameManager.TransitionSystem.isActiveAndEnabled,
                "Map transitions require an active TransitionSystem. The direct MapSystem transition fallback has been removed.");
            DelegateTransition(map, onMapUnloaded, onMapLoaded, onCompletion);
        }

        public void RespawnPlayer()
        {
            if (m_respawnCoroutine != null)
            {
                return;
            }

            m_respawnCoroutine = StartCoroutine(RespawnPlayerCoroutine());
        }

        internal ICheckpoint FindValidCheckpoint()
        {
            while (m_checkpointStack.Count > 0)
            {
                ICheckpoint checkpoint = m_checkpointStack.Peek();

                if (checkpoint.IsValid())
                {
                    return checkpoint;
                }

                Debug.LogWarning("Invalid checkpoint data found! Skipping...");
                m_checkpointStack.Pop();
            }

            return null;
        }

        internal ICheckpoint FindPlaytestCheckpoint()
        {
            MapInfo mapInfo = ResolveActiveMapInfo();
            ICheckpoint checkpoint = null;
            Debug.Assert(mapInfo != null, "No MapInfo object found in the scene! Did you forget to add one?");
            Debug.Assert(mapInfo != null && mapInfo.TryGetPlaytestCheckpoint(out checkpoint), "Invalid playtest checkpoint data! Did you forget to set it?");
            Debug.Assert(checkpoint != null && string.IsNullOrEmpty(checkpoint.map), "Playtest checkpoint should not have a map set, as the current map should be used!");
            return checkpoint;
        }

        internal ICheckpoint FindInitialSpawnCheckpoint()
        {
            MapInfo mapInfo = ResolveActiveMapInfo();
            return mapInfo != null && mapInfo.TryGetInitialSpawnCheckpoint(out ICheckpoint checkpoint) ? checkpoint : null;
        }

        /// <summary>
        /// 当前活动地图配置只允许从正式登记过的 MapInfo 集合里选出，
        /// 不再靠场景树扫描补真相。
        /// </summary>
        internal void RefreshActiveMapInfoFromRegisteredInfos()
        {
            Scene trackedScene = ResolveTrackedScene();
            if (!trackedScene.IsValid() || !trackedScene.isLoaded)
            {
                m_activeMapInfo = null;
                return;
            }

            m_registeredMapInfos.RemoveAll(static mapInfo => mapInfo == null);
            m_activeMapInfo = m_registeredMapInfos.Find(mapInfo => mapInfo.gameObject.scene == trackedScene);
        }

        internal MapInfo ResolveActiveMapInfo()
        {
            if (m_activeMapInfo == null)
            {
                RefreshActiveMapInfoFromRegisteredInfos();
            }

            return m_activeMapInfo;
        }

        private Scene ResolveTrackedScene()
        {
            if (HasCurrentMap())
            {
                Scene currentMapScene = SceneManager.GetSceneByName(GetCurrentMapName());
                if (currentMapScene.IsValid())
                {
                    return currentMapScene;
                }
            }

            return SceneManager.GetActiveScene();
        }

        internal float GetRespawnDelay()
        {
            return m_activeMapInfo != null ? m_activeMapInfo.respawnDelay : 0f;
        }

        /// <summary>
        /// 吸收 uMMORPG `Database.CharacterLoad()` 的出生点健壮性规则：
        /// 读档进入当前地图后，如果保存位置对当前 2D 碰撞闭包已不合法，就回退到本地图正式初始出生点，
        /// 而不是依赖后续角色更新去碰运气脱墙。
        /// </summary>
        internal void EnsureTraversalHeroValidSpawnOnActiveMap()
        {
            Hero traversalHero = GetTraversalHero();
            if (traversalHero == null)
            {
                return;
            }

            if (traversalHero.IsValidSpawnPoint(traversalHero.transform.position))
            {
                return;
            }

            ICheckpoint checkpoint = FindInitialSpawnCheckpoint();
            Debug.Assert(checkpoint != null && checkpoint.IsValid(), "Saved player position is invalid, but the active MapInfo has no valid initial spawn checkpoint.");
            if (checkpoint == null || !checkpoint.IsValid())
            {
                Debug.LogWarning("Saved player position is invalid and no valid initial spawn checkpoint is configured on the active MapInfo.");
                return;
            }

            SaveCheckpoint(checkpoint);
            traversalHero.TeleportTo(checkpoint.position);
        }

        /// <summary>
        /// 当前地图传送与重生仍绑定玩家存档 Hero。
        /// 在队伍控制和世界角色实体彻底拆开前，不能让“谁触发世界穿越”与“谁被传送/复活”分别落在两套真相上。
        /// </summary>
        internal Hero GetTraversalHero()
        {
            return GameManager.PlayerSystem.GetPlayerInstance();
        }

        public void TeleportTo(ICheckpoint checkpoint, Action onMapLoaded = null, Action onCompletion = null)
        {
            Debug.Assert(checkpoint != null && checkpoint.IsValid(), "Invalid checkpoint data!");
            if (checkpoint == null || !checkpoint.IsValid())
            {
                return;
            }

            Hero traversalHero = GetTraversalHero();
            Debug.Assert(traversalHero != null, "No traversal hero available. The player instance must exist before teleporting.");
            if (traversalHero == null)
            {
                return;
            }

            RequestTransition(checkpoint.map, null, () =>
            {
                traversalHero.TeleportTo(checkpoint.position);
                onMapLoaded?.Invoke();
            }, onCompletion);
        }

        public void TeleportToInitialSpawnPosition(string map, Action onCompletion = null)
        {
            RequestTransition(map, null, () =>
            {
                ICheckpoint checkpoint = FindInitialSpawnCheckpoint();
                Debug.Assert(checkpoint != null && checkpoint.IsValid(), "No valid initial spawn checkpoint found in the active MapInfo.");
                if (checkpoint == null || !checkpoint.IsValid())
                {
                    return;
                }

                Hero traversalHero = GetTraversalHero();
                Debug.Assert(traversalHero != null, "No traversal hero available. The player instance must exist before teleporting.");
                if (traversalHero == null)
                {
                    return;
                }

                SaveCheckpoint(checkpoint);
                traversalHero.TeleportTo(checkpoint.position);
            }, onCompletion);
        }

        public void TeleportToPlaytestStartPosition(string map, Action onCompletion = null)
        {
            RequestTransition(map, null, () =>
            {
                ICheckpoint checkpoint = FindPlaytestCheckpoint();
                Hero traversalHero = GetTraversalHero();
                Debug.Assert(traversalHero != null, "No traversal hero available. The player instance must exist before teleporting.");
                if (traversalHero == null)
                {
                    return;
                }

                SaveCheckpoint(checkpoint);
                traversalHero.TeleportTo(checkpoint.position);
            }, onCompletion);
        }

        public MapDataBlock CreateDataBlock()
        {
            return new MapDataBlock
            {
                currentMap = m_currentMap,
                checkpoints = m_checkpointStack.ToArray(),
                hasOrderedCheckpoint = m_hasOrderedCheckpoint,
                currentCheckpointOrder = m_currentCheckpointOrder,
            };
        }

        public void LoadDataBlock(MapDataBlock block)
        {
            ICheckpoint[] checkpoints = block?.checkpoints ?? Array.Empty<ICheckpoint>();
            m_checkpointStack = new Stack<ICheckpoint>(checkpoints.Reverse());
            m_hasOrderedCheckpoint = block?.hasOrderedCheckpoint ?? false;
            m_currentCheckpointOrder = m_hasOrderedCheckpoint ? block.currentCheckpointOrder : int.MinValue;
            m_currentMap = block?.currentMap ?? string.Empty;

            if (block.playtest)
            {
                TeleportToPlaytestStartPosition(block.currentMap);
            }
            else
            {
                bool isFirstTimePlaying = string.IsNullOrEmpty(block.currentMap);

                if (isFirstTimePlaying)
                {
                    ICheckpoint checkpoint = FindValidCheckpoint();
                    Debug.Assert(checkpoint != null, "No valid checkpoint set in the save file! Did you forget to add one or specify a valid map & identifier?");
                    TeleportTo(checkpoint);
                }
                else
                {
                    RequestTransition(block.currentMap, null, EnsureTraversalHeroValidSpawnOnActiveMap);
                }
            }
        }

        private IEnumerator RespawnPlayerCoroutine()
        {
            ICheckpoint checkpoint = FindValidCheckpoint();
            Debug.Assert(checkpoint != null && checkpoint.IsValid(), "No valid checkpoint found! The player cannot respawn.");
            if (checkpoint == null || !checkpoint.IsValid())
            {
                m_respawnCoroutine = null;
                yield break;
            }

            float delay = GetRespawnDelay();
            if (delay > 0f)
            {
                yield return new WaitForSeconds(delay);
            }

            Hero traversalHero = GetTraversalHero();
            Debug.Assert(traversalHero != null, "No traversal hero available. The player instance must exist before respawning.");
            if (traversalHero == null)
            {
                m_respawnCoroutine = null;
                yield break;
            }

            TeleportTo(checkpoint, traversalHero.Revive);
            m_respawnCoroutine = null;
        }

        private void DelegateTransition(string map, Action onMapUnloaded = null, Action onMapLoaded = null, Action onCompletion = null)
        {
            Action<Action> unloadAction =
                HasCurrentMap() && GetCurrentMapName() != map && !string.IsNullOrEmpty(map) ?
                (callback) => UnloadMap(GetCurrentMapName(), callback + onMapUnloaded) :
                (callback) =>
                {
                    callback?.Invoke();
                    onMapUnloaded?.Invoke();
                };

            Action<Action> loadAction =
                !string.IsNullOrEmpty(map) ?
                (callback) => LoadMap(map, () =>
                {
                    callback?.Invoke();
                    onMapLoaded?.Invoke();
                }) :
                (callback) =>
                {
                    callback?.Invoke();
                    onMapLoaded?.Invoke();
                };

            Action completeAction =
                () => CompleteTransition(onCompletion);

            GameRuntimeEvents.NotifyMapTransitionDelegationRequested(new MapLoadingDelegationParams
            {
                unloadDelegate = unloadAction,
                loadDelegate = loadAction,
                completionDelegate = completeAction
            });
        }

        private void UnloadMap(string map, Action onCompletion)
        {
            if (!string.IsNullOrEmpty(map) && map == GetCurrentMapName())
            {
                Debug.Log($"Unloading Map {map}...");

                GameRuntimeEvents.NotifyMapUnloading();

                AsyncOperation operation = SceneManager.UnloadSceneAsync(map);

                operation.completed += _ =>
                {
                    GameRuntimeEvents.NotifyMapUnloaded();
                    onCompletion?.Invoke();
                };
            }
            else
            {
                GameRuntimeEvents.NotifyMapUnloaded();
                onCompletion?.Invoke();
            }
        }

        private void LoadMap(string map, Action onCompletion)
        {
            if (!string.IsNullOrEmpty(map) && map != GetCurrentMapName())
            {
                Debug.Log($"Loading Map {map}...");

                GameRuntimeEvents.NotifyMapLoading();

                AsyncOperation operation = SceneManager.LoadSceneAsync(map, LoadSceneMode.Additive);

                operation.completed += _ =>
                {
                    SetActiveMap(map);
                    GameRuntimeEvents.NotifyMapLoaded();
                    onCompletion?.Invoke();
                };
            }
            else
            {
                RefreshActiveMapInfoFromRegisteredInfos();
                GameRuntimeEvents.NotifyMapLoaded();
                onCompletion?.Invoke();
            }
        }

        private void CompleteTransition(Action onCompletion)
        {
            GameRuntimeEvents.NotifyMapTransitionCompleted();
            onCompletion?.Invoke();
        }
    }
}
