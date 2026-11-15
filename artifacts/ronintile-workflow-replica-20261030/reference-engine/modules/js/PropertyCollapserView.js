var PropertyView = require('./PropertyView.js');
var PropertySeparatorView = require('./PropertySeparatorView.js');
var plh = require('./PointerLockHandler.js');

class PropertyCollapserView extends PropertyView {
	constructor(text, initState=false) {
		super();
		this.div = document.createElement('div');
		this.div.className = "propertycollapser-view";

		var labelDiv = document.createElement('div');
		labelDiv.className = "propertycollapser-label-view";

		var dropdownDiv = document.createElement('img');
		dropdownDiv.className = "propertycollapser-dropdown-view";
		dropdownDiv.src = "./../res/icon/ui_icon_dropdown.png";
		labelDiv.appendChild(dropdownDiv);

		var textDiv = document.createElement('div');
		textDiv.className = "propertycollapser-text-view";
		textDiv.innerHTML = text;
		labelDiv.appendChild(textDiv);

		this.div.appendChild(labelDiv);

		this.containerDiv = document.createElement('div');
		this.containerDiv.className = "propertycollapser-container-view";

		this.contentsDiv = document.createElement('div');
		this.contentsDiv.className = "propertycollapser-contents-view";
		this.containerDiv.appendChild(this.contentsDiv);

		this.div.appendChild(this.containerDiv);

		this.containerDiv.addEventListener("transitionend", function(event) {
			if(this.expanded) {
				this.containerDiv.style.overflowY = 'visible';
				this.containerDiv.style.height = 'auto';
			}
		}.bind(this), false);

		if(initState) {
			this.expanded = true;
			dropdownDiv.src = "./../res/icon/ui_icon_dropdown.png";
		} else {
			this.expanded = false;
			this.containerDiv.style.height = '0px';
			this.containerDiv.style.overflowY = 'hidden';
			dropdownDiv.src = "./../res/icon/ui_icon_dropdown_right.png";
		}

		plh.applyPointerLock(labelDiv, function() {
			plh.lockPointer();
			textDiv.style.color = 'var(--colorSelect)';
			if(!this.expanded) {
				dropdownDiv.src = "./../res/icon/ui_icon_dropdown_right_b.png";
			} else {
				dropdownDiv.src = "./../res/icon/ui_icon_dropdown_b.png";
			}
		}.bind(this), null, function() {
			if(!this.expanded) {
				this.expanded = true;
				this.containerDiv.style.height = this.contentsDiv.clientHeight+'px';
				if(this.contentsDiv.clientHeight == 0) {
					this.containerDiv.style.height = 'auto';
				}
				dropdownDiv.src = "./../res/icon/ui_icon_dropdown.png";
			} else {
				this.expanded = false;
				this.containerDiv.style.overflowY = 'hidden';
				requestAnimationFrame(function() {
					this.containerDiv.style.height = this.contentsDiv.clientHeight+'px';
					requestAnimationFrame(function() {
						this.containerDiv.style.height = '0px';
					}.bind(this));
				}.bind(this));
				dropdownDiv.src = "./../res/icon/ui_icon_dropdown_right.png";
			}
			textDiv.style.color = 'var(--color2)';
		}.bind(this));

		var separator = new PropertySeparatorView();
		this.div.appendChild(separator.getDiv());
	}

	getDiv() {
		return this.div;
	}

	addDiv(div) {
		this.contentsDiv.appendChild(div);
	}

	isExpanded() {
		return this.expanded;
	}
}
module.exports = PropertyCollapserView;