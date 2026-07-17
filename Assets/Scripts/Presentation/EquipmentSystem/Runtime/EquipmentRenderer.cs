using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

/// <summary>
/// 装备渲染器 (配置驱动版本)
/// 新增装备类型时只需在 EquipTypeRegistry 添加配置
/// </summary>
[RequireComponent(typeof(SpriteRenderer))]
public class EquipmentRenderer : MonoBehaviour
{
    [Header("数据")]
    public CharacterFrameData frameData;
    
    [Header("角色外观")]
    public CharacterAppearance appearance;

    [Header("初始装备（可选）")]
    public List<EquipmentRenderData> initialEquipments = new List<EquipmentRenderData>();

    [Header("调试")]
    public Shader overrideShader;

    [Header("运行时依赖")]
    [SerializeField]
    [Tooltip("动作控制入口。正式 Prefab 应显式绑定；未绑定时只允许使用同对象 CharacterActionAnimatorDriver。")]
    CharacterActionAnimatorDriver animationController;

    [SerializeField]
    [Tooltip("角色动作 Animator。正式 Prefab 应显式绑定；未绑定时只允许使用动作控制器暴露的 Animator 或同对象 Animator。")]
    Animator characterAnimator;

    [Header("运行时状态 (只读)")]
    [SerializeField]
    string _debugCurrentAnim = "";

    [SerializeField]
    string _debugAnimatorState = "";

    [SerializeField]
    bool _debugHasBodyUVMap = false;

    [SerializeField]
    bool _debugHasHeadUVMap = false;
    [SerializeField]
    string _debugAnimatorPath = "";

    public string RequestedAnimationKey => _currentAnimName ?? string.Empty;

    public string ResolvedBodyAnimationKey =>
        _currentAnimData != null ? _currentAnimData.GetKey() : string.Empty;

    public string BodyAnimationDebugSummary => _debugCurrentAnim ?? string.Empty;
    public string DebugAnimatorPath => _debugAnimatorPath;
    public int EquippedSlotCount => _slots.Count;
    public bool HasMainHandWeapon => _mainHandWeapon != null;
    public bool HasOffHandWeapon => _offHandWeapon != null;

    public bool IsUsingBodyAnimationFallback =>
        !string.IsNullOrWhiteSpace(_currentAnimName)
        && _currentAnimData != null
        && !string.Equals(
            _currentAnimData.GetKey(),
            _currentAnimName,
            StringComparison.Ordinal);

    // ========== 槽位：统一用字典管理 ==========
    readonly Dictionary<EquipmentType, EquipmentRenderData> _slots =
        new Dictionary<EquipmentType, EquipmentRenderData>();

    // ========== 武器槽位：主手 + 副手 ==========
    EquipmentRenderData _mainHandWeapon;
    EquipmentRenderData _offHandWeapon;

    // 渲染器缓存
    SpriteRenderer _charRenderer;
    readonly Dictionary<EquipmentRenderData, SpriteRenderer> _weaponRenderers =
        new Dictionary<EquipmentRenderData, SpriteRenderer>();
    readonly Dictionary<SpriteRenderer, int> _weaponRendererSlots =
        new Dictionary<SpriteRenderer, int>();
    readonly Dictionary<EquipmentRenderData, Sprite> _runtimePlaceholderSprites =
        new Dictionary<EquipmentRenderData, Sprite>();
    readonly List<UnityEngine.Object> _runtimePlaceholderObjects = new List<UnityEngine.Object>();

    // 动画同步
    Animator _animator;
    CharacterActionAnimatorDriver _animationController;
    string _currentAnimName;
    List<string> _validAnimParams;
    bool _animParamsCached;

    // 帧同步
    Sprite _lastSprite;
    int _frameIndex;
    int _rowIndex;
    FrameData _cachedFrame;
    AnimationData _currentAnimData;
    Coroutine _deferredSpriteSync;

    // Shader
    Material _shaderMaterial;

    // 外观相关 Shader 属性（不走配置表的特殊处理）
    static readonly int MainTexProp = Shader.PropertyToID("_MainTex");
    static readonly int BodyUVMapProp = Shader.PropertyToID("_BodyUVMap");
    static readonly int HeadUVMapProp = Shader.PropertyToID("_HeadUVMap");
    static readonly int HairTexProp = Shader.PropertyToID("_HairTex");
    static readonly int HairRectProp = Shader.PropertyToID("_HairRect");
    static readonly int EnableHairProp = Shader.PropertyToID("_EnableHair");
    static readonly int FaceAccessoryTexProp = Shader.PropertyToID("_FaceAccessoryTex");
    static readonly int FaceAccessoryRectProp = Shader.PropertyToID("_FaceAccessoryRect");
    static readonly int EnableFaceAccessoryProp = Shader.PropertyToID("_EnableFaceAccessory");
    static readonly int BeardTexProp = Shader.PropertyToID("_BeardTex");
    static readonly int BeardRectProp = Shader.PropertyToID("_BeardRect");
    static readonly int EnableBeardProp = Shader.PropertyToID("_EnableBeard");
    static readonly int LeftEyeColorProp = Shader.PropertyToID("_LeftEyeColor");
    static readonly int RightEyeColorProp = Shader.PropertyToID("_RightEyeColor");
    static readonly int EnableLeftEyeProp = Shader.PropertyToID("_EnableLeftEye");
    static readonly int EnableRightEyeProp = Shader.PropertyToID("_EnableRightEye");
    static readonly int BodyInFrontProp = Shader.PropertyToID("_BodyInFront");
    static readonly int BodyInEastProp = Shader.PropertyToID("_BodyInEast");
    
    // 眼部装饰参数（贴图方式）
    static readonly int EyeDecoTexProp = Shader.PropertyToID("_EyeDecoTex");
    static readonly int EyeDecoRectProp = Shader.PropertyToID("_EyeDecoRect");
    static readonly int EnableEyeDecoProp = Shader.PropertyToID("_EnableEyeDeco");
    
    // 像素级阴影参数
    static readonly int ShadowModeProp = Shader.PropertyToID("_ShadowMode");
    static readonly int ShadowEnabledProp = Shader.PropertyToID("_ShadowEnabled");
    static readonly int ShadowLeftXProp = Shader.PropertyToID("_ShadowLeftX");
    static readonly int ShadowRightXProp = Shader.PropertyToID("_ShadowRightX");
    static readonly int ShadowCenterXProp = Shader.PropertyToID("_ShadowCenterX");
    static readonly int ShadowBaseYProp = Shader.PropertyToID("_ShadowBaseY");

    // 帧尺寸（像素）：用于 Shader 中的像素网格换算
    static readonly int FrameSizeProp = Shader.PropertyToID("_FrameSize");

    static readonly int HitOutlineProp = Shader.PropertyToID("_HitOutline");
    static readonly int DefaultOutlineEnabledProp = Shader.PropertyToID("_DefaultOutlineEnabled");
    const string GeneratedWeaponRendererPrefix = "Weapon_";

    const int MaxSkinColors = 16; // 必须与 Shader 中的 MAX_SKIN_COLORS 保持一致

    // 肤色映射参数（颜色表查表）
    static readonly int SkinPaletteEnabledProp = Shader.PropertyToID("_SkinPaletteEnabled");
    static readonly int SkinColorCountProp = Shader.PropertyToID("_SkinColorCount");
    static readonly int SkinSrcColorsProp = Shader.PropertyToID("_SkinSrcColors");
    static readonly int SkinDstColorsProp = Shader.PropertyToID("_SkinDstColors");
    readonly Vector4[] _skinSrcColorBuffer = new Vector4[MaxSkinColors];
    readonly Vector4[] _skinDstColorBuffer = new Vector4[MaxSkinColors];

    // 武器通用参数
    static readonly int CharFrameRectProp = Shader.PropertyToID("_CharFrameRect");

    // 主手武器参数（Weapon0）
    static readonly int Weapon0TexProp = Shader.PropertyToID("_Weapon0Tex");
    static readonly int Weapon0RectProp = Shader.PropertyToID("_Weapon0Rect");
    static readonly int Weapon0AnchorFrameUVProp = Shader.PropertyToID("_Weapon0AnchorFrameUV");
    static readonly int Weapon0RotCosSinProp = Shader.PropertyToID("_Weapon0RotCosSin");
    static readonly int Weapon0FlipXProp = Shader.PropertyToID("_Weapon0FlipX");
    static readonly int Weapon0DepthModeProp = Shader.PropertyToID("_Weapon0DepthMode");
    static readonly int Weapon0EnabledProp = Shader.PropertyToID("_Weapon0Enabled");
    static readonly int Weapon0HandInFrontProp = Shader.PropertyToID("_Weapon0HandInFront");
    static readonly int Weapon0IsSequenceProp = Shader.PropertyToID("_Weapon0IsSequence");
    static readonly int Weapon0HideOutlineOnBodyProp = Shader.PropertyToID("_Weapon0HideOutlineOnBody");

    // 副手武器参数（Weapon1）
    static readonly int Weapon1TexProp = Shader.PropertyToID("_Weapon1Tex");
    static readonly int Weapon1RectProp = Shader.PropertyToID("_Weapon1Rect");
    static readonly int Weapon1AnchorFrameUVProp = Shader.PropertyToID("_Weapon1AnchorFrameUV");
    static readonly int Weapon1RotCosSinProp = Shader.PropertyToID("_Weapon1RotCosSin");
    static readonly int Weapon1FlipXProp = Shader.PropertyToID("_Weapon1FlipX");
    static readonly int Weapon1DepthModeProp = Shader.PropertyToID("_Weapon1DepthMode");
    static readonly int Weapon1EnabledProp = Shader.PropertyToID("_Weapon1Enabled");
    static readonly int Weapon1HandInFrontProp = Shader.PropertyToID("_Weapon1HandInFront");
    static readonly int Weapon1IsSequenceProp = Shader.PropertyToID("_Weapon1IsSequence");
    static readonly int Weapon1HideOutlineOnBodyProp = Shader.PropertyToID("_Weapon1HideOutlineOnBody");

    void Awake()
    {
        EnsureRendererInitialized();
        RemovePersistedGeneratedWeaponRendererChildren();
    }

    void Start()
    {
        // 初始装备
        foreach (var e in initialEquipments)
        {
            if (e != null)
                Equip(e, false);
        }
        // 在第一次 Refresh 之前先同步一次 Animator 动画名，
        // 避免 _currentAnimName 为空导致武器误走静态贴图路径。
        SyncAnimationName();
        Refresh();
    }

    void LateUpdate()
    {
        EnsureRendererInitialized();
        if (_charRenderer == null)
            return;

        // 同步动画名称
        SyncAnimationName();

        // 自动同步 Sprite 变化
        if (_charRenderer.sprite != _lastSprite)
        {
            _lastSprite = _charRenderer.sprite;
            SyncFromSprite();
        }
    }

    /// <summary>
    /// 缓存 Animator 中有效的 Bool 参数
    /// 从 AnimationTypeDatabase 获取动画 Key 列表
    /// </summary>
    void CacheValidAnimParams()
    {
        if (_animParamsCached || _animator == null)
            return;

        _validAnimParams = new List<string>();

        // 从 frameData 中的数据库获取所有动画 Key
        var keywordSet = new HashSet<string>();
        var db = frameData?.animDatabase;
        if (db != null)
        {
            foreach (var type in db.ItemsReadOnly)
            {
                if (type != null)
                    keywordSet.Add(type.name);
            }
        }

        foreach (var param in _animator.parameters)
        {
            if (
                param.type == AnimatorControllerParameterType.Bool
                && keywordSet.Contains(param.name)
            )
            {
                _validAnimParams.Add(param.name);
            }
        }
        _animParamsCached = true;
    }

    /// <summary>
    /// 从 Animator Bool 参数同步当前动画名称
    /// CTR_AnimateCreature 使用 SetBool("Idle", true) 等方式切换动画
    /// </summary>
    void SyncAnimationName()
    {
        if (frameData == null)
            return;

        EnsureCharacterActionAnimatorDriverReference();

        string codeDrivenKey = _animationController != null
            ? _animationController.CurrentAnimationKey
            : string.Empty;

        if (!string.IsNullOrWhiteSpace(codeDrivenKey))
        {
            _debugAnimatorState = "code:" + codeDrivenKey;
            ApplyAnimationKey(codeDrivenKey);
            return;
        }

        if (_animator == null)
            CacheAnimatorReference();

        if (_animator == null)
            return;

        // 方案 D：使用缓存的参数列表，避免 try/catch
        CacheValidAnimParams();

        // 从 Animator 的 Bool 参数找到当前激活的动画
        string activeParam = null;
        foreach (var keyword in _validAnimParams)
        {
            if (_animator.GetBool(keyword))
            {
                activeParam = keyword;
                break;
            }
        }

        _debugAnimatorState = activeParam ?? "(none)";

        // 如果没找到激活的参数，默认用 Idle 或第一个动画
        if (string.IsNullOrEmpty(activeParam))
        {
            activeParam = "Idle";
        }

        ApplyAnimationKey(activeParam);
    }

    void EnsureCharacterActionAnimatorDriverReference()
    {
        if (_animationController != null)
            return;

        _animationController = animationController != null
            ? animationController
            : GetComponent<CharacterActionAnimatorDriver>();
    }

    void CacheAnimatorReference()
    {
        EnsureCharacterActionAnimatorDriverReference();
        _animator = characterAnimator != null
            ? characterAnimator
            : _animationController != null && _animationController.Animator != null
                ? _animationController.Animator
                : GetComponent<Animator>();

        if (_animator != null)
        {
            _debugAnimatorPath = GetTransformPath(_animator.transform);
            return;
        }

        _debugAnimatorPath = "(未配置角色 Animator)";
    }

    void ApplyAnimationKey(string animationKey)
    {
        if (string.IsNullOrWhiteSpace(animationKey))
            return;

        var newAnimData = FindAnimationByKey(animationKey);

        if (newAnimData != null
            && (newAnimData != _currentAnimData
                || !string.Equals(animationKey, _currentAnimName, System.StringComparison.Ordinal)))
        {
            _currentAnimData = newAnimData;
            _currentAnimName = animationKey;
            string resolvedKey = newAnimData.GetKey();
            _debugCurrentAnim = string.Equals(resolvedKey, animationKey, System.StringComparison.Ordinal)
                ? animationKey
                : $"{animationKey} -> {resolvedKey}";
            UpdateUVMapTexture();
        }
        else if (newAnimData == null && animationKey != _currentAnimName)
        {
            _currentAnimData = null;
            _currentAnimName = animationKey;
            _debugCurrentAnim = _currentAnimName + " (no FrameData)";
            UpdateUVMapTexture();
        }
    }

    /// <summary>
    /// 根据 Key 在 frameData 中找到对应的动画
    /// </summary>
    AnimationData FindAnimationByKey(string key)
    {
        if (frameData == null)
            return null;

        AnimationData exact = frameData.GetAnimationByKey(key);
        if (exact != null)
            return exact;

        foreach (string fallbackKey in GetBodyFrameFallbackKeys(key))
        {
            AnimationData fallback = frameData.GetAnimationByKey(fallbackKey);
            if (fallback != null)
                return fallback;
        }

        return null;
    }

    public bool HasExactBodyAnimation(AnimationTypeItem animationType)
    {
        if (animationType == null || string.IsNullOrWhiteSpace(animationType.name) || frameData == null)
            return false;

        AnimationData animation = frameData.GetAnimationByKey(animationType.name);
        return IsStandaloneBodyAnimation(animation);
    }

    static bool IsStandaloneBodyAnimation(AnimationData animation)
    {
        if (animation == null || animation.spritesheet == null)
            return false;

        return true;
    }

    public bool UsesBodyAnimationFallback(AnimationTypeItem animationType)
    {
        return animationType != null
            && !string.IsNullOrWhiteSpace(animationType.name)
            && !HasExactBodyAnimation(animationType)
            && FindAnimationByKey(animationType.name) != null;
    }

    static IEnumerable<string> GetBodyFrameFallbackKeys(string key)
    {
        switch (key)
        {
            case "Wait":
                yield return "Idle";
                break;
            case "Die":
                yield return "SoulDie";
                yield return "SpinDie";
                yield return "Idle";
                break;
            case "SoulDie":
                yield return "SpinDie";
                yield return "Die";
                yield return "Idle";
                break;
            case "SpinDie":
                yield return "Die";
                yield return "SoulDie";
                yield return "Idle";
                break;
        }
    }

    void OnDestroy()
    {
        if (_shaderMaterial != null)
            Destroy(_shaderMaterial);

        ClearRuntimePlaceholderSprites();
    }

    void InitMaterial()
    {
        if (_charRenderer == null)
            _charRenderer = GetComponent<SpriteRenderer>();
        if (_charRenderer == null)
            return;

        // 加载 Shader 换装 Shader
        Shader equipmentShader = Shader.Find("EquipmentSystem/EquipmentUV");
        var shader = overrideShader != null
            && string.Equals(overrideShader.name, "EquipmentSystem/EquipmentUV", StringComparison.Ordinal)
                ? overrideShader
                : equipmentShader;

        if (shader == null)
        {
            Debug.LogError(
                "[EquipmentRenderer] 找不到 EquipmentSystem/EquipmentUV Shader！"
                    + "请确保 Shader 在 Project Settings > Graphics > Always Included Shaders 中，"
                    + "或手动拖拽 Shader 到 overrideShader 字段"
            );
            return;
        }

        if (overrideShader != null
            && !string.Equals(overrideShader.name, "EquipmentSystem/EquipmentUV", StringComparison.Ordinal))
        {
            Debug.LogWarning(
                $"[EquipmentRenderer] overrideShader 指向 {overrideShader.name}，不是换装 Shader，"
                + "已改用 EquipmentSystem/EquipmentUV。");
        }

        _shaderMaterial = new Material(shader);
        ApplyPreviewMaterialDefaults();
        // 使用 sharedMaterial 绑定运行时私有材质，避免 Renderer.material 再克隆一份实例。
        // 后续装备/卸装写入 _shaderMaterial 时，必须直接作用到 SpriteRenderer 实际渲染材质。
        _charRenderer.sharedMaterial = _shaderMaterial;
    }

    void ApplyPreviewMaterialDefaults()
    {
        if (_shaderMaterial == null)
            return;

        if (_shaderMaterial.HasProperty(DefaultOutlineEnabledProp))
            _shaderMaterial.SetFloat(DefaultOutlineEnabledProp, 1f);
        if (_shaderMaterial.HasProperty(ShadowEnabledProp))
            _shaderMaterial.SetFloat(ShadowEnabledProp, 1f);
        if (_shaderMaterial.HasProperty(ShadowModeProp))
            _shaderMaterial.SetFloat(ShadowModeProp, 0f);
    }

    void EnsureRendererInitialized()
    {
        if (_charRenderer == null)
            _charRenderer = GetComponent<SpriteRenderer>();

        EnsureCharacterActionAnimatorDriverReference();

        if (_animator == null)
            CacheAnimatorReference();

        if (_shaderMaterial == null)
            InitMaterial();
        else if (_charRenderer != null && _charRenderer.sharedMaterial != _shaderMaterial)
            _charRenderer.sharedMaterial = _shaderMaterial;

        ApplyPreviewMaterialDefaults();
    }

    /// <summary>
    /// 从 Sprite 的 rect 位置同步帧索引和行索引
    /// </summary>
    void SyncFromSprite()
    {
        if (_lastSprite == null || frameData == null || _currentAnimData == null)
            return;

        // 从 Sprite 的 rect 位置计算帧索引和行索引
        var rect = _lastSprite.rect;
        int frameW = _currentAnimData.frameSize.x;
        int frameH = _currentAnimData.frameSize.y;

        if (frameW > 0 && frameH > 0)
        {
            _frameIndex = Mathf.FloorToInt(rect.x / frameW);
            // Unity Sprite 的 Y 是从底部计算的，需要转换
            _rowIndex = Mathf.FloorToInt(
                (_lastSprite.texture.height - rect.y - rect.height) / frameH
            );
            Refresh();
        }
    }

    /// <summary>
    /// 立即用 SpriteRenderer 的当前 Sprite 同步帧索引、主贴图和帧矩形。
    /// 用于 UI 主动切换 Animator 后，避免材质仍停在上一动作一帧。
    /// </summary>
    public void SyncCurrentSpriteAndRefresh()
    {
        EnsureRendererInitialized();

        if (_charRenderer == null || _charRenderer.sprite == null)
        {
            Refresh();
            return;
        }

        _lastSprite = _charRenderer.sprite;
        SyncAnimationName();
        SyncFromSprite();
    }

    /// <summary>
    /// 将当前实际参与角色表现的 SpriteRenderer 追加到调用方提供的列表。
    /// 用于水面倒影等表现系统复用换装主体与动态武器，不暴露内部渲染器容器。
    /// </summary>
    public void AppendActivePresentationRenderers(List<SpriteRenderer> results)
    {
        if (results == null)
            throw new ArgumentNullException(nameof(results));

        EnsureRendererInitialized();
        if (_charRenderer != null && _charRenderer.enabled && _charRenderer.sprite != null)
            results.Add(_charRenderer);

        foreach (var pair in _weaponRenderers)
        {
            SpriteRenderer renderer = pair.Value;
            if (renderer != null && renderer.enabled && renderer.sprite != null)
                results.Add(renderer);
        }
    }

    /// <summary>
    /// 在下一帧 Animator 采样后再次同步 Sprite。
    /// UI 点击发生在当前帧中途时，SpriteRenderer 可能仍是上一动作。
    /// </summary>
    public void SyncCurrentSpriteAndRefreshNextFrame()
    {
        if (!isActiveAndEnabled)
            return;

        if (_deferredSpriteSync != null)
            StopCoroutine(_deferredSpriteSync);

        _deferredSpriteSync = StartCoroutine(SyncCurrentSpriteAndRefreshAfterFrame());
    }

    IEnumerator SyncCurrentSpriteAndRefreshAfterFrame()
    {
        yield return null;

        SyncCurrentSpriteAndRefresh();
        _deferredSpriteSync = null;
    }

    /// <summary>
    /// 装备（配置驱动，无 switch）
    /// </summary>
    public void Equip(EquipmentRenderData equip, bool autoRefresh = true)
    {
        if (equip == null)
            return;

        var cfg = EquipTypeRegistry.Get(equip.type);
        if (cfg == null)
            return;

        ClearExclusiveConflicts(equip.type, equip);

        if (cfg.RenderMode == EquipRenderMode.Weapon)
        {
            EquipWeapon(equip);
        }
        else
        {
            _slots[equip.type] = equip;
        }

        if (autoRefresh)
            Refresh();
    }

    /// <summary>
    /// 装备武器（根据 WeaponSlotType 自动分配到主手/副手）
    /// </summary>
    void EquipWeapon(EquipmentRenderData equip)
    {
        switch (equip.weaponSlotType)
        {
            case WeaponSlotType.MainHand:
            case WeaponSlotType.TwoHand:
            case WeaponSlotType.DualWield:
                // 卸下旧主手
                if (_mainHandWeapon != null && _mainHandWeapon != equip)
                    UnequipWeaponInternal(_mainHandWeapon);
                // 双手/双持禁止副手
                if (equip.weaponSlotType != WeaponSlotType.MainHand && _offHandWeapon != null)
                    UnequipWeaponInternal(_offHandWeapon);
                _mainHandWeapon = equip;
                CreateWeaponRenderer(equip);
                break;

            case WeaponSlotType.OffHand:
                // 检查主手是否允许副手
                if (
                    _mainHandWeapon != null
                    && (
                        _mainHandWeapon.weaponSlotType == WeaponSlotType.TwoHand
                        || _mainHandWeapon.weaponSlotType == WeaponSlotType.DualWield
                    )
                )
                {
                    Debug.LogWarning("[EquipmentRenderer] 双手/双持武器不允许装备副手");
                    return;
                }
                // 卸下旧副手
                if (_offHandWeapon != null && _offHandWeapon != equip)
                    UnequipWeaponInternal(_offHandWeapon);
                _offHandWeapon = equip;
                CreateWeaponRenderer(equip);
                break;
        }
    }

    /// <summary>
    /// 卸下装备
    /// </summary>
    public void Unequip(EquipmentRenderData equip, bool autoRefresh = true)
    {
        if (equip == null)
            return;

        var cfg = EquipTypeRegistry.Get(equip.type);
        if (cfg == null)
            return;

        if (cfg.RenderMode == EquipRenderMode.Weapon)
        {
            UnequipWeaponInternal(equip);
        }
        else
        {
            if (_slots.TryGetValue(equip.type, out var current) && current == equip)
                _slots.Remove(equip.type);
        }

        if (autoRefresh)
            Refresh();
    }

    /// <summary>
    /// 内部卸下武器（不触发 Refresh）
    /// </summary>
    void UnequipWeaponInternal(EquipmentRenderData equip)
    {
        if (equip == null)
            return;

        if (_mainHandWeapon == equip)
            _mainHandWeapon = null;
        if (_offHandWeapon == equip)
            _offHandWeapon = null;

        // 销毁武器渲染器
        if (_weaponRenderers.TryGetValue(equip, out var sr))
        {
            if (sr != null)
            {
                sr.enabled = false;
                sr.sprite = null;
                _weaponRendererSlots.Remove(sr);
                DestroyGeneratedRendererObject(sr.gameObject);
            }
            _weaponRenderers.Remove(equip);
        }
    }

    /// <summary>
    /// 设置角色外观
    /// </summary>
    public void SetAppearance(CharacterAppearance newAppearance)
    {
        if (appearance == newAppearance)
            return;
        appearance = newAppearance;
        Refresh();
    }

    /// <summary>
    /// 由换装工作台直接指定当前要预览的动作。
    /// 这类预览以 CharacterFrameData 为准，不要求 Animator 里一定存在同名参数。
    /// </summary>
    public bool TrySetPreviewAnimation(AnimationTypeItem animationType, bool autoRefresh = true)
    {
        if (frameData == null || animationType == null)
            return false;

        EnsureCharacterActionAnimatorDriverReference();

        AnimationData animationData = frameData.GetAnimationByKey(animationType.name);
        if (!IsStandaloneBodyAnimation(animationData))
            return false;

        _currentAnimData = animationData;
        _currentAnimName = animationType.name;
        string resolvedKey = animationData.GetKey();
        _debugCurrentAnim = string.Equals(resolvedKey, _currentAnimName, System.StringComparison.Ordinal)
            ? _currentAnimName
            : $"{_currentAnimName} -> {resolvedKey}";
        _cachedFrame = null;
        _frameIndex = 0;
        UpdateUVMapTexture();

        if (autoRefresh)
            Refresh();

        return true;
    }

    public void SetPreviewDirection(int rowIndex, bool autoRefresh = true)
    {
        ApplyPreviewDirection(rowIndex, autoRefresh);
    }

    void ApplyPreviewDirection(int rowIndex, bool autoRefresh)
    {
        int clamped = Mathf.Clamp(rowIndex, 0, 3);
        if (_rowIndex == clamped)
            return;

        _rowIndex = clamped;
        _cachedFrame = null;
        if (autoRefresh)
            Refresh();
    }

    public void SetPreviewAnimation(AnimationTypeItem animationType, bool autoRefresh = true)
    {
        TrySetPreviewAnimation(animationType, autoRefresh);
    }

    public void SetAppearance(CharacterAppearance newAppearance, bool autoRefresh)
    {
        if (appearance == newAppearance)
            return;

        appearance = newAppearance;

        if (autoRefresh)
            Refresh();
    }

    public void SetFrameData(CharacterFrameData newFrameData, bool autoRefresh = true)
    {
        frameData = newFrameData;
        _currentAnimData = null;
        _currentAnimName = null;
        _cachedFrame = null;
        _animParamsCached = false;
        _validAnimParams = null;
        _debugCurrentAnim = string.Empty;
        _debugAnimatorState = string.Empty;
        SyncAnimationName();

        if (autoRefresh)
            Refresh();
    }

    /// <summary>
    /// 卸下所有装备
    /// </summary>
    public void UnequipAll()
    {
        var allEquipped = _slots.Values.ToList();
        if (_mainHandWeapon != null)
            allEquipped.Add(_mainHandWeapon);
        if (_offHandWeapon != null)
            allEquipped.Add(_offHandWeapon);

        foreach (var e in allEquipped)
            Unequip(e, false);

        _slots.Clear();
        _mainHandWeapon = null;
        _offHandWeapon = null;
        RemovePersistedGeneratedWeaponRendererChildren();

        Refresh();
    }

    /// <summary>
    /// 获取指定类型当前装备
    /// </summary>
    public EquipmentRenderData GetEquipped(EquipmentType type)
    {
        var cfg = EquipTypeRegistry.Get(type);
        if (cfg == null)
            return null;

        if (cfg.RenderMode == EquipRenderMode.Weapon)
        {
            if (type == EquipmentType.Shield)
                return _offHandWeapon != null && _offHandWeapon.type == type ? _offHandWeapon : null;

            return _mainHandWeapon != null && _mainHandWeapon.type == type ? _mainHandWeapon : null;
        }

        return _slots.TryGetValue(type, out var equip) ? equip : null;
    }

    /// <summary>
    /// 获取主手武器
    /// </summary>
    public EquipmentRenderData GetMainHandWeapon() => _mainHandWeapon;

    /// <summary>
    /// 获取副手武器
    /// </summary>
    public EquipmentRenderData GetOffHandWeapon() => _offHandWeapon;

    /// <summary>
    /// 获取当前头部插槽装备（Helmet / Hat / Mask，按优先级）
    /// </summary>
    public EquipmentRenderData GetHeadSlotEquipment()
    {
        // 按优先级检查：Helmet > Hat > Mask
        if (_slots.TryGetValue(EquipmentType.Helmet, out var helmet) && helmet != null)
            return helmet;
        if (_slots.TryGetValue(EquipmentType.Hat, out var hat) && hat != null)
            return hat;
        if (_slots.TryGetValue(EquipmentType.Mask, out var mask) && mask != null)
            return mask;
        return null;
    }

    /// <summary>
    /// 检查当前是否允许装备副手
    /// </summary>
    public bool CanEquipOffHand()
    {
        if (_mainHandWeapon == null)
            return true;
        return _mainHandWeapon.weaponSlotType == WeaponSlotType.MainHand;
    }

    void ClearExclusiveConflicts(EquipmentType newType, EquipmentRenderData incomingEquipment)
    {
        if (newType != EquipmentType.Helmet && newType != EquipmentType.Hat && newType != EquipmentType.Mask)
            return;

        ClearHeadSlotType(EquipmentType.Helmet, incomingEquipment);
        ClearHeadSlotType(EquipmentType.Hat, incomingEquipment);
        ClearHeadSlotType(EquipmentType.Mask, incomingEquipment);
    }

    void ClearHeadSlotType(EquipmentType type, EquipmentRenderData incomingEquipment)
    {
        if (_slots.TryGetValue(type, out var equipped) && equipped != null && equipped != incomingEquipment)
            _slots.Remove(type);
    }

    void CreateWeaponRenderer(EquipmentRenderData equip)
    {
        if (equip == null)
            return;

        RemoveStaleGeneratedWeaponRendererChildren();

        if (_weaponRenderers.TryGetValue(equip, out var existing))
        {
            if (existing != null)
                return;

            _weaponRenderers.Remove(equip);
        }

        RemoveDestroyedWeaponRendererSlots();

        if (_weaponRenderers.ContainsKey(equip))
            return;

        RemoveGeneratedWeaponRendererChildren(equip);

        var go = new GameObject(GetGeneratedWeaponRendererName(equip));
        go.hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild;
        go.transform.SetParent(transform, false);
        go.transform.localPosition = Vector3.zero;
        go.transform.localScale = Vector3.one;

        var sr = go.AddComponent<SpriteRenderer>();
        sr.hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild;
        sr.enabled = false;
        sr.maskInteraction = SpriteMaskInteraction.None;
        _weaponRenderers[equip] = sr;
    }

    SpriteRenderer GetOrCreateWeaponRenderer(EquipmentRenderData equip)
    {
        if (equip == null)
            return null;

        RemoveStaleGeneratedWeaponRendererChildren();

        if (_weaponRenderers.TryGetValue(equip, out var existing))
        {
            if (existing != null)
                return existing;

            _weaponRenderers.Remove(equip);
        }

        CreateWeaponRenderer(equip);
        return _weaponRenderers.TryGetValue(equip, out var created) ? created : null;
    }

    void RemoveStaleGeneratedWeaponRendererChildren()
    {
        var activeWeapons = new HashSet<EquipmentRenderData>();
        if (_mainHandWeapon != null)
            activeWeapons.Add(_mainHandWeapon);
        if (_offHandWeapon != null)
            activeWeapons.Add(_offHandWeapon);

        var staleRenderers = _weaponRenderers
            .Where(kv => kv.Key == null || !activeWeapons.Contains(kv.Key) || kv.Value == null)
            .ToList();

        for (int i = 0; i < staleRenderers.Count; i++)
        {
            SpriteRenderer sr = staleRenderers[i].Value;
            if (sr != null)
            {
                _weaponRendererSlots.Remove(sr);
                DestroyGeneratedRendererObject(sr.gameObject);
            }

            _weaponRenderers.Remove(staleRenderers[i].Key);
        }

        var activeNames = new HashSet<string>(
            activeWeapons
                .Where(weapon => weapon != null)
                .Select(GetGeneratedWeaponRendererName),
            StringComparer.Ordinal);

        for (int i = transform.childCount - 1; i >= 0; i--)
        {
            Transform child = transform.GetChild(i);
            if (child == null || !IsGeneratedWeaponRendererName(child.name))
                continue;

            if (activeNames.Contains(child.name))
                continue;

            SpriteRenderer sr = child.GetComponent<SpriteRenderer>();
            if (sr != null)
                _weaponRendererSlots.Remove(sr);

            DestroyGeneratedRendererObject(child.gameObject);
        }
    }

    void RemoveDestroyedWeaponRendererSlots()
    {
        if (_weaponRendererSlots.Count == 0)
            return;

        var destroyedRenderers = _weaponRendererSlots.Keys
            .Where(renderer => renderer == null)
            .ToList();

        for (int i = 0; i < destroyedRenderers.Count; i++)
            _weaponRendererSlots.Remove(destroyedRenderers[i]);
    }

    void RemovePersistedGeneratedWeaponRendererChildren()
    {
        for (int i = transform.childCount - 1; i >= 0; i--)
        {
            Transform child = transform.GetChild(i);
            if (child == null || !IsGeneratedWeaponRendererName(child.name))
                continue;

            SpriteRenderer sr = child.GetComponent<SpriteRenderer>();
            if (sr != null)
                _weaponRendererSlots.Remove(sr);

            DestroyGeneratedRendererObject(child.gameObject);
        }

        _weaponRenderers.Clear();
        _weaponRendererSlots.Clear();
    }

    void RemoveGeneratedWeaponRendererChildren(EquipmentRenderData equip)
    {
        string expectedName = GetGeneratedWeaponRendererName(equip);
        for (int i = transform.childCount - 1; i >= 0; i--)
        {
            Transform child = transform.GetChild(i);
            if (child == null || child.name != expectedName)
                continue;

            SpriteRenderer sr = child.GetComponent<SpriteRenderer>();
            if (sr != null)
                _weaponRendererSlots.Remove(sr);

            DestroyGeneratedRendererObject(child.gameObject);
        }
    }

    static string GetGeneratedWeaponRendererName(EquipmentRenderData equip)
    {
        return GeneratedWeaponRendererPrefix + (equip != null ? equip.name : "Unknown");
    }

    static bool IsGeneratedWeaponRendererName(string objectName)
    {
        return !string.IsNullOrEmpty(objectName)
            && objectName.StartsWith(GeneratedWeaponRendererPrefix, System.StringComparison.Ordinal);
    }

    static void DestroyGeneratedRendererObject(GameObject target)
    {
        if (target == null)
            return;

        target.transform.SetParent(null);

        if (Application.isPlaying)
            Destroy(target);
        else
            DestroyImmediate(target);
    }

    public void Refresh()
    {
        EnsureRendererInitialized();

        if (frameData == null)
        {
            Debug.LogWarning("[EquipmentRenderer] frameData 未设置");
            // 没有帧数据时，重置所有装备相关开关，避免残留上一次的装备渲染
            ResetEquipmentState();
            return;
        }

        if (_currentAnimData == null)
            _currentAnimData = FindAnimationByKey(_currentAnimName);

        _cachedFrame = _currentAnimData != null ? _currentAnimData.GetFrame(_frameIndex, _rowIndex) : null;

        // 普通衣服、斗篷、头盔等 Shader 装备层依赖当前动作的 UV 图。
        // 缺少 UV 图时只能保留武器或装备自己的序列帧；否则会把 32x32 装备图
        // 当成 UV 采样源，表现为中心展示区出现大块错误叠加。
        bool hasAnimData = _currentAnimData != null;
        bool hasFrame = _cachedFrame != null;
        bool hasBodyUV = _currentAnimData != null && _currentAnimData.bodyUVMap != null;
        bool hasHeadUV = _currentAnimData != null && _currentAnimData.headUVMap != null;

        if (!hasAnimData || !hasFrame || !hasBodyUV || !hasHeadUV)
        {
            ResetEquipmentState();

            if (_shaderMaterial != null)
            {
                _shaderMaterial.SetTexture(BodyUVMapProp, null);
                _shaderMaterial.SetTexture(HeadUVMapProp, null);
            }

            RenderWeapons();

            foreach (var cfg in EquipTypeRegistry.All)
            {
                if (
                    cfg.RenderMode == EquipRenderMode.None
                    || cfg.RenderMode == EquipRenderMode.Weapon
                )
                    continue;

                if (!_slots.TryGetValue(cfg.Type, out var equip) || equip == null)
                    continue;

                if (cfg.RenderMode == EquipRenderMode.Sprite && equip.HasSequenceForKey(_currentAnimName))
                    ApplySpriteEquipment(equip, cfg);
            }

            return;
        }

        UpdateShadowHeight();

        // 重置所有装备层（包括武器）
        ResetEquipmentState();

        UpdateUVMapTexture();

        if (_shaderMaterial != null)
        {
            float hitOutlineValue = _cachedFrame != null && _cachedFrame.hitOutlineFrame ? 1f : 0f;
            _shaderMaterial.SetFloat(HitOutlineProp, hitOutlineValue);
        }

        // 身体/头部前后关系（基于躯干部位的实际方向）
        UpdateBodyDepthMode();

        // ========== 武器渲染（支持主手+副手，双持双锚点）==========
        RenderWeapons();

        // 角色外观和颜色换肤依赖 UV 图。
        ApplyAppearanceToShader();

        // ========== 配置驱动：遍历所有装备配置并应用 ==========
        foreach (var cfg in EquipTypeRegistry.All)
        {
            if (
                cfg.RenderMode == EquipRenderMode.None
                || cfg.RenderMode == EquipRenderMode.Weapon
            )
                continue;

            if (!_slots.TryGetValue(cfg.Type, out var equip) || equip == null)
                continue;

            switch (cfg.RenderMode)
            {
                case EquipRenderMode.Sprite:
                    ApplySpriteEquipment(equip, cfg);
                    break;
                case EquipRenderMode.Color:
                    ApplyColorEquipment(equip, cfg);
                    break;
            }
        }
    }

    void UpdateUVMapTexture()
    {
        if (_shaderMaterial == null)
            return;

        // 双层 UV Map：缺失时必须主动清空，避免上一动作的 UV 图残留。
        _debugHasBodyUVMap = _currentAnimData != null && _currentAnimData.bodyUVMap != null;
        _debugHasHeadUVMap = _currentAnimData != null && _currentAnimData.headUVMap != null;

        _shaderMaterial.SetTexture(BodyUVMapProp, _debugHasBodyUVMap ? _currentAnimData.bodyUVMap : null);
        _shaderMaterial.SetTexture(HeadUVMapProp, _debugHasHeadUVMap ? _currentAnimData.headUVMap : null);
    }

    /// <summary>
    /// 重置所有装备层为禁用状态（配置驱动）
    /// </summary>
    void ResetEquipmentState()
    {
        if (_shaderMaterial == null)
            return;

        // 外观层（不走配置表）
        _shaderMaterial.SetFloat(EnableHairProp, 0);
        _shaderMaterial.SetFloat(EnableFaceAccessoryProp, 0);
        _shaderMaterial.SetFloat(EnableBeardProp, 0);
        _shaderMaterial.SetFloat(EnableLeftEyeProp, 0);
        _shaderMaterial.SetFloat(EnableRightEyeProp, 0);
        _shaderMaterial.SetFloat(HitOutlineProp, 0);
        _shaderMaterial.SetFloat(EnableEyeDecoProp, 0);
        _shaderMaterial.SetFloat(SkinPaletteEnabledProp, 0);
        _shaderMaterial.SetFloat(SkinColorCountProp, 0);
        // 双武器
        _shaderMaterial.SetTexture(Weapon0TexProp, null);
        _shaderMaterial.SetTexture(Weapon1TexProp, null);
        _shaderMaterial.SetVector(Weapon0RectProp, Vector4.zero);
        _shaderMaterial.SetVector(Weapon1RectProp, Vector4.zero);
        _shaderMaterial.SetVector(Weapon0AnchorFrameUVProp, Vector4.zero);
        _shaderMaterial.SetVector(Weapon1AnchorFrameUVProp, Vector4.zero);
        _shaderMaterial.SetVector(Weapon0RotCosSinProp, Vector4.zero);
        _shaderMaterial.SetVector(Weapon1RotCosSinProp, Vector4.zero);
        _shaderMaterial.SetFloat(Weapon0FlipXProp, 0);
        _shaderMaterial.SetFloat(Weapon1FlipXProp, 0);
        _shaderMaterial.SetFloat(Weapon0DepthModeProp, 0);
        _shaderMaterial.SetFloat(Weapon1DepthModeProp, 0);
        _shaderMaterial.SetFloat(Weapon0HandInFrontProp, 0);
        _shaderMaterial.SetFloat(Weapon1HandInFrontProp, 0);
        _shaderMaterial.SetFloat(Weapon0EnabledProp, 0);
        _shaderMaterial.SetFloat(Weapon1EnabledProp, 0);
        _shaderMaterial.SetFloat(Weapon0IsSequenceProp, 0);
        _shaderMaterial.SetFloat(Weapon1IsSequenceProp, 0);
        _shaderMaterial.SetFloat(Weapon0HideOutlineOnBodyProp, 0);
        _shaderMaterial.SetFloat(Weapon1HideOutlineOnBodyProp, 0);

        // 装备层（遍历配置表）
        foreach (var cfg in EquipTypeRegistry.All)
        {
            if (cfg.EnablePropId != 0)
                _shaderMaterial.SetFloat(cfg.EnablePropId, 0);
            if (cfg.TexPropId != 0)
                _shaderMaterial.SetTexture(cfg.TexPropId, null);
            if (cfg.RectPropId != 0)
                _shaderMaterial.SetVector(cfg.RectPropId, Vector4.zero);
        }
    }

    void UpdateBodyDepthMode()
    {
        if (_shaderMaterial == null)
            return;
        // 根据“身体实际方向”(Torso.spriteFacing) 判断深度模式：
        // - 当身体朝南 (SouthEast/SouthWest) 时，身体在头后(_BodyInFront=0)
        // - 当身体朝北 (NorthEast/NorthWest) 时，身体在头前(_BodyInFront=1)
        // 只看躯干的实际方向，不受 Head.spriteFacing 影响。

        CharacterFacing facing;
        if (_cachedFrame != null)
        {
            var torsoRegion = _cachedFrame.GetRegion(CharacterBodyPart.Torso);
            if (torsoRegion != null)
                facing = torsoRegion.spriteFacing;
            else
                facing = (CharacterFacing)_rowIndex; // 若缺少躯干区域，退回到当前行方向
        }
        else
        {
            facing = (CharacterFacing)_rowIndex;
        }

        int row = (int)facing;
        if (row < 0 || row > 3)
            row = 0;

        var safeFacing = (CharacterFacing)row;

        bool bodyInFront = row >= 2;
        _shaderMaterial.SetFloat(BodyInFrontProp, bodyInFront ? 1f : 0f);

        // 东向：SouthEast / NorthEast；西向：SouthWest / NorthWest
        bool bodyInEast = safeFacing == CharacterFacing.SouthEast || safeFacing == CharacterFacing.NorthEast;
        _shaderMaterial.SetFloat(BodyInEastProp, bodyInEast ? 1f : 0f);
    }

    void UpdateShadowHeight()
    {
        if (_shaderMaterial == null)
            return;

        if (frameData == null || _cachedFrame == null)
        {
            _shaderMaterial.SetFloat(ShadowModeProp, -1f); // 无阴影
            return;
        }

        var leftFoot = _cachedFrame.GetLimbPixels(CharacterBodyPart.LeftFoot);
        var rightFoot = _cachedFrame.GetLimbPixels(CharacterBodyPart.RightFoot);

        bool hasLeft = leftFoot != null && leftFoot.Count > 0;
        bool hasRight = rightFoot != null && rightFoot.Count > 0;

        if (!hasLeft && !hasRight)
        {
            _shaderMaterial.SetFloat(ShadowModeProp, -1f); // 无阴影
            return;
        }

        // 计算脚部边界
        int minY = int.MaxValue;
        int leftMinX = int.MaxValue, leftMaxX = int.MinValue;
        int rightMinX = int.MaxValue, rightMaxX = int.MinValue;
        int leftFootY = int.MaxValue, rightFootY = int.MaxValue;

        if (hasLeft)
        {
            for (int i = 0; i < leftFoot.Count; i++)
            {
                var p = leftFoot[i];
                if (p.y < minY) minY = p.y;
                if (p.y < leftFootY) leftFootY = p.y;
                if (p.x < leftMinX) leftMinX = p.x;
                if (p.x > leftMaxX) leftMaxX = p.x;
            }
        }

        if (hasRight)
        {
            for (int i = 0; i < rightFoot.Count; i++)
            {
                var p = rightFoot[i];
                if (p.y < minY) minY = p.y;
                if (p.y < rightFootY) rightFootY = p.y;
                if (p.x < rightMinX) rightMinX = p.x;
                if (p.x > rightMaxX) rightMaxX = p.x;
            }
        }

        int groundY = frameData.groundPixelY;
        int heightDiff = groundY - minY;
        
        // 获取帧尺寸
        int frameSizeX = _currentAnimData?.frameSize.x ?? 32;
        int frameSizeY = _currentAnimData?.frameSize.y ?? 32;

        // 将帧尺寸传入 Shader，供像素级阴影计算使用
        _shaderMaterial.SetVector(FrameSizeProp, new Vector4(frameSizeX, frameSizeY, 0f, 0f));

        // 根据高度差确定阴影模式
        float shadowMode;
        float leftX = 0, rightX = 0, centerX = 0;

        if (heightDiff <= 0)
        {
            // Mode 0: 地面状态 - 脚在基线上或更低
            shadowMode = 0;
        }
        else if (heightDiff <= 2)
        {
            // Mode 1: 离地渲染 - 脚在基线y-1到y-2位置
            shadowMode = 1;
            // 计算左脚到右脚的范围
            int overallMinX = Mathf.Min(hasLeft ? leftMinX : 999, hasRight ? rightMinX : 999);
            int overallMaxX = Mathf.Max(hasLeft ? leftMaxX : -999, hasRight ? rightMaxX : -999);
            leftX = overallMinX / (float)frameSizeX;
            rightX = overallMaxX / (float)frameSizeX;
        }
        else if (heightDiff <= 9)
        {
            // Mode 2: 空中模式 - 脚高于基线3-9格
            shadowMode = 2;
            
            // 判断哪只脚在下方
            bool leftLower = leftFootY <= rightFootY;
            if (leftLower && hasLeft)
            {
                // 左脚在下，取右边像素
                centerX = leftMaxX / (float)frameSizeX;
            }
            else if (hasRight)
            {
                // 右脚在下，取左边像素
                centerX = rightMinX / (float)frameSizeX;
            }
        }
        else
        {
            // Mode 3: 完全离地 - 脚高于基线10格以上
            shadowMode = 3;
            // 使用帧中心
            centerX = 0.5f;
        }

        // 写入Shader参数
        _shaderMaterial.SetFloat(ShadowModeProp, shadowMode);
        _shaderMaterial.SetFloat(ShadowLeftXProp, leftX);
        _shaderMaterial.SetFloat(ShadowRightXProp, rightX);
        _shaderMaterial.SetFloat(ShadowCenterXProp, centerX);
        float shadowBaseY01 = 1f - (groundY + 0.5f) / frameSizeY;
        _shaderMaterial.SetFloat(ShadowBaseYProp, shadowBaseY01);
    }

    /// <summary>
    /// 根据 facing 获取当前动画的装备序列帧（若无动画则返回 null），同时返回该帧的深度模式
    /// </summary>
    Sprite GetEquipSequenceSprite(EquipmentRenderData equip, CharacterFacing facing, out FrameDepthMode depthMode)
    {
        depthMode = FrameDepthMode.Front;
        if (equip == null)
            return null;

        return equip.TryGetSequenceSpriteByKeyWithDepth(
            _currentAnimName,
            (int)facing,
            _frameIndex,
            out depthMode
        );
    }

    Sprite GetEquipSequenceSprite(EquipmentRenderData equip, CharacterFacing facing)
    {
        FrameDepthMode _;
        return GetEquipSequenceSprite(equip, facing, out _);
    }

    /// <summary>
    /// Sprite 装备应用（配置驱动）
    /// </summary>
    void ApplySpriteEquipment(EquipmentRenderData equip, EquipTypeConfig cfg)
    {
        if (equip == null)
            return;

        if (_shaderMaterial == null)
            return;

        bool hasSequence = equip.HasSequenceForKey(_currentAnimName);
        var facing = GetSpriteFacingForPart(cfg.BodyPart);
        Sprite finalSprite = null;
        bool usesSequenceSprite = false;
        FrameDepthMode depthMode = FrameDepthMode.Front;

        if (hasSequence)
        {
            Sprite seqSprite = GetEquipSequenceSprite(equip, facing, out depthMode);
            if (seqSprite == null || seqSprite.texture == null)
                return;

            finalSprite = seqSprite;
            usesSequenceSprite = true;
        }

        if (finalSprite == null)
        {
            var variant = GetVariantForPart(cfg.BodyPart);
            finalSprite = equip.GetSprite(facing, variant);
        }

        if (finalSprite == null || finalSprite.texture == null)
            return;

        if (!usesSequenceSprite && IsInvalidEquipmentLayerSprite(finalSprite))
        {
            DisableSpriteEquipmentLayer(cfg);
            return;
        }

        if (finalSprite == null || finalSprite.texture == null)
            return;

        _shaderMaterial.SetTexture(cfg.TexPropId, finalSprite.texture);
        _shaderMaterial.SetVector(cfg.RectPropId, SpriteUtils.GetUVRect(finalSprite));
        _shaderMaterial.SetFloat(cfg.EnablePropId, 1);
    }

    void DisableSpriteEquipmentLayer(EquipTypeConfig cfg)
    {
        if (_shaderMaterial == null || cfg == null)
            return;

        _shaderMaterial.SetTexture(cfg.TexPropId, null);
        _shaderMaterial.SetVector(cfg.RectPropId, Vector4.zero);
        _shaderMaterial.SetFloat(cfg.EnablePropId, 0);
    }

    Sprite GetOrCreateRuntimePlaceholderSprite(EquipmentRenderData equip, EquipTypeConfig cfg)
    {
        if (equip == null || cfg == null)
            return null;

        if (_runtimePlaceholderSprites.TryGetValue(equip, out Sprite cachedSprite))
            return cachedSprite;

        const int size = 16;
        Texture2D texture = new Texture2D(size, size, TextureFormat.RGBA32, false)
        {
            name = equip.name + "_RuntimePlaceholder",
            filterMode = FilterMode.Point,
            wrapMode = TextureWrapMode.Clamp,
        };

        Color clear = new Color(0f, 0f, 0f, 0f);
        Color body = ResolvePlaceholderColor(equip);
        Color trim = Color.Lerp(body, Color.black, 0.42f);
        for (int y = 0; y < size; y++)
        {
            for (int x = 0; x < size; x++)
                texture.SetPixel(x, y, clear);
        }

        DrawRuntimePlaceholder(texture, cfg.Type, body, trim);
        texture.Apply(false, true);

        Sprite sprite = Sprite.Create(texture, new Rect(0f, 0f, size, size), new Vector2(0.5f, 0.5f), size);
        sprite.name = equip.name + "_RuntimePlaceholder";
        _runtimePlaceholderObjects.Add(texture);
        _runtimePlaceholderObjects.Add(sprite);
        _runtimePlaceholderSprites[equip] = sprite;
        return sprite;
    }

    static Color ResolvePlaceholderColor(EquipmentRenderData equip)
    {
        if (equip == null)
            return new Color(0.72f, 0.76f, 0.82f, 1f);

        Color color = Color.Lerp(equip.leftColor, equip.rightColor, 0.5f);
        if (color.a <= 0.01f)
            color.a = 1f;
        if (color.maxColorComponent <= 0.05f)
            color = new Color(0.72f, 0.76f, 0.82f, 1f);
        return color;
    }

    static void DrawRuntimePlaceholder(Texture2D texture, EquipmentType type, Color body, Color trim)
    {
        switch (type)
        {
            case EquipmentType.Helmet:
            case EquipmentType.Hat:
                FillPlaceholderRect(texture, 4, 5, 11, 6, trim);
                FillPlaceholderRect(texture, 5, 6, 10, 11, body);
                FillPlaceholderRect(texture, 3, 10, 12, 11, trim);
                break;
            case EquipmentType.Mask:
                FillPlaceholderRect(texture, 4, 6, 11, 10, body);
                FillPlaceholderRect(texture, 5, 8, 6, 8, trim);
                FillPlaceholderRect(texture, 9, 8, 10, 8, trim);
                break;
            case EquipmentType.Cloak:
                FillPlaceholderRect(texture, 5, 2, 10, 4, trim);
                FillPlaceholderRect(texture, 3, 4, 12, 14, body);
                FillPlaceholderRect(texture, 2, 13, 13, 14, trim);
                break;
            case EquipmentType.Bag:
                FillPlaceholderRect(texture, 4, 4, 11, 12, body);
                FillPlaceholderRect(texture, 5, 3, 10, 4, trim);
                FillPlaceholderRect(texture, 3, 6, 4, 10, trim);
                FillPlaceholderRect(texture, 11, 6, 12, 10, trim);
                break;
            case EquipmentType.Pants:
                FillPlaceholderRect(texture, 5, 3, 10, 7, body);
                FillPlaceholderRect(texture, 5, 7, 7, 14, body);
                FillPlaceholderRect(texture, 8, 7, 10, 14, body);
                FillPlaceholderRect(texture, 5, 13, 10, 14, trim);
                break;
            case EquipmentType.Clothing:
            default:
                FillPlaceholderRect(texture, 5, 2, 10, 5, trim);
                FillPlaceholderRect(texture, 4, 5, 11, 13, body);
                FillPlaceholderRect(texture, 3, 7, 4, 11, body);
                FillPlaceholderRect(texture, 11, 7, 12, 11, body);
                FillPlaceholderRect(texture, 5, 12, 10, 13, trim);
                break;
        }
    }

    static void FillPlaceholderRect(Texture2D texture, int minX, int minY, int maxX, int maxY, Color color)
    {
        if (texture == null)
            return;

        for (int y = Mathf.Max(0, minY); y <= Mathf.Min(texture.height - 1, maxY); y++)
        {
            for (int x = Mathf.Max(0, minX); x <= Mathf.Min(texture.width - 1, maxX); x++)
                texture.SetPixel(x, y, color);
        }
    }

    void ClearRuntimePlaceholderSprites()
    {
        for (int i = 0; i < _runtimePlaceholderObjects.Count; i++)
        {
            UnityEngine.Object target = _runtimePlaceholderObjects[i];
            if (target == null)
                continue;

            if (Application.isPlaying)
                Destroy(target);
            else
                DestroyImmediate(target);
        }

        _runtimePlaceholderObjects.Clear();
        _runtimePlaceholderSprites.Clear();
    }

    static bool IsInvalidEquipmentLayerSprite(Sprite sprite)
    {
        return IsUiIconSprite(sprite) || IsWholeCharacterActionSprite(sprite);
    }

    static bool IsUiIconSprite(Sprite sprite)
    {
        string path = GetEditorAssetPath(sprite);
        if (ContainsPathSegment(path, "/Craftable Items Icons/")
            || ContainsPathSegment(path, "/UI/")
            || ContainsIgnoreCase(path, "_Icons")
            || ContainsIgnoreCase(path, "Icons/"))
        {
            return true;
        }

        string textureName = sprite != null && sprite.texture != null ? sprite.texture.name : string.Empty;
        return ContainsIgnoreCase(textureName, "_Icons")
            || ContainsIgnoreCase(textureName, "Icons");
    }

    static bool IsWholeCharacterActionSprite(Sprite sprite)
    {
        string path = GetEditorAssetPath(sprite);
        if (IsEquipmentArtSpritePath(path))
            return false;

        string textureName = sprite != null && sprite.texture != null ? sprite.texture.name : string.Empty;
        if (IsKnownEquipmentOverlayTexture(textureName))
            return false;

        if (ContainsPathSegment(path, "/Sprites/Animations/Human/")
            || ContainsPathSegment(path, "/Sprites/Humanoids/")
            || ContainsPathSegment(path, "/Sprites/Crafting Professions/")
            || ContainsPathSegment(path, "/Sprites/Gathering Professions/"))
        {
            return true;
        }

        return ContainsIgnoreCase(textureName, "HumanBase")
            || ContainsIgnoreCase(textureName, "CreaturesHuman")
            || ContainsIgnoreCase(textureName, "CreaturesElf")
            || ContainsIgnoreCase(textureName, "CreaturesDwarf")
            || ContainsIgnoreCase(textureName, "CreaturesGoblin")
            || ContainsIgnoreCase(textureName, "CreaturesHalfling")
            || ContainsIgnoreCase(textureName, "CreaturesOrc")
            || ContainsIgnoreCase(textureName, "Human_")
            || ContainsIgnoreCase(textureName, "Elf_")
            || ContainsIgnoreCase(textureName, "Dwarf_")
            || ContainsIgnoreCase(textureName, "Goblin_")
            || ContainsIgnoreCase(textureName, "Halfling_")
            || ContainsIgnoreCase(textureName, "Orc_");
    }

    static bool IsKnownEquipmentOverlayTexture(string textureName)
    {
        return ContainsIgnoreCase(textureName, "Slash_sword_f")
            || ContainsIgnoreCase(textureName, "Slash_sword_b");
    }

    static bool IsEquipmentArtSpritePath(string path)
    {
        return ContainsPathSegment(path, "/Art/equip/")
            || ContainsPathSegment(path, "/ImportedSource/Art/equip/");
    }

    static bool ContainsPathSegment(string source, string marker)
    {
        return !string.IsNullOrEmpty(source)
            && source.IndexOf(marker, System.StringComparison.OrdinalIgnoreCase) >= 0;
    }

    static bool ContainsIgnoreCase(string source, string marker)
    {
        return !string.IsNullOrEmpty(source)
            && source.IndexOf(marker, System.StringComparison.OrdinalIgnoreCase) >= 0;
    }

    static string GetTransformPath(Transform transform)
    {
        if (transform == null)
            return string.Empty;

        string path = transform.name;
        Transform current = transform.parent;
        while (current != null)
        {
            path = current.name + "/" + path;
            current = current.parent;
        }

        return path;
    }

    static string GetEditorAssetPath(Sprite sprite)
    {
#if UNITY_EDITOR
        if (sprite == null)
            return string.Empty;

        string path = UnityEditor.AssetDatabase.GetAssetPath(sprite);
        return string.IsNullOrEmpty(path) ? string.Empty : path.Replace('\\', '/');
#else
        return string.Empty;
#endif
    }

    /// <summary>
    /// 获取指定部位实际使用的贴图方向
    /// 如果部位配置了覆盖，返回覆盖的方向；否则返回当前动画行对应的方向
    /// </summary>
    CharacterFacing GetSpriteFacingForPart(CharacterBodyPart part)
    {
        if (_cachedFrame == null)
            return (CharacterFacing)_rowIndex;

        var region = _cachedFrame.GetRegion(part);
        if (region == null)
            return (CharacterFacing)_rowIndex;

        return region.spriteFacing;
    }

    /// <summary>
    /// 获取指定部位当前帧使用的变体（默认 Base）
    /// </summary>
    FrameVariant GetVariantForPart(CharacterBodyPart part)
    {
        if (_cachedFrame == null)
            return FrameVariant.Base;

        var region = _cachedFrame.GetRegion(part);
        if (region == null)
            return FrameVariant.Base;

        return region.variant;
    }

    /// <summary>
    /// 设置角色外观 (头发/胡子) - 来自 CharacterAppearance
    /// </summary>
    void ApplyAppearanceToShader()
    {
        if (_shaderMaterial == null || appearance == null)
            return;

        // 头部装备隐藏配置（Helmet / Hat / Mask 均可配置）
        bool hideHair = false;
        bool hideBeard = false;
        var headEquip = GetHeadSlotEquipment();
        if (headEquip != null)
        {
            hideHair = headEquip.hideHair;
            hideBeard = headEquip.hideBeard;
        }

        // 头部外观统一跟随 Head 的 spriteFacing
        var headFacing = GetSpriteFacingForPart(CharacterBodyPart.Head);

        // 设置头发
        if (appearance.HasHair && !hideHair)
        {
            var hairSprite = appearance.GetHairSprite(headFacing);
            if (hairSprite != null && hairSprite.texture != null)
            {
                _shaderMaterial.SetTexture(HairTexProp, hairSprite.texture);
                _shaderMaterial.SetVector(HairRectProp, SpriteUtils.GetUVRect(hairSprite));
                _shaderMaterial.SetFloat(EnableHairProp, 1);
            }
        }

        // 设置面部装饰（只在朝南时显示）
        if (appearance.HasFaceAccessory)
        {
            var faceAccessorySprite = appearance.GetFaceAccessorySprite(headFacing);
            if (faceAccessorySprite != null && faceAccessorySprite.texture != null)
            {
                _shaderMaterial.SetTexture(FaceAccessoryTexProp, faceAccessorySprite.texture);
                _shaderMaterial.SetVector(
                    FaceAccessoryRectProp,
                    SpriteUtils.GetUVRect(faceAccessorySprite)
                );
                _shaderMaterial.SetFloat(EnableFaceAccessoryProp, 1);
            }
        }

        // 设置胡子
        if (appearance.HasBeard && !hideBeard)
        {
            var beardSprite = appearance.GetBeardSprite(headFacing);
            if (beardSprite != null && beardSprite.texture != null)
            {
                _shaderMaterial.SetTexture(BeardTexProp, beardSprite.texture);
                _shaderMaterial.SetVector(BeardRectProp, SpriteUtils.GetUVRect(beardSprite));
                _shaderMaterial.SetFloat(EnableBeardProp, 1);
            }
        }

        // 设置眼睛颜色
        var headFacingDir = CharacterFrameData.GetFacingDirection(headFacing);
        bool eyesVisible = headFacingDir == FacingDirection.Front;
        bool leftClosed = false;
        bool rightClosed = false;
        if (_cachedFrame != null)
        {
            leftClosed = _cachedFrame.leftEyeClosed;
            rightClosed = _cachedFrame.rightEyeClosed;
        }
        bool enableLeftEye = eyesVisible && !leftClosed;
        bool enableRightEye = eyesVisible && !rightClosed;
        _shaderMaterial.SetColor(LeftEyeColorProp, appearance.leftEyeColor);
        _shaderMaterial.SetColor(RightEyeColorProp, appearance.rightEyeColor);
        _shaderMaterial.SetFloat(EnableLeftEyeProp, enableLeftEye ? 1f : 0f);
        _shaderMaterial.SetFloat(EnableRightEyeProp, enableRightEye ? 1f : 0f);
        
        // 设置眼部装饰
        ApplyEyeDecoration(headFacing);

        // 设置肤色映射（基于颜色表的查表换肤）
        ApplySkinPalette();
    }
    
    /// <summary>
    /// 设置肤色映射参数（颜色数组查表换肤）
    /// </summary>
    void ApplySkinPalette()
    {
        if (_shaderMaterial == null)
            return;

        if (appearance == null || appearance.skinSrcColors == null || appearance.skinDstColors == null)
        {
            _shaderMaterial.SetFloat(SkinPaletteEnabledProp, 0f);
            _shaderMaterial.SetFloat(SkinColorCountProp, 0f);
            return;
        }

        int count = Mathf.Min(
            appearance.skinSrcColors.Length,
            appearance.skinDstColors.Length,
            MaxSkinColors);

        if (count <= 0)
        {
            _shaderMaterial.SetFloat(SkinPaletteEnabledProp, 0f);
            _shaderMaterial.SetFloat(SkinColorCountProp, 0f);
            return;
        }

        // Unity 在 Linear 色彩空间下会在采样 sRGB 纹理时自动做 Gamma->Linear，
        // 但通过 SetVectorArray 传入的颜色不会自动转换。
        // 这里根据当前项目 ColorSpace 做一次显式统一，保证 Shader 里比较的是“同一空间”的颜色。
        bool useLinear = QualitySettings.activeColorSpace == ColorSpace.Linear;

        for (int i = 0; i < count; i++)
        {
            Color src = appearance.skinSrcColors[i];
            Color dst = appearance.skinDstColors[i];

            if (useLinear)
            {
                src = src.linear;
                dst = dst.linear;
            }

            _skinSrcColorBuffer[i] = src;
            _skinDstColorBuffer[i] = dst;
        }

        _shaderMaterial.SetFloat(SkinPaletteEnabledProp, 1f);
        _shaderMaterial.SetFloat(SkinColorCountProp, count);
        _shaderMaterial.SetVectorArray(SkinSrcColorsProp, _skinSrcColorBuffer);
        _shaderMaterial.SetVectorArray(SkinDstColorsProp, _skinDstColorBuffer);
    }
    
    /// <summary>
    /// 设置眼部装饰贴图（只在朝南时显示）
    /// </summary>
    void ApplyEyeDecoration(CharacterFacing headFacing)
    {
        // 默认关闭
        _shaderMaterial.SetFloat(EnableEyeDecoProp, 0);
        
        if (appearance == null || !appearance.HasEyeDecoration)
            return;
        
        var eyeDecoSprite = appearance.GetEyeDecorationSprite(headFacing);
        if (eyeDecoSprite != null && eyeDecoSprite.texture != null)
        {
            _shaderMaterial.SetTexture(EyeDecoTexProp, eyeDecoSprite.texture);
            _shaderMaterial.SetVector(EyeDecoRectProp, SpriteUtils.GetUVRect(eyeDecoSprite));
            _shaderMaterial.SetFloat(EnableEyeDecoProp, 1);
        }
    }

    /// <summary>
    /// 颜色装备应用（配置驱动）
    /// </summary>
    void ApplyColorEquipment(EquipmentRenderData equip, EquipTypeConfig cfg)
    {
        if (_shaderMaterial == null)
            return;

        _shaderMaterial.SetColor(cfg.LeftColorPropId, equip.leftColor);
        _shaderMaterial.SetColor(cfg.RightColorPropId, equip.rightColor);
        _shaderMaterial.SetFloat(cfg.EnablePropId, 1);
    }

    /// <summary>
    /// 渲染所有武器（主手 + 副手，支持双持双锚点）
    /// </summary>
    void RenderWeapons()
    {
        RemoveStaleGeneratedWeaponRendererChildren();

        // 先隐藏所有武器子对象
        foreach (var kv in _weaponRenderers)
        {
            if (kv.Value != null)
                kv.Value.enabled = false;
        }

        // 更新角色帧 Rect（双武器共用）
        UpdateCharFrameRect();

        if (_mainHandWeapon != null)
        {
            // 双持：同一装备在两个锚点显示
            if (_mainHandWeapon.weaponSlotType == WeaponSlotType.DualWield)
            {
                RenderWeaponSlot(_mainHandWeapon, AnchorType.MainHandWeapon, 0);
                RenderWeaponSlot(_mainHandWeapon, AnchorType.OffHandWeapon, 1);
            }
            else if (_mainHandWeapon.weaponSlotType == WeaponSlotType.TwoHand)
            {
                // 双手武器：根据配置选择锚点
                var anchor = _mainHandWeapon.useOffHandAnchor ? AnchorType.OffHandWeapon : AnchorType.MainHandWeapon;
                RenderWeaponSlot(_mainHandWeapon, anchor, 0);
            }
            else
            {
                // 单手：使用主手锚点
                RenderWeaponSlot(_mainHandWeapon, AnchorType.MainHandWeapon, 0);
            }
        }

        // 副手武器
        if (_offHandWeapon != null)
        {
            RenderWeaponSlot(_offHandWeapon, AnchorType.OffHandWeapon, 1);
        }
    }

    /// <summary>
    /// 更新角色帧 Rect（供 Shader 使用）
    /// </summary>
    void UpdateCharFrameRect()
    {
        if (_shaderMaterial == null)
            return;
        var charSprite = _charRenderer.sprite;
        if (charSprite == null || charSprite.texture == null)
            return;

        var charRect = charSprite.rect;
        float texW = charSprite.texture.width;
        float texH = charSprite.texture.height;
        _shaderMaterial.SetTexture(MainTexProp, charSprite.texture);
        var charFrameRect = new Vector4(
            charRect.xMin / texW,
            charRect.yMin / texH,
            charRect.xMax / texW,
            charRect.yMax / texH
        );
        _shaderMaterial.SetVector(CharFrameRectProp, charFrameRect);
    }

    #region 武器渲染辅助

    /// <summary>
    /// 按方向索引的武器配置表（SE=0, SW=1, NE=2, NW=3）
    /// HandOffsetX/Y 表示"虚拟左手"相对于贴图几何中心(16,16)的像素偏移：
    ///   像素画镜像限制：东向虚拟左手在(15,16)，西向在(16,16)
    ///   X: 东向 -1（像素15），西向 0（像素16）
    ///   Y: 统一 0（像素16）
    /// LeftSortDelta 用于主手锚点（MainHandWeapon）的排序偏移：
    ///   >0: 主手锚点在前（SW/NW），<0: 主手锚点在后（SE/NE）
    ///   副手锚点（OffHandWeapon）使用 -LeftSortDelta
    /// </summary>
    static readonly WeaponFacingConfig[] WeaponConfigByRow =
    {
        new WeaponFacingConfig(-0.5f, -0.5f, true,  -1), // SE: 东向，主手锚点在后
        new WeaponFacingConfig(-0.5f, -0.5f, true,  +1), // SW: 西向，主手锚点在前
        new WeaponFacingConfig(-0.5f, -0.5f, false, -1), // NE: 东向，主手锚点在后
        new WeaponFacingConfig(-0.5f, -0.5f, false, +1), // NW: 西向，主手锚点在前
    };

    readonly struct WeaponFacingConfig
    {
        public readonly float HandOffsetX;   // 虚拟左手偏移 X
        public readonly float HandOffsetY;   // 虚拟左手偏移 Y
        public readonly bool  IsFront;       // 是否前景（武器在身体前）
        public readonly int   LeftSortDelta; // 左武器排序偏移

        public WeaponFacingConfig(float hx, float hy, bool front, int sortDelta)
        {
            HandOffsetX = hx;
            HandOffsetY = hy;
            IsFront = front;
            LeftSortDelta = sortDelta;
        }
    }

    /// <summary>
    /// 像素坐标转帧内 UV（左下角为原点，Y 向上）
    /// </summary>
    static Vector2 PixelToFrameUV(float pixelX, float pixelY, int frameW, int frameH)
    {
        return new Vector2(pixelX / frameW, 1f - pixelY / frameH);
    }

    /// <summary>
    /// 获取当前方向的武器配置
    /// </summary>
    WeaponFacingConfig GetWeaponConfig(int rowIndex)
    {
        return (rowIndex >= 0 && rowIndex < WeaponConfigByRow.Length)
            ? WeaponConfigByRow[rowIndex]
            : WeaponConfigByRow[0];
    }

    /// <summary>
    /// 获取武器排序偏移
    /// 根据当前朝向下“物理左手/右手”的前后关系以及锚点类型(Main/Off)决定：
    ///   1. LeftSortDelta 表示当前朝向下“左手侧武器”的排序偏移
    ///   2. 通过朝向判断主手锚点是在左手还是右手
    ///   3. 再根据 AnchorType 判断当前锚点是不是左手侧锚点
    /// </summary>
    int GetWeaponSortOffset(AnchorType anchorType, int rowIndex)
    {
        var cfg = GetWeaponConfig(rowIndex);
        var facing = (CharacterFacing)rowIndex;

        bool isLeft = AnchorFacingConfig.IsAnchorOnLeftSide(anchorType, facing);

        return isLeft ? cfg.LeftSortDelta : -cfg.LeftSortDelta;
    }

    #endregion

    /// <summary>
    /// 渲染单个武器槽位
    /// </summary>
    void RenderWeaponSlot(EquipmentRenderData equip, AnchorType anchorType, int shaderSlot)
    {
        if (equip == null)
            return;

        // 武器贴图方向：跟随身体躯干的 spriteFacing（转身时武器一起转向）
        var weaponFacing = GetSpriteFacingForPart(CharacterBodyPart.Torso);
        int weaponRowIndex = (int)weaponFacing;

        // 从当前帧数据中获取对应锚点（用于 Shader 模式定位与旋转）；
        // 序列帧模式不强制要求锚点，仅在有锚点时用于微调 SpriteRenderer 位置
        var anchor = _cachedFrame != null ? _cachedFrame.GetAnchor(anchorType) : null;

        // 当前槽位相对角色的前后：根据朝向下“主/副手锚点”对应的左/右手关系来决定
        // 排序偏移 >0 表示在角色前，<0 表示在角色后（静态武器默认规则）
        int baseSortOffset = GetWeaponSortOffset(anchorType, weaponRowIndex);
        bool slotIsFront = baseSortOffset > 0;
        
        // 判断武器类型（后面处理盾牌特殊逻辑）
        bool isShield = (equip.type == EquipmentType.Shield);

        // Shader 武器层：统一通过 Shader 渲染
        if (_shaderMaterial == null || _cachedFrame == null)
            return;

        var charSpriteShader = _charRenderer.sprite;
        if (charSpriteShader == null)
            return;

        // 是否配置了当前动画的序列帧
        bool hasSequence = equip.HasSequenceForKey(_currentAnimName);

        FrameDepthMode depthMode = FrameDepthMode.Front;
        Sprite seqSprite = null;
        Sprite weaponSprite = null;
        bool useSequence = false;

        if (hasSequence)
        {
            // 1）有序列帧：完全由序列帧驱动，不再回退到静态四向贴图
            seqSprite = GetEquipSequenceSprite(equip, weaponFacing, out depthMode);
            weaponSprite = seqSprite;

            // 该帧拿不到序列帧 Sprite 时，本帧不渲染武器（不使用静态贴图兜底）
            if (weaponSprite == null || weaponSprite.texture == null || IsInvalidEquipmentLayerSprite(weaponSprite))
            {
                DisableGeneratedWeaponRenderer(equip);
                SetWeaponShaderEnabled(shaderSlot, false);
                return;
            }

            useSequence = true;
            slotIsFront = (depthMode != FrameDepthMode.Back);
        }
        else
        {
            // 2）无序列帧：使用静态四向贴图 + 原有前后规则
            weaponSprite = equip.GetSpriteByRow(weaponRowIndex);
            if (weaponSprite == null || weaponSprite.texture == null)
                return;
            if (IsUiIconSprite(weaponSprite) || IsWholeCharacterActionSprite(weaponSprite))
                return;
        }

        // 获取当前方向配置（与武器贴图方向一致）
        var cfg = GetWeaponConfig(weaponRowIndex);

        // 西向行（SW=1 / NW=3）是否需要 flipX（仅静态贴图使用）：
        // 只有在"没有任何西向贴图（SW 也没配）"时才需要从 SE 翻转生成
        bool isWestFacing = (weaponRowIndex == 1 || weaponRowIndex == 3);
        bool hasWestSprite = equip.spriteSW != null; // SW 是西向的基础图
        bool flipX = !useSequence && isWestFacing && !hasWestSprite;

        // 帧尺寸
        var charRect = charSpriteShader.rect;
        int frameW = _currentAnimData != null ? _currentAnimData.frameSize.x : (int)charRect.width;
        int frameH = _currentAnimData != null ? _currentAnimData.frameSize.y : (int)charRect.height;
        frameW = Mathf.Max(frameW, 1);
        frameH = Mathf.Max(frameH, 1);

        // 计算手点在角色帧中的像素位置：
        // - 静态武器：必须有锚点，否则直接返回；
        // - 序列帧：优先用锚点，缺失时退回到帧中心。
        float anchorPixelX;
        float anchorPixelY;
        if (anchor != null)
        {
            anchorPixelX = anchor.position.x + 0.5f;
            anchorPixelY = anchor.position.y + 0.5f;
        }
        else
        {
            if (!useSequence)
            {
                DisableGeneratedWeaponRenderer(equip);
                SetWeaponShaderEnabled(shaderSlot, false);
                return;
            }

            anchorPixelX = frameW * 0.5f;
            anchorPixelY = frameH * 0.5f;
        }

        var anchorFrameUV = PixelToFrameUV(anchorPixelX, anchorPixelY, frameW, frameH);

        // 武器贴图中的"虚拟左手"局部 UV（相对于几何中心的像素偏移）
        float weaponW = weaponSprite.rect.width;
        float weaponH = weaponSprite.rect.height;
        float handLocalU = 0.5f + cfg.HandOffsetX / Mathf.Max(weaponW, 1f);
        float handLocalV = 0.5f + cfg.HandOffsetY / Mathf.Max(weaponH, 1f);
        Vector4 anchorAndHandUV = new Vector4(anchorFrameUV.x, anchorFrameUV.y, handLocalU, handLocalV);

        // 旋转：序列帧固定无旋转/FlipX；静态武器沿用锚点角度 + 可选 FlipX
        Vector4 rotCosSin;
        if (useSequence)
        {
            float angleDeg = 0f;
            float angleRad = angleDeg * Mathf.Deg2Rad;
            rotCosSin = new Vector4(Mathf.Cos(angleRad), Mathf.Sin(angleRad), 0f, 0f);
        }
        else
        {
            float angleDeg = anchor != null ? anchor.GetRotationAngle() : 0f;
            if (flipX)
                angleDeg = -angleDeg;
            float angleRad = angleDeg * Mathf.Deg2Rad;
            rotCosSin = new Vector4(Mathf.Cos(angleRad), Mathf.Sin(angleRad), 0f, 0f);
        }

        // 根据武器类型决定手部遮挡：
        // 盾牌特殊处理：朝南时盾牌在前，朝北时手在前
        // 其他武器：手在前（可以看到手握着武器）
        bool handInFront;
        if (isShield)
        {
            // 盾牌：朝南时盾在前，朝北时手在前
            bool isSouth = (weaponFacing == CharacterFacing.SouthEast || weaponFacing == CharacterFacing.SouthWest);
            handInFront = !isSouth;
        }
        else
        {
            // 普通武器：手在前
            handInFront = true;
        }

        bool hideOutlineOnBody = equip.hideOutlineOnBody;

        // 场景新增前的正式换装逻辑：武器通过角色 Shader 按帧 UV 和作者锚点合成。
        // 子 SpriteRenderer 只作为挂载对象保留，不参与主武器图像渲染。
        DisableGeneratedWeaponRenderer(equip);
        SetWeaponShaderParams(
            shaderSlot,
            weaponSprite,
            anchorAndHandUV,
            rotCosSin,
            flipX,
            slotIsFront,
            handInFront,
            useSequence,
            hideOutlineOnBody
        );
    }

    void DisableGeneratedWeaponRenderer(EquipmentRenderData equip)
    {
        if (equip == null)
            return;

        if (_weaponRenderers.TryGetValue(equip, out SpriteRenderer renderer) && renderer != null)
        {
            renderer.enabled = false;
            renderer.sprite = null;
        }

        string expectedName = GetGeneratedWeaponRendererName(equip);
        for (int i = transform.childCount - 1; i >= 0; i--)
        {
            Transform child = transform.GetChild(i);
            if (child == null || child.name != expectedName)
                continue;

            SpriteRenderer childRenderer = child.GetComponent<SpriteRenderer>();
            if (childRenderer == null)
                continue;

            childRenderer.enabled = false;
            childRenderer.sprite = null;
        }
    }

    void ConfigureWeaponPreviewRenderer(
        SpriteRenderer sr,
        Sprite weaponSprite,
        AnchorPoint anchor,
        AnchorType anchorType,
        int weaponRowIndex,
        bool slotIsFront,
        bool useSequence,
        bool flipX)
    {
        if (sr == null || weaponSprite == null || _charRenderer == null)
            return;

        Sprite charSprite = _charRenderer.sprite;
        if (charSprite == null)
            return;

        float ppu = Mathf.Max(charSprite.pixelsPerUnit, 1f);
        int frameW = _currentAnimData != null ? _currentAnimData.frameSize.x : (int)charSprite.rect.width;
        int frameH = _currentAnimData != null ? _currentAnimData.frameSize.y : (int)charSprite.rect.height;
        frameW = Mathf.Max(frameW, 1);
        frameH = Mathf.Max(frameH, 1);

        if (useSequence)
        {
            sr.transform.localPosition = Vector3.zero;
            sr.transform.localRotation = Quaternion.identity;
        }
        else if (anchor != null)
        {
            float frameCx = frameW * 0.5f;
            float frameCy = frameH * 0.5f;
            sr.transform.localPosition = new Vector3(
                (anchor.position.x - frameCx) / ppu,
                (frameCy - anchor.position.y) / ppu,
                0f);
            sr.transform.localRotation = Quaternion.Euler(0f, 0f, anchor.GetRotationAngle());
        }
        else
        {
            Vector2 fallback = GetFallbackWeaponPreviewOffset(anchorType, weaponRowIndex, frameW, frameH);
            sr.transform.localPosition = new Vector3(fallback.x / ppu, fallback.y / ppu, 0f);
            sr.transform.localRotation = Quaternion.identity;
        }

        sr.sprite = weaponSprite;
        sr.enabled = true;
        sr.flipX = !useSequence && flipX;
        sr.flipY = false;
        sr.transform.localScale = Vector3.one;
        sr.sortingLayerID = _charRenderer.sortingLayerID;
        sr.sortingOrder = _charRenderer.sortingOrder + (slotIsFront ? 2 : -2);
        sr.maskInteraction = SpriteMaskInteraction.None;
        _weaponRendererSlots[sr] = slotIsFront ? 1 : -1;
    }

    static Vector2 GetFallbackWeaponPreviewOffset(AnchorType anchorType, int rowIndex, int frameW, int frameH)
    {
        bool west = rowIndex == 1 || rowIndex == 3;
        bool north = rowIndex == 2 || rowIndex == 3;
        float horizontal = west ? -frameW * 0.22f : frameW * 0.22f;
        float vertical = north ? frameH * 0.05f : -frameH * 0.05f;
        if (anchorType == AnchorType.OffHandWeapon)
            horizontal = -horizontal;

        return new Vector2(horizontal, vertical);
    }

    /// <summary>
    /// 设置武器 Shader 参数
    /// </summary>
    void SetWeaponShaderParams(int slot, Sprite sprite, Vector4 anchorAndHandUV, Vector4 rotCosSin, bool flipX, bool isFront, bool handInFront, bool isSequence, bool hideOutlineOnBody)
    {
        int texProp    = slot == 0 ? Weapon0TexProp           : Weapon1TexProp;
        int rectProp   = slot == 0 ? Weapon0RectProp          : Weapon1RectProp;
        int anchorProp = slot == 0 ? Weapon0AnchorFrameUVProp : Weapon1AnchorFrameUVProp;
        int rotProp    = slot == 0 ? Weapon0RotCosSinProp     : Weapon1RotCosSinProp;
        int flipProp   = slot == 0 ? Weapon0FlipXProp         : Weapon1FlipXProp;
        int depthProp  = slot == 0 ? Weapon0DepthModeProp     : Weapon1DepthModeProp;
        int handInFrontProp = slot == 0 ? Weapon0HandInFrontProp : Weapon1HandInFrontProp;
        int isSequenceProp = slot == 0 ? Weapon0IsSequenceProp : Weapon1IsSequenceProp;
        int enableProp = slot == 0 ? Weapon0EnabledProp       : Weapon1EnabledProp;
        int hideOutlineOnBodyProp = slot == 0 ? Weapon0HideOutlineOnBodyProp : Weapon1HideOutlineOnBodyProp;

        _shaderMaterial.SetTexture(texProp, sprite.texture);
        _shaderMaterial.SetVector(rectProp, SpriteUtils.GetUVRect(sprite));
        _shaderMaterial.SetVector(anchorProp, anchorAndHandUV);
        _shaderMaterial.SetVector(rotProp, rotCosSin);
        _shaderMaterial.SetFloat(flipProp, flipX ? 1f : 0f);
        _shaderMaterial.SetFloat(depthProp, isFront ? 1f : 0f);
        _shaderMaterial.SetFloat(handInFrontProp, handInFront ? 1f : 0f);
        _shaderMaterial.SetFloat(isSequenceProp, isSequence ? 1f : 0f);
        _shaderMaterial.SetFloat(hideOutlineOnBodyProp, hideOutlineOnBody ? 1f : 0f);
        _shaderMaterial.SetFloat(enableProp, 1f);
    }

    void SetWeaponShaderEnabled(int slot, bool enabled)
    {
        if (_shaderMaterial == null)
            return;

        int enableProp = slot == 0 ? Weapon0EnabledProp : Weapon1EnabledProp;
        int texProp = slot == 0 ? Weapon0TexProp : Weapon1TexProp;
        int rectProp = slot == 0 ? Weapon0RectProp : Weapon1RectProp;
        int anchorProp = slot == 0 ? Weapon0AnchorFrameUVProp : Weapon1AnchorFrameUVProp;
        int rotProp = slot == 0 ? Weapon0RotCosSinProp : Weapon1RotCosSinProp;
        int flipProp = slot == 0 ? Weapon0FlipXProp : Weapon1FlipXProp;
        int depthProp = slot == 0 ? Weapon0DepthModeProp : Weapon1DepthModeProp;
        int handInFrontProp = slot == 0 ? Weapon0HandInFrontProp : Weapon1HandInFrontProp;
        int isSequenceProp = slot == 0 ? Weapon0IsSequenceProp : Weapon1IsSequenceProp;
        int hideOutlineOnBodyProp = slot == 0 ? Weapon0HideOutlineOnBodyProp : Weapon1HideOutlineOnBodyProp;

        _shaderMaterial.SetFloat(enableProp, enabled ? 1f : 0f);
        if (!enabled)
        {
            _shaderMaterial.SetTexture(texProp, null);
            _shaderMaterial.SetVector(rectProp, Vector4.zero);
            _shaderMaterial.SetVector(anchorProp, Vector4.zero);
            _shaderMaterial.SetVector(rotProp, Vector4.zero);
            _shaderMaterial.SetFloat(flipProp, 0f);
            _shaderMaterial.SetFloat(depthProp, 0f);
            _shaderMaterial.SetFloat(handInFrontProp, 0f);
            _shaderMaterial.SetFloat(isSequenceProp, 0f);
            _shaderMaterial.SetFloat(hideOutlineOnBodyProp, 0f);
        }
    }

#if UNITY_EDITOR
    void OnValidate()
    {
        if (Application.isPlaying)
            Refresh();
    }
#endif
}
