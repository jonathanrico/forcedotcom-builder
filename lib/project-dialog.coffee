ProjectDialogView = require './project-dialog-view'

module.exports =
  class ProjectDialog

    constructor: (builder, callback, callbackArgs) ->
      @builder = builder
      @callback = callback
      @callbackArgs = callbackArgs

      @projectPaths = atom.project.getPaths()
      @selectedPath = @projectPaths[0];

      @projectDialogView = new ProjectDialogView(this);

    checkProject: (selectedPath) ->
      selectedPath in @projectPaths

    setProject: (selectedPath) ->
      if @checkProject selectedPath
        @selectedPath = selectedPath
      @checkProject selectedPath

    applyCheck: () ->
      @checkProject(@selectedPath)

    applyProject: () ->
      @builder.root = @selectedPath
      @projectDialogView.panel.destroy()
      delete @projectDialogView
      if @callback
        @callback.apply(@builder, @callbackArgs)
      delete this

