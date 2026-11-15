var ExportBlock = require('./ExportBlock.js');

class ExportTextBlock extends ExportBlock {
	constructor(text="") {
		super();
		this.text = text;
	}

	setText(text) {
		this.text = text;
	}

	getText() {
		return this.text;
	}
}
module.exports = ExportTextBlock;