var tileroninX = require('./tileroninX.js');

var plh = require('./PointerLockHandler.js');

const { remote } = require('electron');

class WindowBorderView {
	constructor(content) {
		this.div = document.createElement('div');
		this.div.className = "windowborder-view";

		var titleBar = document.createElement('div');
		titleBar.className = "windowborder-titlebar-view";
		this.div.appendChild(titleBar);

		//title decor
		var titleContent = document.createElement('div');
		titleContent.className = "windowborder-titlecontent-view";

		var titleImage0 = document.createElement('img');
		titleImage0.className = "windowborder-titleimage-view";
		titleImage0.src = "../res/logo.svg"
		titleContent.appendChild(titleImage0);

		var titleImage1 = document.createElement('img');
		titleImage1.className = "windowborder-titleimage-view";
		titleImage1.src = "../res/title.svg"
		titleImage1.style.paddingRight = "4px";
		titleContent.appendChild(titleImage1);

		titleContent.innerHTML += tileroninX.getVersionString();

		titleBar.appendChild(titleContent);

		//options init
		var optionsContent = document.createElement('div');
		optionsContent.className = "windowborder-optionscontent-view";

		this.optionDown = -1;

		var option0 = document.createElement('div');
		option0.className = "windowborder-option-view";
		option0.style.backgroundImage = "url('../res/icon/ui_icon_option_a1.png')";
		option0.addEventListener("mousedown", function(event) {
			event.preventDefault();
			this.optionDown = 0;
			option0.style.backgroundColor = "var(--color2)";
			option0.style.backgroundImage = "url('../res/icon/ui_icon_option_b1.png')";
		}.bind(this), false);

		var option1 = document.createElement('div');
		option1.className = "windowborder-option-view";
		option1.style.backgroundImage = "url('../res/icon/ui_icon_option_a2.png')";
		option1.addEventListener("mousedown", function(event) {
			event.preventDefault();
			this.optionDown = 1;
			option1.style.backgroundColor = "var(--color2)";
			option1.style.backgroundImage = "url('../res/icon/ui_icon_option_b2.png')";
		}.bind(this), false);

		var option2 = document.createElement('div');
		option2.className = "windowborder-option-view";
		option2.style.backgroundImage = "url('../res/icon/ui_icon_option_a3.png')";
		option2.addEventListener("mousedown", function(event) {
			event.preventDefault();
			this.optionDown = 2;
			option2.style.backgroundColor = "var(--color2)";
			option2.style.backgroundImage = "url('../res/icon/ui_icon_option_b3.png')";
		}.bind(this), false);

		var optionZOut = document.createElement('div');
		optionZOut.className = "windowborder-option-zoom-view";
		optionZOut.style.backgroundImage = "url('../res/icon/ui_icon_option_a5.png')";
		optionZOut.addEventListener("mousedown", function(event) {
			event.preventDefault();
			this.optionDown = 3;
			optionZOut.style.borderColor = "var(--color2)";
			optionZOut.style.backgroundImage = "url('../res/icon/ui_icon_option_b5.png')";
		}.bind(this), false);

		var optionZIn = document.createElement('div');
		optionZIn.className = "windowborder-option-zoom-view";
		optionZIn.style.backgroundImage = "url('../res/icon/ui_icon_option_a4.png')";
		optionZIn.addEventListener("mousedown", function(event) {
			event.preventDefault();
			this.optionDown = 4;
			optionZIn.style.borderColor = "var(--color2)";
			optionZIn.style.backgroundImage = "url('../res/icon/ui_icon_option_b4.png')";
		}.bind(this), false);

		optionsContent.appendChild(option2);
		optionsContent.appendChild(option1);
		optionsContent.appendChild(option0);
		optionsContent.appendChild(optionZIn);
		optionsContent.appendChild(optionZOut);
		titleBar.appendChild(optionsContent);

		plh.applyPointerLock(optionsContent, function() {
			plh.lockPointer();
			event.stopPropagation();
		}, null, function() {
			if(this.optionDown != -1) {
				option0.style.backgroundColor = "var(--color1)";
				option0.style.backgroundImage = "url('../res/icon/ui_icon_option_a1.png')";
				option1.style.backgroundColor = "var(--color1)";
				option1.style.backgroundImage = "url('../res/icon/ui_icon_option_a2.png')";
				option2.style.backgroundColor = "var(--color1)";
				option2.style.backgroundImage = "url('../res/icon/ui_icon_option_a3.png')";
				optionZOut.style.borderColor = "var(--color1)";
				optionZOut.style.backgroundImage = "url('../res/icon/ui_icon_option_a5.png')";
				optionZIn.style.borderColor = "var(--color1)";
				optionZIn.style.backgroundImage = "url('../res/icon/ui_icon_option_a4.png')";

				if(this.optionDown == 0) {
					var currentWindow = remote.BrowserWindow.getFocusedWindow();
					currentWindow.minimize();
				} else if(this.optionDown == 1) {
					if(!remote.BrowserWindow.getFocusedWindow().isMaximized()) {
						remote.BrowserWindow.getFocusedWindow().maximize();
					} else {
						remote.BrowserWindow.getFocusedWindow().unmaximize();
					}
				} else if(this.optionDown == 2) {
					remote.BrowserWindow.getFocusedWindow().close();
				} else if(this.optionDown == 3) {
					var currentZoom = parseInt(document.body.style.zoom);
					if(currentZoom > 1) {
						document.body.style.zoom = currentZoom-1;
						content.updateContents();
					}
				} else if(this.optionDown == 4) {
					var currentZoom = parseInt(document.body.style.zoom);
					if(currentZoom < 3) {
						document.body.style.zoom = currentZoom+1;
						content.updateContents();
					}
				}

				this.optionDown = -1;
			}
		}.bind(this));

		//window restrictions
		window.addEventListener('resize', function() {
			content.updateContents();
		}, false);
		require('electron').remote.getCurrentWindow().setMinimumSize(content.getMinWidth()+16, content.getMinHeight()+8+48);

		//content
		var contentContainer = document.createElement('div');
		contentContainer.className = "windowborder-contentcontainer-view";
		this.div.appendChild(contentContainer);

		var padding = "8px";
		content.getDiv().style.marginLeft = padding;
		content.getDiv().style.marginRight = padding;
		content.getDiv().style.marginBottom = padding;
		contentContainer.appendChild(content.getDiv());
	}

	getDiv() {
		return this.div;
	}
}
module.exports = WindowBorderView;