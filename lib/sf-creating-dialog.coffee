SfCreatingDialogView = require './sf-creating-dialog-view'

module.exports =
  class SfCreatingDialog

    constructor: (itemType, builder) ->
      @builder = builder;
      @itemType = itemType;

      @label = itemType + ' Name';
      @apiName = itemType + '_Name';
      @apiVersions = ["39.0", "38.0", "37.0", "36.0"];
      @apiVersion = @apiVersions[0];

      @sfDialogView = new SfCreatingDialogView(this);

    checkLabel: (labelText) ->
      /^[a-zA-Z\d\s\_]*$/.test(labelText);

    checkApiName: (apiNameText) ->
      /^[a-zA-Z\d\_]*$/.test(apiNameText);

    checkApiVersion: (apiVersionText) ->
      /^\d{1,3}\.\d{1,2}$/.test(apiVersionText) && apiVersionText in @apiVersions;

    setLabel: (labelText) ->
      if @checkLabel labelText
        @label = labelText;
      @checkLabel labelText

    setApiName: (apiNameText) ->
      if @checkApiName apiNameText
        @apiName = apiNameText;
      @checkApiName apiNameText

    setApiVersion: (apiVersionText) ->
      if @checkApiVersion apiVersionText
        @apiVersion = apiVersionText;
      @checkApiVersion apiVersionText

    creatingCheck: () ->
      /^[a-zA-Z\d\s\_]+$/.test(@label) and /^[a-zA-Z\d\s\_]+$/.test(@apiName) and @checkApiVersion(@apiVersion)

    create: (callback) ->
      if @creatingCheck
        @builder.createSfItem this, callback
