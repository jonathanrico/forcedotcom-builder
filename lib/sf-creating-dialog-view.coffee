{View, $$} = require 'space-pen'
{TextEditorView} = require 'atom-space-pen-views'

module.exports =
class SfCreatingDialogView extends View
  @content: ->
    @div class: 'sf-dialog-panel', =>
      @label "Label"
      @subview 'labelElement', new TextEditorView(mini: true)
      @label "API Name"
      @subview 'apiNameElement', new TextEditorView(mini: true)
      @label "API Version"
      @select class: "form-control", outlet: "apiVersionElement"
      @button class: "btn btn-success create-btn disabled", outlet: "createButton"
      @button class: "btn btn-danger cancel-btn", outlet: "cancelButton", "Cancel"

  initialize: (dialog) ->
    @model = dialog;

    #Set initial values
    @createButton.text("Create " + @model.itemType);
    @labelElement.getModel().getBuffer().setText(@model.label);
    @apiNameElement.getModel().getBuffer().setText(@model.apiName);

    for apiVersionItem in @model.apiVersions
      thisOption = $$ ->
        @option value: apiVersionItem, apiVersionItem
      if apiVersionItem == @model.apiVersion
        thisOption.attr "selected", "selected"
      @apiVersionElement.append(thisOption);

    #Set methods
    @labelElement.getModel().onDidChange () =>
      if @model
        if not @model.setLabel @labelElement.getModel().getText()
          @labelElement.getModel().undo()
        else
          newApiName = @labelElement.getModel().getText().replace(/\s/g,'_')
          if @model.setApiName newApiName
            @apiNameElement.getModel().setText(newApiName)
        @createAllow()

    @apiNameElement.getModel().onDidChange () =>
      if @model
        if not @model.setApiName @apiNameElement.getModel().getText()
          @apiNameElement.getModel().undo()
        @createAllow()

    @apiVersionElement.on "change", (e) =>
      if @model
        @model.setApiVersion @apiVersionElement.val()
        @createAllow()

    @createButton.on 'click', (e) =>
      @create()

    @cancelButton.on 'click', (e) =>
      @cancel();

    @createAllow()

    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show();

  createAllow: () ->
    if @model.creatingCheck()
      @createButton.removeClass('disabled')
    else
      @createButton.addClass('disabled')

  create: () ->
    if not @createButton.hasClass 'disabled'
      @model.create () =>
        @cancel()

  cancel: () ->
    @panel.destroy();
    delete @model
    delete this