var ExportVisualBlock = require('./ExportVisualBlock.js');
var {nativeImage} = require('electron');

class ExportVisualImageBlock extends ExportVisualBlock {
	constructor(x, y, z, dataURL="") {
		super(x, y, z);
		this.image = nativeImage.createFromDataURL(dataURL);
	}

	getImages(dataset) {
		return [{x:parseInt(this.x.getText(dataset)), y:parseInt(this.y.getText(dataset)), z:parseInt(this.z.getText(dataset)), image:Promise.resolve(this.image)}];
	}
}
module.exports = ExportVisualImageBlock;