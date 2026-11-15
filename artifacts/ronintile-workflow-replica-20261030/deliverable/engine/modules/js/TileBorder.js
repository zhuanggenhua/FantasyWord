var Tile = require('./Tile.js');

class TileBorder extends Tile {
	constructor(bgen) {
		super();
		this.bgen = bgen;
		this.bgen.setTile(this);
		this.rebuild(this.bgen.getLayers());
		this.bgen.contentUpdatedSubscribe(function() {
			this.rebuild(this.bgen.getLayers());
			this.contentUpdatedCallback.notify();
		}.bind(this));
	}

	getBorderGenerator() {
		return this.bgen;
	}
}
module.exports = TileBorder;