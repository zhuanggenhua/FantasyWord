class ScreenRegionView {
	constructor(div, minWidth, minHeight) {
		this.div = document.createElement('div');
		this.div.style.position = "absolute";
		this.div.style.left = 0;
		this.div.style.right = 0;
		this.div.style.top = 0;
		this.div.style.bottom = 0;
		this.div.style.zIndex = 0;
		if(div != null) {
			this.div.appendChild(div);
			div.style.minWidth = minWidth+'px';
			div.style.minHeight = minHeight+'px';
		}
		this.minWidth = 32;
		this.minHeight = 32;
	}

	getDiv() {
		return this.div;
	}

	getMinWidth() {
		return this.minWidth;
	}

	getMinHeight() {
		return this.minHeight;
	}

	updateContents() { }
}
module.exports = ScreenRegionView;