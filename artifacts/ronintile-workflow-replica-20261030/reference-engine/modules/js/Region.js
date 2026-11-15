var Selection = require('./Selection.js');
var CallbackManager = require('./CallbackManager.js');

class Region {
	constructor(x0, y0, x1, y1) {
		this.bounds = new Selection();
		this.bounds.setSelection(x0, y0, x1, y1);
		this.valid = true;

		this.displayChangedCallback = new CallbackManager();
	}

	getBounds() {
		return this.bounds.getSelection();
	}

	setBounds(x0, y0, x1, y1) {
		this.bounds.setSelection(x0, y0, x1, y1);
		this.displayChangedCallback.notify();
	}

	isValid() {
		return this.valid;
	}

	setValid(valid) {
		this.valid = valid;
		this.displayChangedCallback.notify();
	}

	getSelected() {
		return this.bounds.getSelected();
	}

	initRegion() {

	}

	finRegion() {

	}

	getLabel() {
		return null;
	}

	translate(ox, oy) {
		this.bounds.translate(ox, oy);
	}

	displayChangedSubscribe(func) {
		this.displayChangedCallback.subscribe(func);
	}
}
module.exports = Region;