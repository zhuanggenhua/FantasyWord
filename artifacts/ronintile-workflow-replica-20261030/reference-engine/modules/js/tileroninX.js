var SourceImage = require('./SourceImage.js');

var {nativeImage} = require('electron');
var fs = require('fs');
var archiver = require('archiver');
var pulverized = require('pulverized');
var guid = require('guid');
var mkdirp = require('mkdirp');
var path = require('path');
var getDirName = require('path').dirname;

var TileGrid = require('./TileGrid.js');
var LayeredTileGrid = require('./LayeredTileGrid.js');
var CallbackManager = require('./CallbackManager.js');

var Tile = require('./Tile.js');
var TileBase = require('./TileBase.js');
var TileBorder = require('./TileBorder.js');
var SourceImage = require('./SourceImage.js');
var BorderSetBlob = require('./BorderSetBlob.js');
var BorderSetWang = require('./BorderSetWang.js');
var RegionSync = require('./RegionSync.js');

var TileRelationWang = require('./TileRelationWang.js');
var TileRelationWangBorder = require('./TileRelationWangBorder.js');
var TileRelationBlob = require('./TileRelationBlob.js');
var TileRelationBlobBorder = require('./TileRelationBlobBorder.js');
var TileRelationProp = require('./TileRelationProp.js');
var TileRelationPropBackground = require('./TileRelationPropBackground.js');
var TileRelationProxy = require('./TileRelationProxy.js');
var TileRelationBlobPre2_0_0 = require('./TileRelationBlobPre2_0_0.js');
var TileRelationWangPre2_0_0 = require('./TileRelationWangPre2_0_0.js');

var tileSizeChangedCallback = new CallbackManager();

var tileSizeChangedSubscribe = function(func) {
    tileSizeChangedCallback.subscribe(func);
}
exports.tileSizeChangedSubscribe = tileSizeChangedSubscribe;
 
var tileSizeChangedUnsubscribe = function(func) {
    tileSizeChangedCallback.unsubscribe(func);
}
exports.tileSizeChangedUnsubscribe = tileSizeChangedUnsubscribe;

var tileShapeChangedCallback = new CallbackManager();

var tileShapeChangedSubscribe = function(func) {
    tileShapeChangedCallback.subscribe(func);
}
exports.tileShapeChangedSubscribe = tileShapeChangedSubscribe;
 
var tileShapeChangedUnsubscribe = function(func) {
    tileShapeChangedCallback.unsubscribe(func);
}
exports.tileShapeChangedUnsubscribe = tileShapeChangedUnsubscribe;

var getTileSize = function() {
    if(tileShape == Shape.ORTHOGRAPHIC) {
        return tileWidth;
    } else if(tileShape == Shape.ISOMETRIC) {
        return [tileWidth, tileHeight];
    }
}
exports.getTileSize = getTileSize;

var getTileShape = function() {
    return tileShape;
}
exports.getTileShape = getTileShape;

var BorderGeneratorWang = require('./BorderGeneratorWang.js');
var BorderGeneratorBlob = require('./BorderGeneratorBlob.js');

var UserError = require('./UserError.js');

var ExportLoopDirectory = require('./ExportLoopDirectory.js');
var ExportFolder = require('./ExportFolder.js');
var ExportTextFile = require('./ExportTextFile.js');
var ExportVisualFile = require('./ExportVisualFile.js');
var ExportBlockField = require('./ExportBlockField.js');
var ExportTextBlock = require('./ExportTextBlock.js');
var ExportTextVariableBlock = require('./ExportTextVariableBlock.js');
var ExportNumberVariableBlock = require('./ExportNumberVariableBlock.js');
var ExportLoopBlock = require('./ExportLoopBlock.js');
var ExportGUIDBlock = require('./ExportGUIDBlock.js');
var ExportVisualBlockField = require('./ExportVisualBlockField.js');
var ExportVisualImageBlock = require('./ExportVisualImageBlock.js');
var ExportVisualImageVariableBlock = require('./ExportVisualImageVariableBlock.js');
var ExportVisualLoopBlock = require('./ExportVisualLoopBlock.js');
var ExportGridLoopBlock = require('./ExportGridLoopBlock.js');

var Shape = Object.freeze({"ORTHOGRAPHIC":0, "ISOMETRIC":1});
exports.Shape = Shape;

var TILE_SIZE_MAX = 256;

var tileWidth = 24;
var tileHeight = 24;
var tileShape = Shape.ORTHOGRAPHIC;
var globalSources = [];

var undoQueue = [];
var redoQueue = [];
var undoState = 0;

/** 正交/等距切换时递增；各视图在 tileSize 同步后若发现代数大于本地已应用的值则对齐默认相机（等距需 x=w/2）。 */
var workspaceCameraSnapGeneration = 0;
var requestSnapWorkspaceCameraToShapeDefault = function() {
    workspaceCameraSnapGeneration++;
};
exports.getWorkspaceCameraSnapGeneration = function() {
    return workspaceCameraSnapGeneration;
};
var restoreUndoState = function(undoGroup) {
    var redoGroup = [];
    for(var u = undoGroup.length-1; u >= 0; u--) {
        var undoParams = undoGroup[u];
        if(undoParams.action === "set_change") { //todo sandbox
            setTilesSetRaw(undoParams.prev_tiles, redoGroup);
        } else if(undoParams.action === "tileshape_convert") {
            var wasShape = tileShape;
            var wasW = tileWidth;
            var wasH = tileHeight;
            requestSnapWorkspaceCameraToShapeDefault();
            tileShape = undoParams.prev_shape;
            tileWidth = undoParams.prev_w;
            tileHeight = undoParams.prev_h;
            tileShapeChangedCallback.notify(tileShape);
            tileSizeChangedCallback.notify(getTileSize());
            redoGroup.push({
                action: "tileshape_convert",
                prev_shape: wasShape,
                prev_w: wasW,
                prev_h: wasH
            });
        } else if(undoParams.action === "tilesize_change") {
            setTileSize(undoParams.prev_value, redoGroup);
        } else if(undoParams.action === "source_replace") {
            undoParams.current_src.setSource(undoParams.prev_src, redoGroup);
        } else if(undoParams.action === "bset_source_change") {
            undoParams.bset.setSource(undoParams.bset_id, undoParams.prev_value, redoGroup);
        } else if(undoParams.action === "bset_rotation_change") {
            undoParams.bset.setRotation(undoParams.bset_id, undoParams.prev_value, redoGroup);
        } else if(undoParams.action === "bset_flipx_change") {
            undoParams.bset.setFlipX(undoParams.bset_id, undoParams.prev_value, redoGroup);
        } else if(undoParams.action === "bset_flipy_change") {
            undoParams.bset.setFlipY(undoParams.bset_id, undoParams.prev_value, redoGroup);
        } else if(undoParams.action === "bset_composite_change") {
            undoParams.bset.setComposite(undoParams.bset_id, undoParams.prev_value, redoGroup);
        } else if(undoParams.action === "bset_cutoff_change") {
            undoParams.bset.setCutoff(undoParams.bset_id, undoParams.prev_value, redoGroup);
        } else if(undoParams.action === "tile_relation_change") {
            Tile.setRelations(undoParams.rels, redoGroup);
        } else if(undoParams.action === "set_region_added") {
            removeRegionSet(undoParams.region, redoGroup);
        } else if(undoParams.action === "set_region_removed") {
            addRegionSetRaw(undoParams.region, redoGroup);
        } else if(undoParams.action === "set_region_moved") {
            moveRegionSetRaw(undoParams.region, -undoParams.offset.x, -undoParams.offset.y, redoGroup);
        } else if(undoParams.action === "sandbox_change") {
            setTilesSandboxRaw(undoParams.prev_tiles, redoGroup);
        } else if(undoParams.action === "variation_weight_change") {
            undoParams.rel.setWeight(undoParams.prev_value, redoGroup);
        }
         else if(undoParams.action === "sandbox_layer_added") {
            removeLayerSandbox(undoParams.id, redoGroup);
        } else if(undoParams.action === "sandbox_layer_removed") {
            addLayerSandboxRaw(undoParams.layer, undoParams.id, redoGroup);
        } else if(undoParams.action === "sandbox_layer_reordered") {
            reorderLayerSandbox(undoParams.new_id, undoParams.id, redoGroup);
        } else if(undoParams.action === "sandbox_layer_edited") {
            editLayerSandbox(undoParams.id, undoParams.prev_visible, undoParams.prev_name, redoGroup);
        }
    }
    saveUndoState(redoGroup);
}
var saveUndoState = function(undoParams) {
    if(undoState == 0) { //common action
        undoQueue.push(undoParams);
        redoQueue = [];
    } else if(undoState == 1) { //undoing
        redoQueue.push(undoParams);
    } else if(undoState == 2) { //redoing
        undoQueue.push(undoParams);
    }
}
exports.saveUndoState = saveUndoState;
var performUndo = function() {
    if(undoQueue.length > 0) {
        undoState = 1;

        var undoParams = undoQueue.pop();
        restoreUndoState(undoParams);

        undoState = 0;
    }
}
exports.performUndo = performUndo;
var performRedo = function() {
    if(redoQueue.length > 0) {
        undoState = 2;

        var undoParams = redoQueue.pop();
        restoreUndoState(undoParams);

        undoState = 0;
    }
}
exports.performRedo = performRedo;

var pushGlobalSource = function(src) {
    if(!globalSources.includes(src)) {
        globalSources.push(src);
    }
}
exports.pushGlobalSource = pushGlobalSource;

var removeGlobalSource = function(src) {
    var index = globalSources.indexOf(src);
    if (index > -1) {
        globalSources.splice(index, 1);
    }
}
exports.removeGlobalSource = removeGlobalSource;

var getGlobalSources = function() {
    return globalSources;
}
exports.getGlobalSources = getGlobalSources;

var setTileSize = function(size, undoGroup=[], errorGroup=[]) {
    if(tileShape == Shape.ORTHOGRAPHIC) {
        if(size < 8) {
            errorGroup.push({msg:"Tile size must be greater than or equal to 8."});
            return;
        } else if(size > TILE_SIZE_MAX) {
            errorGroup.push({msg:"Tile size must be less than or equal to 256."});
            return;
        }

        var undoParams = {action:'tilesize_change', prev_value:tileWidth};
        undoGroup.push(undoParams);

        tileWidth = size;
        tileHeight = tileWidth;
        tileSizeChangedCallback.notify(tileWidth);
    } else if(tileShape == Shape.ISOMETRIC) {
        var success = true;
        if(size[0] < 8) {
            errorGroup.push({msg:"Tile width must be greater than or equal to 8."});
            success = false;
        } else if(size[0] > TILE_SIZE_MAX) {
            errorGroup.push({msg:"Tile width must be less than or equal to 256."});
            success = false;
        } else if(size[0]%2 != 0) {
            errorGroup.push({msg:"Tile width must be even."});
            success = false;
        }
        if(size[1] < 8) {
            errorGroup.push({msg:"Tile height must be greater than or equal to 8."});
            success = false;
        } else if(size[1] > TILE_SIZE_MAX) {
            errorGroup.push({msg:"Tile height must be less than or equal to 256."});
            success = false;
        } else if(size[1]%2 != 0) {
            errorGroup.push({msg:"Tile height must be even."});
            success = false;
        }
        if(size[0] < size[1]) {
            errorGroup.push({msg:"Tile width must be greater than or equal to height."});
            success = false;
        } else if(size[0]%size[1] != 0) {
            errorGroup.push({msg:"Tile width must be a multiple of height."});
            success = false;
        }
        if(!success) {
            return;
        }

        var undoParams = {action:'tilesize_change', prev_value:[tileWidth, tileHeight]};
        undoGroup.push(undoParams);

        tileWidth = size[0];
        tileHeight = size[1];
        tileSizeChangedCallback.notify([tileWidth, tileHeight]);
    }
}
exports.setTileSize = setTileSize;

/**
 * 从正交正方形边长 S 推导满足等距规则的 (w,h)：均为偶数，8<=h<=w<=TILE_SIZE_MAX，w%h==0。
 * 优先 2:1（w=S, h=S/2）；否则在宽度仍为 S 的前提下选最大可行偶数 h；再否则退化为正方形 [S0,S0]。
 */
var orthSquareToIsoDims = function(S) {
    if(S < 8 || S > TILE_SIZE_MAX) {
        return null;
    }
    var S0 = S - (S % 2);
    if(S0 < 8) {
        return null;
    }
    var hHalf = S0 / 2;
    if(hHalf >= 8 && (hHalf % 2 === 0) && (S0 % hHalf === 0)) {
        return [S0, hHalf];
    }
    var hMax = Math.min(S0 - 2, S0 - (S0 % 2));
    if(hMax < 8) {
        return [S0, S0];
    }
    var h;
    for(h = hMax; h >= 8; h -= 2) {
        if(S0 % h === 0) {
            return [S0, h];
        }
    }
    return [S0, S0];
};

var convertOrthographicToIsometric = function(undoGroup, errorGroup) {
    if(undoGroup == null) {
        undoGroup = [];
    }
    if(errorGroup == null) {
        errorGroup = [];
    }
    if(tileShape != Shape.ORTHOGRAPHIC) {
        errorGroup.push({msg: "Only orthographic projects can convert to isometric."});
        return false;
    }
    var S = tileWidth;
    var dims = orthSquareToIsoDims(S);
    if(dims == null) {
        errorGroup.push({msg: "Could not derive valid isometric tile dimensions from the current size."});
        return false;
    }
    undoGroup.push({
        action: "tileshape_convert",
        prev_shape: tileShape,
        prev_w: tileWidth,
        prev_h: tileHeight
    });
    requestSnapWorkspaceCameraToShapeDefault();
    tileShape = Shape.ISOMETRIC;
    tileWidth = dims[0];
    tileHeight = dims[1];
    tileShapeChangedCallback.notify(tileShape);
    tileSizeChangedCallback.notify([tileWidth, tileHeight]);
    return true;
};
exports.convertOrthographicToIsometric = convertOrthographicToIsometric;

var setTileShape = function(shape) {
    for(var key in Shape) {
        if(Shape[key] == shape) {
            tileShape = shape;
            tileShapeChangedCallback.notify(tileShape);
            break;
        }
    }
}

var tileroninXVersion = "2.1.0";
var proSuffix = "-pro";
//FUNCTIONS THAT NEED UPDATING UPON CHANGING THESE VALUES
//  LOAD FUNCTIONS ON FUNCTION (loadData)
//  LOAD FUNCTIONS ON index.html
//  LOAD FUNCTIONS ON SetView.js
//  LOAD FUNCTIONS ON SandboxView.js

var getVersionString = function() {
    return tileroninXVersion;
}
exports.getVersionString = getVersionString;

var getVersionID = function() {
    return tileroninXVersion+proSuffix;
}
exports.getVersionID = getVersionID;

var newData = function(options) {
    //clear globals
    for(var i in globalSources) {
        globalSources[i].unload();
    }
    globalSources = [];
    //clear set
    var setTiles = set.getTiles();
    var changePos = [];
    for(var key in setTiles) {
        var tile = setTiles[key];
        //tile.tile.inSet = false;
        tile.tile.unreference();
        set.setTile(null, tile.pos.x, tile.pos.y);
        changePos.push({x:tile.pos.x, y:tile.pos.y});
    }
    tileChangedSetCallback.notify(changePos);
    var setRegions = set.getRegions();
    while(setRegions.length > 0) {
        var region = setRegions[0];
        set.removeRegion(region);
        region.finRegion();
        regionRemovedSetCallback.notify(region);
    }
    while(sandbox.getLayers().length > 0) {
        sandbox.removeLayer(sandbox.getLayers().length-1);
        layerRemovedSandboxCallback.notify(0);
    }
    sandbox.addLayer();
    layerAddedSandboxCallback.notify(sandbox.getLayers().length-1);
    var sandboxTiles = sandbox.getTiles();
    for(var key in sandboxTiles) {
        var tile = sandboxTiles[key];
        var tk = getTileKey(tile.pos.x, tile.pos.y, tile.pos.z);
        delete tile.tile.sandboxRefs[tk];
        sandbox.setTile(null, tile.pos.x, tile.pos.y, tile.pos.z);
        tileChangedSandboxCallback.notify(tile.pos.x, tile.pos.y, tile.pos.z);
    }

    setTileShape(options.shape);
    if(options.shape == Shape.ORTHOGRAPHIC) {
        setTileSize(24);
    } else if(options.shape == Shape.ISOMETRIC) {
        setTileSize([32, 16]);
    }

    undoQueue = [];
	redoQueue = [];
    clipboardSources = null;
    clipboardTiles = null;

    onNewCallback.notify();
}
exports.newData = newData;

exports.projectFileFilter = { name: 'RoninTile Project', extensions: ['json'] };
exports.exportFormatFilterOrthographic = {name: 'ronintile Orthographic Export Format', extensions: ['tsfo']};
exports.exportFormatFilterIsometric = {name: 'ronintile Isometric Export Format', extensions: ['tsfi']};
exports.imageImportFileFilter = {name: 'Image', extensions: ['png']};

var loadData = function(fn) {
    if(!fs.existsSync(fn)) {
        return false;
    }
    if (fn.endsWith('.json') || fn.endsWith('.tset')) {
        var loadFunc = {'0.1.0-beta.0':loadData_1,
                        '0.1.0-beta.1':loadData_1,
                        '0.1.0-beta.2':loadData_1,
                        '0.1.0-beta.3':loadData_1,
                        '0.1.0-beta.4':loadData_1,
                        '0.1.0-beta.5-lite':loadData_1,
                        '0.1.0-beta.5-pro':loadData_2,
                        '0.1.0-beta.6-lite':loadData_1,
                        '0.1.0-beta.6-pro':loadData_3,
                        '0.1.0-beta.7-lite':loadData_1,
                        '0.1.0-beta.7-pro':loadData_4,
                        '1.0.0-lite':loadData_1,
                        '1.0.0-pro':loadData_5,
                        '1.0.1-dev.0-lite':loadData_1,
                        '1.0.1-dev.0-pro':loadData_5,
                        '1.0.1-lite':loadData_1,
                        '1.0.1-pro':loadData_5,
                        '1.0.2-dev.0-lite':loadData_1,
                        '1.0.2-dev.0-pro':loadData_5,
                        '1.0.2-lite':loadData_1,
                        '1.0.2-pro':loadData_5,
                        '2.0.0-dev.0-lite':loadData_6,
                        '2.0.0-dev.0-pro':loadData_7,
                        '2.0.0-dev.1-lite':loadData_6,
                        '2.0.0-dev.1-pro':loadData_7,
                        '2.0.0-dev.2-lite':loadData_6,
                        '2.0.0-dev.2-pro':loadData_7,
                        '2.0.0-dev.3-lite':loadData_8,
                        '2.0.0-dev.3-pro':loadData_9,
                        '2.0.0-dev.4-lite':loadData_8,
                        '2.0.0-dev.4-pro':loadData_9,
                        '2.0.0-lite':loadData_8,
                        '2.0.0-pro':loadData_9,
                        '2.1.0-dev.0-lite':loadData_8,
                        '2.1.0-dev.0-pro':loadData_10,
                        '2.1.0-lite':loadData_8,
                        '2.1.0-pro':loadData_10};

        var data = JSON.parse(fs.readFileSync(fn));
        var loadFn = loadFunc[data.version];
        if(loadFn == null) {
            return false;
        }

        //clear globals
        for(var i in globalSources) {
            globalSources[i].unload();
        }
        globalSources = [];
        //clear set
        var setTiles = set.getTiles();
        var changePos = [];
        for(var key in setTiles) {
            var tile = setTiles[key];
            //tile.tile.inSet = false;
            tile.tile.unreference();
            set.setTile(null, tile.pos.x, tile.pos.y);
            changePos.push({x:tile.pos.x, y:tile.pos.y});
        }
        tileChangedSetCallback.notify(changePos);
        var setRegions = set.getRegions();
        while(setRegions.length > 0) {
            var region = setRegions[0];
            set.removeRegion(region);
            region.finRegion();
            regionRemovedSetCallback.notify(region);
        }
        while(sandbox.getLayers().length > 0) {
            sandbox.removeLayer(sandbox.getLayers().length-1);
            layerRemovedSandboxCallback.notify(0);
        }
        var sandboxTiles = sandbox.getTiles();
        for(var key in sandboxTiles) {
            var tile = sandboxTiles[key];
            var tk = getTileKey(tile.pos.x, tile.pos.y, tile.pos.z);
            delete tile.tile.sandboxRefs[tk];
            sandbox.setTile(null, tile.pos.x, tile.pos.y, tile.pos.z);
            tileChangedSandboxCallback.notify(tile.pos.x, tile.pos.y, tile.pos.z);
        }

        loadFn(data, fn);

        undoQueue = [];
        redoQueue = [];
        clipboardSources = null;
        clipboardTiles = null;

        onLoadCallback.notify(data);
        return true;
    }
    return false;
}
exports.loadData = loadData;

var loadData_1 = function(data) {
    // -----PRE 2.0.0-----
    // -----PRE 2.0.0-----
    // -----PRE 2.0.0-----
    setTileShape(Shape.ORTHOGRAPHIC);
    setTileSize(data.tilesize);

    var sources = [];
    for(var i in data.sources) {
        var sourceSave = data.sources[i];
        if(sourceSave.type === "image") {
            var src = new SourceImage(nativeImage.createFromDataURL(sourceSave.url));
            sources[i] = src;
        }
    }

    var bsets = [];
    var bsetsBase = []
    for(var i in data.bsets) {
        var bsetSave = data.bsets[i];
        if(bsetSave.type === "blob") {
            var bsetConfig = [];
            for(var di = 1; di < bsetSave.data.length; di++) {
                var bsetConfigRow = {src:sources[bsetSave.data[di].srcID], r:bsetSave.data[di].r, fx:bsetSave.data[di].fx, fy:bsetSave.data[di].fy};
                if(bsetSave.data[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = bsetSave.data[di].cutoff;
                }
                if(bsetSave.data[di].c != null) {
                    bsetConfigRow['c'] = bsetSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetBlob(bsetConfig);
            bsets[i] = bset;
            bsetsBase[i] = sources[bsetSave.data[0].srcID];
        } else if(bsetSave.type === "wang") {
            var bsetConfig = [];
            for(var di = 2; di < bsetSave.data.length; di++) {
                var bsetConfigRow = {src:sources[bsetSave.data[di].srcID], r:bsetSave.data[di].r, fx:bsetSave.data[di].fx, fy:bsetSave.data[di].fy};
                if(bsetSave.data[di].c != null) {
                    bsetConfigRow['c'] = bsetSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetWang(bsetConfig);
            bsets[i] = bset;
            bsetsBase[i] = [sources[bsetSave.data[0].srcID], sources[bsetSave.data[1].srcID]];
        }
    }

    var tiles = [];
    var pre2_0_0Tiles = [];
    for(var i in data.tiles) {
        var tileSave = data.tiles[i];
        if(tileSave.type === "base") {
            var tile = new TileBase(sources[tileSave.sourceID]);
            tiles[i] = tile;
        } else if(tileSave.type === "border") {
            var tile;
            if(bsets[tileSave.bsetID] instanceof BorderSetBlob) {
                tile = new TileBorder(new BorderGeneratorBlob());
                if(pre2_0_0Tiles[tileSave.bsetID] == null) {
                    pre2_0_0Tiles[tileSave.bsetID] = [];
                }
                pre2_0_0Tiles[tileSave.bsetID].push([tile, new TileRelationBlobPre2_0_0(bsets[tileSave.bsetID], tileSave.btype, new TileBase(bsetsBase[tileSave.bsetID]))]);
            } else if(bsets[tileSave.bsetID] instanceof BorderSetWang) {
                tile = new TileBorder(new BorderGeneratorWang());
                if(pre2_0_0Tiles[tileSave.bsetID] == null) {
                    pre2_0_0Tiles[tileSave.bsetID] = [];
                }
                pre2_0_0Tiles[tileSave.bsetID].push([tile, new TileRelationWangPre2_0_0(bsets[tileSave.bsetID], tileSave.btype, new TileBase(bsetsBase[tileSave.bsetID][0]), new TileBase(bsetsBase[tileSave.bsetID][1]))]);
            }
            tiles[i] = tile;
        }
    }
    for(var i in pre2_0_0Tiles) {
        var ts = pre2_0_0Tiles[i];
        for(var j in ts) {
            for(var k in ts) {
                ts[j][0].registerRelation(ts[k][0], ts[j][1], []);
            }
        }
    }

    var changePos = [];
    for(var i in data.set) {
        var setTileSave = data.set[i];
        var ttile = tiles[setTileSave.tileID];
        //ttile.inSet = true;
        ttile.reference();
        set.setTile(ttile, setTileSave.pos.x, setTileSave.pos.y);
        changePos.push({x:setTileSave.pos.x, y:setTileSave.pos.y});
    }
    tileChangedSetCallback.notify(changePos);

    sandbox.addLayer();
    layerAddedSandboxCallback.notify(sandbox.getLayers().length-1);
}

var loadData_2 = function(data) {
    // -----PRE 2.0.0-----
    // -----PRE 2.0.0-----
    // -----PRE 2.0.0-----
    setTileShape(Shape.ORTHOGRAPHIC);
    setTileSize(data.tilesize);

    var sources = [];
    for(var i in data.sources) {
        var sourceSave = data.sources[i];
        if(sourceSave.type === "image") {
            var src = new SourceImage(nativeImage.createFromDataURL(sourceSave.url));
            sources[i] = src;
        }
    }

    var bsets = [];
    var bsetsBase = []
    for(var i in data.bsets) {
        var bsetSave = data.bsets[i];
        if(bsetSave.type === "blob") {
            var bsetConfig = [];
            for(var di = 1; di < bsetSave.data.length; di++) {
                var bsetConfigRow = {src:sources[bsetSave.data[di].srcID], r:bsetSave.data[di].r, fx:bsetSave.data[di].fx, fy:bsetSave.data[di].fy};
                if(bsetSave.data[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = bsetSave.data[di].cutoff;
                }
                if(bsetSave.data[di].c != null) {
                    bsetConfigRow['c'] = bsetSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetBlob(bsetConfig);
            bsets[i] = bset;
            bsetsBase[i] = sources[bsetSave.data[0].srcID];
        } else if(bsetSave.type === "wang") {
            var bsetConfig = [];
            for(var di = 2; di < bsetSave.data.length; di++) {
                var bsetConfigRow = {src:sources[bsetSave.data[di].srcID], r:bsetSave.data[di].r, fx:bsetSave.data[di].fx, fy:bsetSave.data[di].fy};
                if(bsetSave.data[di].c != null) {
                    bsetConfigRow['c'] = bsetSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetWang(bsetConfig);
            bsets[i] = bset;
            bsetsBase[i] = [sources[bsetSave.data[0].srcID], sources[bsetSave.data[1].srcID]];
        }
    }

    var tiles = [];
    var pre2_0_0Tiles = [];
    for(var i in data.tiles) {
        var tileSave = data.tiles[i];
        if(tileSave.type === "base") {
            var tile = new TileBase(sources[tileSave.sourceID]);
            tiles[i] = tile;
        } else if(tileSave.type === "border") {
            var tile;
            if(bsets[tileSave.bsetID] instanceof BorderSetBlob) {
                tile = new TileBorder(new BorderGeneratorBlob());
                if(pre2_0_0Tiles[tileSave.bsetID] == null) {
                    pre2_0_0Tiles[tileSave.bsetID] = [];
                }
                pre2_0_0Tiles[tileSave.bsetID].push([tile, new TileRelationBlobPre2_0_0(bsets[tileSave.bsetID], tileSave.btype, new TileBase(bsetsBase[tileSave.bsetID]))]);
            } else if(bsets[tileSave.bsetID] instanceof BorderSetWang) {
                tile = new TileBorder(new BorderGeneratorWang());
                if(pre2_0_0Tiles[tileSave.bsetID] == null) {
                    pre2_0_0Tiles[tileSave.bsetID] = [];
                }
                pre2_0_0Tiles[tileSave.bsetID].push([tile, new TileRelationWangPre2_0_0(bsets[tileSave.bsetID], tileSave.btype, new TileBase(bsetsBase[tileSave.bsetID][0]), new TileBase(bsetsBase[tileSave.bsetID][1]))]);
            }
            tiles[i] = tile;
        }
    }
    for(var i in pre2_0_0Tiles) {
        var ts = pre2_0_0Tiles[i];
        for(var j in ts) {
            for(var k in ts) {
                ts[j][0].registerRelation(ts[k][0], ts[j][1], []);
            }
        }
    }

    var changePos = [];
    for(var i in data.set) {
        var setTileSave = data.set[i];
        var ttile = tiles[setTileSave.tileID];
        //ttile.inSet = true;
        ttile.reference();
        set.setTile(ttile, setTileSave.pos.x, setTileSave.pos.y);
        changePos.push({x:setTileSave.pos.x, y:setTileSave.pos.y});
    }
    tileChangedSetCallback.notify(changePos);

    for(var i in data.set_regions) {
        var regionSave = data.set_regions[i];
        if(regionSave.type === "sync") {
            var region = new RegionSync(regionSave.bounds.x0, regionSave.bounds.y0, regionSave.filename, regionSave.bounds.x1, regionSave.bounds.y1);
            set.addRegion(region);
            region.initRegion();
            regionAddedSetCallback.notify(region);
        }
    }

    sandbox.addLayer();
    layerAddedSandboxCallback.notify(sandbox.getLayers().length-1);
}

var loadData_3 = function(data) {
    // -----PRE 2.0.0-----
    // -----PRE 2.0.0-----
    // -----PRE 2.0.0-----
    setTileShape(Shape.ORTHOGRAPHIC);
    setTileSize(data.tilesize);

    var sources = [];
    for(var i in data.sources) {
        var sourceSave = data.sources[i];
        if(sourceSave.type === "image") {
            var src = new SourceImage(nativeImage.createFromDataURL(sourceSave.url));
            sources[i] = src;
        }
    }

    var bsets = [];
    var bsetsBase = []
    for(var i in data.bsets) {
        var bsetSave = data.bsets[i];
        if(bsetSave.type === "blob") {
            var bsetConfig = [];
            for(var di = 1; di < bsetSave.data.length; di++) {
                var bsetConfigRow = {src:sources[bsetSave.data[di].srcID], r:bsetSave.data[di].r, fx:bsetSave.data[di].fx, fy:bsetSave.data[di].fy};
                if(bsetSave.data[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = bsetSave.data[di].cutoff;
                }
                if(bsetSave.data[di].c != null) {
                    bsetConfigRow['c'] = bsetSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetBlob(bsetConfig);
            bsets[i] = bset;
            bsetsBase[i] = sources[bsetSave.data[0].srcID];
        } else if(bsetSave.type === "wang") {
            var bsetConfig = [];
            for(var di = 2; di < bsetSave.data.length; di++) {
                var bsetConfigRow = {src:sources[bsetSave.data[di].srcID], r:bsetSave.data[di].r, fx:bsetSave.data[di].fx, fy:bsetSave.data[di].fy};
                if(bsetSave.data[di].c != null) {
                    bsetConfigRow['c'] = bsetSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetWang(bsetConfig);
            bsets[i] = bset;
            bsetsBase[i] = [sources[bsetSave.data[0].srcID], sources[bsetSave.data[1].srcID]];
        }
    }

    var tiles = [];
    var pre2_0_0Tiles = [];
    for(var i in data.tiles) {
        var tileSave = data.tiles[i];
        if(tileSave.type === "base") {
            var tile = new TileBase(sources[tileSave.sourceID]);
            tiles[i] = tile;
        } else if(tileSave.type === "border") {
            var tile;
            if(bsets[tileSave.bsetID] instanceof BorderSetBlob) {
                tile = new TileBorder(new BorderGeneratorBlob());
                if(pre2_0_0Tiles[tileSave.bsetID] == null) {
                    pre2_0_0Tiles[tileSave.bsetID] = [];
                }
                pre2_0_0Tiles[tileSave.bsetID].push([tile, new TileRelationBlobPre2_0_0(bsets[tileSave.bsetID], tileSave.btype, new TileBase(bsetsBase[tileSave.bsetID]))]);
            } else if(bsets[tileSave.bsetID] instanceof BorderSetWang) {
                tile = new TileBorder(new BorderGeneratorWang());
                if(pre2_0_0Tiles[tileSave.bsetID] == null) {
                    pre2_0_0Tiles[tileSave.bsetID] = [];
                }
                pre2_0_0Tiles[tileSave.bsetID].push([tile, new TileRelationWangPre2_0_0(bsets[tileSave.bsetID], tileSave.btype, new TileBase(bsetsBase[tileSave.bsetID][0]), new TileBase(bsetsBase[tileSave.bsetID][1]))]);
            }
            tiles[i] = tile;
        }
    }
    for(var i in pre2_0_0Tiles) {
        var ts = pre2_0_0Tiles[i];
        for(var j in ts) {
            for(var k in ts) {
                ts[j][0].registerRelation(ts[k][0], ts[j][1], []);
            }
        }
    }

    var changePos = [];
    for(var i in data.set) {
        var setTileSave = data.set[i];
        var ttile = tiles[setTileSave.tileID];
        //ttile.inSet = true;
        ttile.reference();
        set.setTile(ttile, setTileSave.pos.x, setTileSave.pos.y);
        changePos.push({x:setTileSave.pos.x, y:setTileSave.pos.y});
    }
    tileChangedSetCallback.notify(changePos);

    for(var i in data.set_regions) {
        var regionSave = data.set_regions[i];
        if(regionSave.type === "sync") {
            var region = new RegionSync(regionSave.bounds.x0, regionSave.bounds.y0, regionSave.filename, regionSave.bounds.x1, regionSave.bounds.y1);
            set.addRegion(region);
            region.initRegion();
            regionAddedSetCallback.notify(region);
        }
    }

    sandbox.addLayer();
    layerAddedSandboxCallback.notify(sandbox.getLayers().length-1);
    for(var i in data.sandbox) {
        var sandboxTileSave = data.sandbox[i];
        var tile = tiles[sandboxTileSave.tileID];
        tile.sandboxRefs[getTileKey(sandboxTileSave.pos.x, sandboxTileSave.pos.y, 0)] = {x:sandboxTileSave.pos.x, y:sandboxTileSave.pos.y, z:0};
        sandbox.setTile(tile, sandboxTileSave.pos.x, sandboxTileSave.pos.y);
        tileChangedSandboxCallback.notify(sandboxTileSave.pos.x, sandboxTileSave.pos.y, 0);
    }
}

var loadData_4 = function(data) {
    // -----PRE 2.0.0-----
    // -----PRE 2.0.0-----
    // -----PRE 2.0.0-----
    setTileShape(Shape.ORTHOGRAPHIC);
    setTileSize(data.tilesize);
    
    var sources = [];
    for(var i in data.sources) {
        var sourceSave = data.sources[i];
        if(sourceSave.type === "image") {
            var src = new SourceImage(nativeImage.createFromDataURL(sourceSave.url));
            sources[i] = src;
        }
    }

    var bsets = [];
    var bsetsBase = []
    for(var i in data.bsets) {
        var bsetSave = data.bsets[i];
        if(bsetSave.type === "blob") {
            var bsetConfig = [];
            for(var di = 1; di < bsetSave.data.length; di++) {
                var bsetConfigRow = {src:sources[bsetSave.data[di].srcID], r:bsetSave.data[di].r, fx:bsetSave.data[di].fx, fy:bsetSave.data[di].fy};
                if(bsetSave.data[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = bsetSave.data[di].cutoff;
                }
                if(bsetSave.data[di].c != null) {
                    bsetConfigRow['c'] = bsetSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetBlob(bsetConfig);
            bsets[i] = bset;
            bsetsBase[i] = sources[bsetSave.data[0].srcID];
        } else if(bsetSave.type === "wang") {
            var bsetConfig = [];
            for(var di = 2; di < bsetSave.data.length; di++) {
                var bsetConfigRow = {src:sources[bsetSave.data[di].srcID], r:bsetSave.data[di].r, fx:bsetSave.data[di].fx, fy:bsetSave.data[di].fy};
                if(bsetSave.data[di].c != null) {
                    bsetConfigRow['c'] = bsetSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetWang(bsetConfig);
            bsets[i] = bset;
            bsetsBase[i] = [sources[bsetSave.data[0].srcID], sources[bsetSave.data[1].srcID]];
        }
    }

    var tiles = [];
    var pre2_0_0Tiles = [];
    for(var i in data.tiles) {
        var tileSave = data.tiles[i];
        if(tileSave.type === "base") {
            var tile = new TileBase(sources[tileSave.sourceID]);
            tiles[i] = tile;
        } else if(tileSave.type === "border") {
            var tile;
            if(bsets[tileSave.bsetID] instanceof BorderSetBlob) {
                tile = new TileBorder(new BorderGeneratorBlob());
                if(pre2_0_0Tiles[tileSave.bsetID] == null) {
                    pre2_0_0Tiles[tileSave.bsetID] = [];
                }
                pre2_0_0Tiles[tileSave.bsetID].push([tile, new TileRelationBlobPre2_0_0(bsets[tileSave.bsetID], tileSave.btype, new TileBase(bsetsBase[tileSave.bsetID]))]);
            } else if(bsets[tileSave.bsetID] instanceof BorderSetWang) {
                tile = new TileBorder(new BorderGeneratorWang());
                if(pre2_0_0Tiles[tileSave.bsetID] == null) {
                    pre2_0_0Tiles[tileSave.bsetID] = [];
                }
                pre2_0_0Tiles[tileSave.bsetID].push([tile, new TileRelationWangPre2_0_0(bsets[tileSave.bsetID], tileSave.btype, new TileBase(bsetsBase[tileSave.bsetID][0]), new TileBase(bsetsBase[tileSave.bsetID][1]))]);
            }
            tiles[i] = tile;
        }
    }

    //convert tile config to post 2.0.0
    var pre2_0_0isProp = function(ts) {
        if(ts.mode == 0 && (ts.pComponents.length > 0 || ts.bgID != -1)) {
            return true;
        }
        return false;
    }
    var pre2_0_0isBlob = function(ts) {
        if(ts.mode == 1 && ts.bBlob.length > 0) {
            return true;
        }
        return false;
    }
    var pre2_0_0isWang = function(ts) {
        if(ts.mode == 2) {
            for(var i in ts.bWang) {
                var other = ts.bWang[i].otherID;
                if(data.tiles[other].mode == 2) {
                    return true;
                }
            }
        }
        return false;
    }
    for(var i in data.tiles) {
        var tileSave = data.tiles[i];
        var cTile = tiles[i];
        if(tileSave.type === "border") {
            continue; //generated tiles cannot be blob masters, wang masters or prop components
        }

        if(pre2_0_0isProp(tileSave)) { //prop
            //TODO
            //TODO
            //TODO
            //TODO
            for(var k in tileSave.pComponents) {
                var pTile = data.tiles[tileSave.pComponents[k].tileID];
                var cOther = tiles[tileSave.pComponents[k].tileID];
                if(pTile.mode != 0 || pTile.type === "border") {
                    continue; // prop relation with non-prop tile or with generated tile
                }
                var pos = tileSave.pComponents[k].pos;
                cTile.registerRelation(cOther, new TileRelationProp(pos.x, pos.y), []);
            }
            //set background
            if(tileSave.bgID != -1) {
                if(tileSave.pComponents.length == 0) {
                    cTile.registerRelation(false, new TileRelationProp(0, 0), []);
                }
                var bgTile = tiles[tileSave.bgID];
                var bgData = data.tiles[tileSave.bgID];
                if(pre2_0_0isBlob(bgData)
                || pre2_0_0isWang(bgData)) {
                    cTile.registerRelation(bgTile, new TileRelationPropBackground(false), []);
                    bgTile.registerRelation(cTile, new TileRelationPropBackground(true), []);
                }
            }
        } else if(pre2_0_0isBlob(tileSave)) { //blob
            //create relation base->false
            //get bset for relation
            //save valid borders to add later
            var bset = null;
            var borders = [];
            for(var k in tileSave.bBlob) {
                var bTile = data.tiles[tileSave.bBlob[k].tileID];
                if(pre2_0_0isProp(bTile) /*prop*/
                || pre2_0_0isBlob(bTile) /*blob*/
                || pre2_0_0isWang(bTile) /*wang*/) {
                    continue; //not eligible
                }
                borders.push(tileSave.bBlob[k]);
                if(bTile.type === "border") {
                    bset = bsets[bTile.bsetID];
                }
            }
            if(bset == null) {
                bset = new BorderSetBlob();
            } else {
                var bsetSources = bset.getSources();
                var bsetConfig = [
                    {src:bsetSources[0], r:bset.getRotation(0), fx:bset.getFlipX(0), fy:bset.getFlipY(0), cutoff:bset.getCutoff(0)},
                    {src:bsetSources[1], r:bset.getRotation(1), fx:bset.getFlipX(1), fy:bset.getFlipY(1), cutoff:bset.getCutoff(1)},
                    {src:bsetSources[2], r:bset.getRotation(2), fx:bset.getFlipX(2), fy:bset.getFlipY(2), cutoff:bset.getCutoff(2)},
                    {src:bsetSources[3], r:bset.getRotation(3), fx:bset.getFlipX(3), fy:bset.getFlipY(3), cutoff:bset.getCutoff(3)},
                    {src:bsetSources[4], r:bset.getRotation(4), fx:bset.getFlipX(4), fy:bset.getFlipY(4), c:bset.getComposite(4)},
                    {src:bsetSources[5], r:bset.getRotation(5), fx:bset.getFlipX(5), fy:bset.getFlipY(5), c:bset.getComposite(5)},
                    {src:bsetSources[6], r:bset.getRotation(6), fx:bset.getFlipX(6), fy:bset.getFlipY(6), c:bset.getComposite(6)},
                    {src:bsetSources[7], r:bset.getRotation(7), fx:bset.getFlipX(7), fy:bset.getFlipY(7), c:bset.getComposite(7)},
                    {src:bsetSources[8], r:bset.getRotation(8), fx:bset.getFlipX(8), fy:bset.getFlipY(8), c:bset.getComposite(8)},
                    {src:bsetSources[9], r:bset.getRotation(9), fx:bset.getFlipX(9), fy:bset.getFlipY(9), c:bset.getComposite(9)},
                    {src:bsetSources[10], r:bset.getRotation(10), fx:bset.getFlipX(10), fy:bset.getFlipY(10), c:bset.getComposite(10)},
                    {src:bsetSources[11], r:bset.getRotation(11), fx:bset.getFlipX(11), fy:bset.getFlipY(11), c:bset.getComposite(11)}
                ];
                bset = new BorderSetBlob(bsetConfig);
            }
            //create relation
            cTile.registerRelation(false, new TileRelationBlob(bset, cTile), []);
            //append borders
            for(var k in borders) {
                var bTile = borders[k];
                var brdTile = tiles[bTile.tileID];
                if(brdTile.getRelations().length > 0) {
                    continue; //skip tiles that have been added as border to another base tile
                }
                //get indexMatrix;
                var newIndex = [0, 1, 2, 7, 3, 6, 5, 4];
                var indexMatrix = [false, false, false, false, false, false, false, false];
                for(var a = 0; a < 8; a++) {
                    if((bTile.i & (1 << a)) != 0) {
                        indexMatrix[newIndex[a]] = cTile;
                    }
                }
                for(var i = 0; i < 4; i++) {
                    if(indexMatrix[(i*2+7)%8] != cTile || indexMatrix[(i*2+1)%8] != cTile) {
                        indexMatrix[i*2] = null;
                    }
                }
                cTile.registerRelation(brdTile, new TileRelationBlobBorder(indexMatrix, false), []);
                brdTile.registerRelation(cTile, new TileRelationBlobBorder(indexMatrix, true), []);
            }
        } else if(pre2_0_0isWang(tileSave)) { //wang
            //get wang pairs
            var pairs = [];
            for(var k in tileSave.bWang) {
                var other = tileSave.bWang[k].otherID;
                if(data.tiles[other].mode != 2) {
                    continue; //pair with a non-wang tile
                }
                if(pairs.indexOf(other) == -1) {
                    pairs.push(other);
                }
            }
            for(var p in pairs) {
                var other = pairs[p];
                var cOther = tiles[other];
                if(cOther.getRelation(cTile) != null) {
                    continue; //skip pairs that have already been connected
                }
                //create relation base0->base1
                //get bset for relation
                //save valid borders to add later
                var bset = null;
                var borders = [];
                for(var k in tileSave.bWang) {
                    if(tileSave.bWang[k].otherID != other) {
                        continue;
                    }
                    var bTile = data.tiles[tileSave.bWang[k].tileID];
                    if(pre2_0_0isProp(bTile) /*prop*/
                    || pre2_0_0isBlob(bTile) /*blob*/
                    || pre2_0_0isWang(bTile) /*wang*/) {
                        continue; //not eligible
                    }
                    borders.push(tileSave.bWang[k]);
                    if(bTile.type === "border") {
                        bset = bsets[bTile.bsetID];
                    }
                }
                if(bset == null) {
                    bset = new BorderSetWang();
                } else {
                    var bsetSources = bset.getSources();
                    var bsetConfig = [
                        {src:bsetSources[0], r:bset.getRotation(0), fx:bset.getFlipX(0), fy:bset.getFlipY(0)},
                        {src:bsetSources[1], r:bset.getRotation(1), fx:bset.getFlipX(1), fy:bset.getFlipY(1)},
                        {src:bsetSources[2], r:bset.getRotation(2), fx:bset.getFlipX(2), fy:bset.getFlipY(2)},
                        {src:bsetSources[3], r:bset.getRotation(3), fx:bset.getFlipX(3), fy:bset.getFlipY(3)},
                        {src:bsetSources[4], r:bset.getRotation(4), fx:bset.getFlipX(4), fy:bset.getFlipY(4), c:bset.getComposite(4)},
                        {src:bsetSources[5], r:bset.getRotation(5), fx:bset.getFlipX(5), fy:bset.getFlipY(5), c:bset.getComposite(5)},
                        {src:bsetSources[6], r:bset.getRotation(6), fx:bset.getFlipX(6), fy:bset.getFlipY(6), c:bset.getComposite(6)},
                        {src:bsetSources[7], r:bset.getRotation(7), fx:bset.getFlipX(7), fy:bset.getFlipY(7), c:bset.getComposite(7)},
                        {src:bsetSources[8], r:bset.getRotation(8), fx:bset.getFlipX(8), fy:bset.getFlipY(8), c:bset.getComposite(8)},
                        {src:bsetSources[9], r:bset.getRotation(9), fx:bset.getFlipX(9), fy:bset.getFlipY(9), c:bset.getComposite(9)},
                        {src:bsetSources[10], r:bset.getRotation(10), fx:bset.getFlipX(10), fy:bset.getFlipY(10), c:bset.getComposite(10)},
                        {src:bsetSources[11], r:bset.getRotation(11), fx:bset.getFlipX(11), fy:bset.getFlipY(11), c:bset.getComposite(11)},
                    ];
                    bset = new BorderSetWang(bsetConfig);
                }
                //create relation
                var rel = new TileRelationWang(bset, cTile);
                cTile.registerRelation(cOther, rel, []);
                cOther.registerRelation(cTile, rel, []);
                //append borders
                for(var k in borders) {
                    var bTile = borders[k];
                    var brdTile = tiles[bTile.tileID];
                    if(brdTile.getRelations().length > 0) {
                        continue; //skip tiles that have been added as border to another base tile
                    }
                    //get indexMatrix;
                    var newIndex = [0, 1, 3, 2];
                    var indexMatrix = [cOther, cOther, cOther, cOther];
                    for(var a = 0; a < 4; a++) {
                        if((bTile.i & (1 << a)) != 0) {
                            indexMatrix[newIndex[a]] = cTile;
                        }
                    }

                    var rel0 = new TileRelationWangBorder(indexMatrix, false);
                    var rel1 = new TileRelationWangBorder(indexMatrix, true);
                    cTile.registerRelation(brdTile, rel0, []);
                    brdTile.registerRelation(cTile, rel1, []);
                    cOther.registerRelation(brdTile, rel0, []);
                    brdTile.registerRelation(cOther, rel1, []);
                }
            }
        }
    }

    //set pre 2.0.0 relations
    var pre2_0_0TilesNoRelations = [];
    for(var i in pre2_0_0Tiles) {
        var ts = pre2_0_0Tiles[i];
        for(var j in ts) {
            if(ts[j][0].getRelations().length == 0) {
                if(pre2_0_0TilesNoRelations[i] == null) {
                    pre2_0_0TilesNoRelations[i] = [];
                }
                pre2_0_0TilesNoRelations[i].push(ts[j]);
            }
        }
    }
    for(var i in pre2_0_0TilesNoRelations) {
        var ts = pre2_0_0TilesNoRelations[i];
        for(var j in ts) {
            for(var k in ts) {
                ts[j][0].registerRelation(ts[k][0], ts[j][1], []);
            }
        }
    }

    var changePos = [];
    for(var i in data.set) {
        var setTileSave = data.set[i];
        var ttile = tiles[setTileSave.tileID];
        //ttile.inSet = true;
        ttile.reference();
        set.setTile(ttile, setTileSave.pos.x, setTileSave.pos.y);
        changePos.push({x:setTileSave.pos.x, y:setTileSave.pos.y});
    }
    tileChangedSetCallback.notify(changePos);

    for(var i in data.set_regions) {
        var regionSave = data.set_regions[i];
        if(regionSave.type === "sync") {
            var region = new RegionSync(regionSave.bounds.x0, regionSave.bounds.y0, regionSave.filename, regionSave.bounds.x1, regionSave.bounds.y1);
            set.addRegion(region);
            region.initRegion();
            regionAddedSetCallback.notify(region);
        }
    }

    sandbox.addLayer();
    layerAddedSandboxCallback.notify(sandbox.getLayers().length-1);
    for(var i in data.sandbox) {
        var sandboxTileSave = data.sandbox[i];
        var tile = tiles[sandboxTileSave.tileID];
        tile.sandboxRefs[getTileKey(sandboxTileSave.pos.x, sandboxTileSave.pos.y, 0)] = {x:sandboxTileSave.pos.x, y:sandboxTileSave.pos.y, z:0};
        sandbox.setTile(tile, sandboxTileSave.pos.x, sandboxTileSave.pos.y);
        tileChangedSandboxCallback.notify(sandboxTileSave.pos.x, sandboxTileSave.pos.y, 0);
    }
}

var loadData_5 = function(data) {
    // -----PRE 2.0.0-----
    // -----PRE 2.0.0-----
    // -----PRE 2.0.0-----
    setTileShape(Shape.ORTHOGRAPHIC);
    setTileSize(data.tilesize);
    
    var sources = [];
    for(var i in data.sources) {
        var sourceSave = data.sources[i];
        if(sourceSave.type === "image") {
            var src = new SourceImage(nativeImage.createFromDataURL(sourceSave.url));
            sources[i] = src;
        }
    }

    var bsets = [];
    var bsetsBase = []
    for(var i in data.bsets) {
        var bsetSave = data.bsets[i];
        if(bsetSave.type === "blob") {
            var bsetConfig = [];
            for(var di = 1; di < bsetSave.data.length; di++) {
                var bsetConfigRow = {src:sources[bsetSave.data[di].srcID], r:bsetSave.data[di].r, fx:bsetSave.data[di].fx, fy:bsetSave.data[di].fy};
                if(bsetSave.data[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = bsetSave.data[di].cutoff;
                }
                if(bsetSave.data[di].c != null) {
                    bsetConfigRow['c'] = bsetSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetBlob(bsetConfig);
            bsets[i] = bset;
            bsetsBase[i] = sources[bsetSave.data[0].srcID];
        } else if(bsetSave.type === "wang") {
            var bsetConfig = [];
            for(var di = 2; di < bsetSave.data.length; di++) {
                var bsetConfigRow = {src:sources[bsetSave.data[di].srcID], r:bsetSave.data[di].r, fx:bsetSave.data[di].fx, fy:bsetSave.data[di].fy};
                if(bsetSave.data[di].c != null) {
                    bsetConfigRow['c'] = bsetSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetWang(bsetConfig);
            bsets[i] = bset;
            bsetsBase[i] = [sources[bsetSave.data[0].srcID], sources[bsetSave.data[1].srcID]];
        }
    }

    var tiles = [];
    var pre2_0_0Tiles = [];
    for(var i in data.tiles) {
        var tileSave = data.tiles[i];
        if(tileSave.type === "base") {
            var tile = new TileBase(sources[tileSave.sourceID]);
            tiles[i] = tile;
        } else if(tileSave.type === "border") {
            var tile;
            if(bsets[tileSave.bsetID] instanceof BorderSetBlob) {
                tile = new TileBorder(new BorderGeneratorBlob());
                if(pre2_0_0Tiles[tileSave.bsetID] == null) {
                    pre2_0_0Tiles[tileSave.bsetID] = [];
                }
                pre2_0_0Tiles[tileSave.bsetID].push([tile, new TileRelationBlobPre2_0_0(bsets[tileSave.bsetID], tileSave.btype, new TileBase(bsetsBase[tileSave.bsetID]))]);
            } else if(bsets[tileSave.bsetID] instanceof BorderSetWang) {
                tile = new TileBorder(new BorderGeneratorWang());
                if(pre2_0_0Tiles[tileSave.bsetID] == null) {
                    pre2_0_0Tiles[tileSave.bsetID] = [];
                }
                pre2_0_0Tiles[tileSave.bsetID].push([tile, new TileRelationWangPre2_0_0(bsets[tileSave.bsetID], tileSave.btype, new TileBase(bsetsBase[tileSave.bsetID][0]), new TileBase(bsetsBase[tileSave.bsetID][1]))]);
            }
            tiles[i] = tile;
        }
    }

    //convert tile config to post 2.0.0
    var pre2_0_0isProp = function(ts) {
        if(ts.mode == 0 && (ts.pComponents.length > 0 || ts.bgID != -1)) {
            return true;
        }
        return false;
    }
    var pre2_0_0isBlob = function(ts) {
        if(ts.mode == 1 && ts.bBlob.length > 0) {
            return true;
        }
        return false;
    }
    var pre2_0_0isWang = function(ts) {
        if(ts.mode == 2) {
            for(var i in ts.bWang) {
                var other = ts.bWang[i].otherID;
                if(data.tiles[other].mode == 2) {
                    return true;
                }
            }
        }
        return false;
    }
    for(var i in data.tiles) {
        var tileSave = data.tiles[i];
        var cTile = tiles[i];
        if(tileSave.type === "border") {
            continue; //generated tiles cannot be blob masters, wang masters or prop components
        }

        if(pre2_0_0isProp(tileSave)) { //prop
            //TODO
            //TODO
            //TODO
            //TODO
            for(var k in tileSave.pComponents) {
                var pTile = data.tiles[tileSave.pComponents[k].tileID];
                var cOther = tiles[tileSave.pComponents[k].tileID];
                if(pTile.mode != 0 || pTile.type === "border") {
                    continue; // prop relation with non-prop tile or with generated tile
                }
                var pos = tileSave.pComponents[k].pos;
                cTile.registerRelation(cOther, new TileRelationProp(pos.x, pos.y), []);
            }
            //set background
            if(tileSave.bgID != -1) {
                if(tileSave.pComponents.length == 0) {
                    cTile.registerRelation(false, new TileRelationProp(0, 0), []);
                }
                var bgTile = tiles[tileSave.bgID];
                var bgData = data.tiles[tileSave.bgID];
                if(pre2_0_0isBlob(bgData)
                || pre2_0_0isWang(bgData)) {
                    cTile.registerRelation(bgTile, new TileRelationPropBackground(false), []);
                    bgTile.registerRelation(cTile, new TileRelationPropBackground(true), []);
                }
            }
        } else if(pre2_0_0isBlob(tileSave)) { //blob
            //create relation base->false
            //get bset for relation
            //save valid borders to add later
            var bset = null;
            var borders = [];
            for(var k in tileSave.bBlob) {
                var bTile = data.tiles[tileSave.bBlob[k].tileID];
                if(pre2_0_0isProp(bTile) /*prop*/
                || pre2_0_0isBlob(bTile) /*blob*/
                || pre2_0_0isWang(bTile) /*wang*/) {
                    continue; //not eligible
                }
                borders.push(tileSave.bBlob[k]);
                if(bTile.type === "border") {
                    bset = bsets[bTile.bsetID];
                }
            }
            if(bset == null) {
                bset = new BorderSetBlob();
            } else {
                var bsetSources = bset.getSources();
                var bsetConfig = [
                    {src:bsetSources[0], r:bset.getRotation(0), fx:bset.getFlipX(0), fy:bset.getFlipY(0), cutoff:bset.getCutoff(0)},
                    {src:bsetSources[1], r:bset.getRotation(1), fx:bset.getFlipX(1), fy:bset.getFlipY(1), cutoff:bset.getCutoff(1)},
                    {src:bsetSources[2], r:bset.getRotation(2), fx:bset.getFlipX(2), fy:bset.getFlipY(2), cutoff:bset.getCutoff(2)},
                    {src:bsetSources[3], r:bset.getRotation(3), fx:bset.getFlipX(3), fy:bset.getFlipY(3), cutoff:bset.getCutoff(3)},
                    {src:bsetSources[4], r:bset.getRotation(4), fx:bset.getFlipX(4), fy:bset.getFlipY(4), c:bset.getComposite(4)},
                    {src:bsetSources[5], r:bset.getRotation(5), fx:bset.getFlipX(5), fy:bset.getFlipY(5), c:bset.getComposite(5)},
                    {src:bsetSources[6], r:bset.getRotation(6), fx:bset.getFlipX(6), fy:bset.getFlipY(6), c:bset.getComposite(6)},
                    {src:bsetSources[7], r:bset.getRotation(7), fx:bset.getFlipX(7), fy:bset.getFlipY(7), c:bset.getComposite(7)},
                    {src:bsetSources[8], r:bset.getRotation(8), fx:bset.getFlipX(8), fy:bset.getFlipY(8), c:bset.getComposite(8)},
                    {src:bsetSources[9], r:bset.getRotation(9), fx:bset.getFlipX(9), fy:bset.getFlipY(9), c:bset.getComposite(9)},
                    {src:bsetSources[10], r:bset.getRotation(10), fx:bset.getFlipX(10), fy:bset.getFlipY(10), c:bset.getComposite(10)},
                    {src:bsetSources[11], r:bset.getRotation(11), fx:bset.getFlipX(11), fy:bset.getFlipY(11), c:bset.getComposite(11)}
                ];
                bset = new BorderSetBlob(bsetConfig);
            }
            //create relation
            cTile.registerRelation(false, new TileRelationBlob(bset, cTile), []);
            //append borders
            for(var k in borders) {
                var bTile = borders[k];
                var brdTile = tiles[bTile.tileID];
                if(brdTile.getRelations().length > 0) {
                    continue; //skip tiles that have been added as border to another base tile
                }
                //get indexMatrix;
                var newIndex = [0, 1, 2, 7, 3, 6, 5, 4];
                var indexMatrix = [false, false, false, false, false, false, false, false];
                for(var a = 0; a < 8; a++) {
                    if((bTile.i & (1 << a)) != 0) {
                        indexMatrix[newIndex[a]] = cTile;
                    }
                }
                for(var i = 0; i < 4; i++) {
                    if(indexMatrix[(i*2+7)%8] != cTile || indexMatrix[(i*2+1)%8] != cTile) {
                        indexMatrix[i*2] = null;
                    }
                }
                cTile.registerRelation(brdTile, new TileRelationBlobBorder(indexMatrix, false), []);
                brdTile.registerRelation(cTile, new TileRelationBlobBorder(indexMatrix, true), []);
            }
        } else if(pre2_0_0isWang(tileSave)) { //wang
            //get wang pairs
            var pairs = [];
            for(var k in tileSave.bWang) {
                var other = tileSave.bWang[k].otherID;
                if(data.tiles[other].mode != 2) {
                    continue; //pair with a non-wang tile
                }
                if(pairs.indexOf(other) == -1) {
                    pairs.push(other);
                }
            }
            for(var p in pairs) {
                var other = pairs[p];
                var cOther = tiles[other];
                if(cOther.getRelation(cTile) != null) {
                    continue; //skip pairs that have already been connected
                }
                //create relation base0->base1
                //get bset for relation
                //save valid borders to add later
                var bset = null;
                var borders = [];
                for(var k in tileSave.bWang) {
                    if(tileSave.bWang[k].otherID != other) {
                        continue;
                    }
                    var bTile = data.tiles[tileSave.bWang[k].tileID];
                    if(pre2_0_0isProp(bTile) /*prop*/
                    || pre2_0_0isBlob(bTile) /*blob*/
                    || pre2_0_0isWang(bTile) /*wang*/) {
                        continue; //not eligible
                    }
                    borders.push(tileSave.bWang[k]);
                    if(bTile.type === "border") {
                        bset = bsets[bTile.bsetID];
                    }
                }
                if(bset == null) {
                    bset = new BorderSetWang();
                } else {
                    var bsetSources = bset.getSources();
                    var bsetConfig = [
                        {src:bsetSources[0], r:bset.getRotation(0), fx:bset.getFlipX(0), fy:bset.getFlipY(0)},
                        {src:bsetSources[1], r:bset.getRotation(1), fx:bset.getFlipX(1), fy:bset.getFlipY(1)},
                        {src:bsetSources[2], r:bset.getRotation(2), fx:bset.getFlipX(2), fy:bset.getFlipY(2)},
                        {src:bsetSources[3], r:bset.getRotation(3), fx:bset.getFlipX(3), fy:bset.getFlipY(3)},
                        {src:bsetSources[4], r:bset.getRotation(4), fx:bset.getFlipX(4), fy:bset.getFlipY(4), c:bset.getComposite(4)},
                        {src:bsetSources[5], r:bset.getRotation(5), fx:bset.getFlipX(5), fy:bset.getFlipY(5), c:bset.getComposite(5)},
                        {src:bsetSources[6], r:bset.getRotation(6), fx:bset.getFlipX(6), fy:bset.getFlipY(6), c:bset.getComposite(6)},
                        {src:bsetSources[7], r:bset.getRotation(7), fx:bset.getFlipX(7), fy:bset.getFlipY(7), c:bset.getComposite(7)},
                        {src:bsetSources[8], r:bset.getRotation(8), fx:bset.getFlipX(8), fy:bset.getFlipY(8), c:bset.getComposite(8)},
                        {src:bsetSources[9], r:bset.getRotation(9), fx:bset.getFlipX(9), fy:bset.getFlipY(9), c:bset.getComposite(9)},
                        {src:bsetSources[10], r:bset.getRotation(10), fx:bset.getFlipX(10), fy:bset.getFlipY(10), c:bset.getComposite(10)},
                        {src:bsetSources[11], r:bset.getRotation(11), fx:bset.getFlipX(11), fy:bset.getFlipY(11), c:bset.getComposite(11)},
                    ];
                    bset = new BorderSetWang(bsetConfig);
                }
                //create relation
                var rel = new TileRelationWang(bset, cTile);
                cTile.registerRelation(cOther, rel, []);
                cOther.registerRelation(cTile, rel, []);
                //append borders
                for(var k in borders) {
                    var bTile = borders[k];
                    var brdTile = tiles[bTile.tileID];
                    if(brdTile.getRelations().length > 0) {
                        continue; //skip tiles that have been added as border to another base tile
                    }
                    //get indexMatrix;
                    var newIndex = [0, 1, 3, 2];
                    var indexMatrix = [cOther, cOther, cOther, cOther];
                    for(var a = 0; a < 4; a++) {
                        if((bTile.i & (1 << a)) != 0) {
                            indexMatrix[newIndex[a]] = cTile;
                        }
                    }

                    var rel0 = new TileRelationWangBorder(indexMatrix, false);
                    var rel1 = new TileRelationWangBorder(indexMatrix, true);
                    cTile.registerRelation(brdTile, rel0, []);
                    brdTile.registerRelation(cTile, rel1, []);
                    cOther.registerRelation(brdTile, rel0, []);
                    brdTile.registerRelation(cOther, rel1, []);
                }
            }
        }
    }

    //set pre 2.0.0 relations
    var pre2_0_0TilesNoRelations = [];
    for(var i in pre2_0_0Tiles) {
        var ts = pre2_0_0Tiles[i];
        for(var j in ts) {
            if(ts[j][0].getRelations().length == 0) {
                if(pre2_0_0TilesNoRelations[i] == null) {
                    pre2_0_0TilesNoRelations[i] = [];
                }
                pre2_0_0TilesNoRelations[i].push(ts[j]);
            }
        }
    }
    for(var i in pre2_0_0TilesNoRelations) {
        var ts = pre2_0_0TilesNoRelations[i];
        for(var j in ts) {
            for(var k in ts) {
                ts[j][0].registerRelation(ts[k][0], ts[j][1], []);
            }
        }
    }

    var changePos = [];
    for(var i in data.set) {
        var setTileSave = data.set[i];
        var ttile = tiles[setTileSave.tileID];
        //ttile.inSet = true;
        ttile.reference();
        set.setTile(ttile, setTileSave.pos.x, setTileSave.pos.y);
        changePos.push({x:setTileSave.pos.x, y:setTileSave.pos.y});
    }
    tileChangedSetCallback.notify(changePos);

    for(var i in data.set_regions) {
        var regionSave = data.set_regions[i];
        if(regionSave.type === "sync") {
            var region = new RegionSync(regionSave.bounds.x0, regionSave.bounds.y0, regionSave.filename, regionSave.bounds.x1, regionSave.bounds.y1);
            var cachedTiles = regionSave.syncTiles;
            for(var k in cachedTiles) {
                var cachedTile = cachedTiles[k];
                if(cachedTile.type == "tile") {
                    region.setCacheTile(tiles[cachedTile.data], cachedTile.pos.x, cachedTile.pos.y);
                } else if(cachedTile.type == "source") {
                    region.setCacheSource(sources[cachedTile.data], cachedTile.pos.x, cachedTile.pos.y);
                }
            }
            set.addRegion(region);
            region.initRegion();
            regionAddedSetCallback.notify(region);
        }
    }

    sandbox.addLayer();
    layerAddedSandboxCallback.notify(sandbox.getLayers().length-1);
    for(var i in data.sandbox) {
        var sandboxTileSave = data.sandbox[i];
        var tile = tiles[sandboxTileSave.tileID];
        tile.sandboxRefs[getTileKey(sandboxTileSave.pos.x, sandboxTileSave.pos.y, 0)] = {x:sandboxTileSave.pos.x, y:sandboxTileSave.pos.y, z:0};
        sandbox.setTile(tile, sandboxTileSave.pos.x, sandboxTileSave.pos.y);
        tileChangedSandboxCallback.notify(sandboxTileSave.pos.x, sandboxTileSave.pos.y, 0);
    }
}

var loadData_6 = function(data) {
    setTileShape(Shape.ORTHOGRAPHIC);
    setTileSize(data.tilesize);
    
    var sources = [];
    for(var i in data.sources) {
        var sourceSave = data.sources[i];
        if(sourceSave.type === "image") {
            var src = new SourceImage(nativeImage.createFromDataURL(sourceSave.url));
            sources[i] = src;
        }
    }

    var tiles = [];
    for(var i in data.tiles) {
        var tileSave = data.tiles[i];
        if(tileSave.type === "base") {
            var tile = new TileBase(sources[tileSave.sourceID]);
            tiles[i] = tile;
        } else if(tileSave.type === "blob") {
            var tile = new TileBorder(new BorderGeneratorBlob());
            tiles[i] = tile;
        } else if(tileSave.type === "wang") {
            var tile = new TileBorder(new BorderGeneratorWang());
            tiles[i] = tile;
        }
    }

    var relations = [];
    for(var i in data.relations) {
        var relationsSave = data.relations[i];
        if(relationsSave.type === "blob") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.data.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.data[di].srcID], r:relationsSave.data[di].r, fx:relationsSave.data[di].fx, fy:relationsSave.data[di].fy};
                if(relationsSave.data[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = relationsSave.data[di].cutoff;
                }
                if(relationsSave.data[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetBlob(bsetConfig);
            relations[i] = new TileRelationBlob(bset, tiles[relationsSave.origin]);
        } else if(relationsSave.type === "blob_border") {
            var indexMatrix = [];
            for(var k in relationsSave.matrix) {
                if(relationsSave.matrix[k] === false) {
                    indexMatrix.push(false);
                } else {
                    indexMatrix.push(tiles[relationsSave.matrix[k]]);
                }
            }
            relations[i] = new TileRelationBlobBorder(indexMatrix, relationsSave.isBorder);
        } else if(relationsSave.type === "wang") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.data.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.data[di].srcID], r:relationsSave.data[di].r, fx:relationsSave.data[di].fx, fy:relationsSave.data[di].fy};
                if(relationsSave.data[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetWang(bsetConfig);
            relations[i] = new TileRelationWang(bset, tiles[relationsSave.origin]);
        } else if(relationsSave.type === "wang_border") {
            var indexMatrix = [];
            for(var k in relationsSave.matrix) {
                if(relationsSave.matrix[k] === false) {
                    indexMatrix.push(false);
                } else {
                    indexMatrix.push(tiles[relationsSave.matrix[k]]);
                }
            }
            relations[i] = new TileRelationWangBorder(indexMatrix, relationsSave.isBorder);
        } else if(relationsSave.type === "blob_pre_2_0_0") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.bset.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.bset[di].srcID], r:relationsSave.bset[di].r, fx:relationsSave.bset[di].fx, fy:relationsSave.bset[di].fy};
                if(relationsSave.bset[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = relationsSave.bset[di].cutoff;
                }
                if(relationsSave.bset[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.bset[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetBlob(bsetConfig);
            relations[i] = new TileRelationBlobPre2_0_0(bset, relationsSave.i, new TileBase(sources[relationsSave.baseSrcID]));
        } else if(relationsSave.type === "wang_pre_2_0_0") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.bset.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.bset[di].srcID], r:relationsSave.bset[di].r, fx:relationsSave.bset[di].fx, fy:relationsSave.bset[di].fy};
                if(relationsSave.bset[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.bset[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetWang(bsetConfig);
            relations[i] = new TileRelationWangPre2_0_0(bset, relationsSave.i, new TileBase(sources[relationsSave.baseSrc0ID]), new TileBase(sources[relationsSave.baseSrc1ID]));
        }
    }

    for(var i = data.tileRelations.length-1; i >= 0; i--) {
        var rel = data.tileRelations[i];
        if(relations[rel.r] == null) {
            continue;
        }
        var other;
        if(rel.other === false) {
            other = false;
        } else {
            other = tiles[rel.other];
        }
        tiles[rel.tile].setRelation(other, relations[rel.r]);
    }

    var changePos = [];
    for(var i in data.set) {
        var setTileSave = data.set[i];
        var ttile = tiles[setTileSave.tileID];
        //ttile.inSet = true;
        ttile.reference();
        set.setTile(ttile, setTileSave.pos.x, setTileSave.pos.y);
        changePos.push({x:setTileSave.pos.x, y:setTileSave.pos.y});
    }
    tileChangedSetCallback.notify(changePos);

    sandbox.addLayer();
    layerAddedSandboxCallback.notify(sandbox.getLayers().length-1);
}

var loadData_7 = function(data, srcFn) {
    setTileShape(Shape.ORTHOGRAPHIC);
    setTileSize(data.tilesize);
    
    var sources = [];
    for(var i in data.sources) {
        var sourceSave = data.sources[i];
        if(sourceSave.type === "image") {
            var src = new SourceImage(nativeImage.createFromDataURL(sourceSave.url));
            sources[i] = src;
        }
    }

    var tiles = [];
    for(var i in data.tiles) {
        var tileSave = data.tiles[i];
        if(tileSave.type === "base") {
            var tile = new TileBase(sources[tileSave.sourceID]);
            tiles[i] = tile;
        } else if(tileSave.type === "blob") {
            var tile = new TileBorder(new BorderGeneratorBlob());
            tiles[i] = tile;
        } else if(tileSave.type === "wang") {
            var tile = new TileBorder(new BorderGeneratorWang());
            tiles[i] = tile;
        }
    }

    var relations = [];
    for(var i in data.relations) {
        var relationsSave = data.relations[i];
        if(relationsSave.type === "blob") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.data.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.data[di].srcID], r:relationsSave.data[di].r, fx:relationsSave.data[di].fx, fy:relationsSave.data[di].fy};
                if(relationsSave.data[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = relationsSave.data[di].cutoff;
                }
                if(relationsSave.data[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetBlob(bsetConfig);
            relations[i] = new TileRelationBlob(bset, tiles[relationsSave.origin]);
        } else if(relationsSave.type === "blob_border") {
            var indexMatrix = [];
            for(var k in relationsSave.matrix) {
                if(relationsSave.matrix[k] === false) {
                    indexMatrix.push(false);
                } else {
                    indexMatrix.push(tiles[relationsSave.matrix[k]]);
                }
            }
            relations[i] = new TileRelationBlobBorder(indexMatrix, relationsSave.isBorder);
        } else if(relationsSave.type === "wang") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.data.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.data[di].srcID], r:relationsSave.data[di].r, fx:relationsSave.data[di].fx, fy:relationsSave.data[di].fy};
                if(relationsSave.data[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetWang(bsetConfig);
            relations[i] = new TileRelationWang(bset, tiles[relationsSave.origin]);
        } else if(relationsSave.type === "wang_border") {
            var indexMatrix = [];
            for(var k in relationsSave.matrix) {
                if(relationsSave.matrix[k] === false) {
                    indexMatrix.push(false);
                } else {
                    indexMatrix.push(tiles[relationsSave.matrix[k]]);
                }
            }
            relations[i] = new TileRelationWangBorder(indexMatrix, relationsSave.isBorder);
        } else if(relationsSave.type === "prop") {
            relations[i] = new TileRelationProp(relationsSave.x, relationsSave.y);
        } else if(relationsSave.type === "prop_background") {
            relations[i] = new TileRelationPropBackground(relationsSave.isBackground);
        } else if(relationsSave.type === "proxy") {
            relations[i] = new TileRelationProxy(relationsSave.isReverse, relationsSave.weight);
        } else if(relationsSave.type === "blob_pre_2_0_0") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.bset.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.bset[di].srcID], r:relationsSave.bset[di].r, fx:relationsSave.bset[di].fx, fy:relationsSave.bset[di].fy};
                if(relationsSave.bset[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = relationsSave.bset[di].cutoff;
                }
                if(relationsSave.bset[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.bset[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetBlob(bsetConfig);
            relations[i] = new TileRelationBlobPre2_0_0(bset, relationsSave.i, new TileBase(sources[relationsSave.baseSrcID]));
        } else if(relationsSave.type === "wang_pre_2_0_0") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.bset.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.bset[di].srcID], r:relationsSave.bset[di].r, fx:relationsSave.bset[di].fx, fy:relationsSave.bset[di].fy};
                if(relationsSave.bset[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.bset[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetWang(bsetConfig);
            relations[i] = new TileRelationWangPre2_0_0(bset, relationsSave.i, new TileBase(sources[relationsSave.baseSrc0ID]), new TileBase(sources[relationsSave.baseSrc1ID]));
        }
    }

    for(var i = data.tileRelations.length-1; i >= 0; i--) {
        var rel = data.tileRelations[i];
        if(relations[rel.r] == null) {
            continue;
        }
        var other;
        if(rel.other === false) {
            other = false;
        } else {
            other = tiles[rel.other];
        }
        tiles[rel.tile].setRelation(other, relations[rel.r]);
    }

    var changePos = [];
    for(var i in data.set) {
        var setTileSave = data.set[i];
        var ttile = tiles[setTileSave.tileID];
        //ttile.inSet = true;
        ttile.reference();
        set.setTile(ttile, setTileSave.pos.x, setTileSave.pos.y);
        changePos.push({x:setTileSave.pos.x, y:setTileSave.pos.y});
    }
    tileChangedSetCallback.notify(changePos);

    for(var i in data.set_regions) {
        var regionSave = data.set_regions[i];
        if(regionSave.type === "sync") {
            var syncFn = path.resolve(srcFn, regionSave.filename); //convert relative path to absolute path
            var region = new RegionSync(regionSave.bounds.x0, regionSave.bounds.y0, syncFn, regionSave.bounds.x1, regionSave.bounds.y1);
            var cachedTiles = regionSave.syncTiles;
            for(var k in cachedTiles) {
                var cachedTile = cachedTiles[k];
                if(cachedTile.type == "tile") {
                    region.setCacheTile(tiles[cachedTile.data], cachedTile.pos.x, cachedTile.pos.y);
                } else if(cachedTile.type == "source") {
                    region.setCacheSource(sources[cachedTile.data], cachedTile.pos.x, cachedTile.pos.y);
                }
            }
            set.addRegion(region);
            region.initRegion();
            regionAddedSetCallback.notify(region);
        }
    }

    for(var i in data.sandbox_layers) {
        sandbox.addLayer(data.sandbox_layers[i].visible, data.sandbox_layers[i].name);
        layerAddedSandboxCallback.notify(sandbox.getLayers().length-1);
    }
    for(var i in data.sandbox) {
        var sandboxTileSave = data.sandbox[i];
        var tile = tiles[sandboxTileSave.tileID];
        tile.sandboxRefs[getTileKey(sandboxTileSave.pos.x, sandboxTileSave.pos.y, sandboxTileSave.pos.z)] = {x:sandboxTileSave.pos.x, y:sandboxTileSave.pos.y, z:sandboxTileSave.pos.z};
        sandbox.setTile(tile, sandboxTileSave.pos.x, sandboxTileSave.pos.y, sandboxTileSave.pos.z);
        tileChangedSandboxCallback.notify(sandboxTileSave.pos.x, sandboxTileSave.pos.y, sandboxTileSave.pos.z);
    }
}

var loadData_8 = function(data) {
    setTileShape(Shape.ORTHOGRAPHIC);
    setTileSize(data.tilesize);
    
    var sources = [];
    for(var i in data.sources) {
        var sourceSave = data.sources[i];
        if(sourceSave.type === "image") {
            var src = new SourceImage(nativeImage.createFromDataURL(sourceSave.url));
            sources[i] = src;
        }
    }

    var tiles = [];
    for(var i in data.tiles) {
        var tileSave = data.tiles[i];
        if(tileSave.type === "base") {
            var tile = new TileBase(sources[tileSave.sourceID]);
            tiles[i] = tile;
        } else if(tileSave.type === "blob") {
            var tile = new TileBorder(new BorderGeneratorBlob());
            tiles[i] = tile;
        } else if(tileSave.type === "wang") {
            var tile = new TileBorder(new BorderGeneratorWang());
            tiles[i] = tile;
        }
    }

    var relations = [];
    for(var i in data.relations) {
        var relationsSave = data.relations[i];
        if(relationsSave.type === "blob") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.data.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.data[di].srcID], r:relationsSave.data[di].r, fx:relationsSave.data[di].fx, fy:relationsSave.data[di].fy};
                if(relationsSave.data[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = relationsSave.data[di].cutoff;
                }
                if(relationsSave.data[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetBlob(bsetConfig);
            relations[i] = new TileRelationBlob(bset, tiles[relationsSave.origin]);
        } else if(relationsSave.type === "blob_border") {
            var indexMatrix = [];
            for(var k in relationsSave.matrix) {
                if(relationsSave.matrix[k] === false) {
                    indexMatrix.push(false);
                } else {
                    indexMatrix.push(tiles[relationsSave.matrix[k]]);
                }
            }
            relations[i] = new TileRelationBlobBorder(indexMatrix, relationsSave.isBorder);
        } else if(relationsSave.type === "wang") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.data.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.data[di].srcID], r:relationsSave.data[di].r, fx:relationsSave.data[di].fx, fy:relationsSave.data[di].fy};
                if(relationsSave.data[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = relationsSave.data[di].cutoff;
                }
                if(relationsSave.data[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetWang(bsetConfig);
            relations[i] = new TileRelationWang(bset, tiles[relationsSave.origin]);
        } else if(relationsSave.type === "wang_border") {
            var indexMatrix = [];
            for(var k in relationsSave.matrix) {
                if(relationsSave.matrix[k] === false) {
                    indexMatrix.push(false);
                } else {
                    indexMatrix.push(tiles[relationsSave.matrix[k]]);
                }
            }
            relations[i] = new TileRelationWangBorder(indexMatrix, relationsSave.isBorder);
        } else if(relationsSave.type === "blob_pre_2_0_0") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.bset.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.bset[di].srcID], r:relationsSave.bset[di].r, fx:relationsSave.bset[di].fx, fy:relationsSave.bset[di].fy};
                if(relationsSave.bset[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = relationsSave.bset[di].cutoff;
                }
                if(relationsSave.bset[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.bset[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetBlob(bsetConfig);
            relations[i] = new TileRelationBlobPre2_0_0(bset, relationsSave.i, new TileBase(sources[relationsSave.baseSrcID]));
        } else if(relationsSave.type === "wang_pre_2_0_0") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.bset.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.bset[di].srcID], r:relationsSave.bset[di].r, fx:relationsSave.bset[di].fx, fy:relationsSave.bset[di].fy};
                if(relationsSave.bset[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.bset[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetWang(bsetConfig);
            relations[i] = new TileRelationWangPre2_0_0(bset, relationsSave.i, new TileBase(sources[relationsSave.baseSrc0ID]), new TileBase(sources[relationsSave.baseSrc1ID]));
        }
    }

    for(var i = data.tileRelations.length-1; i >= 0; i--) {
        var rel = data.tileRelations[i];
        if(relations[rel.r] == null) {
            continue;
        }
        var other;
        if(rel.other === false) {
            other = false;
        } else {
            other = tiles[rel.other];
        }
        tiles[rel.tile].setRelation(other, relations[rel.r]);
    }

    var changePos = [];
    for(var i in data.set) {
        var setTileSave = data.set[i];
        var ttile = tiles[setTileSave.tileID];
        //ttile.inSet = true;
        ttile.reference();
        set.setTile(ttile, setTileSave.pos.x, setTileSave.pos.y);
        changePos.push({x:setTileSave.pos.x, y:setTileSave.pos.y});
    }
    tileChangedSetCallback.notify(changePos);

    sandbox.addLayer();
    layerAddedSandboxCallback.notify(sandbox.getLayers().length-1);
}

var loadData_9 = function(data, srcFn) {
    setTileShape(Shape.ORTHOGRAPHIC);
    setTileSize(data.tilesize);
    
    var sources = [];
    for(var i in data.sources) {
        var sourceSave = data.sources[i];
        if(sourceSave.type === "image") {
            var src = new SourceImage(nativeImage.createFromDataURL(sourceSave.url));
            sources[i] = src;
        }
    }

    var tiles = [];
    for(var i in data.tiles) {
        var tileSave = data.tiles[i];
        if(tileSave.type === "base") {
            var tile = new TileBase(sources[tileSave.sourceID]);
            tiles[i] = tile;
        } else if(tileSave.type === "blob") {
            var tile = new TileBorder(new BorderGeneratorBlob());
            tiles[i] = tile;
        } else if(tileSave.type === "wang") {
            var tile = new TileBorder(new BorderGeneratorWang());
            tiles[i] = tile;
        }
    }

    var relations = [];
    for(var i in data.relations) {
        var relationsSave = data.relations[i];
        if(relationsSave.type === "blob") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.data.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.data[di].srcID], r:relationsSave.data[di].r, fx:relationsSave.data[di].fx, fy:relationsSave.data[di].fy};
                if(relationsSave.data[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = relationsSave.data[di].cutoff;
                }
                if(relationsSave.data[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetBlob(bsetConfig);
            relations[i] = new TileRelationBlob(bset, tiles[relationsSave.origin]);
        } else if(relationsSave.type === "blob_border") {
            var indexMatrix = [];
            for(var k in relationsSave.matrix) {
                if(relationsSave.matrix[k] === false) {
                    indexMatrix.push(false);
                } else {
                    indexMatrix.push(tiles[relationsSave.matrix[k]]);
                }
            }
            relations[i] = new TileRelationBlobBorder(indexMatrix, relationsSave.isBorder);
        } else if(relationsSave.type === "wang") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.data.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.data[di].srcID], r:relationsSave.data[di].r, fx:relationsSave.data[di].fx, fy:relationsSave.data[di].fy};
                if(relationsSave.data[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = relationsSave.data[di].cutoff;
                }
                if(relationsSave.data[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetWang(bsetConfig);
            relations[i] = new TileRelationWang(bset, tiles[relationsSave.origin]);
        } else if(relationsSave.type === "wang_border") {
            var indexMatrix = [];
            for(var k in relationsSave.matrix) {
                if(relationsSave.matrix[k] === false) {
                    indexMatrix.push(false);
                } else {
                    indexMatrix.push(tiles[relationsSave.matrix[k]]);
                }
            }
            relations[i] = new TileRelationWangBorder(indexMatrix, relationsSave.isBorder);
        } else if(relationsSave.type === "prop") {
            relations[i] = new TileRelationProp(relationsSave.x, relationsSave.y);
        } else if(relationsSave.type === "prop_background") {
            relations[i] = new TileRelationPropBackground(relationsSave.isBackground);
        } else if(relationsSave.type === "proxy") {
            relations[i] = new TileRelationProxy(relationsSave.isReverse, relationsSave.weight);
        } else if(relationsSave.type === "blob_pre_2_0_0") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.bset.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.bset[di].srcID], r:relationsSave.bset[di].r, fx:relationsSave.bset[di].fx, fy:relationsSave.bset[di].fy};
                if(relationsSave.bset[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = relationsSave.bset[di].cutoff;
                }
                if(relationsSave.bset[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.bset[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetBlob(bsetConfig);
            relations[i] = new TileRelationBlobPre2_0_0(bset, relationsSave.i, new TileBase(sources[relationsSave.baseSrcID]));
        } else if(relationsSave.type === "wang_pre_2_0_0") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.bset.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.bset[di].srcID], r:relationsSave.bset[di].r, fx:relationsSave.bset[di].fx, fy:relationsSave.bset[di].fy};
                if(relationsSave.bset[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.bset[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetWang(bsetConfig);
            relations[i] = new TileRelationWangPre2_0_0(bset, relationsSave.i, new TileBase(sources[relationsSave.baseSrc0ID]), new TileBase(sources[relationsSave.baseSrc1ID]));
        }
    }

    for(var i = data.tileRelations.length-1; i >= 0; i--) {
        var rel = data.tileRelations[i];
        if(relations[rel.r] == null) {
            continue;
        }
        var other;
        if(rel.other === false) {
            other = false;
        } else {
            other = tiles[rel.other];
        }
        tiles[rel.tile].setRelation(other, relations[rel.r]);
    }

    var changePos = [];
    for(var i in data.set) {
        var setTileSave = data.set[i];
        var ttile = tiles[setTileSave.tileID];
        //ttile.inSet = true;
        ttile.reference();
        set.setTile(ttile, setTileSave.pos.x, setTileSave.pos.y);
        changePos.push({x:setTileSave.pos.x, y:setTileSave.pos.y});
    }
    tileChangedSetCallback.notify(changePos);

    for(var i in data.set_regions) {
        var regionSave = data.set_regions[i];
        if(regionSave.type === "sync") {
            var syncFn = path.resolve(srcFn, regionSave.filename); //convert relative path to absolute path
            var region = new RegionSync(regionSave.bounds.x0, regionSave.bounds.y0, syncFn, regionSave.bounds.x1, regionSave.bounds.y1);
            var cachedTiles = regionSave.syncTiles;
            for(var k in cachedTiles) {
                var cachedTile = cachedTiles[k];
                if(cachedTile.type == "tile") {
                    region.setCacheTile(tiles[cachedTile.data], cachedTile.pos.x, cachedTile.pos.y);
                } else if(cachedTile.type == "source") {
                    region.setCacheSource(sources[cachedTile.data], cachedTile.pos.x, cachedTile.pos.y);
                }
            }
            set.addRegion(region);
            region.initRegion();
            regionAddedSetCallback.notify(region);
        }
    }

    for(var i in data.sandbox_layers) {
        sandbox.addLayer(data.sandbox_layers[i].visible, data.sandbox_layers[i].name);
        layerAddedSandboxCallback.notify(sandbox.getLayers().length-1);
    }
    for(var i in data.sandbox) {
        var sandboxTileSave = data.sandbox[i];
        var tile = tiles[sandboxTileSave.tileID];
        tile.sandboxRefs[getTileKey(sandboxTileSave.pos.x, sandboxTileSave.pos.y, sandboxTileSave.pos.z)] = {x:sandboxTileSave.pos.x, y:sandboxTileSave.pos.y, z:sandboxTileSave.pos.z};
        sandbox.setTile(tile, sandboxTileSave.pos.x, sandboxTileSave.pos.y, sandboxTileSave.pos.z);
        tileChangedSandboxCallback.notify(sandboxTileSave.pos.x, sandboxTileSave.pos.y, sandboxTileSave.pos.z);
    }
}

var loadData_10 = function(data, srcFn) {
    setTileShape(data.tileshape);
    if(data.tileshape == Shape.ORTHOGRAPHIC) {
        setTileSize(data.tilewidth);
    } else if(data.tileshape == Shape.ISOMETRIC) {
        setTileSize([data.tilewidth, data.tileheight]);
    }
    
    var sources = [];
    for(var i in data.sources) {
        var sourceSave = data.sources[i];
        if(sourceSave.type === "image") {
            var src = new SourceImage(nativeImage.createFromDataURL(sourceSave.url));
            sources[i] = src;
        }
    }

    var tiles = [];
    for(var i in data.tiles) {
        var tileSave = data.tiles[i];
        if(tileSave.type === "base") {
            var tile = new TileBase(sources[tileSave.sourceID]);
            tiles[i] = tile;
        } else if(tileSave.type === "blob") {
            var tile = new TileBorder(new BorderGeneratorBlob());
            tiles[i] = tile;
        } else if(tileSave.type === "wang") {
            var tile = new TileBorder(new BorderGeneratorWang());
            tiles[i] = tile;
        }
    }

    var relations = [];
    for(var i in data.relations) {
        var relationsSave = data.relations[i];
        if(relationsSave.type === "blob") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.data.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.data[di].srcID], r:relationsSave.data[di].r, fx:relationsSave.data[di].fx, fy:relationsSave.data[di].fy};
                if(relationsSave.data[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = relationsSave.data[di].cutoff;
                }
                if(relationsSave.data[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetBlob(bsetConfig);
            relations[i] = new TileRelationBlob(bset, tiles[relationsSave.origin]);
        } else if(relationsSave.type === "blob_border") {
            var indexMatrix = [];
            for(var k in relationsSave.matrix) {
                if(relationsSave.matrix[k] === false) {
                    indexMatrix.push(false);
                } else {
                    indexMatrix.push(tiles[relationsSave.matrix[k]]);
                }
            }
            relations[i] = new TileRelationBlobBorder(indexMatrix, relationsSave.isBorder);
        } else if(relationsSave.type === "wang") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.data.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.data[di].srcID], r:relationsSave.data[di].r, fx:relationsSave.data[di].fx, fy:relationsSave.data[di].fy};
                if(relationsSave.data[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = relationsSave.data[di].cutoff;
                }
                if(relationsSave.data[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.data[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetWang(bsetConfig);
            relations[i] = new TileRelationWang(bset, tiles[relationsSave.origin]);
        } else if(relationsSave.type === "wang_border") {
            var indexMatrix = [];
            for(var k in relationsSave.matrix) {
                if(relationsSave.matrix[k] === false) {
                    indexMatrix.push(false);
                } else {
                    indexMatrix.push(tiles[relationsSave.matrix[k]]);
                }
            }
            relations[i] = new TileRelationWangBorder(indexMatrix, relationsSave.isBorder);
        } else if(relationsSave.type === "prop") {
            relations[i] = new TileRelationProp(relationsSave.x, relationsSave.y);
        } else if(relationsSave.type === "prop_background") {
            relations[i] = new TileRelationPropBackground(relationsSave.isBackground);
        } else if(relationsSave.type === "proxy") {
            relations[i] = new TileRelationProxy(relationsSave.isReverse, relationsSave.weight);
        } else if(relationsSave.type === "blob_pre_2_0_0") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.bset.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.bset[di].srcID], r:relationsSave.bset[di].r, fx:relationsSave.bset[di].fx, fy:relationsSave.bset[di].fy};
                if(relationsSave.bset[di].cutoff != null) {
                    bsetConfigRow['cutoff'] = relationsSave.bset[di].cutoff;
                }
                if(relationsSave.bset[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.bset[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetBlob(bsetConfig);
            relations[i] = new TileRelationBlobPre2_0_0(bset, relationsSave.i, new TileBase(sources[relationsSave.baseSrcID]));
        } else if(relationsSave.type === "wang_pre_2_0_0") {
            var bsetConfig = [];
            for(var di = 0; di < relationsSave.bset.length; di++) {
                var bsetConfigRow = {src:sources[relationsSave.bset[di].srcID], r:relationsSave.bset[di].r, fx:relationsSave.bset[di].fx, fy:relationsSave.bset[di].fy};
                if(relationsSave.bset[di].c != null) {
                    bsetConfigRow['c'] = relationsSave.bset[di].c;
                }
                bsetConfig.push(bsetConfigRow);
            }
            var bset = new BorderSetWang(bsetConfig);
            relations[i] = new TileRelationWangPre2_0_0(bset, relationsSave.i, new TileBase(sources[relationsSave.baseSrc0ID]), new TileBase(sources[relationsSave.baseSrc1ID]));
        }
    }

    for(var i = data.tileRelations.length-1; i >= 0; i--) {
        var rel = data.tileRelations[i];
        if(relations[rel.r] == null) {
            continue;
        }
        var other;
        if(rel.other === false) {
            other = false;
        } else {
            other = tiles[rel.other];
        }
        tiles[rel.tile].setRelation(other, relations[rel.r]);
    }

    var changePos = [];
    for(var i in data.set) {
        var setTileSave = data.set[i];
        var ttile = tiles[setTileSave.tileID];
        //ttile.inSet = true;
        ttile.reference();
        set.setTile(ttile, setTileSave.pos.x, setTileSave.pos.y);
        changePos.push({x:setTileSave.pos.x, y:setTileSave.pos.y});
    }
    tileChangedSetCallback.notify(changePos);

    for(var i in data.set_regions) {
        var regionSave = data.set_regions[i];
        if(regionSave.type === "sync") {
            var syncFn = path.resolve(srcFn, regionSave.filename); //convert relative path to absolute path
            var region = new RegionSync(regionSave.bounds.x0, regionSave.bounds.y0, syncFn, regionSave.bounds.x1, regionSave.bounds.y1);
            var cachedTiles = regionSave.syncTiles;
            for(var k in cachedTiles) {
                var cachedTile = cachedTiles[k];
                if(cachedTile.type == "tile") {
                    region.setCacheTile(tiles[cachedTile.data], cachedTile.pos.x, cachedTile.pos.y);
                } else if(cachedTile.type == "source") {
                    region.setCacheSource(sources[cachedTile.data], cachedTile.pos.x, cachedTile.pos.y);
                }
            }
            set.addRegion(region);
            region.initRegion();
            regionAddedSetCallback.notify(region);
        }
    }

    for(var i in data.sandbox_layers) {
        sandbox.addLayer(data.sandbox_layers[i].visible, data.sandbox_layers[i].name);
        layerAddedSandboxCallback.notify(sandbox.getLayers().length-1);
    }
    for(var i in data.sandbox) {
        var sandboxTileSave = data.sandbox[i];
        var tile = tiles[sandboxTileSave.tileID];
        tile.sandboxRefs[getTileKey(sandboxTileSave.pos.x, sandboxTileSave.pos.y, sandboxTileSave.pos.z)] = {x:sandboxTileSave.pos.x, y:sandboxTileSave.pos.y, z:sandboxTileSave.pos.z};
        sandbox.setTile(tile, sandboxTileSave.pos.x, sandboxTileSave.pos.y, sandboxTileSave.pos.z);
        tileChangedSandboxCallback.notify(sandboxTileSave.pos.x, sandboxTileSave.pos.y, sandboxTileSave.pos.z);
    }
}

var onNewCallback = new CallbackManager();
var onNewSubscribe = function(func) {
    onNewCallback.subscribe(func);
}
exports.onNewSubscribe = onNewSubscribe;

var onLoadCallback = new CallbackManager();
var onLoadSubscribe = function(func) {
    onLoadCallback.subscribe(func);
}
exports.onLoadSubscribe = onLoadSubscribe;

var onSaveCallback = new CallbackManager();
var onSaveSubscribe = function(func) {
    onSaveCallback.subscribe(func);
}
exports.onSaveSubscribe = onSaveSubscribe;

var saveData = function(fn, onSaved=null) {
    if (!fn.endsWith('.json') && !fn.endsWith('.tset')) {
        fn = `${fn}.json`;
    }
    var extra = {};
    onSaveCallback.notify(extra);

    snapshotData(null, null, fn).then(function(data) {
        var save = {version: getVersionID(),
                    tilewidth: tileWidth,
                    tileheight: tileHeight,
                    tileshape: tileShape,
                    sources: data.sources,
                    relations: data.relations,
                    tileRelations: data.tileRelations,
                    tiles: data.tiles,
                    set: data.set,
                    set_regions: data.set_regions,
                    sandbox_layers: data.sandbox_layers,
                    sandbox: data.sandbox,
                    extra: extra};
        mkdirp(getDirName(fn), function (err) {
            if(err) return cb(err);
            fs.writeFileSync(fn, `${JSON.stringify(save, null, 2)}\n`);
            if(onSaved != null) {
                onSaved();
            }
        });
    });
}
exports.saveData = saveData;

var snapshotData = function(selectionSet, selectionSandbox, dstFn, z=0, saveRelations=true) {
    var tiles = [];
    var setRegions = [];

    var setTilesSave = [];
    var sandboxTilesSave = [];

    if(selectionSet == null) {
        var setTiles = set.getTiles();
        for(var key in setTiles) {
            var tile = setTiles[key];
            var tileIndex = tiles.indexOf(tile.tile);
            var tileID;
            if(tileIndex != -1) {
                tileID = tileIndex;
            } else {
                tiles.push(tile.tile);
                tileID = tiles.length-1;
            }
            setTilesSave.push({pos:{x:tile.pos.x, y:tile.pos.y}, tileID:tileID});
        }
        setRegions = set.getRegions();
    } else {
        var minX, minY;
        for(var i = 0; i < selectionSet.length; i++) {
            if(selectionSet[i].x < minX || i==0) {
                minX = selectionSet[i].x;
            }
            if(selectionSet[i].y < minY || i==0) {
                minY = selectionSet[i].y;
            }
        }
        for(var key in selectionSet) {
            var tile = set.getTile(selectionSet[key].x, selectionSet[key].y);
            if(tile != null) {
                var tileIndex = tiles.indexOf(tile);
                var tileID;
                if(tileIndex != -1) {
                    tileID = tileIndex;
                } else {
                    tiles.push(tile);
                    tileID = tiles.length-1;
                }
                setTilesSave.push({pos:{x:selectionSet[key].x-minX, y:selectionSet[key].y-minY}, tileID:tileID});
            }
        }
    }

    var sandboxLayers = sandbox.getLayers();
    var sandboxLayersSave = []
    for(var i in sandboxLayers) {
        var layer = sandboxLayers[i];
        sandboxLayersSave.push({visible:layer.visible, name:layer.name});
    }

    if(selectionSandbox == null) { //all sandbox
        var sandboxTiles = sandbox.getTiles();
        for(var key in sandboxTiles) {
            var tile = sandboxTiles[key];
            var tileIndex = tiles.indexOf(tile.tile);
            var tileID;
            if(tileIndex != -1) {
                tileID = tileIndex;
            } else {
                tiles.push(tile.tile);
                tileID = tiles.length-1;
            }
            sandboxTilesSave.push({pos:{x:tile.pos.x, y:tile.pos.y, z:tile.pos.z}, tileID:tileID});
        }
    } else {
        var minX, minY;
        for(var i = 0; i < selectionSandbox.length; i++) {
            if(selectionSandbox[i].x < minX || i==0) {
                minX = selectionSandbox[i].x;
            }
            if(selectionSandbox[i].y < minY || i==0) {
                minY = selectionSandbox[i].y;
            }
        }
        for(var key in selectionSandbox) {
            var tile = sandbox.getTile(selectionSandbox[key].x, selectionSandbox[key].y, z);
            if(tile != null) {
                var tileIndex = tiles.indexOf(tile);
                var tileID;
                if(tileIndex != -1) {
                    tileID = tileIndex;
                } else {
                    tiles.push(tile);
                    tileID = tiles.length-1;
                }
                sandboxTilesSave.push({pos:{x:selectionSandbox[key].x-minX, y:selectionSandbox[key].y-minY, z:z}, tileID:tileID});
            }
        }
    }

    var sources = [];
    var relationGroup = [];

    var tilesSave = [];
    for(var i in tiles) {
        var tile = tiles[i];

        if(saveRelations) {
            tile.getRelationsDependencies(relationGroup);
        }

        if(tile instanceof TileBase) {
            var source = tile.getSource();
            var sourceIndex = sources.indexOf(source);
            var sourceID;
            if(sourceIndex != -1) {
                sourceID = sourceIndex;
            } else {
                sources.push(source);
                sourceID = sources.length-1;
            }
            tilesSave.push({type:"base", sourceID:sourceID});
        } else if(tile instanceof TileBorder) {
            var bgen = tile.getBorderGenerator();
            if(bgen instanceof BorderGeneratorBlob) {
                tilesSave.push({type:"blob"});
            } else if(bgen instanceof BorderGeneratorWang) {
                tilesSave.push({type:"wang"});
            }
        }
    }

    var setRegionsSave = [];
    for(var i in setRegions) {
        var region = setRegions[i];
        if(region instanceof RegionSync) {
            var cachedTiles = region.getCacheTiles();
            var syncTiles = [];
            for(var k in cachedTiles) {
                var tile = cachedTiles[k].tile;
                var tileIndex = tiles.indexOf(tile);
                if(tileIndex != -1) {
                    syncTiles.push({type:"tile", data:tileIndex, pos:cachedTiles[k].pos});
                } else {
                    var sourceIndex = sources.indexOf(tile.getSource());
                    if(sourceIndex != -1) {
                        syncTiles.push({type:"source", data:sourceIndex, pos:cachedTiles[k].pos});
                    }
                }
            }
            var syncFn = region.getLabel();
            if(dstFn != null) { //convert absolute path to relative path
                syncFn = path.relative(dstFn, syncFn);
            }
            setRegionsSave.push({type:"sync", filename:syncFn, bounds:region.getBounds(), syncTiles:syncTiles});
        }
    }

    var relations = [];

    var tileRelationsSave = [];
    for(var i in relationGroup) {
        var rg = relationGroup[i];
        var relation = rg.tile.getRelation(rg.other);
        var relationIndex = relations.indexOf(relation);
        var relationID;
        if(relationIndex != -1) {
            relationID = relationIndex;
        } else {
            relations.push(relation);
            relationID = relations.length-1;
        }
        var otherID;
        if(rg.other == false) {
            otherID = false;
        } else {
            otherID = tiles.indexOf(rg.other);
        }
        tileRelationsSave.push({tile:tiles.indexOf(rg.tile), other:otherID, r:relationID});
    }

    var relationsSave = [];
    for(var i in relations) {
        var relation = relations[i];
        if(relation instanceof TileRelationBlob) {
            var sourceIDs = [];
            var bset = relation.getBorderSet();
            var bsetSources = bset.getSources();
            for(var bi = 0; bi < bsetSources.length; bi++) {
                var source = bsetSources[bi];
                var sourceIndex = sources.indexOf(source);
                var sourceID;
                if(sourceIndex != -1) {
                    sourceID = sourceIndex;
                } else {
                    sources.push(source);
                    sourceID = sources.length-1;
                }
                sourceIDs.push(sourceID);
            }
            relationsSave.push({type:"blob", origin:tiles.indexOf(relation.origin), data:[
                {srcID:sourceIDs[0], r:bset.getRotation(0), fx:bset.getFlipX(0), fy:bset.getFlipY(0), cutoff:bset.getCutoff(0)},
                {srcID:sourceIDs[1], r:bset.getRotation(1), fx:bset.getFlipX(1), fy:bset.getFlipY(1), cutoff:bset.getCutoff(1)},
                {srcID:sourceIDs[2], r:bset.getRotation(2), fx:bset.getFlipX(2), fy:bset.getFlipY(2), cutoff:bset.getCutoff(2)},
                {srcID:sourceIDs[3], r:bset.getRotation(3), fx:bset.getFlipX(3), fy:bset.getFlipY(3), cutoff:bset.getCutoff(3)},
                {srcID:sourceIDs[4], r:bset.getRotation(4), fx:bset.getFlipX(4), fy:bset.getFlipY(4), c:bset.getComposite(4)},
                {srcID:sourceIDs[5], r:bset.getRotation(5), fx:bset.getFlipX(5), fy:bset.getFlipY(5), c:bset.getComposite(5)},
                {srcID:sourceIDs[6], r:bset.getRotation(6), fx:bset.getFlipX(6), fy:bset.getFlipY(6), c:bset.getComposite(6)},
                {srcID:sourceIDs[7], r:bset.getRotation(7), fx:bset.getFlipX(7), fy:bset.getFlipY(7), c:bset.getComposite(7)},
                {srcID:sourceIDs[8], r:bset.getRotation(8), fx:bset.getFlipX(8), fy:bset.getFlipY(8), c:bset.getComposite(8)},
                {srcID:sourceIDs[9], r:bset.getRotation(9), fx:bset.getFlipX(9), fy:bset.getFlipY(9), c:bset.getComposite(9)},
                {srcID:sourceIDs[10], r:bset.getRotation(10), fx:bset.getFlipX(10), fy:bset.getFlipY(10), c:bset.getComposite(10)},
                {srcID:sourceIDs[11], r:bset.getRotation(11), fx:bset.getFlipX(11), fy:bset.getFlipY(11), c:bset.getComposite(11)}
            ]});
        } else if(relation instanceof TileRelationBlobBorder) {
            var indexMatrix = [];
            var im = relation.getIndexMatrix();
            for(var k in im) {
                if(im[k] == false) {
                    indexMatrix.push(false);
                } else {
                    indexMatrix.push(tiles.indexOf(im[k]));
                }
            }
            relationsSave.push({type:"blob_border", matrix:indexMatrix, isBorder:relation.isBorder});
        } else if(relation instanceof TileRelationWang) {
            var sourceIDs = [];
            var bset = relation.getBorderSet();
            var bsetSources = bset.getSources();
            for(var bi = 0; bi < bsetSources.length; bi++) {
                var source = bsetSources[bi];
                var sourceIndex = sources.indexOf(source);
                var sourceID;
                if(sourceIndex != -1) {
                    sourceID = sourceIndex;
                } else {
                    sources.push(source);
                    sourceID = sources.length-1;
                }
                sourceIDs.push(sourceID);
            }
            relationsSave.push({type:"wang", origin:tiles.indexOf(relation.origin), data:[
                {srcID:sourceIDs[0], r:bset.getRotation(0), fx:bset.getFlipX(0), fy:bset.getFlipY(0), cutoff:bset.getCutoff(0)},
                {srcID:sourceIDs[1], r:bset.getRotation(1), fx:bset.getFlipX(1), fy:bset.getFlipY(1), cutoff:bset.getCutoff(1)},
                {srcID:sourceIDs[2], r:bset.getRotation(2), fx:bset.getFlipX(2), fy:bset.getFlipY(2), cutoff:bset.getCutoff(2)},
                {srcID:sourceIDs[3], r:bset.getRotation(3), fx:bset.getFlipX(3), fy:bset.getFlipY(3), cutoff:bset.getCutoff(3)},
                {srcID:sourceIDs[4], r:bset.getRotation(4), fx:bset.getFlipX(4), fy:bset.getFlipY(4), c:bset.getComposite(4)},
                {srcID:sourceIDs[5], r:bset.getRotation(5), fx:bset.getFlipX(5), fy:bset.getFlipY(5), c:bset.getComposite(5)},
                {srcID:sourceIDs[6], r:bset.getRotation(6), fx:bset.getFlipX(6), fy:bset.getFlipY(6), c:bset.getComposite(6)},
                {srcID:sourceIDs[7], r:bset.getRotation(7), fx:bset.getFlipX(7), fy:bset.getFlipY(7), c:bset.getComposite(7)},
                {srcID:sourceIDs[8], r:bset.getRotation(8), fx:bset.getFlipX(8), fy:bset.getFlipY(8), c:bset.getComposite(8)},
                {srcID:sourceIDs[9], r:bset.getRotation(9), fx:bset.getFlipX(9), fy:bset.getFlipY(9), c:bset.getComposite(9)},
                {srcID:sourceIDs[10], r:bset.getRotation(10), fx:bset.getFlipX(10), fy:bset.getFlipY(10), c:bset.getComposite(10)},
                {srcID:sourceIDs[11], r:bset.getRotation(11), fx:bset.getFlipX(11), fy:bset.getFlipY(11), c:bset.getComposite(11)}
            ]});
        } else if(relation instanceof TileRelationWangBorder) {
            var indexMatrix = [];
            var im = relation.getIndexMatrix();
            for(var k in im) {
                if(im[k] == false) {
                    indexMatrix.push(false);
                } else {
                    indexMatrix.push(tiles.indexOf(im[k]));
                }
            }
            relationsSave.push({type:"wang_border", matrix:indexMatrix, isBorder:relation.isBorder});
        } else if(relation instanceof TileRelationProp) {
            relationsSave.push({type:"prop", x:relation.pos.x, y:relation.pos.y});
        } else if(relation instanceof TileRelationPropBackground) {
            relationsSave.push({type:"prop_background", isBackground:relation.isBackground});
        } else if(relation instanceof TileRelationProxy) {
            relationsSave.push({type:"proxy", isReverse:relation.isReverse, weight:relation.getWeight()});
        } else if(relation instanceof TileRelationBlobPre2_0_0) {
            var sourceIDs = [];
            var bset = relation.bset;
            var bsetSources = bset.getSources();
            for(var bi = 0; bi < bsetSources.length; bi++) {
                var source = bsetSources[bi];
                var sourceIndex = sources.indexOf(source);
                var sourceID;
                if(sourceIndex != -1) {
                    sourceID = sourceIndex;
                } else {
                    sources.push(source);
                    sourceID = sources.length-1;
                }
                sourceIDs.push(sourceID);
            }
            var sourceB = relation.getBaseSource();
            var sourceIndexB = sources.indexOf(sourceB);
            var sourceIDB;
            if(sourceIndexB != -1) {
                sourceIDB = sourceIndexB;
            } else {
                sources.push(sourceB);
                sourceIDB = sources.length-1;
            }
            relationsSave.push({type:"blob_pre_2_0_0", i:relation.m, baseSrcID:sourceIDB, bset:[
                {srcID:sourceIDs[0], r:bset.getRotation(0), fx:bset.getFlipX(0), fy:bset.getFlipY(0), cutoff:bset.getCutoff(0)},
                {srcID:sourceIDs[1], r:bset.getRotation(1), fx:bset.getFlipX(1), fy:bset.getFlipY(1), cutoff:bset.getCutoff(1)},
                {srcID:sourceIDs[2], r:bset.getRotation(2), fx:bset.getFlipX(2), fy:bset.getFlipY(2), cutoff:bset.getCutoff(2)},
                {srcID:sourceIDs[3], r:bset.getRotation(3), fx:bset.getFlipX(3), fy:bset.getFlipY(3), cutoff:bset.getCutoff(3)},
                {srcID:sourceIDs[4], r:bset.getRotation(4), fx:bset.getFlipX(4), fy:bset.getFlipY(4), c:bset.getComposite(4)},
                {srcID:sourceIDs[5], r:bset.getRotation(5), fx:bset.getFlipX(5), fy:bset.getFlipY(5), c:bset.getComposite(5)},
                {srcID:sourceIDs[6], r:bset.getRotation(6), fx:bset.getFlipX(6), fy:bset.getFlipY(6), c:bset.getComposite(6)},
                {srcID:sourceIDs[7], r:bset.getRotation(7), fx:bset.getFlipX(7), fy:bset.getFlipY(7), c:bset.getComposite(7)},
                {srcID:sourceIDs[8], r:bset.getRotation(8), fx:bset.getFlipX(8), fy:bset.getFlipY(8), c:bset.getComposite(8)},
                {srcID:sourceIDs[9], r:bset.getRotation(9), fx:bset.getFlipX(9), fy:bset.getFlipY(9), c:bset.getComposite(9)},
                {srcID:sourceIDs[10], r:bset.getRotation(10), fx:bset.getFlipX(10), fy:bset.getFlipY(10), c:bset.getComposite(10)},
                {srcID:sourceIDs[11], r:bset.getRotation(11), fx:bset.getFlipX(11), fy:bset.getFlipY(11), c:bset.getComposite(11)}
            ]});
        } else if(relation instanceof TileRelationWangPre2_0_0) {
            var sourceIDs = [];
            var bset = relation.bset;
            var bsetSources = bset.getSources();
            for(var bi = 0; bi < bsetSources.length; bi++) {
                var source = bsetSources[bi];
                var sourceIndex = sources.indexOf(source);
                var sourceID;
                if(sourceIndex != -1) {
                    sourceID = sourceIndex;
                } else {
                    sources.push(source);
                    sourceID = sources.length-1;
                }
                sourceIDs.push(sourceID);
            }
            var sourceB0 = relation.getBaseSource0();
            var sourceIndexB0 = sources.indexOf(sourceB0);
            var sourceIDB0;
            if(sourceIndexB0 != -1) {
                sourceIDB0 = sourceIndexB0;
            } else {
                sources.push(sourceB0);
                sourceIDB0 = sources.length-1;
            }
            var sourceB1 = relation.getBaseSource1();
            var sourceIndexB1 = sources.indexOf(sourceB1);
            var sourceIDB1;
            if(sourceIndexB1 != -1) {
                sourceIDB1 = sourceIndexB1;
            } else {
                sources.push(sourceB1);
                sourceIDB1 = sources.length-1;
            }
            relationsSave.push({type:"wang_pre_2_0_0", i:relation.m, baseSrc0ID:sourceIDB0, baseSrc1ID:sourceIDB1, bset:[
                {srcID:sourceIDs[0], r:bset.getRotation(0), fx:bset.getFlipX(0), fy:bset.getFlipY(0)},
                {srcID:sourceIDs[1], r:bset.getRotation(1), fx:bset.getFlipX(1), fy:bset.getFlipY(1)},
                {srcID:sourceIDs[2], r:bset.getRotation(2), fx:bset.getFlipX(2), fy:bset.getFlipY(2)},
                {srcID:sourceIDs[3], r:bset.getRotation(3), fx:bset.getFlipX(3), fy:bset.getFlipY(3)},
                {srcID:sourceIDs[4], r:bset.getRotation(4), fx:bset.getFlipX(4), fy:bset.getFlipY(4), c:bset.getComposite(4)},
                {srcID:sourceIDs[5], r:bset.getRotation(5), fx:bset.getFlipX(5), fy:bset.getFlipY(5), c:bset.getComposite(5)},
                {srcID:sourceIDs[6], r:bset.getRotation(6), fx:bset.getFlipX(6), fy:bset.getFlipY(6), c:bset.getComposite(6)},
                {srcID:sourceIDs[7], r:bset.getRotation(7), fx:bset.getFlipX(7), fy:bset.getFlipY(7), c:bset.getComposite(7)},
                {srcID:sourceIDs[8], r:bset.getRotation(8), fx:bset.getFlipX(8), fy:bset.getFlipY(8), c:bset.getComposite(8)},
                {srcID:sourceIDs[9], r:bset.getRotation(9), fx:bset.getFlipX(9), fy:bset.getFlipY(9), c:bset.getComposite(9)},
                {srcID:sourceIDs[10], r:bset.getRotation(10), fx:bset.getFlipX(10), fy:bset.getFlipY(10), c:bset.getComposite(10)},
                {srcID:sourceIDs[11], r:bset.getRotation(11), fx:bset.getFlipX(11), fy:bset.getFlipY(11), c:bset.getComposite(11)}
            ]});
        }
    }

    var promises = [];

    var sourcesSave = [];
    for(var i in sources) {
        var source = sources[i];
        if(source instanceof SourceImage) {
            (function(source, i) {
                var promise = source.getImage();
                promise.then(function(img) {
                    sourcesSave[i] = ({type:"image", url:img.toDataURL()});
                });
                promises.push(promise);
            })(source, i);
        }
    }

    return new Promise(function(resolve, reject) {
        Promise.all(promises).then(function() {
            resolve({sources: sourcesSave,
                    sources_obj: sources,
                    relations: relationsSave,
                    tileRelations: tileRelationsSave,
                    relations_obj: relations,
                    tiles: tilesSave,
                    tiles_obj: tiles,
                    set: setTilesSave,
                    set_regions: setRegionsSave,
                    set_regions_obj: setRegions,
                    sandbox_layers: sandboxLayersSave,
                    sandbox: sandboxTilesSave});
        })
    });
}

var clipboardSources = null;
var clipboardTiles = null;
var buildClipboardSet = function(tiles) {
    return new Promise(function(resolve, reject) {
        snapshotData(tiles, [], null, 0, false).then(function(data) {
            clipboardSources = data.sources_obj;
            clipboardTiles = data.tiles_obj;
            var clip = {sources: data.sources,
                        tiles: data.tiles,
                        set: data.set};
            resolve(Buffer.from(JSON.stringify(clip)));
        });
    });
}
exports.buildClipboardSet = buildClipboardSet;

var buildClipboardSandbox = function(tiles, z=0) {
    return new Promise(function(resolve, reject) {
        snapshotData([], tiles, null, z, false).then(function(data) {
            clipboardSources = data.sources_obj;
            clipboardTiles = data.tiles_obj;
            var clip = {sources: data.sources,
                        tiles: data.tiles,
                        set: data.sandbox};
            resolve(Buffer.from(JSON.stringify(clip)));
        });
    });
}
exports.buildClipboardSandbox = buildClipboardSandbox;

var parseClipboardSet = function(buf) {
    var data = JSON.parse(buf.toString());

    var sources = [];
    if(clipboardSources == null) {
        for(var i in data.sources) {
            var sourceSave = data.sources[i];
            if(sourceSave.type === "image") {
                var src = new SourceImage(nativeImage.createFromDataURL(sourceSave.url));
                sources[i] = src;
            }
        }
    } else {
        sources = clipboardSources;
    }

    var tilesExp = [];
    for(var i in data.set) {
        var setTile = data.set[i];
        var tile;
        var tileSave = data.tiles[setTile.tileID];
        if(tileSave.type === "base") {
            tile = new TileBase(sources[tileSave.sourceID]);
        } else if(tileSave.type === "blob") {
            tile = new TileBorder(new BorderGeneratorBlob());
        } else if(tileSave.type === "wang") {
            tile = new TileBorder(new BorderGeneratorWang());
        }
        tilesExp.push({tile:tile, pos:setTile.pos});
    }
    return tilesExp;
}
exports.parseClipboardSet = parseClipboardSet;

var parseClipboardSandbox = function(buf) {
    var data = JSON.parse(buf.toString());

    var tiles = [];
    if(clipboardTiles == null) {
        var sources = [];
        for(var i in data.sources) {
            var sourceSave = data.sources[i];
            if(sourceSave.type === "image") {
                var src = new SourceImage(nativeImage.createFromDataURL(sourceSave.url));
                sources[i] = src;
            }
        }

        for(var i in data.tiles) {
            var tileSave = data.tiles[i];
            if(tileSave.type === "base") {
                var tile = new TileBase(sources[tileSave.sourceID]);
                tiles[i] = tile;
            } else if(tileSave.type === "blob") {
                var tile = new TileBorder(new BorderGeneratorBlob());
                tiles[i] = tile;
            } else if(tileSave.type === "wang") {
                var tile = new TileBorder(new BorderGeneratorWang());
                tiles[i] = tile;
            }
        }
    } else {
        tiles = clipboardTiles;
    }

    var tilesExp = [];
    for(var i in data.set) {
        var setTile = data.set[i];
        tilesExp.push({tile:tiles[setTile.tileID], pos:setTile.pos});
    }
    return tilesExp;
}
exports.parseClipboardSandbox = parseClipboardSandbox;

var imageToSources = function(image) {
	var sources = [];

	var size = image.getSize();
    var tileSpanX = Math.ceil(size.width/tileWidth);
    var tileSpanY = Math.ceil(size.height/tileHeight);
    for(var i = 0; i < tileSpanX; i++) {
    	for(var j = 0; j < tileSpanY; j++) {
    		//prepare
    		var cropRect = {};
    		cropRect.x = i*tileWidth;
    		cropRect.y = j*tileHeight;
    		cropRect.width = tileWidth;
    		cropRect.height = tileHeight;
    		var cropped = image.crop(cropRect);
            var croppedTemp = nativeImage.createFromBuffer(cropped.toPNG());
            var pixelBuffer = croppedTemp.toBitmap();
            if(pixelBuffer.some(color => color !== 0)) {
                var src = new SourceImage(cropped);
                sources.push({src:src, pos:{x:i, y:j}});
            }
    	}
    }

    return sources;
}
exports.imageToSources = imageToSources;

var imageToSourcesDistinct = function(image, errorGroup=[]) {
    var set = [];

    if(tileShape == Shape.ISOMETRIC) {
        errorGroup.push({msg:"Importing images into the map editor is disabled for isometric."});
        return set;
    }

    var images = [];
    var sources = [];

    var size = image.getSize();
    var tileSpanX = Math.ceil(size.width/tileWidth);
    var tileSpanY = Math.ceil(size.height/tileWidth);
    for(var i = 0; i < tileSpanX; i++) {
        for(var j = 0; j < tileSpanY; j++) {
            //prepare
            var cropRect = {};
            cropRect.x = i*tileWidth;
            cropRect.y = j*tileWidth;
            cropRect.width = tileWidth;
            cropRect.height = tileWidth;
            var cropped = image.crop(cropRect);
            var croppedTemp = nativeImage.createFromBuffer(cropped.toPNG());
            var pixelBuffer = croppedTemp.toBitmap();
            if(pixelBuffer.some(color => color !== 0)) {
                var uIndex = -1;
                for(var k in images) {
                    var uImage = images[k];
                    if(cropped.toDataURL() === uImage.toDataURL()) {
                        uIndex = k;
                        break;
                    }
                }
                if(uIndex == -1) {
                    uIndex = sources.length;
                    images.push(cropped);
                    sources.push(new SourceImage(cropped));
                }
                set.push({src:sources[uIndex], pos:{x:i, y:j}});
            }
        }
    }

    return set;
}
exports.imageToSourcesDistinct = imageToSourcesDistinct;

var blobSet = [
    {i:[0, 0, 0, 1, 1, 1, 0, 0], pos:{x:-1, y:-1}},
    {i:[0, 0, 0, 1, 1, 1, 1, 1], pos:{x:0, y:-1}},
    {i:[0, 0, 0, 0, 0, 1, 1, 1], pos:{x:1, y:-1}},
    {i:[0, 1, 1, 1, 1, 1, 0, 0], pos:{x:-1, y:0}},
    {i:[1, 1, 0, 0, 0, 1, 1, 1], pos:{x:1, y:0}},
    {i:[0, 1, 1, 1, 0, 0, 0, 0], pos:{x:-1, y:1}},
    {i:[1, 1, 1, 1, 0, 0, 0, 1], pos:{x:0, y:1}},
    {i:[1, 1, 0, 0, 0, 0, 0, 1], pos:{x:1, y:1}},
    {i:[0, 0, 0, 1, 0, 0, 0, 0], pos:{x:-1, y:2}},
    {i:[0, 0, 0, 1, 0, 0, 0, 1], pos:{x:0, y:2}},
    {i:[0, 0, 0, 0, 0, 0, 0, 1], pos:{x:1, y:2}},
    {i:[0, 0, 0, 0, 0, 1, 0, 0], pos:{x:2, y:-1}},
    {i:[0, 1, 0, 0, 0, 1, 0, 0], pos:{x:2, y:0}},
    {i:[0, 1, 0, 0, 0, 0, 0, 0], pos:{x:2, y:1}},
    {i:[0, 0, 0, 0, 0, 0, 0, 0], pos:{x:2, y:2}},
    {i:[0, 0, 0, 1, 0, 1, 0, 0], pos:{x:3, y:-1}},
    {i:[0, 0, 0, 1, 0, 1, 1, 1], pos:{x:4, y:-1}},
    {i:[0, 0, 0, 1, 1, 1, 0, 1], pos:{x:5, y:-1}},
    {i:[0, 0, 0, 0, 0, 1, 0, 1], pos:{x:6, y:-1}},
    {i:[0, 1, 1, 1, 0, 1, 0, 0], pos:{x:3, y:0}},
    {i:[1, 1, 1, 1, 0, 1, 1, 1], pos:{x:4, y:0}},
    {i:[1, 1, 1, 1, 1, 1, 0, 1], pos:{x:5, y:0}},
    {i:[1, 1, 0, 0, 0, 1, 0, 1], pos:{x:6, y:0}},
    {i:[0, 1, 0, 1, 1, 1, 0, 0], pos:{x:3, y:1}},
    {i:[1, 1, 0, 1, 1, 1, 1, 1], pos:{x:4, y:1}},
    {i:[0, 1, 1, 1, 1, 1, 1, 1], pos:{x:5, y:1}},
    {i:[0, 1, 0, 0, 0, 1, 1, 1], pos:{x:6, y:1}},
    {i:[0, 1, 0, 1, 0, 0, 0, 0], pos:{x:3, y:2}},
    {i:[1, 1, 0, 1, 0, 0, 0, 1], pos:{x:4, y:2}},
    {i:[0, 1, 1, 1, 0, 0, 0, 1], pos:{x:5, y:2}},
    {i:[0, 1, 0, 0, 0, 0, 0, 1], pos:{x:6, y:2}},
    {i:[0, 1, 0, 1, 0, 1, 0, 0], pos:{x:3, y:3}},
    {i:[1, 1, 0, 1, 0, 1, 1, 1], pos:{x:4, y:3}},
    {i:[0, 1, 1, 1, 1, 1, 0, 1], pos:{x:5, y:3}},
    {i:[0, 1, 0, 0, 0, 1, 0, 1], pos:{x:6, y:3}},
    {i:[0, 0, 0, 1, 0, 1, 0, 1], pos:{x:7, y:-1}},
    {i:[1, 1, 1, 1, 0, 1, 0, 1], pos:{x:7, y:0}},
    {i:[0, 1, 0, 1, 1, 1, 1, 1], pos:{x:7, y:1}},
    {i:[0, 1, 0, 1, 0, 0, 0, 1], pos:{x:7, y:2}},
    {i:[1, 1, 0, 1, 1, 1, 0, 1], pos:{x:8, y:-1}},
    {i:[0, 1, 1, 1, 0, 1, 1, 1], pos:{x:8, y:0}},
    {i:[0, 1, 0, 1, 1, 1, 0, 1], pos:{x:8, y:1}},
    {i:[0, 1, 0, 1, 0, 1, 1, 1], pos:{x:9, y:1}},
    {i:[0, 1, 1, 1, 0, 1, 0, 1], pos:{x:8, y:2}},
    {i:[1, 1, 0, 1, 0, 1, 0, 1], pos:{x:9, y:2}},
    {i:[0, 1, 0, 1, 0, 1, 0, 1], pos:{x:7, y:3}}
];
var buildBordersBlob = function(baseTiles, undoGroup=[], errorGroup=[]) {
    var tiles = [];

    if(baseTiles.length < 1) {
        errorGroup.push({msg:"Please select at least one tile."});
        return tiles;
    }
    if(baseTiles.length == 1) {
        baseTiles.push(false);
    }

    var comboIndex = 0;
    var baseTilesAdded = [];

    var tile0 = baseTiles[0];
    for(var bt1 = 1; bt1 < baseTiles.length; bt1++) {
        var tile1 = baseTiles[bt1];

        //check if relationship will be valid
        var newRelationValid = function(tile, other) {
            var tRels = tile.getRelations();
            for(var tr in tRels) {
                if(!(tRels[tr].r instanceof TileRelationProxy && tRels[tr].r.isReverse)
                && !(tRels[tr].r instanceof TileRelationBlob && tRels[tr].r.origin == tile)
                && !(tRels[tr].r instanceof TileRelationBlob && tRels[tr].r.origin != tile && tRels[tr].t != other)
                && !(tRels[tr].r instanceof TileRelationBlobBorder && !tRels[tr].r.isBorder)
                && !(tRels[tr].r instanceof TileRelationPropBackground && tRels[tr].r.isBackground)) {
                    if(other == false) {
                        errorGroup.push({msg:"Tile %T has incompatible relations.\nBorders for it have not been generated.", tiles:[tile]});
                    } else {
                        errorGroup.push({msg:"Tile %T has incompatible relations.\nBorders between %T and %T have not been generated.", tiles:[tile, tile, other]});
                    }
                    return false;
                }
            }
            if(other != false) {
                var oRels = other.getRelations();
                for(var tr in oRels) {
                    if(!(oRels[tr].r instanceof TileRelationProxy && oRels[tr].r.isReverse)
                    && !(oRels[tr].r instanceof TileRelationBlob)
                    && !(oRels[tr].r instanceof TileRelationBlobBorder && !oRels[tr].r.isBorder)
                    && !(oRels[tr].r instanceof TileRelationPropBackground && oRels[tr].r.isBackground)) {
                        errorGroup.push({msg:"Tile %T has incompatible relations.\nBorders between %T and %T have not been generated.", tiles:[other, tile, other]});
                        return false;
                    }
                }
            }
            return true;
        }
        if(!newRelationValid(tile0, tile1)) {
            continue;
        }

        //add relation between tile0 & tile1
        var rel = new TileRelationBlob(new BorderSetBlob(), tile0);
        tile0.registerRelation(tile1, rel, undoGroup);
        if(tile1 != false) {
            tile1.registerRelation(tile0, rel, undoGroup);
        }

        //generate border tiles and append to the relation
        var genTiles = [tile0, tile1];
        var t0Rel = tile0.getRelations();
        for(var r in t0Rel) {
            var rel = t0Rel[r];
            if(!(rel.r instanceof TileRelationBlob && rel.r.origin == tile0)) {
                continue;
            }
            if(rel.t == tile1) {
                continue;
            }
            genTiles.push(rel.t);
        }
        var genMatrices = [];
        for(var i = 0; i < genTiles.length; i++) {
            for(var j = 0; j < genTiles.length; j++) {
                for(var k = 0; k < genTiles.length; k++) {
                    for(var p = 0; p < genTiles.length; p++) {
                        var xAvailable = i==0&&j==0;
                        var yAvailable = j==0&&k==0;
                        var zAvailable = k==0&&p==0;
                        var wAvailable = p==0&&i==0;
                        var xRange = genTiles.length;
                        if(!xAvailable) { xRange = 1; }
                        var yRange = genTiles.length;
                        if(!yAvailable) { yRange = 1; }
                        var zRange = genTiles.length;
                        if(!zAvailable) { zRange = 1; }
                        var wRange = genTiles.length;
                        if(!wAvailable) { wRange = 1; }
                        for(var x = 0; x < xRange; x++) {
                            for(var y = 0; y < yRange; y++) {
                                for(var z = 0; z < zRange; z++) {
                                    for(var w = 0; w < wRange; w++) {
                                        var genMatrix = [null, genTiles[i], null, genTiles[j], null, genTiles[k], null, genTiles[p]];
                                        if(xAvailable) { genMatrix[2] = genTiles[x]; }
                                        if(yAvailable) { genMatrix[4] = genTiles[y]; }
                                        if(zAvailable) { genMatrix[6] = genTiles[z]; }
                                        if(wAvailable) { genMatrix[0] = genTiles[w]; }

                                        if(!genMatrix.includes(tile1)) {
                                            continue;
                                        }
                                        if(tile0.getRelationBlobBorder(genMatrix) != null) {
                                            continue;
                                        }
                                        //generate tile
                                        var tileGen = new TileBorder(new BorderGeneratorBlob());
                                        //append to the relation
                                        tile0.registerRelation(tileGen, new TileRelationBlobBorder(genMatrix, false), undoGroup);
                                        tileGen.registerRelation(tile0, new TileRelationBlobBorder(genMatrix, true), undoGroup);
                                        genMatrices.push({m:genMatrix, t:tileGen});
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        //place in corect position
        if(!baseTilesAdded.includes(tile1) && tile1 != false) {
            tiles.push({tile:tile1, pos:{x:-2, y:comboIndex}});
            baseTilesAdded.push(tile1);
        }
        var indexG = 0;
        while(genMatrices.length > 0) {
            var gm = genMatrices[0];
            if( (gm.m[0] == tile0 || gm.m[0] == tile1 || gm.m[0] == null) &&
                (gm.m[1] == tile0 || gm.m[1] == tile1 || gm.m[1] == null) &&
                (gm.m[2] == tile0 || gm.m[2] == tile1 || gm.m[2] == null) &&
                (gm.m[3] == tile0 || gm.m[3] == tile1 || gm.m[3] == null) &&
                (gm.m[4] == tile0 || gm.m[4] == tile1 || gm.m[4] == null) &&
                (gm.m[5] == tile0 || gm.m[5] == tile1 || gm.m[5] == null) &&
                (gm.m[6] == tile0 || gm.m[6] == tile1 || gm.m[6] == null) &&
                (gm.m[7] == tile0 || gm.m[7] == tile1 || gm.m[7] == null)) {
                var indexMatrix = [0, 0, 0, 0, 0, 0, 0, 0];
                for(var k = 0; k < 8; k++) {
                    if(gm.m[k] == tile0) {
                        indexMatrix[k] = 1;
                    }
                }
                //console.log(indexMatrix);
                //console.log(gm);
                for(var k = 0; k < blobSet.length; k++) {
                    var im = blobSet[k].i;
                    var arrEqual = true;
                    for(var j = 0; j < 8; j++) {
                        if(indexMatrix[j] != im[j]) {
                            arrEqual = false;
                            break;
                        }
                    }
                    if(arrEqual) {
                        tiles.push({tile:gm.t, pos:{x:blobSet[k].pos.x, y:blobSet[k].pos.y+comboIndex}});
                        break;
                    }
                }
                genMatrices.splice(0, 1);
            } else {
                var ix = (indexG%3)*2;
                var iy = Math.floor(indexG/3);
                for(var gf = genMatrices.length-1; gf >= 0; gf--) {
                    var gmf = genMatrices[gf];
                    if(gmf.t == gm.t) {
                        continue;
                    }
                    if( gmf.m[0] == gm.m[6] &&
                        gmf.m[1] == gm.m[7] &&
                        gmf.m[2] == gm.m[0] &&
                        gmf.m[3] == gm.m[1] &&
                        gmf.m[4] == gm.m[2] &&
                        gmf.m[5] == gm.m[3] &&
                        gmf.m[6] == gm.m[4] &&
                        gmf.m[7] == gm.m[5]) {
                        tiles.push({tile:gmf.t, pos:{x:10+ix+1, y:-1+iy+comboIndex}});
                        genMatrices.splice(gf, 1);
                        break;
                    }
                    if( gmf.m[0] == gm.m[2] &&
                        gmf.m[1] == gm.m[3] &&
                        gmf.m[2] == gm.m[4] &&
                        gmf.m[3] == gm.m[5] &&
                        gmf.m[4] == gm.m[6] &&
                        gmf.m[5] == gm.m[7] &&
                        gmf.m[6] == gm.m[0] &&
                        gmf.m[7] == gm.m[1]) {
                        tiles.push({tile:gmf.t, pos:{x:10+ix+1, y:-1+iy+comboIndex}});
                        genMatrices.splice(gf, 1);
                        break;
                    }
                }
                tiles.push({tile:gm.t, pos:{x:10+ix, y:-1+iy+comboIndex}});
                genMatrices.splice(0, 1);
                indexG++;
            }
        }
        comboIndex += 5+Math.max(0, Math.floor(indexG/3)-5);
    }
    //place tiles in setview
    return tiles;
}
exports.buildBordersBlob = buildBordersBlob;

var replaceBlobBorder = function(tile, indexMatrix, newTile, undoGroup=[], errorGroup=[]) {
    var newRelationValid = function(tile) {
        var tRels = tile.getRelations();
        for(var tr in tRels) {
            if(!(tRels[tr].r instanceof TileRelationProxy && tRels[tr].r.isReverse)) {
                return false;
            }
        }
        return true;
    }
    if(newTile != null && !newRelationValid(newTile)) {
        errorGroup.push({msg:"Tile %T has incompatible relations.\nIt has not been set as border.", tiles:[newTile]});
        return;
    }

    //remove old border
    var other = tile.getRelationBlobBorder(indexMatrix);
    if(other != null) {
        tile.removeRelation(other, undoGroup);
        other.removeRelation(tile, undoGroup);
    }

    //register new border
    if(newTile != null) {
        var clonedMatrix = [indexMatrix[0],
                            indexMatrix[1],
                            indexMatrix[2],
                            indexMatrix[3],
                            indexMatrix[4],
                            indexMatrix[5],
                            indexMatrix[6],
                            indexMatrix[7]]
        tile.registerRelation(newTile, new TileRelationBlobBorder(clonedMatrix, false), undoGroup);
        newTile.registerRelation(tile, new TileRelationBlobBorder(clonedMatrix, true), undoGroup);
    }
}
exports.replaceBlobBorder = replaceBlobBorder;

var wangSet = [
    {i:[0, 0, 1, 0], pos:{x:-1, y:-1}},
    {i:[0, 0, 1, 1], pos:{x:0, y:-1}},
    {i:[0, 0, 0, 1], pos:{x:1, y:-1}},
    {i:[0, 1, 1, 0], pos:{x:-1, y:0}},
    {i:[1, 0, 0, 1], pos:{x:1, y:0}},
    {i:[0, 1, 0, 0], pos:{x:-1, y:1}},
    {i:[1, 1, 0, 0], pos:{x:0, y:1}},
    {i:[1, 0, 0, 0], pos:{x:1, y:1}},

    {i:[1, 1, 0, 1], pos:{x:2, y:-1}},
    {i:[1, 1, 1, 0], pos:{x:3, y:-1}},
    {i:[1, 0, 1, 1], pos:{x:2, y:0}},
    {i:[0, 1, 1, 1], pos:{x:3, y:0}},
    {i:[1, 0, 1, 0], pos:{x:2, y:1}},
    {i:[0, 1, 0, 1], pos:{x:3, y:1}}
];
var buildBordersWang = function(baseTiles, undoGroup=[], errorGroup=[]) {
    var tiles = [];

    if(baseTiles.length < 1) {
        errorGroup.push({msg:"Please select at least one tile."});
        return tiles;
    }
    if(baseTiles.length == 1) {
        baseTiles.push(false);
    }
    //for all tile combos
    var comboIndex = 0;
    var baseTilesAdded = [];
    for(var bt0 = 0; bt0 < baseTiles.length; bt0++) {
        for(var bt1 = bt0+1; bt1 < baseTiles.length; bt1++) {
            var tile0 = baseTiles[bt0]
            var tile1 = baseTiles[bt1];

            //check if relationship will be valid
            var newRelationValid = function(tile, other) {
                var tRels = tile.getRelations();
                for(var tr in tRels) {
                    if(!(tRels[tr].r instanceof TileRelationProxy && tRels[tr].r.isReverse)
                    && !(tRels[tr].r instanceof TileRelationWang)
                    && !(tRels[tr].r instanceof TileRelationWangBorder && !tRels[tr].r.isBorder)
                    && !(tRels[tr].r instanceof TileRelationPropBackground && tRels[tr].r.isBackground)) {
                        if(other == false) {
                            errorGroup.push({msg:"Tile %T has incompatible relations.\nBorders for it have not been generated.", tiles:[tile]});
                        } else {
                            errorGroup.push({msg:"Tile %T has incompatible relations.\nBorders between %T and %T have not been generated.", tiles:[tile, tile, other]});
                        }
                        return false;
                    }
                }
                return true;
            }
            if(!newRelationValid(tile0, tile1) || (tile1 != false && !newRelationValid(tile1, tile0))) {
                continue;
            }

            //add relation between tile0 & tile1 and viceversa
            var rel = new TileRelationWang(new BorderSetWang(), tile0);
            tile0.registerRelation(tile1, rel, undoGroup);
            if(tile1 != false) {
                tile1.registerRelation(tile0, rel, undoGroup);
            }

            //generate border tiles and append to the relation
            var genTiles = [tile0, tile1];
            /*var t1Rel = tile1.getRelations();
            for(var r in t1Rel) {
                var rel = t1Rel[r];
                if(!(rel.r instanceof TileRelationWang)) {
                    continue;
                }
                if(rel.t == tile0) {
                    continue;
                }
                if(rel.t.getRelation(tile0) instanceof TileRelationWang) {
                    genTiles.push(rel.t);
                }
            }*/
            var t0Rel = tile0.getRelations();
            for(var r in t0Rel) {
                var rel = t0Rel[r];
                if(!(rel.r instanceof TileRelationWang)) {
                    continue;
                }
                if(rel.t == tile1) {
                    continue;
                }
                if(rel.t == false) {
                    if(tile1.getRelation(rel.t) instanceof TileRelationWang) {
                        genTiles.push(rel.t);
                    }
                } else {
                    if(rel.t.getRelation(tile1) instanceof TileRelationWang) {
                        genTiles.push(rel.t);
                    }
                }
            }
            var genMatrices = [];
            for(var i = 0; i < genTiles.length; i++) {
                for(var j = 0; j < genTiles.length; j++) {
                    for(var k = 0; k < genTiles.length; k++) {
                        for(var p = 0; p < genTiles.length; p++) {
                            var genMatrix = [genTiles[i], genTiles[j], genTiles[k], genTiles[p]];
                            if(!genMatrix.includes(tile0) || !genMatrix.includes(tile1)) {
                                continue;
                            }
                            if(tile0.getRelationWangBorder(genMatrix) != null) {
                                continue;
                            }
                            //generate tile
                            var tileGen = new TileBorder(new BorderGeneratorWang());
                            //append to the relation
                            var rel0 = new TileRelationWangBorder(genMatrix, false);
                            var rel1 = new TileRelationWangBorder(genMatrix, true);
                            for(var q = 0; q < genMatrix.length; q++) {
                                var tq = genMatrix[q];
                                if(tq == false) {
                                    continue;
                                }
                                tq.registerRelation(tileGen, rel0, undoGroup);
                                tileGen.registerRelation(tq, rel1, undoGroup);
                            }
                            genMatrices.push({m:genMatrix, t:tileGen});
                        }
                    }
                }
            }
            //place in corect position
            if(!baseTilesAdded.includes(tile0)) {
                tiles.push({tile:tile0, pos:{x:0, y:comboIndex}});
                baseTilesAdded.push(tile0);
            }
            if(!baseTilesAdded.includes(tile1) && tile1 != false) {
                tiles.push({tile:tile1, pos:{x:-2, y:comboIndex}});
                baseTilesAdded.push(tile1);
            }
            var indexG = 0;
            while(genMatrices.length > 0) {
                var gm = genMatrices[0];
                if( (gm.m[0] == tile0 || gm.m[0] == tile1) &&
                    (gm.m[1] == tile0 || gm.m[1] == tile1) &&
                    (gm.m[2] == tile0 || gm.m[2] == tile1) &&
                    (gm.m[3] == tile0 || gm.m[3] == tile1)) {
                    var indexMatrix = [0, 0, 0, 0];
                    for(var k = 0; k < 4; k++) {
                        if(gm.m[k] == tile0) {
                            indexMatrix[k] = 1;
                        }
                    }
                    for(var k = 0; k < wangSet.length; k++) {
                        var im = wangSet[k].i;
                        var arrEqual = true;
                        for(var j = 0; j < 4; j++) {
                            if(indexMatrix[j] != im[j]) {
                                arrEqual = false;
                                break;
                            }
                        }
                        if(arrEqual) {
                            tiles.push({tile:gm.t, pos:{x:wangSet[k].pos.x, y:wangSet[k].pos.y+comboIndex}});
                            break;
                        }
                    }
                    genMatrices.splice(0, 1);
                } else {
                    var ix = (indexG%3)*2;
                    var iy = Math.floor(indexG/3)*2;
                    for(var gf = genMatrices.length-1; gf >= 0; gf--) {
                        var gmf = genMatrices[gf];
                        if(gmf.t == gm.t) {
                            continue;
                        }
                        if( gmf.m[0] == gm.m[1] &&
                            gmf.m[1] == gm.m[0] &&
                            gmf.m[2] == gm.m[3] &&
                            gmf.m[3] == gm.m[2]) {
                            tiles.push({tile:gmf.t, pos:{x:4+ix+1, y:-1+iy+comboIndex}});
                            genMatrices.splice(gf, 1);
                            continue;
                        }
                        if( gmf.m[0] == gm.m[3] &&
                            gmf.m[1] == gm.m[2] &&
                            gmf.m[2] == gm.m[1] &&
                            gmf.m[3] == gm.m[0]) {
                            tiles.push({tile:gmf.t, pos:{x:4+ix, y:-1+iy+1+comboIndex}});
                            genMatrices.splice(gf, 1);
                            continue;
                        }
                        if( gmf.m[0] == gm.m[2] &&
                            gmf.m[1] == gm.m[3] &&
                            gmf.m[2] == gm.m[0] &&
                            gmf.m[3] == gm.m[1]) {
                            tiles.push({tile:gmf.t, pos:{x:4+ix+1, y:-1+iy+1+comboIndex}});
                            genMatrices.splice(gf, 1);
                            continue;
                        }
                    }
                    tiles.push({tile:gm.t, pos:{x:4+ix, y:-1+iy+comboIndex}});
                    genMatrices.splice(0, 1);
                    indexG++;
                }
            }
            comboIndex += 3+Math.max(0, Math.floor(indexG/3)*2-3);
        }
    }
    //place tiles in setview
    return tiles;
}
exports.buildBordersWang = buildBordersWang;

var replaceWangBorder = function(indexMatrix, newTile, undoGroup=[], errorGroup=[]) {
    var newRelationValid = function(tile) {
        var tRels = tile.getRelations();
        for(var tr in tRels) {
            if(!(tRels[tr].r instanceof TileRelationProxy && tRels[tr].r.isReverse)) {
                return false;
            }
        }
        return true;
    }
    if(newTile != null && !newRelationValid(newTile)) {
        errorGroup.push({msg:"Tile %T has incompatible relations.\nIt has not been set as border.", tiles:[newTile]});
        return;
    }

    //remove old border
    for(var i in indexMatrix) {
        var t = indexMatrix[i];
        if(t == false) {
            continue;
        }
        var other = t.getRelationWangBorder(indexMatrix);
        if(other != null) {
            t.removeRelation(other, undoGroup);
            other.removeRelation(t, undoGroup);
        }
    }

    //register new border
    if(newTile != null) {
        var clonedMatrix = [indexMatrix[0],
                            indexMatrix[1],
                            indexMatrix[2],
                            indexMatrix[3]]
        var rel0 = new TileRelationWangBorder(clonedMatrix, false);
        var rel1 = new TileRelationWangBorder(clonedMatrix, true);
        for(var i in indexMatrix) {
            var t = indexMatrix[i];
            if(t == false) {
                continue;
            }
            t.registerRelation(newTile, rel0, undoGroup);
            newTile.registerRelation(t, rel1, undoGroup);
        }
    }
}
exports.replaceWangBorder = replaceWangBorder;

var groupTilesAsProp = function(tiles, undoGroup=[], errorGroup=[]) {
    if(tiles.length < 1) {
        errorGroup.push({msg:"Please select at least one tile."});
        return;
    }
    //get bgTile
    var bgTile = null;
    for(var i in tiles) {
        var tile = tiles[i].tile;
        if(tile == false) {
            continue;
        }
        var tRel = tile.getRelations();
        for(var r in tRel) {
            var rel = tRel[r];
            if(rel.r instanceof TileRelationPropBackground && !rel.r.isBackground) {
                bgTile = rel.t;
                break;
            }
        }
        if(bgTile != null) {
            break;
        }
    }
    //remove previous relations
    for(var i in tiles) {
        var tile = tiles[i].tile;
        if(tile == false) {
            continue;
        }
        var tRel = tile.getRelations();
        for(var r in tRel) {
            var rel = tRel[r];
            if(rel.r instanceof TileRelationProp) {
                tile.removeRelation(rel.t, undoGroup);
                if(rel.t != false) {
                    rel.t.removeRelation(tile, undoGroup);
                    //if other prop component is left alone, group them with false (single-tile prop)
                    var alone = true;
                    var ttRel = rel.t.getRelations();
                    for(var r2 in ttRel) {
                        var rel2 = ttRel[r2];
                        if(rel2.r instanceof TileRelationProp) {
                            alone = false;
                            break;
                        }
                    }
                    if(alone) {
                        groupTilesAsProp([{tile:rel.t, pos:{x:0, y:0}}, {tile:false, pos:{x:0, y:0}}], undoGroup);
                        //keep bg on stranded tile
                        var bgTile = null;
                        for(var k in tRel) {
                            var r2 = tRel[k];
                            if(r2.r instanceof TileRelationPropBackground) {
                                bgTile = r2.t;
                                break;
                            }
                        }
                        if(bgTile != null) {
                            setPropBackground(rel.t, bgTile, undoGroup);
                        }
                    }
                }
            }
        }
    }
    //add new relations
    for(var i in tiles) {
        var tA = tiles[i];
        if(tiles[i].tile == false) {
            continue;
        }
        var newRelationValid = function(tile) {
            var tRels = tile.getRelations();
            for(var tr in tRels) {
                if(!(tRels[tr].r instanceof TileRelationProxy && tRels[tr].r.isReverse)
                && !(tRels[tr].r instanceof TileRelationProp)
                && !(tRels[tr].r instanceof TileRelationPropBackground && !tRels[tr].r.isBackground)) {
                    return false;
                }
            }
            return true;
        }
        if(!newRelationValid(tA.tile)) {
            errorGroup.push({msg:"Tile %T has incompatible relations\nand has not been grouped into the Prop.", tiles:[tA.tile]});
            continue;
        }
        for(var j in tiles) {
            var tB = tiles[j];
            if(i != j) {
                if(tB.tile != false && !newRelationValid(tB.tile)) {
                    continue;
                }
                tA.tile.registerRelation(tB.tile, new TileRelationProp(tB.pos.x-tA.pos.x, tB.pos.y-tA.pos.y), undoGroup);
                if(bgTile != null) {
                    tA.tile.registerRelation(bgTile, new TileRelationPropBackground(false), undoGroup);
                    bgTile.registerRelation(tA.tile, new TileRelationPropBackground(true), undoGroup);
                }
            }
        }
    }
}
exports.groupTilesAsProp = groupTilesAsProp;

var ungroupProp = function(tile, undoGroup=[]) {
    var tRel = tile.getRelations();
    for(var i in tRel) {
        var rel = tRel[i];
        if(rel.r instanceof TileRelationProp) {
            tile.removeRelation(rel.t, undoGroup);
            if(rel.t != false) {
                ungroupProp(rel.t, undoGroup);
            }
        }
    }
}
exports.ungroupProp = ungroupProp;

var setPropBackground = function(tile, bg, undoGroup=[], errorGroup=[]) {
    //check if BG tile is either blob or wang base
    var newRelationValid = function(tile) {
        var tRels = tile.getRelations();
        if(tRels.length == 0) {
            return false;
        }
        for(var tr in tRels) {
            if(!(tRels[tr].r instanceof TileRelationProxy && tRels[tr].r.isReverse)
            && !(tRels[tr].r instanceof TileRelationBlob)
            && !(tRels[tr].r instanceof TileRelationBlobBorder && !tRels[tr].r.isBorder)
            && !(tRels[tr].r instanceof TileRelationWang)
            && !(tRels[tr].r instanceof TileRelationWangBorder && !tRels[tr].r.isBorder)
            && !(tRels[tr].r instanceof TileRelationPropBackground && tRels[tr].r.isBackground)) {
                return false;
            }
        }
        return true;
    }
    if(bg != null && !newRelationValid(bg)) {
        errorGroup.push({msg:"Tile %T is neither a blob base nor a wang base.\nIt has not been set as medium.", tiles:[bg]});
        return;
    }
    //get components
    var propComponents = [tile];
    var tRel = tile.getRelations();
    for(var r in tRel) {
        var rel = tRel[r];
        if(rel.r instanceof TileRelationProp) {
            if(rel.t != false) {
                propComponents.push(rel.t);
            }
        }
    }
    //remove previous background rel
    for(var i in propComponents) {
        var pTile = propComponents[i];
        var pRel = pTile.getRelations();
        for(var r in pRel) {
            var rel = pRel[r];
            if(rel.r instanceof TileRelationPropBackground) {
                pTile.removeRelation(rel.t, undoGroup);
                rel.t.removeRelation(pTile, undoGroup);
            }
        }
    }
    //add new background rel
    if(bg != null) {
        for(var i in propComponents) {
            var pTile = propComponents[i];
            pTile.registerRelation(bg, new TileRelationPropBackground(false), undoGroup);
            bg.registerRelation(pTile, new TileRelationPropBackground(true), undoGroup);
        }
    }
}
exports.setPropBackground = setPropBackground;

var setProxy = function(tiles, undoGroup=[], errorGroup=[]) {
    if(tiles.length < 2) {
        errorGroup.push({msg:"Please select at least two tiles."});
        return;
    }
    //find tile to be proxied
    var newRelationValid = function(tile) {
        var tRels = tile.getRelations();
        for(var tr in tRels) {
            if(!(tRels[tr].r instanceof TileRelationProxy && tRels[tr].r.isReverse)) {
                return false;
            }
        }
        return true;
    }
    var proxied = null;
    for(var i in tiles) {
        var tile = tiles[i];
        if(!newRelationValid(tile)) {
            if(proxied == null) {
                proxied = tile;
            } else {
                errorGroup.push({msg:"More than one candidate for proxied tile.\nNo proxies have been set."});
                return; //more than one relationed tile
            }
        }
    }
    if(proxied == null) {
        proxied = tiles[tiles.length-1];
    }
    var newRelationValid2 = function(tile) {
        var tRels = tile.getRelations();
        for(var tr in tRels) {
            if(tRels[tr].r instanceof TileRelationProxy && !tRels[tr].r.isReverse) {
                return false;
            }
        }
        return true;
    }
    if(!newRelationValid2(proxied)) {
        errorGroup.push({msg:"Cannot create a proxy of a proxy.\nNo proxies have been set."});
        return;
    }
    //add proxy relations
    proxied.registerRelation(proxied, new TileRelationProxy(true, 1), undoGroup);
    for(var i in tiles) {
        var tile = tiles[i];
        if(tile != proxied) {
            tile.registerRelation(proxied, new TileRelationProxy(false), undoGroup);
            proxied.registerRelation(tile, new TileRelationProxy(true), undoGroup);
        }
    }
}
exports.setProxy = setProxy;

var replaceProxy = function(tile, newTile, undoGroup=[], errorGroup=[]) {
    var newRelationValid = function(tile) {
        var tRels = tile.getRelations();
        for(var tr in tRels) {
            if(tRels[tr].r instanceof TileRelationProxy && !tRels[tr].r.isReverse) {
                return false;
            }
        }
        return true;
    }
    if(newTile != null && !newRelationValid(newTile)) {
        errorGroup.push({msg:"Cannot create a proxy of a proxy.\nTile %T has not been set as proxied.", tiles:[newTile]});
        return;
    }
    //remove previous proxy
    var tRel = tile.getRelations();
    for(var i in tRel) {
        var rel = tRel[i];
        if(rel.r instanceof TileRelationProxy && !rel.r.isReverse) {
            tile.removeRelation(rel.t, undoGroup);
            rel.t.removeRelation(tile, undoGroup);
        }
    }
    //add new proxy
    if(newTile != null) {
        newTile.registerRelation(newTile, new TileRelationProxy(true, 1), undoGroup);
    }
    if(newTile != null) {
        tile.registerRelation(newTile, new TileRelationProxy(false), undoGroup);
        newTile.registerRelation(tile, new TileRelationProxy(true), undoGroup);
    }
}
exports.replaceProxy = replaceProxy;

var setVariationWeight = function(tile, other, weight, undoGroup=[]) {
    var vr = tile.getRelation(other);
    if(weight < 0) {
        vr.setWeight(vr.getWeight(), undoGroup);
        return;
    } else if(weight == 0) {
        var validWeight = false;
        var tRel = tile.getRelations();
        for(var r in tRel) {
            var rel = tRel[r];
            if(rel.r instanceof TileRelationProxy && rel.t != other && rel.r.isReverse) {
                if(rel.r.getWeight() > 0) {
                    validWeight = true;
                    break;
                }
            }
        }
        if(!validWeight) {
            vr.setWeight(vr.getWeight(), undoGroup);
            return;
        }
    }
    vr.setWeight(weight, undoGroup);
}
exports.setVariationWeight = setVariationWeight;

var convert2_0_0Blob = function(tile, base, undoGroup=[], errorGroup=[]) {
    var newRelationValid = function(tile) {
        var tRels = tile.getRelations();
        for(var tr in tRels) {
            if(!(tRels[tr].r instanceof TileRelationProxy && tRels[tr].r.isReverse)
            && !(tRels[tr].r instanceof TileRelationBlob && tRels[tr].r.origin == tile && tRels[tr].t != false)
            && !(tRels[tr].r instanceof TileRelationBlob && tRels[tr].r.origin != tile)
            && !(tRels[tr].r instanceof TileRelationBlobBorder && !tRels[tr].r.isBorder)
            && !(tRels[tr].r instanceof TileRelationPropBackground && tRels[tr].r.isBackground)) {
                return false;
            }
        }
        return true;
    }
    if(base == null || !newRelationValid(base)) {
        if(base != null) {
            errorGroup.push({msg:"Tile %T has incompatible relations.\nBorders have not been converted.", tiles:[base]});
        }
        return;
    }
    //get all tiles to process
    //get bset to be used for base->false relation
    var relBset = null;
    var processTiles = [null];
    var tRel = tile.getRelations();
    for(var i in tRel) {
        var rel = tRel[i];
        if(rel.r instanceof TileRelationBlobPre2_0_0) {
            relBset = rel.r.bset;
            processTiles[0] = [tile, rel.r.getIndexMatrix(), rel.r.baseTile];
            if(rel.t != tile) {
                var revRel = rel.t.getRelation(tile);
                processTiles.push([rel.t, revRel.getIndexMatrix(), revRel.baseTile]);
            }
        }
    }
    if(relBset == null) {
        return;
    }
    //create base->false relation
    base.registerRelation(false, new TileRelationBlob(relBset, base), undoGroup);
    //process every tile
    for(var k in processTiles) {
        var pTile = processTiles[k][0];
        //remove pre 2.0.0 relations
        var tRel = pTile.getRelations();
        for(var i in tRel) {
            var rel = tRel[i];
            if(rel.r instanceof TileRelationBlobPre2_0_0) {
                pTile.removeRelation(rel.t, undoGroup);
            }
        }
        //get gen matrix
        var preMatrix = processTiles[k][1];
        var genMatrix = [];
        for(var i in preMatrix) {
            if(preMatrix[i] == processTiles[k][2]) {
                genMatrix.push(base);
            } else {
                genMatrix.push(false);
            }
        }
        for(var i = 0; i < 4; i++) {
            if(genMatrix[(i*2+7)%8] != base || genMatrix[(i*2+1)%8] != base) {
                genMatrix[i*2] = null;
            }
        }
        //add border to the relation
        base.registerRelation(pTile, new TileRelationBlobBorder(genMatrix, false), undoGroup);
        pTile.registerRelation(base, new TileRelationBlobBorder(genMatrix, true), undoGroup);
    }
}
exports.convert2_0_0Blob = convert2_0_0Blob;

var convert2_0_0Wang = function(tile, base0, base1, undoGroup=[], errorGroup=[]) {
    if(base0 == base1) {
        errorGroup.push({msg:"Please select two different tiles."});
        return;
    }
    var newRelationValid = function(tile, other) {
        var tRels = tile.getRelations();
        for(var tr in tRels) {
            if(!(tRels[tr].r instanceof TileRelationProxy && tRels[tr].r.isReverse)
            && !(tRels[tr].r instanceof TileRelationWang && tRels[tr].t != other)
            && !(tRels[tr].r instanceof TileRelationWangBorder && !tRels[tr].r.isBorder)
            && !(tRels[tr].r instanceof TileRelationPropBackground && tRels[tr].r.isBackground)) {
                return false;
            }
        }
        return true;
    }
    if(base0 == null || base1 == null || !newRelationValid(base0, base1) || !newRelationValid(base1, base0)) {
        if(!newRelationValid(base0, base1)) {
            errorGroup.push({msg:"Tile %T has incompatible relations.\nBorders have not been converted.", tiles:[base0]});
        }
        if(!newRelationValid(base1, base0)) {
            errorGroup.push({msg:"Tile %T has incompatible relations.\nBorders have not been converted.", tiles:[base1]});
        }
        return;
    }
    //get all tiles to process
    //get bset to be used for base0->base1 relation
    var relBset = null;
    var processTiles = [null];
    var tRel = tile.getRelations();
    for(var i in tRel) {
        var rel = tRel[i];
        if(rel.r instanceof TileRelationWangPre2_0_0) {
            relBset = rel.r.bset;
            processTiles[0] = [tile, rel.r.getIndexMatrix(), rel.r.baseTile0];
            if(rel.t != tile) {
                var revRel = rel.t.getRelation(tile);
                processTiles.push([rel.t, revRel.getIndexMatrix(), revRel.baseTile0]);
            }
        }
    }
    if(relBset == null) {
        return;
    }
    //create base0->base1 relation
    var rel = new TileRelationWang(relBset, base0);
    base0.registerRelation(base1, rel, undoGroup);
    base1.registerRelation(base0, rel, undoGroup);
    //process every tile
    for(var k in processTiles) {
        var pTile = processTiles[k][0];
        //remove pre 2.0.0 relations
        var tRel = pTile.getRelations();
        for(var i in tRel) {
            var rel = tRel[i];
            if(rel.r instanceof TileRelationWangPre2_0_0) {
                pTile.removeRelation(rel.t, undoGroup);
            }
        }
        //get gen matrix
        var preMatrix = processTiles[k][1];
        var genMatrix = [];
        for(var i in preMatrix) {
            if(preMatrix[i] == processTiles[k][2]) {
                genMatrix.push(base0);
            } else {
                genMatrix.push(base1);
            }
        }
        //add border to the relation
        var rel0 = new TileRelationWangBorder(genMatrix, false);
        var rel1 = new TileRelationWangBorder(genMatrix, true);
        base0.registerRelation(pTile, rel0, undoGroup);
        pTile.registerRelation(base0, rel1, undoGroup);
        base1.registerRelation(pTile, rel0, undoGroup);
        pTile.registerRelation(base1, rel1, undoGroup);
    }
    return;
}
exports.convert2_0_0Wang = convert2_0_0Wang;

var set = new TileGrid();
var tileChangedSetCallback = new CallbackManager();
var regionAddedSetCallback = new CallbackManager();
var regionRemovedSetCallback = new CallbackManager();
var regionChangedSetCallback = new CallbackManager();

var tileChangedSetSubscribe = function(func) {
	tileChangedSetCallback.subscribe(func);
}
exports.tileChangedSetSubscribe = tileChangedSetSubscribe;

var regionAddedSetSubscribe = function(func) {
    regionAddedSetCallback.subscribe(func);
}
exports.regionAddedSetSubscribe = regionAddedSetSubscribe;

var regionRemovedSetSubscribe = function(func) {
    regionRemovedSetCallback.subscribe(func);
}
exports.regionRemovedSetSubscribe = regionRemovedSetSubscribe;

var regionChangedSetSubscribe = function(func) {
    regionChangedSetCallback.subscribe(func);
}
exports.regionChangedSetSubscribe = regionChangedSetSubscribe;

var getTileSet = function(x, y) {
	return set.getTile(x, y);
}
exports.getTileSet = getTileSet;

var getTilePositionSet = function(tile) {
    var setTiles = set.getTiles();
    for(var i in setTiles) {
        if(setTiles[i].tile == tile) {
            return setTiles[i].pos;
        }
    }
    return null;
}
exports.getTilePositionSet = getTilePositionSet;

/** 重建 Set 页的 TileGrid 视图后，从模型回填图块与区域（正交/等距切换时视图会换新 DOM 但数据仍在 set 中）。 */
var syncTileGridFromSetView = function(tileGridView) {
    var setTiles = set.getTiles();
    for(var k in setTiles) {
        var e = setTiles[k];
        if(e != null && e.tile != null) {
            tileGridView.setTile(e.tile, e.pos.x, e.pos.y);
        }
    }
    var regions = set.getRegions();
    for(var ri = 0; ri < regions.length; ri++) {
        tileGridView.addRegion(regions[ri]);
    }
};
exports.syncTileGridFromSetView = syncTileGridFromSetView;

/** 重建沙盒 TileGrid 后，从 sandbox 回填各层图块。 */
var syncSandboxTileGridView = function(tileGridView) {
    var tiles = sandbox.getTiles();
    for(var i = 0; i < tiles.length; i++) {
        var t = tiles[i];
        if(t.tile != null) {
            tileGridView.setTile(t.tile, t.pos.x, t.pos.y, t.pos.z);
        }
    }
};
exports.syncSandboxTileGridView = syncSandboxTileGridView;

var setTilesSetRaw = function(tiles, undoGroup=[]) {
    var prev_tiles = [];
    for(var i in tiles) {
        var tile = tiles[i];
        var ttile = set.getTile(tile.x, tile.y);
        if(ttile != null) {
            //ttile.inSet = false;
            ttile.unreference();
        }
        prev_tiles.push({x:tile.x, y:tile.y, tile:ttile});
    }
    var undoParams = {action:'set_change', prev_tiles:prev_tiles};
    undoGroup.push(undoParams);

    var changePos = [];
    for(var i in tiles) {
        var tile = tiles[i];
        if(tile.tile != null) {
            //tile.tile.inSet = true;
            tile.tile.reference();
        }
        set.setTile(tile.tile, tile.x, tile.y);
        changePos.push({x:tile.x, y:tile.y});
    }
    tileChangedSetCallback.notify(changePos);
}
var deleteTile = function(tile, undoGroup=[]) {
    //relations
    tile.clearRelations(undoGroup);
    //sandbox
    var addTiles = [];
    for(var r in tile.sandboxRefs) {
        var ref = tile.sandboxRefs[r];
        addTiles.push({x:ref.x, y:ref.y, z:ref.z, tile:null});
    }
    if(addTiles.length > 0) {
        setTilesSandboxRaw(addTiles, undoGroup);
    }
}

var setTilesSet = function(tiles, undoGroup=[]) { //tiles = [{x, y, tile}, {x, y, tile}]
    //delete operations
    //delete operations
    for(var i in tiles) {
        var prevTile = set.getTile(tiles[i].x, tiles[i].y);
        var tile = tiles[i].tile;
        if(prevTile != null) {
            prevTile.deleting++;
        }
        if(tile != null) {
            tile.deleting--;
        }
    }
    for(var i in tiles) {
        var prevTile = set.getTile(tiles[i].x, tiles[i].y);
        var tile = tiles[i].tile;
        if(prevTile != null) {
            var d = prevTile.deleting;
            prevTile.deleting = 0;
            if(d > 0) {
                deleteTile(prevTile, undoGroup);
            }
        }
        if(tile != null) {
            tile.deleting = 0;
        }
    }

    //set tiles
    //set tiles
    setTilesSetRaw(tiles, undoGroup);
}
exports.setTilesSet = setTilesSet;

var moveTilesSet = function(positions, ox, oy, undoGroup=[]) {
    var minX, minY, maxX, maxY;
    var firstPos = true;
    for(var i = 0; i < positions.length; i++) {
        if(positions[i].x < minX || firstPos) {
            minX = positions[i].x;
        }
        if(positions[i].x > maxX || firstPos) {
            maxX = positions[i].x;
        }
        if(positions[i].y < minY || firstPos) {
            minY = positions[i].y;
        }
        if(positions[i].y > maxY || firstPos) {
            maxY = positions[i].y;
        }
        firstPos = false;
    }
    var w = maxX-minX+1;
    var h = maxY-minY+1;
    var posCache = [];
    var positionsNonNull = [];
    var tilesNonNull = [];
    for(var i in positions) {
        var pos = positions[i];
        var cx = (pos.x-minX);
        var cy = (pos.y-minY);
        var idx = cx*h+cy;
        var tile = set.getTile(pos.x, pos.y);
        if(tile != null) {
            posCache[idx] = 2;
            positionsNonNull.push(pos);
            tilesNonNull.push(tile);
        } else {
            posCache[idx] = 1;
        }
    }

    var unique = [];
    var prev_tiles = [];
    for(var i in positionsNonNull) {
        var pos = positionsNonNull[i];
        var tile = tilesNonNull[i];
        var cx = (pos.x-minX)-ox;
        var cy = (pos.y-minY)-oy;
        var idx = cx*h+cy;
        if(cx < 0 || cx >= w || cy < 0 || cy >= h || posCache[idx] < 2 || posCache[idx] == undefined) {
            unique.push({x:pos.x, y:pos.y});
            prev_tiles.push({x:pos.x, y:pos.y, tile:tile});
        }
        unique.push({x:pos.x+ox, y:pos.y+oy});
        var setTile = set.getTile(pos.x+ox, pos.y+oy);
        prev_tiles.push({x:pos.x+ox, y:pos.y+oy, tile:setTile});
        cx = (pos.x-minX)+ox;
        cy = (pos.y-minY)+oy;
        idx = cx*h+cy;
        if(cx < 0 || cx >= w || cy < 0 || cy >= h || posCache[idx] == undefined) {
            if(setTile != null) {
                //setTile.inSet = false;
                setTile.unreference();
                deleteTile(setTile, undoGroup);
            }
        }
    }

    //set tiles
    //set tiles
    var undoParams = {action:'set_change', prev_tiles:prev_tiles};
    undoGroup.push(undoParams);

    set.moveTiles(positionsNonNull, ox, oy);

    tileChangedSetCallback.notify(unique);
}
exports.moveTilesSet = moveTilesSet;

var addRegionSetRaw = function(region, undoGroup=[]) {
    var undoParams = {action:'set_region_added', region:region};
    undoGroup.push(undoParams);

    set.addRegion(region);
    region.initRegion();
    regionAddedSetCallback.notify(region);
}
var addRegionSet = function(region, undoGroup=[]) {
    var addTiles = [];
    var tiles = region.getSelected();
    for(var i in tiles) {
        var tile = tiles[i];
        addTiles.push({x:tile.x, y:tile.y, tile:null});
    }
    setTilesSet(addTiles, undoGroup);

    addRegionSetRaw(region, undoGroup);
}
exports.addRegionSet = addRegionSet;

var removeRegionSet = function(region, undoGroup=[]) {
    var undoParams = {action:'set_region_removed', region:region};
    undoGroup.push(undoParams);

    set.removeRegion(region);
    region.finRegion();
    regionRemovedSetCallback.notify(region);
}
exports.removeRegionSet = removeRegionSet;

var moveRegionSetRaw = function(region, ox, oy, undoGroup=[]) {
    var undoParams = {action:'set_region_moved', region:region, offset:{x:ox, y:oy}};
    undoGroup.push(undoParams);

    region.translate(ox, oy);
    regionChangedSetCallback.notify(region);
}
var moveRegionSet = function(region, ox, oy, undoGroup=[]) {
    var positions = region.getSelected();
    moveTilesSet(positions, ox, oy, undoGroup);

    moveRegionSetRaw(region, ox, oy, undoGroup);
}
exports.moveRegionSet = moveRegionSet;

var toImageSet = function(positions) {
    //get boundaries
    var lowX = 0;
    var lowY = 0;
    var highX = 0;
    var highY = 0;
    for(var i = 0; i < positions.length; i++) {
        var pos = positions[i];
        if(pos.x < lowX || i == 0) {
            lowX = pos.x;
        }
        if(pos.x > highX || i == 0) {
            highX = pos.x;
        }
        if(pos.y < lowY || i == 0) {
            lowY = pos.y;
        }
        if(pos.y > highY || i == 0) {
            highY = pos.y;
        }
    }
    var canvas;
    if(tileShape == Shape.ORTHOGRAPHIC) {
        //build canvas
        canvas = document.createElement('canvas');
        canvas.width  = (highX+1-lowX)*tileWidth
        canvas.height = (highY+1-lowY)*tileWidth;
        //draw
        var promises = [];
        var ctx = canvas.getContext('2d');
        for(var i in positions) {
            var pos = positions[i];
            var tile = getTileSet(pos.x, pos.y);
            if(tile != null) {
                (function(pos) {
                    var promise = new Promise(function(resolve, reject) {
                        tile.getImage().then(function(img) {
                            ctx.drawImage(img, (pos.x-lowX)*tileWidth, (pos.y-lowY)*tileWidth);
                            resolve();
                        });
                    });
                    promises.push(promise);
                })(pos);
            }
        }
    } else if(tileShape == Shape.ISOMETRIC) {
        //build canvas
        canvas = document.createElement('canvas');
        canvas.width  = (highX+1-lowX)*tileWidth
        canvas.height = (highY+1-lowY)*tileHeight;
        //draw
        var promises = [];
        var ctx = canvas.getContext('2d');
        for(var i in positions) {
            var pos = positions[i];
            var tile = getTileSet(pos.x, pos.y);
            if(tile != null) {
                (function(pos) {
                    var promise = new Promise(function(resolve, reject) {
                        tile.getImage().then(function(img) {
                            ctx.drawImage(img, (pos.x-lowX)*tileWidth, (pos.y-lowY)*tileHeight);
                            resolve();
                        });
                    });
                    promises.push(promise);
                })(pos);
            }
        }
    }
    //finish
    return new Promise(function(resolve, reject) {
        Promise.all(promises).then(function() {
            var url = canvas.toDataURL('image/png');
            resolve(nativeImage.createFromDataURL(url));
        });
    });
}
exports.toImageSet = toImageSet;

var sandbox = new LayeredTileGrid();
var tileChangedSandboxCallback = new CallbackManager();
var layerAddedSandboxCallback = new CallbackManager();
var layerRemovedSandboxCallback = new CallbackManager();
var layersReorderedSandboxCallback = new CallbackManager();
var layerChangedSandboxCallback = new CallbackManager();

var tileChangedSandboxSubscribe = function(func) {
    tileChangedSandboxCallback.subscribe(func);
}
exports.tileChangedSandboxSubscribe = tileChangedSandboxSubscribe;

var layerAddedSandboxSubscribe = function(func) {
    layerAddedSandboxCallback.subscribe(func);
}
exports.layerAddedSandboxSubscribe = layerAddedSandboxSubscribe;
exports.layersChangedSandboxSubscribe = layerAddedSandboxSubscribe;

var layerRemovedSandboxSubscribe = function(func) {
    layerRemovedSandboxCallback.subscribe(func);
}
exports.layerRemovedSandboxSubscribe = layerRemovedSandboxSubscribe;

var layersReorderedSandboxSubscribe = function(func) {
    layersReorderedSandboxCallback.subscribe(func);
}
exports.layersReorderedSandboxSubscribe = layersReorderedSandboxSubscribe;

var layerChangedSandboxSubscribe = function(func) {
    layerChangedSandboxCallback.subscribe(func);
}
exports.layerChangedSandboxSubscribe = layerChangedSandboxSubscribe;

var getLayersSandbox = function() {
    return sandbox.getLayers();
}
exports.getLayersSandbox = getLayersSandbox;

var addLayerSandboxRaw = function(layer, i, undoGroup=[]) {
    var undoParams = {action:'sandbox_layer_added', id:i};
    undoGroup.push(undoParams);

    sandbox.insertLayer(layer, i);
    layerAddedSandboxCallback.notify(i);

    var layerTiles = layer.grid.getTiles();
    for(var key in layerTiles) {
        var tile = layerTiles[key];
        tileChangedSandboxCallback.notify(tile.pos.x, tile.pos.y, i);
    }
}
var addLayerSandbox = function(undoGroup=[]) {
    var undoParams = {action:'sandbox_layer_added', id:sandbox.getLayers().length};
    undoGroup.push(undoParams);

    sandbox.addLayer();
    layerAddedSandboxCallback.notify(sandbox.getLayers().length-1);
}
exports.addLayerSandbox = addLayerSandbox;

var removeLayerSandbox = function(i, undoGroup=[]) {
    if(sandbox.getLayers().length > 1) {
        var undoParams = {action:'sandbox_layer_removed', layer:sandbox.getLayers()[i], id:i};
        undoGroup.push(undoParams);

        sandbox.removeLayer(i);
        layerRemovedSandboxCallback.notify(i);
    }
}
exports.removeLayerSandbox = removeLayerSandbox;

var reorderLayerSandbox = function(i, newI, undoGroup=[]) {
    var undoParams = {action:'sandbox_layer_reordered', id:i, new_id:newI};
    undoGroup.push(undoParams);

    sandbox.reorderLayer(i, newI);
    layersReorderedSandboxCallback.notify(i, newI);
}
exports.reorderLayerSandbox = reorderLayerSandbox;

var editLayerSandbox = function(i, visible=null, name=null, undoGroup=[]) {
    var undoParams = {action:'sandbox_layer_edited', id:i, prev_visible:sandbox.getLayers()[i].visible, prev_name:sandbox.getLayers()[i].name};
    undoGroup.push(undoParams);

    sandbox.editLayer(i, visible, name);
    layerChangedSandboxCallback.notify(i);
}
exports.editLayerSandbox = editLayerSandbox;

var getTileSandbox = function(x, y, z=0) {
    return sandbox.getTile(x, y, z);
}
exports.getTileSandbox = getTileSandbox;

var getTileKey = function(x, y, z) {
    var a = 2*x;
    if(x < 0) { a = -2*x-1; }
    var b = 2*y;
    if(y < 0) { b = -2*y-1; }
    var c = ((a+b)*(a+b+1)+b)/2;
    return ((c+z)*(c+z+1)+z)/2;
}

var setTilesSandboxRaw = function(tiles, undoGroup=[]) {
    var prev_tiles = [];
    var keys = [];
    for(var i in tiles) {
        var tile = tiles[i];
        var key = getTileKey(tile.x, tile.y, tile.z);
        keys.push(key);
        var tt = sandbox.getTile(tile.x, tile.y, tile.z);
        if(tt != null) {
            delete tt.sandboxRefs[key];
        }
        prev_tiles.push({x:tile.x, y:tile.y, z:tile.z, tile:tt});
    }
    var undoParams = {action:'sandbox_change', prev_tiles:prev_tiles};
    undoGroup.push(undoParams);

    for(var i in tiles) {
        var tile = tiles[i];
        var key = keys[i];
        if(tile.tile != null) {
            tile.tile.sandboxRefs[key] = {x:tile.x, y:tile.y, z:tile.z};
        }
        sandbox.setTile(tile.tile, tile.x, tile.y, tile.z);
        tileChangedSandboxCallback.notify(tile.x, tile.y, tile.z);
    }
}
var setTilesSandbox = function(tiles, undoGroup=[]) {
    var setTiles = set.getTiles();
    var minX = -1;
    var minY = 0;
    var maxX = 0;
    var maxY = 0;
    var first = true;
    for(var k in setTiles) {
        var tile = setTiles[k].pos;
        if(tile.x < minX || first) {
            minX = tile.x;
        }
        if(tile.x > maxX || first) {
            maxX = tile.x;
        }
        if(tile.y < minY || first) {
            minY = tile.y;
        }
        if(tile.y > maxY || first) {
            maxY = tile.y;
        }
        first = false;
    }
    var newOrigin = {x:maxX+1, y:minY};

    var addedIndex = 0;
    var addTiles = [];
    for(var i in tiles) {
        var sandboxTile = tiles[i].tile;
        if(sandboxTile == null) {
            continue;
        }
        if(!sandboxTile.inSet) {
            var setX = newOrigin.x+addedIndex%8;
            var setY = newOrigin.y+Math.floor(addedIndex/8);
            addedIndex++;
            //sandboxTile.inSet = true;
            sandboxTile.reference();
            addTiles.push({x:setX, y:setY, tile:sandboxTile});
        }
    }
    if(addTiles.length > 0) {
        setTilesSet(addTiles, undoGroup);
    }

    setTilesSandboxRaw(tiles, undoGroup);
}
exports.setTilesSandbox = setTilesSandbox;

var moveTilesSandbox = function(positions, ox, oy, undoGroup=[], z=0) {
    var minX, minY, maxX, maxY;
    var firstPos = true;
    for(var i = 0; i < positions.length; i++) {
        if(positions[i].x < minX || firstPos) {
            minX = positions[i].x;
        }
        if(positions[i].x > maxX || firstPos) {
            maxX = positions[i].x;
        }
        if(positions[i].y < minY || firstPos) {
            minY = positions[i].y;
        }
        if(positions[i].y > maxY || firstPos) {
            maxY = positions[i].y;
        }
        firstPos = false;
    }
    var w = maxX-minX+1;
    var h = maxY-minY+1;
    var posCache = [];
    var positionsNonNull = [];
    var tilesNonNull = [];
    for(var i in positions) {
        var pos = positions[i];
        var cx = (pos.x-minX);
        var cy = (pos.y-minY);
        var idx = cx*h+cy;
        var tile = sandbox.getTile(pos.x, pos.y, z);
        if(tile != null) {
            posCache[idx] = 2;
            positionsNonNull.push(pos);
            tilesNonNull.push(tile);
        } else {
            posCache[idx] = 1;
        }
    }

    var unique = [];
    var prev_tiles = [];
    for(var i in positionsNonNull) {
        var pos = positionsNonNull[i];
        var tile = tilesNonNull[i];
        var cx = (pos.x-minX)-ox;
        var cy = (pos.y-minY)-oy;
        var idx = cx*h+cy;
        if(cx < 0 || cx >= w || cy < 0 || cy >= h || posCache[idx] < 2) {
            unique.push({x:pos.x, y:pos.y});
            prev_tiles.push({x:pos.x, y:pos.y, z:z, tile:tile});
        }
        unique.push({x:pos.x+ox, y:pos.y+oy});
        prev_tiles.push({x:pos.x+ox, y:pos.y+oy, z:z, tile:sandbox.getTile(pos.x+ox, pos.y+oy, z)});
    }

    var undoParams = {action:'sandbox_change', prev_tiles:prev_tiles};
    undoGroup.push(undoParams);

    sandbox.moveTiles(positionsNonNull, ox, oy, z);

    for(var i in unique) {
        var pos = unique[i];
        tileChangedSandboxCallback.notify(pos.x, pos.y, z);
    }
}
exports.moveTilesSandbox = moveTilesSandbox;

var toImageSandbox = function(positions, layer=-1) {
    //get boundaries
    var lowX = 0;
    var lowY = 0;
    var highX = 0;
    var highY = 0;
    for(var i = 0; i < positions.length; i++) {
        var pos = positions[i];
        if(pos.x < lowX || i == 0) {
            lowX = pos.x;
        }
        if(pos.x > highX || i == 0) {
            highX = pos.x;
        }
        if(pos.y < lowY || i == 0) {
            lowY = pos.y;
        }
        if(pos.y > highY || i == 0) {
            highY = pos.y;
        }
    }
    var canvas;
    if(tileShape == Shape.ORTHOGRAPHIC) {
        //build canvas
        var canvas = document.createElement('canvas');
        canvas.width  = (highX+1-lowX)*tileWidth
        canvas.height = (highY+1-lowY)*tileWidth;
        var ctx = canvas.getContext('2d');
        //draw
        var layers = getLayersSandbox();
        var start = 0;
        var end = layers.length;
        if(layer != -1) {
            start = layer;
            end = parseInt(layer)+1;
        }
        var p = Promise.resolve();
        for(var k = start; k < end; k++) {
            (function(k) {
                p = p.then(function() {
                    return new Promise(function(resolve, reject) {
                        var promises = [];
                        for(var i in positions) {
                            var pos = positions[i];
                            var tile = getTileSandbox(pos.x, pos.y, k);
                            if(tile != null) {
                                (function(pos) {
                                    var promise = new Promise(function(resolve, reject) {
                                        tile.getImage().then(function(img) {
                                            ctx.drawImage(img, (pos.x-lowX)*tileWidth, (pos.y-lowY)*tileWidth);
                                            resolve();
                                        });
                                    });
                                    promises.push(promise);
                                })(pos);
                            }
                        }
                        Promise.all(promises).then(function() {
                            resolve();
                        });
                    });
                });
            }(k));
        }
    } else if(tileShape == Shape.ISOMETRIC) {
        //build canvas
        var canvas = document.createElement('canvas');
        canvas.width  = (highX+1-lowX)*tileWidth
        canvas.height = (highY+1-lowY)*tileHeight;
        var ctx = canvas.getContext('2d');
        //draw
        var layers = getLayersSandbox();
        var start = 0;
        var end = layers.length;
        if(layer != -1) {
            start = layer;
            end = parseInt(layer)+1;
        }
        var p = Promise.resolve();
        for(var k = start; k < end; k++) {
            (function(k) {
                p = p.then(function() {
                    return new Promise(function(resolve, reject) {
                        var promises = [];
                        for(var i in positions) {
                            var pos = positions[i];
                            var tile = getTileSandbox(pos.x, pos.y, k);
                            if(tile != null) {
                                (function(pos) {
                                    var promise = new Promise(function(resolve, reject) {
                                        tile.getImage().then(function(img) {
                                            ctx.drawImage(img, (pos.x-lowX)*tileWidth, (pos.y-lowY)*tileHeight);
                                            resolve();
                                        });
                                    });
                                    promises.push(promise);
                                })(pos);
                            }
                        }
                        Promise.all(promises).then(function() {
                            resolve();
                        });
                    });
                });
            }(k));
        }
    }
    //finish
    return new Promise(function(resolve, reject) {
        p.then(function() {
            var url = canvas.toDataURL('image/png');
            resolve(nativeImage.createFromDataURL(url));
        });
    });
}
exports.toImageSandbox = toImageSandbox;

var drawTilesSandbox = function(tiles, undoGroup=[], z=0) {
    var addTiles = [];
    for(var i in tiles) {
        var tile = tiles[i];
        addTiles.push({x:tile.x, y:tile.y, z:z, tile:tile.tile});
    }
    setTilesSandboxRaw(addTiles, undoGroup);
}
exports.drawTilesSandbox = drawTilesSandbox;

var paintTilesSandbox = function(tiles, undoGroup=[], z=0) {
    var placePropTile = function(tile, x, y, proxy=null) {
        //check to see if prop should be skipped
        //and store tiles to place
        var addTiles = [{x:x, y:y, tile:tile}];
        var isProp = false;
        var cTile = getProxied(getTileSandbox(x, y, z));
        if(tile == cTile || (tile.getRelation(cTile) instanceof TileRelationProp)) {
            if(tile == cTile && proxy != null) {
                placeTileRaw(x, y, proxy);
            }
            return false;
        }
        var blobBg = null;
        var rel = tile.getRelations();
        for(var i in rel) {
            var r = rel[i];
            if(r.r instanceof TileRelationProp) {
                //check if should be skipped
                var c2Tile = getProxied(getTileSandbox(x+r.r.pos.x, y+r.r.pos.y, z));
                if(r.t == c2Tile || (r.t != false && r.t.getRelation(c2Tile) instanceof TileRelationProp)) {
                    return false;
                }
                //store tile
                if(r.t != false) {
                    addTiles.push({x:x+r.r.pos.x, y:y+r.r.pos.y, tile:r.t});
                }
                isProp = true;
            }
            if(r.r instanceof TileRelationPropBackground && !r.r.isBackground) {
                var bgRel = r.t.getRelations();
                for(var k in bgRel) {
                    var bgr = bgRel[k];
                    if(bgr.r instanceof TileRelationBlob && bgr.r.origin == r.t) {
                        blobBg = r.t;
                        break;
                    }
                }
            }
        }
        //place tiles
        if(isProp) {
            //place blob bg around
            if(blobBg != null) {
                for(var i in addTiles) {
                    for(var ax = -1; ax <= 1; ax++) {
                        for(var ay = -1; ay <= 1; ay++) {
                            if(ax == 0 && ay == 0) {
                                continue;
                            }
                            var alreadyPresent = false;
                            for(var k in addTiles) {
                                if(addTiles[k].x == addTiles[i].x+ax && addTiles[k].y == addTiles[i].y+ay) {
                                    alreadyPresent = true;
                                    break;
                                }
                            }
                            if(!alreadyPresent) {
                                //only place outer blob tile (current prop's bg) if it has relations with the tile under where it will be placed
                                var currentT = getProxied(getTileSandbox(addTiles[i].x+ax, addTiles[i].y+ay, z));
                                var treatAs = currentT;
                                if(currentT != null) {
                                    var ctRel = currentT.getRelations();
                                    for(var k in ctRel) {
                                        var ctr = ctRel[k];
                                        if(ctr.r instanceof TileRelationPropBackground && !ctr.r.isBackground) {
                                            treatAs = ctr.t;
                                            break;
                                        }
                                        if(ctr.r instanceof TileRelationBlobBorder && ctr.r.isBorder) {
                                            treatAs = ctr.t;
                                            break;
                                        }
                                    }
                                }
                                var bgpRel = blobBg.getRelation(treatAs);
                                if(treatAs != blobBg && ((bgpRel instanceof TileRelationBlob && bgpRel.origin == blobBg) || blobBg.getRelation(false) instanceof TileRelationBlob)) {
                                    var prevTilePlaced = getProxied(getTileSandbox(addTiles[i].x+ax, addTiles[i].y+ay, z));
                                    placeTileRaw(addTiles[i].x+ax, addTiles[i].y+ay, blobBg);
                                    tilePlaced({x:addTiles[i].x+ax, y:addTiles[i].y+ay, tile:blobBg}, prevTilePlaced);
                                }
                            }
                        }
                    }
                }
            }
            //place all
            var prevTilesPlaced = [];
            for(var i in addTiles) {
                prevTilesPlaced.push(getProxied(getTileSandbox(addTiles[i].x, addTiles[i].y, z)));
                placeTileRaw(addTiles[i].x, addTiles[i].y, addTiles[i].tile);
            }
            //update
            for(var i in addTiles) {
                tilePlaced(addTiles[i], prevTilesPlaced[i]);
            }
            if(proxy != null) {
                placeTileRaw(x, y, proxy);
            }
            return false;
        } else {
            return true;
        }
    }

    //==========
    //==========
    //==========
    //==========

    var adjacentPlaced = [];
    var directPlaced = [];

    var tilePlaced = function(tileDat, prevTile) {
        removeUnderProp(tileDat, prevTile);
        //update adjacents
        directPlaced.push({x:tileDat.x, y:tileDat.y, tileDat:tileDat});
        for(var ax = -1; ax <= 1; ax++) {
            for(var ay = -1; ay <= 1; ay++) {
                //skip center tile
                if(ax == 0 && ay == 0) {
                    continue;
                }
                adjacentPlaced.push({x:tileDat.x+ax, y:tileDat.y+ay, ax:ax, ay:ay, tileDat:tileDat});
            }
        }
    }

    var placeTileRaw = function(x, y, tile) {
        var outputTile = tile;
        if(tile != null) {
            //get all variations
            var variations = [];
            var weightTotal = 0;
            var tRel = tile.getRelations();
            for(var r in tRel) {
                var rel = tRel[r];
                if(rel.r instanceof TileRelationProxy && rel.r.isReverse) {
                    variations.push([rel.r.getWeight(), rel.t]);
                    weightTotal += rel.r.getWeight();
                }
            }
            if(variations.length > 1) {
                var outputWeigh = Math.floor(Math.random()*weightTotal);
                var weightSum = 0;
                for(var i in variations) {
                    weightSum += variations[i][0];
                    if(weightSum > outputWeigh) {
                        outputTile = variations[i][1];
                        break;
                    }
                }
            }
        }
        setTilesSandboxRaw([{x:x, y:y, z:z, tile:outputTile}], undoGroup);
    }

    var removeUnderProp = function(tileDat, prevTile) {
        //remove prop
        if(prevTile != null) {
            var rel = prevTile.getRelations();
            var bgTile = false;
            for(var i in rel) {
                var r = rel[i];
                if(r.r instanceof TileRelationProp && r.t != false) {
                    if(getProxied(getTileSandbox(tileDat.x+r.r.pos.x, tileDat.y+r.r.pos.y, z)) == r.t) {
                        if(bgTile == false) {
                            for(var k in rel) {
                                var r2 = rel[k];
                                if(r2.r instanceof TileRelationPropBackground) {
                                    bgTile = r2.t;
                                    break;
                                }
                            }
                            if(bgTile == false) {
                                bgTile = null;
                            }
                        }
                        placeTileRaw(tileDat.x+r.r.pos.x, tileDat.y+r.r.pos.y, bgTile);
                    }
                }
                if(r.r instanceof TileRelationPropBackground && bgTile == false) {
                    bgTile = r.t;
                }
            }
        }
    }

    var getProxied = function(tile) {
        if(tile == null) {
            return null;
        } else {
            var proxy = tile.getRelationProxy();
            if(proxy == null) {
                return tile;
            } else {
                return proxy;
            }
        }
    }

    //==========
    //==========
    //==========
    //==========

    var adjustBlobTile = function(adjTile, x, y) {
        if(adjTile != null) {
            var rep = adjTile;
            var rel = adjTile.getRelations();
            for(var i in rel) {
                var r = rel[i];
                if(r.r instanceof TileRelationBlobBorder && r.r.isBorder) { //treat blob borders as base tile
                    adjTile = r.t;
                    break;
                }
                if(r.r instanceof TileRelationPropBackground && !r.r.isBackground) { //treat props as bg tile
                    adjTile = r.t;
                    rep = r.t;
                    break;
                }
            }
            var blobAdjacents = [   getProxied(getTileSandbox(x-1, y-1, z)),
                                    getProxied(getTileSandbox(x, y-1, z)),
                                    getProxied(getTileSandbox(x+1, y-1, z)),
                                    getProxied(getTileSandbox(x+1, y, z)),
                                    getProxied(getTileSandbox(x+1, y+1, z)),
                                    getProxied(getTileSandbox(x, y+1, z)),
                                    getProxied(getTileSandbox(x-1, y+1, z)),
                                    getProxied(getTileSandbox(x-1, y, z))];
            for(var i in blobAdjacents) {
                //check if adjacent is border and treat border as base
                if(blobAdjacents[i] != null) {
                    var ar = blobAdjacents[i].getRelations();
                    for(var k in ar) {
                        var r = ar[k];
                        if(r.r instanceof TileRelationBlobBorder && r.r.isBorder) {
                            blobAdjacents[i] = r.t;
                            break;
                        }
                        if(r.r instanceof TileRelationPropBackground && !r.r.isBackground) {
                            blobAdjacents[i] = r.t;
                            break;
                        }
                    }
                }
                //check if adjacent should be treated as a tile or false (any other), except when adjacent is the same tile as the one being placed
                var r = adjTile.getRelation(blobAdjacents[i]);
                if((!(r instanceof TileRelationBlob) || r.origin != adjTile) && blobAdjacents[i] != adjTile) {
                    if(adjTile.getRelation(false) instanceof TileRelationBlob) { //if tile has no relation with 'false', treat unknown tiles as the same species
                        blobAdjacents[i] = false;
                    } else {
                        blobAdjacents[i] = adjTile;
                    }
                }
            }
            var blobBorder = adjTile.getRelationBlobBorder(blobAdjacents);
            if(rep == null || (blobBorder != null && blobBorder != rep) || (blobBorder == null && adjTile != rep)) {
                var prevTilePlaced = getProxied(getTileSandbox(x, y, z));
                if(blobBorder != null) {
                    placeTileRaw(x, y, blobBorder);
                    removeUnderProp({x:x, y:y, tile:blobBorder}, prevTilePlaced);
                } else {
                    placeTileRaw(x, y, adjTile);
                    removeUnderProp({x:x, y:y, tile:blobBorder}, prevTilePlaced);
                }
            }
        }
    }

    var adjustWangTile = function(adjTile, tileDat, ax, ay) {
        //get current matrix for adj tile
        var wangMatrix = null;
        if(adjTile != null) {
            var repeat = true;
            do {
                repeat = false;
                var rel = adjTile.getRelations();
                for(var i in rel) {
                    var r = rel[i];
                    if(r.r instanceof TileRelationWangBorder && r.r.isBorder) {
                        wangMatrix = [  r.r.indexMatrix[0],
                                        r.r.indexMatrix[1],
                                        r.r.indexMatrix[2],
                                        r.r.indexMatrix[3]];
                        break;
                    } else if(r.r instanceof TileRelationWang) {
                        wangMatrix = [  adjTile,
                                        adjTile,
                                        adjTile,
                                        adjTile];
                        break;
                    } else if(r.r instanceof TileRelationPropBackground && !r.r.isBackground) {
                        adjTile = r.t;
                        repeat = true;
                        break;
                    }
                }
            } while(repeat);
        } else {
            wangMatrix = [  false,
                            false,
                            false,
                            false];
        }
        if(wangMatrix != null) {
            var treatAs = tileDat.tile;
            if(treatAs != null) {
                var trel = treatAs.getRelations();
                for(var tk in trel) {
                    var trl = trel[tk];
                    if(trl.r instanceof TileRelationPropBackground && !trl.r.isBackground) {
                        treatAs = trl.t;
                        break;
                    }
                }
            }
            //update adj matrix
            var oldWangMatrix = [wangMatrix[0], wangMatrix[1], wangMatrix[2], wangMatrix[3]];
            if(ax <= 0) {
                if(ay <= 0) {
                    wangMatrix[2] = treatAs;
                }
                if(ay >= 0) {
                    wangMatrix[1] = treatAs;
                }
            }
            if(ax >= 0) {
                if(ay <= 0) {
                    wangMatrix[3] = treatAs;
                }
                if(ay >= 0) {
                    wangMatrix[0] = treatAs;
                }
            }
            var wangMaster = null;
            for(var i in wangMatrix) {
                var wt = wangMatrix[i];
                if(wt == null || wt == false) {
                    continue;
                }
                var rel = wt.getRelations();
                for(var k in rel) {
                    var r = rel[k];
                    if(r.r instanceof TileRelationWang) {
                        wangMaster = wt;
                        break;
                    }
                }
            }
            if(wangMaster != null) {
                //cleanse adj matrix
                for(var i in wangMatrix) {
                    var r = wangMaster.getRelation(wangMatrix[i]);
                    if(!(r instanceof TileRelationWang) && wangMatrix[i] != wangMaster) {
                        wangMatrix[i] = false;
                    }
                }
                //only place if wang matrix changed
                if(oldWangMatrix[0] != wangMatrix[0] || oldWangMatrix[1] != wangMatrix[1] || oldWangMatrix[2] != wangMatrix[2] || oldWangMatrix[3] != wangMatrix[3]) {
                    if(wangMatrix[0] == wangMatrix[1] && wangMatrix[1] == wangMatrix[2] && wangMatrix[2] == wangMatrix[3]) {
                        var prevTilePlaced = getProxied(getTileSandbox(tileDat.x+ax, tileDat.y+ay, z));
                        placeTileRaw(tileDat.x+ax, tileDat.y+ay, wangMatrix[0]);
                        removeUnderProp({x:tileDat.x+ax, y:tileDat.y+ay, tile:wangMatrix[0]}, prevTilePlaced);
                    } else {
                        var wangBorder = wangMaster.getRelationWangBorder(wangMatrix);
                        if(wangBorder != null) {
                            var prevTilePlaced = getProxied(getTileSandbox(tileDat.x+ax, tileDat.y+ay, z));
                            placeTileRaw(tileDat.x+ax, tileDat.y+ay, wangBorder);
                            removeUnderProp({x:tileDat.x+ax, y:tileDat.y+ay, tile:wangBorder}, prevTilePlaced);
                        }
                    }
                }
            } else {
                var prevTilePlaced = getProxied(getTileSandbox(tileDat.x+ax, tileDat.y+ay, z));
                placeTileRaw(tileDat.x+ax, tileDat.y+ay, null);
                removeUnderProp({x:tileDat.x+ax, y:tileDat.y+ay, tile:null}, prevTilePlaced);
            }
        }
    }

    //==========
    //==========
    //==========
    //==========

    //raw placement
    for(var ti in tiles) {
        var tileDat = tiles[ti];
        if(tileDat.tile != null) {
            var pTile = getProxied(tileDat.tile);
            var proxied = tileDat.tile;
            //  ===PROP===
            var notPlaced = placePropTile(pTile, tileDat.x, tileDat.y, proxied);
            //  ===BLOB & WANG===
            if(notPlaced) {
                var prevTilePlaced = getProxied(getTileSandbox(tileDat.x, tileDat.y, z));
                placeTileRaw(tileDat.x, tileDat.y, proxied);
                tilePlaced({x:tileDat.x, y:tileDat.y, tile:pTile}, prevTilePlaced);
            }
        } else {
            var prevTilePlaced = getProxied(getTileSandbox(tileDat.x, tileDat.y, z));
            placeTileRaw(tileDat.x, tileDat.y, tileDat.tile);
            tilePlaced(tileDat, prevTilePlaced);
        }
    }
    //update adjacents and borders
    //adjacents that haven't been overriden by direct placements [WANG|BLOB]
    for(var i in adjacentPlaced) {
        var adj = adjacentPlaced[i];
        var skip = false;
        for(var j in directPlaced) {
            var dir = directPlaced[j];
            if(adj.x == dir.x && adj.y == dir.y) {
                skip = true;
                break;
            }
        }
        if(skip) {
            continue;
        }
        var adjTile = getProxied(getTileSandbox(adj.tileDat.x+adj.ax, adj.tileDat.y+adj.ay, z));
        //  ===BLOB===
        adjustBlobTile(adjTile, adj.tileDat.x+adj.ax, adj.tileDat.y+adj.ay);
        //  ===WANG===
        adjustWangTile(adjTile, adj.tileDat, adj.ax, adj.ay);
    }
    //directs that are not surrounded (can become blob borders) [BLOB]
    var toAdjust = [];
    for(var i in directPlaced) {
        var dir = directPlaced[i];
        var blobAdjacents = [   getProxied(getTileSandbox(dir.x-1, dir.y-1, z)),
                                getProxied(getTileSandbox(dir.x, dir.y-1, z)),
                                getProxied(getTileSandbox(dir.x+1, dir.y-1, z)),
                                getProxied(getTileSandbox(dir.x+1, dir.y, z)),
                                getProxied(getTileSandbox(dir.x+1, dir.y+1, z)),
                                getProxied(getTileSandbox(dir.x, dir.y+1, z)),
                                getProxied(getTileSandbox(dir.x-1, dir.y+1, z)),
                                getProxied(getTileSandbox(dir.x-1, dir.y, z))];
        for(var j in blobAdjacents) {
            if(blobAdjacents[j] != dir.tileDat.tile) {
                toAdjust.push(dir.tileDat);
                break;
            }
        }
    }
    for(var i in toAdjust) {
        var tileDat = toAdjust[i];
        adjustBlobTile(tileDat.tile, tileDat.x, tileDat.y);
    }
}
exports.paintTilesSandbox = paintTilesSandbox;

var exportPackageSet = function(positions, fng, format) {
    var dataset = tileroninXExport.getExportDatasetSet(positions, fng);
    return format.exportContents(dataset, fng, 
    function(fn, resolve, reject) {
        fs.mkdir(fn, function(err) {
            if (err && err.code !== 'EEXIST') {
                reject(new UserError([{msg:"Error writing folder '"+path.relative(path.dirname(fng), fn)+"' ("+err.code+").\nData has not been fully exported."}]));
            }
            resolve();
        })
    }, 
    function(fn, data, resolve, reject, stream) {
        if(stream) {
            var output = fs.createWriteStream(fn);
            output.on('error', function(err) {
                output.end();
                reject(new UserError([{msg:"Error writing file '"+path.relative(path.dirname(fng), fn)+"' ("+err.code+").\nData has not been fully exported."}]));
            }).on('open', function() {
                data.pipe(output);
                resolve();
            });
        } else {
            try {
                fs.writeFileSync(fn, data);
            } catch(e) {
                throw new UserError([{msg:"Error writing file '"+path.relative(path.dirname(fng), fn)+"' ("+e.code+").\nData has not been fully exported."}]);
            }
            resolve();
        }
    });
}
exports.exportPackageSet = exportPackageSet;

var exportPackageMap = function(positions, fng, format) {
    var dataset = tileroninXExport.getExportDatasetMap(positions, fng);
    return format.exportContents(dataset, fng, 
    function(fn, resolve, reject) {
        fs.mkdir(fn, function(err) {
            if (err && err.code !== 'EEXIST') {
                reject(new UserError([{msg:"Error writing folder '"+path.relative(path.dirname(fng), fn)+"' ("+err.code+").\nData has not been fully exported."}]));
            }
            resolve();
        })
    }, 
    function(fn, data, resolve, reject, stream) {
        if(stream) {
            var output = fs.createWriteStream(fn);
            output.on('error', function(err) {
                output.end();
                reject(new UserError([{msg:"Error writing file '"+path.relative(path.dirname(fng), fn)+"' ("+err.code+").\nData has not been fully exported."}]));
            }).on('open', function() {
                data.pipe(output);
                resolve();
            });
        } else {
            try {
                fs.writeFileSync(fn, data);
            } catch(e) {
                throw new UserError([{msg:"Error writing file '"+path.relative(path.dirname(fng), fn)+"' ("+e.code+").\nData has not been fully exported."}]);
            }
            resolve();
        }
    });
}
exports.exportPackageMap = exportPackageMap;
