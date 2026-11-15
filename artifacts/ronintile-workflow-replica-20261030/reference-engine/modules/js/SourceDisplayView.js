class SourceDisplayView {
	constructor() {
		this.div = document.createElement('div');
		this.div.className = "sourcedisplay-view";

		var canvas = document.createElement('div');
		canvas.className = "sourcedisplay-canvas-view";
		this.div.appendChild(canvas);

		this.tileImage = document.createElement('div');
		this.tileImage.className = "sourcedisplay-image-view";
		canvas.appendChild(this.tileImage);
	}

	setSource(src) {
		if(src != null) {
			src.getImage().then(function(img) {
				var downscale = document.createElement("canvas");
				downscale.height = 96;
				downscale.width = 96;
				var bgW = 32;
				var bgH = 32;
				var tileShape = tileroninX.getTileShape();
				if(tileShape == tileroninX.Shape.ISOMETRIC) {
					var tileSize = tileroninX.getTileSize();
					var step = tileSize[0]/tileSize[1];
					downscale.width = downscale.height*step;
					bgW = bgH*step;
				}
				var ctx = downscale.getContext("2d");
				ctx.imageSmoothingEnabled = false;
				ctx.webkitImageSmoothingEnabled = false;
				ctx.mozImageSmoothingEnabled = false;
				ctx.imageSmoothingEnabled = false;
				ctx.webkitImageSmoothingEnabled = false;
				ctx.mozImageSmoothingEnabled = false;

				ctx.drawImage(img, 0, 0, downscale.width, downscale.height);

				this.tileImage.style.backgroundImage = 'url(\"'+downscale.toDataURL()+'\")';
				this.tileImage.style.backgroundSize = bgW+"px "+bgH+"px";//todo zoom
				this.tileImage.style.width = bgW+"px";
				this.tileImage.style.height = bgH+"px";
				this.tileImage.style.visibility = 'visible';
			}.bind(this));
		} else {
			this.tileImage.style.visibility = 'hidden';
		}
	}

	getDiv() {
		return this.div;
	}
}
module.exports = SourceDisplayView;