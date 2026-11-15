var getKey = function(x, y) {
	var a = 2*x;
	if(x < 0) { a = -2*x-1; }
	var b = 2*y;
	if(y < 0) { b = -2*y-1; }
	return ((a+b)*(a+b+1)+b)/2;
}

class TileGrid {
	constructor() {
		this.tiles = [];
		this.regions = [];
	}

	getTiles() {
		return this.tiles;
	}

	getTile(x, y) {
		var tile = this.tiles[getKey(x, y)];
		if(tile != null) {
			return tile.tile;
		} else {
			return null;
		}
	}

	setTile(tile, x, y) {
		if(tile != null) {
			this.tiles[getKey(x, y)] = {pos:{x:x, y:y}, tile:tile};
		} else {
			delete this.tiles[getKey(x, y)];
		}
	}

	moveTiles(positions, ox, oy) {
		var tiles = [];
		for(var i = 0; i < positions.length; i++) {
			var pos = positions[i];
			var key = getKey(pos.x, pos.y);
			var tile = this.tiles[key];
			if(tile != null) {
				tiles.push(tile);
				delete this.tiles[key];
			}
		}
		for(var i in tiles) {
			var tile = tiles[i];
			this.setTile(tile.tile, tile.pos.x+ox, tile.pos.y+oy);
		}
	}

	getRegions() {
		return this.regions;
	}

	addRegion(region) {
		this.regions.push(region);
	}

	removeRegion(region) {
		var index = this.regions.indexOf(region);
		if(index > -1) {
			this.regions.splice(index, 1);
		}
	}
}
module.exports = TileGrid;