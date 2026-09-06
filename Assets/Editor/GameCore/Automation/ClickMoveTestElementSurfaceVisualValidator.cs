#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using GAS.Runtime;
using UnityEditor;
using UnityEngine;
using UnityEngine.Tilemaps;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// ClickMoveTest 的元素地表视觉验证入口。
    /// 验证同一片草覆盖区域在燃烧中显示多格火焰、燃尽后草覆盖层被移除并露出底层 Dirt。
    /// </summary>
    public static class ClickMoveTestElementSurfaceVisualValidator
    {
        private const int MaxStartupFrames = 180;
        private const int MaxBurningObservationFrames = 240;
        private const int MaxExpirationObservationFrames = 900;
        private const int ScreenshotDelayFrames = 3;
        private const int RuntimeDebugLineClearDelayFrames = 75;
        private const int CandidateSearchRadius = 18;
        private const int CaptureClearanceRadius = 3;
        private const int MinimumWideTargetCellCount = 5;
        private const float WideFireRange = 3.5f;
        private const float WideFireHalfAngleDegrees = 30.0f;
        private const float CameraOrthographicSize = 4.2f;
        private const float MinimumCharacterClearance = 1.75f;
        private const int FireOriginCellOffsetX = -2;
        private const int FireOriginCellOffsetY = 0;
        private const int QAbilitySlotIndex = 1;
        private const int FlamethrowerAbilityCode = XAbility.ABILITY_Flamethrower;
        private const string ResultRelativePath =
            "Temp/UnityBridge/results/clickmove-element-surface-q-wide-visual-runtime.json";
        private const string BurningScreenshotRelativePath =
            "Assets/Screenshots/ElementSurfaceE2E/clickmove-element-surface-q-wide-burning.png";
        private const string ExpiredScreenshotRelativePath =
            "Assets/Screenshots/ElementSurfaceE2E/clickmove-element-surface-q-wide-expired.png";
        private const string BaseGroundTilemapName = "基础地面";

        private static ValidationResult? s_result;
        private static bool s_running;
        private static bool s_fireApplied;
        private static bool s_burningScreenshotRequested;
        private static bool s_qReleasedAfterBurningCapture;
        private static bool s_expiredScreenshotRequested;
        private static bool s_reapplyRequested;
        private static bool s_reapplyReleased;
        private static int s_startedFrame;
        private static int s_fireAppliedFrame;
        private static int s_burningScreenshotFrame;
        private static int s_expiredScreenshotFrame;
        private static int s_reapplyFrame;
        private static int s_gasFrameAtFirstObservation = -1;
        private static int s_gasUnityFrameAtFirstObservation;
        private static TerrainNavigationMap? s_navigationMap;
        private static ElementReactionSystem? s_reactionSystem;
        private static TerrainSurfacePresentation? s_presentation;
        private static Tilemap? s_baseGroundTilemap;
        private static CharacterBase? s_player;
        private static Vector3Int s_targetCell;
        private static Vector3 s_targetWorld;
        private static readonly List<Vector3Int> s_targetCells = new();
        private static readonly List<TerrainNodeKey> s_targetNodeScratch = new();
        private static Tilemap[] s_visualBlockerTilemaps = Array.Empty<Tilemap>();
        private static Vector3 s_playerOriginalPosition;
        private static Vector3 s_cameraOriginalPosition;
        private static float s_cameraOriginalOrthographicSize;
        private static Camera? s_camera;
        private static bool s_cameraWasOrthographic;
        private static bool s_debugPathWasEnabled;
        private static readonly List<Behaviour> s_disabledCameraBehaviours = new();
        private static readonly List<Canvas> s_disabledUiCanvases = new();
        private static readonly List<SpriteRenderer> s_disabledPlayerRenderers = new();

        public static string ResultPath => Path.GetFullPath(ResultRelativePath);
        public static string BurningScreenshotPath => Path.GetFullPath(BurningScreenshotRelativePath);
        public static string ExpiredScreenshotPath => Path.GetFullPath(ExpiredScreenshotRelativePath);

        [MenuItem("Tools/FantasyWord/Validation/Start ClickMoveTest Element Surface Visual Validator")]
        public static void StartFromMenu()
        {
            Start();
        }

        public static string Start()
        {
            if (!Application.isPlaying)
            {
                WriteResult(Fail("元素地表视觉验证只能在 PlayMode 下启动。"));
                return ResultPath;
            }

            s_result = new ValidationResult
            {
                ScenePath = UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,
                ScreenSize = $"{Screen.width}x{Screen.height}",
                StartFrame = Time.frameCount
            };
            s_running = true;
            s_fireApplied = false;
            s_burningScreenshotRequested = false;
            s_qReleasedAfterBurningCapture = false;
            s_expiredScreenshotRequested = false;
            s_reapplyRequested = false;
            s_reapplyReleased = false;
            s_startedFrame = Time.frameCount;
            s_fireAppliedFrame = 0;
            s_burningScreenshotFrame = 0;
            s_expiredScreenshotFrame = 0;
            s_reapplyFrame = 0;
            s_gasFrameAtFirstObservation = -1;
            s_gasUnityFrameAtFirstObservation = 0;
            s_navigationMap = null;
            s_reactionSystem = null;
            s_presentation = null;
            s_baseGroundTilemap = null;
            s_player = null;
            s_targetCell = default;
            s_targetWorld = default;
            s_targetCells.Clear();
            s_targetNodeScratch.Clear();
            s_visualBlockerTilemaps = Array.Empty<Tilemap>();
            s_playerOriginalPosition = default;
            s_cameraOriginalPosition = default;
            s_cameraOriginalOrthographicSize = 0.0f;
            s_camera = null;
            s_cameraWasOrthographic = false;
            s_debugPathWasEnabled = false;
            s_disabledCameraBehaviours.Clear();
            s_disabledUiCanvases.Clear();
            s_disabledPlayerRenderers.Clear();

            EditorApplication.update -= Tick;
            EditorApplication.update += Tick;
            return ResultPath;
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
                WriteAndStop(Fail("元素地表视觉验证过程中 PlayMode 已退出。"));
                return;
            }

            try
            {
                if (!s_fireApplied)
                {
                    if (!TryObserveGasStartup(s_result))
                    {
                        if (Time.frameCount - s_startedFrame > MaxStartupFrames)
                        {
                            FinalizeResult(s_result, "等待 EX-GAS 世界启动并推进逻辑帧超时。");
                        }

                        return;
                    }

                    if (!TryResolveRuntimeObjects(s_result))
                    {
                        if (Time.frameCount - s_startedFrame > MaxStartupFrames)
                        {
                            FinalizeResult(s_result, "等待元素地表视觉验证运行时对象初始化超时。");
                        }

                        return;
                    }

                    ApplyWideFireToUnobstructedGrassRegion(s_result);
                    return;
                }

                ObserveBurningPhase(s_result);
                if (!s_qReleasedAfterBurningCapture &&
                    s_result.BurningStateObserved &&
                    s_result.TemporaryFireTileObserved &&
                    s_result.BurningCellCount >= MinimumWideTargetCellCount &&
                    s_result.TemporaryFireTileCountDuringBurning >= MinimumWideTargetCellCount)
                {
                    s_result.QSlotReleaseAfterFireReturned =
                        s_player != null &&
                        s_player.StopFireEquippedAbilityAtIndex(QAbilitySlotIndex);
                    s_result.QSlotReleaseFrame = Time.frameCount;
                    s_qReleasedAfterBurningCapture = true;
                    HidePlayerRenderersForCapture();
                    s_result.Trace.Add(
                        $"frame={Time.frameCount}, release Auto flamethrower after Burning observed, returned={s_result.QSlotReleaseAfterFireReturned}");
                }

                if (!s_qReleasedAfterBurningCapture)
                {
                    return;
                }

                if (!s_burningScreenshotRequested &&
                    Time.frameCount - s_result.QSlotReleaseFrame >= RuntimeDebugLineClearDelayFrames &&
                    s_result.BurningStateObserved &&
                    s_result.TemporaryFireTileObserved &&
                    s_result.TargetVisibleOnScreen)
                {
                    RequestScreenshot(s_result, BurningScreenshotRelativePath, BurningScreenshotPath, burning: true);
                    return;
                }

                if (!s_burningScreenshotRequested ||
                    Time.frameCount - s_burningScreenshotFrame < ScreenshotDelayFrames ||
                    !File.Exists(BurningScreenshotPath))
                {
                    return;
                }

                ObserveExpirationPhase(s_result);
                if (!s_expiredScreenshotRequested &&
                    s_result.BurningClearedObserved &&
                    s_result.GrassCoverRemovedAndDirtRevealed &&
                    s_result.GrassCoverRemovedCellCount >= MinimumWideTargetCellCount &&
                    s_result.NoResultOverrideTileAfterExpiration &&
                    s_result.TemporaryTileClearedAfterExpiration)
                {
                    CenterCameraOnTarget(s_result);
                    RequestScreenshot(s_result, ExpiredScreenshotRelativePath, ExpiredScreenshotPath, burning: false);
                    return;
                }

                if (s_expiredScreenshotRequested &&
                    Time.frameCount - s_expiredScreenshotFrame >= ScreenshotDelayFrames &&
                    File.Exists(ExpiredScreenshotPath))
                {
                    if (!s_reapplyRequested)
                    {
                        RequestFireReapplyAfterExpiration(s_result);
                        return;
                    }

                    ObserveFireReapplyAfterExpiration(s_result);
                    if (s_result.ReapplyWorldElementTaskSubmitCountDelta > 0 &&
                        s_reapplyReleased)
                    {
                        FinalizeResult(s_result, string.Empty);
                    }

                    if (Time.frameCount - s_reapplyFrame >= 90)
                    {
                        if (!s_reapplyReleased)
                        {
                            s_result.ReapplyQSlotReleaseReturned =
                                s_player != null &&
                                s_player.StopFireEquippedAbilityAtIndex(QAbilitySlotIndex);
                            s_reapplyReleased = true;
                        }

                        FinalizeResult(s_result, string.Empty);
                    }

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
            result.HasElementReactionSystem =
                result.GameManagerExists &&
                GameManager.TryGetSystem(out s_reactionSystem) &&
                s_reactionSystem != null;

            if (result.GameManagerExists && GameManager.HasSystem<PlayerSystem>())
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
            s_baseGroundTilemap = ResolveBaseGroundTilemap();
            result.HasBaseGroundTilemap = s_baseGroundTilemap != null;
            result.BaseGroundTilemapName = s_baseGroundTilemap != null
                ? s_baseGroundTilemap.name
                : "null";
            result.BaseGroundSortingOrder = GetTilemapSortingOrder(s_baseGroundTilemap);

            s_presentation = UnityEngine.Object.FindFirstObjectByType<TerrainSurfacePresentation>(
                FindObjectsInactive.Exclude);
            result.HasTerrainSurfacePresentation = s_presentation != null;
            if (s_presentation != null)
            {
                result.HasTemporaryEffectTilemap =
                    TryGetPrivateField(s_presentation, "m_temporaryEffectTilemap", out Tilemap? temp) &&
                    temp != null;
                result.TemporaryEffectTilemapName = temp != null ? temp.name : "null";

                Tilemap? cover = ResolvePrimarySurfaceCoverTilemap();
                result.HasSurfaceCoverTilemap = cover != null;
                result.SurfaceCoverTilemapName = cover != null ? cover.name : "null";
                result.SurfaceCoverSortingOrder = GetTilemapSortingOrder(cover);
            }

            s_camera = GameManager.MainCamera;
            result.CameraExists = s_camera != null;
            if (s_camera != null)
            {
                result.CameraBefore = Format(s_camera.transform.position);
            }

            return s_navigationMap != null &&
                   s_reactionSystem != null &&
                   s_presentation != null &&
                   s_baseGroundTilemap != null &&
                   result.HasTemporaryEffectTilemap &&
                   s_camera != null;
        }

        private static void ApplyWideFireToUnobstructedGrassRegion(ValidationResult result)
        {
            if (s_navigationMap == null || s_reactionSystem == null)
            {
                FinalizeResult(result, "元素地表视觉验证缺少地形地图或元素反应系统。");
                return;
            }

            if (!TryFindUnobstructedGrassCoverRegion(
                    s_navigationMap,
                    s_player,
                    result,
                    out s_targetCell,
                    s_targetCells))
            {
                FinalizeResult(
                    result,
                    $"ClickMoveTest 中没有找到足够明显的无遮挡 Dirt 底层 + Grass 上层覆盖区域，至少需要 {MinimumWideTargetCellCount} 格。");
                return;
            }

            s_targetWorld = s_navigationMap.RuleTilemap.GetCellCenterWorld(s_targetCell);
            MovePlayerAwayFromTarget(result);
            PrepareSceneForVisualCapture(result);
            CenterCameraOnTarget(result);

            TerrainSurfaceSample beforeSample = ReadRequiredSample(s_targetCell);
            result.TargetCell = Format(s_targetCell);
            result.TargetWorld = Format(s_targetWorld);
            result.TargetCellCount = s_targetCells.Count;
            result.TargetCells = FormatCells(s_targetCells);
            result.BaseSurfaceBefore = beforeSample.BaseSurface.ToString();
            result.EffectiveSurfaceBefore = beforeSample.EffectiveSurface.ToString();
            result.BaseSurfaceCoverBefore = beforeSample.BaseSurfaceCover.ToString();
            result.EffectiveSurfaceCoverBefore = beforeSample.EffectiveSurfaceCover.ToString();
            result.SurfaceCoverLifecycleBefore = beforeSample.SurfaceCoverLifecycle.ToString();
            result.BaseTraversalCostBefore = beforeSample.BaseTraversalCost;
            result.EffectiveTraversalCostBefore = beforeSample.EffectiveTraversalCost;
            ReadVisualSurfaceTiles(
                s_targetCell,
                out result.BaseVisualTileBefore,
                out result.SurfaceCoverTileBefore,
                out result.SurfaceCoverAlphaBefore,
                out bool hasBaseTileBefore,
                out bool hasCoverTileBefore);
            result.HasBaseVisualTileBefore = hasBaseTileBefore;
            result.BaseVisualTileBeforeIsDirt = IsDirtVisualTileName(result.BaseVisualTileBefore);
            result.HasSurfaceCoverTileBefore = hasCoverTileBefore;

            Vector2 fireDirection = Vector2.right;
            if (s_player != null)
            {
                fireDirection = (Vector2)(s_targetWorld - s_player.transform.position);
                if (fireDirection.sqrMagnitude <= 0.0001f)
                {
                    fireDirection = Vector2.right;
                }

                fireDirection.Normalize();
                s_player.SetTargetDirection(fireDirection);
                s_player.SetLookAtDirection(fireDirection);
            }

            result.QAbilitySlotIndex = QAbilitySlotIndex;
            result.ExpectedFlamethrowerAbilityCode = FlamethrowerAbilityCode;
            result.FireDirection = Format(fireDirection);
            result.QSlotEquipFlamethrowerReturned =
                s_player != null &&
                s_player.TryEquipFormalGasAbilityCodeToSlot(FlamethrowerAbilityCode, QAbilitySlotIndex);
            result.QSlotAbilityCodeAfterEquip = ResolveEquippedAbilityCode(s_player, QAbilitySlotIndex);

            if (s_player != null && result.QSlotEquipFlamethrowerReturned)
            {
                TaskApplyWorldElement.ResetDebugState();
                result.QSlotReleaseBeforeFireReturned =
                    s_player.StopFireEquippedAbilityAtIndex(QAbilitySlotIndex);
                result.FireApplicationMode = "FormalGasQSlot";
                CharacterAbilityFireResult fireResult = s_player.FireEquippedAbilityAtIndex(
                    QAbilitySlotIndex,
                    GameCommandContext.Script(s_player, "clickmove-element-surface-q-wide-visual-validator"));
                result.QSlotFireResult = fireResult.Result.ToString();
                result.QSlotFireAbilityCode = fireResult.FormalGasAbilityCode;
                result.FireInputAccepted = fireResult.Result == EAbilityFireCheckResult.Valid &&
                    fireResult.FormalGasAbilityCode == FlamethrowerAbilityCode;
                RefreshWorldElementTaskDiagnostics(result);
            }

            if (!result.FireInputAccepted)
            {
                FinalizeResult(result, "Q 对应的第二技能槽没有接受喷火 20010 输入。");
                return;
            }

            result.AreaKind = EElementAreaKind.Cone.ToString();
            result.AreaRange = WideFireRange;
            result.AreaHalfAngleDegrees = WideFireHalfAngleDegrees;

            s_fireApplied = true;
            s_fireAppliedFrame = Time.frameCount;
            result.FireAppliedFrame = s_fireAppliedFrame;
            result.Trace.Add(
                $"frame={Time.frameCount}, hold Auto flamethrower mode={result.FireApplicationMode}, qSlot={result.QSlotAbilityCodeAfterEquip}, fire={result.QSlotFireResult}, releaseBefore={result.QSlotReleaseBeforeFireReturned}, center={result.TargetCell}, count={result.TargetCellCount}, world={result.TargetWorld}, inputAccepted={result.FireInputAccepted}");
        }

        private static void RequestFireReapplyAfterExpiration(ValidationResult result)
        {
            result.WorldElementTaskSubmitCountBeforeReapply = TaskApplyWorldElement.DebugSubmitCount;
            result.WorldElementTaskSuccessfulApplyCountBeforeReapply =
                TaskApplyWorldElement.DebugSuccessfulApplyCount;
            CharacterAbilityFireResult fireResult = s_player != null
                ? s_player.FireEquippedAbilityAtIndex(
                    QAbilitySlotIndex,
                    GameCommandContext.Script(s_player, "clickmove-element-surface-q-wide-reapply-validator"))
                : default;
            result.ReapplyQSlotFireResult = fireResult.Result.ToString();
            result.ReapplyQSlotFireAbilityCode = fireResult.FormalGasAbilityCode;
            result.ReapplyFireInputAccepted = fireResult.Result == EAbilityFireCheckResult.Valid &&
                fireResult.FormalGasAbilityCode == FlamethrowerAbilityCode;
            s_reapplyRequested = true;
            s_reapplyFrame = Time.frameCount;
            result.ReapplyFireFrame = s_reapplyFrame;
            result.Trace.Add(
                $"frame={Time.frameCount}, reapply Fire after grass removal, accepted={result.ReapplyFireInputAccepted}");
        }

        private static void ObserveFireReapplyAfterExpiration(ValidationResult result)
        {
            RefreshWorldElementTaskDiagnostics(result);
            int burningCells = 0;
            int removedTargetCells = 0;
            for (int i = 0; i < s_targetCells.Count; i++)
            {
                TerrainSurfaceSample sample = ReadRequiredSample(s_targetCells[i]);
                if ((sample.RuntimeState & ETerrainRuntimeSurfaceState.Burning) != 0)
                {
                    burningCells++;
                }

                if (sample.EffectiveSurface == ETerrainSurfaceKind.Dirt &&
                    sample.EffectiveSurfaceCover == ETerrainSurfaceCoverKind.None &&
                    sample.SurfaceCoverLifecycle == ETerrainSurfaceCoverLifecycle.Removed)
                {
                    removedTargetCells++;
                }
            }

            result.ReapplyBurningCellCount = Mathf.Max(result.ReapplyBurningCellCount, burningCells);
            result.ReapplyRemovedTargetCellCount = Mathf.Max(
                result.ReapplyRemovedTargetCellCount,
                removedTargetCells);
            result.ReapplyWorldElementTaskSubmitCountDelta =
                result.WorldElementTaskSubmitCount - result.WorldElementTaskSubmitCountBeforeReapply;
            result.ReapplyWorldElementTaskSuccessfulApplyCountDelta =
                result.WorldElementTaskSuccessfulApplyCount -
                result.WorldElementTaskSuccessfulApplyCountBeforeReapply;

            bool taskSubmitted =
                result.ReapplyWorldElementTaskSubmitCountDelta > 0;
            bool timedOutWaitingForSubmit =
                Time.frameCount - s_reapplyFrame >= 90;

            if (!s_reapplyReleased &&
                (taskSubmitted || timedOutWaitingForSubmit))
            {
                result.ReapplyQSlotReleaseReturned =
                    s_player != null && s_player.StopFireEquippedAbilityAtIndex(QAbilitySlotIndex);
                s_reapplyReleased = true;
                result.Trace.Add(
                    $"frame={Time.frameCount}, release reapply Auto flamethrower, submitted={taskSubmitted}, timeout={timedOutWaitingForSubmit}, returned={result.ReapplyQSlotReleaseReturned}");
            }
        }

        private static bool TryObserveGasStartup(ValidationResult result)
        {
            result.GasManagerInitialized = GASManager.IsInitialized;
            result.GasManagerRunning = GASManager.IsRunning;
            if (!result.GasManagerInitialized || !result.GasManagerRunning)
            {
                return false;
            }

            int currentFrame;
            try
            {
                currentFrame = GASManager.CurrentFrame;
            }
            catch (Exception exception)
            {
                result.GasFrameReadFailure = exception.GetType().Name + ": " + exception.Message;
                return false;
            }

            result.GasWorldCreated = true;
            result.GasFrameAtEnd = currentFrame;
            if (s_gasFrameAtFirstObservation < 0)
            {
                s_gasFrameAtFirstObservation = currentFrame;
                s_gasUnityFrameAtFirstObservation = Time.frameCount;
                result.GasFrameAtFirstObservation = currentFrame;
                result.GasUnityFrameAtFirstObservation = Time.frameCount;
                result.Trace.Add(
                    $"frame={Time.frameCount}, EX-GAS first observed at logicFrame={currentFrame}");
                return false;
            }

            result.GasFrameAtFirstObservation = s_gasFrameAtFirstObservation;
            result.GasUnityFrameAtFirstObservation = s_gasUnityFrameAtFirstObservation;
            result.GasFrameBeforeFire = currentFrame;
            result.GasWorldReady = currentFrame > s_gasFrameAtFirstObservation;
            return result.GasWorldReady;
        }

        private static void ObserveBurningPhase(ValidationResult result)
        {
            RefreshWorldElementTaskDiagnostics(result);

            int burningCells = 0;
            int temporaryFireTiles = 0;
            bool anyUnexpectedResultTile = false;
            TerrainSurfaceSample sample = default;

            for (int i = 0; i < s_targetCells.Count; i++)
            {
                Vector3Int cell = s_targetCells[i];
                sample = ReadRequiredSample(cell);
                bool isCellBurning = (sample.RuntimeState & ETerrainRuntimeSurfaceState.Burning) != 0;
                ReadPresentationTiles(
                    cell,
                    out string temporaryTileName,
                    out string resultTileName,
                    out bool hasTemporaryTile,
                    out bool hasResultTile);

                if (isCellBurning)
                {
                    burningCells++;
                    result.RuntimeStateDuringBurning = sample.RuntimeState.ToString();
                    result.EffectiveSurfaceDuringBurning = sample.EffectiveSurface.ToString();
                    result.EffectiveSurfaceCoverDuringBurning = sample.EffectiveSurfaceCover.ToString();
                    result.EffectiveTraversalCostDuringBurning = sample.EffectiveTraversalCost;
                    result.TemporaryTileDuringBurning = temporaryTileName;
                    result.ResultTileDuringBurning = resultTileName;

                    if (hasTemporaryTile)
                    {
                        temporaryFireTiles++;
                    }

                    if (hasResultTile)
                    {
                        anyUnexpectedResultTile = true;
                    }
                }
            }

            result.BurningCellCount = Mathf.Max(result.BurningCellCount, burningCells);
            result.TemporaryFireTileCountDuringBurning = Mathf.Max(
                result.TemporaryFireTileCountDuringBurning,
                temporaryFireTiles);

            if (!result.BurningStateObserved && burningCells >= MinimumWideTargetCellCount)
            {
                result.BurningStateObserved = true;
                result.BurningObservedFrame = Time.frameCount;
                result.Trace.Add($"frame={Time.frameCount}, wide visual Burning state observed, cells={burningCells}.");
            }

            if (!result.TemporaryFireTileObserved && temporaryFireTiles >= MinimumWideTargetCellCount)
            {
                result.TemporaryFireTileObserved = true;
                result.TemporaryFireTileObservedFrame = Time.frameCount;
                result.Trace.Add(
                    $"frame={Time.frameCount}, wide visual temporary fire tiles observed, cells={temporaryFireTiles}");
            }

            result.UnexpectedResultTileDuringBurning |= anyUnexpectedResultTile;
            RefreshVisibilityFacts(result);

            if (Time.frameCount - s_fireAppliedFrame > MaxBurningObservationFrames &&
                (!result.BurningStateObserved || !result.TemporaryFireTileObserved))
            {
                FinalizeResult(result, "等待燃烧状态或火焰 Tile 显示超时。");
            }
        }

        private static void ObserveExpirationPhase(ValidationResult result)
        {
            int clearedCells = 0;
            int removedGrassCells = 0;
            int visuallyRevealedDirtCells = 0;
            int visibleMappedSurfaceCoverSources = 0;
            int remainingTemporaryTiles = 0;
            int resultOverrideTiles = 0;
            TerrainSurfaceSample sample = default;

            for (int i = 0; i < s_targetCells.Count; i++)
            {
                Vector3Int cell = s_targetCells[i];
                sample = ReadRequiredSample(cell);
                if ((sample.RuntimeState & ETerrainRuntimeSurfaceState.Burning) == 0)
                {
                    clearedCells++;
                }

                ReadPresentationTiles(
                    cell,
                    out string temporaryTileName,
                    out string resultTileName,
                    out bool hasTemporaryTile,
                    out bool hasResultTile);

                if (hasTemporaryTile)
                {
                    remainingTemporaryTiles++;
                }

                if (hasResultTile)
                {
                    resultOverrideTiles++;
                }

                if (sample.BaseSurface == ETerrainSurfaceKind.Dirt &&
                    sample.EffectiveSurface == ETerrainSurfaceKind.Dirt &&
                    sample.BaseSurfaceCover == ETerrainSurfaceCoverKind.Grass &&
                    sample.EffectiveSurfaceCover == ETerrainSurfaceCoverKind.None &&
                    sample.SurfaceCoverLifecycle == ETerrainSurfaceCoverLifecycle.Removed)
                {
                    ReadVisualSurfaceTiles(
                        cell,
                        out string baseVisualTileName,
                        out string surfaceCoverTileName,
                        out float surfaceCoverAlpha,
                        out bool hasBaseVisualTile,
                        out bool hasSurfaceCoverTile);
                    bool coverHidden = hasSurfaceCoverTile && surfaceCoverAlpha <= 0.01f;
                    bool baseDirtStillVisibleSource = hasBaseVisualTile;
                    bool anyMappedCoverStillVisible = HasVisibleMappedSurfaceCoverSource(
                        cell,
                        out string visibleMappedCoverSources);

                    removedGrassCells++;
                    result.RuntimeStateAfterExpiration = sample.RuntimeState.ToString();
                    result.EffectiveSurfaceAfterExpiration = sample.EffectiveSurface.ToString();
                    result.EffectiveSurfaceCoverAfterExpiration = sample.EffectiveSurfaceCover.ToString();
                    result.SurfaceCoverLifecycleAfterExpiration = sample.SurfaceCoverLifecycle.ToString();
                    result.EffectiveTraversalCostAfterExpiration = sample.EffectiveTraversalCost;
                    result.TemporaryTileAfterExpiration = temporaryTileName;
                    result.ResultTileAfterExpiration = resultTileName;
                    result.BaseVisualTileAfterExpiration = baseVisualTileName;
                    result.BaseVisualTileAfterExpirationIsDirt = IsDirtVisualTileName(baseVisualTileName);
                    result.SurfaceCoverTileAfterExpiration = surfaceCoverTileName;
                    result.SurfaceCoverAlphaAfterExpiration = surfaceCoverAlpha;
                    result.HasBaseVisualTileAfterExpiration = hasBaseVisualTile;
                    result.HasSurfaceCoverTileAfterExpiration = hasSurfaceCoverTile;
                    result.SurfaceCoverHiddenAfterExpiration = coverHidden;
                    if (anyMappedCoverStillVisible)
                    {
                        visibleMappedSurfaceCoverSources++;
                        if (string.IsNullOrEmpty(result.VisibleMappedSurfaceCoverSourcesAfterExpiration))
                        {
                            result.VisibleMappedSurfaceCoverSourcesAfterExpiration = visibleMappedCoverSources;
                        }
                    }

                    if (baseDirtStillVisibleSource &&
                        IsDirtVisualTileName(baseVisualTileName) &&
                        coverHidden &&
                        !anyMappedCoverStillVisible)
                    {
                        visuallyRevealedDirtCells++;
                    }
                }
            }

            result.BurningClearedCellCount = clearedCells;
            result.GrassCoverRemovedCellCount = removedGrassCells;
            result.GrassCoverVisuallyRemovedCellCount = visuallyRevealedDirtCells;
            result.VisibleMappedSurfaceCoverSourceCountAfterExpiration =
                visibleMappedSurfaceCoverSources;
            result.TemporaryTileCountAfterExpiration = remainingTemporaryTiles;
            result.ResultOverrideTileCountAfterExpiration = resultOverrideTiles;

            if (result.BurningStateObserved &&
                !result.BurningClearedObserved &&
                clearedCells >= MinimumWideTargetCellCount)
            {
                result.BurningClearedObserved = true;
                result.BurningClearedFrame = Time.frameCount;
                result.Trace.Add($"frame={Time.frameCount}, wide visual Burning state cleared, cells={clearedCells}.");
            }

            result.TemporaryTileClearedAfterExpiration = remainingTemporaryTiles == 0;
            result.NoResultOverrideTileAfterExpiration = resultOverrideTiles == 0;
            RefreshWorldElementTaskDiagnostics(result);

            if (!result.GrassCoverRemovedAndDirtRevealed &&
                visuallyRevealedDirtCells >= MinimumWideTargetCellCount)
            {
                result.GrassCoverRemovedAndDirtRevealed = true;
                result.GrassCoverRemovedFrame = Time.frameCount;
                result.Trace.Add(
                    $"frame={Time.frameCount}, wide visual grass cover hidden across mapped sources and base tile remains visible, cells={visuallyRevealedDirtCells}");
            }

            RefreshVisibilityFacts(result);
        }

        private static bool TryFindUnobstructedGrassCoverRegion(
            TerrainNavigationMap navigationMap,
            CharacterBase? player,
            ValidationResult result,
            out Vector3Int centerCell,
            List<Vector3Int> targetCells)
        {
            centerCell = default;
            targetCells.Clear();
            Tilemap ruleTilemap = navigationMap.RuleTilemap;
            if (ruleTilemap == null)
            {
                return false;
            }

            BoundsInt bounds = ruleTilemap.cellBounds;
            Vector3Int originCell = player != null
                ? ruleTilemap.WorldToCell(player.transform.position)
                : new Vector3Int(
                    Mathf.FloorToInt((bounds.xMin + bounds.xMax) * 0.5f),
                    Mathf.FloorToInt((bounds.yMin + bounds.yMax) * 0.5f),
                    0);
            Tilemap? temporaryEffectTilemap = null;
            TerrainSurfacePresentation? presentation = s_presentation;
            if (presentation != null)
            {
                TryGetPrivateField(presentation, "m_temporaryEffectTilemap", out temporaryEffectTilemap);
            }
            result.TemporaryEffectSortingOrder = GetTilemapSortingOrder(temporaryEffectTilemap);
            s_visualBlockerTilemaps = UnityEngine.Object.FindObjectsByType<Tilemap>(
                FindObjectsInactive.Exclude,
                FindObjectsSortMode.InstanceID);

            bool found = false;
            int bestScore = int.MinValue;
            for (int y = originCell.y - CandidateSearchRadius; y <= originCell.y + CandidateSearchRadius; y++)
            {
                for (int x = originCell.x - CandidateSearchRadius; x <= originCell.x + CandidateSearchRadius; x++)
                {
                    Vector3Int cell = new(x, y, 0);
                    if (!TryCollectVisualGrassRegion(
                            navigationMap,
                            ruleTilemap,
                            temporaryEffectTilemap,
                            cell,
                            targetCells,
                            result,
                            out string visualBlockers))
                    {
                        continue;
                    }

                    Vector3 world = ruleTilemap.GetCellCenterWorld(cell);
                    if (player != null &&
                        Vector2.Distance(player.transform.position, world) < MinimumCharacterClearance)
                    {
                        continue;
                    }

                    int distance = Mathf.Abs(cell.x - originCell.x) + Mathf.Abs(cell.y - originCell.y);
                    int edgePenalty = Mathf.Min(
                        Mathf.Min(cell.x - bounds.xMin, bounds.xMax - 1 - cell.x),
                        Mathf.Min(cell.y - bounds.yMin, bounds.yMax - 1 - cell.y));
                    int openGrassNeighborhood = CountFlammableGrassNeighborhood(
                        navigationMap,
                        cell,
                        CaptureClearanceRadius);
                    int score = targetCells.Count * 100 +
                        openGrassNeighborhood * 50 +
                        edgePenalty * 8 -
                        distance;
                    if (found && score <= bestScore)
                    {
                        continue;
                    }

                    found = true;
                    bestScore = score;
                    centerCell = cell;
                    result.TargetVisualBlockers = visualBlockers;
                    result.TargetCellCount = targetCells.Count;
                    result.TargetOpenGrassNeighborhoodCellCount = openGrassNeighborhood;
                }
            }

            if (found)
            {
                TryCollectVisualGrassRegion(
                    navigationMap,
                    ruleTilemap,
                    temporaryEffectTilemap,
                    centerCell,
                    targetCells,
                    result,
                    out string visualBlockers);
                result.TargetVisuallyUnobstructed = true;
                result.TargetVisualBlockers = visualBlockers;
                return true;
            }

            foreach (Vector3Int cell in bounds.allPositionsWithin)
            {
                Vector3 world = ruleTilemap.GetCellCenterWorld(cell);
                if (player != null &&
                    Vector2.Distance(player.transform.position, world) < MinimumCharacterClearance)
                {
                    continue;
                }

                if (!TryCollectVisualGrassRegion(
                        navigationMap,
                        ruleTilemap,
                        temporaryEffectTilemap,
                        cell,
                        targetCells,
                        result,
                        out string visualBlockers))
                {
                    continue;
                }

                centerCell = cell;
                result.TargetVisuallyUnobstructed = true;
                result.TargetVisualBlockers = visualBlockers;
                result.TargetCellCount = targetCells.Count;
                return true;
            }

            return false;
        }

        private static bool TryCollectVisualGrassRegion(
            TerrainNavigationMap navigationMap,
            Tilemap ruleTilemap,
            Tilemap? temporaryEffectTilemap,
            Vector3Int centerCell,
            List<Vector3Int> targetCells,
            ValidationResult result,
            out string visualBlockers)
        {
            targetCells.Clear();
            visualBlockers = string.Empty;

            if (!IsFlammableGrassCoverCell(navigationMap, centerCell))
            {
                return false;
            }

            Vector3Int originCell = centerCell + new Vector3Int(
                FireOriginCellOffsetX,
                FireOriginCellOffsetY,
                0);
            if (!ruleTilemap.cellBounds.Contains(originCell) ||
                !navigationMap.TryGetSurfaceSample(originCell, out TerrainSurfaceSample originSample) ||
                originSample.EffectiveSurface == ETerrainSurfaceKind.ShallowWater)
            {
                return false;
            }

            Vector3 originWorld = ruleTilemap.GetCellCenterWorld(originCell);
            ElementApplication probe = new(
                EWorldElementKind.Fire,
                1.0f,
                0.2f,
                ElementArea.Cone(WideFireRange, WideFireHalfAngleDegrees),
                originWorld,
                Vector2.right);

            s_targetNodeScratch.Clear();
            if (!navigationMap.TryCollectAffectedNodes(probe, s_targetNodeScratch))
            {
                return false;
            }

            List<string> blockers = new();
            for (int i = 0; i < s_targetNodeScratch.Count; i++)
            {
                Vector3Int cell = s_targetNodeScratch[i].Cell;
                if (!IsFlammableGrassCoverCell(navigationMap, cell))
                {
                    continue;
                }

                Vector3 world = ruleTilemap.GetCellCenterWorld(cell);
                if (Vector2.Distance(originWorld, world) < MinimumCharacterClearance)
                {
                    continue;
                }

                if (!IsCellVisuallyUnobstructed(
                        cell,
                        world,
                        ruleTilemap,
                        temporaryEffectTilemap,
                        result.TemporaryEffectSortingOrder,
                        out string cellBlockers))
                {
                    result.VisualCandidateRejectedByBlockers++;
                    if (!string.IsNullOrWhiteSpace(cellBlockers))
                    {
                        blockers.Add(cellBlockers);
                    }

                    continue;
                }

                targetCells.Add(cell);
            }

            visualBlockers = string.Join("; ", blockers);
            return targetCells.Count >= MinimumWideTargetCellCount;
        }

        private static bool IsFlammableGrassCoverCell(
            TerrainNavigationMap navigationMap,
            Vector3Int cell)
        {
            if (!navigationMap.TryGetSurfaceSample(cell, out TerrainSurfaceSample sample) ||
                sample.BaseSurface != ETerrainSurfaceKind.Dirt ||
                sample.EffectiveSurface != ETerrainSurfaceKind.Dirt ||
                sample.BaseSurfaceCover != ETerrainSurfaceCoverKind.Grass ||
                sample.EffectiveSurfaceCover != ETerrainSurfaceCoverKind.Grass ||
                !sample.IsSurfaceCoverFlammable)
            {
                return false;
            }

            ReadVisualSurfaceTiles(
                cell,
                out string baseVisualTileName,
                out _,
                out _,
                out bool hasBaseVisualTile,
                out _);
            return hasBaseVisualTile && IsDirtVisualTileName(baseVisualTileName);
        }

        private static int CountFlammableGrassNeighborhood(
            TerrainNavigationMap navigationMap,
            Vector3Int centerCell,
            int radius)
        {
            int count = 0;
            for (int y = centerCell.y - radius; y <= centerCell.y + radius; y++)
            {
                for (int x = centerCell.x - radius; x <= centerCell.x + radius; x++)
                {
                    if (IsFlammableGrassCoverCell(navigationMap, new Vector3Int(x, y, centerCell.z)))
                    {
                        count++;
                    }
                }
            }

            return count;
        }

        private static bool IsCellVisuallyUnobstructed(
            Vector3Int ruleCell,
            Vector3 ruleCellWorld,
            Tilemap ruleTilemap,
            Tilemap? temporaryEffectTilemap,
            int temporaryEffectSortingOrder,
            out string visualBlockers)
        {
            List<string> blockers = new();
            for (int i = 0; i < s_visualBlockerTilemaps.Length; i++)
            {
                Tilemap tilemap = s_visualBlockerTilemaps[i];
                if (tilemap == null ||
                    tilemap == ruleTilemap ||
                    tilemap == temporaryEffectTilemap ||
                    !tilemap.gameObject.activeInHierarchy)
                {
                    continue;
                }

                TilemapRenderer renderer = tilemap.GetComponent<TilemapRenderer>();
                if (renderer == null ||
                    !renderer.enabled ||
                    renderer.sortingOrder <= temporaryEffectSortingOrder)
                {
                    continue;
                }

                Vector3Int tilemapCell = tilemap.WorldToCell(ruleCellWorld);
                if (!tilemap.HasTile(tilemapCell))
                {
                    continue;
                }

                blockers.Add(
                    $"{tilemap.name} cell={Format(tilemapCell)} order={renderer.sortingOrder}");
            }

            visualBlockers = string.Join("; ", blockers);
            return blockers.Count == 0;
        }

        private static int GetTilemapSortingOrder(Tilemap? tilemap)
        {
            if (tilemap == null)
            {
                return int.MinValue;
            }

            TilemapRenderer renderer = tilemap.GetComponent<TilemapRenderer>();
            return renderer != null ? renderer.sortingOrder : int.MinValue;
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

        private static void MovePlayerAwayFromTarget(ValidationResult result)
        {
            if (s_player == null || s_navigationMap == null)
            {
                result.PlayerClearOfTarget = true;
                return;
            }

            s_playerOriginalPosition = s_player.transform.position;
            Vector3Int target = s_targetCell;
            Vector3Int destinationCell = target + new Vector3Int(
                FireOriginCellOffsetX,
                FireOriginCellOffsetY,
                0);
            BoundsInt bounds = s_navigationMap.RuleTilemap.cellBounds;
            if (!bounds.Contains(destinationCell) ||
                !s_navigationMap.TryGetSurfaceSample(destinationCell, out TerrainSurfaceSample sample) ||
                sample.EffectiveSurface == ETerrainSurfaceKind.ShallowWater)
            {
                destinationCell = target + new Vector3Int(-3, 0, 0);
            }

            Vector3 destination = s_navigationMap.RuleTilemap.GetCellCenterWorld(destinationCell);
            s_player.ResetMovement();
            s_player.transform.position = new Vector3(
                destination.x,
                destination.y,
                s_player.transform.position.z);
            if (s_player.TryGetComponent(out Rigidbody2D body) && body != null)
            {
                body.position = destination;
                body.linearVelocity = Vector2.zero;
                body.angularVelocity = 0.0f;
            }

            result.PlayerPositionAfterRelocation = Format(s_player.transform.position);
            result.PlayerClearDistance = Vector2.Distance(s_player.transform.position, s_targetWorld);
            result.PlayerClearOfTarget = result.PlayerClearDistance >= MinimumCharacterClearance;
        }

        private static void PrepareSceneForVisualCapture(ValidationResult result)
        {
            if (s_navigationMap != null)
            {
                s_debugPathWasEnabled = GetPrivateBool(
                    s_navigationMap,
                    "m_showRuntimeNavigationPath",
                    defaultValue: false);
                SetPrivateBool(s_navigationMap, "m_showRuntimeNavigationPath", false);
                InvokePrivateMethod(s_navigationMap, "ClearRuntimeNavigationDebugPath");
                result.RuntimeNavigationPathHidden = true;
            }

            DisableCameraDriversForVisualCapture(result);
            DisableScreenUiForVisualCapture(result);
        }

        private static void DisableCameraDriversForVisualCapture(ValidationResult result)
        {
            s_disabledCameraBehaviours.Clear();
            Behaviour[] behaviours = UnityEngine.Object.FindObjectsByType<Behaviour>(
                FindObjectsInactive.Exclude,
                FindObjectsSortMode.InstanceID);
            for (int i = 0; i < behaviours.Length; i++)
            {
                Behaviour behaviour = behaviours[i];
                if (behaviour == null || !behaviour.enabled)
                {
                    continue;
                }

                string typeName = behaviour.GetType().FullName ?? string.Empty;
                if (typeName == "FantasyWord.GameCore.PlayerCameraRig" ||
                    typeName == "Unity.Cinemachine.CinemachineBrain")
                {
                    behaviour.enabled = false;
                    s_disabledCameraBehaviours.Add(behaviour);
                }
            }

            result.CameraDriverDisabledCount = s_disabledCameraBehaviours.Count;
        }

        private static void HidePlayerRenderersForCapture()
        {
            s_disabledPlayerRenderers.Clear();
            if (s_player == null)
            {
                return;
            }

            SpriteRenderer[] renderers = s_player.GetComponentsInChildren<SpriteRenderer>(true);
            for (int i = 0; i < renderers.Length; i++)
            {
                SpriteRenderer renderer = renderers[i];
                if (renderer == null || !renderer.enabled)
                {
                    continue;
                }

                renderer.enabled = false;
                s_disabledPlayerRenderers.Add(renderer);
            }
        }

        private static void DisableScreenUiForVisualCapture(ValidationResult result)
        {
            s_disabledUiCanvases.Clear();
            Canvas[] canvases = UnityEngine.Object.FindObjectsByType<Canvas>(
                FindObjectsInactive.Exclude,
                FindObjectsSortMode.InstanceID);
            for (int i = 0; i < canvases.Length; i++)
            {
                Canvas canvas = canvases[i];
                if (canvas == null || !canvas.enabled || canvas.renderMode == RenderMode.WorldSpace)
                {
                    continue;
                }

                canvas.enabled = false;
                s_disabledUiCanvases.Add(canvas);
            }

            result.ScreenUiCanvasDisabledCount = s_disabledUiCanvases.Count;
        }

        private static void CenterCameraOnTarget(ValidationResult result)
        {
            if (s_camera == null)
            {
                return;
            }

            if (s_cameraOriginalOrthographicSize <= 0.0f)
            {
                s_cameraOriginalPosition = s_camera.transform.position;
                s_cameraOriginalOrthographicSize = s_camera.orthographicSize;
                s_cameraWasOrthographic = s_camera.orthographic;
            }

            s_camera.orthographic = true;
            s_camera.orthographicSize = CameraOrthographicSize;
            s_camera.transform.position = new Vector3(
                s_targetWorld.x,
                s_targetWorld.y,
                s_camera.transform.position.z);
            result.CameraCenteredOnTarget = true;
            result.CameraAfter = Format(s_camera.transform.position);
            result.CameraOrthographicSize = s_camera.orthographicSize;
            RefreshVisibilityFacts(result);
        }

        private static void RefreshVisibilityFacts(ValidationResult result)
        {
            if (s_camera == null)
            {
                result.TargetVisibleOnScreen = false;
                return;
            }

            Vector3 viewport = s_camera.WorldToViewportPoint(s_targetWorld);
            result.TargetViewport = Format(viewport);
            result.TargetVisibleOnScreen =
                viewport.z > 0.0f &&
                viewport.x > 0.12f &&
                viewport.x < 0.88f &&
                viewport.y > 0.12f &&
                viewport.y < 0.88f;

            if (s_player != null)
            {
                result.PlayerClearDistance = Vector2.Distance(s_player.transform.position, s_targetWorld);
                result.PlayerClearOfTarget = result.PlayerClearDistance >= MinimumCharacterClearance;
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

        private static void ReadVisualSurfaceTiles(
            Vector3Int cell,
            out string baseVisualTileName,
            out string surfaceCoverTileName,
            out float surfaceCoverAlpha,
            out bool hasBaseVisualTile,
            out bool hasSurfaceCoverTile)
        {
            baseVisualTileName = "null";
            surfaceCoverTileName = "null";
            surfaceCoverAlpha = -1.0f;
            hasBaseVisualTile = false;
            hasSurfaceCoverTile = false;

            if (s_baseGroundTilemap != null)
            {
                TileBase baseTile = s_baseGroundTilemap.GetTile(cell);
                hasBaseVisualTile = baseTile != null;
                baseVisualTileName = baseTile != null ? baseTile.name : "null";
            }

            if (s_navigationMap == null ||
                !s_navigationMap.TryGetSurfaceSample(cell, out TerrainSurfaceSample sample) ||
                !TryResolveSurfaceCoverTilemap(sample, out Tilemap? cover) ||
                cover == null)
            {
                return;
            }

            TileBase coverTile = cover.GetTile(cell);
            hasSurfaceCoverTile = coverTile != null;
            surfaceCoverTileName = coverTile != null ? coverTile.name : "null";
            surfaceCoverAlpha = cover.GetColor(cell).a;
        }

        private static Tilemap? ResolvePrimarySurfaceCoverTilemap()
        {
            if (s_navigationMap == null)
            {
                return null;
            }

            IReadOnlyList<TerrainSurfaceLayerSource> sources = s_navigationMap.SurfaceLayerSources;
            for (int i = 0; i < sources.Count; i++)
            {
                TerrainSurfaceLayerSource source = sources[i];
                if (source != null &&
                    source.Role == ETerrainSurfaceLayerRole.SurfaceCover &&
                    source.Tilemap != null)
                {
                    return source.Tilemap;
                }
            }

            TerrainSurfaceCoverSourceReference legacyReference =
                TerrainSurfaceCoverSourceReference.LegacySurfaceCover;
            return s_navigationMap.TryGetSurfaceCoverTilemap(
                    legacyReference,
                    out Tilemap? legacyTilemap)
                ? legacyTilemap
                : null;
        }

        private static bool TryResolveSurfaceCoverTilemap(
            in TerrainSurfaceSample sample,
            out Tilemap? tilemap)
        {
            tilemap = null;
            if (s_navigationMap == null || !sample.SurfaceCoverSource.IsValid)
            {
                return false;
            }

            return s_navigationMap.TryGetSurfaceCoverTilemap(
                sample.SurfaceCoverSource,
                out tilemap);
        }

        private static bool HasVisibleMappedSurfaceCoverSource(
            Vector3Int cell,
            out string visibleSources)
        {
            visibleSources = string.Empty;
            if (s_navigationMap == null)
            {
                return false;
            }

            List<string> sources = new();
            IReadOnlyList<TerrainSurfaceLayerSource> layerSources =
                s_navigationMap.SurfaceLayerSources;
            for (int i = 0; i < layerSources.Count; i++)
            {
                TerrainSurfaceLayerSource source = layerSources[i];
                if (source == null ||
                    !source.IsValid ||
                    !source.TryResolveSurfaceCover(
                        cell,
                        out ETerrainSurfaceCoverKind coverKind,
                        out _) ||
                    coverKind == ETerrainSurfaceCoverKind.None)
                {
                    continue;
                }

                Tilemap tilemap = source.Tilemap;
                TileBase tile = tilemap.GetTile(cell);
                if (tile == null ||
                    tilemap.GetColor(cell).a <= 0.01f)
                {
                    continue;
                }

                sources.Add(
                    $"{source.SourceId}:{source.Role}:{tilemap.name}:{tile.name}");
            }

            visibleSources = string.Join("; ", sources);
            return sources.Count > 0;
        }

        private static Tilemap? ResolveBaseGroundTilemap()
        {
            Tilemap[] tilemaps = UnityEngine.Object.FindObjectsByType<Tilemap>(
                FindObjectsInactive.Exclude,
                FindObjectsSortMode.InstanceID);
            for (int i = 0; i < tilemaps.Length; i++)
            {
                if (tilemaps[i] != null && tilemaps[i].name == BaseGroundTilemapName)
                {
                    return tilemaps[i];
                }
            }

            return null;
        }

        private static bool IsDirtVisualTileName(string tileName)
        {
            return !string.IsNullOrWhiteSpace(tileName) &&
                tileName.IndexOf("Dirt", StringComparison.OrdinalIgnoreCase) >= 0;
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

        private static bool GetPrivateBool<TTarget>(
            TTarget target,
            string fieldName,
            bool defaultValue)
            where TTarget : class
        {
            FieldInfo? field = typeof(TTarget).GetField(
                fieldName,
                BindingFlags.Instance | BindingFlags.NonPublic);
            return field != null && field.GetValue(target) is bool value
                ? value
                : defaultValue;
        }

        private static void SetPrivateBool<TTarget>(
            TTarget target,
            string fieldName,
            bool value)
            where TTarget : class
        {
            FieldInfo? field = typeof(TTarget).GetField(
                fieldName,
                BindingFlags.Instance | BindingFlags.NonPublic);
            field?.SetValue(target, value);
        }

        private static void InvokePrivateMethod<TTarget>(
            TTarget target,
            string methodName)
            where TTarget : class
        {
            MethodInfo? method = typeof(TTarget).GetMethod(
                methodName,
                BindingFlags.Instance | BindingFlags.NonPublic);
            method?.Invoke(target, null);
        }

        private static void RequestScreenshot(
            ValidationResult result,
            string relativePath,
            string fullPath,
            bool burning)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
            if (File.Exists(fullPath))
            {
                File.Delete(fullPath);
            }

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

            result.Trace.Add($"frame={Time.frameCount}, visual screenshot requested: {fullPath}");
        }

        private static void FinalizeResult(ValidationResult result, string failure)
        {
            List<string> failures = new();
            if (!string.IsNullOrWhiteSpace(failure))
            {
                failures.Add(failure);
            }

            Require(result.GameManagerExists, "场景缺少 GameManager。", failures);
            Require(result.HasElementReactionSystem, "场景缺少 ElementReactionSystem。", failures);
            Require(result.HasTerrainNavigationMap, "场景缺少 TerrainNavigationMap。", failures);
            Require(result.HasBaseGroundTilemap, "场景缺少真实底层地面 Tilemap：基础地面。", failures);
            Require(result.HasTerrainSurfacePresentation, "场景缺少 TerrainSurfacePresentation。", failures);
            Require(result.HasTemporaryEffectTilemap, "地表表现层缺少临时火焰 Tilemap。", failures);
            Require(result.HasSurfaceCoverTilemap, "地表表现层缺少真实草覆盖 Tilemap，不能证明草层移除后露出底层土壤。", failures);
            Require(result.CameraExists, "场景缺少可用于视觉截图的主相机。", failures);
            Require(result.GasWorldReady, "EX-GAS 世界没有在开火前完成启动并推进逻辑帧。", failures);
            Require(result.FireInputAccepted, "Q 对应的第二技能槽没有接受喷火 20010 输入。", failures);
            Require(result.FireApplicationMode == "FormalGasQSlot", "视觉验收没有走 Q 对应的第二技能槽正式喷火 GAS 入口。", failures);
            Require(!result.FallbackDirectElementUsed, "视觉验收使用了直接元素范围降级路径，不能称为按 Q/GAS 验收。", failures);
            Require(result.QSlotEquipFlamethrowerReturned, "无法把喷火 20010 装入 Q 对应的第二技能槽。", failures);
            Require(result.QSlotAbilityCodeAfterEquip == FlamethrowerAbilityCode, "Q 对应的第二技能槽没有持有喷火 20010。", failures);
            Require(result.QSlotFireResult == EAbilityFireCheckResult.Valid.ToString(), "Q 对应的第二技能槽喷火 GAS 没有成功触发。", failures);
            Require(result.QSlotFireAbilityCode == FlamethrowerAbilityCode, "Q 对应的第二技能槽触发的不是喷火 20010。", failures);
            Require(result.QSlotReleaseAfterFireReturned, "喷火燃烧截图完成后没有成功释放 Auto 模式 Q 输入。", failures);
            Require(result.WorldElementTaskSubmitCount > 0, "喷火 20010 的 TaskApplyWorldElement 没有执行，不能证明正式 Q/GAS 已提交火元素。", failures);
            Require(result.WorldElementTaskSuccessfulApplyCount > 0, $"TaskApplyWorldElement 已执行但没有成功施加火元素：{result.WorldElementTaskLastFailure}。", failures);
            Require(result.WorldElementTaskLastSourceAbilityCode == FlamethrowerAbilityCode, "最后一次世界元素提交不是来自喷火 20010。", failures);
            Require(result.TargetCellCount >= MinimumWideTargetCellCount, $"视觉验收区域不足 {MinimumWideTargetCellCount} 格，不能证明大范围燃烧。", failures);
            Require(result.BaseSurfaceBefore == ETerrainSurfaceKind.Dirt.ToString(), "目标格底层地表不是 Dirt。", failures);
            Require(result.EffectiveSurfaceBefore == ETerrainSurfaceKind.Dirt.ToString(), "目标格有效底层地表不是 Dirt。", failures);
            Require(result.BaseSurfaceCoverBefore == ETerrainSurfaceCoverKind.Grass.ToString(), "目标格作者上层覆盖不是 Grass。", failures);
            Require(result.EffectiveSurfaceCoverBefore == ETerrainSurfaceCoverKind.Grass.ToString(), "目标格运行时上层覆盖不是 Grass。", failures);
            Require(result.HasBaseVisualTileBefore, "目标格燃烧前没有真实底层 Tile，不能证明后续露出土壤。", failures);
            Require(result.BaseVisualTileBeforeIsDirt, $"目标格燃烧前真实底层 Tile 不是土壤 Tile：{result.BaseVisualTileBefore}。", failures);
            Require(result.HasSurfaceCoverTileBefore, "目标格燃烧前没有真实草覆盖 Tile，不能证明草层被移除。", failures);
            Require(result.SurfaceCoverAlphaBefore > 0.99f, "目标格燃烧前草覆盖 Tile 不是完全可见状态。", failures);
            Require(result.BurningStateObserved, "Grass 覆盖 + Fire 没有进入大范围 Burning。", failures);
            Require(result.BurningCellCount >= MinimumWideTargetCellCount, $"燃烧中的格子少于 {MinimumWideTargetCellCount} 格，截图不够明显。", failures);
            Require(result.TemporaryFireTileObserved, "Burning 没有显示多格火焰临时覆盖。", failures);
            Require(result.TemporaryFireTileCountDuringBurning >= MinimumWideTargetCellCount, $"火焰临时覆盖少于 {MinimumWideTargetCellCount} 格，截图不够明显。", failures);
            Require(!result.UnexpectedResultTileDuringBurning, "燃烧期间不应出现 Dirt/焦土结果覆盖；露土必须来自移除草层。", failures);
            Require(result.BurningClearedObserved, "Burning 持续时间结束后没有清除。", failures);
            Require(result.BurningClearedCellCount >= MinimumWideTargetCellCount, $"燃尽后清除 Burning 的格子少于 {MinimumWideTargetCellCount} 格。", failures);
            Require(result.GrassCoverRemovedAndDirtRevealed, "Grass 覆盖燃尽后没有大范围移除并露出底层 Dirt。", failures);
            Require(result.GrassCoverRemovedCellCount >= MinimumWideTargetCellCount, $"草覆盖层移除格子少于 {MinimumWideTargetCellCount} 格，截图不能证明大范围露土。", failures);
            Require(result.GrassCoverVisuallyRemovedCellCount >= MinimumWideTargetCellCount, $"草覆盖层真实视觉隐藏格子少于 {MinimumWideTargetCellCount} 格，不能证明画面露出底层土壤。", failures);
            Require(result.VisibleMappedSurfaceCoverSourceCountAfterExpiration == 0, $"燃尽后仍有映射为地表覆盖语义的可见来源层残留：{result.VisibleMappedSurfaceCoverSourcesAfterExpiration}。", failures);
            Require(result.HasBaseVisualTileAfterExpiration, "燃尽后目标格没有保留真实底层 Tile。", failures);
            Require(result.BaseVisualTileAfterExpirationIsDirt, $"燃尽后露出的真实底层 Tile 不是土壤 Tile：{result.BaseVisualTileAfterExpiration}。", failures);
            Require(result.HasSurfaceCoverTileAfterExpiration, "燃尽后目标格没有可核验的草覆盖 Tile。", failures);
            Require(result.SurfaceCoverHiddenAfterExpiration, "燃尽后草覆盖 Tile 没有在真实覆盖层上隐藏。", failures);
            Require(result.TemporaryTileClearedAfterExpiration, "燃尽后火焰临时覆盖没有清除。", failures);
            Require(result.NoResultOverrideTileAfterExpiration, "燃尽后不应显示 Dirt/焦土结果覆盖；当前验收只允许火焰临时层清除。", failures);
            Require(result.ReapplyFireInputAccepted, "Grass 覆盖移除后再次按 Q 时，喷火 20010 输入没有被正式接受。", failures);
            Require(result.ReapplyQSlotReleaseReturned, "Grass 覆盖移除后的第二次喷火没有成功释放 Auto 输入。", failures);
            Require(result.ReapplyWorldElementTaskSubmitCountDelta > 0, "Grass 覆盖移除后的第二次喷火没有执行 TaskApplyWorldElement。", failures);
            Require(result.ReapplyRemovedTargetCellCount >= result.TargetCellCount, "Grass 覆盖移除后的目标 Dirt 格没有全部保持 Removed 覆盖状态。", failures);
            Require(result.ReapplyBurningCellCount == 0, "Grass 覆盖移除后的 Dirt 格再次进入了 Burning。", failures);
            Require(result.TargetVisuallyUnobstructed, "目标区域被其它可见 Tilemap 遮挡，不适合验证草层移除露土视觉结果。", failures);
            Require(result.TargetVisibleOnScreen, "目标区域没有稳定位于截图中央可见区域。", failures);
            Require(result.PlayerClearOfTarget, "玩家角色仍可能遮挡目标地表区域。", failures);
            Require(result.RuntimeNavigationPathHidden, "运行时路径调试线没有被关闭。", failures);
            Require(File.Exists(BurningScreenshotPath), "燃烧阶段视觉截图没有生成。", failures);
            Require(File.Exists(ExpiredScreenshotPath), "燃尽阶段视觉截图没有生成。", failures);

            result.EndFrame = Time.frameCount;
            RefreshGasFrameAtEnd(result);
            result.Completed = true;
            result.Success = failures.Count == 0;
            result.Failures = failures.ToArray();
            result.Message = result.Success
                ? "ClickMoveTest 元素地表视觉验证通过：Q 对应的第二技能槽触发正式喷火 GAS，同一片草覆盖区域燃烧中显示多格火焰，燃尽后移除 Grass 覆盖并露出底层 Dirt。"
                : string.Join(" | ", failures);
            RestoreSceneAfterVisualCapture();
            WriteAndStop(result);
        }

        private static void RestoreSceneAfterVisualCapture()
        {
            if (s_navigationMap != null)
            {
                SetPrivateBool(s_navigationMap, "m_showRuntimeNavigationPath", s_debugPathWasEnabled);
            }

            for (int i = 0; i < s_disabledCameraBehaviours.Count; i++)
            {
                if (s_disabledCameraBehaviours[i] != null)
                {
                    s_disabledCameraBehaviours[i].enabled = true;
                }
            }

            s_disabledCameraBehaviours.Clear();

            for (int i = 0; i < s_disabledUiCanvases.Count; i++)
            {
                if (s_disabledUiCanvases[i] != null)
                {
                    s_disabledUiCanvases[i].enabled = true;
                }
            }

            s_disabledUiCanvases.Clear();

            for (int i = 0; i < s_disabledPlayerRenderers.Count; i++)
            {
                if (s_disabledPlayerRenderers[i] != null)
                {
                    s_disabledPlayerRenderers[i].enabled = true;
                }
            }

            s_disabledPlayerRenderers.Clear();

            if (s_camera != null && s_cameraOriginalOrthographicSize > 0.0f)
            {
                s_camera.transform.position = s_cameraOriginalPosition;
                s_camera.orthographic = s_cameraWasOrthographic;
                s_camera.orthographicSize = s_cameraOriginalOrthographicSize;
            }
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

        private static void RefreshWorldElementTaskDiagnostics(ValidationResult result)
        {
            result.WorldElementTaskSubmitCount = TaskApplyWorldElement.DebugSubmitCount;
            result.WorldElementTaskSuccessfulApplyCount = TaskApplyWorldElement.DebugSuccessfulApplyCount;
            result.WorldElementTaskLastApplyReturned = TaskApplyWorldElement.DebugLastApplyReturned;
            result.WorldElementTaskLastFailure = TaskApplyWorldElement.DebugLastFailure;
            result.WorldElementTaskLastOrigin = Format(TaskApplyWorldElement.DebugLastOrigin);
            result.WorldElementTaskLastDirection = Format(TaskApplyWorldElement.DebugLastDirection);
            result.WorldElementTaskLastSourceAbilityCode = TaskApplyWorldElement.DebugLastSourceAbilityCode;
            RefreshGasFrameAtEnd(result);
        }

        private static void RefreshGasFrameAtEnd(ValidationResult result)
        {
            if (!GASManager.IsInitialized)
            {
                return;
            }

            try
            {
                result.GasFrameAtEnd = GASManager.CurrentFrame;
            }
            catch (Exception exception)
            {
                result.GasFrameReadFailure = exception.GetType().Name + ": " + exception.Message;
            }
        }

        private static string Format(Vector3Int value) => $"({value.x}, {value.y}, {value.z})";
        private static string Format(Vector2 value) => $"({value.x:0.###}, {value.y:0.###})";
        private static string Format(Vector3 value) => $"({value.x:0.###}, {value.y:0.###}, {value.z:0.###})";

        private static int ResolveEquippedAbilityCode(CharacterBase? character, int slotIndex)
        {
            if (character == null)
            {
                return 0;
            }

            CharacterEquippedAbilitySlotView[] slots = character.GetEquippedAbilitySlotViewSnapshots();
            for (int i = 0; i < slots.Length; i++)
            {
                if (slots[i].SlotIndex == slotIndex)
                {
                    return slots[i].FormalGasAbilityCode;
                }
            }

            return 0;
        }

        private static string FormatCells(List<Vector3Int> cells)
        {
            List<string> values = new(cells.Count);
            for (int i = 0; i < cells.Count; i++)
            {
                values.Add(Format(cells[i]));
            }

            return string.Join("; ", values);
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
            public bool GasManagerInitialized;
            public bool GasManagerRunning;
            public bool GasWorldCreated;
            public bool GasWorldReady;
            public int GasFrameAtFirstObservation;
            public int GasUnityFrameAtFirstObservation;
            public int GasFrameBeforeFire;
            public int GasFrameAtEnd;
            public string GasFrameReadFailure = string.Empty;
            public bool GameManagerExists;
            public bool HasElementReactionSystem;
            public bool HasTerrainNavigationMap;
            public bool HasBaseGroundTilemap;
            public bool HasTerrainSurfacePresentation;
            public bool HasTemporaryEffectTilemap;
            public bool HasSurfaceCoverTilemap;
            public bool CameraExists;
            public bool CameraCenteredOnTarget;
            public int CameraDriverDisabledCount;
            public int ScreenUiCanvasDisabledCount;
            public bool TargetVisibleOnScreen;
            public bool PlayerClearOfTarget;
            public bool RuntimeNavigationPathHidden;
            public string PlayerName = string.Empty;
            public string PlayerPositionBefore = string.Empty;
            public string PlayerPositionAfterRelocation = string.Empty;
            public float PlayerClearDistance;
            public string CameraBefore = string.Empty;
            public string CameraAfter = string.Empty;
            public float CameraOrthographicSize;
            public string TargetViewport = string.Empty;
            public string RuleTilemapName = string.Empty;
            public string BaseGroundTilemapName = string.Empty;
            public int BaseGroundSortingOrder;
            public string TemporaryEffectTilemapName = string.Empty;
            public int TemporaryEffectSortingOrder;
            public string SurfaceCoverTilemapName = string.Empty;
            public int SurfaceCoverSortingOrder;
            public string TargetCell = string.Empty;
            public string TargetWorld = string.Empty;
            public int TargetCellCount;
            public int TargetOpenGrassNeighborhoodCellCount;
            public string TargetCells = string.Empty;
            public string AreaKind = string.Empty;
            public float AreaRange;
            public float AreaHalfAngleDegrees;
            public bool TargetVisuallyUnobstructed;
            public string TargetVisualBlockers = string.Empty;
            public int VisualCandidateRejectedByBlockers;
            public string BaseSurfaceBefore = string.Empty;
            public string EffectiveSurfaceBefore = string.Empty;
            public string BaseSurfaceCoverBefore = string.Empty;
            public string EffectiveSurfaceCoverBefore = string.Empty;
            public string SurfaceCoverLifecycleBefore = string.Empty;
            public float BaseTraversalCostBefore;
            public float EffectiveTraversalCostBefore;
            public string BaseVisualTileBefore = string.Empty;
            public bool BaseVisualTileBeforeIsDirt;
            public string SurfaceCoverTileBefore = string.Empty;
            public float SurfaceCoverAlphaBefore;
            public bool HasBaseVisualTileBefore;
            public bool HasSurfaceCoverTileBefore;
            public bool FireInputAccepted;
            public string FireApplicationMode = string.Empty;
            public bool FallbackDirectElementUsed;
            public int QAbilitySlotIndex;
            public int ExpectedFlamethrowerAbilityCode;
            public bool QSlotEquipFlamethrowerReturned;
            public int QSlotAbilityCodeAfterEquip;
            public string QSlotFireResult = string.Empty;
            public int QSlotFireAbilityCode;
            public bool QSlotReleaseBeforeFireReturned;
            public bool QSlotReleaseAfterFireReturned;
            public int QSlotReleaseFrame;
            public string FireDirection = string.Empty;
            public int FireAppliedFrame;
            public int WorldElementTaskSubmitCount;
            public int WorldElementTaskSuccessfulApplyCount;
            public bool WorldElementTaskLastApplyReturned;
            public string WorldElementTaskLastFailure = string.Empty;
            public string WorldElementTaskLastOrigin = string.Empty;
            public string WorldElementTaskLastDirection = string.Empty;
            public int WorldElementTaskLastSourceAbilityCode;
            public bool BurningStateObserved;
            public int BurningObservedFrame;
            public string RuntimeStateDuringBurning = string.Empty;
            public string EffectiveSurfaceDuringBurning = string.Empty;
            public string EffectiveSurfaceCoverDuringBurning = string.Empty;
            public float EffectiveTraversalCostDuringBurning;
            public int BurningCellCount;
            public int TemporaryFireTileCountDuringBurning;
            public bool TemporaryFireTileObserved;
            public int TemporaryFireTileObservedFrame;
            public string TemporaryTileDuringBurning = string.Empty;
            public string ResultTileDuringBurning = string.Empty;
            public bool UnexpectedResultTileDuringBurning;
            public bool BurningClearedObserved;
            public int BurningClearedFrame;
            public int BurningClearedCellCount;
            public bool GrassCoverRemovedAndDirtRevealed;
            public int GrassCoverRemovedFrame;
            public int GrassCoverRemovedCellCount;
            public int GrassCoverVisuallyRemovedCellCount;
            public int VisibleMappedSurfaceCoverSourceCountAfterExpiration;
            public string VisibleMappedSurfaceCoverSourcesAfterExpiration = string.Empty;
            public string RuntimeStateAfterExpiration = string.Empty;
            public string EffectiveSurfaceAfterExpiration = string.Empty;
            public string EffectiveSurfaceCoverAfterExpiration = string.Empty;
            public string SurfaceCoverLifecycleAfterExpiration = string.Empty;
            public float EffectiveTraversalCostAfterExpiration;
            public string TemporaryTileAfterExpiration = string.Empty;
            public string ResultTileAfterExpiration = string.Empty;
            public string BaseVisualTileAfterExpiration = string.Empty;
            public bool BaseVisualTileAfterExpirationIsDirt;
            public string SurfaceCoverTileAfterExpiration = string.Empty;
            public float SurfaceCoverAlphaAfterExpiration;
            public bool HasBaseVisualTileAfterExpiration;
            public bool HasSurfaceCoverTileAfterExpiration;
            public bool SurfaceCoverHiddenAfterExpiration;
            public int TemporaryTileCountAfterExpiration;
            public int ResultOverrideTileCountAfterExpiration;
            public bool TemporaryTileClearedAfterExpiration;
            public bool NoResultOverrideTileAfterExpiration;
            public bool ReapplyFireInputAccepted;
            public string ReapplyQSlotFireResult = string.Empty;
            public int ReapplyQSlotFireAbilityCode;
            public bool ReapplyQSlotReleaseReturned;
            public int ReapplyFireFrame;
            public int ReapplyBurningCellCount;
            public int ReapplyRemovedTargetCellCount;
            public int WorldElementTaskSubmitCountBeforeReapply;
            public int WorldElementTaskSuccessfulApplyCountBeforeReapply;
            public int ReapplyWorldElementTaskSubmitCountDelta;
            public int ReapplyWorldElementTaskSuccessfulApplyCountDelta;
            public string BurningScreenshotPath = string.Empty;
            public int BurningScreenshotFrame;
            public string ExpiredScreenshotPath = string.Empty;
            public int ExpiredScreenshotFrame;
            public string[] Failures = Array.Empty<string>();
            public List<string> Trace = new();
        }
    }
}
