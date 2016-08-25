{TextEditorView, View} = require 'atom-space-pen-views'

labels =
	"common" :
		"cancelButton" : "Cancel"
	"class" :
		"createButton" : "Create Class"
	"page" :
		"createButton" : "Create Page"


module.exports =
class SfDialogView extends View
  @content: ->
    @div class: 'sf-dialog-panel', =>
      @label "Label"
      @subview 'labelItem', new TextEditorView(mini: true)
      @label "API Name"
      @subview 'apiNameItem', new TextEditorView(mini: true)
      @label "API Version"
      @select class: "form-control", outlet: "apiVersion", =>
      	@option value: "37.0", "37.0"
      @button class: "btn btn-success create-btn", outlet: "createButton"
      @button class: "btn btn-danger cancel-btn", outlet: "cancelButton", labels["common"]["cancelButton"]

  initialize: (dialog, itemType) ->
  	@modelDialog = dialog;
  	@type = itemType;

  	@createButton.text(labels[@type]["createButton"]);

  	@labelItem.getModel().getBuffer().onDidChange (oldRange, newRange, oldText, newText) =>
  		console.log(@labelItem.getModel().getText())

  	@createButton.on 'click', (e) =>
  		@create()

  	@cancelButton.on 'click', (e) =>
  		@cancel();

  	@panel ?= atom.workspace.addModalPanel(item: this)
  	@panel.show();

  create: () ->
  	alert(@labelItem.getModel().getText());

  cancel: () ->
  	@panel.destroy();