var plh = require('./PointerLockHandler.js');

var ScreenRegionView = require('./ScreenRegionView.js');
var CallbackManager = require('./CallbackManager.js');

var repositionX = function(offset) {
	if(!this.axis) {
		var offsetAdjusted = offset;

		var divASize = (+(this.div.style.left.replace(/px/g, "")) +offset);
		var pastMinSizeA = this.regionA.getMinWidth()-divASize;
		if(pastMinSizeA > 0) {
			offsetAdjusted += pastMinSizeA;
		}
		var divBSize = (+(this.container.offsetWidth-this.div.style.left.replace(/px/g, ""))-12 -offset);
		var pastMinSizeB = this.regionB.getMinWidth()-divBSize;
		if(pastMinSizeB > 0) {
			offsetAdjusted -= pastMinSizeB;
		}

		this.div.style.left = (offsetAdjusted+ +(this.div.style.left.replace(/px/g, "")))+'px';
		this.regionA.getDiv().style.width = (offsetAdjusted+ +(this.regionA.getDiv().style.width.replace(/px/g, "")))+'px';
		this.regionB.getDiv().style.left = (offsetAdjusted+ +(this.regionB.getDiv().style.left.replace(/px/g, "")))+'px';

		if(pastMinSizeA > 0) {
			this.pushAXCallback.notify(-pastMinSizeA);
		}
		if(pastMinSizeB > 0) {
			this.pushBXCallback.notify(pastMinSizeB);
		}
	}

	this.regionA.updateContents();
	this.regionB.updateContents();
}

var repositionY = function(offset) {
	if(this.axis) {
		var offsetAdjusted = offset;

		var divASize = (+(this.div.style.top.replace(/px/g, "")) +offset);
		var pastMinSizeA = this.regionA.getMinHeight()-divASize;
		if(pastMinSizeA > 0) {
			offsetAdjusted += pastMinSizeA;
		}
		var divBSize = (+(this.container.offsetHeight-this.div.style.top.replace(/px/g, ""))-12 -offset);
		var pastMinSizeB = this.regionB.getMinHeight()-divBSize;
		if(pastMinSizeB > 0) {
			offsetAdjusted -= pastMinSizeB;
		}

		this.div.style.top = (offsetAdjusted+ +(this.div.style.top.replace(/px/g, "")))+'px';
		this.regionA.getDiv().style.height = (offsetAdjusted+ +(this.regionA.getDiv().style.height.replace(/px/g, "")))+'px';
		this.regionB.getDiv().style.top = (offsetAdjusted+ +(this.regionB.getDiv().style.top.replace(/px/g, "")))+'px';

		if(pastMinSizeA > 0) {
			this.pushAYCallback.notify(-pastMinSizeA);
		}
		if(pastMinSizeB > 0) {
			this.pushBYCallback.notify(pastMinSizeB);
		}
	}

	this.regionA.updateContents();
	this.regionB.updateContents();
}

class ScreenSeparatorView extends ScreenRegionView {
	constructor(axis, regionA, regionB, pos) {
		super();

		this.div = document.createElement('div');
		this.axis = axis;
		this.regionA = regionA;
		this.regionB = regionB;

		this.pushAXCallback = new CallbackManager();
		this.pushAYCallback = new CallbackManager();
		this.pushBXCallback = new CallbackManager();
		this.pushBYCallback = new CallbackManager();
		if(!this.axis) {
			if(this.regionA instanceof ScreenSeparatorView) {
				this.regionA.pushAXSubscribe(function(offset) {
					this.pushAXCallback.notify(offset);
				}.bind(this));
				this.regionA.pushBXSubscribe(function(offset) {
					repositionX.bind(this)(offset);
				}.bind(this));

				this.regionA.pushAYSubscribe(function(offset) {
					this.pushAYCallback.notify(offset);
				}.bind(this));
				this.regionA.pushBYSubscribe(function(offset) {
					this.pushBYCallback.notify(offset);
				}.bind(this));
			}
			if(this.regionB instanceof ScreenSeparatorView) {
				this.regionB.pushAXSubscribe(function(offset) {
					repositionX.bind(this)(offset);
				}.bind(this));
				this.regionB.pushBXSubscribe(function(offset) {
					this.pushBXCallback.notify(offset);
				}.bind(this));

				this.regionB.pushAYSubscribe(function(offset) {
					this.pushAYCallback.notify(offset);
				}.bind(this));
				this.regionB.pushBYSubscribe(function(offset) {
					this.pushBYCallback.notify(offset);
				}.bind(this));
			}
		} else {
			if(this.regionA instanceof ScreenSeparatorView) {
				this.regionA.pushAYSubscribe(function(offset) {
					this.pushAYCallback.notify(offset);
				}.bind(this));
				this.regionA.pushBYSubscribe(function(offset) {
					repositionY.bind(this)(offset);
				}.bind(this));

				this.regionA.pushAXSubscribe(function(offset) {
					this.pushAXCallback.notify(offset);
				}.bind(this));
				this.regionA.pushBXSubscribe(function(offset) {
					this.pushBXCallback.notify(offset);
				}.bind(this));
			}
			if(this.regionB instanceof ScreenSeparatorView) {
				this.regionB.pushAYSubscribe(function(offset) {
					repositionY.bind(this)(offset);
				}.bind(this));
				this.regionB.pushBYSubscribe(function(offset) {
					this.pushBYCallback.notify(offset);
				}.bind(this));

				this.regionB.pushAXSubscribe(function(offset) {
					this.pushAXCallback.notify(offset);
				}.bind(this));
				this.regionB.pushBXSubscribe(function(offset) {
					this.pushBXCallback.notify(offset);
				}.bind(this));
			}
		}

		if(!this.axis) {
			this.div.className = "screenseparator-H-view";
		} else {
			this.div.className = "screenseparator-V-view";
		}
		this.setPosition(pos);

		plh.applyPointerLock(this.div, function() {
			event.stopPropagation();
		}, function(cX, cY, event) {
			if(!this.axis) {
				repositionX.bind(this)(event.scaledMovementX);
			} else {
				repositionY.bind(this)(event.scaledMovementY);
			}
		}.bind(this), null);

		this.container = document.createElement('div');
		this.container.className = "screenseparator-container-view";
		this.container.appendChild(this.regionA.getDiv());
		this.container.appendChild(this.regionB.getDiv());
		this.container.appendChild(this.div);
	}

	getDiv() {
		return this.container;
	}

	getMinWidth() {
		if(!this.axis) {
			return this.regionA.getMinWidth()+this.regionB.getMinWidth()+12;
		} else {
			return Math.max(this.regionA.getMinWidth(), this.regionB.getMinWidth());
		}
	}

	getMinHeight() {
		if(this.axis) {
			return this.regionA.getMinHeight()+this.regionB.getMinHeight()+12;
		} else {
			return Math.max(this.regionA.getMinHeight(), this.regionB.getMinHeight());
		}
	}

	updateContents() {
		repositionX.bind(this)(0);
		repositionY.bind(this)(0);
	}

	pushAXSubscribe(func) {
		this.pushAXCallback.subscribe(func);
	}

	pushAYSubscribe(func) {
		this.pushAYCallback.subscribe(func);
	}

	pushBXSubscribe(func) {
		this.pushBXCallback.subscribe(func);
	}

	pushBYSubscribe(func) {
		this.pushBYCallback.subscribe(func);
	}

	setPosition(pos) {
		if(!this.axis) {
			this.div.style.left = pos+'px';
			this.regionA.getDiv().style.width = pos+'px';
			this.regionB.getDiv().style.left = (pos+12)+'px';
		} else {
			this.div.style.top = pos+'px';
			this.regionA.getDiv().style.height = pos+'px';
			this.regionB.getDiv().style.top = (pos+12)+'px';
		}
	}

	getPosition() {
		if(!this.axis) {
			return parseInt(this.regionA.getDiv().style.width.replace(/px/g, ""));
		} else {
			return parseInt(this.regionA.getDiv().style.height.replace(/px/g, ""));
		}
	}
}
module.exports = ScreenSeparatorView;