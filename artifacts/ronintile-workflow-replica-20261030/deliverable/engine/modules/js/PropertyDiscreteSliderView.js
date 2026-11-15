var plh = require('./PointerLockHandler.js');
var CallbackManager = require('./CallbackManager.js');

var PropertyView = require('./PropertyView.js');

class PropertyDiscreteSliderView extends PropertyView {
	constructor(text, max, position) {
		super();
		this.div = document.createElement('div');
		this.div.className = "propertydiscreteslider-view";

		this.slots = [];
		this.slotsChecked = [];

		for(var i = 0; i < max; i++) {
			var slotDiv = document.createElement('div');
			slotDiv.className = "propertydiscreteslider-slot-view";
			this.div.appendChild(slotDiv);
			this.slots.push(slotDiv);
			var slotCheckedDiv = document.createElement('div');
			slotCheckedDiv.className = "propertydiscreteslider-slot-checked-view";
			slotDiv.appendChild(slotCheckedDiv);
			this.slotsChecked.push(slotCheckedDiv);

			if(i < max-1) {
				slotDiv.style.marginRight = 0;

				var separatorDiv = document.createElement('div');
				separatorDiv.className = "propertydiscreteslider-separator-view";
				this.div.appendChild(separatorDiv);
			}
		}

		this.textDiv = document.createElement('div');      
		this.textDiv.innerHTML = text;
		this.div.appendChild(this.textDiv);

		this.slotClicked = -1;
		this.setSlider.bind(this)(position);

		this.sliderChangedCallback = new CallbackManager();

		plh.applyPointerLock(this.div, function() {
			plh.lockPointer();
		}, null, function() {
			if(this.slotClicked != -1) {
				this.slots[this.slotClicked].style.borderColor = 'var(--color2)';
				this.slotsChecked[this.slotClicked].style.background = 'var(--color2)';
				this.setSlider.bind(this)(this.slotClicked);
				this.slotClicked = -1;
				this.sliderChangedCallback.notify(this.sliderPosition);
			}
		}.bind(this));

		for(var i = 0; i < this.slots.length; i++) {
			(function(i) {
				this.slots[i].addEventListener("mousedown", function(event) {
					event.preventDefault();
					if(this.enabled) {
						this.slotClicked = i;
						this.slots[i].style.borderColor = 'var(--colorSelect)';
						this.slotsChecked[i].style.background = 'var(--colorSelect)';
					}
				}.bind(this), false);
			}).bind(this)(i);
		}

		this.enabled = true;
	}

	getDiv() {
		return this.div;
	}

	sliderChangedSubscribe(func) {
		this.sliderChangedCallback.subscribe(func);
	}

	setEnabled(enabled) {
		this.enabled = enabled;
		if(!enabled) {
			this.textDiv.style.color = 'var(--color1)';
			for(var i = 0; i < this.slotsChecked.length; i++) {
				this.slots[i].style.borderColor = 'var(--color1)';
				this.slotsChecked[i].style.background = 'var(--color1)';
			}
		} else {
			this.textDiv.style.color = 'var(--color2)';
			for(var i = 0; i < this.slotsChecked.length; i++) {
				this.slots[i].style.borderColor = 'var(--color2)';
				this.slotsChecked[i].style.background = 'var(--color2)';
			}
		}
	}

	setSlider(position) {
		this.sliderPosition = position;
		for(var i = 0; i < this.slotsChecked.length; i++) {
			if(i != position) {
				this.slotsChecked[i].style.width = '0%';
				this.slotsChecked[i].style.height = '0%';
			} else {
				this.slotsChecked[i].style.width = '100%';
				this.slotsChecked[i].style.height = '100%';
			}
		}
	}
}
module.exports = PropertyDiscreteSliderView;