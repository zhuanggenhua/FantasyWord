var ExportFile = require('./ExportFile.js');
var ExportVisualBlockField = require('./ExportVisualBlockField.js');
var {nativeImage} = require('electron');

class ExportVisualFile extends ExportFile {
	constructor(name, field=new ExportVisualBlockField()) {
		super(name);
		this.field = field;
	}

	getField() {
		return this.field;
	}

	getData(dataset) {
	    return new Promise(function(resolve, reject) {
	    	var imgs = this.field.getImages(dataset);
	    	var minZ = null;
	    	var maxZ = null;
	    	for(var i in imgs) {
	    		if(minZ == null || imgs[i].z < minZ) {
	    			minZ = imgs[i].z;
	    		}
	    		if(maxZ == null || imgs[i].z > maxZ) {
	    			maxZ = imgs[i].z;
	    		}
	    	}
	    	var canvas = document.createElement('canvas');
		    canvas.width  = this.field.getWidth(dataset);
		    canvas.height = this.field.getHeight(dataset);
		    var ctx = canvas.getContext('2d');
	    	var p = Promise.resolve();
	    	for(var k = minZ; k <= maxZ; k++) {
	    		for(var i in imgs) {
	    			if(imgs[i].z != k) {
	    				continue;
	    			}
			    	p = (function(img, pp) {
			    		return new Promise(function(resolve, reject) {
				    		var image = new Image();
				    		image.addEventListener('load', function() {
				    			pp.then(function() {
				    				ctx.drawImage(image, img.x, img.y);
				                	resolve();
				    			});
				            });
				    		img.image.then(function(value) {
				            	image.src = value.toDataURL();
				            });
				    	});
			    	})(imgs[i], p);
			    }
	    	}
		    p.then(function() {
	            resolve(nativeImage.createFromDataURL(canvas.toDataURL('image/png')).toPNG());
	        });
	    }.bind(this));
	}
}
module.exports = ExportVisualFile;