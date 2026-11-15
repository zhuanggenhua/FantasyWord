var tileroninX = require('./tileroninX.js');
var TileBase = require('./TileBase.js');
var Tile = require('./Tile.js');
var TileRelationProxy = require('./TileRelationProxy.js');
var RegionSync = require('./RegionSync.js');

var PropertyEditTextView = require('./PropertyEditTextView.js');
var PropertyEditTextMultiView = require('./PropertyEditTextMultiView.js');

var CallbackManager = require('./CallbackManager.js');

var Mousetrap = require('mousetrap');
var {clipboard} = require('electron');
const {ipcRenderer} = require('electron');

var TileGridOrthographicView = require('./TileGridOrthographicView.js');
var TileGridIsometricView = require('./TileGridIsometricView.js');
var IconTrayView = require('./IconTrayView.js');

var ExpandingMenuView = require('./ExpandingMenuView.js');
var ErrorDisplayView = require('./ErrorDisplayView.js');

var nativeImage = require('electron').nativeImage
var fs = require('fs');
var {dialog} = require('electron').remote;
var path = require('path');

var chokidar = require("chokidar");

var UserError = require('./UserError.js');

var onBrowserFile = function(fn, callback) {
	if(fn == null) {
		return;
	}
	if(typeof window !== 'undefined'
	&& window.__TILERONINX_BROWSER_RUNTIME__ != null
	&& typeof fn[0] === 'string'
	&& fn[0].indexOf('/browser/pending/') === 0) {
		window.__TILERONINX_BROWSER_RUNTIME__.onPendingFile(fn[0], callback);
	} else {
		callback(fn[0]);
	}
}

var clipboardPaste = function() {
	if(this.tilePickCallback != null) {
		this.tilePickCallback(false);
		this.tilePickCallback = null;
	}
	if(clipboard.has("ronintile Set")) { //smart paste
		var tiles = tileroninX.parseClipboardSet(Buffer.from(clipboard.readBuffer("ronintile Set").buffer));

		var origin = this.tileGrid.getSelectionPoint();
		
		var addTiles = [];
		for(var index in tiles) {
			var tile = tiles[index];
			addTiles.push({x:tile.pos.x+origin.x, y:tile.pos.y+origin.y, tile:tile.tile});
		}
		var undoGroup = [];
		tileroninX.setTilesSet(addTiles, undoGroup);
		tileroninX.saveUndoState(undoGroup);

	} else { //image paste
		var pasted = clipboard.readImage();

		var bufs = [clipboard.readBuffer('png'),
					clipboard.readBuffer('image/png')];
		for(var i in bufs) {
			var buf = bufs[i];
			if(buf.length > 0) {
				pasted = nativeImage.createFromBuffer(buf);
			}
		}

		var sources = tileroninX.imageToSources(pasted);
		var addTiles = [];
		for(var index in sources) {
			var source = sources[index];
			var tile = new TileBase(source.src);
			var origin = this.tileGrid.getSelectionPoint();
			addTiles.push({x:source.pos.x+origin.x, y:source.pos.y+origin.y, tile:tile});
		}
		var undoGroup = [];
		tileroninX.setTilesSet(addTiles, undoGroup);
		tileroninX.saveUndoState(undoGroup);

	}
}

var clipboardCopy = function() {
	if(this.tilePickCallback != null) {
		this.tilePickCallback(false);
		this.tilePickCallback = null;
	}
	tileroninX.buildClipboardSet(this.tileGrid.getSelected()).then(function(data) {
		ipcRenderer.send('clipboardWrite', null, {format:"ronintile Set", data:data});
	});
}

var clipboardCopyRaw = function() {
	if(this.tilePickCallback != null) {
		this.tilePickCallback(false);
		this.tilePickCallback = null;
	}
	tileroninX.toImageSet(this.tileGrid.getSelected()).then(function(image) {
		ipcRenderer.send('clipboardWrite', image.toDataURL());
	});
}

var newData = function() {
	if(this.tilePickCallback != null) {
		this.tilePickCallback(false);
		this.tilePickCallback = null;
	}
	this.newMenu.open(this.newMenuPos.x, this.newMenuPos.y);
}

var newDataConfirm = function(shape) {
	tileroninX.newData({shape:shape});
	this.currentProject = null;
	this.rememberedExport = null;
}

var loadData = function() {
	if(this.tilePickCallback != null) {
		this.tilePickCallback(false);
		this.tilePickCallback = null;
	}
	var fn = dialog.showOpenDialogSync({properties: ['openFile'], filters: [ tileroninX.projectFileFilter ] });
	onBrowserFile(fn, function(browserPath) {
		if(tileroninX.loadData(browserPath)) {
			this.currentProject = browserPath;
			this.rememberedExport = null;
		}
	}.bind(this));
}

var saveData = function() {
	if(this.tilePickCallback != null) {
		this.tilePickCallback(false);
		this.tilePickCallback = null;
	}
	if(this.currentProject != null) {
		tileroninX.saveData(this.currentProject);
	} else {
		saveDataAs.bind(this)();
	}
}

var saveDataAs = function() {
	if(this.tilePickCallback != null) {
		this.tilePickCallback(false);
		this.tilePickCallback = null;
	}
	var fn = dialog.showSaveDialogSync({filters: [ tileroninX.projectFileFilter ] });
	if(fn != null) {
		tileroninX.saveData(fn);
		this.currentProject = fn;
	}
}

var performUndo = function() {
	if(this.tilePickCallback != null) {
		this.tilePickCallback(false);
		this.tilePickCallback = null;
	}
	tileroninX.performUndo();
}

var performRedo = function() {
	if(this.tilePickCallback != null) {
		this.tilePickCallback(false);
		this.tilePickCallback = null;
	}
	tileroninX.performRedo();
}

var importTiles = function() {
	if(this.tilePickCallback != null) {
		this.tilePickCallback(false);
		this.tilePickCallback = null;
	}
	var fn = dialog.showOpenDialogSync({properties: ['openFile'], filters: [ tileroninX.imageImportFileFilter ] });
	onBrowserFile(fn, function(browserPath) {
		var image = nativeImage.createFromPath(browserPath);

		var sources = tileroninX.imageToSources(image);
		var addTiles = [];
		for(var index in sources) {
			var source = sources[index];
			var tile = new TileBase(source.src);
			var origin = this.tileGrid.getSelectionPoint();
			addTiles.push({x:source.pos.x+origin.x, y:source.pos.y+origin.y, tile:tile});
		}
		var undoGroup = [];
		tileroninX.setTilesSet(addTiles, undoGroup);
		tileroninX.saveUndoState(undoGroup);
	}.bind(this));
}

var exportTiles = function(format) {
	if(this.tilePickCallback != null) {
		this.tilePickCallback(false);
		this.tilePickCallback = null;
	}
	var fn = dialog.showSaveDialogSync({defaultPath:((this.rememberedExport==null)?"":this.rememberedExport), filters:[{name: format.getName().getText({}), extensions: ['']}]});
	if(fn != null) {
		tileroninX.exportPackageSet(this.tileGrid.getSelected(), fn, format).catch(function(e) {
			if(e instanceof UserError) {
				var selected = this.tileGrid.getSelected();
				var errorTile = {x:0, y:0};
				for(var i = 0; i < selected.length; i++) {
					var sel = selected[i];
					if(sel.x > errorTile.x || i == 0) {
						errorTile.x = sel.x;
						errorTile.y = sel.y;
					} else if(sel.y > errorTile.y) {
						errorTile.y = sel.y;
					}
				}
				this.tileGrid.openError(errorTile.x, errorTile.y, e.errorGroup);
			} else {
				throw e;
			}
		}.bind(this));
		this.rememberedExport = fn;
	}
}

var addExportFormat = function() {
	var filter;
	var tileShape = tileroninX.getTileShape();
	if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
		filter = tileroninX.exportFormatFilterOrthographic;
	} else if(tileShape == tileroninX.Shape.ISOMETRIC) {
		filter = tileroninX.exportFormatFilterIsometric;
	}
	var fn = dialog.showOpenDialogSync({properties: ['openFile'], filters: [ filter ] });
	onBrowserFile(fn, function(browserPath) {
		var name = path.basename(browserPath);
		fs.copyFile(browserPath, path.join(this.formatsDirectory, name), (err) => {
			if (err) throw err;
		});
	}.bind(this));
}

var buildBordersBlob = function() {
	var undoGroup = [];
	var errorGroup = [];

	var selected = this.tileGrid.getSelected();

	var selectedNonNull = [];
	var selectedNonNullPos = [];
	var origin;

	for(var i = 0; i < selected.length; i++) {
		var tileAt = tileroninX.getTileSet(selected[i].x, selected[i].y);
		if(tileAt != null) {
			if(selectedNonNull.length == 0) {
				origin = selected[i];
			}
			selectedNonNull.push(tileroninX.getTileSet(selected[i].x, selected[i].y));
			selectedNonNullPos.push(selected[i]);
		}
	}

	var tiles = tileroninX.buildBordersBlob(selectedNonNull, undoGroup, errorGroup);

	var addTiles = [];
	var newTiles = [];
	for(var index in tiles) {
		var tile = tiles[index];
		var st = selectedNonNull.indexOf(tile.tile);
		if(st != -1) {
			tileroninX.moveTilesSet([{x:selectedNonNullPos[st].x, y:selectedNonNullPos[st].y}], tile.pos.x+origin.x-selectedNonNullPos[st].x, tile.pos.y+origin.y-selectedNonNullPos[st].y, undoGroup);
		} else {
			newTiles.push(tile);
		}
	}
	for(var index in newTiles) {
		var tile = newTiles[index];
		addTiles.push({x:tile.pos.x+origin.x, y:tile.pos.y+origin.y, tile:tile.tile});
	}
	tileroninX.setTilesSet(addTiles, undoGroup);
	tileroninX.saveUndoState(undoGroup);

	if(errorGroup.length > 0) {
		var errorTile = {x:0, y:0};
		for(var i = 0; i < selected.length; i++) {
			var sel = selected[i];
			if(sel.x > errorTile.x || i == 0) {
				errorTile.x = sel.x;
				errorTile.y = sel.y;
			} else if(sel.y > errorTile.y) {
				errorTile.y = sel.y;
			}
		}
		this.tileGrid.openError(errorTile.x, errorTile.y, errorGroup);
	}
}

var buildBordersWang = function() {
	var undoGroup = [];
	var errorGroup = [];

	var selected = this.tileGrid.getSelected();

	var selectedNonNull = [];
	var selectedNonNullPos = [];
	var origin;

	for(var i = 0; i < selected.length; i++) {
		var tileAt = tileroninX.getTileSet(selected[i].x, selected[i].y);
		if(tileAt != null) {
			if(selectedNonNull.length == 0) {
				origin = selected[i];
			}
			selectedNonNull.push(tileroninX.getTileSet(selected[i].x, selected[i].y));
			selectedNonNullPos.push(selected[i]);
		}
	}

	var tiles = tileroninX.buildBordersWang(selectedNonNull, undoGroup, errorGroup);

	var addTiles = [];
	var newTiles = [];
	for(var index in tiles) {
		var tile = tiles[index];
		var st = selectedNonNull.indexOf(tile.tile);
		if(st != -1) {
			tileroninX.moveTilesSet([{x:selectedNonNullPos[st].x, y:selectedNonNullPos[st].y}], tile.pos.x+origin.x-selectedNonNullPos[st].x, tile.pos.y+origin.y-selectedNonNullPos[st].y, undoGroup);
		} else {
			newTiles.push(tile);
		}
	}
	for(var index in newTiles) {
		var tile = newTiles[index];
		addTiles.push({x:tile.pos.x+origin.x, y:tile.pos.y+origin.y, tile:tile.tile});
	}
	tileroninX.setTilesSet(addTiles, undoGroup);
	tileroninX.saveUndoState(undoGroup);

	if(errorGroup.length > 0) {
		var errorTile = {x:0, y:0};
		for(var i = 0; i < selected.length; i++) {
			var sel = selected[i];
			if(sel.x > errorTile.x || i == 0) {
				errorTile.x = sel.x;
				errorTile.y = sel.y;
			} else if(sel.y > errorTile.y) {
				errorTile.y = sel.y;
			}
		}
		this.tileGrid.openError(errorTile.x, errorTile.y, errorGroup);
	}
}

var groupAsProp = function() {
	var selected = this.tileGrid.getSelected();
	var tiles = [];
	for(var i in selected) {
		var tileAt = tileroninX.getTileSet(selected[i].x, selected[i].y);
		if(tileAt != null) {
			tiles.push({tile:tileAt, pos:{x:selected[i].x, y:selected[i].y}});
		}
	}
	if(tiles.length == 1) {
		tiles.push({tile:false, pos:{x:tiles[0].pos.x, y:tiles[0].pos.y}});
	}
	var undoGroup = [];
	var errorGroup = [];
	tileroninX.groupTilesAsProp(tiles, undoGroup, errorGroup);
	tileroninX.saveUndoState(undoGroup);

	if(errorGroup.length > 0) {
		var errorTile = {x:0, y:0};
		for(var i = 0; i < selected.length; i++) {
			var sel = selected[i];
			if(sel.x > errorTile.x || i == 0) {
				errorTile.x = sel.x;
				errorTile.y = sel.y;
			} else if(sel.y > errorTile.y) {
				errorTile.y = sel.y;
			}
		}
		this.tileGrid.openError(errorTile.x, errorTile.y, errorGroup);
	}
}

var setProxy = function() {
	var selected = this.tileGrid.getSelected();
	var tiles = [];
	for(var i in selected) {
		var tileAt = tileroninX.getTileSet(selected[i].x, selected[i].y);
		if(tileAt != null) {
			tiles.push(tileAt);
		}
	}
	var undoGroup = [];
	var errorGroup = [];
	tileroninX.setProxy(tiles, undoGroup, errorGroup);
	tileroninX.saveUndoState(undoGroup);

	if(errorGroup.length > 0) {
		var errorTile = {x:0, y:0};
		for(var i = 0; i < selected.length; i++) {
			var sel = selected[i];
			if(sel.x > errorTile.x || i == 0) {
				errorTile.x = sel.x;
				errorTile.y = sel.y;
			} else if(sel.y > errorTile.y) {
				errorTile.y = sel.y;
			}
		}
		this.tileGrid.openError(errorTile.x, errorTile.y, errorGroup);
	} else if(selected.length > 1) {
		// TilePropertiesView only builds Relations (incl. Proxy) for a single selection; keep one proxy tile selected.
		var pickPos = null;
		for(var si = 0; si < selected.length; si++) {
			var p = selected[si];
			var tileAtPick = tileroninX.getTileSet(p.x, p.y);
			if(tileAtPick == null) {
				continue;
			}
			var relList = tileAtPick.getRelations();
			for(var ri in relList) {
				if(relList[ri].r instanceof TileRelationProxy && !relList[ri].r.isReverse) {
					pickPos = p;
					break;
				}
			}
			if(pickPos != null) {
				break;
			}
		}
		if(pickPos != null) {
			this.tileGrid.select([pickPos]);
			var oneTile = tileroninX.getTileSet(pickPos.x, pickPos.y);
			var tilesOne = [{tile:oneTile, pos:pickPos}];
			this.selectedTileChangedCallback.notify(tilesOne);
			this.currentSelection = tilesOne;
		}
	}
}

var createAutoRegion = function() {
	var fn = dialog.showOpenDialogSync({properties: ['openFile'], filters: [ tileroninX.imageImportFileFilter ] });
	onBrowserFile(fn, function(browserPath) {
		var origin = this.tileGrid.getSelectionPoint();
		var undoGroup = [];
		tileroninX.addRegionSet(new RegionSync(origin.x, origin.y, browserPath), undoGroup);
		tileroninX.saveUndoState(undoGroup);
	}.bind(this));
}

var logInsideDiv;
var logDiv;

var bindHotkeys = function() {
	Mousetrap.bind(['command+c', 'ctrl+c'], clipboardCopy.bind(this));
	Mousetrap.bind(['command+shift+c', 'ctrl+shift+c'], clipboardCopyRaw.bind(this));
	Mousetrap.bind(['command+v', 'ctrl+v'], clipboardPaste.bind(this));
	Mousetrap.bind(['command+i', 'ctrl+i'], importTiles.bind(this));
	//Mousetrap.bind(['command+e', 'ctrl+e'], exportTiles.bind(this));

	Mousetrap.bind(['command+n', 'ctrl+n'], newData.bind(this));
	Mousetrap.bind(['command+o', 'ctrl+o'], loadData.bind(this));
	Mousetrap.bind(['command+s', 'ctrl+s'], saveData.bind(this));
	Mousetrap.bind(['command+shift+s', 'ctrl+shift+s'], saveDataAs.bind(this));

	Mousetrap.bind(['command+z', 'ctrl+z'], performUndo.bind(this));
	Mousetrap.bind(['command+y', 'command+shift+z', 'ctrl+y', 'ctrl+shift+z'], performRedo.bind(this));

	Mousetrap.bind(['command+-', 'ctrl+-'], zoomIn.bind(this));
	Mousetrap.bind(['command+=', 'ctrl+='], zoomOut.bind(this));
}

var setupTileGrid = function() {
	var reload = false;
	if(this.tileGrid != null) {
		this.div.removeChild(this.tileGrid.getDiv());
		reload = true;
	}
	var menuOptions = [
		[
			{label:"Copy"}, 
			{label:"Copy Raw"}, 
			{label:"Paste"}
		], 
		[
			{label:"Import"}, 
			{label:"Export", sub:
				[
					[
						{label:"Add Export Format"},
					]
				]
			}
		], 
		[
			{label:"Build Borders (Blob)"}, 
			{label:"Build Borders (Wang)"}
		], 
		[
			{label:"Create Sync Region"}
		], 
		[
			{label:"Group as Prop"}, 
			{label:"Set Proxy"}
		]
	];
	var tileShape = tileroninX.getTileShape();
	if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
		this.tileGrid = new TileGridOrthographicView(tileroninX.getTileSize(), menuOptions);
	} else if(tileShape == tileroninX.Shape.ISOMETRIC) {
		this.tileGrid = new TileGridIsometricView(tileroninX.getTileSize(), menuOptions);
	}
	this.tileGrid.menuOptionClickedSubscribe(function(indices) {
		var index = indices[0];
		if(index == 0) {
			clipboardCopy.bind(this)();
		} else if(index == 1) {
			clipboardCopyRaw.bind(this)();
		} else if(index == 2) {
			clipboardPaste.bind(this)();
		} else if(index == 3) {
			importTiles.bind(this)();
		} else if(index == 4) {
			var subindex = indices[1];
			var currentIndex = 0;
			var tileShape = tileroninX.getTileShape();
			if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
				for(var k in this.exportFormatsOrthographic) {
					if(subindex == currentIndex) {
						exportTiles.bind(this)(this.exportFormatsOrthographic[k]);
					}
					currentIndex++;
				}
			} else if(tileShape == tileroninX.Shape.ISOMETRIC) {
				for(var k in this.exportFormatsIsometric) {
					if(subindex == currentIndex) {
						exportTiles.bind(this)(this.exportFormatsIsometric[k]);
					}
					currentIndex++;
				}
			}
			if(subindex == currentIndex) {
				addExportFormat.bind(this)();
			}
		} else if(index == 5) {
			buildBordersBlob.bind(this)();
		} else if(index == 6) {
			buildBordersWang.bind(this)();
		} else if(index == 7) {
			createAutoRegion.bind(this)();
		} else if(index == 8) {
			groupAsProp.bind(this)();
		} else if(index == 9) {
			setProxy.bind(this)();
		}
	}.bind(this));
	this.tileGrid.mouseDownSubscribe(function(tilePos, region, event) {
		if(event.button == 0) {
			if(event.altKey) {
				this.tileGrid.setStatePan();
			} else {
				if(region != null) {
					this.tileGrid.setStateMoveRegion(tilePos.x, tilePos.y, region);
					if(this.tilePickCallback != null) {
						this.tilePickCallback(false);
						this.tilePickCallback = null;
					}
				} else {
					if(this.tilePickCallback != null) {
						this.tileGrid.setStatePick(tilePos.x, tilePos.y);
					} else {
						if(this.tileGrid.selectionContains(tilePos.x, tilePos.y)) {
							this.tileGrid.setStateMove(tilePos.x, tilePos.y);
						} else {
							this.tileGrid.setStateSelect(tilePos.x, tilePos.y);
						}
					}
				}
			}
		} else if(event.button == 1) {
			if(event.ctrlKey) {
				this.tileGrid.setStateZoom(tilePos.x, tilePos.y);
			} else {
				this.tileGrid.setStatePan();
			}
		} else if(event.button == 2) {
			if(this.tilePickCallback != null) {
				this.tileGrid.setStatePick(tilePos.x, tilePos.y);
			} else {
				if(!this.tileGrid.selectionContains(tilePos.x, tilePos.y)) {
					this.tileGrid.setStateSelect(tilePos.x, tilePos.y);
				}
			}
		}
	}.bind(this)); 
	this.tileGrid.mouseUpSubscribe(function(tilePos, event, state) {
		if(this.tilePickCallback != null) {
			if(state == 6) {
				var tilePicked = tileroninX.getTileSet(tilePos.x, tilePos.y);
				this.tilePickCallback(tilePicked);
				this.tilePickCallback = null;
			}
		} else {
			if(event.button == 2) {
				var selectedTiles = this.tileGrid.getSelected();
				var menuTile = {x:0, y:0};
				for(var i = 0; i < selectedTiles.length; i++) {
					var sel = selectedTiles[i];
					if(sel.x > menuTile.x || i == 0) {
						menuTile.x = sel.x;
						menuTile.y = sel.y;
					} else if(sel.y > menuTile.y) {
						menuTile.y = sel.y;
					}
				}
				this.tileGrid.openMenu(menuTile.x, menuTile.y);
			}
			if(/*event.button == 2 || event.button == 0*/ state == 2 || state == 3 || state == 5) { //change selection
				var points = this.tileGrid.getSelected();
				var tiles = [];
				var equal = true;
				for(var pi = 0; pi < points.length; pi++) {
					var tileSelected = tileroninX.getTileSet(points[pi].x, points[pi].y);
					if(tileSelected != null) {
						tiles.push({tile:tileSelected, pos:points[pi]});
						if(equal && (this.currentSelection.length < tiles.length || tiles[tiles.length-1].tile != this.currentSelection[tiles.length-1].tile)) {
							equal = false;
						}
					}
				}
				if(tiles.length != this.currentSelection.length) {
					equal = false;
				}
				if(!equal) {
					this.selectedTileChangedCallback.notify(tiles);
				}
				this.currentSelection = tiles;
			}
		}
	}.bind(this));
	this.tileGrid.mouseWheelSubscribe(function(tilePos, deltaZoom) {
		this.tileGrid.zoom(tilePos, deltaZoom);
	}.bind(this));
	this.tileGrid.tilesMovedSubscribe(function(positions, ox, oy) {
		var undoGroup = [];
		tileroninX.moveTilesSet(positions, ox, oy, undoGroup);
		tileroninX.saveUndoState(undoGroup);
	}.bind(this));
	this.tileGrid.regionMovedSubscribe(function(region, ox, oy) {
		var undoGroup = [];
		tileroninX.moveRegionSet(region, ox, oy, undoGroup);
		tileroninX.saveUndoState(undoGroup);
	}.bind(this));
	this.tileGrid.regionRemovedSubscribe(function(region) {
		var undoGroup = [];
		tileroninX.removeRegionSet(region, undoGroup);
		tileroninX.saveUndoState(undoGroup);
	})
	this.tileGrid.selectionSizeChangedSubscribe(function() {
		updateSelectionInfo.bind(this)();
	}.bind(this));
	this.div.appendChild(this.tileGrid.getDiv());
	updateSelectionInfo.bind(this)();
	if(reload) {
		updateMenuOptions.bind(this)();
		tileroninX.syncTileGridFromSetView(this.tileGrid);
	}
}

var zoomIn = function() {
	this.tileGrid.zoom(this.tileGrid.getSelectionPoint(), 200);
}

var zoomOut = function() {
	this.tileGrid.zoom(this.tileGrid.getSelectionPoint(), -200);
}

var updateSelectionInfo = function() {
	var size = this.tileGrid.getSelectionSize();
	this.infoText.innerHTML = size.x+" "+"x"+" "+size.y;
}

var updateMenuOptions = function() {
	var options = 
	[
		[
			{label:"Copy"}, 
			{label:"Copy Raw"}, 
			{label:"Paste"}
		], 
		[
			{label:"Import"}, 
			{label:"Export", sub:
				[
					[
						{label:"Add Export Format"},
					]
				]
			}
		], 
		[
			{label:"Build Borders (Blob)"}, 
			{label:"Build Borders (Wang)"}
		], 
		[
			{label:"Create Sync Region"}
		], 
		[
			{label:"Group as Prop"}, 
			{label:"Set Proxy"}
		]
	]
	var formatOptions = [];
	var formatsList;
	var tileShape = tileroninX.getTileShape();
	if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
		formatsList = this.exportFormatsOrthographic;
	} else if(tileShape == tileroninX.Shape.ISOMETRIC) {
		formatsList = this.exportFormatsIsometric;
	}
	for(var fn in formatsList) {
		var formatName = path.basename(fn, path.extname(fn));
		formatOptions.push({label:formatName});
	}
	if(formatOptions.length > 0) {
		options[1][1].sub.unshift(formatOptions);
	}
	this.tileGrid.setMenuOptions(options);
}

class SetView {
	constructor() {
		this.div = document.createElement('div');
		this.div.style.position = "absolute";
		this.div.style.top = '0';
		this.div.style.bottom = '0';
        this.div.style.left = '0';
        this.div.style.right = '0';
        this.div.style.overflow = "hidden";

        this.tilePickCallback = null;

        this.currentSelection = [];

        this._lastWorkspaceCameraSnapGen = 0;

        this.formatsWatcher = null;
        this.formatsDirectory = null;
        this.exportFormatsOrthographic = {};
        this.exportFormatsIsometric = {};

        this.newMenu = new ExpandingMenuView(
        	[
        		[
        			{label:"New Orthographic Project"},
        			{label:"New Isometric Project"},
        			{label:"Convert to Isometric (current project)"}
        		]
        	]);
        this.newMenu.optionClickedSubscribe(function(indices) {
        	var index = indices[0];
			if(index == 0) {
				newDataConfirm.bind(this)(tileroninX.Shape.ORTHOGRAPHIC);
			} else if(index == 1) {
				newDataConfirm.bind(this)(tileroninX.Shape.ISOMETRIC);
			} else if(index == 2) {
				if(tileroninX.getTileShape() != tileroninX.Shape.ORTHOGRAPHIC) {
					this.tileSizeErrorDisplay.open(this.tileSizeErrorDisplayPos.x, this.tileSizeErrorDisplayPos.y, [
						{msg: "Only orthographic projects can convert to isometric."}
					]);
					return;
				}
				var undoGroup = [];
				var errorGroup = [];
				if(tileroninX.convertOrthographicToIsometric(undoGroup, errorGroup)) {
					tileroninX.saveUndoState(undoGroup);
				} else if(errorGroup.length > 0) {
					this.tileSizeErrorDisplay.open(this.tileSizeErrorDisplayPos.x, this.tileSizeErrorDisplayPos.y, errorGroup);
				}
			}
		}.bind(this));
		this.newMenu.getDiv().style.zIndex = 2147483647;
        this.div.appendChild(this.newMenu.getDiv());

        this.selectedTileChangedCallback = new CallbackManager();
        this.tooltipCallback = new CallbackManager();

		this.div.tabIndex = "1";
		this.div.addEventListener('mousedown', function(event) {
			bindHotkeys.bind(this)();
			this.newMenu.close();
			this.tileSizeErrorDisplay.close();
		}.bind(this));
		this.div.addEventListener('keydown', function(event) {
			if(event.keyCode == 46 || event.keyCode == 8) {
				var selectedTiles = this.tileGrid.getSelected();
				var addTiles = [];
				for(var i in selectedTiles) {
					var pos = selectedTiles[i];
					addTiles.push({x:pos.x, y:pos.y, tile:null});
				}
				var undoGroup = [];
				tileroninX.setTilesSet(addTiles, undoGroup);
				tileroninX.saveUndoState(undoGroup);
				if(this.tilePickCallback != null) {
					this.tilePickCallback(false);
					this.tilePickCallback = null;
				}
			}
		}.bind(this), false);

		bindHotkeys.bind(this)();

		this.infoDiv = document.createElement('div');
		this.infoDiv.className = "setview-info-view";
		this.infoDiv.style.zIndex = 2147483647;
		this.div.appendChild(this.infoDiv);
		var infoIcon = document.createElement('img');
		infoIcon.className = "setview-info-icon-view";
		infoIcon.src = "./../res/icon/ui_icon_c0.png";
		this.infoDiv.appendChild(infoIcon);
		this.infoText = document.createElement('div');
		this.infoText.className = "setview-info-text-view";
		this.infoDiv.appendChild(this.infoText);

		setupTileGrid.bind(this)();

		tileroninX.tileSizeChangedSubscribe(function(size) {
			this.tileGrid.setTileSize(size);
			var tileShape = tileroninX.getTileShape();
			if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
				this.tileSizeSelectorOrtho.setValue(size);
			} else if(tileShape == tileroninX.Shape.ISOMETRIC) {
				this.tileSizeSelectorIso.setValues(size);
			}
			var snapGen = tileroninX.getWorkspaceCameraSnapGeneration();
			if(snapGen > this._lastWorkspaceCameraSnapGen) {
				this._lastWorkspaceCameraSnapGen = snapGen;
				var sh2 = tileroninX.getTileShape();
				if(sh2 == tileroninX.Shape.ISOMETRIC) {
					var szi = tileroninX.getTileSize();
					this.tileGrid.setCamera(szi[0] / 2.0, 0);
				} else if(sh2 == tileroninX.Shape.ORTHOGRAPHIC) {
					this.tileGrid.setCamera(0, 0);
				}
			}
		}.bind(this))
		tileroninX.tileShapeChangedSubscribe(function(shape) {
			setupTileGrid.bind(this)();
			if(shape == tileroninX.Shape.ORTHOGRAPHIC) {
				this.tileSizeSelectorOrtho.getDiv().style.display = "flex";
				this.tileSizeStepControls.style.display = "flex";
				this.tileSizeSelectorIso.getDiv().style.display = "none";
			} else if(shape == tileroninX.Shape.ISOMETRIC) {
				this.tileSizeSelectorOrtho.getDiv().style.display = "none";
				this.tileSizeStepControls.style.display = "none";
				this.tileSizeSelectorIso.getDiv().style.display = "flex";
			}
		}.bind(this))

		var iconTray = new IconTrayView([	["./../res/icon/ui_icon_b20.png", "./../res/icon/ui_icon_a20.png"],
											["./../res/icon/ui_icon_b17.png", "./../res/icon/ui_icon_a17.png"],
											["./../res/icon/ui_icon_b16.png", "./../res/icon/ui_icon_a16.png"]	],
											["New Project",
											"Load Project",
											"Save Project"]);
		iconTray.getDiv().classList.add("setview-project-actions-view");
		iconTray.iconClickedSubscribe(function(index, shift) {
			if(index == 0) {
				newData.bind(this)();
			} if(index == 1) {
				loadData.bind(this)();
			} else if(index == 2) {
				if(shift) {
					saveDataAs.bind(this)();
				} else {
					saveData.bind(this)();
				}
			}
		}.bind(this));
		iconTray.tooltipSubscribe(function(msg) {
			this.tooltipCallback.notify(msg);
		}.bind(this));
		this.div.appendChild(iconTray.getDiv());

		var trayDiv = document.createElement('div');
		trayDiv.className = "setview-tray-view";
		trayDiv.style.zIndex = 2147483647;

		//LOGGING
		logDiv = document.createElement('div');
		logDiv.className = "setview-log-view";
		logDiv.style.zIndex = 2147483647;
		this.div.appendChild(logDiv);

		logInsideDiv = document.createElement('div');
		logInsideDiv.className = "setview-log-inside-view";
		logInsideDiv.style.zIndex = 2147483647;
		logDiv.appendChild(logInsideDiv);


		var logTray = new IconTrayView([	["./../res/icon/ui_icon_b18.png", "./../res/icon/ui_icon_a18.png"]	], ["Copy"]);
		logTray.iconClickedSubscribe(function(index) {
			if(index == 0) {
				clipboard.writeText(logInsideDiv.innerHTML.split('<div style="height:0px; border-style: dashed; border-width: 1px 0px 0px 0px; margin: 4px 0px 4px 0px; border-color:var(--colorError);"></div>').join("\n"));
			}
		});
		logDiv.appendChild(logTray.getDiv());
		//LOGGING

		this.tileSizeSelectorOrtho = new PropertyEditTextView("Tile Size", tileroninX.getTileSize(), "px", true);
		this.tileSizeSelectorOrtho.valueChangedSubscribe(function(value) {
			if(this.tilePickCallback != null) {
				this.tilePickCallback(false);
				this.tilePickCallback = null;
			}
			if(tileroninX.getTileShape() == tileroninX.Shape.ORTHOGRAPHIC) {
				var undoGroup = [];
				var errorGroup = [];
				tileroninX.setTileSize(parseInt(value), undoGroup, errorGroup);
				if(errorGroup.length > 0) {
					this.tileSizeErrorDisplay.open(this.tileSizeErrorDisplayPos.x, this.tileSizeErrorDisplayPos.y, errorGroup);
					this.tileSizeSelectorOrtho.setValue(tileroninX.getTileSize());
				} else {
					tileroninX.saveUndoState(undoGroup);
				}
			}
		}.bind(this));
		this.tileSizeStepControls = document.createElement('div');
		this.tileSizeStepControls.className = 'setview-tilesize-steps-view';
		var tileSizeStepDown = document.createElement('button');
		tileSizeStepDown.type = 'button';
		tileSizeStepDown.className = 'setview-tilesize-step-view';
		tileSizeStepDown.innerHTML = '-12';
		tileSizeStepDown.addEventListener('click', function(event) {
			event.preventDefault();
			event.stopPropagation();
			this.tileSizeSelectorOrtho.offset(-12);
		}.bind(this), false);
		var tileSizeStepUp = document.createElement('button');
		tileSizeStepUp.type = 'button';
		tileSizeStepUp.className = 'setview-tilesize-step-view';
		tileSizeStepUp.innerHTML = '+12';
		tileSizeStepUp.addEventListener('click', function(event) {
			event.preventDefault();
			event.stopPropagation();
			this.tileSizeSelectorOrtho.offset(12);
		}.bind(this), false);
		this.tileSizeStepControls.appendChild(tileSizeStepDown);
		this.tileSizeStepControls.appendChild(tileSizeStepUp);
		trayDiv.appendChild(this.tileSizeSelectorOrtho.getDiv());
		trayDiv.appendChild(this.tileSizeStepControls);

		this.tileSizeSelectorIso = new PropertyEditTextMultiView("Tile Size", [0, 0], "px", true);
		this.tileSizeSelectorIso.getDiv().style.display = "none";
		this.tileSizeSelectorIso.valueChangedSubscribe(function(values) {
			if(this.tilePickCallback != null) {
				this.tilePickCallback(false);
				this.tilePickCallback = null;
			}
			if(tileroninX.getTileShape() == tileroninX.Shape.ISOMETRIC) {
				var undoGroup = [];
				var errorGroup = [];
				tileroninX.setTileSize([parseInt(values[0]), parseInt(values[1])], undoGroup, errorGroup);
				if(errorGroup.length > 0) {
					this.tileSizeErrorDisplay.open(this.tileSizeErrorDisplayPos.x, this.tileSizeErrorDisplayPos.y, errorGroup);
					this.tileSizeSelectorIso.setValues(tileroninX.getTileSize());
				} else {
					tileroninX.saveUndoState(undoGroup);
				}
			}
		}.bind(this));
		trayDiv.appendChild(this.tileSizeSelectorIso.getDiv());

		requestAnimationFrame(function() {
			var embed = document.body.classList && document.body.classList.contains('ronintile-embed');
			var padTop = embed ? 44 : 0;
			var trayExtraLeft = embed ? 56 : 0;
			var iw = iconTray.getDiv().offsetWidth;
			iconTray.getDiv().style.top = embed ? (padTop + 'px') : '';
			trayDiv.style.left = (iw + 16 + trayExtraLeft) + 'px';
			// Tile Size 条只水平右移避让「返回首页」，不与新建/打开/保存一起下移
			trayDiv.style.top = '';
			this.div.appendChild(trayDiv);

			var rowH = Math.max(trayDiv.offsetHeight, iconTray.getDiv().offsetHeight);
			this.newMenuPos = { x: iw + 16, y: padTop + rowH - 4 };
			this.tileSizeErrorDisplayPos = { x: iw + 7 + trayExtraLeft, y: trayDiv.offsetHeight - 4 };
		}.bind(this));

        this.tileSizeErrorDisplay = new ErrorDisplayView();
		this.tileSizeErrorDisplay.getDiv().style.zIndex = 2147483647;
		this.tileSizeErrorDisplay.getDiv().style.transform = "translateY(0)";
		this.tileSizeErrorDisplay.getDiv().children.item(1).style.left = "29px";
		this.tileSizeErrorDisplay.getDiv().children.item(1).style.top = "-9px";
		this.tileSizeErrorDisplay.getDiv().children.item(1).style.transform = "rotate(90deg)";
		this.div.appendChild(this.tileSizeErrorDisplay.getDiv());

		tileroninX.tileChangedSetSubscribe(function(pos) {
			var selectionUpdated = false;
			for(var i in pos) {
				var p = pos[i];
				var tile = tileroninX.getTileSet(p.x, p.y);
				this.tileGrid.setTile(tile, p.x, p.y);

				if(!selectionUpdated && this.tileGrid.selectionContains(p.x, p.y)) {
					selectionUpdated = true;
				}
			}

			if(selectionUpdated) {
				var points = this.tileGrid.getSelected();
				var tiles = [];
				var equal = true;
				for(var pi = 0; pi < points.length; pi++) {
					var tileSelected = tileroninX.getTileSet(points[pi].x, points[pi].y);
					if(tileSelected != null) {
						tiles.push({tile:tileSelected, pos:points[pi]});
						if(equal && (this.currentSelection.length < tiles.length || tiles[tiles.length-1].tile != this.currentSelection[tiles.length-1].tile)) {
							equal = false;
						}
					}
				}
				if(tiles.length != this.currentSelection.length) {
					equal = false;
				}
				if(!equal) {
					this.selectedTileChangedCallback.notify(tiles);
				}
				this.currentSelection = tiles;
			}
		}.bind(this));

		tileroninX.regionAddedSetSubscribe(function(region) {
			this.tileGrid.addRegion(region);
		}.bind(this));

		tileroninX.regionRemovedSetSubscribe(function(region) {
			this.tileGrid.removeRegion(region);
		}.bind(this));

		tileroninX.regionChangedSetSubscribe(function(region) {
			this.tileGrid.updateRegion(region);
		}.bind(this));

		this.currentProject = null;
		this.rememberedExport = null;

		tileroninX.onNewSubscribe(function() {
			this.tileGrid.setZoom(1);
			var tileShape = tileroninX.getTileShape();
			if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
				this.tileGrid.setCamera(0, 0);
			} else if(tileShape == tileroninX.Shape.ISOMETRIC) {
				this.tileGrid.setCamera(tileroninX.getTileSize()[0]/2.0, 0);
			}
		}.bind(this));

		tileroninX.onSaveSubscribe(function(extra) {
			var camera = this.tileGrid.getCamera();
			var zoom = this.tileGrid.getZoom();
			extra.set = {	camX:camera.x,
							camY:camera.y,
							camZoom:zoom};
		}.bind(this));

		tileroninX.onLoadSubscribe(function(data) {
			var loadFunc = {'0.1.0-beta.0':loadExtra_1,
	                        '0.1.0-beta.1':loadExtra_1,
	                        '0.1.0-beta.2':loadExtra_1,
	                        '0.1.0-beta.3':loadExtra_1,
	                        '0.1.0-beta.4':loadExtra_2,
	                        '0.1.0-beta.5-lite':loadExtra_2,
	                        '0.1.0-beta.5-pro':loadExtra_2,
	                        '0.1.0-beta.6-lite':loadExtra_2,
	                        '0.1.0-beta.6-pro':loadExtra_2,
	                        '0.1.0-beta.7-lite':loadExtra_2,
	                        '0.1.0-beta.7-pro':loadExtra_2,
	                        '1.0.0-lite':loadExtra_2,
	                        '1.0.0-pro':loadExtra_2,
	                        '1.0.1-dev.0-lite':loadExtra_2,
	                        '1.0.1-dev.0-pro':loadExtra_2,
	                        '1.0.1-lite':loadExtra_2,
	                        '1.0.1-pro':loadExtra_2,
	                        '1.0.2-dev.0-lite':loadExtra_2,
	                        '1.0.2-dev.0-pro':loadExtra_2,
	                        '1.0.2-lite':loadExtra_2,
	                        '1.0.2-pro':loadExtra_2,
	                        '2.0.0-dev.0-lite':loadExtra_2,
	                        '2.0.0-dev.0-pro':loadExtra_2,
	                        '2.0.0-dev.1-lite':loadExtra_2,
	                        '2.0.0-dev.1-pro':loadExtra_2,
	                        '2.0.0-dev.2-lite':loadExtra_2,
	                        '2.0.0-dev.2-pro':loadExtra_2,
	                        '2.0.0-dev.3-lite':loadExtra_2,
	                        '2.0.0-dev.3-pro':loadExtra_2,
	                        '2.0.0-dev.4-lite':loadExtra_2,
	                        '2.0.0-dev.4-pro':loadExtra_2,
	                        '2.0.0-lite':loadExtra_2,
	                        '2.0.0-pro':loadExtra_2,
	                        '2.1.0-dev.0-lite':loadExtra_2,
	                        '2.1.0-dev.0-pro':loadExtra_2,
	                        '2.1.0-lite':loadExtra_2,
	                        '2.1.0-pro':loadExtra_2};
	        var loadFn = loadFunc[data.version];
            if(loadFn == null) {
                return;
            }
            loadFn.bind(this)(data);
		}.bind(this));

		var loadExtra_1 = function(data) {
			//do nothing
		}

		var loadExtra_2 = function(data) {
			this.tileGrid.setZoom(data.extra.set.camZoom);
			this.tileGrid.setCamera(data.extra.set.camX, data.extra.set.camY);
		}
	}

	getDiv() {
		return this.div;
	}

	pickTile(fn) {
		this.newMenu.close();
		this.tileSizeErrorDisplay.close();
		this.tileGrid.closeMenu();
		this.tileGrid.closeError();
		this.tilePickCallback = fn;
	}

	selectTile(tile) {
		var pos = tileroninX.getTilePositionSet(tile);
		if(pos != null) {
			this.tileGrid.select([{x:pos.x, y:pos.y}]);

			var tiles = [{tile:tile, pos:{x:pos.x, y:pos.y}}];
			var equal = false;
			if(tiles.length == this.currentSelection.length) {
				equal = true;
				for(var i = 0; i < tiles.length; i++) {
					if(tiles[i].tile != this.currentSelection[i].tile) {
						equal = false;
						break;
					}
				}
			}
			if(!equal) {
				this.selectedTileChangedCallback.notify(tiles);
			}
			this.currentSelection = tiles;
		}
	}

	selectedTileChangedSubscribe(func) {
		this.selectedTileChangedCallback.subscribe(func);
	}

	tooltipSubscribe(func) {
		this.tooltipCallback.subscribe(func);
	}

	displayError(message) {
		logDiv.style.visibility = 'visible';
		if(logInsideDiv.innerHTML !== "") {
			logInsideDiv.innerHTML += '<div style="height:0px; border-style: dashed; border-width: 1px 0px 0px 0px; margin: 4px 0px 4px 0px; border-color:var(--colorError);"></div>';
		}
		logInsideDiv.innerHTML += message;
	}

	getCurrentProject() {
		return this.currentProject;
	}

	setCurrentProject(fn) {
		this.currentProject = fn;
	}

	setFormatsDirectory(fn) {
		this.formatsDirectory = fn;
		this.exportFormatsOrthographic = {};
		this.exportFormatsIsometric = {};
		if(this.formatsWatcher != null) {
			this.formatsWatcher.close();
		}

		var errorGroup = [];
		var timeout = null;

		function parseExportFormat(fn) {
			var exportFormat;
			try {
				var exportFormat = tileroninXExport.parseExportFormat(fn);
				if(exportFormat.shape == tileroninX.Shape.ORTHOGRAPHIC) {
					this.exportFormatsOrthographic[fn] = exportFormat.format;
				} else if(exportFormat.shape == tileroninX.Shape.ISOMETRIC) {
					this.exportFormatsIsometric[fn] = exportFormat.format;
				}
				updateMenuOptions.bind(this)();
			} catch(e) {
				if(this.exportFormatsOrthographic[fn] != null) {
					this.exportFormatsOrthographic[fn] = null;
					delete this.exportFormatsOrthographic[fn];
					updateMenuOptions.bind(this)();
				}
				if(this.exportFormatsIsometric[fn] != null) {
					this.exportFormatsIsometric[fn] = null;
					delete this.exportFormatsIsometric[fn];
					updateMenuOptions.bind(this)();
				}
				if(e instanceof UserError) {
					errorGroup = errorGroup.concat(e.errorGroup);
				} else {
					throw e;
				}
			}
			if(timeout != null) {
				clearTimeout(timeout);
			}
			timeout = setTimeout(function() {
				if(errorGroup.length == 0) {
					this.tileGrid.closeError();
				} else {
					var displayErrors = errorGroup;
					errorGroup = [];
					var selected = this.tileGrid.getSelected();
					var errorTile = {x:0, y:0};
					for(var i = 0; i < selected.length; i++) {
						var sel = selected[i];
						if(sel.x > errorTile.x || i == 0) {
							errorTile.x = sel.x;
							errorTile.y = sel.y;
						} else if(sel.y > errorTile.y) {
							errorTile.y = sel.y;
						}
					}
					this.tileGrid.closeMenu();
					this.tileGrid.openError(errorTile.x, errorTile.y, displayErrors);
				}
			}.bind(this), 10);
		}

		this.formatsWatcher = chokidar.watch(this.formatsDirectory, 
			{awaitWriteFinish: {
	    		stabilityThreshold: 500,
	    		pollInterval: 100,
			},
			ignorePermissionErrors: true}
		).on('add', function(fn) {
			parseExportFormat.bind(this)(fn);
		}.bind(this)).on('change', function(fn) {
			parseExportFormat.bind(this)(fn);
		}.bind(this)).on('unlink', function(fn) {
			if(this.exportFormatsOrthographic[fn] != null) {
				this.exportFormatsOrthographic[fn] = null;
				delete this.exportFormatsOrthographic[fn];
				updateMenuOptions.bind(this)();
			}
			if(this.exportFormatsIsometric[fn] != null) {
				this.exportFormatsIsometric[fn] = null;
				delete this.exportFormatsIsometric[fn];
				updateMenuOptions.bind(this)();
			}
		}.bind(this));
	}
}
module.exports = SetView;
