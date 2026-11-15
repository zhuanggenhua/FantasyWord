var TileRelation = require('./TileRelation.js');
var TileRelationWang = require('./TileRelationWang.js');

class TileRelationWangPre2_0_0 extends TileRelation {
	constructor(bset, m, base0, base1) {
		super();
		this.bset = bset;
		this.m = m;

		//

		this.baseTile0 = base0;
		this.baseTile1 = base1;

		var rel = new TileRelationWang(this.bset, this.baseTile0);
		this.baseTile0.registerRelation(this.baseTile1, rel, []);
		this.baseTile1.registerRelation(this.baseTile0, rel, []);

		var newIndex = [0, 1, 3, 2];
		this.indexMatrix = [this.baseTile1, this.baseTile1, this.baseTile1, this.baseTile1];
		for(var a = 0; a < 4; a++) {
			if((m & (1 << a)) != 0) {
				this.indexMatrix[newIndex[a]] = this.baseTile0;
			}
		}
	}

	getBaseSource0() {
		return this.baseTile0.getSource();
	}

	getBaseSource1() {
		return this.baseTile1.getSource();
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
module.exports = TileRelationWangPre2_0_0;