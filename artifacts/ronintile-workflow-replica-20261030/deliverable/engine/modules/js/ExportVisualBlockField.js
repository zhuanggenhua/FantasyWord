var ExportNumberVariableBlock = require('./ExportNumberVariableBlock.js');

class ExportVisualBlockField {
	constructor(blocks=[], width=new ExportNumberVariableBlock([], [], "0"), height=new ExportNumberVariableBlock([], [], "0")) {
		this.blocks = blocks;
		this.width = width;
		this.height = height;
	}

	insertBlock(block, i=-1) {
		if(i == -1) {
			this.blocks.push(block);
		} else {
			this.blocks.splice(z, 0, block);
		}
	}

	getImages(dataset) {
		var imgs = [];
		for(var i in this.blocks) {
			imgs = imgs.concat(this.blocks[i].getImages(dataset));
		}
		return imgs;
	}

	getWidth(dataset) {
		return parseInt(this.width.getText(dataset));
	}

	getHeight(dataset) {
		return parseInt(this.height.getText(dataset));
	}
}
module.exports = ExportVisualBlockField;