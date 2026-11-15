class TooltipView {
	constructor() {
		this.div = document.createElement('div');
		this.div.className = "tooltip-view";
	}

	open(msg) {
		this.div.innerHTML = "";

		var contentDiv = document.createElement('div');
		contentDiv.className = "tooltip-content-view";
		contentDiv.innerHTML = msg;
		this.div.appendChild(contentDiv);

		this.div.style.visibility = 'visible';
	}

	close() {
		this.div.style.visibility = 'hidden';
	}

	getDiv() {
		return this.div;
	}
}
module.exports = TooltipView;