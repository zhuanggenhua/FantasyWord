var TileRelation = require('./TileRelation.js');

class TileRelationWang extends TileRelation {
	constructor(bset, o) {
		super();
		this.borderSet = bset;
		this.origin = o;
	}

	getBorderSet() {
		return this.borderSet;
	}

	reference() {
		super.reference();
		if(this.refCount == 1) {
			this.borderSet.reference();
		}
	}

	unreference() {
		super.unreference();
		if(this.refCount == 0) {
			this.borderSet.unreference();
		}
	}
}
module.exports = TileRelationWang;