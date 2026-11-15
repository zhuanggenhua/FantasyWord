class DirectoryTree {
	constructor() {
		this.children = [];
	}

	getDirectory(path) {
		if(path.length < 0) {
			return;
		} else if(path.length == 0) {
			return this
		} else {
			return this.children[path[0]].getDirectory(path.slice(1));
		}
	}

	getDirectories() {
		return this.children;
	}

	addDirectory(dir, path=null) {
		if(path && path.length < 0) {
			return;
		} else if(!path || path.length == 0) {
			this.children.push(dir);
			return this.children.length-1;
		} else {
			return this.children[path[0]].addDirectory(dir, path.slice(1));
		}
	}

	removeDirectory(path) {
		if(path.length < 1) {
			return;
		} else if(path.length == 1) {
			this.children.splice(path[0], 1);
		} else {
			this.children[path[0]].removeDirectory(path.slice(1));
		}
	}
}
module.exports = DirectoryTree