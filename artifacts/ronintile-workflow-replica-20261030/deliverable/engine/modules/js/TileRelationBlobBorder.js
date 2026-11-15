var TileRelation = require('./TileRelation.js');

class TileRelationBlobBorder extends TileRelation {
	constructor(im, b) {
		super();
		this.indexMatrix = im;
		this.isBorder = b;
	}

	getIndexMatrix() {
		return this.indexMatrix;
	}
}
module.exports = TileRelationBlobBorder;