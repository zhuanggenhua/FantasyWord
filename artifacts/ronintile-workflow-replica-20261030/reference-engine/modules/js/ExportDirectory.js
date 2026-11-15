var DirectoryTree = require('./DirectoryTree.js');

class ExportDirectory extends DirectoryTree {
	constructor(name) {
		super();
		this.name = name;
	}

	getName() {
		return this.name;
	}

	exportDirectory() {
		return Promise.resolve();
	}
}
module.exports = ExportDirectory;