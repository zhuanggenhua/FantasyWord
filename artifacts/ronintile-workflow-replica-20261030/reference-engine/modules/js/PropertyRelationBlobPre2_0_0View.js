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
}

class PropertyRelationBlobPre2_0_0View extends PropertyRelationView {
	constructor(tile) {
		super("CONVERT TO VERSION "+tileroninX.getVersionString());

		this.tile = tile;
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

		this.bgSlot = document.createElement('div');
		this.bgSlot.className = "propertyrelationblob-tile-image-rule-large-view";
		this.bgSlot.style.left = '68px';
		this.bgSlot.style.top = '34px';
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

		var arrowDisplay = document.createElement('div');
		arrowDisplay.className = "propertyrelationpre2_0_0-arrow-view";
		arrowDisplay.style.left = '44px';
		arrowDisplay.style.top = '42px';
		arrowDisplay.style.backgroundImage = "url('../res/icon/ui_icon_relation.png')";
		ruleContainer.appendChild(arrowDisplay);

		this.tileDisplay = document.createElement('div');
		this.tileDisplay.className = "propertyrelationblob-tile-image-rule-view";
		this.tileDisplay.style.left = '20px';
		this.tileDisplay.style.top = '42px';
		ruleContainer.appendChild(this.tileDisplay);

		var instructionText = document.createElement('div');
		instructionText.className = "propertyrelationpre2_0_0-text-view";
		instructionText.innerHTML = "Select the base tile for this border.";
		instructionText.style.top = '74px';
		ruleContainer.appendChild(instructionText);

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
					tileroninX.convert2_0_0Blob(this.tile, tile, undoGroup, errorGroup);
					tileroninX.saveUndoState(undoGroup);
					if(errorGroup.length > 0) {
						this.errorDisplay.open(0, 0, errorGroup);
					}
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
module.exports = PropertyRelationBlobPre2_0_0View;