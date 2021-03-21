child_process = require 'child_process'
fs = require 'fs'

module.exports =
  isWin: () ->
    /^win/.test process.platform

  getPlatformPath: (str) ->
    if @isWin() then str.replace /\//g, '\\' else str

  getSrcPath: (root) ->
    root + @getPlatformPath('/src/')

#-----------

  getSfCreatingItemParams: (sfCreatingDialog, root) ->
    params = {}
    params.srcPath = @getSrcPath(root)
    if sfCreatingDialog.itemType == "Class"
      params.metaDataType = "Apex" + sfCreatingDialog.itemType
      params.extension = "cls"
      params.fldPath = params.srcPath + @getPlatformPath('classes/')
      params.srcLines = ["public with sharing class " + sfCreatingDialog.apiName + " {\n    \n}"]
      params.metaLines = [
        "<apiVersion>" + sfCreatingDialog.apiVersion + "</apiVersion>"
        "<status>Active</status>"
      ]
    else if sfCreatingDialog.itemType == "Trigger"
      params.metaDataType = "Apex" + sfCreatingDialog.itemType
      params.extension = "trigger"
      params.fldPath = params.srcPath + @getPlatformPath('triggers/')
      params.srcLines = [
        "trigger " + sfCreatingDialog.apiName + " on SObject_Api_Name (before update) {"
        "    if (Trigger.isBefore) {"
        "        if (Trigger.isUpdate) {"
        "            "
        "        }"
        "    }"
        "}"
      ]
      params.metaLines = [
        "<apiVersion>" + sfCreatingDialog.apiVersion + "</apiVersion>"
        "<status>Active</status>"
      ]
    else if sfCreatingDialog.itemType == "Page"
      params.metaDataType = "Apex" + sfCreatingDialog.itemType
      params.extension = "page"
      params.fldPath = params.srcPath + @getPlatformPath('pages/')
      params.srcLines = ["<apex:page>\n    <h1>This is new page!</h1>\n</apex:page>"]
      params.metaLines = [
        "<apiVersion>" + sfCreatingDialog.apiVersion + "</apiVersion>"
        "<availableInTouch>false</availableInTouch>"
        "<confirmationTokenRequired>false</confirmationTokenRequired>"
        "<label>" + sfCreatingDialog.label + "</label>"
      ]
    else if sfCreatingDialog.itemType == "Component"
      params.extension = "component"
      params.fldPath = params.srcPath + @getPlatformPath('components/')
      params.srcLines = ["<apex:component>\n    <h1>This is new component!</h1>\n</apex:component>"]
      params.metaLines = [
        "<apiVersion>" + sfCreatingDialog.apiVersion + "</apiVersion>"
        "<label>" + sfCreatingDialog.label + "</label>"
      ]
    else if sfCreatingDialog.itemType == "LightningComponentBundle"
      params.metaDataType = sfCreatingDialog.itemType
      params.extension = "js"
      params.fldPath = params.srcPath + @getPlatformPath('lwc/' + sfCreatingDialog.apiName + '/')
      params.srcLines = ["import { LightningElement, track } from 'lwc';\n\nexport default class Hello extends LightningElement {\n    @track greeting = 'World';\n}"]
      params.metaLines = [
        "<apiVersion>" + sfCreatingDialog.apiVersion + "</apiVersion>"
        "<isExposed>true</isExposed>"
        "<targets>"
        "    <target>lightning__AppPage</target>"
        "    <target>lightning__RecordPage</target>"
        "    <target>lightning__HomePage</target>"
        "</targets>"
      ]
      params.extraFiles = [
          {
              srcFilePath: params.srcPath + @getPlatformPath('lwc/' + sfCreatingDialog.apiName + '/') + sfCreatingDialog.apiName + ".html"
              srcLines: ["<template>\n    <lightning-card title=\"Hello\" icon-name=\"custom:custom14\">\n        <div class=\"slds-m-around_medium\">Hello, {greeting}!</div>\n    </lightning-card>\n</template>"]
          }
      ]
    params.srcFilePath = params.fldPath + sfCreatingDialog.apiName + "." + params.extension
    params.metaFilePath = params.srcFilePath + "-meta.xml"
    params

#-----------

  writeFile: (filePath, lines, dirName) ->
    if dirName && !fs.existsSync(dirName)
        fs.mkdirSync(dirName)
    fh = fs.createWriteStream filePath
    for line in lines
       fh.write(line + "\n")
    fh.end("")

  writeMeta: (itemParams) ->
    if itemParams.metaLines
        lines = []
        lines.push "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<" + itemParams.metaDataType + " xmlns=\"http://soap.sforce.com/2006/04/metadata\">"
        for metaLine in itemParams.metaLines
          lines.push "    " + metaLine
        lines.push "</" + itemParams.metaDataType + ">"
        @writeFile itemParams.metaFilePath, lines, itemParams.fldPath
        itemParams.metaFilePath

  writeSrc: (itemParams) ->
    @writeFile itemParams.srcFilePath, itemParams.srcLines, itemParams.fldPath
    if itemParams.extraFiles
        for extraItemParams in itemParams.extraFiles
            @writeFile extraItemParams.srcFilePath, extraItemParams.srcLines, extraItemParams.fldPath
    itemParams.srcFilePath

#-----------

  writeBeforeLastOccurance: () ->
    [].push.call(arguments, "before")
    @writePerformLastOccurence.apply null, arguments

  writeAfterLastOccurance: () ->
    [].push.call(arguments, "after")
    @writePerformLastOccurence.apply null, arguments

  writePerformLastOccurence: (path, findText, newText, successCallback, errorCallback, place) ->
    if fs.existsSync path
      fileData = fs.readFileSync path, 'utf8'
      indexOcc = fileData.lastIndexOf findText
      if indexOcc != -1
        if place == "after"
          indexOcc += findText.length
        fileData = fileData.substr(0, indexOcc) + newText + fileData.substr(indexOcc)
        fs.writeFileSync path, fileData, 'utf8'
        if successCallback
          successCallback()
      else
        if errorCallback
          errorCallback()

#-----------

  createSfItem: (sfCreatingDialog, root) ->
    itemParams = @getSfCreatingItemParams(sfCreatingDialog, root)
    @writeMeta itemParams
    @writeSrc itemParams

#-----------

  deleteFolderRecursive: (path) ->
    if fs.existsSync(path)
      fs.readdirSync(path).forEach (file, index) =>
        curPath = path + "/" + file
        if fs.lstatSync(curPath).isDirectory()
          @deleteFolderRecursive(curPath);
        else
          fs.unlinkSync(curPath);
      fs.rmdirSync(path);

#-----------

  runProcess: (child, view, command, args, beforeCommand, afterCommand, onclose) ->
    if beforeCommand
      beforeCommand()
    child = child_process.exec(command, args)
    child.stdout.on 'data', view.append
    child.stderr.on 'data', view.append
    child.on "close", onclose
    if afterCommand
      afterCommand()

#-----------

  getMetaDataFromFolderName: (folderName) ->
    folderMapping = {
      'classes' : 'ApexClass'
      ,'triggers' : 'ApexTrigger'
      ,'pages' : 'ApexPage'
      ,'components' : 'ApexComponent'
      ,'staticresources' : 'StaticResource'
      ,'applications' : 'CustomApplication'
      ,'objects' : 'CustomObject'
      ,'tabs' : 'CustomTab'
      ,'layouts' : 'Layout'
      ,'quickActions' : 'QuickAction'
      ,'profiles' : 'Profile'
      ,'labels' : 'CustomLabels'
      ,'workflows' : 'Workflow'
      ,'remoteSiteSettings' : 'RemoteSiteSetting'
      ,'permissionsets' : 'PermissionSet'
      ,'letterhead' : 'Letterhead'
      ,'translations' : 'Translations'
      ,'groups' : 'Group'
      ,'objectTranslations' : 'CustomObjectTranslation'
      ,'communities' : 'Network'
      ,'reportTypes' : 'ReportType'
      ,'settings' : 'Settings'
      ,'assignmentRules' : 'AssignmentRule'
      ,'approvalProcesses' : 'ApprovalProcess'
      ,'escalationRules' : 'EscalationRule'
      ,'flows' : 'Flow'
      ,'aura' : 'AuraDefinitionBundle'
      ,'lwc' : 'LightningComponentBundle'
      ,'documents' : 'Document'
      ,'email' : 'EmailTemplate'
      ,'contentassets' : 'ContentAsset'
      ,'globalValueSets' : 'GlobalValueSet'
      ,'mlDomains' : 'MlDomain'
      ,'bots' : 'Bot'
    }
    result = null
    if folderMapping.hasOwnProperty folderName
      result = folderMapping[folderName]
    result

#-------------

  getLabelMeta: (cl) ->
    [
      '    <labels>'
      '        <fullName>' + cl.apiName + '</fullName>'
      '        <categories>' + cl.categories + '</categories>'
      '        <language>' + cl.language + '</language>'
      '        <protected>true</protected>'
      '        <shortDescription>' + cl.shortDesc + '</shortDescription>'
      '        <value>' + cl.label + '</value>'
      '    </labels>\n'
    ].join('\n')

  getLabelTranslationMeta: (cl) ->
    [
      '    <customLabels>'
      '        <label><!-- ' + cl.label + ' --></label>'
      '        <name>' + cl.apiName + '</name>'
      '    </customLabels>\n'
    ].join('\n')

  insertLabelSelection: (cl, editor) ->
    if editor
      newText = null;
      grammarName = editor.getGrammar().name
      if grammarName == "Apex"
        newText = 'Label.' + cl.apiName
      else if grammarName == "Visualforce"
        newText = '{!$Label.' + cl.apiName + '}'
      if newText != null
        editor.getLastSelection().insertText(newText, {"select" : true})

  insertCustomLabel: (cl, root, editor) ->
    labelsPath = @getPlatformPath root + '/src/labels/CustomLabels.labels'
    utils = this
    if fs.existsSync labelsPath
      @writeBeforeLastOccurance(labelsPath, '</CustomLabels>', @getLabelMeta(cl), () =>
        utils.insertLabelSelection cl, editor
      ,null)

      #Translations
      translationsPath = @getPlatformPath root + '/src/translations/';
      if fs.existsSync translationsPath
        fs.readdir translationsPath, (err, items) ->
          for i in items
            if /^.+\.translation$/.test(i)
              tPath = utils.getPlatformPath translationsPath + i
              utils.writeAfterLastOccurance(tPath, '</customLabels>\n', utils.getLabelTranslationMeta(cl), null, () =>
                utils.writeBeforeLastOccurance(tPath, '</Translations>', utils.getLabelTranslationMeta(cl), null, null)
              )
    fs.existsSync labelsPath
