var ExportDirectory = require('./ExportDirectory.js');

var UserError = require('./UserError.js');

class ExportLoopDirectory extends ExportDirectory {
	constructor(directory, variable, identifiers) {
		super(null);
		this.directory = directory;
		this.variable = variable;
		this.identifiers = identifiers;
	}

	exportDirectory(dataset, directory, folderFunction, fileFunction, p=Promise.resolve()) {
		var loopSet = dataset[this.variable];
		if(loopSet == null) {
			p = p.then(function() {
				throw new UserError([{msg:"Invalid export format: Variable '"+this.variable+"' does not exist in scope.\nData has not been fully exported."}]);
			}.bind(this));
			return p;
		}
		if(tileroninXExport.getDatasetValueType(loopSet) != tileroninXExport.datasetType.LIST) {
			p = p.then(function() {
				throw new UserError([{msg:"Invalid export format: Variable '"+this.variable+"' is not of list type.\nData has not been fully exported."}]);
			}.bind(this));
			return p;
		}
		for(var i = 0; i < loopSet.length; i++) {
			p = tileroninXExport.useExportDatasetScopeAsync(dataset, this.variable, i, p, this.identifiers, function(expandedDataset) {
				return this.directory.exportDirectory(expandedDataset, directory, folderFunction, fileFunction);
			}.bind(this));
		}
		return p;
	}

	getDirectory() {
		return this.directory;
	}
}
module.exports = ExportLoopDirectory;