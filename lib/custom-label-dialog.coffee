module.exports =
  class CustomLabelDialog

    constructor: (src, selection, builder) ->
      @type = src
      @selection = selection
      @builder = builder
      @selection.insertText("Hello", {"select" : true})
