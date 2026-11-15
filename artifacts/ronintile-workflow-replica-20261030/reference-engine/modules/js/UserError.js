class UserError extends Error {
	constructor(errorGroup) {
		super("");
		this.errorGroup = errorGroup;
	}
}
module.exports = UserError;