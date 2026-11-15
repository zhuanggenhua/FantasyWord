var CallbackManager = require('./CallbackManager.js');

var TileRelation = require('./TileRelation.js');

class TileRelationProxy extends TileRelation {
	constructor(r, w=0) {
		super();
		this.isReverse = r;
		this.variationWeight = w;

		this.weightUpdatedCallback = new CallbackManager();
	}

	getWeight() {
		return this.variationWeight;
	}

	setWeight(w, undoGroup=[]) {
		var undoParams = {action:'variation_weight_change', rel:this, prev_value:this.variationWeight};
    	undoGroup.push(undoParams);

		this.variationWeight = w;
		this.weightUpdatedCallback.notify();
	}

	weightUpdatedSubscribe(func) {
		this.weightUpdatedCallback.subscribe(func);
	}

	weightUpdatedUnsubscribe(func) {
		this.weightUpdatedCallback.unsubscribe(func);
	}
}
module.exports = TileRelationProxy;