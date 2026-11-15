var plh = require('./PointerLockHandler.js');
var CallbackManager = require('./CallbackManager.js');

var PropertyView = require('./PropertyView.js');

class PropertyCheckboxView extends PropertyView {
	constructor(text, checked=false) {
		super();
		this.div = document.createElement('div');
		this.div.className = "propertycheckbox-view";

		this.boxDiv = document.createElement('div');
		this.boxDiv.className = "propertycheckbox-box-view";
		this.div.appendChild(this.boxDiv);
		this.boxCheckedDiv = document.createElement('div');
		this.boxCheckedDiv.className = "propertycheckbox-box-checked-view";
		this.boxDiv.appendChild(this.boxCheckedDiv);

		this.textDiv = document.createElement('div');      
		this.textDiv.innerHTML = text;
		this.div.appendChild(this.textDiv);

		this.boxClicked = false;
		this.setCheckbox.bind(this)(checked);

		this.boxCheckedCallback = new CallbackManager();

		plh.applyPointerLock(this.div, function() {
			plh.lockPointer();
		}, null, function() {
			if(this.boxClicked) {
				this.boxDiv.style.borderColor = 'var(--color2)';
				this.boxCheckedDiv.style.background = 'var(--color2)';
				this.boxClicked = false;
				this.setCheckbox.bind(this)(!this.boxChecked);
				this.boxCheckedCallback.notify(this.boxChecked);
			}
		}.bind(this));

		this.boxDiv.addEventListener("mousedown", function(event) {
			event.preventDefault();
			if(this.enabled) {
				this.boxClicked = true;
				this.boxDiv.style.borderColor = 'var(--colorSelect)';
				this.boxCheckedDiv.style.background = 'var(--colorSelect)';
			}
		}.bind(this), false);

		this.enabled = true;
	}

	getDiv() {
		return this.div;
	}

	boxCheckedSubscribe(func) {
		this.boxCheckedCallback.subscribe(func);
	}

	setEnabled(enabled) {
		this.enabled = enabled;
		if(!enabled) {
			this.textDiv.style.color = 'var(--color1)';
			this.boxDiv.style.borderColor = 'var(--color1)';
			this.boxCheckedDiv.style.background = 'var(--color1)';
		} else {
			this.textDiv.style.color = 'var(--color2)';
			this.boxDiv.style.borderColor = 'var(--color2)';
			this.boxCheckedDiv.style.background = 'var(--color2)';
		}
	}

	setCheckbox(checked) {
		if(!checked) {
			this.boxChecked = false;
			this.boxCheckedDiv.style.width = '0%';
			this.boxCheckedDiv.style.height = '0%';
		} else {
			this.boxChecked = true;
			this.boxCheckedDiv.style.width = '100%';
			this.boxCheckedDiv.style.height = '100%';
		}
	}
}
module.exports = PropertyCheckboxView;