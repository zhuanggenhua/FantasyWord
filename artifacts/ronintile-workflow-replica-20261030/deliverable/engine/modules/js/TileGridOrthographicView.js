var plh = require('./PointerLockHandler.js');
var Selection = require('./Selection.js');
var SelectionGroup = require('./SelectionGroup.js');
var CallbackManager = require('./CallbackManager.js');
var ExpandingMenuView = require('./ExpandingMenuView.js');
var ErrorDisplayView = require('./ErrorDisplayView.js');

var LayerList = require('./LayerList.js');

var getUiZoomScale = function() {
	var raw = (typeof document !== 'undefined' && document.body && document.body.style) ? document.body.style.zoom : '';
	var z = parseFloat(raw);
	return Number.isFinite(z) && z > 0 ? z : 1;
};

var translateCamera = function(x, y) {
	this.camera.x += x;
	this.camera.y += y;
	this.camera.x = Math.round(this.camera.x);
	this.camera.y = Math.round(this.camera.y);
	//update visual（相机整数化，与瓦片块及背景网格对齐）
	this.div.style.backgroundPosition = (this.camera.x+'px ')+(this.camera.y+'px ');
	//translate content
	var selDivs = this.selectionDiv.childNodes;
	for(var i = 0; i < selDivs.length; i++) {
		var selDiv = selDivs.item(i);
		selDiv.style.left = (x+ +(selDiv.style.left.replace(/px/g, "")))+'px';
		selDiv.style.top = (y+ +(selDiv.style.top.replace(/px/g, "")))+'px';
	}
	var regionDivs = this.regionsDiv.childNodes;
	for(var i = 0; i < regionDivs.length; i++) {
		var regionDiv = regionDivs.item(i);
		regionDiv.style.left = (x+ +(regionDiv.style.left.replace(/px/g, "")))+'px';
		regionDiv.style.top = (y+ +(regionDiv.style.top.replace(/px/g, "")))+'px';
	}
	var tileDivs = this.tilesDiv.childNodes;
	for(var i = 0; i < tileDivs.length; i++) {
		var tileDiv = tileDivs.item(i);
		tileDiv.style.left = (x+ +(tileDiv.style.left.replace(/px/g, "")))+'px';
		tileDiv.style.top = (y+ +(tileDiv.style.top.replace(/px/g, "")))+'px';
	}
	if(this.menu != null) {
		this.menuX += x;
		this.menuY += y;
		this.menuPaddingH.style.width = Math.max(0, this.menuX+4)+'px';
		this.menuPaddingV.style.height = Math.max(0, this.menuY+4)+'px';
	}
	var errorDiv = this.errorDisplay.getDiv();
	errorDiv.style.left = (x+ +(errorDiv.style.left.replace(/px/g, "")))+'px';
	errorDiv.style.top = (y+ +(errorDiv.style.top.replace(/px/g, "")))+'px';
}

var setSelectionBoundaries = function(x0, y0, x1, y1) {
	this.selectionBoundaries.setSelection(x0, y0, x1, y1);
	//update visual
	var selNrm = this.selectionBoundaries.getSelectionNormalized();
	var borderRadius = 4;
	var s = getZoomedTileSize.bind(this)();
	this.selectionBoundsDiv.style.left = (Math.round(this.camera.x + s * selNrm.x0 - borderRadius)) + 'px';
	this.selectionBoundsDiv.style.top = (Math.round(this.camera.y + s * selNrm.y0 - borderRadius)) + 'px';
	this.selectionBoundsDiv.style.width = (s * (selNrm.x1 + 1 - selNrm.x0)) + 'px';
	this.selectionBoundsDiv.style.height = (s * (selNrm.y1 + 1 - selNrm.y0)) + 'px';
	this.selectionBoundsDiv.style.visibility = "visible";
}

var translateSelection = function(x, y) {
	//update visual
	var selDivs = this.selectionDiv.childNodes;
	for(var i = 0; i < selDivs.length; i++) {
		var selDiv = selDivs.item(i);
		selDiv.style.left = ((getZoomedTileSize.bind(this)()*x)+ +(selDiv.style.left.replace(/px/g, "")))+'px';
		selDiv.style.top = ((getZoomedTileSize.bind(this)()*y)+ +(selDiv.style.top.replace(/px/g, "")))+'px';
	}
	this.selectionCanvas.style.left = ((getZoomedTileSize.bind(this)()*x)+ +(this.selectionCanvas.style.left.replace(/px/g, "")))+'px';
	this.selectionCanvas.style.top = ((getZoomedTileSize.bind(this)()*y)+ +(this.selectionCanvas.style.top.replace(/px/g, "")))+'px';
}

var translateRegion = function(x, y) {
	//update visual
	var selDivs = this.selectionDiv.childNodes;
	for(var i = 0; i < selDivs.length; i++) {
		var selDiv = selDivs.item(i);
		selDiv.style.left = ((getZoomedTileSize.bind(this)()*x)+ +(selDiv.style.left.replace(/px/g, "")))+'px';
		selDiv.style.top = ((getZoomedTileSize.bind(this)()*y)+ +(selDiv.style.top.replace(/px/g, "")))+'px';
	}
	for(var i = 0; i < this.regions.length; i++) {
		if(this.regions[i].region == this.movingRegion) {
			var regionDiv = this.regions[i].div;
			regionDiv.style.left = ((getZoomedTileSize.bind(this)()*x)+ +(regionDiv.style.left.replace(/px/g, "")))+'px';
			regionDiv.style.top = ((getZoomedTileSize.bind(this)()*y)+ +(regionDiv.style.top.replace(/px/g, "")))+'px';
		}
	}
	this.selectionCanvas.style.left = ((getZoomedTileSize.bind(this)()*x)+ +(this.selectionCanvas.style.left.replace(/px/g, "")))+'px';
	this.selectionCanvas.style.top = ((getZoomedTileSize.bind(this)()*y)+ +(this.selectionCanvas.style.top.replace(/px/g, "")))+'px';
}

var buildSelections = function() {
	this.selectionDiv.innerHTML = '';

	var selections = this.selection.getSelections();

	var buildSelBorder = function(x0, y0, x1, y1, side) {
		if(x0 == x1 && y0 == y1) {
			return;
		}
		if(x1 < x0 || y1 < y0) {
			return;
		}
		for(var i = 0; i < selections.length; i++) {
			var sel = selections[i];
			if(side == 0) {
				//left border
				if(sel.x0 < x0 && sel.x1+1 >= x1) {
					if(sel.y0 < y1 && sel.y1+1 > y0) {
						buildSelBorder.bind(this)(x0, y0, x1, sel.y0, side);
						buildSelBorder.bind(this)(x0, sel.y1+1, x1, y1, side);
						return;
					}
				}
			} else if(side == 1) {
				//right border
				if(sel.x0 <= x0 && sel.x1+1 > x1) {
					if(sel.y0 < y1 && sel.y1+1 > y0) {
						buildSelBorder.bind(this)(x0, y0, x1, sel.y0, side);
						buildSelBorder.bind(this)(x0, sel.y1+1, x1, y1, side);
						return;
					}
				}
			} else if(side == 2) {
				//top border
				if(sel.y0 < y0 && sel.y1+1 >= y1) {
					if(sel.x0 < x1 && sel.x1+1 > x0) {
						buildSelBorder.bind(this)(x0, y0, sel.x0, y1, side);
						buildSelBorder.bind(this)(sel.x1+1, y0, x1, y1, side);
						return;
					}
				}
			} else if(side == 3) {
				//down border
				if(sel.y0 <= y0 && sel.y1+1 > y1) {
					if(sel.x0 < x1 && sel.x1+1 > x0) {
						buildSelBorder.bind(this)(x0, y0, sel.x0, y1, side);
						buildSelBorder.bind(this)(sel.x1+1, y0, x1, y1, side);
						return;
					}
				}
			}
		}
		//build
		var borderRadius = 2;
		var s = getZoomedTileSize.bind(this)();
		var selBorder = document.createElement('div');
		selBorder.className = 'tilegrid-selection-view';
		selBorder.style.left = (Math.round(this.camera.x + s * x0 - borderRadius)) + 'px';
		selBorder.style.top = (Math.round(this.camera.y + s * y0 - borderRadius)) + 'px';
		selBorder.style.width = (s * (x1 - x0) + borderRadius * 2) + 'px';
		selBorder.style.height = (s * (y1 - y0) + borderRadius * 2) + 'px';
		this.selectionDiv.appendChild(selBorder);
	}

	for(var i = 0; i < selections.length; i++) {
		var sel = selections[i];
		buildSelBorder.bind(this)(sel.x0+this.moveOffset.x+0, sel.y0+this.moveOffset.y+0, sel.x1+this.moveOffset.x+1, sel.y0+this.moveOffset.y+0, 2);
		buildSelBorder.bind(this)(sel.x1+this.moveOffset.x+1, sel.y0+this.moveOffset.y+0, sel.x1+this.moveOffset.x+1, sel.y1+this.moveOffset.y+1, 1);
		buildSelBorder.bind(this)(sel.x0+this.moveOffset.x+0, sel.y1+this.moveOffset.y+1, sel.x1+this.moveOffset.x+1, sel.y1+this.moveOffset.y+1, 3);
		buildSelBorder.bind(this)(sel.x0+this.moveOffset.x+0, sel.y0+this.moveOffset.y+0, sel.x0+this.moveOffset.x+0, sel.y1+this.moveOffset.y+1, 0);
	}
}

var addSelection = function(selection, clear) {
	if(clear) {
		this.selection.clear();
	}
	var selNrm = selection.getSelectionNormalized();
	var sel = new Selection();
	sel.setSelection(selNrm.x0, selNrm.y0, selNrm.x1, selNrm.y1);
	this.selection.add(sel);
	//update visual
	this.selectionDiv.innerHTML = '';
	buildSelections.bind(this)();
}

var updateBackgroundGrid = function() {
	var s = getZoomedTileSize.bind(this)();
	if (s < 2) {
		s = 2;
	}
	var img = 'repeating-linear-gradient(transparent, transparent '+(s-1)+'px, var(--tileGridLine) '+(s-1)+'px, var(--tileGridLine) '+(s)+'px),\
                      repeating-linear-gradient(0.25turn, var(--tileGridChecker), var(--tileGridChecker) '+(s-1)+'px, var(--tileGridLine) '+(s-1)+'px, var(--tileGridLine) '+(s)+'px)';
	this.div.style.backgroundImage = img;
	this.div.style.backgroundSize = s+'px '+s+'px';
	this.div.style.backgroundPosition = (this.camera.x+'px ')+(this.camera.y+'px ');
}

var getZoomedTileSize = function() {
	var z = this.zoomFactor;
	if(this.zoomFactor < 1) {
		z = 1.0/Math.pow(2.0, (1.0-this.zoomFactor));
	}
	return Math.floor(this.tileSize*z);
}

/** 用 chunk 索引与当前缩放对齐画布块，避免 adjustZoom 按比例缩放产生的累积像素误差（与背景网格错位）。 */
var layoutChunkCanvasOrtho = function(tileDiv, originalTileSize, prevZoomedSize) {
	var cx = parseInt(tileDiv.dataset.chunkX, 10);
	var cy = parseInt(tileDiv.dataset.chunkY, 10);
	var s = getZoomedTileSize.bind(this)();
	if(Number.isFinite(cx) && Number.isFinite(cy)) {
		tileDiv.style.left = (Math.round(this.camera.x + cx * chunkSize * s)) + 'px';
		tileDiv.style.top = (Math.round(this.camera.y + cy * chunkSize * s)) + 'px';
		var w = Math.round(chunkSize * s);
		tileDiv.style.width = w + 'px';
		tileDiv.style.height = w + 'px';
		tileDiv.style.backgroundSize = w + 'px ' + w + 'px';
		return;
	}
	if(originalTileSize == null || prevZoomedSize == null) {
		return;
	}
	var originalX = +tileDiv.style.left.replace(/px/g, "") - this.camera.x;
	var originalY = +tileDiv.style.top.replace(/px/g, "") - this.camera.y;
	var nlx = Math.round(originalX * s / prevZoomedSize + this.camera.x);
	var nly = Math.round(originalY * s / prevZoomedSize + this.camera.y);
	tileDiv.style.left = nlx + 'px';
	tileDiv.style.top = nly + 'px';
	var originalW = +tileDiv.style.width.replace(/px/g, "");
	var originalH = +tileDiv.style.height.replace(/px/g, "");
	var tileDivWidth = Math.round(originalW * s / prevZoomedSize);
	var tileDivHieght = Math.round(originalH * s / prevZoomedSize);
	tileDiv.style.width = tileDivWidth + 'px';
	tileDiv.style.height = tileDivHieght + 'px';
	tileDiv.style.backgroundSize = tileDivWidth + 'px ' + tileDivHieght + 'px';
};

var getTileAtPoint = function(clientX, clientY) {
	var offsets = this.div.getBoundingClientRect();
	var cursorPos = {x:clientX-offsets.left, y:clientY-offsets.top};
	var tileSpace = {x:(cursorPos.x-this.camera.x)/getZoomedTileSize.bind(this)(), y:(cursorPos.y-this.camera.y)/getZoomedTileSize.bind(this)()};
	var tilePos = {x:Math.floor(tileSpace.x), y:Math.floor(tileSpace.y)};
	return {x:tilePos.x, y:tilePos.y, fineX:tileSpace.x-tilePos.x, fineY:tileSpace.y-tilePos.y};
}

var mouseDown = function(clientX, clientY, event) {
	var tilePos = getTileAtPoint.bind(this)(clientX, clientY);
	this.mouseDownCallback.notify(tilePos, this.clickedRegion, event);
}

var autoPan = function(clientX, clientY) {
	var panAmount = function(dist) {
		var k = 10;
		var l = 32;
		return Math.min(k, Math.max(0, k-(dist*k/l)));
	}
	var offsets = this.div.getBoundingClientRect();
	var dists = [panAmount(clientX-offsets.left), panAmount(clientY-offsets.top), panAmount(offsets.right-clientX), panAmount(offsets.bottom-clientY)];
	translateCamera.bind(this)(dists[0]-dists[2], dists[1]-dists[3]);
}

var mouseMove = function(clientX, clientY, event) {
	var tilePos = getTileAtPoint.bind(this)(clientX, clientY);

	if(this.state == StateEnum.PAN) {
		translateCamera.bind(this)(event.scaledMovementX, event.scaledMovementY);
	}
	if(this.state == StateEnum.SELECT) {
		autoPan.bind(this)(clientX, clientY);
		var sel = this.selectionBoundaries.getSelection();
		setSelectionBoundaries.bind(this)(sel.x0, sel.y0, tilePos.x, tilePos.y);
		this.selectionSizeChangedCallback.notify();
	}
	if(this.state == StateEnum.MOVE) {
		autoPan.bind(this)(clientX, clientY);
		var offsetX = tilePos.x-this.move.x;
		var offsetY = tilePos.y-this.move.y;
		translateSelection.bind(this)(offsetX, offsetY);
		this.moveOffset.x += offsetX;
		this.moveOffset.y += offsetY;
		this.move.x = tilePos.x;
		this.move.y = tilePos.y;
	}
	if(this.state == StateEnum.ZOOM) {
		this.zoom(this.zoomStatePos, event.scaledMovementY);
	}
	if(this.state == StateEnum.MOVE_REG) {
		autoPan.bind(this)(clientX, clientY);
		var offsetX = tilePos.x-this.move.x;
		var offsetY = tilePos.y-this.move.y;
		translateRegion.bind(this)(offsetX, offsetY);
		this.moveOffset.x += offsetX;
		this.moveOffset.y += offsetY;
		this.move.x = tilePos.x;
		this.move.y = tilePos.y;
	}
	if(this.state == StateEnum.PICK) {
		setSelectionBoundaries.bind(this)(tilePos.x, tilePos.y, tilePos.x, tilePos.y);
	}

	this.mouseMoveCallback.notify(tilePos, event);
}

var mouseUp = function(clientX, clientY, event) {
	this.clickedRegion = null;
	var tilePos = getTileAtPoint.bind(this)(clientX, clientY);

	if(this.state == StateEnum.SELECT) {
		this.selectionBoundsDiv.style.visibility = "hidden";
		addSelection.bind(this)(this.selectionBoundaries, !event.shiftKey);
	}
	if(this.state == StateEnum.MOVE) {
		var sel = this.selection.getSelected();
		this.selection.translate(this.moveOffset.x, this.moveOffset.y);
		this.tilesMovedCallback.notify(sel, this.moveOffset.x, this.moveOffset.y);
		this.tilesDiv.removeChild(this.selectionCanvas);
		this.selectionCanvas = null;
		this.moveOffset.x = 0;
		this.moveOffset.y = 0;
	}
	if(this.state == StateEnum.MOVE_REG) {
		this.selection.translate(this.moveOffset.x, this.moveOffset.y);
		this.regionMovedCallback.notify(this.movingRegion, this.moveOffset.x, this.moveOffset.y);
		this.tilesDiv.removeChild(this.selectionCanvas);
		this.selectionCanvas = null;
		this.moveOffset.x = 0;
		this.moveOffset.y = 0;
	}
	if(this.state == StateEnum.PICK) {
		this.selectionBoundsDiv.style.visibility = "hidden";
	}
	var currentState = this.state;
	this.state = StateEnum.NONE;

	if(currentState == StateEnum.SELECT) {
		this.selectionSizeChangedCallback.notify();
	}

	this.mouseUpCallback.notify(tilePos, event, currentState);
}

var mouseWheel = function(event) {
	var z = getUiZoomScale();
	var tilePos = getTileAtPoint.bind(this)(event.clientX/z, event.clientY/z);
	this.mouseWheelCallback.notify(tilePos, event.deltaY, event.ctrlKey);
}

var getTileKey = function(x, y) {
	var a = 2*x;
	if(x < 0) { a = -2*x-1; }
	var b = 2*y;
	if(y < 0) { b = -2*y-1; }
	return ((a+b)*(a+b+1)+b)/2;
}

var chunkSize = 16;

var setTileImage = function(image, x, y, z=0) {
	var layer = this.layers.getLayer(z);
	var chunkX = Math.floor(x/chunkSize);
	var chunkY = Math.floor(y/chunkSize);
	var chunkCanvas = layer.chunks[getTileKey(chunkX, chunkY)];
	var tileSize = tileroninX.getTileSize();
	if(chunkCanvas == null && image != null) {
		var cc = document.createElement('canvas');
		cc.className = 'tilegrid-tile-view';
		cc.width  = tileSize*chunkSize;
	    cc.height = tileSize*chunkSize;
		cc.dataset.chunkX = String(chunkX);
		cc.dataset.chunkY = String(chunkY);
		var s0 = getZoomedTileSize.bind(this)();
		cc.style.left = (Math.round(this.camera.x + chunkX * chunkSize * s0)) + 'px';
		cc.style.top = (Math.round(this.camera.y + chunkY * chunkSize * s0)) + 'px';
		cc.style.width = (Math.round(chunkSize * s0)) + 'px';
		cc.style.height = (Math.round(chunkSize * s0)) + 'px';
		cc.style.zIndex = z*2;
		if(!layer.visible) {
			cc.style.visibility = "hidden";
		}
	    this.tilesDiv.appendChild(cc);
	    chunkCanvas = [cc, cc.getContext('2d')];
	    layer.chunks[getTileKey(chunkX, chunkY)] = chunkCanvas;
	}

	if(image != null) {
		var ctx = chunkCanvas[1];
		ctx.clearRect((x-chunkX*chunkSize)*tileSize, (y-chunkY*chunkSize)*tileSize, tileSize, tileSize);
    	ctx.drawImage(image, (x-chunkX*chunkSize)*tileSize, (y-chunkY*chunkSize)*tileSize);
	} else if(chunkCanvas != null) {
		var ctx = chunkCanvas[1];
		ctx.clearRect((x-chunkX*chunkSize)*tileSize, (y-chunkY*chunkSize)*tileSize, tileSize, tileSize);
	}
}

var adjustZoom = function(worldPos, deltaZoom) {
	//get old data
	var originalTileSize = getZoomedTileSize.bind(this)();
	var selectionPoint = this.getSelectionPoint.bind(this)();
	var originalPoint = {x:worldPos.x*originalTileSize, y:worldPos.y*originalTileSize};

	//zoom
	var oldZoomFactor = this.zoomFactor;
	this.zoomFactor += deltaZoom;
	while(getZoomedTileSize.bind(this)() < 8) {
		this.zoomFactor++;
	}
	if(oldZoomFactor == this.zoomFactor) {
		return;
	}

	//update menu
	if(this.menu != null) {
		var originalX = this.menuX-this.camera.x;
		var originalY = this.menuY-this.camera.y;
		this.menuX = Math.round(originalX*getZoomedTileSize.bind(this)()/originalTileSize+this.camera.x);
		this.menuY = Math.round(originalY*getZoomedTileSize.bind(this)()/originalTileSize+this.camera.y);
		this.menuPaddingH.style.width = Math.max(0, this.menuX+4)+'px';
		this.menuPaddingV.style.height = Math.max(0, this.menuY+4)+'px';
	}

	//update error display
	var errorDisplayDiv = this.errorDisplay.getDiv();
	var originalX = errorDisplayDiv.style.left.replace(/px/g, "")-this.camera.x;
	var originalY = errorDisplayDiv.style.top.replace(/px/g, "")-this.camera.y;
	errorDisplayDiv.style.left = (Math.round(originalX*getZoomedTileSize.bind(this)()/originalTileSize+this.camera.x))+'px';
	errorDisplayDiv.style.top = (Math.round(originalY*getZoomedTileSize.bind(this)()/originalTileSize+this.camera.y))+'px';

	//update tile scale & position（按 chunk 网格重算，与背景一致）
	var layers = this.layers.getLayers();
	for(var k = 0; k < layers.length; k++) {
		var layer = layers[k];
		for(var idx in layer.chunks) {
			layoutChunkCanvasOrtho.bind(this)(layer.chunks[idx][0], originalTileSize, originalTileSize);
		}
	}

	//update region scale & position
	for(var i = 0; i < this.regions.length; i++) {
		var region = this.regions[i];
		var borderRadius = 2;
		var regionBounds = region.region.getBounds();
		var regionDiv = region.div;
		var originalX = regionDiv.style.left.replace(/px/g, "")-this.camera.x+borderRadius;
		var originalY = regionDiv.style.top.replace(/px/g, "")-this.camera.y+borderRadius;
		regionDiv.style.left = (Math.round(originalX*getZoomedTileSize.bind(this)()/originalTileSize+this.camera.x-borderRadius))+'px';
		regionDiv.style.top = (Math.round(originalY*getZoomedTileSize.bind(this)()/originalTileSize+this.camera.y-borderRadius))+'px';
		regionDiv.style.width = (getZoomedTileSize.bind(this)()*(regionBounds.x1+1-regionBounds.x0))+'px';
		regionDiv.style.height = (getZoomedTileSize.bind(this)()*(regionBounds.y1+1-regionBounds.y0))+'px';

		regionDiv.childNodes[1].style.maxWidth = (getZoomedTileSize.bind(this)()*(regionBounds.x1+1-regionBounds.x0)*0.5)+'px';
	}

	//get new data
	var newPoint = {x:worldPos.x*getZoomedTileSize.bind(this)(), y:worldPos.y*getZoomedTileSize.bind(this)()};

	updateBackgroundGrid.bind(this)();
	translateCamera.bind(this)(originalPoint.x-newPoint.x, originalPoint.y-newPoint.y);
	buildSelections.bind(this)();
}

var StateEnum = Object.freeze({"NONE":0, "PAN":1, "SELECT":2, "MOVE":3, "ZOOM":4, "MOVE_REG":5, "PICK":6});

class TileGridOrthographicView {
	constructor(tileSize, menuOptions=null) {
		this.state = StateEnum.NONE;

		this.camera = {x:0, y:0};
		this.move = {x:0, y:0};
		this.moveOffset = {x:0, y:0};
		this.tileSize = tileSize;

		this.clickedRegion = null;
		this.movingRegion = null;

		this.zoomFactor = 1;
		this.zoomStatePos = {x:0, y:0};
		this.zoomStateDelta = 0;

		this.layers = new LayerList([{chunks:[], tileCallbacks:[], visible:true}]);

		this.selectionCanvas = null;

		this.tileDivs = {};
		this.tilesDiv = document.createElement('div');

		this.regions = [];
		this.regionsDiv = document.createElement('div');

		this.mouseDownCallback = new CallbackManager();
		this.mouseMoveCallback = new CallbackManager();
		this.mouseUpCallback = new CallbackManager();
		this.mouseWheelCallback = new CallbackManager();

		this.tilesMovedCallback = new CallbackManager();
		this.regionRemovedCallback = new CallbackManager();
		this.regionMovedCallback = new CallbackManager();

		this.selectionSizeChangedCallback = new CallbackManager();

		this.selectionBoundaries = new Selection();
		this.selectionBoundsDiv = document.createElement('div');
		this.selectionBoundsDiv.className = "tilegrid-selectionbounds-view";
		this.selectionBoundsDiv.style.zIndex = 2147483647-2-1;

		this.selection = new SelectionGroup();
		this.selectionDiv = document.createElement('div');
		this.selectionDiv.style.position = "absolute";
		this.selectionDiv.style.zIndex = 2147483647-1-1;

		var firstSelection = new Selection();
		firstSelection.setSelection(4, 4, 4, 4);
		addSelection.bind(this)(firstSelection, true);

		this.div = document.createElement('div');
		this.div.className = "tilegrid-view";

		this.div.appendChild(this.tilesDiv);
		this.div.appendChild(this.regionsDiv);
		this.div.appendChild(this.selectionBoundsDiv);
		this.div.appendChild(this.selectionDiv);

		if(menuOptions != null) {
			this.menu = new ExpandingMenuView(menuOptions);
			this.menu.getDiv().style.zIndex = 2147483647-1;
			this.menu.getDiv().style.marginLeft = '-4px';
			this.menu.getDiv().style.marginTop = '-4px';
			this.menu.getDiv().style.marginBottom = '-4px';
			this.menu.getDiv().style.position = 'relative';

			var menuContainerV = document.createElement('div');
			menuContainerV.style.display = "flex";
			menuContainerV.style.flexDirection = "column-reverse";
			menuContainerV.style.width = "100%";
			menuContainerV.style.height = "100%";

			var menuSpringV = document.createElement('div');
			menuSpringV.style.flexGrow = "1";
			menuSpringV.style.display = "flex";
			menuSpringV.style.flexDirection = "column-reverse";

			var menuSubSpringV = document.createElement('div');
			menuSubSpringV.style.flexGrow = "1";

			this.menuPaddingV = document.createElement('div');
			this.menuPaddingV.style.flexGrow = "0";
			this.menuPaddingV.style.flexShrink = "0";
			this.menuPaddingV.style.maxHeight = "100%";

			var menuContainerH = document.createElement('div');
			menuContainerH.style.display = "flex";
			menuContainerH.style.flexDirection = "row-reverse";
			menuContainerH.style.width = "100%";

			var menuSpringH = document.createElement('div');
			menuSpringH.style.flexGrow = "1";
			menuSpringH.style.display = "flex";
			menuSpringH.style.flexDirection = "row-reverse";

			var menuSubSpringH = document.createElement('div');
			menuSubSpringH.style.flexGrow = "1";

			this.menuPaddingH = document.createElement('div');
			this.menuPaddingH.style.flexGrow = "0";
			this.menuPaddingH.style.flexShrink = "0";
			this.menuPaddingH.style.maxWidth = "100%";

			menuContainerV.appendChild(menuSpringV);
			menuContainerV.appendChild(this.menuPaddingV);
			menuSpringV.appendChild(menuSubSpringV);
			menuSpringV.appendChild(menuContainerH);

			menuContainerH.appendChild(menuSpringH);
			menuContainerH.appendChild(this.menuPaddingH);
			menuSpringH.appendChild(menuSubSpringH);
			menuSpringH.appendChild(this.menu.getDiv());

			this.div.appendChild(menuContainerV);

			this.menuX = 0;
			this.menuY = 0;
		}

		this.errorDisplay = new ErrorDisplayView();
		this.errorDisplay.getDiv().style.zIndex = 2147483647-1;
		this.div.appendChild(this.errorDisplay.getDiv());

		updateBackgroundGrid.bind(this)();
		translateCamera.bind(this)(0, 0);

		plh.applyPointerLock(this.div, mouseDown.bind(this), mouseMove.bind(this), mouseUp.bind(this));
		this.div.addEventListener('wheel', mouseWheel.bind(this), false);
	}

	setTileSize(tileSize) {
		//get old data
		var originalTileSize = getZoomedTileSize.bind(this)();
		var selectionPoint = this.getSelectionPoint.bind(this)();
		var originalPoint = {x:selectionPoint.x*originalTileSize, y:selectionPoint.y*originalTileSize};

		//update tileSize
		this.tileSize = tileSize;
		while(getZoomedTileSize.bind(this)() < 8) {
			this.zoomFactor++;
		}

		//update menu
		if(this.menu != null) {
			var originalX = this.menuX-this.camera.x;
			var originalY = this.menuY-this.camera.y;
			this.menuX = Math.round(originalX*getZoomedTileSize.bind(this)()/originalTileSize+this.camera.x);
			this.menuY = Math.round(originalY*getZoomedTileSize.bind(this)()/originalTileSize+this.camera.y);
			this.menuPaddingH.style.width = Math.max(0, this.menuX+4)+'px';
			this.menuPaddingV.style.height = Math.max(0, this.menuY+4)+'px';
		}

		//update error display
		var errorDisplayDiv = this.errorDisplay.getDiv();
		var originalX = errorDisplayDiv.style.left.replace(/px/g, "")-this.camera.x;
		var originalY = errorDisplayDiv.style.top.replace(/px/g, "")-this.camera.y;
		errorDisplayDiv.style.left = (Math.round(originalX*getZoomedTileSize.bind(this)()/originalTileSize+this.camera.x))+'px';
		errorDisplayDiv.style.top = (Math.round(originalY*getZoomedTileSize.bind(this)()/originalTileSize+this.camera.y))+'px';

		//update region scale & position
		for(var i = 0; i < this.regions.length; i++) {
			var region = this.regions[i];
			var borderRadius = 2;
			var regionBounds = region.region.getBounds();
			var regionDiv = region.div;
			var originalX = regionDiv.style.left.replace(/px/g, "")-this.camera.x+borderRadius;
			var originalY = regionDiv.style.top.replace(/px/g, "")-this.camera.y+borderRadius;
			regionDiv.style.left = (Math.round(originalX*getZoomedTileSize.bind(this)()/originalTileSize+this.camera.x-borderRadius))+'px';
			regionDiv.style.top = (Math.round(originalY*getZoomedTileSize.bind(this)()/originalTileSize+this.camera.y-borderRadius))+'px';
			regionDiv.style.width = (getZoomedTileSize.bind(this)()*(regionBounds.x1+1-regionBounds.x0))+'px';
			regionDiv.style.height = (getZoomedTileSize.bind(this)()*(regionBounds.y1+1-regionBounds.y0))+'px';

			regionDiv.childNodes[1].style.maxWidth = (getZoomedTileSize.bind(this)()*(regionBounds.x1+1-regionBounds.x0)*0.5)+'px';
		}

		//rebuild chunks
		var layers = this.layers.getLayers();
		for(var k = 0; k < layers.length; k++) {
			var layer = layers[k];
			for(var i in layer.chunks) {
				var chunkCanvas = document.createElement('canvas');
				chunkCanvas.className = 'tilegrid-tile-view';
				chunkCanvas.width  = tileSize*chunkSize;
			    chunkCanvas.height = tileSize*chunkSize;
				var prevEl = layer.chunks[i][0];
				if(prevEl.dataset.chunkX != null && prevEl.dataset.chunkX !== '') {
					chunkCanvas.dataset.chunkX = prevEl.dataset.chunkX;
					chunkCanvas.dataset.chunkY = prevEl.dataset.chunkY;
					layoutChunkCanvasOrtho.bind(this)(chunkCanvas, null, null);
				} else {
					var ox = +prevEl.style.left.replace(/px/g, "") - this.camera.x;
					var oy = +prevEl.style.top.replace(/px/g, "") - this.camera.y;
					var sNew = getZoomedTileSize.bind(this)();
					chunkCanvas.style.left = (Math.round(ox * sNew / originalTileSize + this.camera.x)) + 'px';
					chunkCanvas.style.top = (Math.round(oy * sNew / originalTileSize + this.camera.y)) + 'px';
					chunkCanvas.style.width = (Math.round(chunkSize * sNew)) + 'px';
					chunkCanvas.style.height = (Math.round(chunkSize * sNew)) + 'px';
				}
				chunkCanvas.style.zIndex = k*2;
				if(!layer.visible) {
					chunkCanvas.style.visibility = "hidden";
				}
				this.tilesDiv.removeChild(layer.chunks[i][0]);
			    this.tilesDiv.appendChild(chunkCanvas);
			    layer.chunks[i] = [chunkCanvas, chunkCanvas.getContext('2d')];
			}
		}

		//get new data
		var newPoint = {x:selectionPoint.x*getZoomedTileSize.bind(this)(), y:selectionPoint.y*getZoomedTileSize.bind(this)()};

		updateBackgroundGrid.bind(this)();
		translateCamera.bind(this)(originalPoint.x-newPoint.x, originalPoint.y-newPoint.y);
		buildSelections.bind(this)();
	}

	getDiv() {
		return this.div;
	}

	openMenu(x, y) {
		this.closeError();
		if(this.menu != null) {
			this.menuX = (x+1)*getZoomedTileSize.bind(this)()+this.camera.x;
			this.menuY = y*getZoomedTileSize.bind(this)()+this.camera.y;
			this.menuPaddingH.style.width = Math.max(0, this.menuX+4)+'px';
			this.menuPaddingV.style.height = Math.max(0, this.menuY+4)+'px';
			this.menu.open(0, 0);
			plh.lockPointer();
		}
	}

	closeMenu() {
		if(this.menu != null) {
			this.menu.close();
		}
	}

	setMenuOptions(menuOptions) {
		this.menu.setOptions(menuOptions);
	}

	menuOptionClickedSubscribe(func) {
		if(this.menu != null) {
			this.menu.optionClickedSubscribe(func);
		}
	}

	openError(x, y, msgs) {
		this.errorDisplay.open((x+1)*getZoomedTileSize.bind(this)()+this.camera.x, (y+0.5)*getZoomedTileSize.bind(this)()+this.camera.y, msgs);
	}

	closeError() {
		this.errorDisplay.close();
	}

	setStateZoom(x, y) {
		this.state = StateEnum.ZOOM;
		plh.lockPointer();
		this.zoomStatePos = {x:x, y:y};
		//this.zoomStateDelta = 0.5;
	}

	setStatePan() {
		this.state = StateEnum.PAN;
		plh.lockPointer();
	}

	setStateSelect(x, y) {
		this.closeMenu();
		this.closeError();
		this.state = StateEnum.SELECT;
		setSelectionBoundaries.bind(this)(x, y, x, y);

		this.selectionSizeChangedCallback.notify();
	}

	setStateMove(x, y, z=0) {
		this.closeMenu();
		this.closeError();
		this.state = StateEnum.MOVE;
		this.move.x = x;
		this.move.y = y;
		this.moveOffset.x = 0;
		this.moveOffset.y = 0;

		var minX, minY, maxX, maxY;
		var regions = this.selection.getSelections();
		for(var i in regions) {
			var reg = regions[i];
			if(reg.x0 < minX || i == 0) {
				minX = reg.x0;
			}
			if(reg.x1 > maxX || i == 0) {
				maxX = reg.x1;
			}
			if(reg.y0 < minY || i == 0) {
				minY = reg.y0;
			}
			if(reg.y1 > maxY || i == 0) {
				maxY = reg.y1;
			}
		}
		var selWidth = maxX-minX+1;
		var selHeight = maxY-minY+1;

		var tileSize = tileroninX.getTileSize();
		this.selectionCanvas = document.createElement('canvas');
		this.selectionCanvas.className = 'tilegrid-tile-view';
		this.selectionCanvas.width  = tileSize*(selWidth);
	    this.selectionCanvas.height = tileSize*(selHeight);
		var sSel = getZoomedTileSize.bind(this)();
	    this.selectionCanvas.style.left = (Math.round(this.camera.x + sSel * minX)) + 'px';
		this.selectionCanvas.style.top = (Math.round(this.camera.y + sSel * minY)) + 'px';
		this.selectionCanvas.style.width = (selWidth * sSel) + 'px';
		this.selectionCanvas.style.height = (selHeight * sSel) + 'px';
		this.selectionCanvas.style.zIndex = z*2+1;
		if(!this.layers.getLayer(z).visible) {
			this.selectionCanvas.style.visibility = "hidden";
		}
		this.tilesDiv.appendChild(this.selectionCanvas);

		var ctx = this.selectionCanvas.getContext('2d');
	    var layer = this.layers.getLayer(z);

		for(var i in regions) {
			var reg = regions[i];
			var minChunkX = Math.floor(reg.x0/chunkSize);
			var maxChunkX = Math.floor(reg.x1/chunkSize);
			var minChunkY = Math.floor(reg.y0/chunkSize);
			var maxChunkY = Math.floor(reg.y1/chunkSize);

			for(var cx = minChunkX; cx <= maxChunkX; cx++) {
				for(var cy = minChunkY; cy <= maxChunkY; cy++) {
					var chunk = layer.chunks[getTileKey(cx, cy)];
					if(chunk != null) {
						var ctx2 = chunk[1];
						var sfx = Math.max(0, reg.x0-(cx*chunkSize));
						var sfy = Math.max(0, reg.y0-(cy*chunkSize));
						var sw = chunkSize-sfx-Math.max(0, ((cx+1)*chunkSize)-reg.x1-1);
						var sh = chunkSize-sfy-Math.max(0, ((cy+1)*chunkSize)-reg.y1-1);
						var dfx = cx*chunkSize-minX+sfx;
						var dfy = cy*chunkSize-minY+sfy;
						ctx.drawImage(chunk[0], sfx*tileSize, sfy*tileSize, sw*tileSize, sh*tileSize, dfx*tileSize, dfy*tileSize, sw*tileSize, sh*tileSize);
						ctx2.clearRect(sfx*tileSize, sfy*tileSize, sw*tileSize, sh*tileSize);
					}
				}
			}
		}
	}

	setStateMoveRegion(x, y, region, z=0) {
		this.closeMenu();
		this.closeError();
		this.state = StateEnum.MOVE_REG;
		this.movingRegion = region;
		var sel = new Selection();
		var bounds = region.getBounds();
		sel.setSelection(bounds.x0, bounds.y0, bounds.x1, bounds.y1);
		addSelection.bind(this)(sel, true);
		this.move.x = x;
		this.move.y = y;
		this.moveOffset.x = 0;
		this.moveOffset.y = 0;

		var minX = bounds.x0;
		var minY = bounds.y0;
		var maxX = bounds.x1;
		var maxY = bounds.y1;
		var selWidth = maxX-minX+1;
		var selHeight = maxY-minY+1;

		var tileSize = tileroninX.getTileSize();
		this.selectionCanvas = document.createElement('canvas');
		this.selectionCanvas.className = 'tilegrid-tile-view';
		this.selectionCanvas.width  = tileSize*(selWidth);
	    this.selectionCanvas.height = tileSize*(selHeight);
		var sSel = getZoomedTileSize.bind(this)();
	    this.selectionCanvas.style.left = (Math.round(this.camera.x + sSel * minX)) + 'px';
		this.selectionCanvas.style.top = (Math.round(this.camera.y + sSel * minY)) + 'px';
		this.selectionCanvas.style.width = (selWidth * sSel) + 'px';
		this.selectionCanvas.style.height = (selHeight * sSel) + 'px';
		this.selectionCanvas.style.zIndex = z*2+1;
		if(!this.layers.getLayer(z).visible) {
			this.selectionCanvas.style.visibility = "hidden";
		}
		this.tilesDiv.appendChild(this.selectionCanvas);

		var ctx = this.selectionCanvas.getContext('2d');
	    var layer = this.layers.getLayer(z);

		var minChunkX = Math.floor(minX/chunkSize);
		var maxChunkX = Math.floor(maxX/chunkSize);
		var minChunkY = Math.floor(minY/chunkSize);
		var maxChunkY = Math.floor(maxY/chunkSize);

		for(var cx = minChunkX; cx <= maxChunkX; cx++) {
			for(var cy = minChunkY; cy <= maxChunkY; cy++) {
				var chunk = layer.chunks[getTileKey(cx, cy)];
				if(chunk != null) {
					var ctx2 = chunk[1];
					var sfx = Math.max(0, minX-(cx*chunkSize));
					var sfy = Math.max(0, minY-(cy*chunkSize));
					var sw = chunkSize-sfx-Math.max(0, ((cx+1)*chunkSize)-maxX-1);
					var sh = chunkSize-sfy-Math.max(0, ((cy+1)*chunkSize)-maxY-1);
					var dfx = cx*chunkSize-minX;
					var dfy = cy*chunkSize-minY;
					ctx.drawImage(chunk[0], dfx*tileSize, dfy*tileSize);
					ctx2.clearRect(sfx*tileSize, sfy*tileSize, sw*tileSize, sh*tileSize);
				}
			}
		}

		this.selectionSizeChangedCallback.notify();
	}

	setStatePick(x, y) {
		this.closeMenu();
		this.closeError();
		this.state = StateEnum.PICK;
		setSelectionBoundaries.bind(this)(x, y, x, y);
	}

	zoom(tilePos, deltaZoom) {
		var maxZoom = 8;
		var minZoom = -3;
		this.zoomStateDelta += deltaZoom*0.1;
		if(this.zoomStateDelta > 1) {
			this.zoomStateDelta = 0.5;
			if(this.zoomFactor > minZoom) {
				adjustZoom.bind(this)(tilePos, -1);
			}
		}
		if(this.zoomStateDelta < 0) {
			this.zoomStateDelta = 0.5;
			if(this.zoomFactor < maxZoom) {
				adjustZoom.bind(this)(tilePos, +1);
			}
		}
	}

	mouseDownSubscribe(func) {
		this.mouseDownCallback.subscribe(func);
	}

	mouseMoveSubscribe(func) {
		this.mouseMoveCallback.subscribe(func);
	}

	mouseUpSubscribe(func) {
		this.mouseUpCallback.subscribe(func);
	}

	mouseWheelSubscribe(func) {
		this.mouseWheelCallback.subscribe(func);
	}

	tilesMovedSubscribe(func) {
		this.tilesMovedCallback.subscribe(func);
	}

	regionRemovedSubscribe(func) {
		this.regionRemovedCallback.subscribe(func);
	}

	regionMovedSubscribe(func) {
		this.regionMovedCallback.subscribe(func);
	}

	selectionSizeChangedSubscribe(func) {
		this.selectionSizeChangedCallback.subscribe(func);
	}

	setTile(tile, x, y, z=0) {
		var layer = this.layers.getLayer(z);
		var key = getTileKey(x, y);
		if(tile != null) {
			tile.getImage().then(function(img) {
				var tcb0 = layer.tileCallbacks[key];
				if(tcb0 != null && tile == tcb0[0]) {
	        		setTileImage.bind(this)(img, x, y, z);
	        	}
	        }.bind(this));
		} else {
			setTileImage.bind(this)(null, x, y, z);
		}

		//callbacks
		var tcb1 = layer.tileCallbacks[key];
		if(tcb1 != null) {
			tcb1[0].contentUpdatedUnsubscribeIndex(tcb1[1]);
		}
		if(tile != null) {
			var callbackFunc = function() {
				tile.getImage().then(function(img) {
					var tcb2 = layer.tileCallbacks[key];
					if(tcb2 != null && tile == tcb2[0]) {
		        		setTileImage.bind(this)(img, x, y, z);
		        	}
		        }.bind(this));
			}.bind(this);
			var cbi = tile.contentUpdatedSubscribe(callbackFunc);
			layer.tileCallbacks[key] = [tile, cbi];
		} else {
			delete layer.tileCallbacks[key];
		}
	}

	addRegion(region) {
		var regionDiv = document.createElement('div');
		var regionColor = "var(--colorSelect)";
		if(!region.isValid()) {
			regionColor = "var(--colorErrorLight)";
		}
		regionDiv.style.zIndex = 2147483647-1-1;
		regionDiv.className = "tilegrid-region-view";
		var borderRadius = 2;
		var regionBounds = region.getBounds();
		regionDiv.style.left = (this.camera.x+getZoomedTileSize.bind(this)()*regionBounds.x0-borderRadius)+'px';
		regionDiv.style.top = (this.camera.y+getZoomedTileSize.bind(this)()*regionBounds.y0-borderRadius)+'px';
		regionDiv.style.width = (getZoomedTileSize.bind(this)()*(regionBounds.x1+1-regionBounds.x0))+'px';
		regionDiv.style.height = (getZoomedTileSize.bind(this)()*(regionBounds.y1+1-regionBounds.y0))+'px';
		regionDiv.style.borderColor = regionColor;
		this.regionsDiv.appendChild(regionDiv);

		var regionButtonDiv = document.createElement('div');
		regionButtonDiv.className = "tilegrid-regionbutton-view";
		regionButtonDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_a.png')";
		regionButtonDiv.style.backgroundColor = regionColor;
		regionDiv.appendChild(regionButtonDiv);

		plh.applyPointerLock(regionButtonDiv, function() {
			plh.lockPointer();
			if(region.isValid()) {
				regionButtonDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_b.png')";
			} else {
				regionButtonDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_d.png')";
			}
		}.bind(this), null, function() {
			this.regionRemovedCallback.notify(region);
		}.bind(this));

		var regionLabelDiv = document.createElement('div');
		regionLabelDiv.className = "tilegrid-regionlabel-view";
		regionLabelDiv.innerHTML = region.getLabel();
		regionLabelDiv.style.maxWidth = (getZoomedTileSize.bind(this)()*(regionBounds.x1+1-regionBounds.x0)*0.5)+'px';
		regionLabelDiv.style.backgroundColor = regionColor;
		regionDiv.appendChild(regionLabelDiv);

		plh.applyPointerLock(regionLabelDiv, function(clientX, clientY, event) {
			this.clickedRegion = region;
			mouseDown.bind(this)(clientX, clientY, event);
		}.bind(this), mouseMove.bind(this), mouseUp.bind(this));

		this.regions.push({region:region, div:regionDiv});

		region.displayChangedSubscribe(function() {
			this.updateRegion.bind(this)(region);
		}.bind(this));
	}

	removeRegion(region) {
		for(var i = 0; i < this.regions.length; i++) {
			if(this.regions[i].region == region) {
				this.regionsDiv.removeChild(this.regions[i].div);
				this.regions.splice(i, 1);
				i--;
			}
		}
	}

	updateRegion(region) {
		for(var i = 0; i < this.regions.length; i++) {
			if(this.regions[i].region == region) {
				var regionDiv = this.regions[i].div;
				var regionColor = "var(--colorSelect)";
				if(!region.isValid()) {
					regionColor = "var(--colorErrorLight)";
				}
				regionDiv.style.borderColor = regionColor;
				regionDiv.childNodes[0].style.backgroundColor = regionColor;
				regionDiv.childNodes[1].style.backgroundColor = regionColor;
				var borderRadius = 2;
				var regionBounds = region.getBounds();
				regionDiv.style.left = (this.camera.x+getZoomedTileSize.bind(this)()*regionBounds.x0-borderRadius)+'px';
				regionDiv.style.top = (this.camera.y+getZoomedTileSize.bind(this)()*regionBounds.y0-borderRadius)+'px';
				regionDiv.style.width = (getZoomedTileSize.bind(this)()*(regionBounds.x1+1-regionBounds.x0))+'px';
				regionDiv.style.height = (getZoomedTileSize.bind(this)()*(regionBounds.y1+1-regionBounds.y0))+'px';
				break;
			}
		}
	}

	addLayer(z, visible) {
		var layers = this.layers.getLayers();
		for(var i = z; i < layers.length; i++) {
			var layer = layers[i];
			for(var k in layer.chunks) {
				layer.chunks[k][0].style.zIndex = (i+1)*2;
			}
		}
		this.layers.insertLayer({chunks:[], tileCallbacks:[], visible:visible}, z);
	}

	removeLayer(z) {
		var layers = this.layers.getLayers();
		for(var i = z+1; i < layers.length; i++) {
			var layer = layers[i];
			for(var k in layer.chunks) {
				layer.chunks[k][0].style.zIndex = (i-1)*2;
			}
		}
		var layer = layers[z];
		for(var i in layer.chunks) {
			this.tilesDiv.removeChild(layer.chunks[i][0]);
		}
		for(var i in layer.tileCallbacks) {
			layer.tileCallbacks[i][0].contentUpdatedUnsubscribeIndex(layer.tileCallbacks[i][1]);
		}
		this.layers.removeLayer(z);
	}

	reorderLayer(z, newZ) {
		var layers = this.layers.getLayers();
		console.log(z, z+1);
		for(var i = z+1; i <= newZ; i++) {
			var layer = layers[i];
			for(var k in layer.chunks) {
				layer.chunks[k][0].style.zIndex = (i-1)*2;
			}
		}
		for(var i = z-1; i >= newZ; i--) {
			var layer = layers[i];
			for(var k in layer.chunks) {
				layer.chunks[k][0].style.zIndex = (i+1)*2;
			}
		}
		var movedLayer = layers[z];
		for(var i in movedLayer.chunks) {
			movedLayer.chunks[i][0].style.zIndex = (newZ)*2;
		}
		this.layers.reorderLayer(z, newZ);
	}

	setLayerVisibility(z, visible) {
		var layer = this.layers.getLayer(z);
		layer.visible = visible;
		for(var i in layer.chunks) {
			if(visible) {
				layer.chunks[i][0].style.visibility = "visible";
			} else {
				layer.chunks[i][0].style.visibility = "hidden";
			}
		}
	}

	getSelected() {
		return this.selection.getSelected();
	}

	getSelectionSize() {
		if(this.state == StateEnum.SELECT) {
			var sel = this.selectionBoundaries.getSelection();
			var minX = Math.min(sel.x0, sel.x1);
			var minY = Math.min(sel.y0, sel.y1)
			var maxX = Math.max(sel.x0, sel.x1);
			var maxY = Math.max(sel.y0, sel.y1);
			return {x:maxX-minX+1, y:maxY-minY+1};
		} else {
			var minX;
			var minY;
			var maxX;
			var maxY;
			var selections = this.selection.getSelections();
			for(var i = 0; i < selections.length; i++) {
				var bounds = selections[i].getSelection();
				if(i == 0 || bounds.x0 < minX) {
					minX = bounds.x0;
				}
				if(i == 0 || bounds.y0 < minY) {
					minY = bounds.y0;
				}
				if(i == 0 || bounds.x1 > maxX) {
					maxX = bounds.x1;
				}
				if(i == 0 || bounds.y1 > maxY) {
					maxY = bounds.y1;
				}
			}
			return {x:maxX-minX+1, y:maxY-minY+1};
		}
	}

	getSelectionPoint() {
		var selection = this.selection.getSelections()[0].getSelection();
		return {x:selection.x0, y:selection.y0};
	}

	selectionContains(x, y) {
		return this.selection.contains(x, y);
	}

	getCamera() {
		return this.camera;
	}

	setCamera(x, y) {
		translateCamera.bind(this)(x-this.camera.x, y-this.camera.y);
	}

	getZoom() {
		return this.zoomFactor;
	}

	setZoom(z) {
		adjustZoom.bind(this)({x:0, y:0}, z-this.zoomFactor);
	}

	select(positions) {
		for(var i in positions) {
			var pos = positions[i];
			var newSelection = new Selection();
			newSelection.setSelection(pos.x, pos.y, pos.x, pos.y);
			var replace = (i==0) ? true : false;
			addSelection.bind(this)(newSelection, replace);
		}
		this.selectionSizeChangedCallback.notify();
	}
}
module.exports = TileGridOrthographicView;
