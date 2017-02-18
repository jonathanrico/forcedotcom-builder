{View, $$} = require 'space-pen'
{TextEditorView,SelectListView} = require 'atom-space-pen-views'

module.exports =
class CustomLabelDialogView extends View
  @content: ->
    @div class: 'custom-label-dialog-panel', =>
      @label "Label"
      @subview 'labelElement', new TextEditorView(mini: true)
      @label "API Name"
      @subview 'apiNameElement', new TextEditorView(mini: true)
      @label "Short Description"
      @subview 'shortDescElement', new TextEditorView(mini: true)
      @label "Language"
      @subview 'languageElement', new TextEditorView(mini: true)
      @label "Categories"
      @subview 'categoriesElement', new TextEditorView(mini: true)
      @button class: "btn btn-success create-btn disabled", outlet: "createButton", "Create Label"
      @button class: "btn btn-danger cancel-btn", outlet: "cancelButton", "Cancel"

  initialize: (dialog) ->
    @model = dialog;

    @apiNameElement.getModel().onDidChange () =>
      if @model
        if not @model.setApiName @apiNameElement.getModel().getText()
          @apiNameElement.getModel().undo()
        else
          if @model.setShortDesc @apiNameElement.getModel().getText()
            @shortDescElement.getModel().setText @apiNameElement.getModel().getText()
        @createAllow()

    @labelElement.getModel().onDidChange () =>
      if @model
        if not @model.setLabel @labelElement.getModel().getText()
          @labelElement.getModel().undo()
        else
          newApiName = @labelElement.getModel().getText().replace(/\s/g,'_').replace(/[^a-zA-Z0-9\_]/g,'')
          if @model.setApiName newApiName
            @apiNameElement.getModel().setText(newApiName)
        @createAllow()

    @shortDescElement.getModel().onDidChange () =>
      if @model
        if not @model.setShortDesc @shortDescElement.getModel().getText()
          @shortDescElement.getModel().undo()
        @createAllow()

    @languageElement.getModel().onDidChange () =>
      if @model
        if not @model.setLanguage @languageElement.getModel().getText()
          @languageElement.getModel().undo()
        @createAllow()

    @categoriesElement.getModel().onDidChange () =>
      if @model
        if not @model.setCategories @categoriesElement.getModel().getText()
          @categoriesElement.getModel().undo()
        @createAllow()

    @labelElement.getModel().getBuffer().setText(@model.label);
    @apiNameElement.getModel().getBuffer().setText(@model.apiName);
    @shortDescElement.getModel().getBuffer().setText(@model.shortDesc);
    @languageElement.getModel().getBuffer().setText(@model.language);
    @categoriesElement.getModel().getBuffer().setText(@model.categories);

    @createButton.on 'click', (e) =>
      @create();

    @cancelButton.on 'click', (e) =>
      @cancel();

    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show();
    @createAllow()

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
