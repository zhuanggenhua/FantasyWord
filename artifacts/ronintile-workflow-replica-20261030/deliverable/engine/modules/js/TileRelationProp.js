var TileRelation = require('./TileRelation.js');

class TileRelationProp extends TileRelation {
	constructor(x, y) {
		super();
		this.pos = {x:x, y:y};
	}
}
module.exports = TileRelationProp;