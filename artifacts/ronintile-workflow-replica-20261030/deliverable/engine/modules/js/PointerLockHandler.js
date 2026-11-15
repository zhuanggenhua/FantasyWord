var robotjs = require("../../robotjs");

var clientX = 0;
var clientY = 0;
var globalX = 0;
var globalY = 0;
var lock = false;

var inUse = false;

var zoomDivisor = function() {
	var z = parseFloat(document.body.style.zoom);
	return Number.isFinite(z) && z > 0 ? z : 1;
};

var applyPointerLock = function(div, downCallback, moveCallback, upCallback) {
	var usePointerCapture = typeof PointerEvent !== "undefined" && typeof div.setPointerCapture === "function";

	if(usePointerCapture) {
		var activePointerId = null;
		var sessionDone = false;

		var detachPointerListeners = function() {
			div.removeEventListener("pointermove", onPointerMove);
			div.removeEventListener("pointerup", finalizePointer);
			div.removeEventListener("pointercancel", finalizePointer);
			div.removeEventListener("lostpointercapture", finalizePointer);
			window.removeEventListener("blur", onWindowBlurPointer, false);
		};

		var cleanupPointer = function() {
			document.body.style.cursor = "default";
			if(lock) {
				robotjs.moveMouse(globalX, globalY);
				lock = false;
			}
			inUse = false;
			activePointerId = null;
		};

		var onPointerMove = function(event) {
			if(activePointerId != null && event.pointerId !== activePointerId) {
				return;
			}
			var z = zoomDivisor();
			var newCX = event.clientX / z;
			var newCY = event.clientY / z;
			event.scaledMovementX = newCX - clientX;
			event.scaledMovementY = newCY - clientY;
			clientX = newCX;
			clientY = newCY;
			if(moveCallback != null) {
				moveCallback(clientX, clientY, event);
			}
		};

		var finalizePointer = function(event) {
			if(sessionDone) {
				return;
			}
			if(activePointerId != null && event.pointerId !== activePointerId) {
				return;
			}
			sessionDone = true;
			detachPointerListeners();
			try {
				if(activePointerId != null && div.releasePointerCapture) {
					div.releasePointerCapture(activePointerId);
				}
			} catch(e) {
				// 已释放或非当前捕获时忽略
			}
			if(upCallback != null) {
				upCallback(clientX, clientY, event);
			}
			cleanupPointer();
		};

		var onWindowBlurPointer = function() {
			if(!inUse || sessionDone) {
				return;
			}
			sessionDone = true;
			try {
				if(activePointerId != null && div.releasePointerCapture) {
					div.releasePointerCapture(activePointerId);
				}
			} catch(e) {
				// ignore
			}
			detachPointerListeners();
			if(upCallback != null) {
				upCallback(clientX, clientY, { type: "blur" });
			}
			cleanupPointer();
		};

		div.addEventListener("pointerdown", function(event) {
			if(!event.isPrimary || inUse) {
				return;
			}
			sessionDone = false;
			inUse = true;
			activePointerId = event.pointerId;
			try {
				div.setPointerCapture(event.pointerId);
			} catch(e) {
				inUse = false;
				activePointerId = null;
				return;
			}
			document.body.style.cursor = "none";
			var cursor = robotjs.getMousePos();
			globalX = cursor.x;
			globalY = cursor.y;
			var z = zoomDivisor();
			clientX = event.clientX / z;
			clientY = event.clientY / z;
			if(downCallback != null) {
				downCallback(clientX, clientY, event);
			}
			div.addEventListener("pointermove", onPointerMove);
			div.addEventListener("pointerup", finalizePointer);
			div.addEventListener("pointercancel", finalizePointer);
			div.addEventListener("lostpointercapture", finalizePointer);
			window.addEventListener("blur", onWindowBlurPointer, false);
		}, false);
		return;
	}

	var mouseMove = function(event) {
		var z = zoomDivisor();
		var newCX = event.clientX / z;
		var newCY = event.clientY / z;
		event.scaledMovementX = newCX - clientX;
		event.scaledMovementY = newCY - clientY;

		clientX = newCX;
		clientY = newCY;
		if(moveCallback != null) {
			moveCallback(clientX, clientY, event);
		}
	}

	var mouseUp = function(event) {
		document.body.style.cursor = "default";
		if(upCallback != null) {
			upCallback(clientX, clientY, event);
		}
		if(lock) {
			robotjs.moveMouse(globalX, globalY);
			lock = false;
		}
		document.removeEventListener("mousemove", mouseMove, false);
		document.removeEventListener("mouseup", mouseUp, false);
		window.removeEventListener("blur", onWindowBlur, false);
		inUse = false;
	}

	var onWindowBlur = function() {
		if(!inUse) {
			return;
		}
		document.body.style.cursor = "default";
		document.removeEventListener("mousemove", mouseMove, false);
		document.removeEventListener("mouseup", mouseUp, false);
		window.removeEventListener("blur", onWindowBlur, false);
		if(upCallback != null) {
			upCallback(clientX, clientY, { type: "blur" });
		}
		if(lock) {
			robotjs.moveMouse(globalX, globalY);
			lock = false;
		}
		inUse = false;
	}
	
	div.addEventListener("mousedown", function(event) {
		if(!inUse) {
			inUse = true;
			document.body.style.cursor = "none";
			var cursor = robotjs.getMousePos();
			globalX = cursor.x;
			globalY = cursor.y;
			var z = zoomDivisor();
			clientX = event.clientX / z;
			clientY = event.clientY / z;
			if(downCallback != null) {
				downCallback(clientX, clientY, event);
			}
			document.addEventListener("mousemove", mouseMove, false);
    		document.addEventListener("mouseup", mouseUp, false);
			window.addEventListener("blur", onWindowBlur, false);
		}
	}, false);
}
exports.applyPointerLock = applyPointerLock;

var lockPointer = function() {
	lock = true;
}
exports.lockPointer = lockPointer;
