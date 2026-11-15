var plh = require('./PointerLockHandler.js');
var CallbackManager = require('./CallbackManager.js');

class IconTraySelectView {
	constructor(icons, init=0, desc) {
		this.div = document.createElement('div');
		this.div.className = "icontray-view";
		this.div.style.zIndex = 2147483647;

		this.icons = icons;
		this.desc = desc;

		this.iconDown = -1;
		this.iconSelected = init;

		this.iconSelectedCallback = new CallbackManager();
		this.tooltipCallback = new CallbackManager();

		plh.applyPointerLock(this.div, function() {
			plh.lockPointer();
		}, null, function() {
			if(this.iconDown != -1) {
				this.iconSelectedCallback.notify(this.iconDown);
				var iconDivs = this.div.childNodes;
				for(var i = 0; i < iconDivs.length; i++) {
					if(i != this.iconDown) {
						iconDivs[i].src = this.icons[i][0];
					}
				}
				this.iconSelected = this.iconDown;
				this.iconDown = -1;
			}
		}.bind(this));

		for(var i = 0; i < this.icons.length; i++) {
			var iconDiv = document.createElement('img');
			iconDiv.className = "icontray-icon-view";
			iconDiv.src = this.icons[i][0];
			if(i == init) {
				iconDiv.src = this.icons[i][1];
			}

			(function(iconDiv, i) {
				iconDiv.addEventListener("mousedown", function(event) {
					event.preventDefault();
					this.iconDown = i;
					iconDiv.src = this.icons[i][1];
				}.bind(this), false);
				iconDiv.addEventListener("mouseover", function(event) {
					this.tooltipCallback.notify(this.desc[i]);
				}.bind(this), false);
				iconDiv.addEventListener("mouseout", function(event) {
					this.tooltipCallback.notify(null);
				}.bind(this), false);
			}.bind(this))(iconDiv, i);

			this.div.appendChild(iconDiv);
		}
	}

	getDiv() {
		return this.div;
	}

	iconSelectedSubscribe(func) {
		this.iconSelectedCallback.subscribe(func);
	}

	tooltipSubscribe(func) {
		this.tooltipCallback.subscribe(func);
	}

	getSelected() {
		return this.iconSelected;
	}

	setSelected(x) {
		this.iconSelected = x;
		var iconDivs = this.div.childNodes;
		for(var i = 0; i < iconDivs.length; i++) {
			if(i != this.iconSelected) {
				iconDivs[i].src = this.icons[i][0];
			} else {
				iconDivs[i].src = this.icons[i][1];
			}
		}
	}
}
module.exports = IconTraySelectView;