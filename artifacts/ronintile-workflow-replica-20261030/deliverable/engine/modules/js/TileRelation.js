class TileRelation {
	constructor() {
		this.refCount = 0;
	}

	reference() {
		this.refCount++;
	}

	unreference() {
		this.refCount--;
	}
}
module.exports = TileRelation;