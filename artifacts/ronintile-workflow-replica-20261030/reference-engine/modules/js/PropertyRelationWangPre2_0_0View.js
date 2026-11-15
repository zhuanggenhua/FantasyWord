var PropertyRelationView = require('./PropertyRelationView.js');
var plh = require('./PointerLockHandler.js');
var CallbackManager = require('./CallbackManager.js');

var loadDisplay = function() {
	for(var i in this.tileContentCallbacks) {
		this.tileContentCallbacks[i][0].contentUpdatedUnsubscribe(this.tileContentCallbacks[i][1]);
	}
	this.tileContentCallbacks = [];

	var tileSlotUpdateImage = function() {
		this.tile.getImage().then(function(img) {
			this.tileDisplay.style.backgroundImage = 'url(\"'+img.toDataURL()+'\")';
		}.bind(this));
	}.bind(this)
	tileSlotUpdateImage();
	this.tile.contentUpdatedSubscribe(tileSlotUpdateImage);
	this.tileContentCallbacks.push([this.tile, tileSlotUpdateImage]);

	if(this.base0Tile != null) {
		var tileSlotBg0UpdateImage = function() {
			this.base0Tile.getImage().then(function(img) {
				this.bgSlot0.style.backgroundImage = 'url(\"'+img.toDataURL()+'\")';
			}.bind(this));
		}.bind(this)
		tileSlotBg0UpdateImage();
		this.base0Tile.contentUpdatedSubscribe(tileSlotBg0UpdateImage);
		this.tileContentCallbacks.push([this.base0Tile, tileSlotBg0UpdateImage]);
	} else {
		this.bgSlot0.style.backgroundImage = 'none';
	}
	if(this.base1Tile != null) {
		var tileSlotBg1UpdateImage = function() {
			this.base1Tile.getImage().then(function(img) {
				this.bgSlot1.style.backgroundImage = 'url(\"'+img.toDataURL()+'\")';
			}.bind(this));
		}.bind(this)
		tileSlotBg1UpdateImage();
		this.base1Tile.contentUpdatedSubscribe(tileSlotBg1UpdateImage);
		this.tileContentCallbacks.push([this.base1Tile, tileSlotBg1UpdateImage]);
	} else {
		this.bgSlot1.style.backgroundImage = 'none';
	}
}

class PropertyRelationWangPre2_0_0View extends PropertyRelationView {
	constructor(tile) {
		super("CONVERT TO VERSION "+tileroninX.getVersionString());

		this.tile = tile;
		this.selectedTile = false;
		this.base0Tile = null;
		this.base1Tile = null;
		this.tileContentCallbacks = [];
		this.relationsUpdatedCallback = function() {
			loadDisplay.bind(this)();
		}.bind(this);
		this.tile.relationsUpdatedSubscribe(this.relationsUpdatedCallback);

		this.slotClickedCallback = new CallbackManager();

		this.contentDiv.style.height = "120px";

		var ruleContainer = document.createElement('div');
		ruleContainer.className = "propertyrelationblob-rule-container-view";
		this.contentDiv.appendChild(ruleContainer);

		this.bgSlot0 = document.createElement('div');
		this.bgSlot0.className = "propertyrelationblob-tile-image-rule-large-view";
		this.bgSlot0.style.left = '-12px';
		this.bgSlot0.style.top = '34px';
		ruleContainer.appendChild(this.bgSlot0);

		var bgSlotHighlight0 = document.createElement('div');
		bgSlotHighlight0.className = "propertyrelationblob-tile-highlight-view";
		bgSlotHighlight0.style.left = '0px';
		bgSlotHighlight0.style.top = '0px';
		this.bgSlot0.appendChild(bgSlotHighlight0);

		var bgSlotSelect0 = document.createElement('div');
		bgSlotSelect0.className = "propertyrelationblob-tile-image-rule-large-select-view";
		bgSlotSelect0.style.left = '-2px';
		bgSlotSelect0.style.top = '-2px';
		this.bgSlot0.appendChild(bgSlotSelect0);

		this.bgSlot1 = document.createElement('div');
		this.bgSlot1.className = "propertyrelationblob-tile-image-rule-large-view";
		this.bgSlot1.style.left = '100px';
		this.bgSlot1.style.top = '34px';
		ruleContainer.appendChild(this.bgSlot1);

		var bgSlotHighlight1 = document.createElement('div');
		bgSlotHighlight1.className = "propertyrelationblob-tile-highlight-view";
		bgSlotHighlight1.style.left = '0px';
		bgSlotHighlight1.style.top = '0px';
		this.bgSlot1.appendChild(bgSlotHighlight1);

		var bgSlotSelect1 = document.createElement('div');
		bgSlotSelect1.className = "propertyrelationblob-tile-image-rule-large-select-view";
		bgSlotSelect1.style.left = '-2px';
		bgSlotSelect1.style.top = '-2px';
		this.bgSlot1.appendChild(bgSlotSelect1);

		var arrowDisplay0 = document.createElement('div');
		arrowDisplay0.className = "propertyrelationpre2_0_0-arrow-view";
		arrowDisplay0.style.left = '28px';
		arrowDisplay0.style.top = '42px';
		arrowDisplay0.style.transform = 'scaleX(-1)';
		arrowDisplay0.style.backgroundImage = "url('../res/icon/ui_icon_relation.png')";
		ruleContainer.appendChild(arrowDisplay0);

		var arrowDisplay1 = document.createElement('div');
		arrowDisplay1.className = "propertyrelationpre2_0_0-arrow-view";
		arrowDisplay1.style.left = '76px';
		arrowDisplay1.style.top = '42px';
		arrowDisplay1.style.backgroundImage = "url('../res/icon/ui_icon_relation.png')";
		ruleContainer.appendChild(arrowDisplay1);

		this.tileDisplay = document.createElement('div');
		this.tileDisplay.className = "propertyrelationblob-tile-image-rule-view";
		this.tileDisplay.style.left = '52px';
		this.tileDisplay.style.top = '42px';
		ruleContainer.appendChild(this.tileDisplay);

		var instructionText = document.createElement('div');
		instructionText.className = "propertyrelationpre2_0_0-text-view";
		instructionText.innerHTML = "Select the base tiles for this border.";
		instructionText.style.top = '74px';
		ruleContainer.appendChild(instructionText);

		plh.applyPointerLock(this.bgSlot0, function() {
			if(this.selectedTile) {
				return;
			}
			plh.lockPointer();
			this.errorDisplay.close();
			bgSlotSelect0.style.visibility = 'visible';
		}.bind(this), null, function() {
			if(this.selectedTile) {
				return;
			}
			bgSlotSelect0.style.visibility = 'hidden';
			bgSlotHighlight0.style.visibility = 'visible';
			this.bgSlot0.style.visibility = 'hidden';
			this.selectedTile = true;
			this.slotClickedCallback.notify(function(tile) {
				bgSlotHighlight0.style.visibility = 'hidden';
				this.bgSlot0.style.visibility = 'visible';
				this.base0Tile = tile;
				this.selectedTile = false;
				if(this.base0Tile != null && this.base1Tile != null) {
					var undoGroup = [];
					var errorGroup = [];
					tileroninX.convert2_0_0Wang(this.tile, this.base0Tile, this.base1Tile, undoGroup, errorGroup);
					tileroninX.saveUndoState(undoGroup);
					if(errorGroup.length > 0) {
						this.errorDisplay.open(0, 0, errorGroup);
					}
					this.base0Tile = null;
					this.base1Tile = null;
					loadDisplay.bind(this)();
				} else {
					loadDisplay.bind(this)();
				}
			}.bind(this))
		}.bind(this));

		plh.applyPointerLock(this.bgSlot1, function() {
			if(this.selectedTile) {
				return;
			}
			plh.lockPointer();
			this.errorDisplay.close();
			bgSlotSelect1.style.visibility = 'visible';
		}.bind(this), null, function() {
			if(this.selectedTile) {
				return;
			}
			bgSlotSelect1.style.visibility = 'hidden';
			bgSlotHighlight1.style.visibility = 'visible';
			this.bgSlot1.style.visibility = 'hidden';
			this.selectedTile = true;
			this.slotClickedCallback.notify(function(tile) {
				bgSlotHighlight1.style.visibility = 'hidden';
				this.bgSlot1.style.visibility = 'visible';
				this.base1Tile = tile;
				this.selectedTile = false;
				if(this.base0Tile != null && this.base1Tile != null) {
					var undoGroup = [];
					var errorGroup = [];
					tileroninX.convert2_0_0Wang(this.tile, this.base0Tile, this.base1Tile, undoGroup, errorGroup);
					tileroninX.saveUndoState(undoGroup);
					if(errorGroup.length > 0) {
						this.errorDisplay.open(0, 0, errorGroup);
					}
					this.base0Tile = null;
					this.base1Tile = null;
					loadDisplay.bind(this)();
				} else {
					loadDisplay.bind(this)();
				}
			}.bind(this))
		}.bind(this));

		loadDisplay.bind(this)();
	}

	getDiv() {
		return this.div;
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
module.exports = PropertyRelationWangPre2_0_0View;