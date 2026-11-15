var PropertyView = require('./PropertyView.js');

class PropertySeparatorView extends PropertyView {
	constructor() {
		super();
		this.div = document.createElement('div');
		this.div.className = "propertyseparator-view";
	}

	getDiv() {
		return this.div;
	}
}
module.exports = PropertySeparatorView;