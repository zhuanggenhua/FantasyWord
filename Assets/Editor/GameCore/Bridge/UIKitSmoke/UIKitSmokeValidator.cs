using System;
using System.Collections.Generic;
using UnityEngine;
using YokiFrame;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// UIKit 面板栈专项的正式 smoke 入口。
    /// 这里只验证生命周期、栈、焦点 API、缓存退场和资源链，不触碰具体业务菜单。
    /// </summary>
    public static class UIKitSmokeValidator
    {
        private const string SmokeStackName = "fw_uikit_smoke";
        private const string SmokeTag = "fw-uikit-smoke";

        [Serializable]
        public sealed class UIKitSmokeValidationResult
        {
            public bool Success;
            public string Message;
            public string StackName = SmokeStackName;
            public string PanelTag = SmokeTag;
            public UIKitSmokeResourceEvidence Resources = new();
            public UIKitSmokePanelEvidence PrimaryAfterFirstPush = new();
            public UIKitSmokePanelEvidence SecondaryAfterSecondPush = new();
            public UIKitSmokePanelEvidence PrimaryAfterSecondaryPop = new();
            public int StackDepthAfterPrimaryPush;
            public int StackDepthAfterSecondaryPush;
            public int StackDepthAfterSecondaryPop;
            public int FinalStackDepth;
            public bool FocusClearedWhenSecondaryClosed;
            public bool PrimaryPanelClearedAfterCleanup;
            public bool SecondaryPanelClearedAfterCleanup;
            public string[] Failures = Array.Empty<string>();
        }

        [Serializable]
        public sealed class UIKitSmokeResourceEvidence
        {
            public bool UIKitRootPrefabFound;
            public bool PrimaryPanelPrefabFound;
            public bool SecondaryPanelPrefabFound;
        }

        [Serializable]
        public sealed class UIKitSmokePanelEvidence
        {
            public string PanelType;
            public bool GetPanelMatchesOpenedInstance;
            public bool IsTopPanelAtLevel;
            public bool ManualFocusWorked;
            public UIKitSmokePanelSnapshot Snapshot;
        }

        public static UIKitSmokeValidationResult Run()
        {
            UIKitSmokeValidationResult result = new();
            List<string> failures = new();

            if (!Application.isPlaying)
            {
                result.Message = "UIKit smoke 只能在 PlayMode 下运行。";
                result.Failures = new[] { result.Message };
                return result;
            }

            bool previousHotCacheEnabled = UIKit.HotCacheEnabled;
            bool previousFocusSystemEnabled = UIKit.FocusSystemEnabled;

            try
            {
                UIKit.HotCacheEnabled = false;
                UIKit.FocusSystemEnabled = true;
                CleanupSmokeArtifacts();

                result.Resources = CaptureResources();
                Require(result.Resources.UIKitRootPrefabFound, "缺少 UIKit 根 prefab：Resources/UIKit.prefab。", failures);
                Require(result.Resources.PrimaryPanelPrefabFound, "缺少主 smoke 面板 prefab：Resources/Art/UIPrefab/UIKitSmokePrimaryPanel.prefab。", failures);
                Require(result.Resources.SecondaryPanelPrefabFound, "缺少次 smoke 面板 prefab：Resources/Art/UIPrefab/UIKitSmokeSecondaryPanel.prefab。", failures);

                UIKitSmokePrimaryPanel primaryPanel = OpenSmokePanel<UIKitSmokePrimaryPanel>(failures);
                if (primaryPanel == null)
                {
                    return FinalizeResult(result, failures);
                }

                UIKit.PushPanel(primaryPanel, SmokeStackName, true);
                result.StackDepthAfterPrimaryPush = UIKit.GetStackDepth(SmokeStackName);
                result.PrimaryAfterFirstPush = CapturePanelEvidence(primaryPanel);
                result.PrimaryAfterFirstPush.ManualFocusWorked = TryFocusDefaultSelectable(primaryPanel);

                Require(result.StackDepthAfterPrimaryPush == 1, "主 smoke 面板入栈后，栈深度应为 1。", failures);
                Require(result.PrimaryAfterFirstPush.GetPanelMatchesOpenedInstance, "UIKit.GetPanel<UIKitSmokePrimaryPanel>() 没有返回已打开的主 smoke 面板实例。", failures);
                Require(result.PrimaryAfterFirstPush.IsTopPanelAtLevel, "主 smoke 面板入栈后没有成为目标层级的顶部面板。", failures);
                Require(result.PrimaryAfterFirstPush.ManualFocusWorked, "主 smoke 面板的默认焦点不可选中。", failures);
                Require(result.PrimaryAfterFirstPush.Snapshot.InitCount == 1, "主 smoke 面板 Init 次数不正确。", failures);
                Require(result.PrimaryAfterFirstPush.Snapshot.OpenCount == 1, "主 smoke 面板 Open 次数不正确。", failures);
                Require(result.PrimaryAfterFirstPush.Snapshot.WillShowCount == 1 && result.PrimaryAfterFirstPush.Snapshot.DidShowCount == 1, "主 smoke 面板首次显示生命周期不完整。", failures);
                Require(result.PrimaryAfterFirstPush.Snapshot.FocusCount >= 1, "主 smoke 面板入栈后没有收到焦点回调。", failures);

                UIKitSmokeSecondaryPanel secondaryPanel = OpenSmokePanel<UIKitSmokeSecondaryPanel>(failures);
                if (secondaryPanel == null)
                {
                    return FinalizeResult(result, failures);
                }

                UIKit.PushPanel(secondaryPanel, SmokeStackName, true);
                result.StackDepthAfterSecondaryPush = UIKit.GetStackDepth(SmokeStackName);
                result.SecondaryAfterSecondPush = CapturePanelEvidence(secondaryPanel);
                result.SecondaryAfterSecondPush.ManualFocusWorked = TryFocusDefaultSelectable(secondaryPanel);

                Require(result.StackDepthAfterSecondaryPush == 2, "次 smoke 面板入栈后，栈深度应为 2。", failures);
                Require(result.SecondaryAfterSecondPush.GetPanelMatchesOpenedInstance, "UIKit.GetPanel<UIKitSmokeSecondaryPanel>() 没有返回已打开的次 smoke 面板实例。", failures);
                Require(result.SecondaryAfterSecondPush.IsTopPanelAtLevel, "次 smoke 面板入栈后没有成为目标层级的顶部面板。", failures);
                Require(result.SecondaryAfterSecondPush.ManualFocusWorked, "次 smoke 面板的默认焦点不可选中。", failures);
                Require(result.SecondaryAfterSecondPush.Snapshot.InitCount == 1, "次 smoke 面板 Init 次数不正确。", failures);
                Require(result.SecondaryAfterSecondPush.Snapshot.OpenCount == 1, "次 smoke 面板 Open 次数不正确。", failures);
                Require(result.SecondaryAfterSecondPush.Snapshot.WillShowCount == 1 && result.SecondaryAfterSecondPush.Snapshot.DidShowCount == 1, "次 smoke 面板首次显示生命周期不完整。", failures);
                Require(result.SecondaryAfterSecondPush.Snapshot.FocusCount >= 1, "次 smoke 面板入栈后没有收到焦点回调。", failures);

                IPanel poppedPanel = UIKit.PopPanel(SmokeStackName, true, true);
                result.StackDepthAfterSecondaryPop = UIKit.GetStackDepth(SmokeStackName);
                result.FocusClearedWhenSecondaryClosed = UIKit.GetCurrentFocus() == null;
                result.PrimaryAfterSecondaryPop = CapturePanelEvidence(primaryPanel);
                result.PrimaryAfterSecondaryPop.ManualFocusWorked = TryFocusDefaultSelectable(primaryPanel);

                Require(ReferenceEquals(poppedPanel, secondaryPanel), "从 smoke 栈弹出的不是次 smoke 面板。", failures);
                Require(result.StackDepthAfterSecondaryPop == 1, "弹出次 smoke 面板后，栈深度应回到 1。", failures);
                Require(result.FocusClearedWhenSecondaryClosed, "次 smoke 面板关闭后，焦点没有从已隐藏控件上清掉。", failures);
                Require(result.PrimaryAfterSecondaryPop.ManualFocusWorked, "次 smoke 面板关闭后，主 smoke 面板无法重新获得焦点。", failures);
                Require(result.PrimaryAfterSecondaryPop.Snapshot.BlurCount >= 1, "主 smoke 面板被次面板覆盖时没有收到失焦回调。", failures);
                Require(result.PrimaryAfterSecondaryPop.Snapshot.ResumeCount >= 1, "主 smoke 面板在次面板弹出后没有收到恢复回调。", failures);
                Require(result.PrimaryAfterSecondaryPop.Snapshot.DidShowCount >= 2, "主 smoke 面板在次面板弹出后没有重新显示。", failures);
                Require(result.SecondaryAfterSecondPush.Snapshot.WillHideCount == 0, "次 smoke 面板在入栈时不应提前隐藏。", failures);

                CleanupSmokeArtifacts();

                result.FinalStackDepth = UIKit.GetStackDepth(SmokeStackName);
                result.PrimaryPanelClearedAfterCleanup = UIKit.GetPanel<UIKitSmokePrimaryPanel>() == null;
                result.SecondaryPanelClearedAfterCleanup = UIKit.GetPanel<UIKitSmokeSecondaryPanel>() == null;

                Require(result.FinalStackDepth == 0, "smoke 清理后栈深度应为 0。", failures);
                Require(result.PrimaryPanelClearedAfterCleanup, "smoke 清理后主面板仍残留在 UIKit 缓存中。", failures);
                Require(result.SecondaryPanelClearedAfterCleanup, "smoke 清理后次面板仍残留在 UIKit 缓存中。", failures);

                return FinalizeResult(result, failures);
            }
            finally
            {
                CleanupSmokeArtifacts();
                UIKit.ClearFocus();
                UIKit.FocusSystemEnabled = previousFocusSystemEnabled;
                UIKit.HotCacheEnabled = previousHotCacheEnabled;
            }
        }

        private static UIKitSmokeResourceEvidence CaptureResources()
        {
            return new UIKitSmokeResourceEvidence
            {
                UIKitRootPrefabFound = Resources.Load<GameObject>("UIKit") != null,
                PrimaryPanelPrefabFound = Resources.Load<GameObject>(BuildPanelResourcePath(typeof(UIKitSmokePrimaryPanel))) != null,
                SecondaryPanelPrefabFound = Resources.Load<GameObject>(BuildPanelResourcePath(typeof(UIKitSmokeSecondaryPanel))) != null,
            };
        }

        private static UIKitSmokePanelEvidence CapturePanelEvidence<TPanel>(TPanel panel)
            where TPanel : UIKitSmokePanelBase
        {
            return new UIKitSmokePanelEvidence
            {
                PanelType = typeof(TPanel).Name,
                GetPanelMatchesOpenedInstance = UIKit.GetPanel<TPanel>() == panel,
                IsTopPanelAtLevel = UIKit.GetTopPanelAtLevel(UILevel.Pop) == panel,
                Snapshot = panel.CreateSnapshot()
            };
        }

        private static TPanel OpenSmokePanel<TPanel>(List<string> failures)
            where TPanel : UIKitSmokePanelBase
        {
            TPanel panel = UIKit.OpenPanel<TPanel>(UILevel.Pop, null, SmokeTag);
            if (panel == null)
            {
                failures.Add($"UIKit 无法打开 {typeof(TPanel).Name}。");
                return null;
            }

            panel.ForceTemporaryCacheMode();
            return panel;
        }

        private static bool TryFocusDefaultSelectable(UIKitSmokePanelBase panel)
        {
            if (panel == null)
            {
                return false;
            }

            var selectable = panel.GetDefaultSelectable();
            if (selectable == null)
            {
                return false;
            }

            UIKit.SetFocus(selectable);
            return (UnityEngine.Object)UIKit.GetCurrentFocus() == selectable.gameObject;
        }

        private static void CleanupSmokeArtifacts()
        {
            UIKit.ClearFocus();
            UIKit.ClearStack(SmokeStackName, true);
            UIKit.ClosePanelsByTag(SmokeTag);
        }

        private static string BuildPanelResourcePath(Type panelType) =>
            $"{DefaultPanelLoaderPool.DEFAULT_PATH_PREFIX}/{panelType.Name}";

        private static void Require(bool condition, string failure, List<string> failures)
        {
            if (!condition)
            {
                failures.Add(failure);
            }
        }

        private static UIKitSmokeValidationResult FinalizeResult(UIKitSmokeValidationResult result, List<string> failures)
        {
            result.Failures = failures.ToArray();
            result.Success = failures.Count == 0;
            result.Message = result.Success
                ? "UIKit 非业务面板栈 smoke 通过。"
                : string.Join(" | ", failures);
            return result;
        }
    }
}
