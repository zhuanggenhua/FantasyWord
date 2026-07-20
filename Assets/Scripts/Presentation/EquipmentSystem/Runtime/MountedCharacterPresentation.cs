using FantasyWord.GameCore;
using UnityEngine;
using UnityEngine.Serialization;

/// <summary>
/// 骑乘状态的表现同步器。
/// 坐骑本体和骑手基础层使用同一个动作、方向和帧索引；
/// 坐骑本体始终按作者原版 Sprite 直显，骑手层可在有普通装备时复用骑乘帧数据做换装叠加。
/// </summary>
[DisallowMultipleComponent]
public sealed class MountedCharacterPresentation : MonoBehaviour
{
    [Header("运行时依赖")]
    [InspectorName("动作驱动")]
    [Tooltip("读取当前角色动作键。正式 Prefab 必须显式绑定。")]
    [SerializeField] private CharacterActionAnimatorDriver actionDriver;

    [InspectorName("方向驱动")]
    [Tooltip("读取当前 SE/SW/NE/NW 方向索引。正式 Prefab 必须显式绑定。")]
    [SerializeField] private DirectionalSpriteLibraryDriver directionDriver;

    [InspectorName("骑手 SpriteRenderer")]
    [Tooltip("骑手基础层 SpriteRenderer，通常就是 EquipmentRenderer 所在对象的 SpriteRenderer。")]
    [SerializeField] private SpriteRenderer riderRenderer;

    [InspectorName("坐骑 SpriteRenderer")]
    [Tooltip("坐骑本体底层 SpriteRenderer。")]
    [SerializeField] private SpriteRenderer mountRenderer;

    [InspectorName("骑手换装渲染器")]
    [Tooltip("可选引用。骑手穿普通装备时使用骑乘帧数据刷新换装材质；无普通装备时保持原版 Sprite 直显。")]
    [SerializeField] private EquipmentRenderer riderEquipmentRenderer;

    [Header("未骑乘默认值")]
    [InspectorName("默认骑手帧数据")]
    [Tooltip("卸下坐骑后恢复的普通站立/行走帧数据。为空时使用启动时 EquipmentRenderer 上的帧数据。")]
    [SerializeField] private CharacterFrameData defaultRiderFrameData;

    [Header("调试")]
    [SerializeField] private MountRenderData activeMount;
    [FormerlySerializedAs("debugAnimationKey")]
    [SerializeField] private string debugCharacterAnimationKey;
    [SerializeField] private string debugMountActionKey;
    [SerializeField] private int debugDirectionIndex;
    [SerializeField] private int debugFrameIndex;
    [InspectorName("调试帧数")]
    [Tooltip("当前坐骑动作在当前方向下，本体和骑手基础层共同可播放的帧数。")]
    [SerializeField] private int debugFrameCount;
    [InspectorName("调试动作周期秒数")]
    [Tooltip("当前坐骑动作完成一轮的时间，用来确认不同帧数坐骑是否按同一动作周期采样。")]
    [SerializeField] private float debugCycleDurationSeconds;
    [InspectorName("骑手普通装备叠加")]
    [Tooltip("为 true 时，骑手层使用骑乘帧数据和普通换装 Shader 叠加服装/帽子等装备。坐骑本体不受影响。")]
    [SerializeField] private bool debugRiderEquipmentOverlayEnabled;
    [InspectorName("动作发生回退")]
    [SerializeField] private bool debugUsedFallbackAction;
    [InspectorName("请求的坐骑动作")]
    [SerializeField] private string debugRequestedMountActionKey;

    float _elapsed;
    int _lastAppliedFrameIndex = -1;
    int _lastDirectionIndex = -1;
    string _lastAnimationKey = string.Empty;
    CharacterFrameData _capturedDefaultFrameData;
    Material _originalSpriteDirectMaterial;
    bool _hasRequestedAction;
    MountActionRequest _requestedAction;
    string _lastReportedFallbackKey = string.Empty;
    int _lastReportedInvalidDirectionIndex = int.MinValue;

    public MountRenderData ActiveMount => activeMount;
    public bool IsMounted => activeMount != null;
    public bool RiderEquipmentOverlayEnabled => debugRiderEquipmentOverlayEnabled;

    void Awake()
    {
        CaptureDefaultFrameData();
        ValidateStaticReferences(reportErrors: true);
        ApplyMountedStateVisibility();
    }

    void OnEnable()
    {
        CaptureDefaultFrameData();
        ApplyMountedStateVisibility();
    }

    void LateUpdate()
    {
        if (activeMount == null)
            return;

        TickMountedPresentation(Time.deltaTime);
    }

    void OnDestroy()
    {
        if (_originalSpriteDirectMaterial != null)
            Destroy(_originalSpriteDirectMaterial);
    }

    public void SetMount(MountRenderData mount)
    {
        if (activeMount == mount)
        {
            ApplyRiderRenderModeForCurrentState();
            return;
        }

        activeMount = mount;
        _hasRequestedAction = false;
        _elapsed = 0f;
        _lastAppliedFrameIndex = -1;
        _lastDirectionIndex = -1;
        _lastAnimationKey = string.Empty;

        if (activeMount != null)
        {
            if (!ValidateStaticReferences(reportErrors: true))
                return;

            if (riderEquipmentRenderer != null && activeMount.RiderFrameData != null)
            {
                riderEquipmentRenderer.SetFrameData(activeMount.RiderFrameData, false);
            }

            ApplyRiderRenderModeForCurrentState();
            ApplyOriginalSpriteDirectMaterials();
        }
        else
        {
            CharacterFrameData restoreFrameData = defaultRiderFrameData != null
                ? defaultRiderFrameData
                : _capturedDefaultFrameData;
            if (restoreFrameData != null && riderEquipmentRenderer != null)
                riderEquipmentRenderer.SetFrameData(restoreFrameData, false);

            riderEquipmentRenderer?.ClearAnimationContextOverride(false);
            riderEquipmentRenderer?.SetOriginalSpriteDirectMode(false);
        }

        ApplyMountedStateVisibility();
        TickMountedPresentation(0f);

        if (activeMount == null && riderEquipmentRenderer != null && !riderEquipmentRenderer.IsOriginalSpriteDirectMode)
            riderEquipmentRenderer.Refresh();
    }

    public void RefreshRiderEquipmentOverlayFromRenderer()
    {
        ApplyRiderRenderModeForCurrentState();
        if (activeMount != null)
        {
            _lastAppliedFrameIndex = -1;
            TickMountedPresentation(0f);
        }
    }

    public bool TryPlayAction(MountActionSemantic action, string customActionKey = null)
    {
        if (activeMount == null)
            return false;

        MountActionRequest request = new(action, customActionKey);
        if (!activeMount.TryGetAnimation(request, out _, out _))
            return false;

        _requestedAction = request;
        _hasRequestedAction = true;
        _elapsed = 0f;
        _lastAppliedFrameIndex = -1;
        _lastAnimationKey = string.Empty;
        TickMountedPresentation(0f);
        return true;
    }

    public void ClearRequestedAction()
    {
        if (!_hasRequestedAction)
            return;

        _hasRequestedAction = false;
        _elapsed = 0f;
        _lastAppliedFrameIndex = -1;
        _lastAnimationKey = string.Empty;
        if (activeMount != null)
            TickMountedPresentation(0f);
    }

    public void ClearMount()
    {
        SetMount(null);
    }

    void TickMountedPresentation(float deltaTime)
    {
        if (activeMount == null || !ValidateStaticReferences(reportErrors: false))
            return;

        string characterAnimationKey = actionDriver != null && !string.IsNullOrWhiteSpace(actionDriver.CurrentAnimationKey)
            ? actionDriver.CurrentAnimationKey
            : activeMount.FallbackAnimationKey;
        MountActionRequest requestedAction = _hasRequestedAction
            ? _requestedAction
            : MountActionResolver.ResolveRequest(characterAnimationKey);

        if (!activeMount.TryGetAnimation(requestedAction, out MountAnimationData animation, out bool usedFallback) || animation == null)
            return;

        debugUsedFallbackAction = usedFallback;
        debugRequestedMountActionKey = requestedAction.Semantic == MountActionSemantic.Custom
            ? requestedAction.CustomKey
            : MountActionResolver.ToKey(requestedAction.Semantic);
        ReportFallbackIfNeeded(usedFallback, debugRequestedMountActionKey, animation.MountActionKey);

        if (ShouldRenderRiderEquipmentOverlay())
            riderEquipmentRenderer.SetAnimationContextOverride(animation.AnimationKey, false);
        else
            riderEquipmentRenderer?.ClearAnimationContextOverride(false);

        int directionIndex = directionDriver != null
            ? directionDriver.CurrentDirectionIndex
            : CharacterAnimationDirections.SouthEast;
        if (!CharacterAnimationDirections.IsValidIndex(directionIndex))
        {
            if (_lastReportedInvalidDirectionIndex != directionIndex)
            {
                _lastReportedInvalidDirectionIndex = directionIndex;
                Debug.LogError($"坐骑表现收到非法方向索引 {directionIndex}，已停止本帧刷新。", this);
            }

            return;
        }

        _lastReportedInvalidDirectionIndex = int.MinValue;

        string mountActionKey = animation.MountActionKey;
        if (!string.Equals(_lastAnimationKey, mountActionKey, System.StringComparison.Ordinal)
            || _lastDirectionIndex != directionIndex)
        {
            _elapsed = 0f;
            _lastAppliedFrameIndex = -1;
            _lastAnimationKey = mountActionKey;
            _lastDirectionIndex = directionIndex;
        }
        else
        {
            _elapsed += Mathf.Max(0f, deltaTime);
        }

        int frameCount = animation.GetFrameCount(directionIndex);
        if (frameCount <= 0)
            return;

        if (_hasRequestedAction
            && !animation.Loop
            && _elapsed >= animation.GetCycleDurationSeconds(directionIndex))
        {
            if (animation.CompletionBehavior == MountActionCompletionBehavior.ReturnToCharacterAction)
            {
                ClearRequestedAction();
                return;
            }

            if (animation.CompletionBehavior == MountActionCompletionBehavior.ClearMount)
            {
                ClearMount();
                return;
            }
        }

        int frameIndex = animation.ResolveFrameIndex(_elapsed, directionIndex);
        if (frameIndex < 0)
            return;

        debugCharacterAnimationKey = characterAnimationKey;
        debugMountActionKey = mountActionKey;
        debugDirectionIndex = directionIndex;
        debugFrameIndex = frameIndex;
        debugFrameCount = frameCount;
        debugCycleDurationSeconds = animation.GetCycleDurationSeconds(directionIndex);

        if (_lastAppliedFrameIndex == frameIndex)
            return;

        ApplyFrame(animation, directionIndex, frameIndex);
        _lastAppliedFrameIndex = frameIndex;
    }

    void ApplyFrame(MountAnimationData animation, int directionIndex, int frameIndex)
    {
        Sprite mountSprite = animation.GetMountFrame(directionIndex, frameIndex);
        Sprite riderSprite = animation.GetRiderFrame(directionIndex, frameIndex);
        if (mountRenderer != null)
        {
            ApplyLayerFrame(mountRenderer, mountSprite, animation.MountEmptyBehavior);
            ApplyOriginalSpriteDirectMaterial(mountRenderer);
        }

        if (riderRenderer != null)
        {
            ApplyLayerFrame(riderRenderer, riderSprite, animation.RiderEmptyBehavior);
            if (ShouldRenderRiderEquipmentOverlay())
            {
                riderEquipmentRenderer.SyncCurrentSpriteAndRefresh();
            }
            else
            {
                ApplyOriginalSpriteDirectMaterial(riderRenderer);
            }
        }
    }

    void ApplyOriginalSpriteDirectMaterials()
    {
        ApplyOriginalSpriteDirectMaterial(mountRenderer);
        if (!ShouldRenderRiderEquipmentOverlay() && riderEquipmentRenderer == null)
            ApplyOriginalSpriteDirectMaterial(riderRenderer);
    }

    void ApplyRiderRenderModeForCurrentState()
    {
        if (riderEquipmentRenderer == null)
            return;

        bool useOverlay = ShouldRenderRiderEquipmentOverlay();
        debugRiderEquipmentOverlayEnabled = useOverlay;
        riderEquipmentRenderer.SetOriginalSpriteDirectMode(activeMount != null && !useOverlay);
        if (useOverlay && activeMount.RiderFrameData != null)
            riderEquipmentRenderer.SetFrameData(activeMount.RiderFrameData, false);
        if (!useOverlay)
            riderEquipmentRenderer.ClearAnimationContextOverride(false);
    }

    bool ShouldRenderRiderEquipmentOverlay()
    {
        return activeMount != null
            && riderEquipmentRenderer != null
            && riderEquipmentRenderer.HasEquippedVisuals
            && activeMount.RiderFrameData != null;
    }

    static void ApplyLayerFrame(
        SpriteRenderer renderer,
        Sprite sprite,
        MountLayerEmptyBehavior emptyBehavior)
    {
        if (sprite != null)
        {
            renderer.sprite = sprite;
            renderer.enabled = true;
            return;
        }

        if (emptyBehavior == MountLayerEmptyBehavior.KeepPrevious)
            return;

        renderer.sprite = null;
        renderer.enabled = false;
    }

    void ReportFallbackIfNeeded(bool usedFallback, string requestedKey, string selectedKey)
    {
        if (!usedFallback)
        {
            _lastReportedFallbackKey = string.Empty;
            return;
        }

        string reportKey = requestedKey + "->" + selectedKey;
        if (string.Equals(_lastReportedFallbackKey, reportKey, System.StringComparison.Ordinal))
            return;

        _lastReportedFallbackKey = reportKey;
        Debug.LogWarning(
            $"坐骑“{activeMount.DisplayName}”不支持动作“{requestedKey}”，已回退为“{selectedKey}”。",
            this);
    }

    void ApplyOriginalSpriteDirectMaterial(SpriteRenderer targetRenderer)
    {
        if (targetRenderer == null)
            return;

        Material directMaterial = ResolveOriginalSpriteDirectMaterial();
        if (directMaterial != null && targetRenderer.sharedMaterial != directMaterial)
            targetRenderer.sharedMaterial = directMaterial;
    }

    Material ResolveOriginalSpriteDirectMaterial()
    {
        if (_originalSpriteDirectMaterial != null)
            return _originalSpriteDirectMaterial;

        Shader shader = Shader.Find("Universal Render Pipeline/2D/Sprite-Unlit-Default");
        if (shader == null)
            shader = Shader.Find("Universal Render Pipeline/2D/Sprite-Lit-Default");
        if (shader == null)
            shader = Shader.Find("Sprites/Default");
        if (shader == null)
            return null;

        _originalSpriteDirectMaterial = new Material(shader)
        {
            name = "坐骑本体原版Sprite直显材质"
        };
        return _originalSpriteDirectMaterial;
    }

    void ApplyMountedStateVisibility()
    {
        bool mounted = activeMount != null;
        if (mountRenderer != null && !mounted)
        {
            mountRenderer.sprite = null;
            mountRenderer.enabled = false;
        }

    }

    void CaptureDefaultFrameData()
    {
        if (_capturedDefaultFrameData != null || riderEquipmentRenderer == null)
            return;

        _capturedDefaultFrameData = riderEquipmentRenderer.frameData;
    }

    bool ValidateStaticReferences(bool reportErrors)
    {
        bool valid = true;

        if (riderRenderer == null)
        {
            valid = false;
            if (reportErrors)
                Debug.LogError("骑乘表现缺少骑手 SpriteRenderer，请在 Prefab 上显式绑定。", this);
        }

        if (mountRenderer == null)
        {
            valid = false;
            if (reportErrors)
                Debug.LogError("骑乘表现缺少坐骑 SpriteRenderer，请在 Prefab 上显式绑定。", this);
        }

        return valid;
    }

#if UNITY_EDITOR
    void Reset()
    {
        riderRenderer = GetComponent<SpriteRenderer>();
        riderEquipmentRenderer = GetComponent<EquipmentRenderer>();
    }
#endif
}
