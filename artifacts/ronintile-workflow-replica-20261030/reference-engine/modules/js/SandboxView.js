var TileGrid = require('./TileGrid.js');
var TileGridOrthographicView = require('./TileGridOrthographicView.js');
var TileGridIsometricView = require('./TileGridIsometricView.js');
var Tile = require('./Tile.js');
var TileBase = require('./TileBase.js');
var IconTraySelectView = require('./IconTraySelectView.js');
var IconTrayView = require('./IconTrayView.js');

var LayerList = require('./LayerList.js');

var plh = require('./PointerLockHandler.js');

var PropertyEditTextView = require('./PropertyEditTextView.js');

var LayerDisplayView = require('./LayerDisplayView.js');

var CallbackManager = require('./CallbackManager.js');

var TileRelationBlobBorder = require('./TileRelationBlobBorder.js');
var TileRelationWangBorder = require('./TileRelationWangBorder.js');

var {clipboard} = require('electron');
const {ipcRenderer} = require('electron');

var nativeImage = require('electron').nativeImage;
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
	if(clipboard.has("ronintile Set")) { //smart paste
		var tiles = tileroninX.parseClipboardSandbox(Buffer.from(clipboard.readBuffer("ronintile Set").buffer));

		var origin = this.tileGrid.getSelectionPoint();
		
		var addTiles = [];
		for(var index in tiles) {
			var tile = tiles[index];
			addTiles.push({x:tile.pos.x+origin.x, y:tile.pos.y+origin.y, z:this.selectedLayerIndex, tile:tile.tile});
		}
		var undoGroup = [];
		tileroninX.setTilesSandbox(addTiles, undoGroup);
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

		var errorGroup = [];
		var sources = tileroninX.imageToSourcesDistinct(pasted, errorGroup);
		if(errorGroup.length > 0) {
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
			this.tileGrid.openError(errorTile.x, errorTile.y, errorGroup);
		} else {
			var origin = this.tileGrid.getSelectionPoint();
			var newTiles = [];
			var addTiles = [];
			for(var index in sources) {
				var source = sources[index];
				var tIndex = -1;
				for(var k in newTiles) {
					if(source.src == newTiles[k].getSource()) {
						tIndex = k;
						break;
					}
				}
				if(tIndex == -1) {
					tIndex = newTiles.length;
					newTiles.push(new TileBase(source.src));
				}
				addTiles.push({x:source.pos.x+origin.x, y:source.pos.y+origin.y, z:this.selectedLayerIndex, tile:newTiles[tIndex]});
			}
			var undoGroup = [];
			tileroninX.setTilesSandbox(addTiles, undoGroup);
			tileroninX.saveUndoState(undoGroup);
		}
	}
}

var clipboardCopy = function() {
	tileroninX.buildClipboardSandbox(this.tileGrid.getSelected(), this.selectedLayerIndex).then(function(data) {
		ipcRenderer.send('clipboardWrite', null, {format:"ronintile Set", data:data});
	});
}

var clipboardCopyRaw = function() {
	tileroninX.toImageSandbox(this.tileGrid.getSelected(), this.selectedLayerIndex).then(function(image) {
		ipcRenderer.send('clipboardWrite', image.toDataURL());
	});
}

var importTiles = function() {
	if(tileroninX.getTileShape() == tileroninX.Shape.ISOMETRIC) {
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
		this.tileGrid.openError(errorTile.x, errorTile.y, [{msg:"Importing images into the map editor is disabled for isometric."}]);
		return;
	}
	var fn = dialog.showOpenDialogSync({properties: ['openFile'], filters: [ tileroninX.imageImportFileFilter ] });
	onBrowserFile(fn, function(browserPath) {
		var image = nativeImage.createFromPath(browserPath);

		var errorGroup = [];
		var sources = tileroninX.imageToSourcesDistinct(image, errorGroup);
		if(errorGroup.length > 0) {
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
			this.tileGrid.openError(errorTile.x, errorTile.y, errorGroup);
		} else {
			var origin = this.tileGrid.getSelectionPoint();
			var newTiles = [];
			var addTiles = [];
			for(var index in sources) {
				var source = sources[index];
				var tIndex = -1;
				for(var k in newTiles) {
					if(source.src == newTiles[k].getSource()) {
						tIndex = k;
						break;
					}
				}
				if(tIndex == -1) {
					tIndex = newTiles.length;
					newTiles.push(new TileBase(source.src));
				}
				addTiles.push({x:source.pos.x+origin.x, y:source.pos.y+origin.y, z:this.selectedLayerIndex, tile:newTiles[tIndex]});
			}
			var undoGroup = [];
			tileroninX.setTilesSandbox(addTiles, undoGroup);
			tileroninX.saveUndoState(undoGroup);
		}
	}.bind(this));
}

var exportTiles = function(format) {
	var fn = dialog.showSaveDialogSync({defaultPath:((this.rememberedExport==null)?"":this.rememberedExport), filters:[{name: format.getName().getText({}), extensions: ['']}]});
	if(fn != null) {
		tileroninX.exportPackageMap(this.tileGrid.getSelected(), fn, format).catch(function(e) {
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

var drawTiles = function(pos, undoGroup) {
	var addTiles = [];
	for(var i in pos) {
		var x = pos[i].x
		var y = pos[i].y;
		if(this.erasing || this.lastStamp == null || x >= this.lastStamp.x+this.brushDimensions.x || x <= this.lastStamp.x-this.brushDimensions.x || y >= this.lastStamp.y+this.brushDimensions.y || y <= this.lastStamp.y-this.brushDimensions.y) {//prevent stamp overlap
			if(!this.erasing) {
				for(var i in this.tilesBrush) {
					var tile = this.tilesBrush[i];
					addTiles.push({x:tile.pos.x-this.brushOffset.x+x, y:tile.pos.y-this.brushOffset.y+y, tile:tile.tile});
				}
			} else {
				addTiles.push({x:x, y:y, tile:null});
			}
			this.lastStamp = {x:x, y:y};
		}
	}
	tileroninX.drawTilesSandbox(addTiles, undoGroup, this.selectedLayerIndex);
}

var brushNullTile = new Tile();
var paintTiles = function(pos, undoGroup) {
    //populate paint grid
	var tile = brushNullTile;
	if(!this.erasing) {
		if(this.tilesBrush.length == 0) {
			return;
		}
		tile = this.tilesBrush[0].tile;
	}
	for(var i in pos) {
		for(var k in this.brushMesh) {
			var bPos = this.brushMesh[k];
			this.paintGrid.setTile(tile, bPos.x+pos[i].x, bPos.y+pos[i].y);
		}
	}
	//get addTiles and clear paint grid
	var addTiles = [];
	var newBrush = this.paintGrid.getTiles();
    for(var key in newBrush) {
        var tileH = newBrush[key];
        if(tileH.tile != brushNullTile) {
        	addTiles.push({x:tileH.pos.x, y:tileH.pos.y, tile:tileH.tile});
        } else {
        	addTiles.push({x:tileH.pos.x, y:tileH.pos.y, tile:null});
        }
        this.paintGrid.setTile(null, tileH.pos.x, tileH.pos.y);
    }
	tileroninX.paintTilesSandbox(addTiles, undoGroup, this.selectedLayerIndex);
}

var drawLineLow = function(x0, y0, x1, y1, fn, flip=false) {
	var deltaX = x1-x0;
	var deltaY = y1-y0;
	var deltaErr = Math.abs(deltaY/deltaX);
	var error = 0.0;
	var pixelY = y0;
	for(var pixelX = x0; pixelX <= x1; pixelX++) {
		if(flip) {
			fn(2*x0-pixelX, 2*y0-pixelY);
		} else {
			fn(pixelX, pixelY);
		}
		error += deltaErr;
		while(error >= 0.5) {
			pixelY += Math.sign(deltaY);
			error -= 1.0;
		}
	}
}

var drawLineHigh = function(x0, y0, x1, y1, fn, flip=false) {
	var deltaX = x1-x0;
	var deltaY = y1-y0;
	var deltaErr = Math.abs(deltaX/deltaY);
	var error = 0.0;
	var pixelX = x0;
	for(var pixelY = y0; pixelY <= y1; pixelY++) {
		if(flip) {
			fn(2*x0-pixelX, 2*y0-pixelY);
		} else {
			fn(pixelX, pixelY);
		}
		error += deltaErr;
		while(error >= 0.5) {
			pixelX += Math.sign(deltaX);
			error -= 1.0;
		}
	}
}

var drawLine = function(x0, y0, x1, y1, fn) {
	if(Math.abs(y1-y0) < Math.abs(x1-x0)) {
		if(x1 > x0) {
			drawLineLow(x0, y0, x1, y1, fn);
		} else {
			drawLineLow(x0, y0, 2*x0-x1, 2*y0-y1, fn, true);
		}
	} else {
		if(y1 > y0) {
			drawLineHigh(x0, y0, x1, y1, fn);
		} else {
			drawLineHigh(x0, y0, 2*x0-x1, 2*y0-y1, fn, true);
		}
	}
}

var showCursor = function(x, y) {
	this.drawBrush.style.visibility = 'visible';
	var bounds = this.div.getBoundingClientRect();
	this.drawBrush.style.left = (x-bounds.left-6)+'px';
	this.drawBrush.style.top = (y-bounds.top-6)+'px';
}

var hideCursor = function() {
	this.drawBrush.style.visibility = 'hidden';
}

var bindHotkeys = function() {
	Mousetrap.bind(['command+c', 'ctrl+c'], clipboardCopy.bind(this));
	Mousetrap.bind(['command+shift+c', 'ctrl+shift+c'], clipboardCopyRaw.bind(this));
	Mousetrap.bind(['command+v', 'ctrl+v'], clipboardPaste.bind(this));
	Mousetrap.bind(['command+i', 'ctrl+i'], importTiles.bind(this));
	//Mousetrap.bind(['command+e', 'ctrl+e'], exportTiles.bind(this));

	Mousetrap.bind(['m'], setModeSelect.bind(this));
	Mousetrap.bind(['p'], setModeDraw.bind(this));
	Mousetrap.bind(['b'], setModePaint.bind(this));

	Mousetrap.bind(['w'], selectLayerUp.bind(this));
	Mousetrap.bind(['s'], selectLayerDown.bind(this));
	Mousetrap.bind(['r'], toggleSelectedLayerVisibility.bind(this));

	Mousetrap.bind(['command+-', 'ctrl+-'], zoomIn.bind(this));
	Mousetrap.bind(['command+=', 'ctrl+='], zoomOut.bind(this));

	Mousetrap.bind(['shift+w'], function() {
		var focus = this.layerDisplay.getFocus();
		this.layerDisplay.setFocus(focus.x, focus.y-1);
	}.bind(this));
	Mousetrap.bind(['shift+d'], function() {
		var focus = this.layerDisplay.getFocus();
		this.layerDisplay.setFocus(focus.x+1, focus.y);
	}.bind(this));
	Mousetrap.bind(['shift+s'], function() {
		var focus = this.layerDisplay.getFocus();
		this.layerDisplay.setFocus(focus.x, focus.y+1);
	}.bind(this));
	Mousetrap.bind(['shift+a'], function() {
		var focus = this.layerDisplay.getFocus();
		this.layerDisplay.setFocus(focus.x-1, focus.y);
	}.bind(this));
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
		}
	}.bind(this));
    this.tileGrid.mouseDownSubscribe(function(tilePos, region, event) {
    	this.modeLock = true;
    	var mode = this.iconTray.getSelected();
    	if(event.button == 0) {
    		if(event.altKey) {
				this.tileGrid.setStatePan();
			} else {
				if(mode == 0) { // select
        			if(this.tileGrid.selectionContains(tilePos.x, tilePos.y)) {
						this.tileGrid.setStateMove(tilePos.x, tilePos.y, this.selectedLayerIndex);
					} else {
						this.tileGrid.setStateSelect(tilePos.x, tilePos.y);
					}
        		} else if(mode == 1) { // draw
        			if(event.ctrlKey) {
        				this.tileGrid.setStatePick(tilePos.x, tilePos.y);
        			} else {
		        		showCursor.bind(this)(event.clientX/parseInt(document.body.style.zoom), event.clientY/parseInt(document.body.style.zoom));
		        		this.tileGrid.closeMenu();
		        		this.drawUndoGroup = [];
		        		this.drawing = true;
		        		this.lastStamp = null;
		        		this.erasing = false;
		        		drawTiles.bind(this)([{x:tilePos.x, y:tilePos.y}], this.drawUndoGroup);
		        		this.prevTile = tilePos;
        			}
        		} else if(mode == 2) { // paint
        			if(event.ctrlKey) {
        				this.tileGrid.setStatePick(tilePos.x, tilePos.y);
        			} else {
		        		showCursor.bind(this)(event.clientX/parseInt(document.body.style.zoom), event.clientY/parseInt(document.body.style.zoom));
		        		this.tileGrid.closeMenu();
		        		this.drawUndoGroup = [];
		        		this.drawing = true;
		        		this.erasing = false;
		        		paintTiles.bind(this)([{x:tilePos.x, y:tilePos.y}], this.drawUndoGroup);
		        		this.prevTile = tilePos;
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
			if(mode == 0) { // select
				if(!this.tileGrid.selectionContains(tilePos.x, tilePos.y)) {
					this.tileGrid.setStateSelect(tilePos.x, tilePos.y);
				}
			} else if(mode == 1) { // draw
				if(event.ctrlKey) {
    				this.tileGrid.setStatePick(tilePos.x, tilePos.y);
    			} else {
					showCursor.bind(this)(event.clientX/parseInt(document.body.style.zoom), event.clientY/parseInt(document.body.style.zoom));
	        		this.tileGrid.closeMenu();
	        		this.drawUndoGroup = [];
	        		this.drawing = true;
	        		this.lastStamp = null;
	        		this.erasing = true;
	        		drawTiles.bind(this)([{x:tilePos.x, y:tilePos.y}], this.drawUndoGroup);
	        		this.prevTile = tilePos;
				}
			} else if(mode == 2) { // paint
				if(event.ctrlKey) {
    				this.tileGrid.setStatePick(tilePos.x, tilePos.y);
    			} else {
					showCursor.bind(this)(event.clientX/parseInt(document.body.style.zoom), event.clientY/parseInt(document.body.style.zoom));
	        		this.tileGrid.closeMenu();
	        		this.drawUndoGroup = [];
	        		this.drawing = true;
	        		this.erasing = true;
	        		paintTiles.bind(this)([{x:tilePos.x, y:tilePos.y}], this.drawUndoGroup);
	        		this.prevTile = tilePos;
				}
			}
		}
	}.bind(this));
	this.tileGrid.mouseMoveSubscribe(function(tilePos, event) {
		if(this.drawing) {
			var mode = this.iconTray.getSelected();
			if(mode == 1) {
				if(this.prevTile.x != tilePos.x || this.prevTile.y != tilePos.y) {
					var pos = [];
					drawLine(this.prevTile.x, this.prevTile.y, tilePos.x, tilePos.y, function(x, y) {
						pos.push({x, y});
					}.bind(this));
					drawTiles.bind(this)(pos, this.drawUndoGroup);
					this.prevTile = tilePos;
				}
				showCursor.bind(this)(event.clientX/parseInt(document.body.style.zoom), event.clientY/parseInt(document.body.style.zoom));
			} else if(mode == 2) {
				if(this.prevTile.x != tilePos.x || this.prevTile.y != tilePos.y) {
					var pos = [];
					drawLine(this.prevTile.x, this.prevTile.y, tilePos.x, tilePos.y, function(x, y) {
						pos.push({x, y});
					}.bind(this));
					paintTiles.bind(this)(pos, this.drawUndoGroup);
					this.prevTile = tilePos;
				}
				showCursor.bind(this)(event.clientX/parseInt(document.body.style.zoom), event.clientY/parseInt(document.body.style.zoom));
			}
		}
	}.bind(this));
	this.tileGrid.mouseUpSubscribe(function(tilePos, event, state) {
		this.modeLock = false;
		if(state == 6) {
			var mode = this.iconTray.getSelected();
			var pickedTile = tileroninX.getTileSandbox(tilePos.x, tilePos.y, this.selectedLayerIndex);
			if(mode == 2 && pickedTile != null) {
				var rel = pickedTile.getRelations();
				for(var ri in rel) {
					var r = rel[ri];
					if(r.r instanceof TileRelationBlobBorder && r.r.isBorder) {
						pickedTile = r.t;
						break
					}
					if(r.r instanceof TileRelationWangBorder && r.r.isBorder) {
						var indexMatrix = r.r.getIndexMatrix();
						var tileIndex = 0;
						if(tilePos.fineX > 0.5) {
							tileIndex = 1;
						}
						if(tilePos.fineY > 0.5) {
							tileIndex = 3-tileIndex;
						}
						pickedTile = indexMatrix[tileIndex];
						if(pickedTile == false) {
							pickedTile = null;
						}
					}
				}
			}
			this.tilePickedCallback.notify(pickedTile);
		} else {
			var mode = this.iconTray.getSelected();
			if(mode == 0) { // select
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
					var positions = this.tileGrid.getSelected();
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
				    var x = Math.floor((lowX+highX)/2);
				    var y = Math.floor((lowY+highY)/2);
					this.layerDisplay.setFocus(x, y);
				}
			} else if(mode == 1 || mode == 2) { // draw & paint
				if(this.drawing) {
					this.drawing = false;
					tileroninX.saveUndoState(this.drawUndoGroup);
					hideCursor.bind(this)();
					this.layerDisplay.setFocus(tilePos.x, tilePos.y);
				}
			}
		}
	}.bind(this));
	this.tileGrid.mouseWheelSubscribe(function(tilePos, deltaZoom, ctrl) {
		if(ctrl) {
			var mode = this.iconTray.getSelected();
			if(mode != 2) {
				return;
			}
			this.brushStateDelta += deltaZoom*0.1;
			if(this.brushStateDelta > 1) {
				this.brushStateDelta = 0.5;
				this.brushSizeSelector.offset(-1);
			}
			if(this.brushStateDelta < 0) {
				this.brushStateDelta = 0.5;
				this.brushSizeSelector.offset(+1);
			}
		} else {
			this.tileGrid.zoom(tilePos, deltaZoom);
		}
	}.bind(this));
	this.tileGrid.tilesMovedSubscribe(function(positions, ox, oy) {
		var undoGroup = [];
		tileroninX.moveTilesSandbox(positions, ox, oy, undoGroup, this.selectedLayerIndex);
		tileroninX.saveUndoState(undoGroup);
	}.bind(this));
	this.tileGrid.selectionSizeChangedSubscribe(function() {
		updateSelectionInfo.bind(this)();
	}.bind(this));
	this.div.appendChild(this.tileGrid.getDiv());
	updateSelectionInfo.bind(this)();
	if(reload) {
		this.tileGrid.removeLayer(0);
		var layersSb = tileroninX.getLayersSandbox();
		for(var z = 0; z < layersSb.length; z++) {
			this.tileGrid.addLayer(z, layersSb[z].visible);
		}
		tileroninX.syncSandboxTileGridView(this.tileGrid);
		updateMenuOptions.bind(this)();
	}
}

var zoomIn = function() {
	this.tileGrid.zoom(this.tileGrid.getSelectionPoint(), 200);
}

var zoomOut = function() {
	this.tileGrid.zoom(this.tileGrid.getSelectionPoint(), -200);
}

var getBrushMesh = function(size) {
	var o = size/2.0;
	var bo = Math.floor((size-1)/2.0);
	var mesh = [];
	var t = size/2.0;
	if(size == 3) {
		t = size/2.0-0.25;
	}
	for(var x = 0; x < size; x++) {
		for(var y = 0; y < size; y++) {
			var tx = x+0.5;
			var ty = y+0.5;
			var dx = tx-o;
			var dy = ty-o;
			var d = Math.sqrt(dx*dx+dy*dy);
			if(d < t) {
				mesh.push({x:x-bo, y:y-bo})
			}
		}
	}
	return mesh;
}

var setMode = function(index) {
	this.iconTray.setSelected(index);
	if(index == 0) {
		this.trayDiv.style.visibility = 'hidden';
	} if(index == 1) {
		this.trayDiv.style.visibility = 'hidden';
	} else if(index == 2) {
		this.trayDiv.style.visibility = 'visible';
	}
}

var setModeSelect = function() {
	if(!this.modeLock) {
		setMode.bind(this)(0);
	}
}

var setModeDraw = function() {
	if(!this.modeLock) {
		setMode.bind(this)(1);
	}
}

var setModePaint = function() {
	if(!this.modeLock) {
		setMode.bind(this)(2);
	}
}

var updateSelectionInfo = function() {
	var size = this.tileGrid.getSelectionSize();
	this.infoText.innerHTML = size.x+" "+"x"+" "+size.y;
}

var previewLayer = function(i) {
	var layers = tileroninX.getLayersSandbox();
	for(var j = 0; j < layers.length; j++) {
		if(i == j) {
			this.tileGrid.setLayerVisibility(j, true);
		} else {
			this.tileGrid.setLayerVisibility(j, false);
		}
	}
}

var selectLayer = function(i) {
	this.selectedLayerIndex = i;
	var layerDivs = this.layerContainer.children;
	for(var k = 0; k < layerDivs.length; k++) {
		var ld = layerDivs[layerDivs.length-1-k];
		var lContent = ld.children[1];
		if(k != this.selectedLayerIndex) {
			lContent.style.background = "var(--colorBG)";
			ld.style.borderColor = "var(--rtInset)";
			lContent.style.borderColor = "var(--colorSteel)";
		} else {
			lContent.style.background = "var(--color1)";
			ld.style.borderColor = "#c32e2e";
			lContent.style.borderColor = "#c32e2e";
		}
	}
	this.layerDisplay.selectLayer(i);

	previewLayer.bind(this)(i);
	if(this.layerPreviewTimeout != null) {
		clearTimeout(this.layerPreviewTimeout);
		this.layerPreviewTimeout = null;
	}
	var layers = tileroninX.getLayersSandbox();
	this.layerPreviewTimeout = setTimeout(function() {
		for(var j = 0; j < layers.length; j++) {
			this.tileGrid.setLayerVisibility(j, layers[j].visible);
		}
		this.layerPreviewTimeout = null;
	}.bind(this), 100);
}

var selectLayerUp = function() {
	var layers = tileroninX.getLayersSandbox();
	if(this.selectedLayerIndex < layers.length-1) {
		selectLayer.bind(this)(this.selectedLayerIndex+1);
	}
}

var selectLayerDown = function() {
	if(this.selectedLayerIndex > 0) {
		selectLayer.bind(this)(this.selectedLayerIndex-1);
	}
}

var toggleSelectedLayerVisibility = function() {
	var layer = tileroninX.getLayersSandbox()[this.selectedLayerIndex];
	var undoGroup = [];
	tileroninX.editLayerSandbox(this.selectedLayerIndex, !layer.visible, null, undoGroup);
	tileroninX.saveUndoState(undoGroup);
}

var organizeLayers = function() {
	this.layerContainer.innerHTML = '';

	var layers = this.displayLayers.getLayers();
	for(var i = layers.length-1; i >= 0; i--) {
		layers[i][0] = i;
		this.layerContainer.appendChild(layers[i][1]);
		if(layers.length == 1) {
			layers[i][2].disableIcon(1);
		} else {
			layers[i][2].enableIcon(1);
		}
	}
}

var addLayer = function(z) {
	var layers = tileroninX.getLayersSandbox();
	var layer = layers[z];
	this.tileGrid.addLayer(z, layer.visible);

	var lObj = [z];

	var layerDiv = document.createElement('div');
	layerDiv.className = 'sandboxview-layer-view';

	var layerDrag = document.createElement('div');
	layerDrag.className = 'sandboxview-layer-drag-view';
	layerDiv.appendChild(layerDrag);
	var layerDivHeight = 80;
	var dragY = 0;
	var layerIndex = 0;
	plh.applyPointerLock(layerDrag, 	
	function(cx, cy) {

		dragY = cy;
		layerIndex = 0;

		this.layerContainer.style.height = this.layerContainer.offsetHeight+"px";
		var layerDivs = this.layerContainer.children;
		for(var k = 0; k < layerDivs.length; k++) {
			var ld = layerDivs[k];
			ld.style.top = ld.offsetTop+"px";
		}
		for(var k = 0; k < layerDivs.length; k++) {
			var ld = layerDivs[k];
			ld.style.width = ld.offsetWidth+"px";
			ld.style.marginTop = '0px';
			ld.style.position = 'absolute';
			if(ld != layerDiv) {
				ld.style.transition = "top 0.2s cubic-bezier(0.19, 1, 0.22, 1)";
			}
		}
		layerDiv.style.zIndex = '3';

	}.bind(this), 
	function(cx, cy) {

		var currentTop = parseInt(layerDiv.style.top.replace(/px/g, ""));
		currentTop += (cy-dragY);
		if(currentTop < 0) {
			currentTop = 0;
		} else if(currentTop > (layers.length-1)*layerDivHeight) {
			currentTop = (layers.length-1)*layerDivHeight;
		}
		layerDiv.style.top = currentTop+'px';

		dragY = cy;

		var layerIndexOffset;
		if((currentTop-(layerIndex+layers.length-1-lObj[0])*layerDivHeight) > 0) {
			layerIndexOffset = Math.floor((currentTop-(layerIndex+layers.length-1-lObj[0])*layerDivHeight)/layerDivHeight);
		} else {
			layerIndexOffset = Math.ceil((currentTop-(layerIndex+layers.length-1-lObj[0])*layerDivHeight)/layerDivHeight);
		}
		layerIndex += layerIndexOffset;

		var layerDivs = this.layerContainer.children;
		for(var k = 0; k < layerDivs.length; k++) {
			var ld = layerDivs[k];
			if(ld == layerDiv) {
				continue;
			}
			var offset = 0;
			if(k < (layers.length-1-lObj[0]) && k >= layerIndex+layers.length-1-lObj[0]) {
				offset = 1;
			} else if(k > (layers.length-1-lObj[0]) && k <= layerIndex+layers.length-1-lObj[0]) {
				offset = -1;
			}
			ld.style.top = ((k+offset)*layerDivHeight)+'px';
		}
	}.bind(this), 
	function() {

		this.layerContainer.style.height = 'auto';
		var layerDivs = this.layerContainer.children;
		for(var k = 0; k < layerDivs.length; k++) {
			var ld = layerDivs[k];
			ld.style.top = 'auto';
			ld.style.width = 'auto';
			ld.style.marginTop = '8px';
			ld.style.position = 'static';
			ld.style.transition = "none";
		}
		layerDiv.style.zIndex = 'auto';

		var undoGroup = [];
		tileroninX.reorderLayerSandbox(lObj[0], lObj[0]-layerIndex, undoGroup);
		tileroninX.saveUndoState(undoGroup);

	}.bind(this));

	var layerContent = document.createElement('div');
	layerContent.className = 'sandboxview-layer-content-view';
	layerDiv.appendChild(layerContent);
	var toBeSelectedLayer;
	var dragYSelect;
	plh.applyPointerLock(layerContent, function(cx, cy) {
		plh.lockPointer();

		toBeSelectedLayer = lObj[0];
		dragYSelect = cy;
		previewLayer.bind(this)(toBeSelectedLayer);

		layerContent.style.borderColor = "var(--color2)";
	}.bind(this), function(cx, cy) {
		var layers = this.displayLayers.getLayers();
		var dragMovement = cy-dragYSelect;
		var thresholdRadius = 20;
		if(dragMovement > thresholdRadius) {
			dragYSelect += thresholdRadius*2;
			if(toBeSelectedLayer > 0) {
				toBeSelectedLayer--;
				previewLayer.bind(this)(toBeSelectedLayer);
			}
		} else if(dragMovement <= -thresholdRadius) {
			dragYSelect -= thresholdRadius*2;
			if(toBeSelectedLayer < layers.length-1) {
				toBeSelectedLayer++;
				previewLayer.bind(this)(toBeSelectedLayer);
			}
		}

		for(var k = 0; k < layers.length; k++) {
			var lRow = layers[k][1];
			var lContent = layers[k][4];
			if(k == toBeSelectedLayer) {
				lRow.style.borderColor = "#c32e2e";
				lContent.style.borderColor = "#c32e2e";
			} else {
				lRow.style.borderColor = "var(--rtInset)";
				lContent.style.borderColor = "var(--colorSteel)";
			}
		}
	}.bind(this), function() {
		selectLayer.bind(this)(toBeSelectedLayer);
	}.bind(this));

	layerIcons = new IconTrayView([	["./../res/icon/ui_icon_b21.png", "./../res/icon/ui_icon_a21.png"],
									["./../res/icon/ui_icon_b23.png", "./../res/icon/ui_icon_a23.png"]],
									["Hide/View Layer",
									"Delete Layer"]);
	if(!layer.visible) {
		layerIcons.setIconImage(0, "./../res/icon/ui_icon_b22.png", "./../res/icon/ui_icon_a22.png");
	}
	layerIcons.getDiv().style.top = "-4px";
	layerContent.appendChild(layerIcons.getDiv());
	layerIcons.iconClickedSubscribe(function(index, shift) {
		if(index == 0) {
			var undoGroup = [];
			tileroninX.editLayerSandbox(lObj[0], !layer.visible, null, undoGroup);
			tileroninX.saveUndoState(undoGroup);
		} else if(index == 1) {
			var undoGroup = [];
			tileroninX.removeLayerSandbox(lObj[0], undoGroup);
			this.tooltipCallback.notify(null);
			tileroninX.saveUndoState(undoGroup);
		}
	}.bind(this));
	layerIcons.tooltipSubscribe(function(msg) {
		this.tooltipCallback.notify(msg);
	}.bind(this));

	var layerNameTray = document.createElement('div');
	layerNameTray.className = "sandboxview-tray-view";
	layerNameTray.style.zIndex = 2147483647;
	layerNameTray.style.top = "-4px";
	layerContent.appendChild(layerNameTray);

	var layerName = new PropertyEditTextView("Name", layer.name, "", false);
	layerName.getDiv().children[1].style.width = "100px";
	layerNameTray.style.left = '36px';
	layerNameTray.appendChild(layerName.getDiv());
	layerName.valueChangedSubscribe(function(value) {
		if(value === '') {
			layerName.setValue(layer.name);
		} else {
			var undoGroup = [];
			tileroninX.editLayerSandbox(lObj[0], null, value, undoGroup);
			tileroninX.saveUndoState(undoGroup);
		}
	}.bind(this));

	lObj.push(layerDiv);
	lObj.push(layerIcons);
	lObj.push(layerName);
	lObj.push(layerContent);
	this.displayLayers.insertLayer(lObj, z);
	organizeLayers.bind(this)();
	selectLayer.bind(this)(z);
}

var removeLayer = function(z) {
	this.tileGrid.removeLayer(z);

	this.displayLayers.removeLayer(z);
	organizeLayers.bind(this)();
	if(z < this.selectedLayerIndex) {
		this.selectedLayerIndex--;
	} else if(z == this.selectedLayerIndex) {
		selectLayer.bind(this)(Math.max(0, this.selectedLayerIndex-1));
	}
}

var reorderLayer = function(z, newZ) {
	this.tileGrid.reorderLayer(z, newZ);

	this.displayLayers.reorderLayer(z, newZ);
	organizeLayers.bind(this)();
	if(this.selectedLayerIndex == z) {
		this.selectedLayerIndex = newZ;
	} else if(this.selectedLayerIndex > z && this.selectedLayerIndex <= newZ) {
		this.selectedLayerIndex--;
	} else if(this.selectedLayerIndex < z && this.selectedLayerIndex >= newZ) {
		this.selectedLayerIndex++;
	}
	selectLayer.bind(this)(this.selectedLayerIndex);
}

var updateLayer = function(z) {
	var layer = tileroninX.getLayersSandbox()[z];
	this.tileGrid.setLayerVisibility(z, layer.visible);
	if(layer.visible) {
		this.displayLayers.getLayer(z)[2].setIconImage(0, "./../res/icon/ui_icon_b21.png", "./../res/icon/ui_icon_a21.png");
	} else {
		this.displayLayers.getLayer(z)[2].setIconImage(0, "./../res/icon/ui_icon_b22.png", "./../res/icon/ui_icon_a22.png");
	}
	this.displayLayers.getLayer(z)[3].setValue(layer.name);
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

class SandboxView {
	constructor() {
		this.div = document.createElement('div');
		this.div.style.position = "absolute";
		this.div.style.top = '0';
		this.div.style.bottom = '0';
        this.div.style.left = '0';
        this.div.style.right = '0';
        this.div.style.overflow = "hidden";

        this.tilePickedCallback = new CallbackManager();
        this.tooltipCallback = new CallbackManager();

        this.formatsWatcher = null;
        this.formatsDirectory = null;
        this.exportFormatsOrthographic = {};
        this.exportFormatsIsometric = {};

        this.div.tabIndex = "1";
        this.div.addEventListener('mousedown', function(event) {
			bindHotkeys.bind(this)();
		}.bind(this));
		this.div.addEventListener('keydown', function(event) {
			if(event.keyCode == 46 || event.keyCode == 8) {
				var selectedTiles = this.tileGrid.getSelected();
				var addTiles = [];
				for(var i in selectedTiles) {
					var pos = selectedTiles[i];
					addTiles.push({x:pos.x, y:pos.y, z:this.selectedLayerIndex, tile:null});
				}
				var undoGroup = [];
				tileroninX.setTilesSandbox(addTiles, undoGroup);
				tileroninX.saveUndoState(undoGroup);
			}
		}.bind(this), false);

		bindHotkeys.bind(this)();

        this.tilesBrush = [];
        this.brushOffset = {x:0, y:0};
        this.brushDimensions = {x:0, y:0};
        this.erasing = false;
        this.prevTile = {x:0, y:0};
        this.drawing = false;
        this.lastStamp = null;
        this.brushMesh = getBrushMesh(1);
        this.paintGrid = new TileGrid();
        this.modeLock = false;
        this.drawUndoGroup = [];
        this.brushStateDelta = 0;

        this._lastWorkspaceCameraSnapGen = 0;

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
        this.tileGrid.removeLayer(0);

		tileroninX.tileSizeChangedSubscribe(function(size) {
			this.tileGrid.setTileSize(size);
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
		}.bind(this))

		this.iconTray = new IconTraySelectView([	["./../res/icon/ui_icon_b0.png", "./../res/icon/ui_icon_a0.png"],
													["./../res/icon/ui_icon_b1.png", "./../res/icon/ui_icon_a1.png"],
													["./../res/icon/ui_icon_b15.png", "./../res/icon/ui_icon_a15.png"]], 0,
													["Select",
													"Draw",
													"Paint (Auto-tile)"]);
		this.div.appendChild(this.iconTray.getDiv());

		this.trayDiv = document.createElement('div');
		this.trayDiv.className = "sandboxview-tray-view";
		this.trayDiv.style.zIndex = 2147483647;
		this.trayDiv.style.visibility = 'hidden';

		this.iconTray.iconSelectedSubscribe(function(index, shift) {
			setMode.bind(this)(index);
		}.bind(this));
		this.iconTray.tooltipSubscribe(function(msg) {
			this.tooltipCallback.notify(msg);
		}.bind(this));

		var maxBrushSize = 8;
		this.brushSizeSelector = new PropertyEditTextView("Brush Size", 1, "tl", true, 1, maxBrushSize);
		this.brushSizeSelector.valueChangedSubscribe(function(value) {
			var brushSize = Math.min(Math.max(1, value), maxBrushSize);
			this.brushMesh = getBrushMesh(brushSize);
			this.brushSizeSelector.setValue(brushSize);
		}.bind(this));
		this.trayDiv.appendChild(this.brushSizeSelector.getDiv());

		requestAnimationFrame(function() {
			this.trayDiv.style.left = (this.iconTray.getDiv().offsetWidth+16)+'px';
			this.div.appendChild(this.trayDiv);

			this.newMenuPos = {x:this.iconTray.getDiv().offsetWidth+16, y:this.trayDiv.offsetHeight-4};
		}.bind(this));

		tileroninX.tileChangedSandboxSubscribe(function(x, y, z) {
			var tile = tileroninX.getTileSandbox(x, y, z);
			this.tileGrid.setTile(tile, x, y, z);
		}.bind(this));

		this.drawBrush = document.createElement('div');
		this.drawBrush.className = "sandboxview-brush-view";
		this.drawBrush.style.zIndex = 2147483647;
		this.div.appendChild(this.drawBrush);

		this.rememberedExport = null;

		tileroninX.onNewSubscribe(function() {
			this.tileGrid.setZoom(1);
			var tileShape = tileroninX.getTileShape();
			if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
				this.tileGrid.setCamera(0, 0);
			} else if(tileShape == tileroninX.Shape.ISOMETRIC) {
				this.tileGrid.setCamera(tileroninX.getTileSize()[0]/2.0, 0);
			}
			this.rememberedExport = null;
		}.bind(this));

		tileroninX.onSaveSubscribe(function(extra) {
			var camera = this.tileGrid.getCamera();
			var zoom = this.tileGrid.getZoom();
			extra.sandbox = {	camX:camera.x,
								camY:camera.y,
								camZoom:zoom};
		}.bind(this));

		tileroninX.onLoadSubscribe(function(data) {
			var loadFunc = {'0.1.0-beta.0':loadExtra_1,
	                        '0.1.0-beta.1':loadExtra_1,
	                        '0.1.0-beta.2':loadExtra_1,
	                        '0.1.0-beta.3':loadExtra_1,
	                        '0.1.0-beta.4':loadExtra_1,
	                        '0.1.0-beta.5-lite':loadExtra_1,
	                        '0.1.0-beta.5-pro':loadExtra_1,
	                        '0.1.0-beta.6-lite':loadExtra_1,
	                        '0.1.0-beta.6-pro':loadExtra_2,
	                        '0.1.0-beta.7-lite':loadExtra_1,
	                        '0.1.0-beta.7-pro':loadExtra_2,
	                        '1.0.0-lite':loadExtra_1,
	                        '1.0.0-pro':loadExtra_2,
	                        '1.0.1-dev.0-lite':loadExtra_1,
	                        '1.0.1-dev.0-pro':loadExtra_2,
	                        '1.0.1-lite':loadExtra_1,
	                        '1.0.1-pro':loadExtra_2,
	                        '1.0.2-dev.0-lite':loadExtra_1,
	                        '1.0.2-dev.0-pro':loadExtra_2,
	                        '1.0.2-lite':loadExtra_1,
	                        '1.0.2-pro':loadExtra_2,
	                        '2.0.0-dev.0-lite':loadExtra_1,
	                        '2.0.0-dev.0-pro':loadExtra_2,
	                        '2.0.0-dev.1-lite':loadExtra_1,
	                        '2.0.0-dev.1-pro':loadExtra_2,
	                        '2.0.0-dev.2-lite':loadExtra_1,
	                        '2.0.0-dev.2-pro':loadExtra_2,
	                        '2.0.0-dev.3-lite':loadExtra_1,
	                        '2.0.0-dev.3-pro':loadExtra_2,
	                        '2.0.0-dev.4-lite':loadExtra_1,
	                        '2.0.0-dev.4-pro':loadExtra_2,
	                        '2.0.0-lite':loadExtra_1,
	                        '2.0.0-pro':loadExtra_2,
	                        '2.1.0-dev.0-lite':loadExtra_1,
	                        '2.1.0-dev.0-pro':loadExtra_2,
	                        '2.1.0-lite':loadExtra_1,
	                        '2.1.0-pro':loadExtra_2};
	        var loadFn = loadFunc[data.version];
	        this.rememberedExport = null;
            if(loadFn == null) {
                return;
            }
            loadFn.bind(this)(data);
		}.bind(this));

		var loadExtra_1 = function(data) {
			//do nothing
		}

		var loadExtra_2 = function(data) {
			this.tileGrid.setZoom(data.extra.sandbox.camZoom);
			this.tileGrid.setCamera(data.extra.sandbox.camX, data.extra.sandbox.camY);
		}

		//-----LAYER DIV-----
		//-----LAYER DIV-----
		//-----LAYER DIV-----

		this.layerDiv = document.createElement('div');
		this.layerDiv.className = "sandboxview-layerproperties-view";

		this.layerDisplay = new LayerDisplayView();
		this.layerDiv.appendChild(this.layerDisplay.getDiv());

		var layerAddDiv = document.createElement('div');
		this.layerAddDiv = layerAddDiv;
		layerAddDiv.className = 'sandboxview-layer-add-view sandboxview-layer-add-view--in-title';
		layerAddDiv.addEventListener("mouseover", function(event) {
			this.tooltipCallback.notify("Create Layer");
		}.bind(this), false);
		layerAddDiv.addEventListener("mouseout", function(event) {
			this.tooltipCallback.notify(null);
		}.bind(this), false);

		var layerAddIconDiv = document.createElement('div');
		layerAddIconDiv.className = 'sandboxview-layer-add-icon-view';
		layerAddIconDiv.style.backgroundImage = "url('../res/icon/ui_icon_b24.png')";
		layerAddDiv.appendChild(layerAddIconDiv);

		plh.applyPointerLock(layerAddDiv, function() {
			plh.lockPointer();
			layerAddDiv.style.background = "var(--color2)";
			layerAddIconDiv.style.backgroundImage = "url('../res/icon/ui_icon_a24.png')";
		}.bind(this), null, function() {
			layerAddDiv.style.background = "var(--color1)";
			layerAddIconDiv.style.backgroundImage = "url('../res/icon/ui_icon_b24.png')";
			var undoGroup = [];
			tileroninX.addLayerSandbox(undoGroup);
			tileroninX.saveUndoState(undoGroup);
		}.bind(this));

		this.layerContainer = document.createElement('div');
		this.layerContainer.className = 'sandboxview-layerproperties-container-view';
		this.layerDiv.appendChild(this.layerContainer);

		this.displayLayers = new LayerList();
        this.selectedLayerIndex = null;
        this.layerPreviewTimeout = null;
        
        addLayer.bind(this)(0);

		tileroninX.layerAddedSandboxSubscribe(function(z) {
			addLayer.bind(this)(z);
		}.bind(this));
		tileroninX.layerRemovedSandboxSubscribe(function(z) {
			removeLayer.bind(this)(z);
		}.bind(this));
		tileroninX.layersReorderedSandboxSubscribe(function(z, newZ) {
			reorderLayer.bind(this)(z, newZ);
		}.bind(this));
		tileroninX.layerChangedSandboxSubscribe(function(z) {
			updateLayer.bind(this)(z);
		}.bind(this));
	}

	getDiv() {
		return this.div;
	}

	getLayerDiv() {
		return this.layerDiv;
	}

	getLayerAddButton() {
		return this.layerAddDiv;
	}

	setTilesBrush(tiles) {
		this.tilesBrush = tiles;
		var minX, minY, maxX, maxY;
        for(var i = 0; i < tiles.length; i++) {
            if(tiles[i].pos.x < minX || i==0) {
                minX = tiles[i].pos.x;
            }
            if(tiles[i].pos.x > maxX || i==0) {
                maxX = tiles[i].pos.x;
            }
            if(tiles[i].pos.y < minY || i==0) {
                minY = tiles[i].pos.y;
            }
            if(tiles[i].pos.y > maxY || i==0) {
                maxY = tiles[i].pos.y;
            }
        }
        this.brushOffset = {x:Math.floor((minX+maxX)/2), y:Math.floor((minY+maxY)/2)};
        this.brushDimensions = {x:maxX-minX+1, y:maxY-minY+1};
	}

	tilePickedSubscribe(func) {
		this.tilePickedCallback.subscribe(func);
	}

	tooltipSubscribe(func) {
		this.tooltipCallback.subscribe(func);
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
module.exports = SandboxView;
