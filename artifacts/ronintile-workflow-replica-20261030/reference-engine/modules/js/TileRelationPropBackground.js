var TileRelation = require('./TileRelation.js');

class TileRelationPropBackground extends TileRelation {
	constructor(b) {
		super();
		this.isBackground = b;
	}
}
module.exports = TileRelationPropBackground;