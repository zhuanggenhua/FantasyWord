var TileGrid = require('./TileGrid.js');
var LayerList = require('./LayerList.js');

class LayeredTileGrid {
	constructor() {
		this.layers = new LayerList([{grid:new TileGrid(), visible:true, name:"未命名图层"}]);
	}

	getTiles() {
		var tiles = [];
		var layers = this.layers.getLayers();
		for(var i in layers) {
			var lt = layers[i].grid.getTiles();
			for(var k in lt) {
				var t = lt[k];
				tiles.push({pos:{x:t.pos.x, y:t.pos.y, z:i}, tile:t.tile});
			}
		}
		return tiles;
	}

	getTile(x, y, z=0) {
		return this.layers.getLayer(z).grid.getTile(x, y);
	}

	setTile(tile, x, y, z=0) {
		this.layers.getLayer(z).grid.setTile(tile, x, y);
	}

	moveTiles(positions, ox, oy, z=0) {
		this.layers.getLayer(z).grid.moveTiles(positions, ox, oy);
	}

	getLayers() {
		return this.layers.getLayers();
	}

	addLayer(visible=true, name="未命名图层") {
		this.layers.insertLayer({grid:new TileGrid(), visible:visible, name:name});
	}

	insertLayer(layer, z) {
		this.layers.insertLayer(layer, z);
	}

	removeLayer(z) {
		this.layers.removeLayer(z);
	}

	reorderLayer(z, newZ) {
		this.layers.reorderLayer(z, newZ);
	}

	editLayer(z, visible=null, name=null) {
		if(visible != null) {
			this.layers.getLayer(z).visible = visible;
		}
		if(name != null) {
			this.layers.getLayer(z).name = name;
		}
	}
}
module.exports = LayeredTileGrid;
