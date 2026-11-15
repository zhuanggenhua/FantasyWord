var TileDisplayView = require('./TileDisplayView.js');
var PropertyCheckboxView = require('./PropertyCheckboxView.js');
var PropertySourceView = require('./PropertySourceView.js');
var PropertySeparatorView = require('./PropertySeparatorView.js');
var PropertyDiscreteSliderView = require('./PropertyDiscreteSliderView.js');
var PropertyEditTextView = require('./PropertyEditTextView.js');
var PropertyCollapserView = require('./PropertyCollapserView.js');

var CallbackManager = require('./CallbackManager.js');

var TileBase = require('./TileBase.js');
var TileBorder = require('./TileBorder.js');

var BorderSetBlob = require('./BorderSetBlob.js');
var BorderSetWang = require('./BorderSetWang.js');
var BorderGeneratorBlob = require('./BorderGeneratorBlob.js');
var BorderGeneratorWang = require('./BorderGeneratorWang.js');

var TileRelationBlob = require('./TileRelationBlob.js');
var TileRelationBlobBorder = require('./TileRelationBlobBorder.js');
var TileRelationWang = require('./TileRelationWang.js');
var TileRelationWangBorder = require('./TileRelationWangBorder.js');
var TileRelationProp = require('./TileRelationProp.js');
var TileRelationProxy = require('./TileRelationProxy.js');
var TileRelationBlobPre2_0_0 = require('./TileRelationBlobPre2_0_0.js');
var TileRelationWangPre2_0_0 = require('./TileRelationWangPre2_0_0.js');

var PropertyRelationBlobView = require('./PropertyRelationBlobView.js');
var PropertyRelationBlobNeighborView = require('./PropertyRelationBlobNeighborView.js');
var PropertyRelationBlobBorderView = require('./PropertyRelationBlobBorderView.js');
var PropertyRelationWangView = require('./PropertyRelationWangView.js');
var PropertyRelationWangBorderView = require('./PropertyRelationWangBorderView.js');
var PropertyRelationPropView = require('./PropertyRelationPropView.js');
var PropertyRelationProxyView = require('./PropertyRelationProxyView.js');
var PropertyRelationBlobPre2_0_0View = require('./PropertyRelationBlobPre2_0_0View.js');
var PropertyRelationWangPre2_0_0View = require('./PropertyRelationWangPre2_0_0View.js');
var PropertyRelationVariationView = require('./PropertyRelationVariationView.js');

var loadTileConfig = function(tile) {
	var iso = (tileroninX.getTileShape()==tileroninX.Shape.ISOMETRIC);
	if(tile instanceof TileBase) {
		this.titleDiv.innerHTML = "Base Tile";

		var propertyGroup = document.createElement('div');
		propertyGroup.className = "tileproperties-propertygroup-view";
		this.compositionContainer.addDiv(propertyGroup);

		var s0 = new PropertySourceView("Source", tile.getSource(), true);
		s0.sourceOpenedSubscribe(function(src) {
			this.sourceOpenedCallback.notify(src);
		}.bind(this));
		s0.tooltipSubscribe(function(msg) {
			this.tooltipCallback.notify(msg);
		}.bind(this));
		propertyGroup.appendChild(s0.getDiv());

	} else if(tile instanceof TileBorder) {
		this.titleDiv.innerHTML = "Border Tile";

		var bgen = tile.getBorderGenerator();
		if(bgen instanceof BorderGeneratorWang) {

			var createPropertySource = function(bset, r) {
				var pS = new PropertySourceView("Source", bset.getSource(r));
				pS.sourceOpenedSubscribe(function(src) {
					this.sourceOpenedCallback.notify(src);
				}.bind(this));
				pS.tooltipSubscribe(function(msg) {
					this.tooltipCallback.notify(msg);
				}.bind(this));
				pS.sourceChangedSubscribe(function(src) {
					var undoGroup = [];
					bset.setSource(r, src, undoGroup);
					tileroninX.saveUndoState(undoGroup);
				}.bind(this));
				pS.sourcePickingSubscribe(function(fn) {
					this.borderSlotClickedCallback.notify(fn);
				}.bind(this));
				//BSETCALLBACK
				var bsetContentCallbackFunc = function() {
					pS.setSource(bset.getSource(r));
				}
				this.registeredCallbacks.push({bset:bset, callback:bsetContentCallbackFunc});
				bset.contentUpdatedSubscribe(bsetContentCallbackFunc);
				return pS;
			}

			var createPropertyRotation = function(bset, r) {
				var pR = new PropertyDiscreteSliderView("Rotation", 4, bset.getRotation(r));
				pR.sliderChangedSubscribe(function(position) {
					var undoGroup = [];
					bset.setRotation(r, position, undoGroup);
					tileroninX.saveUndoState(undoGroup);
				});
				//BSETCALLBACK
				var bsetContentCallbackFunc = function() {
					pR.setSlider(bset.getRotation(r));
				}
				this.registeredCallbacks.push({bset:bset, callback:bsetContentCallbackFunc});
				bset.contentUpdatedSubscribe(bsetContentCallbackFunc);
				return pR
			}

			var createPropertyFlipX = function(bset, r) {
				var pX = new PropertyCheckboxView("Flip X", bset.getFlipX(r));
				pX.boxCheckedSubscribe(function(checked) {
					var undoGroup = [];
					bset.setFlipX(r, checked, undoGroup);
					tileroninX.saveUndoState(undoGroup);
				});
				//BSETCALLBACK
				var bsetContentCallbackFunc = function() {
					pX.setCheckbox(bset.getFlipX(r));
				}
				this.registeredCallbacks.push({bset:bset, callback:bsetContentCallbackFunc});
				bset.contentUpdatedSubscribe(bsetContentCallbackFunc);
				return pX;
			}

			var createPropertyFlipY = function(bset, r) {
				var pY = new PropertyCheckboxView("Flip Y", bset.getFlipY(r));
				pY.boxCheckedSubscribe(function(checked) {
					var undoGroup = [];
					bset.setFlipY(r, checked, undoGroup);
					tileroninX.saveUndoState(undoGroup);
				});
				//BSETCALLBACK
				var bsetContentCallbackFunc = function() {
					pY.setCheckbox(bset.getFlipY(r));
				}
				this.registeredCallbacks.push({bset:bset, callback:bsetContentCallbackFunc});
				bset.contentUpdatedSubscribe(bsetContentCallbackFunc);
				return pY;
			}

			var createPropertyCutoff = function(bset, r) {
				var directionName = ["Up", "Right", "Down", "Left"];

				var pCo = new PropertyEditTextView(directionName[r]+" Cutoff", bset.getCutoff(r), "px", true);
				pCo.getDiv().children[1].style.borderColor = "var(--color1)"
				pCo.valueChangedSubscribe(function(value) {
					var undoGroup = [];
					bset.setCutoff(r, parseInt(value), undoGroup);
					tileroninX.saveUndoState(undoGroup);
				});
				//BSETCALLBACK
				var bsetContentCallbackFunc = function() {
					pCo.setValue(bset.getCutoff(r));
				}
				this.registeredCallbacks.push({bset:bset, callback:bsetContentCallbackFunc});
				bset.contentUpdatedSubscribe(bsetContentCallbackFunc);
				return pCo;
			}

			var bcmp = bgen.getComponents();
			for(var c = 0; c < bcmp.length; c++) {
				(function(c) {
					var cmp = bcmp[c];

					var propertyGroup = document.createElement('div');
					propertyGroup.className = "tileproperties-propertygroup-view";
					this.compositionContainer.addDiv(propertyGroup);

					if(cmp.t == 0) {
						propertyGroup.appendChild(createPropertySource.bind(this)(cmp.bset, cmp.r).getDiv());
						if(!iso) {
							propertyGroup.appendChild(createPropertyRotation.bind(this)(cmp.bset, cmp.r).getDiv());
						}
						propertyGroup.appendChild(createPropertyFlipX.bind(this)(cmp.bset, cmp.r).getDiv());
						propertyGroup.appendChild(createPropertyFlipY.bind(this)(cmp.bset, cmp.r).getDiv());
						propertyGroup.appendChild(createPropertyCutoff.bind(this)(cmp.bset, cmp.r).getDiv());
					} else if(cmp.t == 1) {
						var pC = new PropertyCheckboxView("Composite", cmp.bset.getComposite(cmp.r+4));
						pC.boxCheckedSubscribe(function(checked) {
							var undoGroup = [];
							cmp.bset.setComposite(cmp.r+4, checked, undoGroup);
							tileroninX.saveUndoState(undoGroup);
							pS.setEnabled(!checked);
							if(!iso) {
								pR.setEnabled(!checked);
							}
							pX.setEnabled(!checked);
							pY.setEnabled(!checked);
						});
						propertyGroup.appendChild(pC.getDiv());
						//BSETCALLBACK
						var bsetContentCallbackFunc = function() {
							var checked = cmp.bset.getComposite(cmp.r+4);
							pC.setCheckbox(checked);
							pS.setEnabled(!checked);
							if(!iso) {
								pR.setEnabled(!checked);
							}
							pX.setEnabled(!checked);
							pY.setEnabled(!checked);
						}
						this.registeredCallbacks.push({bset:cmp.bset, callback:bsetContentCallbackFunc});
						cmp.bset.contentUpdatedSubscribe(bsetContentCallbackFunc);

						var pS = createPropertySource.bind(this)(cmp.bset, cmp.r+4);
						if(!iso) {
							var pR = createPropertyRotation.bind(this)(cmp.bset, cmp.r+4);
						}
						var pX = createPropertyFlipX.bind(this)(cmp.bset, cmp.r+4);
						var pY = createPropertyFlipY.bind(this)(cmp.bset, cmp.r+4);
						var pCo0 = createPropertyCutoff.bind(this)(cmp.bset, cmp.r);
						var pCo1 = createPropertyCutoff.bind(this)(cmp.bset, (cmp.r+3)%4);
						propertyGroup.appendChild(pS.getDiv());
						if(!iso) {
							propertyGroup.appendChild(pR.getDiv());
						}
						propertyGroup.appendChild(pX.getDiv());
						propertyGroup.appendChild(pY.getDiv());
						propertyGroup.appendChild(pCo0.getDiv());
						propertyGroup.appendChild(pCo1.getDiv());
						pS.setEnabled(!(cmp.bset.getComposite(cmp.r+4)));
						if(!iso) {
							pR.setEnabled(!(cmp.bset.getComposite(cmp.r+4)));
						}
						pX.setEnabled(!(cmp.bset.getComposite(cmp.r+4)));
						pY.setEnabled(!(cmp.bset.getComposite(cmp.r+4)));
					} else if(cmp.t == 2) {
						var pC = new PropertyCheckboxView("Composite", cmp.bset.getComposite(cmp.r+8));
						pC.boxCheckedSubscribe(function(checked) {
							var undoGroup = [];
							cmp.bset.setComposite(cmp.r+8, checked, undoGroup);
							tileroninX.saveUndoState(undoGroup);
							pS.setEnabled(!checked);
							if(!iso) {
								pR.setEnabled(!checked);
							}
							pX.setEnabled(!checked);
							pY.setEnabled(!checked);
						});
						propertyGroup.appendChild(pC.getDiv());
						//BSETCALLBACK
						var bsetContentCallbackFunc = function() {
							var checked = cmp.bset.getComposite(cmp.r+8);
							pC.setCheckbox(checked);
							pS.setEnabled(!checked);
							if(!iso) {
								pR.setEnabled(!checked);
							}
							pX.setEnabled(!checked);
							pY.setEnabled(!checked);
						}
						this.registeredCallbacks.push({bset:cmp.bset, callback:bsetContentCallbackFunc});
						cmp.bset.contentUpdatedSubscribe(bsetContentCallbackFunc);

						var pS = createPropertySource.bind(this)(cmp.bset, cmp.r+8);
						if(!iso) {
							var pR = createPropertyRotation.bind(this)(cmp.bset, cmp.r+8);
						}
						var pX = createPropertyFlipX.bind(this)(cmp.bset, cmp.r+8);
						var pY = createPropertyFlipY.bind(this)(cmp.bset, cmp.r+8);
						var pCo0 = createPropertyCutoff.bind(this)(cmp.bset, cmp.r);
						var pCo1 = createPropertyCutoff.bind(this)(cmp.bset, (cmp.r+3)%4);
						propertyGroup.appendChild(pS.getDiv());
						if(!iso) {
							propertyGroup.appendChild(pR.getDiv());
						}
						propertyGroup.appendChild(pX.getDiv());
						propertyGroup.appendChild(pY.getDiv());
						propertyGroup.appendChild(pCo0.getDiv());
						propertyGroup.appendChild(pCo1.getDiv());
						pS.setEnabled(!(cmp.bset.getComposite(cmp.r+8)));
						if(!iso) {
							pR.setEnabled(!(cmp.bset.getComposite(cmp.r+8)));
						}
						pX.setEnabled(!(cmp.bset.getComposite(cmp.r+8)));
						pY.setEnabled(!(cmp.bset.getComposite(cmp.r+8)));
					}

					if(c < bcmp.length-1) {
						this.compositionContainer.addDiv((new PropertySeparatorView()).getDiv());
					}
				}.bind(this))(c);
			}
		} else if(bgen instanceof BorderGeneratorBlob) {

			var createPropertySource = function(bset, r) {
				var pS = new PropertySourceView("Source", bset.getSource(r));
				pS.sourceOpenedSubscribe(function(src) {
					this.sourceOpenedCallback.notify(src);
				}.bind(this));
				pS.tooltipSubscribe(function(msg) {
					this.tooltipCallback.notify(msg);
				}.bind(this));
				pS.sourceChangedSubscribe(function(src) {
					var undoGroup = [];
					bset.setSource(r, src, undoGroup);
					tileroninX.saveUndoState(undoGroup);
				}.bind(this));
				pS.sourcePickingSubscribe(function(fn) {
					this.borderSlotClickedCallback.notify(fn);
				}.bind(this));
				//BSETCALLBACK
				var bsetContentCallbackFunc = function() {
					pS.setSource(bset.getSource(r));
				}
				this.registeredCallbacks.push({bset:bset, callback:bsetContentCallbackFunc});
				bset.contentUpdatedSubscribe(bsetContentCallbackFunc);
				return pS;
			}

			var createPropertyRotation = function(bset, r) {
				var pR = new PropertyDiscreteSliderView("Rotation", 4, bset.getRotation(r));
				pR.sliderChangedSubscribe(function(position) {
					var undoGroup = [];
					bset.setRotation(r, position, undoGroup);
					tileroninX.saveUndoState(undoGroup);
				});
				//BSETCALLBACK
				var bsetContentCallbackFunc = function() {
					pR.setSlider(bset.getRotation(r));
				}
				this.registeredCallbacks.push({bset:bset, callback:bsetContentCallbackFunc});
				bset.contentUpdatedSubscribe(bsetContentCallbackFunc);
				return pR
			}

			var createPropertyFlipX = function(bset, r) {
				var pX = new PropertyCheckboxView("Flip X", bset.getFlipX(r));
				pX.boxCheckedSubscribe(function(checked) {
					var undoGroup = [];
					bset.setFlipX(r, checked, undoGroup);
					tileroninX.saveUndoState(undoGroup);
				});
				//BSETCALLBACK
				var bsetContentCallbackFunc = function() {
					pX.setCheckbox(bset.getFlipX(r));
				}
				this.registeredCallbacks.push({bset:bset, callback:bsetContentCallbackFunc});
				bset.contentUpdatedSubscribe(bsetContentCallbackFunc);
				return pX;
			}

			var createPropertyFlipY = function(bset, r) {
				var pY = new PropertyCheckboxView("Flip Y", bset.getFlipY(r));
				pY.boxCheckedSubscribe(function(checked) {
					var undoGroup = [];
					bset.setFlipY(r, checked, undoGroup);
					tileroninX.saveUndoState(undoGroup);
				});
				//BSETCALLBACK
				var bsetContentCallbackFunc = function() {
					pY.setCheckbox(bset.getFlipY(r));
				}
				this.registeredCallbacks.push({bset:bset, callback:bsetContentCallbackFunc});
				bset.contentUpdatedSubscribe(bsetContentCallbackFunc);
				return pY;
			}

			var createPropertyCutoff = function(bset, r) {
				var directionName = ["Up", "Right", "Down", "Left"];

				var pCo = new PropertyEditTextView(directionName[r]+" Cutoff", bset.getCutoff(r), "px", true);
				pCo.getDiv().children[1].style.borderColor = "var(--color1)"
				pCo.valueChangedSubscribe(function(value) {
					var undoGroup = [];
					bset.setCutoff(r, parseInt(value), undoGroup);
					tileroninX.saveUndoState(undoGroup);
				});
				//BSETCALLBACK
				var bsetContentCallbackFunc = function() {
					pCo.setValue(bset.getCutoff(r));
				}
				this.registeredCallbacks.push({bset:bset, callback:bsetContentCallbackFunc});
				bset.contentUpdatedSubscribe(bsetContentCallbackFunc);
				return pCo;
			}

			var bcmp = bgen.getComponents();
			console.log(bcmp);
			for(var c = 0; c < bcmp.length; c++) {
				(function(c) {
					var cmp = bcmp[c];

					var propertyGroup = document.createElement('div');
					propertyGroup.className = "tileproperties-propertygroup-view";
					this.compositionContainer.addDiv(propertyGroup);

					if(cmp.t == 0) {
						propertyGroup.appendChild(createPropertySource.bind(this)(cmp.bset, cmp.r).getDiv());
						if(!iso) {
							propertyGroup.appendChild(createPropertyRotation.bind(this)(cmp.bset, cmp.r).getDiv());
						}
						propertyGroup.appendChild(createPropertyFlipX.bind(this)(cmp.bset, cmp.r).getDiv());
						propertyGroup.appendChild(createPropertyFlipY.bind(this)(cmp.bset, cmp.r).getDiv());
						propertyGroup.appendChild(createPropertyCutoff.bind(this)(cmp.bset, cmp.r).getDiv());
					} else if(cmp.t == 1) {
						var pC = new PropertyCheckboxView("Composite", cmp.bset.getComposite(cmp.r+4));
						pC.boxCheckedSubscribe(function(checked) {
							var undoGroup = [];
							cmp.bset.setComposite(cmp.r+4, checked, undoGroup);
							tileroninX.saveUndoState(undoGroup);
							pS.setEnabled(!checked);
							if(!iso) {
								pR.setEnabled(!checked);
							}
							pX.setEnabled(!checked);
							pY.setEnabled(!checked);
						});
						propertyGroup.appendChild(pC.getDiv());
						//BSETCALLBACK
						var bsetContentCallbackFunc = function() {
							var checked = cmp.bset.getComposite(cmp.r+4);
							pC.setCheckbox(checked);
							pS.setEnabled(!checked);
							if(!iso) {
								pR.setEnabled(!checked);
							}
							pX.setEnabled(!checked);
							pY.setEnabled(!checked);
						}
						this.registeredCallbacks.push({bset:cmp.bset, callback:bsetContentCallbackFunc});
						cmp.bset.contentUpdatedSubscribe(bsetContentCallbackFunc);

						var pS = createPropertySource.bind(this)(cmp.bset, cmp.r+4);
						if(!iso) {
							var pR = createPropertyRotation.bind(this)(cmp.bset, cmp.r+4);
						}
						var pX = createPropertyFlipX.bind(this)(cmp.bset, cmp.r+4);
						var pY = createPropertyFlipY.bind(this)(cmp.bset, cmp.r+4);
						var pCo0 = createPropertyCutoff.bind(this)(cmp.bset, cmp.r);
						var pCo1 = createPropertyCutoff.bind(this)(cmp.bset, (cmp.r+3)%4);
						propertyGroup.appendChild(pS.getDiv());
						if(!iso) {
							propertyGroup.appendChild(pR.getDiv());
						}
						propertyGroup.appendChild(pX.getDiv());
						propertyGroup.appendChild(pY.getDiv());
						propertyGroup.appendChild(pCo0.getDiv());
						propertyGroup.appendChild(pCo1.getDiv());
						pS.setEnabled(!(cmp.bset.getComposite(cmp.r+4)));
						if(!iso) {
							pR.setEnabled(!(cmp.bset.getComposite(cmp.r+4)));
						}
						pX.setEnabled(!(cmp.bset.getComposite(cmp.r+4)));
						pY.setEnabled(!(cmp.bset.getComposite(cmp.r+4)));
					} else if(cmp.t == 2) {
						var pC = new PropertyCheckboxView("Composite", cmp.bset.getComposite(cmp.r+8));
						pC.boxCheckedSubscribe(function(checked) {
							var undoGroup = [];
							cmp.bset.setComposite(cmp.r+8, checked, undoGroup);
							tileroninX.saveUndoState(undoGroup);
							pS.setEnabled(!checked);
							if(!iso) {
								pR.setEnabled(!checked);
							}
							pX.setEnabled(!checked);
							pY.setEnabled(!checked);
						});
						propertyGroup.appendChild(pC.getDiv());
						//BSETCALLBACK
						var bsetContentCallbackFunc = function() {
							var checked = cmp.bset.getComposite(cmp.r+8);
							pC.setCheckbox(checked);
							pS.setEnabled(!checked);
							if(!iso) {
								pR.setEnabled(!checked);
							}
							pX.setEnabled(!checked);
							pY.setEnabled(!checked);
						}
						this.registeredCallbacks.push({bset:cmp.bset, callback:bsetContentCallbackFunc});
						cmp.bset.contentUpdatedSubscribe(bsetContentCallbackFunc);

						var pS = createPropertySource.bind(this)(cmp.bset, cmp.r+8);
						if(!iso) {
							var pR = createPropertyRotation.bind(this)(cmp.bset, cmp.r+8);
						}
						var pX = createPropertyFlipX.bind(this)(cmp.bset, cmp.r+8);
						var pY = createPropertyFlipY.bind(this)(cmp.bset, cmp.r+8);
						var pCo0 = createPropertyCutoff.bind(this)(cmp.bset, cmp.r);
						var pCo1 = createPropertyCutoff.bind(this)(cmp.bset, (cmp.r+3)%4);
						propertyGroup.appendChild(pS.getDiv());
						if(!iso) {
							propertyGroup.appendChild(pR.getDiv());
						}
						propertyGroup.appendChild(pX.getDiv());
						propertyGroup.appendChild(pY.getDiv());
						propertyGroup.appendChild(pCo0.getDiv());
						propertyGroup.appendChild(pCo1.getDiv());
						pS.setEnabled(!(cmp.bset.getComposite(cmp.r+8)));
						if(!iso) {
							pR.setEnabled(!(cmp.bset.getComposite(cmp.r+8)));
						}
						pX.setEnabled(!(cmp.bset.getComposite(cmp.r+8)));
						pY.setEnabled(!(cmp.bset.getComposite(cmp.r+8)));
					}

					if(c < bcmp.length-1) {
						this.compositionContainer.addDiv((new PropertySeparatorView()).getDiv());
					}
				}.bind(this))(c);
			}
		}
	}
	updateTileRelations.bind(this)(tile);
}

var updateTileRelations = function(tile) { //TODO UPDATE ON TILE RELATIONS CHANGED CALLBACK
	var blobR = false;
	var blobNeighborR = false;
	var blobBorderR = false;
	var wangR = false;
	var wangBorderR = false;
	var propR = false;
	var proxyR = false;
	var blobPre2_0_0R = false;
	var wangPre2_0_0R = false;
	var variationR = false;
	var rel = tile.getRelations();
	console.log(rel.length);
	for(var i in rel) {
		var r = rel[i];
		if(r.r instanceof TileRelationBlob && r.r.origin == tile) {
			blobR = true;
		}
		if(r.r instanceof TileRelationBlob && r.r.origin != tile) {
			blobNeighborR = true;
		}
		if(r.r instanceof TileRelationBlobBorder && r.r.isBorder) {
			blobBorderR = true;
		}
		if(r.r instanceof TileRelationWang) {
			wangR = true;
		}
		if(r.r instanceof TileRelationWangBorder && r.r.isBorder) {
			wangBorderR = true;
		}
		if(r.r instanceof TileRelationProp) {
			propR = true;
		}
		if(r.r instanceof TileRelationProxy && !r.r.isReverse) {
			proxyR = true;
		}
		if(r.r instanceof TileRelationBlobPre2_0_0) {
			blobPre2_0_0R = true;
		}
		if(r.r instanceof TileRelationWangPre2_0_0) {
			wangPre2_0_0R = true;
		}
		if(r.r instanceof TileRelationProxy && r.r.isReverse) {
			variationR = true;
		}
	}
	if(blobNeighborR) {
		if(this.blobNeighborRelationInterface == null) {
			this.blobNeighborRelationInterface = new PropertyRelationBlobNeighborView(tile);
			this.relationsContainer.addDiv(this.blobNeighborRelationInterface.getDiv());
			this.blobNeighborRelationInterface.relationDeletedSubscribe(function(other) {
				var undoGroup = [];
				tile.removeRelation(other, undoGroup);
				tileroninX.saveUndoState(undoGroup);
			});
		}
	} else {
		if(this.blobNeighborRelationInterface != null) {
			this.blobNeighborRelationInterface.getDiv().parentNode.removeChild(this.blobNeighborRelationInterface.getDiv());
			this.blobNeighborRelationInterface.clearCallbacks();
			this.blobNeighborRelationInterface = null;
		}
	}
	if(blobR) {
		if(this.blobRelationInterface == null) {
			this.blobRelationInterface = new PropertyRelationBlobView(tile);
			this.relationsContainer.addDiv(this.blobRelationInterface.getDiv());
			this.blobRelationInterface.relationDeletedSubscribe(function(other) {
				var undoGroup = [];
				tile.removeRelation(other, undoGroup);
				tileroninX.saveUndoState(undoGroup);
			});
			this.blobRelationInterface.slotClickedSubscribe(function(fn) {
				this.borderSlotClickedCallback.notify(fn);
			}.bind(this));
		}
	} else {
		if(this.blobRelationInterface != null) {
			this.blobRelationInterface.getDiv().parentNode.removeChild(this.blobRelationInterface.getDiv());
			this.blobRelationInterface.clearCallbacks();
			this.blobRelationInterface = null;
		}
	}
	if(blobBorderR) {
		if(this.blobBorderRelationInterface == null) {
			this.blobBorderRelationInterface = new PropertyRelationBlobBorderView(tile);
			this.relationsContainer.addDiv(this.blobBorderRelationInterface.getDiv());
			this.blobBorderRelationInterface.borderRemovedSubscribe(function() {
				var origin;
				var im;
				var tRel = tile.getRelations();
				for(var i in tRel) {
					var rel = tRel[i];
					if(rel.r instanceof TileRelationBlobBorder) {
						origin = rel.t;
						im = rel.r.getIndexMatrix();
						break;
					}
				}
				var undoGroup = [];
				tileroninX.replaceBlobBorder(origin, im, null, undoGroup);
				tileroninX.saveUndoState(undoGroup);
			});
		}
	} else {
		if(this.blobBorderRelationInterface != null) {
			this.blobBorderRelationInterface.getDiv().parentNode.removeChild(this.blobBorderRelationInterface.getDiv());
			this.blobBorderRelationInterface.clearCallbacks();
			this.blobBorderRelationInterface = null;
		}
	}
	if(wangR) {
		if(this.wangRelationInterface == null) {
			this.wangRelationInterface = new PropertyRelationWangView(tile);
			this.relationsContainer.addDiv(this.wangRelationInterface.getDiv());
			this.wangRelationInterface.relationDeletedSubscribe(function(other) {
				var undoGroup = [];
				tile.removeRelation(other, undoGroup);
				tileroninX.saveUndoState(undoGroup);
			});
			this.wangRelationInterface.slotClickedSubscribe(function(fn) {
				this.borderSlotClickedCallback.notify(fn);
			}.bind(this));
		}
	} else {
		if(this.wangRelationInterface != null) {
			this.wangRelationInterface.getDiv().parentNode.removeChild(this.wangRelationInterface.getDiv());
			this.wangRelationInterface.clearCallbacks();
			this.wangRelationInterface = null;
		}
	}
	if(wangBorderR) {
		if(this.wangBorderRelationInterface == null) {
			this.wangBorderRelationInterface = new PropertyRelationWangBorderView(tile);
			this.relationsContainer.addDiv(this.wangBorderRelationInterface.getDiv());
			this.wangBorderRelationInterface.borderRemovedSubscribe(function() {
				var im;
				var tRel = tile.getRelations();
				for(var i in tRel) {
					var rel = tRel[i];
					if(rel.r instanceof TileRelationWangBorder) {
						im = rel.r.getIndexMatrix();
						break;
					}
				}
				var undoGroup = [];
				tileroninX.replaceWangBorder(im, null, undoGroup);
				tileroninX.saveUndoState(undoGroup);
			});
		}
	} else {
		if(this.wangBorderRelationInterface != null) {
			this.wangBorderRelationInterface.getDiv().parentNode.removeChild(this.wangBorderRelationInterface.getDiv());
			this.wangBorderRelationInterface.clearCallbacks();
			this.wangBorderRelationInterface = null;
		}
	}
	if(propR) {
		if(this.propRelationInterface == null) {
			this.propRelationInterface = new PropertyRelationPropView(tile);
			this.relationsContainer.addDiv(this.propRelationInterface.getDiv());
			this.propRelationInterface.propUngroupedSubscribe(function() {
				var undoGroup = [];
				tileroninX.ungroupProp(tile, undoGroup);
				tileroninX.saveUndoState(undoGroup);
			});
			this.propRelationInterface.slotClickedSubscribe(function(fn) {
				this.borderSlotClickedCallback.notify(fn);
			}.bind(this));
		}
	} else {
		if(this.propRelationInterface != null) {
			this.propRelationInterface.getDiv().parentNode.removeChild(this.propRelationInterface.getDiv());
			this.propRelationInterface.clearCallbacks();
			this.propRelationInterface = null;
		}
	}
	if(proxyR) {
		if(this.proxyRelationInterface == null) {
			this.proxyRelationInterface = new PropertyRelationProxyView(tile);
			this.relationsContainer.addDiv(this.proxyRelationInterface.getDiv());
			this.proxyRelationInterface.slotClickedSubscribe(function(fn) {
				this.borderSlotClickedCallback.notify(fn);
			}.bind(this));
		}
	} else {
		if(this.proxyRelationInterface != null) {
			this.proxyRelationInterface.getDiv().parentNode.removeChild(this.proxyRelationInterface.getDiv());
			this.proxyRelationInterface.clearCallbacks();
			this.proxyRelationInterface = null;
		}
	}
	if(blobPre2_0_0R) {
		if(this.blobPre2_0_0RelationInterface == null) {
			this.blobPre2_0_0RelationInterface = new PropertyRelationBlobPre2_0_0View(tile);
			this.relationsContainer.addDiv(this.blobPre2_0_0RelationInterface.getDiv());
			this.blobPre2_0_0RelationInterface.slotClickedSubscribe(function(fn) {
				this.borderSlotClickedCallback.notify(fn);
			}.bind(this));
		}
	} else {
		if(this.blobPre2_0_0RelationInterface != null) {
			this.blobPre2_0_0RelationInterface.getDiv().parentNode.removeChild(this.blobPre2_0_0RelationInterface.getDiv());
			this.blobPre2_0_0RelationInterface.clearCallbacks();
			this.blobPre2_0_0RelationInterface = null;
		}
	}
	if(wangPre2_0_0R) {
		if(this.wangPre2_0_0RelationInterface == null) {
			this.wangPre2_0_0RelationInterface = new PropertyRelationWangPre2_0_0View(tile);
			this.relationsContainer.addDiv(this.wangPre2_0_0RelationInterface.getDiv());
			this.wangPre2_0_0RelationInterface.slotClickedSubscribe(function(fn) {
				this.borderSlotClickedCallback.notify(fn);
			}.bind(this));
		}
	} else {
		if(this.wangPre2_0_0RelationInterface != null) {
			this.wangPre2_0_0RelationInterface.getDiv().parentNode.removeChild(this.wangPre2_0_0RelationInterface.getDiv());
			this.wangPre2_0_0RelationInterface.clearCallbacks();
			this.wangPre2_0_0RelationInterface = null;
		}
	}
	if(variationR) {
		if(this.variationRelationInterface == null) {
			this.variationRelationInterface = new PropertyRelationVariationView(tile);
			this.relationsContainer.addDiv(this.variationRelationInterface.getDiv());
		}
	} else {
		if(this.variationRelationInterface != null) {
			this.variationRelationInterface.getDiv().parentNode.removeChild(this.variationRelationInterface.getDiv());
			this.variationRelationInterface.clearCallbacks();
			this.variationRelationInterface = null;
		}
	}
}

class TilePropertiesView {
	constructor() {
		this.div = document.createElement('div');
		this.div.className = "tileproperties-view";

		this.titleDiv = document.createElement('div');
		this.titleDiv.className = 'tileproperties-title-view';
		this.titleDiv.innerHTML = "No tile selected";
		this.div.appendChild(this.titleDiv);

		this.tileDisplay = new TileDisplayView();
		this.div.appendChild(this.tileDisplay.getDiv());

		this.propertyContainer = document.createElement('div');
		this.propertyContainer.className = "tileproperties-propertycontainer-view";
		this.div.appendChild(this.propertyContainer);

		this.sourceOpenedCallback = new CallbackManager();
		this.borderSlotClickedCallback = new CallbackManager();
		this.tooltipCallback = new CallbackManager();

		this.loadedTileCallback = null;
		this.loadedTileCallbackRelation = null;
		this.registeredCallbacks = [];

		this.compositionExpanded = true;
		this.compositionContainer = null;

		this.relationsExpanded = true;
		this.relationsContainer = null;

		this.blobRelationInterface = null;
		this.blobNeighborRelationInterface = null;
		this.blobBorderRelationInterface = null;
		this.wangRelationInterface = null;
		this.wangBorderRelationInterface = null;
		this.propRelationInterface = null;
		this.proxyRelationInterface = null;
		this.blobPre2_0_0RelationInterface = null;
		this.wangPre2_0_0RelationInterface = null;
		this.variationRelationInterface = null;
	}

	loadTiles(tiles) {
		if(this.compositionContainer != null) {
			this.compositionExpanded = this.compositionContainer.isExpanded();
			this.compositionContainer = null;
		}
		if(this.relationsContainer != null) {
			this.relationsExpanded = this.relationsContainer.isExpanded();
			this.relationsContainer = null;
		}
		if(this.loadedTileCallback != null) {
			this.loadedTileCallback[0].contentUpdatedUnsubscribe(this.loadedTileCallback[1]);
		}
		if(this.loadedTileCallbackRelation != null) {
			this.loadedTileCallbackRelation[0].relationsUpdatedUnsubscribe(this.loadedTileCallbackRelation[1]);
		}
		for(var i in this.registeredCallbacks) {
			this.registeredCallbacks[i].bset.contentUpdatedUnsubscribe(this.registeredCallbacks[i].callback);
		}
		this.registeredCallbacks = [];

		if(this.blobRelationInterface != null) {
			this.blobRelationInterface.clearCallbacks();
			this.blobRelationInterface = null;
		}
		if(this.blobNeighborRelationInterface != null) {
			this.blobNeighborRelationInterface.clearCallbacks();
			this.blobNeighborRelationInterface = null;
		}
		if(this.blobBorderRelationInterface != null) {
			this.blobBorderRelationInterface.clearCallbacks();
			this.blobBorderRelationInterface = null;
		}
		if(this.wangRelationInterface != null) {
			this.wangRelationInterface.clearCallbacks();
			this.wangRelationInterface = null;
		}
		if(this.wangBorderRelationInterface != null) {
			this.wangBorderRelationInterface.clearCallbacks();
			this.wangBorderRelationInterface = null;
		}
		if(this.propRelationInterface != null) {
			this.propRelationInterface.clearCallbacks();
			this.propRelationInterface = null;
		}
		if(this.proxyRelationInterface != null) {
			this.proxyRelationInterface.clearCallbacks();
			this.proxyRelationInterface = null;
		}
		if(this.blobPre2_0_0RelationInterface != null) {
			this.blobPre2_0_0RelationInterface.clearCallbacks();
			this.blobPre2_0_0RelationInterface = null;
		}
		if(this.wangPre2_0_0RelationInterface != null) {
			this.wangPre2_0_0RelationInterface.clearCallbacks();
			this.wangPre2_0_0RelationInterface = null;
		}
		if(this.variationRelationInterface != null) {
			this.variationRelationInterface.clearCallbacks();
			this.variationRelationInterface = null;
		}

		this.propertyContainer.innerHTML = "";
		if(tiles.length == 1) {
			var compositionContainer = new PropertyCollapserView("Composition", this.compositionExpanded);
			this.compositionContainer = compositionContainer;
			this.propertyContainer.appendChild(compositionContainer.getDiv());

			var relationsContainer = new PropertyCollapserView("Relations", this.relationsExpanded);
			this.relationsContainer = relationsContainer;
			this.propertyContainer.appendChild(relationsContainer.getDiv());

			var tile = tiles[0].tile;
			this.tileDisplay.setTile(tile);
			var callbackFunc = function() {
				this.tileDisplay.setTile(tile);
			}.bind(this);
			tile.contentUpdatedSubscribe(callbackFunc);
			this.loadedTileCallback = [tile, callbackFunc];

			var callbackFuncRelation = function() {
				updateTileRelations.bind(this)(tile);
			}.bind(this);
			tile.relationsUpdatedSubscribe(callbackFuncRelation);
			this.loadedTileCallbackRelation = [tile, callbackFuncRelation];

			loadTileConfig.bind(this)(tile);
		} else if(tiles.length == 0) {
			this.tileDisplay.setTile(null);
			this.loadedTileCallback = null;

			this.titleDiv.innerHTML = "No tile selected";
		} else if(tiles.length > 1) {
			this.tileDisplay.setTile(null);
			this.loadedTileCallback = null;

			this.titleDiv.innerHTML = "Multiple tiles selected";

			console.log(tiles[0].tile.getRelation(tiles[1].tile));
		}
	}

	getDiv() {
		return this.div;
	}

	sourceOpenedSubscribe(func) {
		this.sourceOpenedCallback.subscribe(func);
	}

	borderSlotClickedSubscribe(func) {
		this.borderSlotClickedCallback.subscribe(func);
	}

	tooltipSubscribe(func) {
		this.tooltipCallback.subscribe(func);
	}
}
module.exports = TilePropertiesView;