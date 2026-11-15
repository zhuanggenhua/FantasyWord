var ExportFile = require('./ExportFile.js');
var ExportBlockField = require('./ExportBlockField.js');

class ExportTextFile extends ExportFile {
	constructor(name, field=new ExportBlockField()) {
		super(name);
		this.field = field;
	}

	getField() {
		return this.field;
	}

	getData(dataset) {
		return Promise.resolve(this.field.getText(dataset));
	}
}
module.exports = ExportTextFile;