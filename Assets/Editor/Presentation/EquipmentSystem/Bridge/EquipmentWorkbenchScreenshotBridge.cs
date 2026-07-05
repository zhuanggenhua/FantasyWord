using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace FantasyWord.Presentation.EquipmentSystem
{
    /// <summary>
    /// 为换装预览入口的端到端验证提供最小 Unity 内部截图入口。
    /// 只负责在 PlayMode 中延迟若干帧后导出当前 GameView。
    /// </summary>
    public static class EquipmentWorkbenchScreenshotBridge
    {
        static string s_outputPath;
        static int s_targetFrame;
        static bool s_pending;
        static bool s_captureRequested;
        static double s_captureRequestTime;
        const double CaptureFileTimeoutSeconds = 10d;
        const double CaptureReadyTimeoutSeconds = 12d;

        [Serializable]
        public sealed class ScheduleResult
        {
            public bool Success;
            public string Message = string.Empty;
            public string OutputPath = string.Empty;
            public int CurrentFrame;
            public int TargetFrame;
            public bool Pending;
        }

        public static ScheduleResult ScheduleCapture(string outputFileName = "EquipmentWorkbenchE2E-bridge.png", int frameDelay = 8)
        {
            if (!Application.isPlaying)
            {
                return new ScheduleResult
                {
                    Success = false,
                    Message = "当前不在 PlayMode，无法抓取换装预览运行画面。",
                };
            }

            string projectRoot = Directory.GetParent(Application.dataPath)?.FullName ?? Directory.GetCurrentDirectory();
            string outputDirectory = Path.Combine(projectRoot, "Temp", "UnityBridge");
            Directory.CreateDirectory(outputDirectory);

            s_outputPath = Path.Combine(outputDirectory, outputFileName);
            if (File.Exists(s_outputPath))
                File.Delete(s_outputPath);

            s_targetFrame = Time.frameCount + Mathf.Max(1, frameDelay);
            s_pending = true;
            s_captureRequested = false;
            s_captureRequestTime = 0d;

            EditorApplication.update -= TryCaptureOnUpdate;
            EditorApplication.update += TryCaptureOnUpdate;

            return new ScheduleResult
            {
                Success = true,
                Message = "已登记截图请求。",
                OutputPath = s_outputPath,
                CurrentFrame = Time.frameCount,
                TargetFrame = s_targetFrame,
                Pending = true,
            };
        }

        public static string ScheduleDefaultCapture()
        {
            ScheduleResult result = ScheduleCapture();
            return result.OutputPath;
        }

        public static string GetLatestOutputPath()
        {
            return s_outputPath ?? string.Empty;
        }

        public static bool IsCapturePending()
        {
            return s_pending;
        }

        public static ScheduleResult GetStatus()
        {
            FileInfo info = !string.IsNullOrEmpty(s_outputPath) && File.Exists(s_outputPath)
                ? new FileInfo(s_outputPath)
                : null;

            return new ScheduleResult
            {
                Success = info != null,
                Message = info != null ? "截图文件已生成。" : s_pending ? "截图仍在等待执行。" : "当前没有已生成截图文件。",
                OutputPath = s_outputPath ?? string.Empty,
                CurrentFrame = Time.frameCount,
                TargetFrame = s_targetFrame,
                Pending = s_pending,
            };
        }

        static void TryCaptureOnUpdate()
        {
            if (!s_pending)
            {
                EditorApplication.update -= TryCaptureOnUpdate;
                return;
            }

            if (!Application.isPlaying)
                return;

            if (!s_captureRequested && Time.frameCount < s_targetFrame)
                return;

            if (!s_captureRequested)
            {
                if (!IsWorkbenchVisualReady())
                {
                    if (s_captureRequestTime <= 0d)
                        s_captureRequestTime = EditorApplication.timeSinceStartup;

                    if (EditorApplication.timeSinceStartup - s_captureRequestTime < CaptureReadyTimeoutSeconds)
                        return;

                    Debug.LogWarning("[EquipmentWorkbenchScreenshotBridge] UI/角色画面未完全就绪，达到等待上限后继续截图。");
                }

                s_captureRequested = true;
                s_captureRequestTime = EditorApplication.timeSinceStartup;
                ScreenCapture.CaptureScreenshot(s_outputPath, 1);
                Debug.Log($"[EquipmentWorkbenchScreenshotBridge] Screenshot requested: {s_outputPath}");
                return;
            }

            if (File.Exists(s_outputPath))
            {
                FileInfo info = new FileInfo(s_outputPath);
                if (info.Length > 0)
                {
                    Debug.Log($"[EquipmentWorkbenchScreenshotBridge] Screenshot written: {s_outputPath}");
                    s_pending = false;
                    EditorApplication.update -= TryCaptureOnUpdate;
                }
                return;
            }

            if (EditorApplication.timeSinceStartup - s_captureRequestTime >= CaptureFileTimeoutSeconds)
            {
                Debug.LogWarning($"[EquipmentWorkbenchScreenshotBridge] Screenshot timeout: {s_outputPath}");
                s_pending = false;
                EditorApplication.update -= TryCaptureOnUpdate;
            }
        }

        static bool IsWorkbenchVisualReady()
        {
            GameObject workbenchRoot = GameObject.Find("EquipmentWorkbenchUIRoot");
            if (workbenchRoot == null || !workbenchRoot.activeInHierarchy)
                return false;

            Button[] buttons = workbenchRoot.GetComponentsInChildren<Button>(true);
            bool hasAttackButton = buttons.Any(button =>
                button != null
                && button.gameObject.activeInHierarchy
                && button.GetComponentsInChildren<TMPro.TextMeshProUGUI>(true)
                    .Any(label => label != null && label.text == "攻击"));
            if (!hasAttackButton)
                return false;

            ScrollRect[] scrollRects = workbenchRoot.GetComponentsInChildren<ScrollRect>(true);
            bool hasAnimationScroll = scrollRects.Any(scroll =>
                scroll != null
                && scroll.gameObject.activeInHierarchy
                && scroll.content != null
                && scroll.content.name.IndexOf("Animation", StringComparison.OrdinalIgnoreCase) >= 0
                && scroll.content.childCount >= 20);
            bool hasEquipmentScroll = scrollRects.Any(scroll =>
                scroll != null
                && scroll.gameObject.activeInHierarchy
                && scroll.content != null
                && scroll.content.name.IndexOf("Equipment", StringComparison.OrdinalIgnoreCase) >= 0
                && scroll.content.childCount >= 2);
            if (!hasAnimationScroll || !hasEquipmentScroll)
                return false;

            GameObject character = GameObject.Find("EquipmentSystemDemoCharacter");
            SpriteRenderer renderer = character != null ? character.GetComponent<SpriteRenderer>() : null;
            return renderer != null
                && renderer.enabled
                && renderer.sprite != null
                && renderer.color.a > 0.01f;
        }
    }
}
