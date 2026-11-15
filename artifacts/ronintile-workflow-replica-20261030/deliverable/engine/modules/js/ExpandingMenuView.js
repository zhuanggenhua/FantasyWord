var plh = require('./PointerLockHandler.js');
var CallbackManager = require('./CallbackManager.js');

var loadOptions = function(options) {
	while(this.div.firstChild && this.div.removeChild(this.div.firstChild));
	while(this.subDiv.firstChild && this.subDiv.removeChild(this.subDiv.firstChild));
	this.submenus = [];
	this.openSubmenu = null;
	this.optionDown = -1;

	var optionIndex = 0;
	for(var i in options) {
		var optionSet = options[i];
		for(var j in optionSet) {
			var option = optionSet[j];
			var optionDiv = document.createElement('div');
			optionDiv.className = 'expandingmenu-option-view'
			optionDiv.style.color = 'var(--color2)';
			optionDiv.innerHTML = option.label;

			if(option.sub) {
				(function(optionDiv, index) {
					//add arrow icon
					var arrowDiv = document.createElement('img');
					arrowDiv.className = "expandingmenu-subicon-view";
					arrowDiv.src = "./../res/icon/ui_icon_dropdown_right_b.png";
					optionDiv.appendChild(arrowDiv);
					requestAnimationFrame(function() {
						var width = 22;
						optionDiv.style.paddingRight = width+"px";
						optionDiv.style.position = "relative";
						arrowDiv.style.right = (-16)+"px";
					});
					//register submenu
					var submenu = new ExpandingMenuView(option.sub);
					submenu.getDiv().style.position = "relative";
					this.submenus.push(submenu);
					this.subDiv.appendChild(submenu.getDiv());
					//callbacks
					submenu.optionClickedSubscribe(function(indices) {
						indices.unshift(index);
						this.optionClickedCallback.notify(indices);
						this.close();
					}.bind(this));
					//opening
					optionDiv.addEventListener("mouseover", function(event) {
						if(this.div.style.width !== '0px' && this.openSubmenu != submenu) {
							this.openSubmenu = submenu;
							for(var k in this.submenus) {
								this.submenus[k].close();
							}
							submenu.open(0, 0);
							submenu.getDiv().style.marginTop = (optionDiv.offsetTop-12)+'px';
						}
					}.bind(this));
				}.bind(this))(optionDiv, optionIndex);
			} else {
				(function(optionDiv, index) {
					optionDiv.addEventListener("mousedown", function(event) {
						event.preventDefault();
						this.optionDown = index;
						optionDiv.style.color = 'var(--colorSelect)';
					}.bind(this), false);
				}.bind(this))(optionDiv, optionIndex);
			}
			
			this.div.appendChild(optionDiv);

			optionIndex++;
		}

		if(i < options.length-1) {
			var optionSeparator = document.createElement('div');
			optionSeparator.className = 'expandingmenu-separator-view'
			this.div.appendChild(optionSeparator);
		}
	}
}

class ExpandingMenuView {
	constructor(options) {
		this.div = document.createElement('div');
		this.div.className = "expandingmenu-view";

		this.subDiv = document.createElement('div');
		this.subDiv.className = "expandingmenu-subcontainer-view";
		this.submenus = [];
		this.openSubmenu = null;

		this.containerDiv = document.createElement('div');
		this.containerDiv.className = "expandingmenu-container-view";
		this.containerDiv.appendChild(this.div);
		this.containerDiv.appendChild(this.subDiv);

		this.div.addEventListener("transitionend", function(event) {
			if(this.div.style.width.replace(/px/g, "") == 0) {
				this.div.style.display = 'none';
				this.div.style.visibility = 'hidden';
			}
		}.bind(this), false);

		this.optionDown = -1;

		this.optionClickedCallback = new CallbackManager();

		plh.applyPointerLock(this.div, function(clientX, clientY, ev) {
			plh.lockPointer();
			if(ev && typeof ev.stopPropagation === "function") {
				ev.stopPropagation();
			}
		}, null, function() {
			if(this.optionDown != -1) {
				this.optionClickedCallback.notify([this.optionDown]);
				var optionDivs = this.div.childNodes;
				for(var i = 0; i < optionDivs.length; i++) {
					if(optionDivs[i].className == "expandingmenu-option-view") {
				    	optionDivs[i].style.color = 'var(--color2)';
				    }
				}
				this.optionDown = -1;
				this.close();
			}
		}.bind(this));

		loadOptions.bind(this)(options);

		requestAnimationFrame(function() {
			this.div.style.display = 'none';
		}.bind(this));
	}

	open(x, y) {
		this.openSubmenu = null;
		this.div.style.display = 'block';
		this.div.style.visibility = 'visible';
		this.div.style.width = 'auto';
		requestAnimationFrame(function() {
			var elementTransition = this.div.style.transition;
	  		this.div.style.transition = '';
			var fullSize = this.div.scrollWidth+'px';
			this.div.style.width = '0px';
			requestAnimationFrame(function() {
				this.div.style.transition = elementTransition;
				this.div.style.width = fullSize;
			}.bind(this));
		}.bind(this));

		this.containerDiv.style.left = x+'px';
		this.containerDiv.style.top = y+'px';
	}

	close() {
		this.div.style.width = '0px';
		for(var k in this.submenus) {
			this.submenus[k].close();
			this.submenus[k].getDiv().style.top = this.submenus[k].getDiv().style.marginTop;
			this.submenus[k].getDiv().style.marginTop = '0px';
		}
	}

	setOptions(options) {
		loadOptions.bind(this)(options);
		this.close();
	}

	getDiv() {
		return this.containerDiv;
	}

	optionClickedSubscribe(func) {
		this.optionClickedCallback.subscribe(func);
	}
}
module.exports = ExpandingMenuView;