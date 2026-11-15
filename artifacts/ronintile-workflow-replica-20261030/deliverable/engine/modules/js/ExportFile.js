var ExportDirectory = require('./ExportDirectory.js');
var path = require('path');

class ExportFile extends ExportDirectory {
	constructor(name) {
		super(name);
	}

	getData() {
		return null;
	}

	exportDirectory(dataset, directory, folderFunction, fileFunction, p=Promise.resolve()) {
		p = p.then(function() {
			return this.getData(dataset).then(function(data) {
				return new Promise(function(resolve, reject) {
					fileFunction(path.join(directory, this.name.getText(dataset).replace(/\n/g, "").replace(/\t/g, "")), data, resolve, reject);
				}.bind(this));
			}.bind(this))
	    }.bind(this));
	    return p;
	}
}
module.exports = ExportFile;