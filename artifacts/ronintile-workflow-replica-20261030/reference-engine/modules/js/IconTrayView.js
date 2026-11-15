var plh = require('./PointerLockHandler.js');
var CallbackManager = require('./CallbackManager.js');

class IconTrayView {
	constructor(icons, desc) {
		this.div = document.createElement('div');
		this.div.className = "icontray-view";
		this.div.style.zIndex = 2147483647;

		this.iconDown = -1;
		this.shiftDown = false;

		this.iconImgs = icons;
		this.desc = desc || [];
		this.iconEnabled = [];
		for(var i in this.iconImgs) {
			this.iconEnabled.push(true);
		}

		this.iconClickedCallback = new CallbackManager();
		this.tooltipCallback = new CallbackManager();

		plh.applyPointerLock(this.div, function() {
			plh.lockPointer();
		}, null, function() {
			if(this.iconDown != -1) {
				this.iconClickedCallback.notify(this.iconDown, this.shiftDown);
				var iconDivs = this.div.childNodes;
				iconDivs[this.iconDown].src = this.iconImgs[this.iconDown][0];
				this.iconDown = -1;
				this.shiftDown = false;
			}
		}.bind(this));

		for(var i = 0; i < this.iconImgs.length; i++) {
			var iconDiv = document.createElement('img');
			iconDiv.className = "icontray-icon-view";
			iconDiv.src = this.iconImgs[i][0];

			(function(iconDiv, i) {
				iconDiv.addEventListener("mousedown", function(event) {
					event.preventDefault();
					if(this.iconEnabled[i]) {
						this.iconDown = i;
						this.shiftDown = event.shiftKey;
						iconDiv.src = this.iconImgs[i][1];
					}
				}.bind(this), false);
				iconDiv.addEventListener("mouseover", function(event) {
					this.tooltipCallback.notify(this.desc[i] || null);
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

	iconClickedSubscribe(func) {
		this.iconClickedCallback.subscribe(func);
	}

	tooltipSubscribe(func) {
		this.tooltipCallback.subscribe(func);
	}

	setIconImage(i, off, on) {
		this.iconImgs[i] = [off, on];
		var iconDivs = this.div.childNodes;
		iconDivs[i].src = this.iconImgs[i][0];
	}

	enableIcon(i) {
		this.iconEnabled[i] = true;
		var iconDivs = this.div.childNodes;
		iconDivs[i].style.visibility = "visible";
	}

	disableIcon(i) {
		this.iconEnabled[i] = false;
		var iconDivs = this.div.childNodes;
		iconDivs[i].style.visibility = "hidden";
	}
}
module.exports = IconTrayView;
