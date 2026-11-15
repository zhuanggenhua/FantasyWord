var BorderGenerator = require('./BorderGenerator.js');

var TileRelationWangBorder = require('./TileRelationWangBorder.js');
var TileRelationWangPre2_0_0 = require('./TileRelationWangPre2_0_0.js');

var {nativeImage} = require('electron');
var path = require('path');

var getGenMatrix = function() {
	this.pre2_0_0 = false;
	var genMatrix = null;
	var tRel = this.tile.getRelations();
	for(var k in tRel) {
		if(tRel[k].r instanceof TileRelationWangBorder && tRel[k].r.isBorder) {
			genMatrix = tRel[k].r.getIndexMatrix();
			break;
		}
		if(tRel[k].r instanceof TileRelationWangPre2_0_0) {
			genMatrix = tRel[k].r.getIndexMatrix();
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
	for(var i = 0; i < genMatrix.length; i++) {
		if(genMatrix[i] != false && this.imageTiles.indexOf(genMatrix[i]) == -1) {
			var tileCallbackFunc = function() {
				this.contentUpdatedCallback.notify();
			}.bind(this)
			var cbi = genMatrix[i].contentUpdatedSubscribe(tileCallbackFunc);
			this.imageTiles.push(genMatrix[i]);
			this.imageTileCallbacks.push(cbi);
		}
		for(var j = i+1; j < genMatrix.length; j++) {
			if(genMatrix[i] == genMatrix[j]) {
				continue;
			}
			var bset;
			if(genMatrix[i] == false) {
				bset = genMatrix[j].getRelation(genMatrix[i]).getBorderSet();
			} else {
				bset = genMatrix[i].getRelation(genMatrix[j]).getBorderSet();
			}
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
}

var getLayersOrthographic = function() {
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

    function clipBorderBase(bset=null, origin=false) {
    	var top = 0;
    	var right = 0;
    	var bottom = 0;
    	var left = 0;
    	if(bset != null) {
    		top = bset.borderSources[0]['cutoff'];
    		right = bset.borderSources[1]['cutoff'];
    		bottom = bset.borderSources[2]['cutoff'];
    		left = bset.borderSources[3]['cutoff'];
    	}
    	if(origin) {
    		var aux = bottom;
    		bottom = top*-1;
    		top = aux*-1;
    		aux = left;
    		left = right*-1;
    		right = aux*-1;
    	}
    	var clip_up = [ // [-`] ////
	    	[0, tileSize/2+bottom],
	    	[tileSize, tileSize/2+bottom],
	    	[tileSize, 0],
	    	[0, 0]
	    ];
		    var clip_right = [ // [|:] ////
	    	[tileSize/2-left, 0],
	    	[tileSize/2-left, tileSize],
	    	[tileSize, tileSize],
	    	[tileSize, 0]
	    ];
	    var clip_down = [ // [.-] ////
	    	[0, tileSize/2-top],
	    	[tileSize, tileSize/2-top],
	    	[tileSize, tileSize],
	    	[0, tileSize]
	    ];
	    var clip_left = [ // [:|] ////
	    	[tileSize/2+right, 0],
	    	[tileSize/2+right, tileSize],
	    	[0, tileSize],
	    	[0, 0]
	    ];
	    return [clip_up, clip_right, clip_down, clip_left];
    }

    function clipBorderDiag(bseth=null, originh=false, bsetv=null, originv=false) {
    	var tl = 0;
    	var tr = 0;
    	var br = 0;
    	var bl = 0;
    	if(bseth != null && bsetv != null) {
    		var top = bsetv.borderSources[0]['cutoff'];
    		var right = bseth.borderSources[1]['cutoff'];
    		var bottom = bsetv.borderSources[2]['cutoff'];
    		var left = bseth.borderSources[3]['cutoff'];
    		if(!originh) {
    			var aux = left;
	    		left = right*-1;
	    		right = aux*-1;
    		}
    		if(!originv) {
    			var aux = bottom;
	    		bottom = top*-1;
	    		top = aux*-1;
    		}
    		tl = -top+right;
    		tr = bottom-right;
    		br = -bottom+left;
    		bl = top-left;
    	}

    	var clip_upLeft = [ // [`/]
	    ];
	    for(var ci = 0; ci <= tileSize-Math.abs(tl); ci++) {
	    	clip_upLeft.push([ci+Math.max(0, tl), tileSize-ci+Math.min(0, tl)]);
	    	clip_upLeft.push([ci+1+Math.max(0, tl), tileSize-ci+Math.min(0, tl)]);
	    }
	    if(tl > 0) { clip_upLeft.push([tileSize, 0]); }
	    clip_upLeft.push([0, 0]);
	    if(tl > 0) { clip_upLeft.push([0, tileSize]); }

	    var clip_upRight = [ // [\`]
	    ];
	    for(var ci = 0; ci <= tileSize-Math.abs(tr); ci++) {
	    	clip_upRight.push([ci-Math.min(0, tr), ci+Math.max(0, tr)]);
	    	clip_upRight.push([ci+1-Math.min(0, tr), ci+Math.max(0, tr)]);
	    }
	    if(tr > 0) { clip_upRight.push([tileSize, tileSize]); }
	    clip_upRight.push([tileSize, 0]);
	    if(tr > 0) { clip_upRight.push([0, 0]); }

	    var clip_downRight = [ // [/.]
	    ];
	    for(var ci = 0; ci <= tileSize-Math.abs(br); ci++) {
	    	clip_downRight.push([ci-Math.min(0, br), tileSize-ci-Math.max(0, br)]);
	    	clip_downRight.push([ci+1-Math.min(0, br), tileSize-ci-Math.max(0, br)]);
	    }
	    if(br > 0) { clip_downRight.push([tileSize, 0]); }
	    clip_downRight.push([tileSize, tileSize]);
	    if(br > 0) { clip_downRight.push([0, tileSize]); }

	    var clip_downLeft = [ // [.\]
	    ];
	    for(var ci = 0; ci <= tileSize-Math.abs(bl); ci++) {
	    	clip_downLeft.push([ci+Math.max(0, bl), ci-Math.min(0, bl)]);
	    	clip_downLeft.push([ci+1+Math.max(0, bl), ci-Math.min(0, bl)]);
	    }
	    if(bl > 0) { clip_downLeft.push([tileSize, tileSize]); }
	    clip_downLeft.push([0, tileSize]);
	    if(bl > 0) { clip_downLeft.push([0, 0]); }

	    return [clip_upRight, clip_downRight, clip_downLeft, clip_upLeft];
    }

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
		        	ctxDrawRotateFlip(ctx, image, bset.getRotation(i)*90, bset.getFlipX(i), bset.getFlipY(i));
		            resolve(canvas);
		        }.bind(this));
				bset.getSource(i).getImage().then(function(img) {
		        	image.src = img.toDataURL();
		        });
	        }.bind(this)));

	        bset.layersCache[i] = layers;
		}
        return bset.layersCache[i];
    }

    function drawBorderOuter(i, bset, origin) {
    	if(bset.layersCache[i+4] == null) {
	    	var layers = [];

	    	if(bset.getComposite(i+4)) {
	    		var canvas0 = document.createElement('canvas');
			    canvas0.width  = tileSize;
			    canvas0.height = tileSize;
			    var ctx0 = canvas0.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxClip(ctx0, clipBorderDiag(bset, origin, bset, origin)[i]);
			        	ctxDrawRotateFlip(ctx0, image, bset.getRotation(i)*90, bset.getFlipX(i), bset.getFlipY(i));
			            resolve(canvas0);
			        }.bind(this));
					bset.getSource(i).getImage().then(function(img) {
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
			        	ctxClip(ctx1, clipBorderDiag(bset, !origin, bset, !origin)[(i+2)%4]);
			        	ctxDrawRotateFlip(ctx1, image, bset.getRotation((i+3)%4)*90, bset.getFlipX((i+3)%4), bset.getFlipY((i+3)%4));
			            resolve(canvas1);
			        }.bind(this));
					bset.getSource((i+3)%4).getImage().then(function(img) {
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
			        	ctxDrawRotateFlip(ctx0, image, bset.getRotation(i+4)*90, bset.getFlipX(i+4), bset.getFlipY(i+4));
			            resolve(canvas0);
			        }.bind(this));
					bset.getSource(i+4).getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
		        }.bind(this)));
	    	}

	    	bset.layersCache[i+4] = layers;
	    }
    	return bset.layersCache[i+4];
    }

    function drawBorderInner(i, bset, origin) {
    	if(bset.layersCache[i+8] == null) {
	    	var layers = [];

	    	if(bset.getComposite(i+8)) {
	    		var canvas0 = document.createElement('canvas');
			    canvas0.width  = tileSize;
			    canvas0.height = tileSize;
			    var ctx0 = canvas0.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxClip(ctx0, clipBorderDiag(bset, !origin, bset, !origin)[(i+2)%4]);
			        	ctxDrawRotateFlip(ctx0, image, bset.getRotation(i)*90, bset.getFlipX(i), bset.getFlipY(i));
			            resolve(canvas0);
			        }.bind(this));
					bset.getSource(i).getImage().then(function(img) {
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
			        	ctxClip(ctx1, clipBorderDiag(bset, origin, bset, origin)[i]);
			        	ctxDrawRotateFlip(ctx1, image, bset.getRotation((i+3)%4)*90, bset.getFlipX((i+3)%4), bset.getFlipY((i+3)%4));
			            resolve(canvas1);
			        }.bind(this));
					bset.getSource((i+3)%4).getImage().then(function(img) {
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
			        	ctxDrawRotateFlip(ctx0, image, bset.getRotation(i+8)*90, bset.getFlipX(i+8), bset.getFlipY(i+8));
			            resolve(canvas0);
			        }.bind(this));
					bset.getSource(i+8).getImage().then(function(img) {
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

    var layers = [];

    var genMatrix = this.genMatrixCache;
	if(genMatrix == null) {
	    layers.push(BorderGenerator.missingImage);
	} else {
	    //base layers
	    //base layers
	    //base layers
	    var uniqueTiles = [];
	    var baseCanvases = [];
	    for(var k in genMatrix) {
	    	var gTile = genMatrix[k];
	    	var bcIdx = uniqueTiles.indexOf(gTile);
	    	if(bcIdx == -1) {
	    		uniqueTiles.push(gTile);
	    		if(gTile != false) {
	    			var bCanvas = document.createElement('canvas');
				    bCanvas.width  = tileSize;
				    bCanvas.height = tileSize;
				    baseCanvases[uniqueTiles.length-1] = bCanvas;
	    		}
	    	}
	    }

	    var p = Promise.resolve();

	    for(var i = 0; i < genMatrix.length; i++) {
	    	if(genMatrix[i] == false) {
	    		continue;
	    	}
	    	(function(i) {
				p = p.then(function() {
			    	return new Promise(function(resolve, reject) {
			        	var gTile = genMatrix[i];
		        		gTile.getImage().then(function(img) { //TODO: gTile.getImage()??
				        	var cIdx = uniqueTiles.indexOf(gTile);
				        	var ctx = baseCanvases[cIdx].getContext('2d');
				        	ctx.save();
				        	if(gTile != genMatrix[(i+1)%4]) {
				        		var rel = gTile.getRelation(genMatrix[(i+1)%4]);
				        		if(rel != null) {
				        			ctxClip(ctx, clipBorderBase(rel.getBorderSet(), rel.origin==gTile)[(i+3)%4]);
				        		}
				        	} else if(genMatrix[(i+2)%4] != genMatrix[(i+3)%4]) {
				        		var rTile = genMatrix[(i+2)%4];
				        		var r2Tile = genMatrix[(i+3)%4];
				        		if(rTile == false) {
				        			rTile = genMatrix[(i+3)%4];
				        			r2Tile = genMatrix[(i+2)%4];
				        		}
				        		var rel = rTile.getRelation(r2Tile);
				        		if(rel != null) {
				        			ctxClip(ctx, clipBorderBase(rel.getBorderSet(), rel.origin==genMatrix[(i+3)%4])[(i+3)%4]);
				        		}
				        	} else {
				        		//clipBorderBase((i+3)%4, ctx);
				        		ctxClip(ctx, clipBorderBase()[(i+3)%4]);
				        	}
				        	if(gTile != genMatrix[(i+3)%4]) {
				        		var rel = gTile.getRelation(genMatrix[(i+3)%4]);
				        		if(rel != null) {
				        			ctxClip(ctx, clipBorderBase(rel.getBorderSet(), rel.origin==gTile)[i]);
				        		}
				        	} else if(genMatrix[(i+2)%4] != genMatrix[(i+1)%4]) {
				        		var rTile = genMatrix[(i+2)%4];
				        		var r2Tile = genMatrix[(i+1)%4];
				        		if(rTile == false) {
				        			rTile = genMatrix[(i+1)%4];
				        			r2Tile = genMatrix[(i+2)%4];
				        		}
				        		var rel = rTile.getRelation(r2Tile);
				        		if(rel != null) {
				        			ctxClip(ctx, clipBorderBase(rel.getBorderSet(), rel.origin==genMatrix[(i+1)%4])[i]);
				        		}
				        	} else {
				        		//clipBorderBase(i, ctx, null);
				        		ctxClip(ctx, clipBorderBase()[i]);
				        	}
				            ctx.drawImage(img, 0, 0);
				            ctx.restore();
				            resolve();
				        });
				    }.bind(this));
			    }.bind(this));
	    	}).bind(this)(i);
	    }

	    for(var k in baseCanvases) {
	    	if(baseCanvases[k] == null) {
	    		continue;
	    	}
	    	(function(k) {
	    		var canvas = baseCanvases[k];
		    	layers.push(p.then(function() {
			    	return new Promise(function(resolve, reject) {
			            resolve(canvas);
				    });
			    }));
	    	}).bind(this)(k);
	    }

	    //overlay layers
	    //overlay layers
	    //overlay layers
	    var canvasLayers = [];
	    for(var t0 = 0; t0 < uniqueTiles.length; t0++) {
	    	for(var t1 = t0+1; t1 < uniqueTiles.length; t1++) {
	    		var tA = uniqueTiles[t0];
	    		var tB = uniqueTiles[t1];
	    		if(tA == false) {
	    			tA = uniqueTiles[t1];
	    			tB = uniqueTiles[t0];
	    		}
	    		var rel = tA.getRelation(tB);
	    		if(rel.origin == tB) {
	    			tA = uniqueTiles[t1];
	    			tB = uniqueTiles[t0];
	    		}
	    		var bset = rel.getBorderSet();
	    		//for each unique pair
	    		for(var r = 0; r < 4; r++) {
	    			//for all 4 directions
	    			//full version logic
	    			if(	genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tA 
	    			&& 	genMatrix[(2+r)%4]==tB 
	    			&& 	genMatrix[(3+r)%4]==tB) {
	    				var layersB = drawBorder.bind(this)(r, bset);
	    				var layersFinal = [];
	    				for(var lb in layersB) {
	    					layersFinal.push([layersB[lb], []]);
	    				}
	    				canvasLayers = canvasLayers.concat(layersFinal);
	    			}
	    			if(	genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tA 
	    			&& 	genMatrix[(2+r)%4]==tB 
	    			&& 	genMatrix[(3+r)%4]==tA) {
	    				var layersB = drawBorderOuter.bind(this)(r, bset, rel.origin==tB);
	    				var layersFinal = [];
	    				for(var lb in layersB) {
	    					layersFinal.push([layersB[lb], []]);
	    				}
	    				canvasLayers = canvasLayers.concat(layersFinal);
	    			}
	    			if(	genMatrix[(0+r)%4]!=tA && genMatrix[(0+r)%4]!=tB
	    			&& 	genMatrix[(1+r)%4]==tA 
	    			&& 	genMatrix[(2+r)%4]==tB 
	    			&& 	genMatrix[(3+r)%4]==tA) {
	    				var layersB = drawBorderOuter.bind(this)(r, bset, rel.origin==tB);
	    				var layersFinal = [];
	    				for(var lb in layersB) {
	    					var clips = [];
	    					var xRel = tA.getRelation(tB);
	    					if(r == 0 || r == 2) {
	    						clips.push(clipBorderDiag(xRel.getBorderSet(), xRel.origin!=tB, xRel.getBorderSet(), xRel.origin==tB)[(r+1)%4])
	    					} else if(r == 1 || r == 3) {
	    						clips.push(clipBorderDiag(xRel.getBorderSet(), xRel.origin==tB, xRel.getBorderSet(), xRel.origin!=tB)[(r+1)%4])
	    					}
	    					layersFinal.push([layersB[lb], clips]);
	    				}
	    				canvasLayers = canvasLayers.concat(layersFinal);
	    			}
	    			if(	genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tB 
	    			&& 	genMatrix[(2+r)%4]==tB 
	    			&& 	genMatrix[(3+r)%4]==tB) {
	    				var layersB = drawBorderInner.bind(this)(r, bset, rel.origin==tB);
	    				var layersFinal = [];
	    				for(var lb in layersB) {
	    					layersFinal.push([layersB[lb], []]);
	    				}
	    				canvasLayers = canvasLayers.concat(layersFinal);
	    			}
	    			if(	genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tB 
	    			&& 	genMatrix[(2+r)%4]!=tB 
	    			&& 	genMatrix[(3+r)%4]==tB) {
	    				var layersB = drawBorderInner.bind(this)(r, bset, rel.origin==tB);
	    				var layersFinal = [];
	    				for(var lb in layersB) {
	    					var clips = [];
	    					if(genMatrix[(2+r)%4] != tA) {
	    						var xrel;
	    						if(tB == false) {
	    							xRel = genMatrix[(2+r)%4].getRelation(tB);
	    						} else {
	    							xRel = tB.getRelation(genMatrix[(2+r)%4]);
	    						}
	    						if(r == 0 || r == 2) {
		    						clips.push(clipBorderDiag(xRel.getBorderSet(), xRel.origin!=tB, xRel.getBorderSet(), xRel.origin==tB)[(r+3)%4])
		    					} else if(r == 1 || r == 3) {
		    						clips.push(clipBorderDiag(xRel.getBorderSet(), xRel.origin==tB, xRel.getBorderSet(), xRel.origin!=tB)[(r+3)%4])
		    					}
	    					} else {
	    						clips.push(clipBorderDiag()[(r+3)%4])
	    					}
	    					layersFinal.push([layersB[lb], clips]);
	    				}
	    				canvasLayers = canvasLayers.concat(layersFinal);
	    			}
	    			if(	genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]!=tA && genMatrix[(1+r)%4]!=tB 
	    			&& 	genMatrix[(2+r)%4]!=tA 
	    			&& 	genMatrix[(3+r)%4]==tB
	    			||
	    				genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tA
	    			&& 	genMatrix[(2+r)%4]!=tA && genMatrix[(2+r)%4]!=tB 
	    			&& 	genMatrix[(3+r)%4]==tB) {
	    				var layersB = drawBorder.bind(this)(r, bset);
	    				var layersFinal = [];
	    				for(var lb in layersB) {
	    					//layersFinal.push([layersB[lb], [clips[(r+3)%4]]]);
	    					var xTile = genMatrix[(1+r)%4];
	    					var yTile = tA;
	    					var clips = [];
	    					if(xTile == tA) {
	    						xTile = genMatrix[(2+r)%4];
	    						yTile = tB;
	    					} else {
	    						var xRel = tA.getRelation(xTile);
	    						if(r == 0 || r == 2) {
	    							clips.push(clipBorderDiag(xRel.getBorderSet(), xRel.origin==tA, bset, rel.origin==tA)[(r+2)%4]);
	    						} else if(r == 1 || r == 3) {
	    							clips.push(clipBorderDiag(bset, rel.origin==tA, xRel.getBorderSet(), xRel.origin==tA)[(r+2)%4]);
	    						}
	    					}
	    					var xyrel;
	    					if(xTile == false) {
	    						xyrel = yTile.getRelation(xTile);
				    		} else {
				    			xyrel = xTile.getRelation(yTile);
				    		}
    						clips.push(clipBorderBase(xyrel.getBorderSet(), xyrel.origin==yTile)[(r+3)%4]);
	    					layersFinal.push([layersB[lb], clips]);
	    				}
	    				canvasLayers = canvasLayers.concat(layersFinal);
	    			}
	    			if(	genMatrix[(0+r)%4]!=tA && genMatrix[(0+r)%4]!=tB 
	    			&& 	genMatrix[(1+r)%4]==tA
	    			&& 	genMatrix[(2+r)%4]==tB 
	    			&& 	genMatrix[(3+r)%4]!=tA
	    			||
	    				genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tA
	    			&& 	genMatrix[(2+r)%4]==tB
	    			&& 	genMatrix[(3+r)%4]!=tA && genMatrix[(3+r)%4]!=tB) {
	    				var layersB = drawBorder.bind(this)(r, bset);
	    				var layersFinal = [];
	    				for(var lb in layersB) {
	    					//layersFinal.push([layersB[lb], [clips[(r+1)%4]]]);
	    					var xTile = genMatrix[(0+r)%4];
	    					var yTile = tA;
	    					var clips = [];
	    					if(xTile == tA) {
	    						xTile = genMatrix[(3+r)%4];
	    						yTile = tB;
	    					} else {
	    						var xRel = tA.getRelation(xTile);
	    						if(r == 0 || r == 2) {
	    							clips.push(clipBorderDiag(xRel.getBorderSet(), xRel.origin!=tA, bset, rel.origin!=tA)[(r+1)%4]);
	    						} else if(r == 1 || r == 3) {
	    							clips.push(clipBorderDiag(bset, rel.origin!=tA, xRel.getBorderSet(), xRel.origin!=tA)[(r+1)%4]);
	    						}
	    					}
	    					var xyrel;
	    					if(xTile == false) {
	    						xyrel = yTile.getRelation(xTile);
				    		} else {
				    			xyrel = xTile.getRelation(yTile);
				    		}
    						clips.push(clipBorderBase(xyrel.getBorderSet(), xyrel.origin==yTile)[(r+1)%4]);
	    					layersFinal.push([layersB[lb], clips]);
	    				}
	    				canvasLayers = canvasLayers.concat(layersFinal);
	    			}
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

    function clipBorderBase(bset=null, origin=false) {
    	var top = 0;
    	var right = 0;
    	var bottom = 0;
    	var left = 0;
    	if(bset != null) {
    		top = bset.borderSources[0]['cutoff'];
    		right = bset.borderSources[1]['cutoff'];
    		bottom = bset.borderSources[2]['cutoff'];
    		left = bset.borderSources[3]['cutoff'];
    	}
    	if(origin) {
    		var aux = bottom;
    		bottom = top*-1;
    		top = aux*-1;
    		aux = left;
    		left = right*-1;
    		right = aux*-1;
    	}
    	var mid = tileSize[0]/2;
    	var step = tileSize[0]/tileSize[1];

    	var m_u = Math.floor((tileSize[0]+step)/2)+bottom;
    	var m_r = Math.floor((tileSize[0]+step)/2)-left;
    	var m_d = Math.floor((tileSize[0]+step)/2)-top;
    	var m_l = Math.floor((tileSize[0]+step)/2)+right;
    	
    	var clip_up = [];
    	for(var k = 0; k < tileSize[1]; k++) {
    		clip_up.push([mid+(k+1)*step-m_u, k]);
    		clip_up.push([mid+(k+1)*step-m_u, k+1]);
    	}
    	clip_up.push([tileSize[0], tileSize[1]]);
    	clip_up.push([tileSize[0], 0]);

    	var clip_right = [];
    	for(var k = 0; k < tileSize[1]; k++) {
    		clip_right.push([mid-(k+1)*step+m_r, k]);
    		clip_right.push([mid-(k+1)*step+m_r, k+1]);
    	}
    	clip_right.push([tileSize[0], tileSize[1]]);
    	clip_right.push([tileSize[0], 0]);

    	var clip_down = [];
    	for(var k = 0; k < tileSize[1]; k++) {
    		clip_down.push([mid+(k+1)*step-m_d, k]);
    		clip_down.push([mid+(k+1)*step-m_d, k+1]);
    	}
    	clip_down.push([0, tileSize[1]]);
    	clip_down.push([0, 0]);

    	var clip_left = [];
    	for(var k = 0; k < tileSize[1]; k++) {
    		clip_left.push([mid-(k+1)*step+m_l, k]);
    		clip_left.push([mid-(k+1)*step+m_l, k+1]);
    	}
    	clip_left.push([0, tileSize[1]]);
    	clip_left.push([0, 0]);

	    return [clip_up, clip_right, clip_down, clip_left];
    }

    function clipBorderDiag(bseth=null, originh=false, bsetv=null, originv=false) {
    	var tl = 0;
    	var tr = 0;
    	var br = 0;
    	var bl = 0;
    	if(bseth != null && bsetv != null) {
    		var top = bsetv.borderSources[0]['cutoff'];
    		var right = bseth.borderSources[1]['cutoff'];
    		var bottom = bsetv.borderSources[2]['cutoff'];
    		var left = bseth.borderSources[3]['cutoff'];
    		if(!originh) {
    			var aux = left;
	    		left = right*-1;
	    		right = aux*-1;
    		}
    		if(!originv) {
    			var aux = bottom;
	    		bottom = top*-1;
	    		top = aux*-1;
    		}
	    	var step = tileSize[0]/tileSize[1];

	    	var m_u = Math.floor((tileSize[0]+step)/2)+bottom;
	    	var m_r = Math.floor((tileSize[0]+step)/2)-left;
	    	var m_d = Math.floor((tileSize[0]+step)/2)-top;
	    	var m_l = Math.floor((tileSize[0]+step)/2)+right;

    		tl = Math.floor((m_l+m_d-tileSize[0])/(2*step));
    		tr = Math.floor((m_l-m_u)/2);
    		br = Math.floor((m_r+m_u-tileSize[0])/(2*step));
    		bl = Math.floor((m_r-m_d)/2);
    	}

    	var m_tl = tileSize[1]/2+tl;
    	var m_tr = tileSize[0]/2+tr;
    	var m_br = tileSize[1]/2+br;
    	var m_bl = tileSize[0]/2+bl;

    	var clip_upLeft = [ // [`/]
	    	[0, 0],
	    	[tileSize[0], 0],
	    	[tileSize[0], m_tl],
	    	[0, m_tl]
	    ];
	    var clip_upRight = [ // [\`]
	    	[m_tr, 0],
	    	[tileSize[0], 0],
	    	[tileSize[0], tileSize[1]],
	    	[m_tr, tileSize[1]]
	    ];
	    var clip_downRight = [ // [/.]
	    	[0, m_br],
	    	[tileSize[0], m_br],
	    	[tileSize[0], tileSize[1]],
	    	[0, tileSize[1]]
	    ];
	    var clip_downLeft = [ // [.\]
	    	[0, 0],
	    	[m_bl, 0],
	    	[m_bl, tileSize[1]],
	    	[0, tileSize[1]]
	    ];

	    return [clip_upRight, clip_downRight, clip_downLeft, clip_upLeft];
    }

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
		        	ctxDrawRotateFlip(ctx, image, bset.getRotation(i)*90, bset.getFlipX(i), bset.getFlipY(i));
		            resolve(canvas);
		        }.bind(this));
				bset.getSource(i).getImage().then(function(img) {
		        	image.src = img.toDataURL();
		        });
	        }.bind(this)));

	        bset.layersCache[i] = layers;
		}
        return bset.layersCache[i];
    }

    function drawBorderOuter(i, bset, origin) {
    	if(bset.layersCache[i+4] == null) {
	    	var layers = [];

	    	if(bset.getComposite(i+4)) {
	    		var canvas0 = document.createElement('canvas');
			    canvas0.width  = tileSize[0];
			    canvas0.height = tileSize[1];
			    var ctx0 = canvas0.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxClip(ctx0, clipBorderDiag(bset, origin, bset, origin)[i]);
			        	ctxDrawRotateFlip(ctx0, image, bset.getRotation(i)*90, bset.getFlipX(i), bset.getFlipY(i));
			            resolve(canvas0);
			        }.bind(this));
					bset.getSource(i).getImage().then(function(img) {
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
			        	ctxClip(ctx1, clipBorderDiag(bset, !origin, bset, !origin)[(i+2)%4]);
			        	ctxDrawRotateFlip(ctx1, image, bset.getRotation((i+3)%4)*90, bset.getFlipX((i+3)%4), bset.getFlipY((i+3)%4));
			            resolve(canvas1);
			        }.bind(this));
					bset.getSource((i+3)%4).getImage().then(function(img) {
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
			        	ctxDrawRotateFlip(ctx0, image, bset.getRotation(i+4)*90, bset.getFlipX(i+4), bset.getFlipY(i+4));
			            resolve(canvas0);
			        }.bind(this));
					bset.getSource(i+4).getImage().then(function(img) {
			        	image.src = img.toDataURL();
			        });
		        }.bind(this)));
	    	}

	    	bset.layersCache[i+4] = layers;
	    }
    	return bset.layersCache[i+4];
    }

    function drawBorderInner(i, bset, origin) {
    	if(bset.layersCache[i+8] == null) {
	    	var layers = [];

	    	if(bset.getComposite(i+8)) {
	    		var canvas0 = document.createElement('canvas');
			    canvas0.width  = tileSize[0];
			    canvas0.height = tileSize[1];
			    var ctx0 = canvas0.getContext('2d');

			    layers.push(new Promise(function(resolve, reject) {
					var image = new Image();
			        image.addEventListener('load', function() {
			        	ctxClip(ctx0, clipBorderDiag(bset, !origin, bset, !origin)[(i+2)%4]);
			        	ctxDrawRotateFlip(ctx0, image, bset.getRotation(i)*90, bset.getFlipX(i), bset.getFlipY(i));
			            resolve(canvas0);
			        }.bind(this));
					bset.getSource(i).getImage().then(function(img) {
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
			        	ctxClip(ctx1, clipBorderDiag(bset, origin, bset, origin)[i]);
			        	ctxDrawRotateFlip(ctx1, image, bset.getRotation((i+3)%4)*90, bset.getFlipX((i+3)%4), bset.getFlipY((i+3)%4));
			            resolve(canvas1);
			        }.bind(this));
					bset.getSource((i+3)%4).getImage().then(function(img) {
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
			        	ctxDrawRotateFlip(ctx0, image, bset.getRotation(i+8)*90, bset.getFlipX(i+8), bset.getFlipY(i+8));
			            resolve(canvas0);
			        }.bind(this));
					bset.getSource(i+8).getImage().then(function(img) {
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

    var layers = [];

    var genMatrix = this.genMatrixCache;
	if(genMatrix == null) {
	    layers.push(BorderGenerator.missingImage);
	} else {
	    //base layers
	    //base layers
	    //base layers
	    var uniqueTiles = [];
	    var baseCanvases = [];
	    for(var k in genMatrix) {
	    	var gTile = genMatrix[k];
	    	var bcIdx = uniqueTiles.indexOf(gTile);
	    	if(bcIdx == -1) {
	    		uniqueTiles.push(gTile);
	    		if(gTile != false) {
	    			var bCanvas = document.createElement('canvas');
				    bCanvas.width  = tileSize[0];
				    bCanvas.height = tileSize[1];
				    baseCanvases[uniqueTiles.length-1] = bCanvas;
	    		}
	    	}
	    }

	    var p = Promise.resolve();

	    for(var i = 0; i < genMatrix.length; i++) {
	    	if(genMatrix[i] == false) {
	    		continue;
	    	}
	    	(function(i) {
				p = p.then(function() {
			    	return new Promise(function(resolve, reject) {
			        	var gTile = genMatrix[i];
		        		gTile.getImage().then(function(img) { //TODO: gTile.getImage()??
				        	var cIdx = uniqueTiles.indexOf(gTile);
				        	var ctx = baseCanvases[cIdx].getContext('2d');
				        	ctx.save();
				        	if(gTile != genMatrix[(i+1)%4]) {
				        		var rel = gTile.getRelation(genMatrix[(i+1)%4]);
				        		if(rel != null) {
				        			ctxClip(ctx, clipBorderBase(rel.getBorderSet(), rel.origin==gTile)[(i+3)%4]);
				        		}
				        	} else if(genMatrix[(i+2)%4] != genMatrix[(i+3)%4]) {
				        		var rTile = genMatrix[(i+2)%4];
				        		var r2Tile = genMatrix[(i+3)%4];
				        		if(rTile == false) {
				        			rTile = genMatrix[(i+3)%4];
				        			r2Tile = genMatrix[(i+2)%4];
				        		}
				        		var rel = rTile.getRelation(r2Tile);
				        		if(rel != null) {
				        			ctxClip(ctx, clipBorderBase(rel.getBorderSet(), rel.origin==genMatrix[(i+3)%4])[(i+3)%4]);
				        		}
				        	} else {
				        		//clipBorderBase((i+3)%4, ctx);
				        		ctxClip(ctx, clipBorderBase()[(i+3)%4]);
				        	}
				        	if(gTile != genMatrix[(i+3)%4]) {
				        		var rel = gTile.getRelation(genMatrix[(i+3)%4]);
				        		if(rel != null) {
				        			ctxClip(ctx, clipBorderBase(rel.getBorderSet(), rel.origin==gTile)[i]);
				        		}
				        	} else if(genMatrix[(i+2)%4] != genMatrix[(i+1)%4]) {
				        		var rTile = genMatrix[(i+2)%4];
				        		var r2Tile = genMatrix[(i+1)%4];
				        		if(rTile == false) {
				        			rTile = genMatrix[(i+1)%4];
				        			r2Tile = genMatrix[(i+2)%4];
				        		}
				        		var rel = rTile.getRelation(r2Tile);
				        		if(rel != null) {
				        			ctxClip(ctx, clipBorderBase(rel.getBorderSet(), rel.origin==genMatrix[(i+1)%4])[i]);
				        		}
				        	} else {
				        		//clipBorderBase(i, ctx, null);
				        		ctxClip(ctx, clipBorderBase()[i]);
				        	}
				            ctx.drawImage(img, 0, 0);
				            ctx.restore();
				            resolve();
				        });
				    }.bind(this));
			    }.bind(this));
	    	}).bind(this)(i);
	    }

	    for(var k in baseCanvases) {
	    	if(baseCanvases[k] == null) {
	    		continue;
	    	}
	    	(function(k) {
	    		var canvas = baseCanvases[k];
		    	layers.push(p.then(function() {
			    	return new Promise(function(resolve, reject) {
			            resolve(canvas);
				    });
			    }));
	    	}).bind(this)(k);
	    }

	    //overlay layers
	    //overlay layers
	    //overlay layers
	    var canvasLayers = [];
	    for(var t0 = 0; t0 < uniqueTiles.length; t0++) {
	    	for(var t1 = t0+1; t1 < uniqueTiles.length; t1++) {
	    		var tA = uniqueTiles[t0];
	    		var tB = uniqueTiles[t1];
	    		if(tA == false) {
	    			tA = uniqueTiles[t1];
	    			tB = uniqueTiles[t0];
	    		}
	    		var rel = tA.getRelation(tB);
	    		if(rel.origin == tB) {
	    			tA = uniqueTiles[t1];
	    			tB = uniqueTiles[t0];
	    		}
	    		var bset = rel.getBorderSet();
	    		//for each unique pair
	    		for(var r = 0; r < 4; r++) {
	    			//for all 4 directions
	    			//full version logic
	    			if(	genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tA 
	    			&& 	genMatrix[(2+r)%4]==tB 
	    			&& 	genMatrix[(3+r)%4]==tB) {
	    				var layersB = drawBorder.bind(this)(r, bset);
	    				var layersFinal = [];
	    				for(var lb in layersB) {
	    					layersFinal.push([layersB[lb], []]);
	    				}
	    				canvasLayers = canvasLayers.concat(layersFinal);
	    			}
	    			if(	genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tA 
	    			&& 	genMatrix[(2+r)%4]==tB 
	    			&& 	genMatrix[(3+r)%4]==tA) {
	    				var layersB = drawBorderOuter.bind(this)(r, bset, rel.origin==tB);
	    				var layersFinal = [];
	    				for(var lb in layersB) {
	    					layersFinal.push([layersB[lb], []]);
	    				}
	    				canvasLayers = canvasLayers.concat(layersFinal);
	    			}
	    			if(	genMatrix[(0+r)%4]!=tA && genMatrix[(0+r)%4]!=tB
	    			&& 	genMatrix[(1+r)%4]==tA 
	    			&& 	genMatrix[(2+r)%4]==tB 
	    			&& 	genMatrix[(3+r)%4]==tA) {
	    				var layersB = drawBorderOuter.bind(this)(r, bset, rel.origin==tB);
	    				var layersFinal = [];
	    				for(var lb in layersB) {
	    					var clips = [];
	    					var xRel = tA.getRelation(tB);
	    					if(r == 0 || r == 2) {
	    						clips.push(clipBorderDiag(xRel.getBorderSet(), xRel.origin!=tB, xRel.getBorderSet(), xRel.origin==tB)[(r+1)%4])
	    					} else if(r == 1 || r == 3) {
	    						clips.push(clipBorderDiag(xRel.getBorderSet(), xRel.origin==tB, xRel.getBorderSet(), xRel.origin!=tB)[(r+1)%4])
	    					}
	    					layersFinal.push([layersB[lb], clips]);
	    				}
	    				canvasLayers = canvasLayers.concat(layersFinal);
	    			}
	    			if(	genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tB 
	    			&& 	genMatrix[(2+r)%4]==tB 
	    			&& 	genMatrix[(3+r)%4]==tB) {
	    				var layersB = drawBorderInner.bind(this)(r, bset, rel.origin==tB);
	    				var layersFinal = [];
	    				for(var lb in layersB) {
	    					layersFinal.push([layersB[lb], []]);
	    				}
	    				canvasLayers = canvasLayers.concat(layersFinal);
	    			}
	    			if(	genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tB 
	    			&& 	genMatrix[(2+r)%4]!=tB 
	    			&& 	genMatrix[(3+r)%4]==tB) {
	    				var layersB = drawBorderInner.bind(this)(r, bset, rel.origin==tB);
	    				var layersFinal = [];
	    				for(var lb in layersB) {
	    					var clips = [];
	    					if(genMatrix[(2+r)%4] != tA) {
	    						var xrel;
	    						if(tB == false) {
	    							xRel = genMatrix[(2+r)%4].getRelation(tB);
	    						} else {
	    							xRel = tB.getRelation(genMatrix[(2+r)%4]);
	    						}
	    						if(r == 0 || r == 2) {
		    						clips.push(clipBorderDiag(xRel.getBorderSet(), xRel.origin!=tB, xRel.getBorderSet(), xRel.origin==tB)[(r+3)%4])
		    					} else if(r == 1 || r == 3) {
		    						clips.push(clipBorderDiag(xRel.getBorderSet(), xRel.origin==tB, xRel.getBorderSet(), xRel.origin!=tB)[(r+3)%4])
		    					}
	    					} else {
	    						clips.push(clipBorderDiag()[(r+3)%4])
	    					}
	    					layersFinal.push([layersB[lb], clips]);
	    				}
	    				canvasLayers = canvasLayers.concat(layersFinal);
	    			}
	    			if(	genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]!=tA && genMatrix[(1+r)%4]!=tB 
	    			&& 	genMatrix[(2+r)%4]!=tA 
	    			&& 	genMatrix[(3+r)%4]==tB
	    			||
	    				genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tA
	    			&& 	genMatrix[(2+r)%4]!=tA && genMatrix[(2+r)%4]!=tB 
	    			&& 	genMatrix[(3+r)%4]==tB) {
	    				var layersB = drawBorder.bind(this)(r, bset);
	    				var layersFinal = [];
	    				for(var lb in layersB) {
	    					//layersFinal.push([layersB[lb], [clips[(r+3)%4]]]);
	    					var xTile = genMatrix[(1+r)%4];
	    					var yTile = tA;
	    					var clips = [];
	    					if(xTile == tA) {
	    						xTile = genMatrix[(2+r)%4];
	    						yTile = tB;
	    					} else {
	    						var xRel = tA.getRelation(xTile);
	    						if(r == 0 || r == 2) {
	    							clips.push(clipBorderDiag(xRel.getBorderSet(), xRel.origin==tA, bset, rel.origin==tA)[(r+2)%4]);
	    						} else if(r == 1 || r == 3) {
	    							clips.push(clipBorderDiag(bset, rel.origin==tA, xRel.getBorderSet(), xRel.origin==tA)[(r+2)%4]);
	    						}
	    					}
	    					var xyrel;
	    					if(xTile == false) {
	    						xyrel = yTile.getRelation(xTile);
				    		} else {
				    			xyrel = xTile.getRelation(yTile);
				    		}
    						clips.push(clipBorderBase(xyrel.getBorderSet(), xyrel.origin==yTile)[(r+3)%4]);
	    					layersFinal.push([layersB[lb], clips]);
	    				}
	    				canvasLayers = canvasLayers.concat(layersFinal);
	    			}
	    			if(	genMatrix[(0+r)%4]!=tA && genMatrix[(0+r)%4]!=tB 
	    			&& 	genMatrix[(1+r)%4]==tA
	    			&& 	genMatrix[(2+r)%4]==tB 
	    			&& 	genMatrix[(3+r)%4]!=tA
	    			||
	    				genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tA
	    			&& 	genMatrix[(2+r)%4]==tB
	    			&& 	genMatrix[(3+r)%4]!=tA && genMatrix[(3+r)%4]!=tB) {
	    				var layersB = drawBorder.bind(this)(r, bset);
	    				var layersFinal = [];
	    				for(var lb in layersB) {
	    					//layersFinal.push([layersB[lb], [clips[(r+1)%4]]]);
	    					var xTile = genMatrix[(0+r)%4];
	    					var yTile = tA;
	    					var clips = [];
	    					if(xTile == tA) {
	    						xTile = genMatrix[(3+r)%4];
	    						yTile = tB;
	    					} else {
	    						var xRel = tA.getRelation(xTile);
	    						if(r == 0 || r == 2) {
	    							clips.push(clipBorderDiag(xRel.getBorderSet(), xRel.origin!=tA, bset, rel.origin!=tA)[(r+1)%4]);
	    						} else if(r == 1 || r == 3) {
	    							clips.push(clipBorderDiag(bset, rel.origin!=tA, xRel.getBorderSet(), xRel.origin!=tA)[(r+1)%4]);
	    						}
	    					}
	    					var xyrel;
	    					if(xTile == false) {
	    						xyrel = yTile.getRelation(xTile);
				    		} else {
				    			xyrel = xTile.getRelation(yTile);
				    		}
    						clips.push(clipBorderBase(xyrel.getBorderSet(), xyrel.origin==yTile)[(r+1)%4]);
	    					layersFinal.push([layersB[lb], clips]);
	    				}
	    				canvasLayers = canvasLayers.concat(layersFinal);
	    			}
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

class BorderGeneratorWang extends BorderGenerator {
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

	getComponents() {
		var components = [];

		var genMatrix = this.genMatrixCache;
		if(genMatrix == null || this.pre2_0_0) {
			return components;
		}

		var uniqueTiles = [];
	    for(var k in genMatrix) {
	    	var gTile = genMatrix[k];
	    	if(uniqueTiles.indexOf(gTile) == -1) {
	    		uniqueTiles.push(gTile);
	    	}
	    }
	    for(var t0 = 0; t0 < uniqueTiles.length; t0++) {
	    	for(var t1 = t0+1; t1 < uniqueTiles.length; t1++) {
	    		var tA = uniqueTiles[t0];
	    		var tB = uniqueTiles[t1];
	    		if(tA == false) {
	    			tA = uniqueTiles[t1];
	    			tB = uniqueTiles[t0];
	    		}
	    		var rel = tA.getRelation(tB);
	    		if(rel.origin == tB) {
	    			tA = uniqueTiles[t1];
	    			tB = uniqueTiles[t0];
	    		}
	    		var bset = rel.getBorderSet();
	    		for(var r = 0; r < 4; r++) {
	    			//full version logic
	    			if(	genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tA 
	    			&& 	genMatrix[(2+r)%4]==tB 
	    			&& 	genMatrix[(3+r)%4]==tB
	    			||
	    				genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]!=tA && genMatrix[(1+r)%4]!=tB 
	    			&& 	genMatrix[(2+r)%4]!=tA 
	    			&& 	genMatrix[(3+r)%4]==tB
	    			||
	    				genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tA
	    			&& 	genMatrix[(2+r)%4]!=tA && genMatrix[(2+r)%4]!=tB 
	    			&& 	genMatrix[(3+r)%4]==tB
	    			||
	    				genMatrix[(0+r)%4]!=tA && genMatrix[(0+r)%4]!=tB 
	    			&& 	genMatrix[(1+r)%4]==tA
	    			&& 	genMatrix[(2+r)%4]==tB 
	    			&& 	genMatrix[(3+r)%4]!=tA
	    			||
	    				genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tA
	    			&& 	genMatrix[(2+r)%4]==tB
	    			&& 	genMatrix[(3+r)%4]!=tA && genMatrix[(3+r)%4]!=tB) {
	    				components.push({bset:bset, r:r, t:0});
	    			}
	    			if(	genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tA 
	    			&& 	genMatrix[(2+r)%4]==tB 
	    			&& 	genMatrix[(3+r)%4]==tA
	    			||
	    				genMatrix[(0+r)%4]!=tA && genMatrix[(0+r)%4]!=tB
	    			&& 	genMatrix[(1+r)%4]==tA 
	    			&& 	genMatrix[(2+r)%4]==tB 
	    			&& 	genMatrix[(3+r)%4]==tA) {
	    				components.push({bset:bset, r:r, t:1});
	    			}
	    			if(	genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tB 
	    			&& 	genMatrix[(2+r)%4]==tB 
	    			&& 	genMatrix[(3+r)%4]==tB
	    			||
	    				genMatrix[(0+r)%4]==tA
	    			&& 	genMatrix[(1+r)%4]==tB 
	    			&& 	genMatrix[(2+r)%4]!=tB 
	    			&& 	genMatrix[(3+r)%4]==tB) {
	    				components.push({bset:bset, r:r, t:2});
	    			}
	    		}
	    	}
	    }

		return components;
	}
}
module.exports = BorderGeneratorWang;