var PropertyRelationView = require('./PropertyRelationView.js');
var plh = require('./PointerLockHandler.js');
var CallbackManager = require('./CallbackManager.js');

var TileRelationProxy = require('./TileRelationProxy.js');

var loadDisplay = function() {
	for(var i in this.tileContentCallbacks) {
		this.tileContentCallbacks[i][0].contentUpdatedUnsubscribe(this.tileContentCallbacks[i][1]);
	}
	this.tileContentCallbacks = [];

	var bgTile = null;
	var tRel = this.tile.getRelations();
	for(var i in tRel) {
		var rel = tRel[i];
		if(rel.r instanceof TileRelationProxy && !rel.r.isReverse) {
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

class PropertyRelationProxyView extends PropertyRelationView {
	constructor(tile) {
		super("Proxy");

		this.tile = tile;
		this.tileContentCallbacks = [];
		this.relationsUpdatedCallback = function() {
			loadDisplay.bind(this)();
		}.bind(this);
		this.tile.relationsUpdatedSubscribe(this.relationsUpdatedCallback);

		this.slotClickedCallback = new CallbackManager();

		this.contentDiv.style.height = "100px";

		var ruleContainer = document.createElement('div');
		ruleContainer.className = "propertyrelationblob-rule-container-view";
		this.contentDiv.appendChild(ruleContainer);

		var iso = false;
		var tileShape = tileroninX.getTileShape();
		if(tileShape == tileroninX.Shape.ISOMETRIC) {
			iso = true;
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
					tileroninX.replaceProxy(this.tile, tile, undoGroup, errorGroup);
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
module.exports = PropertyRelationProxyView;