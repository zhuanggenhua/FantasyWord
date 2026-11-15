var PropertyRelationView = require('./PropertyRelationView.js');
var plh = require('./PointerLockHandler.js');
var CallbackManager = require('./CallbackManager.js');

var TileRelationProp = require('./TileRelationProp.js');
var TileRelationPropBackground = require('./TileRelationPropBackground.js');

var loadDisplay = function() {
	for(var i in this.tileContentCallbacks) {
		this.tileContentCallbacks[i][0].contentUpdatedUnsubscribe(this.tileContentCallbacks[i][1]);
	}
	this.tileContentCallbacks = [];

	this.displayContainerDiv.innerHTML = "";

	//get components
	var slots = [{t:this.tile, x:0, y:0}];
	var tRel = this.tile.getRelations();
	for(var i in tRel) {
		var rel = tRel[i];
		if(rel.r instanceof TileRelationProp) {
			if(rel.t != false) {
				slots.push({t:rel.t, x:rel.r.pos.x, y:rel.r.pos.y});
			}
		}
	}

	//place slots
	var slotSize = 16;
	var slotSpacing = 1;
	var ratio = 1;

	var iso = false;
	var tileShape = tileroninX.getTileShape();
	if(tileShape == tileroninX.Shape.ISOMETRIC) {
		var tileSize = tileroninX.getTileSize();
		iso = true;
		ratio = tileSize[0]/tileSize[1];
	}

	//get offset
	var minX = 0;
	var minY = 0;
	var maxX = 0;
	var maxY = 0;
	var isoMinX = 0;
	var isoMinY = 0;
	var isoMaxX = 0;
	var isoMaxY = 0;
	for(var i = 0; i < slots.length; i++) {
		var slot = slots[i];
		if(slot.x < minX) {
			minX = slot.x;
		} else if(slot.x > maxX) {
			maxX = slot.x;
		}
		if(slot.y < minY) {
			minY = slot.y;
		} else if(slot.y > maxY) {
			maxY = slot.y;
		}
		var isoX = (slot.x-slot.y)*(slotSize*ratio/2+slotSpacing*ratio);
		var isoY = (slot.x+slot.y)*(slotSize/2+slotSpacing);
		if(isoX-slotSize*ratio/2 < isoMinX || i == 0) {
			isoMinX = isoX-slotSize*ratio/2;
		}
		if(isoX+slotSize*ratio/2 > isoMaxX || i == 0) {
			isoMaxX = isoX+slotSize*ratio/2;
		}
		if(isoY < isoMinY || i == 0) {
			isoMinY = isoY;
		}
		if(isoY+slotSize > isoMaxY || i == 0) {
			isoMaxY = isoY+slotSize;
		}
	}

	this.displayContainerDiv.style.width = (maxX-minX+1)*(slotSize+slotSpacing)-slotSpacing+'px';
	this.displayContainerDiv.style.height = (maxY-minY+1)*(slotSize+slotSpacing)-slotSpacing+'px';
	if(iso) {
		this.displayContainerDiv.style.width = (isoMaxX-isoMinX)+'px';
		this.displayContainerDiv.style.height = (isoMaxY-isoMinY)+'px';
	}

	for(var i in slots) {
		var slot = slots[i];
		(function a(slot) {
			var slotX = (slot.x-minX)*(slotSize+slotSpacing);
			var slotY = (slot.y-minY)*(slotSize+slotSpacing);
			if(iso) {
				slotX = (slot.x-slot.y)*(slotSize*ratio/2+slotSpacing*ratio)-isoMinX;
				slotY = (slot.x+slot.y)*(slotSize/2+slotSpacing)-isoMinY;
			}

			var slotDisplay = document.createElement('div');
			slotDisplay.className = "propertyrelationblob-tile-image-rule-view";
			slotDisplay.style.left = slotX+'px';
			slotDisplay.style.top = slotY+'px';
			slotDisplay.style.borderRadius = "0px";
			var slotDisplay2 = document.createElement('div');
			slotDisplay2.className = "propertyrelationblob-tile-image-rule-view-display";
			slotDisplay.appendChild(slotDisplay2);
			this.displayContainerDiv.appendChild(slotDisplay);
			if(iso) {
				slotDisplay.style.transform = "translateX(-50%) translateY(-50%) scale("+ratio+", 1) rotate(45deg) translateX(50%) translateY(50%)";

				slotDisplay2.style.transform = "translate(-50%, -50%) rotate(-45deg)";
				slotDisplay2.style.left = "50%";
				slotDisplay2.style.top = "50%";
				slotDisplay.style.width = (16/Math.sqrt(2))+"px";
				slotDisplay.style.height = slotDisplay.style.width;
			}

			var tileSlotUpdateImage = function() {
				slot.t.getImage().then(function(img) {
					var downscale = document.createElement("canvas");
					downscale.height = 48;
					downscale.width = 48;
					var ctx = downscale.getContext("2d");
					ctx.imageSmoothingEnabled = false;
					ctx.webkitImageSmoothingEnabled = false;
					ctx.mozImageSmoothingEnabled = false;

					ctx.drawImage(img, 0, 0, 48, 48);

					slotDisplay2.style.backgroundImage = 'url(\"'+downscale.toDataURL()+'\")';
				}.bind(this));
			}.bind(this)
			tileSlotUpdateImage();
			slot.t.contentUpdatedSubscribe(tileSlotUpdateImage);
			this.tileContentCallbacks.push([slot.t, tileSlotUpdateImage]);
		}.bind(this))(slot);
	}

	var bgTile = null;
	for(var i in tRel) {
		var rel = tRel[i];
		if(rel.r instanceof TileRelationPropBackground) {
			bgTile = rel.t;
			break;
		}
	}
	if(bgTile != null) {
		var tileSlotBgUpdateImage = function() {
			bgTile.getImage().then(function(img) {
				var downscale = document.createElement("canvas");
				downscale.height = 96;
				downscale.width = 96;
				var ctx = downscale.getContext("2d");
				ctx.imageSmoothingEnabled = false;
				ctx.webkitImageSmoothingEnabled = false;
				ctx.mozImageSmoothingEnabled = false;

				ctx.drawImage(img, 0, 0, 96, 96);

				this.bgSlotDisplay.style.backgroundImage = 'url(\"'+downscale.toDataURL()+'\")';
			}.bind(this));
		}.bind(this)
		tileSlotBgUpdateImage();
		bgTile.contentUpdatedSubscribe(tileSlotBgUpdateImage);
		this.tileContentCallbacks.push([bgTile, tileSlotBgUpdateImage]);
	} else {
		this.bgSlotDisplay.style.backgroundImage = 'none';
	}
}

class PropertyRelationPropView extends PropertyRelationView {
	constructor(tile) {
		super("Prop");

		this.tile = tile;
		this.selectedTile = false;
		this.tileContentCallbacks = [];
		this.relationsUpdatedCallback = function() {
			loadDisplay.bind(this)();
		}.bind(this);
		this.tile.relationsUpdatedSubscribe(this.relationsUpdatedCallback);

		tileroninX.tileSizeChangedSubscribe(function() {
			if(tileroninX.getTileShape() == tileroninX.Shape.ISOMETRIC) {
				loadDisplay.bind(this)();
			}
		}.bind(this));

		this.propUngroupedCallback = new CallbackManager();
		this.slotClickedCallback = new CallbackManager();

		this.contentDiv.style.display = "flex";
		this.contentDiv.style.height = "252px";
		this.contentDiv.style.flexDirection = "column";

		this.contentDiv.children.item(0).style.zIndex = 1;

		var propContainerDiv = document.createElement('div');
		propContainerDiv.className = "propertyrelationprop-prop-container-view";
		propContainerDiv.style.overflow = "hidden";
		propContainerDiv.style.margin = "4px";
		propContainerDiv.style.height = "144px";
		this.contentDiv.appendChild(propContainerDiv);

		this.displayContainerDiv = document.createElement('div');
		this.displayContainerDiv.className = "propertyrelationblob-rule-container-view";
		propContainerDiv.appendChild(this.displayContainerDiv);

		var ungroupDiv = document.createElement('div');
		ungroupDiv.className = "propertyrelationprop-remove-view";
		ungroupDiv.style.marginLeft = '6px';
		ungroupDiv.style.top = '4px';
		ungroupDiv.style.right = '4px';
		ungroupDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_b.png')";
		propContainerDiv.appendChild(ungroupDiv);

		plh.applyPointerLock(ungroupDiv, function() {
			if(this.selectedTile) {
				return;
			}
			plh.lockPointer();
			this.errorDisplay.close();
			ungroupDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_c.png')";
		}.bind(this), null, function() {
			if(this.selectedTile) {
				return;
			}
			ungroupDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_b.png')";
			this.propUngroupedCallback.notify();
		}.bind(this));

		var bgContainerDiv = document.createElement('div');
		bgContainerDiv.className = "propertyrelationprop-bg-container-view";
		this.contentDiv.appendChild(bgContainerDiv);

		var bgText = document.createElement('div');
		bgText.className = "propertyrelation-text-view";
		bgText.innerHTML = "Prop Medium";
		bgContainerDiv.appendChild(bgText);

		var ruleContainer = document.createElement('div');
		ruleContainer.className = "propertyrelationblob-rule-container-view";
		bgContainerDiv.appendChild(ruleContainer);

		var iso = false;
		var tileShape = tileroninX.getTileShape();
		if(tileShape == tileroninX.Shape.ISOMETRIC) {
			var tileSize = tileroninX.getTileSize();
			iso = true;
			var ratio = tileSize[1]/tileSize[0];
			ruleContainer.style.transform = "translateX(-50%) translateY(-50%) rotate(45deg)";
		}

		this.bgSlot = document.createElement('div');
		this.bgSlot.className = "propertyrelationblob-tile-image-rule-large-view";
		this.bgSlot.style.left = '44px';
		this.bgSlot.style.top = '44px';
		this.bgSlotDisplay = document.createElement('div');
		this.bgSlotDisplay.className = "propertyrelationblob-tile-image-rule-large-view-display";
		this.bgSlot.appendChild(this.bgSlotDisplay);
		ruleContainer.appendChild(this.bgSlot);

		var bgSlotHighlight = document.createElement('div');
		bgSlotHighlight.className = "propertyrelationblob-tile-highlight-view";
		bgSlotHighlight.style.left = '0px';
		bgSlotHighlight.style.top = '0px';
		this.bgSlot.appendChild(bgSlotHighlight);

		var bgSlotSelect = document.createElement('div');
		bgSlotSelect.className = "propertyrelationblob-tile-image-rule-large-select-view";
		bgSlotSelect.style.left = '-2px';
		bgSlotSelect.style.top = '-2px';
		this.bgSlot.appendChild(bgSlotSelect);
		if(iso) {
			this.bgSlotDisplay.style.transform = "translate(-50%, -50%) rotate(-45deg)";
			this.bgSlotDisplay.style.left = "50%";
			this.bgSlotDisplay.style.top = "50%";
			this.bgSlot.style.width = (32/Math.sqrt(2))+"px";
			this.bgSlot.style.height = this.bgSlot.style.width;
			bgSlotHighlight.style.width = this.bgSlot.style.width;
			bgSlotHighlight.style.height = this.bgSlot.style.width;
			bgSlotSelect.style.width = (32/Math.sqrt(2)+4)+"px";
			bgSlotSelect.style.height = bgSlotSelect.style.width;
			this.bgSlot.style.left = (60-(32/Math.sqrt(2))/2)+'px';
			this.bgSlot.style.top = this.bgSlot.style.left;
		}

		plh.applyPointerLock(this.bgSlot, function() {
			plh.lockPointer();
			this.errorDisplay.close();
			bgSlotSelect.style.visibility = 'visible';
		}.bind(this), null, function() {
			bgSlotSelect.style.visibility = 'hidden';
			bgSlotHighlight.style.visibility = 'visible';
			this.bgSlot.style.visibility = 'hidden';
			this.selectedTile = true;
			this.slotClickedCallback.notify(function(tile) {
				bgSlotHighlight.style.visibility = 'hidden';
				this.bgSlot.style.visibility = 'visible';
				if(tile != false) {
					var undoGroup = [];
					var errorGroup = [];
					tileroninX.setPropBackground(this.tile, tile, undoGroup, errorGroup);
					tileroninX.saveUndoState(undoGroup);
					if(errorGroup.length > 0) {
						this.errorDisplay.open(0, 0, errorGroup);
					}
					this.selectedTile = false;
				}
			}.bind(this))
		}.bind(this));

		loadDisplay.bind(this)();
	}

	getDiv() {
		return this.div;
	}

	propUngroupedSubscribe(func) {
		this.propUngroupedCallback.subscribe(func);
	}

	slotClickedSubscribe(func) {
		this.slotClickedCallback.subscribe(func);
	}

	clearCallbacks() {
		this.tile.relationsUpdatedUnsubscribe(this.relationsUpdatedCallback);

		for(var i in this.tileContentCallbacks) {
			this.tileContentCallbacks[i][0].contentUpdatedUnsubscribe(this.tileContentCallbacks[i][1]);
		}
		this.tileContentCallbacks = [];
	}
}
module.exports = PropertyRelationPropView;