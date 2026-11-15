var TileRelation = require('./TileRelation.js');
var TileRelationBlob = require('./TileRelationBlob.js');

class TileRelationBlobPre2_0_0 extends TileRelation {
	constructor(bset, m, base) {
		super();
		this.bset = bset;
		this.m = m;

		//

		this.baseTile = base;

		this.baseTile.registerRelation(false, new TileRelationBlob(this.bset, this.baseTile), []);

		var newIndex = [0, 1, 2, 7, 3, 6, 5, 4];
		this.indexMatrix = [false, false, false, false, false, false, false, false];
		for(var a = 0; a < 8; a++) {
			if((m & (1 << a)) != 0) {
				this.indexMatrix[newIndex[a]] = this.baseTile;
			}
		}
	}

	getBaseSource() {
		return this.baseTile.getSource();
	}

	getBaseTile() {
		return this.baseTile;
	}

	getIndexMatrix() {
		return this.indexMatrix;
	}

	reference() {
		super.reference();
		if(this.refCount == 1) {
			this.bset.reference();
		}
	}

	unreference() {
		super.unreference();
		if(this.refCount == 0) {
			this.bset.unreference();
		}
	}
}
module.exports = TileRelationBlobPre2_0_0;