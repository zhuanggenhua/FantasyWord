var tileroninX = require('./tileroninX.js');
var SourceDisplayView = require('./SourceDisplayView.js');
var IconTrayView = require('./IconTrayView.js');

var {clipboard} = require('electron');
var nativeImage = require('electron').nativeImage;

var SourceImage = require('./SourceImage.js');
var CallbackManager = require('./CallbackManager.js');

var clipboardPaste = function() {
	var pasted = clipboard.readImage();

	var bufs = [clipboard.readBuffer('png'),
				clipboard.readBuffer('image/png')];
	for(var i in bufs) {
		var buf = bufs[i];
		if(buf.length > 0) {
			pasted = nativeImage.createFromBuffer(buf);
		}
	}

	var sources = tileroninX.imageToSources(pasted);
	if(sources.length > 0) {
		var source = sources[0].src;
		var undoGroup = [];
		this.loadedSource.setSource(source, undoGroup);
		tileroninX.saveUndoState(undoGroup);
	}
}

var clipboardCopy = function() {
	this.loadedSource.getImage().then(function(img) {
    	ipcRenderer.send('clipboardWrite', img.toDataURL());
    });
}

var setSource = function(src) {
	if(this.loadedSourceCallback != null) {
		this.loadedSourceCallback[0].sourceChangedUnsubscribe(this.loadedSourceCallback[1]);
		this.loadedSourceCallback = null;
	}

	this.srcDisplay.setSource(src);
    this.loadedSource = src;
    if(this.loadedSource != null) {
    	var cbFn = function(newSrc) {
    		setSource.bind(this)(newSrc);
    	}.bind(this);
        this.loadedSource.sourceChangedSubscribe(cbFn);
	    this.loadedSourceCallback = [this.loadedSource, cbFn];
    }
}

class SourcePropertiesView {
	constructor() {
		this.div = document.createElement('div');
		this.div.className = "sourceproperties-view";

		this.titleDiv = document.createElement('div');
		this.titleDiv.className = 'sourceproperties-title-view';
		this.titleDiv.innerHTML = "No source selected";
		this.div.appendChild(this.titleDiv);

		this.tooltipCallback = new CallbackManager();

		this.loadedSource = null;

		this.srcDisplay = new SourceDisplayView();
		var iconTray = new IconTrayView([	["./../res/icon/ui_icon_b18.png", "./../res/icon/ui_icon_a18.png"],
											["./../res/icon/ui_icon_b19.png", "./../res/icon/ui_icon_a19.png"]	],
											["Copy Source",
											"Paste Source"]);
		iconTray.iconClickedSubscribe(function(index) {
			if(this.loadedSource != null) {
				if(index == 0) {
					clipboardCopy.bind(this)();
				} else if(index == 1) {
					clipboardPaste.bind(this)();
				}
			}
		}.bind(this));
		iconTray.tooltipSubscribe(function(msg) {
			this.tooltipCallback.notify(msg);
		}.bind(this));
		this.srcDisplay.getDiv().appendChild(iconTray.getDiv());
		this.div.appendChild(this.srcDisplay.getDiv());
	}

	loadSource(src) {
		if(src != null) {
			setSource.bind(this)(src);

			if(src instanceof SourceImage) {
				this.titleDiv.innerHTML = "Image Source";
			}
		} else {
			setSource.bind(this)(null);

			this.titleDiv.innerHTML = "No source selected";
		}
	}

	getDiv() {
		return this.div;
	}

	tooltipSubscribe(func) {
		this.tooltipCallback.subscribe(func);
	}
}
module.exports = SourcePropertiesView;