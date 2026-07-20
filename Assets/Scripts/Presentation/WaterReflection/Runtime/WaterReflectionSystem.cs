using System.Collections.Generic;
using FantasyWord.GameCore;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace FantasyWord.Presentation
{
    /// <summary>
    /// 场景级水面倒影表现系统。
    /// 它统一管理反射代理的可见性和共享捕获纹理，不拥有游泳或水域玩法状态。
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class WaterReflectionSystem : AGameSystem
    {
        private static readonly int ReflectionTextureId = Shader.PropertyToID("_WaterReflectionTexture");
        private static readonly int ReflectionViewProjectionId =
            Shader.PropertyToID("_WaterReflectionViewProjection");
        private static readonly int WaterMaskTextureId = Shader.PropertyToID("_WaterMaskTex");
        private const int ReflectionTextureDepthBits = 24;

        [Header("共享捕获")]
        [Tooltip("只渲染 WaterReflectionProxy 层的正交相机。必须使用不包含 xBRZ 的独立 Renderer2D。")]
        [SerializeField] private Camera m_captureCamera;

        [Tooltip("共享捕获相机在 UniversalRP Renderer List 中的索引。")]
        [Min(0)]
        [SerializeField] private int m_captureRendererIndex = 1;

        [Tooltip("反射代理专用 Unity Layer 名称。主相机必须排除该层。")]
        [SerializeField] private string m_proxyLayerName = "WaterReflectionProxy";

        [Header("水面来源")]
        [Tooltip("当前场景中消费共享倒影纹理的水面 Renderer。其 Bounds 用于代理粗剔除。")]
        [SerializeField] private Renderer[] m_waterRenderers = System.Array.Empty<Renderer>();

        [Header("质量")]
        [Tooltip("共享倒影纹理相对主相机像素尺寸的比例。")]
        [Range(0.125f, 1f)]
        [SerializeField] private float m_captureScale = 0.5f;

        [Tooltip("相机焦点附近保持完整倒影的距离。")]
        [Min(0f)]
        [SerializeField] private float m_nearDistance = 6f;

        [Tooltip("超过该距离后关闭动态倒影代理。")]
        [Min(0.01f)]
        [SerializeField] private float m_farDistance = 12f;

        [Tooltip("关闭后保留动画水，但不更新动态倒影。")]
        [SerializeField] private bool m_dynamicReflectionEnabled = true;

        private readonly HashSet<WaterReflectionCaster2D> m_casters = new();
        private readonly Plane[] m_frustumPlanes = new Plane[6];
        private MaterialPropertyBlock m_waterPropertyBlock;
        private Texture2D m_emptyReflectionTexture;
        private RenderTexture m_reflectionTexture;
        private int m_proxyLayer = -1;
        private bool m_ready;

        public int ProxyLayer => m_proxyLayer;
        public Texture ReflectionTexture => m_reflectionTexture;

        public override void OnSystemInit()
        {
            m_proxyLayer = LayerMask.NameToLayer(m_proxyLayerName);
            m_ready = ValidateConfiguration();
            if (!m_ready)
            {
                enabled = false;
                return;
            }

            ConfigureCaptureCamera();
            EnsureReflectionTexture();
        }

        public override void OnSystemStart()
        {
            SetCaptureEnabled(m_dynamicReflectionEnabled);
        }

        public override void OnSystemStop()
        {
            SetCaptureEnabled(false);
            foreach (WaterReflectionCaster2D caster in m_casters)
            {
                if (caster != null)
                {
                    caster.ApplyRuntimeVisibility(false, 0f, 0f);
                }
            }
        }

        private void OnDestroy()
        {
            ReleaseReflectionTexture();
            ReleaseEmptyReflectionTexture();
        }

        private void LateUpdate()
        {
            if (!m_ready || !m_dynamicReflectionEnabled)
            {
                return;
            }

            Camera mainCamera = GameManager.MainCamera;
            if (mainCamera == null)
            {
                SetCaptureEnabled(false);
                return;
            }

            EnsureReflectionTexture();
            SynchronizeCaptureCamera(mainCamera);
            SetWaterReflectionTexture(m_reflectionTexture);
            UpdateCasterVisibility(mainCamera);
        }

        public void Register(WaterReflectionCaster2D caster)
        {
            if (caster == null)
            {
                return;
            }

            m_casters.Add(caster);
            caster.ConfigureRuntime(this);
        }

        public void Unregister(WaterReflectionCaster2D caster)
        {
            if (caster == null)
            {
                return;
            }

            caster.ApplyRuntimeVisibility(false, 0f, 0f);
            m_casters.Remove(caster);
        }

        public void SetDynamicReflectionEnabled(bool enabledValue)
        {
            m_dynamicReflectionEnabled = enabledValue;
            SetCaptureEnabled(enabledValue && m_ready);
            if (enabledValue)
            {
                return;
            }

            foreach (WaterReflectionCaster2D caster in m_casters)
            {
                if (caster != null)
                {
                    caster.ApplyRuntimeVisibility(false, 0f, 0f);
                }
            }
        }

        private bool ValidateConfiguration()
        {
            bool valid = true;
            if (m_captureCamera == null)
            {
                Debug.LogError("水面倒影系统缺少共享捕获相机，无法生成动态倒影。", this);
                valid = false;
            }

            if (m_proxyLayer < 0)
            {
                Debug.LogError(
                    $"水面倒影系统找不到 Unity Layer“{m_proxyLayerName}”，请在 Project Settings/Tags and Layers 中配置。",
                    this);
                valid = false;
            }

            if (m_waterRenderers == null || m_waterRenderers.Length == 0)
            {
                Debug.LogError("水面倒影系统没有配置水面 Renderer，无法执行水域范围粗剔除。", this);
                valid = false;
            }
            else
            {
                for (int i = 0; i < m_waterRenderers.Length; i++)
                {
                    Renderer waterRenderer = m_waterRenderers[i];
                    Material waterMaterial = waterRenderer != null ? waterRenderer.sharedMaterial : null;
                    if (waterMaterial == null ||
                        !waterMaterial.HasProperty(WaterMaskTextureId) ||
                        waterMaterial.GetTexture(WaterMaskTextureId) == null)
                    {
                        Debug.LogError(
                            $"水面倒影系统的第 {i + 1} 个水面 Renderer 没有绑定正式水像素 Mask，已拒绝启用倒影。",
                            this);
                        valid = false;
                    }
                    else if (!waterMaterial.HasProperty(ReflectionTextureId))
                    {
                        Debug.LogError(
                            $"水面倒影系统的第 {i + 1} 个水面 Renderer 使用的 Shader 没有共享倒影纹理属性。",
                            this);
                        valid = false;
                    }
                }
            }

            return valid;
        }

        private void ConfigureCaptureCamera()
        {
            m_captureCamera.enabled = false;
            m_captureCamera.orthographic = true;
            m_captureCamera.clearFlags = CameraClearFlags.SolidColor;
            m_captureCamera.backgroundColor = Color.clear;
            m_captureCamera.cullingMask = 1 << m_proxyLayer;
            m_captureCamera.allowHDR = false;
            m_captureCamera.allowMSAA = false;
            m_captureCamera.allowDynamicResolution = false;
            m_captureCamera.useOcclusionCulling = false;

            UniversalAdditionalCameraData cameraData =
                m_captureCamera.GetUniversalAdditionalCameraData();
            cameraData.renderPostProcessing = false;
            cameraData.requiresColorOption = CameraOverrideOption.Off;
            cameraData.requiresDepthOption = CameraOverrideOption.Off;
            cameraData.SetRenderer(m_captureRendererIndex);
        }

        private void SynchronizeCaptureCamera(Camera mainCamera)
        {
            Transform mainTransform = mainCamera.transform;
            Transform captureTransform = m_captureCamera.transform;
            captureTransform.SetPositionAndRotation(mainTransform.position, mainTransform.rotation);
            m_captureCamera.orthographicSize = mainCamera.orthographicSize;
            m_captureCamera.nearClipPlane = mainCamera.nearClipPlane;
            m_captureCamera.farClipPlane = mainCamera.farClipPlane;
            m_captureCamera.depth = mainCamera.depth - 1f;
            SetCaptureEnabled(true);
        }

        private void UpdateCasterVisibility(Camera mainCamera)
        {
            GeometryUtility.CalculateFrustumPlanes(mainCamera, m_frustumPlanes);
            Vector2 cameraFocus = mainCamera.transform.position;
            float nearDistance = Mathf.Max(0f, m_nearDistance);
            float farDistance = Mathf.Max(nearDistance + 0.01f, m_farDistance);

            foreach (WaterReflectionCaster2D caster in m_casters)
            {
                if (caster == null || !caster.isActiveAndEnabled)
                {
                    continue;
                }

                Bounds reflectionBounds = caster.CalculatePotentialReflectionBounds();
                bool intersectsWater = IntersectsConfiguredWater(reflectionBounds);
                bool insideCamera = GeometryUtility.TestPlanesAABB(m_frustumPlanes, reflectionBounds);
                float distance = Vector2.Distance(cameraFocus, caster.ReflectionAnchorPosition);
                bool active = intersectsWater && insideCamera && distance < farDistance;

                if (!active)
                {
                    caster.ApplyRuntimeVisibility(false, 0f, 0f);
                    continue;
                }

                float quality = distance <= nearDistance
                    ? 1f
                    : 1f - Mathf.InverseLerp(nearDistance, farDistance, distance);
                float strength = Mathf.SmoothStep(0f, 1f, quality);
                float lengthScale = Mathf.Lerp(0.45f, 1f, quality);
                caster.ApplyRuntimeVisibility(true, strength, lengthScale);
            }
        }

        private bool IntersectsConfiguredWater(Bounds reflectionBounds)
        {
            for (int i = 0; i < m_waterRenderers.Length; i++)
            {
                Renderer waterRenderer = m_waterRenderers[i];
                if (waterRenderer != null &&
                    waterRenderer.enabled &&
                    waterRenderer.bounds.Intersects(reflectionBounds))
                {
                    return true;
                }
            }

            return false;
        }

        private void EnsureReflectionTexture()
        {
            Camera mainCamera = GameManager.MainCamera;
            if (mainCamera == null)
            {
                return;
            }

            int width = Mathf.Max(64, Mathf.RoundToInt(mainCamera.pixelWidth * m_captureScale));
            int height = Mathf.Max(64, Mathf.RoundToInt(mainCamera.pixelHeight * m_captureScale));
            if (m_reflectionTexture != null &&
                m_reflectionTexture.width == width &&
                m_reflectionTexture.height == height)
            {
                return;
            }

            ReleaseReflectionTexture();
            m_reflectionTexture = new RenderTexture(
                width,
                height,
                ReflectionTextureDepthBits,
                RenderTextureFormat.ARGB32)
            {
                name = "WaterReflectionSharedRT",
                filterMode = FilterMode.Point,
                wrapMode = TextureWrapMode.Clamp,
                useMipMap = false,
                autoGenerateMips = false
            };
            m_reflectionTexture.Create();
            m_captureCamera.targetTexture = m_reflectionTexture;
            SetWaterReflectionTexture(m_reflectionTexture);
            Shader.SetGlobalTexture(ReflectionTextureId, m_reflectionTexture);
        }

        private void ReleaseReflectionTexture()
        {
            Texture emptyTexture = GetEmptyReflectionTexture();
            SetWaterReflectionTexture(emptyTexture);
            if (m_captureCamera != null)
            {
                m_captureCamera.targetTexture = null;
            }

            if (m_reflectionTexture == null)
            {
                return;
            }

            m_reflectionTexture.Release();
            Destroy(m_reflectionTexture);
            m_reflectionTexture = null;
            Shader.SetGlobalTexture(ReflectionTextureId, emptyTexture);
        }

        private void SetCaptureEnabled(bool enabledValue)
        {
            if (m_captureCamera != null)
            {
                m_captureCamera.enabled = enabledValue;
            }

            Texture reflectionTexture = enabledValue && m_reflectionTexture != null
                ? m_reflectionTexture
                : GetEmptyReflectionTexture();
            SetWaterReflectionTexture(reflectionTexture);
            Shader.SetGlobalTexture(
                ReflectionTextureId,
                reflectionTexture);
        }

        private Texture2D GetEmptyReflectionTexture()
        {
            if (m_emptyReflectionTexture != null)
            {
                return m_emptyReflectionTexture;
            }

            m_emptyReflectionTexture = new Texture2D(
                1,
                1,
                TextureFormat.RGBA32,
                false,
                true)
            {
                name = "WaterReflectionEmptyTexture",
                filterMode = FilterMode.Point,
                wrapMode = TextureWrapMode.Clamp,
                hideFlags = HideFlags.HideAndDontSave
            };
            m_emptyReflectionTexture.SetPixel(0, 0, Color.clear);
            m_emptyReflectionTexture.Apply(false, true);
            return m_emptyReflectionTexture;
        }

        private void ReleaseEmptyReflectionTexture()
        {
            if (m_emptyReflectionTexture == null)
            {
                return;
            }

            Destroy(m_emptyReflectionTexture);
            m_emptyReflectionTexture = null;
        }

        private void SetWaterReflectionTexture(Texture texture)
        {
            if (m_waterRenderers == null)
            {
                return;
            }

            m_waterPropertyBlock ??= new MaterialPropertyBlock();

            for (int i = 0; i < m_waterRenderers.Length; i++)
            {
                Renderer waterRenderer = m_waterRenderers[i];
                if (waterRenderer == null)
                {
                    continue;
                }

                m_waterPropertyBlock.Clear();
                waterRenderer.GetPropertyBlock(m_waterPropertyBlock);
                m_waterPropertyBlock.SetTexture(ReflectionTextureId, texture);
                m_waterPropertyBlock.SetMatrix(
                    ReflectionViewProjectionId,
                    CalculateCaptureViewProjection());
                waterRenderer.SetPropertyBlock(m_waterPropertyBlock);
            }
        }

        private Matrix4x4 CalculateCaptureViewProjection()
        {
            if (m_captureCamera == null)
            {
                return Matrix4x4.identity;
            }

            Matrix4x4 projection = GL.GetGPUProjectionMatrix(
                m_captureCamera.projectionMatrix,
                true);
            return projection * m_captureCamera.worldToCameraMatrix;
        }
    }
}
