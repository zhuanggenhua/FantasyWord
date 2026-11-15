var ExportFolder = require('./ExportFolder.js');
var ExportTextFile = require('./ExportTextFile.js');
var ExportVisualFile = require('./ExportVisualFile.js');
var ExportLoopDirectory = require('./ExportLoopDirectory.js');
var ExportBlockField = require('./ExportBlockField.js');
var ExportTextBlock = require('./ExportTextBlock.js');
var ExportTextVariableBlock = require('./ExportTextVariableBlock.js');
var ExportGUIDBlock = require('./ExportGUIDBlock.js');
var ExportNumberVariableBlock = require('./ExportNumberVariableBlock.js');
var ExportLoopBlock = require('./ExportLoopBlock.js');
var ExportGridLoopBlock = require('./ExportGridLoopBlock.js');
var ExportVisualBlockField = require('./ExportVisualBlockField.js');
var ExportVisualImageBlock = require('./ExportVisualImageBlock.js');
var ExportVisualImageVariableBlock = require('./ExportVisualImageVariableBlock.js');
var ExportVisualLoopBlock = require('./ExportVisualLoopBlock.js');

var TileRelationBlob = require('./TileRelationBlob.js');
var TileRelationBlobBorder = require('./TileRelationBlobBorder.js');
var TileRelationWang = require('./TileRelationWang.js');
var TileRelationWangBorder = require('./TileRelationWangBorder.js');

var UserError = require('./UserError.js');

var path = require('path');
var fs = require('fs');
var mathjs = require('mathjs');

/*
    dataset {
        #SCOPE: {}
        #RUNTIME: {}
        timestamp:
        export_name:
        tile_size: <ORTHOGRAPHIC>
        tile_width: <ISOMETRIC>
        tile_height: <ISOMETRIC>
        set_width:
        set_height:
        tile: [{
            index:
            #RUNTIME: {}
            x:
            y:
            image:
        }]
        tile_count:
        blobset: [{
            index:
            #RUNTIME: {}
            REF#tile: 
            member: [{
                index:
                #RUNTIME: {}
                role:
                REF#tile: 
            }]
            member_count:
        }]
        blobset_count:
        wangset: [{
            index:
            #RUNTIME: {}
            REF#tile: 
            member: [{
                index:
                #RUNTIME: {}
                role:
                REF#tile: 
            }]
            member_count:
        }]
        wangset_count:
        misctile: [{
            index:
            #RUNTIME: {}
            REF#tile:
        }]
        misctile_count:
    }
*/
var getExportDatasetSet = function(positions, fn) {
    var dataset = {
        '#SCOPE': {},
        '#RUNTIME': {},
        'timestamp': Math.floor(new Date()/1000),
        'export_name': path.basename(fn, path.extname(fn)),
        'set_width': null,
        'set_height': null,
        'tile': [],
        'tile_count': null,
        'blobset': [],
        'blobset_count': null,
        'wangset': [],
        'wangset_count': null,
        'misctile': [],
        'misctile_count': null
    };

    var tileShape = tileroninX.getTileShape();
    if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
        dataset['tile_size'] = tileroninX.getTileSize();
    } else if(tileShape == tileroninX.Shape.ISOMETRIC) {
        var tileSize = tileroninX.getTileSize();
        dataset['tile_width'] = tileSize[0];
        dataset['tile_height'] = tileSize[1];
    }

    var minX, minY, maxX, maxY;
    var layers = tileroninX.getLayersSandbox();
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
    dataset['set_width'] = maxX-minX+1;
    dataset['set_height'] = maxY-minY+1;

    var uniqueTiles = [];
    for(var i = 0; i < positions.length; i++) {
        var tile = tileroninX.getTileSet(positions[i].x, positions[i].y); if(tile == null) { continue; }
        var tileIndex = uniqueTiles.indexOf(tile);
        if(tileIndex == -1) {
            var tileDataset = {
                'index': uniqueTiles.length,
                '#RUNTIME': {},
                'x': positions[i].x-minX,
                'y': positions[i].y-minY,
                'image': tile.getImage()
            }
            dataset['tile'].push(tileDataset);
            uniqueTiles.push(tile);
        }
    }
    dataset['tile_count'] = uniqueTiles.length;

    var blobSets = [];
    var wangSets = [];
    var miscTiles = [];
    for(var i = 0; i < uniqueTiles.length; i++) {
        var setMember = false;
        var tile = uniqueTiles[i];
        var rels = tile.getRelations();
        for(var r in rels) {
            var rel = rels[r];
            if(rel.r instanceof TileRelationBlob && rel.r.origin == tile) {
                var baseTile = tile;
                var otherTile = rel.t;
                //create blobset
                var setIndex = -1;
                for(var s = 0; s < blobSets.length; s++) {
                    var bs = blobSets[s];
                    if((bs.tileA == baseTile && bs.tileB == otherTile) || (bs.tileB == baseTile && bs.tileA == otherTile)) {
                        setIndex = s;
                        break;
                    }
                }
                if(setIndex == -1) {
                    setIndex = blobSets.length;
                    blobSets.push({tileA:baseTile, tileB:otherTile, members:[]});
                }
                blobSets[setIndex].members.push({tile:tile, role:255});
                setMember = true;
            } else if(rel.r instanceof TileRelationBlobBorder && rel.r.isBorder) {
                //skip complex borders
                var complex = false;
                var indexMatrix = rel.r.getIndexMatrix();
                var baseTile = rel.t;
                var otherTile = null;
                for(var im in indexMatrix) {
                    var imTile = indexMatrix[im];
                    if(imTile == baseTile || imTile == null) {
                        continue;
                    }
                    if(otherTile == null) {
                        otherTile = imTile;
                    } else if(otherTile != imTile) {
                        complex = true;
                        break;
                    }
                }
                if(complex) {
                    continue;
                }
                //create blobset
                var setIndex = -1;
                for(var s = 0; s < blobSets.length; s++) {
                    var bs = blobSets[s];
                    if((bs.tileA == baseTile && bs.tileB == otherTile) || (bs.tileB == baseTile && bs.tileA == otherTile)) {
                        setIndex = s;
                        break;
                    }
                }
                if(setIndex == -1) {
                    setIndex = blobSets.length;
                    blobSets.push({tileA:baseTile, tileB:otherTile, members:[]});
                }
                if(blobSets[setIndex].tileA == baseTile) {
                    var role = 0;
                    for(var im = 0; im < indexMatrix.length; im++) {
                        if(indexMatrix[im] == baseTile) {
                            role += Math.pow(2, im);
                        }
                    }
                    blobSets[setIndex].members.push({tile:tile, role:role});
                    setMember = true;
                }
            } else if(rel.r instanceof TileRelationWang) {
                var baseTile = tile;
                var otherTile = rel.t;
                //create wangset
                var setIndex = -1;
                for(var s = 0; s < wangSets.length; s++) {
                    var ws = wangSets[s];
                    if((ws.tileA == baseTile && ws.tileB == otherTile) || (ws.tileB == baseTile && ws.tileA == otherTile)) {
                        setIndex = s;
                        break;
                    }
                }
                if(setIndex == -1) {
                    setIndex = wangSets.length;
                    wangSets.push({tileA:baseTile, tileB:otherTile, members:[]});
                }
                var role = ((wangSets[setIndex].tileA == baseTile) ? 15 : 0);
                wangSets[setIndex].members.push({tile:tile, role:role});
                if(wangSets[setIndex].tileA == baseTile) {
                    setMember = true;
                }
            } else if(rel.r instanceof TileRelationWangBorder && rel.r.isBorder) {
                //skip complex borders
                var complex = false;
                var indexMatrix = rel.r.getIndexMatrix();
                var baseTile = rel.t;
                var otherTile = false;
                for(var im in indexMatrix) {
                    var imTile = indexMatrix[im];
                    if(imTile == baseTile) {
                        continue;
                    }
                    if(otherTile == false) {
                        otherTile = imTile;
                    } else if(otherTile != imTile) {
                        complex = true;
                        break;
                    }
                }
                if(complex) {
                    continue;
                }
                //create wangset
                var setIndex = -1;
                for(var s = 0; s < wangSets.length; s++) {
                    var ws = wangSets[s];
                    if((ws.tileA == baseTile && ws.tileB == otherTile) || (ws.tileB == baseTile && ws.tileA == otherTile)) {
                        setIndex = s;
                        break;
                    }
                }
                if(setIndex == -1) {
                    setIndex = wangSets.length;
                    wangSets.push({tileA:baseTile, tileB:otherTile, members:[]});
                }
                if(wangSets[setIndex].tileA == baseTile) {
                    var role = 0;
                    for(var im = 0; im < indexMatrix.length; im++) {
                        if(indexMatrix[im] == baseTile) {
                            role += Math.pow(2, im);
                        }
                    }
                    wangSets[setIndex].members.push({tile:tile, role:role});
                    setMember = true;
                }
            }
        }
        if(!setMember) {
            miscTiles.push(tile);
        }
    }

    for(var s = 0; s < blobSets.length; s++) {
        var setDataset = {
            'index': s,
            '#RUNTIME': {},
            'REF#tile': null,
            'member': [],
            'member_count': null
        }
        if(uniqueTiles.indexOf(blobSets[s].tileA) == -1) {
            setDataset['REF#tile'] = uniqueTiles.indexOf(blobSets[s].members[0].tile);
        } else {
            setDataset['REF#tile'] = uniqueTiles.indexOf(blobSets[s].tileA);
        }
        var set = blobSets[s];
        for(var ss = 0; ss < set.members.length; ss++) {
            var setMemberDataset = {
                'index': ss,
                '#RUNTIME': {},
                'role': set.members[ss].role,
                'REF#tile': uniqueTiles.indexOf(set.members[ss].tile)
            }
            setDataset['member'].push(setMemberDataset);
        }
        setDataset['member_count'] = set.members.length;
        dataset['blobset'].push(setDataset);
    }
    dataset['blobset_count'] = blobSets.length;

    for(var s = 0; s < wangSets.length; s++) {
        var setDataset = {
            'index': s,
            '#RUNTIME': {},
            'REF#tile': null,
            'member': [],
            'member_count': null
        }
        if(uniqueTiles.indexOf(wangSets[s].tileA) == -1) {
            setDataset['REF#tile'] = uniqueTiles.indexOf(wangSets[s].members[0].tile);
        } else {
            setDataset['REF#tile'] = uniqueTiles.indexOf(wangSets[s].tileA);
        }
        var set = wangSets[s];
        console.log(set.members);
        for(var ss = 0; ss < set.members.length; ss++) {
            var setMemberDataset = {
                'index': ss,
                '#RUNTIME': {},
                'role': set.members[ss].role,
                'REF#tile': uniqueTiles.indexOf(set.members[ss].tile)
            }
            setDataset['member'].push(setMemberDataset);
        }
        setDataset['member_count'] = set.members.length;
        dataset['wangset'].push(setDataset);
    }
    dataset['wangset_count'] = wangSets.length;

    for(var s = 0; s < miscTiles.length; s++) {
        var miscDataset = {
            'index': s,
            '#RUNTIME': {},
            'REF#tile': uniqueTiles.indexOf(miscTiles[s])
        }
        dataset['misctile'].push(miscDataset);
    }
    dataset['misctile_count'] = miscTiles.length;

    return dataset;
}
exports.getExportDatasetSet = getExportDatasetSet;

/*
    dataset {
        #SCOPE: {}
        #RUNTIME: {}
        timestamp:
        export_name:
        tile_size: <ORTHOGRAPHIC>
        tile_width: <ISOMETRIC>
        tile_height: <ISOMETRIC>
        map_width:
        map_height:
        tile: [{
            index:
            #RUNTIME: {}
            image:
        }]
        tile_count:
        layer: [{
            index:
            #RUNTIME: {}
            name:
            position: [{
                index:
                #RUNTIME: {}
                x:
                y:
                REF#tile: 
            }]
            position_count:
        }]
        layer_count:
        layer!tile#position_count:
    }
*/
var getExportDatasetMap = function(positions, fn) {
    var dataset = {
        '#SCOPE': {},
        '#RUNTIME': {},
        'timestamp': Math.floor(new Date()/1000),
        'export_name': path.basename(fn, path.extname(fn)),
        'map_width': null,
        'map_height': null,
        'tile': [],
        'tile_count': null,
        'layer': [],
        'layer_count': null,
        'layer!tile#position_count': null
    };

    var tileShape = tileroninX.getTileShape();
    if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
        dataset['tile_size'] = tileroninX.getTileSize();
    } else if(tileShape == tileroninX.Shape.ISOMETRIC) {
        var tileSize = tileroninX.getTileSize();
        dataset['tile_width'] = tileSize[0];
        dataset['tile_height'] = tileSize[1];
    }

    var minX, minY, maxX, maxY;
    var layers = tileroninX.getLayersSandbox();
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
    dataset['map_width'] = maxX-minX+1;
    dataset['map_height'] = maxY-minY+1;

    var uniqueTiles = [];
    var refCount = [];
    for(var k = 0; k < layers.length; k++) {
        var layerDataset = {
            'index': k,
            '#RUNTIME': {},
            'name': layers[k].name,
            'position': [],
            'position_count': null
        }
        refCount.push([]);
        for(var j = 0; j < uniqueTiles.length; j++) {
            refCount[k].push(0);
        }
        for(var i = 0; i < positions.length; i++) {
            var tile = tileroninX.getTileSandbox(positions[i].x, positions[i].y, k); if(tile == null) { continue; }
            var positionDataset = {
                'index': i,
                '#RUNTIME': {},
                'x': positions[i].x-minX,
                'y': positions[i].y-minY,
                'REF#tile': null
            }

            var tileIndex = uniqueTiles.indexOf(tile);
            if(tileIndex == -1) {
                var tileDataset = {
                    'index': uniqueTiles.length,
                    '#RUNTIME': {},
                    'image': tile.getImage()
                }
                dataset['tile'].push(tileDataset);
                tileIndex = uniqueTiles.length;
                uniqueTiles.push(tile);
                for(var j = 0; j < refCount.length; j++) {
                    refCount[j].push(0);
                }
            }
            refCount[k][tileIndex]++;

            positionDataset['REF#tile'] = tileIndex;
            layerDataset['position'].push(positionDataset);
        }
        layerDataset['position_count'] = layerDataset['position'].length;
        dataset['layer'].push(layerDataset);
    }
    dataset['tile_count'] = uniqueTiles.length;
    dataset['layer_count'] = layers.length;

    dataset['layer!tile#position_count'] = refCount;

    return dataset;
}
exports.getExportDatasetMap = getExportDatasetMap;

var datasetType = Object.freeze({"TEXT":0, "NUMBER":1, "IMAGE":2, "LIST":3});
exports.datasetType = datasetType;
var getDatasetValueType = function(val) {
    if(val.constructor === Array) {
        return datasetType.LIST;
    } else if(val instanceof Promise) {
        return datasetType.IMAGE;
    } else if(!isNaN(val)) {
        return datasetType.NUMBER;
    } else if(typeof val === 'string' || val instanceof String) {
        return datasetType.TEXT;
    }
}
exports.getDatasetValueType = getDatasetValueType;

/*
    returns ExportFolder root for parsed XML file at fn
*/
var parseExportFormat = function(fn) {
    var filename = path.basename(fn);
    if(!fs.existsSync(fn)) {
        throw new UserError([{msg:"Could not find file '"+filename+"'."}]);
    }
    if(!fn.endsWith(".tsfo") && !fn.endsWith(".tsfi")) {
        throw new UserError([{msg:"Invalid export format: File has an invalid extension.\n'"+filename+"' has not been loaded."}]);
    }
    var domParser = new DOMParser();
    xmlDoc = domParser.parseFromString(fs.readFileSync(fn), "text/xml");
    if(xmlDoc.getElementsByTagName('parsererror').length > 0) {
        throw new UserError([{msg:"Invalid export format: Invalid XML in file.\n'"+filename+"' has not been loaded."}]);
    }

    ////PARSING////
    ////PARSING////
    ////PARSING////
    ////PARSING////

    var translations = [];

    function parseNvar(tag, tagName) {
        //get expression
        var expression = "x0";
        var exVar = tag.getAttribute('expression');
        if(exVar != null) {
            expression = exVar;
        }

        //get operands
        var operands = [];
        var tTables = [];
        for(var j in tag.childNodes) {
            var attrTag = tag.childNodes[j];
            if(attrTag.nodeType == Node.ELEMENT_NODE && attrTag.nodeName === 'x') {
                var aVar = attrTag.getAttribute('v');
                if(aVar == null) {
                    throw new UserError([{msg:"Invalid export format: Missing 'v' attribute at <x>.\n'"+filename+"' has not been loaded."}]);
                } else {
                    if(/[#]/.test(aVar)) {
                        throw new UserError([{msg:"Invalid export format: Illegal character in 'v' attribute at <x>.\n'"+filename+"' has not been loaded."}]);
                    }
                }
                operands.push(aVar);
                //get translation
                var tVar = attrTag.getAttribute('tl');
                if(tVar != null) {
                    var tl = null;
                    for(var tli in translations) {
                        if(translations[tli].name === tVar) {
                            tl = translations[tli];
                        }
                    }
                    if(tl == null) {
                        throw new UserError([{msg:"Invalid export format: Invalid value for 'tl' attribute at <x>.\n'"+filename+"' has not been loaded."}]);
                    } else {
                        tTables.push(tl.mappings);
                    }
                } else {
                    tTables.push([]);
                }
            }
        }
        try {
            var variables = {};
            for(var i = 0; i < operands.length; i++) {
                variables['x'+i] = 1;
            }
            mathjs.evaluate(expression, variables);
        } catch(e) {
            if(e.message.startsWith("Undefined symbol x")) {
                var symbol = e.message.slice(18);
                if(/^\d+$/.test(symbol)) {
                    throw new UserError([{msg:"Invalid export format: Missing <x> tag at <"+tagName+">.\n'"+filename+"' has not been loaded."}]);
                } 
            }
            throw new UserError([{msg:"Invalid export format: Invalid value for 'expression' attribute at <"+tagName+">.\n'"+filename+"' has not been loaded."}]);
        }
        return new ExportNumberVariableBlock(operands, tTables, expression);
    }

    function parseDirectoryContents(tag, rootDir=false) {
        var subFiles = [];
        for(var j in tag.childNodes) {
            var subtag = tag.childNodes[j];
            if(subtag.nodeType == Node.ELEMENT_NODE) {
                if(rootDir && subtag.nodeName === 'translation') {
                    //parse translation
                    var tl = subtag;

                    //get name
                    var aVar = tl.getAttribute('name');
                    if(aVar == null) {
                        throw new UserError([{msg:"Invalid export format: Missing 'name' attribute at <translation>.\n'"+filename+"' has not been loaded."}]);
                    }

                    //get modifiers
                    var mappings = [];
                    for(var j in tl.childNodes) {
                        var attrTag = tl.childNodes[j];
                        if(attrTag.nodeType == Node.ELEMENT_NODE && attrTag.nodeName === 'map') {
                            var aFrom = attrTag.getAttribute('from');
                            if(aFrom == null) {
                                throw new UserError([{msg:"Invalid export format: Missing 'from' attribute at <map>.\n'"+filename+"' has not been loaded."}]);
                            }
                            var aTo = attrTag.getAttribute('to');
                            if(aTo == null) {
                                throw new UserError([{msg:"Invalid export format: Missing 'to' attribute at <map>.\n'"+filename+"' has not been loaded."}]);
                            }
                            mappings.push([aFrom, aTo]);
                        }
                    }

                    //success
                    translations.push({name:aVar, mappings:mappings});
                } else if(subtag.nodeName === 'folder') {
                    //parse folder
                    var folder = subtag;

                    //get export mode
                    var exportMode = 0;
                    var aMode = folder.getAttribute('mode');
                    if(aMode != null) {
                        if(aMode === 'default') {
                            exportMode = 0;
                        } else if(aMode === 'targz') {
                            exportMode = 1;
                        } else {
                            throw new UserError([{msg:"Invalid export format: Invalid value for 'mode' attribute at <folder>.\n'"+filename+"' has not been loaded."}]);
                        }
                    }

                    var foreach = folder.getAttribute('foreach');
                    if(foreach != null) {
                        if(/[#]/.test(foreach)) {
                            throw new UserError([{msg:"Invalid export format: Illegal character in 'foreach' attribute at <folder>.\n'"+filename+"' has not been loaded."}]);
                        }
                    }

                    //get name and contents
                    var nameTag = null;
                    var contentsTag = null;
                    var foreachIdentifiers = [];
                    for(var i in folder.childNodes) {
                        var attrTag = folder.childNodes[i];
                        if(attrTag.nodeType == Node.ELEMENT_NODE) {
                            if(foreach != null && attrTag.nodeName === 'as') {
                                var aVar = attrTag.getAttribute('i');
                                if(aVar == null) {
                                    throw new UserError([{msg:"Invalid export format: Missing 'i' attribute at <as>.\n'"+filename+"' has not been loaded."}]);
                                } else {
                                    if(/[#\.!]/.test(aVar)) {
                                        throw new UserError([{msg:"Invalid export format: Illegal character in 'i' attribute at <as>.\n'"+filename+"' has not been loaded."}]);
                                    }
                                }
                                foreachIdentifiers.push(aVar);
                            } else if(attrTag.nodeName === 'name' && nameTag == null) {
                                nameTag = attrTag;
                            } else if(attrTag.nodeName === 'directory-contents' && contentsTag == null) {
                                contentsTag = attrTag;
                            }
                        }
                    }
                    if(nameTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <name> tag at <folder>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var name = parseTextContents(nameTag);

                    if(contentsTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <directory-contents> tag at <folder>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var directoryContents = parseDirectoryContents(contentsTag);

                    //success
                    var exportFolder = new ExportFolder(name, exportMode);
                    for(var i in directoryContents) {
                        exportFolder.addDirectory(directoryContents[i]);
                    }

                    //loop directory handling
                    if(foreach == null) {
                        subFiles.push(exportFolder);
                    } else {
                        //variable checked in runtime
                        subFiles.push(new ExportLoopDirectory(exportFolder, foreach, foreachIdentifiers));
                    }
                } else if(subtag.nodeName === "text-file") {
                    //parse file
                    var file = subtag;

                    var foreach = file.getAttribute('foreach');
                    if(foreach != null) {
                        if(/[#]/.test(foreach)) {
                            throw new UserError([{msg:"Invalid export format: Illegal character in 'foreach' attribute at <text-file>.\n'"+filename+"' has not been loaded."}]);
                        }
                    }

                    //get name and contents
                    var nameTag = null;
                    var contentsTag = null;
                    var foreachIdentifiers = [];
                    for(var i in file.childNodes) {
                        var attrTag = file.childNodes[i];
                        if(attrTag.nodeType == Node.ELEMENT_NODE) {
                            if(foreach != null && attrTag.nodeName === 'as') {
                                var aVar = attrTag.getAttribute('i');
                                if(aVar == null) {
                                    throw new UserError([{msg:"Invalid export format: Missing 'i' attribute at <as>.\n'"+filename+"' has not been loaded."}]);
                                } else {
                                    if(/[#\.!]/.test(aVar)) {
                                        throw new UserError([{msg:"Invalid export format: Illegal character in 'i' attribute at <as>.\n'"+filename+"' has not been loaded."}]);
                                    }
                                }
                                foreachIdentifiers.push(aVar);
                            } else if(attrTag.nodeName === 'name' && nameTag == null) {
                                nameTag = attrTag;
                            } else if(attrTag.nodeName === 'text-contents' && contentsTag == null) {
                                contentsTag = attrTag;
                            }
                        }
                    }
                    if(nameTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <name> tag at <text-file>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var name = parseTextContents(nameTag);

                    if(contentsTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <text-contents> tag at <text-file>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var textContents = parseTextContents(contentsTag);

                    //success
                    var exportFile = new ExportTextFile(name, textContents);

                    //loop directory handling
                    if(foreach == null) {
                        subFiles.push(exportFile);
                    } else {
                        //variable checked in runtime
                        subFiles.push(new ExportLoopDirectory(exportFile, foreach, foreachIdentifiers));
                    }
                } else if(subtag.nodeName === "image-file") {
                    //parse file
                    var file = subtag;

                    var foreach = file.getAttribute('foreach');
                    if(foreach != null) {
                        if(/[#]/.test(foreach)) {
                            throw new UserError([{msg:"Invalid export format: Illegal character in 'foreach' attribute at <image-file>.\n'"+filename+"' has not been loaded."}]);
                        }
                    }

                    //get name, contents, width and height
                    var nameTag = null;
                    var widthTag = null;
                    var heightTag = null;
                    var contentsTag = null;
                    var foreachIdentifiers = [];
                    for(var i in file.childNodes) {
                        var attrTag = file.childNodes[i];
                        if(attrTag.nodeType == Node.ELEMENT_NODE) {
                            if(foreach != null && attrTag.nodeName === 'as') {
                                var aVar = attrTag.getAttribute('i');
                                if(aVar == null) {
                                    throw new UserError([{msg:"Invalid export format: Missing 'i' attribute at <as>.\n'"+filename+"' has not been loaded."}]);
                                } else {
                                    if(/[#\.!]/.test(aVar)) {
                                        throw new UserError([{msg:"Invalid export format: Illegal character in 'i' attribute at <as>.\n'"+filename+"' has not been loaded."}]);
                                    }
                                }
                                foreachIdentifiers.push(aVar);
                            } else if(attrTag.nodeName === 'name' && nameTag == null) {
                                nameTag = attrTag;
                            } else if(attrTag.nodeName === 'image-contents' && contentsTag == null) {
                                contentsTag = attrTag;
                            } else if(attrTag.nodeName === 'width' && widthTag == null) {
                                widthTag = attrTag;
                            } else if(attrTag.nodeName === 'height' && heightTag == null) {
                                heightTag = attrTag;
                            }
                        }
                    }
                    if(nameTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <name> tag at <image-file>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var name = parseTextContents(nameTag);

                    if(widthTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <width> tag at <image-file>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var width = parseNvar(widthTag, "width");

                    if(heightTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <height> tag at <image-file>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var height = parseNvar(heightTag, "height");

                    if(contentsTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <image-contents> tag at <image-file>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var imageContents = parseImageContents(contentsTag, width, height);

                    //success
                    var exportFile = new ExportVisualFile(name, imageContents);

                    //loop directory handling
                    if(foreach == null) {
                        subFiles.push(exportFile);
                    } else {
                        //variable checked in runtime
                        subFiles.push(new ExportLoopDirectory(exportFile, foreach, foreachIdentifiers));
                    }
                }
            }
        }
        return subFiles;
    }

    function parseTextContents(tag) {
        var blocks = [];
        for(var i in tag.childNodes) {
            var blockTag = tag.childNodes[i];
            if(blockTag.nodeType == Node.TEXT_NODE) {
                var block = new ExportTextBlock(blockTag.nodeValue);
                blocks.push(block);
            } else if(blockTag.nodeType == Node.ELEMENT_NODE) {
                if(blockTag.nodeName === 'var' || blockTag.nodeName === 'GUID') {
                    //parse var
                    //get identifier
                    var aVar = blockTag.getAttribute('v');
                    if(aVar == null) {
                        throw new UserError([{msg:"Invalid export format: Missing 'v' attribute at <"+blockTag.nodeName+">.\n'"+filename+"' has not been loaded."}]);
                    } else {
                        if(/[#]/.test(aVar)) {
                            throw new UserError([{msg:"Invalid export format: Illegal character in 'v' attribute at <"+blockTag.nodeName+">.\n'"+filename+"' has not been loaded."}]);
                        }
                    }

                    //get modifiers
                    var tTable = [];
                    if(blockTag.nodeName === 'var') {
                        //get translation
                        var tVar = blockTag.getAttribute('tl');
                        if(tVar != null) {
                            var tl = null;
                            for(var tli in translations) {
                                if(translations[tli].name === tVar) {
                                    tl = translations[tli];
                                }
                            }
                            if(tl == null) {
                                throw new UserError([{msg:"Invalid export format: Invalid value for 'tl' attribute at <var>.\n'"+filename+"' has not been loaded."}]);
                            } else {
                                tTable = tl.mappings;
                            }
                        }
                    }
                    var regex = [];
                    for(var j in blockTag.childNodes) {
                        var attrTag = blockTag.childNodes[j];
                        if(attrTag.nodeType == Node.ELEMENT_NODE && attrTag.nodeName === 'replace') {
                            var aFrom = attrTag.getAttribute('from');
                            if(aFrom == null) {
                                throw new UserError([{msg:"Invalid export format: Missing 'from' attribute at <replace>.\n'"+filename+"' has not been loaded."}]);
                            }
                            try {
                                new RegExp(aFrom, 'g');
                            } catch(e) {
                                throw new UserError([{msg:"Invalid export format: Invalid value for 'from' attribute at <replace>.\n'"+filename+"' has not been loaded."}]);
                            }
                            var aTo = attrTag.getAttribute('to');
                            if(aTo == null) {
                                throw new UserError([{msg:"Invalid export format: Missing 'to' attribute at <replace>.\n'"+filename+"' has not been loaded."}]);
                            }
                            regex.push([aFrom, aTo]);
                        }
                    }

                    //success
                    var block;
                    if(blockTag.nodeName === 'var') {
                        block = new ExportTextVariableBlock(aVar, tTable, regex);
                    } else if(blockTag.nodeName === 'GUID') {
                        block = new ExportGUIDBlock(aVar, regex);
                    }
                    blocks.push(block);
                } else if(blockTag.nodeName === 'nvar') {
                    //parse nvar
                    var block = parseNvar(blockTag, "nvar");

                    //sucess
                    blocks.push(block);
                } else if(blockTag.nodeName === 'list-loop') {
                    //parse list loop
                    //get foreach
                    var aForeach = blockTag.getAttribute('foreach');
                    if(aForeach == null) {
                        throw new UserError([{msg:"Invalid export format: Missing 'foreach' attribute at <list-loop>.\n'"+filename+"' has not been loaded."}]);
                    } else {
                        if(/[#]/.test(aForeach)) {
                            throw new UserError([{msg:"Invalid export format: Illegal character in 'foreach' attribute at <list-loop>.\n'"+filename+"' has not been loaded."}]);
                        }
                    }

                    //get reverse
                    var reverse = false;
                    var aReverse = blockTag.getAttribute('reverse');
                    if(aReverse != null) {
                        if(aReverse === 'false') {
                            reverse = false;
                        } else if(aReverse === 'true') {
                            reverse = true;
                        } else {
                            throw new UserError([{msg:"Invalid export format: Invalid value for 'reverse' attribute at <list-loop>.\n'"+filename+"' has not been loaded."}]);
                        }
                    }

                    //get separator and contents
                    var separatorTag = null;
                    var contentsTag = null;
                    var foreachIdentifiers = [];
                    for(var j in blockTag.childNodes) {
                        var attrTag = blockTag.childNodes[j];
                        if(attrTag.nodeType == Node.ELEMENT_NODE) {
                            if(attrTag.nodeName === 'as') {
                                var aVar = attrTag.getAttribute('i');
                                if(aVar == null) {
                                    throw new UserError([{msg:"Invalid export format: Missing 'i' attribute at <as>.\n'"+filename+"' has not been loaded."}]);
                                } else {
                                    if(/[#\.!]/.test(aVar)) {
                                        throw new UserError([{msg:"Invalid export format: Illegal character in 'i' attribute at <as>.\n'"+filename+"' has not been loaded."}]);
                                    }
                                }
                                foreachIdentifiers.push(aVar);
                            } else if(attrTag.nodeName === 'separator' && separatorTag == null) {
                                separatorTag = attrTag;
                            } else if(attrTag.nodeName === 'text-contents' && contentsTag == null) {
                                contentsTag = attrTag;
                            }
                        }
                    }
                    if(contentsTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <text-contents> tag at <list-loop>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var textContents = parseTextContents(contentsTag);

                    var separator;
                    if(separatorTag == null) {
                        separator = new ExportBlockField();
                    } else {
                        separator = parseTextContents(separatorTag);
                    }

                    //success
                    var block = new ExportLoopBlock(aForeach, foreachIdentifiers, textContents, separator, reverse);
                    blocks.push(block);
                } else if(blockTag.nodeName === 'grid-loop') {
                    //parse grid loop
                    //get foreach
                    var aForeach = blockTag.getAttribute('foreach');
                    if(aForeach == null) {
                        throw new UserError([{msg:"Invalid export format: Missing 'foreach' attribute at <grid-loop>.\n'"+filename+"' has not been loaded."}]);
                    } else {
                        if(/[#]/.test(aForeach)) {
                            throw new UserError([{msg:"Invalid export format: Illegal character in 'foreach' attribute at <grid-loop>.\n'"+filename+"' has not been loaded."}]);
                        }
                    }

                    //get separator-x, separator-y, null-contents, contents, width, height, grid-x and grid-y
                    var separatorXTag = null;
                    var separatorYTag = null;
                    var nullContentsTag = null;
                    var contentsTag = null;
                    var widthTag = null;
                    var heightTag = null;
                    var gridXTag = null;
                    var gridYTag = null;
                    var foreachIdentifiers = [];
                    for(var j in blockTag.childNodes) {
                        var attrTag = blockTag.childNodes[j];
                        if(attrTag.nodeType == Node.ELEMENT_NODE) {
                            if(attrTag.nodeName === 'as') {
                                var aVar = attrTag.getAttribute('i');
                                if(aVar == null) {
                                    throw new UserError([{msg:"Invalid export format: Missing 'i' attribute at <as>.\n'"+filename+"' has not been loaded."}]);
                                } else {
                                    if(/[#\.!]/.test(aVar)) {
                                        throw new UserError([{msg:"Invalid export format: Illegal character in 'i' attribute at <as>.\n'"+filename+"' has not been loaded."}]);
                                    }
                                }
                                foreachIdentifiers.push(aVar);
                            } else if(attrTag.nodeName === 'separator-x' && separatorXTag == null) {
                                separatorXTag = attrTag;
                            } else if(attrTag.nodeName === 'separator-y' && separatorYTag == null) {
                                separatorYTag = attrTag;
                            } else if(attrTag.nodeName === 'null-contents' && nullContentsTag == null) {
                                nullContentsTag = attrTag;
                            } else if(attrTag.nodeName === 'text-contents' && contentsTag == null) {
                                contentsTag = attrTag;
                            } else if(attrTag.nodeName === 'width' && widthTag == null) {
                                widthTag = attrTag;
                            } else if(attrTag.nodeName === 'height' && heightTag == null) {
                                heightTag = attrTag;
                            } else if(attrTag.nodeName === 'grid-x' && gridXTag == null) {
                                gridXTag = attrTag;
                            } else if(attrTag.nodeName === 'grid-y' && gridYTag == null) {
                                gridYTag = attrTag;
                            } 
                        }
                    }
                    if(contentsTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <text-contents> tag at <grid-loop>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var textContents = parseTextContents(contentsTag);

                    var separatorX;
                    if(separatorXTag == null) {
                        separatorX = new ExportBlockField();
                    } else {
                        separatorX = parseTextContents(separatorXTag);
                    }

                    var separatorY;
                    if(separatorYTag == null) {
                        separatorY = new ExportBlockField();
                    } else {
                        separatorY = parseTextContents(separatorYTag);
                    }

                    var nullContents;
                    if(nullContentsTag == null) {
                        nullContents = new ExportBlockField();
                    } else {
                        nullContents = parseTextContents(nullContentsTag);
                    }

                    if(widthTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <width> tag at <grid-loop>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var width = parseNvar(widthTag, "width");

                    if(heightTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <height> tag at <grid-loop>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var height = parseNvar(heightTag, "height");

                    if(gridXTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <grid-x> tag at <grid-loop>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var gridX = parseNvar(gridXTag, "grid-x");

                    if(gridYTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <grid-y> tag at <grid-loop>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var gridY = parseNvar(gridYTag, "grid-y");

                    //success
                    var block = new ExportGridLoopBlock(aForeach, foreachIdentifiers, width, height, gridX, gridY, nullContents, textContents, separatorX, separatorY);
                    blocks.push(block);
                }
            }
        }
        return new ExportBlockField(blocks);
    }

    function parseImageContents(tag, width, height) {
        var blocks = [];
        for(var i in tag.childNodes) {
            var blockTag = tag.childNodes[i];
            if(blockTag.nodeType == Node.ELEMENT_NODE) {
                if(blockTag.nodeName === 'image') {
                    //parse image
                    //get dataURL
                    var dataURL = blockTag.getAttribute('dataURL');
                    if(dataURL == null) {
                        throw new UserError([{msg:"Invalid export format: Missing 'dataURL' attribute at <image>.\n'"+filename+"' has not been loaded."}]);
                    }

                    //get grid-x, grid-y and z-index
                    var gridXTag = null;
                    var gridYTag = null;
                    var zIndexTag = null;
                    for(var i in blockTag.childNodes) {
                        var attrTag = blockTag.childNodes[i];
                        if(attrTag.nodeType == Node.ELEMENT_NODE) {
                            if(attrTag.nodeName === 'grid-x' && gridXTag == null) {
                                gridXTag = attrTag;
                            } else if(attrTag.nodeName === 'grid-y' && gridYTag == null) {
                                gridYTag = attrTag;
                            } else if(attrTag.nodeName === 'z-index' && zIndexTag == null) {
                                zIndexTag = attrTag;
                            }
                        }
                    }
                    if(gridXTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <grid-x> tag at <image>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var gridX = parseNvar(gridXTag, "grid-x");

                    if(gridYTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <grid-y> tag at <image>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var gridY = parseNvar(gridYTag, "grid-y");

                    var zIndex;
                    if(zIndexTag == null) {
                        zIndex = new ExportNumberVariableBlock([], [], '0');
                    } else {
                        zIndex = parseNvar(zIndexTag, "z-index");
                    }

                    //success
                    var block = new ExportVisualImageBlock(gridX, gridY, zIndex, dataURL);
                    if(block.image.isEmpty() || block.image.getSize().width == 0 || block.image.getSize().height == 0) {
                        throw new UserError([{msg:"Invalid export format: Invalid value for 'dataURL' attribute at <image>.\n'"+filename+"' has not been loaded."}]);
                    }
                    blocks.push(block);
                } else if(blockTag.nodeName === 'ivar') {
                    //parse image
                    //get ivar
                    var aVar = blockTag.getAttribute('v');
                    if(aVar == null) {
                        throw new UserError([{msg:"Invalid export format: Missing 'v' attribute at <ivar>.\n'"+filename+"' has not been loaded."}]);
                    } else {
                        if(/[#]/.test(aVar)) {
                            throw new UserError([{msg:"Invalid export format: Illegal character in 'v' attribute at <ivar>.\n'"+filename+"' has not been loaded."}]);
                        }
                    }

                    //get grid-x, grid-y and z-index
                    var gridXTag = null;
                    var gridYTag = null;
                    var zIndexTag = null;
                    for(var i in blockTag.childNodes) {
                        var attrTag = blockTag.childNodes[i];
                        if(attrTag.nodeType == Node.ELEMENT_NODE) {
                            if(attrTag.nodeName === 'grid-x' && gridXTag == null) {
                                gridXTag = attrTag;
                            } else if(attrTag.nodeName === 'grid-y' && gridYTag == null) {
                                gridYTag = attrTag;
                            } else if(attrTag.nodeName === 'z-index' && zIndexTag == null) {
                                zIndexTag = attrTag;
                            }
                        }
                    }
                    if(gridXTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <grid-x> tag at <ivar>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var gridX = parseNvar(gridXTag, "grid-x");

                    if(gridYTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <grid-y> tag at <ivar>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var gridY = parseNvar(gridYTag, "grid-y");

                    var zIndex;
                    if(zIndexTag == null) {
                        zIndex = new ExportNumberVariableBlock([], [], '0');
                    } else {
                        zIndex = parseNvar(zIndexTag, "z-index");
                    }

                    //success
                    var block = new ExportVisualImageVariableBlock(gridX, gridY, zIndex, aVar);
                    blocks.push(block);
                } else if(blockTag.nodeName === 'image-loop') {
                    //parse image-loop
                    //get foreach
                    var aForeach = blockTag.getAttribute('foreach');
                    if(aForeach == null) {
                        throw new UserError([{msg:"Invalid export format: Missing 'foreach' attribute at <image-loop>.\n'"+filename+"' has not been loaded."}]);
                    } else {
                        if(/[#]/.test(aForeach)) {
                            throw new UserError([{msg:"Invalid export format: Illegal character in 'foreach' attribute at <image-loop>.\n'"+filename+"' has not been loaded."}]);
                        }
                    }

                    //get contents
                    var contentsTag = null;
                    var foreachIdentifiers = [];
                    for(var j in blockTag.childNodes) {
                        var attrTag = blockTag.childNodes[j];
                        if(attrTag.nodeType == Node.ELEMENT_NODE) {
                            if(attrTag.nodeName === 'as') {
                                var aVar = attrTag.getAttribute('i');
                                if(aVar == null) {
                                    throw new UserError([{msg:"Invalid export format: Missing 'i' attribute at <as>.\n'"+filename+"' has not been loaded."}]);
                                } else {
                                    if(/[#\.!]/.test(aVar)) {
                                        throw new UserError([{msg:"Invalid export format: Illegal character in 'i' attribute at <as>.\n'"+filename+"' has not been loaded."}]);
                                    }
                                }
                                foreachIdentifiers.push(aVar);
                            } else if(attrTag.nodeName === 'image-contents' && contentsTag == null) {
                                contentsTag = attrTag;
                            }
                        }
                    }

                    if(contentsTag == null) {
                        throw new UserError([{msg:"Invalid export format: Missing <image-contents> tag at <image-loop>.\n'"+filename+"' has not been loaded."}]);
                    }
                    var imageContents = parseImageContents(contentsTag, new ExportNumberVariableBlock([], [], '0'), new ExportNumberVariableBlock([], [], '0'));

                    //success
                    var block = new ExportVisualLoopBlock(new ExportNumberVariableBlock([], [], '0'), new ExportNumberVariableBlock([], [], '0'), new ExportNumberVariableBlock([], [], '0'), aForeach, foreachIdentifiers, imageContents);
                    blocks.push(block);
                }
            }
        }
        return new ExportVisualBlockField(blocks, width, height);
    }

    //get initial tag
    var format = null;
    var tags = xmlDoc.childNodes;
    for(var i in tags) {
        var tag = tags[i];
        if(tag.nodeType == Node.ELEMENT_NODE && tag.nodeName === 'format') {
            format = tag;
            break;
        }
    }
    if(format == null) {
        throw new UserError([{msg:"Invalid export format: Missing <format> tag as root.\n'"+filename+"' has not been loaded."}]);
    }

    //get format name
    fName = "";
    var aName = format.getAttribute('name');
    if(aName != null) {
        fName = aName;
    }

    //get directory contents
    var directoryContents = parseDirectoryContents(format, true);

    //success
    var shape = tileroninX.Shape.ORTHOGRAPHIC;
    if(fn.endsWith(".tsfi")) {
        shape = tileroninX.Shape.ISOMETRIC;
    }
    var exportRoot = new ExportFolder(new ExportBlockField([new ExportTextBlock(fName)]));
    for(var i in directoryContents) {
        exportRoot.addDirectory(directoryContents[i]);
    }
    return {format:exportRoot, shape:shape};
}
exports.parseExportFormat = parseExportFormat;

//=================//
//=================//
//=====RUNTIME=====//
//=================//
//=================//

/*
    creates and returns shallow clone of input dataset.
    (SCOPE and RUNTIME are deep cloned)
*/
var cloneDatasetScope = function(dataset) {
    var ds = {};
    for(var k in dataset) {
        ds[k] = dataset[k];
    }
    ds['#SCOPE'] = {};
    for(var k in dataset['#SCOPE']) {
        ds['#SCOPE'][k] = dataset['#SCOPE'][k];
    }
    ds['#RUNTIME'] = {};
    for(var k in dataset['#RUNTIME']) {
        ds['#RUNTIME'][k] = dataset['#RUNTIME'][k];
    }
    return ds;
}

/*
    object at index 'i' of list 'v' in the dataset is exposed into the global scope
    with suffix vAs[0].
    > object's RUNTIMEs are merged into global RUNTIME
    > new identifier created in SCOPE for object
    > objects in predecessor scopes referenced by the revealing object are revealed as well
    > if cartesian product matrix is available in current scope, reveal cross variables if the matrix crosses 
    between the revealing object's class and a previously revealed object's class
*/
var revealDatasetScope = function(dataset, v, i, vAs) {
    //
    var ls = dataset[v][i];
    if(ls == null) {
        throw new UserError([{msg:"Invalid export format: Variable '"+v+"' does not exist in scope.\nData has not been fully exported."}]);
    }
    //
    var varName = vAs.shift();
    if(varName == null) {
        throw new UserError([{msg:"Invalid export format: Not enough identifiers provided for scope.\nData has not been fully exported."}]);
    }
    if(dataset['#SCOPE'][varName] != null) {
        throw new UserError([{msg:"Invalid export format: Identifier '"+varName+"' is already assigned in scope.\nData has not been fully exported."}]);
    }
    dataset['#SCOPE'][varName] = {v:v, i:i}; 
    //
    var outerScope = "";
    if(v.includes('.')) {
        outerScope = v.slice(0, v.lastIndexOf('.'))+'.';
    }
    for(var k in dataset) {
        if(!(k.includes('!') && k.includes('#'))) {
            continue;
        }
        if((outerScope.length == 0 && !k.includes('.')) ||
          (outerScope.length > 0 && k.startsWith(outerScope))) {
            var productTokens = k.slice(outerScope.length)
            productTokens = productTokens.slice(0, productTokens.lastIndexOf('#')).split('!');
            if(v === outerScope+productTokens[0] || v === outerScope+productTokens[1]) {
                var otherToken = ((v === outerScope+productTokens[0]) ? productTokens[1] : productTokens[0]);
                for(var j in dataset['#SCOPE']) {
                    if(dataset['#SCOPE'][j].v === outerScope+otherToken) {
                        var prodValue = dataset[k][dataset['#SCOPE'][j].i][i];
                        if(v === outerScope+productTokens[0]) {
                            prodValue = dataset[k][i][dataset['#SCOPE'][j].i];
                        }
                        dataset[j+'!'+varName+'.'+k.slice(k.lastIndexOf('#')+1)] = prodValue;
                        dataset[varName+'!'+j+'.'+k.slice(k.lastIndexOf('#')+1)] = prodValue;
                    }
                }
            }
        }
    }
    //
    for(var k in ls) {
        if(k.startsWith("REF#")) {
            var referenceVar = k.slice(4);
            var outerScope = varName;
            do {
                outerScope = dataset['#SCOPE'][outerScope].v;
                if(outerScope.includes('.')) {
                    outerScope = outerScope.slice(0, outerScope.lastIndexOf('.'));
                } else {
                    outerScope = "";
                }
                var searchVar = outerScope;
                if(searchVar.length > 0) {
                    searchVar += '.';
                }
                searchVar += referenceVar;
                if(dataset[searchVar] != null) {
                    revealDatasetScope(dataset, searchVar, ls[k], vAs);
                    break;
                }
            } while(outerScope.length > 0);
        } else if(k === '#RUNTIME') {
            for(var j in ls[k]) {
                dataset['#RUNTIME'][varName+'.'+j] = ls[k][j];
            }
        } else {
            dataset[varName+'.'+k] = ls[k];
        }
    }
}

/*
    for each RUNTIME in cloned dataset, either:
    1. keep it global in original dataset,
    2. 'stash' it in one of the original dataset's objects
*/
var bubbleUpScopeRuntimes = function(prev, curr) {
    for(var k in curr['#RUNTIME']) {
        var runtimeVar = k;
        var runtimePrefix = "";
        if(runtimeVar.includes('.')) {
            runtimePrefix = runtimeVar.slice(0, runtimeVar.lastIndexOf('.'));
            runtimeVar = runtimeVar.slice(runtimeVar.lastIndexOf('.')+1);
        }

        if(runtimePrefix.length > 0 && prev['#SCOPE'][runtimePrefix] == null) {
            var container = curr['#SCOPE'][runtimePrefix];
            prev[container.v][container.i]['#RUNTIME'][runtimeVar] = curr['#RUNTIME'][k];
        } else {
            prev['#RUNTIME'][k] = curr['#RUNTIME'][k];
        }
    }
}

/*  
    - clone dataset
    - expose object into global scope
    - perform operation with expanded dataset
    - update original dataset with RUNTIMEs
*/
var useExportDatasetScopeSync = function(dataset, variable, i, identifiers, inScopeFn) {
    //create scope
    var expandedDataset = cloneDatasetScope(dataset);
    revealDatasetScope(expandedDataset, variable, i, [...identifiers]);
    //scope operation
    inScopeFn(expandedDataset);
    //keep/save RUNTIMEs
    bubbleUpScopeRuntimes(dataset, expandedDataset);
}
exports.useExportDatasetScopeSync = useExportDatasetScopeSync;

/*  
    - clone dataset
    - expose object into global scope
    - perform operation with expanded dataset
    - update original dataset with RUNTIMEs
*/
var useExportDatasetScopeAsync = function(dataset, variable, i, p, identifiers, inScopeFn) {
    p = p.then(function() {
        var expandedDataset;
        var pLocal = Promise.resolve();
        pLocal = pLocal.then(function() {
            //create scope
            expandedDataset = cloneDatasetScope(dataset);
            revealDatasetScope(expandedDataset, variable, i, [...identifiers]);
            //scope operation
            return inScopeFn(expandedDataset);
        });
        pLocal = pLocal.then(function() {
            return new Promise(function(resolveLocal, rejectLocal) {
                //keep/save RUNTIMEs
                bubbleUpScopeRuntimes(dataset, expandedDataset);
                resolveLocal();
            })
        });
        return pLocal;
    });
    return p;
}
exports.useExportDatasetScopeAsync = useExportDatasetScopeAsync;