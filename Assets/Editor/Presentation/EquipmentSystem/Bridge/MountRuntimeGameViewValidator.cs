using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using FantasyWord.GameCore;
using TMPro;
using UnityEditor;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace FantasyWord.Presentation.EquipmentSystem
{
    /// <summary>
    /// 坐骑接入真实 GameView 验收。
    /// 在装备测试场景 PlayMode 中实例化正式角色 Prefab、通过正式装备槽穿上战马，
    /// 再用 ScreenCapture.CaptureScreenshot 抓当前 GameView 的完整画面。
    /// </summary>
    public static class MountRuntimeGameViewValidator
    {
        private const string ResultRelativePath = "Temp/UnityBridge/results/mount-runtime-gameview.json";
        private const string ScreenshotRelativePath = "Temp/UnityBridge/results/mount-runtime-gameview.png";
        private const string EquippedRiderResultRelativePath = "Temp/UnityBridge/results/mount-equipped-rider-gameview.json";
        private const string EquippedRiderScreenshotRelativePath = "Temp/UnityBridge/results/mount-equipped-rider-gameview.png";
        private const string ExpectedScenePath = "Assets/Scenes/EquipmentSystemDemo.unity";
        private const string CharacterActorPrefabPath = "Assets/Prefabs/Entities/Characters/Heroes/玩家角色.prefab";
        private const string WorkbenchCatalogPath = "Assets/GameData/EquipmentSystem/Data/Workbench/换装工作台目录.asset";
        private const string MountDataPath = "Assets/GameData/EquipmentSystem/Mounts/战马_人类骑乘表现.asset";
        private const string MountEquipmentPath = "Assets/Database/Items/Equipment/战马.asset";
        private const string RiderClothingEquipmentPath = "Assets/Database/Items/Equipment/基础布衣.asset";
        private const double CaptureFileTimeoutSeconds = 10d;
        private const int CaptureFrameDelay = 8;

        private static PendingCapture s_pendingCapture;

        public static string ResultPath => Path.GetFullPath(ResultRelativePath);
        public static string ScreenshotPath => Path.GetFullPath(ScreenshotRelativePath);
        public static string EquippedRiderResultPath => Path.GetFullPath(EquippedRiderResultRelativePath);
        public static string EquippedRiderScreenshotPath => Path.GetFullPath(EquippedRiderScreenshotRelativePath);

        public static StartResult Start()
        {
            return StartInternal(
                equipRiderEquipment: false,
                resultPath: ResultPath,
                screenshotPath: ScreenshotPath);
        }

        public static StartResult StartEquippedRider()
        {
            return StartInternal(
                equipRiderEquipment: true,
                resultPath: EquippedRiderResultPath,
                screenshotPath: EquippedRiderScreenshotPath);
        }

        private static StartResult StartInternal(bool equipRiderEquipment, string resultPath, string screenshotPath)
        {
            CleanupPendingCapture();

            ValidationResult result = new()
            {
                Completed = false,
                Success = false,
                Message = equipRiderEquipment
                    ? "骑手穿普通装备真实 GameView 验收已启动。"
                    : "真实 GameView 验收已启动。",
                SourceMode = equipRiderEquipment ? "MountedRiderEquipmentOverlay" : "OriginalSpriteDirect",
                CaptureSource = "ScreenCapture.CaptureScreenshot(CurrentGameView)",
                ResultPath = resultPath,
                ExpectedScenePath = ExpectedScenePath,
                ScenePath = SceneManager.GetActiveScene().path,
                PlayMode = Application.isPlaying,
                ScreenWidth = Screen.width,
                ScreenHeight = Screen.height,
                GameViewScreenshot = true,
                UsesRenderTexture = false,
                UsesTemporaryCamera = false,
                ScreenshotPath = screenshotPath,
                RiderEquipmentOverlayExpected = equipRiderEquipment,
            };

            try
            {
                if (!Application.isPlaying)
                    throw new InvalidOperationException("坐骑 GameView 验收只能在 PlayMode 下启动。");

                result.SceneMatchesExpected = string.Equals(
                    result.ScenePath,
                    ExpectedScenePath,
                    StringComparison.OrdinalIgnoreCase);
                if (!result.SceneMatchesExpected)
                {
                    throw new InvalidOperationException(
                        $"当前场景不是装备测试入口。当前：{result.ScenePath}；预期：{ExpectedScenePath}");
                }

                ValidatePrefabWiring(result);
                GameObject target = InstantiateMountedCharacterForGameView(result, equipRiderEquipment);
                ScheduleGameViewCapture(result, target);
            }
            catch (Exception exception)
            {
                result.Completed = true;
                result.Success = false;
                result.Message = exception.ToString();
                result.Failures = new[] { exception.ToString() };
                WriteResult(result);
            }

            return new StartResult
            {
                ResultPath = resultPath,
                ScreenshotPath = screenshotPath,
            };
        }

        public static StatusResult GetStatus()
        {
            return GetStatus(ResultPath, ScreenshotPath);
        }

        public static StatusResult GetEquippedRiderStatus()
        {
            return GetStatus(EquippedRiderResultPath, EquippedRiderScreenshotPath);
        }

        private static StatusResult GetStatus(string resultPath, string screenshotPath)
        {
            if (File.Exists(resultPath))
            {
                return new StatusResult
                {
                    ResultPath = resultPath,
                    ScreenshotPath = screenshotPath,
                    Pending = s_pendingCapture != null,
                    ResultJson = File.ReadAllText(resultPath),
                };
            }

            return new StatusResult
            {
                ResultPath = resultPath,
                ScreenshotPath = screenshotPath,
                Pending = s_pendingCapture != null,
                ResultJson = string.Empty,
            };
        }

        private static void ValidatePrefabWiring(ValidationResult result)
        {
            GameObject prefab = AssetDatabase.LoadAssetAtPath<GameObject>(CharacterActorPrefabPath);
            result.PrefabFound = prefab != null;
            if (prefab == null)
                throw new InvalidOperationException($"缺少统一角色 Prefab：{CharacterActorPrefabPath}");

            EquipmentRenderer equipmentRenderer = prefab.GetComponentInChildren<EquipmentRenderer>(true);
            MountedCharacterPresentation mountedPresentation = prefab.GetComponentInChildren<MountedCharacterPresentation>(true);
            CharacterEquipmentPresentation equipmentPresentation = prefab.GetComponentInChildren<CharacterEquipmentPresentation>(true);
            CharacterEquipment characterEquipment = prefab.GetComponentInChildren<CharacterEquipment>(true);

            result.PrefabHasEquipmentRenderer = equipmentRenderer != null;
            result.PrefabHasMountedPresentation = mountedPresentation != null;
            result.PrefabHasCharacterEquipmentPresentation = equipmentPresentation != null;
            result.PrefabHasCharacterEquipment = characterEquipment != null;
            result.PrefabEquipmentRendererPath = GetTransformPath(equipmentRenderer != null ? equipmentRenderer.transform : null);
            result.PrefabMountedPresentationPath = GetTransformPath(mountedPresentation != null ? mountedPresentation.transform : null);
            result.PrefabCharacterEquipmentPresentationPath = GetTransformPath(equipmentPresentation != null ? equipmentPresentation.transform : null);

            if (mountedPresentation != null)
            {
                SerializedObject mountedSerialized = new(mountedPresentation);
                result.PrefabMountedHasActionDriver = HasReference(mountedSerialized, "actionDriver");
                result.PrefabMountedHasDirectionDriver = HasReference(mountedSerialized, "directionDriver");
                result.PrefabMountedHasRiderRenderer = HasReference(mountedSerialized, "riderRenderer");
                result.PrefabMountedHasMountRenderer = HasReference(mountedSerialized, "mountRenderer");
                result.PrefabMountedHasOptionalEquipmentRenderer = HasReference(mountedSerialized, "riderEquipmentRenderer");
            }

            if (equipmentPresentation != null)
            {
                SerializedObject equipmentPresentationSerialized = new(equipmentPresentation);
                result.PrefabEquipmentPresentationHasMountedPresentation =
                    HasReference(equipmentPresentationSerialized, "mountedPresentation");
            }
        }

        internal static GameObject InstantiateMountedCharacterForGameView(ValidationResult result, bool equipRiderEquipment)
        {
            MountRenderData mountData = LoadRequired<MountRenderData>(MountDataPath);
            Equipment mountEquipment = LoadRequired<Equipment>(MountEquipmentPath);
            Equipment riderEquipment = equipRiderEquipment ? LoadRequired<Equipment>(RiderClothingEquipmentPath) : null;
            EquipmentWorkbenchCatalog catalog = LoadRequired<EquipmentWorkbenchCatalog>(WorkbenchCatalogPath);
            GameObject prefab = LoadRequired<GameObject>(CharacterActorPrefabPath);

            result.MountDataFound = mountData != null;
            result.MountEquipmentFound = mountEquipment != null;
            result.MountEquipmentVisualIsMountData = mountEquipment != null && mountEquipment.visual == mountData;
            result.RiderFrameDataFound = mountData != null && mountData.RiderFrameData != null;
            result.OriginalSpriteDirectMode = !equipRiderEquipment;
            result.RiderEquipmentPath = equipRiderEquipment ? RiderClothingEquipmentPath : string.Empty;
            result.RiderEquipmentFound = riderEquipment != null;
            result.RiderEquipmentVisualIsEquipmentRenderData =
                riderEquipment == null || riderEquipment.visual is EquipmentRenderData;
            result.PrefabPath = CharacterActorPrefabPath;
            result.WorkbenchCatalogPath = WorkbenchCatalogPath;
            result.MountDataPath = MountDataPath;
            result.MountEquipmentPath = MountEquipmentPath;

            Camera camera = ResolveGameViewCamera();
            if (camera == null)
                throw new InvalidOperationException("装备测试场景缺少可用于 GameView 的相机。");

            result.CameraName = camera.name;
            result.CameraPath = GetTransformPath(camera.transform);
            result.CameraOrthographic = camera.orthographic;
            result.CameraOrthographicSize = camera.orthographic ? camera.orthographicSize : 0f;

            HideExistingEquipmentPreviewRenderers(result);

            GameObject target = PrefabUtility.InstantiatePrefab(prefab) as GameObject;
            if (target == null)
                target = UnityEngine.Object.Instantiate(prefab);

            target.name = "坐骑真实GameView验收角色";
            target.hideFlags = HideFlags.DontSave;
            target.transform.position = new Vector3(camera.transform.position.x, camera.transform.position.y - 0.35f, 0f);
            target.transform.rotation = Quaternion.identity;
            target.SetActive(true);

            result.TargetObjectPath = GetTransformPath(target.transform);
            result.TargetPosition = FormatVector3(target.transform.position);

            CharacterEquipment characterEquipment = target.GetComponentInChildren<CharacterEquipment>(true);
            CharacterEquipmentPresentation equipmentPresentation = target.GetComponentInChildren<CharacterEquipmentPresentation>(true);
            MountedCharacterPresentation mountedPresentation = target.GetComponentInChildren<MountedCharacterPresentation>(true);
            CharacterActionAnimatorDriver actionDriver = target.GetComponentInChildren<CharacterActionAnimatorDriver>(true);
            DirectionalSpriteLibraryDriver directionDriver = target.GetComponentInChildren<DirectionalSpriteLibraryDriver>(true);
            EquipmentRenderer riderEquipmentRenderer = target.GetComponentInChildren<EquipmentRenderer>(true);
            SpriteRenderer riderRenderer = mountedPresentation != null
                ? GetReferencedSpriteRenderer(mountedPresentation, "riderRenderer")
                : null;
            SpriteRenderer mountRenderer = mountedPresentation != null
                ? GetReferencedSpriteRenderer(mountedPresentation, "mountRenderer")
                : null;
            result.RuntimeHasCharacterEquipment = characterEquipment != null;
            result.RuntimeHasCharacterEquipmentPresentation = equipmentPresentation != null;
            result.RuntimeHasMountedPresentation = mountedPresentation != null;
            result.RuntimeHasActionDriver = actionDriver != null;
            result.RuntimeHasDirectionDriver = directionDriver != null;
            result.RuntimeHasRiderEquipmentRenderer = riderEquipmentRenderer != null;

            if (characterEquipment == null || equipmentPresentation == null || mountedPresentation == null)
                throw new InvalidOperationException("实例化的正式角色缺少装备、装备表现或坐骑表现组件。");

            result.RuntimeHasCharacter = characterEquipment.Character != null;

            RunWorkbenchUiMountSelection(
                result,
                catalog,
                riderEquipmentRenderer,
                actionDriver,
                directionDriver,
                characterEquipment,
                equipmentPresentation,
                mountEquipment,
                equipRiderEquipment ? riderEquipment : null);
            result.MountEquippedThroughCharacterEquipment =
                characterEquipment.TryGetEquipment(EEquipmentType.Mount, out Equipment equippedMount)
                && equippedMount == mountEquipment;
            result.EquipOperationResult = result.MountEquippedThroughCharacterEquipment ? "Valid" : "Invalid";
            result.EquipOperationMode = "EquipmentWorkbenchRuntimeUI category button -> mount option button -> CharacterEquipment.TryEquip";

            equipmentPresentation.RefreshFromEquipment();
            result.MountedPresentationActivated = mountedPresentation.IsMounted;
            result.RiderEquipmentOverlayEnabled = mountedPresentation.RiderEquipmentOverlayEnabled;
            result.RiderEquippedSlotCount = riderEquipmentRenderer != null ? riderEquipmentRenderer.EquippedSlotCount : 0;
            result.RiderOriginalSpriteDirectMode =
                riderEquipmentRenderer != null && riderEquipmentRenderer.IsOriginalSpriteDirectMode;
            InspectRiderFrameUvMaps(result, riderEquipmentRenderer);

            List<FrameProbeResult> probes = new();
            AnimationTypeDatabase animationDatabase = actionDriver != null ? actionDriver.AnimationDatabase : null;
            foreach (string animationKey in new[] { "Idle", "Walk" })
            {
                AnimationTypeItem animationType = animationDatabase != null ? animationDatabase.GetByKey(animationKey) : null;
                for (int direction = 0; direction < CharacterAnimationDirections.Count; direction++)
                {
                    probes.Add(ProbeFrame(
                        mountData,
                        mountedPresentation,
                        actionDriver,
                        directionDriver,
                        animationType,
                        direction,
                        mountRenderer,
                        riderRenderer,
                        riderEquipmentRenderer,
                        equipRiderEquipment));
                }
            }

            result.FrameProbes = probes.ToArray();
            result.FrameProbeCount = result.FrameProbes.Length;
            result.FrameProbeSuccessCount = 0;
            foreach (FrameProbeResult probe in result.FrameProbes)
            {
                if (probe.Success)
                    result.FrameProbeSuccessCount++;
            }

            AnimationTypeItem finalAnimation = animationDatabase != null ? animationDatabase.GetByKey("Idle") : null;
            if (finalAnimation != null)
                actionDriver?.SetAnimation(finalAnimation);
            directionDriver?.SetDirection(CharacterAnimationDirections.SouthEast);
            InvokeMountedTick(mountedPresentation, 0.21f);
            RestoreWorkbenchMountListForScreenshot(result, mountEquipment);

            result.FinalAnimationKey = finalAnimation != null ? finalAnimation.name : string.Empty;
            result.FinalDirection = CharacterAnimationDirections.GetName(CharacterAnimationDirections.SouthEast);
            result.RiderMaterialShaderName = riderEquipmentRenderer != null
                ? riderEquipmentRenderer.CurrentSharedMaterialShaderName
                : GetMaterialShaderName(riderRenderer);
            result.MountMaterialShaderName = GetMaterialShaderName(mountRenderer);
            result.RiderUsesEquipmentUvShader = IsEquipmentUvShader(result.RiderMaterialShaderName);
            result.MountUsesEquipmentUvShader = IsEquipmentUvShader(result.MountMaterialShaderName);

            return target;
        }

        private static void HideExistingEquipmentPreviewRenderers(ValidationResult result)
        {
            List<string> hiddenPaths = new();
            EquipmentRenderer[] existingRenderers = UnityEngine.Object.FindObjectsByType<EquipmentRenderer>(
                FindObjectsInactive.Include,
                FindObjectsSortMode.None);

            for (int i = 0; i < existingRenderers.Length; i++)
            {
                EquipmentRenderer equipmentRenderer = existingRenderers[i];
                if (equipmentRenderer == null)
                    continue;

                SpriteRenderer[] spriteRenderers = equipmentRenderer.GetComponentsInChildren<SpriteRenderer>(true);
                for (int j = 0; j < spriteRenderers.Length; j++)
                {
                    SpriteRenderer spriteRenderer = spriteRenderers[j];
                    if (spriteRenderer == null || !spriteRenderer.enabled)
                        continue;

                    spriteRenderer.enabled = false;
                    hiddenPaths.Add(GetTransformPath(spriteRenderer.transform));
                }
            }

            result.ScenePreviewRenderersHidden = hiddenPaths.Count;
            result.ScenePreviewRendererPaths = hiddenPaths.ToArray();
        }

        private static void RunWorkbenchUiMountSelection(
            ValidationResult result,
            EquipmentWorkbenchCatalog catalog,
            EquipmentRenderer riderEquipmentRenderer,
            CharacterActionAnimatorDriver actionDriver,
            DirectionalSpriteLibraryDriver directionDriver,
            CharacterEquipment characterEquipment,
            CharacterEquipmentPresentation equipmentPresentation,
            Equipment mountEquipment,
            Equipment riderEquipment)
        {
            result.WorkbenchCatalogFound = catalog != null;
            if (catalog == null)
                throw new InvalidOperationException($"缺少工作台目录：{WorkbenchCatalogPath}");

            result.WorkbenchCatalogHasMountOption = catalog.HasMountOptions;
            EquipmentWorkbenchController controller = FindFirstRuntimeObject<EquipmentWorkbenchController>();
            EquipmentWorkbenchRuntimeUI runtimeUi = FindFirstRuntimeObject<EquipmentWorkbenchRuntimeUI>();
            result.WorkbenchControllerFound = controller != null;
            result.WorkbenchRuntimeUiFound = runtimeUi != null;

            if (controller == null)
                throw new InvalidOperationException("场景缺少 EquipmentWorkbenchController，不能验证 UI 坐骑闭环。");
            if (runtimeUi == null)
                throw new InvalidOperationException("场景缺少 EquipmentWorkbenchRuntimeUI，不能验证 UI 坐骑闭环。");

            controller.Configure(
                catalog,
                riderEquipmentRenderer,
                actionDriver,
                directionDriver,
                characterEquipment,
                equipmentPresentation);
            controller.InitializeIfNeeded();
            runtimeUi.Bind(controller, null);
            Canvas.ForceUpdateCanvases();

            if (riderEquipment != null)
            {
                SelectRiderEquipmentThroughWorkbenchUi(
                    result,
                    catalog,
                    runtimeUi,
                    riderEquipmentRenderer,
                    riderEquipment);
            }

            result.WorkbenchControllerBoundToCharacterEquipment = controller.CharacterEquipment == characterEquipment;
            IReadOnlyList<EquipmentWorkbenchMountOption> mountOptions = controller.GetMountOptions();
            result.WorkbenchControllerMountOptionCount = mountOptions.Count;
            for (int i = 0; i < mountOptions.Count; i++)
            {
                EquipmentWorkbenchMountOption option = mountOptions[i];
                if (option != null && option.Equipment == mountEquipment)
                {
                    result.WorkbenchControllerHasWarHorseMountOption = true;
                    break;
                }
            }

            Button mountChipButton = FindVisibleButtonByText(runtimeUi, "坐骑");
            result.WorkbenchUiMountChipVisible = mountChipButton != null;
            if (mountChipButton == null)
                throw new InvalidOperationException("工作台 UI 没有显示“坐骑”分类按钮。");

            mountChipButton.onClick.Invoke();
            result.WorkbenchUiMountChipClicked = true;
            Canvas.ForceUpdateCanvases();

            string mountDisplayName = !string.IsNullOrWhiteSpace(mountEquipment.displayName)
                ? mountEquipment.displayName
                : "战马";
            Button mountOptionButton = FindVisibleButtonByText(runtimeUi, mountDisplayName);
            result.WorkbenchUiMountOptionVisible = mountOptionButton != null;
            if (mountOptionButton == null)
                throw new InvalidOperationException($"工作台 UI 坐骑列表没有显示“{mountDisplayName}”按钮。");

            mountOptionButton.onClick.Invoke();
            result.WorkbenchUiMountOptionClicked = true;
            Canvas.ForceUpdateCanvases();

            result.WorkbenchControllerEquippedMountOptionMatches =
                controller.GetEquippedMountOption()?.Equipment == mountEquipment;
            result.MountEquippedThroughCharacterEquipment =
                characterEquipment.TryGetEquipment(EEquipmentType.Mount, out Equipment equippedMount)
                && equippedMount == mountEquipment;
        }

        private static void SelectRiderEquipmentThroughWorkbenchUi(
            ValidationResult result,
            EquipmentWorkbenchCatalog catalog,
            EquipmentWorkbenchRuntimeUI runtimeUi,
            EquipmentRenderer riderEquipmentRenderer,
            Equipment riderEquipment)
        {
            EquipmentRenderData riderVisual = riderEquipment != null
                ? riderEquipment.visual as EquipmentRenderData
                : null;
            if (riderVisual == null)
                throw new InvalidOperationException("骑手验收装备没有普通换装表现资源。");

            if (catalog == null || !catalog.TryGetEquipmentOption(riderVisual, out EquipmentWorkbenchEquipmentOption option))
                throw new InvalidOperationException("工作台目录没有登记基础布衣对应的普通换装选项。");

            Button categoryButton = FindVisibleButtonByText(runtimeUi, EquipTypeRegistry.GetDisplayName(riderVisual.type));
            result.WorkbenchUiRiderCategoryVisible = categoryButton != null;
            if (categoryButton == null)
                throw new InvalidOperationException("工作台 UI 没有显示骑手装备分类按钮。");

            categoryButton.onClick.Invoke();
            result.WorkbenchUiRiderCategoryClicked = true;
            Canvas.ForceUpdateCanvases();

            Button optionButton = FindVisibleButtonByText(runtimeUi, option.DisplayName);
            result.WorkbenchUiRiderOptionVisible = optionButton != null;
            if (optionButton == null)
                throw new InvalidOperationException($"工作台 UI 没有显示骑手装备“{option.DisplayName}”。");

            optionButton.onClick.Invoke();
            result.WorkbenchUiRiderOptionClicked = true;
            Canvas.ForceUpdateCanvases();
            result.RiderEquipmentSelectedThroughWorkbenchUi = true;
            result.RiderEquipmentVisualAppliedToRenderer =
                riderEquipmentRenderer != null
                && riderEquipmentRenderer.GetEquipped(riderVisual.type) == riderVisual;
        }

        private static void RestoreWorkbenchMountListForScreenshot(ValidationResult result, Equipment mountEquipment)
        {
            EquipmentWorkbenchRuntimeUI runtimeUi = FindFirstRuntimeObject<EquipmentWorkbenchRuntimeUI>();
            result.WorkbenchScreenshotMountListRestored = false;
            result.WorkbenchScreenshotMountOptionVisible = false;

            if (runtimeUi == null)
                return;

            Button mountChipButton = FindVisibleButtonByText(runtimeUi, "坐骑");
            if (mountChipButton == null)
                return;

            mountChipButton.onClick.Invoke();
            result.WorkbenchScreenshotMountListRestored = true;
            Canvas.ForceUpdateCanvases();

            string mountDisplayName = mountEquipment != null && !string.IsNullOrWhiteSpace(mountEquipment.displayName)
                ? mountEquipment.displayName
                : "战马";
            result.WorkbenchScreenshotMountOptionVisible =
                FindVisibleButtonByText(runtimeUi, mountDisplayName) != null;
        }

        private static T FindFirstRuntimeObject<T>() where T : UnityEngine.Object
        {
            T[] objects = UnityEngine.Object.FindObjectsByType<T>(
                FindObjectsInactive.Include,
                FindObjectsSortMode.None);
            return objects != null && objects.Length > 0 ? objects[0] : null;
        }

        private static Button FindVisibleButtonByText(EquipmentWorkbenchRuntimeUI runtimeUi, string expectedText)
        {
            if (runtimeUi == null || string.IsNullOrWhiteSpace(expectedText))
                return null;

            Button[] buttons = runtimeUi.GetComponentsInChildren<Button>(true);
            for (int i = 0; i < buttons.Length; i++)
            {
                Button button = buttons[i];
                if (button == null || !button.gameObject.activeInHierarchy)
                    continue;

                if (ButtonHasText(button, expectedText))
                    return button;
            }

            return null;
        }

        private static bool ButtonHasText(Button button, string expectedText)
        {
            TMP_Text[] labels = button.GetComponentsInChildren<TMP_Text>(true);
            for (int i = 0; i < labels.Length; i++)
            {
                TMP_Text label = labels[i];
                if (label == null)
                    continue;

                string text = label.text != null ? label.text.Trim() : string.Empty;
                if (string.Equals(text, expectedText, StringComparison.Ordinal))
                    return true;
            }

            return false;
        }

        private static void ScheduleGameViewCapture(ValidationResult result, GameObject target)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(result.ScreenshotPath)!);
            if (File.Exists(result.ScreenshotPath))
                File.Delete(result.ScreenshotPath);

            s_pendingCapture = new PendingCapture
            {
                Result = result,
                Target = target,
                TargetFrame = Time.frameCount + CaptureFrameDelay,
            };

            WriteResult(result);
            EditorApplication.update -= TryCompleteCapture;
            EditorApplication.update += TryCompleteCapture;
        }

        private static void TryCompleteCapture()
        {
            PendingCapture pending = s_pendingCapture;
            if (pending == null)
            {
                EditorApplication.update -= TryCompleteCapture;
                return;
            }

            ValidationResult result = pending.Result;
            try
            {
                if (!Application.isPlaying)
                    throw new InvalidOperationException("截图完成前已退出 PlayMode。");

                if (!pending.CaptureRequested)
                {
                    if (Time.frameCount < pending.TargetFrame)
                        return;

                    pending.CaptureRequested = true;
                    pending.CaptureRequestTime = EditorApplication.timeSinceStartup;
                    result.CaptureRequestedFrame = Time.frameCount;
                    result.Message = "已向当前 GameView 请求完整截图。";
                    ScreenCapture.CaptureScreenshot(result.ScreenshotPath, 1);
                    WriteResult(result);
                    return;
                }

                if (File.Exists(result.ScreenshotPath))
                {
                    FileInfo info = new(result.ScreenshotPath);
                    if (info.Length > 0)
                    {
                        AnalyzeScreenshot(result);
                        FinalizeResult(result);
                        WriteResult(result);
                        CleanupPendingCapture();
                    }
                    return;
                }

                if (EditorApplication.timeSinceStartup - pending.CaptureRequestTime >= CaptureFileTimeoutSeconds)
                    throw new TimeoutException($"等待 GameView 截图文件超时：{result.ScreenshotPath}");
            }
            catch (Exception exception)
            {
                result.Completed = true;
                result.Success = false;
                result.Message = exception.ToString();
                result.Failures = new[] { exception.ToString() };
                WriteResult(result);
                CleanupPendingCapture();
            }
        }

        private static FrameProbeResult ProbeFrame(
            MountRenderData mountData,
            MountedCharacterPresentation mountedPresentation,
            CharacterActionAnimatorDriver actionDriver,
            DirectionalSpriteLibraryDriver directionDriver,
            AnimationTypeItem animationType,
            int directionIndex,
            SpriteRenderer mountRenderer,
            SpriteRenderer riderRenderer,
            EquipmentRenderer riderEquipmentRenderer,
            bool expectRiderEquipmentOverlay)
        {
            MountActionRequest actionRequest = animationType != null
                ? MountActionResolver.ResolveRequest(animationType.name)
                : new MountActionRequest(MountActionSemantic.Unspecified);
            FrameProbeResult result = new()
            {
                AnimationKey = animationType != null ? animationType.name : string.Empty,
                MountActionKey = MountActionResolver.ToKey(actionRequest.Semantic),
                Direction = CharacterAnimationDirections.GetName(directionIndex),
                SourceMode = expectRiderEquipmentOverlay ? "MountedRiderEquipmentOverlay" : "OriginalSpriteDirect",
            };

            List<string> failures = new();
            Require(mountData != null, "缺少坐骑表现资产。", failures);
            Require(mountedPresentation != null, "缺少坐骑表现组件。", failures);
            Require(actionDriver != null, "缺少角色动作驱动。", failures);
            Require(directionDriver != null, "缺少角色方向驱动。", failures);
            Require(animationType != null, "缺少动作类型资产。", failures);
            if (failures.Count > 0)
            {
                result.Failures = failures.ToArray();
                return result;
            }

            bool animationResolved = mountData.TryGetAnimation(
                actionRequest,
                out MountAnimationData mountAnimation,
                out bool usedFallback);
            result.AnimationResolved = animationResolved;
            result.UsedFallbackAction = usedFallback;
            Require(animationResolved && mountAnimation != null, "坐骑资产没有匹配当前角色动作的逐帧数据。", failures);
            Require(!usedFallback, "Idle/Walk 验收动作发生了坐骑动作回退。", failures);
            if (mountAnimation == null)
            {
                result.Failures = failures.ToArray();
                return result;
            }

            result.ExpectedFrameCount = mountAnimation.GetFrameCount(directionIndex);
            Require(result.ExpectedFrameCount >= 2, "当前动作/方向少于两帧，不能证明连续换帧。", failures);
            if (result.ExpectedFrameCount < 2)
            {
                result.Failures = failures.ToArray();
                return result;
            }

            actionDriver.SetAnimation(animationType);
            directionDriver.SetDirection(directionIndex);
            mountedPresentation.SetMount(null);
            mountedPresentation.SetMount(mountData);

            Sprite expectedMountFrame0 = mountAnimation.GetMountFrame(directionIndex, 0);
            Sprite expectedRiderFrame0 = mountAnimation.GetRiderFrame(directionIndex, 0);
            Sprite actualMountFrame0 = mountRenderer != null ? mountRenderer.sprite : null;
            Sprite actualRiderFrame0 = riderRenderer != null ? riderRenderer.sprite : null;
            result.ExpectedFirstMountSpriteName = GetSpriteName(expectedMountFrame0);
            result.ExpectedFirstRiderSpriteName = GetSpriteName(expectedRiderFrame0);
            result.FirstMountSpriteName = GetSpriteName(actualMountFrame0);
            result.FirstRiderSpriteName = GetSpriteName(actualRiderFrame0);
            result.FirstMountFrameMatches = actualMountFrame0 == expectedMountFrame0;
            result.FirstRiderFrameMatches = actualRiderFrame0 == expectedRiderFrame0;

            float frameStepSeconds = mountAnimation.GetCycleDurationSeconds(directionIndex)
                / result.ExpectedFrameCount
                + 0.0001f;
            result.ExpectedSecondFrameIndex = mountAnimation.ResolveFrameIndex(frameStepSeconds, directionIndex);
            InvokeMountedTick(mountedPresentation, frameStepSeconds);

            Sprite expectedMountFrame1 = mountAnimation.GetMountFrame(directionIndex, result.ExpectedSecondFrameIndex);
            Sprite expectedRiderFrame1 = mountAnimation.GetRiderFrame(directionIndex, result.ExpectedSecondFrameIndex);
            Sprite actualMountFrame1 = mountRenderer != null ? mountRenderer.sprite : null;
            Sprite actualRiderFrame1 = riderRenderer != null ? riderRenderer.sprite : null;
            result.ExpectedSecondMountSpriteName = GetSpriteName(expectedMountFrame1);
            result.ExpectedSecondRiderSpriteName = GetSpriteName(expectedRiderFrame1);
            result.SecondMountSpriteName = GetSpriteName(actualMountFrame1);
            result.SecondRiderSpriteName = GetSpriteName(actualRiderFrame1);
            result.SecondMountFrameMatches = actualMountFrame1 == expectedMountFrame1;
            result.SecondRiderFrameMatches = actualRiderFrame1 == expectedRiderFrame1;
            result.MountAdvancedToNextFrame = actualMountFrame0 != actualMountFrame1;
            result.RiderAdvancedToNextFrame = actualRiderFrame0 != actualRiderFrame1;

            result.MountSpriteName = result.SecondMountSpriteName;
            result.RiderSpriteName = result.SecondRiderSpriteName;
            result.MountRendererEnabled = mountRenderer != null && mountRenderer.enabled;
            result.RiderRendererEnabled = riderRenderer != null && riderRenderer.enabled;
            result.RiderOriginalSpriteDirectMode =
                riderEquipmentRenderer != null && riderEquipmentRenderer.IsOriginalSpriteDirectMode;
            result.RiderMaterialShaderName = riderEquipmentRenderer != null
                ? riderEquipmentRenderer.CurrentSharedMaterialShaderName
                : GetMaterialShaderName(riderRenderer);
            result.MountMaterialShaderName = GetMaterialShaderName(mountRenderer);
            result.RiderUsesEquipmentUvShader = IsEquipmentUvShader(result.RiderMaterialShaderName);
            result.MountUsesEquipmentUvShader = IsEquipmentUvShader(result.MountMaterialShaderName);

            Require(result.MountRendererEnabled && !string.IsNullOrWhiteSpace(result.MountSpriteName), "坐骑本体没有渲染原版 Sprite。", failures);
            Require(result.RiderRendererEnabled && !string.IsNullOrWhiteSpace(result.RiderSpriteName), "骑手基础层没有渲染原版 Sprite。", failures);
            Require(result.ExpectedSecondFrameIndex > 0, "推进一个帧时长后仍解析为第 0 帧。", failures);
            Require(result.FirstMountFrameMatches, $"坐骑本体第 0 帧不匹配资产，预期 {result.ExpectedFirstMountSpriteName}，实际 {result.FirstMountSpriteName}。", failures);
            Require(result.FirstRiderFrameMatches, $"骑手第 0 帧不匹配资产，预期 {result.ExpectedFirstRiderSpriteName}，实际 {result.FirstRiderSpriteName}。", failures);
            Require(result.SecondMountFrameMatches, $"坐骑本体下一帧不匹配资产，预期 {result.ExpectedSecondMountSpriteName}，实际 {result.SecondMountSpriteName}。", failures);
            Require(result.SecondRiderFrameMatches, $"骑手下一帧不匹配资产，预期 {result.ExpectedSecondRiderSpriteName}，实际 {result.SecondRiderSpriteName}。", failures);
            Require(result.MountAdvancedToNextFrame, "坐骑本体推进后仍是同一张 Sprite。", failures);
            Require(result.RiderAdvancedToNextFrame, "骑手推进后仍是同一张 Sprite。", failures);
            if (expectRiderEquipmentOverlay)
            {
                Require(!result.RiderOriginalSpriteDirectMode, "骑手穿普通装备时仍处于原版 Sprite 直显模式。", failures);
                Require(result.RiderUsesEquipmentUvShader, "骑手穿普通装备时没有使用 EquipmentUV 换装 Shader。", failures);
            }
            else
            {
                Require(result.RiderOriginalSpriteDirectMode, "骑手基础层没有进入原版 Sprite 直显模式。", failures);
                Require(!result.RiderUsesEquipmentUvShader, "骑手基础层仍在使用 EquipmentUV 换装 Shader。", failures);
            }
            Require(!result.MountUsesEquipmentUvShader, "坐骑本体仍在使用 EquipmentUV 换装 Shader。", failures);
            result.Success = failures.Count == 0;
            result.Failures = failures.ToArray();
            return result;
        }

        private static string GetSpriteName(Sprite sprite)
        {
            return sprite != null ? sprite.name : string.Empty;
        }

        private static void AnalyzeScreenshot(ValidationResult result)
        {
            result.ScreenshotExists = File.Exists(result.ScreenshotPath);
            if (!result.ScreenshotExists)
                return;

            byte[] bytes = File.ReadAllBytes(result.ScreenshotPath);
            result.ScreenshotBytes = bytes.Length;
            Texture2D texture = new(2, 2, TextureFormat.RGBA32, false);
            try
            {
                if (!texture.LoadImage(bytes))
                    return;

                result.ScreenshotWidth = texture.width;
                result.ScreenshotHeight = texture.height;
                result.ScreenshotMatchesScreenSize =
                    result.ScreenshotWidth == result.ScreenWidth
                    && result.ScreenshotHeight == result.ScreenHeight;
                result.ScreenshotIsCompleteGameView =
                    result.GameViewScreenshot
                    && result.ScreenshotMatchesScreenSize
                    && !result.UsesRenderTexture
                    && !result.UsesTemporaryCamera;

                Color32[] pixels = texture.GetPixels32();
                HashSet<int> sampledColors = new();
                int step = Mathf.Max(1, pixels.Length / 4096);
                for (int i = 0; i < pixels.Length; i += step)
                {
                    Color32 pixel = pixels[i];
                    sampledColors.Add((pixel.r << 24) | (pixel.g << 16) | (pixel.b << 8) | pixel.a);
                }

                result.SampledDistinctColorCount = sampledColors.Count;

                int magentaErrorPixelCount = 0;
                int minX = texture.width;
                int minY = texture.height;
                int maxX = -1;
                int maxY = -1;
                for (int y = 0; y < texture.height; y++)
                {
                    for (int x = 0; x < texture.width; x++)
                    {
                        Color32 pixel = pixels[y * texture.width + x];
                        if (pixel.a < 250 || pixel.r < 230 || pixel.g > 30 || pixel.b < 220)
                            continue;

                        magentaErrorPixelCount++;
                        minX = Math.Min(minX, x);
                        minY = Math.Min(minY, y);
                        maxX = Math.Max(maxX, x);
                        maxY = Math.Max(maxY, y);
                    }
                }

                result.MagentaErrorPixelCount = magentaErrorPixelCount;
                result.ScreenshotHasMagentaErrorBlock = magentaErrorPixelCount > 256;
                result.MagentaErrorBounds = magentaErrorPixelCount > 0
                    ? $"{minX},{minY},{maxX},{maxY}"
                    : string.Empty;
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(texture);
            }
        }

        private static void FinalizeResult(ValidationResult result)
        {
            List<string> failures = new();
            Require(result.PlayMode, "没有进入 PlayMode。", failures);
            Require(result.SceneMatchesExpected, "没有在装备测试场景中验收。", failures);
            Require(result.PrefabFound, "统一角色 Prefab 不存在。", failures);
            Require(result.PrefabHasMountedPresentation, "统一角色 Prefab 缺少 MountedCharacterPresentation。", failures);
            Require(result.PrefabHasCharacterEquipmentPresentation, "统一角色 Prefab 缺少 CharacterEquipmentPresentation。", failures);
            Require(result.PrefabHasCharacterEquipment, "统一角色 Prefab 缺少 CharacterEquipment。", failures);
            Require(result.PrefabMountedHasActionDriver, "Prefab 的坐骑表现缺少动作驱动引用。", failures);
            Require(result.PrefabMountedHasDirectionDriver, "Prefab 的坐骑表现缺少方向驱动引用。", failures);
            Require(result.PrefabMountedHasRiderRenderer, "Prefab 的坐骑表现缺少骑手 Renderer 引用。", failures);
            Require(result.PrefabMountedHasMountRenderer, "Prefab 的坐骑表现缺少坐骑 Renderer 引用。", failures);
            Require(result.PrefabEquipmentPresentationHasMountedPresentation, "Prefab 的装备表现同步器没有接到坐骑表现组件。", failures);
            Require(result.WorkbenchCatalogFound, "工作台目录不存在。", failures);
            Require(result.WorkbenchCatalogHasMountOption, "工作台目录没有登记有效坐骑选项。", failures);
            Require(result.WorkbenchControllerFound, "场景中没有工作台控制器，无法验证 UI 闭环。", failures);
            Require(result.WorkbenchRuntimeUiFound, "场景中没有工作台运行时 UI，无法验证 UI 闭环。", failures);
            Require(result.WorkbenchControllerBoundToCharacterEquipment, "工作台控制器没有绑定到正式角色装备槽。", failures);
            Require(result.WorkbenchControllerHasWarHorseMountOption, "工作台控制器没有拿到“战马”坐骑选项。", failures);
            Require(result.WorkbenchUiMountChipVisible, "工作台 UI 没有显示“坐骑”分类。", failures);
            Require(result.WorkbenchUiMountChipClicked, "验收没有点击“坐骑”分类。", failures);
            Require(result.WorkbenchUiMountOptionVisible, "工作台 UI 坐骑列表没有显示“战马”。", failures);
            Require(result.WorkbenchUiMountOptionClicked, "验收没有点击“战马”坐骑选项。", failures);
            Require(result.WorkbenchScreenshotMountListRestored, "最终截图前没有切回“坐骑”列表。", failures);
            Require(result.WorkbenchScreenshotMountOptionVisible, "最终截图前“战马”坐骑选项不可见。", failures);
            Require(result.WorkbenchControllerEquippedMountOptionMatches, "点击 UI 后工作台当前坐骑选项没有变成“战马”。", failures);
            Require(result.MountEquipmentVisualIsMountData, "战马装备没有引用战马坐骑表现资产。", failures);
            Require(result.MountEquippedThroughCharacterEquipment, "战马没有通过正式 CharacterEquipment 装备槽穿上。", failures);
            Require(result.MountedPresentationActivated, "坐骑表现组件没有进入骑乘状态。", failures);
            if (result.RiderEquipmentOverlayExpected)
            {
                Require(result.RiderEquipmentFound, "基础布衣装备资产不存在。", failures);
                Require(result.RiderEquipmentVisualIsEquipmentRenderData, "基础布衣没有引用普通换装表现资源。", failures);
                Require(result.WorkbenchUiRiderCategoryVisible, "工作台 UI 没有显示基础布衣所属分类。", failures);
                Require(result.WorkbenchUiRiderCategoryClicked, "验收没有点击基础布衣所属分类。", failures);
                Require(result.WorkbenchUiRiderOptionVisible, "工作台 UI 没有显示基础布衣选项。", failures);
                Require(result.WorkbenchUiRiderOptionClicked, "验收没有点击基础布衣选项。", failures);
                Require(result.RiderEquipmentSelectedThroughWorkbenchUi, "基础布衣没有通过工作台 UI 选择。", failures);
                Require(result.RiderEquipmentVisualAppliedToRenderer, "基础布衣点击后没有进入骑手换装渲染槽。", failures);
                Require(result.RiderEquipmentOverlayEnabled, "坐骑骑手层没有开启普通装备叠加。", failures);
                Require(result.RiderEquippedSlotCount > 0, "骑手换装渲染器没有收到任何普通装备槽。", failures);
                Require(!result.RiderOriginalSpriteDirectMode, "骑手穿普通装备时仍处于原版 Sprite 直显模式。", failures);
                Require(result.RiderUsesEquipmentUvShader, "骑手穿普通装备时没有使用 EquipmentUV 换装 Shader。", failures);
                Require(result.RiderIdleBodyUvMapFound, "骑乘 Idle 缺少 Body UV。", failures);
                Require(result.RiderIdleHeadUvMapFound, "骑乘 Idle 缺少 Head UV。", failures);
                Require(result.RiderWalkBodyUvMapFound, "骑乘 Walk 缺少 Body UV。", failures);
                Require(result.RiderWalkHeadUvMapFound, "骑乘 Walk 缺少 Head UV。", failures);
            }
            else
            {
                Require(result.RiderOriginalSpriteDirectMode, "骑手基础层没有进入原版 Sprite 直显模式。", failures);
                Require(result.OriginalSpriteDirectMode, "坐骑验收没有按原版 Sprite 直显模式运行。", failures);
                Require(!result.RiderUsesEquipmentUvShader, "骑手基础层仍在使用 EquipmentUV 换装 Shader。", failures);
            }
            Require(!result.MountUsesEquipmentUvShader, "坐骑本体仍在使用 EquipmentUV 换装 Shader。", failures);
            Require(result.FrameProbeCount == 8, $"应覆盖 Idle/Walk x 4 方向，实际探针数为 {result.FrameProbeCount}。", failures);
            Require(result.FrameProbeSuccessCount == result.FrameProbeCount, "存在动作/方向探针失败。", failures);
            Require(result.GameViewScreenshot, "截图来源不是当前 GameView。", failures);
            Require(!result.UsesRenderTexture, "验收仍使用 RenderTexture 离屏截图。", failures);
            Require(!result.UsesTemporaryCamera, "验收仍使用临时相机截图。", failures);
            Require(result.ScreenshotExists, "真实 GameView 完整截图没有生成。", failures);
            Require(result.ScreenshotIsCompleteGameView, $"截图不是当前 GameView 完整画面：截图 {result.ScreenshotWidth}x{result.ScreenshotHeight}，GameView {result.ScreenWidth}x{result.ScreenHeight}。", failures);
            Require(result.SampledDistinctColorCount > 1, "GameView 截图看起来是单色空画面。", failures);
            Require(!result.ScreenshotHasMagentaErrorBlock, $"GameView 截图仍有洋红错误块：像素数 {result.MagentaErrorPixelCount}，范围 {result.MagentaErrorBounds}。", failures);

            result.Success = failures.Count == 0;
            result.Failures = failures.ToArray();
            result.Message = result.Success
                ? (result.RiderEquipmentOverlayExpected
                    ? "骑手穿普通装备的坐骑真实 GameView 验收通过。"
                    : "坐骑原版素材直显真实 GameView 验收通过。")
                : string.Join(" | ", failures);
            result.Completed = true;
        }

        private static void CleanupPendingCapture()
        {
            EditorApplication.update -= TryCompleteCapture;
            if (s_pendingCapture != null && s_pendingCapture.Target != null)
                UnityEngine.Object.Destroy(s_pendingCapture.Target);

            s_pendingCapture = null;
        }

        private static Camera ResolveGameViewCamera()
        {
            if (Camera.main != null)
                return Camera.main;

            return UnityEngine.Object.FindFirstObjectByType<Camera>();
        }

        private static T LoadRequired<T>(string assetPath) where T : UnityEngine.Object
        {
            T asset = AssetDatabase.LoadAssetAtPath<T>(assetPath);
            if (asset == null)
                throw new InvalidOperationException($"缺少资源：{assetPath}");

            return asset;
        }

        private static bool HasReference(SerializedObject serialized, string propertyName)
        {
            SerializedProperty property = serialized.FindProperty(propertyName);
            return property != null && property.objectReferenceValue != null;
        }

        private static SpriteRenderer GetReferencedSpriteRenderer(UnityEngine.Object target, string propertyName)
        {
            SerializedObject serialized = new(target);
            SerializedProperty property = serialized.FindProperty(propertyName);
            return property != null ? property.objectReferenceValue as SpriteRenderer : null;
        }

        private static void InspectRiderFrameUvMaps(ValidationResult result, EquipmentRenderer riderEquipmentRenderer)
        {
            CharacterFrameData frameData = riderEquipmentRenderer != null ? riderEquipmentRenderer.frameData : null;
            AnimationData idle = frameData != null ? frameData.GetAnimationByKey("Idle") : null;
            AnimationData walk = frameData != null ? frameData.GetAnimationByKey("Walk") : null;

            result.RiderIdleBodyUvMapFound = idle != null && idle.bodyUVMap != null;
            result.RiderIdleHeadUvMapFound = idle != null && idle.headUVMap != null;
            result.RiderWalkBodyUvMapFound = walk != null && walk.bodyUVMap != null;
            result.RiderWalkHeadUvMapFound = walk != null && walk.headUVMap != null;
        }

        private static void InvokeMountedTick(MountedCharacterPresentation mountedPresentation, float deltaTime)
        {
            if (mountedPresentation == null)
                return;

            MethodInfo method = typeof(MountedCharacterPresentation).GetMethod(
                "TickMountedPresentation",
                BindingFlags.Instance | BindingFlags.NonPublic);
            if (method == null)
                throw new MissingMethodException(typeof(MountedCharacterPresentation).FullName, "TickMountedPresentation");

            method.Invoke(mountedPresentation, new object[] { deltaTime });
        }

        private static string GetMaterialShaderName(SpriteRenderer renderer)
        {
            Material material = renderer != null ? renderer.sharedMaterial : null;
            Shader shader = material != null ? material.shader : null;
            return shader != null ? shader.name : string.Empty;
        }

        private static bool IsEquipmentUvShader(string shaderName)
        {
            return string.Equals(shaderName, "EquipmentSystem/EquipmentUV", StringComparison.Ordinal);
        }

        private static string GetTransformPath(Transform target)
        {
            if (target == null)
                return string.Empty;

            string path = target.name;
            Transform current = target.parent;
            while (current != null)
            {
                path = current.name + "/" + path;
                current = current.parent;
            }

            return path;
        }

        private static string FormatVector3(Vector3 value)
        {
            return $"{value.x:0.###},{value.y:0.###},{value.z:0.###}";
        }

        private static void WriteResult(ValidationResult result)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(result.ResultPath)!);
            File.WriteAllText(result.ResultPath, JsonUtility.ToJson(result, true));
        }

        private static void Require(bool condition, string failure, List<string> failures)
        {
            if (!condition)
                failures.Add(failure);
        }

        private sealed class PendingCapture
        {
            public ValidationResult Result;
            public GameObject Target;
            public int TargetFrame;
            public bool CaptureRequested;
            public double CaptureRequestTime;
        }

        [Serializable]
        public sealed class StartResult
        {
            public string ResultPath = string.Empty;
            public string ScreenshotPath = string.Empty;
        }

        [Serializable]
        public sealed class StatusResult
        {
            public string ResultPath = string.Empty;
            public string ScreenshotPath = string.Empty;
            public bool Pending;
            public string ResultJson = string.Empty;
        }

        [Serializable]
        public sealed class ValidationResult
        {
            public bool Completed;
            public bool Success;
            public string Message = string.Empty;
            public string SourceMode = string.Empty;
            public string CaptureSource = string.Empty;
            public string ResultPath = string.Empty;
            public string ExpectedScenePath = string.Empty;
            public string ScenePath = string.Empty;
            public bool SceneMatchesExpected;
            public bool PlayMode;
            public int ScreenWidth;
            public int ScreenHeight;

            public string PrefabPath = string.Empty;
            public bool PrefabFound;
            public bool PrefabHasEquipmentRenderer;
            public bool PrefabHasMountedPresentation;
            public bool PrefabHasCharacterEquipmentPresentation;
            public bool PrefabHasCharacterEquipment;
            public string PrefabEquipmentRendererPath = string.Empty;
            public string PrefabMountedPresentationPath = string.Empty;
            public string PrefabCharacterEquipmentPresentationPath = string.Empty;
            public bool PrefabMountedHasActionDriver;
            public bool PrefabMountedHasDirectionDriver;
            public bool PrefabMountedHasRiderRenderer;
            public bool PrefabMountedHasMountRenderer;
            public bool PrefabMountedHasOptionalEquipmentRenderer;
            public bool PrefabEquipmentPresentationHasMountedPresentation;

            public string WorkbenchCatalogPath = string.Empty;
            public bool WorkbenchCatalogFound;
            public bool WorkbenchCatalogHasMountOption;
            public bool WorkbenchControllerFound;
            public bool WorkbenchRuntimeUiFound;
            public bool WorkbenchControllerBoundToCharacterEquipment;
            public int WorkbenchControllerMountOptionCount;
            public bool WorkbenchControllerHasWarHorseMountOption;
            public bool WorkbenchUiMountChipVisible;
            public bool WorkbenchUiMountChipClicked;
            public bool WorkbenchUiMountOptionVisible;
            public bool WorkbenchUiMountOptionClicked;
            public bool WorkbenchScreenshotMountListRestored;
            public bool WorkbenchScreenshotMountOptionVisible;
            public bool WorkbenchControllerEquippedMountOptionMatches;

            public string MountDataPath = string.Empty;
            public string MountEquipmentPath = string.Empty;
            public bool MountDataFound;
            public bool MountEquipmentFound;
            public bool MountEquipmentVisualIsMountData;
            public bool RiderFrameDataFound;
            public bool OriginalSpriteDirectMode;
            public int ScenePreviewRenderersHidden;
            public string[] ScenePreviewRendererPaths = Array.Empty<string>();
            public bool RiderEquipmentOverlayExpected;
            public string RiderEquipmentPath = string.Empty;
            public bool RiderEquipmentFound;
            public bool RiderEquipmentVisualIsEquipmentRenderData;
            public bool WorkbenchUiRiderCategoryVisible;
            public bool WorkbenchUiRiderCategoryClicked;
            public bool WorkbenchUiRiderOptionVisible;
            public bool WorkbenchUiRiderOptionClicked;
            public bool RiderEquipmentSelectedThroughWorkbenchUi;
            public bool RiderEquipmentVisualAppliedToRenderer;
            public bool RiderEquipmentOverlayEnabled;
            public int RiderEquippedSlotCount;
            public bool RiderIdleBodyUvMapFound;
            public bool RiderIdleHeadUvMapFound;
            public bool RiderWalkBodyUvMapFound;
            public bool RiderWalkHeadUvMapFound;

            public string CameraName = string.Empty;
            public string CameraPath = string.Empty;
            public bool CameraOrthographic;
            public float CameraOrthographicSize;
            public string TargetObjectPath = string.Empty;
            public string TargetPosition = string.Empty;
            public bool RuntimeHasCharacterEquipment;
            public bool RuntimeHasCharacterEquipmentPresentation;
            public bool RuntimeHasMountedPresentation;
            public bool RuntimeHasActionDriver;
            public bool RuntimeHasDirectionDriver;
            public bool RuntimeHasRiderEquipmentRenderer;
            public bool RuntimeHasCharacter;
            public string EquipOperationResult = string.Empty;
            public string EquipOperationMode = string.Empty;
            public string EquipOperationException = string.Empty;
            public bool MountEquippedThroughCharacterEquipment;
            public bool MountedPresentationActivated;
            public bool RiderOriginalSpriteDirectMode;

            public int FrameProbeCount;
            public int FrameProbeSuccessCount;
            public FrameProbeResult[] FrameProbes = Array.Empty<FrameProbeResult>();
            public string FinalAnimationKey = string.Empty;
            public string FinalDirection = string.Empty;
            public string RiderMaterialShaderName = string.Empty;
            public string MountMaterialShaderName = string.Empty;
            public bool RiderUsesEquipmentUvShader;
            public bool MountUsesEquipmentUvShader;

            public bool GameViewScreenshot;
            public bool UsesRenderTexture;
            public bool UsesTemporaryCamera;
            public int CaptureRequestedFrame;
            public string ScreenshotPath = string.Empty;
            public bool ScreenshotExists;
            public int ScreenshotBytes;
            public int ScreenshotWidth;
            public int ScreenshotHeight;
            public bool ScreenshotMatchesScreenSize;
            public bool ScreenshotIsCompleteGameView;
            public int SampledDistinctColorCount;
            public bool ScreenshotHasMagentaErrorBlock;
            public int MagentaErrorPixelCount;
            public string MagentaErrorBounds = string.Empty;
            public string[] Failures = Array.Empty<string>();
        }

        [Serializable]
        public sealed class FrameProbeResult
        {
            public bool Success;
            public string SourceMode = string.Empty;
            public string AnimationKey = string.Empty;
            public string MountActionKey = string.Empty;
            public string Direction = string.Empty;
            public bool AnimationResolved;
            public bool UsedFallbackAction;
            public int ExpectedFrameCount;
            public int ExpectedSecondFrameIndex;
            public string ExpectedFirstMountSpriteName = string.Empty;
            public string ExpectedFirstRiderSpriteName = string.Empty;
            public string FirstMountSpriteName = string.Empty;
            public string FirstRiderSpriteName = string.Empty;
            public bool FirstMountFrameMatches;
            public bool FirstRiderFrameMatches;
            public string ExpectedSecondMountSpriteName = string.Empty;
            public string ExpectedSecondRiderSpriteName = string.Empty;
            public string SecondMountSpriteName = string.Empty;
            public string SecondRiderSpriteName = string.Empty;
            public bool SecondMountFrameMatches;
            public bool SecondRiderFrameMatches;
            public bool MountAdvancedToNextFrame;
            public bool RiderAdvancedToNextFrame;
            public string MountSpriteName = string.Empty;
            public string RiderSpriteName = string.Empty;
            public bool MountRendererEnabled;
            public bool RiderRendererEnabled;
            public bool RiderOriginalSpriteDirectMode;
            public string RiderMaterialShaderName = string.Empty;
            public string MountMaterialShaderName = string.Empty;
            public bool RiderUsesEquipmentUvShader;
            public bool MountUsesEquipmentUvShader;
            public string[] Failures = Array.Empty<string>();
        }
    }
}



