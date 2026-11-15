var ExportVisualBlock = require('./ExportVisualBlock.js');
var ExportVisualBlockField = require('./ExportVisualBlockField.js');

var UserError = require('./UserError.js');

class ExportVisualLoopBlock extends ExportVisualBlock {
	constructor(x, y, z, variable, identifiers, content=new ExportVisualBlockField()) {
		super(x, y, z);
		this.variable = variable;
		this.identifiers = identifiers;
		this.content = content;
	}

	getContent() {
		return this.content;
	}

	getImages(dataset) {
		var imgs = [];
		var loopSet = dataset[this.variable];
		if(loopSet == null) {
			throw new UserError([{msg:"Invalid export format: Variable '"+this.variable+"' does not exist in scope.\nData has not been fully exported."}]);
		}
		if(tileroninXExport.getDatasetValueType(loopSet) != tileroninXExport.datasetType.LIST) {
			throw new UserError([{msg:"Invalid export format: Variable '"+this.variable+"' is not of list type.\nData has not been fully exported."}]);
		}
		for(var i = 0; i < loopSet.length; i++) {
			tileroninXExport.useExportDatasetScopeSync(dataset, this.variable, i, this.identifiers, function(expandedDataset) {
				imgs = imgs.concat(this.content.getImages(expandedDataset));
			}.bind(this));
		}
		return imgs;
	}
}
module.exports = ExportVisualLoopBlock;