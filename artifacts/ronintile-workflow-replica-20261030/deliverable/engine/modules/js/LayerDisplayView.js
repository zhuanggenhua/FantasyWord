class LayerDisplayView {
	constructor() {
		this.div = document.createElement('div');
		this.div.className = "layerdisplay-view layerdisplay-view-hidden";
		this.focus = {x:0, y:0};
		this.focusedLayerIndex = 0;
	}

	setFocus(x, y) {
		this.focus = {x:x, y:y};
	}

	getFocus() {
		return this.focus;
	}

	selectLayer(i) {
		this.focusedLayerIndex = i;
	}

	getDiv() {
		return this.div;
	}
}

module.exports = LayerDisplayView;
