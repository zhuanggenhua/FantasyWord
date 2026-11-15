var tileroninX = require('./tileroninX.js');

var plh = require('./PointerLockHandler.js');
var CallbackManager = require('./CallbackManager.js');

var PropertyView = require('./PropertyView.js');

var SourceImage = require('./SourceImage.js');

var {nativeImage} = require('electron');
var path = require('path');

var TileBase = require('./TileBase.js');

var ErrorDisplayView = require('./ErrorDisplayView.js');

class PropertySourceView extends PropertyView {
	constructor(text, src, locked=false) {
		super();
		this.locked = locked;
		this.div = document.createElement('div');
		this.div.className = "propertysource-view";

		this.textDiv = document.createElement('div');      
		this.textDiv.innerHTML = text+":";
		this.div.appendChild(this.textDiv);

		this.step = 1;
		this.iso = false;
		var tileShape = tileroninX.getTileShape();
		if(tileShape == tileroninX.Shape.ISOMETRIC) {
			var tileSize = tileroninX.getTileSize();
			this.step = tileSize[0]/tileSize[1];
			this.iso = true;
		}

		tileroninX.tileSizeChangedSubscribe(function(size) {
			var tileShape = tileroninX.getTileShape();
			if(tileShape == tileroninX.Shape.ISOMETRIC) {
				this.step = size[0]/size[1];
				this.iso = true;
			} else {
				this.step = 1;
				this.iso = false;
			}
			baseDiv.style.width = (Math.min(3*32*this.step+6, maxWidth+2)+8)+"px";
			containerDiv.style.width = (Math.min(3*32*this.step+6, maxWidth+2)+8)+"px";
			displayDiv.style.width = (Math.min(3*32*this.step+6, maxWidth+2)+8)+"px";
			var iw = 16;
			var ih = 16/this.step;
			this.imageDiv.style.height = ih+"px";
			this.imageDiv.style.backgroundSize = iw+"px "+ih+"px";
			scrollDiv.style.width = (Math.min(3*32*this.step+6, maxWidth+2)+8)+"px";
			scrollDisplayDiv.style.width = (Math.min(3*32*this.step+6, maxWidth+2)+2)+"px";
		}.bind(this));

		var maxWidth = 256;

		var baseDiv = document.createElement('div');
		baseDiv.className = "propertysource-scrollbase-view";
		baseDiv.style.width = (Math.min(3*32*this.step+6, maxWidth+2)+8)+"px";
		this.div.appendChild(baseDiv);

		var containerDiv = document.createElement('div');
		containerDiv.className = "propertysource-scrollcontainer-view";
		containerDiv.style.width = (Math.min(3*32*this.step+6, maxWidth+2)+8)+"px";
		baseDiv.appendChild(containerDiv);

		var displayDiv = document.createElement('div');
		displayDiv.className = "propertysource-display-view";
		displayDiv.style.backgroundColor = "var(--colorBG)";
		displayDiv.style.width = (Math.min(3*32*this.step+6, maxWidth+2)+8)+"px";
		containerDiv.appendChild(displayDiv);
		this.imageDiv = document.createElement('div');
		this.imageDiv.className = "propertysource-image-view";
		var iw = 16;
		var ih = 16/this.step;
		this.imageDiv.style.height = ih+"px";
		this.imageDiv.style.backgroundSize = iw+"px "+ih+"px";
		displayDiv.appendChild(this.imageDiv);
		this.textDivDisplay = document.createElement('div');
		displayDiv.appendChild(this.textDivDisplay);

		this.displayHighlightDiv = document.createElement('div');
		this.displayHighlightDiv.className = "propertysource-highlight-view";
		displayDiv.appendChild(this.displayHighlightDiv);

		if(!this.locked) {
			this.dropdownDiv = document.createElement('img');
			this.dropdownDiv.className = "propertysource-dropdown-view";
			this.dropdownDiv.src = "./../res/icon/ui_icon_dropdown.png";
			displayDiv.appendChild(this.dropdownDiv);
		}

		this.iconDiv = document.createElement('img');
		this.iconDiv.className = "propertysource-icon-view";
		this.iconDiv.style.marginTop = "3px";
		this.iconDiv.style.marginBottom = "1px";
		this.iconDiv.src = "./../res/icon/ui_icon_c1.png";
		this.div.appendChild(this.iconDiv);
		this.iconDiv.addEventListener("mouseover", function(event) {
			this.tooltipCallback.notify("Open Source");
		}.bind(this), false);
		this.iconDiv.addEventListener("mouseout", function(event) {
			this.tooltipCallback.notify(null);
		}.bind(this), false);

		this.iconDown = 0;
		this.selectedTile = false;

		this.iconDiv.addEventListener("mousedown", function(event) {
			if(this.selectedTile) {
				return;
			}
			event.preventDefault();
			this.iconDown = 1;
			this.iconDiv.src = "./../res/icon/ui_icon_b1.png";
		}.bind(this), false);

		if(!this.locked) {
			this.icon2Div = document.createElement('img');
			this.icon2Div.className = "propertysource-icon-view";
			this.icon2Div.style.marginLeft = "-4px";
			this.icon2Div.style.marginRight = "-2px";
			this.icon2Div.style.marginTop = "3px";
			this.icon2Div.style.marginBottom = "1px";
			this.icon2Div.src = "./../res/icon/ui_icon_c29.png";
			this.div.appendChild(this.icon2Div);
			this.icon2Div.addEventListener("mouseover", function(event) {
				this.tooltipCallback.notify("Pick Source");
			}.bind(this), false);
			this.icon2Div.addEventListener("mouseout", function(event) {
				this.tooltipCallback.notify(null);
			}.bind(this), false);

			this.icon2Div.addEventListener("mousedown", function(event) {
				if(this.selectedTile) {
					return;
				}
				event.preventDefault();
				this.iconDown = 2;
				this.icon2Div.src = "./../res/icon/ui_icon_a29.png";
			}.bind(this), false);

			this.errorDisplay = new ErrorDisplayView(false);
			this.errorDisplay.getDiv().style.position = "relative";
			this.errorDisplay.getDiv().style.transform = "none";
			this.errorDisplay.getDiv().style.display = "inline-block";
			this.errorDisplay.getDiv().style.marginLeft = "0px";
			this.errorDisplay.getDiv().style.marginBottom = "-18px";
			this.errorDisplay.getDiv().style.marginTop = "-18px";
			this.div.appendChild(this.errorDisplay.getDiv());
		}

		this.callback = null;

		this.setSource.bind(this)(src);

		var scrollDiv = document.createElement('div');
		scrollDiv.className = "propertysource-scroll-view";
		scrollDiv.style.width = (Math.min(3*32*this.step+6, maxWidth+2)+8)+"px";
		containerDiv.appendChild(scrollDiv);

		var scrollDisplayDiv = document.createElement('div');
		scrollDisplayDiv.className = "propertysource-scroll-display-view";
		scrollDisplayDiv.style.width = (Math.min(3*32*this.step+6, maxWidth+2)+2)+"px";
		scrollDiv.appendChild(scrollDisplayDiv);

		this.srcSelected = null;
		this.sourceOpenedCallback = new CallbackManager();
		this.sourceChangedCallback = new CallbackManager();
		this.sourcePickingCallback = new CallbackManager();
		this.tooltipCallback = new CallbackManager();

		function openMenu() {
			containerDiv.style.height = (scrollDiv.clientHeight+displayDiv.clientHeight+1)+'px';
			containerDiv.style.zIndex = "14";

			while (scrollDisplayDiv.firstChild) {
			    scrollDisplayDiv.removeChild(scrollDisplayDiv.firstChild);
			}

			var addDiv = document.createElement('div');
			addDiv.className = "propertysource-display-view";
			if(32*this.step <= maxWidth) {
				addDiv.style.width = (32*this.step)+"px";
				addDiv.style.height = "32px";
			} else {
				addDiv.style.width = (maxWidth)+"px";
				addDiv.style.height = (maxWidth/this.step)+"px";
			}
			addDiv.style.margin = "1px";
			if(this.iso) {
				addDiv.style.background = 'var(--colorBG)';
				var w;
				var h;
				if(32*this.step <= maxWidth) {
					w = 32*this.step;
					h = 32;
				} else {
					w = maxWidth;
					h = maxWidth/this.step;
				}
				var isoBgDiv = document.createElement('div');
				isoBgDiv.style.background = 'var(--color1)';
				isoBgDiv.style.position = 'absolute';
				isoBgDiv.style.left = '50%';
				isoBgDiv.style.top = '50%';
				isoBgDiv.style.width = maxWidth+"px";
				isoBgDiv.style.height = maxWidth+"px";
				var size = Math.sqrt(2)*maxWidth;
				isoBgDiv.style.transform = "translate(-50%, -50%) scale("+(w/size)+", "+(h/size)+") rotate(45deg)";
				addDiv.appendChild(isoBgDiv);
			}
			var imageAddDiv = document.createElement('img');
			imageAddDiv.className = "propertysource-image-view";
			imageAddDiv.style.margin = "0px";
			imageAddDiv.style.marginRight = "auto";
			imageAddDiv.style.marginLeft = "auto";
			imageAddDiv.style.width = "20px";
			imageAddDiv.style.height = "20px";
			if(32*this.step <= maxWidth) {
				imageAddDiv.src = "./../res/icon/ui_icon_b24.png";
			} else {
				imageAddDiv.src = "./../res/icon/ui_icon_b30.png";
			}
			addDiv.appendChild(imageAddDiv);
			//var textAddDiv = document.createElement('div');      
			//textAddDiv.innerHTML = "New Source";
			//addDiv.appendChild(textAddDiv);

			scrollDisplayDiv.appendChild(addDiv);

			addDiv.addEventListener("mousedown", function(event) {
				event.preventDefault();
				//addDiv.style.background = 'var(--color1)';

				this.srcSelected = -1;
			}.bind(this), false);

			var sources = tileroninX.getGlobalSources();
			for(var i = 0; i < sources.length; i++) {
				if(sources[i].refCount == 0) {
					continue;
				}
				(function(i) {
					var subDisplayDiv = document.createElement('div');
					subDisplayDiv.className = "propertysource-display-view";
					if(32*this.step <= maxWidth) {
						subDisplayDiv.style.width = (32*this.step)+"px";
						subDisplayDiv.style.height = "32px";
					} else {
						subDisplayDiv.style.width = (maxWidth)+"px";
						subDisplayDiv.style.height = (maxWidth/this.step)+"px";
					}
					subDisplayDiv.style.margin = "1px";
					if(this.iso) {
						subDisplayDiv.style.background = 'var(--colorBG)';
						var w;
						var h;
						if(32*this.step <= maxWidth) {
							w = 32*this.step;
							h = 32;
						} else {
							w = maxWidth;
							h = maxWidth/this.step;
						}
						var isoBgDiv = document.createElement('div');
						isoBgDiv.style.background = 'var(--color1)';
						isoBgDiv.style.position = 'absolute';
						isoBgDiv.style.left = '50%';
						isoBgDiv.style.top = '50%';
						isoBgDiv.style.width = maxWidth+"px";
						isoBgDiv.style.height = maxWidth+"px";
						var size = Math.sqrt(2)*maxWidth;
						isoBgDiv.style.transform = "translate(-50%, -50%) scale("+(w/size)+", "+(h/size)+") rotate(45deg)";
						subDisplayDiv.appendChild(isoBgDiv);
					}
					var imageDiv = document.createElement('div');
					imageDiv.className = "propertysource-image-view";
					sources[i].getImage().then(function(image) {
			        	var downscale = document.createElement("canvas");
						downscale.height = 96;
						downscale.width = 96*this.step;
						var ctx = downscale.getContext("2d");
						ctx.imageSmoothingEnabled = false;
						ctx.webkitImageSmoothingEnabled = false;
						ctx.mozImageSmoothingEnabled = false;

						ctx.drawImage(image, 0, 0, 96*this.step, 96);

						imageDiv.style.backgroundImage = 'url(\"'+downscale.toDataURL()+'\")';
			        }.bind(this));
			        if(32*this.step <= maxWidth) {
						imageDiv.style.width = (32*this.step)+"px";
						imageDiv.style.height = "32px";
						imageDiv.style.backgroundSize = (32*this.step)+"px 32px";
					} else {
						imageDiv.style.width = (maxWidth)+"px";
						imageDiv.style.height = (maxWidth/this.step)+"px";
						imageDiv.style.backgroundSize = (maxWidth)+"px "+(maxWidth/this.step)+"px";
					}
					imageDiv.style.margin = "0px";
					subDisplayDiv.appendChild(imageDiv);

					var slotDisplaySelect = document.createElement('div');
					slotDisplaySelect.className = "propertyrelationblob-tile-image-rule-large-select-view";
					slotDisplaySelect.style.left = '-2px';
					slotDisplaySelect.style.top = '-2px';
					if(32*this.step <= maxWidth) {
						slotDisplaySelect.style.width = (32*this.step+4)+"px";
					} else {
						slotDisplaySelect.style.width = (maxWidth+4)+"px";
						slotDisplaySelect.style.height = (maxWidth/this.step+4)+"px";
					}
					subDisplayDiv.appendChild(slotDisplaySelect);

					scrollDisplayDiv.appendChild(subDisplayDiv);

					subDisplayDiv.addEventListener("mousedown", function(event) {
						event.preventDefault();
						slotDisplaySelect.style.visibility = "visible";
						//subDisplayDiv.style.background = 'var(--color1)';

						this.srcSelected = sources[i];
					}.bind(this), false);
				}).bind(this)(i);
			}

			this.menuOpen = true;
		}

		function closeMenu() {
			containerDiv.style.height = displayDiv.style.height;

			this.menuOpen = false;
		}

		containerDiv.addEventListener("transitionend", function(event) {
			if(containerDiv.style.height.replace(/px/g, "") == 0) {
				containerDiv.style.zIndex = "auto";
			}
		}.bind(this), false);

		this.menuOpen = false;

		var mouseUp = function() {
			if(this.selectedTile) {
				return;
			}
			if(this.srcSelected != null) {
				containerDiv.style.borderColor = 'var(--color1)';

				if(!this.menuOpen) {
					if(!this.locked) {
						openMenu.bind(this)();
					}
				} else {
					if(this.srcSelected == -1) {
						//create new source
						var canvas;
						var tileShape = tileroninX.getTileShape();
						if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
							var tileSize = tileroninX.getTileSize();
							var canvas = document.createElement('canvas');
						    canvas.width  = tileSize;
						    canvas.height = tileSize;
						    var ctx = canvas.getContext('2d');
						    //drawing
						    var p = new Promise(function(resolve, reject) {
							    var image = new Image();
						        image.addEventListener('load', function() {
						        	for(var ix = 0; ix < tileSize; ix+=image.width) {
						        		for(var iy = 0; iy < tileSize; iy+=image.height) {
						        			ctx.drawImage(image, ix, iy);
						        		}
						        	}
						            resolve();
						        });
						        image.src = nativeImage.createFromPath(path.join(__dirname, '/../../res/placeholder/placeholder_default.png')).toDataURL();
						    }.bind(this));
						} else if(tileShape == tileroninX.Shape.ISOMETRIC) {
							var tileSize = tileroninX.getTileSize();
							var canvas = document.createElement('canvas');
						    canvas.width  = tileSize[0];
						    canvas.height = tileSize[1];
						    var ctx = canvas.getContext('2d');
						    //drawing
						    var p = new Promise(function(resolve, reject) {
							    var image = new Image();
						        image.addEventListener('load', function() {
						        	for(var ix = 0; ix < tileSize[0]; ix+=image.width) {
						        		for(var iy = 0; iy < tileSize[1]; iy+=image.height) {
						        			ctx.drawImage(image, ix, iy);
						        		}
						        	}
						            resolve();
						        });
						        image.src = nativeImage.createFromPath(path.join(__dirname, '/../../res/placeholder/placeholder_default.png')).toDataURL();
						    }.bind(this));
						}
					    //finish
					    p = p.then(function() {
					    	return new Promise(function(resolve, reject) {
						        var url = canvas.toDataURL('image/png');
						        resolve(nativeImage.createFromDataURL(url));
						    }.bind(this));
					    }.bind(this));

					    var placeholderSrc = new SourceImage(p);
				        this.setSource.bind(this)(placeholderSrc);
						this.sourceChangedCallback.notify(this.currentSrc);
						closeMenu.bind(this)();
					} else {
						this.setSource.bind(this)(this.srcSelected);
						this.sourceChangedCallback.notify(this.currentSrc);
						closeMenu.bind(this)();
					}
				}
				this.srcSelected = null;
			} else if(this.iconDown == 1) {
				this.iconDiv.src = "./../res/icon/ui_icon_c1.png";
				this.iconDown = 0;
				this.sourceOpenedCallback.notify(this.currentSrc);
			} else if(this.iconDown == 2) {
				this.iconDown = 0;
				this.icon2Div.src = "./../res/icon/ui_icon_b29.png";
				this.displayHighlightDiv.style.visibility = "visible";
				this.selectedTile = true;
				this.sourcePickingCallback.notify(function(tile) {
					if(tile != null && this.enabled) {
						if(tile instanceof TileBase) {
							var src = tile.getSource();
							this.setSource.bind(this)(src);
							this.sourceChangedCallback.notify(src);
						} else {
							this.errorDisplay.open(0, 0, [{msg:"Please select a\nnon-generated tile."}]);
						}
					}
					this.icon2Div.src = "./../res/icon/ui_icon_c29.png";
					this.displayHighlightDiv.style.visibility = "hidden";
					this.selectedTile = false;
				}.bind(this));
			}
		};

		plh.applyPointerLock(displayDiv, function() {
			if(this.selectedTile) {
				return;
			}
			plh.lockPointer();
			if(!this.locked) {
				this.errorDisplay.close();
			}
		}.bind(this), null, mouseUp.bind(this));

		plh.applyPointerLock(this.iconDiv, function() {
			if(this.selectedTile) {
				return;
			}
			plh.lockPointer();
			if(!this.locked) {
				this.errorDisplay.close();
			}
		}.bind(this), null, mouseUp.bind(this));

		if(!this.locked) {
			plh.applyPointerLock(this.icon2Div, function() {
				if(this.selectedTile) {
					return;
				}
				plh.lockPointer();
				this.errorDisplay.close();
			}.bind(this), null, mouseUp.bind(this));
		}

		plh.applyPointerLock(scrollDisplayDiv, function() {
			if(this.selectedTile) {
				return;
			}
			plh.lockPointer();
			if(!this.locked) {
				this.errorDisplay.close();
			}
		}.bind(this), null, mouseUp.bind(this));

		displayDiv.addEventListener("mousedown", function(event) {
			if(this.selectedTile) {
				return;
			}
			event.preventDefault();
			if(this.enabled) {
				containerDiv.style.borderColor = 'var(--color2)';

				this.srcSelected = this.currentSrc;
			}
		}.bind(this), false);

		containerDiv.addEventListener("mouseleave", function(event) {
			this.srcSelected = null;
			closeMenu.bind(this)();
		}.bind(this), false);

		this.enabled = true;
	}

	getDiv() {
		return this.div;
	}

	sourceOpenedSubscribe(func) {
		this.sourceOpenedCallback.subscribe(func);
	}

	sourceChangedSubscribe(func) {
		this.sourceChangedCallback.subscribe(func);
	}

	sourcePickingSubscribe(func) {
		this.sourcePickingCallback.subscribe(func);
	}

	tooltipSubscribe(func) {
		this.tooltipCallback.subscribe(func);
	}

	setEnabled(enabled) {
		this.enabled = enabled;
		if(!enabled) {
			this.errorDisplay.close();
			this.textDiv.style.color = 'var(--color1)';
			if(this.dropdownDiv != null) {
				this.dropdownDiv.style.visibility = 'hidden';
			}
			this.iconDiv.style.visibility = 'hidden';
			if(!this.locked) {
				this.icon2Div.style.visibility = 'hidden';
			}
			this.textDivDisplay.style.color = 'var(--color1)';
		} else {
			this.textDiv.style.color = '';
			if(this.dropdownDiv != null) {
				this.dropdownDiv.style.visibility = 'visible';
			}
			this.iconDiv.style.visibility = 'visible';
			if(!this.locked) {
				this.icon2Div.style.visibility = 'visible';
			}
			this.textDivDisplay.style.color = 'var(--color2)';
		}
	}

	setSource(newSrc) {
		if(this.callback != null) {
			this.currentSrc.sourceChangedUnsubscribe(this.callback);
		}
		var cbfn = function(newSrc) {
			this.setSource.bind(this)(newSrc);
		}.bind(this);
		this.callback = cbfn;
		newSrc.sourceChangedSubscribe(cbfn);

		this.currentSrc = newSrc;
		newSrc.getImage().then(function(image) {
	    	var downscale = document.createElement("canvas");
			downscale.height = 96;
			downscale.width = 96;
			var ctx = downscale.getContext("2d");
			ctx.imageSmoothingEnabled = false;
			ctx.webkitImageSmoothingEnabled = false;
			ctx.mozImageSmoothingEnabled = false;

			ctx.drawImage(image, 0, 0, 96, 96);

			this.imageDiv.style.backgroundImage = 'url(\"'+downscale.toDataURL()+'\")';
	    }.bind(this));
	    if(newSrc instanceof SourceImage) {
			this.textDivDisplay.innerHTML = "Image";
	    } else {
	    	this.textDivDisplay.innerHTML = "";
	    }
	}
}
module.exports = PropertySourceView;