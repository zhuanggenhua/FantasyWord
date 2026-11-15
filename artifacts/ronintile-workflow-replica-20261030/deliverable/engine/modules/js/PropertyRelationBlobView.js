var PropertyRelationView = require('./PropertyRelationView.js');
var plh = require('./PointerLockHandler.js');
var CallbackManager = require('./CallbackManager.js');

var TileRelationBlob = require('./TileRelationBlob.js');

var tileroninX = require('./tileroninX.js');

var loadRuleGrid = function() {
	if(this.ruleTiles[1] != this.blobRelations[0] || this.ruleTiles[7] != this.blobRelations[0]) {
		this.ruleTiles[0] = null;
	} else if(this.ruleTiles[0] == null) {
        this.ruleTiles[0] = this.blobRelations[1];
	}
	if(this.ruleTiles[1] != this.blobRelations[0] || this.ruleTiles[3] != this.blobRelations[0]) {
		this.ruleTiles[2] = null;
	} else if(this.ruleTiles[2] == null) {
        this.ruleTiles[2] = this.blobRelations[1];
	}
	if(this.ruleTiles[3] != this.blobRelations[0] || this.ruleTiles[5] != this.blobRelations[0]) {
		this.ruleTiles[4] = null;
	} else if(this.ruleTiles[4] == null) {
        this.ruleTiles[4] = this.blobRelations[1];
	}
	if(this.ruleTiles[5] != this.blobRelations[0] || this.ruleTiles[7] != this.blobRelations[0]) {
		this.ruleTiles[6] = null;
	} else if(this.ruleTiles[6] == null) {
        this.ruleTiles[6] = this.blobRelations[1];
	}

	for(var i in this.tileContentRuleCallbacks) {
		this.tileContentRuleCallbacks[i][0].contentUpdatedUnsubscribe(this.tileContentRuleCallbacks[i][1]);
	}
	this.tileContentRuleCallbacks = [];

	for(var i in this.ruleTiles) {
		(function a(i) {
			var t = this.ruleTiles[i];
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
	var borderTile = this.tile.getRelationBlobBorder(this.ruleTiles);
	if(borderTile != null) {
		var tileSlotCenterUpdateImage = function() {
			borderTile.getImage().then(function(img) {
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
		borderTile.contentUpdatedSubscribe(tileSlotCenterUpdateImage);
		this.tileContentRuleCallbacks.push([borderTile, tileSlotCenterUpdateImage]);
	} else {
		var centerTile = true;
		for(var i in this.ruleTiles) {
			if(this.ruleTiles[i] != this.tile) {
				centerTile = false;
				break;
			}
		}
		if(centerTile) {
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
		} else {
			this.mainSlotDisplay.style.backgroundImage = 'none';
		}
	}
	if(this.ruleTiles[0] != null) {
		this.adjacentSlots[0].style.display = 'inline';
	} else {
		this.adjacentSlots[0].style.display = 'none';
	}
	if(this.ruleTiles[2] != null) {
		this.adjacentSlots[2].style.display = 'inline';
	} else {
		this.adjacentSlots[2].style.display = 'none';
	}
	if(this.ruleTiles[4] != null) {
		this.adjacentSlots[4].style.display = 'inline';
	} else {
		this.adjacentSlots[4].style.display = 'none';
	}
	if(this.ruleTiles[6] != null) {
		this.adjacentSlots[6].style.display = 'inline';
	} else {
		this.adjacentSlots[6].style.display = 'none';
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

	this.blobRelations = [this.tile];
	var rel = this.tile.getRelations();
	for(var i in rel) {
		var r = rel[i];
		if(r.r instanceof TileRelationBlob && r.r.origin == this.tile) {
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
					this.tile.getImage().then(function(img) {
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
				this.tile.contentUpdatedSubscribe(tileDisplayAUpdateImage);
				this.tileContentRelationCallbacks.push([this.tile, tileDisplayAUpdateImage]);

				relationContainer.appendChild(tileDisplayA);
				
				var relationDisplay = document.createElement('div');
				relationDisplay.className = "propertyrelationblob-tile-image-view";
				relationDisplay.style.background = "none";
				relationDisplay.style.backgroundImage = "url('../res/icon/ui_icon_relation.png')";
				relationContainer.appendChild(relationDisplay);

				var tileDisplayB = document.createElement('div');
				tileDisplayB.className = "propertyrelationblob-tile-image-view";
				tileDisplayB.style.marginLeft = '6px';
				if(r.t != false) {
					tileDisplayB.style.height = (16/step)+"px";
					tileDisplayB.style.backgroundSize = "16px "+(16/step)+"px";
					tileDisplayB.style.marginBottom = ((16-(16/step))/2)+"px";
					var tileDisplayBUpdateImage = function() {
						r.t.getImage().then(function(img) {
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
					r.t.contentUpdatedSubscribe(tileDisplayBUpdateImage);
					this.tileContentRelationCallbacks.push([r.t, tileDisplayBUpdateImage]);
				} else {
					tileDisplayB.style.backgroundImage = "url('../res/icon/ui_icon_wildcard.png')";
				}
				relationContainer.appendChild(tileDisplayB);

				var removeDiv = document.createElement('div');
				removeDiv.className = "propertyrelationblob-remove-view";
				removeDiv.style.marginLeft = '6px';
				removeDiv.style.backgroundImage = "url('../res/icon/ui_icon_region_b.png')";
				relationContainer.appendChild(removeDiv);

				plh.applyPointerLock(removeDiv, function() {
					plh.lockPointer();
					this.errorDisplay.close();
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

class PropertyRelationBlobView extends PropertyRelationView {
	constructor(tile) {
		super("Blob Base");

		this.tile = tile;
		this.selectedTile = false;
		this.adjacentSlots = [];
		this.adjacentSlotDisplays = [];
		this.mainSlot = null;
		this.mainSlotDisplay = null;
		this.ruleTiles = [];
		this.blobRelations = [];
		this.tileContentRelationCallbacks = [];
		this.tileContentRuleCallbacks = [];
		this.relationsUpdatedCallback = function() {
			loadRelations.bind(this)();
			for(var i in this.ruleTiles) {
				if(!this.blobRelations.includes(this.ruleTiles[i])) {
					this.ruleTiles[i] = this.blobRelations[0];
				}
			}
			loadRuleGrid.bind(this)();
		}.bind(this);
		this.tile.relationsUpdatedSubscribe(this.relationsUpdatedCallback);

		this.relationDeletedCallback = new CallbackManager();
		this.slotClickedCallback = new CallbackManager();

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

			var slotDisplaySelect = document.createElement('div');
			slotDisplaySelect.className = "propertyrelationblob-tile-image-rule-select-view";
			//slotDisplaySelect.style.left = (slot.x*40+12-1)+'px';
			//slotDisplaySelect.style.top = (slot.y*40+12-1)+'px';
			slotDisplaySelect.style.left = (60-16+33*(slot.x-1))+'px';
			slotDisplaySelect.style.top = (60-16+33*(slot.y-1))+'px';
			slotDisplaySelect.style.width = (32)+'px';
			slotDisplaySelect.style.height = (32)+'px';
			ruleContainer.appendChild(slotDisplaySelect);
			if(iso) {
				slotDisplay2.style.transform = "translate(-50%, -50%) rotate(-45deg)";
				slotDisplayBg.style.width = (16/Math.sqrt(2))+'px';
				slotDisplayBg.style.height = slotDisplayBg.style.width;
				slotDisplayBg.style.left = (0.5*(32-16/Math.sqrt(2)))+'px';
				slotDisplayBg.style.top = (0.5*(32-16/Math.sqrt(2)))+'px';
				//slotDisplay2.style.left = "50%";
				//slotDisplay2.style.top = "50%";
				//slotDisplay.style.width = (16/Math.sqrt(2))+"px";
				//slotDisplay.style.height = slotDisplay.style.width;
				//slotDisplay.style.left = (60-8/Math.sqrt(2)+32*(slot.x-1))+'px';
				//slotDisplay.style.top = (60-8/Math.sqrt(2)+32*(slot.y-1))+'px';

				/*slotDisplaySelect.style.width = (16/Math.sqrt(2)+2)+"px";
				slotDisplaySelect.style.height = slotDisplaySelect.style.width;
				slotDisplaySelect.style.left = (slot.x*(12*Math.sqrt(2)+16)+44-16*Math.sqrt(2)-1)+'px';
				slotDisplaySelect.style.top = (slot.y*(12*Math.sqrt(2)+16)+44-16*Math.sqrt(2)-1)+'px';*/
			}

			(function a(s, slotDisplaySelect) {
				plh.applyPointerLock(slotDisplay, function() {
					if(this.selectedTile) {
						return;
					}
					plh.lockPointer();
					this.errorDisplay.close();
					slotDisplaySelect.style.visibility = 'visible';
				}.bind(this), null, function() {
					if(this.selectedTile) {
						return;
					}
					slotDisplaySelect.style.visibility = 'hidden';
					var currentTile = this.ruleTiles[s];
					var idx = this.blobRelations.indexOf(currentTile);
					this.ruleTiles[s] = this.blobRelations[(idx+1)%this.blobRelations.length];
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

		var mainSlotHighlight = document.createElement('div');
		mainSlotHighlight.className = "propertyrelationblob-tile-highlight-view";
		mainSlotHighlight.style.borderRadius = "0px";
		//mainSlotHighlight.style.left = '0px';
		//mainSlotHighlight.style.top = '0px';
		mainSlotHighlight.style.left = (60-32/2)+'px';
		mainSlotHighlight.style.top = (60-32/2)+'px';
		mainSlotHighlight.style.width = (32)+'px';
		mainSlotHighlight.style.height = (32)+'px';
		ruleContainer.appendChild(mainSlotHighlight);

		var mainSlotSelect = document.createElement('div');
		mainSlotSelect.className = "propertyrelationblob-tile-image-rule-select-view";
		//mainSlotSelect.style.left = '-2px';
		//mainSlotSelect.style.top = '-2px';
		mainSlotSelect.style.left = (60-32/2)+'px';
		mainSlotSelect.style.top = (60-32/2)+'px';
		mainSlotSelect.style.width = (32)+'px';
		mainSlotSelect.style.height = (32)+'px';
		ruleContainer.appendChild(mainSlotSelect);
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

			/*mainSlotHighlight.style.width = this.mainSlot.style.width;
			mainSlotHighlight.style.height = this.mainSlot.style.width;
			mainSlotSelect.style.width = (32/Math.sqrt(2)+4)+"px";
			mainSlotSelect.style.height = mainSlotSelect.style.width;*/
			//this.mainSlot.style.left = (60-32/2)+'px';
			//this.mainSlot.style.top = this.mainSlot.style.left;
		}

		plh.applyPointerLock(this.mainSlot, function() {
			plh.lockPointer();
			this.errorDisplay.close();
			mainSlotSelect.style.visibility = 'visible';
		}.bind(this), null, function() {
			mainSlotSelect.style.visibility = 'hidden';
			mainSlotHighlight.style.visibility = 'visible';
			this.mainSlot.style.visibility = 'hidden';
			this.selectedTile = true;
			this.slotClickedCallback.notify(function(tile) {
				mainSlotHighlight.style.visibility = 'hidden';
				this.mainSlot.style.visibility = 'visible';
				if(tile != false) {
					var undoGroup = [];
					var errorGroup = [];
					tileroninX.replaceBlobBorder(this.tile, this.ruleTiles, tile, undoGroup, errorGroup);
					tileroninX.saveUndoState(undoGroup);
					if(errorGroup.length > 0) {
						this.errorDisplay.open(0, 0, errorGroup);
					}
					this.selectedTile = false;
				}
			}.bind(this))
		}.bind(this));

		loadRelations.bind(this)();
		for(var i = 0; i < 8; i++) {
			this.ruleTiles.push(this.blobRelations[1]);
		}
		loadRuleGrid.bind(this)();
	}

	getDiv() {
		return this.div;
	}

	relationDeletedSubscribe(func) {
		this.relationDeletedCallback.subscribe(func);
	}

	slotClickedSubscribe(func) {
		this.slotClickedCallback.subscribe(func);
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
module.exports = PropertyRelationBlobView;