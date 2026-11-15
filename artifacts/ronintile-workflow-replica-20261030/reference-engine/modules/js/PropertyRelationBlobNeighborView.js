var PropertyRelationView = require('./PropertyRelationView.js');
var plh = require('./PointerLockHandler.js');
var CallbackManager = require('./CallbackManager.js');

var TileRelationBlob = require('./TileRelationBlob.js');

var tileroninX = require('./tileroninX.js');

var loadRuleGrid = function() {
	for(var i in this.tileContentRuleCallbacks) {
		this.tileContentRuleCallbacks[i][0].contentUpdatedUnsubscribe(this.tileContentRuleCallbacks[i][1]);
	}
	this.tileContentRuleCallbacks = [];

	for(var i in this.adjacentSlots) {
		(function a(i) {
			var t;
			if(i == 0) {
				t = this.ruleTile;
			} else {
				t = this.tile;
			}
			if(t != null) {
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

						this.adjacentSlotDisplays[i].style.backgroundImage = 'url(\"'+downscale.toDataURL()+'\")';
					}.bind(this));
				}.bind(this)
				tileSlotUpdateImage();
				t.contentUpdatedSubscribe(tileSlotUpdateImage);
				this.tileContentRuleCallbacks.push([t, tileSlotUpdateImage]);
			}
		}).bind(this)(i);
	}
	if(this.ruleTile == null) {
		return;
	}
	var centerTile = this.ruleTile.getRelationBlobBorder([this.ruleTile, this.ruleTile, null, this.tile, null, this.ruleTile, this.ruleTile, this.ruleTile]);
	if(centerTile != null) {
		var tileSlotCenterUpdateImage = function() {
			centerTile.getImage().then(function(img) {
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
		centerTile.contentUpdatedSubscribe(tileSlotCenterUpdateImage);
		this.tileContentRuleCallbacks.push([centerTile, tileSlotCenterUpdateImage]);
	} else {
		this.mainSlotDisplay.style.backgroundImage = 'none';
	}
}

var loadRelations = function() {
	this.relationSection.innerHTML = "";

	for(var i in this.tileContentRelationCallbacks) {
		this.tileContentRelationCallbacks[i][0].contentUpdatedUnsubscribe(this.tileContentRelationCallbacks[i][1]);
	}
	this.tileContentRelationCallbacks = [];

	var step = 1;
	var tileShape = tileroninX.getTileShape();
	if(tileShape == tileroninX.Shape.ISOMETRIC) {
		var tileSize = tileroninX.getTileSize();
		step = tileSize[0]/tileSize[1];
	}

	this.blobRelations = [];
	var rel = this.tile.getRelations();
	for(var i in rel) {
		var r = rel[i];
		if(r.r instanceof TileRelationBlob && r.r.origin != this.tile) {
			(function a(r) {
				this.blobRelations.push(r.t);
				//create view for blob relation
				var relationContainer = document.createElement('div');
				relationContainer.className = "propertyrelationblob-relation-container-view";

				var tileDisplayA = document.createElement('div');
				tileDisplayA.className = "propertyrelationblob-tile-image-view";
				tileDisplayA.style.marginRight = '6px';
				tileDisplayA.style.height = (16/step)+"px";
				tileDisplayA.style.backgroundSize = "16px "+(16/step)+"px";
				tileDisplayA.style.marginBottom = ((16-(16/step))/2)+"px";

				var tileDisplayAUpdateImage = function() {
					r.t.getImage().then(function(img) {
						var downscale = document.createElement("canvas");
						downscale.height = 48/step;
						downscale.width = 48;
						var ctx = downscale.getContext("2d");
						ctx.imageSmoothingEnabled = false;
						ctx.webkitImageSmoothingEnabled = false;
						ctx.mozImageSmoothingEnabled = false;

						ctx.drawImage(img, 0, 0, 48, 48/step);

						tileDisplayA.style.backgroundImage = 'url(\"'+downscale.toDataURL()+'\")';
					});
				}.bind(this);
				tileDisplayAUpdateImage();
				r.t.contentUpdatedSubscribe(tileDisplayAUpdateImage);
				this.tileContentRelationCallbacks.push([r.t, tileDisplayAUpdateImage]);

				relationContainer.appendChild(tileDisplayA);
				
				var relationDisplay = document.createElement('div');
				relationDisplay.className = "propertyrelationblob-tile-image-view";
				relationDisplay.style.background = "none";
				relationDisplay.style.backgroundImage = "url('../res/icon/ui_icon_relation.png')";
				relationContainer.appendChild(relationDisplay);

				var tileDisplayB = document.createElement('div');
				tileDisplayB.className = "propertyrelationblob-tile-image-view";
				tileDisplayB.style.marginLeft = '6px';
				tileDisplayB.style.height = (16/step)+"px";
				tileDisplayB.style.backgroundSize = "16px "+(16/step)+"px";
				tileDisplayB.style.marginBottom = ((16-(16/step))/2)+"px";
				
				var tileDisplayBUpdateImage = function() {
					this.tile.getImage().then(function(img) {
						var downscale = document.createElement("canvas");
						downscale.height = 48/step;
						downscale.width = 48;
						var ctx = downscale.getContext("2d");
						ctx.imageSmoothingEnabled = false;
						ctx.webkitImageSmoothingEnabled = false;
						ctx.mozImageSmoothingEnabled = false;

						ctx.drawImage(img, 0, 0, 48, 48/step);

						tileDisplayB.style.backgroundImage = 'url(\"'+downscale.toDataURL()+'\")';
					});
				}.bind(this);
				tileDisplayBUpdateImage();
				this.tile.contentUpdatedSubscribe(tileDisplayBUpdateImage);
				this.tileContentRelationCallbacks.push([this.tile, tileDisplayBUpdateImage]);

				relationContainer.appendChild(tileDisplayB);

				var removeDiv = document.createElement('div');
				removeDiv.className = "propertyrelationblob-remove-view";
				removeDiv.style.marginLeft = '6px';
				removeDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_b.png')";
				relationContainer.appendChild(removeDiv);

				plh.applyPointerLock(removeDiv, function() {
					plh.lockPointer();
					removeDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_c.png')";
				}.bind(this), null, function() {
					removeDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_b.png')";
					this.relationDeletedCallback.notify(r.t);
				}.bind(this));

				this.relationSection.appendChild(relationContainer);
			}).bind(this)(r);
		}
	}
}

class PropertyRelationBlobNeighborView extends PropertyRelationView {
	constructor(tile) {
		super("Blob Neighbor");

		this.tile = tile;
		this.adjacentSlots = [];
		this.adjacentSlotDisplays = [];
		this.mainSlot = null;
		this.mainSlotDisplay = null;
		this.ruleTile = null;
		this.blobRelations = [];
		this.tileContentRelationCallbacks = [];
		this.tileContentRuleCallbacks = [];
		this.relationsUpdatedCallback = function() {
			loadRelations.bind(this)();
			if(!this.blobRelations.includes(this.ruleTile)) {
				this.ruleTile = this.blobRelations[0];
			}
			loadRuleGrid.bind(this)();
		}.bind(this);
		this.tile.relationsUpdatedSubscribe(this.relationsUpdatedCallback);

		this.relationDeletedCallback = new CallbackManager();

		this.contentDiv.style.height = "128px";

		var sectionContainer = document.createElement('div');
		sectionContainer.className = "propertyrelationblob-section-container-view";
		this.contentDiv.appendChild(sectionContainer);

		this.relationSection = document.createElement('div');
		this.relationSection.className = "propertyrelationblob-relation-section-view";
		sectionContainer.appendChild(this.relationSection);

		var ruleSection = document.createElement('div');
		ruleSection.className = "propertyrelationblob-rule-section-view";
		sectionContainer.appendChild(ruleSection);

		var ruleContainer = document.createElement('div');
		ruleContainer.className = "propertyrelationblob-rule-container-view";
		ruleSection.appendChild(ruleContainer);

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
			separatorH.style.top = (60-0.5*32)+"px";
			separatorH.style.height = (1*32)+"px";
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
		{x:0, y:1},
		{x:2, y:1}
		];
		for(var s = 0; s < slots.length; s++) {
			var slot = slots[s];
			var slotDisplay = document.createElement('div');
			slotDisplay.className = "propertyrelationblob-tile-image-rule-view";
			//slotDisplay.style.left = (slot.x*40+12)+'px';
			//slotDisplay.style.top = (slot.y*40+12)+'px';
			slotDisplay.style.left = (60-16+33*(slot.x-1))+'px';
			slotDisplay.style.top = (60-16+33*(slot.y-1))+'px';
			slotDisplay.style.width = (32)+'px';
			slotDisplay.style.height = (32)+'px';
			slotDisplay.style.background = "transparent";
			slotDisplay.style.borderRadius = "0px";
			var slotDisplayBg = document.createElement('div');
			slotDisplayBg.className = "propertyrelationblob-tile-image-rule-view";
			slotDisplayBg.style.borderRadius = "0px";
			slotDisplayBg.style.left = (0.5*(32-16))+'px';
			slotDisplayBg.style.top = (0.5*(32-16))+'px';
			var slotDisplay2 = document.createElement('div');
			slotDisplay2.className = "propertyrelationblob-tile-image-rule-view-display";
			slotDisplay2.style.left = "50%";
			slotDisplay2.style.top = "50%";
			slotDisplay2.style.transform = "translate(-50%, -50%)";
			this.adjacentSlots.push(slotDisplay);
			this.adjacentSlotDisplays.push(slotDisplay2);
			slotDisplay.appendChild(slotDisplayBg);
			slotDisplay.appendChild(slotDisplay2);
			ruleContainer.appendChild(slotDisplay);

			if(iso) {
				slotDisplay2.style.transform = "translate(-50%, -50%) rotate(-45deg)";
				slotDisplayBg.style.width = (16/Math.sqrt(2))+'px';
				slotDisplayBg.style.height = slotDisplayBg.style.width;
				slotDisplayBg.style.left = (0.5*(32-16/Math.sqrt(2)))+'px';
				slotDisplayBg.style.top = (0.5*(32-16/Math.sqrt(2)))+'px';
				//slotDisplay2.style.left = "50%";
				//slotDisplay2.style.top = "50%";
				/*slotDisplay.style.width = (16/Math.sqrt(2))+"px";
				slotDisplay.style.height = slotDisplay.style.width;
				slotDisplay.style.left = (60-8/Math.sqrt(2)+33*(slot.x-1))+'px';
				slotDisplay.style.top = (60-8/Math.sqrt(2)+33*(slot.y-1))+'px';*/
				//slotDisplay.style.left = (slot.x*(12*Math.sqrt(2)+16)+44-16*Math.sqrt(2))+'px';
				//slotDisplay.style.top = (slot.y*(12*Math.sqrt(2)+16)+44-16*Math.sqrt(2))+'px';
			}

			if(s > 0) { continue; }

			var slotDisplaySelect = document.createElement('div');
			slotDisplaySelect.className = "propertyrelationblob-tile-image-rule-select-view";
			//slotDisplaySelect.style.left = (slot.x*40+12-1)+'px';
			//slotDisplaySelect.style.top = (slot.y*40+12-1)+'px';
			slotDisplaySelect.style.left = (60-16+33*(slot.x-1))+'px';
			slotDisplaySelect.style.top = (60-16+33*(slot.y-1))+'px';
			slotDisplaySelect.style.width = (32)+'px';
			slotDisplaySelect.style.height = (32)+'px';
			ruleContainer.appendChild(slotDisplaySelect);

			(function a(s, slotDisplaySelect) {
				plh.applyPointerLock(slotDisplay, function() {
					plh.lockPointer();
					slotDisplaySelect.style.visibility = 'visible';
				}.bind(this), null, function() {
					slotDisplaySelect.style.visibility = 'hidden';
					var currentTile = this.ruleTile;
					var idx = this.blobRelations.indexOf(currentTile);
					this.ruleTile = this.blobRelations[(idx+1)%this.blobRelations.length];
					loadRuleGrid.bind(this)();
				}.bind(this));
			}).bind(this)(s, slotDisplaySelect);
		}
		this.mainSlot = document.createElement('div');
		this.mainSlot.className = "propertyrelationblob-tile-image-rule-large-view";
		this.mainSlot.style.left = '44px';
		this.mainSlot.style.top = '44px';
		this.mainSlot.style.borderRadius = "0px";
		this.mainSlot.style.background = "transparent";
		this.mainSlot.style.overflow = "hidden";
		var mainSlotBg = document.createElement('div');
		mainSlotBg.className = "propertyrelationblob-tile-image-rule-large-view";
		mainSlotBg.style.borderRadius = "0px";
		this.mainSlotDisplay = document.createElement('div');
		this.mainSlotDisplay.className = "propertyrelationblob-tile-image-rule-large-view-display";
		this.mainSlot.appendChild(mainSlotBg);
		this.mainSlot.appendChild(this.mainSlotDisplay);
		ruleContainer.appendChild(this.mainSlot);

		if(iso) {
			this.mainSlotDisplay.style.transform = "translate(-50%, -50%) rotate(-45deg)";
			this.mainSlotDisplay.style.left = "50%";
			this.mainSlotDisplay.style.top = "50%";

			mainSlotBg.style.width = (32/Math.sqrt(2))+'px';
			mainSlotBg.style.height = mainSlotBg.style.width;
			mainSlotBg.style.left = (0.5*(32-32/Math.sqrt(2)))+'px';
			mainSlotBg.style.top = (0.5*(32-32/Math.sqrt(2)))+'px';

			//this.mainSlot.style.width = (32/Math.sqrt(2))+"px";
			//this.mainSlot.style.height = this.mainSlot.style.width;
			//this.mainSlot.style.left = (60-(32/Math.sqrt(2))/2)+'px';
			//this.mainSlot.style.top = this.mainSlot.style.left;
		}

		loadRelations.bind(this)();
		this.ruleTile = this.blobRelations[0];
		loadRuleGrid.bind(this)();
	}

	getDiv() {
		return this.div;
	}

	relationDeletedSubscribe(func) {
		this.relationDeletedCallback.subscribe(func);
	}

	clearCallbacks() {
		this.tile.relationsUpdatedUnsubscribe(this.relationsUpdatedCallback);

		for(var i in this.tileContentRelationCallbacks) {
			this.tileContentRelationCallbacks[i][0].contentUpdatedUnsubscribe(this.tileContentRelationCallbacks[i][1]);
		}
		this.tileContentRelationCallbacks = [];

		for(var i in this.tileContentRuleCallbacks) {
			this.tileContentRuleCallbacks[i][0].contentUpdatedUnsubscribe(this.tileContentRuleCallbacks[i][1]);
		}
		this.tileContentRuleCallbacks = [];
	}
}
module.exports = PropertyRelationBlobNeighborView;