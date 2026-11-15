class CallbackManager {
	constructor() {
		this.callbacks = [];
		this.callbackRanks = [];
		this.maxRank = 0;
	}

	subscribe(func, rank=0) {
		var index = this.callbacks.length;
		this.callbacks[index] = func;
		this.callbackRanks[index] = rank;
		if(rank > this.maxRank) {
			this.maxRank = rank;
		}
		return index;
	}

	unsubscribe(func) {
		var index = this.callbacks.indexOf(func);
		if(index > -1) {
			delete this.callbacks[index];
			delete this.callbackRanks[index];
		}
	}

	unsubscribeIndex(index) {
		delete this.callbacks[index];
		delete this.callbackRanks[index];
	}

	notify() {
		var currentCallbacks = this.callbacks.slice();
		var currentCallbackRanks = this.callbackRanks.slice();
		for(var r = 0; r <= this.maxRank; r++) {
			for(var i in currentCallbacks) {
				if(currentCallbackRanks[i] == r) {
					currentCallbacks[i].apply(null, arguments);
				}
			}
		}
	}
}
module.exports = CallbackManager;