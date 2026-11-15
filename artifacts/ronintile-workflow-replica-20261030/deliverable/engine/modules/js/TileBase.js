var Tile = require('./Tile.js');

var setSource = function(src) {
	if(this.callback != null) {
		this.source.sourceChangedUnsubscribe(this.callback);
	}

	if(this.inSet) {
		if(this.source != null) {
			this.source.unreference();
		}
		src.reference();
	}
	this.source = src;
	var cbfn = function(newSrc) {
		setSource.bind(this)(newSrc);
		this.rebuild([this.source.getImage()]);
		this.contentUpdatedCallback.notify();
	}.bind(this);
	this.callback = cbfn;
	this.source.sourceChangedSubscribe(cbfn);
}

class TileBase extends Tile {
	constructor(src) {
		super();
		this.callback = null;
		setSource.bind(this)(src);
		this.rebuild([this.source.getImage()]);
	}

	getSource() {
		return this.source;
	}

	reference() {
		if(this.inSet == false) {
			this.source.reference();
		}
		super.reference();
	}

	unreference() {
		if(this.inSet == true) {
			this.source.unreference();
		}
		super.unreference();
	}
}
module.exports = TileBase;