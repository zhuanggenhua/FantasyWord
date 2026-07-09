using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.UI;
using UnityEngine.Serialization;
using UnityEngine.UI;

/// <summary>
/// 场景启动入口：把 catalog、渲染器、动画控制器和预览 UI 绑定起来。
/// </summary>
[DisallowMultipleComponent]
public sealed class EquipmentWorkbenchBootstrap : MonoBehaviour
{
    static TMP_FontAsset _cachedSilverFont;

    [SerializeField]
    [FormerlySerializedAs("configuration")]
    EquipmentWorkbenchCatalog catalog;

    [SerializeField]
    EquipmentRenderer equipmentRenderer;

    [SerializeField]
    AnimationController animationController;

    [SerializeField]
    EquipmentWorkbenchController controller;

    [SerializeField]
    EquipmentWorkbenchRuntimeUI runtimeUi;

    [SerializeField]
    EquipmentWorkbenchRuntimeUI runtimeUiPrefab;

    const string DefaultWorkbenchUiResourcePath = "Art/UIPrefab/UIEquipmentWorkbench";

    public void SetCatalog(EquipmentWorkbenchCatalog newCatalog)
    {
        catalog = newCatalog;
    }

    void Reset()
    {
        equipmentRenderer = GetComponent<EquipmentRenderer>();
        animationController = GetComponent<AnimationController>();
        controller = GetComponent<EquipmentWorkbenchController>();
    }

    void Awake()
    {
        EnsureControllerBinding();
    }

    void OnEnable()
    {
        EnsureWorkbenchReady();
    }

    void Start()
    {
        EnsureWorkbenchReady();
    }

    public void EnsureWorkbenchReady()
    {
        EnsureControllerBinding();
        if (controller == null)
            return;

        controller.InitializeIfNeeded();
        EnsureEventSystem();
        EnsureRuntimeUi();
    }

    void EnsureControllerBinding()
    {
        if (equipmentRenderer == null)
            equipmentRenderer = GetComponent<EquipmentRenderer>();
        if (animationController == null)
            animationController = GetComponent<AnimationController>();
        if (controller == null)
            controller = GetComponent<EquipmentWorkbenchController>();
        if (controller == null)
            controller = gameObject.AddComponent<EquipmentWorkbenchController>();

        controller.Configure(catalog, equipmentRenderer, animationController);
    }

    void EnsureEventSystem()
    {
        EventSystem reusable = null;
        EventSystem[] existingEventSystems = FindObjectsByType<EventSystem>(
            FindObjectsInactive.Include,
            FindObjectsSortMode.None);
        for (int i = 0; i < existingEventSystems.Length; i++)
        {
            EventSystem existing = existingEventSystems[i];
            if (existing == null || !existing.gameObject.scene.IsValid())
                continue;

            bool temporaryWorkbenchEventSystem = existing.gameObject.name == "EquipmentWorkbenchEventSystem"
                && (existing.gameObject.hideFlags & HideFlags.DontSaveInEditor) != 0;
            if (temporaryWorkbenchEventSystem)
            {
                DestroyWorkbenchEventSystem(existing.gameObject);
                continue;
            }

            if (reusable == null)
                reusable = existing;
        }

        if (reusable != null)
        {
            EnsureInputModule(reusable);
            EventSystem.current = reusable;
            return;
        }

        if (EventSystem.current != null)
            return;

        GameObject eventSystemGo = new GameObject("EquipmentWorkbenchEventSystem");
        eventSystemGo.hideFlags = HideFlags.DontSaveInEditor;
        eventSystemGo.AddComponent<EventSystem>();
        eventSystemGo.AddComponent<InputSystemUIInputModule>();
    }

    static void EnsureInputModule(EventSystem eventSystem)
    {
        if (eventSystem == null || eventSystem.GetComponent<BaseInputModule>() != null)
            return;

        eventSystem.gameObject.AddComponent<InputSystemUIInputModule>();
    }

    static void DestroyWorkbenchEventSystem(GameObject eventSystemGo)
    {
        if (eventSystemGo == null)
            return;

        if (Application.isPlaying)
            Destroy(eventSystemGo);
        else
            DestroyImmediate(eventSystemGo);
    }

    void EnsureRuntimeUi()
    {
        if (runtimeUi == null)
            runtimeUi = FindFirstObjectByType<EquipmentWorkbenchRuntimeUI>();

        if (runtimeUi == null)
        {
            EquipmentWorkbenchRuntimeUI prefab = runtimeUiPrefab != null
                ? runtimeUiPrefab
                : Resources.Load<EquipmentWorkbenchRuntimeUI>(DefaultWorkbenchUiResourcePath);

            if (prefab == null)
            {
                Debug.LogError(
                    $"未找到正式换装工作台 UI 预制体。请检查 {DefaultWorkbenchUiResourcePath}.prefab 或场景显式绑定。",
                    this);
                return;
            }

            runtimeUi = Instantiate(prefab);
            runtimeUi.name = "EquipmentWorkbenchUIRoot";
        }

        runtimeUi.Bind(controller, ResolveFont());
    }

    static TMP_FontAsset ResolveFont()
    {
        TMP_FontAsset silver = Resources.Load<TMP_FontAsset>("Fonts/Silver SDF");
        if (silver != null)
            return silver;

        if (_cachedSilverFont != null)
            return _cachedSilverFont;

        Font silverFont = Resources.Load<Font>("Fonts/Silver");
        if (silverFont != null)
        {
            _cachedSilverFont = TMP_FontAsset.CreateFontAsset(silverFont);
            return _cachedSilverFont;
        }

        if (TMP_Settings.defaultFontAsset != null)
            return TMP_Settings.defaultFontAsset;

        return Resources.Load<TMP_FontAsset>("Fonts & Materials/LiberationSans SDF");
    }
}
