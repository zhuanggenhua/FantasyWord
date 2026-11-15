var tileroninX = require('./tileroninX.js');
var CallbackManager = require('./CallbackManager.js');

var TileRelationWang = require('./TileRelationWang.js');
var TileRelationWangBorder = require('./TileRelationWangBorder.js');

var TileRelationBlob = require('./TileRelationBlob.js');
var TileRelationBlobBorder = require('./TileRelationBlobBorder.js');

var TileRelationProp = require('./TileRelationProp.js');
var TileRelationPropBackground = require('./TileRelationPropBackground.js');
var TileRelationProxy = require('./TileRelationProxy.js');

var TileRelationBlobPre2_0_0 = require('./TileRelationBlobPre2_0_0.js');
var TileRelationWangPre2_0_0 = require('./TileRelationWangPre2_0_0.js');

var {nativeImage} = require('electron');

var registerBlobBorderIndex = function(other, rel) {
	if(rel instanceof TileRelationBlobBorder && !rel.isBorder) {
		var key = "";
		var m = rel.getIndexMatrix();
		for(var i = 0; i < m.length; i++) {
			var tile = m[i];
			var k;
			if(tile == this) {
				k = "b";
			} else if(tile == null) {
				k = "n";
			} else {
				k = this.relationIndex.indexOf(tile);
			}
			key += k;
			if(i < m.length-1) {
				key += "_";
			}
		}
		this.blobBorderIndex[key] = other;
	}
}
var removeBlobBorderIndex = function(other) {
	var rel = this.getRelation(other);
	if(rel instanceof TileRelationBlobBorder && !rel.isBorder) {
		for(var i in this.blobBorderIndex) {
			if(this.blobBorderIndex[i] == other) {
				delete(this.blobBorderIndex[i]);
				return;
			}
		}
	}
}

var registerWangBorderIndex = function(other, rel) {
	if(rel instanceof TileRelationWangBorder && !rel.isBorder) {
		var key = "";
		var m = rel.getIndexMatrix();
		for(var i = 0; i < m.length; i++) {
			var tile = m[i];
			var k;
			if(tile == this) {
				k = "b";
			} else {
				k = this.relationIndex.indexOf(tile);
			}
			key += k;
			if(i < m.length-1) {
				key += "_";
			}
		}
		this.wangBorderIndex[key] = other;
	}
}
var removeWangBorderIndex = function(other) {
	var rel = this.getRelation(other);
	if(rel instanceof TileRelationWangBorder && !rel.isBorder) {
		for(var i in this.wangBorderIndex) {
			if(this.wangBorderIndex[i] == other) {
				delete(this.wangBorderIndex[i]);
				return;
			}
		}
	}
}

var registerProxyTile = function(other, rel) {
	if(rel instanceof TileRelationProxy && !rel.isReverse) {
		this.proxyTile = other;
	}
}
var removeProxyTile = function(other) {
	var rel = this.getRelation(other);
	if(rel instanceof TileRelationProxy && !rel.isReverse) {
		this.proxyTile = null;
	}
}

class Tile {
	constructor() {
		this.contentUpdatedCallback = new CallbackManager();
		this.relationsUpdatedCallback = new CallbackManager();

		this.layersCache = null;
		this.imageCache = null;

		this.relationIndex = [];
		this.relations = [];

		this.blobBorderIndex = [];
		this.wangBorderIndex = [];
		this.proxyTile = null;

		this.deleting = 0;
		this.sandboxRefs = [];
		this.inSet = false;
	}

	reference() {
		this.inSet = true;
	}

	unreference() {
		this.inSet = false;
	}

	contentUpdatedSubscribe(func) {
		this.contentUpdatedCallback.subscribe(func);
	}
	contentUpdatedUnsubscribe(func) {
		this.contentUpdatedCallback.unsubscribe(func);
	}
	contentUpdatedUnsubscribeIndex(index) {
		this.contentUpdatedCallback.unsubscribeIndex(index);
	}

	relationsUpdatedSubscribe(func) {
		this.relationsUpdatedCallback.subscribe(func);
	}
	relationsUpdatedUnsubscribe(func) {
		this.relationsUpdatedCallback.unsubscribe(func);
	}

	getLayers() {
		return this.layersCache;
	}

	getImage() {
		return this.imageCache;
	}

	rebuild(layers) {
		this.layersCache = layers;

		var tileSize = tileroninX.getTileSize();
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

	    var p = Promise.resolve();

	    var layers = this.getLayers();
	    for(var i in layers) {
	    	var layer = layers[i];
	    	(function(layer) {
	    		p = p.then(function() {
			    	return new Promise(function(resolve, reject) {
				        layer.then(function(image) {
				        	ctx.drawImage(image, 0, 0);
				            resolve();
				        });
				    }.bind(this));
			    }.bind(this));
	    	}).bind(this)(layer);
	    }

	    this.imageCache = p.then(function() {
	    	return new Promise(function(resolve, reject) {
	            resolve(canvas);
	    	}.bind(this));
	    }.bind(this));
	}

	setRelation(other, rel, undoGroup=[]) {
		var rIdx = this.relationIndex.indexOf(other);

		var undoParams = {action:'tile_relation_change', rels:[{tile:this, other:other, prev_value:this.relations[rIdx]}]};
    	undoGroup.push(undoParams);

		if(rel == null && rIdx != -1) {
			//this.relationIndex.splice(rIdx, 1);
			//this.relations.splice(rIdx, 1);
			removeBlobBorderIndex.bind(this)(other);
			removeWangBorderIndex.bind(this)(other);
			removeProxyTile.bind(this)(other);
			delete(this.relationIndex[rIdx]);
			this.relations[rIdx].unreference();
			delete(this.relations[rIdx]);
			this.relationsUpdatedCallback.notify();
		} else if(rel != null && rIdx != -1) { //is this unreachable?
			this.relations[rIdx] = rel;
			rel.reference();
			this.relationsUpdatedCallback.notify();
		} else if(rel != null && rIdx == -1) {
			rIdx = this.relationIndex.length;
			this.relationIndex.push(other);
			this.relations[rIdx] = rel;
			rel.reference();
			registerBlobBorderIndex.bind(this)(other, rel);
			registerWangBorderIndex.bind(this)(other, rel);
			registerProxyTile.bind(this)(other, rel);
			this.relationsUpdatedCallback.notify();
		}
	}
	registerRelation(other, rel, undoGroup=[]) {
		var rIdx = this.relationIndex.indexOf(other);

		var undoParams = {action:'tile_relation_change', rels:[{tile:this, other:other, prev_value:this.relations[rIdx]}]};
    	undoGroup.push(undoParams);

		if(rIdx == -1) {
			rIdx = this.relationIndex.length;
			this.relationIndex.push(other);
			this.relations[rIdx] = rel;
			rel.reference();
			registerBlobBorderIndex.bind(this)(other, rel);
			registerWangBorderIndex.bind(this)(other, rel);
			registerProxyTile.bind(this)(other, rel);
			this.relationsUpdatedCallback.notify();
		}
	}
	removeRelation(other, undoGroup=[], changedTiles=null) {
		var processedRelations = [];
		this.getRelationDependencies(other, processedRelations);
		var uniqueTiles;
		var undoEntries;
		if(changedTiles == null) {
			uniqueTiles = [];
			undoEntries = [];
		} else {
			uniqueTiles = changedTiles[0];
			undoEntries = changedTiles[1];
		}
		for(var i in processedRelations) {
			var t = processedRelations[i].tile;
			var o = processedRelations[i].other;

			var uid = uniqueTiles.indexOf(t);
			if(uid == -1) {
				uniqueTiles.push(t);
			}

			var undoEntry = {tile:t, other:o, prev_value:t.getRelation(o)};
			undoEntries.push(undoEntry);

			var rIdx = t.relationIndex.indexOf(o);
			//t.relationIndex.splice(rIdx, 1);
			//t.relations.splice(rIdx, 1);
			removeBlobBorderIndex.bind(t)(o);
			removeWangBorderIndex.bind(t)(o);
			removeProxyTile.bind(t)(o);
			delete(t.relationIndex[rIdx]);
			if(rIdx != -1) {
				t.relations[rIdx].unreference();
			}
			delete(t.relations[rIdx]);
		}
		if(changedTiles == null) {
			var undoParams = {action:'tile_relation_change', rels:undoEntries};
			undoGroup.push(undoParams);
			for(var i in uniqueTiles) {
				uniqueTiles[i].relationsUpdatedCallback.notify();
			}
		}
	}
	clearRelations(undoGroup=[]) {
		var changedTiles = [[], []];
		for(var i = this.relationIndex.length-1; i >= 0; i--) {
			if(this.relationIndex[i] != null) {
				this.removeRelation(this.relationIndex[i], undoGroup, changedTiles);
			}
		}
		var uniqueTiles = changedTiles[0];
		var undoEntries = changedTiles[1];
		var undoParams = {action:'tile_relation_change', rels:undoEntries};
		undoGroup.push(undoParams);
		for(var i in uniqueTiles) {
			uniqueTiles[i].relationsUpdatedCallback.notify();
		}
	}
	getRelation(other) {
		var rIdx = this.relationIndex.indexOf(other);
		return this.relations[rIdx];
	}
	getRelations() {
		var r = [];
		for(var i in this.relationIndex) {
			r.push({t:this.relationIndex[i], r:this.relations[i]});
		}
		return r;
	}
	getRelationDependencies(other, processedRelations=[]) {
		for(var i in processedRelations) {
			if(processedRelations[i].tile == this && processedRelations[i].other == other) {
				return;
			}
		}

		var rIdx = this.relationIndex.indexOf(other);
		var rel = this.relations[rIdx];

		if(rel instanceof TileRelationWang) {
			for(var k in this.relations) {
				var or = this.relations[k];
				if(or instanceof TileRelationWangBorder && or.getIndexMatrix().includes(other)) {
					this.getRelationDependencies(this.relationIndex[k], processedRelations);
				}
			}
		} else if(rel instanceof TileRelationBlob && rel.origin == this) {
			for(var k in this.relations) {
				var or = this.relations[k];
				if(or instanceof TileRelationBlobBorder && or.getIndexMatrix().includes(other)) {
					this.getRelationDependencies(this.relationIndex[k], processedRelations);
				}
			}
		}

		processedRelations.push({tile:this, other:other});

		if(rel instanceof TileRelationWang) {
			if(other != false && other.getRelation(this) != null) {
				other.getRelationDependencies(this, processedRelations);
			}

			var noLongerAuto = true;
			for(var k in this.relations) {
				var or = this.relations[k];
				if(or instanceof TileRelationWang) {
					var alreadyProcessed = false;
					for(var i in processedRelations) {
						if(processedRelations[i].tile == this && processedRelations[i].other == this.relationIndex[k]) {
							alreadyProcessed = true;
							break;
						}
					}
					if(!alreadyProcessed) {
						noLongerAuto = false;
					}
				}
			}
			if(noLongerAuto) {
				for(var k in this.relations) {
					var or = this.relations[k];
					if(or instanceof TileRelationPropBackground) {
						this.getRelationDependencies(this.relationIndex[k], processedRelations);
					}
				}
			}
		} else if(rel instanceof TileRelationWangBorder) {
			if(other.getRelation(this) != null) {
				other.getRelationDependencies(this, processedRelations);
			}
			if(rel.isBorder) {
				for(var k in this.relations) {
					var or = this.relations[k];
					if(or instanceof TileRelationWangBorder) {
						this.getRelationDependencies(this.relationIndex[k], processedRelations);
					}
				}
			}
		} else if(rel instanceof TileRelationBlob) {
			if(other != false && other.getRelation(this) != null) {
				other.getRelationDependencies(this, processedRelations);
			}

			var noLongerAuto = true;
			for(var k in this.relations) {
				var or = this.relations[k];
				if(or instanceof TileRelationBlob) {
					var alreadyProcessed = false;
					for(var i in processedRelations) {
						if(processedRelations[i].tile == this && processedRelations[i].other == this.relationIndex[k]) {
							alreadyProcessed = true;
							break;
						}
					}
					if(!alreadyProcessed) {
						noLongerAuto = false;
					}
				}
			}
			if(noLongerAuto) {
				for(var k in this.relations) {
					var or = this.relations[k];
					if(or instanceof TileRelationPropBackground) {
						this.getRelationDependencies(this.relationIndex[k], processedRelations);
					}
				}
			}
		} else if(rel instanceof TileRelationBlobBorder) {
			if(other.getRelation(this) != null) {
				other.getRelationDependencies(this, processedRelations);
			}
		} else if(rel instanceof TileRelationProp) {
			var skipRest = false;
			for(var i in processedRelations) {
				if(processedRelations[i].tile == other && processedRelations[i].other == this) {
					skipRest = true;
					break;
				}
			}
			if(!skipRest) {
				for(var k in this.relations) {
					var or = this.relations[k];
					if(or instanceof TileRelationProp) {
						this.getRelationDependencies(this.relationIndex[k], processedRelations);
					}
				}
			}
			if(other != false && other.getRelation(this) != null) {
				other.getRelationDependencies(this, processedRelations);
			}

			var noLongerProp = true;
			for(var k in this.relations) {
				var or = this.relations[k];
				if(or instanceof TileRelationProp) {
					var alreadyProcessed = false;
					for(var i in processedRelations) {
						if(processedRelations[i].tile == this && processedRelations[i].other == this.relationIndex[k]) {
							alreadyProcessed = true;
							break;
						}
					}
					if(!alreadyProcessed) {
						noLongerProp = false;
					}
				}
			}
			if(noLongerProp) {
				for(var k in this.relations) {
					var or = this.relations[k];
					if(or instanceof TileRelationPropBackground) {
						this.getRelationDependencies(this.relationIndex[k], processedRelations);
					}
				}
			}
		} else if(rel instanceof TileRelationPropBackground) {
			if(other.getRelation(this) != null) {
				other.getRelationDependencies(this, processedRelations);
			}
		} else if(rel instanceof TileRelationProxy) {
			if(other != this && other.getRelation(this) != null) {
				other.getRelationDependencies(this, processedRelations);
			}

			if(rel.isReverse && other != this) {
				var noLongerProxied = true;
				for(var k in this.relations) {
					var or = this.relations[k];
					if(or instanceof TileRelationProxy && or.isReverse && this.relationIndex[k] != this) {
						var alreadyProcessed = false;
						for(var i in processedRelations) {
							if(processedRelations[i].tile == this && processedRelations[i].other == this.relationIndex[k]) {
								alreadyProcessed = true;
								break;
							}
						}
						if(!alreadyProcessed) {
							noLongerProxied = false;
						}
					}
				}
				if(noLongerProxied) {
					this.getRelationDependencies(this, processedRelations);
				}
			}
		} else if(rel instanceof TileRelationBlobPre2_0_0) {
			var skipRest = false;
			for(var i in processedRelations) {
				if(processedRelations[i].tile == other && processedRelations[i].other == this) {
					skipRest = true;
					break;
				}
			}
			if(!skipRest) {
				for(var k in this.relations) {
					var or = this.relations[k];
					if(or instanceof TileRelationBlobPre2_0_0) {
						this.getRelationDependencies(this.relationIndex[k], processedRelations);
					}
				}
			}
			if(other != false && other.getRelation(this) != null) {
				other.getRelationDependencies(this, processedRelations);
			}
		} else if(rel instanceof TileRelationWangPre2_0_0) {
			var skipRest = false;
			for(var i in processedRelations) {
				if(processedRelations[i].tile == other && processedRelations[i].other == this) {
					skipRest = true;
					break;
				}
			}
			if(!skipRest) {
				for(var k in this.relations) {
					var or = this.relations[k];
					if(or instanceof TileRelationWangPre2_0_0) {
						this.getRelationDependencies(this.relationIndex[k], processedRelations);
					}
				}
			}
			if(other != false && other.getRelation(this) != null) {
				other.getRelationDependencies(this, processedRelations);
			}
		}
	}
	getRelationsDependencies(processedRelations=[]) {
		for(var i in this.relationIndex) {
			this.getRelationDependencies(this.relationIndex[i], processedRelations);
		}
	}

	getRelationWangBorder(indexMatrix) { //OPTIMIZE
		var key = "";
		for(var i = 0; i < indexMatrix.length; i++) {
			var tile = indexMatrix[i];
			var k;
			if(tile == this) {
				k = "b";
			} else {
				k = this.relationIndex.indexOf(tile);
			}
			key += k;
			if(i < indexMatrix.length-1) {
				key += "_";
			}
		}
		return this.wangBorderIndex[key];
	}

	getRelationBlobBorder(indexMatrix) {
		var key = "";
		for(var i = 0; i < indexMatrix.length; i++) {
			var k;
			if(i%2==0 && (indexMatrix[(1+i)%8]!=this || indexMatrix[(7+i)%8]!=this)) {
				k = "n";
			} else {
				var tile = indexMatrix[i];
				if(tile == this) {
					k = "b";
				} else {
					k = this.relationIndex.indexOf(tile);
				}
			}
			key += k;
			if(i < indexMatrix.length-1) {
				key += "_";
			}
		}
		return this.blobBorderIndex[key];
	}

	getRelationProxy() {
		return this.proxyTile;
	}
}
module.exports = Tile;

Tile.setRelations = function(relations, undoGroup=[]) {
	var uniqueTiles = [];
	var undoEntries = [];
	for(var i = relations.length-1; i >= 0; i--) {
		var r = relations[i];
		var tile = r.tile;
		var other = r.other;
		var rel = r.prev_value;

		var rIdx = tile.relationIndex.indexOf(other);

		var entry = {tile:tile, other:other, prev_value:tile.relations[rIdx]};
		undoEntries.push(entry);

		if(rel == null && rIdx != -1) {
			//this.relationIndex.splice(rIdx, 1);
			//this.relations.splice(rIdx, 1);
			removeBlobBorderIndex.bind(tile)(other);
			removeWangBorderIndex.bind(tile)(other);
			removeProxyTile.bind(tile)(other);
			delete(tile.relationIndex[rIdx]);
			tile.relations[rIdx].unreference();
			delete(tile.relations[rIdx]);
			var uid = uniqueTiles.indexOf(tile);
			if(uid == -1) {
				uniqueTiles.push(tile);
			}
		} else if(rel != null && rIdx != -1) { //is this unreachable?
			tile.relations[rIdx] = rel;
			rel.reference();
			var uid = uniqueTiles.indexOf(tile);
			if(uid == -1) {
				uniqueTiles.push(tile);
			}
		} else if(rel != null && rIdx == -1) {
			rIdx = tile.relationIndex.length;
			tile.relationIndex.push(other);
			tile.relations[rIdx] = rel;
			rel.reference();
			registerBlobBorderIndex.bind(tile)(other, rel);
			registerWangBorderIndex.bind(tile)(other, rel);
			registerProxyTile.bind(tile)(other, rel);
			var uid = uniqueTiles.indexOf(tile);
			if(uid == -1) {
				uniqueTiles.push(tile);
			}
		}
	}
	var undoParams = {action:'tile_relation_change', rels:undoEntries};
	undoGroup.push(undoParams);
	for(var i in uniqueTiles) {
		uniqueTiles[i].relationsUpdatedCallback.notify();
	}
}