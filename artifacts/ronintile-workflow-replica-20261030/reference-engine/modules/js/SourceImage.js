var tileroninX = require('./tileroninX.js');
var Source = require('./Source.js');

var {nativeImage} = require('electron');

class SourceImage extends Source {
	constructor(img) {
		super();
		this.image = Promise.resolve(img);
	}
	
	getImage() {
		var tileSize = tileroninX.getTileSize();
		if(this.imageCache == null || tileSize != this.size) {
			this.size = tileSize;

			var canvas = document.createElement('canvas');
			var tileShape = tileroninX.getTileShape();
			if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
				canvas.width  = tileSize;
		    	canvas.height = tileSize;
			} else if(tileShape == tileroninX.Shape.ISOMETRIC) {
				canvas.width  = tileSize[0];
		    	canvas.height = tileSize[1];
			}
		    var ctx = canvas.getContext('2d');

		    var p = this.image.then(function(img) {
		    	return new Promise(function(resolve, reject) {
				    var image = new Image();
			        image.addEventListener('load', function() {
			        	if(tileShape == tileroninX.Shape.ISOMETRIC) { // clip isometric shape
			        		var step = tileSize[0]/tileSize[1];
			        		ctx.beginPath();
					    	ctx.moveTo(tileSize[0]/2+step, 0);
					    	for(var i = 0; i < tileSize[1]/2-1; i++) {
					    		ctx.lineTo(tileSize[0]/2+(i+1)*step, i+1);
					    		ctx.lineTo(tileSize[0]/2+(i+2)*step, i+1);
					    	}
					    	for(var i = 0; i < tileSize[1]/2-1; i++) {
					    		ctx.lineTo(tileSize[0]-i*step, tileSize[1]/2+1+i);
					    		ctx.lineTo(tileSize[0]-(i+1)*step, tileSize[1]/2+1+i);
					    	}
					    	ctx.lineTo(tileSize[0]/2+step, tileSize[1]);
					    	ctx.lineTo(tileSize[0]/2-step, tileSize[1]);
					    	for(var i = 0; i < tileSize[1]/2-1; i++) {
					    		ctx.lineTo(tileSize[0]/2-(i+1)*step, tileSize[1]-i-1);
					    		ctx.lineTo(tileSize[0]/2-(i+2)*step, tileSize[1]-i-1);
					    	}
					    	for(var i = 0; i < tileSize[1]/2-1; i++) {
					    		ctx.lineTo(i*step, tileSize[1]/2-1-i);
					    		ctx.lineTo((i+1)*step, tileSize[1]/2-1-i);
					    	}
					    	ctx.lineTo(tileSize[0]/2-step, 0);
					    	ctx.clip();
			        	}
			            ctx.drawImage(image, 0, 0);
			            resolve();
			        });
			        image.src = img.toDataURL();
			    }.bind(this));
		    }.bind(this));

		    this.imageCache = p.then(function() {
		    	return new Promise(function(resolve, reject) {
		            resolve(canvas);
		    	}.bind(this));
		    }.bind(this));
		}
		return this.imageCache;
	}
}
module.exports = SourceImage;