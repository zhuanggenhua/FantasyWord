var ExportBlock = require('./ExportBlock.js');
var mathjs = require('mathjs');

var UserError = require('./UserError.js');

class ExportNumberVariableBlock extends ExportBlock {
	constructor(variables, translations, expression="x0") {
		super();
		this.expression = expression;
		this.variables = variables;
		this.translations = translations;
	}

	getExpression() {
		return this.expression;
	}

	getText(dataset) {
		var variables = {};
		for(var i = 0; i < this.variables.length; i++) {
			var variable = dataset[this.variables[i]];
			if(variable == null) {
				throw new UserError([{msg:"Invalid export format: Variable '"+this.variables[i]+"' does not exist in scope.\nData has not been fully exported."}]);
			}
			var tl = this.translations[i];
			for(var tli in tl) {
				if(tl[tli][0] == variable) {
					variable = tl[tli][1];
					break;
				}
			}
			if(tileroninXExport.getDatasetValueType(variable) != tileroninXExport.datasetType.NUMBER) {
				throw new UserError([{msg:"Invalid export format: Variable '"+this.variables[i]+"' is not of number type.\nData has not been fully exported."}]);
			}
			variables['x'+i] = variable;
		}
		return mathjs.evaluate(this.expression, variables);
	}
}
module.exports = ExportNumberVariableBlock;