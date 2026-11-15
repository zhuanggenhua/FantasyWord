var PropertyRelationView = require('./PropertyRelationView.js');
var plh = require('./PointerLockHandler.js');
var CallbackManager = require('./CallbackManager.js');

var PropertyEditTextView = require('./PropertyEditTextView.js');

var TileRelationProxy = require('./TileRelationProxy.js');

var updatePercentages = function() {
	var totalWeight = 0;
	for(var v in this.variations) {
		totalWeight += this.variations[v][0].getWeight();
	}
	for(var v in this.variations) {
		var vn = this.variations[v];
		vn[1].innerHTML = Math.floor(vn[0].getWeight()*100/totalWeight)+"%";
	}
}

var loadDisplay = function() {
	for(var i in this.tileContentCallbacks) {
		this.tileContentCallbacks[i][0].contentUpdatedUnsubscribe(this.tileContentCallbacks[i][1]);
	}
	this.tileContentCallbacks = [];
	for(var i in this.registeredCallbacks) {
		this.registeredCallbacks[i].r.weightUpdatedUnsubscribe(this.registeredCallbacks[i].callback);
	}
	this.registeredCallbacks = [];

	this.scrollContainer.innerHTML = "";
	this.variations = [];

	var iso = false;
	var tileShape = tileroninX.getTileShape();
	if(tileShape == tileroninX.Shape.ISOMETRIC) {
		iso = true;
	}

	var loadVariation = function(rr, rt) {
		var variationContainer = document.createElement('div');
		variationContainer.className = "propertyrelationvariation-variation-container-view";

		var tileDisplay = document.createElement('div');
		tileDisplay.className = "propertyrelationvariation-tile-image-view";
		var tileDisplay2 = document.createElement('div');
		tileDisplay2.className = "propertyrelationblob-tile-image-rule-large-view-display";
		tileDisplay.appendChild(tileDisplay2);
		if(iso) {
			tileDisplay.style.transform = "rotate(45deg)";
			tileDisplay2.style.transform = "translate(-50%, -50%) rotate(-45deg)";
			tileDisplay2.style.left = "50%";
			tileDisplay2.style.top = "50%";
			tileDisplay.style.width = (32/Math.sqrt(2))+"px";
			tileDisplay.style.height = tileDisplay.style.width;
		}
		///////////////////
		var displayTile = rt;
		var tileSlotUpdateImage = function() {
			displayTile.getImage().then(function(img) {
				var downscale = document.createElement("canvas");
				downscale.height = 96;
				downscale.width = 96;
				var ctx = downscale.getContext("2d");
				ctx.imageSmoothingEnabled = false;
				ctx.webkitImageSmoothingEnabled = false;
				ctx.mozImageSmoothingEnabled = false;

				ctx.drawImage(img, 0, 0, 96, 96);

				tileDisplay2.style.backgroundImage = 'url(\"'+downscale.toDataURL()+'\")';
			}.bind(this));
		}.bind(this)
		tileSlotUpdateImage();
		displayTile.contentUpdatedSubscribe(tileSlotUpdateImage);
		this.tileContentCallbacks.push([displayTile, tileSlotUpdateImage]);
		///////////////////
		variationContainer.appendChild(tileDisplay);

		var weightText = new PropertyEditTextView("Weight", rr.getWeight(), "", true);
		weightText.getDiv().children[1].style.borderColor = "var(--color1)";
		weightText.getDiv().children[1].style.position = "static";
		///////////////////
		weightText.valueChangedSubscribe(function(value) {
			var undoGroup = [];
			tileroninX.setVariationWeight(this.tile, rt, parseInt(value), undoGroup);
			tileroninX.saveUndoState(undoGroup);
		}.bind(this));
		var weightCallbackFunc = function() {
			weightText.setValue(rr.getWeight());
			updatePercentages.bind(this)();
		}.bind(this);
		this.registeredCallbacks.push({r:rr, callback:weightCallbackFunc});
		rr.weightUpdatedSubscribe(weightCallbackFunc);
		///////////////////
		variationContainer.appendChild(weightText.getDiv());

		var probText = document.createElement('div');
		probText.className = "propertyrelationvariation-text-view";
		///////////////////
		this.variations.push([rr, probText]);
		///////////////////
		variationContainer.appendChild(probText);

		this.scrollContainer.appendChild(variationContainer);
	}.bind(this);

	var fRel = this.tile.getRelation(this.tile);
	if(fRel instanceof TileRelationProxy && fRel.isReverse) {
		loadVariation(fRel, this.tile);
	}
	var rel = this.tile.getRelations();
	for(var i in rel) {
		var r = rel[i];
		if(r.r instanceof TileRelationProxy && r.r.isReverse && r.t != this.tile) {
			loadVariation(r.r, r.t);
		}
	}
	updatePercentages.bind(this)();
}

class PropertyRelationVariationView extends PropertyRelationView {
	constructor(tile) {
		super("Variations");

		this.tile = tile;
		this.variations = [];
		this.tileContentCallbacks = [];
		this.registeredCallbacks = [];
		this.relationsUpdatedCallback = function() {
			loadDisplay.bind(this)();
		}.bind(this);
		this.tile.relationsUpdatedSubscribe(this.relationsUpdatedCallback);

		this.scrollContainer = document.createElement('div');
		this.scrollContainer.className = "propertyrelationvariation-scroll-view";
		this.contentDiv.appendChild(this.scrollContainer);

		loadDisplay.bind(this)();
	}

	getDiv() {
		return this.div;
	}

	clearCallbacks() {
		this.tile.relationsUpdatedUnsubscribe(this.relationsUpdatedCallback);

		for(var i in this.tileContentCallbacks) {
			this.tileContentCallbacks[i][0].contentUpdatedUnsubscribe(this.tileContentCallbacks[i][1]);
		}
		this.tileContentCallbacks = [];
		for(var i in this.registeredCallbacks) {
			this.registeredCallbacks[i].r.weightUpdatedUnsubscribe(this.registeredCallbacks[i].callback);
		}
		this.registeredCallbacks = [];
	}
}
module.exports = PropertyRelationVariationView;