var ExportBlock = require('./ExportBlock.js');
var ExportBlockField = require('./ExportBlockField.js');

var UserError = require('./UserError.js');

class ExportGridLoopBlock extends ExportBlock {
	constructor(variable, identifiers, gridWidth, gridHeight, gridX, gridY, nullContent=new ExportBlockField(), content=new ExportBlockField(), separatorX=new ExportBlockField(), separatorY=new ExportBlockField()) {
		super();
		this.variable = variable;
		this.identifiers = identifiers;
		this.gridWidth = gridWidth;
		this.gridHeight = gridHeight;
		this.gridX = gridX;
		this.gridY = gridY;
		this.nullContent = nullContent
		this.content = content;
		this.separatorX = separatorX;
		this.separatorY = separatorY;
	}

	getVariable() {
		return this.variable;
	}

	getGridWidth() {
		return this.gridWidth;
	}

	getGridHeight() {
		return this.gridHeight;
	}

	getGridX() {
		return this.gridX;
	}

	getGridY() {
		return this.gridY;
	}

	getNullContent() {
		return this.nullContent;
	}

	getContent() {
		return this.content;
	}

	getSeparatorX() {
		return this.separatorX;
	}

	getSeparatorY() {
		return this.separatorY;
	}

	getText(dataset) {
		var loopSet = dataset[this.variable];
		if(loopSet == null) {
			throw new UserError([{msg:"Invalid export format: Variable '"+this.variable+"' does not exist in scope.\nData has not been fully exported."}]);
		}
		if(tileroninXExport.getDatasetValueType(loopSet) != tileroninXExport.datasetType.LIST) {
			throw new UserError([{msg:"Invalid export format: Variable '"+this.variable+"' is not of list type.\nData has not been fully exported."}]);
		}
 		var grid = [];
 		var gridW = parseInt(this.gridWidth.getText(dataset));
 		var gridH = parseInt(this.gridHeight.getText(dataset));
 		var nullValue = this.nullContent.getText(dataset);
 		for(var y = 0; y < gridH; y++) {
 			grid[y] = [];
 			for(var x = 0; x < gridW; x++) {
 				grid[y][x] = nullValue;
 			}
 		}
 		for(var i = 0; i < loopSet.length; i++) {
 			tileroninXExport.useExportDatasetScopeSync(dataset, this.variable, i, this.identifiers, function(expandedDataset) {
				var contentX = parseInt(this.gridX.getText(expandedDataset));
				var contentY = parseInt(this.gridY.getText(expandedDataset));
				var contentText = this.content.getText(expandedDataset);
				if(contentX >= 0 && contentX < gridW && contentY >= 0 && contentY < gridH) {
					grid[contentY][contentX] = contentText
				}
			}.bind(this));
 		}
 		var text = "";
 		for(var y = 0; y < gridH; y++) {
 			for(var x = 0; x < gridW; x++) {
 				text += grid[y][x];
 				if(x < gridW-1) {
 					text += this.separatorX.getText(dataset);
 				}
 			}
 			if(y < gridH-1) {
				text += this.separatorY.getText(dataset);
			}
 		}
		return text;
	}
}
module.exports = ExportGridLoopBlock;