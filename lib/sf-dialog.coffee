SfDialogView = require './sf-dialog-view'

module.exports =
	class SfDialog

	  constructor: (itemType) ->
	  	@sfDialogView = new SfDialogView(this, itemType);