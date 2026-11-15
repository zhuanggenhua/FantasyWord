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
	indexCb = i+1;

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
			//this.contentUpdatedCallback.notify();
			notifyWhenReady.bind(this)();
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

	detectWidths.bind(this)(i);

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

var detectWidths = function(i) {
	this.isReady = false;
	//auto detect width
	if(i >= 0 && i < 4) {
	    (function(i) {
	    	this.borderSources[i]['widthPromise'] = new Promise(function(resolve, reject) {
	    		var tileShape = tileroninX.getTileShape();
	    		if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
	    			var tileSize = tileroninX.getTileSize();
					var canvas = document.createElement('canvas');
				    canvas.width  = tileSize;
				    canvas.height = tileSize;
				    var ctx = canvas.getContext('2d');

				    var image = new Image();
			        image.addEventListener('load', function() {
			            var deg = this.borderSources[i]['r']*90;
			            var fx = this.borderSources[i]['fx'];
			            var fy = this.borderSources[i]['fy'];
			            var rad = deg*Math.PI/180.0;
				    	ctx.translate(tileSize/2, tileSize/2);
				    	if(fx) {
							ctx.scale(-1, 1);
						}
						if(fy) {
							ctx.scale(1, -1);
						}
						ctx.rotate(rad);
			            ctx.drawImage(image, -tileSize/2, -tileSize/2);
						ctx.rotate(rad);
			            ctx.translate(-tileSize/2, -tileSize/2);
			           	
			           	var width = null;
			           	var cache = ctx.getImageData(0, 0, tileSize, tileSize).data;
			           	for(var k = 0; k < tileSize && width==null; k++) {
			           		for(var j = 0; j < tileSize && width==null; j++) {
			           			var x = k;
			           			var y = j;
			           			if(i%2 == 0) {
			           				var tmp = x;
			           				x = y;
			           				y = tmp;
			           			}
			           			if(((i+1)%4)<2) {
			           				x = tileSize-x-1;
			           				y = tileSize-y-1;
			           			}
			           			var idx = (y*tileSize+x)*4;
			           			var alpha = cache[idx+3];
			           			if(alpha != 0) {
			           				width = tileSize-k;
			           			}
			           		}
			           	}
			           	resolve(width);
			        }.bind(this));
			        this.borderSources[i]['src'].getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
	    		} else if(tileShape == tileroninX.Shape.ISOMETRIC) {
	    			var tileSize = tileroninX.getTileSize();
					var canvas = document.createElement('canvas');
				    canvas.width  = tileSize[0];
				    canvas.height = tileSize[1];
				    var ctx = canvas.getContext('2d');

				    var step = tileSize[0]/tileSize[1];

				    var image = new Image();
			        image.addEventListener('load', function() {
			            var deg = this.borderSources[i]['r'];
			            var fx = this.borderSources[i]['fx'];
			            var fy = this.borderSources[i]['fy'];
				    	ctx.translate(tileSize[0]/2, tileSize[1]/2);
				    	if(fx) {
							ctx.scale(-1, 1);
						}
						if(fy) {
							ctx.scale(1, -1);
						}
				        ctx.drawImage(image, -tileSize[0]/2, -tileSize[1]/2);
						
			           	var width = null;
			           	var cache = ctx.getImageData(0, 0, tileSize[0], tileSize[1]).data;
			           	for(var k = 0; k < tileSize[0]+step && width==null; k++) {
			           		for(var j = 0; j < tileSize[1] && width==null; j++) {
			           			var x = tileSize[0]/2-(j+1)*step+k;
			           			var y = j;
			           			if(i == 2 || i == 3) {
			           				x = tileSize[0]-1-x;
			           			}
			           			if(i == 0 || i == 3) {
			           				y = tileSize[1]-1-y;
			           			}
			           			if(x < 0 || x >= tileSize[0] || y < 0 || y >= tileSize[1]) {
			           				continue;
			           			}
			           			var idx = (y*tileSize[0]+x)*4;
			           			var alpha = cache[idx+3];
			           			if(alpha != 0) {
			           				width = tileSize[0]+step-k;
			           			}
			           		}
			           	}
			           	resolve(width);
			        }.bind(this));
			        this.borderSources[i]['src'].getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
	    		}
	        }.bind(this));
	    }).bind(this)(i);
	}
}

var notifyWhenReady = function() {
	var promises = [];
	for(var i = 0; i < 4; i++) {
		promises.push(this.borderSources[i]['widthPromise']);
	}
	Promise.all(promises).then(function(values) {
		this.isReady = true;
		for(var i in values) {
			this.borderSources[i]['width'] = values[i];
		}
        this.contentUpdatedCallback.notify();
	}.bind(this));
}

class BorderSetBlob extends BorderSet {
	constructor(config=null) {
		super();

		this.callbacks = [];
		this.globalCallbacks = [];

		this.isReady = false;

		this.layersCache = [null, null, null, null, null, null, null, null, null, null, null, null];

		this.borderSources = 
		[
			{src:null, r:0, fx:false, fy:false, cutoff:4, widthPromise:null, width:0}, //up
			{src:null, r:1, fx:false, fy:false, cutoff:4, widthPromise:null, width:0}, //right
			{src:null, r:2, fx:false, fy:false, cutoff:4, widthPromise:null, width:0}, //down
			{src:null, r:3, fx:false, fy:false, cutoff:4, widthPromise:null, width:0}, //left

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
			        		ctx.drawImage(image, ix, 0);
			        	}
			            resolve();
			        });
			        image.src = nativeImage.createFromPath(path.join(__dirname, '/../../res/placeholder/border_placeholder_blob.png')).toDataURL();
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
			        	for(var ix = -1; ix <= tileSize[1]/2; ix++) {
			        		ctx.drawImage(image, tileSize[0]/2+(ix+1)*step-2-3, ix);
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
				this.borderSources[i].r = config[i].r;
				this.borderSources[i].fx = config[i].fx;
				this.borderSources[i].fy = config[i].fy;
				initSource.bind(this)(config[i].src, i);
				if(this.borderSources[i].cutoff != null) {
					this.borderSources[i].cutoff = config[i].cutoff;
				}
				if(this.borderSources[i].c != null) {
					this.borderSources[i].c = config[i].c;
				}
			}
		}

		notifyWhenReady.bind(this)();
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
		//this.contentUpdatedCallback.notify();
		notifyWhenReady.bind(this)();
	}
	setRotation(i, r, undoGroup=[]) {
		var undoParams = {action:'bset_rotation_change', bset:this, bset_id:i, prev_value:this.getRotation(i)};
    	undoGroup.push(undoParams);

		this.borderSources[i]['r'] = r;
		detectWidths.bind(this)(i);
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
		//this.contentUpdatedCallback.notify();
		notifyWhenReady.bind(this)();
	}
	setFlipX(i, fx, undoGroup=[]) {
		var undoParams = {action:'bset_flipx_change', bset:this, bset_id:i, prev_value:this.getFlipX(i)};
    	undoGroup.push(undoParams);

		this.borderSources[i]['fx'] = fx;
		detectWidths.bind(this)(i);
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
		//this.contentUpdatedCallback.notify();
		notifyWhenReady.bind(this)();
	}
	setFlipY(i, fy, undoGroup=[]) {
		var undoParams = {action:'bset_flipy_change', bset:this, bset_id:i, prev_value:this.getFlipY(i)};
    	undoGroup.push(undoParams);

		this.borderSources[i]['fy'] = fy;
		detectWidths.bind(this)(i);
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
		//this.contentUpdatedCallback.notify();
		notifyWhenReady.bind(this)();
	}
	setComposite(i, c, undoGroup=[]) {
		var undoParams = {action:'bset_composite_change', bset:this, bset_id:i, prev_value:this.getComposite(i)};
    	undoGroup.push(undoParams);

		this.borderSources[i]['c'] = c;
		this.layersCache[i] = null;
		//this.contentUpdatedCallback.notify();
		notifyWhenReady.bind(this)();
	}
	setCutoff(i, c, undoGroup=[]) {
		var undoParams = {action:'bset_cutoff_change', bset:this, bset_id:i, prev_value:this.getCutoff(i)};
    	undoGroup.push(undoParams);

		this.borderSources[i]['cutoff'] = Math.max(0, c);
		//this.contentUpdatedCallback.notify();
		notifyWhenReady.bind(this)();
	}
}
module.exports = BorderSetBlob;