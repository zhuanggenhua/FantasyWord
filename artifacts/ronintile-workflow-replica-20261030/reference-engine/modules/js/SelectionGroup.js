class SelectionGroup {
	constructor() {
		this.selections = [];
		this.selected = [];
	}

	clear() {
		this.selections.length = 0;
		this.selected = [];
	}

	add(sel) {
		this.selected = this.selected.concat(sel.getSelected(this.selections));
		this.selections.push(sel);
	}

	getSelections() {
		return this.selections;
	}

	translate(x, y) {
		if(x == 0 && y == 0) { return; }
		for(var i = 0; i < this.selections.length; i++) {
			this.selections[i].translate(x, y);
		}
		var newSel = [];
		for(var i = 0; i < this.selected.length; i++) {
			newSel.push({x:this.selected[i].x+x, y:this.selected[i].y+y});
		}
		this.selected = newSel;
	}

	contains(x, y) {
		for(var i = 0; i < this.selections.length; i++) {
			var sel = this.selections[i];
			if(sel.contains(x, y)) {
				return true;
			}
		}
		return false;
	}

	getSelected() {
		return this.selected;
	}
}
module.exports = SelectionGroup;