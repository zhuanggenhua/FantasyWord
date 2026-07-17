#nullable enable

using System;
using System.IO;
using FantasyWord.Presentation;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using UnityEngine.Tilemaps;

namespace FantasyWord.EditorTools
{
    /// <summary>
    /// ClickMoveTest 水面倒影的一次性确定性接线入口。
    /// 只处理已锁定的正式场景对象，不进入运行时依赖查找链路。
    /// </summary>
    public static class ClickMoveTestWaterReflectionInstaller
    {
        private const string ScenePath = "Assets/Scenes/ClickMoveTest.unity";
        private const string WaterTilemapName = "河流与湖泊";
        private const string PlayerName = "玩家角色";
        private const string MainCameraName = "Main Camera";
        private const string SystemName = "Water Reflection System";
        private const string CaptureCameraName = "Water Reflection Capture Camera";
        private const string ReflectionAnchorName = "Water Reflection Anchor";
        private const string ProxyLayerName = "WaterReflectionProxy";
        private const string ProxyMaterialPath =
            "Assets/Settings/WaterReflection/WaterReflectionProxy2D.mat";
        private const string WaterMaterialPath =
            "Assets/Settings/WaterReflection/WaterReflectionTilemap.mat";
        private const string ResultRelativePath =
            "Temp/UnityBridge/results/clickmove-water-reflection-install.json";

        [MenuItem("Tools/FantasyWord/Water Reflection/Install ClickMoveTest")]
        public static void InstallFromMenu()
        {
            Install();
        }

        public static string Install()
        {
            InstallResult result = new();
            Undo.IncrementCurrentGroup();
            int undoGroup = Undo.GetCurrentGroup();
            Undo.SetCurrentGroupName("安装 ClickMoveTest 水面倒影");
            try
            {
                Scene scene = RequireTargetScene();
                Tilemap waterTilemap = FindSceneComponent<Tilemap>(scene, WaterTilemapName)
                    ?? throw new InvalidOperationException($"场景缺少水面 Tilemap：{WaterTilemapName}");
                TilemapRenderer waterRenderer = waterTilemap.GetComponent<TilemapRenderer>()
                    ?? throw new InvalidOperationException($"{WaterTilemapName} 缺少 TilemapRenderer。");
                GameObject player = FindSceneGameObject(scene, PlayerName)
                    ?? throw new InvalidOperationException($"场景缺少玩家根对象：{PlayerName}");
                Camera mainCamera = FindSceneComponent<Camera>(scene, MainCameraName)
                    ?? throw new InvalidOperationException($"场景缺少主相机：{MainCameraName}");

                Material proxyMaterial = AssetDatabase.LoadAssetAtPath<Material>(ProxyMaterialPath)
                    ?? throw new InvalidOperationException($"缺少倒影代理材质：{ProxyMaterialPath}");
                Material waterMaterial = AssetDatabase.LoadAssetAtPath<Material>(WaterMaterialPath)
                    ?? throw new InvalidOperationException($"缺少水面倒影材质：{WaterMaterialPath}");
                int proxyLayer = LayerMask.NameToLayer(ProxyLayerName);
                if (proxyLayer < 0)
                {
                    throw new InvalidOperationException($"缺少 Unity Layer：{ProxyLayerName}");
                }

                GameObject systemObject = FindSceneGameObject(scene, SystemName) ?? CreateRoot(SystemName, scene);
                Camera captureCamera = ResolveCaptureCamera(systemObject);
                WaterReflectionSystem system = GetOrAddComponent<WaterReflectionSystem>(
                    systemObject,
                    "添加水面倒影系统");

                ConfigureCaptureCamera(captureCamera, proxyLayer);
                ConfigureSystem(system, captureCamera, proxyMaterial, waterRenderer);
                ConfigureWaterRenderer(waterRenderer, waterMaterial);
                ConfigureMainCamera(mainCamera, proxyLayer);

                WaterReflectionCaster2D playerCaster = ConfigurePlayerCaster(player);
                SpriteRenderer treeRenderer = SelectTreeCasterSource(scene, waterTilemap, player.transform.position)
                    ?? throw new InvalidOperationException("没有找到倒影投影落入水格的近岸 Tree SpriteRenderer。");
                WaterReflectionCaster2D treeCaster = ConfigureTreeCaster(treeRenderer);

                EditorSceneManager.MarkSceneDirty(scene);
                if (!EditorSceneManager.SaveScene(scene))
                {
                    throw new InvalidOperationException("保存 ClickMoveTest 水面倒影接线失败。");
                }

                result.Success = true;
                result.ScenePath = scene.path;
                result.WaterPath = GetHierarchyPath(waterTilemap.transform);
                result.PlayerPath = GetHierarchyPath(player.transform);
                result.TreePath = GetHierarchyPath(treeRenderer.transform);
                result.SystemPath = GetHierarchyPath(system.transform);
                result.CaptureCameraPath = GetHierarchyPath(captureCamera.transform);
                result.ProxyLayer = proxyLayer;
                result.CaptureRendererIndex = 1;
                result.PlayerCasterConfigured = playerCaster != null;
                result.TreeCasterConfigured = treeCaster != null;
                result.MainCameraExcludesProxy = (mainCamera.cullingMask & (1 << proxyLayer)) == 0;
                result.WaterMaterialConfigured = waterRenderer.sharedMaterial == waterMaterial;
                result.Message = "ClickMoveTest 水面倒影场景接线完成。";
                Undo.CollapseUndoOperations(undoGroup);
            }
            catch (Exception exception)
            {
                Undo.RevertAllDownToGroup(undoGroup);
                result.Success = false;
                result.Message = exception.ToString();
            }

            string resultPath = Path.GetFullPath(ResultRelativePath);
            Directory.CreateDirectory(Path.GetDirectoryName(resultPath)!);
            File.WriteAllText(resultPath, JsonUtility.ToJson(result, true));
            return resultPath;
        }

        public static string Inspect()
        {
            Scene scene = RequireTargetScene();
            Tilemap? waterTilemap = FindSceneComponent<Tilemap>(scene, WaterTilemapName);
            Camera? mainCamera = FindSceneComponent<Camera>(scene, MainCameraName);
            GameObject? player = FindSceneGameObject(scene, PlayerName);
            WaterReflectionSystem? system = FindSceneComponent<WaterReflectionSystem>(scene, SystemName);
            int proxyLayer = LayerMask.NameToLayer(ProxyLayerName);

            InspectResult result = new()
            {
                ScenePath = scene.path,
                SceneDirty = scene.isDirty,
                ProxyLayer = proxyLayer,
                HasWaterTilemap = waterTilemap != null,
                HasWaterMaterial = waterTilemap != null &&
                    waterTilemap.GetComponent<TilemapRenderer>()?.sharedMaterial?.shader?.name ==
                    "FantasyWord/Water Reflection Tilemap",
                HasSystem = system != null,
                HasCaptureCamera = system != null &&
                    system.GetComponentInChildren<Camera>(true) != null,
                PlayerHasCaster = player != null && player.GetComponent<WaterReflectionCaster2D>() != null,
                CasterCount = CountSceneComponents<WaterReflectionCaster2D>(scene),
                MainCameraExcludesProxy = mainCamera != null && proxyLayer >= 0 &&
                    (mainCamera.cullingMask & (1 << proxyLayer)) == 0
            };
            return JsonUtility.ToJson(result, true);
        }

        private static Scene RequireTargetScene()
        {
            Scene scene = SceneManager.GetActiveScene();
            if (!scene.IsValid() || !scene.isLoaded || scene.path != ScenePath)
            {
                throw new InvalidOperationException($"必须先打开目标场景：{ScenePath}");
            }

            return scene;
        }

        private static GameObject CreateRoot(string name, Scene scene)
        {
            GameObject created = new(name);
            Undo.RegisterCreatedObjectUndo(created, $"创建{name}");
            SceneManager.MoveGameObjectToScene(created, scene);
            return created;
        }

        private static Camera ResolveCaptureCamera(GameObject systemObject)
        {
            Transform? existing = systemObject.transform.Find(CaptureCameraName);
            GameObject cameraObject;
            if (existing != null)
            {
                cameraObject = existing.gameObject;
            }
            else
            {
                cameraObject = new GameObject(CaptureCameraName);
                Undo.RegisterCreatedObjectUndo(cameraObject, "创建水面倒影捕获相机");
                cameraObject.transform.SetParent(systemObject.transform, false);
            }

            Camera? camera = cameraObject.GetComponent<Camera>();
            if (camera == null)
            {
                camera = cameraObject.AddComponent<Camera>();
                Undo.RegisterCreatedObjectUndo(camera, "添加水面倒影 Camera 组件");
            }

            return camera;
        }

        private static void ConfigureCaptureCamera(Camera camera, int proxyLayer)
        {
            Undo.RecordObject(camera, "配置水面倒影捕获相机");
            camera.enabled = false;
            camera.orthographic = true;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = Color.clear;
            camera.cullingMask = 1 << proxyLayer;
            camera.allowHDR = false;
            camera.allowMSAA = false;
            camera.allowDynamicResolution = false;
            camera.useOcclusionCulling = false;

            UniversalAdditionalCameraData cameraData = camera.GetUniversalAdditionalCameraData();
            Undo.RecordObject(cameraData, "配置水面倒影 Renderer2D");
            cameraData.renderPostProcessing = false;
            cameraData.SetRenderer(1);
            EditorUtility.SetDirty(cameraData);
        }

        private static void ConfigureSystem(
            WaterReflectionSystem system,
            Camera captureCamera,
            Material proxyMaterial,
            TilemapRenderer waterRenderer)
        {
            Undo.RecordObject(system, "配置水面倒影系统");
            SerializedObject serialized = new(system);
            SetObject(serialized, "m_captureCamera", captureCamera);
            SetInt(serialized, "m_captureRendererIndex", 1);
            SetObject(serialized, "m_defaultProxyMaterial", proxyMaterial);
            SetString(serialized, "m_proxyLayerName", ProxyLayerName);
            SerializedProperty waterRenderers = serialized.FindProperty("m_waterRenderers")
                ?? throw new InvalidOperationException("WaterReflectionSystem 缺少 m_waterRenderers 字段。");
            waterRenderers.arraySize = 1;
            waterRenderers.GetArrayElementAtIndex(0).objectReferenceValue = waterRenderer;
            serialized.ApplyModifiedProperties();
            EditorUtility.SetDirty(system);
        }

        private static void ConfigureWaterRenderer(TilemapRenderer renderer, Material material)
        {
            Undo.RecordObject(renderer, "绑定水面倒影材质");
            renderer.sharedMaterial = material;
            EditorUtility.SetDirty(renderer);
        }

        private static void ConfigureMainCamera(Camera camera, int proxyLayer)
        {
            Undo.RecordObject(camera, "主相机排除倒影代理层");
            camera.cullingMask &= ~(1 << proxyLayer);
            EditorUtility.SetDirty(camera);
        }

        private static WaterReflectionCaster2D ConfigurePlayerCaster(GameObject player)
        {
            WaterReflectionCaster2D caster = GetOrAddComponent<WaterReflectionCaster2D>(
                player,
                "添加玩家水面倒影");
            EquipmentRenderer equipmentRenderer = player.GetComponentInChildren<EquipmentRenderer>(true)
                ?? throw new InvalidOperationException("玩家缺少 EquipmentRenderer，不能生成完整换装倒影。");
            SpriteRenderer bodyRenderer = equipmentRenderer.GetComponent<SpriteRenderer>()
                ?? throw new InvalidOperationException("玩家 EquipmentRenderer 缺少主体 SpriteRenderer，不能定位脚底倒影锚点。");
            Transform reflectionAnchor = ConfigureReflectionAnchor(player.transform, bodyRenderer);
            Undo.RecordObject(caster, "配置玩家水面倒影");
            SerializedObject serialized = new(caster);
            SetObject(serialized, "m_equipmentRenderer", equipmentRenderer);
            SetObject(serialized, "m_reflectionAnchor", reflectionAnchor);
            SetBool(serialized, "m_disableWhileSwimming", true);
            serialized.ApplyModifiedProperties();
            EditorUtility.SetDirty(caster);
            return caster;
        }

        private static WaterReflectionCaster2D ConfigureTreeCaster(SpriteRenderer source)
        {
            WaterReflectionCaster2D caster = GetOrAddComponent<WaterReflectionCaster2D>(
                source.gameObject,
                "添加近岸树木水面倒影");
            Transform reflectionAnchor = ConfigureReflectionAnchor(source.transform, source);
            Undo.RecordObject(caster, "配置近岸树木水面倒影");
            SerializedObject serialized = new(caster);
            SetObject(serialized, "m_reflectionAnchor", reflectionAnchor);
            SerializedProperty sources = serialized.FindProperty("m_sourceRenderers")
                ?? throw new InvalidOperationException("WaterReflectionCaster2D 缺少 m_sourceRenderers 字段。");
            sources.arraySize = 1;
            sources.GetArrayElementAtIndex(0).objectReferenceValue = source;
            serialized.ApplyModifiedProperties();
            EditorUtility.SetDirty(caster);
            return caster;
        }

        private static Transform ConfigureReflectionAnchor(Transform owner, SpriteRenderer source)
        {
            Transform? existing = owner.Find(ReflectionAnchorName);
            Transform anchor;
            if (existing != null)
            {
                anchor = existing;
                Undo.RecordObject(anchor, "更新水面倒影脚底锚点");
            }
            else
            {
                GameObject anchorObject = new(ReflectionAnchorName);
                Undo.RegisterCreatedObjectUndo(anchorObject, "创建水面倒影脚底锚点");
                anchorObject.transform.SetParent(owner, false);
                anchor = anchorObject.transform;
            }

            Vector3 worldAnchor = new(source.bounds.center.x, source.bounds.min.y, owner.position.z);
            anchor.localPosition = owner.InverseTransformPoint(worldAnchor);
            anchor.localRotation = Quaternion.identity;
            anchor.localScale = Vector3.one;
            EditorUtility.SetDirty(anchor);
            return anchor;
        }

        private static SpriteRenderer? SelectTreeCasterSource(
            Scene scene,
            Tilemap waterTilemap,
            Vector3 playerPosition)
        {
            SpriteRenderer? best = null;
            float bestDistance = float.PositiveInfinity;
            foreach (GameObject root in scene.GetRootGameObjects())
            {
                foreach (SpriteRenderer renderer in root.GetComponentsInChildren<SpriteRenderer>(true))
                {
                    if (!renderer.enabled || renderer.sprite == null ||
                        !BelongsToTreeHierarchy(renderer.transform))
                    {
                        continue;
                    }

                    float reflectionDepth = Mathf.Max(0.25f, renderer.bounds.size.y * 0.45f);
                    Vector3 reflectedCenter = renderer.transform.position + Vector3.down * reflectionDepth;
                    float waterDistance = DistanceToNearestWaterTileSq(waterTilemap, reflectedCenter);
                    float playerDistance = (renderer.transform.position - playerPosition).sqrMagnitude;
                    float score = waterDistance * 100f + playerDistance;
                    if (score < bestDistance)
                    {
                        best = renderer;
                        bestDistance = score;
                    }
                }
            }

            return best;
        }

        private static bool BelongsToTreeHierarchy(Transform transform)
        {
            for (Transform? current = transform; current != null; current = current.parent)
            {
                if (current.name.StartsWith("Tree", StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }

            return false;
        }

        private static float DistanceToNearestWaterTileSq(Tilemap waterTilemap, Vector3 worldPosition)
        {
            float best = float.PositiveInfinity;
            foreach (Vector3Int cell in waterTilemap.cellBounds.allPositionsWithin)
            {
                if (!waterTilemap.HasTile(cell))
                {
                    continue;
                }

                Vector3 center = waterTilemap.GetCellCenterWorld(cell);
                float distance = (new Vector2(center.x, center.y) -
                    new Vector2(worldPosition.x, worldPosition.y)).sqrMagnitude;
                if (distance < best)
                {
                    best = distance;
                }
            }

            return best;
        }

        private static GameObject? FindSceneGameObject(Scene scene, string name)
        {
            foreach (GameObject root in scene.GetRootGameObjects())
            {
                foreach (Transform transform in root.GetComponentsInChildren<Transform>(true))
                {
                    if (transform.name == name)
                    {
                        return transform.gameObject;
                    }
                }
            }

            return null;
        }

        private static T? FindSceneComponent<T>(Scene scene, string gameObjectName)
            where T : Component
        {
            return FindSceneGameObject(scene, gameObjectName)?.GetComponent<T>();
        }

        private static int CountSceneComponents<T>(Scene scene) where T : Component
        {
            int count = 0;
            foreach (GameObject root in scene.GetRootGameObjects())
            {
                count += root.GetComponentsInChildren<T>(true).Length;
            }

            return count;
        }

        private static T GetOrAddComponent<T>(GameObject gameObject, string undoName)
            where T : Component
        {
            T? component = gameObject.GetComponent<T>();
            if (component != null)
            {
                return component;
            }

            component = gameObject.AddComponent<T>();
            Undo.RegisterCreatedObjectUndo(component, undoName);
            return component;
        }

        private static string GetHierarchyPath(Transform transform)
        {
            string path = transform.name;
            while (transform.parent != null)
            {
                transform = transform.parent;
                path = transform.name + "/" + path;
            }

            return path;
        }

        private static void SetObject(SerializedObject serialized, string name, UnityEngine.Object value)
        {
            SerializedProperty property = serialized.FindProperty(name)
                ?? throw new InvalidOperationException($"{serialized.targetObject.GetType().Name} 缺少字段 {name}。");
            property.objectReferenceValue = value;
        }

        private static void SetInt(SerializedObject serialized, string name, int value)
        {
            SerializedProperty property = serialized.FindProperty(name)
                ?? throw new InvalidOperationException($"{serialized.targetObject.GetType().Name} 缺少字段 {name}。");
            property.intValue = value;
        }

        private static void SetString(SerializedObject serialized, string name, string value)
        {
            SerializedProperty property = serialized.FindProperty(name)
                ?? throw new InvalidOperationException($"{serialized.targetObject.GetType().Name} 缺少字段 {name}。");
            property.stringValue = value;
        }

        private static void SetBool(SerializedObject serialized, string name, bool value)
        {
            SerializedProperty property = serialized.FindProperty(name)
                ?? throw new InvalidOperationException($"{serialized.targetObject.GetType().Name} 缺少字段 {name}。");
            property.boolValue = value;
        }

        [Serializable]
        private sealed class InstallResult
        {
            public bool Success;
            public string ScenePath = string.Empty;
            public string WaterPath = string.Empty;
            public string PlayerPath = string.Empty;
            public string TreePath = string.Empty;
            public string SystemPath = string.Empty;
            public string CaptureCameraPath = string.Empty;
            public int ProxyLayer = -1;
            public int CaptureRendererIndex = -1;
            public bool PlayerCasterConfigured;
            public bool TreeCasterConfigured;
            public bool MainCameraExcludesProxy;
            public bool WaterMaterialConfigured;
            public string Message = string.Empty;
        }

        [Serializable]
        private sealed class InspectResult
        {
            public string ScenePath = string.Empty;
            public bool SceneDirty;
            public int ProxyLayer = -1;
            public bool HasWaterTilemap;
            public bool HasWaterMaterial;
            public bool HasSystem;
            public bool HasCaptureCamera;
            public bool PlayerHasCaster;
            public int CasterCount;
            public bool MainCameraExcludesProxy;
        }
    }
}
