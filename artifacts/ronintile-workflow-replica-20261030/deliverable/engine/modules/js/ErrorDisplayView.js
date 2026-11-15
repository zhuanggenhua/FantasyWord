class ErrorDisplayView {
	constructor(v=false) {
		this.verticalExpand = v;

		this.div = document.createElement('div');
		this.div.className = "errordisplay-container-view";

		this.displayDiv = document.createElement('div');
		this.displayDiv.className = "errordisplay-view";
		this.div.appendChild(this.displayDiv);

		this.displayDiv.addEventListener("transitionend", function(event) {
			var expandSize = this.displayDiv.style.width.replace(/px/g, "");
			if(this.verticalExpand) {
				expandSize = this.displayDiv.style.height.replace(/px/g, "");
			}
			if(expandSize == 0) {
				this.div.style.visibility = 'hidden';
			}
		}.bind(this), false);

		this.arrowDiv = document.createElement('div');
		this.arrowDiv.className = "errordisplay-arrow-view";
		this.arrowDiv.style.backgroundImage = "url('../res/icon/ui_icon_error_arrow.png')";
		this.div.appendChild(this.arrowDiv);

		if(this.verticalExpand) {
			this.div.style.transform = "translateX(-50%)";
			this.displayDiv.style.transition = "height 0.2s cubic-bezier(0.19, 1, 0.22, 1)";
			this.displayDiv.style.left = "0px";
			this.displayDiv.style.top = "9px";
			this.arrowDiv.style.left = "50%";
			this.arrowDiv.style.top = "0px";
			this.arrowDiv.style.transform = "translateX(-50%) rotate(90deg)";
		}
	}

	open(x, y, msgs) {
		if(msgs == null || msgs.length == 0) {
			return;
		}
		//populate messages
		this.displayDiv.innerHTML = "";
        for(var i in msgs) {
			var msg = msgs[i];

			var containerDiv = document.createElement('div');
			containerDiv.className = "errordisplay-content-view";
			this.displayDiv.appendChild(containerDiv);

			var contentDiv = document.createElement('div');
			contentDiv.className = "errordisplay-text-view";
			if(this.verticalExpand) {
				contentDiv.style.whiteSpace = "normal";
			}

			var iconDiv = document.createElement('img');
			iconDiv.className = "errordisplay-icon-view";
			iconDiv.src = "./../res/icon/ui_icon_d5.png";
			containerDiv.appendChild(iconDiv);

			var tileIndex = 0;
			var txtDiv = document.createElement('div');
			for(var k = 0; k < msg.msg.length; k++) {
                if(msg.msg[k] == '%' && msg.msg[k+1] == 'T') {
                	txtDiv.innerHTML = '(';
                	contentDiv.appendChild(txtDiv.firstChild);

                    var tileContainer = document.createElement('div');
			        tileContainer.className = "errordisplay-tile-container-view";
			        contentDiv.appendChild(tileContainer);

			        (function a() {
				        var tileDisplay = document.createElement('div');
				        tileDisplay.className = "errordisplay-tile-view";
				        msg.tiles[tileIndex].getImage().then(function(img) {
				        	var downscale = document.createElement("canvas");
							downscale.height = 48;
							downscale.width = 48;
							var ctx = downscale.getContext("2d");
							ctx.imageSmoothingEnabled = false;
							ctx.webkitImageSmoothingEnabled = false;
							ctx.mozImageSmoothingEnabled = false;

							ctx.drawImage(img, 0, 0, 48, 48);

							tileDisplay.style.backgroundImage = 'url(\"'+downscale.toDataURL()+'\")';
						}.bind(this));
				        tileContainer.appendChild(tileDisplay);
				    }.bind(this))();

                	txtDiv.innerHTML = ')';
                	contentDiv.appendChild(txtDiv.firstChild);
                	tileIndex++;
                	k++;
                } else if(msg.msg[k] == '\n') {
                	txtDiv.innerHTML = '<br>';
                	contentDiv.appendChild(txtDiv.firstChild);
                } else {
                	txtDiv.innerHTML = msg.msg[k];
                	contentDiv.appendChild(txtDiv.firstChild);
                }
			}

            containerDiv.appendChild(contentDiv);
        }

		this.div.style.visibility = 'visible';
		this.arrowDiv.style.visibility = 'inherit';
		if(this.verticalExpand) {
			this.displayDiv.style.height = 'auto';
		} else {
			this.displayDiv.style.width = 'auto';
		}
		requestAnimationFrame(function() {
			var elementTransition = this.displayDiv.style.transition;
	  		this.displayDiv.style.transition = '';
	  		if(this.verticalExpand) {
				var fullSize = this.displayDiv.scrollHeight+'px';
				this.displayDiv.style.height = '0px';
			} else {
				var fullSize = this.displayDiv.scrollWidth+'px';
				this.displayDiv.style.width = '0px';
			}
			requestAnimationFrame(function() {
				this.displayDiv.style.transition = elementTransition;
				if(this.verticalExpand) {
					this.displayDiv.style.height = fullSize;
				} else {
					this.displayDiv.style.width = fullSize;
				}
			}.bind(this));
		}.bind(this));

		this.div.style.left = x+'px';
		this.div.style.top = y+'px';
	}

	close() {
		this.arrowDiv.style.visibility = 'hidden';
		if(this.verticalExpand) {
			this.displayDiv.style.height = '0px';
		} else {
			this.displayDiv.style.width = '0px';
		}
	}

	getDiv() {
		return this.div;
	}
}
module.exports = ErrorDisplayView;