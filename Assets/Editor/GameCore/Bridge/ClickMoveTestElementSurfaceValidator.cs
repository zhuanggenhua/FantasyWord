#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using UnityEditor;
using UnityEngine;
using UnityEngine.Tilemaps;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// ClickMoveTest 的元素地表 PlayMode 验证入口。
    /// 只通过 ElementReactionSystem 施加 Fire，并检查地表状态、表现层、燃烧伤害和燃尽结果。
    /// </summary>
    public static class ClickMoveTestElementSurfaceValidator
    {
        private const int MaxStartupFrames = 180;
        private const int MaxBurningObservationFrames = 240;
        private const int MaxExpirationObservationFrames = 900;
        private const int ScreenshotDelayFrames = 2;
        private const string ResultRelativePath =
            "Temp/UnityBridge/results/clickmove-element-surface-runtime.json";
        private const string ReapplyResultRelativePath =
            "Temp/UnityBridge/results/clickmove-element-surface-reapply.json";
        private const string BurningScreenshotRelativePath =
            "Assets/Screenshots/ElementSurfaceE2E/clickmove-element-surface-burning.png";
        private const string ExpiredScreenshotRelativePath =
            "Assets/Screenshots/ElementSurfaceE2E/clickmove-element-surface-expired.png";

        private static ValidationResult? s_result;
        private static bool s_running;
        private static int s_startedFrame;
        private static int s_fireAppliedFrame;
        private static int s_burningScreenshotFrame;
        private static int s_expiredScreenshotFrame;
        private static bool s_fireApplied;
        private static bool s_burningScreenshotRequested;
        private static bool s_expiredScreenshotRequested;
        private static CharacterBase? s_player;
        private static TerrainNavigationMap? s_navigationMap;
        private static ElementReactionSystem? s_reactionSystem;
        private static TerrainSurfaceDamageSystem? s_damageSystem;
        private static TerrainSurfacePresentation? s_presentation;
        private static Vector3Int s_targetCell;
        private static Vector3 s_targetWorld;
        private static int s_initialPlayerHealth;
        private static int s_latestPlayerHealth;

        public static string ResultPath => Path.GetFullPath(ResultRelativePath);
        public static string ReapplyResultPath => Path.GetFullPath(ReapplyResultRelativePath);
        public static string BurningScreenshotPath => Path.GetFullPath(BurningScreenshotRelativePath);
        public static string ExpiredScreenshotPath => Path.GetFullPath(ExpiredScreenshotRelativePath);

        [MenuItem("Tools/FantasyWord/Validation/Start ClickMoveTest Element Surface Validator")]
        public static void StartFromMenu()
        {
            Start();
        }

        public static string Start()
        {
            if (!Application.isPlaying)
            {
                WriteResult(Fail("元素地表验证只能在 PlayMode 下启动。"));
                return ResultPath;
            }

            s_result = new ValidationResult
            {
                ScenePath = UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,
                ScreenSize = $"{Screen.width}x{Screen.height}",
                StartFrame = Time.frameCount
            };
            s_running = true;
            s_startedFrame = Time.frameCount;
            s_fireAppliedFrame = 0;
            s_burningScreenshotFrame = 0;
            s_expiredScreenshotFrame = 0;
            s_fireApplied = false;
            s_burningScreenshotRequested = false;
            s_expiredScreenshotRequested = false;
            s_player = null;
            s_navigationMap = null;
            s_reactionSystem = null;
            s_damageSystem = null;
            s_presentation = null;
            s_targetCell = default;
            s_targetWorld = default;
            s_initialPlayerHealth = 0;
            s_latestPlayerHealth = 0;

            EditorApplication.update -= Tick;
            EditorApplication.update += Tick;
            return ResultPath;
        }

        public static string ProbeReapplyFireToLastTarget()
        {
            ReapplyProbeResult result = new()
            {
                ScenePath = UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,
                Frame = Time.frameCount
            };

            try
            {
                if (!Application.isPlaying)
                {
                    throw new InvalidOperationException("防复燃探针只能在 PlayMode 下运行。");
                }

                TerrainNavigationMap navigationMap =
                    s_navigationMap != null
                        ? s_navigationMap
                        : UnityEngine.Object.FindFirstObjectByType<TerrainNavigationMap>(
                            FindObjectsInactive.Include);
                ElementReactionSystem reactionSystem =
                    s_reactionSystem != null
                        ? s_reactionSystem
                        : UnityEngine.Object.FindFirstObjectByType<ElementReactionSystem>(
                            FindObjectsInactive.Include);

                if (navigationMap == null)
                {
                    throw new InvalidOperationException("防复燃探针缺少 TerrainNavigationMap。");
                }

                if (reactionSystem == null)
                {
                    throw new InvalidOperationException("防复燃探针缺少 ElementReactionSystem。");
                }

                Vector3Int targetCell = s_targetCell;
                Vector3 targetWorld = s_targetWorld;
                if (s_result != null)
                {
                    result.RuntimeE2ESuccess = s_result.Success;
                    result.RuntimeE2ECompleted = s_result.Completed;
                    if (targetCell == default)
                    {
                        targetCell = ParseVector3Int(s_result.TargetCell);
                    }

                    if (targetWorld == default)
                    {
                        targetWorld = ParseVector3(s_result.TargetWorld);
                    }
                }

                if (!navigationMap.TryGetSurfaceSample(targetCell, out TerrainSurfaceSample before))
                {
                    throw new InvalidOperationException($"防复燃探针无法读取目标格：{targetCell}。");
                }

                result.TargetCell = Format(targetCell);
                result.TargetWorld = Format(targetWorld);
                result.BeforeRuntimeState = before.RuntimeState.ToString();
                result.BeforeEffectiveSurface = before.EffectiveSurface.ToString();
                result.BeforeEffectiveSurfaceCover = before.EffectiveSurfaceCover.ToString();
                result.BeforeSurfaceCoverLifecycle = before.SurfaceCoverLifecycle.ToString();

                ElementApplication application = new(
                    EWorldElementKind.Fire,
                    1.0f,
                    0.2f,
                    ElementArea.Point(),
                    targetWorld,
                    Vector2.right);
                result.FireApplyReturned = reactionSystem.Apply(application);

                if (!navigationMap.TryGetSurfaceSample(targetCell, out TerrainSurfaceSample after))
                {
                    throw new InvalidOperationException($"防复燃探针无法读取施火后目标格：{targetCell}。");
                }

                result.AfterRuntimeState = after.RuntimeState.ToString();
                result.AfterEffectiveSurface = after.EffectiveSurface.ToString();
                result.AfterEffectiveSurfaceCover = after.EffectiveSurfaceCover.ToString();
                result.AfterSurfaceCoverLifecycle = after.SurfaceCoverLifecycle.ToString();
                result.Success =
                    result.RuntimeE2ECompleted &&
                    result.RuntimeE2ESuccess &&
                    before.EffectiveSurface == ETerrainSurfaceKind.Dirt &&
                    before.EffectiveSurfaceCover == ETerrainSurfaceCoverKind.None &&
                    before.SurfaceCoverLifecycle == ETerrainSurfaceCoverLifecycle.Removed &&
                    !result.FireApplyReturned &&
                    after.EffectiveSurface == ETerrainSurfaceKind.Dirt &&
                    after.EffectiveSurfaceCover == ETerrainSurfaceCoverKind.None &&
                    after.SurfaceCoverLifecycle == ETerrainSurfaceCoverLifecycle.Removed &&
                    (after.RuntimeState & ETerrainRuntimeSurfaceState.Burning) == 0;
                result.Message = result.Success
                    ? "防复燃探针通过：草覆盖移除后，同格 Fire 不再匹配 Grass 覆盖燃烧规则。"
                    : "防复燃探针失败：草覆盖移除后再次施火仍发生了状态变化。";
            }
            catch (Exception exception)
            {
                result.Success = false;
                result.Message = exception.ToString();
            }

            Directory.CreateDirectory(Path.GetDirectoryName(ReapplyResultPath)!);
            File.WriteAllText(ReapplyResultPath, JsonUtility.ToJson(result, true));
            return ReapplyResultPath;
        }

        private static void Tick()
        {
            if (!s_running || s_result == null)
            {
                StopTicking();
                return;
            }

            if (!Application.isPlaying)
            {
                WriteAndStop(Fail("元素地表验证过程中 PlayMode 已退出。"));
                return;
            }

            try
            {
                if (!s_fireApplied)
                {
                    if (!TryResolveRuntimeObjects(s_result))
                    {
                        if (Time.frameCount - s_startedFrame > MaxStartupFrames)
                        {
                            FinalizeResult(s_result, "等待元素地表运行时对象初始化超时。");
                        }

                        return;
                    }

                    ApplyFireToGrassCoverCell(s_result);
                    return;
                }

                ObserveBurningPhase(s_result);
                if (!s_burningScreenshotRequested &&
                    s_result.BurningStateObserved &&
                    s_result.TemporaryFireTileObserved)
                {
                    RequestScreenshot(s_result, BurningScreenshotRelativePath, BurningScreenshotPath, burning: true);
                    return;
                }

                ObserveExpirationPhase(s_result);
                if (s_result.BurningClearedObserved &&
                    s_result.GrassCoverRemovedAndDirtRevealed &&
                    !s_expiredScreenshotRequested)
                {
                    RequestScreenshot(s_result, ExpiredScreenshotRelativePath, ExpiredScreenshotPath, burning: false);
                    return;
                }

                if (s_expiredScreenshotRequested &&
                    Time.frameCount - s_expiredScreenshotFrame >= ScreenshotDelayFrames)
                {
                    FinalizeResult(s_result, string.Empty);
                    return;
                }

                if (Time.frameCount - s_fireAppliedFrame > MaxExpirationObservationFrames)
                {
                    FinalizeResult(s_result, "等待 Burning 燃尽、草覆盖移除并露出底层 Dirt 超时。");
                }
            }
            catch (Exception exception)
            {
                WriteAndStop(Fail(exception.ToString()));
            }
        }

        private static bool TryResolveRuntimeObjects(ValidationResult result)
        {
            result.GameManagerExists = GameManager.Exists();
            result.HasPlayerSystem = result.GameManagerExists && GameManager.HasSystem<PlayerSystem>();
            result.HasElementReactionSystem =
                result.GameManagerExists &&
                GameManager.TryGetSystem(out s_reactionSystem) &&
                s_reactionSystem != null;
            result.HasTerrainSurfaceDamageSystem =
                result.GameManagerExists &&
                GameManager.TryGetSystem(out s_damageSystem) &&
                s_damageSystem != null;

            if (result.HasPlayerSystem)
            {
                s_player = GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
            }

            if (s_player == null)
            {
                s_player = FindFirstActiveCharacter();
            }

            result.PlayerName = s_player != null ? s_player.name : "null";
            if (s_player != null)
            {
                result.PlayerPositionBefore = Format(s_player.transform.position);
            }

            s_navigationMap = ResolveActiveTerrainNavigationMap();
            result.HasTerrainNavigationMap = s_navigationMap != null;
            result.RuleTilemapName = s_navigationMap != null && s_navigationMap.RuleTilemap != null
                ? s_navigationMap.RuleTilemap.name
                : "null";

            s_presentation = UnityEngine.Object.FindFirstObjectByType<TerrainSurfacePresentation>(
                FindObjectsInactive.Exclude);
            result.HasTerrainSurfacePresentation = s_presentation != null;
            if (s_presentation != null)
            {
                result.HasTemporaryEffectTilemap =
                    TryGetPrivateField(s_presentation, "m_temporaryEffectTilemap", out Tilemap? temp) &&
                    temp != null;
                result.TemporaryEffectTilemapName = temp != null ? temp.name : "null";
            }

            return s_player != null &&
                   s_navigationMap != null &&
                   s_reactionSystem != null &&
                   s_damageSystem != null &&
                   s_presentation != null &&
                   result.HasTemporaryEffectTilemap;
        }

        private static void ApplyFireToGrassCoverCell(ValidationResult result)
        {
            if (s_player == null || s_navigationMap == null || s_reactionSystem == null)
            {
                FinalizeResult(result, "元素地表验证缺少玩家、地形地图或元素反应系统。");
                return;
            }

            if (!TryFindGrassCoverCellNearPlayer(s_navigationMap, s_player.transform.position, out s_targetCell))
            {
                FinalizeResult(result, "ClickMoveTest 中没有找到可用于验证的 Dirt 底层 + Grass 上层覆盖格。");
                return;
            }

            s_targetWorld = s_navigationMap.RuleTilemap.GetCellCenterWorld(s_targetCell);
            PositionPlayerForDamageProbe(s_player, s_targetWorld);
            EnsurePlayerCanTakeBurningDamage(s_player, result);
            s_initialPlayerHealth = s_player.GetCurrentHealth();
            s_latestPlayerHealth = s_initialPlayerHealth;

            TerrainSurfaceSample beforeSample = ReadRequiredSample(s_targetCell);
            result.TargetCell = Format(s_targetCell);
            result.TargetWorld = Format(s_targetWorld);
            result.PlayerPositionAfterPlacement = Format(s_player.transform.position);
            result.InitialPlayerHealth = s_initialPlayerHealth;
            result.BaseSurfaceBefore = beforeSample.BaseSurface.ToString();
            result.EffectiveSurfaceBefore = beforeSample.EffectiveSurface.ToString();
            result.BaseSurfaceCoverBefore = beforeSample.BaseSurfaceCover.ToString();
            result.EffectiveSurfaceCoverBefore = beforeSample.EffectiveSurfaceCover.ToString();
            result.SurfaceCoverLifecycleBefore = beforeSample.SurfaceCoverLifecycle.ToString();
            result.BaseTraversalCostBefore = beforeSample.BaseTraversalCost;
            result.EffectiveTraversalCostBefore = beforeSample.EffectiveTraversalCost;

            ElementApplication application = new(
                EWorldElementKind.Fire,
                1.0f,
                0.2f,
                ElementArea.Point(),
                s_targetWorld,
                Vector2.right,
                s_player,
                0);
            result.FireApplyReturned = s_reactionSystem.Apply(application);
            s_fireApplied = true;
            s_fireAppliedFrame = Time.frameCount;
            result.FireAppliedFrame = s_fireAppliedFrame;
            result.Trace.Add(
                $"frame={Time.frameCount}, apply Fire to cell={result.TargetCell}, world={result.TargetWorld}, returned={result.FireApplyReturned}");
        }

        private static void EnsurePlayerCanTakeBurningDamage(
            CharacterBase player,
            ValidationResult result)
        {
            int healthBeforeRecovery = player.GetCurrentHealth();
            int maxHealthBeforeRecovery = player.GetMaxHealth();
            result.PlayerHealthBeforeRecovery = healthBeforeRecovery;
            result.PlayerMaxHealthBeforeRecovery = maxHealthBeforeRecovery;

            if (healthBeforeRecovery > 0)
            {
                result.PlayerHealthAfterRecovery = healthBeforeRecovery;
                result.PlayerHealthRecoveredForDamageProbe = false;
                result.Trace.Add(
                    $"frame={Time.frameCount}, player already damageable, health={healthBeforeRecovery}, maxHealth={maxHealthBeforeRecovery}");
                return;
            }

            if (maxHealthBeforeRecovery <= 0)
            {
                result.PlayerHealthAfterRecovery = healthBeforeRecovery;
                result.PlayerHealthRecoveryFailure =
                    "玩家当前生命和最大生命都不是正数，无法通过正式生命入口恢复到可受伤状态。";
                result.Trace.Add(
                    $"frame={Time.frameCount}, player is not damageable, health={healthBeforeRecovery}, maxHealth={maxHealthBeforeRecovery}");
                return;
            }

            player.Heal(maxHealthBeforeRecovery, EEffectVisualFlags.NoFloatingText);
            result.PlayerHealthAfterRecovery = player.GetCurrentHealth();
            result.PlayerHealthRecoveredForDamageProbe =
                result.PlayerHealthAfterRecovery > healthBeforeRecovery;
            result.Trace.Add(
                $"frame={Time.frameCount}, recovered player for damage probe, health={healthBeforeRecovery}->{result.PlayerHealthAfterRecovery}, maxHealth={maxHealthBeforeRecovery}");
        }

        private static void ObserveBurningPhase(ValidationResult result)
        {
            if (s_navigationMap == null || s_player == null)
            {
                return;
            }

            TerrainSurfaceSample sample = ReadRequiredSample(s_targetCell);
            bool isBurning = (sample.RuntimeState & ETerrainRuntimeSurfaceState.Burning) != 0;
            if (isBurning)
            {
                result.RuntimeStateDuringBurning = sample.RuntimeState.ToString();
                result.EffectiveSurfaceDuringBurning = sample.EffectiveSurface.ToString();
                result.EffectiveSurfaceCoverDuringBurning = sample.EffectiveSurfaceCover.ToString();
                result.EffectiveTraversalCostDuringBurning = sample.EffectiveTraversalCost;
                result.RuntimeStateCountDuringBurning = s_navigationMap.RuntimeStateCount;
            }

            if (!result.BurningStateObserved &&
                isBurning)
            {
                result.BurningStateObserved = true;
                result.BurningObservedFrame = Time.frameCount;
                result.Trace.Add($"frame={Time.frameCount}, Burning state observed.");
            }

            if (!result.TraversalCostIncreasedDuringBurning &&
                isBurning &&
                sample.EffectiveTraversalCost > sample.BaseTraversalCost + 0.0001f)
            {
                result.TraversalCostIncreasedDuringBurning = true;
                result.Trace.Add(
                    $"frame={Time.frameCount}, traversal cost {sample.BaseTraversalCost:0.###}->{sample.EffectiveTraversalCost:0.###}");
            }

            ReadPresentationTiles(
                s_targetCell,
                out string temporaryTileName,
                out string resultTileName,
                out bool hasTemporaryTile,
                out bool hasResultTile);
            if (isBurning)
            {
                result.TemporaryTileDuringBurning = temporaryTileName;
                result.ResultTileDuringBurning = resultTileName;
            }

            if (!result.TemporaryFireTileObserved && hasTemporaryTile)
            {
                result.TemporaryFireTileObserved = true;
                result.TemporaryFireTileObservedFrame = Time.frameCount;
                result.Trace.Add(
                    $"frame={Time.frameCount}, temporary fire tile observed: {temporaryTileName}");
            }

            if (isBurning && hasResultTile)
            {
                result.UnexpectedResultTileDuringBurning = true;
            }

            s_latestPlayerHealth = s_player.GetCurrentHealth();
            result.LatestPlayerHealth = s_latestPlayerHealth;
            if (!result.PlayerTookBurningDamage &&
                s_latestPlayerHealth < s_initialPlayerHealth)
            {
                result.PlayerTookBurningDamage = true;
                result.PlayerDamageObservedFrame = Time.frameCount;
                result.Trace.Add(
                    $"frame={Time.frameCount}, player health {s_initialPlayerHealth}->{s_latestPlayerHealth}");
            }

            if (Time.frameCount - s_fireAppliedFrame > MaxBurningObservationFrames &&
                (!result.BurningStateObserved || !result.TemporaryFireTileObserved))
            {
                FinalizeResult(result, "等待 Burning 状态或火焰表现层出现超时。");
            }
        }

        private static void ObserveExpirationPhase(ValidationResult result)
        {
            if (s_navigationMap == null || !s_fireApplied)
            {
                return;
            }

            TerrainSurfaceSample sample = ReadRequiredSample(s_targetCell);
            if (result.BurningStateObserved &&
                !result.BurningClearedObserved &&
                (sample.RuntimeState & ETerrainRuntimeSurfaceState.Burning) == 0)
            {
                result.BurningClearedObserved = true;
                result.BurningClearedFrame = Time.frameCount;
                result.Trace.Add($"frame={Time.frameCount}, Burning state cleared.");
            }

            ReadPresentationTiles(
                s_targetCell,
                out string temporaryTileName,
                out string resultTileName,
                out bool hasTemporaryTile,
                out bool hasResultTile);
            result.RuntimeStateAfterExpiration = sample.RuntimeState.ToString();
            result.EffectiveSurfaceAfterExpiration = sample.EffectiveSurface.ToString();
            result.EffectiveSurfaceCoverAfterExpiration = sample.EffectiveSurfaceCover.ToString();
            result.SurfaceCoverLifecycleAfterExpiration = sample.SurfaceCoverLifecycle.ToString();
            result.EffectiveTraversalCostAfterExpiration = sample.EffectiveTraversalCost;
            result.RuntimeStateCountAfterExpiration = s_navigationMap.RuntimeStateCount;
            result.TemporaryTileAfterExpiration = temporaryTileName;
            result.ResultTileAfterExpiration = resultTileName;
            result.TemporaryTileClearedAfterExpiration = !hasTemporaryTile;
            result.NoResultOverrideTileAfterExpiration = !hasResultTile;

            if (!result.GrassCoverRemovedAndDirtRevealed &&
                sample.BaseSurface == ETerrainSurfaceKind.Dirt &&
                sample.EffectiveSurface == ETerrainSurfaceKind.Dirt &&
                sample.BaseSurfaceCover == ETerrainSurfaceCoverKind.Grass &&
                sample.EffectiveSurfaceCover == ETerrainSurfaceCoverKind.None &&
                sample.SurfaceCoverLifecycle == ETerrainSurfaceCoverLifecycle.Removed)
            {
                result.GrassCoverRemovedAndDirtRevealed = true;
                result.GrassCoverRemovedFrame = Time.frameCount;
                result.Trace.Add(
                    $"frame={Time.frameCount}, grass cover removed and base Dirt revealed, resultTile={resultTileName}");
            }
        }

        private static bool TryFindGrassCoverCellNearPlayer(
            TerrainNavigationMap navigationMap,
            Vector3 playerPosition,
            out Vector3Int grassCoverCell)
        {
            grassCoverCell = default;
            Tilemap ruleTilemap = navigationMap.RuleTilemap;
            if (ruleTilemap == null)
            {
                return false;
            }

            BoundsInt bounds = ruleTilemap.cellBounds;
            Vector3Int playerCell = ruleTilemap.WorldToCell(playerPosition);
            bool found = false;
            float bestDistance = float.MaxValue;
            foreach (Vector3Int cell in bounds.allPositionsWithin)
            {
                if (!navigationMap.TryGetSurfaceSample(cell, out TerrainSurfaceSample sample) ||
                    sample.BaseSurface != ETerrainSurfaceKind.Dirt ||
                    sample.EffectiveSurface != ETerrainSurfaceKind.Dirt ||
                    sample.BaseSurfaceCover != ETerrainSurfaceCoverKind.Grass ||
                    sample.EffectiveSurfaceCover != ETerrainSurfaceCoverKind.Grass ||
                    !sample.IsSurfaceCoverFlammable)
                {
                    continue;
                }

                Vector3Int delta = cell - playerCell;
                float distance = delta.sqrMagnitude;
                if (found && distance >= bestDistance)
                {
                    continue;
                }

                found = true;
                bestDistance = distance;
                grassCoverCell = cell;
            }

            return found;
        }

        private static TerrainSurfaceSample ReadRequiredSample(Vector3Int cell)
        {
            if (s_navigationMap == null ||
                !s_navigationMap.TryGetSurfaceSample(cell, out TerrainSurfaceSample sample))
            {
                throw new InvalidOperationException($"无法读取目标地表格：{cell}。");
            }

            return sample;
        }

        private static void PositionPlayerForDamageProbe(CharacterBase player, Vector3 targetWorld)
        {
            player.transform.position = new Vector3(
                targetWorld.x,
                targetWorld.y,
                player.transform.position.z);
            if (player.TryGetComponent(out Rigidbody2D body) && body != null)
            {
                body.position = targetWorld;
                body.linearVelocity = Vector2.zero;
                body.angularVelocity = 0.0f;
            }

            Camera? camera = GameManager.MainCamera;
            if (camera != null)
            {
                camera.transform.position = new Vector3(
                    targetWorld.x,
                    targetWorld.y,
                    camera.transform.position.z);
            }
        }

        private static TerrainNavigationMap? ResolveActiveTerrainNavigationMap()
        {
            if (GameManager.Exists() &&
                GameManager.TryGetSystem(out MapSystem mapSystem))
            {
                MethodInfo? resolveMethod = typeof(MapSystem).GetMethod(
                    "ResolveActiveMapInfo",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                if (resolveMethod?.Invoke(mapSystem, null) is MapInfo mapInfo &&
                    mapInfo.TryGetTerrainNavigationMap(out TerrainNavigationMap navigationMap))
                {
                    return navigationMap;
                }
            }

            return UnityEngine.Object.FindFirstObjectByType<TerrainNavigationMap>(
                FindObjectsInactive.Exclude);
        }

        private static CharacterBase? FindFirstActiveCharacter()
        {
            CharacterActor[] actors = UnityEngine.Object.FindObjectsByType<CharacterActor>(
                FindObjectsInactive.Exclude,
                FindObjectsSortMode.InstanceID);
            return actors.Length > 0 ? actors[0] : null;
        }

        private static void ReadPresentationTiles(
            Vector3Int cell,
            out string temporaryTileName,
            out string resultTileName,
            out bool hasTemporaryTile,
            out bool hasResultTile)
        {
            temporaryTileName = "null";
            resultTileName = "null";
            hasTemporaryTile = false;
            hasResultTile = false;

            if (s_presentation == null)
            {
                return;
            }

            if (TryGetPrivateField(s_presentation, "m_temporaryEffectTilemap", out Tilemap? temp) &&
                temp != null)
            {
                TileBase tile = temp.GetTile(cell);
                hasTemporaryTile = tile != null;
                temporaryTileName = tile != null ? tile.name : "null";
            }

        }

        private static bool TryGetPrivateField<TTarget, TValue>(
            TTarget target,
            string fieldName,
            out TValue? value)
            where TTarget : class
            where TValue : class
        {
            FieldInfo? field = typeof(TTarget).GetField(
                fieldName,
                BindingFlags.Instance | BindingFlags.NonPublic);
            value = field?.GetValue(target) as TValue;
            return value != null;
        }

        private static void RequestScreenshot(
            ValidationResult result,
            string relativePath,
            string fullPath,
            bool burning)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
            ScreenCapture.CaptureScreenshot(relativePath);
            if (burning)
            {
                s_burningScreenshotRequested = true;
                s_burningScreenshotFrame = Time.frameCount;
                result.BurningScreenshotPath = fullPath;
                result.BurningScreenshotFrame = Time.frameCount;
            }
            else
            {
                s_expiredScreenshotRequested = true;
                s_expiredScreenshotFrame = Time.frameCount;
                result.ExpiredScreenshotPath = fullPath;
                result.ExpiredScreenshotFrame = Time.frameCount;
            }

            result.Trace.Add($"frame={Time.frameCount}, screenshot requested: {fullPath}");
        }

        private static void FinalizeResult(ValidationResult result, string failure)
        {
            List<string> failures = new();
            if (!string.IsNullOrWhiteSpace(failure))
            {
                failures.Add(failure);
            }

            Require(result.GameManagerExists, "场景缺少 GameManager。", failures);
            Require(result.HasPlayerSystem, "场景缺少 PlayerSystem。", failures);
            Require(result.HasElementReactionSystem, "场景缺少 ElementReactionSystem。", failures);
            Require(result.HasTerrainSurfaceDamageSystem, "场景缺少 TerrainSurfaceDamageSystem。", failures);
            Require(result.HasTerrainNavigationMap, "场景缺少 TerrainNavigationMap。", failures);
            Require(result.HasTerrainSurfacePresentation, "场景缺少 TerrainSurfacePresentation。", failures);
            Require(result.HasTemporaryEffectTilemap, "地表表现层缺少临时火焰 Tilemap。", failures);
            Require(string.IsNullOrWhiteSpace(result.PlayerHealthRecoveryFailure), result.PlayerHealthRecoveryFailure, failures);
            Require(result.InitialPlayerHealth > 0, "燃烧伤害验证开始时玩家生命不是正数，无法验证地表伤害。", failures);
            Require(result.FireApplyReturned, "ElementReactionSystem.Apply 没有接受 Fire 施加。", failures);
            Require(result.BaseSurfaceBefore == ETerrainSurfaceKind.Dirt.ToString(), "目标格底层地表不是 Dirt。", failures);
            Require(result.EffectiveSurfaceBefore == ETerrainSurfaceKind.Dirt.ToString(), "目标格有效底层地表不是 Dirt。", failures);
            Require(result.BaseSurfaceCoverBefore == ETerrainSurfaceCoverKind.Grass.ToString(), "目标格作者上层覆盖不是 Grass。", failures);
            Require(result.EffectiveSurfaceCoverBefore == ETerrainSurfaceCoverKind.Grass.ToString(), "目标格运行时上层覆盖不是 Grass。", failures);
            Require(result.BurningStateObserved, "Grass 覆盖 + Fire 没有进入 Burning。", failures);
            Require(result.TemporaryFireTileObserved, "Burning 没有显示火焰临时覆盖。", failures);
            Require(result.PlayerTookBurningDamage, "站在 Burning 地表上的角色没有受到燃烧伤害。", failures);
            Require(result.TraversalCostIncreasedDuringBurning, "Burning 没有提高移动代价。", failures);
            Require(!result.UnexpectedResultTileDuringBurning, "燃烧期间不应出现 Dirt/焦土结果覆盖；露土必须来自移除草层。", failures);
            Require(result.BurningClearedObserved, "Burning 持续时间结束后没有清除。", failures);
            Require(result.GrassCoverRemovedAndDirtRevealed, "Grass 覆盖燃尽后没有被移除并露出底层 Dirt。", failures);
            Require(result.TemporaryTileClearedAfterExpiration, "燃尽后火焰临时覆盖没有清除。", failures);
            Require(result.NoResultOverrideTileAfterExpiration, "燃尽后不应显示 Dirt/焦土结果覆盖；当前验收只允许火焰临时层清除。", failures);
            Require(File.Exists(BurningScreenshotPath), "燃烧阶段截图没有生成。", failures);
            Require(File.Exists(ExpiredScreenshotPath), "燃尽阶段截图没有生成。", failures);

            result.EndFrame = Time.frameCount;
            result.Completed = true;
            result.Success = failures.Count == 0;
            result.Failures = failures.ToArray();
            result.Message = result.Success
                ? "ClickMoveTest 元素地表端到端验证通过：火焰燃烧 Grass 覆盖，燃尽后移除覆盖并露出底层 Dirt。"
                : string.Join(" | ", failures);
            WriteAndStop(result);
        }

        private static ValidationResult Fail(string message)
        {
            return new ValidationResult
            {
                Completed = true,
                Success = false,
                Message = message,
                Failures = new[] { message }
            };
        }

        private static void WriteAndStop(ValidationResult result)
        {
            WriteResult(result);
            StopTicking();
        }

        private static void WriteResult(ValidationResult result)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(ResultPath)!);
            File.WriteAllText(ResultPath, JsonUtility.ToJson(result, true));
        }

        private static void StopTicking()
        {
            s_running = false;
            EditorApplication.update -= Tick;
        }

        private static void Require(bool condition, string failure, List<string> failures)
        {
            if (!condition)
            {
                failures.Add(failure);
            }
        }

        private static string Format(Vector3Int value) => $"({value.x}, {value.y}, {value.z})";
        private static string Format(Vector2 value) => $"({value.x:0.###}, {value.y:0.###})";
        private static string Format(Vector3 value) => $"({value.x:0.###}, {value.y:0.###}, {value.z:0.###})";

        private static Vector3Int ParseVector3Int(string value)
        {
            string[] parts = value.Trim('(', ')').Split(',');
            return new Vector3Int(
                int.Parse(parts[0]),
                int.Parse(parts[1]),
                int.Parse(parts[2]));
        }

        private static Vector3 ParseVector3(string value)
        {
            string[] parts = value.Trim('(', ')').Split(',');
            return new Vector3(
                float.Parse(parts[0]),
                float.Parse(parts[1]),
                float.Parse(parts[2]));
        }

        [Serializable]
        public sealed class ReapplyProbeResult
        {
            public bool Success;
            public string Message = string.Empty;
            public string ScenePath = string.Empty;
            public int Frame;
            public bool RuntimeE2ECompleted;
            public bool RuntimeE2ESuccess;
            public string TargetCell = string.Empty;
            public string TargetWorld = string.Empty;
            public string BeforeRuntimeState = string.Empty;
            public string BeforeEffectiveSurface = string.Empty;
            public string BeforeEffectiveSurfaceCover = string.Empty;
            public string BeforeSurfaceCoverLifecycle = string.Empty;
            public bool FireApplyReturned;
            public string AfterRuntimeState = string.Empty;
            public string AfterEffectiveSurface = string.Empty;
            public string AfterEffectiveSurfaceCover = string.Empty;
            public string AfterSurfaceCoverLifecycle = string.Empty;
        }

        [Serializable]
        public sealed class ValidationResult
        {
            public bool Completed;
            public bool Success;
            public string Message = string.Empty;
            public string ScenePath = string.Empty;
            public string ScreenSize = string.Empty;
            public int StartFrame;
            public int EndFrame;
            public bool GameManagerExists;
            public bool HasPlayerSystem;
            public bool HasElementReactionSystem;
            public bool HasTerrainSurfaceDamageSystem;
            public bool HasTerrainNavigationMap;
            public bool HasTerrainSurfacePresentation;
            public bool HasTemporaryEffectTilemap;
            public string PlayerName = string.Empty;
            public string PlayerPositionBefore = string.Empty;
            public string PlayerPositionAfterPlacement = string.Empty;
            public string RuleTilemapName = string.Empty;
            public string TemporaryEffectTilemapName = string.Empty;
            public string TargetCell = string.Empty;
            public string TargetWorld = string.Empty;
            public int PlayerHealthBeforeRecovery;
            public int PlayerMaxHealthBeforeRecovery;
            public int PlayerHealthAfterRecovery;
            public bool PlayerHealthRecoveredForDamageProbe;
            public string PlayerHealthRecoveryFailure = string.Empty;
            public int InitialPlayerHealth;
            public int LatestPlayerHealth;
            public string BaseSurfaceBefore = string.Empty;
            public string EffectiveSurfaceBefore = string.Empty;
            public string BaseSurfaceCoverBefore = string.Empty;
            public string EffectiveSurfaceCoverBefore = string.Empty;
            public string SurfaceCoverLifecycleBefore = string.Empty;
            public float BaseTraversalCostBefore;
            public float EffectiveTraversalCostBefore;
            public bool FireApplyReturned;
            public int FireAppliedFrame;
            public bool BurningStateObserved;
            public int BurningObservedFrame;
            public string RuntimeStateDuringBurning = string.Empty;
            public string EffectiveSurfaceDuringBurning = string.Empty;
            public string EffectiveSurfaceCoverDuringBurning = string.Empty;
            public float EffectiveTraversalCostDuringBurning;
            public int RuntimeStateCountDuringBurning;
            public bool TraversalCostIncreasedDuringBurning;
            public bool TemporaryFireTileObserved;
            public int TemporaryFireTileObservedFrame;
            public string TemporaryTileDuringBurning = string.Empty;
            public string ResultTileDuringBurning = string.Empty;
            public bool UnexpectedResultTileDuringBurning;
            public bool PlayerTookBurningDamage;
            public int PlayerDamageObservedFrame;
            public bool BurningClearedObserved;
            public int BurningClearedFrame;
            public bool GrassCoverRemovedAndDirtRevealed;
            public int GrassCoverRemovedFrame;
            public string RuntimeStateAfterExpiration = string.Empty;
            public string EffectiveSurfaceAfterExpiration = string.Empty;
            public string EffectiveSurfaceCoverAfterExpiration = string.Empty;
            public string SurfaceCoverLifecycleAfterExpiration = string.Empty;
            public float EffectiveTraversalCostAfterExpiration;
            public int RuntimeStateCountAfterExpiration;
            public string TemporaryTileAfterExpiration = string.Empty;
            public string ResultTileAfterExpiration = string.Empty;
            public bool TemporaryTileClearedAfterExpiration;
            public bool NoResultOverrideTileAfterExpiration;
            public string BurningScreenshotPath = string.Empty;
            public int BurningScreenshotFrame;
            public string ExpiredScreenshotPath = string.Empty;
            public int ExpiredScreenshotFrame;
            public string[] Failures = Array.Empty<string>();
            public List<string> Trace = new();
        }
    }
}
