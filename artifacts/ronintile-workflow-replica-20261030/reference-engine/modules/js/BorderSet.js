var CallbackManager = require('./CallbackManager.js');

class BorderSet {
	constructor() {
		this.contentUpdatedCallback = new CallbackManager();
		this.refCount = 0;
	}

	contentUpdatedSubscribe(func) {
		this.contentUpdatedCallback.subscribe(func);
	}

	contentUpdatedUnsubscribe(func) {
		this.contentUpdatedCallback.unsubscribe(func);
	}

	contentUpdatedUnsubscribeIndex(func) {
		this.contentUpdatedCallback.unsubscribeIndex(func);
	}

	reference() {
		this.refCount++;
	}

	unreference() {
		this.refCount--;
	}
}
module.exports = BorderSet;