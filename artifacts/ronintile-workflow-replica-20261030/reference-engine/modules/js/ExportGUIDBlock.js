var ExportTextVariableBlock = require('./ExportTextVariableBlock.js');
var guid = require('guid');

class ExportGUIDBlock extends ExportTextVariableBlock {
	constructor(variable, regex=[]) {
		super(variable, [], regex);
	}

	getTextRaw(dataset) {
		if(dataset['#RUNTIME'][this.variable+'#GUID'] == null) {
			dataset['#RUNTIME'][this.variable+'#GUID'] = guid.create().value;
		}
		return dataset['#RUNTIME'][this.variable+'#GUID'];
	}
}
module.exports = ExportGUIDBlock;