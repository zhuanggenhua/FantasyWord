var plh = require('./PointerLockHandler.js');
var CallbackManager = require('./CallbackManager.js');

var PropertyView = require('./PropertyView.js');

class PropertyEditTextView extends PropertyView {
	constructor(text, value, suffix, numeric=false, slideMin=null, slideMax=null) {
		super();
		this.div = document.createElement('div');
		this.div.className = "propertyedittext-view";

		this.textDiv = document.createElement('div');
		this.textDiv.style.whiteSpace = "nowrap";
		this.textDiv.innerHTML = text+":";
		this.div.appendChild(this.textDiv);

		var displayDiv = document.createElement('div');
		displayDiv.className = "propertyedittext-display-view";
		this.div.appendChild(displayDiv);

		this.textDivDisplay = document.createElement('input');
		this.textDivDisplay.className = "propertyedittext-input-view";
		this.textDivDisplay.type = "text";
		this.textDivDisplay.style.pointerEvents = 'none';
		this.textDivDisplay.value = value;
		this.textDivDisplay.tabIndex = '-1';
		displayDiv.appendChild(this.textDivDisplay);

		this.suffixDivDisplay = document.createElement('div');
		this.suffixDivDisplay.className = "propertyedittext-suffix-view";
		this.suffixDivDisplay.innerHTML = suffix;
		displayDiv.appendChild(this.suffixDivDisplay);

		this.valueChangedCallback = new CallbackManager();

		this.numeric = numeric;

		this.dragStart = null;
		this.originalValue = null;

		plh.applyPointerLock(this.div, function(clientX, clientY) {
			plh.lockPointer();
			if(!this.enabled) { return; }
			if(numeric && slideMin != null && slideMax != null) {
				this.dragStart = clientX;
			}
			this.textDivDisplay.style.color = "var(--colorSelect)";
		}.bind(this), function(clientX, clientY) {
			if(!this.enabled) { return; }
			if(numeric && slideMin != null && slideMax != null) {
				var delta = Math.floor((clientX-this.dragStart)/16.0);
				if(delta < 0) {
					delta += 1;
				}
				if(delta != 0 && this.originalValue == null) {
					this.originalValue = parseInt(this.textDivDisplay.value);
					this.textDivDisplay.value = Math.min(Math.max(this.originalValue+delta, slideMin), slideMax);
					this.textDivDisplay.style.color = "var(--color2)";
				} else if(this.originalValue != null) {
					this.textDivDisplay.value = Math.min(Math.max(this.originalValue+delta, slideMin), slideMax);
				}
			}
		}.bind(this), function() {
			if(!this.enabled) { return; }
			this.textDivDisplay.style.color = "var(--color2)";
			if(this.originalValue == null) {
				this.textDivDisplay.focus();
				this.textDivDisplay.setSelectionRange(0, this.textDivDisplay.value.length);
			} else {
				this.setValue(this.textDivDisplay.value);
				this.valueChangedCallback.notify(this.textDivDisplay.value);
			}
			this.dragStart = null;
			this.originalValue = null;
		}.bind(this));

		this.textDivDisplay.addEventListener("keyup", function(event) {
			event.preventDefault();
			if(event.keyCode == 13) {
		        this.textDivDisplay.blur();
		    }
		}.bind(this), false);

		this.textDivDisplay.addEventListener("focusout", function(event) {
			event.preventDefault();
			this.setValue(this.textDivDisplay.value);
			this.valueChangedCallback.notify(this.textDivDisplay.value);
		}.bind(this), false);

		this.enabled = true;
	}

	getDiv() {
		return this.div;
	}

	valueChangedSubscribe(func) {
		this.valueChangedCallback.subscribe(func);
	}

	setEnabled(enabled) {
		this.enabled = enabled;
		if(!enabled) {
			this.textDiv.style.color = 'var(--color1)';
			this.textDivDisplay.style.color = 'var(--color1)';
			this.suffixDivDisplay.style.color = 'var(--color1)';
		} else {
			this.textDiv.style.color = '';
			this.textDivDisplay.style.color = 'var(--color2)';
			this.suffixDivDisplay.style.color = 'var(--color2)';
		}
	}

	getValue() {
		return this.textDivDisplay.value;
	}

	setValue(value) {
		this.textDivDisplay.value = value;
		if(this.numeric) {
			var numbers = this.textDivDisplay.value.match(/^-?\d+|\d+\b|\d+(?=\w)/g);
			if(numbers != null) {
				this.textDivDisplay.value = numbers[0];
			} else {
				this.textDivDisplay.value = '0';
			}
		}
	}

	setLabel(text) {
		this.textDiv.innerHTML = text+":";
	}

	offset(delta) {
		if(!this.numeric) {
			return;
		}
		this.setValue(parseInt(this.textDivDisplay.value) + delta);
		this.valueChangedCallback.notify(this.textDivDisplay.value);
	}
}
module.exports = PropertyEditTextView;