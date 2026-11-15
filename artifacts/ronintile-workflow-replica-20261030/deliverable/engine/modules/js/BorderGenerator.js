var CallbackManager = require('./CallbackManager.js');
var tileroninX = require('./tileroninX.js');

var {nativeImage} = require('electron');
var path = require('path');

class BorderGenerator {
	constructor() {
		this.contentUpdatedCallback = new CallbackManager();
	}

	contentUpdatedSubscribe(func) {
		this.contentUpdatedCallback.subscribe(func);
	}

	contentUpdatedUnsubscribe(func) {
		this.contentUpdatedCallback.unsubscribe(func);
	}
}
module.exports = BorderGenerator;

var buildMissingImage = function() {
	BorderGenerator.missingImage = new Promise(function(resolve, reject) {
		var image = new Image();
		image.addEventListener('load', function() {
			var tileShape = tileroninX.getTileShape();
			if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
				var tileSize = tileroninX.getTileSize();
				var canvas = document.createElement('canvas');
				canvas.width  = tileSize;
		    	canvas.height = tileSize;
			    var ctx = canvas.getContext('2d');

		    	/*for(var ix = 0; ix < tileSize; ix+=image.width) {
		    		for(var iy = 0; iy < tileSize; iy+=image.height) {
		    			ctx.drawImage(image, ix, iy);
		    		}
		    	}*/
		    	ctx.fillStyle = '#404040';
		    	ctx.fillRect(0, 0, tileSize, tileSize);
		    	ctx.drawImage(image, Math.floor((tileSize-image.width)/2), Math.floor((tileSize-image.height)/2));
		        resolve(canvas);
			} else if(tileShape == tileroninX.Shape.ISOMETRIC) {
				var tileSize = tileroninX.getTileSize();
				var canvas = document.createElement('canvas');
				canvas.width  = tileSize[0];
		    	canvas.height = tileSize[1];
			    var ctx = canvas.getContext('2d');

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
		    	/*for(var ix = (tileSize[0]-image.width)/2-Math.ceil((tileSize[0]-image.width)/(2*image.width))*image.width; ix < tileSize[0]; ix+=image.width) {
		    		for(var iy = (tileSize[1]-image.height)/2-Math.ceil((tileSize[1]-image.height)/(2*image.height))*image.height; iy < tileSize[1]; iy+=image.height) {
		    			ctx.drawImage(image, ix, iy);
		    		}
		    	}*/
		    	ctx.fillStyle = '#404040';
		    	ctx.fillRect(0, 0, tileSize[0], tileSize[1]);
		    	ctx.drawImage(image, Math.floor((tileSize[0]-image.width)/2), Math.floor((tileSize[1]-image.height)/2));
		        resolve(canvas);
			}
	    });
	    var small = false;
	    var tileShape = tileroninX.getTileShape();
		if(tileShape == 0) {
			var tileSize = tileroninX.getTileSize();
			if(tileSize < 12) {
				small = true;
			}
		} else if(tileShape == 1) {
			var tileSize = tileroninX.getTileSize();
			if(tileSize[1] < 12) {
				small = true;
			}
		}
	    if(small) {
	    	image.src = nativeImage.createFromPath(path.join(__dirname, '/../../res/placeholder/missing_small.png')).toDataURL();
	    } else {
	    	image.src = nativeImage.createFromPath(path.join(__dirname, '/../../res/placeholder/missing.png')).toDataURL();
	    }
	});
}
buildMissingImage();
tileroninX.tileSizeChangedSubscribe(function() {
	buildMissingImage();
})