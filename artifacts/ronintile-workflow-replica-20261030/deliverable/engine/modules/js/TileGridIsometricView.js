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
	//update visual
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
	var tileDivs = [];
	if(this.tilesDiv.contains(this.selectionCanvas)) {
		tileDivs.push(this.selectionCanvas);
	}
	var layers = this.layers.getLayers();
	for(var i = 0; i < layers.length; i++) {
		var layer = layers[i];
		tileDivs = tileDivs.concat(Array.from(layer.div.childNodes));
	}
	for(var i = 0; i < tileDivs.length; i++) {
		var tileDiv = tileDivs[i];
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
	var ratio = this.tileSize[1]/this.tileSize[0];
	var borderRadius = Math.floor(4/Math.sqrt((2*ratio*ratio)/(1.0+ratio*ratio)));
	var s = getZoomedTileDims.bind(this)()[0]/Math.sqrt(2);
	var tw = getZoomedTileDims.bind(this)()[0];
	var th = getZoomedTileDims.bind(this)()[1];
	this.selectionBoundsDiv.style.left = (Math.round(this.camera.x + tw / 2.0 * (selNrm.x0 - selNrm.y0) - borderRadius)) + 'px';
	this.selectionBoundsDiv.style.top = (Math.round(this.camera.y + th / 2.0 * (selNrm.x0 + selNrm.y0) - borderRadius)) + 'px';
	this.selectionBoundsDiv.style.width = (s*(selNrm.x1+1-selNrm.x0))+'px';
	this.selectionBoundsDiv.style.height = (s*(selNrm.y1+1-selNrm.y0))+'px';
	this.selectionBoundsDiv.style.transform = "translate(-50%, -50%) translate("+borderRadius+"px, "+borderRadius+"px) scale(1, "+ratio+") rotate(45deg) translate("+(-borderRadius)+"px, "+(-borderRadius)+"px) translate(50%, 50%)";
	this.selectionBoundsDiv.style.borderWidth = borderRadius+"px";
	this.selectionBoundsDiv.style.visibility = "visible";
}

var translateSelection = function(x, y) {
	//update visual
	var selDivs = this.selectionDiv.childNodes;
	for(var i = 0; i < selDivs.length; i++) {
		var selDiv = selDivs.item(i);
		selDiv.style.left = ((getZoomedTileDims.bind(this)()[0]/2.0*(x-y))+ +(selDiv.style.left.replace(/px/g, "")))+'px';
		selDiv.style.top = ((getZoomedTileDims.bind(this)()[1]/2.0*(x+y))+ +(selDiv.style.top.replace(/px/g, "")))+'px';
	}
	this.selectionCanvas.style.left = ((getZoomedTileDims.bind(this)()[0]/2.0*(x-y))+ +(this.selectionCanvas.style.left.replace(/px/g, "")))+'px';
	this.selectionCanvas.style.top = ((getZoomedTileDims.bind(this)()[1]/2.0*(x+y))+ +(this.selectionCanvas.style.top.replace(/px/g, "")))+'px';
}

var translateRegion = function(x, y) {
	//update visual
	var selDivs = this.selectionDiv.childNodes;
	for(var i = 0; i < selDivs.length; i++) {
		var selDiv = selDivs.item(i);
		selDiv.style.left = ((getZoomedTileDims.bind(this)()[0]/2.0*(x-y))+ +(selDiv.style.left.replace(/px/g, "")))+'px';
		selDiv.style.top = ((getZoomedTileDims.bind(this)()[1]/2.0*(x+y))+ +(selDiv.style.top.replace(/px/g, "")))+'px';
	}
	for(var i = 0; i < this.regions.length; i++) {
		if(this.regions[i].region == this.movingRegion) {
			var regionDiv = this.regions[i].div;
			regionDiv.style.left = ((getZoomedTileDims.bind(this)()[0]/2.0*(x-y))+ +(regionDiv.style.left.replace(/px/g, "")))+'px';
			regionDiv.style.top = ((getZoomedTileDims.bind(this)()[1]/2.0*(x+y))+ +(regionDiv.style.top.replace(/px/g, "")))+'px';
		}
	}
	this.selectionCanvas.style.left = ((getZoomedTileDims.bind(this)()[0]/2.0*(x-y))+ +(this.selectionCanvas.style.left.replace(/px/g, "")))+'px';
	this.selectionCanvas.style.top = ((getZoomedTileDims.bind(this)()[1]/2.0*(x+y))+ +(this.selectionCanvas.style.top.replace(/px/g, "")))+'px';
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
		var halfThickness = 2;

		var ratio = this.tileSize[1]/this.tileSize[0];
		var borderRadius = Math.floor(halfThickness/Math.sqrt((2.0*ratio*ratio)/(1.0+ratio*ratio)));
		var selFlush = halfThickness*4*Math.sqrt(2/(1.0+ratio*ratio));

		var deg;
		var selStripe;
		//var selStripe = halfThickness*2*Math.sqrt(2);
		var bgHeight;
		var bgWidth;
		var scrollXA = 0;
		var scrollXB = 0;
		var scrollYA = 0;
		var scrollYB = 0;
		if(side == 2 || side == 3) {
			deg = 135-Math.atan((1-ratio)/(ratio+ratio*ratio))*180/Math.PI;
			selStripe = selFlush/Math.sqrt(1+Math.pow(Math.tan((deg-90)*Math.PI/180.0), 2));
			//
			//bgHeight = selStripe*4*Math.sqrt(1+Math.pow(Math.tan((180-deg)*Math.PI/180.0), 2));
			bgHeight = borderRadius*2;
			bgWidth = selFlush*4;
			//
			scrollXA = selFlush;
			scrollXB = selFlush*3;
		} else {
			deg = 135+Math.atan((1-ratio)/(ratio+ratio*ratio))*180/Math.PI;
			selStripe = selFlush/Math.sqrt(1+Math.pow(Math.tan((180-deg)*Math.PI/180.0), 2));
			//
			//bgHeight = selStripe*4*Math.sqrt(1+Math.pow(Math.tan((180-deg)*Math.PI/180.0), 2));
			bgHeight = selFlush*4;
			bgWidth = borderRadius*2;
			//
			scrollYA = selFlush;
			scrollYB = selFlush*3;
		}
		var s = getZoomedTileDims.bind(this)()[0]/Math.sqrt(2);

		var selBorder = document.createElement('div');
		selBorder.className = 'tilegrid-selection-view';
		var twB = getZoomedTileDims.bind(this)()[0];
		var thB = getZoomedTileDims.bind(this)()[1];
		selBorder.style.left = (Math.round(this.camera.x + twB / 2.0 * (x0 - y0) - borderRadius)) + 'px';
		selBorder.style.top = (Math.round(this.camera.y + thB / 2.0 * (x0 + y0) - borderRadius)) + 'px';
		selBorder.style.width = (s*(x1-x0)+borderRadius*2)+'px';
		selBorder.style.height = (s*(y1-y0)+borderRadius*2)+'px';
		selBorder.style.transform = "translate(-50%, -50%) translate("+borderRadius+"px, "+borderRadius+"px) scale(1, "+ratio+") rotate(45deg) translate("+(-borderRadius)+"px, "+(-borderRadius)+"px) translate(50%, 50%)";
		selBorder.style.background = "repeating-linear-gradient("+deg+"deg, transparent, transparent "+selStripe+"px, var(--colorSelect) "+selStripe+"px, var(--colorSelect) "+(selStripe*2)+"px)";
		selBorder.style.backgroundSize = (bgWidth)+"px "+(bgHeight)+"px";
		/*if(side == 0) {
			selBorder.style.clipPath = "polygon(0 0, 100% "+(borderRadius*2)+"px, 100% "+(s*(y1-y0))+"px, 0 100%)";
		} else if(side == 1) {
			selBorder.style.clipPath = "polygon(0 "+(borderRadius*2)+"px, 100% 0, 100% 100%, 0 "+(s*(y1-y0))+"px)";
		} else if(side == 2) {
			selBorder.style.clipPath = "polygon(0 0, 100% 0, "+(s*(x1-x0))+"px 100%, "+(borderRadius*2)+"px 100%)";
		} else {
			selBorder.style.clipPath = "polygon("+(borderRadius*2)+"px 0, "+(s*(x1-x0))+"px 0, 100% 100%, 0 100%)";
		}*/
		selBorder.style.setProperty('--selScrollXA', scrollXA+"px");
		selBorder.style.setProperty('--selScrollXB', scrollXB+"px");
		selBorder.style.setProperty('--selScrollYA', scrollYA+"px");
		selBorder.style.setProperty('--selScrollYB', scrollYB+"px");
		this.selectionDiv.appendChild(selBorder);
	}

	var expandSelBorder = function(x0, y0, x1, y1, side) {
		for(var i = 0; i < selections.length; i++) {
			var sel = selections[i];
			if(side == 0) {
				//left border
				if(sel.x0 == x0) {
					if((sel.y0 < y0 && sel.y1+1 >= y0) || (sel.y0 <= y1 && sel.y1+1 > y1)) {
						expandSelBorder.bind(this)(x0, Math.min(sel.y0, y0), x1, Math.max(sel.y1+1, y1), side);
						return;
					}
				}
			} else if(side == 1) {
				//right border
				if(sel.x1+1 == x1) {
					if((sel.y0 < y0 && sel.y1+1 >= y0) || (sel.y0 <= y1 && sel.y1+1 > y1)) {
						expandSelBorder.bind(this)(x0, Math.min(sel.y0, y0), x1, Math.max(sel.y1+1, y1), side);
						return;
					}
				}
			} else if(side == 2) {
				//top border
				if(sel.y0 == y0) {
					if((sel.x0 < x0 && sel.x1+1 >= x0) || (sel.x0 <= x1 && sel.x1+1 > x1)) {
						expandSelBorder.bind(this)(Math.min(sel.x0, x0), y0, Math.max(sel.x1+1, x1), y1, side);
						return;
					}
				}
			} else if(side == 3) {
				//down border
				if(sel.y1+1 == y1) {
					if((sel.x0 < x0 && sel.x1+1 >= x0) || (sel.x0 <= x1 && sel.x1+1 > x1)) {
						expandSelBorder.bind(this)(Math.min(sel.x0, x0), y0, Math.max(sel.x1+1, x1), y1, side);
						return;
					}
				}
			}
		}
		buildSelBorder.bind(this)(x0, y0, x1, y1, side);
	}

	for(var i = 0; i < selections.length; i++) {
		var sel = selections[i];
		expandSelBorder.bind(this)(sel.x0+this.moveOffset.x+0, sel.y0+this.moveOffset.y+0, sel.x1+this.moveOffset.x+1, sel.y0+this.moveOffset.y+0, 2);
		expandSelBorder.bind(this)(sel.x1+this.moveOffset.x+1, sel.y0+this.moveOffset.y+0, sel.x1+this.moveOffset.x+1, sel.y1+this.moveOffset.y+1, 1);
		expandSelBorder.bind(this)(sel.x0+this.moveOffset.x+0, sel.y1+this.moveOffset.y+1, sel.x1+this.moveOffset.x+1, sel.y1+this.moveOffset.y+1, 3);
		expandSelBorder.bind(this)(sel.x0+this.moveOffset.x+0, sel.y0+this.moveOffset.y+0, sel.x0+this.moveOffset.x+0, sel.y1+this.moveOffset.y+1, 0);
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
	var tw = getZoomedTileDims.bind(this)()[0];
	var th = getZoomedTileDims.bind(this)()[1];
	var a = Math.atan(th/tw);
	var b = Math.PI-a;
	var t = Math.sin(Math.PI/2.0-a)*th;
	if (t < 2) {
		t = 2;
	}
	a = a/(2*Math.PI);
	b = b/(2*Math.PI);
	var img = 'repeating-linear-gradient('+a+'turn, transparent, transparent '+(t-1)+'px, var(--tileGridLine) '+(t-1)+'px, var(--tileGridLine) '+(t)+'px),\
                      repeating-linear-gradient('+b+'turn, var(--tileGridChecker), var(--tileGridChecker) '+(t-1)+'px, var(--tileGridLine) '+(t-1)+'px, var(--tileGridLine) '+(t)+'px)';
	this.div.style.backgroundImage = img;
	this.div.style.backgroundSize = tw+'px '+th+'px';
	this.div.style.backgroundPosition = (this.camera.x+'px ')+(this.camera.y+'px ');
}

var getZoomedTileDims = function() {
	var z = this.zoomFactor;
	if(this.zoomFactor < 1) {
		z = 1.0/Math.pow(2.0, (1.0-this.zoomFactor));
	}
	return [Math.floor(this.tileSize[0]*z), Math.floor(this.tileSize[1]*z)];
}

/** 等距 chunk 按索引与当前缩放对齐，避免 adjustZoom 按比例缩放与背景网格错位。 */
var layoutChunkCanvasIso = function(tileDiv, prevTw, prevTh) {
	var cx = parseInt(tileDiv.dataset.chunkX, 10);
	var cy = parseInt(tileDiv.dataset.chunkY, 10);
	var d = getZoomedTileDims.bind(this)();
	var tw = d[0];
	var th = d[1];
	if(Number.isFinite(cx) && Number.isFinite(cy)) {
		tileDiv.style.left = (Math.round(this.camera.x + (cx - cy - 1) * chunkSize * tw / 2.0)) + 'px';
		tileDiv.style.top = (Math.round(this.camera.y + (cx + cy) * chunkSize * th / 2.0)) + 'px';
		var w = Math.round(chunkSize * tw);
		var h = Math.round(chunkSize * th);
		tileDiv.style.width = w + 'px';
		tileDiv.style.height = h + 'px';
		tileDiv.style.backgroundSize = w + 'px ' + h + 'px';
		return;
	}
	if(prevTw == null || prevTh == null) {
		return;
	}
	var originalX = +tileDiv.style.left.replace(/px/g, "") - this.camera.x;
	var originalY = +tileDiv.style.top.replace(/px/g, "") - this.camera.y;
	tileDiv.style.left = (originalX * tw / prevTw + this.camera.x) + 'px';
	tileDiv.style.top = (originalY * th / prevTh + this.camera.y) + 'px';
	var originalW = +tileDiv.style.width.replace(/px/g, "");
	var originalH = +tileDiv.style.height.replace(/px/g, "");
	var tileDivWidth = originalW * tw / prevTw;
	var tileDivHieght = originalH * th / prevTh;
	tileDiv.style.width = tileDivWidth + 'px';
	tileDiv.style.height = tileDivHieght + 'px';
	tileDiv.style.backgroundSize = tileDivWidth + 'px ' + tileDivHieght + 'px';
};

var getTileAtPoint = function(clientX, clientY) {
	var offsets = this.div.getBoundingClientRect();
	var cursorPos = {x:clientX-offsets.left, y:clientY-offsets.top};
	var tileSpace = {x:(cursorPos.x-this.camera.x)/getZoomedTileDims.bind(this)()[0]+(cursorPos.y-this.camera.y)/getZoomedTileDims.bind(this)()[1], y:(cursorPos.y-this.camera.y)/getZoomedTileDims.bind(this)()[1]-(cursorPos.x-this.camera.x)/getZoomedTileDims.bind(this)()[0]};
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
		cc.width  = tileSize[0]*chunkSize;
	    cc.height = tileSize[1]*chunkSize;
		cc.dataset.chunkX = String(chunkX);
		cc.dataset.chunkY = String(chunkY);
		var d0 = getZoomedTileDims.bind(this)();
		cc.style.left = (Math.round(this.camera.x + (chunkX - chunkY - 1) * chunkSize * d0[0] / 2.0)) + 'px';
		cc.style.top = (Math.round(this.camera.y + (chunkX + chunkY) * chunkSize * d0[1] / 2.0)) + 'px';
		cc.style.width = (Math.round(chunkSize * d0[0])) + 'px';
		cc.style.height = (Math.round(chunkSize * d0[1])) + 'px';
		cc.style.zIndex = chunkX+chunkY;
		if(!layer.visible) {
			cc.style.visibility = "hidden";
		}
	    layer.div.appendChild(cc);
	    chunkCanvas = [cc, cc.getContext('2d')];
	    layer.chunks[getTileKey(chunkX, chunkY)] = chunkCanvas;
	}

	if(chunkCanvas != null) {
		var keyA = getTileKey(x-1, y);
		var tA = layer.tileCallbacks[keyA];
		var tAI = (Math.floor((x-1)/chunkSize) == chunkX && tA != null) ? tA[0].getImage() : Promise.resolve(null);

		var keyB = getTileKey(x, y-1);
		var tB = layer.tileCallbacks[keyB];
		var tBI = (Math.floor((y-1)/chunkSize) == chunkY && tB != null) ? tB[0].getImage() : Promise.resolve(null);

		var keyC = getTileKey(x, y+1);
		var tC = layer.tileCallbacks[keyC];
		var tCI = (Math.floor((y+1)/chunkSize) == chunkY && tC != null) ? tC[0].getImage() : Promise.resolve(null);

		var keyD = getTileKey(x+1, y);
		var tD = layer.tileCallbacks[keyD];
		var tDI = (Math.floor((x+1)/chunkSize) == chunkX && tD != null) ? tD[0].getImage() : Promise.resolve(null);

		tAI.then(function(imgA) {
			tBI.then(function(imgB) {
				tCI.then(function(imgC) {
					tDI.then(function(imgD) {
						var ctx = chunkCanvas[1];
				    	ctx.clearRect((x-y-1-(chunkX-chunkY-1)*chunkSize)*tileSize[0]/2.0, (x+y-(chunkX+chunkY)*chunkSize)*tileSize[1]/2.0, tileSize[0], tileSize[1]);
				    	if(imgA != null && layer.tileCallbacks[keyA] != null && layer.tileCallbacks[keyA][0] == tA[0]) {
				    		ctx.drawImage(imgA, tileSize[0]/2.0, tileSize[1]/2.0, tileSize[0]/2.0, tileSize[1]/2.0, (x-y-1-(chunkX-chunkY-1)*chunkSize)*tileSize[0]/2.0, (x+y-(chunkX+chunkY)*chunkSize)*tileSize[1]/2.0, tileSize[0]/2.0, tileSize[1]/2.0);
				    	}
				    	if(imgB != null && layer.tileCallbacks[keyB] != null && layer.tileCallbacks[keyB][0] == tB[0]) {
				    		ctx.drawImage(imgB, 0, tileSize[1]/2.0, tileSize[0]/2.0, tileSize[1]/2.0, (x-y-1-(chunkX-chunkY-1)*chunkSize+1)*tileSize[0]/2.0, (x+y-(chunkX+chunkY)*chunkSize)*tileSize[1]/2.0, tileSize[0]/2.0, tileSize[1]/2.0);
				    	}
					    if(image != null) {
				    		ctx.drawImage(image, (x-y-1-(chunkX-chunkY-1)*chunkSize)*tileSize[0]/2.0, (x+y-(chunkX+chunkY)*chunkSize)*tileSize[1]/2.0);
				    	}
				    	if(imgC != null && layer.tileCallbacks[keyC] != null && layer.tileCallbacks[keyC][0] == tC[0]) {
				    		ctx.drawImage(imgC, tileSize[0]/2.0, 0, tileSize[0]/2.0, tileSize[1]/2.0, (x-y-1-(chunkX-chunkY-1)*chunkSize)*tileSize[0]/2.0, (x+y-(chunkX+chunkY)*chunkSize+1)*tileSize[1]/2.0, tileSize[0]/2.0, tileSize[1]/2.0);
				    	}
				    	if(imgD != null && layer.tileCallbacks[keyD] != null && layer.tileCallbacks[keyD][0] == tD[0]) {
				    		ctx.drawImage(imgD, 0, 0, tileSize[0]/2.0, tileSize[1]/2.0, (x-y-1-(chunkX-chunkY-1)*chunkSize+1)*tileSize[0]/2.0, (x+y-(chunkX+chunkY)*chunkSize+1)*tileSize[1]/2.0, tileSize[0]/2.0, tileSize[1]/2.0);
				    	}
        			}.bind(this));
        		}.bind(this));
        	}.bind(this));
        }.bind(this));
    }
}

var adjustZoom = function(worldPos, deltaZoom) {
	//get old data
	var originalTileDims = getZoomedTileDims.bind(this)();
	var selectionPoint = this.getSelectionPoint.bind(this)();
	var originalPoint = {x:worldPos.x*originalTileDims[0]/2.0-worldPos.y*originalTileDims[0]/2.0, y:worldPos.x*originalTileDims[1]/2.0+worldPos.y*originalTileDims[1]/2.0};

	//zoom
	var oldZoomFactor = this.zoomFactor;
	this.zoomFactor += deltaZoom;
	while(Math.min(getZoomedTileDims.bind(this)()[0], getZoomedTileDims.bind(this)()[1]) < 8) {
		this.zoomFactor++;
	}
	if(oldZoomFactor == this.zoomFactor) {
		return;
	}

	//update menu
	if(this.menu != null) {
		var originalX = this.menuX-this.camera.x;
		var originalY = this.menuY-this.camera.y;
		this.menuX = (originalX*getZoomedTileDims.bind(this)()[0]/originalTileDims[0]+this.camera.x);
		this.menuY = (originalY*getZoomedTileDims.bind(this)()[1]/originalTileDims[1]+this.camera.y);
		this.menuPaddingH.style.width = Math.max(0, this.menuX+4)+'px';
		this.menuPaddingV.style.height = Math.max(0, this.menuY+4)+'px';
	}

	//update error display
	var errorDisplayDiv = this.errorDisplay.getDiv();
	var originalX = errorDisplayDiv.style.left.replace(/px/g, "")-this.camera.x;
	var originalY = errorDisplayDiv.style.top.replace(/px/g, "")-this.camera.y;
	errorDisplayDiv.style.left = (originalX*getZoomedTileDims.bind(this)()[0]/originalTileDims[0]+this.camera.x)+'px';
	errorDisplayDiv.style.top = (originalY*getZoomedTileDims.bind(this)()[1]/originalTileDims[1]+this.camera.y)+'px';

	//update tile scale & position（chunk 用网格公式；拖动选区画布仍按比例）
	var layers = this.layers.getLayers();
	for(var li = 0; li < layers.length; li++) {
		var layer = layers[li];
		for(var ckey in layer.chunks) {
			layoutChunkCanvasIso.bind(this)(layer.chunks[ckey][0], originalTileDims[0], originalTileDims[1]);
		}
	}
	if(this.selectionCanvas != null && this.tilesDiv.contains(this.selectionCanvas)) {
		var sc = this.selectionCanvas;
		var ox = +sc.style.left.replace(/px/g, "") - this.camera.x;
		var oy = +sc.style.top.replace(/px/g, "") - this.camera.y;
		sc.style.left = (ox * getZoomedTileDims.bind(this)()[0] / originalTileDims[0] + this.camera.x) + 'px';
		sc.style.top = (oy * getZoomedTileDims.bind(this)()[1] / originalTileDims[1] + this.camera.y) + 'px';
		var ow = +sc.style.width.replace(/px/g, "");
		var oh = +sc.style.height.replace(/px/g, "");
		var sw = ow * getZoomedTileDims.bind(this)()[0] / originalTileDims[0];
		var sh = oh * getZoomedTileDims.bind(this)()[1] / originalTileDims[1];
		sc.style.width = sw + 'px';
		sc.style.height = sh + 'px';
		sc.style.backgroundSize = sw + 'px ' + sh + 'px';
	}

	//update region scale & position
	for(var i = 0; i < this.regions.length; i++) {
		var region = this.regions[i];
		var ratio = this.tileSize[1]/this.tileSize[0];
		var borderRadius = Math.floor(2/Math.sqrt((2*ratio*ratio)/(1.0+ratio*ratio)));
		var s = getZoomedTileDims.bind(this)()[0]/Math.sqrt(2);
		var regionBounds = region.region.getBounds();
		var regionDiv = region.div;
		var originalX = regionDiv.style.left.replace(/px/g, "")-this.camera.x+borderRadius;
		var originalY = regionDiv.style.top.replace(/px/g, "")-this.camera.y+borderRadius;
		regionDiv.style.left = (originalX*getZoomedTileDims.bind(this)()[0]/originalTileDims[0]+this.camera.x-borderRadius)+'px';
		regionDiv.style.top = (originalY*getZoomedTileDims.bind(this)()[1]/originalTileDims[1]+this.camera.y-borderRadius)+'px';
		regionDiv.style.width = (s*(regionBounds.x1+1-regionBounds.x0))+'px';
		regionDiv.style.height = (s*(regionBounds.y1+1-regionBounds.y0))+'px';

		regionDiv.childNodes[1].style.maxWidth = ((Math.sqrt(Math.pow(getZoomedTileDims.bind(this)()[0], 2)+Math.pow(getZoomedTileDims.bind(this)()[1], 2))/2.0)*(regionBounds.x1+1-regionBounds.x0)*0.5)+'px';
	}

	//get new data
	var newPoint = {x:(worldPos.x-worldPos.y)*getZoomedTileDims.bind(this)()[0]/2.0, y:(worldPos.x+worldPos.y)*getZoomedTileDims.bind(this)()[1]/2.0};

	updateBackgroundGrid.bind(this)();
	translateCamera.bind(this)(originalPoint.x-newPoint.x, originalPoint.y-newPoint.y);
	buildSelections.bind(this)();
}

var StateEnum = Object.freeze({"NONE":0, "PAN":1, "SELECT":2, "MOVE":3, "ZOOM":4, "MOVE_REG":5, "PICK":6});

class TileGridIsometricView {
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

		this.selectionCanvas = null;

		this.tileDivs = {};
		this.tilesDiv = document.createElement('div');

		var layerDiv = document.createElement('div');
		layerDiv.style.position = "relative";
		layerDiv.style.zIndex = 0;
		this.tilesDiv.appendChild(layerDiv);
		this.layers = new LayerList([{chunks:[], div:layerDiv, tileCallbacks:[], visible:true}]);

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
		firstSelection.setSelection(6, 2, 6, 2);
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
		var originalTileDims = getZoomedTileDims.bind(this)();
		var selectionPoint = this.getSelectionPoint.bind(this)();
		var originalPoint = {x:(selectionPoint.x-selectionPoint.y-1)*originalTileDims[0]/2.0, y:(selectionPoint.x+selectionPoint.y)*originalTileDims[1]/2.0};

		//update tileSize
		this.tileSize = tileSize;
		while(Math.min(getZoomedTileDims.bind(this)()[0], getZoomedTileDims.bind(this)()[1]) < 8) {
			this.zoomFactor++;
		}

		//update menu
		if(this.menu != null) {
			var originalX = this.menuX-this.camera.x;
			var originalY = this.menuY-this.camera.y;
			this.menuX = (originalX*getZoomedTileDims.bind(this)()[0]/originalTileDims[0]+this.camera.x);
			this.menuY = (originalY*getZoomedTileDims.bind(this)()[1]/originalTileDims[1]+this.camera.y);
			this.menuPaddingH.style.width = Math.max(0, this.menuX+4)+'px';
			this.menuPaddingV.style.height = Math.max(0, this.menuY+4)+'px';
		}

		//update error display
		var errorDisplayDiv = this.errorDisplay.getDiv();
		var originalX = errorDisplayDiv.style.left.replace(/px/g, "")-this.camera.x;
		var originalY = errorDisplayDiv.style.top.replace(/px/g, "")-this.camera.y;
		errorDisplayDiv.style.left = (originalX*getZoomedTileDims.bind(this)()[0]/originalTileDims[0]+this.camera.x)+'px';
		errorDisplayDiv.style.top = (originalY*getZoomedTileDims.bind(this)()[1]/originalTileDims[1]+this.camera.y)+'px';

		//update region scale & position
		for(var i = 0; i < this.regions.length; i++) {
			var region = this.regions[i];
			var ratio = this.tileSize[1]/this.tileSize[0];
			var borderRadius = Math.floor(2/Math.sqrt((2*ratio*ratio)/(1.0+ratio*ratio)));
			var s = getZoomedTileDims.bind(this)()[0]/Math.sqrt(2);
			var regionBounds = region.region.getBounds();
			var regionDiv = region.div;
			var originalX = regionDiv.style.left.replace(/px/g, "")-this.camera.x+parseInt(regionDiv.style.borderWidth.replace(/px/g, ""));
			var originalY = regionDiv.style.top.replace(/px/g, "")-this.camera.y+parseInt(regionDiv.style.borderWidth.replace(/px/g, ""));
			regionDiv.style.left = (originalX*getZoomedTileDims.bind(this)()[0]/originalTileDims[0]+this.camera.x-borderRadius)+'px';
			regionDiv.style.top = (originalY*getZoomedTileDims.bind(this)()[1]/originalTileDims[1]+this.camera.y-borderRadius)+'px';
			regionDiv.style.width = (s*(regionBounds.x1+1-regionBounds.x0))+'px';
			regionDiv.style.height = (s*(regionBounds.y1+1-regionBounds.y0))+'px';
			regionDiv.style.transform = "translate(-50%, -50%) translate("+borderRadius+"px, "+borderRadius+"px) scale(1, "+ratio+") rotate(45deg) translate("+(-borderRadius)+"px, "+(-borderRadius)+"px) translate(50%, 50%)";
			regionDiv.style.borderWidth = borderRadius+"px";

			regionDiv.childNodes[0].style.transform = "translate(50%, -50%) rotate(-45deg) scale(1, "+(1.0/ratio)+") rotate("+Math.atan(ratio)+"rad) translate(-50%, 50%)";
			regionDiv.childNodes[0].style.right = (-borderRadius)+"px";
			regionDiv.childNodes[0].style.top = (-borderRadius)+"px";

			regionDiv.childNodes[0].childNodes[0].style.transform = "translate(-0.5px, -0.5px) rotate("+(-Math.atan(ratio))+"rad) translate(0.5px, 0.5px)";

			regionDiv.childNodes[1].style.maxWidth = ((Math.sqrt(Math.pow(getZoomedTileDims.bind(this)()[0], 2)+Math.pow(getZoomedTileDims.bind(this)()[1], 2))/2.0)*(regionBounds.x1+1-regionBounds.x0)*0.5)+'px';
			regionDiv.childNodes[1].style.transform = "translate(-50%, -50%) rotate(-45deg) scale(1, "+(1.0/ratio)+") rotate("+Math.atan(ratio)+"rad) translate(50%, -50%)";
			regionDiv.childNodes[1].style.left = (-borderRadius)+"px";
		}

		//rebuild chunks
		var layers = this.layers.getLayers();
		for(var k = 0; k < layers.length; k++) {
			var layer = layers[k];
			for(var i in layer.chunks) {
				var chunkCanvas = document.createElement('canvas');
				chunkCanvas.className = 'tilegrid-tile-view';
				chunkCanvas.width  = tileSize[0]*chunkSize;
			    chunkCanvas.height = tileSize[1]*chunkSize;
				var prevEl = layer.chunks[i][0];
				chunkCanvas.style.zIndex = prevEl.style.zIndex;
				if(prevEl.dataset.chunkX != null && prevEl.dataset.chunkX !== '') {
					chunkCanvas.dataset.chunkX = prevEl.dataset.chunkX;
					chunkCanvas.dataset.chunkY = prevEl.dataset.chunkY;
					layoutChunkCanvasIso.bind(this)(chunkCanvas, null, null);
				} else {
					var ox = +prevEl.style.left.replace(/px/g, "") - this.camera.x;
					var oy = +prevEl.style.top.replace(/px/g, "") - this.camera.y;
					var dNew = getZoomedTileDims.bind(this)();
					chunkCanvas.style.left = (ox * dNew[0] / originalTileDims[0] + this.camera.x) + 'px';
					chunkCanvas.style.top = (oy * dNew[1] / originalTileDims[1] + this.camera.y) + 'px';
					chunkCanvas.style.width = (chunkSize * dNew[0]) + 'px';
					chunkCanvas.style.height = (chunkSize * dNew[1]) + 'px';
				}
				if(!layer.visible) {
					chunkCanvas.style.visibility = "hidden";
				}
				layer.div.removeChild(layer.chunks[i][0]);
			    layer.div.appendChild(chunkCanvas);
			    layer.chunks[i] = [chunkCanvas, chunkCanvas.getContext('2d')];
			}
		}

		//get new data
		var newPoint = {x:(selectionPoint.x-selectionPoint.y-1)*getZoomedTileDims.bind(this)()[0]/2.0, y:(selectionPoint.x+selectionPoint.y)*getZoomedTileDims.bind(this)()[1]/2.0};

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
			this.menuX = (x+1-y)*getZoomedTileDims.bind(this)()[0]/2.0+this.camera.x;
			this.menuY = (x+1+y)*getZoomedTileDims.bind(this)()[1]/2.0+this.camera.y;
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
		this.errorDisplay.open((x+1-y)*getZoomedTileDims.bind(this)()[0]/2.0+this.camera.x, (x+1+y)*getZoomedTileDims.bind(this)()[1]/2.0+this.camera.y, msgs);
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
		var step = tileSize[0]/tileSize[1];
		this.selectionCanvas = document.createElement('canvas');
		this.selectionCanvas.className = 'tilegrid-tile-view';
		this.selectionCanvas.width  = (selWidth+selHeight)*tileSize[0]/2.0;
	    this.selectionCanvas.height = (selWidth+selHeight)*tileSize[1]/2.0;
		var dS = getZoomedTileDims.bind(this)();
	    this.selectionCanvas.style.left = (Math.round(this.camera.x + (minX - maxY - 1) * dS[0] / 2.0)) + 'px';
		this.selectionCanvas.style.top = (Math.round(this.camera.y + (minX + minY) * dS[1] / 2.0)) + 'px';
		this.selectionCanvas.style.width = ((selWidth + selHeight) * dS[0] / 2.0) + 'px';
		this.selectionCanvas.style.height = ((selWidth + selHeight) * dS[1] / 2.0) + 'px';
		this.selectionCanvas.style.zIndex = z*2+1;
		if(!this.layers.getLayer(z).visible) {
			this.selectionCanvas.style.visibility = "hidden";
		}
		this.tilesDiv.appendChild(this.selectionCanvas);

		var ctx = this.selectionCanvas.getContext('2d');
	    var layer = this.layers.getLayer(z);

	    var clipA = function(ctx, ox, oy) {
	    	ctx.lineTo(tileSize[0]/2+step+ox, 0+oy);
	    }

	    var clipRA = function(ctx, ox, oy) {
	    	clipDelta(ctx, ox, oy);
	    }

	    var clipB = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2-1; i++) {
	    		ctx.lineTo(tileSize[0]/2+(i+1)*step+ox, i+1+oy);
	    		ctx.lineTo(tileSize[0]/2+(i+2)*step+ox, i+1+oy);
	    	}
	    }

	    var clipRB = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2; i++) {
	    		ctx.lineTo(tileSize[0]/2+(i)*step+ox, i+1+oy);
	    		ctx.lineTo(tileSize[0]/2+(i+1)*step+ox, i+1+oy);
	    	}
	    }

	    var clipC = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2-1; i++) {
	    		ctx.lineTo(tileSize[0]-i*step+ox, tileSize[1]/2+1+i+oy);
	    		ctx.lineTo(tileSize[0]-(i+1)*step+ox, tileSize[1]/2+1+i+oy);
	    	}
	    }

	    var clipRC = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2; i++) {
	    		ctx.lineTo(tileSize[0]-i*step+ox, tileSize[1]/2+i+oy);
	    		ctx.lineTo(tileSize[0]-(i+1)*step+ox, tileSize[1]/2+i+oy);
	    	}
	    }

	    var clipD = function(ctx, ox, oy) {
	    	ctx.lineTo(tileSize[0]/2+step+ox, tileSize[1]+oy);
	    }

	    var clipRD = function(ctx, ox, oy) {
	    	clipBeta(ctx, ox, oy);
	    }

	    var clipE = function(ctx, ox, oy) {
	    	ctx.lineTo(tileSize[0]/2-step+ox, tileSize[1]+oy);
	    }

	    var clipRE = function(ctx, ox, oy) {
	    	clipBeta(ctx, ox, oy);
	    }

	    var clipF = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2-1; i++) {
	    		ctx.lineTo(tileSize[0]/2-(i+1)*step+ox, tileSize[1]-i-1+oy);
	    		ctx.lineTo(tileSize[0]/2-(i+2)*step+ox, tileSize[1]-i-1+oy);
	    	}
	    }

	    var clipRF = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2; i++) {
	    		ctx.lineTo(tileSize[0]/2-(i)*step+ox, tileSize[1]-i-1+oy);
	    		ctx.lineTo(tileSize[0]/2-(i+1)*step+ox, tileSize[1]-i-1+oy);
	    	}
	    }

	    var clipG = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2-1; i++) {
	    		ctx.lineTo(i*step+ox, tileSize[1]/2-1-i+oy);
	    		ctx.lineTo((i+1)*step+ox, tileSize[1]/2-1-i+oy);
	    	}
	    }

	    var clipRG = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2; i++) {
	    		ctx.lineTo(i*step+ox, tileSize[1]/2-i+oy);
	    		ctx.lineTo((i+1)*step+ox, tileSize[1]/2-i+oy);
	    	}
	    }

	    var clipH = function(ctx, ox, oy) {
	    	ctx.lineTo(tileSize[0]/2-step+ox, 0+oy);
	    }

	    var clipRH = function(ctx, ox, oy) {
	    	clipDelta(ctx, ox, oy);
	    }

	    var clipAlpha = function(ctx, ox, oy) {
	    	ctx.lineTo(tileSize[0]+ox, tileSize[1]/2+oy);
	    }

	    var clipBeta = function(ctx, ox, oy) {
	    	ctx.lineTo(tileSize[0]/2+ox, tileSize[1]+oy);
	    }

	    var clipGamma = function(ctx, ox, oy) {
	    	ctx.lineTo(0+ox, tileSize[1]/2+oy);
	    }

	    var clipDelta = function(ctx, ox, oy) {
	    	ctx.lineTo(tileSize[0]/2+ox, 0+oy);
	    }

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

						ctx.save();
						ctx2.save();
						ctx.beginPath();
						ctx2.beginPath();
						for(var pi = 0; pi < sw; pi++) {
							//TOP
							var tx = cx*chunkSize+sfx+pi;
							var ty = cy*chunkSize+sfy;

							var ttx = (tx-ty-1)*tileSize[0]/2;
							var tty = (tx+ty)*tileSize[1]/2;
							var srcx = ttx-chunkSize*(cx-cy-1)*tileSize[0]/2;
							var srcy = tty-chunkSize*(cx+cy)*tileSize[1]/2;
							var dstx = ttx-(minX-maxY-1)*tileSize[0]/2;
							var dsty = tty-(minX+minY)*tileSize[1]/2;

							var receded = false;
							if(layer.tileCallbacks[getTileKey(tx, ty)] == null) {
								receded = true;
							}
							if(!receded) {
								clipA(ctx, dstx, dsty);
								clipB(ctx, dstx, dsty);

								clipA(ctx2, srcx, srcy);
								clipB(ctx2, srcx, srcy);
							} else {
								clipRA(ctx, dstx, dsty);
								clipRB(ctx, dstx, dsty);

								clipRA(ctx2, srcx, srcy);
								clipRB(ctx2, srcx, srcy);
							}
							clipAlpha(ctx, dstx, dsty);

							clipAlpha(ctx2, srcx, srcy);
						}
						for(var pi = 0; pi < sh; pi++) {
							//RIGHT
							var tx = cx*chunkSize+sfx+sw-1;
							var ty = cy*chunkSize+sfy+pi;

							var ttx = (tx-ty-1)*tileSize[0]/2;
							var tty = (tx+ty)*tileSize[1]/2;
							var srcx = ttx-chunkSize*(cx-cy-1)*tileSize[0]/2;
							var srcy = tty-chunkSize*(cx+cy)*tileSize[1]/2;
							var dstx = ttx-(minX-maxY-1)*tileSize[0]/2;
							var dsty = tty-(minX+minY)*tileSize[1]/2;

							var receded = false;
							if(layer.tileCallbacks[getTileKey(tx, ty)] == null) {
								receded = true;
							}
							if(!receded) {
								clipC(ctx, dstx, dsty);
								clipD(ctx, dstx, dsty);

								clipC(ctx2, srcx, srcy);
								clipD(ctx2, srcx, srcy);
							} else {
								clipRC(ctx, dstx, dsty);
								clipRD(ctx, dstx, dsty);

								clipRC(ctx2, srcx, srcy);
								clipRD(ctx2, srcx, srcy);
							}
							clipBeta(ctx, dstx, dsty);

							clipBeta(ctx2, srcx, srcy);
						}
						for(var pi = 0; pi < sw; pi++) {
							//BOTTOM
							var tx = cx*chunkSize+sfx+sw-1-pi;
							var ty = cy*chunkSize+sfy+sh-1;

							var ttx = (tx-ty-1)*tileSize[0]/2;
							var tty = (tx+ty)*tileSize[1]/2;
							var srcx = ttx-chunkSize*(cx-cy-1)*tileSize[0]/2;
							var srcy = tty-chunkSize*(cx+cy)*tileSize[1]/2;
							var dstx = ttx-(minX-maxY-1)*tileSize[0]/2;
							var dsty = tty-(minX+minY)*tileSize[1]/2;

							var receded = false;
							if(layer.tileCallbacks[getTileKey(tx, ty)] == null) {
								receded = true;
							}
							if(!receded) {
								clipE(ctx, dstx, dsty);
								clipF(ctx, dstx, dsty);

								clipE(ctx2, srcx, srcy);
								clipF(ctx2, srcx, srcy);
							} else {
								clipRE(ctx, dstx, dsty);
								clipRF(ctx, dstx, dsty);

								clipRE(ctx2, srcx, srcy);
								clipRF(ctx2, srcx, srcy);
							}
							clipGamma(ctx, dstx, dsty);

							clipGamma(ctx2, srcx, srcy);
						}
						for(var pi = 0; pi < sh; pi++) {
							//LEFT
							var tx = cx*chunkSize+sfx;
							var ty = cy*chunkSize+sfy+sh-1-pi;

							var ttx = (tx-ty-1)*tileSize[0]/2;
							var tty = (tx+ty)*tileSize[1]/2;
							var srcx = ttx-chunkSize*(cx-cy-1)*tileSize[0]/2;
							var srcy = tty-chunkSize*(cx+cy)*tileSize[1]/2;
							var dstx = ttx-(minX-maxY-1)*tileSize[0]/2;
							var dsty = tty-(minX+minY)*tileSize[1]/2;

							var receded = false;
							if(layer.tileCallbacks[getTileKey(tx, ty)] == null) {
								receded = true;
							}
							if(!receded) {
								clipG(ctx, dstx, dsty);
								clipH(ctx, dstx, dsty);

								clipG(ctx2, srcx, srcy);
								clipH(ctx2, srcx, srcy);
							} else {
								clipRG(ctx, dstx, dsty);
								clipRH(ctx, dstx, dsty);

								clipRG(ctx2, srcx, srcy);
								clipRH(ctx2, srcx, srcy);
							}
							clipDelta(ctx, dstx, dsty);

							clipDelta(ctx2, srcx, srcy);
						}
						ctx.clip();
						ctx2.clip();
						ctx.drawImage(chunk[0], (sfx-sfy-sh+chunkSize)*tileSize[0]/2.0, (sfx+sfy)*tileSize[1]/2.0, (sw+sh)*tileSize[0]/2.0, (sw+sh)*tileSize[1]/2.0, (dfx-dfy+selHeight-sh)*tileSize[0]/2.0, (dfx+dfy)*tileSize[1]/2.0, (sw+sh)*tileSize[0]/2.0, (sw+sh)*tileSize[1]/2.0);
						ctx2.clearRect((sfx-sfy-sh+chunkSize)*tileSize[0]/2.0, (sfx+sfy)*tileSize[1]/2.0, (sw+sh)*tileSize[0]/2.0, (sw+sh)*tileSize[1]/2.0);
						ctx.restore();
						ctx2.restore();

						/*ctx.save();
						ctx.beginPath();
						ctx.moveTo(tileSize[0]/2.0*(dfx-dfy+selHeight), tileSize[1]/2.0*(dfx+dfy)+1);
						ctx.lineTo(tileSize[0]/2.0*(dfx+sw-dfy+selHeight)-step, tileSize[1]/2.0*(dfx+sw+dfy));
						ctx.lineTo(tileSize[0]/2.0*(dfx+sw-dfy-sh+selHeight), tileSize[1]/2.0*(dfx+sw+dfy+sh)-1);
						ctx.lineTo(tileSize[0]/2.0*(dfx-dfy-sh+selHeight)+step, tileSize[1]/2.0*(dfx+dfy+sh));
						ctx.clip();
						ctx.drawImage(chunk[0], (sfx-sfy-sh+chunkSize)*tileSize[0]/2.0, (sfx+sfy)*tileSize[1]/2.0, (sw+sh)*tileSize[0]/2.0, (sw+sh)*tileSize[1]/2.0, (dfx-dfy+selHeight-sh)*tileSize[0]/2.0, (dfx+dfy)*tileSize[1]/2.0, (sw+sh)*tileSize[0]/2.0, (sw+sh)*tileSize[1]/2.0);
						ctx.restore();
						ctx2.save();
						ctx2.beginPath();
						ctx2.moveTo(tileSize[0]/2.0*(sfx-sfy+chunkSize), tileSize[1]/2.0*(sfx+sfy)+1);
						ctx2.lineTo(tileSize[0]/2.0*(sfx+sw-sfy+chunkSize)-step, tileSize[1]/2.0*(sfx+sw+sfy));
						ctx2.lineTo(tileSize[0]/2.0*(sfx+sw-sfy-sh+chunkSize), tileSize[1]/2.0*(sfx+sw+sfy+sh)-1);
						ctx2.lineTo(tileSize[0]/2.0*(sfx-sfy-sh+chunkSize)+step, tileSize[1]/2.0*(sfx+sfy+sh));
						ctx2.clip();
						ctx2.clearRect((sfx-sfy-sh+chunkSize)*tileSize[0]/2.0, (sfx+sfy)*tileSize[1]/2.0, (sw+sh)*tileSize[0]/2.0, (sw+sh)*tileSize[1]/2.0);
						ctx2.restore();*/
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
		var step = tileSize[0]/tileSize[1];
		this.selectionCanvas = document.createElement('canvas');
		this.selectionCanvas.className = 'tilegrid-tile-view';
		this.selectionCanvas.width  = (selWidth+selHeight)*tileSize[0]/2.0;
	    this.selectionCanvas.height = (selWidth+selHeight)*tileSize[1]/2.0;
		var dS = getZoomedTileDims.bind(this)();
	    this.selectionCanvas.style.left = (Math.round(this.camera.x + (minX - maxY - 1) * dS[0] / 2.0)) + 'px';
		this.selectionCanvas.style.top = (Math.round(this.camera.y + (minX + minY) * dS[1] / 2.0)) + 'px';
		this.selectionCanvas.style.width = ((selWidth + selHeight) * dS[0] / 2.0) + 'px';
		this.selectionCanvas.style.height = ((selWidth + selHeight) * dS[1] / 2.0) + 'px';
		this.selectionCanvas.style.zIndex = z*2+1;
		if(!this.layers.getLayer(z).visible) {
			this.selectionCanvas.style.visibility = "hidden";
		}
		this.tilesDiv.appendChild(this.selectionCanvas);

		var ctx = this.selectionCanvas.getContext('2d');
	    var layer = this.layers.getLayer(z);

	    var clipA = function(ctx, ox, oy) {
	    	ctx.lineTo(tileSize[0]/2+step+ox, 0+oy);
	    }

	    var clipRA = function(ctx, ox, oy) {
	    	clipDelta(ctx, ox, oy);
	    }

	    var clipB = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2-1; i++) {
	    		ctx.lineTo(tileSize[0]/2+(i+1)*step+ox, i+1+oy);
	    		ctx.lineTo(tileSize[0]/2+(i+2)*step+ox, i+1+oy);
	    	}
	    }

	    var clipRB = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2; i++) {
	    		ctx.lineTo(tileSize[0]/2+(i)*step+ox, i+1+oy);
	    		ctx.lineTo(tileSize[0]/2+(i+1)*step+ox, i+1+oy);
	    	}
	    }

	    var clipC = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2-1; i++) {
	    		ctx.lineTo(tileSize[0]-i*step+ox, tileSize[1]/2+1+i+oy);
	    		ctx.lineTo(tileSize[0]-(i+1)*step+ox, tileSize[1]/2+1+i+oy);
	    	}
	    }

	    var clipRC = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2; i++) {
	    		ctx.lineTo(tileSize[0]-i*step+ox, tileSize[1]/2+i+oy);
	    		ctx.lineTo(tileSize[0]-(i+1)*step+ox, tileSize[1]/2+i+oy);
	    	}
	    }

	    var clipD = function(ctx, ox, oy) {
	    	ctx.lineTo(tileSize[0]/2+step+ox, tileSize[1]+oy);
	    }

	    var clipRD = function(ctx, ox, oy) {
	    	clipBeta(ctx, ox, oy);
	    }

	    var clipE = function(ctx, ox, oy) {
	    	ctx.lineTo(tileSize[0]/2-step+ox, tileSize[1]+oy);
	    }

	    var clipRE = function(ctx, ox, oy) {
	    	clipBeta(ctx, ox, oy);
	    }

	    var clipF = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2-1; i++) {
	    		ctx.lineTo(tileSize[0]/2-(i+1)*step+ox, tileSize[1]-i-1+oy);
	    		ctx.lineTo(tileSize[0]/2-(i+2)*step+ox, tileSize[1]-i-1+oy);
	    	}
	    }

	    var clipRF = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2; i++) {
	    		ctx.lineTo(tileSize[0]/2-(i)*step+ox, tileSize[1]-i-1+oy);
	    		ctx.lineTo(tileSize[0]/2-(i+1)*step+ox, tileSize[1]-i-1+oy);
	    	}
	    }

	    var clipG = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2-1; i++) {
	    		ctx.lineTo(i*step+ox, tileSize[1]/2-1-i+oy);
	    		ctx.lineTo((i+1)*step+ox, tileSize[1]/2-1-i+oy);
	    	}
	    }

	    var clipRG = function(ctx, ox, oy) {
	    	for(var i = 0; i < tileSize[1]/2; i++) {
	    		ctx.lineTo(i*step+ox, tileSize[1]/2-i+oy);
	    		ctx.lineTo((i+1)*step+ox, tileSize[1]/2-i+oy);
	    	}
	    }

	    var clipH = function(ctx, ox, oy) {
	    	ctx.lineTo(tileSize[0]/2-step+ox, 0+oy);
	    }

	    var clipRH = function(ctx, ox, oy) {
	    	clipDelta(ctx, ox, oy);
	    }

	    var clipAlpha = function(ctx, ox, oy) {
	    	ctx.lineTo(tileSize[0]+ox, tileSize[1]/2+oy);
	    }

	    var clipBeta = function(ctx, ox, oy) {
	    	ctx.lineTo(tileSize[0]/2+ox, tileSize[1]+oy);
	    }

	    var clipGamma = function(ctx, ox, oy) {
	    	ctx.lineTo(0+ox, tileSize[1]/2+oy);
	    }

	    var clipDelta = function(ctx, ox, oy) {
	    	ctx.lineTo(tileSize[0]/2+ox, 0+oy);
	    }

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
					var dfx = cx*chunkSize-minX+sfx;
					var dfy = cy*chunkSize-minY+sfy;

					ctx.save();
					ctx2.save();
					ctx.beginPath();
					ctx2.beginPath();
					for(var pi = 0; pi < sw; pi++) {
						//TOP
						var tx = cx*chunkSize+sfx+pi;
						var ty = cy*chunkSize+sfy;

						var ttx = (tx-ty-1)*tileSize[0]/2;
						var tty = (tx+ty)*tileSize[1]/2;
						var srcx = ttx-chunkSize*(cx-cy-1)*tileSize[0]/2;
						var srcy = tty-chunkSize*(cx+cy)*tileSize[1]/2;
						var dstx = ttx-(minX-maxY-1)*tileSize[0]/2;
						var dsty = tty-(minX+minY)*tileSize[1]/2;

						var receded = false;
						if(layer.tileCallbacks[getTileKey(tx, ty)] == null) {
							receded = true;
						}
						if(!receded) {
							clipA(ctx, dstx, dsty);
							clipB(ctx, dstx, dsty);

							clipA(ctx2, srcx, srcy);
							clipB(ctx2, srcx, srcy);
						} else {
							clipRA(ctx, dstx, dsty);
							clipRB(ctx, dstx, dsty);

							clipRA(ctx2, srcx, srcy);
							clipRB(ctx2, srcx, srcy);
						}
						clipAlpha(ctx, dstx, dsty);

						clipAlpha(ctx2, srcx, srcy);
					}
					for(var pi = 0; pi < sh; pi++) {
						//RIGHT
						var tx = cx*chunkSize+sfx+sw-1;
						var ty = cy*chunkSize+sfy+pi;

						var ttx = (tx-ty-1)*tileSize[0]/2;
						var tty = (tx+ty)*tileSize[1]/2;
						var srcx = ttx-chunkSize*(cx-cy-1)*tileSize[0]/2;
						var srcy = tty-chunkSize*(cx+cy)*tileSize[1]/2;
						var dstx = ttx-(minX-maxY-1)*tileSize[0]/2;
						var dsty = tty-(minX+minY)*tileSize[1]/2;

						var receded = false;
						if(layer.tileCallbacks[getTileKey(tx, ty)] == null) {
							receded = true;
						}
						if(!receded) {
							clipC(ctx, dstx, dsty);
							clipD(ctx, dstx, dsty);

							clipC(ctx2, srcx, srcy);
							clipD(ctx2, srcx, srcy);
						} else {
							clipRC(ctx, dstx, dsty);
							clipRD(ctx, dstx, dsty);

							clipRC(ctx2, srcx, srcy);
							clipRD(ctx2, srcx, srcy);
						}
						clipBeta(ctx, dstx, dsty);

						clipBeta(ctx2, srcx, srcy);
					}
					for(var pi = 0; pi < sw; pi++) {
						//BOTTOM
						var tx = cx*chunkSize+sfx+sw-1-pi;
						var ty = cy*chunkSize+sfy+sh-1;

						var ttx = (tx-ty-1)*tileSize[0]/2;
						var tty = (tx+ty)*tileSize[1]/2;
						var srcx = ttx-chunkSize*(cx-cy-1)*tileSize[0]/2;
						var srcy = tty-chunkSize*(cx+cy)*tileSize[1]/2;
						var dstx = ttx-(minX-maxY-1)*tileSize[0]/2;
						var dsty = tty-(minX+minY)*tileSize[1]/2;

						var receded = false;
						if(layer.tileCallbacks[getTileKey(tx, ty)] == null) {
							receded = true;
						}
						if(!receded) {
							clipE(ctx, dstx, dsty);
							clipF(ctx, dstx, dsty);

							clipE(ctx2, srcx, srcy);
							clipF(ctx2, srcx, srcy);
						} else {
							clipRE(ctx, dstx, dsty);
							clipRF(ctx, dstx, dsty);

							clipRE(ctx2, srcx, srcy);
							clipRF(ctx2, srcx, srcy);
						}
						clipGamma(ctx, dstx, dsty);

						clipGamma(ctx2, srcx, srcy);
					}
					for(var pi = 0; pi < sh; pi++) {
						//LEFT
						var tx = cx*chunkSize+sfx;
						var ty = cy*chunkSize+sfy+sh-1-pi;

						var ttx = (tx-ty-1)*tileSize[0]/2;
						var tty = (tx+ty)*tileSize[1]/2;
						var srcx = ttx-chunkSize*(cx-cy-1)*tileSize[0]/2;
						var srcy = tty-chunkSize*(cx+cy)*tileSize[1]/2;
						var dstx = ttx-(minX-maxY-1)*tileSize[0]/2;
						var dsty = tty-(minX+minY)*tileSize[1]/2;

						var receded = false;
						if(layer.tileCallbacks[getTileKey(tx, ty)] == null) {
							receded = true;
						}
						if(!receded) {
							clipG(ctx, dstx, dsty);
							clipH(ctx, dstx, dsty);

							clipG(ctx2, srcx, srcy);
							clipH(ctx2, srcx, srcy);
						} else {
							clipRG(ctx, dstx, dsty);
							clipRH(ctx, dstx, dsty);

							clipRG(ctx2, srcx, srcy);
							clipRH(ctx2, srcx, srcy);
						}
						clipDelta(ctx, dstx, dsty);

						clipDelta(ctx2, srcx, srcy);
					}
					ctx.clip();
					ctx2.clip();
					ctx.drawImage(chunk[0], (sfx-sfy-sh+chunkSize)*tileSize[0]/2.0, (sfx+sfy)*tileSize[1]/2.0, (sw+sh)*tileSize[0]/2.0, (sw+sh)*tileSize[1]/2.0, (dfx-dfy+selHeight-sh)*tileSize[0]/2.0, (dfx+dfy)*tileSize[1]/2.0, (sw+sh)*tileSize[0]/2.0, (sw+sh)*tileSize[1]/2.0);
					ctx2.clearRect((sfx-sfy-sh+chunkSize)*tileSize[0]/2.0, (sfx+sfy)*tileSize[1]/2.0, (sw+sh)*tileSize[0]/2.0, (sw+sh)*tileSize[1]/2.0);
					ctx.restore();
					ctx2.restore();

					/*ctx.save();
					ctx.beginPath();
					ctx.moveTo(tileSize[0]/2.0*(dfx-dfy+selHeight), tileSize[1]/2.0*(dfx+dfy)+1);
					ctx.lineTo(tileSize[0]/2.0*(dfx+sw-dfy+selHeight)-step, tileSize[1]/2.0*(dfx+sw+dfy));
					ctx.lineTo(tileSize[0]/2.0*(dfx+sw-dfy-sh+selHeight), tileSize[1]/2.0*(dfx+sw+dfy+sh)-1);
					ctx.lineTo(tileSize[0]/2.0*(dfx-dfy-sh+selHeight)+step, tileSize[1]/2.0*(dfx+dfy+sh));
					ctx.clip();
					ctx.drawImage(chunk[0], (sfx-sfy-sh+chunkSize)*tileSize[0]/2.0, (sfx+sfy)*tileSize[1]/2.0, (sw+sh)*tileSize[0]/2.0, (sw+sh)*tileSize[1]/2.0, (dfx-dfy+selHeight-sh)*tileSize[0]/2.0, (dfx+dfy)*tileSize[1]/2.0, (sw+sh)*tileSize[0]/2.0, (sw+sh)*tileSize[1]/2.0);
					ctx.restore();
					ctx2.save();
					ctx2.beginPath();
					ctx2.moveTo(tileSize[0]/2.0*(sfx-sfy+chunkSize), tileSize[1]/2.0*(sfx+sfy)+1);
					ctx2.lineTo(tileSize[0]/2.0*(sfx+sw-sfy+chunkSize)-step, tileSize[1]/2.0*(sfx+sw+sfy));
					ctx2.lineTo(tileSize[0]/2.0*(sfx+sw-sfy-sh+chunkSize), tileSize[1]/2.0*(sfx+sw+sfy+sh)-1);
					ctx2.lineTo(tileSize[0]/2.0*(sfx-sfy-sh+chunkSize)+step, tileSize[1]/2.0*(sfx+sfy+sh));
					ctx2.clip();
					ctx2.clearRect((sfx-sfy-sh+chunkSize)*tileSize[0]/2.0, (sfx+sfy)*tileSize[1]/2.0, (sw+sh)*tileSize[0]/2.0, (sw+sh)*tileSize[1]/2.0);
					ctx2.restore();*/
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
		var ratio = this.tileSize[1]/this.tileSize[0];
		var borderRadius = Math.floor(2/Math.sqrt((2*ratio*ratio)/(1.0+ratio*ratio)));
		var s = getZoomedTileDims.bind(this)()[0]/Math.sqrt(2);
		var regionBounds = region.getBounds();
		regionDiv.style.left = (this.camera.x+getZoomedTileDims.bind(this)()[0]/2.0*(regionBounds.x0-regionBounds.y0)-borderRadius)+'px';
		regionDiv.style.top = (this.camera.y+getZoomedTileDims.bind(this)()[1]/2.0*(regionBounds.x0+regionBounds.y0)-borderRadius)+'px';
		regionDiv.style.width = (s*(regionBounds.x1+1-regionBounds.x0))+'px';
		regionDiv.style.height = (s*(regionBounds.y1+1-regionBounds.y0))+'px';
		regionDiv.style.borderColor = regionColor;
		regionDiv.style.transform = "translate(-50%, -50%) translate("+borderRadius+"px, "+borderRadius+"px) scale(1, "+ratio+") rotate(45deg) translate("+(-borderRadius)+"px, "+(-borderRadius)+"px) translate(50%, 50%)";
		regionDiv.style.borderWidth = borderRadius+"px";
		this.regionsDiv.appendChild(regionDiv);

		var regionButtonDiv = document.createElement('div');
		regionButtonDiv.className = "tilegrid-regionbutton-view";
		//regionButtonDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_a.png')";
		regionButtonDiv.style.transform = "translate(50%, -50%) rotate(-45deg) scale(1, "+(1.0/ratio)+") rotate("+Math.atan(ratio)+"rad) translate(-50%, 50%)";
		regionButtonDiv.style.borderRadius = "0px 2px 7px 7px";
		regionButtonDiv.style.right = (-borderRadius)+"px";
		regionButtonDiv.style.top = (-borderRadius)+"px";
		regionButtonDiv.style.borderRadius = "0px 2px 7px 7px";
		regionButtonDiv.style.backgroundColor = regionColor;
		var regionButtonBgDiv = document.createElement('div');
		regionButtonBgDiv.style.width = "100%";
		regionButtonBgDiv.style.height = "100%";
		regionButtonBgDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_a.png')";
		regionButtonBgDiv.style.backgroundRepeat = "no-repeat";
		regionButtonBgDiv.style.backgroundPosition = "center";
		regionButtonBgDiv.style.transform = "translate(-0.5px, -0.5px) rotate("+(-Math.atan(ratio))+"rad) translate(0.5px, 0.5px)";
		regionButtonDiv.appendChild(regionButtonBgDiv);
		regionDiv.appendChild(regionButtonDiv);

		plh.applyPointerLock(regionButtonDiv, function() {
			plh.lockPointer();
			if(region.isValid()) {
				regionButtonBgDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_b.png')";
			} else {
				regionButtonBgDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_d.png')";
			}
		}.bind(this), null, function() {
			this.regionRemovedCallback.notify(region);
		}.bind(this));

		var regionLabelDiv = document.createElement('div');
		regionLabelDiv.className = "tilegrid-regionlabel-view";
		regionLabelDiv.innerHTML = region.getLabel();
		regionLabelDiv.style.maxWidth = ((Math.sqrt(Math.pow(getZoomedTileDims.bind(this)()[0], 2)+Math.pow(getZoomedTileDims.bind(this)()[1], 2))/2.0)*(regionBounds.x1+1-regionBounds.x0)*0.5)+'px';
		regionLabelDiv.style.backgroundColor = regionColor;
		regionLabelDiv.style.transform = "translate(-50%, -50%) rotate(-45deg) scale(1, "+(1.0/ratio)+") rotate("+Math.atan(ratio)+"rad) translate(50%, -50%)";
		regionLabelDiv.style.left = (-borderRadius)+"px";
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
				var ratio = this.tileSize[1]/this.tileSize[0];
				var borderRadius = Math.floor(2/Math.sqrt((2*ratio*ratio)/(1.0+ratio*ratio)));
				var s = getZoomedTileDims.bind(this)()[0]/Math.sqrt(2);
				var regionBounds = region.getBounds();
				regionDiv.style.left = (this.camera.x+getZoomedTileDims.bind(this)()[0]/2.0*(regionBounds.x0-regionBounds.y0)-borderRadius)+'px';
				regionDiv.style.top = (this.camera.y+getZoomedTileDims.bind(this)()[1]/2.0*(regionBounds.x0+regionBounds.y0)-borderRadius)+'px';
				regionDiv.style.width = (s*(regionBounds.x1+1-regionBounds.x0))+'px';
				regionDiv.style.height = (s*(regionBounds.y1+1-regionBounds.y0))+'px';
				break;
			}
		}
	}

	addLayer(z, visible) {
		var layers = this.layers.getLayers();
		for(var i = z; i < layers.length; i++) {
			var layer = layers[i];
			layer.div.style.zIndex = (i+1)*2;
		}
		var layerDiv = document.createElement('div');
		layerDiv.style.position = "relative";
		layerDiv.style.zIndex = z*2;
		this.tilesDiv.appendChild(layerDiv);
		this.layers.insertLayer({chunks:[], div:layerDiv, tileCallbacks:[], visible:visible}, z);
	}

	removeLayer(z) {
		var layers = this.layers.getLayers();
		for(var i = z+1; i < layers.length; i++) {
			var layer = layers[i];
			layer.div.style.zIndex = (i-1)*2;
		}
		var layer = layers[z];
		this.tilesDiv.removeChild(layer.div);
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
			layer.div.style.zIndex = (i-1)*2;
		}
		for(var i = z-1; i >= newZ; i--) {
			var layer = layers[i];
			layer.div.style.zIndex = (i+1)*2;
		}
		var movedLayer = layers[z];
		movedLayer.div.style.zIndex = (newZ)*2;
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
module.exports = TileGridIsometricView;
