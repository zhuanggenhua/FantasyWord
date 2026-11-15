var tileroninX = require('./tileroninX.js');

var BorderSet = require('./BorderSet.js');
var SourceImage = require('./SourceImage.js');

var {nativeImage} = require('electron');
var path = require('path');

var initSource = function(src, i) {
	//set tile
	//init callback for newly added tile
	//remove callback of previous tile
	//if no other instances of new tile, add global callbkack for new tile
	//if no other instances of previos tile, remove global callback of previous tile
	var oldSource = null;
	var indexCb = -1;
	oldSource = this.borderSources[i]['src'];
	indexCb = i+2;

	if(this.callbacks[indexCb] != null) {
		oldSource.sourceChangedUnsubscribe(this.callbacks[indexCb]);
	}

	var sources = this.getSources();
	var firstAdded = true;
	for(var si = 0; si < sources.length; si++) {
		if(sources[si] == src) {
			firstAdded = false;
		}
	}
	if(firstAdded) {
		var glfn = function(newSrc) {
			this.contentUpdatedCallback.notify();
		}.bind(this);
		this.globalCallbacks.push([src, glfn]);
		src.sourceChangedSubscribe(glfn, 1);
	}

	if(this.refCount > 0) {
		if(this.borderSources[i]['src'] != null) {
			this.borderSources[i]['src'].unreference();
		}
		src.reference();
	}
	this.borderSources[i]['src'] = src;

	sources = this.getSources();
	var lastRemoved = true;
	for(var si = 0; si < sources.length; si++) {
		if(sources[si] == oldSource) {
			lastRemoved = false;
		}
	}
	if(lastRemoved) {
		var fn = null;
		var index = -1;
		for(var gc = 0; gc < this.globalCallbacks.length; gc++) {
			if(this.globalCallbacks[gc][0] == oldSource) {
				fn = this.globalCallbacks[gc][1];
				index = gc;
			}
		}
		if(fn != null) {
			this.globalCallbacks.splice(index, 1);
			oldSource.sourceChangedUnsubscribe(fn);
		}
	}

	var cbfn = function(newSrc) {
		initSource.bind(this)(newSrc, i);
	}.bind(this);
	this.callbacks[indexCb] = cbfn;
	src.sourceChangedSubscribe(cbfn);

	if(i >= 0 && i < 4) {
		this.layersCache[i] = null;
		if(this.borderSources[4+(i+0)%4]['c']) {
			this.layersCache[4+(i+0)%4] = null;
		}
		if(this.borderSources[4+(i+1)%4]['c']) {
			this.layersCache[4+(i+1)%4] = null;
		}
		if(this.borderSources[8+(i+0)%4]['c']) {
			this.layersCache[8+(i+0)%4] = null;
		}
		if(this.borderSources[8+(i+1)%4]['c']) {
			this.layersCache[8+(i+1)%4] = null;
		}
	} else {
		if(!this.borderSources[i]['c']) {
			this.layersCache[i] = null;
		}
	}
}

class BorderSetWang extends BorderSet {
	constructor(config=null) {
		super();

		this.callbacks = [];
		this.globalCallbacks = [];

		this.layersCache = [null, null, null, null, null, null, null, null, null, null, null, null];

		this.borderSources = 
		[
			{src:null, r:0, fx:false, fy:false, cutoff:0}, //up
			{src:null, r:1, fx:false, fy:false, cutoff:0}, //right
			{src:null, r:2, fx:false, fy:false, cutoff:0}, //down
			{src:null, r:3, fx:false, fy:false, cutoff:0}, //left

			{src:null, r:0, fx:false, fy:false, c:true}, //up-left
			{src:null, r:0, fx:false, fy:false, c:true}, //up-right
			{src:null, r:0, fx:false, fy:false, c:true}, //down-right
			{src:null, r:0, fx:false, fy:false, c:true}, //down-left

			{src:null, r:0, fx:false, fy:false, c:true}, //up-left
			{src:null, r:0, fx:false, fy:false, c:true}, //up-right
			{src:null, r:0, fx:false, fy:false, c:true}, //down-right
			{src:null, r:0, fx:false, fy:false, c:true}  //down-left
		];

		if(config==null) { //auto-config
			//canvas
			var canvas;
			var tileShape = tileroninX.getTileShape();
			if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
				var tileSize = tileroninX.getTileSize();
				canvas = document.createElement('canvas');
			    canvas.width  = tileSize;
			    canvas.height = tileSize;
			    var ctx = canvas.getContext('2d');
			    //drawing
			    var p = new Promise(function(resolve, reject) {
				    var image = new Image();
			        image.addEventListener('load', function() {
			        	for(var ix = 0; ix < tileSize; ix+=image.width) {
			        		ctx.drawImage(image, ix, tileSize/2-8);
			        	}
			            resolve();
			        });
			        image.src = nativeImage.createFromPath(path.join(__dirname, '/../../res/placeholder/border_placeholder_wang.png')).toDataURL();
			    }.bind(this));
			} else if(tileShape == tileroninX.Shape.ISOMETRIC) {
				var tileSize = tileroninX.getTileSize();
				var step = tileSize[0]/tileSize[1];
				canvas = document.createElement('canvas');
			    canvas.width  = tileSize[0];
			    canvas.height = tileSize[1];
			    var ctx = canvas.getContext('2d');
			    //drawing
			    var p = new Promise(function(resolve, reject) {
				    var image = new Image();
			        image.addEventListener('load', function() {
			        	ctx.drawImage(image, tileSize[0]/2-1, tileSize[1]/2-1);
			        	for(var ix = 1; ix <= Math.ceil(tileSize[1]/4); ix++) {
			        		ctx.drawImage(image, tileSize[0]/2-1-ix*step, tileSize[1]/2-1-ix);
			        		ctx.drawImage(image, tileSize[0]/2-1+ix*step, tileSize[1]/2-1+ix);
			        	}
			            resolve();
			        });
			        image.src = nativeImage.createFromPath(path.join(__dirname, '/../../res/placeholder/border_placeholder_isometric.png')).toDataURL();
			    }.bind(this));

			    //use flips instead of rotation for default borders when isometric
			    this.borderSources[1].fy = true;
			    this.borderSources[2].fx = true; this.borderSources[2].fy = true;
			    this.borderSources[3].fx = true;
			}
		    //finish
		    p = p.then(function() {
		    	return new Promise(function(resolve, reject) {
			        var url = canvas.toDataURL('image/png');
			        resolve(nativeImage.createFromDataURL(url));
			    }.bind(this));
		    }.bind(this));

		    var placeholderSrc = new SourceImage(p);
	        for(var i = 0; i < this.borderSources.length; i++) {
				initSource.bind(this)(placeholderSrc, i);
			}
		} else {
			for(var i = 0; i < config.length; i++) {
				initSource.bind(this)(config[i].src, i);
				this.borderSources[i].r = config[i].r;
				this.borderSources[i].fx = config[i].fx;
				this.borderSources[i].fy = config[i].fy;
				if(this.borderSources[i].cutoff != null && config[i].cutoff != null) {
					this.borderSources[i].cutoff = config[i].cutoff;
				}
				if(this.borderSources[i].c != null) {
					this.borderSources[i].c = config[i].c;
				}
			}
		}
	}

	reference() {
		super.reference();
		if(this.refCount == 1) {
			for(var i = 0; i < this.borderSources.length; i++) {
				this.borderSources[i]['src'].reference();
			}
		}
	}

	unreference() {
		super.unreference();
		if(this.refCount == 0) {
			for(var i = 0; i < this.borderSources.length; i++) {
				this.borderSources[i]['src'].unreference();
			}
		}
	}

	getSources() {
		var src = [];
		for(var i = 0; i < this.borderSources.length; i++) {
			src.push(this.borderSources[i]['src']);
		}
		return src;
	}

	getSource(i) {
		return this.borderSources[i]['src'];
	}
	getRotation(i) {
		return this.borderSources[i]['r'];
	}
	getFlipX(i) {
		return this.borderSources[i]['fx'];
	}
	getFlipY(i) {
		return this.borderSources[i]['fy'];
	}
	getComposite(i) {
		return this.borderSources[i]['c'];
	}
	getCutoff(i) {
		return this.borderSources[i]['cutoff'];
	}

	setSource(i, src, undoGroup=[]) {
		var undoParams = {action:'bset_source_change', bset:this, bset_id:i, prev_value:this.getSources()[i]};
    	undoGroup.push(undoParams);

		initSource.bind(this)(src, i);
		this.contentUpdatedCallback.notify();
	}
	setRotation(i, r, undoGroup=[]) {
		var undoParams = {action:'bset_rotation_change', bset:this, bset_id:i, prev_value:this.getRotation(i)};
    	undoGroup.push(undoParams);

		this.borderSources[i]['r'] = r;
		if(i >= 0 && i < 4) {
			this.layersCache[i] = null;
			if(this.borderSources[4+(i+0)%4]['c']) {
				this.layersCache[4+(i+0)%4] = null;
			}
			if(this.borderSources[4+(i+1)%4]['c']) {
				this.layersCache[4+(i+1)%4] = null;
			}
			if(this.borderSources[8+(i+0)%4]['c']) {
				this.layersCache[8+(i+0)%4] = null;
			}
			if(this.borderSources[8+(i+1)%4]['c']) {
				this.layersCache[8+(i+1)%4] = null;
			}
		} else {
			if(!this.borderSources[i]['c']) {
				this.layersCache[i] = null;
			}
		}
		this.contentUpdatedCallback.notify();
	}
	setFlipX(i, fx, undoGroup=[]) {
		var undoParams = {action:'bset_flipx_change', bset:this, bset_id:i, prev_value:this.getFlipX(i)};
    	undoGroup.push(undoParams);

		this.borderSources[i]['fx'] = fx;
		if(i >= 0 && i < 4) {
			this.layersCache[i] = null;
			if(this.borderSources[4+(i+0)%4]['c']) {
				this.layersCache[4+(i+0)%4] = null;
			}
			if(this.borderSources[4+(i+1)%4]['c']) {
				this.layersCache[4+(i+1)%4] = null;
			}
			if(this.borderSources[8+(i+0)%4]['c']) {
				this.layersCache[8+(i+0)%4] = null;
			}
			if(this.borderSources[8+(i+1)%4]['c']) {
				this.layersCache[8+(i+1)%4] = null;
			}
		} else {
			if(!this.borderSources[i]['c']) {
				this.layersCache[i] = null;
			}
		}
		this.contentUpdatedCallback.notify();
	}
	setFlipY(i, fy, undoGroup=[]) {
		var undoParams = {action:'bset_flipy_change', bset:this, bset_id:i, prev_value:this.getFlipY(i)};
    	undoGroup.push(undoParams);

		this.borderSources[i]['fy'] = fy;
		if(i >= 0 && i < 4) {
			this.layersCache[i] = null;
			if(this.borderSources[4+(i+0)%4]['c']) {
				this.layersCache[4+(i+0)%4] = null;
			}
			if(this.borderSources[4+(i+1)%4]['c']) {
				this.layersCache[4+(i+1)%4] = null;
			}
			if(this.borderSources[8+(i+0)%4]['c']) {
				this.layersCache[8+(i+0)%4] = null;
			}
			if(this.borderSources[8+(i+1)%4]['c']) {
				this.layersCache[8+(i+1)%4] = null;
			}
		} else {
			if(!this.borderSources[i]['c']) {
				this.layersCache[i] = null;
			}
		}
		this.contentUpdatedCallback.notify();
	}
	setComposite(i, c, undoGroup=[]) {
		var undoParams = {action:'bset_composite_change', bset:this, bset_id:i, prev_value:this.getComposite(i)};
    	undoGroup.push(undoParams);

		this.borderSources[i]['c'] = c;
		this.layersCache[i] = null;
		this.contentUpdatedCallback.notify();
	}
	setCutoff(i, c, undoGroup=[]) {
		var undoParams = {action:'bset_cutoff_change', bset:this, bset_id:i, prev_value:this.getCutoff(i)};
    	undoGroup.push(undoParams);

		this.borderSources[i]['cutoff'] = c;
		this.layersCache[i] = null;
		if(this.borderSources[4+(i+0)%4]['c']) {
			this.layersCache[4+(i+0)%4] = null;
		}
		if(this.borderSources[4+(i+1)%4]['c']) {
			this.layersCache[4+(i+1)%4] = null;
		}
		if(this.borderSources[8+(i+0)%4]['c']) {
			this.layersCache[8+(i+0)%4] = null;
		}
		if(this.borderSources[8+(i+1)%4]['c']) {
			this.layersCache[8+(i+1)%4] = null;
		}
		this.contentUpdatedCallback.notify();
	}
}
module.exports = BorderSetWang;