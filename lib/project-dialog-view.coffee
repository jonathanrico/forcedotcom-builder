{View, $$} = require 'space-pen'

module.exports =
class ProjectDialogView extends View
  @content: ->
    @div class: 'project-dialog-panel', =>
      @label "Project Path:"
      @select class: "form-control", outlet: "projectPathElement"
      @button class: "btn btn-success create-btn disabled", outlet: "applyButton"
      @button class: "btn btn-danger cancel-btn", outlet: "cancelButton", "Cancel"

  initialize: (dialog) ->
    @model = dialog;

    #Set initial values
    @applyButton.text("Apply");

    for projectPath in @model.projectPaths
      thisOption = $$ ->
        @option value: projectPath, projectPath
      if projectPath == @model.selectedPath
        thisOption.attr "selected", "selected"
      @projectPathElement.append(thisOption);

    #Set methods
    @projectPathElement.on "change", (e) =>
      if @model
        @model.setProject @projectPathElement.val()
        @applyAllow()

    @applyButton.on 'click', (e) =>
      @apply()

    @cancelButton.on 'click', (e) =>
      @cancel();

    @applyAllow()

    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show();

  applyAllow: () ->
    if @model.applyCheck()
      @applyButton.removeClass('disabled')
    else
      @applyButton.addClass('disabled')

  apply: () ->
    if not @applyButton.hasClass 'disabled'
      @model.applyProject () =>
        @cancel()

  cancel: () ->
    @panel.destroy();
    delete @model
    delete this