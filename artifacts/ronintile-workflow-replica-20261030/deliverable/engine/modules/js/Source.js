var tileroninX = require('./tileroninX.js');
var CallbackManager = require('./CallbackManager.js');

class Source {
	constructor() {
		this.sourceChangedCallback = new CallbackManager();
		tileroninX.pushGlobalSource(this);

		this.size = tileroninX.getTileSize();
		this.imageCache = null;

		this.cbfn = function(size) {
			this.sourceChangedCallback.notify(this);
		}.bind(this);
		tileroninX.tileSizeChangedSubscribe(this.cbfn);

		this.refCount = 0;
	}

	setSource(src, undoGroup=[]) {
		var undoParams = {action:'source_replace', current_src:src, prev_src:this};
		undoGroup.push(undoParams);
    	
		this.sourceChangedCallback.notify(src);
    	tileroninX.pushGlobalSource(src);
		tileroninX.removeGlobalSource(this);
	}

	sourceChangedSubscribe(func, rank=0) {
		this.sourceChangedCallback.subscribe(func, rank);
	}

	sourceChangedUnsubscribe(func) {
		this.sourceChangedCallback.unsubscribe(func);
	}
	
	getImage() {
		return null;
	}

	unload() {
		tileroninX.tileSizeChangedUnsubscribe(this.cbfn);
	}

	reference() {
		this.refCount++;
	}

	unreference() {
		this.refCount--;
	}
}
module.exports = Source;