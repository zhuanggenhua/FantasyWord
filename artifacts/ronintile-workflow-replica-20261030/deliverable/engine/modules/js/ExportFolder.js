var ExportDirectory = require('./ExportDirectory.js');
var ExportFile = require('./ExportFile.js');
var archiver = require('archiver');
var pulverized = require('pulverized');
var path = require('path');

var ExportModeEnum = Object.freeze({"DEFAULT":0, "TARGZ":1});

class ExportFolder extends ExportDirectory {
	constructor(name, exportMode=ExportModeEnum.DEFAULT) {
		super(name);
		this.exportMode = exportMode;
	}

	exportDirectory(dataset, directory, folderFunction, fileFunction, p=Promise.resolve()) {
		if(this.exportMode == ExportModeEnum.TARGZ) {
			var tar = archiver('tar');
			for(var i in this.children) {
				p = this.children[i].exportDirectory(dataset, "", function(fn, resolve, reject) {
			        resolve();
			    }, function(fn, data, resolve, reject) {
			        tar.append(data, { name: fn });
			        resolve();
			    }, p);
			}
			p = p.then(function() {
		    	return new Promise(function(resolve, reject) {
		    		tar.finalize();
		    		fileFunction(path.join(directory, this.name.getText(dataset).replace(/\n/g, "").replace(/\t/g, "")), tar.pipe(pulverized.compress.gz.stream()), resolve, reject, true);
			    }.bind(this));
		    }.bind(this));
		} else {
			p = p.then(function() {
		    	return new Promise(function(resolve, reject) {
		    		folderFunction(path.join(directory, this.name.getText(dataset).replace(/\n/g, "").replace(/\t/g, "")), resolve, reject);
			    }.bind(this));
		    }.bind(this));
		    for(var i in this.children) {
				p = this.children[i].exportDirectory(dataset, path.join(directory, this.name.getText(dataset).replace(/\n/g, "").replace(/\t/g, "")), folderFunction, fileFunction, p);
			}
		}
	    return p;
	}

	exportContents(dataset, directory, folderFunction, fileFunction) {
		var p = Promise.resolve();
		var dir = path.dirname(directory);
		for(var i in this.children) {
			p = this.children[i].exportDirectory(dataset, dir, folderFunction, fileFunction, p);
		}
		return p;
	}
}
module.exports = ExportFolder;