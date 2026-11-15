var BorderGenerator = require('./BorderGenerator.js');

var TileRelationBlob = require('./TileRelationBlob.js');
var TileRelationBlobBorder = require('./TileRelationBlobBorder.js');
var TileRelationBlobPre2_0_0 = require('./TileRelationBlobPre2_0_0.js');

var {nativeImage} = require('electron');
var path = require('path');

var getGenMatrix = function() {
	this.pre2_0_0 = false;
	var genMatrix = null;
	var tRel = this.tile.getRelations();
	for(var k in tRel) {
		if(tRel[k].r instanceof TileRelationBlobBorder && tRel[k].r.isBorder) {
			genMatrix = [tRel[k].t];
			genMatrix = genMatrix.concat(tRel[k].r.getIndexMatrix());
			break;
		}
		if(tRel[k].r instanceof TileRelationBlobPre2_0_0) {
			genMatrix = [tRel[k].r.getBaseTile()];
			genMatrix = genMatrix.concat(tRel[k].r.getIndexMatrix());
			this.pre2_0_0 = true;
			break;
		}
	}
	return genMatrix;
}

var refreshRelations = function() {
	//unregister callbacks
	for(var i in this.bsets) {
		this.bsets[i].contentUpdatedUnsubscribeIndex(this.bsetCallbacks[i]);
	}
	this.bsets = [];
	this.bsetCallbacks = [];
	for(var i in this.imageTiles) {
		this.imageTiles[i].contentUpdatedUnsubscribeIndex(this.imageTileCallbacks[i]);
	}
	this.imageTiles = [];
	this.imageTileCallbacks = [];

	var genMatrix = this.genMatrixCache;
	if(genMatrix == null) {
		return;
	}
	//register callbacks
	if(this.imageTiles.indexOf(genMatrix[0]) == -1) {
		var tileCallbackFunc = function() {
			this.contentUpdatedCallback.notify();
		}.bind(this)
		var cbi = genMatrix[0].contentUpdatedSubscribe(tileCallbackFunc);
		this.imageTiles.push(genMatrix[0]);
		this.imageTileCallbacks.push(cbi);
	}
	for(var i = 1; i < genMatrix.length; i++) {
		if(genMatrix[0] == genMatrix[i] || genMatrix[i] == null) {
			continue;
		}
		var bset = genMatrix[0].getRelation(genMatrix[i]).getBorderSet(); //TODO: check relation type?
		if(this.bsets.indexOf(bset) == -1) {
			var bsetCallbackFunc = function() {
				this.contentUpdatedCallback.notify();
			}.bind(this)
			var cbi = bset.contentUpdatedSubscribe(bsetCallbackFunc);
			this.bsets.push(bset);
			this.bsetCallbacks.push(cbi);
		}
	}
}

var getLayersOrthographic = function() { //TODO
	//HELPER FUNCTIONS & VARS
	//HELPER FUNCTIONS & VARS
	//HELPER FUNCTIONS & VARS
	//HELPER FUNCTIONS & VARS

	var ctxClip = function(ctx, clip) {
    	ctx.beginPath();
    	var origin = clip[0];
    	ctx.moveTo(origin[0], origin[1]);
    	for(var i = 1; i < clip.length; i++) {
    		var point = clip[i];
    		ctx.lineTo(point[0], point[1]);
    	}
    	ctx.clip();
    }

    var ctxMask = function(ctx, clip) {
    	ctx.beginPath();
    	var origin = clip[0];
    	ctx.moveTo(origin[0], origin[1]);
    	for(var i = 1; i < clip.length; i++) {
    		var point = clip[i];
    		ctx.lineTo(point[0], point[1]);
    	}
    	ctx.fill();
    }

    var ctxDrawRotateFlip = function(ctx, image, deg, fx, fy) {
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
		ctx.rotate(-rad);
		if(fx) {
			ctx.scale(-1, 1);
		}
		if(fy) {
			ctx.scale(1, -1);
		}
        ctx.translate(-tileSize/2, -tileSize/2);
    }

    var tileSize = tileroninX.getTileSize();

	//BASE CLIPPING FUNCS
    //BASE CLIPPING FUNCS
    //BASE CLIPPING FUNCS
    //BASE CLIPPING FUNCS

    function clipBorderBase(i, ctx, bset) {
    	var clipbase_up = [ // [.-] ////
	    	[0, bset.borderSources[0]['cutoff']],
	    	[tileSize, bset.borderSources[0]['cutoff']],
	    	[tileSize, tileSize],
	    	[0, tileSize]
	    ];
	    var clipbase_right = [ // [:|] ////
	    	[(tileSize-bset.borderSources[1]['cutoff']), 0],
	    	[(tileSize-bset.borderSources[1]['cutoff']), tileSize],
	    	[0, tileSize],
	    	[0, 0]
	    ];
	    var clipbase_down = [ // [-`] ////
	    	[0, (tileSize-bset.borderSources[2]['cutoff'])],
	    	[tileSize, (tileSize-bset.borderSources[2]['cutoff'])],
	    	[tileSize, 0],
	    	[0, 0]
	    ];
	    var clipbase_left = [ // [|:] ////
	    	[bset.borderSources[3]['cutoff'], 0],
	    	[bset.borderSources[3]['cutoff'], tileSize],
	    	[tileSize, tileSize],
	    	[tileSize, 0]
	    ];
	    var clipsbase = [clipbase_up, clipbase_right, clipbase_down, clipbase_left];

    	ctxClip(ctx, clipsbase[i]);
    }

    function clipBorderInnerBase(i, ctx, bset) {
    	var clipbase_upLeftInner = [ // [-'] ////
	    	[0, bset.borderSources[0]['cutoff']],
	    	[bset.borderSources[3]['cutoff'], bset.borderSources[0]['cutoff']],
	    	[bset.borderSources[3]['cutoff'], 0],
	    	[tileSize, 0],
	    	[tileSize, tileSize],
	    	[0, tileSize]
	    ];
	    var clipbase_upRightInner = [ // ['-] ////
	    	[0, 0],
	    	[(tileSize-bset.borderSources[1]['cutoff']), 0],
	    	[(tileSize-bset.borderSources[1]['cutoff']), bset.borderSources[0]['cutoff']],
	    	[tileSize, bset.borderSources[0]['cutoff']],
	    	[tileSize, tileSize],
	    	[0, tileSize]
	    ];
	    var clipbase_downRightInner = [ // [,-] ////
	    	[0, 0],
	    	[tileSize, 0],
	    	[tileSize, (tileSize-bset.borderSources[2]['cutoff'])],
	    	[(tileSize-bset.borderSources[1]['cutoff']), (tileSize-bset.borderSources[2]['cutoff'])],
	    	[(tileSize-bset.borderSources[1]['cutoff']), tileSize],
	    	[0, tileSize]
	    ];
	    var clipbase_downLeftInner = [ // [-,] ////
	    	[0, 0],
	    	[tileSize, 0],
	    	[tileSize, tileSize],
	    	[bset.borderSources[3]['cutoff'], tileSize],
	    	[bset.borderSources[3]['cutoff'], (tileSize-bset.borderSources[2]['cutoff'])],
	    	[0, (tileSize-bset.borderSources[2]['cutoff'])]
	    ];
	    var clipsbaseInner = [clipbase_upLeftInner, clipbase_upRightInner, clipbase_downRightInner, clipbase_downLeftInner];

		ctxClip(ctx, clipsbaseInner[i]);
    }

    //BORDER CLIPPING FUNCS
    //BORDER CLIPPING FUNCS
    //BORDER CLIPPING FUNCS
    //BORDER CLIPPING FUNCS

    function clipBorder(i, bsetA, bsetB) {
    	var mergeY_up = Math.floor((bsetA.borderSources[0]['width']+(tileSize-bsetB.borderSources[2]['width']))/2);
		var mergeX_right = Math.floor((bsetB.borderSources[3]['width']+(tileSize-bsetA.borderSources[1]['width']))/2);
		var mergeY_down = Math.floor((bsetB.borderSources[0]['width']+(tileSize-bsetA.borderSources[2]['width']))/2);
		var mergeX_left = Math.floor((bsetA.borderSources[3]['width']+(tileSize-bsetB.borderSources[1]['width']))/2);
        var clip_up = [ // [-`] ////
		    [0, mergeY_up],
			[tileSize, mergeY_up],
			[tileSize, 0],
			[0, 0]
		];
		var clip_right = [ // [|:] ////
		    [mergeX_right, 0],
			[mergeX_right, tileSize],
			[tileSize, tileSize],
			[tileSize, 0]
		];
		var clip_down = [ // [.-] ////
			[0, mergeY_down],
			[tileSize, mergeY_down],
			[tileSize, tileSize],
		    [0, tileSize]
		];
		var clip_left = [ // [:|] ////
			[mergeX_left, 0],
			[mergeX_left, tileSize],
		    [0, tileSize],
		    [0, 0]
	    ];
	    var clips = [clip_up, clip_right, clip_down, clip_left];
    	return clips[i];
    }

    function clipBorderInner(i, bsetA, bsetB) {
        var mergeY_up = Math.floor((bsetA.borderSources[0]['width']+(tileSize-bsetB.borderSources[2]['width']))/2);
		var mergeX_right = Math.floor((bsetB.borderSources[3]['width']+(tileSize-bsetA.borderSources[1]['width']))/2);
		var mergeY_down = Math.floor((bsetB.borderSources[0]['width']+(tileSize-bsetA.borderSources[2]['width']))/2);
		var mergeX_left = Math.floor((bsetA.borderSources[3]['width']+(tileSize-bsetB.borderSources[1]['width']))/2);
        var clip_upLeftInner = [ // [-'] ////
			[0, mergeY_down],
			[mergeX_right, mergeY_down],
			[mergeX_right, 0],
			[tileSize, 0],
			[tileSize, tileSize],
			[0, tileSize]
		];
		var clip_upRightInner = [ // ['-] ////
			[0, 0],
			[mergeX_left, 0],
			[mergeX_left, mergeY_down],
			[tileSize, mergeY_down],
			[tileSize, tileSize],
			[0, tileSize]
		];
		var clip_downRightInner = [ // [,-] ////
			[0, 0],
			[tileSize, 0],
			[tileSize, mergeY_up],
			[mergeX_left, mergeY_up],
			[mergeX_left, tileSize],
		    [0, tileSize]
		];
		var clip_downLeftInner = [ // [-,] ////
			[0, 0],
			[tileSize, 0],
			[tileSize, tileSize],
			[mergeX_right, tileSize],
			[mergeX_right, mergeY_up],
			[0, mergeY_up]
		];
	    var clipsInner = [clip_upLeftInner, clip_upRightInner, clip_downRightInner, clip_downLeftInner];
    	return clipsInner[i];
    }

    //DEFINE BORDER CLIPS
    //DEFINE BORDER CLIPS
    //DEFINE BORDER CLIPS
    //DEFINE BORDER CLIPS

    var clip_upLeft = [ // [`/]
    ];
    for(var ci = 0; ci <= tileSize; ci++) {
    	clip_upLeft.push([ci, tileSize-ci]);
    	clip_upLeft.push([ci+1, tileSize-ci]);
    }
    clip_upLeft.push([0, 0]);
    var clip_upRight = [ // [\`]
    ];
    for(var ci = 0; ci <= tileSize; ci++) {
    	clip_upRight.push([ci, ci]);
    	clip_upRight.push([ci+1, ci]);
    }
    clip_upRight.push([tileSize, 0]);
    var clip_downRight = [ // [/.]
    ];
    for(var ci = 0; ci <= tileSize; ci++) {
    	clip_downRight.push([ci, tileSize-ci]);
    	clip_downRight.push([ci+1, tileSize-ci]);
    }
    clip_downRight.push([tileSize, tileSize]);
    var clip_downLeft = [ // [.\]
    ];
    for(var ci = 0; ci <= tileSize; ci++) {
    	clip_downLeft.push([ci, ci]);
    	clip_downLeft.push([ci+1, ci]);
    }
    clip_downLeft.push([0, tileSize]);
    var clipsDiag = [clip_upRight, clip_downRight, clip_downLeft, clip_upLeft];

    //BORDER DRAWING FUNCS
    //BORDER DRAWING FUNCS
    //BORDER DRAWING FUNCS
    //BORDER DRAWING FUNCS

    function drawBorder(i, bset) {
    	if(bset.layersCache[i] == null) {
    		var layers = [];

	    	var canvas = document.createElement('canvas');
		    canvas.width  = tileSize;
		    canvas.height = tileSize;
		    var ctx = canvas.getContext('2d');

	    	layers.push(new Promise(function(resolve, reject) {
				var image = new Image();
		        image.addEventListener('load', function() {
		        	ctxDrawRotateFlip(ctx, image, bset.borderSources[i]['r']*90, bset.borderSources[i]['fx'], bset.borderSources[i]['fy']);
		            resolve(canvas);
		        }.bind(this));
				bset.borderSources[i]['src'].getImage().then(function(img) {
		        	image.src = img.toDataURL();
		        });
	        }.bind(this)));

	        bset.layersCache[i] = layers;
    	}
        return bset.layersCache[i];
    }

    function drawBorderOuter(i, bset) {
    	if(bset.layersCache[i+4] == null) {
	    	var layers = [];

	    	if(bset.borderSources[i+4]['c']) {
	    		var canvas0 = document.createElement('canvas');
			    canvas0.width  = tileSize;
			    canvas0.height = tileSize;
			    var ctx0 = canvas0.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxClip(ctx0, clipsDiag[i]);
			        	ctxDrawRotateFlip(ctx0, image, bset.borderSources[i]['r']*90, bset.borderSources[i]['fx'], bset.borderSources[i]['fy']);
			            resolve(canvas0);
			        }.bind(this));
					bset.borderSources[i]['src'].getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
		        }.bind(this)));

		        var canvas1 = document.createElement('canvas');
			    canvas1.width  = tileSize;
			    canvas1.height = tileSize;
			    var ctx1 = canvas1.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxClip(ctx1, clipsDiag[(i+2)%4]);
			        	ctxDrawRotateFlip(ctx1, image, bset.borderSources[(i+3)%4]['r']*90, bset.borderSources[(i+3)%4]['fx'], bset.borderSources[(i+3)%4]['fy']);
			            resolve(canvas1);
			        }.bind(this));
					bset.borderSources[(i+3)%4]['src'].getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
		        }.bind(this)));
	    	} else {
	    		var canvas0 = document.createElement('canvas');
			    canvas0.width  = tileSize;
			    canvas0.height = tileSize;
			    var ctx0 = canvas0.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxDrawRotateFlip(ctx0, image, bset.borderSources[i+4]['r']*90, bset.borderSources[i+4]['fx'], bset.borderSources[i+4]['fy']);
			            resolve(canvas0);
			        }.bind(this));
					bset.borderSources[i+4]['src'].getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
		        }.bind(this)));
	    	}

	    	bset.layersCache[i+4] = layers;
	    }
    	return bset.layersCache[i+4];
    }

    function drawBorderInner(i, bset) {
    	if(bset.layersCache[i+8] == null) {
	    	var layers = [];

	    	if(bset.borderSources[i+8]['c']) {
	    		var canvas0 = document.createElement('canvas');
			    canvas0.width  = tileSize;
			    canvas0.height = tileSize;
			    var ctx0 = canvas0.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxClip(ctx0, clipsDiag[(i+2)%4]);
			        	ctxDrawRotateFlip(ctx0, image, bset.borderSources[i]['r']*90, bset.borderSources[i]['fx'], bset.borderSources[i]['fy']);
			            resolve(canvas0);
			        }.bind(this));
					bset.borderSources[i]['src'].getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
		        }.bind(this)));

		        var canvas1 = document.createElement('canvas');
			    canvas1.width  = tileSize;
			    canvas1.height = tileSize;
			    var ctx1 = canvas1.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxClip(ctx1, clipsDiag[i]);
			        	ctxDrawRotateFlip(ctx1, image, bset.borderSources[(i+3)%4]['r']*90, bset.borderSources[(i+3)%4]['fx'], bset.borderSources[(i+3)%4]['fy']);
			            resolve(canvas1);
			        }.bind(this));
					bset.borderSources[(i+3)%4]['src'].getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
		        }.bind(this)));
	    	} else {
	    		var canvas0 = document.createElement('canvas');
			    canvas0.width  = tileSize;
			    canvas0.height = tileSize;
			    var ctx0 = canvas0.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxDrawRotateFlip(ctx0, image, bset.borderSources[i+8]['r']*90, bset.borderSources[i+8]['fx'], bset.borderSources[i+8]['fy']);
			            resolve(canvas0);
			        }.bind(this));
					bset.borderSources[i+8]['src'].getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
		        }.bind(this)));
	    	}

	    	bset.layersCache[i+8] = layers;
	    }
    	return bset.layersCache[i+8];
    }

 	//BEGIN ALGORITHM
    //BEGIN ALGORITHM
    //BEGIN ALGORITHM
    //BEGIN ALGORITHM

    var layers = []; //OPTIMIZE
    for(var i in this.bsets) {
    	if(!this.bsets[i].isReady) {
            return layers;
    	}
    }

    var genMatrix = this.genMatrixCache;
	if(genMatrix == null) {
		layers.push(BorderGenerator.missingImage);
	} else {
		var tileBase = genMatrix[0];
		//base layer
		//base layer
		//base layer
	    var canvas = document.createElement('canvas');
	    canvas.width  = tileSize;
	    canvas.height = tileSize;
	    var ctx = canvas.getContext('2d');

	    for(var r = 0; r < 4; r++) { //for all 4 directions
	    	if(genMatrix[1+(1+r*2)%8]!=tileBase) {
	    		clipBorderBase(r, ctx, tileBase.getRelation(genMatrix[1+(1+r*2)%8]).getBorderSet());
	    	}
	    	if(	genMatrix[1+(1+r*2)%8]==tileBase
	    	&&	genMatrix[1+(7+r*2)%8]==tileBase
	    	&&	genMatrix[1+(0+r*2)%8]!=tileBase) {
	    		clipBorderInnerBase(r, ctx, tileBase.getRelation(genMatrix[1+(0+r*2)%8]).getBorderSet());
	    	}
	    }

	    layers.push(new Promise(function(resolve, reject) {
	        tileBase.getImage().then(function(img) {
	        	ctx.drawImage(img, 0, 0);
            	resolve(canvas);
	        });
	    }.bind(this)));

	    //overlay layers
	    //overlay layers
	    //overlay layers
	    var uniqueTiles = [];
	    for(var k = 1; k < genMatrix.length; k++) {
	    	var gTile = genMatrix[k];
	    	if(gTile == null || gTile == tileBase) {
	    		continue;
	    	}
	    	var bcIdx = uniqueTiles.indexOf(gTile);
	    	if(bcIdx == -1) {
	    		uniqueTiles.push(gTile);
	    	}
	    }
	    var canvasLayers = [];
	    for(var k in uniqueTiles) {
	    	var ut = uniqueTiles[k];
	    	var bset = tileBase.getRelation(ut).getBorderSet();
	    	for(var r = 0; r < 4; r++) {
    			//for all 4 directions
    			//full version logic
                if(	genMatrix[1+(1+r*2)%8]==ut
    			&&	genMatrix[1+(3+r*2)%8]==tileBase
    			&&	genMatrix[1+(7+r*2)%8]==tileBase
    			||
    			    genMatrix[1+(1+r*2)%8]==ut
    			&&  genMatrix[1+(7+r*2)%8]!=ut && genMatrix[1+(7+r*2)%8]!=tileBase
    			||
    			    genMatrix[1+(1+r*2)%8]==ut
    			&&  genMatrix[1+(7+r*2)%8]==ut
    			&&  bset.borderSources[4+(0+r)%4]['c']
    			||
    			    genMatrix[1+(1+r*2)%8]==ut
    			&&  genMatrix[1+(3+r*2)%8]!=ut && genMatrix[1+(3+r*2)%8]!=tileBase
    			||
    			    genMatrix[1+(1+r*2)%8]==ut
    			&&  genMatrix[1+(3+r*2)%8]==ut
    			&&  bset.borderSources[4+(1+r)%4]['c']) {
    				//border up
    				var layersB = drawBorder.bind(this)((0+r)%4, bset);
    				var clipsB = [];
    				//CUTS
    				if(genMatrix[1+(6+r*2)%8]!=tileBase && genMatrix[1+(6+r*2)%8]!=null) {
    					//bottom left cut
    					clipsB.push(clipBorderInner.bind(this)((3+r)%4, bset, tileBase.getRelation(genMatrix[1+(6+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(5+r*2)%8]!=tileBase) {
    					//bottom cut
				    	clipsB.push(clipBorder.bind(this)((0+r)%4, bset, tileBase.getRelation(genMatrix[1+(5+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(4+r*2)%8]!=tileBase && genMatrix[1+(4+r*2)%8]!=null) {
    					//bottom right cut
    					clipsB.push(clipBorderInner.bind(this)((2+r)%4, bset, tileBase.getRelation(genMatrix[1+(4+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(3+r*2)%8]==ut && !bset.borderSources[4+(1+r)%4]['c']) {
    					//right cut
				    	clipsB.push(clipBorder.bind(this)((3+r)%4, bset, tileBase.getRelation(genMatrix[1+(3+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(7+r*2)%8]==ut && !bset.borderSources[4+(0+r)%4]['c']) {
    					//left cut
				    	clipsB.push(clipBorder.bind(this)((1+r)%4, bset, tileBase.getRelation(genMatrix[1+(7+r*2)%8]).getBorderSet()));
    				}

    				if(	genMatrix[1+(3+r*2)%8]==ut && bset.borderSources[4+(1+r)%4]['c']
    				||	genMatrix[1+(3+r*2)%8]!=ut && genMatrix[1+(3+r*2)%8]!=tileBase) {
    					//diag cut preserve top left
				    	clipsB.push(clipsDiag[(r+3)%4]);
    				}
    				if(	genMatrix[1+(7+r*2)%8]==ut && bset.borderSources[4+(0+r)%4]['c']
    				||	genMatrix[1+(7+r*2)%8]!=ut && genMatrix[1+(7+r*2)%8]!=tileBase) {
    					//diag cut preserve top right
				    	clipsB.push(clipsDiag[(r+0)%4]);
    				}
    				var layersFinal = [];
    				for(var lb in layersB) {
    					layersFinal.push([layersB[lb], clipsB]);
    				}
    				canvasLayers = canvasLayers.concat(layersFinal);
    		    }
    			if(	genMatrix[1+(1+r*2)%8]==ut
    			&&	genMatrix[1+(7+r*2)%8]==ut
    			&&	!bset.borderSources[4+(0+r)%4]['c']) {
    				//corner topleft
    				var layersB = drawBorderOuter.bind(this)((0+r)%4, bset);
    				var clipsB = [];
    				//CUTS
					if(genMatrix[1+(3+r*2)%8]!=tileBase) {
    					//right cut
    					clipsB.push(clipBorder.bind(this)((3+r)%4, bset, tileBase.getRelation(genMatrix[1+(3+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(4+r*2)%8]!=tileBase && genMatrix[1+(4+r*2)%8]!=null) {
    					//bottom right cut
    					clipsB.push(clipBorderInner.bind(this)((2+r)%4, bset, tileBase.getRelation(genMatrix[1+(4+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(5+r*2)%8]!=tileBase) {
    					//bottom cut
    					clipsB.push(clipBorder.bind(this)((0+r)%4, bset, tileBase.getRelation(genMatrix[1+(5+r*2)%8]).getBorderSet()));
    				}
    				var layersFinal = [];
    				for(var lb in layersB) {
    					layersFinal.push([layersB[lb], clipsB]);
    				}
    				canvasLayers = canvasLayers.concat(layersFinal);
    			}
    			if(	genMatrix[1+(0+r*2)%8]==ut
    			&&	genMatrix[1+(1+r*2)%8]==tileBase
    			&&	genMatrix[1+(7+r*2)%8]==tileBase) {
    				//inner border top left
    				var layersB = drawBorderInner.bind(this)((0+r)%4, bset);
    				var clipsB = [];
    				//CUTS
    				if(genMatrix[1+(2+r*2)%8]!=tileBase && genMatrix[1+(2+r*2)%8]!=null) {
    					//top right cut
    					clipsB.push(clipBorderInner.bind(this)((1+r)%4, bset, tileBase.getRelation(genMatrix[1+(2+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(3+r*2)%8]!=tileBase) {
    					//right cut
    					clipsB.push(clipBorder.bind(this)((3+r)%4, bset, tileBase.getRelation(genMatrix[1+(3+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(4+r*2)%8]!=tileBase && genMatrix[1+(4+r*2)%8]!=null) {
    					//bottom right cut
    					clipsB.push(clipBorderInner.bind(this)((2+r)%4, bset, tileBase.getRelation(genMatrix[1+(4+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(5+r*2)%8]!=tileBase) {
    					//bottom cut
    					clipsB.push(clipBorder.bind(this)((0+r)%4, bset, tileBase.getRelation(genMatrix[1+(5+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(6+r*2)%8]!=tileBase && genMatrix[1+(6+r*2)%8]!=null) {
    					//bottom left cut
    					clipsB.push(clipBorderInner.bind(this)((3+r)%4, bset, tileBase.getRelation(genMatrix[1+(6+r*2)%8]).getBorderSet()));
    				}
    				var layersFinal = [];
    				for(var lb in layersB) {
    					layersFinal.push([layersB[lb], clipsB]);
    				}
    				canvasLayers = canvasLayers.concat(layersFinal);
    			}
    		}
	    }

	    for(var i in canvasLayers) {
	    	var canvasLayer = canvasLayers[i];
	    	(function(cl) {
	    		layers.push(new Promise(function(resolve, reject) {
	    			cl[0].then(function(data) {
	    				var newCanvas = document.createElement('canvas');
					    newCanvas.width  = tileSize;
					    newCanvas.height = tileSize;
					    var ctx = newCanvas.getContext('2d');

					    ctx.drawImage(data, 0, 0);
					    ctx.globalCompositeOperation = "destination-in";
		            	for(var k in cl[1]) {
					    	ctxMask(ctx, cl[1][k]);
					    }

					    resolve(newCanvas);
	    			});
		    	}.bind(this)));
	    	}.bind(this))(canvasLayer);
	    }

	    if(this.pre2_0_0) {
	    	//generate warning texture
			//canvas
			var canvasWarn = document.createElement('canvas');
		    canvasWarn.width  = tileSize;
		    canvasWarn.height = tileSize;
		    var ctxWarn = canvasWarn.getContext('2d');
		    //drawing
		    var p = new Promise(function(resolve, reject) {
			    var image = new Image();
		        image.addEventListener('load', function() {
		        	for(var ix = 0; ix < tileSize; ix+=image.width) {
		        		for(var iy = 0; iy < tileSize; iy+=image.height) {
		        			ctxWarn.drawImage(image, ix, iy);
		        		}
		        	}
		            resolve();
		        });
		        image.src = nativeImage.createFromPath(path.join(__dirname, '/../../res/placeholder/warning.png')).toDataURL();
		    }.bind(this));
		    //finish
		    layers.push(p.then(function() {
		    	return new Promise(function(resolve, reject) {
		            resolve(canvasWarn);
			    });
		    }));
	    }
	}

    return layers;
}

var getLayersIsometric = function() {
	//HELPER FUNCTIONS & VARS
	//HELPER FUNCTIONS & VARS
	//HELPER FUNCTIONS & VARS
	//HELPER FUNCTIONS & VARS

	var ctxClip = function(ctx, clip) {
    	ctx.beginPath();
    	var origin = clip[0];
    	ctx.moveTo(origin[0], origin[1]);
    	for(var i = 1; i < clip.length; i++) {
    		var point = clip[i];
    		ctx.lineTo(point[0], point[1]);
    	}
    	ctx.clip();
    }

    var ctxMask = function(ctx, clip) {
    	ctx.beginPath();
    	var origin = clip[0];
    	ctx.moveTo(origin[0], origin[1]);
    	for(var i = 1; i < clip.length; i++) {
    		var point = clip[i];
    		ctx.lineTo(point[0], point[1]);
    	}
    	ctx.fill();
    }

    var ctxDrawRotateFlip = function(ctx, image, deg, fx, fy) {
        ctx.translate(tileSize[0]/2, tileSize[1]/2);
        if(fx) {
			ctx.scale(-1, 1);
		}
		if(fy) {
			ctx.scale(1, -1);
		}
		ctx.drawImage(image, -tileSize[0]/2, -tileSize[1]/2);
		if(fx) {
			ctx.scale(-1, 1);
		}
		if(fy) {
			ctx.scale(1, -1);
		}
		ctx.translate(-tileSize[0]/2, -tileSize[1]/2);
    }

	var tileSize = tileroninX.getTileSize();

	//BASE CLIPPING FUNCS
    //BASE CLIPPING FUNCS
    //BASE CLIPPING FUNCS
    //BASE CLIPPING FUNCS

    function clipBorderBase(i, ctx, bset) {
    	var mid = tileSize[0]/2;
    	var step = tileSize[0]/tileSize[1];

    	var clipbase_up = [];
    	for(var k = 0; k < tileSize[1]; k++) {
    		clipbase_up.push([mid+(k+1)*step-bset.borderSources[0]['cutoff'], k]);
    		clipbase_up.push([mid+(k+1)*step-bset.borderSources[0]['cutoff'], k+1]);
    	}
    	clipbase_up.push([0, tileSize[1]]);
    	clipbase_up.push([0, 0]);

    	var clipbase_right = [];
    	for(var k = 0; k < tileSize[1]; k++) {
    		clipbase_right.push([mid+(k+1)*step-bset.borderSources[1]['cutoff'], tileSize[1]-k]);
    		clipbase_right.push([mid+(k+1)*step-bset.borderSources[1]['cutoff'], tileSize[1]-k-1]);
    	}
    	clipbase_right.push([0, 0]);
    	clipbase_right.push([0, tileSize[1]]);

    	var clipbase_down = [];
    	for(var k = 0; k < tileSize[1]; k++) {
    		clipbase_down.push([mid-(k+1)*step+bset.borderSources[2]['cutoff'], tileSize[1]-k]);
    		clipbase_down.push([mid-(k+1)*step+bset.borderSources[2]['cutoff'], tileSize[1]-k-1]);
    	}
    	clipbase_down.push([tileSize[0], 0]);
    	clipbase_down.push([tileSize[0], tileSize[1]]);

    	var clipbase_left = [];
    	for(var k = 0; k < tileSize[1]; k++) {
    		clipbase_left.push([mid-(k+1)*step+bset.borderSources[3]['cutoff'], k]);
    		clipbase_left.push([mid-(k+1)*step+bset.borderSources[3]['cutoff'], k+1]);
    	}
    	clipbase_left.push([tileSize[0], tileSize[1]]);
    	clipbase_left.push([tileSize[0], 0]);

	    var clipsbase = [clipbase_up, clipbase_right, clipbase_down, clipbase_left];

    	ctxClip(ctx, clipsbase[i]);
    }

    function clipBorderInnerBase(i, ctx, bset) {
    	var mid = tileSize[0]/2;
    	var step = tileSize[0]/tileSize[1];

    	var clipbase_upLeftInner = [];
    	var g_ul = bset.borderSources[0]['cutoff']+bset.borderSources[3]['cutoff']-2*step;
    	g_ul = Math.floor((g_ul-1)/(2*step))+1;
    	for(var k = 0; k < g_ul; k++) {
    		clipbase_upLeftInner.push([mid+(k+1)*step-bset.borderSources[0]['cutoff'], k]);
    		clipbase_upLeftInner.push([mid+(k+1)*step-bset.borderSources[0]['cutoff'], k+1]);
    	}
    	for(var k = g_ul-1; k >= 0; k--) {
    		clipbase_upLeftInner.push([mid-(k+1)*step+bset.borderSources[3]['cutoff'], k+1]);
    		clipbase_upLeftInner.push([mid-(k+1)*step+bset.borderSources[3]['cutoff'], k]);
    	}
    	clipbase_upLeftInner.push([tileSize[0], 0]);
    	clipbase_upLeftInner.push([tileSize[0], tileSize[1]]);
    	clipbase_upLeftInner.push([0, tileSize[1]]);
    	clipbase_upLeftInner.push([0, 0]);

    	var clipbase_upRightInner = [];
    	var k_ur = bset.borderSources[1]['cutoff']-bset.borderSources[0]['cutoff'];
    	var g_ur = tileSize[1]/2-Math.floor((k_ur+step-1)/(2*step));
    	var h_ur = tileSize[1]/2+Math.floor((k_ur+step)/(2*step));
    	var q_ur = ((k_ur%step)==0) ? true : false;
    	for(var k = tileSize[1]-1; k >= tileSize[1]-g_ur; k--) {
    		clipbase_upRightInner.push([mid+(k+1)*step-bset.borderSources[1]['cutoff'], tileSize[1]-k-1]);
    		if(k != tileSize[1]-g_ur || !q_ur) {
    			clipbase_upRightInner.push([mid+(k+1)*step-bset.borderSources[1]['cutoff'], tileSize[1]-k]);
    		}
    	}
    	for(var k = tileSize[1]-h_ur; k < tileSize[1]; k++) {
    		if(k != tileSize[1]-h_ur || !q_ur) {
				clipbase_upRightInner.push([mid+(k+1)*step-bset.borderSources[0]['cutoff'], k]);
    		}
    		clipbase_upRightInner.push([mid+(k+1)*step-bset.borderSources[0]['cutoff'], k+1]);
    	}
    	clipbase_upRightInner.push([0, tileSize[1]]);
    	clipbase_upRightInner.push([0, 0]);

    	var clipbase_downRightInner = [];
    	var g_dr = bset.borderSources[1]['cutoff']+bset.borderSources[2]['cutoff']-2*step;
    	g_dr = Math.floor((g_dr-1)/(2*step))+1;
    	for(var k = 0; k < g_dr; k++) {
    		clipbase_downRightInner.push([mid+(k+1)*step-bset.borderSources[1]['cutoff'], tileSize[1]-k]);
    		clipbase_downRightInner.push([mid+(k+1)*step-bset.borderSources[1]['cutoff'], tileSize[1]-k-1]);
    	}
    	for(var k = g_dr-1; k >= 0; k--) {
    		clipbase_downRightInner.push([mid-(k+1)*step+bset.borderSources[2]['cutoff'], tileSize[1]-k-1]);
    		clipbase_downRightInner.push([mid-(k+1)*step+bset.borderSources[2]['cutoff'], tileSize[1]-k]);
    	}
    	clipbase_downRightInner.push([tileSize[0], tileSize[1]]);
    	clipbase_downRightInner.push([tileSize[0], 0]);
    	clipbase_downRightInner.push([0, 0]);
    	clipbase_downRightInner.push([0, tileSize[1]]);

    	var clipbase_downLeftInner = [];
    	var k_dl = bset.borderSources[2]['cutoff']-bset.borderSources[3]['cutoff'];
    	var g_dl = tileSize[1]/2-Math.floor((k_dl+step-1)/(2*step));
    	var h_dl = tileSize[1]/2+Math.floor((k_dl+step)/(2*step));
    	var q_dl = ((k_dl%step)==0) ? true : false;
    	for(var k = tileSize[1]-1; k >= tileSize[1]-g_dl; k--) {
    		clipbase_downLeftInner.push([mid-(k+1)*step+bset.borderSources[2]['cutoff'], tileSize[1]-k-1]);
    		if(k != tileSize[1]-g_dl || !q_dl) {
    			clipbase_downLeftInner.push([mid-(k+1)*step+bset.borderSources[2]['cutoff'], tileSize[1]-k]);
    		}
    	}
    	for(var k = tileSize[1]-h_dl; k < tileSize[1]; k++) {
    		if(k != tileSize[1]-h_dl || !q_dl) {
				clipbase_downLeftInner.push([mid-(k+1)*step+bset.borderSources[3]['cutoff'], k]);
			}
    		clipbase_downLeftInner.push([mid-(k+1)*step+bset.borderSources[3]['cutoff'], k+1]);
    	}
    	clipbase_downLeftInner.push([tileSize[0], tileSize[1]]);
    	clipbase_downLeftInner.push([tileSize[0], 0]);

	    var clipsbaseInner = [clipbase_upLeftInner, clipbase_upRightInner, clipbase_downRightInner, clipbase_downLeftInner];

		ctxClip(ctx, clipsbaseInner[i]);
    }

    //BORDER CLIPPING FUNCS
    //BORDER CLIPPING FUNCS
    //BORDER CLIPPING FUNCS
    //BORDER CLIPPING FUNCS

    function clipBorder(i, bsetA, bsetB) {
    	var mid = tileSize[0]/2;
    	var step = tileSize[0]/tileSize[1];
    	
    	var mergeY_up = Math.floor((bsetA.borderSources[0]['width']+(tileSize[0]+step-bsetB.borderSources[2]['width']))/2);
    	var mergeX_right = Math.floor((bsetB.borderSources[3]['width']+(tileSize[0]+step-bsetA.borderSources[1]['width']))/2);
    	var mergeY_down = Math.floor((bsetB.borderSources[0]['width']+(tileSize[0]+step-bsetA.borderSources[2]['width']))/2);
    	var mergeX_left = Math.floor((bsetA.borderSources[3]['width']+(tileSize[0]+step-bsetB.borderSources[1]['width']))/2);

    	var clip_up = [];
    	for(var k = 0; k < tileSize[1]; k++) {
    		clip_up.push([mid+(k+1)*step-mergeY_up, k]);
    		clip_up.push([mid+(k+1)*step-mergeY_up, k+1]);
    	}
    	clip_up.push([tileSize[0], tileSize[1]]);
    	clip_up.push([tileSize[0], 0]);

    	var clip_right = [];
    	for(var k = 0; k < tileSize[1]; k++) {
    		clip_right.push([mid-(k+1)*step+mergeX_right, k]);
    		clip_right.push([mid-(k+1)*step+mergeX_right, k+1]);
    	}
    	clip_right.push([tileSize[0], tileSize[1]]);
    	clip_right.push([tileSize[0], 0]);

    	var clip_down = [];
    	for(var k = 0; k < tileSize[1]; k++) {
    		clip_down.push([mid+(k+1)*step-mergeY_down, k]);
    		clip_down.push([mid+(k+1)*step-mergeY_down, k+1]);
    	}
    	clip_down.push([0, tileSize[1]]);
    	clip_down.push([0, 0]);

    	var clip_left = [];
    	for(var k = 0; k < tileSize[1]; k++) {
    		clip_left.push([mid-(k+1)*step+mergeX_left, k]);
    		clip_left.push([mid-(k+1)*step+mergeX_left, k+1]);
    	}
    	clip_left.push([0, tileSize[1]]);
    	clip_left.push([0, 0]);

	    var clips = [clip_up, clip_right, clip_down, clip_left];
    	return clips[i];
    }

    function clipBorderInner(i, bsetA, bsetB) {
    	var mid = tileSize[0]/2;
    	var step = tileSize[0]/tileSize[1];

    	var mergeY_up = Math.floor((bsetA.borderSources[0]['width']+(tileSize[0]+step-bsetB.borderSources[2]['width']))/2);
    	var mergeX_right = Math.floor((bsetB.borderSources[3]['width']+(tileSize[0]+step-bsetA.borderSources[1]['width']))/2);
    	var mergeY_down = Math.floor((bsetB.borderSources[0]['width']+(tileSize[0]+step-bsetA.borderSources[2]['width']))/2);
    	var mergeX_left = Math.floor((bsetA.borderSources[3]['width']+(tileSize[0]+step-bsetB.borderSources[1]['width']))/2);

    	var clip_upLeftInner = [];
    	var a_ul = mergeY_down;
    	var b_ul = mergeX_right;
    	var g_ul = a_ul+b_ul-2*step;
    	g_ul = Math.floor((g_ul-1)/(2*step))+1;
    	for(var k = 0; k < g_ul; k++) {
    		clip_upLeftInner.push([mid+(k+1)*step-a_ul, k]);
    		clip_upLeftInner.push([mid+(k+1)*step-a_ul, k+1]);
    	}
    	for(var k = g_ul-1; k >= 0; k--) {
    		clip_upLeftInner.push([mid-(k+1)*step+b_ul, k+1]);
    		clip_upLeftInner.push([mid-(k+1)*step+b_ul, k]);
    	}
    	clip_upLeftInner.push([tileSize[0], 0]);
    	clip_upLeftInner.push([tileSize[0], tileSize[1]]);
    	clip_upLeftInner.push([0, tileSize[1]]);
    	clip_upLeftInner.push([0, 0]);

    	var clip_upRightInner = [];
    	var a_ur = tileSize[0]+step-mergeX_left;
    	var b_ur = mergeY_down;
    	var k_ur = a_ur-b_ur;
    	var g_ur = tileSize[1]/2-Math.floor((k_ur+step-1)/(2*step));
    	var h_ur = tileSize[1]/2+Math.floor((k_ur+step)/(2*step));
    	var q_ur = ((k_ur%step)==0) ? true : false;
    	for(var k = tileSize[1]-1; k >= tileSize[1]-g_ur; k--) {
    		clip_upRightInner.push([mid+(k+1)*step-a_ur, tileSize[1]-k-1]);
    		if(k != tileSize[1]-g_ur || !q_ur) {
    			clip_upRightInner.push([mid+(k+1)*step-a_ur, tileSize[1]-k]);
    		}
    	}
    	for(var k = tileSize[1]-h_ur; k < tileSize[1]; k++) {
    		if(k != tileSize[1]-h_ur || !q_ur) {
				clip_upRightInner.push([mid+(k+1)*step-b_ur, k]);
    		}
    		clip_upRightInner.push([mid+(k+1)*step-b_ur, k+1]);
    	}
    	clip_upRightInner.push([0, tileSize[1]]);
    	clip_upRightInner.push([0, 0]);

    	var clip_downRightInner = [];
    	var a_dr = tileSize[0]+step-mergeX_left;
    	var b_dr = tileSize[0]+step-mergeY_up;
    	var g_dr = a_dr+b_dr-2*step;
    	g_dr = Math.floor((g_dr-1)/(2*step))+1;
    	for(var k = 0; k < g_dr; k++) {
    		clip_downRightInner.push([mid+(k+1)*step-a_dr, tileSize[1]-k]);
    		clip_downRightInner.push([mid+(k+1)*step-a_dr, tileSize[1]-k-1]);
    	}
    	for(var k = g_dr-1; k >= 0; k--) {
    		clip_downRightInner.push([mid-(k+1)*step+b_dr, tileSize[1]-k-1]);
    		clip_downRightInner.push([mid-(k+1)*step+b_dr, tileSize[1]-k]);
    	}
    	clip_downRightInner.push([tileSize[0], tileSize[1]]);
    	clip_downRightInner.push([tileSize[0], 0]);
    	clip_downRightInner.push([0, 0]);
    	clip_downRightInner.push([0, tileSize[1]]);

    	var clip_downLeftInner = [];
    	var a_dl = tileSize[0]+step-mergeY_up;
    	var b_dl = mergeX_right;
    	var k_dl = a_dl-b_dl;
    	var g_dl = tileSize[1]/2-Math.floor((k_dl+step-1)/(2*step));
    	var h_dl = tileSize[1]/2+Math.floor((k_dl+step)/(2*step));
    	var q_dl = ((k_dl%step)==0) ? true : false;
    	for(var k = tileSize[1]-1; k >= tileSize[1]-g_dl; k--) {
    		clip_downLeftInner.push([mid-(k+1)*step+a_dl, tileSize[1]-k-1]);
    		if(k != tileSize[1]-g_dl || !q_dl) {
    			clip_downLeftInner.push([mid-(k+1)*step+a_dl, tileSize[1]-k]);
    		}
    	}
    	for(var k = tileSize[1]-h_dl; k < tileSize[1]; k++) {
    		if(k != tileSize[1]-h_dl || !q_dl) {
				clip_downLeftInner.push([mid-(k+1)*step+b_dl, k]);
			}
    		clip_downLeftInner.push([mid-(k+1)*step+b_dl, k+1]);
    	}
    	clip_downLeftInner.push([tileSize[0], tileSize[1]]);
    	clip_downLeftInner.push([tileSize[0], 0]);

	    var clipsInner = [clip_upLeftInner, clip_upRightInner, clip_downRightInner, clip_downLeftInner];
    	return clipsInner[i];
    }

    //DEFINE BORDER CLIPS
    //DEFINE BORDER CLIPS
    //DEFINE BORDER CLIPS
    //DEFINE BORDER CLIPS

    var clip_upLeft = [ // [`/]
    	[0, 0],
    	[tileSize[0], 0],
    	[tileSize[0], tileSize[1]/2],
    	[0, tileSize[1]/2]
    ];
    var clip_upRight = [ // [\`]
    	[tileSize[0]/2, 0],
    	[tileSize[0], 0],
    	[tileSize[0], tileSize[1]],
    	[tileSize[0]/2, tileSize[1]]
    ];
    var clip_downRight = [ // [/.]
    	[0, tileSize[1]/2],
    	[tileSize[0], tileSize[1]/2],
    	[tileSize[0], tileSize[1]],
    	[0, tileSize[1]]
    ];
    var clip_downLeft = [ // [.\]
    	[0, 0],
    	[tileSize[0]/2, 0],
    	[tileSize[0]/2, tileSize[1]],
    	[0, tileSize[1]]
    ];
    var clipsDiag = [clip_upRight, clip_downRight, clip_downLeft, clip_upLeft];

    //BORDER DRAWING FUNCS
    //BORDER DRAWING FUNCS
    //BORDER DRAWING FUNCS
    //BORDER DRAWING FUNCS

    function drawBorder(i, bset) {
    	if(bset.layersCache[i] == null) {
    		var layers = [];

	    	var canvas = document.createElement('canvas');
		    canvas.width  = tileSize[0];
		    canvas.height = tileSize[1];
		    var ctx = canvas.getContext('2d');

	    	layers.push(new Promise(function(resolve, reject) {
				var image = new Image();
		        image.addEventListener('load', function() {
		        	ctxDrawRotateFlip(ctx, image, bset.borderSources[i]['r']*90, bset.borderSources[i]['fx'], bset.borderSources[i]['fy']);
		            resolve(canvas);
		        }.bind(this));
				bset.borderSources[i]['src'].getImage().then(function(img) {
		        	image.src = img.toDataURL();
		        });
	        }.bind(this)));

	        bset.layersCache[i] = layers;
    	}
        return bset.layersCache[i];
    }

    function drawBorderOuter(i, bset) {
    	if(bset.layersCache[i+4] == null) {
	    	var layers = [];

	    	if(bset.borderSources[i+4]['c']) {
	    		var canvas0 = document.createElement('canvas');
			    canvas0.width  = tileSize[0];
			    canvas0.height = tileSize[1];
			    var ctx0 = canvas0.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxClip(ctx0, clipsDiag[i]);
			        	ctxDrawRotateFlip(ctx0, image, bset.borderSources[i]['r']*90, bset.borderSources[i]['fx'], bset.borderSources[i]['fy']);
			            resolve(canvas0);
			        }.bind(this));
					bset.borderSources[i]['src'].getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
		        }.bind(this)));

		        var canvas1 = document.createElement('canvas');
			    canvas1.width  = tileSize[0];
			    canvas1.height = tileSize[1];
			    var ctx1 = canvas1.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxClip(ctx1, clipsDiag[(i+2)%4]);
			        	ctxDrawRotateFlip(ctx1, image, bset.borderSources[(i+3)%4]['r']*90, bset.borderSources[(i+3)%4]['fx'], bset.borderSources[(i+3)%4]['fy']);
			            resolve(canvas1);
			        }.bind(this));
					bset.borderSources[(i+3)%4]['src'].getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
		        }.bind(this)));
	    	} else {
	    		var canvas0 = document.createElement('canvas');
			    canvas0.width  = tileSize[0];
			    canvas0.height = tileSize[1];
			    var ctx0 = canvas0.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxDrawRotateFlip(ctx0, image, bset.borderSources[i+4]['r']*90, bset.borderSources[i+4]['fx'], bset.borderSources[i+4]['fy']);
			            resolve(canvas0);
			        }.bind(this));
					bset.borderSources[i+4]['src'].getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
		        }.bind(this)));
	    	}

	    	bset.layersCache[i+4] = layers;
	    }
    	return bset.layersCache[i+4];
    }

    function drawBorderInner(i, bset) {
    	if(bset.layersCache[i+8] == null) {
	    	var layers = [];

	    	if(bset.borderSources[i+8]['c']) {
	    		var canvas0 = document.createElement('canvas');
			    canvas0.width  = tileSize[0];
			    canvas0.height = tileSize[1];
			    var ctx0 = canvas0.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxClip(ctx0, clipsDiag[(i+2)%4]);
			        	ctxDrawRotateFlip(ctx0, image, bset.borderSources[i]['r']*90, bset.borderSources[i]['fx'], bset.borderSources[i]['fy']);
			            resolve(canvas0);
			        }.bind(this));
					bset.borderSources[i]['src'].getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
		        }.bind(this)));

		        var canvas1 = document.createElement('canvas');
			    canvas1.width  = tileSize[0];
			    canvas1.height = tileSize[1];
			    var ctx1 = canvas1.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxClip(ctx1, clipsDiag[i]);
			        	ctxDrawRotateFlip(ctx1, image, bset.borderSources[(i+3)%4]['r']*90, bset.borderSources[(i+3)%4]['fx'], bset.borderSources[(i+3)%4]['fy']);
			            resolve(canvas1);
			        }.bind(this));
					bset.borderSources[(i+3)%4]['src'].getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
		        }.bind(this)));
	    	} else {
	    		var canvas0 = document.createElement('canvas');
			    canvas0.width  = tileSize[0];
			    canvas0.height = tileSize[1];
			    var ctx0 = canvas0.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxDrawRotateFlip(ctx0, image, bset.borderSources[i+8]['r']*90, bset.borderSources[i+8]['fx'], bset.borderSources[i+8]['fy']);
			            resolve(canvas0);
			        }.bind(this));
					bset.borderSources[i+8]['src'].getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
		        }.bind(this)));
	    	}

	    	bset.layersCache[i+8] = layers;
	    }
    	return bset.layersCache[i+8];
    }

	//BEGIN ALGORITHM
    //BEGIN ALGORITHM
    //BEGIN ALGORITHM
    //BEGIN ALGORITHM

    var layers = []; //OPTIMIZE
    for(var i in this.bsets) {
    	if(!this.bsets[i].isReady) {
            return layers;
    	}
    }

    var genMatrix = this.genMatrixCache;
	if(genMatrix == null) {
		layers.push(BorderGenerator.missingImage);
	} else {
		var tileBase = genMatrix[0];
		//base layer
		//base layer
		//base layer
	    var canvas = document.createElement('canvas');
	    canvas.width  = tileSize[0];
	    canvas.height = tileSize[1];
	    var ctx = canvas.getContext('2d');

	    for(var r = 0; r < 4; r++) { //for all 4 directions
	    	if(genMatrix[1+(1+r*2)%8]!=tileBase) {
	    		clipBorderBase(r, ctx, tileBase.getRelation(genMatrix[1+(1+r*2)%8]).getBorderSet());
	    	}
	    	if(	genMatrix[1+(1+r*2)%8]==tileBase
	    	&&	genMatrix[1+(7+r*2)%8]==tileBase
	    	&&	genMatrix[1+(0+r*2)%8]!=tileBase) {
	    		clipBorderInnerBase(r, ctx, tileBase.getRelation(genMatrix[1+(0+r*2)%8]).getBorderSet());
	    	}
	    }

	    layers.push(new Promise(function(resolve, reject) {
	        tileBase.getImage().then(function(img) {
	        	ctx.drawImage(img, 0, 0);
            	resolve(canvas);
	        });
	    }.bind(this)));

	    //overlay layers
	    //overlay layers
	    //overlay layers
	    var uniqueTiles = [];
	    for(var k = 1; k < genMatrix.length; k++) {
	    	var gTile = genMatrix[k];
	    	if(gTile == null || gTile == tileBase) {
	    		continue;
	    	}
	    	var bcIdx = uniqueTiles.indexOf(gTile);
	    	if(bcIdx == -1) {
	    		uniqueTiles.push(gTile);
	    	}
	    }
	    var canvasLayers = [];
	    for(var k in uniqueTiles) {
	    	var ut = uniqueTiles[k];
	    	var bset = tileBase.getRelation(ut).getBorderSet();
	    	for(var r = 0; r < 4; r++) {
    			//for all 4 directions
    			//full version logic
                if(	genMatrix[1+(1+r*2)%8]==ut
    			&&	genMatrix[1+(3+r*2)%8]==tileBase
    			&&	genMatrix[1+(7+r*2)%8]==tileBase
    			||
    			    genMatrix[1+(1+r*2)%8]==ut
    			&&  genMatrix[1+(7+r*2)%8]!=ut && genMatrix[1+(7+r*2)%8]!=tileBase
    			||
    			    genMatrix[1+(1+r*2)%8]==ut
    			&&  genMatrix[1+(7+r*2)%8]==ut
    			&&  bset.borderSources[4+(0+r)%4]['c']
    			||
    			    genMatrix[1+(1+r*2)%8]==ut
    			&&  genMatrix[1+(3+r*2)%8]!=ut && genMatrix[1+(3+r*2)%8]!=tileBase
    			||
    			    genMatrix[1+(1+r*2)%8]==ut
    			&&  genMatrix[1+(3+r*2)%8]==ut
    			&&  bset.borderSources[4+(1+r)%4]['c']) {
    				//border up
    				var layersB = drawBorder.bind(this)((0+r)%4, bset);
    				var clipsB = [];
    				//CUTS
    				if(genMatrix[1+(6+r*2)%8]!=tileBase && genMatrix[1+(6+r*2)%8]!=null) {
    					//bottom left cut
    					clipsB.push(clipBorderInner.bind(this)((3+r)%4, bset, tileBase.getRelation(genMatrix[1+(6+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(5+r*2)%8]!=tileBase) {
    					//bottom cut
				    	clipsB.push(clipBorder.bind(this)((0+r)%4, bset, tileBase.getRelation(genMatrix[1+(5+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(4+r*2)%8]!=tileBase && genMatrix[1+(4+r*2)%8]!=null) {
    					//bottom right cut
    					clipsB.push(clipBorderInner.bind(this)((2+r)%4, bset, tileBase.getRelation(genMatrix[1+(4+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(3+r*2)%8]==ut && !bset.borderSources[4+(1+r)%4]['c']) {
    					//right cut
				    	clipsB.push(clipBorder.bind(this)((3+r)%4, bset, tileBase.getRelation(genMatrix[1+(3+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(7+r*2)%8]==ut && !bset.borderSources[4+(0+r)%4]['c']) {
    					//left cut
				    	clipsB.push(clipBorder.bind(this)((1+r)%4, bset, tileBase.getRelation(genMatrix[1+(7+r*2)%8]).getBorderSet()));
    				}

    				if(	genMatrix[1+(3+r*2)%8]==ut && bset.borderSources[4+(1+r)%4]['c']
    				||	genMatrix[1+(3+r*2)%8]!=ut && genMatrix[1+(3+r*2)%8]!=tileBase) {
    					//diag cut preserve top left
				    	clipsB.push(clipsDiag[(r+3)%4]);
    				}
    				if(	genMatrix[1+(7+r*2)%8]==ut && bset.borderSources[4+(0+r)%4]['c']
    				||	genMatrix[1+(7+r*2)%8]!=ut && genMatrix[1+(7+r*2)%8]!=tileBase) {
    					//diag cut preserve top right
				    	clipsB.push(clipsDiag[(r+0)%4]);
    				}
    				var layersFinal = [];
    				for(var lb in layersB) {
    					layersFinal.push([layersB[lb], clipsB]);
    				}
    				canvasLayers = canvasLayers.concat(layersFinal);
    		    }
    			if(	genMatrix[1+(1+r*2)%8]==ut
    			&&	genMatrix[1+(7+r*2)%8]==ut
    			&&	!bset.borderSources[4+(0+r)%4]['c']) {
    				//corner topleft
    				var layersB = drawBorderOuter.bind(this)((0+r)%4, bset);
    				var clipsB = [];
    				//CUTS
					if(genMatrix[1+(3+r*2)%8]!=tileBase) {
    					//right cut
    					clipsB.push(clipBorder.bind(this)((3+r)%4, bset, tileBase.getRelation(genMatrix[1+(3+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(4+r*2)%8]!=tileBase && genMatrix[1+(4+r*2)%8]!=null) {
    					//bottom right cut
    					clipsB.push(clipBorderInner.bind(this)((2+r)%4, bset, tileBase.getRelation(genMatrix[1+(4+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(5+r*2)%8]!=tileBase) {
    					//bottom cut
    					clipsB.push(clipBorder.bind(this)((0+r)%4, bset, tileBase.getRelation(genMatrix[1+(5+r*2)%8]).getBorderSet()));
    				}
    				var layersFinal = [];
    				for(var lb in layersB) {
    					layersFinal.push([layersB[lb], clipsB]);
    				}
    				canvasLayers = canvasLayers.concat(layersFinal);
    			}
    			if(	genMatrix[1+(0+r*2)%8]==ut
    			&&	genMatrix[1+(1+r*2)%8]==tileBase
    			&&	genMatrix[1+(7+r*2)%8]==tileBase) {
    				//inner border top left
    				var layersB = drawBorderInner.bind(this)((0+r)%4, bset);
    				var clipsB = [];
    				//CUTS
    				if(genMatrix[1+(2+r*2)%8]!=tileBase && genMatrix[1+(2+r*2)%8]!=null) {
    					//top right cut
    					clipsB.push(clipBorderInner.bind(this)((1+r)%4, bset, tileBase.getRelation(genMatrix[1+(2+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(3+r*2)%8]!=tileBase) {
    					//right cut
    					clipsB.push(clipBorder.bind(this)((3+r)%4, bset, tileBase.getRelation(genMatrix[1+(3+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(4+r*2)%8]!=tileBase && genMatrix[1+(4+r*2)%8]!=null) {
    					//bottom right cut
    					clipsB.push(clipBorderInner.bind(this)((2+r)%4, bset, tileBase.getRelation(genMatrix[1+(4+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(5+r*2)%8]!=tileBase) {
    					//bottom cut
    					clipsB.push(clipBorder.bind(this)((0+r)%4, bset, tileBase.getRelation(genMatrix[1+(5+r*2)%8]).getBorderSet()));
    				}
    				if(genMatrix[1+(6+r*2)%8]!=tileBase && genMatrix[1+(6+r*2)%8]!=null) {
    					//bottom left cut
    					clipsB.push(clipBorderInner.bind(this)((3+r)%4, bset, tileBase.getRelation(genMatrix[1+(6+r*2)%8]).getBorderSet()));
    				}
    				var layersFinal = [];
    				for(var lb in layersB) {
    					layersFinal.push([layersB[lb], clipsB]);
    				}
    				canvasLayers = canvasLayers.concat(layersFinal);
    			}
    		}
	    }

	    for(var i in canvasLayers) {
	    	var canvasLayer = canvasLayers[i];
	    	(function(cl) {
	    		layers.push(new Promise(function(resolve, reject) {
	    			cl[0].then(function(data) {
	    				var newCanvas = document.createElement('canvas');
					    newCanvas.width  = tileSize[0];
					    newCanvas.height = tileSize[1];
					    var ctx = newCanvas.getContext('2d');

					    ctx.drawImage(data, 0, 0);
					    ctx.globalCompositeOperation = "destination-in";
		            	for(var k in cl[1]) {
					    	ctxMask(ctx, cl[1][k]);
					    }

					    resolve(newCanvas);
	    			});
		    	}.bind(this)));
	    	}.bind(this))(canvasLayer);
	    }
	}

    return layers;
}

class BorderGeneratorBlob extends BorderGenerator {
	constructor() {
		super();
		this.tile = null;
		this.bsets = [];
		this.bsetCallbacks = [];
		this.imageTiles = [];
		this.imageTileCallbacks = [];
		this.genMatrixCache = null;
		this.pre2_0_0 = false;
	}

	setTile(t) {
		if(this.tile != null) {
			return;
		}
		this.tile = t;
		this.tile.relationsUpdatedSubscribe(function() {
			var newGenMatrix = getGenMatrix.bind(this)();
			if(newGenMatrix == this.genMatrixCache) {
				return;
			} else if(newGenMatrix != null && this.genMatrixCache != null) {
				var different = false;
				for(var k in newGenMatrix) {
					if(newGenMatrix[k] != this.genMatrixCache[k]) {
						different = true;
						break;
					}
				}
				if(!different) {
					return;
				}
			}
			this.genMatrixCache = newGenMatrix;
			refreshRelations.bind(this)();
			this.contentUpdatedCallback.notify();
		}.bind(this))
		this.genMatrixCache = getGenMatrix.bind(this)();
		refreshRelations.bind(this)();
	}

	getLayers() {
		var tileShape = tileroninX.getTileShape();
		if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
			return getLayersOrthographic.bind(this)();
		} else if(tileShape == tileroninX.Shape.ISOMETRIC) {
			return getLayersIsometric.bind(this)();
		}
	}

	getComponents() { //TODO
		var components = [];

		var genMatrix = this.genMatrixCache;
		if(genMatrix == null || this.pre2_0_0) {
			return components;
		}

		var uniqueTiles = [];
		var tileBase = genMatrix[0];
	    for(var k = 1; k < genMatrix.length; k++) {
	    	var gTile = genMatrix[k];
	    	if(gTile == null || gTile == tileBase) {
	    		continue;
	    	}
	    	var bcIdx = uniqueTiles.indexOf(gTile);
	    	if(bcIdx == -1) {
	    		uniqueTiles.push(gTile);
	    	}
	    }
	    for(var k in uniqueTiles) {
	    	var ut = uniqueTiles[k];
	    	var bset = tileBase.getRelation(ut).getBorderSet();
	    	for(var r = 0; r < 4; r++) {
    			//full version logic
    			if(	genMatrix[1+(1+r*2)%8]==ut
    			&&	genMatrix[1+(3+r*2)%8]!=ut
    			&&	genMatrix[1+(7+r*2)%8]!=ut) {
    				components.push({bset:bset, r:r, t:0});
    			}
    			if(	genMatrix[1+(1+r*2)%8]==ut
    			&&	genMatrix[1+(7+r*2)%8]==ut) {
    				components.push({bset:bset, r:r, t:1});
    			}
    			if(	genMatrix[1+(0+r*2)%8]==ut
    			&&	genMatrix[1+(1+r*2)%8]==tileBase
    			&&	genMatrix[1+(7+r*2)%8]==tileBase) {
    				components.push({bset:bset, r:r, t:2});
    			}
    		}
	    }
		return components;
	}
}
module.exports = BorderGeneratorBlob;