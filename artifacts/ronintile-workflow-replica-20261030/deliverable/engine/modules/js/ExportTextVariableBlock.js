var ExportBlock = require('./ExportBlock.js');

var UserError = require('./UserError.js');

class ExportTextVariableBlock extends ExportBlock {
	constructor(variable, translation, regex=[]) {
		super();
		this.variable = variable;
		this.translation = translation;
		this.regex = regex;
	}

	getVariable() {
		return this.variable;
	}

	getRegex() {
		return this.regex;
	}

	getTextRaw(dataset) {
		var variable = dataset[this.variable];
		if(variable == null) {
			throw new UserError([{msg:"Invalid export format: Variable '"+this.variable+"' does not exist in scope.\nData has not been fully exported."}]);
		}
		for(var tli in this.translation) {
			if(this.translation[tli][0] == variable) {
				variable = this.translation[tli][1];
				break;
			}
		}
		var varType = tileroninXExport.getDatasetValueType(variable);
		if(varType != tileroninXExport.datasetType.TEXT && varType != tileroninXExport.datasetType.NUMBER) {
			throw new UserError([{msg:"Invalid export format: Variable '"+this.variables[i]+"' is not of text or number type.\nData has not been fully exported."}]);
		}
		return variable.toString();
	}

	getText(dataset) {
		var text = this.getTextRaw(dataset);
		for(var i in this.regex) {
			var re = new RegExp(this.regex[i][0], 'g');
			text = text.replace(re, this.regex[i][1]);
		}
		return text;
	}
}
module.exports = ExportTextVariableBlock;