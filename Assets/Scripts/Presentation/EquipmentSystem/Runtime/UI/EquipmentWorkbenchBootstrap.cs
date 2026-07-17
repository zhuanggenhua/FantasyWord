using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.UI;
using UnityEngine.Serialization;

/// <summary>
/// 场景启动入口：把 catalog、渲染器、动画控制器和预览 UI 绑定起来。
/// </summary>
[DisallowMultipleComponent]
public sealed class EquipmentWorkbenchBootstrap : MonoBehaviour
{
    [SerializeField]
    [FormerlySerializedAs("configuration")]
    EquipmentWorkbenchCatalog catalog;

    [SerializeField]
    EquipmentRenderer equipmentRenderer;

    [SerializeField]
    CharacterActionAnimatorDriver animationController;

    [SerializeField]
    DirectionalSpriteLibraryDriver directionDriver;

    [SerializeField]
    EquipmentWorkbenchController controller;

    [SerializeField]
    EquipmentWorkbenchRuntimeUI runtimeUi;

    [SerializeField]
    EquipmentWorkbenchRuntimeUI runtimeUiPrefab;

    [SerializeField]
    EventSystem eventSystem;

    [SerializeField]
    InputSystemUIInputModule inputModule;

    [SerializeField]
    [Tooltip("工作台 UI 字体。为空时使用 Runtime UI 预制体上绑定的字体。")]
    TMP_FontAsset workbenchFont;

    public void SetCatalog(EquipmentWorkbenchCatalog newCatalog)
    {
        catalog = newCatalog;
    }

    void Reset()
    {
        equipmentRenderer = GetComponent<EquipmentRenderer>();
        animationController = GetComponent<CharacterActionAnimatorDriver>();
        directionDriver = GetComponent<DirectionalSpriteLibraryDriver>();
        controller = GetComponent<EquipmentWorkbenchController>();
    }

    void Awake()
    {
        if (!Application.isPlaying)
            return;

        ValidateControllerBinding();
    }

    void OnEnable()
    {
        if (!Application.isPlaying)
            return;

        EnsureWorkbenchReady();
    }

    void Start()
    {
        if (!Application.isPlaying)
            return;

        EnsureWorkbenchReady();
    }

    public void EnsureWorkbenchReady()
    {
        if (!Application.isPlaying)
            return;

        if (!ValidateControllerBinding())
            return;

        controller.InitializeIfNeeded();
        if (!EnsureEventSystem())
            return;

        EnsureRuntimeUi();
    }

    bool ValidateControllerBinding()
    {
        if (controller == null)
        {
            Debug.LogError("未绑定 EquipmentWorkbenchController。工作台启动器不再运行时自动添加控制器。", this);
            return false;
        }

        if (catalog == null)
        {
            Debug.LogError("未绑定 EquipmentWorkbenchCatalog。", this);
            return false;
        }

        if (equipmentRenderer == null)
        {
            Debug.LogError("未绑定 EquipmentRenderer。", this);
            return false;
        }

        if (animationController == null)
        {
            Debug.LogError("未绑定 CharacterActionAnimatorDriver。", this);
            return false;
        }

        if (directionDriver == null)
        {
            Debug.LogError("未绑定 DirectionalSpriteLibraryDriver。", this);
            return false;
        }

        controller.Configure(catalog, equipmentRenderer, animationController, directionDriver);
        return true;
    }

    bool EnsureEventSystem()
    {
        if (eventSystem == null)
        {
            Debug.LogError("未绑定工作台 EventSystem。请在场景里显式配置 EventSystem 引用。", this);
            return false;
        }

        if (inputModule == null)
        {
            Debug.LogError("未绑定工作台 InputSystemUIInputModule。请在场景里显式配置输入模块引用。", this);
            return false;
        }

        if (!eventSystem.isActiveAndEnabled)
        {
            Debug.LogError("工作台 EventSystem 未启用。", eventSystem);
            return false;
        }

        if (!inputModule.isActiveAndEnabled)
        {
            Debug.LogError("工作台 InputSystemUIInputModule 未启用。", inputModule);
            return false;
        }

        EventSystem.current = eventSystem;
        return true;
    }

    void EnsureRuntimeUi()
    {
        if (runtimeUi == null)
        {
            if (runtimeUiPrefab == null)
            {
                Debug.LogError(
                    "未绑定正式换装工作台 UI。请在 EquipmentWorkbenchBootstrap 上显式配置 runtimeUi 或 runtimeUiPrefab。",
                    this);
                return;
            }

            runtimeUi = Instantiate(runtimeUiPrefab);
            runtimeUi.name = "EquipmentWorkbenchUIRoot";
        }

        runtimeUi.Bind(controller, workbenchFont);
    }
}
