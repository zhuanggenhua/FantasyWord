var PropertyView = require('./PropertyView.js');
var ErrorDisplayView = require('./ErrorDisplayView.js');

class PropertyRelationView extends PropertyView {
	constructor(label) {
		super();
		this.div = document.createElement('div');
		this.div.className = "propertyrelation-container-view";

		this.contentDiv = document.createElement('div');
		this.contentDiv.className = "propertyrelation-view";
		this.div.appendChild(this.contentDiv);

		var text = document.createElement('div');
		text.className = "propertyrelation-text-view";
		text.innerHTML = label;
		this.contentDiv.appendChild(text);

		this.errorDisplay = new ErrorDisplayView(true);
		this.errorDisplay.getDiv().style.position = "relative";
		this.errorDisplay.getDiv().style.transform = "none";
		this.errorDisplay.getDiv().style.display = "inline-block";
		this.errorDisplay.getDiv().style.marginLeft = "auto";
		this.errorDisplay.getDiv().style.marginRight = "auto";
		this.errorDisplay.getDiv().children[0].style.top = "0px";
		this.errorDisplay.getDiv().children[1].style.top = "-9px";
		this.errorDisplay.getDiv().style.marginTop = "-8px";
		this.div.appendChild(this.errorDisplay.getDiv());
	}

	getDiv() {
		return this.div;
	}
}
module.exports = PropertyRelationView;