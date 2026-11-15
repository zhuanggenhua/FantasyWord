THREE = require("three");
var plh = require('./PointerLockHandler.js');

class TileDisplayView {
	constructor() {
		this.div = document.createElement('div');
		this.div.className = "tiledisplay-view";

		var canvas = document.createElement('div');
		canvas.className = "tiledisplay-canvas-view";
		this.div.appendChild(canvas);

		this.tile = null;

		this.hovered = false;
		this.dragging = false;
		this.targetX = 0.5;
		this.targetY = -0.7;
		canvas.addEventListener("mouseover", function(event) {
			if(!this.hovered) {
				this.hovered = true;
				this.targetX = 0.5;
				this.targetY = -0.7;
			}
		}.bind(this), false);
		canvas.addEventListener("mouseout", function(event) {
			if(!this.dragging) {
				this.hovered = false;
			}
		}.bind(this), false);

		plh.applyPointerLock(canvas, function() {
			plh.lockPointer();
			this.dragging = true;
		}.bind(this), function(x, y, event) {
			var scale = 0.01;
			this.targetX -= event.scaledMovementY*scale;
			this.targetY -= event.scaledMovementX*scale;
			var limit = Math.PI*0.4;
			if(this.targetX > limit) {
				this.targetX = limit;
			} else if(this.targetX < -limit) {
				this.targetX = -limit;
			}
			if(this.targetY > limit) {
				this.targetY = limit;
			} else if(this.targetY < -limit) {
				this.targetY = -limit;
			}
		}.bind(this), function() {
			this.dragging = false;
		}.bind(this));

		var tileImage = document.createElement('div');
		tileImage.className = "tiledisplay-image-view";
		canvas.appendChild(tileImage);

		//threejs init

		var size = 512;
		this.camera = new THREE.OrthographicCamera(size/-2, size/2, size/2, size/-2, -128, 1000);
		var camDist = 128;
		this.camera.position.z = camDist;

	    this.scene = new THREE.Scene();

	    var renderer = new THREE.WebGLRenderer({antialias: true, alpha: true});
	    renderer.setClearColor(0xffffff, 0);
	    renderer.setSize(size, size);
	    tileImage.appendChild(renderer.domElement);

	    var animate = function() {
			requestAnimationFrame(animate.bind(this));

			var targetX = 0;
			var targetY = 0;
			if(this.hovered) {
				targetX = this.targetX;
				targetY = this.targetY;
			}

			var dampingX = 0.23;
			var dampingY = 0.19;
			this.camera.rotation.x += (targetX-this.camera.rotation.x)*dampingX;
			this.camera.rotation.y += (targetY-this.camera.rotation.y)*dampingY;
			this.camera.position.y = -Math.sin(this.camera.rotation.x)*Math.cos(this.camera.rotation.y)*camDist;
			this.camera.position.x = Math.sin(this.camera.rotation.y)*camDist;
			this.camera.position.z = Math.cos(this.camera.rotation.y)*Math.cos(this.camera.rotation.x)*camDist;

			var nx = 0;
			var ny = 0;
			var nz = 1;
			var cx = this.camera.position.x;
			var cy = this.camera.position.y;
			var cz = this.camera.position.z;
			var cmag = Math.sqrt(cx*cx+cy*cy+cz*cz);
			cx /= cmag;
			cy /= cmag;
			cz /= cmag;
			var dot = nx*cx+ny*cy+nz*cz;

			for(var i in this.scene.children) {
				if(i%2 == 1) {
					var mesh = this.scene.children[i];
					var invDot = 1-dot;
					mesh.material.opacity = Math.pow(invDot, 0.5)*0.2;
				}
			}

			renderer.render(this.scene, this.camera);
		}
		animate.bind(this)();
	}

	setTile(tile) {
		this.tile = tile;
		var layers = [];
		if(tile != null) {
			layers = tile.getLayers();
		}
		Promise.all(layers).then(function(values) {
			if(this.tile != tile) {
				return;
			}
			while(this.scene.children.length > 0){ 
			    this.scene.remove(this.scene.children[0]); 
			}

			var planeW = 32;
			var planeH = 32;

			var tileShape = tileroninX.getTileShape();
			if(tileShape == tileroninX.Shape.ISOMETRIC) {
				var tileSize = tileroninX.getTileSize();
				var step = tileSize[0]/tileSize[1];
				planeW = planeH*step;
			}

			for(var i in values) {
				var img = values[i];

				var geometry = new THREE.PlaneGeometry(planeW, planeH);
		    	var material;
		    	var tex = new THREE.CanvasTexture(img);
		    	tex.magFilter = THREE.NearestFilter;
		    	tex.minFilter = THREE.NearestFilter;
		    	material = new THREE.MeshBasicMaterial({transparent: true, map: tex});
		    	var mesh = new THREE.Mesh(geometry, material);
			    var layerOffset = 32;
			    mesh.position.z = (-(layers.length-1)/2.0+ +i)*layerOffset;
			    this.scene.add(mesh);

			    var geometry = new THREE.PlaneGeometry(planeW, planeH);
		    	material = new THREE.MeshBasicMaterial({transparent: true, opacity:0});
		    	material.color.setHex(0xffffff)
		    	var mesh = new THREE.Mesh(geometry, material);
			    mesh.position.z = (-(layers.length-1)/2.0+ +i)*layerOffset-0.01;
			    this.scene.add(mesh);
			}
		}.bind(this));
	}

	getDiv() {
		return this.div;
	}
}
module.exports = TileDisplayView;