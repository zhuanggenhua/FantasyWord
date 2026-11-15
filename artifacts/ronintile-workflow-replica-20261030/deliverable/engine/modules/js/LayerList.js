class LayerList {
	constructor(data=[]) {
		this.layers = data;
	}

	getLayer(z) {
		return this.layers[z];
	}

	getLayers() {
		return this.layers;
	}

	insertLayer(data, z=-1) {
		if(z == -1) {
			this.layers.push(data);
		} else {
			this.layers.splice(z, 0, data);
		}
	}

	removeLayer(z) {
		this.layers.splice(z, 1);
	}

	reorderLayer(z, newZ) {
		var layer = this.layers.splice(z, 1)[0];
		this.layers.splice(newZ, 0, layer);
	}
}
module.exports = LayerList;