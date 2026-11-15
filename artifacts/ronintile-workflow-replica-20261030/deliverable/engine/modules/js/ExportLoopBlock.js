var ExportBlock = require('./ExportBlock.js');
var ExportBlockField = require('./ExportBlockField.js');

var UserError = require('./UserError.js');

class ExportLoopBlock extends ExportBlock {
	constructor(variable, identifiers, content=new ExportBlockField(), separator=new ExportBlockField(), reverse=false) {
		super();
		this.variable = variable;
		this.identifiers = identifiers;
		this.content = content;
		this.separator = separator;
		this.reverse = reverse
	}

	getVariable() {
		return this.variable;
	}

	getContent() {
		return this.content;
	}

	getSeparator() {
		return this.separator;
	}

	getReverse() {
		return this.reverse;
	}

	getText(dataset) {
		var text = "";
		var loopSet = dataset[this.variable];
		if(loopSet == null) {
			throw new UserError([{msg:"Invalid export format: Variable '"+this.variable+"' does not exist in scope.\nData has not been fully exported."}]);
		}
		if(tileroninXExport.getDatasetValueType(loopSet) != tileroninXExport.datasetType.LIST) {
			throw new UserError([{msg:"Invalid export format: Variable '"+this.variable+"' is not of list type.\nData has not been fully exported."}]);
		}
		for(var i = 0; i < loopSet.length; i++) {
			var index = i;
			if(this.reverse) {
				index = loopSet.length-1-i;
			}
			tileroninXExport.useExportDatasetScopeSync(dataset, this.variable, index, this.identifiers, function(expandedDataset) {
				text += this.content.getText(expandedDataset);
			}.bind(this));
			if(i < loopSet.length-1) {
				text += this.separator.getText(dataset);
			}
		}
		return text;
	}
}
module.exports = ExportLoopBlock;