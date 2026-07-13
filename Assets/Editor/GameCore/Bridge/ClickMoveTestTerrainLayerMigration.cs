#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.Tilemaps;

namespace FantasyWord.GameCore
{
    public static class ClickMoveTestTerrainLayerMigration
    {
        private const string ScenePath = "Assets/Scenes/ClickMoveTest.unity";
        private const string SourceScenePath =
            "Assets/Art/KrishnaPalacio/MINIFANTASY - Forgotten Plains/Scenes/Demo - Forgotten Plains (Rule + Animated Tiles).unity";
        private const string GridName = "地形Grid";
        private const string SourceGridName = "Grid";
        private const string SourceGroundLayerName = "Ground";
        private const string SourceDetailLayerName = "GroundDecoration";
        private const string BaseLayerName = "基础地面";
        private const string LegacyDetailLayerName = "地表装饰";
        private const string DetailLayerName = "地表细节";
        private const string CoverLayerName = "地表覆盖";
        private const string RuleLayerName = "地形规则";
        private const string LowlandGrassRuleTileName = "地形规则_低地草地";
        private const string DirtTileName = "Dirt";
        private const string LegacyGrassTileName = "Grass";
        private const string OriginalLowlandVisualTileName =
            "Cliff5_Minifantasy_ForgottenPlainsTiles_239";
        private const string ResultRelativePath =
            "Temp/UnityBridge/results/clickmove-terrain-layer-migration.json";

        public static string ResultPath => Path.GetFullPath(ResultRelativePath);

        [MenuItem("Tools/FantasyWord/Migration/Migrate ClickMoveTest Terrain Layers")]
        public static void MigrateFromMenu()
        {
            Migrate();
        }

        public static string Migrate()
        {
            MigrationResult result = new();
            Scene sourceScene = default;
            bool closeSourceScene = false;
            try
            {
                Scene scene = SceneManager.GetActiveScene();
                result.ScenePath = scene.path;
                if (!scene.IsValid() || !scene.isLoaded || scene.path != ScenePath)
                {
                    throw new InvalidOperationException($"必须先打开目标场景：{ScenePath}");
                }

                Grid grid = FindSceneComponent<Grid>(scene, GridName)
                    ?? throw new InvalidOperationException($"场景缺少 Grid：{GridName}");
                Dictionary<string, Tilemap> tilemaps = CollectChildTilemaps(grid);
                Tilemap baseLayer = RequireTilemap(tilemaps, BaseLayerName);
                Tilemap ruleLayer = RequireTilemap(tilemaps, RuleLayerName);
                Tilemap detailLayer = ResolveDetailLayer(tilemaps);
                Tilemap coverLayer = ResolveOrCreateCoverLayer(grid, tilemaps, detailLayer, result);

                sourceScene = SceneManager.GetSceneByPath(SourceScenePath);
                if (!sourceScene.IsValid() || !sourceScene.isLoaded)
                {
                    sourceScene = EditorSceneManager.OpenScene(SourceScenePath, OpenSceneMode.Additive);
                    closeSourceScene = true;
                }

                Grid sourceGrid = FindSceneComponent<Grid>(sourceScene, SourceGridName)
                    ?? throw new InvalidOperationException($"来源场景缺少 Grid：{SourceGridName}");
                Dictionary<string, Tilemap> sourceTilemaps = CollectChildTilemaps(sourceGrid);
                Tilemap sourceGroundLayer = RequireTilemap(
                    sourceTilemaps,
                    SourceGroundLayerName,
                    SourceGridName);
                Tilemap sourceDetailLayer = RequireTilemap(
                    sourceTilemaps,
                    SourceDetailLayerName,
                    SourceGridName);

                TileBase dirtTile = FindTileByName(sourceGroundLayer, DirtTileName)
                    ?? throw new InvalidOperationException($"{BaseLayerName} 缺少现有 Dirt Tile。不能自动创建素材。");
                TileBase originalLowlandVisualTile =
                    FindTileByName(sourceGroundLayer, OriginalLowlandVisualTileName) ??
                    throw new InvalidOperationException(
                        $"场景缺少原低地草坪 Tile：{OriginalLowlandVisualTileName}。不能用其它 Tile 替换原地图视觉。");
                TileBase? legacyGrassTile =
                    FindTileByName(detailLayer, LegacyGrassTileName) ??
                    FindTileByName(coverLayer, LegacyGrassTileName);

                Undo.RegisterCompleteObjectUndo(baseLayer, "迁移低地 Dirt 底层");
                Undo.RegisterCompleteObjectUndo(detailLayer, "恢复来源场景地表装饰");
                Undo.RegisterCompleteObjectUndo(coverLayer, "迁移低地 Grass 覆盖");

                if (detailLayer.name != LegacyDetailLayerName)
                {
                    Undo.RecordObject(detailLayer.gameObject, "恢复地表装饰层名称");
                    detailLayer.gameObject.name = LegacyDetailLayerName;
                }

                TilemapRenderer detailRenderer = detailLayer.GetComponent<TilemapRenderer>();
                if (detailRenderer != null)
                {
                    Undo.RecordObject(detailRenderer, "恢复地表装饰排序");
                    detailRenderer.sortingOrder = -8;
                }

                TilemapRenderer coverRenderer = coverLayer.GetComponent<TilemapRenderer>();
                if (coverRenderer != null)
                {
                    Undo.RecordObject(coverRenderer, "调整地表覆盖排序");
                    coverRenderer.sortingOrder = -9;
                }

                baseLayer.ClearAllTiles();
                coverLayer.ClearAllTiles();
                CopyTilemapCells(sourceDetailLayer, detailLayer);

                foreach (Vector3Int cell in sourceGroundLayer.cellBounds.allPositionsWithin)
                {
                    TileBase sourceTile = sourceGroundLayer.GetTile(cell);
                    if (sourceTile == null)
                    {
                        continue;
                    }

                    TileBase ruleTile = ruleLayer.GetTile(cell);
                    bool isLowlandRule =
                        ruleTile != null &&
                        ruleTile.name == LowlandGrassRuleTileName;
                    if (isLowlandRule && sourceTile == originalLowlandVisualTile)
                    {
                        baseLayer.SetTile(cell, dirtTile);
                        coverLayer.SetTile(cell, sourceTile);
                        CopyCellPresentation(sourceGroundLayer, coverLayer, cell);
                    }
                    else
                    {
                        baseLayer.SetTile(cell, sourceTile);
                        CopyCellPresentation(sourceGroundLayer, baseLayer, cell);
                    }

                    if (isLowlandRule)
                    {
                        result.LowlandLayeredCellCount++;
                    }
                }

                TerrainNavigationMap navigationMap = FindSceneComponent<TerrainNavigationMap>(scene)
                    ?? throw new InvalidOperationException("场景缺少 TerrainNavigationMap。");
                TerrainSurfacePresentation presentation = FindSceneComponent<TerrainSurfacePresentation>(scene)
                    ?? throw new InvalidOperationException("场景缺少 TerrainSurfacePresentation。");
                AssignTilemapReference(navigationMap, "m_surfaceCoverTilemap", coverLayer);
                AssignTilemapReference(presentation, "m_surfaceCoverTilemap", coverLayer);
                AssignGrassCoverMapping(navigationMap, originalLowlandVisualTile, legacyGrassTile);

                baseLayer.CompressBounds();
                detailLayer.CompressBounds();
                coverLayer.CompressBounds();
                result.SourceScenePath = SourceScenePath;
                result.SourceVisibleGroundMismatchCount = CountVisibleGroundMismatches(
                    sourceGroundLayer,
                    baseLayer,
                    coverLayer);
                result.SourceDetailMismatchCount = CountTilemapCellMismatches(
                    sourceDetailLayer,
                    detailLayer);
                result.SourceDetailOccupiedCellCount = CountOccupiedCells(sourceDetailLayer);
                result.DetailOccupiedCellCount = CountOccupiedCells(detailLayer);
                if (result.SourceVisibleGroundMismatchCount != 0 ||
                    result.SourceDetailMismatchCount != 0)
                {
                    throw new InvalidOperationException(
                        $"来源地图逐格恢复不完整：Ground 差异 {result.SourceVisibleGroundMismatchCount}，" +
                        $"GroundDecoration 差异 {result.SourceDetailMismatchCount}。");
                }

                EditorUtility.SetDirty(baseLayer);
                EditorUtility.SetDirty(detailLayer);
                EditorUtility.SetDirty(coverLayer);
                EditorSceneManager.MarkSceneDirty(scene);
                if (!EditorSceneManager.SaveScene(scene))
                {
                    throw new InvalidOperationException("保存 ClickMoveTest 场景失败。");
                }

                result.BaseDirtCellCount = CountTileByName(baseLayer, DirtTileName);
                result.CoverGrassCellCount = CountTile(coverLayer, originalLowlandVisualTile);
                CountLowlandLayerContract(
                    ruleLayer,
                    baseLayer,
                    coverLayer,
                    originalLowlandVisualTile,
                    out result.LowlandRuleCellCount,
                    out result.LowlandDirtCellCount,
                    out result.LowlandGrassCoverCellCount,
                    out result.LowlandBareDirtCellCount);
                result.RemainingGrassInDetailCellCount = CountTileByName(detailLayer, LegacyGrassTileName);
                result.LowlandVisualTileName = originalLowlandVisualTile.name;
                result.NavigationMapUsesCoverLayer = ReadTilemapReference(
                    navigationMap,
                    "m_surfaceCoverTilemap") == coverLayer;
                result.PresentationUsesCoverLayer = ReadTilemapReference(
                    presentation,
                    "m_surfaceCoverTilemap") == coverLayer;
                result.Success = result.LowlandRuleCellCount > 0 &&
                    result.LowlandDirtCellCount == result.LowlandRuleCellCount &&
                    result.LowlandGrassCoverCellCount > 0 &&
                    result.LowlandBareDirtCellCount > 0 &&
                    result.LowlandGrassCoverCellCount + result.LowlandBareDirtCellCount ==
                        result.LowlandRuleCellCount &&
                    result.SourceVisibleGroundMismatchCount == 0 &&
                    result.SourceDetailMismatchCount == 0 &&
                    result.NavigationMapUsesCoverLayer &&
                    result.PresentationUsesCoverLayer;
                result.Message = result.Success
                    ? "ClickMoveTest 低地已拆为 Dirt 底层 + 原视觉 Tile 覆盖层。"
                    : "迁移已执行，但全图计数或正式引用未满足合同。";
            }
            catch (Exception exception)
            {
                result.Success = false;
                result.Message = exception.ToString();
            }
            finally
            {
                if (closeSourceScene && sourceScene.IsValid() && sourceScene.isLoaded)
                {
                    EditorSceneManager.CloseScene(sourceScene, true);
                }
            }

            Directory.CreateDirectory(Path.GetDirectoryName(ResultPath)!);
            File.WriteAllText(ResultPath, JsonUtility.ToJson(result, true));
            return ResultPath;
        }

        private static Tilemap ResolveDetailLayer(Dictionary<string, Tilemap> tilemaps)
        {
            if (tilemaps.TryGetValue(DetailLayerName, out Tilemap detailLayer))
            {
                return detailLayer;
            }

            return RequireTilemap(tilemaps, LegacyDetailLayerName);
        }

        private static Tilemap ResolveOrCreateCoverLayer(
            Grid grid,
            Dictionary<string, Tilemap> tilemaps,
            Tilemap detailLayer,
            MigrationResult result)
        {
            if (tilemaps.TryGetValue(CoverLayerName, out Tilemap existing))
            {
                return existing;
            }

            GameObject coverObject = new(CoverLayerName);
            Undo.RegisterCreatedObjectUndo(coverObject, "创建地表覆盖层");
            coverObject.transform.SetParent(grid.transform, false);
            Tilemap coverLayer = Undo.AddComponent<Tilemap>(coverObject);
            TilemapRenderer coverRenderer = Undo.AddComponent<TilemapRenderer>(coverObject);
            TilemapRenderer detailRenderer = detailLayer.GetComponent<TilemapRenderer>();
            if (detailRenderer != null)
            {
                coverRenderer.sortingLayerID = detailRenderer.sortingLayerID;
                coverRenderer.mode = detailRenderer.mode;
                coverRenderer.detectChunkCullingBounds = detailRenderer.detectChunkCullingBounds;
            }

            coverRenderer.sortingOrder = -9;
            result.CoverLayerCreated = true;
            return coverLayer;
        }

        private static void AssignTilemapReference(UnityEngine.Object target, string propertyName, Tilemap value)
        {
            SerializedObject serialized = new(target);
            SerializedProperty property = serialized.FindProperty(propertyName)
                ?? throw new InvalidOperationException($"{target.GetType().Name} 缺少字段 {propertyName}。");
            property.objectReferenceValue = value;
            serialized.ApplyModifiedPropertiesWithoutUndo();
            EditorUtility.SetDirty(target);
        }

        private static void AssignGrassCoverMapping(
            TerrainNavigationMap navigationMap,
            TileBase originalLowlandVisualTile,
            TileBase? legacyGrassTile)
        {
            SerializedObject serialized = new(navigationMap);
            SerializedProperty mappings = serialized.FindProperty("m_surfaceCoverTileMappings")
                ?? throw new InvalidOperationException(
                    "TerrainNavigationMap 缺少上层地表 Tile 映射字段。");
            SerializedProperty? targetMapping = null;
            for (int i = 0; i < mappings.arraySize; i++)
            {
                SerializedProperty mapping = mappings.GetArrayElementAtIndex(i);
                UnityEngine.Object tile = mapping.FindPropertyRelative("m_tile").objectReferenceValue;
                if (tile == originalLowlandVisualTile || tile == legacyGrassTile)
                {
                    targetMapping = mapping;
                    break;
                }
            }

            if (targetMapping == null)
            {
                int index = mappings.arraySize;
                mappings.InsertArrayElementAtIndex(index);
                targetMapping = mappings.GetArrayElementAtIndex(index);
            }

            targetMapping.FindPropertyRelative("m_tile").objectReferenceValue = originalLowlandVisualTile;
            targetMapping.FindPropertyRelative("m_coverKind").enumValueIndex =
                (int)ETerrainSurfaceCoverKind.Grass;
            targetMapping.FindPropertyRelative("m_traits").intValue =
                (int)(ETerrainSurfaceCoverTraits.Flammable |
                    ETerrainSurfaceCoverTraits.Destructible |
                    ETerrainSurfaceCoverTraits.Regrowable);
            serialized.ApplyModifiedPropertiesWithoutUndo();
            EditorUtility.SetDirty(navigationMap);
        }

        private static Tilemap? ReadTilemapReference(UnityEngine.Object target, string propertyName)
        {
            SerializedObject serialized = new(target);
            return serialized.FindProperty(propertyName)?.objectReferenceValue as Tilemap;
        }

        private static Dictionary<string, Tilemap> CollectChildTilemaps(Grid grid)
        {
            Dictionary<string, Tilemap> result = new(StringComparer.Ordinal);
            foreach (Tilemap tilemap in grid.GetComponentsInChildren<Tilemap>(true))
            {
                result[tilemap.name] = tilemap;
            }

            return result;
        }

        private static Tilemap RequireTilemap(
            Dictionary<string, Tilemap> tilemaps,
            string name,
            string ownerName = GridName)
        {
            return tilemaps.TryGetValue(name, out Tilemap tilemap)
                ? tilemap
                : throw new InvalidOperationException($"{ownerName} 缺少 Tilemap：{name}");
        }

        private static void CopyTilemapCells(Tilemap source, Tilemap target)
        {
            target.ClearAllTiles();
            foreach (Vector3Int cell in source.cellBounds.allPositionsWithin)
            {
                TileBase tile = source.GetTile(cell);
                if (tile == null)
                {
                    continue;
                }

                target.SetTile(cell, tile);
                CopyCellPresentation(source, target, cell);
            }
        }

        private static void CopyCellPresentation(Tilemap source, Tilemap target, Vector3Int cell)
        {
            target.SetTileFlags(cell, TileFlags.None);
            target.SetTransformMatrix(cell, source.GetTransformMatrix(cell));
            target.SetColor(cell, source.GetColor(cell));
            target.SetTileFlags(cell, source.GetTileFlags(cell));
        }

        private static int CountVisibleGroundMismatches(
            Tilemap sourceGround,
            Tilemap baseLayer,
            Tilemap coverLayer)
        {
            int mismatches = 0;
            foreach (Vector3Int cell in sourceGround.cellBounds.allPositionsWithin)
            {
                TileBase expected = sourceGround.GetTile(cell);
                Tilemap actualLayer = coverLayer.GetTile(cell) != null
                    ? coverLayer
                    : baseLayer;
                TileBase actual = actualLayer.GetTile(cell);
                if (actual != expected ||
                    actualLayer.GetTransformMatrix(cell) != sourceGround.GetTransformMatrix(cell) ||
                    actualLayer.GetColor(cell) != sourceGround.GetColor(cell))
                {
                    mismatches++;
                }
            }

            return mismatches;
        }

        private static int CountTilemapCellMismatches(Tilemap expected, Tilemap actual)
        {
            BoundsInt bounds = expected.cellBounds;
            bounds.xMin = Mathf.Min(bounds.xMin, actual.cellBounds.xMin);
            bounds.yMin = Mathf.Min(bounds.yMin, actual.cellBounds.yMin);
            bounds.xMax = Mathf.Max(bounds.xMax, actual.cellBounds.xMax);
            bounds.yMax = Mathf.Max(bounds.yMax, actual.cellBounds.yMax);
            int mismatches = 0;
            foreach (Vector3Int cell in bounds.allPositionsWithin)
            {
                if (expected.GetTile(cell) != actual.GetTile(cell) ||
                    expected.GetTransformMatrix(cell) != actual.GetTransformMatrix(cell) ||
                    expected.GetColor(cell) != actual.GetColor(cell))
                {
                    mismatches++;
                }
            }

            return mismatches;
        }

        private static int CountOccupiedCells(Tilemap tilemap)
        {
            int count = 0;
            foreach (Vector3Int cell in tilemap.cellBounds.allPositionsWithin)
            {
                if (tilemap.HasTile(cell))
                {
                    count++;
                }
            }

            return count;
        }

        private static TileBase? FindTileByName(Tilemap tilemap, string tileName)
        {
            foreach (Vector3Int cell in tilemap.cellBounds.allPositionsWithin)
            {
                TileBase tile = tilemap.GetTile(cell);
                if (tile != null && tile.name == tileName)
                {
                    return tile;
                }
            }

            return null;
        }

        private static int CountTileByName(Tilemap tilemap, string tileName)
        {
            int count = 0;
            foreach (Vector3Int cell in tilemap.cellBounds.allPositionsWithin)
            {
                if (tilemap.GetTile(cell)?.name == tileName)
                {
                    count++;
                }
            }

            return count;
        }

        private static int CountTile(Tilemap tilemap, TileBase expectedTile)
        {
            int count = 0;
            foreach (Vector3Int cell in tilemap.cellBounds.allPositionsWithin)
            {
                if (tilemap.GetTile(cell) == expectedTile)
                {
                    count++;
                }
            }

            return count;
        }

        private static void CountLowlandLayerContract(
            Tilemap ruleLayer,
            Tilemap baseLayer,
            Tilemap coverLayer,
            TileBase expectedLowlandVisualTile,
            out int ruleCellCount,
            out int dirtCellCount,
            out int grassCoverCellCount,
            out int bareDirtCellCount)
        {
            ruleCellCount = 0;
            dirtCellCount = 0;
            grassCoverCellCount = 0;
            bareDirtCellCount = 0;
            foreach (Vector3Int cell in ruleLayer.cellBounds.allPositionsWithin)
            {
                if (ruleLayer.GetTile(cell)?.name != LowlandGrassRuleTileName)
                {
                    continue;
                }

                ruleCellCount++;
                if (baseLayer.GetTile(cell)?.name == DirtTileName)
                {
                    dirtCellCount++;
                }

                if (coverLayer.GetTile(cell) == expectedLowlandVisualTile)
                {
                    grassCoverCellCount++;
                }
                else if (coverLayer.GetTile(cell) == null)
                {
                    bareDirtCellCount++;
                }
            }
        }

        private static T? FindSceneComponent<T>(Scene scene, string? objectName = null)
            where T : Component
        {
            foreach (GameObject root in scene.GetRootGameObjects())
            {
                foreach (T component in root.GetComponentsInChildren<T>(true))
                {
                    if (objectName == null || component.name == objectName)
                    {
                        return component;
                    }
                }
            }

            return null;
        }

        [Serializable]
        private sealed class MigrationResult
        {
            public bool Success;
            public string Message = string.Empty;
            public string ScenePath = string.Empty;
            public bool CoverLayerCreated;
            public bool DetailLayerRenamed;
            public int LowlandLayeredCellCount;
            public int MovedGrassDetailCellCount;
            public int BaseDirtCellCount;
            public int CoverGrassCellCount;
            public int LowlandRuleCellCount;
            public int LowlandDirtCellCount;
            public int LowlandGrassCoverCellCount;
            public int LowlandBareDirtCellCount;
            public int RemainingGrassInDetailCellCount;
            public string LowlandVisualTileName = string.Empty;
            public string SourceScenePath = string.Empty;
            public int SourceVisibleGroundMismatchCount;
            public int SourceDetailMismatchCount;
            public int SourceDetailOccupiedCellCount;
            public int DetailOccupiedCellCount;
            public bool NavigationMapUsesCoverLayer;
            public bool PresentationUsesCoverLayer;
        }
    }
}
