var Region = require('./Region.js');
var tileroninX = require('./tileroninX.js');
var TileBase = require('./TileBase.js');
var TileGrid = require('./TileGrid.js');
var {nativeImage} = require('electron');

var chokidar = require("chokidar");

var loadTiles = function() {
	var image = nativeImage.createFromPath(this.fn);
	if(!image.isEmpty()) {
		this.setValid(true);
		var size = image.getSize();
		var bounds = this.getBounds();
		var tileShape = tileroninX.getTileShape();
		if(tileShape == tileroninX.Shape.ORTHOGRAPHIC) {
			this.setBounds(bounds.x0, bounds.y0, bounds.x0+Math.ceil(size.width/tileroninX.getTileSize())-1, bounds.y0+Math.ceil(size.height/tileroninX.getTileSize())-1);
		} else if(tileShape = tileroninX.Shape.ISOMETRIC) {
			this.setBounds(bounds.x0, bounds.y0, bounds.x0+Math.ceil(size.width/tileroninX.getTileSize()[0])-1, bounds.y0+Math.ceil(size.height/tileroninX.getTileSize()[1])-1);
		}
		var tiles = this.syncTiles.getTiles();
		for(var i in tiles) {
			var pos = tiles[i].pos;
			if(!this.bounds.contains(pos.x+bounds.x0, pos.y+bounds.y0)) {
				this.syncTiles.setTile(null, pos.x, pos.y);
			}
		}

		var sources = tileroninX.imageToSources(image);
		var addTiles = [];
		var bounds = this.getBounds();
		for(var index in sources) {
			var source = sources[index];
			var syncTile = this.syncTiles.getTile(source.pos.x, source.pos.y);
			if(syncTile == null) {
				var tile = new TileBase(source.src);
				this.syncTiles.setTile(tile, source.pos.x, source.pos.y);
				addTiles.push({x:source.pos.x+bounds.x0, y:source.pos.y+bounds.y0, tile:tile});
			} else {
				syncTile.getSource().setSource(source.src);
				if(tileroninX.getTileSet(source.pos.x+bounds.x0, source.pos.y+bounds.y0) !== syncTile) {
					var tile = new TileBase(syncTile.getSource());
					this.syncTiles.setTile(tile, source.pos.x, source.pos.y);
					addTiles.push({x:source.pos.x+bounds.x0, y:source.pos.y+bounds.y0, tile:tile});
				}
			}
		}
		tileroninX.setTilesSet(addTiles);
	} else {
		this.setValid(false);
	}
}

class RegionSync extends Region {
	constructor(x0, y0, fn, x1, y1) {
		super(x0, y0, (x1==null)?x0:x1, (y1==null)?y0:y1);
		this.fn = fn;
		this.watcher = null;
		this.syncTiles = new TileGrid();

		//var image = nativeImage.createFromPath(this.fn);
		//var size = image.getSize();
		//this.bounds.setSelection(x0, y0, x0+Math.ceil(size.width/tileroninX.getTileSize())-1, y0+Math.ceil(size.height/tileroninX.getTileSize())-1);
	}

	initRegion() {
		this.watcher = chokidar.watch(this.fn, {awaitWriteFinish: {
												    stabilityThreshold: 500,
												    pollInterval: 100,
												}}
		).on('all', function(event, filename) {
			loadTiles.bind(this)();
		}.bind(this));
		loadTiles.bind(this)();
	}

	finRegion() {
		if(this.watcher != null) {
			this.watcher.close();
		}
	}

	getLabel() {
		return this.fn;
	}

	getCacheTiles() {
		return this.syncTiles.getTiles();
	}

	setCacheTile(tile, x, y) {
		this.syncTiles.setTile(tile, x, y);
	}

	setCacheSource(src, x, y) {
		var tile = new TileBase(src);
		this.syncTiles.setTile(tile, x, y);
	}
}
module.exports = RegionSync;