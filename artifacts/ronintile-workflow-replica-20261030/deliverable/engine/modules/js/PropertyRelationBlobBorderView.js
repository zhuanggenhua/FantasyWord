var PropertyRelationView = require('./PropertyRelationView.js');
var plh = require('./PointerLockHandler.js');
var CallbackManager = require('./CallbackManager.js');

var TileRelationBlobBorder = require('./TileRelationBlobBorder.js');

var loadRuleGrid = function() {
	var ruleTiles = null;
	var other = null;
	var rel = this.tile.getRelations();
	for(var i in rel) {
		var r = rel[i];
		if(r.r instanceof TileRelationBlobBorder && r.r.isBorder) {
			ruleTiles = r.r.getIndexMatrix();
			other = r.t;
			break;
		}
	}

	for(var i in this.tileContentRuleCallbacks) {
		this.tileContentRuleCallbacks[i][0].contentUpdatedUnsubscribe(this.tileContentRuleCallbacks[i][1]);
	}
	this.tileContentRuleCallbacks = [];

	if(ruleTiles == null) {
		return;
	}

	for(var i in ruleTiles) {
		(function a(i) {
			var t = ruleTiles[i];
			if(t != false && t != null) {
				var tileSlotUpdateImage = function() {
					t.getImage().then(function(img) {
						var downscale = document.createElement("canvas");
						downscale.height = 48;
						downscale.width = 48;
						var ctx = downscale.getContext("2d");
						ctx.imageSmoothingEnabled = false;
						ctx.webkitImageSmoothingEnabled = false;
						ctx.mozImageSmoothingEnabled = false;

						ctx.drawImage(img, 0, 0, 48, 48);

						this.adjacentSlotDisplays[i].style.backgroundColor = "transparent";
						this.adjacentSlotDisplays[i].style.backgroundImage = 'url(\"'+downscale.toDataURL()+'\")';
						this.adjacentSlotDisplays[i].style.borderStyle = "none";
					}.bind(this));
				}.bind(this)
				tileSlotUpdateImage();
				t.contentUpdatedSubscribe(tileSlotUpdateImage);
				this.tileContentRuleCallbacks.push([t, tileSlotUpdateImage]);
			} else {
				this.adjacentSlotDisplays[i].style.backgroundColor = "var(--colorBG)";
				this.adjacentSlotDisplays[i].style.backgroundImage = "url('../res/icon/ui_icon_other.png')";
				this.adjacentSlotDisplays[i].style.borderWidth = "1px";
				this.adjacentSlotDisplays[i].style.borderColor = "var(--colorBG)";
				this.adjacentSlotDisplays[i].style.borderStyle = "solid";
			}
		}).bind(this)(i);
	}
	var tileSlotCenterUpdateImage = function() {
		this.tile.getImage().then(function(img) {
			var downscale = document.createElement("canvas");
			downscale.height = 96;
			downscale.width = 96;
			var ctx = downscale.getContext("2d");
			ctx.imageSmoothingEnabled = false;
			ctx.webkitImageSmoothingEnabled = false;
			ctx.mozImageSmoothingEnabled = false;

			ctx.drawImage(img, 0, 0, 96, 96);

			this.mainSlotDisplay.style.backgroundImage = 'url(\"'+downscale.toDataURL()+'\")';
		}.bind(this));
	}.bind(this)
	tileSlotCenterUpdateImage();
	this.tile.contentUpdatedSubscribe(tileSlotCenterUpdateImage);
	this.tileContentRuleCallbacks.push([this.tile, tileSlotCenterUpdateImage]);
	if(ruleTiles[1] == other && ruleTiles[7] == other) {
		this.adjacentSlots[0].style.display = 'inline';
	} else {
		this.adjacentSlots[0].style.display = 'none';
	}
	if(ruleTiles[1] == other && ruleTiles[3] == other) {
		this.adjacentSlots[2].style.display = 'inline';
	} else {
		this.adjacentSlots[2].style.display = 'none';
	}
	if(ruleTiles[3] == other && ruleTiles[5] == other) {
		this.adjacentSlots[4].style.display = 'inline';
	} else {
		this.adjacentSlots[4].style.display = 'none';
	}
	if(ruleTiles[5] == other && ruleTiles[7] == other) {
		this.adjacentSlots[6].style.display = 'inline';
	} else {
		this.adjacentSlots[6].style.display = 'none';
	}
}

class PropertyRelationBlobBorderView extends PropertyRelationView {
	constructor(tile) {
		super("Blob Border");

		this.tile = tile;
		this.adjacentSlots = [];
		this.adjacentSlotDisplays = [];
		this.mainSlot = null;
		this.mainSlotDisplay = null;
		this.tileContentRuleCallbacks = [];
		this.relationsUpdatedCallback = function() {
			loadRuleGrid.bind(this)();
		}.bind(this);
		this.tile.relationsUpdatedSubscribe(this.relationsUpdatedCallback);

		this.borderRemovedCallback = new CallbackManager();

		var ruleContainer = document.createElement('div');
		ruleContainer.className = "propertyrelationblob-rule-container-view";
		this.contentDiv.appendChild(ruleContainer);

		var iso = false;
		var tileShape = tileroninX.getTileShape();
		if(tileShape == tileroninX.Shape.ISOMETRIC) {
			iso = true;
			ruleContainer.style.transform = "translateX(-50%) translateY(-50%) rotate(45deg)";
		}

		for(var i = 0; i < 2; i++) {
			var separatorH = document.createElement('div');
			separatorH.style.position = "absolute";
			separatorH.style.background = "var(--color1)";
			separatorH.style.top = (60-1.5*32-1)+"px";
			separatorH.style.height = (3*32+2)+"px";
			//separatorH.style.left = (60+(i-0.5)*32)+"px";
			separatorH.style.left = (60-32/2-1+i*(32+1))+"px";
			separatorH.style.width = "1px";
			ruleContainer.appendChild(separatorH);

			var separatorV = document.createElement('div');
			separatorV.style.position = "absolute";
			separatorV.style.background = "var(--color1)";
			separatorV.style.left = (60-1.5*32-1)+"px";
			separatorV.style.width = (3*32+2)+"px";
			//separatorV.style.top = (60+(i-0.5)*32)+"px";
			separatorV.style.top = (60-32/2-1+i*(32+1))+"px";
			separatorV.style.height = "1px";
			ruleContainer.appendChild(separatorV);
		}

		var slots = [
		{x:0, y:0},
		{x:1, y:0},
		{x:2, y:0},
		{x:2, y:1},
		{x:2, y:2},
		{x:1, y:2},
		{x:0, y:2},
		{x:0, y:1}
		];
		for(var s in slots) {
			var slot = slots[s];
			var slotDisplay = document.createElement('div');
			slotDisplay.className = "propertyrelationblob-tile-image-rule-view";
			//slotDisplay.style.left = (slot.x*40+12)+'px';
			//slotDisplay.style.top = (slot.y*40+12)+'px';
			slotDisplay.style.left = (60-8+33*(slot.x-1))+'px';
			slotDisplay.style.top = (60-8+33*(slot.y-1))+'px';
			slotDisplay.style.borderRadius = "0px";
			var slotDisplay2 = document.createElement('div');
			slotDisplay2.className = "propertyrelationblob-tile-image-rule-view-display";
			slotDisplay2.style.left = "50%";
			slotDisplay2.style.top = "50%";
			slotDisplay2.style.transform = "translate(-50%, -50%)";
			this.adjacentSlots.push(slotDisplay);
			this.adjacentSlotDisplays.push(slotDisplay2);
			slotDisplay.appendChild(slotDisplay2);
			ruleContainer.appendChild(slotDisplay);

			if(iso) {
				slotDisplay2.style.transform = "translate(-50%, -50%) rotate(-45deg)";
				//slotDisplay2.style.left = "50%";
				//slotDisplay2.style.top = "50%";
				slotDisplay.style.width = (16/Math.sqrt(2))+"px";
				slotDisplay.style.height = slotDisplay.style.width;
				slotDisplay.style.left = (60-8/Math.sqrt(2)+33*(slot.x-1))+'px';
				slotDisplay.style.top = (60-8/Math.sqrt(2)+33*(slot.y-1))+'px';
				//slotDisplay.style.left = (slot.x*(12*Math.sqrt(2)+16)+44-16*Math.sqrt(2))+'px';
				//slotDisplay.style.top = (slot.y*(12*Math.sqrt(2)+16)+44-16*Math.sqrt(2))+'px';
				//slotDisplay.style.left = (60+(-8+32*(slot.x-1))/Math.sqrt(2))+'px';
				//slotDisplay.style.top = (60+(-8+32*(slot.y-1))/Math.sqrt(2))+'px';
			}
		}
		this.mainSlot = document.createElement('div');
		this.mainSlot.className = "propertyrelationblob-tile-image-rule-large-view";
		this.mainSlot.style.left = '44px';
		this.mainSlot.style.top = '44px';
		this.mainSlot.style.borderRadius = "0px";
		this.mainSlotDisplay = document.createElement('div');
		this.mainSlotDisplay.className = "propertyrelationblob-tile-image-rule-large-view-display";
		this.mainSlot.appendChild(this.mainSlotDisplay);
		ruleContainer.appendChild(this.mainSlot);

		if(iso) {
			this.mainSlotDisplay.style.transform = "translate(-50%, -50%) rotate(-45deg)";
			this.mainSlotDisplay.style.left = "50%";
			this.mainSlotDisplay.style.top = "50%";
			this.mainSlot.style.width = (32/Math.sqrt(2))+"px";
			this.mainSlot.style.height = this.mainSlot.style.width;
			this.mainSlot.style.left = (60-(32/Math.sqrt(2))/2)+'px';
			this.mainSlot.style.top = this.mainSlot.style.left;
		}

		var ungroupDiv = document.createElement('div');
		ungroupDiv.className = "propertyrelationblobborder-remove-view";
		ungroupDiv.style.marginLeft = '6px';
		ungroupDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_b.png')";
		this.contentDiv.appendChild(ungroupDiv);

		plh.applyPointerLock(ungroupDiv, function() {
			plh.lockPointer();
			ungroupDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_c.png')";
		}.bind(this), null, function() {
			ungroupDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_b.png')";
			this.borderRemovedCallback.notify();
		}.bind(this));

		loadRuleGrid.bind(this)();
	}

	getDiv() {
		return this.div;
	}

	borderRemovedSubscribe(func) {
		this.borderRemovedCallback.subscribe(func);
	}

	clearCallbacks() {
		this.tile.relationsUpdatedUnsubscribe(this.relationsUpdatedCallback);

		for(var i in this.tileContentRuleCallbacks) {
			this.tileContentRuleCallbacks[i][0].contentUpdatedUnsubscribe(this.tileContentRuleCallbacks[i][1]);
		}
		this.tileContentRuleCallbacks = [];
	}
}
module.exports = PropertyRelationBlobBorderView;