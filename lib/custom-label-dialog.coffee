CustomLabelDialogView = require './custom-label-dialog-view'

module.exports =
  class CustomLabelDialog

    constructor: (src, editor, builder) ->
      @type = src
      @editor = editor
      @builder = builder

      if @editor
        @selection = @editor.getLastSelection()
        @label = @selection.getText()
      else
        @label = "Sample Label Text"
      @apiName = @label.replace(/\s/g,'_').replace(/[^a-zA-Z0-9\_]/g,'');
      @shortDesc = @apiName;
      @language = "en_US";
      @categories = "Learning General, Learning UI";

      @customLabelDialogView = new CustomLabelDialogView(this)

    setLabel: (t) ->
      if @checkLabel t
        @label = t;
      @checkLabel t

    setApiName: (t) ->
      if @checkApiName t
        @apiName = t;
      @checkApiName t

    setShortDesc: (t) ->
      if @checkLabel t
        @shortDesc = t;
      @checkLabel t

    setLanguage: (t) ->
      if @checkApiName t
        @language = t;
      @checkApiName t

    setCategories: (t) ->
      if @checkLabel t
        @categories = t;
      @checkLabel t

    checkLabel: (t) ->
      /^.*$/.test(t);

    checkApiName: (t) ->
      /^[a-zA-Z\d\_]*$/.test(t);

    creatingCheck: () ->
      /^.+$/.test(@label) and /^[a-zA-Z\d\_]+$/.test(@apiName) and /^.+$/.test(@shortDesc) and /^[a-zA-Z\d\_]+$/.test(@language) and /^.+$/.test(@categories)

    create: (callback) ->
      if @creatingCheck
        @builder.createCustomLabel this, callback
