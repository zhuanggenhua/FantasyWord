class ExportBlockField {
	constructor(blocks=[]) {
		this.blocks = blocks;
	}

	getBlocks() {
		return this.blocks;
	}

	insertBlock(block, i=-1) {
		if(i == -1) {
			this.blocks.push(block);
		} else {
			this.blocks.splice(z, 0, block);
		}
	}

	getText(dataset) {
		var text = "";
		for(var i in this.blocks) {
			text += this.blocks[i].getText(dataset);
		}
		return text;
	}
}
module.exports = ExportBlockField;