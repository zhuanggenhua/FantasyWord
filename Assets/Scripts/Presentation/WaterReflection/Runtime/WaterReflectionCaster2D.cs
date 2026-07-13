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
        private static readonly int ReflectionEnabledId = Shader.PropertyToID("_WaterReflectionProxy");
        private static readonly int ReflectionAnchorId = Shader.PropertyToID("_WaterReflectionAnchorWS");
        private static readonly int ReflectionVerticalScaleId = Shader.PropertyToID("_WaterReflectionVerticalScale");
        private static readonly int ReflectionSkewId = Shader.PropertyToID("_WaterReflectionSkew");
        private static readonly int ReflectionLengthScaleId = Shader.PropertyToID("_WaterReflectionLengthScale");

        [Header("反射来源")]
        [Tooltip("没有换装渲染器时使用的正式 SpriteRenderer。留空可在自身层级内初始化一次。")]
        [SerializeField] private SpriteRenderer[] m_sourceRenderers = System.Array.Empty<SpriteRenderer>();

        [Tooltip("可选的换装表现入口。配置后会包含角色主体和当前启用的武器 Renderer。")]
        [SerializeField] private EquipmentRenderer m_equipmentRenderer;

        [Tooltip("没有手工配置来源时，在当前对象子层级内初始化一次 SpriteRenderer。")]
        [SerializeField] private bool m_collectChildRenderersOnAwake = true;

        [Header("45 度倒影")]
        [Tooltip("反射绕该锚点生成；通常放在角色脚底或物体接地点。")]
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

        public Vector2 ReflectionAnchorPosition =>
            m_reflectionAnchor != null ? m_reflectionAnchor.position : transform.position;

        private sealed class ProxyBinding
        {
            public SpriteRenderer Source;
            public SpriteRenderer Proxy;
            public MaterialPropertyBlock PropertyBlock;
            public bool SourceHadPropertyBlock;
            public bool ReflectionPropertiesInitialized;
            public Vector2 ReflectionAnchor;
            public float VerticalScale;
            public float Skew;
            public float LengthScale;
        }

        private void Awake()
        {
            ResolveLocalReferences();
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
            if (m_equipmentRenderer == null)
            {
                m_equipmentRenderer = GetComponentInChildren<EquipmentRenderer>(true);
            }

            if ((m_sourceRenderers == null || m_sourceRenderers.Length == 0) &&
                m_equipmentRenderer == null &&
                m_collectChildRenderersOnAwake)
            {
                m_sourceRenderers = GetComponentsInChildren<SpriteRenderer>(true);
            }

            if (m_reflectionAnchor == null)
            {
                m_reflectionAnchor = transform;
            }
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
            GameObject proxyObject = new($"Water Reflection Proxy - {source.name}");
            proxyObject.hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild;
            proxyObject.layer = m_system.ProxyLayer;
            proxyObject.transform.SetParent(source.transform, false);

            SpriteRenderer proxy = proxyObject.AddComponent<SpriteRenderer>();
            proxy.sharedMaterial = UsesEquipmentShader(source)
                ? source.sharedMaterial
                : m_system.DefaultProxyMaterial;
            proxy.maskInteraction = SpriteMaskInteraction.None;

            return new ProxyBinding
            {
                Source = source,
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

                Material expectedMaterial = UsesEquipmentShader(source)
                    ? source.sharedMaterial
                    : m_system.DefaultProxyMaterial;
                if (proxy.sharedMaterial != expectedMaterial)
                {
                    proxy.sharedMaterial = expectedMaterial;
                }

                Vector2 anchor = ReflectionAnchorPosition;
                bool sourceHasPropertyBlock = source.HasPropertyBlock();
                bool reflectionPropertiesChanged =
                    !binding.ReflectionPropertiesInitialized ||
                    binding.ReflectionAnchor != anchor ||
                    !Mathf.Approximately(binding.VerticalScale, m_verticalScale) ||
                    !Mathf.Approximately(binding.Skew, m_skew) ||
                    !Mathf.Approximately(binding.LengthScale, m_runtimeLengthScale);
                if (!sourceHasPropertyBlock &&
                    !binding.SourceHadPropertyBlock &&
                    !reflectionPropertiesChanged)
                {
                    continue;
                }

                if (sourceHasPropertyBlock)
                {
                    source.GetPropertyBlock(binding.PropertyBlock);
                }
                else
                {
                    binding.PropertyBlock.Clear();
                }

                binding.PropertyBlock.SetFloat(ReflectionEnabledId, 1f);
                binding.PropertyBlock.SetVector(
                    ReflectionAnchorId,
                    new Vector4(anchor.x, anchor.y, 0f, 0f));
                binding.PropertyBlock.SetFloat(ReflectionVerticalScaleId, m_verticalScale);
                binding.PropertyBlock.SetFloat(ReflectionSkewId, m_skew);
                binding.PropertyBlock.SetFloat(ReflectionLengthScaleId, m_runtimeLengthScale);
                proxy.SetPropertyBlock(binding.PropertyBlock);

                binding.SourceHadPropertyBlock = sourceHasPropertyBlock;
                binding.ReflectionPropertiesInitialized = true;
                binding.ReflectionAnchor = anchor;
                binding.VerticalScale = m_verticalScale;
                binding.Skew = m_skew;
                binding.LengthScale = m_runtimeLengthScale;
            }
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

        private static bool UsesEquipmentShader(SpriteRenderer source)
        {
            return source != null &&
                source.sharedMaterial != null &&
                source.sharedMaterial.shader != null &&
                source.sharedMaterial.shader.name == "EquipmentSystem/EquipmentUV";
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
            if (binding?.Proxy != null)
            {
                Object.Destroy(binding.Proxy.gameObject);
            }
        }
    }
}
