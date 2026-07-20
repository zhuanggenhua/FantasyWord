using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace FantasyWord.Presentation.EquipmentSystem
{
    /// <summary>
    /// 从当前真实 GameView 连续抓取骑乘 Idle/Walk 帧。
    /// 输出帧只用于编码验收 GIF，不使用 RenderTexture、临时相机或离线素材拼贴。
    /// </summary>
    public static class MountRuntimeGameViewSequenceCapture
    {
        private const string ExpectedScenePath = "Assets/Scenes/EquipmentSystemDemo.unity";
        private const string OutputDirectoryRelativePath = "Temp/UnityBridge/results/mount-equipped-rider-sequence";
        private const string ResultRelativePath = "Temp/UnityBridge/results/mount-equipped-rider-sequence.json";
        private const int IdleFrameCount = 12;
        private const int WalkFrameCount = 12;
        // 使用半帧周期连续采样，避免采样频率与动画帧长相同后固定跳过某一帧。
        private const double CaptureIntervalSeconds = 0.1d;
        private const double CaptureTimeoutSeconds = 10d;

        private static PendingSequence s_pending;

        public static string OutputDirectory => Path.GetFullPath(OutputDirectoryRelativePath);
        public static string ResultPath => Path.GetFullPath(ResultRelativePath);

        public static SequenceStartResult Start()
        {
            Cleanup(destroyTarget: true);
            if (!Application.isPlaying)
                throw new InvalidOperationException("坐骑连续帧验收只能在 PlayMode 下启动。");

            string activeScenePath = SceneManager.GetActiveScene().path;
            if (!string.Equals(activeScenePath, ExpectedScenePath, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException(
                    $"当前场景不是装备测试入口。当前：{activeScenePath}；预期：{ExpectedScenePath}");
            }

            Directory.CreateDirectory(OutputDirectory);
            foreach (string framePath in Directory.GetFiles(OutputDirectory, "frame-*.png"))
                File.Delete(framePath);

            SequenceResult result = new()
            {
                Completed = false,
                Success = false,
                ScenePath = activeScenePath,
                CaptureSource = "ScreenCapture.CaptureScreenshot(CurrentGameView)",
                ScreenWidth = Screen.width,
                ScreenHeight = Screen.height,
                OutputDirectory = OutputDirectory,
                ResultPath = ResultPath,
            };

            MountRuntimeGameViewValidator.ValidationResult setup = new()
            {
                RiderEquipmentOverlayExpected = true,
                OriginalSpriteDirectMode = false,
            };
            GameObject target = MountRuntimeGameViewValidator.InstantiateMountedCharacterForGameView(setup, true);
            MountedCharacterPresentation mounted = target.GetComponentInChildren<MountedCharacterPresentation>(true);
            CharacterActionAnimatorDriver actionDriver = target.GetComponentInChildren<CharacterActionAnimatorDriver>(true);
            DirectionalSpriteLibraryDriver directionDriver = target.GetComponentInChildren<DirectionalSpriteLibraryDriver>(true);
            if (mounted == null || actionDriver == null || directionDriver == null || mounted.ActiveMount == null)
            {
                UnityEngine.Object.Destroy(target);
                throw new InvalidOperationException("连续帧验收角色缺少坐骑表现、动作驱动、方向驱动或当前坐骑资产。");
            }

            AnimationTypeItem idle = actionDriver.AnimationDatabase?.GetByKey("Idle");
            AnimationTypeItem walk = actionDriver.AnimationDatabase?.GetByKey("Walk");
            if (idle == null || walk == null)
            {
                UnityEngine.Object.Destroy(target);
                throw new InvalidOperationException("连续帧验收缺少 Idle 或 Walk 动作资产。");
            }

            SpriteRenderer riderRenderer = target.GetComponentInChildren<EquipmentRenderer>(true)?.GetComponent<SpriteRenderer>();
            SpriteRenderer mountRenderer = ResolveMountRenderer(mounted);
            if (riderRenderer == null || mountRenderer == null)
            {
                UnityEngine.Object.Destroy(target);
                throw new InvalidOperationException("连续帧验收缺少骑手或坐骑本体 SpriteRenderer。");
            }

            directionDriver.SetDirection(CharacterAnimationDirections.SouthEast);
            ResetAnimation(mounted, actionDriver, idle);

            s_pending = new PendingSequence
            {
                Result = result,
                Target = target,
                Mounted = mounted,
                ActionDriver = actionDriver,
                Idle = idle,
                Walk = walk,
                RiderRenderer = riderRenderer,
                MountRenderer = mountRenderer,
                NextCaptureTime = EditorApplication.timeSinceStartup + 0.1d,
            };

            WriteResult(result);
            EditorApplication.update -= Tick;
            EditorApplication.update += Tick;
            return new SequenceStartResult
            {
                ResultPath = ResultPath,
                OutputDirectory = OutputDirectory,
            };
        }

        private static void Tick()
        {
            PendingSequence pending = s_pending;
            if (pending == null)
            {
                EditorApplication.update -= Tick;
                return;
            }

            try
            {
                if (!Application.isPlaying)
                    throw new InvalidOperationException("连续帧抓取完成前已退出 PlayMode。");

                if (pending.CaptureRequested)
                {
                    if (File.Exists(pending.PendingFramePath)
                        && new FileInfo(pending.PendingFramePath).Length > 0)
                    {
                        pending.CaptureRequested = false;
                        pending.CapturedFrames.Add(pending.PendingFrame);
                        pending.PendingFrame = null;
                        pending.PendingFramePath = string.Empty;
                        pending.FrameIndex++;
                        pending.NextCaptureTime = EditorApplication.timeSinceStartup + CaptureIntervalSeconds;
                        if (pending.FrameIndex >= IdleFrameCount + WalkFrameCount)
                            Complete(pending);
                    }
                    else if (EditorApplication.timeSinceStartup - pending.CaptureRequestTime >= CaptureTimeoutSeconds)
                    {
                        throw new TimeoutException($"等待连续帧截图超时：{pending.PendingFramePath}");
                    }

                    return;
                }

                if (EditorApplication.timeSinceStartup < pending.NextCaptureTime)
                    return;

                if (pending.FrameIndex == IdleFrameCount && !pending.WalkStarted)
                {
                    pending.WalkStarted = true;
                    ResetAnimation(pending.Mounted, pending.ActionDriver, pending.Walk);
                }

                string actionKey = pending.WalkStarted ? "Walk" : "Idle";
                string framePath = Path.Combine(OutputDirectory, $"frame-{pending.FrameIndex:00}.png");
                SequenceFrame frame = new()
                {
                    Index = pending.FrameIndex,
                    ActionKey = actionKey,
                    Direction = CharacterAnimationDirections.GetName(CharacterAnimationDirections.SouthEast),
                    RequestedGameFrame = Time.frameCount,
                    MountSpriteName = GetSpriteName(pending.MountRenderer.sprite),
                    RiderSpriteName = GetSpriteName(pending.RiderRenderer.sprite),
                    Path = framePath,
                };

                pending.PendingFrame = frame;
                pending.PendingFramePath = framePath;
                pending.CaptureRequested = true;
                pending.CaptureRequestTime = EditorApplication.timeSinceStartup;
                ScreenCapture.CaptureScreenshot(framePath, 1);
            }
            catch (Exception exception)
            {
                pending.Result.Completed = true;
                pending.Result.Success = false;
                pending.Result.Message = exception.ToString();
                pending.Result.Failures = new[] { exception.ToString() };
                WriteResult(pending.Result);
                Cleanup(destroyTarget: true);
            }
        }

        private static void Complete(PendingSequence pending)
        {
            List<string> failures = new();
            HashSet<string> idleMountSprites = new(StringComparer.Ordinal);
            HashSet<string> walkMountSprites = new(StringComparer.Ordinal);
            HashSet<string> idleRiderSprites = new(StringComparer.Ordinal);
            HashSet<string> walkRiderSprites = new(StringComparer.Ordinal);

            for (int i = 0; i < pending.CapturedFrames.Count; i++)
            {
                SequenceFrame frame = pending.CapturedFrames[i];
                if (!File.Exists(frame.Path) || new FileInfo(frame.Path).Length == 0)
                {
                    failures.Add($"连续帧文件不存在或为空：{frame.Path}");
                }
                else
                {
                    InspectFrameImage(frame, pending.Result.ScreenWidth, pending.Result.ScreenHeight, failures);
                }
                if (string.IsNullOrWhiteSpace(frame.MountSpriteName) || string.IsNullOrWhiteSpace(frame.RiderSpriteName))
                    failures.Add($"连续帧 {frame.Index} 缺少坐骑本体或骑手 Sprite。 ");

                HashSet<string> mountSet = frame.ActionKey == "Idle" ? idleMountSprites : walkMountSprites;
                HashSet<string> riderSet = frame.ActionKey == "Idle" ? idleRiderSprites : walkRiderSprites;
                mountSet.Add(frame.MountSpriteName);
                riderSet.Add(frame.RiderSpriteName);
            }

            if (pending.CapturedFrames.Count != IdleFrameCount + WalkFrameCount)
                failures.Add($"连续帧数量不正确：{pending.CapturedFrames.Count}。 ");
            if (idleMountSprites.Count < 4 || idleRiderSprites.Count < 4)
                failures.Add("Idle 连续帧没有观察到足够的本体/骑手 Sprite 变化。");
            if (walkMountSprites.Count < 4 || walkRiderSprites.Count < 4)
                failures.Add("Walk 连续帧没有观察到完整的本体/骑手四帧变化。");

            pending.Result.Frames = pending.CapturedFrames.ToArray();
            pending.Result.IdleDistinctMountSprites = idleMountSprites.Count;
            pending.Result.IdleDistinctRiderSprites = idleRiderSprites.Count;
            pending.Result.WalkDistinctMountSprites = walkMountSprites.Count;
            pending.Result.WalkDistinctRiderSprites = walkRiderSprites.Count;
            pending.Result.AllFramesCompleteGameView = pending.CapturedFrames.TrueForAll(
                frame => frame.CompleteGameView && !frame.HasMagentaErrorBlock);
            pending.Result.Completed = true;
            pending.Result.Success = failures.Count == 0;
            pending.Result.Message = pending.Result.Success
                ? "骑乘 Idle/Walk 真实 GameView 连续帧抓取通过。"
                : string.Join(" | ", failures);
            pending.Result.Failures = failures.ToArray();
            WriteResult(pending.Result);
            Cleanup(destroyTarget: true);
        }

        private static void InspectFrameImage(
            SequenceFrame frame,
            int expectedWidth,
            int expectedHeight,
            List<string> failures)
        {
            Texture2D texture = new(2, 2, TextureFormat.RGBA32, false);
            try
            {
                if (!texture.LoadImage(File.ReadAllBytes(frame.Path)))
                {
                    failures.Add($"连续帧 {frame.Index} 不是有效 PNG。 ");
                    return;
                }

                frame.Width = texture.width;
                frame.Height = texture.height;
                frame.CompleteGameView = frame.Width == expectedWidth && frame.Height == expectedHeight;
                if (!frame.CompleteGameView)
                {
                    failures.Add(
                        $"连续帧 {frame.Index} 不是完整 GameView："
                        + $"截图 {frame.Width}x{frame.Height}，GameView {expectedWidth}x{expectedHeight}。 ");
                }

                Color32[] pixels = texture.GetPixels32();
                HashSet<int> sampledColors = new();
                int sampleStep = Mathf.Max(1, pixels.Length / 4096);
                for (int i = 0; i < pixels.Length; i += sampleStep)
                {
                    Color32 pixel = pixels[i];
                    sampledColors.Add((pixel.r << 24) | (pixel.g << 16) | (pixel.b << 8) | pixel.a);
                }

                frame.SampledDistinctColorCount = sampledColors.Count;
                if (frame.SampledDistinctColorCount <= 1)
                    failures.Add($"连续帧 {frame.Index} 看起来是单色空画面。 ");

                int magentaPixels = 0;
                for (int i = 0; i < pixels.Length; i++)
                {
                    Color32 pixel = pixels[i];
                    if (pixel.a >= 250 && pixel.r >= 230 && pixel.g <= 30 && pixel.b >= 220)
                        magentaPixels++;
                }

                frame.MagentaErrorPixelCount = magentaPixels;
                frame.HasMagentaErrorBlock = magentaPixels > 256;
                if (frame.HasMagentaErrorBlock)
                    failures.Add($"连续帧 {frame.Index} 有洋红错误块，像素数 {magentaPixels}。 ");
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(texture);
            }
        }

        private static void ResetAnimation(
            MountedCharacterPresentation mounted,
            CharacterActionAnimatorDriver actionDriver,
            AnimationTypeItem animation)
        {
            MountRenderData mount = mounted.ActiveMount;
            actionDriver.SetAnimation(animation);
            mounted.SetMount(null);
            mounted.SetMount(mount);
        }

        private static SpriteRenderer ResolveMountRenderer(MountedCharacterPresentation mounted)
        {
            SerializedObject serialized = new(mounted);
            return serialized.FindProperty("mountRenderer")?.objectReferenceValue as SpriteRenderer;
        }

        private static string GetSpriteName(Sprite sprite)
        {
            return sprite != null ? sprite.name : string.Empty;
        }

        private static void Cleanup(bool destroyTarget)
        {
            EditorApplication.update -= Tick;
            if (destroyTarget && s_pending?.Target != null)
                UnityEngine.Object.Destroy(s_pending.Target);
            s_pending = null;
        }

        private static void WriteResult(SequenceResult result)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(ResultPath)!);
            File.WriteAllText(ResultPath, JsonUtility.ToJson(result, true));
        }

        private sealed class PendingSequence
        {
            public SequenceResult Result;
            public GameObject Target;
            public MountedCharacterPresentation Mounted;
            public CharacterActionAnimatorDriver ActionDriver;
            public AnimationTypeItem Idle;
            public AnimationTypeItem Walk;
            public SpriteRenderer RiderRenderer;
            public SpriteRenderer MountRenderer;
            public readonly List<SequenceFrame> CapturedFrames = new();
            public int FrameIndex;
            public bool WalkStarted;
            public bool CaptureRequested;
            public double CaptureRequestTime;
            public double NextCaptureTime;
            public string PendingFramePath = string.Empty;
            public SequenceFrame PendingFrame;
        }

        [Serializable]
        public sealed class SequenceStartResult
        {
            public string ResultPath = string.Empty;
            public string OutputDirectory = string.Empty;
        }

        [Serializable]
        public sealed class SequenceResult
        {
            public bool Completed;
            public bool Success;
            public string Message = string.Empty;
            public string ScenePath = string.Empty;
            public string CaptureSource = string.Empty;
            public int ScreenWidth;
            public int ScreenHeight;
            public string OutputDirectory = string.Empty;
            public string ResultPath = string.Empty;
            public int IdleDistinctMountSprites;
            public int IdleDistinctRiderSprites;
            public int WalkDistinctMountSprites;
            public int WalkDistinctRiderSprites;
            public bool AllFramesCompleteGameView;
            public SequenceFrame[] Frames = Array.Empty<SequenceFrame>();
            public string[] Failures = Array.Empty<string>();
        }

        [Serializable]
        public sealed class SequenceFrame
        {
            public int Index;
            public string ActionKey = string.Empty;
            public string Direction = string.Empty;
            public int RequestedGameFrame;
            public string MountSpriteName = string.Empty;
            public string RiderSpriteName = string.Empty;
            public string Path = string.Empty;
            public int Width;
            public int Height;
            public bool CompleteGameView;
            public int SampledDistinctColorCount;
            public int MagentaErrorPixelCount;
            public bool HasMagentaErrorBlock;
        }
    }
}
