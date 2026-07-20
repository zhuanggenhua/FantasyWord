using System.Collections.Generic;
using FantasyWord.GameCore;
using UnityEngine;

namespace FantasyWord.Presentation
{
    /// <summary>
    /// 为一个场景对象维护水面倒影代理组。
    /// 代理只进入共享捕获相机，不直接进入主相机画面。
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class WaterReflectionCaster2D : MonoBehaviour
    {
        [Header("反射来源")]
        [Tooltip("没有换装渲染器时使用的正式 SpriteRenderer。必须显式配置，运行时不自动扫描子级。")]
        [SerializeField] private SpriteRenderer[] m_sourceRenderers = System.Array.Empty<SpriteRenderer>();

        [Tooltip("可选的换装表现入口。配置后会包含角色主体和当前启用的武器 Renderer。")]
        [SerializeField] private EquipmentRenderer m_equipmentRenderer;

        [Header("45 度倒影")]
        [Tooltip("普通 Sprite 的反射接地点；换装角色优先使用 CharacterFrameData 的正式地面基准，缺失时才使用这里。")]
        [SerializeField] private Transform m_reflectionAnchor;

        [Tooltip("倒影相对原 Sprite 高度的压缩比例。")]
        [Range(0.05f, 1.5f)]
        [SerializeField] private float m_verticalScale = 0.65f;

        [Tooltip("45 度俯视角的水平偏斜。正负方向取决于美术投影方向。")]
        [Range(-1.5f, 1.5f)]
        [SerializeField] private float m_skew = -0.35f;

        [Tooltip("用于空间粗剔除的额外水域探测距离。")]
        [Min(0f)]
        [SerializeField] private float m_waterReach = 0.5f;

        [Header("状态")]
        [Tooltip("游泳动画期间默认关闭完整站立倒影。")]
        [SerializeField] private bool m_disableWhileSwimming = true;

        private readonly List<SpriteRenderer> m_sourceScratch = new(8);
        private readonly List<ProxyBinding> m_bindings = new(8);
        private WaterReflectionSystem m_system;
        private bool m_swimming;
        private bool m_registered;
        private bool m_runtimeVisible;
        private float m_runtimeStrength;
        private float m_runtimeLengthScale = 1f;

        public Vector2 ReflectionAnchorPosition
        {
            get
            {
                if (m_equipmentRenderer != null &&
                    m_equipmentRenderer.TryGetGroundAnchorWorldPosition(out Vector2 groundPosition))
                {
                    return groundPosition;
                }

                return m_reflectionAnchor != null
                    ? m_reflectionAnchor.position
                    : transform.position;
            }
        }

        private sealed class ProxyBinding
        {
            public SpriteRenderer Source;
            public Transform TransformRoot;
            public Transform AxisCorrection;
            public SpriteRenderer Proxy;
            public MaterialPropertyBlock PropertyBlock;
        }

        private void Awake()
        {
            ResolveLocalReferences();
            if (!ValidateSourceConfiguration())
            {
                enabled = false;
            }
        }

        private void OnEnable()
        {
            TryRegister();
        }

        private void Start()
        {
            TryRegister();
        }

        private void LateUpdate()
        {
            if (!m_registered)
            {
                TryRegister();
            }

            RefreshProxyBindings();
            SynchronizeProxyRenderers();
        }

        private void OnDisable()
        {
            Unregister();
            SetAllProxiesEnabled(false);
        }

        private void OnDestroy()
        {
            DestroyProxyBindings();
        }

        private void Reset()
        {
            ResolveLocalReferences();
            m_reflectionAnchor = transform;
        }

        private void OnValidate()
        {
            m_verticalScale = Mathf.Max(0.05f, m_verticalScale);
            m_waterReach = Mathf.Max(0f, m_waterReach);
            if (m_reflectionAnchor == null)
            {
                m_reflectionAnchor = transform;
            }
        }

        public void ConfigureRuntime(WaterReflectionSystem system)
        {
            m_system = system;
            RefreshProxyBindings();
        }

        public void SetSwimming(bool swimming)
        {
            m_swimming = swimming;
            if (m_disableWhileSwimming && m_swimming)
            {
                ApplyRuntimeVisibility(false, 0f, 0f);
            }
        }

        public void ApplyRuntimeVisibility(bool visible, float strength, float lengthScale)
        {
            m_runtimeVisible = visible;
            m_runtimeStrength = Mathf.Clamp01(strength);
            m_runtimeLengthScale = Mathf.Clamp01(lengthScale);
        }

        public Bounds CalculatePotentialReflectionBounds()
        {
            GatherSourceRenderers();
            if (m_sourceScratch.Count == 0)
            {
                return new Bounds(ReflectionAnchorPosition, Vector3.zero);
            }

            bool initialized = false;
            Bounds result = default;
            for (int i = 0; i < m_sourceScratch.Count; i++)
            {
                SpriteRenderer source = m_sourceScratch[i];
                if (source == null || source.sprite == null)
                {
                    continue;
                }

                Bounds reflected = ReflectBounds(source.bounds, 1f);
                if (!initialized)
                {
                    result = reflected;
                    initialized = true;
                }
                else
                {
                    result.Encapsulate(reflected);
                }
            }

            if (!initialized)
            {
                result = new Bounds(ReflectionAnchorPosition, Vector3.zero);
            }

            result.Expand(new Vector3(m_waterReach * 2f, m_waterReach * 2f, 0f));
            return result;
        }

        private void ResolveLocalReferences()
        {
            if (m_reflectionAnchor == null)
            {
                m_reflectionAnchor = transform;
            }
        }

        private bool ValidateSourceConfiguration()
        {
            if (m_equipmentRenderer != null)
            {
                return true;
            }

            if (m_sourceRenderers != null)
            {
                for (int i = 0; i < m_sourceRenderers.Length; i++)
                {
                    SpriteRenderer source = m_sourceRenderers[i];
                    if (source != null && !IsReflectionProxy(source))
                    {
                        return true;
                    }
                }
            }

            Debug.LogError(
                "水面倒影投射器缺少正式反射来源。请显式绑定 EquipmentRenderer，或至少绑定一个 SpriteRenderer。",
                this);
            return false;
        }

        private void TryRegister()
        {
            if (m_registered ||
                !GameManager.Exists() ||
                !GameManager.TryGetSystem(out WaterReflectionSystem system))
            {
                return;
            }

            m_registered = true;
            m_system = system;
            system.Register(this);
        }

        private void Unregister()
        {
            if (!m_registered)
            {
                return;
            }

            if (m_system != null)
            {
                m_system.Unregister(this);
            }

            m_registered = false;
            m_system = null;
        }

        private void GatherSourceRenderers()
        {
            m_sourceScratch.Clear();
            if (m_equipmentRenderer != null)
            {
                m_equipmentRenderer.AppendActivePresentationRenderers(m_sourceScratch);
                return;
            }

            if (m_sourceRenderers == null)
            {
                return;
            }

            for (int i = 0; i < m_sourceRenderers.Length; i++)
            {
                SpriteRenderer source = m_sourceRenderers[i];
                if (source != null && !IsReflectionProxy(source))
                {
                    m_sourceScratch.Add(source);
                }
            }
        }

        private void RefreshProxyBindings()
        {
            if (m_system == null || m_system.ProxyLayer < 0)
            {
                return;
            }

            GatherSourceRenderers();
            for (int i = m_bindings.Count - 1; i >= 0; i--)
            {
                ProxyBinding binding = m_bindings[i];
                if (binding.Source != null && m_sourceScratch.Contains(binding.Source))
                {
                    continue;
                }

                DestroyProxy(binding);
                m_bindings.RemoveAt(i);
            }

            for (int i = 0; i < m_sourceScratch.Count; i++)
            {
                SpriteRenderer source = m_sourceScratch[i];
                if (FindBinding(source) == null)
                {
                    m_bindings.Add(CreateProxy(source));
                }
            }
        }

        private ProxyBinding CreateProxy(SpriteRenderer source)
        {
            HideFlags proxyHideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild;

            GameObject transformRootObject = new($"Water Reflection Transform - {source.name}")
            {
                hideFlags = proxyHideFlags,
                layer = m_system.ProxyLayer
            };

            GameObject axisCorrectionObject = new($"Water Reflection Axis - {source.name}")
            {
                hideFlags = proxyHideFlags,
                layer = m_system.ProxyLayer
            };
            axisCorrectionObject.transform.SetParent(transformRootObject.transform, false);

            GameObject proxyObject = new($"Water Reflection Proxy - {source.name}")
            {
                hideFlags = proxyHideFlags,
                layer = m_system.ProxyLayer
            };
            proxyObject.transform.SetParent(axisCorrectionObject.transform, false);

            SpriteRenderer proxy = proxyObject.AddComponent<SpriteRenderer>();
            proxy.sharedMaterial = ResolveProxyMaterial(source);
            proxy.maskInteraction = SpriteMaskInteraction.None;

            return new ProxyBinding
            {
                Source = source,
                TransformRoot = transformRootObject.transform,
                AxisCorrection = axisCorrectionObject.transform,
                Proxy = proxy,
                PropertyBlock = new MaterialPropertyBlock()
            };
        }

        private void SynchronizeProxyRenderers()
        {
            bool visible = m_runtimeVisible &&
                (!m_disableWhileSwimming || !m_swimming) &&
                m_runtimeStrength > 0.001f;

            for (int i = 0; i < m_bindings.Count; i++)
            {
                ProxyBinding binding = m_bindings[i];
                SpriteRenderer source = binding.Source;
                SpriteRenderer proxy = binding.Proxy;
                if (source == null || proxy == null)
                {
                    continue;
                }

                bool shouldEnable = visible && source.enabled && source.sprite != null;
                if (proxy.enabled != shouldEnable)
                {
                    proxy.enabled = shouldEnable;
                }

                if (!proxy.enabled)
                {
                    continue;
                }

                if (proxy.sprite != source.sprite)
                {
                    proxy.sprite = source.sprite;
                }

                if (proxy.flipX != source.flipX)
                {
                    proxy.flipX = source.flipX;
                }

                if (proxy.flipY != source.flipY)
                {
                    proxy.flipY = source.flipY;
                }

                Color sourceColor = source.color;
                sourceColor.a *= m_runtimeStrength;
                if (proxy.color != sourceColor)
                {
                    proxy.color = sourceColor;
                }

                if (proxy.drawMode != source.drawMode)
                {
                    proxy.drawMode = source.drawMode;
                }

                if (proxy.size != source.size)
                {
                    proxy.size = source.size;
                }

                if (proxy.tileMode != source.tileMode)
                {
                    proxy.tileMode = source.tileMode;
                }

                if (!Mathf.Approximately(proxy.adaptiveModeThreshold, source.adaptiveModeThreshold))
                {
                    proxy.adaptiveModeThreshold = source.adaptiveModeThreshold;
                }

                if (proxy.spriteSortPoint != source.spriteSortPoint)
                {
                    proxy.spriteSortPoint = source.spriteSortPoint;
                }

                if (proxy.sortingLayerID != source.sortingLayerID)
                {
                    proxy.sortingLayerID = source.sortingLayerID;
                }

                if (proxy.sortingOrder != source.sortingOrder)
                {
                    proxy.sortingOrder = source.sortingOrder;
                }

                Material expectedMaterial = ResolveProxyMaterial(source);
                if (proxy.sharedMaterial != expectedMaterial)
                {
                    proxy.sharedMaterial = expectedMaterial;
                }

                if (!SynchronizeProxyTransform(binding, ReflectionAnchorPosition))
                {
                    proxy.enabled = false;
                    continue;
                }

                CopySourcePropertyBlock(binding);
            }
        }

        /// <summary>
        /// 倒影只改变代理的几何矩阵，不要求源材质实现倒影，也不改写角色本体属性。
        /// </summary>
        private bool SynchronizeProxyTransform(ProxyBinding binding, Vector2 anchor)
        {
            if (binding.TransformRoot == null || binding.AxisCorrection == null)
            {
                return false;
            }

            Matrix4x4 sourceMatrix = binding.Source.transform.localToWorldMatrix;
            float verticalScale = Mathf.Max(0.0001f, m_verticalScale * m_runtimeLengthScale);
            float shear = -verticalScale * m_skew;

            float m00 = sourceMatrix.m00 + shear * sourceMatrix.m10;
            float m01 = sourceMatrix.m01 + shear * sourceMatrix.m11;
            float m10 = -verticalScale * sourceMatrix.m10;
            float m11 = -verticalScale * sourceMatrix.m11;
            if (!TryDecomposeLinearTransform(
                    m00,
                    m01,
                    m10,
                    m11,
                    out float rootRotation,
                    out Vector2 rootScale,
                    out float correctionRotation))
            {
                return false;
            }

            float sourceX = sourceMatrix.m03;
            float sourceY = sourceMatrix.m13;
            float deltaY = sourceY - anchor.y;
            binding.TransformRoot.SetPositionAndRotation(
                new Vector3(
                    sourceX + shear * deltaY,
                    anchor.y - verticalScale * deltaY,
                    sourceMatrix.m23),
                Quaternion.Euler(0f, 0f, rootRotation * Mathf.Rad2Deg));
            binding.TransformRoot.localScale = new Vector3(
                rootScale.x,
                rootScale.y,
                Mathf.Max(0.0001f, Mathf.Abs(binding.Source.transform.lossyScale.z)));

            binding.AxisCorrection.localPosition = Vector3.zero;
            binding.AxisCorrection.localRotation = Quaternion.Euler(
                0f,
                0f,
                correctionRotation * Mathf.Rad2Deg);
            binding.AxisCorrection.localScale = Vector3.one;

            Transform proxyTransform = binding.Proxy.transform;
            proxyTransform.localPosition = Vector3.zero;
            proxyTransform.localRotation = Quaternion.identity;
            proxyTransform.localScale = Vector3.one;
            return true;
        }

        private static bool TryDecomposeLinearTransform(
            float m00,
            float m01,
            float m10,
            float m11,
            out float rootRotation,
            out Vector2 rootScale,
            out float correctionRotation)
        {
            float ata00 = m00 * m00 + m10 * m10;
            float ata01 = m00 * m01 + m10 * m11;
            float ata11 = m01 * m01 + m11 * m11;
            float axisRotation = 0.5f * Mathf.Atan2(2f * ata01, ata00 - ata11);
            float axisCos = Mathf.Cos(axisRotation);
            float axisSin = Mathf.Sin(axisRotation);

            Vector2 firstAxis = new(axisCos, axisSin);
            Vector2 secondAxis = new(-axisSin, axisCos);
            Vector2 firstMapped = new(
                m00 * firstAxis.x + m01 * firstAxis.y,
                m10 * firstAxis.x + m11 * firstAxis.y);
            Vector2 secondMapped = new(
                m00 * secondAxis.x + m01 * secondAxis.y,
                m10 * secondAxis.x + m11 * secondAxis.y);

            float firstScale = firstMapped.magnitude;
            float secondScale = secondMapped.magnitude;
            if (firstScale <= 0.0001f || secondScale <= 0.0001f)
            {
                rootRotation = 0f;
                rootScale = Vector2.zero;
                correctionRotation = 0f;
                return false;
            }

            Vector2 firstDirection = firstMapped / firstScale;
            Vector2 secondDirection = secondMapped / secondScale;
            float orientation = firstDirection.x * secondDirection.y -
                firstDirection.y * secondDirection.x;
            if (orientation < 0f)
            {
                secondScale = -secondScale;
            }

            rootRotation = Mathf.Atan2(firstDirection.y, firstDirection.x);
            rootScale = new Vector2(firstScale, secondScale);
            correctionRotation = -axisRotation;
            return true;
        }

        private static void CopySourcePropertyBlock(ProxyBinding binding)
        {
            binding.PropertyBlock.Clear();
            if (binding.Source.HasPropertyBlock())
            {
                binding.Source.GetPropertyBlock(binding.PropertyBlock);
            }

            binding.Proxy.SetPropertyBlock(binding.PropertyBlock);
        }

        private Bounds ReflectBounds(Bounds sourceBounds, float lengthScale)
        {
            Vector2 anchor = ReflectionAnchorPosition;
            Vector3 min = sourceBounds.min;
            Vector3 max = sourceBounds.max;
            Bounds reflected = new(ReflectPoint(new Vector2(min.x, min.y), anchor, lengthScale), Vector3.zero);
            reflected.Encapsulate(ReflectPoint(new Vector2(min.x, max.y), anchor, lengthScale));
            reflected.Encapsulate(ReflectPoint(new Vector2(max.x, min.y), anchor, lengthScale));
            reflected.Encapsulate(ReflectPoint(new Vector2(max.x, max.y), anchor, lengthScale));

            reflected.Encapsulate(new Vector3(reflected.min.x, reflected.min.y, min.z));
            reflected.Encapsulate(new Vector3(reflected.max.x, reflected.max.y, max.z));
            return reflected;
        }

        private Vector3 ReflectPoint(Vector2 point, Vector2 anchor, float lengthScale)
        {
            Vector2 delta = point - anchor;
            float reflectedY = -delta.y * m_verticalScale * lengthScale;
            float reflectedX = delta.x + reflectedY * m_skew;
            return new Vector3(anchor.x + reflectedX, anchor.y + reflectedY, transform.position.z);
        }

        private ProxyBinding FindBinding(SpriteRenderer source)
        {
            for (int i = 0; i < m_bindings.Count; i++)
            {
                if (m_bindings[i].Source == source)
                {
                    return m_bindings[i];
                }
            }

            return null;
        }

        private Material ResolveProxyMaterial(SpriteRenderer source)
        {
            return source != null ? source.sharedMaterial : null;
        }

        private static bool IsReflectionProxy(SpriteRenderer renderer)
        {
            return renderer != null &&
                renderer.gameObject.name.StartsWith("Water Reflection Proxy - ");
        }

        private void SetAllProxiesEnabled(bool enabledValue)
        {
            for (int i = 0; i < m_bindings.Count; i++)
            {
                if (m_bindings[i].Proxy != null)
                {
                    m_bindings[i].Proxy.enabled = enabledValue;
                }
            }
        }

        private void DestroyProxyBindings()
        {
            for (int i = 0; i < m_bindings.Count; i++)
            {
                DestroyProxy(m_bindings[i]);
            }

            m_bindings.Clear();
        }

        private static void DestroyProxy(ProxyBinding binding)
        {
            if (binding?.TransformRoot != null)
            {
                Object.Destroy(binding.TransformRoot.gameObject);
            }
            else if (binding?.Proxy != null)
            {
                Object.Destroy(binding.Proxy.gameObject);
            }
        }
    }
}
