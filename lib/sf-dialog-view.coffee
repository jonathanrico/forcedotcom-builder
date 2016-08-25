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
      @div "Type your answer:"
      @subview 'answer', new TextEditorView(mini: true)
      @button class: "btn btn-success create-btn", outlet: "createButton"
      @button class: "btn btn-danger cancel-btn", outlet: "cancelButton", labels["common"]["cancelButton"]

  initialize: (dialog, itemType) ->
  	@modelDialog = dialog;
  	@type = itemType;

  	@createButton.text(labels[@type]["createButton"]);

  	@answer.getModel().getBuffer().onDidChange (oldRange, newRange, oldText, newText) =>
  		console.log(@answer.getModel().getText())

  	@createButton.on 'click', (e) =>
  		@create()

  	@cancelButton.on 'click', (e) =>
  		@cancel();

  	@panel ?= atom.workspace.addModalPanel(item: this)
  	@panel.show();

  create: () ->
  	alert(@answer.getModel().getText());

  cancel: () ->
  	@panel.destroy();