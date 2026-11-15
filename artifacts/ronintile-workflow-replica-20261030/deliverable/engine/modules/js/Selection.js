class Selection {
	constructor() {
		this.x0 = 0;
		this.y0 = 0;
		this.x1 = 0;
		this.y1 = 0;
	}

	getSelection() {
		return {x0:this.x0, y0:this.y0, x1:this.x1, y1:this.y1};
	}

	getSelectionNormalized() {
		var x0, x1, y0, y1;
		if(this.x1 >= this.x0) {
			x0 = this.x0;
			x1 = this.x1;
		} else {
			x0 = this.x1;
			x1 = this.x0;
		}
		if(this.y1 >= this.y0) {
			y0 = this.y0;
			y1 = this.y1;
		} else {
			y0 = this.y1;
			y1 = this.y0;
		}
		return {x0:x0, y0:y0, x1:x1, y1:y1};
	}

	setSelection(x0, y0, x1, y1) {
		this.x0 = x0;
		this.y0 = y0;
		this.x1 = x1;
		this.y1 = y1;
	}

	translate(x, y) {
		this.x0 += x;
		this.y0 += y;
		this.x1 += x;
		this.y1 += y;
	}

	contains(x, y) {
		return (this.x0 <= x && this.x1 >= x && this.y0 <= y && this.y1 >= y);
	}

	getSelected(exclude=[]) {
		var sel = [];
		for(var i = this.x0; i < this.x1+1; i++) {
			for(var j = this.y0; j < this.y1+1; j++) {
				var skip = false;
				for(var s = 0; s < exclude.length; s++) {
					var r = exclude[s];
					if(r.contains(i, j)) {
						skip = true;
						break;
					}
				}
				if(!skip) {
					sel.push({x:i, y:j});
				}
			}
		}
		return sel;
	}
}
module.exports = Selection;