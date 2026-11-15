var CallbackManager = require('./CallbackManager.js');

var PropertyView = require('./PropertyView.js');
var PropertyEditTextView = require('./PropertyEditTextView.js');

class PropertyEditTextMultiView extends PropertyView {
	constructor(text, values, suffix, numeric=false) {
		super();
		this.div = document.createElement('div');
		this.div.className = "propertyedittextmulti-view";
		this.div.tabIndex = "1";

		this.inputs = [];
		this.fields = [];

		this.valueChangedCallback = new CallbackManager();

		for(var i = 0; i < values.length; i++) {
			var et = new PropertyEditTextView(text, values[i], suffix, numeric);
			this.inputs.push(et);
			var input = et.getDiv().children.item(1).children.item(0);
			this.fields.push(input);
			et.getDiv().style.margin = "0px";
			if(i == 0) {
				et.getDiv().children.item(1).style.borderRadius = "2px 0px 0px 2px";
			} else if(i == values.length-1) {
				et.getDiv().children.item(1).style.borderRadius = "0px 2px 2px 0px";
			} else {
				et.getDiv().children.item(1).style.borderRadius = "0px 0px 0px 0px";
			}
			if(i < values.length-1) {
				et.getDiv().children.item(1).style.marginRight = "1px";
			}
			if(i > 0) {
				et.getDiv().children.item(1).style.marginLeft = "0px";
				et.getDiv().removeChild(et.getDiv().children.item(0));
			}
			this.div.appendChild(et.getDiv());

			input.addEventListener("focusout", function(event) {
				event.preventDefault();
				//if(event.relatedTarget !== this.div) {
				if(!this.div.contains(event.relatedTarget)) {
					var newValues = [];
					for(var k = 0; k < this.inputs.length; k++) {
						newValues.push(this.inputs[k].getValue());
					}
					this.valueChangedCallback.notify(newValues);
				}
			}.bind(this), false);
		}

		this.div.addEventListener('keydown', function(event) {
			if(event.keyCode === 9) {
				for(var i = 0; i < this.fields.length; i++) {
					if(document.activeElement === this.fields[i]) {
						var idx = (i+1)%(this.fields.length);

						this.fields[idx].style.color = "var(--color2)";
						this.fields[idx].focus();
						this.fields[idx].setSelectionRange(0, this.fields[idx].value.length);

						break;
					}
				}
			}
		}.bind(this), false);
	}

	getDiv() {
		return this.div;
	}

	valueChangedSubscribe(func) {
		this.valueChangedCallback.subscribe(func);
	}

	setValues(values) {
		for(var i = 0; i < values.length; i++) {
			this.inputs[i].setValue(values[i]);
		}
	}
}
module.exports = PropertyEditTextMultiView;