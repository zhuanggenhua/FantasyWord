var ExportVisualBlock = require('./ExportVisualBlock.js');

var UserError = require('./UserError.js');

class ExportVisualImageVariableBlock extends ExportVisualBlock {
	constructor(x, y, z, variable) {
		super(x, y, z);
		this.variable = variable;
	}

	getImages(dataset) {
		var image = dataset[this.variable];
		if(image == null) {
			throw new UserError([{msg:"Invalid export format: Variable '"+this.variable+"' does not exist in scope.\nData has not been fully exported."}]);
		}
		if(tileroninXExport.getDatasetValueType(image) != tileroninXExport.datasetType.IMAGE) {
			throw new UserError([{msg:"Invalid export format: Variable '"+this.variables[i]+"' is not of image type.\nData has not been fully exported."}]);
		}
		return [{x:parseInt(this.x.getText(dataset)), y:parseInt(this.y.getText(dataset)), z:parseInt(this.z.getText(dataset)), image:image}];
	}
}
module.exports = ExportVisualImageVariableBlock;